--[[
	Theme.lua
	Single source of truth for AETHER UI: colors, transparency, geometry,
	typography, z-index and motion presets. Every other module reads from a
	Theme instance (injected through `ctx.Theme`) and never hard-codes a value.

	Theme.new(overrides)         deep-merges `overrides` over the defaults.
	                             `overrides.Preset` selects Dark | Midnight | Light.
	Theme:SetTheme(name, root)   switches preset IN PLACE (every table that other
	                             modules captured stays valid) and repaints `root`.
	Theme:Override(table, root)  runtime override, e.g. { Colors = { Accent = ... } }
	Theme:SetAccent(color, root) re-derives hover / pressed / on-accent tones.
	Theme:RegisterPreset(name, overrides)
	Theme:OnChanged(fn)          -> connection with :Disconnect()
	Theme:Repaint(root, previous) remaps every palette colour found on `root`'s
	                             descendants from the `previous` palette to the
	                             current one. Instances carrying the attribute
	                             "AetherLock" (user data such as colour swatches)
	                             are skipped.
]]

local Theme = {}
Theme.__index = Theme

-- Order matters: when two keys share a colour, the first one wins during repaint.
local COLOR_KEYS = {
	"Background", "Surface", "Secondary", "Border", "Text", "Muted", "Accent",
	"BorderHover", "Hover", "Elevated", "Pressed", "Subtle",
	"AccentText", "AccentHover", "AccentPressed",
	"Success", "Warning", "Error", "Info",
}

local function merge(target, source)
	for key, value in pairs(source) do
		if type(value) == "table" and type(target[key]) == "table" then
			merge(target[key], value)
		else
			target[key] = value
		end
	end
end

local function hex(value)
	return Color3.fromHex(value)
end

local function defaults()
	local Style = Enum.EasingStyle
	local Dir = Enum.EasingDirection

	return {
		Name = "Dark",

		Colors = {
			-- Core palette
			Background = hex("#090A0D"),
			Surface = hex("#101216"),
			Secondary = hex("#15181E"),
			Border = hex("#252A33"),
			Text = hex("#F1F3F7"),
			Muted = hex("#9299A6"),
			Accent = hex("#A8B5FF"),

			-- Derived tones
			BorderHover = hex("#363D4A"),
			Hover = hex("#1C2028"),
			Elevated = hex("#1A1E26"),
			Pressed = hex("#0E1014"),
			Subtle = hex("#5B6270"),
			AccentText = hex("#0B0D14"),
			AccentHover = hex("#BAC4FF"),
			AccentPressed = hex("#96A4F2"),

			-- Status (Info always equals Accent)
			Success = hex("#7BDCA8"),
			Warning = hex("#F2C879"),
			Error = hex("#F2808C"),
			Info = hex("#A8B5FF"),

			Black = hex("#000000"),
			White = hex("#FFFFFF"),
		},

		-- 0 = opaque, 1 = invisible
		Transparency = {
			Window = 0.06,
			Topbar = 0.3,
			Sidebar = 0.35,
			Card = 0.25,
			Row = 0.05,
			Stroke = 0.35,
			Backdrop = 0.45,
			Popup = 0.02,
			Disabled = 0.5,
		},

		ZIndex = {
			Window = 10,
			Floating = 20,
			Modal = 100,
			Popup = 150,
			Notification = 200,
			Tooltip = 300,
		},

		Layout = {
			WindowSize = Vector2.new(650, 420),
			MinWindowSize = Vector2.new(300, 240),
			ScreenMargin = 12,
			ScreenMarginTouch = 22,
			CompactBreakpoint = 560,

			TopbarHeight = 42,
			FooterHeight = 24,
			SidebarWidth = 165,
			SidebarCompactWidth = 56,
			SidebarItem = 36,
			SidebarItemTouch = 42,

			RadiusWindow = 12,
			RadiusPanel = 10,
			RadiusCard = 8,
			RadiusControl = 6,

			Padding = 10,
			PagePadding = 14,
			Gap = 6,
			SectionGap = 10,

			RowHeight = 36,
			RowHeightTouch = 44,
			ControlHeight = 26,
			ControlHeightTouch = 34,
			ContextItem = 30,
			ContextItemTouch = 40,
			ButtonHeight = 32,
			ButtonHeightTouch = 40,

			DropdownItem = 28,
			DropdownItemTouch = 38,
			DropdownMaxVisible = 6,

			ColorPickerWidth = 224,
			ColorPickerArea = 140,

			TooltipOffset = 10,
			TooltipMaxWidth = 240,
			DialogWidth = 330,
			ModalWidth = 380,
			PopupMargin = 8,

			FloatingButton = 44,
			FloatingButtonTouch = 52,

			NotificationWidth = 290,
			NotificationMax = 5,
		},

		Fonts = {
			Regular = Enum.Font.Gotham,
			Medium = Enum.Font.GothamMedium,
			SemiBold = Enum.Font.GothamSemibold,
			Bold = Enum.Font.GothamBold,
			Mono = Enum.Font.RobotoMono,
		},

		Sizes = {
			Heading = 16,
			Title = 14,
			Body = 13,
			Small = 12,
			Caption = 11,
			Tiny = 10,
		},

		Motion = {
			-- Seconds for the looping animations
			Spinner = 0.9,
			Indeterminate = 1.3,
			Pulse = 0.6,
			TooltipDelay = 0.45,
			LongPress = 0.5,

			Presets = {
				-- Components
				Hover = { Time = 0.15, Style = Style.Sine, Direction = Dir.Out },
				Press = { Time = 0.10, Style = Style.Quad, Direction = Dir.Out },
				Toggle = { Time = 0.20, Style = Style.Quart, Direction = Dir.Out },
				Slider = { Time = 0.10, Style = Style.Quad, Direction = Dir.Out },
				Dropdown = { Time = 0.22, Style = Style.Quart, Direction = Dir.Out },
				Focus = { Time = 0.15, Style = Style.Sine, Direction = Dir.Out },
				Fade = { Time = 0.20, Style = Style.Sine, Direction = Dir.Out },
				Layout = { Time = 0.20, Style = Style.Quart, Direction = Dir.Out },

				-- Navigation
				Indicator = { Time = 0.25, Style = Style.Quart, Direction = Dir.Out },
				Page = { Time = 0.25, Style = Style.Quart, Direction = Dir.Out },
				PageOut = { Time = 0.18, Style = Style.Quad, Direction = Dir.Out },

				-- Window
				WindowOpen = { Time = 0.35, Style = Style.Quart, Direction = Dir.Out },
				WindowScale = { Time = 0.35, Style = Style.Back, Direction = Dir.Out },
				WindowClose = { Time = 0.22, Style = Style.Quad, Direction = Dir.In },

				-- Overlays
				Modal = { Time = 0.25, Style = Style.Quart, Direction = Dir.Out },
				ModalScale = { Time = 0.30, Style = Style.Back, Direction = Dir.Out },
				ModalOut = { Time = 0.18, Style = Style.Quad, Direction = Dir.In },
				Notification = { Time = 0.30, Style = Style.Quart, Direction = Dir.Out },
				NotificationOut = { Time = 0.25, Style = Style.Quad, Direction = Dir.In },
				Tooltip = { Time = 0.12, Style = Style.Sine, Direction = Dir.Out },
				ContextMenu = { Time = 0.15, Style = Style.Quart, Direction = Dir.Out },
				ContextMenuOut = { Time = 0.10, Style = Style.Quad, Direction = Dir.In },
				Popup = { Time = 0.18, Style = Style.Quart, Direction = Dir.Out },
				PopupOut = { Time = 0.12, Style = Style.Quad, Direction = Dir.In },
			},
		},
	}
