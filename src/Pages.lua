--[[
	Pages.lua
	Built-in pages of a Window: Dashboard, Components, Showcase, Notifications,
	Modals, Configurations and Settings. They are ordinary tabs built with the
	public API (plus a few custom cards), so they double as living examples.

	Pages.Build(window, spec)
	  spec: nil / true  -> every page
	        false       -> none
	        { Settings = false, ... } -> everything except the listed pages

	Pages split out of Window.lua so the window stays focused on frame logic.
]]

local Pages = {}

local function enabled(spec, name)
	if spec == nil or spec == true then
		return true
	end
	if type(spec) == "table" then
		return spec[name] ~= false
	end
	return false
end

----------------------------------------------------------------------
-- Shared helpers
----------------------------------------------------------------------

local function card(ctx, height)
	local Utils, theme = ctx.Utils, ctx.Theme
	local frame = Utils.Create("Frame", {
		Name = "Card",
		Size = UDim2.new(1, 0, 0, height),
		BackgroundColor3 = theme.Colors.Secondary,
		BackgroundTransparency = theme.Transparency.Row,
		BorderSizePixel = 0,
	})
	Utils.Corner(frame, theme.Layout.RadiusCard)
	Utils.Stroke(frame, theme.Colors.Border, 1, theme.Transparency.Stroke)
	return frame
end

local function off(config)
	config.Flag = false
	return config
end

local function formatTime(stamp)
	if not stamp or stamp <= 0 then
		return "unknown date"
	end
	local ok, text = pcall(os.date, "%b %d, %H:%M", stamp)
	return ok and text or "unknown date"
end

local function formatBytes(bytes)
	if bytes < 1024 then
		return bytes .. " B"
	end
	return string.format("%.1f KB", bytes / 1024)
end

local function copyToClipboard(text)
	local ok, fn = pcall(function()
		return getfenv(0)["setclipboard"]
	end)
	if ok and type(fn) == "function" then
		return pcall(fn, text)
	end
	return false
end

----------------------------------------------------------------------
-- Dashboard
----------------------------------------------------------------------

