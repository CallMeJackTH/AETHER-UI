--[[
	Components.lua
	Component registry, the Section class and the behaviour every component
	shares (disabled state, visibility, tooltip, flag registration, Destroy).

	Component modules live in Components/ and expose
	    Module.new(ctx, parent, config, section) -> component
	with Set / Get and a `Maid`. Components.lua adds the shared methods:
	    :SetDisabled(bool) :IsDisabled() :SetVisible(bool) :IsVisible()
	    :SetTooltip(text)  :SetName(text) :SetDescription(text) :Destroy()
	and registers value components with the ConfigManager under `Flag`
	(auto-generated "Tab.Section.Name" unless config.Flag is given;
	config.Flag = false opts out).

	Built-in here: SearchBar, ProgressBar, LoadingIndicator.

	Section:CreateButton / CreateToggle / CreateSlider / CreateDropdown /
	CreateMultiDropdown / CreateTextbox / CreateKeybind / CreateColorPicker /
	CreateLabel / CreateParagraph / CreateDivider / CreateSearchBar /
	CreateProgressBar / CreateLoadingIndicator
	Components.Register(name, module) adds Section:Create<name>.
]]

local Components = {}
Components.Types = {}
Components.Order = {}

-- Works both when Components.lua sits beside a `Components` folder and when it
-- is the `init` module of that folder.
local function findRoot()
	if script:FindFirstChild("Button") then
		return script
	end
	for _, child in ipairs(script.Parent:GetChildren()) do
		if child ~= script and child.Name == "Components" and child:FindFirstChild("Button") then
			return child
		end
	end
	error("[AetherUI] Components folder not found next to Components.lua")
end

local root = findRoot()

----------------------------------------------------------------------
-- Built-in: SearchBar
----------------------------------------------------------------------

local SearchBar = {}
SearchBar.__index = SearchBar

function SearchBar.new(ctx, parent, config)
	local self = setmetatable({}, SearchBar)
	local Utils, theme, animation = ctx.Utils, ctx.Theme, ctx.Animation
	local colors, fonts, sizes = theme.Colors, theme.Fonts, theme.Sizes
	local inline = config.Inline and true or false

	self.ctx = ctx
	self.Maid = Utils.Maid.new()
	self.Callback = config.Callback
	self.Live = config.Live ~= false
	self.Value = ""
	self.Disabled = false
	self.Searchable = false

	local height = config.Height or (ctx.ControlHeight + (inline and 0 or 8))
	local holder = Utils.Create("Frame", {
		Name = "SearchBar",
		Size = config.Size or UDim2.new(1, 0, 0, height),
		Position = config.Position or UDim2.new(),
		AnchorPoint = config.AnchorPoint or Vector2.new(0, 0),
		BackgroundColor3 = colors.Background,
		BorderSizePixel = 0,
		Parent = parent,
	})
	Utils.Corner(holder, theme.Layout.RadiusControl)
	self.Stroke = Utils.Stroke(holder, colors.Border, 1, 0)
	self.Root = holder
	self.Holder = holder

	local icon = Utils.Icon("search", holder, colors.Subtle, {
		Size = UDim2.fromOffset(14, 14),
		AnchorPoint = Vector2.new(0, 0.5),
		Position = UDim2.new(0, 9, 0.5, 0),
	})

	self.Box = Utils.Create("TextBox", {
		Name = "Box",
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		Position = UDim2.fromOffset(30, 0),
		Size = UDim2.new(1, -56, 1, 0),
		Font = fonts.Regular,
		TextSize = sizes.Small + 1,
		TextColor3 = colors.Text,
		PlaceholderText = config.Placeholder or "Search...",
		PlaceholderColor3 = colors.Subtle,
		TextXAlignment = Enum.TextXAlignment.Left,
		ClearTextOnFocus = false,
		TextTruncate = Enum.TextTruncate.AtEnd,
		Text = "",
		Parent = holder,
	})

	local clear = Utils.Create("TextButton", {
		Name = "Clear",
		Text = "",
		AutoButtonColor = false,
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(1, -5, 0.5, 0),
		Size = UDim2.fromOffset(20, 20),
		BackgroundColor3 = colors.Hover,
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		Visible = false,
		Parent = holder,
	})
	Utils.Corner(clear, 5)
	local clearIcon = Utils.Icon("close", clear, colors.Muted, {
		Size = UDim2.fromOffset(10, 10),
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.new(0.5, 0, 0.5, 0),
	})
	self._clear = clear

	Utils.BindInteract(clear, self.Maid, {
		Hover = function(hover)
			animation:Play(clear, "Hover", { BackgroundTransparency = hover and 0.4 or 1 })
			animation:IconColor(clearIcon, hover and colors.Text or colors.Muted)
		end,
	})
	self.Maid:Give(clear.Activated:Connect(function()
		self:Clear()
		self.Box:CaptureFocus()
	end))

	self.Maid:Give(self.Box.Focused:Connect(function()
		animation:Focus(self.Stroke, holder, true)
		animation:IconColor(icon, colors.Accent)
	end))
	self.Maid:Give(self.Box.FocusLost:Connect(function(enter)
		animation:Focus(self.Stroke, holder, false)
		animation:IconColor(icon, colors.Subtle)
		if not self.Live and enter then
			Utils.Safe(self.Callback, self.Value)
		end
	end))

	local token = 0
	self.Maid:Give(self.Box:GetPropertyChangedSignal("Text"):Connect(function()
		self.Value = self.Box.Text
		clear.Visible = self.Value ~= ""
		if self.Live then
			token = token + 1
			local mine = token
			task.delay(0.1, function()
				if mine == token and holder.Parent then
					Utils.Safe(self.Callback, self.Value)
				end
			end)
		end
	end))

	self.Row = { Disabler = Utils.CreateDisabler(theme, holder, theme.Layout.RadiusControl) }
	return self
