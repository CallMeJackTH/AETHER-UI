--[[
	Notifications.lua
	Toast stack anchored bottom-right of the ScreenGui (it stays visible even
	while the main window is minimized). Each toast has a type badge, title,
	wrapped body, dismiss button and a timer bar.

	Notifications.new(ctx, gui)
	  :Notify({ Title, Content, Type = "Info"|"Success"|"Warning"|"Error",
	            Duration = seconds (0 = persistent), Callback = fn })
	  :Clear()
]]

local Notifications = {}
Notifications.__index = Notifications

local TYPE_STYLES = {
	Info = { Color = "Info", Icon = "info" },
	Success = { Color = "Success", Icon = "success" },
	Warning = { Color = "Warning", Icon = "warning" },
	Error = { Color = "Error", Icon = "error" },
}

function Notifications.new(ctx, gui)
	local self = setmetatable({}, Notifications)
	local Utils = ctx.Utils
	local theme = ctx.Theme

	self.ctx = ctx
	self.Gui = gui
	self.Maid = Utils.Maid.new()
	self._active = {}
	self._order = 0
	self._destroyed = false

	self.Container = Utils.Create("Frame", {
		Name = "Notifications",
		AnchorPoint = Vector2.new(1, 1),
		Position = UDim2.new(1, -16, 1, -16),
		Size = UDim2.new(0, theme.Layout.NotificationWidth, 1, -32),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ZIndex = theme.ZIndex.Notification,
		Parent = gui,
	})

	Utils.List(self.Container, 8, Enum.FillDirection.Vertical, Enum.HorizontalAlignment.Left, Enum.VerticalAlignment.Bottom)

	self:_resize()
	self.Maid:Give(gui:GetPropertyChangedSignal("AbsoluteSize"):Connect(function()
		self:_resize()
	end))

	return self
end

function Notifications:_width()
	local viewport = self.ctx.Utils.GetViewport(self.Gui)
	return math.max(220, math.min(self.ctx.Theme.Layout.NotificationWidth, viewport.X - 32))
end

function Notifications:_resize()
	self.Container.Size = UDim2.new(0, self:_width(), 1, -32)
end

