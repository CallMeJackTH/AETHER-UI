--[[
	Window.lua
	Window and Tab classes.

	Window.new(ctx, options)
	  options: Title, Size (Vector2 | UDim2), Version, Position (Vector2 centre),
	           ToggleKey (Enum.KeyCode, default RightShift), ConfirmClose (default true),
	           Pages (nil/true = all built-in pages, false = none, or { Dashboard = false, ... })

	Window
	  :CreateTab({ Name, Icon, Section, Description, Order }) -> Tab
	  :GetTab(name) / :SelectTab(tabOrName, instant)
	  :Minimize() :Restore() :Toggle() :Close(force) :Destroy()
	  :SetTitle(text) :SetStatus(text, kind) :SetToggleKey(keyCode) :SetSize(vector2)
	  :SetTransparency(value) :SetBlur(bool) :Search(query) :Notify(config)
	  :IsVisible()
	  .OnClosed / .OnMinimized / .OnRestored / .OnTabChanged / .OnDestroyed   Signals

	Tab
	  :CreateSection(name) -> Section (see Components.lua)
	  :Select() :SetFilter(query) :Destroy()
]]

local UserInputService = game:GetService("UserInputService")
local Lighting = game:GetService("Lighting")

local Window = {}
Window.__index = Window

local Tab = {}
Tab.__index = Tab
Window.Tab = Tab

local function slug(text)
	return (string.lower(tostring(text)):gsub("[^%w]+", "_"))
end

----------------------------------------------------------------------
-- Tab
----------------------------------------------------------------------

function Tab.new(window, config)
	local ctx = window.ctx
	local Utils, theme = ctx.Utils, ctx.Theme
	local colors, fonts, sizes, layout = theme.Colors, theme.Fonts, theme.Sizes, theme.Layout

	local self = setmetatable({}, Tab)
	self.Window = window
	self.ctx = ctx
	self.Name = tostring(config.Name or "Tab")
	self.Description = config.Description
	self.Sections = {}
	self.Query = ""
	self._order = 0
	self.Maid = Utils.Maid.new()

	local id = slug(self.Name)
	local base, suffix = id, 1
	while window.TabsById[id] do
		suffix = suffix + 1
		id = base .. "_" .. suffix
	end
	self.Id = id

	self.Page = Utils.Create("CanvasGroup", {
		Name = "Page_" .. id,
		Size = UDim2.new(1, 0, 1, 0),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		GroupTransparency = 0,
		Visible = false,
		Parent = window.Content,
	})

	self.Scroll = Utils.Create("ScrollingFrame", {
		Name = "Scroll",
		Size = UDim2.new(1, 0, 1, 0),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ScrollBarThickness = ctx.Touch and 0 or 3,
		ScrollBarImageColor3 = colors.Border,
		ScrollingDirection = Enum.ScrollingDirection.Y,
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		CanvasSize = UDim2.new(),
		ElasticBehavior = Enum.ElasticBehavior.Never,
		Parent = self.Page,
	})
	Utils.Padding(self.Scroll, layout.PagePadding, layout.PagePadding, layout.PagePadding, layout.PagePadding)
	Utils.List(self.Scroll, layout.SectionGap)

	local header = Utils.Create("Frame", {
		Name = "Header",
		Size = UDim2.new(1, 0, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		LayoutOrder = 0,
		Parent = self.Scroll,
	})
	Utils.List(header, 2)
	Utils.Text(theme, header, {
		Name = "Title",
		Text = self.Name,
		Font = fonts.Bold,
		TextSize = sizes.Heading,
		Size = UDim2.new(1, 0, 0, 22),
		LayoutOrder = 1,
	})
	if self.Description and self.Description ~= "" then
		Utils.Text(theme, header, {
			Name = "Subtitle",
			Text = tostring(self.Description),
			Font = fonts.Regular,
			TextSize = sizes.Small,
			TextColor3 = colors.Muted,
			TextWrapped = true,
			TextYAlignment = Enum.TextYAlignment.Top,
			AutomaticSize = Enum.AutomaticSize.Y,
			Size = UDim2.new(1, 0, 0, 16),
			LayoutOrder = 2,
		})
	end

	-- Empty state
	self.Empty = Utils.Create("Frame", {
		Name = "EmptyState",
		Size = UDim2.new(1, 0, 0, 170),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		Visible = false,
		LayoutOrder = 100000,
		Parent = self.Scroll,
	})
	local badge = Utils.Create("Frame", {
		Name = "Badge",
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 24),
		Size = UDim2.fromOffset(46, 46),
		BackgroundColor3 = colors.Secondary,
		BorderSizePixel = 0,
		Parent = self.Empty,
	})
	Utils.Corner(badge, 23)
	Utils.Stroke(badge, colors.Border, 1, 0.3)
	Utils.Icon("search", badge, colors.Subtle, {
		Size = UDim2.fromOffset(20, 20),
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.new(0.5, 0, 0.5, 0),
	})
	self.EmptyTitle = Utils.Text(theme, self.Empty, {
		Name = "Title",
		Font = fonts.SemiBold,
		TextSize = sizes.Body,
		TextXAlignment = Enum.TextXAlignment.Center,
		Position = UDim2.fromOffset(0, 82),
		Size = UDim2.new(1, 0, 0, 20),
	})
	self.EmptyText = Utils.Text(theme, self.Empty, {
		Name = "Text",
		Font = fonts.Regular,
		TextSize = sizes.Small,
		TextColor3 = colors.Muted,
		TextWrapped = true,
		TextXAlignment = Enum.TextXAlignment.Center,
		TextYAlignment = Enum.TextYAlignment.Top,
		Position = UDim2.fromOffset(20, 104),
		Size = UDim2.new(1, -40, 0, 36),
	})

	self:_updateEmpty()
	return self
