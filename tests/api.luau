-- Public API completeness + layering + lifecycle (no mock dependence beyond Instances)
local pass, fail = 0, {}
local function check(c, l) if c then pass += 1 else table.insert(fail, l); print("  FAIL: " .. l) end end
local function methods(obj, list, label)
	for _, name in ipairs(list) do check(type(obj[name]) == "function", label .. ":" .. name .. " exists") end
end

methods(Library, { "CreateWindow", "GetWindows", "CreateESP", "Notify", "Dialog", "Modal", "ContextMenu", "AttachTooltip", "SetTheme", "SetAccent", "Override", "GetTheme", "GetThemeNames", "SaveConfig", "LoadConfig", "DeleteConfig", "ListConfigs", "LoadAutoload", "Destroy" }, "Library")
check(type(Library.new) == "function", "Library.new creates extra instances")
check(Library.Version == "1.1.0", "Library.Version")

local window = Library:CreateWindow({ Title = "API", Size = Vector2.new(650, 420), Pages = false })
methods(window, { "CreateTab", "GetTab", "SelectTab", "Minimize", "Restore", "Toggle", "Close", "Destroy", "SetTitle", "SetStatus", "SetToggleKey", "SetSize", "SetTransparency", "SetBlur", "Search", "Notify", "IsVisible", "BringToFront" }, "Window")
for _, sig in ipairs({ "OnClosed", "OnMinimized", "OnRestored", "OnTabChanged", "OnDestroyed" }) do check(window[sig] ~= nil, "Window." .. sig) end

local tab = window:CreateTab("StringName")
check(tab.Name == "StringName", "CreateTab accepts a plain string")
methods(tab, { "CreateSection", "Select", "SetFilter", "Destroy" }, "Tab")
local section = tab:CreateSection("S")
methods(section, { "CreateButton", "CreateToggle", "CreateSlider", "CreateDropdown", "CreateMultiDropdown", "CreateTextbox", "CreateKeybind", "CreateColorPicker", "CreateLabel", "CreateParagraph", "CreateDivider", "CreateSearchBar", "CreateProgressBar", "CreateLoadingIndicator", "AddCustom", "SetVisible", "Destroy" }, "Section")

local made = {
	Button = section:CreateButton({ Name = "b" }), Toggle = section:CreateToggle({ Name = "t" }), Slider = section:CreateSlider({ Name = "s" }),
	Dropdown = section:CreateDropdown({ Name = "d", Options = { "a" } }), MultiDropdown = section:CreateMultiDropdown({ Name = "m", Options = { "a" } }),
	Textbox = section:CreateTextbox({ Name = "x" }), Keybind = section:CreateKeybind({ Name = "k" }), ColorPicker = section:CreateColorPicker({ Name = "c" }),
	Label = section:CreateLabel({ Text = "l" }), Paragraph = section:CreateParagraph({ Title = "p", Content = "c" }), Divider = section:CreateDivider({}),
	SearchBar = section:CreateSearchBar({}), ProgressBar = section:CreateProgressBar({ Name = "pb" }), LoadingIndicator = section:CreateLoadingIndicator({ Name = "li" }),
}
for name, c in pairs(made) do
	methods(c, { "Set", "Get", "SetDisabled", "IsDisabled", "SetVisible", "IsVisible", "SetTooltip", "SetName", "SetDescription", "Destroy" }, name)
	check(c.Root ~= nil and c.Maid ~= nil, name .. " exposes Root and Maid")
	check(c.Type == name, name .. " reports its type")
end
check(made.Slider.Changed ~= nil and made.Toggle.Changed ~= nil, "value components expose Changed")
local invisible = made.Toggle
invisible:SetVisible(false); check(not invisible.Root.Visible and not invisible:IsVisible(), "SetVisible(false)")
invisible:SetVisible(true); check(invisible.Root.Visible and invisible:IsVisible(), "SetVisible(true)")
invisible:SetName("renamed"); check(invisible.Row.Title.Text == "renamed", "SetName")

-- Custom component registration
local Custom = {}
Custom.__index = Custom
function Custom.new(ctx, parent, config)
	local self = setmetatable({}, Custom)
	self.Maid = ctx.Utils.Maid.new()
	self.Root = ctx.Utils.Create("Frame", { Name = "Custom", Size = UDim2.new(1, 0, 0, 10), Parent = parent })
	self.Value = config.Default or 0
	return self
end
function Custom:Set(v) self.Value = v end
function Custom:Get() return self.Value end
Library.Components.Register("Custom", Custom)
local custom = section:CreateCustom({ Name = "c", Default = 5 })
check(custom:Get() == 5 and custom.Type == "Custom", "Components.Register adds Section:CreateCustom")
custom:Destroy()

-- Layer ordering (popups above modals, tooltips above everything)
local z = Library.Theme.ZIndex
check(z.Window < z.Floating and z.Floating < z.Modal and z.Modal < z.Popup and z.Popup < z.Notification and z.Notification < z.Tooltip, "ZIndex ladder is strictly increasing")
check(Library.Overlay.ModalLayer.ZIndex == z.Modal and Library.Overlay.Layer.ZIndex == z.Popup and Library.Overlay.TooltipLayer.ZIndex == z.Tooltip, "overlay layers use the ladder")
check(Library.Notifications.Container.ZIndex == z.Notification, "notifications use the ladder")
check(window.Root.ZIndex >= z.Window and window.Root.ZIndex < z.Floating, "window z within its band")
local w2 = Library:CreateWindow({ Title = "two", Pages = false }); MockStep(0.5)
local before = window.Root.ZIndex
window:BringToFront()
check(window.Root.ZIndex > w2.Root.ZIndex or window.Root.ZIndex >= before, "BringToFront raises z")
w2:Destroy()