end

----------------------------------------------------------------------
-- Presets (applied on top of the Dark defaults)
----------------------------------------------------------------------

Theme.Presets = {
	Dark = {
		Name = "Dark",
	},

	Midnight = {
		Name = "Midnight",
		Colors = {
			Background = hex("#05060E"),
			Surface = hex("#0A0C18"),
			Secondary = hex("#0F1224"),
			Border = hex("#1C2140"),
			Text = hex("#EAEDFF"),
			Muted = hex("#8A91B5"),
			Accent = hex("#8C9EFF"),
			BorderHover = hex("#2B3260"),
			Hover = hex("#151A33"),
			Elevated = hex("#131730"),
			Pressed = hex("#080A14"),
			Subtle = hex("#565C80"),
			AccentText = hex("#070914"),
			AccentHover = hex("#A4B2FF"),
			AccentPressed = hex("#7387EE"),
			Info = hex("#8C9EFF"),
		},
	},

	Light = {
		Name = "Light",
		Colors = {
			Background = hex("#EDF0F5"),
			Surface = hex("#F7F8FB"),
			Secondary = hex("#FBFCFE"),
			Border = hex("#D6DBE5"),
			Text = hex("#14171D"),
			Muted = hex("#5B6472"),
			Accent = hex("#4C5FE6"),
			BorderHover = hex("#BFC6D4"),
			Hover = hex("#E7EBF2"),
			Elevated = hex("#F0F3F8"),
			Pressed = hex("#E1E6EE"),
			Subtle = hex("#8A93A3"),
			AccentText = hex("#FEFEFF"),
			AccentHover = hex("#6272EE"),
			AccentPressed = hex("#3A4BD0"),
			Success = hex("#1F9D63"),
			Warning = hex("#B7791F"),
			Error = hex("#D64555"),
			Info = hex("#4C5FE6"),
		},
	},
}

Theme.PresetOrder = { "Dark", "Midnight", "Light" }

----------------------------------------------------------------------
-- Construction
----------------------------------------------------------------------

function Theme:_compose(name)
	local preset = self._presets[name] or Theme.Presets[name]
	local fresh = defaults()
	if preset then
		merge(fresh, preset)
	end
	merge(fresh, self._base)
	fresh.Preset = nil
	fresh.Name = name
	return fresh
end