function Notifications:Notify(config)
	if self._destroyed then
		return nil
	end
	config = config or {}

	local ctx = self.ctx
	local Utils = ctx.Utils
	local theme = ctx.Theme
	local colors, fonts, sizes = theme.Colors, theme.Fonts, theme.Sizes
	local animation = ctx.Animation

	local style = TYPE_STYLES[config.Type or "Info"] or TYPE_STYLES.Info
	local tint = colors[style.Color]
	local title = tostring(config.Title or "Notification")
	local content = config.Content and tostring(config.Content) or ""
	local duration = config.Duration
	if duration == nil then
		duration = (ctx.Settings and ctx.Settings.NotificationDuration) or 4
	end

	-- Enforce the stack limit by dismissing the oldest toast.
	while #self._active >= theme.Layout.NotificationMax do
		self._active[1]:Dismiss()
	end

	-- Measure the body so the holder has a deterministic height.
	local width = self:_width()
	local textWidth = width - 10 - 24 - 10 - 28 - 10
	local bodyHeight = 0
	if content ~= "" then
		bodyHeight = Utils.TextSize(content, fonts.Regular, sizes.Small, textWidth).Y
	end
	local height = math.max(64, 12 + 16 + (content ~= "" and (2 + bodyHeight) or 0) + 16)

	self._order = self._order + 1
	local holder = Utils.Create("Frame", {
		Name = "Toast",
		Size = UDim2.new(1, 0, 0, height),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		LayoutOrder = self._order,
		Parent = self.Container,
	})

	local inner = Utils.Create("CanvasGroup", {
		Name = "Inner",
		Size = UDim2.new(1, 0, 1, 0),
		BackgroundColor3 = colors.Surface,
		BackgroundTransparency = theme.Transparency.Popup,
		BorderSizePixel = 0,
		GroupTransparency = 1,
		Parent = holder,
	})
	Utils.Corner(inner, theme.Layout.RadiusCard)
	Utils.Stroke(inner, colors.Border, 1, 0.2)

	-- Type badge
	local badge = Utils.Create("Frame", {
		Name = "Badge",
		Position = UDim2.fromOffset(10, 12),
		Size = UDim2.fromOffset(24, 24),
		BackgroundColor3 = tint,
		BackgroundTransparency = 0.85,
		BorderSizePixel = 0,
		Parent = inner,
	})
	Utils.Corner(badge, 12)
	Utils.Icon(style.Icon, badge, tint, {
		Size = UDim2.fromOffset(14, 14),
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.new(0.5, 0, 0.5, 0),
	})

	Utils.Text(theme, inner, {
		Name = "Title",
		Text = title,
		Font = fonts.SemiBold,
		TextSize = sizes.Body,
		TextTruncate = Enum.TextTruncate.AtEnd,
		Position = UDim2.fromOffset(44, 12),
		Size = UDim2.new(1, -44 - 38, 0, 16),
	})

	if content ~= "" then
		Utils.Text(theme, inner, {
			Name = "Body",
			Text = content,
			Font = fonts.Regular,
			TextSize = sizes.Small,
			TextColor3 = colors.Muted,
			TextWrapped = true,
			TextYAlignment = Enum.TextYAlignment.Top,
			Position = UDim2.fromOffset(44, 30),
			Size = UDim2.new(1, -44 - 38, 0, bodyHeight),
		})
	end

	local closeButton = Utils.Create("TextButton", {
		Name = "Close",
		Text = "",
		AutoButtonColor = false,
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -6, 0, 6),
		Size = UDim2.fromOffset(28, 28),
		BackgroundColor3 = colors.Hover,
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		Parent = inner,
	})
	Utils.Corner(closeButton, 6)
	local closeIcon = Utils.Icon("close", closeButton, colors.Muted, {
		Size = UDim2.fromOffset(12, 12),
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.new(0.5, 0, 0.5, 0),
	})

	local timer = nil
	if duration > 0 then
		timer = Utils.Create("Frame", {
			Name = "Timer",
			AnchorPoint = Vector2.new(0, 1),
			Position = UDim2.new(0, 0, 1, 0),
			Size = UDim2.new(1, 0, 0, 2),
			BackgroundColor3 = tint,
			BackgroundTransparency = 0.2,
			BorderSizePixel = 0,
			Parent = inner,
		})
	end

	local toastMaid = Utils.Maid.new()
	local toast = { Instance = holder, Maid = toastMaid }
	local active = self._active
	local dismissed = false

	function toast:Dismiss()
		if dismissed then
			return
		end
		dismissed = true

		local index = table.find(active, toast)
		if index then
			table.remove(active, index)
		end

		if timer then
			animation:Cancel(timer)
		end

		animation:NotificationOut({ Holder = holder, Inner = inner }, function()
			toastMaid:Destroy()
			holder:Destroy()
		end)
	end

	Utils.BindInteract(closeButton, toastMaid, {
		Hover = function(hovering)
			animation:Play(closeButton, "Hover", { BackgroundTransparency = hovering and 0.4 or 1 })
			animation:IconColor(closeIcon, hovering and colors.Text or colors.Muted)
		end,
	})

	toastMaid:Give(closeButton.Activated:Connect(function()
		toast:Dismiss()
	end))

	toastMaid:Give(inner.InputBegan:Connect(function(input)
		if Utils.IsPointerInput(input) and config.Callback then
			Utils.Safe(config.Callback)
			toast:Dismiss()
		end
	end))

	table.insert(self._active, toast)
	animation:NotificationIn({ Holder = holder, Inner = inner })

	if timer then
		animation:Tween(
			timer,
			{ Size = UDim2.new(0, 0, 0, 2) },
			duration,
			Enum.EasingStyle.Linear,
			Enum.EasingDirection.Out,
			function()
				toast:Dismiss()
			end
		)
	end

	return toast
end

function Notifications:Clear()
	for index = #self._active, 1, -1 do
		local toast = self._active[index]
		if toast then
			toast:Dismiss()
		end
	end
end

function Notifications:Destroy()
	if self._destroyed then
		return
	end
	self._destroyed = true
	for _, toast in ipairs(table.clone(self._active)) do
		toast.Maid:Destroy()
	end
	self.Maid:Destroy()
	if self.Container then
		self.Container:Destroy()
		self.Container = nil
	end
	self._active = {}
end

return Notifications
