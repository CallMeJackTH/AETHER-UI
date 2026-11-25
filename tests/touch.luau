--@touch
-- Touch device: no keyboard, no mouse. Verifies the mobile code paths.
local pass, fail = 0, {}
local function check(c, l) if c then pass += 1 else table.insert(fail, l); print("  FAIL: " .. l) end end
local function find(root, name) if root.Name == name then return root end return root:FindFirstChild(name, true) end
local UIS = MockServices().UserInputService

local ctx = Library.Ctx
check(ctx.Touch == true, "touch detected")
check(ctx.RowHeight == 44 and ctx.ControlHeight == 34 and ctx.ButtonHeight == 40, "touch dimensions selected")

local window = Library:CreateWindow({ Title = "Touch", Size = Vector2.new(650, 420) })
MockStep(1)
local tab = window:CreateTab({ Name = "T" })
local sec = tab:CreateSection("S")
local toggle = sec:CreateToggle({ Name = "Row" })
check(toggle.Root.Size.Y.Offset == 44, "rows use touch height")
check(window.Floating.Size.X.Offset == 52, "floating button uses touch size")
check(tab.Scroll.ScrollBarThickness == 0, "scrollbar hidden on touch")
local sidebarItem
for _, section in pairs(window.Sidebar._sections) do for _, item in ipairs(section.Items) do sidebarItem = item end end
check(sidebarItem.Button.Size.Y.Offset == 42, "sidebar items use touch height")
check(window.Root.Size.X.Offset == 650, "window keeps requested size when it fits")

-- tap
toggle.Root.Activated:Fire(); check(toggle:Get() == true, "tap toggles")

-- slider touch drag (same input object across Began/Changed/Ended)
local slider = sec:CreateSlider({ Name = "Sl", Min = 0, Max = 100, Default = 0 })
MockStep(0.1)
local hit = find(slider.Root, "Hit")
local track = slider.Track
local touch = MockInput(Enum.UserInputType.Touch, { Position = Vector2.new(track.AbsolutePosition.X + track.AbsoluteSize.X * 0.25, 300) })
hit.InputBegan:Fire(touch)
check(math.abs(slider:Get() - 25) <= 1, "touch begin sets slider (" .. tostring(slider:Get()) .. ")")
touch.Position = Vector2.new(track.AbsolutePosition.X + track.AbsoluteSize.X * 0.75, 300)
UIS.InputChanged:Fire(touch, false)
check(math.abs(slider:Get() - 75) <= 1, "touch move updates slider (" .. tostring(slider:Get()) .. ")")
touch.UserInputState = Enum.UserInputState.End
UIS.InputEnded:Fire(touch, false)
local before = slider:Get()
UIS.InputChanged:Fire(MockInput(Enum.UserInputType.Touch, { Position = Vector2.new(0, 0) }), false)
check(slider:Get() == before, "a different touch does not move the slider")

-- long-press opens a context menu
local target = sec:CreateButton({ Name = "Long press me", ContextMenu = { { Text = "Action", Callback = function() end } } })
local press = MockInput(Enum.UserInputType.Touch, { Position = Vector2.new(400, 300) })
target.Root.InputBegan:Fire(press)
MockStep(0.2)
check(find(Library.Overlay.Layer, "ContextMenu") == nil, "no menu before the long-press delay")
MockStep(0.5)
check(find(Library.Overlay.Layer, "ContextMenu") ~= nil, "long-press opens context menu")
local item = find(Library.Overlay.Layer, "Item_1")
check(item.Size.Y.Offset == 40, "context items use touch height")
Library.Overlay:CloseAll(); MockStep(0.4)
-- short tap must not open it
local tap = MockInput(Enum.UserInputType.Touch, { Position = Vector2.new(400, 300) })
target.Root.InputBegan:Fire(tap)
tap.UserInputState = Enum.UserInputState.End
MockStep(0.7)
check(find(Library.Overlay.Layer, "ContextMenu") == nil, "released touch does not open the menu")

-- small phone viewport
workspace.CurrentCamera.ViewportSize = Vector2.new(390, 300)
Library.Gui.AbsoluteSize = Vector2.new(390, 300)
window:_fit(); MockStep(0.5)
check(window.Size.X <= 390 - 44 and window.Size.Y <= 300 - 44, "touch margin applied on phone viewport (" .. window.Size.X .. "x" .. window.Size.Y .. ")")
check(window.Sidebar.Compact, "compact sidebar on phone")
check(not window.SearchBar.Root.Visible or window.Size.X >= 380, "search hides on very narrow windows")

Library:Destroy(); MockStep(0.5)
check(UIS.InputBegan:Count() == 0 and UIS.InputChanged:Count() == 0 and UIS.InputEnded:Count() == 0, "touch run: listeners released")
check((MOCK_ERRORS or 0) == 0, "touch run: no handler errors")
print(string.format("\nTOUCH RESULT: %d passed, %d failed", pass, #fail))
if #fail > 0 then error("touch tests failed") end
