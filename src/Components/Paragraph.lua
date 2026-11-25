--[[
	Paragraph.lua  -  titled card with wrapped body text.
	Paragraph.new(ctx, parent, config, section)
	  config: Title | Name, Content | Text
	  :Set(content)  :Get()  :SetTitle(text)
]]

local Paragraph = {}
Paragraph.__index = Paragraph

function Paragraph.new(ctx, parent, config)
	local self = setmetatable({}, Paragraph)
	local Utils, theme = ctx.Utils, ctx.Theme
	local colors, fonts, sizes = theme.Colors, theme.Fonts, theme.Sizes

	self.Maid = Utils.Maid.new()
	self.Content = tostring(config.Content or config.Text or "")
	local title = tostring(config.Title or config.Name or "")

	local root = Utils.Create("Frame", {
		Name = "Paragraph",
		Size = UDim2.new(1, 0, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundColor3 = colors.Secondary,
		BackgroundTransparency = theme.Transparency.Row,
		BorderSizePixel = 0,
		Parent = parent,
	})
	Utils.Corner(root, theme.Layout.RadiusControl)
	Utils.Stroke(root, colors.Border, 1, theme.Transparency.Stroke)
	Utils.Padding(root, 10, theme.Layout.Padding, 10, theme.Layout.Padding)
	Utils.List(root, 4)

	self.TitleLabel = Utils.Text(theme, root, {
		Name = "Title",
		Text = title,
		Font = fonts.SemiBold,
		TextSize = sizes.Body,
		TextWrapped = true,
		AutomaticSize = Enum.AutomaticSize.Y,
		Size = UDim2.new(1, 0, 0, 18),
		Visible = title ~= "",
		LayoutOrder = 1,
	})

	self.Body = Utils.Text(theme, root, {
		Name = "Content",
		Text = self.Content,
		Font = fonts.Regular,
		TextSize = sizes.Small + 1,
		TextColor3 = colors.Muted,
		TextWrapped = true,
		TextYAlignment = Enum.TextYAlignment.Top,
		AutomaticSize = Enum.AutomaticSize.Y,
		Size = UDim2.new(1, 0, 0, 16),
		LayoutOrder = 2,
	})

	self.Root = root
	self.Title = title
	return self
end

function Paragraph:Set(content)
	self.Content = tostring(content)
	self.Body.Text = self.Content
	if self._item then
		self._item.Description = self.Content
	end
end

function Paragraph:Get()
	return self.Content
end

function Paragraph:SetTitle(title)
	self.Title = tostring(title)
	self.TitleLabel.Text = self.Title
	self.TitleLabel.Visible = self.Title ~= ""
	if self._item then
		self._item.Name = self.Title
	end
end

return Paragraph
