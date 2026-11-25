--[[
	Label.lua  -  plain themed text line.
	Label.new(ctx, parent, config, section)
	  config: Text | Name, Color
	  :Set(text)  :Get()  :SetColor(color3)
]]

local Label = {}
Label.__index = Label

function Label.new(ctx, parent, config)
	local self = setmetatable({}, Label)
	local Utils, theme = ctx.Utils, ctx.Theme

	self.Maid = Utils.Maid.new()
	self.Text = tostring(config.Text or config.Name or "")

	self.Root = Utils.Text(theme, parent, {
		Name = "Label",
		Text = self.Text,
		Font = theme.Fonts.Regular,
		TextSize = theme.Sizes.Small + 1,
		TextColor3 = config.Color or theme.Colors.Muted,
		TextWrapped = true,
		TextYAlignment = Enum.TextYAlignment.Top,
		AutomaticSize = Enum.AutomaticSize.Y,
		Size = UDim2.new(1, 0, 0, 18),
	})
	Utils.Padding(self.Root, 2, 4, 2, 4)
	self.Label = self.Root
	return self
end

function Label:Set(text)
	self.Text = tostring(text)
	self.Root.Text = self.Text
	if self._item then
		self._item.Name = self.Text
	end
end

function Label:Get()
	return self.Text
end

function Label:SetColor(color)
	self.Root.TextColor3 = color
end

return Label