end

function Tab:CreateSection(name, options)
	options = options or {}
	self._order = self._order + 1
	local section = self.ctx.Components.Section.new(self.ctx, self, name, {
		LayoutOrder = self._order,
		ParentFrame = self.Scroll,
	})
	table.insert(self.Sections, section)
	if options.Description then
		-- Optional one-line caption under the section header.
		self.ctx.Components.Types.Label.new(self.ctx, section.Container, {
			Text = options.Description,
		}).Root.LayoutOrder = 1
	end
	self:_updateEmpty()
	return section
end

function Tab:_removeSection(section)
	local index = table.find(self.Sections, section)
	if index then
		table.remove(self.Sections, index)
	end
	self:_updateEmpty()
end

function Tab:_sectionChanged()
	self:_updateEmpty()
end

function Tab:_updateEmpty()
	local visibleSections = 0
	for _, section in ipairs(self.Sections) do
		if section.Frame and section.Frame.Visible then
			visibleSections = visibleSections + 1
		end
	end

	local searching = self.Query ~= ""
	if visibleSections > 0 then
		self.Empty.Visible = false
	elseif searching then
		self.EmptyTitle.Text = "No results"
		self.EmptyText.Text = 'Nothing matches "' .. self.Query .. '" on this page.'
		self.Empty.Visible = true
	else
		self.EmptyTitle.Text = "Nothing here yet"
		self.EmptyText.Text = "Sections and components added to this tab will show up here."
		self.Empty.Visible = true
	end
end

function Tab:SetFilter(query)
	query = string.lower(self.ctx.Utils.Trim(query or ""))
	self.Query = query
	for _, section in ipairs(self.Sections) do
		section:ApplyFilter(query)
	end
	self:_updateEmpty()
end

function Tab:Select(instant)
	self.Window:SelectTab(self, instant)
end

function Tab:Destroy()
	self.Window:_removeTab(self)
end

----------------------------------------------------------------------
-- Window
----------------------------------------------------------------------

local function toVector2(size, fallback)
	if typeof(size) == "Vector2" then
		return size
	elseif typeof(size) == "UDim2" then
		return Vector2.new(size.X.Offset, size.Y.Offset)
	end
	return fallback
end

