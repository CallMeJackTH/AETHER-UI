--[[
	Keybind.lua  -  key / mouse-button binding row.
	Keybind.new(ctx, parent, config, section)
	  config: Name, Description,
	          Default = Enum.KeyCode | Enum.UserInputType | "F" | nil,
	          Mode = "Press" | "Hold",
	          Callback(pressed)   -- when the bound input is pressed (and released in Hold mode)
	          OnChanged(name)     -- when the binding changes
	  Click the chip, then press a key. Esc cancels, Backspace/Delete clears.
	  :Set(value, silent)  :Get() -> "F" | "MouseButton2" | "None"  :GetKey() -> EnumItem?
	  .Pressed -> Signal(pressed)    .Changed -> Signal(name)
]]

local UserInputService = game:GetService("UserInputService")

local Keybind = {}
Keybind.__index = Keybind
Keybind.Persistent = true

local SHORT = {
	MouseButton2 = "MB2",
	MouseButton3 = "MB3",
	LeftShift = "LShift",
	RightShift = "RShift",
	LeftControl = "LCtrl",
	RightControl = "RCtrl",
	LeftAlt = "LAlt",
	RightAlt = "RAlt",
	Return = "Enter",
}

local function resolve(value)
	if value == nil or value == "" or value == "None" then
		return nil, "None"
	end
	if typeof(value) == "EnumItem" then
		if value.EnumType == Enum.KeyCode or value.EnumType == Enum.UserInputType then
			return value, value.Name
		end
		return nil, "None"
	end
	if type(value) == "string" then
		local okKey, keyCode = pcall(function()
			return Enum.KeyCode[value]
		end)
		if okKey and keyCode then
			return keyCode, keyCode.Name
		end
		local okType, inputType = pcall(function()
			return Enum.UserInputType[value]
		end)
		if okType and inputType then
			return inputType, inputType.Name
		end
	end
	return nil, "None"
end

function Keybind.new(ctx, parent, config)
	local self = setmetatable({}, Keybind)
	local Utils, theme = ctx.Utils, ctx.Theme
	local colors, fonts, sizes = theme.Colors, theme.Fonts, theme.Sizes

	self.ctx = ctx
	self.Maid = Utils.Maid.new()
	self.Callback = config.Callback
	self.OnChanged = config.OnChanged
	self.Mode = config.Mode or "Press"
	self.Pressed = Utils.Signal.new()
	self.Changed = Utils.Signal.new()
	self.Maid:Give(self.Pressed)
	self.Maid:Give(self.Changed)
	self.Disabled = false
	self.Listening = false

	local row = Utils.CreateRow(ctx, parent, config, { Interactive = true, Reserve = 90 })
	self.Row = row
	self.Root = row.Root

	self.Chip = Utils.Create("Frame", {
		Name = "Chip",
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(1, -row.Padding, 0.5, 0),
		Size = UDim2.fromOffset(54, ctx.ControlHeight),
		BackgroundColor3 = colors.Background,
		BorderSizePixel = 0,
		Parent = row.Root,
	})
	Utils.Corner(self.Chip, theme.Layout.RadiusControl)
	self.Stroke = Utils.Stroke(self.Chip, colors.Border, 1, 0)
	self.ChipLabel = Utils.Text(theme, self.Chip, {
		Name = "Key",
		Font = fonts.Mono,
		TextSize = sizes.Caption,
		TextColor3 = colors.Text,
		TextXAlignment = Enum.TextXAlignment.Center,
		Size = UDim2.new(1, 0, 1, 0),
	})

	self.Key, self.Name = resolve(config.Default)
	self:_render()

	Utils.BindRowFeedback(ctx, row, row.Root, self.Maid, function()
		return self.Disabled
	end)

	self.Maid:Give(row.Root.Activated:Connect(function()
		if self.Disabled then
			return
		end
		if self.Listening then
			self:_stopListening()
		else
			self:_startListening()
		end
	end))

	-- Bound input detection
	self.Maid:Give(UserInputService.InputBegan:Connect(function(input, processed)
		if processed or self.Listening or self.Disabled or not self.Key then
			return
		end
		if self:_matches(input) then
			self.Pressed:Fire(true)
			Utils.Safe(self.Callback, true)
		end
	end))

	self.Maid:Give(UserInputService.InputEnded:Connect(function(input)
		if self.Mode ~= "Hold" or self.Disabled or not self.Key then
			return
		end
		if self:_matches(input) then
			self.Pressed:Fire(false)
			Utils.Safe(self.Callback, false)
		end
	end))

	self.Maid:Give(function()
		self:_stopListening()
	end)

	return self
