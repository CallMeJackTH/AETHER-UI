--[[
	Sidebar.lua
	Navigation rail: section headers, icon + label items, animated active
	indicator, hover/press feedback and a compact (icon-only) mode used on
	narrow screens. Positions are computed manually so the indicator never
	depends on layout timing.

	Items are grouped into sections. Sections are ordered by the smallest
	`order` of their items, items by `order`, so tabs created later can still
	land between built-in groups.

	Sidebar.new(ctx, parent)
	  :AddHeader(text)                         -- declares a (possibly empty) section
	  :AddItem(id, text, iconName, section, order)
	  :RemoveItem(id)
	  :SetActive(id, instant)
	  :SetCompact(bool, instant)
	  :CreateFooter(height) -> Frame           -- docked at the bottom
	  :GetWidth()
	  :Destroy()
	  .Clicked        -> Signal(id)
	  .CompactChanged -> Signal(bool)
]]

local Sidebar = {}
Sidebar.__index = Sidebar

function Sidebar.new(ctx, parent)
	local self = setmetatable({}, Sidebar)
	local Utils = ctx.Utils
	local theme = ctx.Theme
	local colors = theme.Colors

	self.ctx = ctx
	self.Maid = Utils.Maid.new()
	self.Clicked = Utils.Signal.new()
	self.CompactChanged = Utils.Signal.new()
	self.Compact = false
	self.ActiveId = nil
	self._items = {}
	self._sections = {}
	self._sectionCount = 0
	self._counter = 0
	self._footerHeight = 0

	self.Frame = Utils.Create("Frame", {
		Name = "Sidebar",
		Size = UDim2.new(0, theme.Layout.SidebarWidth, 1, 0),
		BackgroundColor3 = colors.Surface,
		BackgroundTransparency = theme.Transparency.Sidebar,
		BorderSizePixel = 0,
		ClipsDescendants = true,
		ZIndex = 2,
		Parent = parent,
	})

	Utils.Create("Frame", {
		Name = "Divider",
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, 0, 0, 0),
		Size = UDim2.new(0, 1, 1, 0),
		BackgroundColor3 = colors.Border,
		BackgroundTransparency = 0.4,
		BorderSizePixel = 0,
		ZIndex = 3,
		Parent = self.Frame,
	})

	self.Scroll = Utils.Create("ScrollingFrame", {
		Name = "Items",
		Size = UDim2.new(1, -1, 1, 0),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ScrollBarThickness = 0,
		ScrollingDirection = Enum.ScrollingDirection.Y,
		CanvasSize = UDim2.new(),
		Parent = self.Frame,
	})

	self.Indicator = Utils.Create("Frame", {
		Name = "Indicator",
		Size = UDim2.fromOffset(3, 16),
		Position = UDim2.fromOffset(0, 0),
		BackgroundColor3 = colors.Accent,
		BorderSizePixel = 0,
		Visible = false,
		ZIndex = 4,
		Parent = self.Scroll,
	})
	Utils.Corner(self.Indicator, 2)

	return self
end

function Sidebar:_itemHeight()
	local layout = self.ctx.Theme.Layout
	return self.ctx.Touch and layout.SidebarItemTouch or layout.SidebarItem
end

function Sidebar:_section(name)
	local section = self._sections[name]
	if section then
		return section
	end

	local ctx = self.ctx
	local theme = ctx.Theme
	self._sectionCount = self._sectionCount + 1
	section = { Name = name, Items = {}, Index = self._sectionCount }

	if name ~= "" then
		section.Header = ctx.Utils.Text(theme, self.Scroll, {
			Name = "Header_" .. name,
			Text = string.upper(name),
			Font = theme.Fonts.Bold,
			TextSize = theme.Sizes.Tiny,
			TextColor3 = theme.Colors.Subtle,
			TextTransparency = self.Compact and 1 or 0,
			Size = UDim2.new(1, -28, 0, 16),
			Visible = false,
		})
	end

	self._sections[name] = section
	return section
end

function Sidebar:AddHeader(text)
	local section = self:_section(text)
	return section.Header
end