end

function SearchBar:Set(text, silent)
	self.Box.Text = tostring(text or "")
	self.Value = self.Box.Text
	if silent then
		return
	end
	self.ctx.Utils.Safe(self.Callback, self.Value)
end

function SearchBar:Get()
	return self.Value
end

function SearchBar:Clear()
	self.Box.Text = ""
end

function SearchBar:Focus()
	if not self.Disabled then
		self.Box:CaptureFocus()
	end
end

function SearchBar:_onDisabled(disabled)
	self.Disabled = disabled
	self.Box.TextEditable = not disabled
end

----------------------------------------------------------------------
-- Built-in: ProgressBar
----------------------------------------------------------------------

local ProgressBar = {}
ProgressBar.__index = ProgressBar

function ProgressBar.new(ctx, parent, config)
	local self = setmetatable({}, ProgressBar)
	local Utils, theme = ctx.Utils, ctx.Theme
	local colors, fonts, sizes = theme.Colors, theme.Fonts, theme.Sizes

	self.ctx = ctx
	self.Maid = Utils.Maid.new()
	self.Callback = config.Callback
	self.Min = config.Min or 0
	self.Max = config.Max or 100
	self.Suffix = config.Suffix
	self.Disabled = false
	self.Indeterminate = false

	local hasDescription = config.Description ~= nil and config.Description ~= ""
	local height = (hasDescription and (ctx.RowHeight + 14) or ctx.RowHeight) + 8
	local row = Utils.CreateRow(ctx, parent, config, { TopAligned = true, Height = height, Reserve = 60 })
	self.Row = row
	self.Root = row.Root

	self.ValueLabel = Utils.Text(theme, row.Root, {
		Name = "Value",
		Font = fonts.Mono,
		TextSize = sizes.Caption,
		TextColor3 = colors.Accent,
		TextXAlignment = Enum.TextXAlignment.Right,
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -row.Padding, 0, 8),
		Size = UDim2.fromOffset(70, 18),
	})

	self.Track = Utils.Create("Frame", {
		Name = "Track",
		AnchorPoint = Vector2.new(0, 0.5),
		Position = UDim2.new(0, row.Padding, 1, -14),
		Size = UDim2.new(1, -row.Padding * 2, 0, 4),
		BackgroundColor3 = colors.Border,
		BorderSizePixel = 0,
		ClipsDescendants = true,
		Parent = row.Root,
	})
	Utils.Corner(self.Track, 2)

	self.Fill = Utils.Create("Frame", {
		Name = "Fill",
		Size = UDim2.new(0, 0, 1, 0),
		BackgroundColor3 = colors.Accent,
		BorderSizePixel = 0,
		Parent = self.Track,
	})
	Utils.Corner(self.Fill, 2)

	self.Segment = Utils.Create("Frame", {
		Name = "Segment",
		Size = UDim2.new(0.4, 0, 1, 0),
		BackgroundColor3 = colors.Accent,
		BorderSizePixel = 0,
		Visible = false,
		Parent = self.Track,
	})
	Utils.Corner(self.Segment, 2)

	self.Maid:Give(function()
		if self._stop then
			self._stop()
			self._stop = nil
		end
	end)

	self.Value = Utils.Clamp(config.Default or self.Min, self.Min, self.Max)
	self:_render(true)
	if config.Indeterminate then
		self:SetIndeterminate(true)
	end
	return self
