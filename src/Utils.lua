--[[
	Utils.lua
	Dependency-free helpers shared by every module:
	  * Signal / Maid         - events and lifetime management
	  * Instance builders     - Create, Corner, Stroke, Padding, List, Text
	  * Shared UI builders    - CreateRow, CreateDisabler, Shadow, Icon
	  * Input helpers         - BindInteract, BindDrag, BindOutsideClick
	  * Misc                  - math, color and text measurement helpers
	  * CreateButton          - compact standalone button used by dialogs and lists

	Utils never requires another AETHER module. Builders that need styling
	receive the Theme as an explicit argument.
]]

local UserInputService = game:GetService("UserInputService")
local TextService = game:GetService("TextService")
local GuiService = game:GetService("GuiService")

local Utils = {}

----------------------------------------------------------------------
-- Signal
----------------------------------------------------------------------

local Signal = {}
Signal.__index = Signal

function Signal.new()
	return setmetatable({ _connections = {}, _destroyed = false }, Signal)
end

function Signal:Connect(callback)
	assert(type(callback) == "function", "Signal:Connect expects a function")

	local connection = { Connected = true, _callback = callback, _signal = self }

	function connection.Disconnect(conn)
		if not conn.Connected then
			return
		end
		conn.Connected = false
		local list = conn._signal._connections
		local index = table.find(list, conn)
		if index then
			table.remove(list, index)
		end
	end

	if self._destroyed then
		connection.Connected = false
		return connection
	end

	table.insert(self._connections, connection)
	return connection
end

function Signal:Once(callback)
	local connection
	connection = self:Connect(function(...)
		connection:Disconnect()
		callback(...)
	end)
	return connection
end

function Signal:Fire(...)
	if self._destroyed then
		return
	end
	local snapshot = table.clone(self._connections)
	for _, connection in ipairs(snapshot) do
		if connection.Connected then
			task.spawn(connection._callback, ...)
		end
	end
end

function Signal:Destroy()
	self._destroyed = true
	for _, connection in ipairs(self._connections) do
		connection.Connected = false
	end
	table.clear(self._connections)
end

Utils.Signal = Signal

----------------------------------------------------------------------
-- Maid
----------------------------------------------------------------------

local Maid = {}
Maid.__index = Maid

function Maid.new()
	return setmetatable({ _tasks = {}, _destroyed = false }, Maid)
end

local function cleanTask(item)
	local kind = typeof(item)
	if kind == "RBXScriptConnection" then
		item:Disconnect()
	elseif kind == "Instance" then
		item:Destroy()
	elseif kind == "function" then
		item()
	elseif kind == "thread" then
		pcall(task.cancel, item)
	elseif kind == "table" then
		if type(item.Disconnect) == "function" then
			item:Disconnect()
		elseif type(item.Destroy) == "function" then
			item:Destroy()
		end
	end
end

function Maid:Give(item)
	if item == nil then
		return nil
	end
	if self._destroyed then
		pcall(cleanTask, item)
		return item
	end
	table.insert(self._tasks, item)
	return item
end

function Maid:Clean()
	local tasks = self._tasks
	self._tasks = {}
	for index = #tasks, 1, -1 do
		local ok, err = pcall(cleanTask, tasks[index])
		if not ok then
			warn("[AetherUI] cleanup error: " .. tostring(err))
		end
	end
end

function Maid:Destroy()
	self._destroyed = true
	self:Clean()
end

Utils.Maid = Maid

----------------------------------------------------------------------
-- Generic helpers
----------------------------------------------------------------------

function Utils.Safe(callback, ...)
	if type(callback) ~= "function" then
		return false
	end
	local ok, err = pcall(callback, ...)
	if not ok then
		warn("[AetherUI] callback error: " .. tostring(err))
	end
	return ok
end

function Utils.DeepCopy(value, seen)
	if type(value) ~= "table" then
		return value
	end
	seen = seen or {}
	if seen[value] then
		return seen[value]
	end
	local copy = {}
	seen[value] = copy
	for key, item in pairs(value) do
		copy[Utils.DeepCopy(key, seen)] = Utils.DeepCopy(item, seen)
	end
	return copy
end

function Utils.Trim(text)
	return (tostring(text):gsub("^%s+", ""):gsub("%s+$", ""))
end

function Utils.Clamp(value, low, high)
	if high < low then
		return low
	end
	return math.max(low, math.min(high, value))
end

function Utils.Round(value, step)
	if not step or step <= 0 then
		return value
	end
	return math.floor(value / step + 0.5) * step
end

function Utils.Decimals(step)
	local text = string.format("%.6f", step)
	text = text:gsub("0+$", "")
	local decimals = text:match("%.(%d*)$")
	return decimals and #decimals or 0
end