function Window.new(ctx, options)
	options = options or {}
	local Utils, theme = ctx.Utils, ctx.Theme
	local colors, fonts, sizes, layout = theme.Colors, theme.Fonts, theme.Sizes, theme.Layout

	local self = setmetatable({}, Window)
	self.ctx = ctx
	self.Maid = Utils.Maid.new()
	self.Title = tostring(options.Title or "AETHER")
	self.Version = tostring(options.Version or ctx.Library.Version)
	self.RequestedSize = toVector2(options.Size, layout.WindowSize)
	self.ToggleKey = options.ToggleKey or Enum.KeyCode.RightShift
	self.ConfirmClose = options.ConfirmClose ~= false
	self.Tabs = {}
	self.TabsById = {}
	self.ActiveTab = nil
	self.Query = ""
	self.Minimized = false
	self.Destroyed = false
	self.Closing = false
	self._userTabs = 0
	self._noDrag = {}
	self.DefaultSection = "MODULES"

	self.OnClosed = Utils.Signal.new()
	self.OnMinimized = Utils.Signal.new()
	self.OnRestored = Utils.Signal.new()
	self.OnTabChanged = Utils.Signal.new()
	self.OnDestroyed = Utils.Signal.new()

	local gui = ctx.Gui
	local viewport = Utils.GetViewport(gui)

	----------------------------------------------------------------
	-- Frames
	----------------------------------------------------------------
	self.Center = options.Position or Vector2.new(viewport.X / 2, viewport.Y / 2)
	local size = Vector2.new(self.RequestedSize.X, self.RequestedSize.Y)

	self.Root = Utils.Create("Frame", {
		Name = "Window",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromOffset(self.Center.X, self.Center.Y),
		Size = UDim2.fromOffset(size.X, size.Y),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ZIndex = theme.ZIndex.Window,
		Visible = false,
		Parent = gui,
	})
	self.Scale = Utils.Create("UIScale", { Scale = 1, Parent = self.Root })
	self.Shadow = Utils.Shadow(self.Root, layout.RadiusWindow, 22, 8, 0.05)

	self.Canvas = Utils.Create("CanvasGroup", {
		Name = "Canvas",
		Size = UDim2.new(1, 0, 1, 0),
		BackgroundColor3 = colors.Background,
		BackgroundTransparency = theme.Transparency.Window,
		BorderSizePixel = 0,
		ZIndex = 2,
		Parent = self.Root,
	})
	Utils.Corner(self.Canvas, layout.RadiusWindow)
	self.Stroke = Utils.Stroke(self.Canvas, colors.Border, 1, theme.Transparency.Stroke)

	-- Glass sheen
	local sheen = Utils.Create("Frame", {
		Name = "Sheen",
		Size = UDim2.new(1, 0, 0, 140),
		BackgroundColor3 = colors.Text,
		BackgroundTransparency = 0,
		BorderSizePixel = 0,
		ZIndex = 1,
		Parent = self.Canvas,
	})
	Utils.Create("UIGradient", {
		Transparency = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 0.95),
			NumberSequenceKeypoint.new(1, 1),
		}),
		Rotation = 90,
		Parent = sheen,
	})

	self.Parts = {
		Root = self.Root,
		Canvas = self.Canvas,
		Stroke = self.Stroke,
		Scale = self.Scale,
		Shadow = self.Shadow,
		Position = self.Root.Position,
		Transparency = theme.Transparency.Window,
	}

	----------------------------------------------------------------
	-- Topbar
	----------------------------------------------------------------
	local topbarHeight = layout.TopbarHeight
	self.Topbar = Utils.Create("Frame", {
		Name = "Topbar",
		Size = UDim2.new(1, 0, 0, topbarHeight),
		BackgroundColor3 = colors.Surface,
		BackgroundTransparency = theme.Transparency.Topbar,
		BorderSizePixel = 0,
		ZIndex = 4,
		Parent = self.Canvas,
	})
	Utils.Create("Frame", {
		Name = "Line",
		AnchorPoint = Vector2.new(0, 1),
		Position = UDim2.new(0, 0, 1, 0),
		Size = UDim2.new(1, 0, 0, 1),
		BackgroundColor3 = colors.Border,
		BackgroundTransparency = 0.4,
		BorderSizePixel = 0,
		Parent = self.Topbar,
	})

	local logo = Utils.Create("Frame", {
		Name = "Logo",
		Position = UDim2.fromOffset(12, (topbarHeight - 26) / 2),
		Size = UDim2.fromOffset(26, 26),
		BackgroundColor3 = colors.Accent,
		BackgroundTransparency = 0.85,
		BorderSizePixel = 0,
		Parent = self.Topbar,
	})
	Utils.Corner(logo, 7)
	Utils.Stroke(logo, colors.Accent, 1, 0.7)
	Utils.Icon("logo", logo, colors.Accent, {
		Size = UDim2.fromOffset(16, 16),
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.new(0.5, 0, 0.5, 0),
	})

	self.TitleLabel = Utils.Text(theme, self.Topbar, {
		Name = "Title",
		Text = self.Title,
		Font = fonts.SemiBold,
		TextSize = sizes.Title,
		TextTruncate = Enum.TextTruncate.AtEnd,
		AnchorPoint = Vector2.new(0, 0.5),
		Position = UDim2.new(0, 46, 0.5, 0),
		Size = UDim2.fromOffset(120, 18),
	})

	self.VersionBadge = Utils.Create("Frame", {
		Name = "Version",
		AnchorPoint = Vector2.new(0, 0.5),
		Position = UDim2.new(0, 170, 0.5, 0),
		Size = UDim2.fromOffset(40, 16),
		BackgroundColor3 = colors.Elevated,
		BorderSizePixel = 0,
		Parent = self.Topbar,
	})
	Utils.Corner(self.VersionBadge, 8)
	Utils.Stroke(self.VersionBadge, colors.Border, 1, 0.3)
	self.VersionLabel = Utils.Text(theme, self.VersionBadge, {
		Name = "Text",
		Text = "v" .. self.Version:gsub("^v", ""),
		Font = fonts.Mono,
		TextSize = sizes.Tiny,
		TextColor3 = colors.Muted,
		TextXAlignment = Enum.TextXAlignment.Center,
		Size = UDim2.new(1, 0, 1, 0),
	})

	local function windowButton(name, iconName, order, danger)
		local button = Utils.Create("TextButton", {
			Name = name,
			Text = "",
			AutoButtonColor = false,
			AnchorPoint = Vector2.new(1, 0.5),
			Position = UDim2.new(1, -(8 + (order - 1) * 32), 0.5, 0),
			Size = UDim2.fromOffset(28, 28),
			BackgroundColor3 = danger and colors.Error or colors.Hover,
			BackgroundTransparency = 1,
			BorderSizePixel = 0,
			Parent = self.Topbar,
		})
		Utils.Corner(button, layout.RadiusControl)
		local icon = Utils.Icon(iconName, button, colors.Muted, {
			Size = UDim2.fromOffset(13, 13),
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.new(0.5, 0, 0.5, 0),
		})
		Utils.BindInteract(button, self.Maid, {
			Hover = function(hover)
				ctx.Animation:Play(button, "Hover", {
					BackgroundTransparency = hover and (danger and 0.8 or 0.4) or 1,
				})
				ctx.Animation:IconColor(icon, hover and (danger and colors.Error or colors.Text) or colors.Muted)
			end,
		})
		table.insert(self._noDrag, button)
		return button
	end

	self.CloseButton = windowButton("Close", "close", 1, true)
	self.MinimizeButton = windowButton("Minimize", "minimize", 2, false)
	ctx.Overlay:AttachTooltip(self.CloseButton, "Close", 0.5)
	ctx.Overlay:AttachTooltip(self.MinimizeButton, "Minimize", 0.5)

	self.Maid:Give(self.CloseButton.Activated:Connect(function()
		self:Close()
	end))
	self.Maid:Give(self.MinimizeButton.Activated:Connect(function()
		self:Minimize()
	end))

	self.SearchBar = ctx.Components.Types.SearchBar.new(ctx, self.Topbar, {
		Inline = true,
		Placeholder = "Search...",
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(1, -78, 0.5, 0),
		Size = UDim2.fromOffset(170, 26),
		Callback = function(query)
			self:Search(query)
		end,
	})
	table.insert(self._noDrag, self.SearchBar.Root)

	----------------------------------------------------------------
	-- Body: sidebar + content
	----------------------------------------------------------------
	local footerHeight = layout.FooterHeight
	self.Body = Utils.Create("Frame", {
		Name = "Body",
		Position = UDim2.fromOffset(0, topbarHeight),
		Size = UDim2.new(1, 0, 1, -(topbarHeight + footerHeight)),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ClipsDescendants = true,
		ZIndex = 2,
		Parent = self.Canvas,
	})

	self.Sidebar = ctx.Sidebar.new(ctx, self.Body)
	self.Maid:Give(self.Sidebar.Clicked:Connect(function(id)
		self:SelectTab(id)
	end))

	self.Content = Utils.Create("Frame", {
		Name = "Content",
		Position = UDim2.fromOffset(layout.SidebarWidth, 0),
		Size = UDim2.new(1, -layout.SidebarWidth, 1, 0),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ClipsDescendants = true,
		Parent = self.Body,
	})

	self:_buildProfile()

	----------------------------------------------------------------
	-- Footer
	----------------------------------------------------------------
	self.Footer = Utils.Create("Frame", {
		Name = "Footer",
		AnchorPoint = Vector2.new(0, 1),
		Position = UDim2.new(0, 0, 1, 0),
		Size = UDim2.new(1, 0, 0, footerHeight),
		BackgroundColor3 = colors.Surface,
		BackgroundTransparency = theme.Transparency.Topbar,
		BorderSizePixel = 0,
		ZIndex = 4,
		Parent = self.Canvas,
	})
	Utils.Create("Frame", {
		Name = "Line",
		Size = UDim2.new(1, 0, 0, 1),
		BackgroundColor3 = colors.Border,
		BackgroundTransparency = 0.4,
		BorderSizePixel = 0,
		Parent = self.Footer,
	})
	self.StatusDot = Utils.Create("Frame", {
		Name = "Dot",
		AnchorPoint = Vector2.new(0, 0.5),
		Position = UDim2.new(0, 12, 0.5, 0),
		Size = UDim2.fromOffset(6, 6),
		BackgroundColor3 = colors.Success,
		BorderSizePixel = 0,
		Parent = self.Footer,
	})
	Utils.Corner(self.StatusDot, 3)
	self.StatusText = Utils.Text(theme, self.Footer, {
		Name = "Status",
		Text = "Ready",
		Font = fonts.Medium,
		TextSize = sizes.Caption,
		TextColor3 = colors.Muted,
		TextTruncate = Enum.TextTruncate.AtEnd,
		Position = UDim2.fromOffset(26, 0),
		Size = UDim2.new(0.55, -26, 1, 0),
	})
	self.MetricsLabel = Utils.Text(theme, self.Footer, {
		Name = "Metrics",
		Font = fonts.Mono,
		TextSize = sizes.Tiny,
		TextColor3 = colors.Subtle,
		TextXAlignment = Enum.TextXAlignment.Right,
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -12, 0, 0),
		Size = UDim2.new(0.45, -12, 1, 0),
	})

	local function paintMetrics(metrics)
		self.MetricsLabel.Text = string.format("%d FPS  -  %d ms", metrics.FPS, metrics.Ping)
	end
	paintMetrics(ctx.Metrics)
	self.Maid:Give(ctx.MetricsChanged:Connect(function(metrics)
		if not self.Destroyed then
			paintMetrics(metrics)
		end
	end))

	----------------------------------------------------------------
	-- Floating reopen button
	----------------------------------------------------------------
	self:_buildFloating()

	----------------------------------------------------------------
	-- Interaction
	----------------------------------------------------------------
	self:_bindDrag()

	self.Maid:Give(UserInputService.InputBegan:Connect(function(input, processed)
		if processed or ctx.State.CapturingKey or self.Destroyed or self.Closing then
			return
		end
		if input.KeyCode == self.ToggleKey and UserInputService:GetFocusedTextBox() == nil then
			self:Toggle()
		end
	end))

	self.Maid:Give(gui:GetPropertyChangedSignal("AbsoluteSize"):Connect(function()
		self:_fit()
	end))
	self.Maid:Give(self.Sidebar.CompactChanged:Connect(function()
		self:_layoutBody(false)
		self:_layoutTopbar()
	end))

	self:_fit(true)

	self.Parts.Position = self.Root.Position
	self.Root.Visible = true
	ctx.Animation:WindowOpen(self.Parts)

	if ctx.Pages and options.Pages ~= false then
		ctx.Pages.Build(self, options.Pages)
	end

	return self