function Sidebar:AddItem(id, text, iconName, section, order)
	assert(not self._items[id], "[AetherUI] Sidebar item already exists: " .. tostring(id))

	local ctx = self.ctx
	local Utils = ctx.Utils
	local theme = ctx.Theme
	local colors = theme.Colors

	self._counter = self._counter + 1
	local sectionEntry = self:_section(section or "")

	local button = Utils.Create("TextButton", {
		Name = "Item_" .. id,
		Text = "",
		AutoButtonColor = false,
		BackgroundColor3 = colors.Hover,
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		Size = UDim2.new(1, -16, 0, self:_itemHeight()),
		Parent = self.Scroll,
	})
	Utils.Corner(button, theme.Layout.RadiusControl)

	local icon = Utils.Icon(Utils.HasIcon(iconName) and iconName or "components", button, colors.Muted, {
		Size = UDim2.fromOffset(16, 16),
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.new(0, 20, 0.5, 0),
	})

	local label = Utils.Text(theme, button, {
		Name = "Label",
		Text = text,
		Font = theme.Fonts.Medium,
		TextSize = theme.Sizes.Body,
		TextColor3 = colors.Muted,
		TextTruncate = Enum.TextTruncate.AtEnd,
		TextTransparency = self.Compact and 1 or 0,
		Position = UDim2.new(0, 40, 0, 0),
		Size = UDim2.new(1, -48, 1, 0),
	})

	local item = {
		Id = id,
		Text = text,
		Order = order or self._counter,
		Section = sectionEntry,
		Button = button,
		Instance = button,
		Label = label,
		Icon = icon,
		Hovering = false,
	}

	Utils.BindInteract(button, self.Maid, {
		Hover = function(hovering)
			item.Hovering = hovering
			if self.ActiveId ~= id then
				ctx.Animation:SidebarItem(item, hovering and "Hover" or "Idle")
			end
		end,
		Press = function(pressed)
			if self.ActiveId ~= id then
				ctx.Animation:SidebarItem(item, pressed and "Pressed" or (item.Hovering and "Hover" or "Idle"))
			end
		end,
	})

	item.Connection = button.Activated:Connect(function()
		self.Clicked:Fire(id)
	end)
	self.Maid:Give(item.Connection)

	-- In compact mode the label is hidden, so surface it as a tooltip.
	if ctx.Overlay then
		item.Tooltip = ctx.Overlay:AttachTooltip(button, function()
			return self.Compact and text or nil
		end, 0.3)
		self.Maid:Give(item.Tooltip)
	end

	table.insert(sectionEntry.Items, item)
	self._items[id] = item
	self:_layout(true)
	return item
end

function Sidebar:RemoveItem(id)
	local item = self._items[id]
	if not item then
		return
	end

	local section = item.Section
	local index = table.find(section.Items, item)
	if index then
		table.remove(section.Items, index)
	end
	self._items[id] = nil

	if item.Connection then
		item.Connection:Disconnect()
	end
	if item.Tooltip then
		item.Tooltip()
	end
	self.ctx.Animation:Cancel(item.Button)
	item.Button:Destroy()

	if self.ActiveId == id then
		self.ActiveId = nil
		self.Indicator.Visible = false
	end
	self:_layout(true)
end

function Sidebar:_layout(instant)
	local animation = self.ctx.Animation
	local itemHeight = self:_itemHeight()
	local headerHeight = self.Compact and 10 or 26
	local y = 8

	local sections = {}
	for _, section in pairs(self._sections) do
		local rank = math.huge
		for _, item in ipairs(section.Items) do
			rank = math.min(rank, item.Order)
		end
		section.Rank = rank
		table.insert(sections, section)
	end
	table.sort(sections, function(a, b)
		if a.Rank ~= b.Rank then
			return a.Rank < b.Rank
		end
		return a.Index < b.Index
	end)

	for _, section in ipairs(sections) do
		local populated = #section.Items > 0
		if section.Header then
			section.Header.Visible = populated
		end

		if populated then
			if section.Header then
				section.Header.Position = UDim2.fromOffset(14, y + (self.Compact and 0 or 6))
				y = y + headerHeight
			end

			table.sort(section.Items, function(a, b)
				if a.Order ~= b.Order then
					return a.Order < b.Order
				end
				return a.Id < b.Id
			end)

			for _, item in ipairs(section.Items) do
				item.Y = y
				item.Height = itemHeight
				item.Button.Size = UDim2.new(1, -16, 0, itemHeight)
				local position = UDim2.fromOffset(8, y)
				if instant then
					animation:Tween(item.Button, { Position = position }, 0)
				else
					animation:Play(item.Button, "Indicator", { Position = position })
				end
				y = y + itemHeight + 4
			end
		end
	end

	self.Scroll.CanvasSize = UDim2.fromOffset(0, y + 8)

	local active = self.ActiveId and self._items[self.ActiveId]
	if active then
		self:_moveIndicator(active, instant)
	end