end

function ProgressBar:_ratio()
	local span = self.Max - self.Min
	if span <= 0 then
		return 0
	end
	return (self.Value - self.Min) / span
end

function ProgressBar:_render(instant)
	local ratio = self:_ratio()
	if not self.Indeterminate then
		self.ValueLabel.Text = self.Suffix and (tostring(math.floor(self.Value * 10 + 0.5) / 10) .. self.Suffix)
			or (math.floor(ratio * 100 + 0.5) .. "%")
	end
	if instant then
		self.ctx.Animation:Tween(self.Fill, { Size = UDim2.new(ratio, 0, 1, 0) }, 0)
	else
		self.ctx.Animation:ProgressFill(self.Fill, ratio)
	end
end

function ProgressBar:Set(value, silent)
	if self.Indeterminate then
		self:SetIndeterminate(false)
	end
	self.Value = self.ctx.Utils.Clamp(tonumber(value) or self.Min, self.Min, self.Max)
	self:_render(false)
	if not silent then
		self.ctx.Utils.Safe(self.Callback, self.Value)
	end
end

function ProgressBar:Get()
	return self.Value
end

function ProgressBar:SetIndeterminate(state)
	state = state and true or false
	if state == self.Indeterminate then
		return
	end
	self.Indeterminate = state
	self.Fill.Visible = not state
	self.Segment.Visible = state

	if state then
		self.ValueLabel.Text = "..."
		self._stop = self.ctx.Animation:Indeterminate(self.Segment)
	else
		if self._stop then
			self._stop()
			self._stop = nil
		end
		self:_render(true)
	end
end

----------------------------------------------------------------------
-- Built-in: LoadingIndicator
----------------------------------------------------------------------

local LoadingIndicator = {}
LoadingIndicator.__index = LoadingIndicator

function LoadingIndicator.new(ctx, parent, config)
	local self = setmetatable({}, LoadingIndicator)
	local Utils, theme = ctx.Utils, ctx.Theme
	local colors = theme.Colors

	self.ctx = ctx
	self.Maid = Utils.Maid.new()
	self.Disabled = false
	self.Active = false

	local row = Utils.CreateRow(ctx, parent, config)
	self.Row = row
	self.Root = row.Root
	local pad = row.Padding

	-- Make room for the spinner on the left.
	row.Title.Position = row.Description and UDim2.fromOffset(pad + 30, 8) or UDim2.new(0, pad + 30, 0.5, 0)
	row.Title.Size = UDim2.new(1, -(pad * 2 + 30), 0, 18)
	if row.Description then
		row.Description.Position = UDim2.fromOffset(pad + 30, 26)
		row.Description.Size = UDim2.new(1, -(pad * 2 + 30), 0, 16)
	end

	local ring = Utils.Create("Frame", {
		Name = "Spinner",
		AnchorPoint = Vector2.new(0, 0.5),
		Position = UDim2.new(0, pad, 0.5, 0),
		Size = UDim2.fromOffset(18, 18),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		Parent = row.Root,
	})
	Utils.Corner(ring, 9)
	self.RingStroke = Utils.Stroke(ring, colors.Accent, 2, 0.75)
	self.Gradient = Utils.Create("UIGradient", {
		Transparency = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 0),
			NumberSequenceKeypoint.new(0.5, 0.55),
			NumberSequenceKeypoint.new(1, 1),
		}),
		Parent = self.RingStroke,
	})

	self.Maid:Give(function()
		if self._stop then
			self._stop()
			self._stop = nil
		end
	end)

	self:Set(config.Active ~= false)
	return self
end

function LoadingIndicator:Set(active)
	active = active and true or false
	if active == self.Active and (self._stop ~= nil) == active then
		return
	end
	self.Active = active
	if active then
		self.RingStroke.Transparency = 0
		if not self._stop then
			self._stop = self.ctx.Animation:Spinner(self.Gradient)
		end
	else
		if self._stop then
			self._stop()
			self._stop = nil
		end
		self.RingStroke.Transparency = 0.75
	end