local function buildDashboard(window)
	local ctx = window.ctx
	local Utils, theme, library = ctx.Utils, ctx.Theme, ctx.Library
	local colors, fonts, sizes = theme.Colors, theme.Fonts, theme.Sizes
	local pad = theme.Layout.Padding

	local tab = window:CreateTab({
		Name = "Dashboard",
		Icon = "dashboard",
		Section = "MAIN",
		Order = 100,
		Description = "Overview of this session.",
	})

	-- Welcome card
	local overview = tab:CreateSection("Overview")
	local player = game:GetService("Players").LocalPlayer
	local welcome = card(ctx, 74)
	Utils.Text(theme, welcome, {
		Name = "Title",
		Text = "Welcome back, " .. (player and player.DisplayName or "Guest"),
		Font = fonts.SemiBold,
		TextSize = sizes.Title + 1,
		TextTruncate = Enum.TextTruncate.AtEnd,
		Position = UDim2.fromOffset(pad + 2, 12),
		Size = UDim2.new(1, -(pad * 2 + 110), 0, 20),
	})
	local subtitle = Utils.Text(theme, welcome, {
		Name = "Subtitle",
		Text = "",
		Font = fonts.Regular,
		TextSize = sizes.Small,
		TextColor3 = colors.Muted,
		TextTruncate = Enum.TextTruncate.AtEnd,
		Position = UDim2.fromOffset(pad + 2, 34),
		Size = UDim2.new(1, -(pad * 2 + 110), 0, 16),
	})
	local pill = Utils.Create("Frame", {
		Name = "Status",
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -pad, 0, 14),
		Size = UDim2.fromOffset(92, 22),
		BackgroundColor3 = colors.Success,
		BackgroundTransparency = 0.86,
		BorderSizePixel = 0,
		Parent = welcome,
	})
	Utils.Corner(pill, 11)
	Utils.Stroke(pill, colors.Success, 1, 0.6)
	Utils.Text(theme, pill, {
		Text = "OPERATIONAL",
		Font = fonts.Bold,
		TextSize = sizes.Tiny,
		TextColor3 = colors.Success,
		TextXAlignment = Enum.TextXAlignment.Center,
		Size = UDim2.new(1, 0, 1, 0),
	})
	Utils.Text(theme, welcome, {
		Name = "Hint",
		Text = "Press " .. window.ToggleKey.Name .. " to hide or show the window.",
		Font = fonts.Regular,
		TextSize = sizes.Tiny + 1,
		TextColor3 = colors.Subtle,
		Position = UDim2.fromOffset(pad + 2, 52),
		Size = UDim2.new(1, -(pad * 2), 0, 14),
	})
	overview:AddCustom(welcome)

	-- Metric cards
	local row = Utils.Create("Frame", {
		Name = "Metrics",
		Size = UDim2.new(1, 0, 0, 64),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
	})
	Utils.List(row, 8, Enum.FillDirection.Horizontal)
	overview:AddCustom(row)

	local function metric(title, unit, order)
		local frame = card(ctx, 64)
		frame.Size = UDim2.new(1 / 3, -6, 1, 0)
		frame.LayoutOrder = order
		frame.Parent = row
		Utils.Text(theme, frame, {
			Text = string.upper(title),
			Font = fonts.Bold,
			TextSize = sizes.Tiny,
			TextColor3 = colors.Subtle,
			Position = UDim2.fromOffset(pad, 9),
			Size = UDim2.new(1, -pad * 2, 0, 14),
		})
		local value = Utils.Text(theme, frame, {
			Text = "0",
			Font = fonts.Bold,
			TextSize = sizes.Heading + 4,
			Position = UDim2.fromOffset(pad, 26),
			Size = UDim2.new(1, -pad * 2 - 26, 0, 28),
		})
		Utils.Text(theme, frame, {
			Text = unit,
			Font = fonts.Medium,
			TextSize = sizes.Caption,
			TextColor3 = colors.Muted,
			TextXAlignment = Enum.TextXAlignment.Right,
			AnchorPoint = Vector2.new(1, 0),
			Position = UDim2.new(1, -pad, 0, 34),
			Size = UDim2.fromOffset(30, 16),
		})
		return value
	end
	local fpsValue = metric("Framerate", "FPS", 1)
	local pingValue = metric("Latency", "ms", 2)
	local memoryValue = metric("Memory", "MB", 3)

	local function paintMetrics(metrics)
		fpsValue.Text = tostring(metrics.FPS)
		pingValue.Text = tostring(metrics.Ping)
		memoryValue.Text = tostring(metrics.Memory)
	end
	paintMetrics(ctx.Metrics)
	window.Maid:Give(ctx.MetricsChanged:Connect(paintMetrics))

	-- Configuration summary
	local summary = card(ctx, 54)
	Utils.Text(theme, summary, {
		Text = "ACTIVE CONFIGURATION",
		Font = fonts.Bold,
		TextSize = sizes.Tiny,
		TextColor3 = colors.Subtle,
		Position = UDim2.fromOffset(pad, 9),
		Size = UDim2.new(1, -pad * 2, 0, 14),
	})
	local configValue = Utils.Text(theme, summary, {
		Font = fonts.SemiBold,
		TextSize = sizes.Body,
		TextColor3 = colors.Accent,
		TextTruncate = Enum.TextTruncate.AtEnd,
		Position = UDim2.fromOffset(pad, 26),
		Size = UDim2.new(1, -pad * 2, 0, 18),
	})
	overview:AddCustom(summary)

	local function paintConfig()
		local current = ctx.Config.Current
		configValue.Text = current and (current .. ".json") or "None (unsaved)"
		subtitle.Text = string.format(
			"%s storage  -  %d components registered",
			ctx.Config:GetBackend(),
			#ctx.Config:GetFlags()
		)
	end
	paintConfig()
	window.Maid:Give(ctx.Config.Changed:Connect(paintConfig))

	-- Quick actions
	local actions = tab:CreateSection("Quick Actions")
	actions:CreateButton(off({
		Name = "Browse components",
		Description = "Every control in the library, live.",
		Style = "Primary",
		Callback = function()
			window:SelectTab("Components")
		end,
	}))
	actions:CreateButton(off({
		Name = "Send a test notification",
		Callback = function()
			ctx.Notifications:Notify({
				Title = "Hello from AETHER",
				Content = "Toasts stack in the bottom-right corner.",
				Type = "Info",
			})
		end,
	}))
	actions:CreateButton(off({
		Name = "Open settings",
		Callback = function()
			window:SelectTab("Settings")
		end,
	}))

	-- What's new
	local news = tab:CreateSection("What's New")
	news:CreateParagraph({
		Title = "v" .. library.Version .. "  -  Initial release",
		Content = "Dark, Midnight and Light themes with live repaint, inline dropdowns, colour picker, configuration manager with memory fallback and a full animation engine.",
	})
	return tab
end

----------------------------------------------------------------------
-- Components
----------------------------------------------------------------------

