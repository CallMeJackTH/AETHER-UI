--[[
	Animation.lua
	The only module that touches TweenService. Everything else asks this
	engine to animate through named presets (see Theme.Motion.Presets) or the
	composite animations below.

	Guarantees:
	  * Conflicting tweens (same instance + same property) are cancelled
	    before a new one starts; unrelated leftovers snap to their goal.
	  * Active tweens are tracked in a weak table and cancelled when their
	    instance is destroyed, so nothing leaks.
	  * Looping tweens return a stop function.
	  * Flush() snaps every finite tween to its goal (used before a theme
	    repaint); CancelAll() stops everything; Count() reports live tweens.
]]

local TweenService = game:GetService("TweenService")

local Animation = {}
Animation.__index = Animation

function Animation.new(theme)
	local self = setmetatable({}, Animation)
	self.Theme = theme
	self.Speed = 1
	self._active = setmetatable({}, { __mode = "k" })
	self._loops = setmetatable({}, { __mode = "k" })
	self._destroyed = false
	return self
end

function Animation:SetSpeed(speed)
	self.Speed = math.clamp(speed, 0.25, 4)
end

----------------------------------------------------------------------
-- Core
----------------------------------------------------------------------

function Animation:_entry(instance)
	local entry = self._active[instance]
	if not entry then
		entry = {}
		self._active[instance] = entry
		instance.Destroying:Once(function()
			local current = self._active[instance]
			if current then
				for tween in pairs(current) do
					tween:Cancel()
				end
			end
			self._active[instance] = nil
		end)
	end
	return entry
end

function Animation:_resolveConflicts(instance, entry, goal)
	for existing, existingGoal in pairs(entry) do
		local overlaps = false
		for property in pairs(goal) do
			if existingGoal[property] ~= nil then
				overlaps = true
				break
			end
		end
		if overlaps then
			existing:Cancel()
			entry[existing] = nil
			for property, value in pairs(existingGoal) do
				if goal[property] == nil then
					pcall(function()
						instance[property] = value
					end)
				end
			end
		end
	end
end

function Animation:_create(instance, goal, tweenInfo, onComplete)
	local entry = self:_entry(instance)
	self:_resolveConflicts(instance, entry, goal)

	local tween = TweenService:Create(instance, tweenInfo, goal)
	entry[tween] = goal
	tween.Completed:Once(function(state)
		entry[tween] = nil
		if state == Enum.PlaybackState.Completed and onComplete and not self._destroyed then
			onComplete()
		end
	end)
	tween:Play()
	return tween
end

-- duration <= 0 applies the goal immediately (still cancelling conflicts).
function Animation:Tween(instance, goal, duration, style, direction, onComplete)
	if self._destroyed or not instance then
		return nil
	end

	duration = (duration or 0) / self.Speed
	if duration <= 0 then
		self:_resolveConflicts(instance, self:_entry(instance), goal)
		for property, value in pairs(goal) do
			instance[property] = value
		end
		if onComplete then
			onComplete()
		end
		return nil
	end

	local info = TweenInfo.new(
		duration,
		style or Enum.EasingStyle.Quad,
		direction or Enum.EasingDirection.Out
	)
	return self:_create(instance, goal, info, onComplete)
end

function Animation:Play(instance, presetName, goal, onComplete)
	local preset = self.Theme.Motion.Presets[presetName]
	assert(preset, "Unknown animation preset: " .. tostring(presetName))
	return self:Tween(instance, goal, preset.Time, preset.Style, preset.Direction, onComplete)
end

-- Infinite tween. Returns a function that stops it.
function Animation:Loop(instance, goal, duration, style, reverses)
	if self._destroyed or not instance then
		return function() end
	end
	local info = TweenInfo.new(
		duration,
		style or Enum.EasingStyle.Linear,
		Enum.EasingDirection.InOut,
		-1,
		reverses or false,
		0
	)
	local tween = self:_create(instance, goal, info)
	self._loops[tween] = true
	return function()
		tween:Cancel()
	end
