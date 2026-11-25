--[[
	Overlay.lua
	Everything that floats above the window: popup registry (colour picker,
	context menu), tooltips, dialogs and modals.

	Layer order inside the ScreenGui (Theme.ZIndex):
	  Window < ModalLayer < PopupLayer < Notifications < TooltipLayer
	Popups always sit above modals, so a colour picker opened from inside a
	modal is never hidden behind it.

	Overlay.new(ctx, gui)
	  :AttachTooltip(gui, textOrFn, delay, side) -> disconnect()
	  :ShowTooltip(text, anchorGui, side) / :HideTooltip()
	  :ContextMenu(items, position) -> { Close }
	  :AttachContextMenu(gui, itemsOrFn, maid)
	  :Dialog({ Title, Content, Buttons, Dismissable, OnClose }) -> handle
	  :Modal({ Title, Content, Width, Height, Build, Buttons, Dismissable, OnClose }) -> handle
	  :RegisterPopup(popup) / :UnregisterPopup(popup)   popup = { Frame, Close, Owner }
	  :Place(size, anchorGui) -> Vector2          anchored, edge-clamped position
	  :Clamp(position, size) -> Vector2
	  :CloseAll() / :CloseModals() / :Destroy()

	  items (context menu): { Text, Callback, Shortcut, Danger, Disabled } or { Divider = true }
	  buttons (dialog/modal): { Text, Style, Callback, KeepOpen }
	  handle: { Panel, Body, Backdrop, Closed (Signal), Close() }
]]

local UserInputService = game:GetService("UserInputService")

local Overlay = {}
Overlay.__index = Overlay