local function buildComponents(window)
	local ctx = window.ctx
	local tab = window:CreateTab({
		Name = "Components",
		Icon = "components",
		Section = "LIBRARY",
		Order = 2000,
		Description = "Every control, with callbacks, Set() / Get() and disabled states.",
	})

	local buttons = tab:CreateSection("Buttons")
	buttons:CreateButton({
		Name = "Default button",
		Description = "Neutral action",
		Callback = function()
			window:SetStatus("Default button clicked", "Info")
		end,
	})
	buttons:CreateButton({ Name = "Primary button", Style = "Primary", Callback = function()
		window:SetStatus("Primary button clicked", "Success")
	end })
	buttons:CreateButton({ Name = "Danger button", Style = "Danger", Callback = function()
		window:SetStatus("Danger button clicked", "Error")
	end })
	buttons:CreateButton({ Name = "Disabled button", Disabled = true })

	local toggles = tab:CreateSection("Toggles and Sliders")
	toggles:CreateToggle({ Name = "Enable feature", Description = "Callback receives the new value", Default = true })
	local master = toggles:CreateToggle({ Name = "Master switch", Default = false })
	local dependent = toggles:CreateSlider({ Name = "Intensity", Min = 0, Max = 100, Default = 40, Suffix = "%" })
	dependent:SetDisabled(true)
	master.Changed:Connect(function(value)
		dependent:SetDisabled(not value)
	end)
	toggles:CreateSlider({ Name = "Precision", Min = 0, Max = 1, Increment = 0.05, Default = 0.5 })
	toggles:CreateToggle({ Name = "Disabled toggle", Default = true, Disabled = true })

	local selection = tab:CreateSection("Selection")
	selection:CreateDropdown({
		Name = "Mode",
		Options = { "Balanced", "Performance", "Quality", "Battery saver" },
		Default = "Balanced",
	})
	selection:CreateMultiDropdown({
		Name = "Features",
		Description = "Select any combination",
		Options = { "Shadows", "Reflections", "Particles", "Ambient occlusion", "Bloom", "Depth of field" },
		Default = { "Shadows", "Bloom" },
	})

	local input = tab:CreateSection("Input")
	input:CreateTextbox({ Name = "Display name", Placeholder = "Enter a name", Default = "" })
	input:CreateTextbox({ Name = "Amount", Numeric = true, Min = 0, Max = 999, Default = 25 })
	input:CreateKeybind({ Name = "Action key", Default = Enum.KeyCode.F })
	input:CreateColorPicker({ Name = "Highlight colour", Default = ctx.Theme.Colors.Accent })
	input:CreateSearchBar({
		Placeholder = "Type to search...",
		Callback = function(query)
			window:SetStatus(query == "" and "Search cleared" or ('Searching "' .. query .. '"'), "Info")
		end,
	})

	local display = tab:CreateSection("Display")
	display:CreateLabel({ Text = "Labels are plain themed text lines." })
	display:CreateDivider({ Text = "Divider" })
	display:CreateParagraph({
		Title = "Paragraph",
		Content = "Paragraphs wrap automatically and grow with their content, which makes them useful for descriptions and release notes.",
	})
	local progress = display:CreateProgressBar({ Name = "Download", Default = 64 })
	display:CreateProgressBar({ Name = "Indeterminate", Indeterminate = true })
	display:CreateLoadingIndicator({ Name = "Syncing...", Description = "Looping spinner" })
	display:CreateButton({
		Name = "Randomise progress",
		Callback = function()
			progress:Set(math.random(0, 100))
		end,
	})
	return tab
end

----------------------------------------------------------------------
-- Showcase
----------------------------------------------------------------------