end

function Animation:Cancel(instance)
	local entry = self._active[instance]
	if not entry then
		return
	end
	for tween in pairs(entry) do
		tween:Cancel()
		entry[tween] = nil
	end
end

-- Stops every tween (loops included) without touching property values.
function Animation:CancelAll()
	for _, entry in pairs(self._active) do
		for tween in pairs(entry) do
			tween:Cancel()
			entry[tween] = nil
		end
	end
end

-- Snaps every finite tween to its goal and cancels it. Looping tweens keep
-- running. Call before anything that reads current property values.
function Animation:Flush()
	for instance, entry in pairs(self._active) do
		for tween, goal in pairs(entry) do
			if not self._loops[tween] then
				tween:Cancel()
				entry[tween] = nil
				for property, value in pairs(goal) do
					pcall(function()
						instance[property] = value
					end)
				end
			end
		end
	end
end

-- Number of tweens currently tracked.
function Animation:Count()
	local total = 0
	for _, entry in pairs(self._active) do
		for _ in pairs(entry) do
			total = total + 1
		end
	end
	return total
end

function Animation:Destroy()
	if self._destroyed then
		return
	end
	self._destroyed = true
	self:CancelAll()
	self._active = {}
	self._loops = {}
end

----------------------------------------------------------------------
-- Generic component feedback
----------------------------------------------------------------------

function Animation:Press(scale, pressed)
	self:Play(scale, "Press", { Scale = pressed and 0.985 or 1 })
end

function Animation:Disabled(overlay, disabled)
	if disabled then
		overlay.Visible = true
		overlay.Active = true
		self:Play(overlay, "Hover", { BackgroundTransparency = self.Theme.Transparency.Disabled })
	else
		overlay.Active = false
		self:Play(overlay, "Hover", { BackgroundTransparency = 1 }, function()
			overlay.Visible = false
		end)
	end
end

function Animation:Focus(stroke, box, focused)
	local colors = self.Theme.Colors
	self:Play(stroke, "Focus", { Color = focused and colors.Accent or colors.Border })
	self:Play(box, "Focus", { BackgroundColor3 = focused and colors.Secondary or colors.Background })
end

function Animation:Expand(root, height, open, chevron)
	self:Play(root, "Dropdown", { Size = UDim2.new(root.Size.X.Scale, root.Size.X.Offset, 0, height) })
	if chevron then
		self:Play(chevron, "Dropdown", { Rotation = open and 180 or 0 })
	end
end

function Animation:IconColor(icon, color)
	for _, target in ipairs(icon.Targets) do
		self:Play(target.Instance, "Hover", { [target.Property] = color })
	end
end

function Animation:IconTransparency(icon, value)
	for _, target in ipairs(icon.Targets) do
		self:Play(target.Instance, "Fade", { [target.Alpha] = value })
	end
end

function Animation:ProgressFill(fill, ratio)
	self:Play(fill, "Toggle", { Size = UDim2.new(ratio, 0, 1, 0) })
end

-- Rotating comet on a ring (UIGradient on a UIStroke). Returns stop().
function Animation:Spinner(gradient)
	gradient.Rotation = 0
	return self:Loop(gradient, { Rotation = 360 }, self.Theme.Motion.Spinner, Enum.EasingStyle.Linear, false)
end

-- Sliding segment for indeterminate progress. Returns stop().
function Animation:Indeterminate(segment)
	segment.Position = UDim2.new(-0.4, 0, 0, 0)
	return self:Loop(segment, { Position = UDim2.new(1, 0, 0, 0) }, self.Theme.Motion.Indeterminate, Enum.EasingStyle.Quad, false)
end

-- Breathing stroke used while a Keybind is listening. Returns stop().
function Animation:Pulse(stroke)
	stroke.Transparency = 0.1
	return self:Loop(stroke, { Transparency = 0.75 }, self.Theme.Motion.Pulse, Enum.EasingStyle.Sine, true)
