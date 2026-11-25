--[[
	MultiDropdown.lua  -  multi-select list that expands inline.
	MultiDropdown.new(ctx, parent, config, section)
	  config: Name, Description, Options, Default = { values }, Max (optional limit),
	          Placeholder = "None", Callback(valuesArray)
	  :Set(array, silent)  :Get() -> array (option order)  :Toggle(value)
	  :SetOptions(list)    :Open()  :Close()
	  .Changed -> Signal(array)
]]

local MultiDropdown = {}
MultiDropdown.__index = MultiDropdown
MultiDropdown.Persistent = true

local function normalize(options)
	local entries = {}
	for _, option in ipairs(options or {}) do
		if type(option) == "table" then
			table.insert(entries, { Text = tostring(option.Text or option.Name or option.Value), Value = option.Value })
		else
			table.insert(entries, { Text = tostring(option), Value = option })
		end
	end
	return entries
end

function MultiDropdown.new(ctx, parent, config)
	local self = setmetatable({}, MultiDropdown)
	local Utils = ctx.Utils

	self.ctx = ctx
	self.Maid = Utils.Maid.new()
	self.Callback = config.Callback
	self.Placeholder = config.Placeholder or "None"
	self.Max = config.Max
	self.Changed = Utils.Signal.new()
	self.Maid:Give(self.Changed)
	self.Disabled = false
	self._selected = {}

	self.Shell = Utils.CreateDropdownShell(ctx, parent, config, self.Maid)
	self.Row = self.Shell.Row
	self.Root = self.Shell.Root

	self.Shell.OnPick = function(entry)
		self:Toggle(entry.Value)
	end

	self:SetOptions(config.Options or {})
	for _, value in ipairs(config.Default or {}) do
		self:_add(value)
	end
	self:_render()
	return self
end

function MultiDropdown:_find(value)
	for _, entry in ipairs(self.Shell.Entries) do
		if entry.Value == value or entry.Text == value then
			return entry
		end
	end
	return nil
end

function MultiDropdown:_count()
	local total = 0
	for _ in pairs(self._selected) do
		total = total + 1
	end
	return total
end

function MultiDropdown:_add(value)
	local entry = self:_find(value)
	if not entry then
		return false
	end
	if self.Max and not self._selected[entry] and self:_count() >= self.Max then
		return false
	end
	self._selected[entry] = true
	return true
end

function MultiDropdown:_render()
	local names = {}
	for _, entry in ipairs(self.Shell.Entries) do
		if self._selected[entry] then
			table.insert(names, entry.Text)
		end
	end

	if #names == 0 then
		self.Shell:SetValueText(self.Placeholder, true)
	elseif #names <= 2 then
		self.Shell:SetValueText(table.concat(names, ", "), false)
	else
		self.Shell:SetValueText(#names .. " selected", false)
	end

	self.Shell:Refresh(function(candidate)
		return self._selected[candidate] == true
	end)
end

function MultiDropdown:_emit(silent)
	self:_render()
	local values = self:Get()
	self.Changed:Fire(values)
	if not silent then
		self.ctx.Utils.Safe(self.Callback, values)
	end
end

function MultiDropdown:SetOptions(options)
	local previous = {}
	for entry in pairs(self._selected) do
		previous[entry.Value] = true
	end
	self.Shell:SetEntries(normalize(options))
	self._selected = {}
	for _, entry in ipairs(self.Shell.Entries) do
		if previous[entry.Value] then
			self._selected[entry] = true
		end
	end
	self:_render()
end

function MultiDropdown:Toggle(value)
	local entry = self:_find(value)
	if not entry then
		return
	end
	if self._selected[entry] then
		self._selected[entry] = nil
	elseif not self:_add(value) then
		return
	end
	self:_emit(false)
end

function MultiDropdown:Set(values, silent)
	self._selected = {}
	for _, value in ipairs(values or {}) do
		self:_add(value)
	end
	self:_emit(silent)
end

function MultiDropdown:Get()
	local values = {}
	for _, entry in ipairs(self.Shell.Entries) do
		if self._selected[entry] then
			table.insert(values, entry.Value)
		end
	end
	return values
end

function MultiDropdown:Open()
	self.Shell:Open()
end

function MultiDropdown:Close()
	self.Shell:Close()
end

function MultiDropdown:_onDisabled(disabled)
	self.Disabled = disabled
	self.Shell:SetDisabled(disabled)
end

return MultiDropdown
