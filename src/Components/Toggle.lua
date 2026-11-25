--[[
	Toggle.lua  -  on/off switch row.
	Toggle.new(ctx, parent, config, section)
	  config: Name, Description, Default = false, Callback(value)
	  :Set(bool, silent)  :Get()  :Toggle()
	  .Changed -> Signal(value)
]]

local Toggle = {}
Toggle.__index = Toggle
Toggle.Persistent = true

function Toggle.new(ctx, parent, config)
	local self = setmetatable({}, Toggle)
	local Utils, theme, animation = ctx.Utils, ctx.Theme, ctx.Animation
	local colors = theme.Colors

	self.ctx = ctx
	self.Maid = Utils.Maid.new()
	self.Callback = config.Callback
	self.Value = config.Default and true or false
	self.Changed = Utils.Signal.new()
	self.Maid:Give(self.Changed)
	self.Disabled = false

	local row = Utils.CreateRow(ctx, parent, config, { Interactive = true, Reserve = 52 })
	self.Row = row
	self.Root = row.Root

	local track = Utils.Create("Frame", {
		Name = "Track",
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(1, -row.Padding, 0.5, 0),
		Size = UDim2.fromOffset(38, 20),
		BackgroundColor3 = colors.Elevated,
		BorderSizePixel = 0,
		Parent = row.Root,
	})
	Utils.Corner(track, 10)
	local stroke = Utils.Stroke(track, colors.Border, 1, 0.2)

	local knob = Utils.Create("Frame", {
		Name = "Knob",
		AnchorPoint = Vector2.new(0, 0.5),
		Position = UDim2.new(0, 3, 0.5, 0),
		Size = UDim2.fromOffset(14, 14),
		BackgroundColor3 = colors.Muted,
		BorderSizePixel = 0,
		Parent = track,
	})
	Utils.Corner(knob, 7)

	self._parts = { Track = track, Knob = knob, Stroke = stroke, KnobSize = 14, KnobInset = 3 }
	animation:Toggle(self._parts, self.Value, true)

	Utils.BindRowFeedback(ctx, row, row.Root, self.Maid, function()
		return self.Disabled
	end)

	self.Maid:Give(row.Root.Activated:Connect(function()
		if not self.Disabled then
			self:Set(not self.Value)
		end
	end))

	return self
end

function Toggle:Set(value, silent)
	value = value and true or false
	if value == self.Value then
		return
	end
	self.Value = value
	self.ctx.Animation:Toggle(self._parts, value, false)
	self.Changed:Fire(value)
	if not silent then
		self.ctx.Utils.Safe(self.Callback, value)
	end
end

function Toggle:Get()
	return self.Value
end

function Toggle:Toggle()
	self:Set(not self.Value)
end

return Toggle