local function buildShowcase(window)
	local ctx = window.ctx
	local Utils, theme, library = ctx.Utils, ctx.Theme, ctx.Library
	local colors, fonts, sizes = theme.Colors, theme.Fonts, theme.Sizes

	local tab = window:CreateTab({
		Name = "Showcase",
		Icon = "showcase",
		Section = "LIBRARY",
		Order = 2010,
		Description = "Design tokens and composed examples.",
	})

	-- Palette
	local palette = tab:CreateSection("Palette")
	local swatchRow = Utils.Create("Frame", {
		Name = "Swatches",
		Size = UDim2.new(1, 0, 0, 62),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
	})
	Utils.List(swatchRow, 6, Enum.FillDirection.Horizontal)
	palette:AddCustom(swatchRow)

	local keys = { "Background", "Surface", "Secondary", "Border", "Text", "Accent" }
	local hexLabels = {}
	for index, key in ipairs(keys) do
		local holder = Utils.Create("Frame", {
			Name = key,
			Size = UDim2.new(1 / #keys, -5, 1, 0),
			BackgroundTransparency = 1,
			LayoutOrder = index,
			Parent = swatchRow,
		})
		local chip = Utils.Create("Frame", {
			Size = UDim2.new(1, 0, 0, 36),
			BackgroundColor3 = colors[key],
			BorderSizePixel = 0,
			Parent = holder,
		})
		Utils.Corner(chip, theme.Layout.RadiusControl)
		Utils.Stroke(chip, colors.BorderHover, 1, 0.3)
		Utils.Text(theme, holder, {
			Text = key,
			Font = fonts.Medium,
			TextSize = sizes.Tiny,
			TextColor3 = colors.Muted,
			TextXAlignment = Enum.TextXAlignment.Center,
			TextTruncate = Enum.TextTruncate.AtEnd,
			Position = UDim2.fromOffset(0, 38),
			Size = UDim2.new(1, 0, 0, 11),
		})
		hexLabels[key] = Utils.Text(theme, holder, {
			Text = Utils.ColorToHex(colors[key]),
			Font = fonts.Mono,
			TextSize = sizes.Tiny - 1,
			TextColor3 = colors.Subtle,
			TextXAlignment = Enum.TextXAlignment.Center,
			Position = UDim2.fromOffset(0, 50),
			Size = UDim2.new(1, 0, 0, 11),
		})
	end
	window.Maid:Give(library.ThemeChanged:Connect(function()
		for key, label in pairs(hexLabels) do
			label.Text = Utils.ColorToHex(theme.Colors[key])
		end
	end))

	-- Typography
	local type_ = tab:CreateSection("Typography")
	local samples = {
		{ "Heading", fonts.Bold, sizes.Heading },
		{ "Title", fonts.SemiBold, sizes.Title },
		{ "Body text", fonts.Medium, sizes.Body },
		{ "Small and secondary", fonts.Regular, sizes.Small },
		{ "MONO  0123456789", fonts.Mono, sizes.Small },
	}
	for _, sample in ipairs(samples) do
		type_:CreateLabel({ Text = sample[1], Color = colors.Text }).Label.Font = sample[2]
		type_.Items[#type_.Items].Label.TextSize = sample[3]
	end

	-- Composed example
	local demo = tab:CreateSection("Composed Example")
	local task_ = demo:CreateProgressBar({ Name = "Simulated task", Default = 0 })
	local running = false
	demo:CreateButton({
		Name = "Run simulation",
		Description = "Drives the progress bar and posts a notification",
		Style = "Primary",
		Callback = function()
			if running then
				return
			end
			running = true
			task_:Set(0)
			window:SetStatus("Simulation running...", "Warning")
			task.spawn(function()
				for step = 1, 10 do
					task.wait(0.18)
					if window.Destroyed then
						return
					end
					task_:Set(step * 10)
				end
				running = false
				window:SetStatus("Simulation finished", "Success")
				ctx.Notifications:Notify({ Title = "Simulation complete", Content = "All steps finished.", Type = "Success" })
			end)
		end,
	})
	return tab
end

----------------------------------------------------------------------
-- Notifications
----------------------------------------------------------------------

local function buildNotifications(window)
	local ctx = window.ctx
	local tab = window:CreateTab({
		Name = "Notifications",
		Icon = "notifications",
		Section = "LIBRARY",
		Order = 2020,
		Description = "Toasts stack bottom-right, even while the window is minimized.",
	})

	local duration = 4
	local clickable = false
	local customTitle, customBody = "Custom notification", "Edit this text in the boxes above."

	local function send(kind, title, body)
		ctx.Notifications:Notify({
			Title = title,
			Content = body,
			Type = kind,
			Duration = duration,
			Callback = clickable and function()
				window:SetStatus("Toast clicked", "Info")
			end or nil,
		})
	end

	local triggers = tab:CreateSection("Severity")
	triggers:CreateButton(off({ Name = "Info", Callback = function()
		send("Info", "Information", "Something worth knowing.")
	end }))
	triggers:CreateButton(off({ Name = "Success", Callback = function()
		send("Success", "Saved", "Your changes were stored.")
	end }))
	triggers:CreateButton(off({ Name = "Warning", Callback = function()
		send("Warning", "Careful", "This action cannot be undone.")
	end }))
	triggers:CreateButton(off({ Name = "Error", Callback = function()
		send("Error", "Something failed", "The request could not be completed.")
	end }))

	local options = tab:CreateSection("Options")
	options:CreateSlider(off({
		Name = "Duration",
		Description = "0 keeps the toast until dismissed",
		Min = 0,
		Max = 10,
		Default = 4,
		Suffix = "s",
		Callback = function(value)
			duration = value
		end,
	}))
	options:CreateToggle(off({
		Name = "Clickable toast",
		Description = "Clicking the toast runs a callback",
		Callback = function(value)
			clickable = value
		end,
	}))

	local custom = tab:CreateSection("Custom")
	custom:CreateTextbox(off({ Name = "Title", Default = customTitle, Callback = function(value)
		customTitle = value
	end }))
	custom:CreateTextbox(off({ Name = "Message", Default = customBody, Callback = function(value)
		customBody = value
	end }))
	custom:CreateButton(off({ Name = "Send custom", Style = "Primary", Callback = function()
		send("Info", customTitle, customBody)
	end }))
	custom:CreateButton(off({ Name = "Clear all", Style = "Danger", Callback = function()
		ctx.Notifications:Clear()
	end }))
	return tab
end

----------------------------------------------------------------------
-- Modals
----------------------------------------------------------------------

local function buildModals(window)
	local ctx = window.ctx
	local Utils = ctx.Utils
	local tab = window:CreateTab({
		Name = "Modals",
		Icon = "modals",
		Section = "LIBRARY",
		Order = 2030,
		Description = "Dialogs, modals, context menus and tooltips.",
	})

	local dialogs = tab:CreateSection("Dialogs")
	dialogs:CreateButton(off({
		Name = "Confirmation dialog",
		Description = "Backdrop, scale-in panel, destructive action",
		Callback = function()
			ctx.Overlay:Dialog({
				Title = "Reset all settings?",
				Content = "This restores every value to its default. You can load a saved configuration afterwards.",
				Buttons = {
					{ Text = "Cancel" },
					{ Text = "Reset", Style = "Danger", Callback = function()
						ctx.Notifications:Notify({ Title = "Settings reset", Type = "Warning" })
					end },
				},
			})
		end,
	}))

	dialogs:CreateButton(off({
		Name = "Input form modal",
		Description = "Components inside a modal body",
		Callback = function()
			local fields = {}
			ctx.Overlay:Modal({
				Title = "Create profile",
				Content = "Components can be created inside any modal.",
				Height = 150,
				Build = function(body)
					local container = ctx.Components.NewContainer(ctx, body)
					fields.name = container:CreateTextbox({ Name = "Name", Placeholder = "My profile", Flag = false })
					fields.color = container:CreateColorPicker({ Name = "Colour", Flag = false })
					fields.public = container:CreateToggle({ Name = "Shared", Flag = false })
				end,
				Buttons = {
					{ Text = "Cancel" },
					{ Text = "Create", Style = "Primary", Callback = function()
						local name = fields.name:Get()
						if not name or Utils.Trim(name) == "" then
							ctx.Notifications:Notify({ Title = "Name required", Type = "Error" })
							return false
						end
						ctx.Notifications:Notify({
							Title = "Profile created",
							Content = name .. (fields.public:Get() and " (shared)" or ""),
							Type = "Success",
						})
						return true
					end },
				},
			})
		end,
	}))

	local menus = tab:CreateSection("Menus and Tooltips")
	local items = {
		{ Text = "Copy flag id", Shortcut = "Ctrl+C", Callback = function()
			window:SetStatus("Copied", "Success")
		end },
		{ Text = "Reset to default", Shortcut = "Ctrl+R", Callback = function()
			window:SetStatus("Reset", "Warning")
		end },
		{ Divider = true },
		{ Text = "Unavailable action", Disabled = true },
		{ Text = "Delete", Shortcut = "Del", Danger = true, Callback = function()
			window:SetStatus("Deleted", "Error")
		end },
	}
	menus:CreateButton(off({
		Name = "Right-click or long-press me",
		Description = "A context menu opens at the pointer",
		ContextMenu = items,
		Callback = function()
			window:SetStatus("Try right-clicking this row", "Info")
		end,
	}))
	menus:CreateButton(off({
		Name = "Open context menu here",
		Callback = function()
			local root = window.Root
			ctx.Overlay:ContextMenu(items, Vector2.new(root.AbsolutePosition.X + 220, root.AbsolutePosition.Y + 140))
		end,
	}))
	menus:CreateButton(off({
		Name = "Hover for a tooltip",
		Tooltip = "Tooltips appear after a short delay and never leave the screen.",
	}))
	return tab
end

----------------------------------------------------------------------
-- Configurations
----------------------------------------------------------------------

local function buildConfigurations(window)
	local ctx = window.ctx
	local Utils, theme = ctx.Utils, ctx.Theme
	local colors, fonts, sizes = theme.Colors, theme.Fonts, theme.Sizes
	local config = ctx.Config
	local pad = theme.Layout.Padding

	local tab = window:CreateTab({
		Name = "Configurations",
		Icon = "configurations",
		Section = "SYSTEM",
		Order = 3000,
		Description = "Save, load and share every component value.",
	})

	local function report(ok, result, success)
		if ok then
			ctx.Notifications:Notify({ Title = success, Type = "Success" })
			window:SetStatus(success, "Success")
		else
			ctx.Notifications:Notify({ Title = "Configuration error", Content = tostring(result), Type = "Error" })
			window:SetStatus(tostring(result), "Error")
		end
	end

	-- Create
	local create = tab:CreateSection("Create")
	local nameBox = create:CreateTextbox(off({ Name = "Name", Placeholder = "My config", MaxLength = 40 }))
	create:CreateButton(off({
		Name = "Save current values",
		Style = "Primary",
		Description = config:GetBackend() .. " storage",
		Callback = function()
			local ok, result = config:Save(nameBox:Get())
			report(ok, result, "Saved '" .. tostring(nameBox:Get()) .. "'")
			if ok then
				nameBox:Set("", true)
			end
		end,
	}))

	-- Saved list
	local saved = tab:CreateSection("Saved")
	local listFrame = Utils.Create("Frame", {
		Name = "List",
		Size = UDim2.new(1, 0, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
	})
	Utils.List(listFrame, theme.Layout.Gap)
	saved:AddCustom(listFrame)

	local listMaid = Utils.Maid.new()
	window.Maid:Give(listMaid)

	local function addRow(entry, index, autoload)
		local rowFrame = card(ctx, 54)
		rowFrame.LayoutOrder = index
		rowFrame.Parent = listFrame

		Utils.Text(theme, rowFrame, {
			Name = "Name",
			Text = entry.Name .. (autoload == entry.Name and "   AUTOLOAD" or ""),
			Font = fonts.SemiBold,
			TextSize = sizes.Body,
			TextTruncate = Enum.TextTruncate.AtEnd,
			Position = UDim2.fromOffset(pad, 9),
			Size = UDim2.new(1, -(pad * 2 + 196), 0, 18),
		})
		Utils.Text(theme, rowFrame, {
			Name = "Meta",
			Text = formatTime(entry.Modified) .. "  -  " .. formatBytes(entry.Size),
			Font = fonts.Regular,
			TextSize = sizes.Tiny + 1,
			TextColor3 = colors.Muted,
			TextTruncate = Enum.TextTruncate.AtEnd,
			Position = UDim2.fromOffset(pad, 29),
			Size = UDim2.new(1, -(pad * 2 + 196), 0, 14),
		})

		local buttons = Utils.Create("Frame", {
			Name = "Buttons",
			AnchorPoint = Vector2.new(1, 0.5),
			Position = UDim2.new(1, -pad, 0.5, 0),
			Size = UDim2.fromOffset(190, 26),
			BackgroundTransparency = 1,
			Parent = rowFrame,
		})
		Utils.List(buttons, 4, Enum.FillDirection.Horizontal, Enum.HorizontalAlignment.Right)

		local function small(text, style, order, width, callback)
			Utils.CreateButton(ctx, buttons, {
				Text = text,
				Style = style,
				Width = width,
				Height = 26,
				LayoutOrder = order,
				Maid = listMaid,
				Callback = callback,
			})
		end

		small("Load", "Primary", 1, 46, function()
			local ok, result = config:Load(entry.Name)
			local message = "Loaded '" .. entry.Name .. "'"
			if ok and type(result) == "table" then
				message = message .. " (" .. result.Applied .. " values)"
			end
			report(ok, result, message)
		end)
		small("Save", "Default", 2, 46, function()
			local ok, result = config:Save(entry.Name)
			report(ok, result, "Overwrote '" .. entry.Name .. "'")
		end)
		small(autoload == entry.Name and "Auto  on" or "Auto", autoload == entry.Name and "Primary" or "Ghost", 3, autoload == entry.Name and 58 or 44, function()
			config:SetAutoload(autoload ~= entry.Name and entry.Name or nil)
		end)
		small("Del", "Danger", 4, 36, function()
			ctx.Overlay:Dialog({
				Title = "Delete '" .. entry.Name .. "'?",
				Content = "This cannot be undone.",
				Buttons = {
					{ Text = "Cancel" },
					{ Text = "Delete", Style = "Danger", Callback = function()
						local ok, result = config:Delete(entry.Name)
						report(ok, result, "Deleted '" .. entry.Name .. "'")
					end },
				},
			})
		end)
	end

	local emptyState
	local function refresh()
		listMaid:Clean()
		for _, child in ipairs(listFrame:GetChildren()) do
			if child:IsA("GuiObject") then
				child:Destroy()
			end
		end
		emptyState = nil

		local entries = config:List()
		local autoload = config:GetAutoload()
		if #entries == 0 then
			emptyState = card(ctx, 64)
			emptyState.Parent = listFrame
			Utils.Text(theme, emptyState, {
				Text = "No saved configurations yet",
				Font = fonts.SemiBold,
				TextSize = sizes.Body,
				TextXAlignment = Enum.TextXAlignment.Center,
				Position = UDim2.fromOffset(0, 12),
				Size = UDim2.new(1, 0, 0, 18),
			})
			Utils.Text(theme, emptyState, {
				Text = "Name a configuration above and press Save.",
				Font = fonts.Regular,
				TextSize = sizes.Small,
				TextColor3 = colors.Muted,
				TextXAlignment = Enum.TextXAlignment.Center,
				Position = UDim2.fromOffset(0, 33),
				Size = UDim2.new(1, 0, 0, 16),
			})
			return
		end
		for index, entry in ipairs(entries) do
			addRow(entry, index, autoload)
		end
	end
	refresh()
	window.Maid:Give(config.Changed:Connect(refresh))

	-- Tools
	local tools = tab:CreateSection("Share")
	tools:CreateButton(off({
		Name = "Export current values",
		Description = "Copies JSON when the clipboard is available",
		Callback = function()
			local json, err = config:Encode(config.Current or "Export")
			if not json then
				report(false, err)
				return
			end
			local copied = copyToClipboard(json)
			ctx.Overlay:Modal({
				Title = "Exported configuration",
				Content = copied and "Copied to the clipboard." or "Select the text below and copy it.",
				Height = 130,
				Build = function(body)
					Utils.Create("TextBox", {
						Name = "Json",
						Size = UDim2.new(1, 0, 0, 120),
						BackgroundColor3 = colors.Background,
						BorderSizePixel = 0,
						Font = fonts.Mono,
						TextSize = sizes.Tiny + 1,
						TextColor3 = colors.Text,
						TextXAlignment = Enum.TextXAlignment.Left,
						TextYAlignment = Enum.TextYAlignment.Top,
						TextWrapped = true,
						MultiLine = true,
						ClearTextOnFocus = false,
						Text = json,
						Parent = body,
					})
				end,
				Buttons = { { Text = "Done", Style = "Primary" } },
			})
		end,
	}))
	tools:CreateButton(off({
		Name = "Import from JSON",
		Callback = function()
			local fields = {}
			ctx.Overlay:Modal({
				Title = "Import configuration",
				Height = 190,
				Build = function(body)
					local container = ctx.Components.NewContainer(ctx, body)
					fields.name = container:CreateTextbox({ Name = "Save as", Placeholder = "Imported", Flag = false })
					local holder = Utils.Create("Frame", {
						Size = UDim2.new(1, 0, 0, 110),
						BackgroundColor3 = colors.Background,
						BorderSizePixel = 0,
						LayoutOrder = 100,
						Parent = body,
					})
					Utils.Corner(holder, theme.Layout.RadiusControl)
					Utils.Stroke(holder, colors.Border, 1, 0)
					fields.json = Utils.Create("TextBox", {
						Name = "Json",
						Position = UDim2.fromOffset(8, 6),
						Size = UDim2.new(1, -16, 1, -12),
						BackgroundTransparency = 1,
						BorderSizePixel = 0,
						Font = fonts.Mono,
						TextSize = sizes.Tiny + 1,
						TextColor3 = colors.Text,
						PlaceholderText = "Paste configuration JSON here",
						PlaceholderColor3 = colors.Subtle,
						TextXAlignment = Enum.TextXAlignment.Left,
						TextYAlignment = Enum.TextYAlignment.Top,
						TextWrapped = true,
						MultiLine = true,
						ClearTextOnFocus = false,
						Text = "",
						Parent = holder,
					})
				end,
				Buttons = {
					{ Text = "Cancel" },
					{ Text = "Import", Style = "Primary", Callback = function()
						local ok, result = config:Import(fields.name:Get() or "", fields.json.Text)
						report(ok, result, "Imported '" .. tostring(fields.name:Get()) .. "'")
						if not ok then
							return false
						end
						return true
					end },
				},
			})
		end,
	}))
	tools:CreateButton(off({
		Name = "Refresh list",
		Callback = refresh,
	}))
	return tab
end

----------------------------------------------------------------------
-- Settings
----------------------------------------------------------------------

local function buildSettings(window)
	local ctx = window.ctx
	local theme, library = ctx.Theme, ctx.Library

	local tab = window:CreateTab({
		Name = "Settings",
		Icon = "settings",
		Section = "SYSTEM",
		Order = 3010,
		Description = "Appearance and interface behaviour.",
	})

	local appearance = tab:CreateSection("Appearance")
	local accent
	appearance:CreateDropdown(off({
		Name = "Theme",
		Description = "Switches every colour live",
		Options = library:GetThemeNames(),
		Default = theme.Name,
		Callback = function(name)
			if library:SetTheme(name) and accent then
				accent:Set(theme.Colors.Accent, true)
			end
		end,
	}))
	accent = appearance:CreateColorPicker(off({
		Name = "Accent colour",
		Default = theme.Colors.Accent,
		Callback = function(color)
			library:SetAccent(color)
		end,
	}))
	appearance:CreateSlider(off({
		Name = "Window transparency",
		Min = 0,
		Max = 60,
		Default = math.floor(theme.Transparency.Window * 100 + 0.5),
		Suffix = "%",
		Callback = function(value)
			window:SetTransparency(value / 100)
		end,
	}))
	appearance:CreateToggle(off({
		Name = "Background blur",
		Description = "Soft blur behind the interface",
		Callback = function(value)
			window:SetBlur(value)
		end,
	}))
	appearance:CreateSlider(off({
		Name = "Animation speed",
		Min = 0.5,
		Max = 2,
		Increment = 0.25,
		Default = 1,
		Suffix = "x",
		Callback = function(value)
			ctx.Animation:SetSpeed(value)
		end,
	}))

	local interface = tab:CreateSection("Interface")
	interface:CreateKeybind(off({
		Name = "Toggle window",
		Description = "Shows or hides the window",
		Default = window.ToggleKey,
		OnChanged = function(name)
			local ok, key = pcall(function()
				return Enum.KeyCode[name]
			end)
			if ok and key then
				window:SetToggleKey(key)
			end
		end,
	}))
	interface:CreateToggle(off({
		Name = "Tooltips",
		Default = true,
		Callback = function(value)
			ctx.Settings.Tooltips = value
		end,
	}))
	interface:CreateToggle(off({
		Name = "Confirm before closing",
		Default = window.ConfirmClose,
		Callback = function(value)
			window.ConfirmClose = value
		end,
	}))
	interface:CreateSlider(off({
		Name = "Notification duration",
		Min = 1,
		Max = 15,
		Default = ctx.Settings.NotificationDuration,
		Suffix = "s",
		Callback = function(value)
			ctx.Settings.NotificationDuration = value
		end,
	}))

	local about = tab:CreateSection("About")
	about:CreateParagraph({
		Title = "AETHER UI v" .. library.Version,
		Content = "Premium dark minimalism with acrylic surfaces. Configurations are stored in "
			.. ctx.Config:GetBackend():lower() .. " storage.",
	})
	about:CreateButton(off({
		Name = "Destroy interface",
		Style = "Danger",
		Callback = function()
			ctx.Overlay:Dialog({
				Title = "Destroy AETHER UI?",
				Content = "Every window, connection and animation will be removed.",
				Buttons = {
					{ Text = "Cancel" },
					{ Text = "Destroy", Style = "Danger", Callback = function()
						task.defer(function()
							library:Destroy()
						end)
					end },
				},
			})
		end,
	}))
	return tab
end

----------------------------------------------------------------------
-- Public
----------------------------------------------------------------------

function Pages.Build(window, spec)
	if enabled(spec, "Dashboard") then
		buildDashboard(window)
	end
	if enabled(spec, "Components") then
		buildComponents(window)
	end
	if enabled(spec, "Showcase") then
		buildShowcase(window)
	end
	if enabled(spec, "Notifications") then
		buildNotifications(window)
	end
	if enabled(spec, "Modals") then
		buildModals(window)
	end
	if enabled(spec, "Configurations") then
		buildConfigurations(window)
	end
	if enabled(spec, "Settings") then
		buildSettings(window)
	end
end

return Pages