end

function LoadingIndicator:Get()
	return self.Active
end

function LoadingIndicator:SetText(text)
	self.Row.Title.Text = tostring(text)
	if self._item then
		self._item.Name = tostring(text)
	end
end

----------------------------------------------------------------------
-- Registry
----------------------------------------------------------------------

local Section = {}
Section.__index = Section
Components.Section = Section

local function installMethod(typeName)
	Section["Create" .. typeName] = function(self, config)
		return self:_create(typeName, config)
	end
end

function Components.Register(name, module)
	assert(type(name) == "string" and name ~= "", "Components.Register expects a name")
	assert(type(module) == "table" and type(module.new) == "function", "Components.Register expects a module with .new")
	if not Components.Types[name] then
		table.insert(Components.Order, name)
	end
	Components.Types[name] = module
	installMethod(name)
end

for _, name in ipairs({ "Button", "Toggle", "Slider", "Dropdown", "MultiDropdown", "Textbox", "Keybind", "ColorPicker", "Label", "Paragraph", "Divider" }) do
	Components.Register(name, require(root[name]))
end
Components.Register("SearchBar", SearchBar)
Components.Register("ProgressBar", ProgressBar)
Components.Register("LoadingIndicator", LoadingIndicator)

----------------------------------------------------------------------
-- Shared component behaviour
----------------------------------------------------------------------

local Mixin = {}

function Mixin:SetDisabled(disabled)
	disabled = disabled and true or false
	self.Disabled = disabled
	local row = self.Row
	if row and row.Disabler then
		self._ctx.Animation:Disabled(row.Disabler, disabled)
	end
	if self._onDisabled then
		self:_onDisabled(disabled)
	end
end

function Mixin:IsDisabled()
	return self.Disabled == true
end

function Mixin:SetVisible(visible)
	local item = self._item
	if item then
		item.UserHidden = not visible
		item.Root.Visible = visible and item.Matches
		if self.Section then
			self.Section:_changed()
		end
	else
		self.Root.Visible = visible and true or false
	end
end

function Mixin:IsVisible()
	if self._item then
		return not self._item.UserHidden
	end
	return self.Root.Visible
end

function Mixin:SetTooltip(text)
	self._tooltipText = text
	if not self._tooltipAttached and self._ctx.Overlay then
		self._tooltipAttached = true
		self.Maid:Give(self._ctx.Overlay:AttachTooltip(self.Root, function()
			return self._tooltipText
		end))
	end
end

function Mixin:SetName(text)
	text = tostring(text)
	if self.Row and self.Row.Title then
		self.Row.Title.Text = text
	end
	if self._item then
		self._item.Name = text
	end
end

function Mixin:SetDescription(text)
	text = tostring(text)
	if self.Row and self.Row.Description then
		self.Row.Description.Text = text
	end
	if self._item then
		self._item.Description = text
	end
end

function Mixin:Destroy()
	if self.Destroyed then
		return
	end
	self.Destroyed = true
	local ctx = self._ctx
	if self.Flag then
		ctx.Config:Unregister(self.Flag)
		self.Flag = nil
	end
	if self.Section then
		self.Section:_remove(self)
	end
	self.Maid:Destroy()
	if self.Root then
		ctx.Animation:Cancel(self.Root)
		self.Root:Destroy()
	end
end

local function finalize(component, section, typeName, config)
	local ctx = section.ctx
	component._ctx = ctx
	component.Type = typeName
	component.Section = section

	for name, fn in pairs(Mixin) do
		if component[name] == nil then
			component[name] = fn
		end
	end

	local title = tostring(config.Name or config.Title or config.Text or "")
	component._item = {
		Component = component,
		Root = component.Root,
		Name = title,
		Description = config.Description or config.Content,
		Searchable = component.Searchable ~= false,
		Matches = true,
		UserHidden = false,
	}
	table.insert(section.Items, component)

	if component.Root and component.Root:IsA("GuiObject") then
		section._order = section._order + 1
		component.Root.LayoutOrder = section._order
	end

	-- Persist value components.
	if getmetatable(component) and getmetatable(component).Persistent and config.Flag ~= false then
		local flag = config.Flag
		if type(flag) ~= "string" or flag == "" then
			local scope = section.Tab and (section.Tab.Name .. ".") or ""
			flag = scope .. (section.Name ~= "" and (section.Name .. ".") or "") .. (title ~= "" and title or typeName)
		end
		component.Flag = ctx.Config:Register(flag, component)
	end

	if config.Tooltip then
		component:SetTooltip(config.Tooltip)
	end
	if config.ContextMenu and ctx.Overlay then
		ctx.Overlay:AttachContextMenu(component.Root, config.ContextMenu, component.Maid)
	end
	if config.Disabled then
		component:SetDisabled(true)
	end
	if config.Visible == false then
		component:SetVisible(false)
	end

	section:_changed()
	return component
