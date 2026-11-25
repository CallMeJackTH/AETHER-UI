--[[ Behavioural tests against the mock. Globals provided: Library + mock helpers. ]]
local results = { pass = 0, fail = 0, failures = {} }
local function check(cond, label)
	if cond then results.pass += 1 else results.fail += 1; table.insert(results.failures, label); print("  FAIL: " .. label) end
end
local function section(name) print("== " .. name) end
local function eq(a, b, label) check(a == b, label .. " (got " .. tostring(a) .. ", expected " .. tostring(b) .. ")") end
local function throws(fn, label) local ok = pcall(fn); check(not ok, label) end
local function find(root, name)
	if root.Name == name then return root end
	return root:FindFirstChild(name, true)
end
local function findAll(root, pred)
	local out = {}
	for _, d in ipairs(root:GetDescendants()) do if pred(d) then table.insert(out, d) end end
	return out
end
local UIS = MockServices().UserInputService

----------------------------------------------------------------------
section("Window + built-in pages")
local window = Library:CreateWindow({ Title = "AETHER", Size = Vector2.new(650, 420) })
MockStep(1)
local names = {}
for _, t in ipairs(window.Tabs) do table.insert(names, t.Name) end
eq(table.concat(names, ","), "Dashboard,Components,Showcase,Notifications,Modals,Configurations,Settings", "seven built-in pages in order")
eq(window.ActiveTab.Name, "Dashboard", "dashboard active first")
eq(window.Root.Size.X.Offset, 650, "window width 650")
eq(window.Root.Size.Y.Offset, 420, "window height 420")
eq(window.Topbar.Size.Y.Offset, 42, "topbar 42px")
eq(window.Sidebar.Frame.Size.X.Offset, 165, "sidebar 165px")
check(window.Root.Visible, "window visible after open")
eq(window.Canvas.GroupTransparency, 0, "canvas fully visible after entrance")
eq(MOCK_ERRORS or 0, 0, "no handler errors during construction")

----------------------------------------------------------------------
section("Public API: CreateTab / CreateSection / CreateButton / CreateToggle")
local tab = window:CreateTab({ Name = "Main", Icon = "dashboard" })
local sec = tab:CreateSection("General")
local clicks = 0
local button = sec:CreateButton({ Name = "Click me", Callback = function() clicks += 1 end })
button:Fire()
eq(clicks, 1, "button callback fires")
button.Root.Activated:Fire()
eq(clicks, 2, "button Activated fires callback")
local last
local toggle = sec:CreateToggle({ Name = "Enabled", Default = true, Callback = function(v) last = v end })
eq(toggle:Get(), true, "toggle default")
toggle:Set(false)
eq(toggle:Get(), false, "toggle Set/Get")
eq(last, false, "toggle callback receives value")
last = "untouched"
toggle:Set(true, true)
eq(last, "untouched", "silent Set skips callback")
eq(toggle:Get(), true, "silent Set still changes value")
toggle:SetDisabled(true)
check(toggle:IsDisabled(), "disabled flag")
toggle.Root.Activated:Fire()
eq(toggle:Get(), true, "disabled toggle ignores click")
toggle:SetDisabled(false)
toggle.Root.Activated:Fire()
eq(toggle:Get(), false, "enabled toggle responds to click")
eq(window:GetTab("Main"), tab, "GetTab")
local sidebarOrder = {}
for _, section_ in pairs(window.Sidebar._sections) do for _, item in ipairs(section_.Items) do sidebarOrder[item.Id] = item.Order end end
check(sidebarOrder["main"] > sidebarOrder["dashboard"] and sidebarOrder["main"] < sidebarOrder["components"], "user tab sorts between MAIN and LIBRARY")

----------------------------------------------------------------------
section("Every component: Set / Get / callbacks / flags")
local ctab = window:CreateTab({ Name = "Kit" })
local s = ctab:CreateSection("All")
local got = {}
local slider = s:CreateSlider({ Name = "Vol", Min = 0, Max = 10, Default = 3, Increment = 0.5, Suffix = "x", Callback = function(v) got.slider = v end })
eq(slider:Get(), 3, "slider default")
slider:Set(7.3)
eq(slider:Get(), 7.5, "slider rounds to increment")
slider:Set(99)
eq(slider:Get(), 10, "slider clamps max")
slider:Set(-5)
eq(slider:Get(), 0, "slider clamps min")
eq(got.slider, 0, "slider callback")