end

----------------------------------------------------------------------
-- Sidebar profile card
----------------------------------------------------------------------

function Window:_buildProfile()
	local ctx = self.ctx
	local Utils, theme = ctx.Utils, ctx.Theme
	local colors, fonts, sizes = theme.Colors, theme.Fonts, theme.Sizes

	local player = game:GetService("Players").LocalPlayer
	local name = player and player.DisplayName or "Guest"
	local footer = self.Sidebar:CreateFooter(52)

	local avatar = Utils.Create("Frame", {
		Name = "Avatar",
		AnchorPoint = Vector2.new(0, 0.5),
		Position = UDim2.new(0, 14, 0.5, 2),
		Size = UDim2.fromOffset(28, 28),
		BackgroundColor3 = colors.Accent,
		BackgroundTransparency = 0.82,
		BorderSizePixel = 0,
		Parent = footer,
	})
	Utils.Corner(avatar, 14)
	Utils.Stroke(avatar, colors.Accent, 1, 0.65)
	Utils.Text(theme, avatar, {
		Name = "Initial",
		Text = string.upper(string.sub(name, 1, 1)),
		Font = fonts.Bold,
		TextSize = sizes.Body,
		TextColor3 = colors.Accent,
		TextXAlignment = Enum.TextXAlignment.Center,
		Size = UDim2.new(1, 0, 1, 0),
	})

	local nameLabel = Utils.Text(theme, footer, {
		Name = "Name",
		Text = name,
		Font = fonts.SemiBold,
		TextSize = sizes.Small,
		TextTruncate = Enum.TextTruncate.AtEnd,
		Position = UDim2.fromOffset(50, 10),
		Size = UDim2.new(1, -58, 0, 16),
	})
	local roleLabel = Utils.Text(theme, footer, {
		Name = "Role",
		Text = "Session active",
		Font = fonts.Regular,
		TextSize = sizes.Tiny + 1,
		TextColor3 = colors.Muted,
		TextTruncate = Enum.TextTruncate.AtEnd,
		Position = UDim2.fromOffset(50, 27),
		Size = UDim2.new(1, -58, 0, 14),
	})

	self.Maid:Give(self.Sidebar.CompactChanged:Connect(function(compact)
		local goal = { TextTransparency = compact and 1 or 0 }
		ctx.Animation:Play(nameLabel, "Hover", goal)
		ctx.Animation:Play(roleLabel, "Hover", goal)
	end))