end

function Sidebar:_moveIndicator(item, instant)
	local animation = self.ctx.Animation
	local y = item.Y + (item.Height - 16) / 2
	self.Indicator.Visible = true
	if instant then
		animation:Tween(self.Indicator, { Position = UDim2.fromOffset(0, y) }, 0)
	else
		animation:SidebarIndicator(self.Indicator, y)
	end
end

function Sidebar:SetActive(id, instant)
	local item = self._items[id]
	if not item or self.ActiveId == id then
		return
	end

	local animation = self.ctx.Animation
	local previous = self._items[self.ActiveId]
	self.ActiveId = id

	if previous then
		animation:SidebarItem(previous, previous.Hovering and "Hover" or "Idle")
	end

	if instant then
		local colors = self.ctx.Theme.Colors
		animation:Tween(item.Button, { BackgroundColor3 = colors.Accent, BackgroundTransparency = 0.88 }, 0)
		animation:Tween(item.Label, { TextColor3 = colors.Text }, 0)
		item.Icon:SetColor(colors.Accent)
	else
		animation:SidebarItem(item, "Active")
	end

	self:_moveIndicator(item, instant)
end

function Sidebar:SetCompact(compact, instant)
	compact = compact and true or false
	if self.Compact == compact then
		return
	end
	self.Compact = compact

	local animation = self.ctx.Animation
	local width = self:GetWidth()
	local size = UDim2.new(0, width, 1, 0)

	if instant then
		animation:Tween(self.Frame, { Size = size }, 0)
	else
		animation:Play(self.Frame, "Indicator", { Size = size })
	end

	local goal = { TextTransparency = compact and 1 or 0 }
	local function fade(instance)
		if instant then
			animation:Tween(instance, goal, 0)
		else
			animation:Play(instance, "Hover", goal)
		end
	end

	for _, section in pairs(self._sections) do
		if section.Header then
			fade(section.Header)
		end
		for _, item in ipairs(section.Items) do
			fade(item.Label)
		end
	end

	self:_layout(instant)
	self.CompactChanged:Fire(compact)
end

function Sidebar:CreateFooter(height)
	local Utils = self.ctx.Utils
	local colors = self.ctx.Theme.Colors

	if self.Footer then
		self.Footer:Destroy()
	end

	self._footerHeight = height
	self.Scroll.Size = UDim2.new(1, -1, 1, -height)

	self.Footer = Utils.Create("Frame", {
		Name = "Footer",
		AnchorPoint = Vector2.new(0, 1),
		Position = UDim2.new(0, 0, 1, 0),
		Size = UDim2.new(1, -1, 0, height),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ZIndex = 3,
		Parent = self.Frame,
	})

	Utils.Create("Frame", {
		Name = "Line",
		Size = UDim2.new(1, -16, 0, 1),
		Position = UDim2.fromOffset(8, 0),
		BackgroundColor3 = colors.Border,
		BackgroundTransparency = 0.5,
		BorderSizePixel = 0,
		Parent = self.Footer,
	})

	return self.Footer
end

function Sidebar:GetWidth()
	local layout = self.ctx.Theme.Layout
	return self.Compact and layout.SidebarCompactWidth or layout.SidebarWidth
end

function Sidebar:Destroy()
	self.Maid:Destroy()
	self.Clicked:Destroy()
	self.CompactChanged:Destroy()
	if self.Frame then
		self.Frame:Destroy()
		self.Frame = nil
	end
end

return Sidebar
