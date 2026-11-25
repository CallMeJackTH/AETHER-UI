--[[
	ConfigManager.lua
	Saves, loads, deletes and lists named configurations.

	  * Components register themselves under a flag (see Components.lua);
	    Collect() reads every registered component, Apply() restores them.
	  * Values are sanitised into JSON-safe data (Color3 -> "#RRGGBB",
	    EnumItem -> name, NaN/inf -> 0) and encoded with HttpService.
	  * Storage: a real folder when the environment exposes the file functions
	    (writefile, readfile, isfile, ...). Every configuration is ALSO mirrored
	    in a memory store, so everything keeps working - for the current
	    session - when no filesystem exists or a write fails.

	ConfigManager.new(ctx, { Folder = "AetherUI" })
	  :Register(flag, component) -> finalFlag      :Unregister(flag)
	  :Collect() -> { [flag] = value }              :Apply(values) -> report
	  :Save(name) / :Load(name) / :Delete(name)     -> ok, errorOrReport
	  :List() -> { { Name, Modified, Size } }       :Exists(name)
	  :Export(name?) -> json                        :Import(name, json) -> ok, err
	  :SetAutoload(name|nil) / :GetAutoload() / :LoadAutoload()
	  :GetBackend() -> "File" | "Memory"            .Current / .Changed (Signal)
]]

local HttpService = game:GetService("HttpService")

local ConfigManager = {}
ConfigManager.__index = ConfigManager

local FORMAT = "AetherConfig"
local VERSION = 1
local MAX_NAME = 40

local function envLookup(name)
	local ok, value = pcall(function()
		return getfenv(0)[name]
	end)
	if ok and value ~= nil then
		return value
	end
	local okGlobal, globalValue = pcall(function()
		return _G[name]
	end)
	if okGlobal then
		return globalValue
	end
	return nil
end

local function sanitize(value, depth)
	depth = depth or 0
	if depth > 8 then
		return nil
	end

	local kind = typeof(value)
	if kind == "number" then
		if value ~= value or value == math.huge or value == -math.huge then
			return 0
		end
		return value
	elseif kind == "string" or kind == "boolean" then
		return value
	elseif kind == "Color3" then
		return string.format(
			"#%02X%02X%02X",
			math.floor(value.R * 255 + 0.5),
			math.floor(value.G * 255 + 0.5),
			math.floor(value.B * 255 + 0.5)
		)
	elseif kind == "EnumItem" then
		return value.Name
	elseif kind == "table" then
		local isArray = #value > 0 or next(value) == nil
		local result = {}
		if isArray then
			for index, item in ipairs(value) do
				result[index] = sanitize(item, depth + 1)
			end
		else
			for key, item in pairs(value) do
				if type(key) == "string" then
					result[key] = sanitize(item, depth + 1)
				end
			end
		end
		return result
	end
	return nil
end

local function cleanName(name)
	name = tostring(name or "")
	name = name:gsub("%.json$", "")
	name = name:gsub("[^%w _%-%.]", "")
	name = name:gsub("^%s+", ""):gsub("%s+$", "")
	if #name > MAX_NAME then
		name = name:sub(1, MAX_NAME)
	end
	return name
end

function ConfigManager.new(ctx, options)
	options = options or {}
	local self = setmetatable({}, ConfigManager)

	self.ctx = ctx
	self.Folder = options.Folder or "AetherUI"
	self.ConfigFolder = self.Folder .. "/configs"
	self.AutoloadPath = self.Folder .. "/autoload.txt"
	self.Changed = ctx.Utils.Signal.new()
	self.Current = nil
	self._flags = {}
	self._flagOrder = {}
	self._destroyed = false

	-- Shared memory store survives re-execution within the same session.
	local holder = (type(_G) == "table") and _G or {}
	local ok = pcall(function()
		holder.__AetherUIStore = holder.__AetherUIStore or { Configs = {}, Meta = {}, Autoload = nil }
	end)
	self._store = (ok and holder.__AetherUIStore) or { Configs = {}, Meta = {}, Autoload = nil }

	self._fs = {
		writefile = envLookup("writefile"),
		readfile = envLookup("readfile"),
		isfile = envLookup("isfile"),
		isfolder = envLookup("isfolder"),
		makefolder = envLookup("makefolder"),
		listfiles = envLookup("listfiles"),
		delfile = envLookup("delfile"),
	}

	local fs = self._fs
	self._hasFiles = type(fs.writefile) == "function"
		and type(fs.readfile) == "function"
		and type(fs.isfile) == "function"
		and type(fs.isfolder) == "function"
		and type(fs.makefolder) == "function"
		and type(fs.listfiles) == "function"
		and type(fs.delfile) == "function"

	if self._hasFiles then
		local prepared = pcall(function()
			if not fs.isfolder(self.Folder) then
				fs.makefolder(self.Folder)
			end
			if not fs.isfolder(self.ConfigFolder) then
				fs.makefolder(self.ConfigFolder)
			end
		end)
		if not prepared then
			self._hasFiles = false
		end
	end

	return self