end

----------------------------------------------------------------------
-- Floating reopen button
----------------------------------------------------------------------

function Window:_buildFloating()
	local ctx = self.ctx
	local Utils, theme = ctx.Utils, ctx.Theme
	local colors, layout = theme.Colors, theme.Layout
	local diameter = ctx.Touch and layout.FloatingButtonTouch or layout.FloatingButton
	local viewport = Utils.GetViewport(ctx.Gui)

	self.FloatCenter = Vector2.new(diameter / 2 + 16, viewport.Y - diameter / 2 - 60)

	self.Floating = Utils.Create("CanvasGroup", {
		Name = "Reopen",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromOffset(self.FloatCenter.X, self.FloatCenter.Y),
		Size = UDim2.fromOffset(diameter, diameter),
		BackgroundColor3 = colors.Surface,
		BackgroundTransparency = 0.05,
		BorderSizePixel = 0,
		GroupTransparency = 1,
		Visible = false,
		ZIndex = theme.ZIndex.Floating,
		Parent = ctx.Gui,
	})
	Utils.Corner(self.Floating, diameter / 3)
	local stroke = Utils.Stroke(self.Floating, colors.Accent, 1.5, 0.35)
	self.FloatingScale = Utils.Create("UIScale", { Scale = 1, Parent = self.Floating })
	Utils.Icon("logo", self.Floating, colors.Accent, {
		Size = UDim2.fromOffset(diameter * 0.45, diameter * 0.45),
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.new(0.5, 0, 0.5, 0),
	})

	Utils.BindInteract(self.Floating, self.Maid, {
		Hover = function(hover)
			ctx.Animation:Play(stroke, "Hover", { Transparency = hover and 0 or 0.35 })
		end,
	})
	ctx.Overlay:AttachTooltip(self.Floating, function()
		return self.Minimized and ("Open " .. self.Title) or nil
	end, 0.5, "Right")

	local startPointer, startCenter, moved = nil, nil, 0
	Utils.BindDrag(self.Floating, self.Maid, {
		NoScrollLock = true,
		Began = function(input)
			startPointer = Utils.InputPosition(input)
			startCenter = self.FloatCenter
			moved = 0
		end,
		Changed = function(input)
			local delta = Utils.InputPosition(input) - startPointer
			moved = math.max(moved, delta.Magnitude)
			if moved > 6 then
				local vp = Utils.GetViewport(ctx.Gui)
				local half = diameter / 2
				self.FloatCenter = Vector2.new(
					Utils.Clamp(startCenter.X + delta.X, half, vp.X - half),
					Utils.Clamp(startCenter.Y + delta.Y, half, vp.Y - half)
				)
				ctx.Animation:Tween(self.Floating, { Position = UDim2.fromOffset(self.FloatCenter.X, self.FloatCenter.Y) }, 0)
			end
		end,
		Ended = function()
			if moved <= 6 and self.Minimized then
				self:Restore()
			end
		end,
	})
