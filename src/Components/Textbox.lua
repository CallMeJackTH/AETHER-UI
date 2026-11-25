--[[
	Textbox.lua  -  single-line input row.
	Textbox.new(ctx, parent, config, section)
	  config: Name, Description, Default = "", Placeholder, Numeric = false,
	          Min, Max (numeric clamp), MaxLength, ClearOnFocus = false,
	          Callback(value, enterPressed)   -- fires when the box loses focus
	  :Set(value, silent)  :Get()  :Focus()
	  .Changed -> Signal(value)
]]

local UserInputService = game:GetService("UserInputService")

local Textbox = {}
Textbox.__index = Textbox
Textbox.Persistent = true

function Textbox.new(ctx, parent, config)
	local self = setmetatable({}, Textbox)
	local Utils, theme, animation = ctx.Utils, ctx.Theme, ctx.Animation
	local colors, fonts, sizes = theme.Colors, theme.Fonts, theme.Sizes

	self.ctx = ctx
	self.Maid = Utils.Maid.new()
	self.Callback = config.Callback
	self.Numeric = config.Numeric and true or false
	self.Min, self.Max = config.Min, config.Max
	self.MaxLength = config.MaxLength
	self.Changed = Utils.Signal.new()
	self.Maid:Give(self.Changed)
	self.Disabled = false

	local row = Utils.CreateRow(ctx, parent, config, { ReserveScale = 0.42 })
	self.Row = row
	self.Root = row.Root

	self.Holder = Utils.Create("Frame", {
		Name = "Input",
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(1, -row.Padding, 0.5, 0),
		Size = UDim2.new(0.42, -row.Padding, 0, ctx.ControlHeight),
		BackgroundColor3 = colors.Background,
		BorderSizePixel = 0,
		Parent = row.Root,
	})
	Utils.Corner(self.Holder, theme.Layout.RadiusControl)
	self.Stroke = Utils.Stroke(self.Holder, colors.Border, 1, 0)

	self.Box = Utils.Create("TextBox", {
		Name = "Box",
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		Position = UDim2.fromOffset(8, 0),
		Size = UDim2.new(1, -16, 1, 0),
		Font = fonts.Regular,
		TextSize = sizes.Small + 1,
		TextColor3 = colors.Text,
		PlaceholderText = config.Placeholder or "",
		PlaceholderColor3 = colors.Subtle,
		TextXAlignment = Enum.TextXAlignment.Left,
		ClearTextOnFocus = config.ClearOnFocus and true or false,
		TextTruncate = Enum.TextTruncate.AtEnd,
		Text = "",
		Parent = self.Holder,
	})

	local start = config.Default
	if start == nil and not self.Numeric then
		start = ""
	end
	self.Value = self:_coerce(start)
	self.Box.Text = self.Value ~= nil and tostring(self.Value) or ""

	self.Maid:Give(self.Box.Focused:Connect(function()
		animation:Focus(self.Stroke, self.Holder, true)
	end))

	self.Maid:Give(self.Box:GetPropertyChangedSignal("Text"):Connect(function()
		local text = self.Box.Text
		if self.Numeric then
			local filtered = text:gsub("[^%d%.%-]", "")
			if filtered ~= text then
				self.Box.Text = filtered
				return
			end
		end
		if self.MaxLength and #text > self.MaxLength then
			self.Box.Text = text:sub(1, self.MaxLength)
		end
	end))

	self.Maid:Give(self.Box.FocusLost:Connect(function(enter)
		animation:Focus(self.Stroke, self.Holder, false)
		local coerced = self:_coerce(self.Box.Text)
		if coerced == nil and self.Numeric then
			self.Box.Text = self.Value ~= nil and tostring(self.Value) or ""
			return
		end
		self.Value = coerced
		self.Box.Text = coerced ~= nil and tostring(coerced) or ""
		self.Changed:Fire(self.Value)
		if not self.Disabled then
			Utils.Safe(self.Callback, self.Value, enter)
		end
	end))

	Utils.BindRowFeedback(ctx, row, row.Root, self.Maid, function()
		return self.Disabled
	end)

	return self
end

function Textbox:_coerce(value)
	if self.Numeric then
		local number = tonumber(value)
		if number == nil then
			return nil
		end
		if self.Min then
			number = math.max(self.Min, number)
		end
		if self.Max then
			number = math.min(self.Max, number)
		end
		return number
	end
	local text = value == nil and "" or tostring(value)
	if self.MaxLength and #text > self.MaxLength then
		text = text:sub(1, self.MaxLength)
	end
	return text
end

function Textbox:Set(value, silent)
	local coerced = self:_coerce(value)
	if coerced == nil and self.Numeric then
		return false
	end
	self.Value = coerced
	self.Box.Text = coerced ~= nil and tostring(coerced) or ""
	self.Changed:Fire(self.Value)
	if not silent then
		self.ctx.Utils.Safe(self.Callback, self.Value, false)
	end
	return true
end

function Textbox:Get()
	return self.Value
end

function Textbox:Focus()
	if not self.Disabled then
		self.Box:CaptureFocus()
	end
end

function Textbox:_onDisabled(disabled)
	self.Disabled = disabled
	self.Box.TextEditable = not disabled
	if disabled and UserInputService:GetFocusedTextBox() == self.Box then
		self.Box:ReleaseFocus()
	end
end

return Textbox