end

function ConfigManager:GetBackend()
	return self._hasFiles and "File" or "Memory"
end

----------------------------------------------------------------------
-- Flag registry
----------------------------------------------------------------------

function ConfigManager:Register(flag, component)
	assert(type(flag) == "string" and flag ~= "", "[AetherUI] flag must be a non-empty string")
	local final = flag
	local suffix = 1
	while self._flags[final] do
		suffix = suffix + 1
		final = flag .. "#" .. suffix
	end
	self._flags[final] = component
	table.insert(self._flagOrder, final)
	return final
end

function ConfigManager:Unregister(flag)
	if not flag or not self._flags[flag] then
		return
	end
	self._flags[flag] = nil
	local index = table.find(self._flagOrder, flag)
	if index then
		table.remove(self._flagOrder, index)
	end
end

function ConfigManager:GetFlags()
	return table.clone(self._flagOrder)
end

function ConfigManager:GetComponent(flag)
	return self._flags[flag]
end

----------------------------------------------------------------------
-- Collect / apply
----------------------------------------------------------------------

function ConfigManager:Collect()
	local values = {}
	for _, flag in ipairs(self._flagOrder) do
		local component = self._flags[flag]
		if component then
			local ok, value = pcall(function()
				if component.Serialize then
					return component:Serialize()
				end
				return component:Get()
			end)
			if ok then
				local clean = sanitize(value)
				if clean ~= nil then
					values[flag] = clean
				end
			else
				warn("[AetherUI] could not read flag '" .. flag .. "': " .. tostring(value))
			end
		end
	end
	return values
end

-- Returns { Applied = n, Failed = { flag, ... }, Unknown = { flag, ... } }
function ConfigManager:Apply(values)
	local report = { Applied = 0, Failed = {}, Unknown = {} }
	if type(values) ~= "table" then
		return report
	end

	for flag, value in pairs(values) do
		local component = self._flags[flag]
		if not component then
			table.insert(report.Unknown, flag)
		else
			local ok, err = pcall(function()
				if component.Deserialize then
					component:Deserialize(value)
				else
					component:Set(value)
				end
			end)
			if ok then
				report.Applied = report.Applied + 1
			else
				table.insert(report.Failed, flag)
				warn("[AetherUI] could not restore flag '" .. flag .. "': " .. tostring(err))
			end
		end
	end
	return report
end

----------------------------------------------------------------------
-- Serialization
----------------------------------------------------------------------

function ConfigManager:Encode(name, values)
	local payload = {
		Format = FORMAT,
		Version = VERSION,
		Name = name or "Config",
		Saved = os.time(),
		Flags = values or self:Collect(),
	}
	local ok, result = pcall(function()
		return HttpService:JSONEncode(payload)
	end)
	if not ok then
		return nil, "Could not encode configuration: " .. tostring(result)
	end
	return result
end

function ConfigManager:Decode(json)
	if type(json) ~= "string" or json:gsub("%s", "") == "" then
		return nil, "Configuration data is empty"
	end
	local ok, data = pcall(function()
		return HttpService:JSONDecode(json)
	end)
	if not ok or type(data) ~= "table" then
		return nil, "Configuration data is not valid JSON"
	end
	if type(data.Flags) == "table" then
		return data
	end
	if data.Format == nil and data.Flags == nil then
		-- Bare { flag = value } map.
		return { Format = FORMAT, Version = VERSION, Flags = data }
	end
	return nil, "Configuration data has no Flags table"
end

----------------------------------------------------------------------
-- Storage
----------------------------------------------------------------------

function ConfigManager:_path(name)
	return self.ConfigFolder .. "/" .. name .. ".json"
end