end

----------------------------------------------------------------------
-- Buttons
----------------------------------------------------------------------

-- Visual description of a button variant in a given state.
-- variant: Default | Primary | Danger | Ghost     state: Idle | Hover | Pressed
-- Returns { Background, BackgroundTransparency, Stroke, StrokeTransparency, Text, Description }
function Animation:ButtonStyle(variant, state)
	local colors = self.Theme.Colors
	local transparency = self.Theme.Transparency
	local hover, pressed = state == "Hover", state == "Pressed"

	if variant == "Primary" then
		local fill = pressed and colors.AccentPressed or (hover and colors.AccentHover or colors.Accent)
		return {
			Background = fill,
			BackgroundTransparency = 0,
			Stroke = fill,
			StrokeTransparency = 0.4,
			Text = colors.AccentText,
			Description = colors.AccentText,
		}
	elseif variant == "Danger" then
		return {
			Background = colors.Error,
			BackgroundTransparency = pressed and 0.74 or (hover and 0.82 or 0.9),
			Stroke = colors.Error,
			StrokeTransparency = hover and 0.35 or 0.6,
			Text = colors.Error,
			Description = colors.Error,
		}
	elseif variant == "Ghost" then
		return {
			Background = colors.Hover,
			BackgroundTransparency = pressed and 0.2 or (hover and 0.5 or 1),
			Stroke = colors.Border,
			StrokeTransparency = 1,
			Text = (hover or pressed) and colors.Text or colors.Muted,
			Description = colors.Muted,
		}
	end

	return {
		Background = pressed and colors.Pressed or (hover and colors.Elevated or colors.Secondary),
		BackgroundTransparency = transparency.Row,
		Stroke = hover and colors.BorderHover or colors.Border,
		StrokeTransparency = transparency.Stroke,
		Text = colors.Text,
		Description = colors.Muted,
	}
end

-- parts: Root, Stroke, Label, Description (optional), Icon (optional Utils.Icon)
function Animation:Button(parts, variant, state)
	local style = self:ButtonStyle(variant, state)
	local preset = state == "Pressed" and "Press" or "Hover"

	self:Play(parts.Root, preset, {
		BackgroundColor3 = style.Background,
		BackgroundTransparency = style.BackgroundTransparency,
	})
	if parts.Stroke then
		self:Play(parts.Stroke, preset, { Color = style.Stroke, Transparency = style.StrokeTransparency })
	end
	if parts.Label then
		self:Play(parts.Label, preset, { TextColor3 = style.Text })
	end
	if parts.Description then
		self:Play(parts.Description, preset, { TextColor3 = style.Description })
	end
	if parts.Icon then
		self:IconColor(parts.Icon, style.Text)
	end
end

----------------------------------------------------------------------
-- Toggle / Slider / Options
----------------------------------------------------------------------

-- parts: Track, Knob, Stroke (optional), KnobSize (default 14), KnobInset (default 3)
function Animation:Toggle(parts, on, instant)
	local colors = self.Theme.Colors
	local size = parts.KnobSize or 14
	local inset = parts.KnobInset or 3

	local goals = {
		{ parts.Track, { BackgroundColor3 = on and colors.Accent or colors.Elevated } },
		{
			parts.Knob,
			{
				Position = on and UDim2.new(1, -(size + inset), 0.5, 0) or UDim2.new(0, inset, 0.5, 0),
				BackgroundColor3 = on and colors.AccentText or colors.Muted,
			},
		},
	}
	if parts.Stroke then
		table.insert(goals, { parts.Stroke, { Color = on and colors.Accent or colors.Border } })
	end

	for _, pair in ipairs(goals) do
		if instant then
			self:Tween(pair[1], pair[2], 0)
		else
			self:Play(pair[1], "Toggle", pair[2])
		end
	end