end

----------------------------------------------------------------------
-- Layout / responsiveness
----------------------------------------------------------------------

function Window:_layoutBody(instant)
	local animation = self.ctx.Animation
	local width = self.Sidebar:GetWidth()
	local goal = {
		Position = UDim2.fromOffset(width, 0),
		Size = UDim2.new(1, -width, 1, 0),
	}
	if instant then
		animation:Tween(self.Content, goal, 0)
	else
		animation:Play(self.Content, "Indicator", goal)
	end
end

function Window:_layoutTopbar()
	local Utils = self.ctx.Utils
	local theme = self.ctx.Theme
	local width = self.Size and self.Size.X or self.RequestedSize.X

	local showSearch = width >= 380
	local searchWidth = Utils.Clamp(math.floor(width * 0.28), 110, 200)
	self.SearchBar.Root.Visible = showSearch
	self.SearchBar.Root.Size = UDim2.fromOffset(searchWidth, 26)

	local rightReserve = 8 + 64 + 10 + (showSearch and (searchWidth + 8) or 0)
	local showVersion = width >= 440
	local available = width - 46 - rightReserve - (showVersion and 52 or 0)
	local textWidth = Utils.TextSize(self.Title, theme.Fonts.SemiBold, theme.Sizes.Title).X
	local titleWidth = math.max(40, math.min(textWidth + 4, available))

	self.TitleLabel.Size = UDim2.fromOffset(titleWidth, 18)
	self.VersionBadge.Visible = showVersion
	local versionWidth = Utils.TextSize(self.VersionLabel.Text, theme.Fonts.Mono, theme.Sizes.Tiny).X + 14
	self.VersionBadge.Size = UDim2.fromOffset(versionWidth, 16)
	self.VersionBadge.Position = UDim2.new(0, 46 + titleWidth + 8, 0.5, 0)
end

function Window:_clampCenter(center)
	local Utils = self.ctx.Utils
	local viewport = Utils.GetViewport(self.ctx.Gui)
	local size = self.Size
	local keep = 80
	return Vector2.new(
		Utils.Clamp(center.X, keep - size.X / 2, viewport.X - keep + size.X / 2),
		Utils.Clamp(center.Y, size.Y / 2, viewport.Y - self.ctx.Theme.Layout.TopbarHeight + size.Y / 2)
	)
end

function Window:_setCenter(center)
	self.Center = self:_clampCenter(center)
	local position = UDim2.fromOffset(self.Center.X, self.Center.Y)
	self.Parts.Position = position
	self.ctx.Animation:Tween(self.Root, { Position = position }, 0)
end