function ConfigManager:_write(name, json)
	self._store.Configs[name] = json
	self._store.Meta[name] = { Modified = os.time(), Size = #json }

	if self._hasFiles then
		local ok, err = pcall(self._fs.writefile, self:_path(name), json)
		if not ok then
			warn("[AetherUI] file write failed, kept in memory: " .. tostring(err))
			return true, "Saved to memory only"
		end
	end
	return true
end

function ConfigManager:_read(name)
	if self._hasFiles then
		local ok, text = pcall(function()
			if self._fs.isfile(self:_path(name)) then
				return self._fs.readfile(self:_path(name))
			end
			return nil
		end)
		if ok and type(text) == "string" then
			return text
		end
	end
	return self._store.Configs[name]
end

function ConfigManager:Exists(name)
	name = cleanName(name)
	if name == "" then
		return false
	end
	return self:_read(name) ~= nil
end

function ConfigManager:Save(name)
	name = cleanName(name)
	if name == "" then
		return false, "Enter a configuration name"
	end

	local json, err = self:Encode(name)
	if not json then
		return false, err
	end

	local ok, note = self:_write(name, json)
	if not ok then
		return false, note
	end

	self.Current = name
	self.Changed:Fire("Saved", name)
	return true, note
end

function ConfigManager:Load(name)
	name = cleanName(name)
	if name == "" then
		return false, "Select a configuration"
	end

	local json = self:_read(name)
	if not json then
		return false, "Configuration '" .. name .. "' was not found"
	end

	local data, err = self:Decode(json)
	if not data then
		return false, err
	end

	local report = self:Apply(data.Flags)
	self.Current = name
	self.Changed:Fire("Loaded", name)
	return true, report
end

function ConfigManager:Delete(name)
	name = cleanName(name)
	if name == "" then
		return false, "Select a configuration"
	end
	if not self:Exists(name) then
		return false, "Configuration '" .. name .. "' was not found"
	end

	self._store.Configs[name] = nil
	self._store.Meta[name] = nil

	if self._hasFiles then
		local ok, err = pcall(function()
			if self._fs.isfile(self:_path(name)) then
				self._fs.delfile(self:_path(name))
			end
		end)
		if not ok then
			return false, "Could not delete file: " .. tostring(err)
		end
	end

	if self:GetAutoload() == name then
		self:SetAutoload(nil)
	end
	if self.Current == name then
		self.Current = nil
	end

	self.Changed:Fire("Deleted", name)
	return true
end

function ConfigManager:List()
	local found = {}

	if self._hasFiles then
		local ok, files = pcall(self._fs.listfiles, self.ConfigFolder)
		if ok and type(files) == "table" then
			for _, path in ipairs(files) do
				local name = tostring(path):match("([^/\\]+)%.json$")
				if name then
					found[name] = true
				end
			end
		end
	end
	for name in pairs(self._store.Configs) do
		found[name] = true
	end

	local list = {}
	for name in pairs(found) do
		local meta = self._store.Meta[name]
		if not meta then
			local json = self:_read(name)
			local data = json and self:Decode(json)
			meta = {
				Modified = data and tonumber(data.Saved) or 0,
				Size = json and #json or 0,
			}
			self._store.Meta[name] = meta
		end
		table.insert(list, { Name = name, Modified = meta.Modified, Size = meta.Size })
	end

	table.sort(list, function(a, b)
		if a.Modified ~= b.Modified then
			return a.Modified > b.Modified
		end
		return a.Name < b.Name
	end)
	return list
end

----------------------------------------------------------------------
-- Export / import
----------------------------------------------------------------------

function ConfigManager:Export(name)
	if name and name ~= "" then
		name = cleanName(name)
		local json = self:_read(name)
		if json then
			return json
		end
	end
	return self:Encode(name or self.Current or "Config")
end

function ConfigManager:Import(name, json)
	name = cleanName(name)
	if name == "" then
		return false, "Enter a name for the imported configuration"
	end
	local data, err = self:Decode(json)
	if not data then
		return false, err
	end
	local text, encodeErr = self:Encode(name, data.Flags)
	if not text then
		return false, encodeErr
	end
	local ok, note = self:_write(name, text)
	if not ok then
		return false, note
	end
	self.Changed:Fire("Imported", name)
	return true, note
end

----------------------------------------------------------------------
-- Autoload
----------------------------------------------------------------------

function ConfigManager:GetAutoload()
	if self._hasFiles then
		local ok, text = pcall(function()
			if self._fs.isfile(self.AutoloadPath) then
				return self._fs.readfile(self.AutoloadPath)
			end
			return nil
		end)
		if ok and type(text) == "string" and text ~= "" then
			return cleanName(text)
		end
	end
	return self._store.Autoload
end

function ConfigManager:SetAutoload(name)
	name = name and cleanName(name) or nil
	if name == "" then
		name = nil
	end
	self._store.Autoload = name

	if self._hasFiles then
		pcall(function()
			if name then
				self._fs.writefile(self.AutoloadPath, name)
			elseif self._fs.isfile(self.AutoloadPath) then
				self._fs.delfile(self.AutoloadPath)
			end
		end)
	end
	self.Changed:Fire("Autoload", name)
end

function ConfigManager:LoadAutoload()
	local name = self:GetAutoload()
	if not name then
		return false, "No autoload configuration is set"
	end
	return self:Load(name)
end

function ConfigManager:Destroy()
	if self._destroyed then
		return
	end
	self._destroyed = true
	self.Changed:Destroy()
	self._flags = {}
	self._flagOrder = {}
end

return ConfigManager
