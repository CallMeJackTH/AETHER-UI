--[[
	Divider.lua  -  hairline separator with optional centred caption.
	Divider.new(ctx, parent, config, section)
	  config: Text | Name (optional)
	  :Set(text)  :Get()
]]

local Divider = {}
Divider.__index = Divider

function Divider.new(ctx, parent, config)
	local self = setmetatable({}, Divider)
	local Utils, theme = ctx.Utils, ctx.Theme
	local colors = theme.Colors

	self.Maid = Utils.Maid.new()
	self.Searchable = false
	self.Text = tostring(config.Text or config.Name or "")

	self.Root = Utils.Create("Frame", {
		Name = "Divider",
		Size = UDim2.new(1, 0, 0, 16),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		Parent = parent,
	})

	local function line(name, anchorX, positionX)
		return Utils.Create("Frame", {
			Name = name,
			AnchorPoint = Vector2.new(anchorX, 0.5),
			Position = UDim2.new(positionX, 0, 0.5, 0),
			Size = UDim2.new(1, 0, 0, 1),
			BackgroundColor3 = colors.Border,
			BackgroundTransparency = 0.3,
			BorderSizePixel = 0,
			Parent = self.Root,
		})
	end

	self.Left = line("Left", 0, 0)
	self.Right = line("Right", 1, 1)
	self.Caption = Utils.Text(theme, self.Root, {
		Name = "Caption",
		Font = theme.Fonts.SemiBold,
		TextSize = theme.Sizes.Tiny,
		TextColor3 = colors.Subtle,
		TextXAlignment = Enum.TextXAlignment.Center,
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.new(0.5, 0, 0.5, 0),
	})

	self:Set(self.Text)
	return self
end

function Divider:Set(text)
	self.Text = tostring(text or "")
	local hasText = self.Text ~= ""
	self.Caption.Visible = hasText
	self.Caption.Text = string.upper(self.Text)

	if hasText then
		local width = self.Caption.TextBounds.X
		if width <= 0 then
			width = #self.Text * 7
		end
		self.Caption.Size = UDim2.fromOffset(width + 4, 14)
		local half = width / 2 + 10
		self.Left.Size = UDim2.new(0.5, -half, 0, 1)
		self.Right.Size = UDim2.new(0.5, -half, 0, 1)
	else
		self.Left.Size = UDim2.new(1, 0, 0, 1)
		self.Right.Size = UDim2.new(0, 0, 0, 1)
	end
end

function Divider:Get()
	return self.Text
end

return Divider