function Window:_fit(initial)
	if self.Destroyed then
		return
	end
	local Utils, layout = self.ctx.Utils, self.ctx.Theme.Layout
	local viewport = Utils.GetViewport(self.ctx.Gui)
	local margin = self.ctx.Touch and layout.ScreenMarginTouch or layout.ScreenMargin
	local minimum = layout.MinWindowSize

	local maxWidth = viewport.X - margin * 2
	local maxHeight = viewport.Y - margin * 2
	local width = Utils.Clamp(self.RequestedSize.X, math.min(minimum.X, maxWidth), maxWidth)
	local height = Utils.Clamp(self.RequestedSize.Y, math.min(minimum.Y, maxHeight), maxHeight)
	self.Size = Vector2.new(width, height)

	self.Root.Size = UDim2.fromOffset(width, height)
	self:_setCenter(self.Center)
	self.Sidebar:SetCompact(width < layout.CompactBreakpoint, initial)
	self:_layoutBody(true)
	self:_layoutTopbar()

	-- Keep the floating button on screen.
	local half = (self.ctx.Touch and layout.FloatingButtonTouch or layout.FloatingButton) / 2
	self.FloatCenter = Vector2.new(
		Utils.Clamp(self.FloatCenter.X, half, viewport.X - half),
		Utils.Clamp(self.FloatCenter.Y, half, viewport.Y - half)
	)
	self.Floating.Position = UDim2.fromOffset(self.FloatCenter.X, self.FloatCenter.Y)
end

function Window:SetSize(size)
	self.RequestedSize = toVector2(size, self.RequestedSize)
	self:_fit()
end

----------------------------------------------------------------------
-- Dragging
----------------------------------------------------------------------

function Window:_bindDrag()
	local ctx = self.ctx
	local Utils = ctx.Utils
	local startPointer, startCenter

	Utils.BindDrag(self.Topbar, self.Maid, {
		NoScrollLock = true,
		CanBegin = function(input)
			if self.Minimized or self.Closing then
				return false
			end
			local point = Utils.InputPosition(input)
			for _, gui in ipairs(self._noDrag) do
				if gui.Visible and Utils.IsPointInside(gui, point) then
					return false
				end
			end
			return true
		end,
		Began = function(input)
			startPointer = Utils.InputPosition(input)
			startCenter = self.Center
			ctx.Overlay:CloseAll()
			self:BringToFront()
			ctx.Animation:DragFeedback(self.Parts, true)
		end,
		Changed = function(input)
			self:_setCenter(startCenter + (Utils.InputPosition(input) - startPointer))
		end,
		Ended = function()
			ctx.Animation:DragFeedback(self.Parts, false)
		end,
	})
end

function Window:BringToFront()
	local zindex = self.ctx.Theme.ZIndex.Window
	self.ctx.Library._windowZ = (self.ctx.Library._windowZ or zindex) + 1
	self.Root.ZIndex = math.min(self.ctx.Library._windowZ, self.ctx.Theme.ZIndex.Floating - 1)
end

----------------------------------------------------------------------
-- Tabs
----------------------------------------------------------------------

function Window:CreateTab(config)
	if type(config) == "string" then
		config = { Name = config }
	end
	config = config or {}

	local tab = Tab.new(self, config)
	table.insert(self.Tabs, tab)
	self.TabsById[tab.Id] = tab

	local order = config.Order
	if not order then
		self._userTabs = self._userTabs + 1
		order = 1000 + self._userTabs
	end
	local section = config.Section
	if section == nil then
		section = self.DefaultSection
	elseif section == false then
		section = ""
	end

	self.Sidebar:AddItem(tab.Id, tab.Name, config.Icon or "components", section, order)

	if not self.ActiveTab then
		self:SelectTab(tab, true)
	end
	return tab
end

function Window:GetTab(name)
	if self.TabsById[name] then
		return self.TabsById[name]
	end
	for _, tab in ipairs(self.Tabs) do
		if tab.Name == name then
			return tab
		end
	end
	return nil
end

function Window:SelectTab(target, instant)
	local tab = type(target) == "string" and self:GetTab(target) or target
	if not tab or tab == self.ActiveTab or self.Destroyed then
		return
	end

	local ctx = self.ctx
	local previous = self.ActiveTab
	self.ActiveTab = tab
	ctx.Overlay:CloseAll()
	self.Sidebar:SetActive(tab.Id, instant)

	if instant or not previous then
		ctx.Animation:Tween(tab.Page, { GroupTransparency = 0, Position = UDim2.new() }, 0)
		tab.Page.Visible = true
		if previous then
			previous.Page.Visible = false
		end
	else
		local direction = (table.find(self.Tabs, tab) or 0) >= (table.find(self.Tabs, previous) or 0) and 1 or -1
		ctx.Animation:PageSwitch(previous.Page, tab.Page, direction)
	end

	tab:SetFilter(self.Query)
	self.OnTabChanged:Fire(tab)
end

function Window:_removeTab(tab)
	local index = table.find(self.Tabs, tab)
	if index then
		table.remove(self.Tabs, index)
	end
	self.TabsById[tab.Id] = nil
	self.Sidebar:RemoveItem(tab.Id)
	for _, section in ipairs(table.clone(tab.Sections)) do
		section:Destroy()
	end
	tab.Maid:Destroy()
	self.ctx.Animation:Cancel(tab.Page)
	tab.Page:Destroy()

	if self.ActiveTab == tab then
		self.ActiveTab = nil
		local fallback = self.Tabs[1]
		if fallback then
			self:SelectTab(fallback, true)
		end
	end