function Theme.new(overrides)
	local self = setmetatable(defaults(), Theme)
	self._base = overrides or {}
	self._presets = {}
	self._presetOrder = {}
	self._listeners = {}

	local presetName = self._base.Preset or "Dark"
	if not Theme.Presets[presetName] then
		presetName = "Dark"
	end
	merge(self, self:_compose(presetName))
	return self
end

function Theme:RegisterPreset(name, overrides)
	assert(type(name) == "string" and name ~= "", "Theme:RegisterPreset expects a name")
	assert(type(overrides) == "table", "Theme:RegisterPreset expects a table")
	if not self._presets[name] and not Theme.Presets[name] then
		table.insert(self._presetOrder, name)
	end
	self._presets[name] = overrides
end

function Theme:GetThemeNames()
	local names = table.clone(Theme.PresetOrder)
	for _, name in ipairs(self._presetOrder) do
		table.insert(names, name)
	end
	return names
end

function Theme:HasTheme(name)
	return (self._presets[name] or Theme.Presets[name]) ~= nil
end

----------------------------------------------------------------------
-- Change notification
----------------------------------------------------------------------

function Theme:OnChanged(callback)
	assert(type(callback) == "function", "Theme:OnChanged expects a function")
	local listeners = self._listeners
	local connection = { Connected = true }
	function connection:Disconnect()
		if not self.Connected then
			return
		end
		self.Connected = false
		local index = table.find(listeners, callback)
		if index then
			table.remove(listeners, index)
		end
	end
	table.insert(listeners, callback)
	return connection
end

function Theme:_notify()
	for _, callback in ipairs(table.clone(self._listeners)) do
		local ok, err = pcall(callback, self)
		if not ok then
			warn("[AetherUI] theme listener error: " .. tostring(err))
		end
	end
end

----------------------------------------------------------------------
-- Repaint
----------------------------------------------------------------------

local function colorKey(color)
	return math.floor(color.R * 255 + 0.5) * 65536
		+ math.floor(color.G * 255 + 0.5) * 256
		+ math.floor(color.B * 255 + 0.5)
end

function Theme:Repaint(root, previous)
	if not root or not previous then
		return 0
	end

	local lookup = {}
	for _, key in ipairs(COLOR_KEYS) do
		local old, new = previous[key], self.Colors[key]
		if old and new then
			local id = colorKey(old)
			if lookup[id] == nil then
				lookup[id] = new
			end
		end
	end

	local changed = 0
	local function map(instance, property)
		local mapped = lookup[colorKey(instance[property])]
		if mapped then
			instance[property] = mapped
			changed = changed + 1
		end
	end

	local descendants = root:GetDescendants()
	table.insert(descendants, root)

	for _, instance in ipairs(descendants) do
		if not instance:GetAttribute("AetherLock") then
			if instance:IsA("GuiObject") then
				map(instance, "BackgroundColor3")
				if instance:IsA("TextLabel") or instance:IsA("TextButton") then
					map(instance, "TextColor3")
				elseif instance:IsA("TextBox") then
					map(instance, "TextColor3")
					map(instance, "PlaceholderColor3")
				elseif instance:IsA("ImageLabel") or instance:IsA("ImageButton") then
					map(instance, "ImageColor3")
				elseif instance:IsA("ScrollingFrame") then
					map(instance, "ScrollBarImageColor3")
				end
			elseif instance:IsA("UIStroke") then
				map(instance, "Color")
			elseif instance:IsA("UIGradient") then
				local keypoints = instance.Color.Keypoints
				local rebuilt, dirty = {}, false
				for _, keypoint in ipairs(keypoints) do
					local mapped = lookup[colorKey(keypoint.Value)]
					if mapped then
						dirty = true
					end
					table.insert(rebuilt, ColorSequenceKeypoint.new(keypoint.Time, mapped or keypoint.Value))
				end
				if dirty then
					instance.Color = ColorSequence.new(rebuilt)
					changed = changed + 1
				end
			end
		end
	end

	return changed
end

----------------------------------------------------------------------
-- Switching / overriding
----------------------------------------------------------------------

function Theme:SetTheme(name, root)
	if not self:HasTheme(name) then
		return false
	end
	local previous = table.clone(self.Colors)
	merge(self, self:_compose(name))
	self:Repaint(root, previous)
	self:_notify()
	return true
end

function Theme:Override(overrides, root)
	assert(type(overrides) == "table", "Theme:Override expects a table")
	local previous = table.clone(self.Colors)
	merge(self, overrides)
	self:Repaint(root, previous)
	self:_notify()
end

function Theme:SetAccent(color, root)
	local colors = self.Colors
	local previous = table.clone(colors)
	local follow = colors.Info == colors.Accent
	local luminance = 0.2126 * color.R + 0.7152 * color.G + 0.0722 * color.B

	colors.Accent = color
	colors.AccentHover = color:Lerp(colors.White, 0.22)
	colors.AccentPressed = color:Lerp(colors.Black, 0.14)
	colors.AccentText = luminance > 0.55 and hex("#0B0D14") or hex("#FEFEFF")
	if follow then
		colors.Info = color
	end

	self:Repaint(root, previous)
	self:_notify()
end

return Theme