local dropdown = s:CreateDropdown({ Name = "Mode", Options = { "A", "B", "C" }, Default = "B", Callback = function(v) got.dd = v end })
eq(dropdown:Get(), "B", "dropdown default")
dropdown:Set("C")
eq(dropdown:Get(), "C", "dropdown Set")
eq(got.dd, "C", "dropdown callback")
check(not dropdown:Set("nope"), "dropdown rejects unknown option")
eq(dropdown:Get(), "C", "dropdown unchanged after invalid Set")
dropdown:SetOptions({ "X", "Y" })
eq(dropdown:Get(), nil, "dropdown clears selection when option vanishes")
dropdown:Set("Y", true)

local multi = s:CreateMultiDropdown({ Name = "Multi", Options = { "a", "b", "c", "d" }, Default = { "a", "c" }, Callback = function(v) got.multi = v end })
eq(table.concat(multi:Get(), ","), "a,c", "multi default")
multi:Toggle("b")
eq(table.concat(multi:Get(), ","), "a,b,c", "multi toggle on (option order)")
multi:Toggle("a")
eq(table.concat(got.multi, ","), "b,c", "multi callback")
multi:Set({ "d" })
eq(table.concat(multi:Get(), ","), "d", "multi Set")
local limited = s:CreateMultiDropdown({ Name = "Limited", Options = { "1", "2", "3" }, Max = 2 })
limited:Toggle("1"); limited:Toggle("2"); limited:Toggle("3")
eq(#limited:Get(), 2, "multi Max enforced")

local textbox = s:CreateTextbox({ Name = "Name", Default = "hi", Callback = function(v, enter) got.tb = v end })
eq(textbox:Get(), "hi", "textbox default")
textbox:Set("yo")
eq(textbox:Get(), "yo", "textbox Set")
textbox.Box.Text = "typed"
textbox.Box.FocusLost:Fire(true)
eq(got.tb, "typed", "textbox commits on FocusLost")
local numeric = s:CreateTextbox({ Name = "Num", Numeric = true, Min = 0, Max = 10, Default = 5 })
eq(numeric:Get(), 5, "numeric default")
numeric.Box.Text = "99"
numeric.Box.FocusLost:Fire(false)
eq(numeric:Get(), 10, "numeric clamps")
numeric.Box.Text = "abc"
eq(numeric.Box.Text, "", "numeric filters letters")
numeric.Box.FocusLost:Fire(false)
eq(numeric:Get(), 10, "numeric reverts on invalid")

local key = s:CreateKeybind({ Name = "Key", Default = Enum.KeyCode.F, Callback = function(p) got.keyPressed = p end, OnChanged = function(n) got.keyChanged = n end })
eq(key:Get(), "F", "keybind default")
MockPressKey(Enum.KeyCode.F)
eq(got.keyPressed, true, "bound key press fires Callback")
key:Set(Enum.KeyCode.G)
eq(key:Get(), "G", "keybind Set(enum)")
eq(got.keyChanged, "G", "keybind OnChanged")
key:Set("MouseButton2", true)
eq(key:Get(), "MouseButton2", "keybind accepts mouse button name")
key:Set("None", true)
eq(key:Get(), "None", "keybind none")
-- Listening flow
key.Root.Activated:Fire()
check(key.Listening, "keybind listens after click")
check(Library.Ctx.State.CapturingKey, "capturing flag raised")
MockPressKey(Enum.KeyCode.H)
eq(key:Get(), "H", "keybind binds the next key")
check(not key.Listening, "keybind stops listening after bind")
check(not Library.Ctx.State.CapturingKey, "capturing flag cleared")
key.Root.Activated:Fire()
MockPressKey(Enum.KeyCode.Escape)
eq(key:Get(), "H", "escape cancels binding")
key.Root.Activated:Fire()
MockPressKey(Enum.KeyCode.Backspace)
eq(key:Get(), "None", "backspace clears binding")

local picker = s:CreateColorPicker({ Name = "Color", Default = Color3.fromHex("#FF0000"), Callback = function(c) got.color = c end })
eq(picker:Serialize(), "#FF0000", "color serialize")
picker:Set(Color3.fromHex("#00FF00"))
eq(picker:Serialize(), "#00FF00", "color Set")
picker:Set("#0000FF", true)
eq(picker:Serialize(), "#0000FF", "color Set(hex string)")
picker:Deserialize("#123456")
eq(picker:Serialize(), "#123456", "color Deserialize")

local label = s:CreateLabel({ Text = "hello" })
label:Set("bye"); eq(label:Get(), "bye", "label Set/Get")
local para = s:CreateParagraph({ Title = "T", Content = "C" })
para:Set("D"); eq(para:Get(), "D", "paragraph Set/Get")
local div = s:CreateDivider({ Text = "part" }); eq(div:Get(), "part", "divider text")
local search = s:CreateSearchBar({ Placeholder = "find", Callback = function(q) got.q = q end })
search:Set("abc"); eq(search:Get(), "abc", "searchbar Set/Get")
eq(got.q, "abc", "searchbar callback on Set")
local progress = s:CreateProgressBar({ Name = "P", Default = 25 })
progress:Set(60); eq(progress:Get(), 60, "progress Set/Get")
progress:Set(500); eq(progress:Get(), 100, "progress clamps")
progress:SetIndeterminate(true); check(progress.Indeterminate, "progress indeterminate on")
progress:SetIndeterminate(false); check(not progress.Indeterminate, "progress indeterminate off")
local loader = s:CreateLoadingIndicator({ Name = "L" })
check(loader:Get(), "loader active by default")
loader:Set(false); check(not loader:Get(), "loader stops")
loader:Set(true); check(loader:Get(), "loader restarts")
MockStep(0.5)

for _, comp in ipairs({ slider, dropdown, multi, textbox, numeric, key, picker, search, progress, loader, label, para, div, button }) do
	comp:SetDisabled(true)
	check(comp:IsDisabled(), "disabled: " .. comp.Type)
	comp:SetDisabled(false)
end
local flags = Library.Config:GetFlags()
local function hasFlag(f) return table.find(flags, f) ~= nil end
check(hasFlag("Kit.All.Vol"), "auto flag path Tab.Section.Name")
check(not hasFlag("Kit.All.Click me"), "buttons are not persisted")
check(not hasFlag("Kit.All.P"), "progress is not persisted")
check(not hasFlag("Kit.All.find"), "searchbar is not persisted")
throws(function() s:_create("Nope", {}) end, "unknown component type errors")

----------------------------------------------------------------------
section("Inline dropdown open/close + popup registry")
dropdown:Set("X", true)
dropdown:Open()
check(dropdown.Shell.IsOpen, "dropdown opens")
MockStep(0.4)
check(dropdown.Root.Size.Y.Offset > dropdown.Row.Height, "dropdown expanded height")
multi:Open()
check(not dropdown.Shell.IsOpen, "opening another popup closes the first")
check(multi.Shell.IsOpen, "multi open")
Library.Overlay:CloseAll()
check(not multi.Shell.IsOpen, "CloseAll closes inline dropdown")
MockStep(0.4)
eq(dropdown.Root.Size.Y.Offset, dropdown.Row.Height, "dropdown collapses back")
dropdown:Open()
MockPressKey(Enum.KeyCode.Escape)
check(not dropdown.Shell.IsOpen, "Escape closes popup")

----------------------------------------------------------------------
section("Colour picker popup")
picker:Open()
check(picker._popup ~= nil, "picker popup created")
MockStep(0.3)
check(find(Library.Overlay.Layer, "ColorPicker") ~= nil, "picker lives in popup layer")
picker:Set("#FF8800")
eq(find(Library.Overlay.Layer, "Hex").Text, "#FF8800", "popup hex follows Set")
Library.Overlay:CloseAll()
MockStep(0.4)
check(picker._popup == nil, "picker closes")
check(find(Library.Overlay.Layer, "ColorPicker") == nil, "picker popup destroyed after close animation")

----------------------------------------------------------------------
section("Configuration manager")
local cfg = Library.Config
eq(cfg:GetBackend(), "Memory", "memory backend without filesystem")
slider:Set(4); toggle:Set(true, true); picker:Set("#ABCDEF", true); multi:Set({ "b", "c" }, true)
dropdown:SetOptions({ "A", "B" }); dropdown:Set("B", true)
key:Set(Enum.KeyCode.Q, true); textbox:Set("saved", true)
local ok, err = cfg:Save("alpha")
check(ok, "save ok " .. tostring(err))
slider:Set(1); toggle:Set(false, true); picker:Set("#000000", true); multi:Set({}, true); dropdown:Set("A", true); key:Set(Enum.KeyCode.Z, true); textbox:Set("changed", true)
local lok, report = cfg:Load("alpha")
check(lok, "load ok")
eq(slider:Get(), 4, "restored slider")
eq(toggle:Get(), true, "restored toggle")
eq(picker:Serialize(), "#ABCDEF", "restored colour")
eq(table.concat(multi:Get(), ","), "b,c", "restored multi")
eq(dropdown:Get(), "B", "restored dropdown")
eq(key:Get(), "Q", "restored keybind")
eq(textbox:Get(), "saved", "restored textbox")
check(report.Applied >= 7, "report counts applied values (" .. tostring(report.Applied) .. ")")
eq(cfg.Current, "alpha", "current config tracked")
local list = cfg:List()
eq(#list, 1, "list has one config")
eq(list[1].Name, "alpha", "list entry name")
check(list[1].Size > 20, "list entry size")
check(cfg:Exists("alpha"), "Exists")
local json = cfg:Export("alpha")
check(type(json) == "string" and json:find('"Flags"') ~= nil, "export is JSON with Flags")
ok = cfg:Import("copy", json); check(ok, "import ok")
eq(#cfg:List(), 2, "import adds config")
local bad, berr = cfg:Import("broken", "{not json")
check(not bad and berr ~= nil, "import rejects invalid JSON: " .. tostring(berr))
local bad2 = cfg:Import("", json); check(not bad2, "import rejects empty name")
local nokey = cfg:Load("missing"); check(not nokey, "load missing config fails")
local noname = cfg:Save("   "); check(not noname, "save rejects blank name")
local sanitized = cfg:Save("we/ird:na*me"); check(sanitized, "save sanitises names")
check(cfg:Exists("weirdname"), "sanitised name stored")
cfg:SetAutoload("alpha"); eq(cfg:GetAutoload(), "alpha", "autoload set")
slider:Set(9); local alok = cfg:LoadAutoload(); check(alok, "autoload loads"); eq(slider:Get(), 4, "autoload applied")
local dok = cfg:Delete("alpha"); check(dok, "delete ok")
check(not cfg:Exists("alpha"), "deleted config gone")
eq(cfg:GetAutoload(), nil, "autoload cleared when its config is deleted")
-- NaN / inf safety
slider.Value = 0 / 0
local enc = cfg:Encode("nan")
check(enc ~= nil, "NaN value sanitised for JSON")
slider.Value = 4

----------------------------------------------------------------------
section("Theme switching + repaint")
local canvas = window.Canvas
local darkBg = Library.Theme.Colors.Background
eq(canvas.BackgroundColor3 == darkBg, true, "canvas uses theme background")
local accentBefore = Library.Theme.Colors.Accent
check(Library:SetTheme("Midnight"), "SetTheme Midnight")
eq(Library:GetTheme(), "Midnight", "theme name updates")
check(canvas.BackgroundColor3 == Color3.fromHex("#05060E"), "window repainted to Midnight")
check(window.Sidebar.Indicator.BackgroundColor3 == Color3.fromHex("#8C9EFF"), "accent elements repainted")
check(picker.Swatch.BackgroundColor3 == Color3.fromHex("#ABCDEF") or picker.Swatch.BackgroundColor3 == picker.Color, "locked swatch keeps user colour")
check(Library:SetTheme("Light"), "SetTheme Light")
check(canvas.BackgroundColor3 == Color3.fromHex("#EDF0F5"), "window repainted to Light")
check(window.TitleLabel.TextColor3 == Color3.fromHex("#14171D"), "text repainted to Light")
check(Library:SetTheme("Dark"), "SetTheme Dark (round trip)")
check(canvas.BackgroundColor3 == darkBg, "round trip restores background exactly")
check(window.Sidebar.Indicator.BackgroundColor3 == accentBefore, "round trip restores accent exactly")
check(not Library:SetTheme("DoesNotExist"), "unknown theme rejected")
Library:SetAccent(Color3.fromHex("#FF5577"))
check(window.Sidebar.Indicator.BackgroundColor3 == Color3.fromHex("#FF5577"), "SetAccent repaints")
check(Library.Theme.Colors.AccentText ~= nil, "accent text derived")
Library:SetTheme("Dark")
Library.Theme:RegisterPreset("Custom", { Colors = { Accent = Color3.fromHex("#00FFAA") } })
check(Library:SetTheme("Custom"), "custom preset works")
check(window.Sidebar.Indicator.BackgroundColor3 == Color3.fromHex("#00FFAA"), "custom preset repainted")
Library:SetTheme("Dark")
local seenChange = 0
local conn = Library.Theme:OnChanged(function() seenChange += 1 end)
Library:SetTheme("Midnight"); Library:SetTheme("Dark")
eq(seenChange, 2, "OnChanged listeners fire")
conn:Disconnect(); Library:SetTheme("Midnight"); Library:SetTheme("Dark")
eq(seenChange, 2, "OnChanged disconnect works")

----------------------------------------------------------------------
section("Navigation, page transitions, search, empty states")
for _, name in ipairs({ "Components", "Showcase", "Notifications", "Modals", "Configurations", "Settings", "Dashboard", "Kit" }) do
	window:SelectTab(name)
	MockStep(0.6)
	local active = window.ActiveTab
	eq(active.Name, name, "select " .. name)
	check(active.Page.Visible and active.Page.GroupTransparency == 0, name .. " page visible and opaque")
	local others = 0
	for _, t in ipairs(window.Tabs) do if t ~= active and t.Page.Visible then others += 1 end end
	eq(others, 0, name .. ": other pages hidden after transition")
	eq(window.Sidebar.ActiveId, active.Id, name .. ": sidebar active id")
end
window:SelectTab("Components"); MockStep(0.5)
window:Search("toggle")
local comps = window.ActiveTab
local visibleSections = 0
for _, sct in ipairs(comps.Sections) do if sct.Frame.Visible then visibleSections += 1 end end
check(visibleSections >= 1 and visibleSections < #comps.Sections, "search narrows sections")
check(not comps.Empty.Visible, "no empty state when there are matches")
window:Search("zzzzqqq")
check(comps.Empty.Visible, "empty state shows for no results")
check(comps.EmptyTitle.Text == "No results", "empty state title")
window:Search("")
check(not comps.Empty.Visible, "empty state hides when cleared")
local allVisible = true
for _, sct in ipairs(comps.Sections) do if not sct.Frame.Visible then allVisible = false end end
check(allVisible, "all sections visible after clearing search")
local emptyTab = window:CreateTab({ Name = "Blank" })
check(emptyTab.Empty.Visible, "fresh tab shows empty state")
window.SearchBar:Set("abc", true); window.SearchBar.Box.Text = "xyz"; MockStep(0.3)
eq(window.Query, "xyz", "topbar search drives window query")
window:Search("")
window.SearchBar:Clear()
window:SelectTab("Dashboard")
MockStep(0.5)

----------------------------------------------------------------------
section("Overlay: dialog, modal, context menu, tooltip")
local dlgResult
local dlg = Library:Dialog({ Title = "Sure?", Content = "body", Buttons = { { Text = "No" }, { Text = "Yes", Style = "Danger", Callback = function() dlgResult = "yes" end } } })
MockStep(0.4)
check(dlg ~= nil and dlg.Panel.Parent ~= nil, "dialog created")
local yes = find(dlg.Panel, "Buttons"):GetChildren()
local yesButton
for _, b in ipairs(yes) do if b:IsA("TextButton") and find(b, "Label").Text == "Yes" then yesButton = b end end
check(yesButton ~= nil, "dialog has Yes button")
yesButton.Activated:Fire()
eq(dlgResult, "yes", "dialog button callback")
MockStep(0.5)
check(#Library.Overlay._modals == 0, "dialog removed after button")
check(find(Library.Overlay.ModalLayer, "Dialog") == nil, "dialog instance destroyed")

local built
local modal = Library:Modal({ Title = "Form", Height = 120, Build = function(body, handle)
	local container = Library.Components.NewContainer(Library.Ctx, body)
	built = container:CreateTextbox({ Name = "Inside", Flag = false })
end })
MockStep(0.4)
check(built ~= nil and built:Get() == "", "modal Build creates components in body")
check(#Library.Config:GetFlags() == #flags, "Flag=false keeps modal components out of configs")
modal:Close(); MockStep(0.5)
check(find(Library.Overlay.ModalLayer, "Modal") == nil, "modal destroyed after close")

local menuHit
local menu = Library:ContextMenu({ { Text = "One", Callback = function() menuHit = "one" end }, { Divider = true }, { Text = "Two", Disabled = true } }, Vector2.new(100, 100))
MockStep(0.3)
check(menu ~= nil and find(Library.Overlay.Layer, "ContextMenu") ~= nil, "context menu opens")
find(Library.Overlay.Layer, "Item_1").Activated:Fire()
eq(menuHit, "one", "context menu item callback")
MockStep(0.3)
check(find(Library.Overlay.Layer, "ContextMenu") == nil, "context menu closed after selection")
check(#Library.Overlay._popups == 0, "popup registry empty")

local tipTarget = Instance.new("TextButton"); tipTarget.Parent = Library.Gui
local detach = Library:AttachTooltip(tipTarget, "Hello tip", 0.2)
tipTarget.MouseEnter:Fire(); MockStep(0.5)
check(Library.Overlay._tip and Library.Overlay._tip.Group.Visible and Library.Overlay._tip.Label.Text == "Hello tip", "tooltip shows after delay")
tipTarget.MouseLeave:Fire(); MockStep(0.4)
check(not Library.Overlay._tip.Group.Visible, "tooltip hides on leave")
detach(); detach()
tipTarget.MouseEnter:Fire(); MockStep(0.5)
check(not Library.Overlay._tip.Group.Visible, "detached tooltip no longer shows")
tipTarget:Destroy()

----------------------------------------------------------------------
section("Notifications")
for i = 1, 7 do Library:Notify({ Title = "T" .. i, Content = "body " .. i, Type = ({ "Info", "Success", "Warning", "Error" })[(i % 4) + 1], Duration = 2 }) end
MockStep(0.5)
check(#Library.Notifications._active <= Library.Theme.Layout.NotificationMax, "toast stack capped at NotificationMax")
MockStep(4)
eq(#Library.Notifications._active, 0, "toasts auto-dismiss")
Library:Notify({ Title = "Sticky", Duration = 0 }); MockStep(5)
eq(#Library.Notifications._active, 1, "Duration 0 stays")
Library.Notifications:Clear(); MockStep(0.6)
eq(#Library.Notifications._active, 0, "Clear removes toasts")

----------------------------------------------------------------------
section("Window: minimize / restore / toggle key / floating button / drag")
window:Minimize(); MockStep(0.6)
check(window.Minimized, "minimized flag")
check(window.Floating.Visible, "floating button visible")
check(window.Floating.GroupTransparency < 1, "floating button faded in")
window:Restore(); MockStep(0.6)
check(not window.Minimized and window.Root.Visible, "restored")
check(not window.Floating.Visible, "floating button hidden after restore")
MockPressKey(Enum.KeyCode.RightShift); MockStep(0.5)
check(window.Minimized, "toggle key minimizes")
MockPressKey(Enum.KeyCode.RightShift); MockStep(0.5)
check(not window.Minimized, "toggle key restores")
window:SetToggleKey(Enum.KeyCode.F4)
MockPressKey(Enum.KeyCode.RightShift); MockStep(0.3)
check(not window.Minimized, "old toggle key ignored after rebind")
MockPressKey(Enum.KeyCode.F4); MockStep(0.5)
check(window.Minimized, "new toggle key works")
window:Restore(); MockStep(0.5)
Library.Ctx.State.CapturingKey = true
MockPressKey(Enum.KeyCode.F4); MockStep(0.3)
check(not window.Minimized, "toggle key ignored while a keybind is capturing")
Library.Ctx.State.CapturingKey = false
-- floating click restores
window:Minimize(); MockStep(0.5)
local fl = window.Floating
local began = MockInput(Enum.UserInputType.MouseButton1, { Position = Vector2.new(window.FloatCenter.X, window.FloatCenter.Y) })
fl.InputBegan:Fire(began); MockStep(0.05)
local ended = MockInput(Enum.UserInputType.MouseButton1, { Position = began.Position, UserInputState = Enum.UserInputState.End })
UIS.InputEnded:Fire(ended, false); fl.InputEnded:Fire(ended); MockStep(0.5)
check(not window.Minimized, "clicking the floating button restores the window")
-- drag by topbar (real input pipeline)
local beforeX, beforeY = window.Center.X, window.Center.Y
local down = MockInput(Enum.UserInputType.MouseButton1, { Position = Vector2.new(335, 170) })
window.Topbar.InputBegan:Fire(down)
UIS.InputChanged:Fire(MockInput(Enum.UserInputType.MouseMovement, { Position = Vector2.new(435, 210) }), false)
MockStep(0.1)
eq(window.Center.X, beforeX + 100, "topbar drag moves window X")
eq(window.Center.Y, beforeY + 40, "topbar drag moves window Y")
UIS.InputEnded:Fire(MockInput(Enum.UserInputType.MouseButton1, { Position = Vector2.new(435, 210), UserInputState = Enum.UserInputState.End }), false)
UIS.InputChanged:Fire(MockInput(Enum.UserInputType.MouseMovement, { Position = Vector2.new(900, 600) }), false)
eq(window.Center.X, beforeX + 100, "drag stops after release")
-- pressing a window button must not start a drag
local closeCenter = window.Center
local onClose = MockInput(Enum.UserInputType.MouseButton1, { Position = Vector2.new(window.CloseButton.AbsolutePosition.X + 5, window.CloseButton.AbsolutePosition.Y + 5) })
window.Topbar.InputBegan:Fire(onClose)
UIS.InputChanged:Fire(MockInput(Enum.UserInputType.MouseMovement, { Position = Vector2.new(700, 500) }), false)
check(window.Center == closeCenter, "pressing a topbar button does not drag the window")
UIS.InputEnded:Fire(MockInput(Enum.UserInputType.MouseButton1, { UserInputState = Enum.UserInputState.End }), false)
window:_setCenter(Vector2.new(640, 360))
-- slider drag
window:SelectTab("Kit"); MockStep(0.4)
local sliderHit = find(slider.Root, "Hit")
local track = slider.Track
local midX = track.AbsolutePosition.X + track.AbsoluteSize.X * 0.5
slider:SetRange(0, 100); slider:Set(0)
sliderHit.InputBegan:Fire(MockInput(Enum.UserInputType.MouseButton1, { Position = Vector2.new(midX, 300) }))
check(math.abs(slider:Get() - 50) <= 1, "slider drag begin sets value from pointer (" .. tostring(slider:Get()) .. ")")
UIS.InputChanged:Fire(MockInput(Enum.UserInputType.MouseMovement, { Position = Vector2.new(track.AbsolutePosition.X + track.AbsoluteSize.X, 300) }), false)
eq(slider:Get(), 100, "slider drag to the end reaches max")
UIS.InputChanged:Fire(MockInput(Enum.UserInputType.MouseMovement, { Position = Vector2.new(track.AbsolutePosition.X - 500, 300) }), false)
eq(slider:Get(), 0, "slider drag past the start clamps to min")
UIS.InputEnded:Fire(MockInput(Enum.UserInputType.MouseButton1, { UserInputState = Enum.UserInputState.End }), false)
slider:SetRange(0, 10); slider:Set(3)
window:_setCenter(Vector2.new(-5000, -5000))
check(window.Center.X > -5000 and window.Center.Y >= window.Size.Y / 2, "window clamped on screen (left/top)")
window:_setCenter(Vector2.new(9000, 9000))
check(window.Center.X < 9000 and window.Center.Y < 9000, "window clamped on screen (right/bottom)")
window:_setCenter(Vector2.new(640, 360))

section("Responsive layout")
workspace.CurrentCamera.ViewportSize = Vector2.new(480, 300)
Library.Gui.AbsoluteSize = Vector2.new(480, 300)
window:_fit()
MockStep(0.5)
check(window.Size.X <= 480 - 24 and window.Size.Y <= 300 - 24, "window shrinks to the viewport (" .. tostring(window.Size.X) .. "x" .. tostring(window.Size.Y) .. ")")
check(window.Sidebar.Compact, "sidebar goes compact on narrow windows")
eq(window.Sidebar.Frame.Size.X.Offset, 56, "compact sidebar width")
check(window.Content.Size.X.Offset == -56, "content follows compact sidebar")
Library.Gui.AbsoluteSize = Vector2.new(1280, 720)
workspace.CurrentCamera.ViewportSize = Vector2.new(1280, 720)
window:_fit(); MockStep(0.5)
eq(window.Size.X, 650, "window restores requested width")
check(not window.Sidebar.Compact, "sidebar expands again")

----------------------------------------------------------------------
section("Settings page behaviours")
window:SelectTab("Settings"); MockStep(0.4)
local settingsTab = window.ActiveTab
local function comp(tabObj, name)
	for _, sct in ipairs(tabObj.Sections) do for _, c in ipairs(sct.Items) do if c._item.Name == name then return c end end end
end
local themeDd = comp(settingsTab, "Theme")
themeDd:Set("Midnight"); MockStep(0.3)
eq(Library:GetTheme(), "Midnight", "settings theme dropdown switches theme")
themeDd:Set("Dark"); MockStep(0.3)
local trans = comp(settingsTab, "Window transparency")
trans:Set(30); MockStep(0.4)
check(math.abs(window.Canvas.BackgroundTransparency - 0.3) < 0.001, "transparency slider drives canvas")
local speed = comp(settingsTab, "Animation speed")
speed:Set(2)
local tips = comp(settingsTab, "Tooltips"); tips:Set(false)
eq(Library.Settings.Tooltips, false, "tooltips setting")
tips:Set(true)
local blur = comp(settingsTab, "Background blur")
blur:Set(true); MockStep(0.5)
check(MockServices().Lighting:FindFirstChild("AetherBlur") ~= nil, "blur effect created")
blur:Set(false); MockStep(0.5)
check(MockServices().Lighting:FindFirstChild("AetherBlur") == nil, "blur effect removed")
local dur = comp(settingsTab, "Notification duration"); dur:Set(9)
eq(Library.Settings.NotificationDuration, 9, "notification duration setting")
local tk = comp(settingsTab, "Toggle window"); tk:Set(Enum.KeyCode.F6)
eq(window.ToggleKey.Name, "F6", "keybind setting rebinds toggle key")
window:SetToggleKey(Enum.KeyCode.RightShift)
check(not table.find(Library.Config:GetFlags(), "Settings.Appearance.Theme"), "settings components are not persisted")

section("Configurations page UI")
window:SelectTab("Configurations"); MockStep(0.4)
local confTab = window.ActiveTab
local nameBox = comp(confTab, "Name")
nameBox:Set("ui-made", true)
comp(confTab, "Save current values"):Fire(); MockStep(0.3)
check(Library.Config:Exists("ui-made"), "UI save creates config")
local rows = findAll(confTab.Page, function(d) return d.Name == "Card" end)
check(#rows >= 1, "saved list renders rows")
check(find(confTab.Page, "Buttons") ~= nil, "row has action buttons")
Library.Config:Delete("ui-made"); MockStep(0.2)
check(findAll(confTab.Page, function(d) return d.Name == "Name" and d.Text == "ui-made" end)[1] == nil, "list refreshes after delete")
for _, c in ipairs(Library.Config:List()) do Library.Config:Delete(c.Name) end
MockStep(0.2)
check(findAll(confTab.Page, function(d) return d.Text == "No saved configurations yet" end)[1] ~= nil, "empty state when no configs")

section("Dashboard metrics")
window:SelectTab("Dashboard"); MockStep(1.2)
check(findAll(window.ActiveTab.Page, function(d) return d.Text == "42" end)[1] ~= nil, "dashboard shows ping metric")
check(findAll(window.Footer, function(d) return d.Name == "Metrics" and d.Text:find("FPS") end)[1] ~= nil, "footer shows FPS")

section("Remove tab / section / component")
local count0 = #Library.Config:GetFlags()
local tmpTab = window:CreateTab({ Name = "Temp" })
local tmpSec = tmpTab:CreateSection("S")
local tt = tmpSec:CreateToggle({ Name = "T" })
eq(#Library.Config:GetFlags(), count0 + 1, "flag registered")
tt:Destroy()
eq(#Library.Config:GetFlags(), count0, "component Destroy unregisters flag")
tmpSec:CreateSlider({ Name = "S1" })
tmpTab:Destroy()
eq(#Library.Config:GetFlags(), count0, "tab Destroy unregisters its flags")
check(window:GetTab("Temp") == nil, "tab removed")
check(window.Sidebar._items["temp"] == nil, "sidebar item removed")

----------------------------------------------------------------------
section("Close flow")
window:Close()
MockStep(0.4)
check(#Library.Overlay._modals == 1, "close asks for confirmation")
local confirm = Library.Overlay._modals[1]
local closeBtn
for _, b in ipairs(find(confirm.Panel, "Buttons"):GetChildren()) do if b:IsA("TextButton") and find(b, "Label").Text == "Close" then closeBtn = b end end
closeBtn.Activated:Fire()
MockStep(1)
check(window.Destroyed, "window destroyed after confirmed close")
eq(#Library.Windows, 0, "window removed from Library list")

----------------------------------------------------------------------
section("Cleanup / leak check")
local w2 = Library:CreateWindow({ Title = "Second", Pages = { Settings = false, Modals = false } })
MockStep(0.5)
eq(#w2.Tabs, 5, "Pages table disables selected pages")
local w3 = Library:CreateWindow({ Title = "Third", Pages = false })
eq(#w3.Tabs, 0, "Pages=false builds none")
local t3 = w3:CreateTab({ Name = "Only" }); check(w3.ActiveTab == t3, "first user tab auto-selected")
w3:Destroy(); w2:Destroy(); MockStep(1)
Library:Destroy()
MockStep(1)
check(Library.Gui == nil, "Library.Gui cleared")
local stats = MockInstanceStats()
local leftovers = {}
for _, inst in ipairs(MockAliveInstances()) do
	local p = inst
	local top = p
	while rawget(top, "_parent") do top = rawget(top, "_parent") end
	if inst.Name ~= "Lighting" and top ~= MockServices().Lighting and top ~= MockServices().CoreGui and top ~= MockPlayerGui() then table.insert(leftovers, inst.Name) end
end
eq(#leftovers, 0, "no orphan instances after Destroy: " .. table.concat(leftovers, ","):sub(1, 120))
eq(#MockServices().CoreGui:GetChildren(), 0, "ScreenGui removed from CoreGui")
eq(MockActiveTweens(), 0, "no active tweens after Destroy")
eq(UIS.InputBegan:Count(), 0, "InputBegan connections released (" .. UIS.InputBegan:Count() .. ")")
eq(UIS.InputEnded:Count(), 0, "InputEnded connections released (" .. UIS.InputEnded:Count() .. ")")
eq(UIS.InputChanged:Count(), 0, "InputChanged connections released (" .. UIS.InputChanged:Count() .. ")")
eq(MockServices().RunService.Heartbeat:Count(), 0, "Heartbeat connections released (" .. MockServices().RunService.Heartbeat:Count() .. ")")
eq(MOCK_ERRORS or 0, 0, "no handler errors anywhere in the suite")

print(string.format("\nRESULT: %d passed, %d failed", results.pass, results.fail))
if results.fail > 0 then
	print("Failures:")
	for _, f in ipairs(results.failures) do print(" - " .. f) end
	error("suite failed")
end