end

function Keybind:_matches(input)
	local key = self.Key
	if not key then
		return false
	end
	if key.EnumType == Enum.KeyCode then
		return input.KeyCode == key
	end
	return input.UserInputType == key
end

function Keybind:_render()
	local text = self.Name == "None" and "None" or (SHORT[self.Name] or self.Name)
	if self.Listening then
		text = "..."
	end
	self.ChipLabel.Text = text
	local width = self.ctx.Utils.TextSize(text, self.ctx.Theme.Fonts.Mono, self.ctx.Theme.Sizes.Caption).X + 20
	self.Chip.Size = UDim2.fromOffset(math.max(54, width), self.ctx.ControlHeight)
end

function Keybind:_startListening()
	if self.Listening then
		return
	end
	local Utils = self.ctx.Utils
	self.Listening = true
	self.ctx.State.CapturingKey = true
	self.ctx.Overlay:CloseAll()
	self:_render()
	self._stopPulse = self.ctx.Animation:Pulse(self.Stroke)
	self.Stroke.Color = self.ctx.Theme.Colors.Accent

	self._listen = UserInputService.InputBegan:Connect(function(input)
		local kind = input.UserInputType
		if kind == Enum.UserInputType.Keyboard then
			if input.KeyCode == Enum.KeyCode.Escape then
				self:_stopListening()
			elseif input.KeyCode == Enum.KeyCode.Backspace or input.KeyCode == Enum.KeyCode.Delete then
				self:_bind(nil)
			elseif input.KeyCode ~= Enum.KeyCode.Unknown then
				self:_bind(input.KeyCode)
			end
		elseif kind == Enum.UserInputType.MouseButton2 or kind == Enum.UserInputType.MouseButton3 then
			self:_bind(kind)
		elseif kind == Enum.UserInputType.MouseButton1 or kind == Enum.UserInputType.Touch then
			if not Utils.IsPointInside(self.Root, Utils.InputPosition(input)) then
				self:_stopListening()
			end
		end
	end)
end

function Keybind:_stopListening()
	if not self.Listening then
		return
	end
	self.Listening = false
	self.ctx.State.CapturingKey = false
	if self._listen then
		self._listen:Disconnect()
		self._listen = nil
	end
	if self._stopPulse then
		self._stopPulse()
		self._stopPulse = nil
	end
	local colors = self.ctx.Theme.Colors
	self.Stroke.Transparency = 0
	self.Stroke.Color = colors.Border
	self:_render()
end

function Keybind:_bind(value)
	self:_stopListening()
	self:Set(value, false)
end

function Keybind:Set(value, silent)
	local key, name = resolve(value)
	self.Key, self.Name = key, name
	self:_render()
	self.Changed:Fire(name)
	if not silent then
		self.ctx.Utils.Safe(self.OnChanged, name)
	end
end

function Keybind:Get()
	return self.Name
end

function Keybind:GetKey()
	return self.Key
end

function Keybind:Serialize()
	return self.Name
end

function Keybind:Deserialize(value)
	self:Set(value, false)
end

function Keybind:_onDisabled(disabled)
	self.Disabled = disabled
	if disabled then
		self:_stopListening()
	end
end

return Keybind
