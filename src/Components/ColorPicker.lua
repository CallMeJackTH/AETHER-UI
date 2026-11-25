--[[
	ColorPicker.lua  -  colour row with an anchored saturation/value + hue popup.
	ColorPicker.new(ctx, parent, config, section)
	  config: Name, Description, Default = Color3, Callback(color3)
	  :Set(color3 | "#RRGGBB", silent)  :Get() -> Color3  :Open()  :Close()
	  Serialises as "#RRGGBB".
	  .Changed -> Signal(color3)
]]

local ColorPicker = {}
ColorPicker.__index = ColorPicker
ColorPicker.Persistent = true

local function hexOf(color)
	return string.format(
		"#%02X%02X%02X",
		math.floor(color.R * 255 + 0.5),
		math.floor(color.G * 255 + 0.5),
		math.floor(color.B * 255 + 0.5)
	)
end

function ColorPicker.new(ctx, parent, config)
	local self = setmetatable({}, ColorPicker)
	local Utils, theme = ctx.Utils, ctx.Theme
	local colors, fonts, sizes = theme.Colors, theme.Fonts, theme.Sizes

	self.ctx = ctx
	self.Maid = Utils.Maid.new()
	self.Callback = config.Callback
	self.Changed = Utils.Signal.new()
	self.Maid:Give(self.Changed)
	self.Disabled = false
	self.Color = config.Default or colors.Accent
	self.H, self.S, self.V = self.Color:ToHSV()

	local row = Utils.CreateRow(ctx, parent, config, { Interactive = true, Reserve = 110 })
	self.Row = row
	self.Root = row.Root

	self.HexLabel = Utils.Text(theme, row.Root, {
		Name = "Hex",
		Font = fonts.Mono,
		TextSize = sizes.Tiny + 1,
		TextColor3 = colors.Muted,
		TextXAlignment = Enum.TextXAlignment.Right,
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(1, -(row.Padding + 36), 0.5, 0),
		Size = UDim2.fromOffset(70, 18),
	})

	self.Swatch = Utils.Create("Frame", {
		Name = "Swatch",
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(1, -row.Padding, 0.5, 0),
		Size = UDim2.fromOffset(28, 16),
		BackgroundColor3 = self.Color,
		BorderSizePixel = 0,
		Parent = row.Root,
	})
	self.Swatch:SetAttribute("AetherLock", true)
	Utils.Corner(self.Swatch, 4)
	Utils.Stroke(self.Swatch, colors.Border, 1, 0)

	self:_renderOuter()

	Utils.BindRowFeedback(ctx, row, row.Root, self.Maid, function()
		return self.Disabled
	end)

	self.Maid:Give(row.Root.Activated:Connect(function()
		if self.Disabled then
			return
		end
		if self._popup then
			self:Close()
		else
			self:Open()
		end
	end))

	self.Maid:Give(function()
		self:_destroyPopup()
	end)

	return self
end

function ColorPicker:_renderOuter()
	self.Swatch.BackgroundColor3 = self.Color
	self.HexLabel.Text = hexOf(self.Color)
end

function ColorPicker:_renderPopup()
	local popup = self._popup
	if not popup then
		return
	end
	popup.Area.BackgroundColor3 = Color3.fromHSV(self.H, 1, 1)
	popup.Cursor.Position = UDim2.new(self.S, 0, 1 - self.V, 0)
	popup.HueCursor.Position = UDim2.new(self.H, 0, 0.5, 0)
	popup.Preview.BackgroundColor3 = self.Color
	if not popup.Box:IsFocused() then
		popup.Box.Text = hexOf(self.Color)
	end
end

function ColorPicker:_commit(silent)
	self.Color = Color3.fromHSV(self.H, self.S, self.V)
	self:_renderOuter()
	self:_renderPopup()
	self.Changed:Fire(self.Color)
	if not silent then
		self.ctx.Utils.Safe(self.Callback, self.Color)
	end
end

function ColorPicker:Set(value, silent)
	if type(value) == "string" then
		value = self.ctx.Utils.HexToColor(value)
	end
	if typeof(value) ~= "Color3" then
		return false
	end
	local h, s, v = value:ToHSV()
	if s < 0.001 or v < 0.001 then
		h = self.H
	end
	self.H, self.S, self.V = h, s, v
	self.Color = value
	self:_renderOuter()
	self:_renderPopup()
	self.Changed:Fire(value)
	if not silent then
		self.ctx.Utils.Safe(self.Callback, value)
	end
	return true
end