end

-- parts: Fill, Knob. ratio is 0-1.
function Animation:Slider(parts, ratio, instant)
	local fill = { Size = UDim2.new(ratio, 0, 1, 0) }
	local knob = { Position = UDim2.new(ratio, 0, 0.5, 0) }
	if instant then
		self:Tween(parts.Fill, fill, 0)
		self:Tween(parts.Knob, knob, 0)
	else
		self:Play(parts.Fill, "Slider", fill)
		self:Play(parts.Knob, "Slider", knob)
	end
end

function Animation:SliderKnob(knob, active, rest)
	rest = rest or 12
	local size = active and rest + 4 or rest
	self:Play(knob, "Press", { Size = UDim2.fromOffset(size, size) })
end

-- Dropdown / multi-dropdown option row.
-- item: Button, Label, Check (optional Utils.Icon)     state: Idle | Hover | Selected | SelectedHover
function Animation:Option(item, state)
	local colors = self.Theme.Colors
	local selected = state == "Selected" or state == "SelectedHover"
	local hover = state == "Hover" or state == "SelectedHover"

	self:Play(item.Button, "Hover", {
		BackgroundColor3 = selected and colors.Accent or colors.Hover,
		BackgroundTransparency = selected and (hover and 0.82 or 0.88) or (hover and 0.35 or 1),
	})
	self:Play(item.Label, "Hover", { TextColor3 = (selected or hover) and colors.Text or colors.Muted })
	if item.Check then
		self:IconTransparency(item.Check, selected and 0 or 1)
	end
end

-- Chip / pill selected state (used by compact selectors).
function Animation:Chip(chip, label, active)
	local colors = self.Theme.Colors
	self:Play(chip, "Hover", {
		BackgroundColor3 = active and colors.Accent or colors.Elevated,
		BackgroundTransparency = active and 0.85 or 0,
	})
	self:Play(label, "Hover", { TextColor3 = active and colors.Accent or colors.Muted })
end

----------------------------------------------------------------------
-- Window
-- parts: Root, Canvas, Stroke, Scale, Shadow, Position (UDim2 rest position),
--        Transparency (resting canvas background transparency)
----------------------------------------------------------------------

function Animation:ShadowTo(shadow, visible, instant)
	for _, layer in ipairs(shadow.Layers) do
		local goal = { BackgroundTransparency = visible and layer.Base or 1 }
		if instant then
			self:Tween(layer.Instance, goal, 0)
		else
			self:Play(layer.Instance, "Fade", goal)
		end
	end
end

local function offsetPosition(position, dy)
	return UDim2.new(position.X.Scale, position.X.Offset, position.Y.Scale, position.Y.Offset + dy)
end

function Animation:_windowShow(parts, fromScale, fromOffset, onDone)
	local rest = parts.Position
	parts.Root.Visible = true

	self:Tween(parts.Canvas, { GroupTransparency = 1 }, 0)
	self:Tween(parts.Scale, { Scale = fromScale }, 0)
	self:Tween(parts.Root, { Position = offsetPosition(rest, fromOffset) }, 0)
	self:Tween(parts.Stroke, { Transparency = 1 }, 0)
	self:ShadowTo(parts.Shadow, false, true)

	self:Play(parts.Canvas, "WindowOpen", { GroupTransparency = 0 })
	self:Play(parts.Scale, "WindowScale", { Scale = 1 })
	self:Play(parts.Stroke, "WindowOpen", { Transparency = self.Theme.Transparency.Stroke })
	self:ShadowTo(parts.Shadow, true, false)

	-- Completion is tied to the slowest tween (the 0.35s root slide).
	self:Play(parts.Root, "WindowOpen", { Position = rest }, onDone)
end

