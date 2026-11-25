--[[
	Button.lua  -  full-width action row.
	Button.new(ctx, parent, config, section)
	  config: Name | Text, Description, Callback, Style = Default|Primary|Danger|Ghost,
	          Icon (optional icon name shown on the right)
	  :Set(text) / :Get()      label text
	  :SetStyle(name)          :Fire()  (alias :Click())
	  .Clicked                 Signal
]]

local Button = {}
Button.__index = Button

function Button.new(ctx, parent, config)
	local self = setmetatable({}, Button)
	local Utils, theme, animation = ctx.Utils, ctx.Theme, ctx.Animation

	self.ctx = ctx
	self.Maid = Utils.Maid.new()
	self.Callback = config.Callback
	self.Variant = config.Style or "Default"
	self.Clicked = Utils.Signal.new()
	self.Maid:Give(self.Clicked)
	self.Disabled = false

	local row = Utils.CreateRow(ctx, parent, config, { Interactive = true, Reserve = 26 })
	self.Row = row
	self.Root = row.Root
	self.Text = row.Title.Text

	local customIcon = config.Icon and Utils.HasIcon(config.Icon)
	self.Icon = Utils.Icon(customIcon and config.Icon or "chevron", row.Root, theme.Colors.Muted, {
		Size = UDim2.fromOffset(14, 14),
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(1, -row.Padding, 0.5, 0),
	})
	if not customIcon then
		self.Icon.Frame.Rotation = -90
	end

	self._parts = {
		Root = row.Root,
		Stroke = row.Stroke,
		Label = row.Title,
		Description = row.Description,
		Icon = self.Icon,
	}

	local hovering, pressing = false, false
	local function state()
		return pressing and "Pressed" or (hovering and "Hover" or "Idle")
	end
	self._refresh = function()
		animation:Button(self._parts, self.Variant, state())
	end

	-- Initial look without a tween.
	local style = animation:ButtonStyle(self.Variant, "Idle")
	row.Root.BackgroundColor3 = style.Background
	row.Root.BackgroundTransparency = style.BackgroundTransparency
	row.Stroke.Color = style.Stroke
	row.Stroke.Transparency = style.StrokeTransparency
	row.Title.TextColor3 = style.Text
	if row.Description then
		row.Description.TextColor3 = style.Description
	end
	self.Icon:SetColor(style.Text)

	Utils.BindInteract(row.Root, self.Maid, {
		Hover = function(hover)
			hovering = hover
			if not self.Disabled then
				self._refresh()
			end
		end,
		Press = function(pressed)
			pressing = pressed
			if not self.Disabled then
				self._refresh()
			end
		end,
	})

	self.Maid:Give(row.Root.Activated:Connect(function()
		if not self.Disabled then
			self:Fire()
		end
	end))

	return self
end

function Button:Fire()
	if self.Disabled then
		return
	end
	self.ctx.Utils.Safe(self.Callback)
	self.Clicked:Fire()
end

Button.Click = Button.Fire

function Button:Set(text)
	self.Text = tostring(text)
	self.Row.Title.Text = self.Text
	if self._item then
		self._item.Name = self.Text
	end
end

function Button:Get()
	return self.Text
end

function Button:SetStyle(name)
	self.Variant = name
	self._refresh()
end

return Button