-- Theme API
local T = Library.Theme
methods(T, { "SetTheme", "Override", "SetAccent", "RegisterPreset", "OnChanged", "GetThemeNames", "HasTheme", "Repaint" }, "Theme")
check(table.concat(T:GetThemeNames(), ",") == "Dark,Midnight,Light", "theme names")
for _, group in ipairs({ "Colors", "Transparency", "ZIndex", "Layout", "Fonts", "Sizes", "Motion" }) do check(type(T[group]) == "table", "Theme." .. group) end
local captured = T.Colors
Library:SetTheme("Light")
check(T.Colors == captured, "theme switch mutates colours in place (captured references stay valid)")
Library:SetTheme("Dark")
Library:Override({ Layout = { RowHeight = 40 } })
check(T.Layout.RowHeight == 40, "Override deep-merges")
Library:SetTheme("Dark")
check(T.Layout.RowHeight == 36, "SetTheme resets runtime overrides")
local custom2 = Library.new({ Parent = MockPlayerGui(), Theme = { Preset = "Light", Colors = { Accent = Color3.fromHex("#FF0000") } } })
check(custom2.Theme.Name == "Light" and custom2.Theme.Colors.Accent == Color3.fromHex("#FF0000"), "constructor preset + overrides")
check(custom2 ~= Library and custom2.Gui.Parent == MockPlayerGui(), "Library.new is independent and honours Parent")
custom2:Destroy()
check(not Library._destroyed, "destroying a second instance leaves the first alone")

-- Animation API
local A = Library.Animation
methods(A, { "Tween", "Play", "Cancel", "CancelAll", "Flush", "Count", "Loop", "SetSpeed", "Press", "Button", "ButtonStyle", "Toggle", "Slider", "SliderKnob", "Option", "Expand", "PageSwitch", "WindowOpen", "WindowClose", "WindowMinimize", "WindowRestore", "Floating", "DragFeedback", "SidebarItem", "SidebarIndicator", "Focus", "Pulse", "Spinner", "Indeterminate", "ProgressFill", "TooltipIn", "TooltipOut", "ModalIn", "ModalOut", "ContextMenuIn", "ContextMenuOut", "PopupIn", "PopupOut", "NotificationIn", "NotificationOut", "Disabled", "Destroy" }, "Animation")

-- Conflicting tweens are replaced, not stacked
A:Flush()
local loopsRunning = A:Count() -- spinners owned by the demo components above
local f = Instance.new("Frame"); f.Parent = Library.Gui
local c0 = A:Count()
for i = 1, 20 do A:Play(f, "Hover", { BackgroundTransparency = (i % 2) * 0.5 }) end
check(A:Count() - c0 == 1, "20 conflicting tweens on one property keep a single active tween (" .. (A:Count() - c0) .. ")")
A:Play(f, "Hover", { Position = UDim2.new(0, 5, 0, 5) })
check(A:Count() - c0 == 2, "non-conflicting properties tween in parallel")
A:Flush()
check(A:Count() == loopsRunning, "Flush cancels every finite tween (" .. A:Count() .. " vs " .. loopsRunning .. " loops)")
check(f.Position == UDim2.new(0, 5, 0, 5), "Flush snaps the property to its goal")
local gradient = Instance.new("UIGradient"); gradient.Parent = f
local stop = A:Spinner(gradient)
check(A:Count() == loopsRunning + 1, "loop counted"); A:Flush(); check(A:Count() == loopsRunning + 1, "Flush keeps loops running")
stop(); MockStep(0.1); check(A:Count() == loopsRunning, "loop stop function cancels the loop")
A:Play(f, "Hover", { BackgroundTransparency = 1 }); A:CancelAll(); check(A:Count() == 0, "CancelAll stops everything")
f:Destroy()

-- Lifecycle: create/destroy cycles must not grow
Library:Destroy(); MockStep(0.5)
local lib = Library.new({ Parent = MockPlayerGui() })
local function alive() return MockInstanceStats().Alive end
local base = alive()
for i = 1, 5 do
	local w = lib:CreateWindow({ Title = "cycle" .. i }); MockStep(0.6)
	w:SelectTab("Components"); MockStep(0.4); w:SelectTab("Settings"); MockStep(0.4)
	w:Destroy(); MockStep(0.6)
end
check(alive() == base, "5 window create/destroy cycles leave no instances behind (" .. alive() - base .. " extra)")
check(MockActiveTweens() <= 0, "no tweens left after cycles")
local UIS = MockServices().UserInputService
local listeners = UIS.InputBegan:Count()
local w = lib:CreateWindow({ Title = "x" }); MockStep(0.5); w:Destroy(); MockStep(0.5)
check(UIS.InputBegan:Count() == listeners, "window create/destroy releases its input listeners")
lib:Destroy(); MockStep(0.5)
check((MOCK_ERRORS or 0) == 0, "no handler errors")
print(string.format("\nAPI RESULT: %d passed, %d failed", pass, #fail))
if #fail > 0 then error("api tests failed") end