function Animation:_windowHide(parts, toScale, toOffset, onDone)
	local rest = parts.Position
	self:Play(parts.Scale, "WindowClose", { Scale = toScale })
	self:Play(parts.Stroke, "WindowClose", { Transparency = 1 })
	self:Play(parts.Root, "WindowClose", { Position = offsetPosition(rest, toOffset) })
	self:ShadowTo(parts.Shadow, false, false)
	self:Play(parts.Canvas, "WindowClose", { GroupTransparency = 1 }, function()
		parts.Root.Visible = false
		if onDone then
			onDone()
		end
	end)
end

function Animation:WindowOpen(parts, onDone)
	self:_windowShow(parts, 0.94, 16, onDone)
end

function Animation:WindowRestore(parts, onDone)
	self:_windowShow(parts, 0.9, 10, onDone)
end

function Animation:WindowMinimize(parts, onDone)
	self:_windowHide(parts, 0.9, 10, onDone)
end

function Animation:WindowClose(parts, onDone)
	self:_windowHide(parts, 0.96, 8, onDone)
end

function Animation:DragFeedback(parts, dragging)
	local colors = self.Theme.Colors
	self:Play(parts.Stroke, "Hover", {
		Color = dragging and colors.Accent or colors.Border,
		Transparency = dragging and 0.2 or self.Theme.Transparency.Stroke,
	})
	self:Play(parts.Canvas, "Hover", {
		BackgroundTransparency = dragging and (parts.Transparency + 0.06) or parts.Transparency,
	})
end

-- Floating reopen button (CanvasGroup + UIScale)
function Animation:Floating(button, scale, visible)
	if visible then
		button.Visible = true
		self:Tween(button, { GroupTransparency = 1 }, 0)
		self:Tween(scale, { Scale = 0.6 }, 0)
		self:Play(button, "Fade", { GroupTransparency = 0 })
		self:Play(scale, "WindowScale", { Scale = 1 })
	else
		self:Play(scale, "WindowClose", { Scale = 0.6 })
		self:Play(button, "WindowClose", { GroupTransparency = 1 }, function()
			button.Visible = false
		end)
	end
end

----------------------------------------------------------------------
-- Sidebar / pages
----------------------------------------------------------------------

-- item: Button, Label, Icon      state: Idle | Hover | Pressed | Active
function Animation:SidebarItem(item, state)
	local colors = self.Theme.Colors
	local background, backgroundAlpha, textColor, iconColor

	if state == "Active" then
		background, backgroundAlpha, textColor, iconColor = colors.Accent, 0.88, colors.Text, colors.Accent
	elseif state == "Pressed" then
		background, backgroundAlpha, textColor, iconColor = colors.Hover, 0.1, colors.Text, colors.Text
	elseif state == "Hover" then
		background, backgroundAlpha, textColor, iconColor = colors.Hover, 0.4, colors.Text, colors.Text
	else
		background, backgroundAlpha, textColor, iconColor = colors.Hover, 1, colors.Muted, colors.Muted
	end

	self:Play(item.Button, "Hover", { BackgroundColor3 = background, BackgroundTransparency = backgroundAlpha })
	self:Play(item.Label, "Hover", { TextColor3 = textColor })
	self:IconColor(item.Icon, iconColor)
end

function Animation:SidebarIndicator(indicator, y)
	self:Play(indicator, "Indicator", { Position = UDim2.fromOffset(0, y) })
end

-- oldPage / newPage are CanvasGroups; direction 1 = forward, -1 = backward.
function Animation:PageSwitch(oldPage, newPage, direction)
	local offset = 10 * (direction or 1)

	if newPage then
		newPage.Visible = true
		self:Tween(newPage, { GroupTransparency = 1, Position = UDim2.new(0, 0, 0, offset) }, 0)
		self:Play(newPage, "Page", { GroupTransparency = 0, Position = UDim2.new(0, 0, 0, 0) })
	end

	if oldPage and oldPage ~= newPage then
		self:Play(oldPage, "PageOut", {
			GroupTransparency = 1,
			Position = UDim2.new(0, 0, 0, -offset),
		}, function()
			oldPage.Visible = false
		end)
	end