function ColorPicker:Get()
	return self.Color
end

function ColorPicker:Serialize()
	return hexOf(self.Color)
end

function ColorPicker:Deserialize(value)
	self:Set(value, false)
end

function ColorPicker:Open()
	if self._popup or self.Disabled then
		return
	end

	local ctx = self.ctx
	local Utils, theme, animation, overlay = ctx.Utils, ctx.Theme, ctx.Animation, ctx.Overlay
	local colors, fonts, sizes, layout = theme.Colors, theme.Fonts, theme.Sizes, theme.Layout

	local width = layout.ColorPickerWidth
	local area = layout.ColorPickerArea
	local inner = width - 20
	local hueY = 10 + area + 10
	local hexY = hueY + 12 + 10
	local height = hexY + 28 + 10

	local position = overlay:Place(Vector2.new(width, height), self.Swatch)
	local maid = Utils.Maid.new()

	local panel = Utils.Create("CanvasGroup", {
		Name = "ColorPicker",
		Position = UDim2.fromOffset(position.X, position.Y),
		Size = UDim2.fromOffset(width, height),
		BackgroundColor3 = colors.Elevated,
		BackgroundTransparency = theme.Transparency.Popup,
		BorderSizePixel = 0,
		GroupTransparency = 1,
		Parent = overlay.Layer,
	})
	Utils.Corner(panel, layout.RadiusCard)
	Utils.Stroke(panel, colors.Border, 1, 0.2)
	local scale = Utils.Create("UIScale", { Scale = 1, Parent = panel })

	-- Saturation / value square
	local areaFrame = Utils.Create("Frame", {
		Name = "Area",
		Position = UDim2.fromOffset(10, 10),
		Size = UDim2.fromOffset(inner, area),
		BackgroundColor3 = Color3.fromHSV(self.H, 1, 1),
		BorderSizePixel = 0,
		ClipsDescendants = true,
		Parent = panel,
	})
	areaFrame:SetAttribute("AetherLock", true)
	Utils.Corner(areaFrame, 6)

	local function overlayFrame(name, color, transparency, rotation)
		local frame = Utils.Create("Frame", {
			Name = name,
			Size = UDim2.new(1, 0, 1, 0),
			BackgroundColor3 = color,
			BorderSizePixel = 0,
			Parent = areaFrame,
		})
		frame:SetAttribute("AetherLock", true)
		Utils.Create("UIGradient", { Transparency = transparency, Rotation = rotation, Parent = frame })
		return frame
	end
	overlayFrame("White", Color3.new(1, 1, 1), NumberSequence.new(0, 1), 0)
	overlayFrame("Black", Color3.new(0, 0, 0), NumberSequence.new(1, 0), 90)

	local cursor = Utils.Create("Frame", {
		Name = "Cursor",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Size = UDim2.fromOffset(12, 12),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ZIndex = 3,
		Parent = areaFrame,
	})
	Utils.Corner(cursor, 6)
	local cursorStroke = Utils.Stroke(cursor, Color3.new(1, 1, 1), 2, 0)
	cursorStroke:SetAttribute("AetherLock", true)

	-- Hue bar
	local hueFrame = Utils.Create("Frame", {
		Name = "Hue",
		Position = UDim2.fromOffset(10, hueY),
		Size = UDim2.fromOffset(inner, 12),
		BackgroundColor3 = Color3.new(1, 1, 1),
		BorderSizePixel = 0,
		Parent = panel,
	})
	hueFrame:SetAttribute("AetherLock", true)
	Utils.Corner(hueFrame, 6)

	local keypoints = {}
	for index = 0, 6 do
		table.insert(keypoints, ColorSequenceKeypoint.new(index / 6, Color3.fromHSV(index / 6, 1, 1)))
	end
	Utils.Create("UIGradient", { Color = ColorSequence.new(keypoints), Parent = hueFrame })

	local hueCursor = Utils.Create("Frame", {
		Name = "HueCursor",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Size = UDim2.fromOffset(6, 18),
		BackgroundColor3 = Color3.new(1, 1, 1),
		BorderSizePixel = 0,
		ZIndex = 3,
		Parent = hueFrame,
	})
	hueCursor:SetAttribute("AetherLock", true)
	Utils.Corner(hueCursor, 3)
	local hueStroke = Utils.Stroke(hueCursor, Color3.new(0, 0, 0), 1, 0.5)
	hueStroke:SetAttribute("AetherLock", true)

	-- Hex entry + preview
	local preview = Utils.Create("Frame", {
		Name = "Preview",
		Position = UDim2.fromOffset(10, hexY),
		Size = UDim2.fromOffset(28, 28),
		BackgroundColor3 = self.Color,
		BorderSizePixel = 0,
		Parent = panel,
	})
	preview:SetAttribute("AetherLock", true)
	Utils.Corner(preview, 6)
	Utils.Stroke(preview, colors.Border, 1, 0)

	local boxHolder = Utils.Create("Frame", {
		Name = "HexInput",
		Position = UDim2.fromOffset(46, hexY),
		Size = UDim2.fromOffset(inner - 36, 28),
		BackgroundColor3 = colors.Background,
		BorderSizePixel = 0,
		Parent = panel,
	})
	Utils.Corner(boxHolder, 6)
	local boxStroke = Utils.Stroke(boxHolder, colors.Border, 1, 0)

	local box = Utils.Create("TextBox", {
		Name = "Hex",
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		Position = UDim2.fromOffset(8, 0),
		Size = UDim2.new(1, -16, 1, 0),
		Font = fonts.Mono,
		TextSize = sizes.Small,
		TextColor3 = colors.Text,
		PlaceholderText = "#RRGGBB",
		PlaceholderColor3 = colors.Subtle,
		TextXAlignment = Enum.TextXAlignment.Left,
		ClearTextOnFocus = false,
		Text = hexOf(self.Color),
		Parent = boxHolder,
	})

	maid:Give(box.Focused:Connect(function()
		animation:Focus(boxStroke, boxHolder, true)
	end))
	maid:Give(box.FocusLost:Connect(function()
		animation:Focus(boxStroke, boxHolder, false)
		local parsed = Utils.HexToColor(box.Text)
		if parsed then
			self:Set(parsed, false)
		end
		box.Text = hexOf(self.Color)
	end))

	-- Dragging
	Utils.BindDrag(areaFrame, maid, {
		NoScrollLock = true,
		Began = function(input)
			local p = Utils.InputPosition(input)
			self.S = Utils.Clamp((p.X - areaFrame.AbsolutePosition.X) / math.max(areaFrame.AbsoluteSize.X, 1), 0, 1)
			self.V = 1 - Utils.Clamp((p.Y - areaFrame.AbsolutePosition.Y) / math.max(areaFrame.AbsoluteSize.Y, 1), 0, 1)
			self:_commit(false)
		end,
		Changed = function(input)
			local p = Utils.InputPosition(input)
			self.S = Utils.Clamp((p.X - areaFrame.AbsolutePosition.X) / math.max(areaFrame.AbsoluteSize.X, 1), 0, 1)
			self.V = 1 - Utils.Clamp((p.Y - areaFrame.AbsolutePosition.Y) / math.max(areaFrame.AbsoluteSize.Y, 1), 0, 1)
			self:_commit(false)
		end,
	})

	local function setHue(input)
		local p = Utils.InputPosition(input)
		self.H = Utils.Clamp((p.X - hueFrame.AbsolutePosition.X) / math.max(hueFrame.AbsoluteSize.X, 1), 0, 1)
		self:_commit(false)
	end
	Utils.BindDrag(hueFrame, maid, { NoScrollLock = true, Began = setHue, Changed = setHue })

	local popup = {
		Frame = panel,
		Owner = self.Root,
		Panel = panel,
		Scale = scale,
		Maid = maid,
		Area = areaFrame,
		Cursor = cursor,
		HueCursor = hueCursor,
		Preview = preview,
		Box = box,
	}
	popup.Close = function()
		self:Close()
	end

	self._popup = popup
	self:_renderPopup()
	overlay:RegisterPopup(popup)
	animation:PopupIn(panel, scale)
end

function ColorPicker:Close()
	local popup = self._popup
	if not popup then
		return
	end
	self._popup = nil
	self.ctx.Overlay:UnregisterPopup(popup)
	self.ctx.Animation:PopupOut(popup.Panel, popup.Scale, function()
		popup.Maid:Destroy()
		popup.Panel:Destroy()
	end)
end

-- Immediate teardown (component destruction).
function ColorPicker:_destroyPopup()
	local popup = self._popup
	if not popup then
		return
	end
	self._popup = nil
	self.ctx.Overlay:UnregisterPopup(popup)
	popup.Maid:Destroy()
	popup.Panel:Destroy()
end

function ColorPicker:_onDisabled(disabled)
	self.Disabled = disabled
	if disabled then
		self:Close()
	end
end

return ColorPicker