function Overlay.new(ctx, gui)
	local self = setmetatable({}, Overlay)
	local Utils = ctx.Utils
	local theme = ctx.Theme

	self.ctx = ctx
	self.Gui = gui
	self.Maid = Utils.Maid.new()
	self._popups = {}
	self._modals = {}
	self._modalZ = 1
	self._tipToken = 0
	self._destroyed = false

	local function layer(name, zindex)
		return Utils.Create("Frame", {
			Name = name,
			Size = UDim2.new(1, 0, 1, 0),
			BackgroundTransparency = 1,
			BorderSizePixel = 0,
			Active = false,
			ZIndex = zindex,
			Parent = gui,
		})
	end

	self.ModalLayer = layer("Modals", theme.ZIndex.Modal)
	self.Layer = layer("Popups", theme.ZIndex.Popup)
	self.TooltipLayer = layer("Tooltips", theme.ZIndex.Tooltip)

	self.Maid:Give(UserInputService.InputBegan:Connect(function(input, processed)
		if processed or input.KeyCode ~= Enum.KeyCode.Escape then
			return
		end
		local popup = self._popups[#self._popups]
		if popup then
			popup.Close()
			return
		end
		local modal = self._modals[#self._modals]
		if modal and modal.Dismissable then
			modal:Close()
		end
	end))

	return self
end

----------------------------------------------------------------------
-- Geometry
----------------------------------------------------------------------

function Overlay:Clamp(position, size)
	local viewport = self.ctx.Utils.GetViewport(self.Gui)
	local margin = self.ctx.Theme.Layout.PopupMargin
	return Vector2.new(
		self.ctx.Utils.Clamp(position.X, margin, viewport.X - size.X - margin),
		self.ctx.Utils.Clamp(position.Y, margin, viewport.Y - size.Y - margin)
	)
end

-- Anchored placement: below the anchor (right edges aligned), flipped above
-- when there is not enough room.
function Overlay:Place(size, anchor)
	local viewport = self.ctx.Utils.GetViewport(self.Gui)
	local margin = self.ctx.Theme.Layout.PopupMargin
	local position, extent = anchor.AbsolutePosition, anchor.AbsoluteSize

	local x = position.X + extent.X - size.X
	local y = position.Y + extent.Y + 6
	if y + size.Y > viewport.Y - margin then
		y = position.Y - size.Y - 6
	end
	return self:Clamp(Vector2.new(x, y), size)
end

----------------------------------------------------------------------
-- Popup registry
----------------------------------------------------------------------

function Overlay:RegisterPopup(popup)
	if self._destroyed then
		return
	end

	if not popup.KeepOthers then
		for index = #self._popups, 1, -1 do
			local other = self._popups[index]
			if other then
				other.Close()
			end
		end
	end

	table.insert(self._popups, popup)
	popup._active = true

	-- Deferred so the click that opened the popup cannot close it again.
	task.defer(function()
		if popup._active and not self._destroyed then
			popup._outside = self.ctx.Utils.BindOutsideClick(popup.Frame, function(input)
				if popup.Owner and popup.Owner.Parent then
					if self.ctx.Utils.IsPointInside(popup.Owner, self.ctx.Utils.InputPosition(input)) then
						return
					end
				end
				popup.Close()
			end)
		end
	end)
end

function Overlay:UnregisterPopup(popup)
	popup._active = false
	if popup._outside then
		popup._outside:Disconnect()
		popup._outside = nil
	end
	local index = table.find(self._popups, popup)
	if index then
		table.remove(self._popups, index)
	end
end

function Overlay:CloseAll()
	for index = #self._popups, 1, -1 do
		local popup = self._popups[index]
		if popup then
			popup.Close()
		end
	end
	self:HideTooltip()
end

function Overlay:CloseModals()
	for index = #self._modals, 1, -1 do
		local modal = self._modals[index]
		if modal then
			modal:Close()
		end
	end
end

----------------------------------------------------------------------
-- Tooltip
----------------------------------------------------------------------

function Overlay:_tooltip()
	if self._tip then
		return self._tip
	end

	local Utils = self.ctx.Utils
	local theme = self.ctx.Theme
	local colors = theme.Colors

	local group = Utils.Create("CanvasGroup", {
		Name = "Tooltip",
		Size = UDim2.fromOffset(10, 10),
		BackgroundColor3 = colors.Elevated,
		BackgroundTransparency = 0,
		BorderSizePixel = 0,
		GroupTransparency = 1,
		Visible = false,
		Parent = self.TooltipLayer,
	})
	Utils.Corner(group, theme.Layout.RadiusControl)
	Utils.Stroke(group, colors.Border, 1, 0.2)

	local label = Utils.Text(theme, group, {
		Name = "Text",
		Font = theme.Fonts.Medium,
		TextSize = theme.Sizes.Caption,
		TextColor3 = colors.Text,
		TextWrapped = true,
		TextXAlignment = Enum.TextXAlignment.Left,
		Position = UDim2.fromOffset(8, 0),
		Size = UDim2.new(1, -16, 1, 0),
	})

	self._tip = { Group = group, Label = label }
	return self._tip
end

-- side: "Bottom" (default) | "Right"
function Overlay:ShowTooltip(text, anchor, side)
	if self._destroyed or not text or text == "" then
		return
	end

	local ctx = self.ctx
	local Utils, theme = ctx.Utils, ctx.Theme
	local layout = theme.Layout
	local tip = self:_tooltip()

	local bounds = Utils.TextSize(text, theme.Fonts.Medium, theme.Sizes.Caption, layout.TooltipMaxWidth)
	local width = math.min(layout.TooltipMaxWidth, bounds.X) + 18
	local height = bounds.Y + 12
	local size = Vector2.new(width, height)

	tip.Label.Text = text
	tip.Group.Size = UDim2.fromOffset(width, height)

	local position
	if anchor and anchor.Parent then
		local ap, extent = anchor.AbsolutePosition, anchor.AbsoluteSize
		if side == "Right" then
			position = Vector2.new(ap.X + extent.X + layout.TooltipOffset, ap.Y + extent.Y / 2 - height / 2)
		else
			position = Vector2.new(ap.X + extent.X / 2 - width / 2, ap.Y + extent.Y + layout.TooltipOffset)
			local viewport = Utils.GetViewport(self.Gui)
			if position.Y + height > viewport.Y - layout.PopupMargin then
				position = Vector2.new(position.X, ap.Y - height - layout.TooltipOffset)
			end
		end
	else
		local mouse = UserInputService:GetMouseLocation()
		position = Vector2.new(mouse.X + 14, mouse.Y + 18)
	end

	position = self:Clamp(position, size)
	tip.Group.Position = UDim2.fromOffset(position.X, position.Y)

	self._tipToken = self._tipToken + 1
	ctx.Animation:TooltipIn(tip.Group)
end

function Overlay:HideTooltip()
	local tip = self._tip
	if not tip or not tip.Group.Visible then
		return
	end
	self._tipToken = self._tipToken + 1
	local token = self._tipToken
	self.ctx.Animation:TooltipOut(tip.Group, function()
		if token == self._tipToken and tip.Group.Parent then
			tip.Group.Visible = false
		end
	end)
end

-- `source` is a string or a function returning a string (or nil for "no tip").
-- Returns an idempotent disconnect function.
function Overlay:AttachTooltip(gui, source, delay, side)
	local ctx = self.ctx
	local Utils = ctx.Utils
	local maid = Utils.Maid.new()
	local token = 0
	local hovering = false
	local detached = false

	local function resolve()
		if type(source) == "function" then
			local ok, value = pcall(source)
			return ok and value or nil
		end
		return source
	end

	maid:Give(gui.MouseEnter:Connect(function()
		hovering = true
		token = token + 1
		local mine = token
		task.delay(delay or ctx.Theme.Motion.TooltipDelay, function()
			if mine == token and hovering and not detached and gui.Parent then
				if ctx.Settings and ctx.Settings.Tooltips == false then
					return
				end
				local text = resolve()
				if text and text ~= "" then
					self:ShowTooltip(text, gui, side)
				end
			end
		end)
	end))

	maid:Give(gui.MouseLeave:Connect(function()
		hovering = false
		token = token + 1
		self:HideTooltip()
	end))

	maid:Give(gui.InputBegan:Connect(function(input)
		if Utils.IsPointerInput(input) then
			token = token + 1
			self:HideTooltip()
		end
	end))

	local function disconnect()
		if detached then
			return
		end
		detached = true
		token = token + 1
		maid:Destroy()
	end

	self.Maid:Give(disconnect)
	return disconnect
end

----------------------------------------------------------------------
-- Context menu
----------------------------------------------------------------------

function Overlay:ContextMenu(items, position)
	if self._destroyed or type(items) ~= "table" or #items == 0 then
		return nil
	end

	self:CloseAll()

	local ctx = self.ctx
	local Utils, theme, animation = ctx.Utils, ctx.Theme, ctx.Animation
	local colors, fonts, sizes, layout = theme.Colors, theme.Fonts, theme.Sizes, theme.Layout
	local itemHeight = ctx.Touch and layout.ContextItemTouch or layout.ContextItem
	local padding = 4

	local width, height = 150, padding * 2
	for _, item in ipairs(items) do
		if item.Divider then
			height = height + 9
		else
			height = height + itemHeight
			local needed = Utils.TextSize(tostring(item.Text or ""), fonts.Medium, sizes.Body).X + 28
			if item.Shortcut then
				needed = needed + Utils.TextSize(tostring(item.Shortcut), fonts.Mono, sizes.Tiny).X + 24
			end
			width = math.max(width, needed)
		end
	end

	local origin = position or UserInputService:GetMouseLocation()
	origin = self:Clamp(Vector2.new(origin.X, origin.Y), Vector2.new(width, height))

	local maid = Utils.Maid.new()
	local panel = Utils.Create("CanvasGroup", {
		Name = "ContextMenu",
		Position = UDim2.fromOffset(origin.X, origin.Y),
		Size = UDim2.fromOffset(width, height),
		BackgroundColor3 = colors.Elevated,
		BackgroundTransparency = theme.Transparency.Popup,
		BorderSizePixel = 0,
		GroupTransparency = 1,
		Parent = self.Layer,
	})
	Utils.Corner(panel, theme.Layout.RadiusCard)
	Utils.Stroke(panel, colors.Border, 1, 0.2)
	local scale = Utils.Create("UIScale", { Scale = 1, Parent = panel })
	Utils.Padding(panel, padding)
	Utils.List(panel, 0)

	local menu = {}
	local closed = false
	local popup = { Frame = panel }

	function menu.Close()
		if closed then
			return
		end
		closed = true
		self:UnregisterPopup(popup)
		animation:ContextMenuOut(panel, scale, function()
			maid:Destroy()
			panel:Destroy()
		end)
	end
	popup.Close = menu.Close

	for index, item in ipairs(items) do
		if item.Divider then
			local holder = Utils.Create("Frame", {
				Name = "Divider",
				Size = UDim2.new(1, 0, 0, 9),
				BackgroundTransparency = 1,
				LayoutOrder = index,
				Parent = panel,
			})
			Utils.Create("Frame", {
				AnchorPoint = Vector2.new(0, 0.5),
				Position = UDim2.new(0, 6, 0.5, 0),
				Size = UDim2.new(1, -12, 0, 1),
				BackgroundColor3 = colors.Border,
				BackgroundTransparency = 0.3,
				BorderSizePixel = 0,
				Parent = holder,
			})
		else
			local disabled = item.Disabled and true or false
			local button = Utils.Create("TextButton", {
				Name = "Item_" .. index,
				Text = "",
				AutoButtonColor = false,
				Size = UDim2.new(1, 0, 0, itemHeight),
				BackgroundColor3 = colors.Hover,
				BackgroundTransparency = 1,
				BorderSizePixel = 0,
				LayoutOrder = index,
				Parent = panel,
			})
			Utils.Corner(button, theme.Layout.RadiusControl)

			local restColor = item.Danger and colors.Error or colors.Muted
			local label = Utils.Text(theme, button, {
				Name = "Label",
				Text = tostring(item.Text or ""),
				Font = fonts.Medium,
				TextSize = sizes.Body,
				TextColor3 = disabled and colors.Subtle or restColor,
				Position = UDim2.fromOffset(10, 0),
				Size = UDim2.new(1, -20, 1, 0),
			})

			if item.Shortcut then
				Utils.Text(theme, button, {
					Name = "Shortcut",
					Text = tostring(item.Shortcut),
					Font = fonts.Mono,
					TextSize = sizes.Tiny,
					TextColor3 = colors.Subtle,
					TextXAlignment = Enum.TextXAlignment.Right,
					Position = UDim2.fromOffset(10, 0),
					Size = UDim2.new(1, -20, 1, 0),
				})
			end

			if not disabled then
				Utils.BindInteract(button, maid, {
					Hover = function(hover)
						animation:Play(button, "Hover", { BackgroundTransparency = hover and 0.35 or 1 })
						animation:Play(label, "Hover", {
							TextColor3 = (item.Danger and colors.Error) or (hover and colors.Text or colors.Muted),
						})
					end,
				})
				maid:Give(button.Activated:Connect(function()
					menu.Close()
					Utils.Safe(item.Callback)
				end))
			end
		end
	end

	self:RegisterPopup(popup)
	animation:ContextMenuIn(panel, scale)
	return menu
end

-- Right click (mouse) or long press (touch). `itemsOrFn` may be a function
-- returning the item list so menus can be built lazily.
function Overlay:AttachContextMenu(gui, itemsOrFn, maid)
	local ctx = self.ctx
	local Utils = ctx.Utils
	maid = maid or self.Maid

	local function open(position)
		local items = itemsOrFn
		if type(itemsOrFn) == "function" then
			local ok, result = pcall(itemsOrFn)
			items = ok and result or nil
		end
		if items then
			self:ContextMenu(items, position)
		end
	end

	maid:Give(gui.InputBegan:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton2 then
			open(UserInputService:GetMouseLocation())
		elseif input.UserInputType == Enum.UserInputType.Touch then
			local start = Utils.InputPosition(input)
			task.delay(ctx.Theme.Motion.LongPress, function()
				if input.UserInputState ~= Enum.UserInputState.End
					and input.UserInputState ~= Enum.UserInputState.Cancel
					and (Utils.InputPosition(input) - start).Magnitude < 12
					and gui.Parent
				then
					open(Utils.InputPosition(input))
				end
			end)
		end
	end))
end

----------------------------------------------------------------------
-- Dialog / Modal
----------------------------------------------------------------------

function Overlay:_createModal(kind, config)
	if self._destroyed then
		return nil
	end
	config = config or {}

	self:CloseAll()

	local overlay = self
	local ctx = self.ctx
	local Utils, theme, animation = ctx.Utils, ctx.Theme, ctx.Animation
	local colors, fonts, sizes, layout = theme.Colors, theme.Fonts, theme.Sizes, theme.Layout
	local viewport = Utils.GetViewport(self.Gui)

	local width = config.Width or (kind == "Dialog" and layout.DialogWidth or layout.ModalWidth)
	width = math.min(width, viewport.X - 32)

	self._modalZ = self._modalZ + 1
	local maid = Utils.Maid.new()
	local handle = {
		Kind = kind,
		Dismissable = config.Dismissable ~= false,
		Closed = Utils.Signal.new(),
	}

	local backdrop = Utils.Create("Frame", {
		Name = kind .. "Backdrop",
		Size = UDim2.new(1, 0, 1, 0),
		BackgroundColor3 = colors.Black,
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		Active = true,
		ZIndex = self._modalZ,
		Parent = self.ModalLayer,
	})

	local panel = Utils.Create("CanvasGroup", {
		Name = kind,
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.new(0.5, 0, 0.5, 0),
		Size = UDim2.new(0, width, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundColor3 = colors.Surface,
		BackgroundTransparency = theme.Transparency.Popup,
		BorderSizePixel = 0,
		GroupTransparency = 1,
		ZIndex = self._modalZ + 1,
		Parent = backdrop,
	})
	Utils.Corner(panel, layout.RadiusPanel)
	Utils.Stroke(panel, colors.Border, 1, 0.15)
	local scale = Utils.Create("UIScale", { Scale = 1, Parent = panel })
	Utils.Padding(panel, 16)
	Utils.List(panel, 10)

	local reserve = (kind == "Modal") and 34 or 0
	Utils.Text(theme, panel, {
		Name = "Title",
		Text = tostring(config.Title or (kind == "Dialog" and "Confirm" or "Modal")),
		Font = fonts.SemiBold,
		TextSize = sizes.Title + 1,
		TextWrapped = true,
		AutomaticSize = Enum.AutomaticSize.Y,
		Size = UDim2.new(1, -reserve, 0, 20),
		LayoutOrder = 1,
	})

	if config.Content and config.Content ~= "" then
		Utils.Text(theme, panel, {
			Name = "Content",
			Text = tostring(config.Content),
			Font = fonts.Regular,
			TextSize = sizes.Small + 1,
			TextColor3 = colors.Muted,
			TextWrapped = true,
			TextYAlignment = Enum.TextYAlignment.Top,
			AutomaticSize = Enum.AutomaticSize.Y,
			Size = UDim2.new(1, 0, 0, 16),
			LayoutOrder = 2,
		})
	end

	if kind == "Modal" then
		local bodyHeight = config.Height or math.min(180, math.max(80, viewport.Y - 220))
		handle.Body = Utils.Create("ScrollingFrame", {
			Name = "Body",
			Size = UDim2.new(1, 0, 0, bodyHeight),
			BackgroundTransparency = 1,
			BorderSizePixel = 0,
			ScrollBarThickness = 3,
			ScrollBarImageColor3 = colors.Border,
			ScrollingDirection = Enum.ScrollingDirection.Y,
			AutomaticCanvasSize = Enum.AutomaticSize.Y,
			CanvasSize = UDim2.new(),
			LayoutOrder = 3,
			Parent = panel,
		})
		Utils.List(handle.Body, layout.Gap)
		Utils.Padding(handle.Body, 0, 4, 0, 0)
	end

	local closed = false
	function handle:Close()
		if closed then
			return
		end
		closed = true

		local index = table.find(overlay._modals, handle)
		if index then
			table.remove(overlay._modals, index)
		end

		animation:ModalOut({ Backdrop = backdrop, Panel = panel, Scale = scale }, function()
			maid:Destroy()
			backdrop:Destroy()
			if config.OnClose then
				Utils.Safe(config.OnClose)
			end
			handle.Closed:Fire()
			handle.Closed:Destroy()
		end)
	end

	handle.Panel = panel
	handle.Backdrop = backdrop

	if kind == "Modal" then
		local closeButton = Utils.Create("TextButton", {
			Name = "Close",
			Text = "",
			AutoButtonColor = false,
			AnchorPoint = Vector2.new(1, 0),
			Position = UDim2.new(1, -10, 0, 10),
			Size = UDim2.fromOffset(26, 26),
			BackgroundColor3 = colors.Hover,
			BackgroundTransparency = 1,
			BorderSizePixel = 0,
			ZIndex = 5,
			Parent = panel,
		})
		Utils.Corner(closeButton, layout.RadiusControl)
		local icon = Utils.Icon("close", closeButton, colors.Muted, {
			Size = UDim2.fromOffset(12, 12),
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.new(0.5, 0, 0.5, 0),
		})
		Utils.BindInteract(closeButton, maid, {
			Hover = function(hover)
				animation:Play(closeButton, "Hover", { BackgroundTransparency = hover and 0.4 or 1 })
				animation:IconColor(icon, hover and colors.Text or colors.Muted)
			end,
		})
		maid:Give(closeButton.Activated:Connect(function()
			handle:Close()
		end))
	end

	local buttons = config.Buttons
	if (not buttons or #buttons == 0) and kind == "Dialog" then
		buttons = { { Text = "OK", Style = "Primary" } }
	end
	if buttons and #buttons > 0 then
		local row = Utils.Create("Frame", {
			Name = "Buttons",
			Size = UDim2.new(1, 0, 0, ctx.ButtonHeight),
			BackgroundTransparency = 1,
			LayoutOrder = 4,
			Parent = panel,
		})
		Utils.List(row, 8, Enum.FillDirection.Horizontal, Enum.HorizontalAlignment.Right)
		for index, spec in ipairs(buttons) do
			Utils.CreateButton(ctx, row, {
				Text = spec.Text or "OK",
				Style = spec.Style or "Default",
				LayoutOrder = index,
				Maid = maid,
				Callback = function()
					local keepOpen = spec.KeepOpen
					if spec.Callback then
						local ok, result = pcall(spec.Callback, handle)
						if not ok then
							warn("[AetherUI] button callback error: " .. tostring(result))
						elseif result == false then
							keepOpen = true
						end
					end
					if not keepOpen then
						handle:Close()
					end
				end,
			})
		end
	end

	if handle.Dismissable then
		maid:Give(backdrop.InputBegan:Connect(function(input)
			if Utils.IsPointerInput(input) and not Utils.IsPointInside(panel, Utils.InputPosition(input)) then
				handle:Close()
			end
		end))
	end

	table.insert(self._modals, handle)
	animation:ModalIn({ Backdrop = backdrop, Panel = panel, Scale = scale }, kind)

	if config.Build then
		Utils.Safe(config.Build, handle.Body, handle)
	end

	return handle
end

function Overlay:Dialog(config)
	return self:_createModal("Dialog", config)
end

function Overlay:Modal(config)
	return self:_createModal("Modal", config)
end

function Overlay:Destroy()
	if self._destroyed then
		return
	end
	self._destroyed = true

	for index = #self._popups, 1, -1 do
		local popup = self._popups[index]
		if popup and popup._outside then
			popup._outside:Disconnect()
		end
	end
	self._popups = {}
	self._modals = {}
	self.Maid:Destroy()

	for _, instance in ipairs({ self.ModalLayer, self.Layer, self.TooltipLayer }) do
		self.ctx.Animation:Cancel(instance)
		instance:Destroy()
	end
	self._tip = nil
end

return Overlay