end

function Window:Search(query)
	self.Query = tostring(query or "")
	if self.ActiveTab then
		self.ActiveTab:SetFilter(self.Query)
	end
end

----------------------------------------------------------------------
-- Visibility
----------------------------------------------------------------------

function Window:IsVisible()
	return not self.Minimized and not self.Destroyed
end

function Window:Minimize()
	if self.Minimized or self.Closing or self.Destroyed then
		return
	end
	self.Minimized = true
	self.ctx.Overlay:CloseAll()
	self.ctx.Animation:WindowMinimize(self.Parts)
	self.ctx.Animation:Floating(self.Floating, self.FloatingScale, true)
	self.OnMinimized:Fire()
end

function Window:Restore()
	if not self.Minimized or self.Destroyed then
		return
	end
	self.Minimized = false
	self.ctx.Animation:Floating(self.Floating, self.FloatingScale, false)
	self.ctx.Animation:WindowRestore(self.Parts)
	self:BringToFront()
	self.OnRestored:Fire()
end

function Window:Toggle()
	if self.Minimized then
		self:Restore()
	else
		self:Minimize()
	end
end

function Window:Close(force)
	if self.Closing or self.Destroyed then
		return
	end

	if self.ConfirmClose and not force then
		self.ctx.Overlay:Dialog({
			Title = "Close " .. self.Title .. "?",
			Content = "The window will be destroyed. Use minimize to keep it available from the floating button.",
			Buttons = {
				{ Text = "Cancel", Style = "Default" },
				{
					Text = "Close",
					Style = "Danger",
					Callback = function()
						self:Close(true)
					end,
				},
			},
		})
		return
	end

	self.Closing = true
	self.ctx.Overlay:CloseAll()
	self.OnClosed:Fire()
	self.ctx.Animation:WindowClose(self.Parts, function()
		self:Destroy()
	end)
	if self.Minimized then
		self.Floating.Visible = false
	end
end

----------------------------------------------------------------------
-- Misc
----------------------------------------------------------------------

function Window:SetTitle(text)
	self.Title = tostring(text)
	self.TitleLabel.Text = self.Title
	self:_layoutTopbar()
end

function Window:SetStatus(text, kind)
	local colors = self.ctx.Theme.Colors
	self.StatusText.Text = tostring(text)
	self.ctx.Animation:Play(self.StatusDot, "Hover", { BackgroundColor3 = colors[kind or "Success"] or colors.Success })
end

function Window:SetToggleKey(key)
	if typeof(key) == "EnumItem" and key.EnumType == Enum.KeyCode then
		self.ToggleKey = key
	end
end

function Window:SetTransparency(value)
	value = self.ctx.Utils.Clamp(value, 0, 0.9)
	self.Parts.Transparency = value
	self.ctx.Animation:Play(self.Canvas, "Hover", { BackgroundTransparency = value })
end

function Window:SetBlur(enabled)
	if enabled then
		if not self._blur then
			local blur = Instance.new("BlurEffect")
			blur.Name = "AetherBlur"
			blur.Size = 0
			blur.Parent = Lighting
			self._blur = blur
		end
		self.ctx.Animation:Play(self._blur, "Fade", { Size = 14 })
	elseif self._blur then
		local blur = self._blur
		self._blur = nil
		self.ctx.Animation:Play(blur, "Fade", { Size = 0 }, function()
			blur:Destroy()
		end)
	end
end

function Window:Notify(config)
	return self.ctx.Notifications:Notify(config)
end

function Window:Destroy()
	if self.Destroyed then
		return
	end
	self.Destroyed = true

	local ctx = self.ctx
	ctx.Overlay:CloseAll()

	for _, tab in ipairs(table.clone(self.Tabs)) do
		for _, section in ipairs(table.clone(tab.Sections)) do
			section:Destroy()
		end
		tab.Maid:Destroy()
	end
	self.Tabs = {}
	self.TabsById = {}

	if self._blur then
		self._blur:Destroy()
		self._blur = nil
	end

	self.Maid:Destroy()
	self.SearchBar.Maid:Destroy()
	self.Sidebar:Destroy()

	ctx.Animation:Cancel(self.Root)
	ctx.Animation:Cancel(self.Canvas)
	ctx.Animation:Cancel(self.Floating)
	self.Floating:Destroy()
	self.Root:Destroy()

	self.OnDestroyed:Fire(self)
	self.OnClosed:Destroy()
	self.OnMinimized:Destroy()
	self.OnRestored:Destroy()
	self.OnTabChanged:Destroy()
	self.OnDestroyed:Destroy()
end

return Window