end

----------------------------------------------------------------------
-- Overlays
----------------------------------------------------------------------

-- parts: Holder (layout slot), Inner (CanvasGroup)
function Animation:NotificationIn(parts)
	self:Tween(parts.Inner, { Position = UDim2.new(1, 24, 0, 0), GroupTransparency = 1 }, 0)
	self:Play(parts.Inner, "Notification", { Position = UDim2.new(0, 0, 0, 0), GroupTransparency = 0 })
end

function Animation:NotificationOut(parts, onDone)
	self:Play(parts.Inner, "NotificationOut", {
		Position = UDim2.new(1, 24, 0, 0),
		GroupTransparency = 1,
	}, function()
		self:Play(parts.Holder, "Layout", { Size = UDim2.new(1, 0, 0, 0) }, onDone)
	end)
end

-- parts: Backdrop, Panel (CanvasGroup, anchored at centre), Scale (UIScale)
-- kind: "Modal" | "Dialog"
function Animation:ModalIn(parts, kind)
	local dialog = kind == "Dialog"
	local center = UDim2.new(0.5, 0, 0.5, 0)

	self:Tween(parts.Backdrop, { BackgroundTransparency = 1 }, 0)
	self:Tween(parts.Panel, { GroupTransparency = 1, Position = dialog and UDim2.new(0.5, 0, 0.5, 16) or center }, 0)
	self:Tween(parts.Scale, { Scale = dialog and 0.88 or 0.94 }, 0)

	self:Play(parts.Backdrop, "Modal", { BackgroundTransparency = self.Theme.Transparency.Backdrop })
	self:Play(parts.Panel, "Modal", { GroupTransparency = 0, Position = center })
	self:Play(parts.Scale, dialog and "ModalScale" or "Modal", { Scale = 1 })
end

function Animation:ModalOut(parts, onDone)
	self:Play(parts.Backdrop, "ModalOut", { BackgroundTransparency = 1 })
	self:Play(parts.Scale, "ModalOut", { Scale = 0.96 })
	self:Play(parts.Panel, "ModalOut", { GroupTransparency = 1 }, onDone)
end

function Animation:ContextMenuIn(panel, scale)
	self:Tween(panel, { GroupTransparency = 1 }, 0)
	self:Tween(scale, { Scale = 0.92 }, 0)
	self:Play(panel, "ContextMenu", { GroupTransparency = 0 })
	self:Play(scale, "ContextMenu", { Scale = 1 })
end

function Animation:ContextMenuOut(panel, scale, onDone)
	self:Play(scale, "ContextMenuOut", { Scale = 0.95 })
	self:Play(panel, "ContextMenuOut", { GroupTransparency = 1 }, onDone)
end

function Animation:TooltipIn(group)
	group.Visible = true
	self:Tween(group, { GroupTransparency = 1 }, 0)
	self:Play(group, "Tooltip", { GroupTransparency = 0 })
end

function Animation:TooltipOut(group, onDone)
	self:Play(group, "Tooltip", { GroupTransparency = 1 }, onDone)
end

-- Generic anchored popup (colour picker, small pickers). panel is a CanvasGroup.
function Animation:PopupIn(panel, scale)
	self:Tween(panel, { GroupTransparency = 1 }, 0)
	self:Tween(scale, { Scale = 0.94 }, 0)
	self:Play(panel, "Popup", { GroupTransparency = 0 })
	self:Play(scale, "Popup", { Scale = 1 })
end

function Animation:PopupOut(panel, scale, onDone)
	self:Play(scale, "PopupOut", { Scale = 0.96 })
	self:Play(panel, "PopupOut", { GroupTransparency = 1 }, onDone)
end

Animation.ColorPickerIn = Animation.PopupIn
Animation.ColorPickerOut = Animation.PopupOut

return Animation
