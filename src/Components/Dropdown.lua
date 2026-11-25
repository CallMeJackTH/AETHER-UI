--[[
	Dropdown.lua  -  single-select list that expands inline.
	Dropdown.new(ctx, parent, config, section)
	  config: Name, Description, Options = { "A", "B" } or { { Text, Value } },
	          Default, Placeholder = "Select...", Callback(value)
	  :Set(value, silent)  :Get()  :SetOptions(list, keepSelection)
	  :Open()  :Close()
	  .Changed -> Signal(value)
]]

local Dropdown = {}
Dropdown.__index = Dropdown
Dropdown.Persistent = true

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

function Dropdown.new(ctx, parent, config)
	local self = setmetatable({}, Dropdown)
	local Utils = ctx.Utils

	self.ctx = ctx
	self.Maid = Utils.Maid.new()
	self.Callback = config.Callback
	self.Placeholder = config.Placeholder or "Select..."
	self.Changed = Utils.Signal.new()
	self.Maid:Give(self.Changed)
	self.Disabled = false
	self.Value = nil

	self.Shell = Utils.CreateDropdownShell(ctx, parent, config, self.Maid)
	self.Row = self.Shell.Row
	self.Root = self.Shell.Root

	self.Shell.OnPick = function(entry)
		self:Set(entry.Value)
		self.Shell:Close()
	end

	self:SetOptions(config.Options or {}, false)
	if config.Default ~= nil then
		self:_select(config.Default)
	end
	self:_render()
	return self
end

function Dropdown:_find(value)
	for _, entry in ipairs(self.Shell.Entries) do
		if entry.Value == value or entry.Text == value then
			return entry
		end
	end
	return nil
end

function Dropdown:_select(value)
	local entry = self:_find(value)
	if entry then
		self.Value = entry.Value
		return true
	end
	return false
end

function Dropdown:_render()
	local entry = self.Value ~= nil and self:_find(self.Value) or nil
	if entry then
		self.Shell:SetValueText(entry.Text, false)
	else
		self.Shell:SetValueText(self.Placeholder, true)
	end
	self.Shell:Refresh(function(candidate)
		return self.Value ~= nil and candidate.Value == self.Value
	end)
end

function Dropdown:SetOptions(options, keepSelection)
	self.Shell:SetEntries(normalize(options))
	if keepSelection == false or self.Value == nil or not self:_find(self.Value) then
		self.Value = nil
	end
	self:_render()
end

function Dropdown:Set(value, silent)
	if not self:_select(value) then
		return false
	end
	self:_render()
	self.Changed:Fire(self.Value)
	if not silent then
		self.ctx.Utils.Safe(self.Callback, self.Value)
	end
	return true
end

function Dropdown:Get()
	return self.Value
end

function Dropdown:Open()
	self.Shell:Open()
end

function Dropdown:Close()
	self.Shell:Close()
end

function Dropdown:_onDisabled(disabled)
	self.Disabled = disabled
	self.Shell:SetDisabled(disabled)
end

return Dropdown
