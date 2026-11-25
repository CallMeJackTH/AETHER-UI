--[[
	Slider.lua  -  numeric slider with mouse + touch dragging.
	Slider.new(ctx, parent, config, section)
	  config: Name, Description, Min = 0, Max = 100, Default = Min, Increment = 1,
	          Suffix = "", Callback(value)
	  :Set(value, silent)  :Get()  :SetRange(min, max)
	  .Changed -> Signal(value)
]]

local Slider = {}
Slider.__index = Slider
Slider.Persistent = true

function Slider.new(ctx, parent, config)
	local self = setmetatable({}, Slider)
	local Utils, theme, animation = ctx.Utils, ctx.Theme, ctx.Animation
	local colors, fonts, sizes = theme.Colors, theme.Fonts, theme.Sizes

	self.ctx = ctx
	self.Maid = Utils.Maid.new()
	self.Callback = config.Callback
	self.Min = config.Min or 0
	self.Max = config.Max or 100
	self.Increment = config.Increment or 1
	self.Suffix = config.Suffix or ""
	self.Decimals = Utils.Decimals(self.Increment)
	self.Changed = Utils.Signal.new()
	self.Maid:Give(self.Changed)
	self.Disabled = false

	local hasDescription = config.Description ~= nil and config.Description ~= ""
	local height = (hasDescription and (ctx.RowHeight + 14) or ctx.RowHeight) + 20
	local row = Utils.CreateRow(ctx, parent, config, { TopAligned = true, Height = height, Reserve = 70 })
	self.Row = row
	self.Root = row.Root
	local pad = row.Padding

	self.ValueLabel = Utils.Text(theme, row.Root, {
		Name = "Value",
		Font = fonts.Mono,
		TextSize = sizes.Caption,
		TextColor3 = colors.Accent,
		TextXAlignment = Enum.TextXAlignment.Right,
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -pad, 0, 8),
		Size = UDim2.fromOffset(80, 18),
	})

	local track = Utils.Create("Frame", {
		Name = "Track",
		AnchorPoint = Vector2.new(0, 0.5),
		Position = UDim2.new(0, pad, 1, -14),
		Size = UDim2.new(1, -pad * 2, 0, 4),
		BackgroundColor3 = colors.Border,
		BorderSizePixel = 0,
		Parent = row.Root,
	})
	Utils.Corner(track, 2)

	local fill = Utils.Create("Frame", {
		Name = "Fill",
		Size = UDim2.new(0, 0, 1, 0),
		BackgroundColor3 = colors.Accent,
		BorderSizePixel = 0,
		Parent = track,
	})
	Utils.Corner(fill, 2)

	local knob = Utils.Create("Frame", {
		Name = "Knob",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.new(0, 0, 0.5, 0),
		Size = UDim2.fromOffset(12, 12),
		BackgroundColor3 = colors.Text,
		BorderSizePixel = 0,
		ZIndex = 2,
		Parent = track,
	})
	Utils.Corner(knob, 6)
	Utils.Stroke(knob, colors.Accent, 2, 0)

	self.Track, self.Fill, self.Knob = track, fill, knob
	self._parts = { Fill = fill, Knob = knob }

	local hit = Utils.Create("TextButton", {
		Name = "Hit",
		Text = "",
		AutoButtonColor = false,
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		AnchorPoint = Vector2.new(0, 1),
		Position = UDim2.new(0, 0, 1, 0),
		Size = UDim2.new(1, 0, 0, 30),
		ZIndex = 3,
		Parent = row.Root,
	})

	local function ratioFrom(input)
		local x = Utils.InputPosition(input).X
		local left = track.AbsolutePosition.X
		local width = math.max(track.AbsoluteSize.X, 1)
		return Utils.Clamp((x - left) / width, 0, 1)
	end

	Utils.BindDrag(hit, self.Maid, {
		CanBegin = function()
			return not self.Disabled
		end,
		Began = function(input)
			animation:SliderKnob(knob, true)
			self:_setRatio(ratioFrom(input))
		end,
		Changed = function(input)
			self:_setRatio(ratioFrom(input))
		end,
		Ended = function()
			animation:SliderKnob(knob, false)
		end,
	})

	Utils.BindRowFeedback(ctx, row, row.Root, self.Maid, function()
		return self.Disabled
	end)

	local start = config.Default
	if start == nil then
		start = self.Min
	end
	self.Value = self:_normalize(start)
	self:_render(true)
	return self
end

function Slider:_normalize(value)
	value = tonumber(value) or self.Min
	value = self.ctx.Utils.Round(value - self.Min, self.Increment) + self.Min
	return self.ctx.Utils.Clamp(tonumber(self.ctx.Utils.FormatNumber(value, self.Decimals)), self.Min, self.Max)
end

function Slider:_ratio()
	local span = self.Max - self.Min
	if span <= 0 then
		return 0
	end
	return (self.Value - self.Min) / span
end

function Slider:_render(instant)
	self.ValueLabel.Text = self.ctx.Utils.FormatNumber(self.Value, self.Decimals) .. self.Suffix
	self.ctx.Animation:Slider(self._parts, self:_ratio(), instant)
end

function Slider:_setRatio(ratio)
	self:Set(self.Min + ratio * (self.Max - self.Min))
end

function Slider:Set(value, silent)
	value = self:_normalize(value)
	if value == self.Value then
		return
	end
	self.Value = value
	self:_render(false)
	self.Changed:Fire(value)
	if not silent then
		self.ctx.Utils.Safe(self.Callback, value)
	end
end

function Slider:Get()
	return self.Value
end

function Slider:SetRange(min, max)
	self.Min, self.Max = min, math.max(min, max)
	self.Value = self:_normalize(self.Value)
	self:_render(true)
end

return Slider