end

----------------------------------------------------------------------
-- Section
----------------------------------------------------------------------

-- Section.new(ctx, tab, name, options)
--   options.Parent: use an existing container instead of creating a framed group
function Section.new(ctx, tab, name, options)
	options = options or {}
	local self = setmetatable({}, Section)
	local Utils, theme = ctx.Utils, ctx.Theme

	self.ctx = ctx
	self.Tab = tab
	self.Name = tostring(name or "")
	self.Items = {}
	self.Hidden = false
	self._order = 0

	if options.Parent then
		self.Frame = options.Parent
		self.Container = options.Parent
		self._external = true
		return self
	end

	self.Frame = Utils.Create("Frame", {
		Name = "Section_" .. self.Name,
		Size = UDim2.new(1, 0, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		LayoutOrder = options.LayoutOrder or 0,
		Parent = options.ParentFrame,
	})
	Utils.List(self.Frame, theme.Layout.Gap)
	self.Container = self.Frame

	if self.Name ~= "" then
		self.Header = Utils.Text(theme, self.Frame, {
			Name = "Header",
			Text = string.upper(self.Name),
			Font = theme.Fonts.Bold,
			TextSize = theme.Sizes.Tiny + 1,
			TextColor3 = theme.Colors.Subtle,
			Size = UDim2.new(1, 0, 0, 18),
			LayoutOrder = 0,
		})
		Utils.Padding(self.Header, 0, 0, 0, 2)
	end

	return self
end

function Components.NewContainer(ctx, parent)
	return Section.new(ctx, nil, "", { Parent = parent })
end

function Section:_create(typeName, config)
	local module = Components.Types[typeName]
	assert(module, "[AetherUI] Unknown component type: " .. tostring(typeName))
	if type(config) ~= "table" then
		config = { Name = config }
	end
	local component = module.new(self.ctx, self.Container, config, self)
	return finalize(component, self, typeName, config)
end

-- Parents a hand-built instance into the section's layout (e.g. custom cards).
function Section:AddCustom(instance)
	self._order = self._order + 1
	instance.LayoutOrder = self._order
	instance.Parent = self.Container
	return instance
end

function Section:_remove(component)
	local index = table.find(self.Items, component)
	if index then
		table.remove(self.Items, index)
	end
	self:_changed()
end

function Section:_changed()
	if self.Tab and self.Tab._sectionChanged then
		self.Tab:_sectionChanged(self)
	end
end

-- Returns true when the section still has something visible.
function Section:ApplyFilter(query)
	local anyVisible = false
	for _, component in ipairs(self.Items) do
		local item = component._item
		if query == "" then
			item.Matches = true
		elseif item.Searchable == false then
			item.Matches = false
		else
			local haystack = string.lower(tostring(item.Name or "") .. " " .. tostring(item.Description or ""))
			item.Matches = string.find(haystack, query, 1, true) ~= nil
		end
		local visible = item.Matches and not item.UserHidden
		item.Root.Visible = visible
		if visible then
			anyVisible = true
		end
	end

	local shown
	if query == "" then
		shown = true
	else
		shown = anyVisible
	end
	if not self._external then
		self.Frame.Visible = shown and not self.Hidden
	end
	return shown and not self.Hidden
end

function Section:SetVisible(visible)
	self.Hidden = not visible
	if not self._external then
		self.Frame.Visible = visible
	end
	self:_changed()
end

function Section:Destroy()
	for _, component in ipairs(table.clone(self.Items)) do
		component:Destroy()
	end
	if self.Tab and self.Tab._removeSection then
		self.Tab:_removeSection(self)
	end
	if not self._external and self.Frame then
		self.Frame:Destroy()
		self.Frame = nil
	end
end

return Components