function Utils.FormatNumber(value, decimals)
	return string.format("%." .. tostring(decimals or 0) .. "f", value)
end

function Utils.ColorToHex(color)
	return string.format(
		"%02X%02X%02X",
		math.floor(color.R * 255 + 0.5),
		math.floor(color.G * 255 + 0.5),
		math.floor(color.B * 255 + 0.5)
	)
end

function Utils.HexToColor(text)
	local hex = tostring(text):gsub("#", ""):gsub("%s", "")
	if #hex ~= 6 or not hex:match("^%x+$") then
		return nil
	end
	return Color3.fromRGB(
		tonumber(hex:sub(1, 2), 16),
		tonumber(hex:sub(3, 4), 16),
		tonumber(hex:sub(5, 6), 16)
	)
end

function Utils.TextSize(text, font, size, width)
	local ok, result = pcall(function()
		return TextService:GetTextSize(text, size, font, Vector2.new(width or 10000, 10000))
	end)
	if ok then
		return result
	end
	return Vector2.new(#text * size * 0.55, size + 2)
end

function Utils.IsTouch()
	return UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled
end

function Utils.GetViewport(gui)
	local size = gui and gui.AbsoluteSize or Vector2.new(0, 0)
	if size.X < 2 or size.Y < 2 then
		local camera = workspace.CurrentCamera
		size = camera and camera.ViewportSize or Vector2.new(1280, 720)
	end
	return size
end

function Utils.IsPointerInput(input)
	local kind = input.UserInputType
	return kind == Enum.UserInputType.MouseButton1 or kind == Enum.UserInputType.Touch
end

-- Converts an InputObject position to the coordinate space of a ScreenGui
-- that has IgnoreGuiInset = true (the only kind AETHER creates).
function Utils.InputPosition(input)
	local inset = GuiService:GetGuiInset()
	return Vector2.new(input.Position.X + inset.X, input.Position.Y + inset.Y)
end

function Utils.IsPointInside(gui, point)
	local position, size = gui.AbsolutePosition, gui.AbsoluteSize
	return point.X >= position.X
		and point.X <= position.X + size.X
		and point.Y >= position.Y
		and point.Y <= position.Y + size.Y
end

----------------------------------------------------------------------
-- Instance builders
----------------------------------------------------------------------

function Utils.Create(className, props, children)
	local instance = Instance.new(className)
	local parent
	if props then
		for key, value in pairs(props) do
			if key == "Parent" then
				parent = value
			else
				instance[key] = value
			end
		end
	end
	if children then
		for _, child in ipairs(children) do
			child.Parent = instance
		end
	end
	if parent then
		instance.Parent = parent
	end
	return instance
end

function Utils.Corner(parent, radius)
	return Utils.Create("UICorner", {
		CornerRadius = typeof(radius) == "UDim" and radius or UDim.new(0, radius or 6),
		Parent = parent,
	})
end

function Utils.Stroke(parent, color, thickness, transparency)
	return Utils.Create("UIStroke", {
		Color = color,
		Thickness = thickness or 1,
		Transparency = transparency or 0,
		ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
		Parent = parent,
	})
end

function Utils.Padding(parent, top, right, bottom, left)
	right = right or top
	bottom = bottom or top
	left = left or right
	return Utils.Create("UIPadding", {
		PaddingTop = UDim.new(0, top or 0),
		PaddingRight = UDim.new(0, right or 0),
		PaddingBottom = UDim.new(0, bottom or 0),
		PaddingLeft = UDim.new(0, left or 0),
		Parent = parent,
	})
end

function Utils.List(parent, padding, direction, horizontal, vertical)
	return Utils.Create("UIListLayout", {
		Padding = UDim.new(0, padding or 0),
		FillDirection = direction or Enum.FillDirection.Vertical,
		HorizontalAlignment = horizontal or Enum.HorizontalAlignment.Left,
		VerticalAlignment = vertical or Enum.VerticalAlignment.Top,
		SortOrder = Enum.SortOrder.LayoutOrder,
		Parent = parent,
	})
end

-- Themed TextLabel. `props` override the defaults.
function Utils.Text(theme, parent, props)
	local label = Instance.new("TextLabel")
	label.BackgroundTransparency = 1
	label.BorderSizePixel = 0
	label.Font = theme.Fonts.Medium
	label.TextSize = theme.Sizes.Body
	label.TextColor3 = theme.Colors.Text
	label.TextXAlignment = Enum.TextXAlignment.Left
	label.TextYAlignment = Enum.TextYAlignment.Center
	label.Text = ""
	if props then
		for key, value in pairs(props) do
			label[key] = value
		end
	end
	label.Parent = parent
	return label
end

----------------------------------------------------------------------
-- Shared visual building blocks
----------------------------------------------------------------------

-- Dimming overlay used for every component's disabled state. Animation:Disabled
-- fades it in and flips `Active` so it also blocks input.
function Utils.CreateDisabler(theme, parent, radius)
	local overlay = Utils.Create("Frame", {
		Name = "Disabler",
		Size = UDim2.new(1, 0, 1, 0),
		BackgroundColor3 = theme.Colors.Background,
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		Active = false,
		Visible = false,
		ZIndex = 20,
		Parent = parent,
	})
	Utils.Corner(overlay, radius or theme.Layout.RadiusControl)
	return overlay
end

-- Standard component row: rounded Secondary surface, hairline border, title,
-- optional description and a disabler overlay.
--   config:  Name | Title | Text, Description
--   options: Interactive (TextButton root), Height, TopAligned, Reserve (px),
--            ReserveScale (0-1), ClipsDescendants, Name
function Utils.CreateRow(ctx, parent, config, options)
	options = options or {}
	local theme = ctx.Theme
	local colors, fonts, sizes, layout = theme.Colors, theme.Fonts, theme.Sizes, theme.Layout
	local pad = layout.Padding

	local title = tostring(config.Name or config.Title or config.Text or "")
	local description = config.Description
	local hasDescription = description ~= nil and description ~= ""
	local height = options.Height or (hasDescription and (ctx.RowHeight + 14) or ctx.RowHeight)

	local props = {
		Name = options.Name or (title ~= "" and title or "Row"),
		Size = UDim2.new(1, 0, 0, height),
		BackgroundColor3 = colors.Secondary,
		BackgroundTransparency = theme.Transparency.Row,
		BorderSizePixel = 0,
		ClipsDescendants = options.ClipsDescendants or false,
		Parent = parent,
	}

	local root
	if options.Interactive then
		props.Text = ""
		props.AutoButtonColor = false
		root = Utils.Create("TextButton", props)
	else
		root = Utils.Create("Frame", props)
	end

	Utils.Corner(root, layout.RadiusControl)
	local stroke = Utils.Stroke(root, colors.Border, 1, theme.Transparency.Stroke)

	local reserve = options.Reserve or 0
	local reserveScale = options.ReserveScale or 0
	local titleSize = UDim2.new(1 - reserveScale, -(pad * 2 + reserve), 0, 18)
	local stacked = hasDescription or options.TopAligned

	local titleLabel = Utils.Text(theme, root, {
		Name = "Title",
		Text = title,
		Font = fonts.Medium,
		TextSize = sizes.Body,
		TextColor3 = colors.Text,
		TextTruncate = Enum.TextTruncate.AtEnd,
		AnchorPoint = stacked and Vector2.new(0, 0) or Vector2.new(0, 0.5),
		Position = stacked and UDim2.fromOffset(pad, 8) or UDim2.new(0, pad, 0.5, 0),
		Size = titleSize,
	})

	local descriptionLabel = nil
	if hasDescription then
		descriptionLabel = Utils.Text(theme, root, {
			Name = "Description",
			Text = tostring(description),
			Font = fonts.Regular,
			TextSize = sizes.Small,
			TextColor3 = colors.Muted,
			TextTruncate = Enum.TextTruncate.AtEnd,
			Position = UDim2.fromOffset(pad, 26),
			Size = UDim2.new(1 - reserveScale, -(pad * 2 + reserve), 0, 16),
		})
	end

	local disabler = Utils.CreateDisabler(theme, root, layout.RadiusControl)

	return {
		Root = root,
		Stroke = stroke,
		Title = titleLabel,
		Description = descriptionLabel,
		Disabler = disabler,
		Padding = pad,
		Height = height,
	}
end

-- Hover + pressed feedback shared by every row-style component.
function Utils.BindRowFeedback(ctx, row, target, maid, isDisabled, extra)
	local animation = ctx.Animation
	local colors = ctx.Theme.Colors
	local hovering = false

	Utils.BindInteract(target, maid, {
		Hover = function(hover)
			hovering = hover
			if isDisabled and isDisabled() then
				return
			end
			animation:Play(row.Root, "Hover", { BackgroundColor3 = hover and colors.Elevated or colors.Secondary })
			animation:Play(row.Stroke, "Hover", { Color = hover and colors.BorderHover or colors.Border })
			if extra and extra.Hover then
				extra.Hover(hover)
			end
		end,
		Press = function(pressed)
			if isDisabled and isDisabled() then
				return
			end
			animation:Play(row.Root, "Press", {
				BackgroundColor3 = pressed and colors.Pressed or (hovering and colors.Elevated or colors.Secondary),
			})
			if extra and extra.Press then
				extra.Press(pressed)
			end
		end,
	})
end

-- Layered translucent frames approximating a soft drop shadow.
-- Returns { Frame = container, Layers = { { Instance, Base }, ... } }.
function Utils.Shadow(parent, radius, spread, offsetY, alpha)
	local container = Utils.Create("Frame", {
		Name = "Shadow",
		Size = UDim2.new(1, 0, 1, 0),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ZIndex = 1,
		Parent = parent,
	})

	local layers = {}
	local count = 6
	for index = 1, count do
		local grow = spread * index / count
		local base = 1 - (alpha or 0.06)
		local layer = Utils.Create("Frame", {
			Name = "Layer" .. index,
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.new(0.5, 0, 0.5, offsetY or 0),
			Size = UDim2.new(1, grow * 2, 1, grow * 2),
			BackgroundColor3 = Color3.new(0, 0, 0),
			BackgroundTransparency = base,
			BorderSizePixel = 0,
			Parent = container,
		})
		Utils.Corner(layer, radius + grow)
		table.insert(layers, { Instance = layer, Base = base })
	end

	return { Frame = container, Layers = layers }
end

----------------------------------------------------------------------
-- Icons (pure Instance vector icons - no asset ids required)
-- Shapes live in a unit square:
--   bar     {cx, cy, length, thickness, rotation}
--   dot     {cx, cy, diameter}
--   box     {x, y, w, h, cornerScale, rotation}
--   ring    {cx, cy, diameter}                 (stroke only)
--   outline {x, y, w, h, cornerScale, rotation} (stroke only)
----------------------------------------------------------------------

local ICONS = {
	close = { { "bar", 0.5, 0.5, 0.78, 0.11, 45 }, { "bar", 0.5, 0.5, 0.78, 0.11, -45 } },
	minimize = { { "bar", 0.5, 0.5, 0.72, 0.11, 0 } },
	plus = { { "bar", 0.5, 0.5, 0.72, 0.11, 0 }, { "bar", 0.5, 0.5, 0.72, 0.11, 90 } },
	chevron = { { "bar", 0.35, 0.5, 0.42, 0.11, 45 }, { "bar", 0.65, 0.5, 0.42, 0.11, -45 } },
	check = { { "bar", 0.31, 0.63, 0.31, 0.12, 45 }, { "bar", 0.61, 0.52, 0.58, 0.12, -49 } },
	search = { { "ring", 0.4, 0.4, 0.62 }, { "bar", 0.77, 0.77, 0.34, 0.12, 45 } },
	info = { { "dot", 0.5, 0.25, 0.16 }, { "bar", 0.5, 0.65, 0.42, 0.12, 90 } },
	warning = { { "bar", 0.5, 0.4, 0.44, 0.12, 90 }, { "dot", 0.5, 0.78, 0.16 } },
	dashboard = {
		{ "box", 0.12, 0.12, 0.33, 0.33, 0.22, 0 },
		{ "box", 0.55, 0.12, 0.33, 0.33, 0.22, 0 },
		{ "box", 0.12, 0.55, 0.33, 0.33, 0.22, 0 },
		{ "box", 0.55, 0.55, 0.33, 0.33, 0.22, 0 },
	},
	components = {
		{ "box", 0.12, 0.12, 0.34, 0.34, 0.2, 0 },
		{ "dot", 0.71, 0.29, 0.34 },
		{ "box", 0.12, 0.54, 0.34, 0.34, 0.2, 0 },
		{ "box", 0.57, 0.57, 0.28, 0.28, 0.12, 45 },
	},
	settings = {
		{ "bar", 0.5, 0.24, 0.76, 0.08, 0 },
		{ "bar", 0.5, 0.5, 0.76, 0.08, 0 },
		{ "bar", 0.5, 0.76, 0.76, 0.08, 0 },
		{ "dot", 0.32, 0.24, 0.26 },
		{ "dot", 0.68, 0.5, 0.26 },
		{ "dot", 0.42, 0.76, 0.26 },
	},
	configurations = {
		{ "outline", 0.2, 0.08, 0.6, 0.84, 0.12, 0 },
		{ "bar", 0.5, 0.36, 0.32, 0.07, 0 },
		{ "bar", 0.5, 0.52, 0.32, 0.07, 0 },
		{ "bar", 0.42, 0.68, 0.16, 0.07, 0 },
	},
	showcase = {
		{ "bar", 0.5, 0.5, 0.82, 0.1, 0 },
		{ "bar", 0.5, 0.5, 0.82, 0.1, 90 },
		{ "bar", 0.5, 0.5, 0.52, 0.08, 45 },
		{ "bar", 0.5, 0.5, 0.52, 0.08, -45 },
	},
	notifications = {
		{ "box", 0.2, 0.12, 0.6, 0.58, 0.5, 0 },
		{ "bar", 0.5, 0.78, 0.74, 0.1, 0 },
		{ "dot", 0.5, 0.9, 0.14 },
	},
	modals = {
		{ "outline", 0.1, 0.18, 0.8, 0.64, 0.14, 0 },
		{ "box", 0.28, 0.4, 0.44, 0.2, 0.25, 0 },
	},
	logo = {
		{ "outline", 0.25, 0.25, 0.5, 0.5, 0.12, 45 },
		{ "box", 0.38, 0.38, 0.24, 0.24, 0.12, 45 },
	},
}
ICONS.success = ICONS.check
ICONS.error = ICONS.close

local Icon = {}
Icon.__index = Icon

function Icon:SetColor(color)
	self.Color = color
	for _, target in ipairs(self.Targets) do
		target.Instance[target.Property] = color
	end
end

function Icon:SetTransparency(value)
	for _, target in ipairs(self.Targets) do
		target.Instance[target.Alpha] = value
	end
end

function Icon:Destroy()
	self.Frame:Destroy()
end

local function addIconPart(container, targets, spec, color, thickness)
	local kind = spec[1]
	local frame = Instance.new("Frame")
	frame.BorderSizePixel = 0
	frame.BackgroundColor3 = color

	local stroked = false
	local cornerScale = 0

	if kind == "bar" then
		frame.AnchorPoint = Vector2.new(0.5, 0.5)
		frame.Position = UDim2.fromScale(spec[2], spec[3])
		frame.Size = UDim2.fromScale(spec[4], spec[5])
		frame.Rotation = spec[6] or 0
		cornerScale = 0.5
	elseif kind == "dot" then
		frame.AnchorPoint = Vector2.new(0.5, 0.5)
		frame.Position = UDim2.fromScale(spec[2], spec[3])
		frame.Size = UDim2.fromScale(spec[4], spec[4])
		cornerScale = 0.5
	elseif kind == "box" then
		frame.Position = UDim2.fromScale(spec[2], spec[3])
		frame.Size = UDim2.fromScale(spec[4], spec[5])
		frame.Rotation = spec[7] or 0
		cornerScale = spec[6] or 0
	elseif kind == "ring" then
		frame.AnchorPoint = Vector2.new(0.5, 0.5)
		frame.Position = UDim2.fromScale(spec[2], spec[3])
		frame.Size = UDim2.fromScale(spec[4], spec[4])
		cornerScale = 0.5
		stroked = true
	elseif kind == "outline" then
		frame.Position = UDim2.fromScale(spec[2], spec[3])
		frame.Size = UDim2.fromScale(spec[4], spec[5])
		frame.Rotation = spec[7] or 0
		cornerScale = spec[6] or 0
		stroked = true
	end

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(cornerScale, 0)
	corner.Parent = frame

	if stroked then
		frame.BackgroundTransparency = 1
		local stroke = Instance.new("UIStroke")
		stroke.Color = color
		stroke.Thickness = thickness
		stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
		stroke.Parent = frame
		table.insert(targets, { Instance = stroke, Property = "Color", Alpha = "Transparency" })
	else
		table.insert(targets, { Instance = frame, Property = "BackgroundColor3", Alpha = "BackgroundTransparency" })
	end

	frame.Parent = container
end

-- props: Name, Size, Position, AnchorPoint, Thickness, LayoutOrder, Parent override
function Utils.Icon(name, parent, color, props)
	local spec = ICONS[name]
	if not spec then
		error("[AetherUI] Unknown icon: " .. tostring(name), 2)
	end
	props = props or {}

	local container = Instance.new("Frame")
	container.Name = props.Name or ("Icon_" .. name)
	container.BackgroundTransparency = 1
	container.BorderSizePixel = 0
	container.Size = props.Size or UDim2.fromOffset(16, 16)
	container.Position = props.Position or UDim2.new()
	container.AnchorPoint = props.AnchorPoint or Vector2.new(0, 0)
	container.LayoutOrder = props.LayoutOrder or 0

	local targets = {}
	for _, part in ipairs(spec) do
		addIconPart(container, targets, part, color, props.Thickness or 1.5)
	end
	container.Parent = parent

	return setmetatable({ Frame = container, Targets = targets, Color = color }, Icon)
end

function Utils.HasIcon(name)
	return ICONS[name] ~= nil
end

----------------------------------------------------------------------
-- Input helpers
----------------------------------------------------------------------

-- Consistent hover/press detection for mouse and touch.
-- handlers: Hover(bool), Press(bool)
function Utils.BindInteract(gui, maid, handlers)
	local pressing = false

	maid:Give(gui.MouseEnter:Connect(function()
		if handlers.Hover then
			handlers.Hover(true)
		end
	end))

	maid:Give(gui.MouseLeave:Connect(function()
		if pressing then
			pressing = false
			if handlers.Press then
				handlers.Press(false)
			end
		end
		if handlers.Hover then
			handlers.Hover(false)
		end
	end))

	maid:Give(gui.InputBegan:Connect(function(input)
		if Utils.IsPointerInput(input) then
			pressing = true
			if handlers.Press then
				handlers.Press(true)
			end
		end
	end))

	maid:Give(gui.InputEnded:Connect(function(input)
		if Utils.IsPointerInput(input) and pressing then
			pressing = false
			if handlers.Press then
				handlers.Press(false)
			end
		end
	end))
end

-- Temporarily disables the nearest ScrollingFrame ancestor (so horizontal
-- drags on sliders do not scroll the page on touch devices).
function Utils.LockScroll(gui)
	local scroller = gui:FindFirstAncestorWhichIsA("ScrollingFrame")
	if not scroller then
		return nil
	end
	local previous = scroller.ScrollingEnabled
	scroller.ScrollingEnabled = false
	return function()
		if scroller.Parent then
			scroller.ScrollingEnabled = previous
		end
	end
end

-- Mouse + touch drag tracking.
-- callbacks: CanBegin(input) -> bool, Began(input), Changed(input), Ended(input),
--            NoScrollLock (bool)
-- Returns a function that force-ends the current drag.
function Utils.BindDrag(gui, maid, callbacks)
	local dragMaid = Maid.new()
	maid:Give(dragMaid)

	local activeInput = nil
	local restoreScroll = nil

	local function finish()
		if not activeInput then
			return
		end
		local input = activeInput
		activeInput = nil
		dragMaid:Clean()
		if restoreScroll then
			restoreScroll()
			restoreScroll = nil
		end
		if callbacks.Ended then
			Utils.Safe(callbacks.Ended, input)
		end
	end

	maid:Give(gui.InputBegan:Connect(function(input)
		if activeInput or not Utils.IsPointerInput(input) then
			return
		end
		if callbacks.CanBegin and not callbacks.CanBegin(input) then
			return
		end

		activeInput = input
		if not callbacks.NoScrollLock then
			restoreScroll = Utils.LockScroll(gui)
		end
		if callbacks.Began then
			Utils.Safe(callbacks.Began, input)
		end

		dragMaid:Give(UserInputService.InputChanged:Connect(function(changed)
			if not activeInput then
				return
			end
			local isMouseMove = changed.UserInputType == Enum.UserInputType.MouseMovement
				and activeInput.UserInputType == Enum.UserInputType.MouseButton1
			if isMouseMove or changed == activeInput then
				if callbacks.Changed then
					Utils.Safe(callbacks.Changed, changed)
				end
			end
		end))

		dragMaid:Give(UserInputService.InputEnded:Connect(function(ended)
			if not activeInput then
				return
			end
			local mouseRelease = ended.UserInputType == Enum.UserInputType.MouseButton1
				and activeInput.UserInputType == Enum.UserInputType.MouseButton1
			if ended == activeInput or mouseRelease then
				finish()
			end
		end))
	end))

	maid:Give(finish)
	return finish
end

-- Calls `callback(input)` when a pointer press lands outside `gui`.
-- Returns the connection (caller owns disconnecting it).
function Utils.BindOutsideClick(gui, callback)
	return UserInputService.InputBegan:Connect(function(input)
		local kind = input.UserInputType
		if kind ~= Enum.UserInputType.MouseButton1
			and kind ~= Enum.UserInputType.MouseButton2
			and kind ~= Enum.UserInputType.Touch then
			return
		end
		if not Utils.IsPointInside(gui, Utils.InputPosition(input)) then
			callback(input)
		end
	end)
end

----------------------------------------------------------------------
-- Standalone button
----------------------------------------------------------------------

-- options: Text, Style (Default | Primary | Danger | Ghost), Width, Height, Size,
--          Position, AnchorPoint, LayoutOrder, Name, Callback, Maid
-- Returns { Instance, Label, Stroke, Maid, SetText, SetStyle, SetDisabled, Destroy }
function Utils.CreateButton(ctx, parent, options)
	options = options or {}
	local theme, animation = ctx.Theme, ctx.Animation
	local ownMaid = options.Maid == nil
	local maid = options.Maid or Maid.new()

	local button = { Style = options.Style or "Default", Disabled = false, Maid = maid }
	local text = tostring(options.Text or "Button")
	local height = options.Height or ctx.ButtonHeight
	local width = options.Width or (Utils.TextSize(text, theme.Fonts.Medium, theme.Sizes.Body).X + 28)
	local style = animation:ButtonStyle(button.Style, "Idle")

	local root = Utils.Create("TextButton", {
		Name = options.Name or "Button",
		Text = "",
		AutoButtonColor = false,
		BackgroundColor3 = style.Background,
		BackgroundTransparency = style.BackgroundTransparency,
		BorderSizePixel = 0,
		Size = options.Size or UDim2.fromOffset(width, height),
		Position = options.Position or UDim2.new(),
		AnchorPoint = options.AnchorPoint or Vector2.new(0, 0),
		LayoutOrder = options.LayoutOrder or 0,
		Parent = parent,
	})
	Utils.Corner(root, theme.Layout.RadiusControl)
	local stroke = Utils.Stroke(root, style.Stroke, 1, style.StrokeTransparency)
	local label = Utils.Text(theme, root, {
		Name = "Label",
		Text = text,
		Font = theme.Fonts.Medium,
		TextSize = theme.Sizes.Body,
		TextColor3 = style.Text,
		TextXAlignment = Enum.TextXAlignment.Center,
		Size = UDim2.new(1, 0, 1, 0),
	})
	local disabler = Utils.CreateDisabler(theme, root, theme.Layout.RadiusControl)

	local parts = { Root = root, Stroke = stroke, Label = label }
	local hovering, pressing = false, false

	local function refresh()
		animation:Button(parts, button.Style, pressing and "Pressed" or (hovering and "Hover" or "Idle"))
	end

	Utils.BindInteract(root, maid, {
		Hover = function(hover)
			hovering = hover
			if not button.Disabled then
				refresh()
			end
		end,
		Press = function(pressed)
			pressing = pressed
			if not button.Disabled then
				refresh()
			end
		end,
	})

	maid:Give(root.Activated:Connect(function()
		if not button.Disabled then
			Utils.Safe(options.Callback)
		end
	end))

	button.Instance = root
	button.Label = label
	button.Stroke = stroke

	function button:SetText(value)
		label.Text = tostring(value)
	end

	function button:SetStyle(name)
		self.Style = name
		refresh()
	end

	function button:SetDisabled(disabled)
		self.Disabled = disabled and true or false
		animation:Disabled(disabler, self.Disabled)
	end

	function button:Destroy()
		if ownMaid then
			maid:Destroy()
		end
		root:Destroy()
	end

	if options.Disabled then
		button:SetDisabled(true)
	end

	return button
end

----------------------------------------------------------------------
-- Inline dropdown shell (shared by Dropdown and MultiDropdown)
----------------------------------------------------------------------

-- Builds the collapsible row: header (title, current value, chevron) and a
-- scrolling option list that expands inline. Selection logic stays with the
-- caller:  shell.OnPick(entry, index), shell:Refresh(isSelectedFn).
-- entries: array of { Text = string, Value = any }
function Utils.CreateDropdownShell(ctx, parent, config, maid)
	local theme, animation, overlay = ctx.Theme, ctx.Animation, ctx.Overlay
	local colors, fonts, sizes, layout = theme.Colors, theme.Fonts, theme.Sizes, theme.Layout
	local pad = layout.Padding
	local itemHeight = ctx.Touch and layout.DropdownItemTouch or layout.DropdownItem

	local row = Utils.CreateRow(ctx, parent, config, { ClipsDescendants = true, ReserveScale = 0.45 })
	local collapsed = row.Height
	local itemMaid = Maid.new()
	maid:Give(itemMaid)

	local header = Utils.Create("TextButton", {
		Name = "Header",
		Text = "",
		AutoButtonColor = false,
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		Size = UDim2.new(1, 0, 0, collapsed),
		ZIndex = 2,
		Parent = row.Root,
	})

	local valueLabel = Utils.Text(theme, row.Root, {
		Name = "Value",
		Font = fonts.Medium,
		TextSize = sizes.Small,
		TextColor3 = colors.Accent,
		TextXAlignment = Enum.TextXAlignment.Right,
		TextTruncate = Enum.TextTruncate.AtEnd,
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(1, -(pad + 22), 0, collapsed / 2),
		Size = UDim2.new(0.45, -(pad + 4), 0, 18),
	})

	local chevron = Utils.Icon("chevron", row.Root, colors.Muted, {
		Size = UDim2.fromOffset(12, 12),
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.new(1, -(pad + 6), 0, collapsed / 2),
	})

	local list = Utils.Create("ScrollingFrame", {
		Name = "Options",
		Position = UDim2.fromOffset(6, collapsed + 2),
		Size = UDim2.new(1, -12, 0, itemHeight),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ScrollBarThickness = 3,
		ScrollBarImageColor3 = colors.Border,
		ScrollingDirection = Enum.ScrollingDirection.Y,
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		CanvasSize = UDim2.new(),
		Parent = row.Root,
	})
	Utils.List(list, 2)

	local shell = {
		Row = row,
		Root = row.Root,
		Header = header,
		ValueLabel = valueLabel,
		List = list,
		Chevron = chevron,
		Entries = {},
		Items = {},
		IsOpen = false,
		Disabled = false,
		OnPick = nil,
	}

	local function listHeight()
		local visible = math.min(math.max(#shell.Entries, 1), layout.DropdownMaxVisible)
		return visible * itemHeight + (visible - 1) * 2
	end

	local function expandedHeight()
		return collapsed + 4 + listHeight() + 8
	end

	local popup = {
		Frame = row.Root,
		Close = function()
			shell:Close()
		end,
	}

	local function paint(item)
		local selected = shell._isSelected and shell._isSelected(item.Entry) or false
		item.Selected = selected
		local state
		if selected then
			state = item.Hovering and "SelectedHover" or "Selected"
		else
			state = item.Hovering and "Hover" or "Idle"
		end
		animation:Option(item, state)
	end

	function shell:Refresh(isSelected)
		if isSelected then
			self._isSelected = isSelected
		end
		for _, item in ipairs(self.Items) do
			paint(item)
		end
	end

	function shell:SetEntries(entries)
		itemMaid:Clean()
		for _, item in ipairs(self.Items) do
			item.Button:Destroy()
		end
		for _, child in ipairs(list:GetChildren()) do
			if child:IsA("TextLabel") then
				child:Destroy()
			end
		end
		self.Items = {}
		self.Entries = entries

		if #entries == 0 then
			Utils.Text(theme, list, {
				Name = "Empty",
				Text = "No options",
				Font = fonts.Regular,
				TextSize = sizes.Small,
				TextColor3 = colors.Subtle,
				Size = UDim2.new(1, -4, 0, itemHeight),
				Position = UDim2.fromOffset(10, 0),
			})
		end

		for index, entry in ipairs(entries) do
			local button = Utils.Create("TextButton", {
				Name = "Option_" .. index,
				Text = "",
				AutoButtonColor = false,
				BackgroundColor3 = colors.Hover,
				BackgroundTransparency = 1,
				BorderSizePixel = 0,
				Size = UDim2.new(1, -4, 0, itemHeight),
				LayoutOrder = index,
				Parent = list,
			})
			Utils.Corner(button, layout.RadiusControl)

			local label = Utils.Text(theme, button, {
				Name = "Label",
				Text = entry.Text,
				Font = fonts.Medium,
				TextSize = sizes.Small + 1,
				TextColor3 = colors.Muted,
				TextTruncate = Enum.TextTruncate.AtEnd,
				Position = UDim2.fromOffset(10, 0),
				Size = UDim2.new(1, -34, 1, 0),
			})

			local check = Utils.Icon("check", button, colors.Accent, {
				Size = UDim2.fromOffset(12, 12),
				AnchorPoint = Vector2.new(1, 0.5),
				Position = UDim2.new(1, -10, 0.5, 0),
			})
			check:SetTransparency(1)

			local item = { Button = button, Label = label, Check = check, Entry = entry, Hovering = false }
			table.insert(self.Items, item)

			Utils.BindInteract(button, itemMaid, {
				Hover = function(hover)
					item.Hovering = hover
					paint(item)
				end,
			})
			itemMaid:Give(button.Activated:Connect(function()
				if not self.Disabled and self.OnPick then
					self.OnPick(entry, index)
				end
			end))
		end

		self:Refresh()
		if self.IsOpen then
			list.Size = UDim2.new(1, -12, 0, listHeight())
			animation:Expand(row.Root, expandedHeight(), true, chevron.Frame)
		end
	end

	function shell:SetValueText(text, placeholder)
		valueLabel.Text = text
		valueLabel.TextColor3 = placeholder and colors.Subtle or colors.Accent
	end

	function shell:Open()
		if self.IsOpen or self.Disabled then
			return
		end
		self.IsOpen = true
		overlay:RegisterPopup(popup)
		list.Size = UDim2.new(1, -12, 0, listHeight())
		animation:Expand(row.Root, expandedHeight(), true, chevron.Frame)
	end

	function shell:Close()
		if not self.IsOpen then
			return
		end
		self.IsOpen = false
		overlay:UnregisterPopup(popup)
		animation:Expand(row.Root, collapsed, false, chevron.Frame)
	end

	function shell:Toggle()
		if self.IsOpen then
			self:Close()
		else
			self:Open()
		end
	end

	function shell:SetDisabled(disabled)
		self.Disabled = disabled and true or false
		if self.Disabled then
			self:Close()
		end
	end

	Utils.BindRowFeedback(ctx, row, header, maid, function()
		return shell.Disabled
	end)

	maid:Give(header.Activated:Connect(function()
		if not shell.Disabled then
			shell:Toggle()
		end
	end))

	maid:Give(function()
		if shell.IsOpen then
			shell.IsOpen = false
			overlay:UnregisterPopup(popup)
		end
	end)

	return shell
end

return Utils
