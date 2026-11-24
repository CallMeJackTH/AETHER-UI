-- AETHER UI v2.4 - Reference-matched Roblox showcase
-- Run as a LocalScript in Roblox Studio after installing the AETHER_UI ModuleScript.
-- The page order and component layout follow prototype/index.html.

local function loadAether()
    local module = game:GetService("ReplicatedStorage"):FindFirstChild("AETHER_UI")
    if module then
        return require(module)
    end

    -- Optional standalone fallback for executor-based preview environments.
    local url = "https://raw.githubusercontent.com/CallMeJackTH/AETHER-UI/main/build/AetherUI.lua"
    local source = game:HttpGet(url)
    assert(type(source) == "string" and #source > 0, "[AETHER UI] Library source is empty.")
    local chunk, compileError = loadstring(source)
    assert(type(chunk) == "function", "[AETHER UI] Library compile failed: " .. tostring(compileError))
    return chunk()
end

local Aether = loadAether()
local Window = Aether:CreateWindow({
    Title = "Aether Framework",
    Subtitle = "Premium Interface Framework",
    Size = UDim2.fromOffset(680, 440),
    Theme = "Dark",
    Acrylic = true
})

-- 01. DASHBOARD
local Dashboard = Window:CreateTab({Name = "Dashboard", Icon = "▦"})
local Overview = Dashboard:CreateSection("SYSTEM OVERVIEW")
Overview:CreateParagraph({
    Title = "Welcome back, KairoDev",
    Content = "UNDETECTED  •  Game detected: Phantom Arena [v4.18]  •  Client: Roblox Player"
})
Overview:CreateLabel("CLIENT FRAMERATE     143.8 FPS")
Overview:CreateLabel("NETWORK LATENCY       28 ms")
Overview:CreateLabel("ACTIVE MODULES        08 / 12")
Overview:CreateButton({
    Name = "Script Synchronization",
    Description = "Verify module hooks against the current game build.",
    ButtonText = "Sync Hooks",
    Callback = function()
        Window:Notify({Title = "Script Synchronized", Content = "All module hooks verified.", Duration = 3})
    end
})
local Activity = Dashboard:CreateSection("RECENT ACTIVITY")
Activity:CreateParagraph({Title = "AETHER UI Initialized", Content = "Loaded navigation, component controls, notifications and modal layers."})
Activity:CreateProgressBar({Name = "Module Initialization", Value = 72})

-- 02. COMBAT
local Combat = Window:CreateTab({Name = "Combat", Icon = "◎"})
local Targeting = Combat:CreateSection("TARGETING")
Targeting:CreateToggle({Name = "Enable Aim Assistance", Description = "Toggle target assistance state.", Default = true, Callback = function(v) print("Aim Assistance:", v) end})
Targeting:CreateKeybind({Name = "Aim Keybind", Description = "Set the activation key.", Default = Enum.KeyCode.ButtonR2, Callback = function(v) print("Aim key:", v.Name) end})
Targeting:CreateSlider({Name = "Field of View Radius", Min = 20, Max = 300, Default = 145, Callback = function(v) print("FOV:", v) end})
Targeting:CreateDropdown({Name = "Target Priority Bone", Options = {"Head (Primary)", "UpperTorso", "HumanoidRootPart"}, Default = "Head (Primary)", Callback = function(v) print("Target bone:", v) end})
Targeting:CreateMultiDropdown({Name = "Target Validation Checks", Description = "Multi-select target filters.", Options = {"Visible", "Team", "Alive", "ForceField"}, Default = {"Visible", "Team", "Alive"}, Callback = function(v) print("Checks:", table.concat(v, ", ")) end})
local Trigger = Combat:CreateSection("TRIGGERBOT")
Trigger:CreateToggle({Name = "Auto Trigger Fire", Description = "Enable or disable trigger state.", Default = false})
Trigger:CreateSlider({Name = "Reaction Delay", Min = 0, Max = 150, Default = 35})
local Hitbox = Combat:CreateSection("HITBOX EXPANDER")
Hitbox:CreateToggle({Name = "Head Hitbox Scale", Default = true})
Hitbox:CreateSlider({Name = "Multiplier", Min = 1, Max = 3, Default = 1.4})

-- 03. VISUALS
local Visuals = Window:CreateTab({Name = "Visuals", Icon = "◉"})
local Esp = Visuals:CreateSection("ESP OVERLAY")
Esp:CreateToggle({Name = "2D Corner Bounding Box", Default = true})
Esp:CreateToggle({Name = "Health Bar & Nameplate", Default = true})
Esp:CreateColorPicker({Name = "Enemy Visible Color", Default = Color3.fromRGB(94, 139, 255), Callback = function(c) print("ESP color:", c) end})
Esp:CreateDropdown({Name = "Box Style", Options = {"Corner", "Full", "3D"}, Default = "Corner"})
Esp:CreateParagraph({Title = "LIVE ESP PREVIEW", Content = "R15 Rig  •  Target_01 [82]  •  42 studs"})
local VisualOptions = Visuals:CreateSection("VISUAL OPTIONS")
VisualOptions:CreateToggle({Name = "Show Distance", Default = true})
VisualOptions:CreateToggle({Name = "Team Color", Default = false})

-- 04. SETTINGS
local Settings = Window:CreateTab({Name = "Settings", Icon = "⚙"})
local Appearance = Settings:CreateSection("APPEARANCE")
Appearance:CreateDropdown({Name = "Accent Theme Preset", Options = {"Obsidian Slate", "Carbon Indigo", "Midnight Emerald", "Crimson Graphite"}, Default = "Obsidian Slate", Callback = function(v) print("Accent preset:", v) end})
Appearance:CreateSlider({Name = "Acrylic Surface Opacity", Min = 65, Max = 98, Default = 90})
Appearance:CreateToggle({Name = "Enable Acrylic", Default = true})
local Interface = Settings:CreateSection("INTERFACE")
Interface:CreateKeybind({Name = "Interface Toggle Keybind", Default = Enum.KeyCode.RightShift})
Interface:CreateButton({Name = "Unload Interface", ButtonText = "Unload", Callback = function() Window:ShowDialog({Title = "Unload AETHER UI?", Content = "This will close the interface.", ConfirmText = "Unload", Callback = function() Window:Destroy() end}) end})

-- 05. CONFIGURATIONS
local Configs = Window:CreateTab({Name = "Configs", Icon = "☷"})
local Profiles = Configs:CreateSection("PROFILE MANAGER")
Profiles:CreateTextbox({Name = "New Profile", Placeholder = "Enter new profile name..."})
Profiles:CreateConfigurationManager({ConfigName = "Legit_Main"})
Profiles:CreateButton({Name = "Save Current Profile", ButtonText = "Save", Callback = function() Window:SaveConfiguration("Legit_Main"); Window:Notify({Title = "Config Saved", Content = "Legit_Main profile saved."}) end})
Profiles:CreateButton({Name = "Load Current Profile", ButtonText = "Load", Callback = function() local ok, err = Window:LoadConfiguration("Legit_Main"); if not ok then Window:Notify({Title = "Load Failed", Content = err}) end end})

-- 06. COMPONENTS
local Components = Window:CreateTab({Name = "Components", Icon = "✧"})
local KitchenSink = Components:CreateSection("ALL INTERACTIVE STATES & PRIMITIVES")
KitchenSink:CreateButton({Name = "Button", Description = "Standard callback action.", ButtonText = "Run", Callback = function() Window:Notify({Title = "Primary Action", Content = "Button callback fired."}) end})
KitchenSink:CreateToggle({Name = "Toggle ON / OFF", Default = true})
KitchenSink:CreateSlider({Name = "Slider", Min = 0, Max = 100, Default = 72})
KitchenSink:CreateDropdown({Name = "Dropdown", Options = {"Option One", "Option Two", "Option Three"}, Default = "Option One"})
KitchenSink:CreateMultiDropdown({Name = "MultiDropdown", Options = {"Alpha", "Beta", "Gamma"}, Default = {"Alpha"}})
KitchenSink:CreateTextbox({Name = "Textbox", Placeholder = "Enter text..."})
KitchenSink:CreateKeybind({Name = "Keybind", Default = Enum.KeyCode.F})
KitchenSink:CreateColorPicker({Name = "ColorPicker", Default = Color3.fromRGB(94, 139, 255)})
KitchenSink:CreateLabel("Label component")
KitchenSink:CreateParagraph({Title = "Paragraph", Content = "A longer description for an interface control."})
KitchenSink:CreateDivider()
KitchenSink:CreateSearchBar({Name = "SearchBar", Placeholder = "Search flags, tabs or settings..."})
KitchenSink:CreateProgressBar({Name = "Determinate Progress", Value = 72})
KitchenSink:CreateLoadingIndicator({Name = "Loading Indicator"})
KitchenSink:CreateTooltip({Name = "Tooltip", Tooltip = "Helpful contextual information"})
KitchenSink:CreateContextMenu({Name = "Context Menu", Options = {"Copy Flag ID", "Reset Default", "Unbind Key"}})
KitchenSink:CreateModal({Name = "Modal", Title = "Example Modal", Content = "Modal content", Callback = function() print("Modal confirmed") end})
KitchenSink:CreateConfigurationManager({ConfigName = "Components"})
KitchenSink:CreateThemeManager()

-- 07. NOTIFICATIONS
local Notifications = Window:CreateTab({Name = "Notifications", Icon = "♧"})
local Toasts = Notifications:CreateSection("INTERACTIVE TOAST NOTIFICATIONS")
Toasts:CreateButton({Name = "Info Notification", ButtonText = "Trigger Info", Callback = function() Window:Notify({Title = "System Info", Content = "Teleport service hook initialized."}) end})
Toasts:CreateButton({Name = "Success Notification", ButtonText = "Trigger Success", Callback = function() Window:Notify({Title = "Profile Saved", Content = "Configuration written successfully."}) end})
Toasts:CreateButton({Name = "Warning Notification", ButtonText = "Trigger Warning", Callback = function() Window:Notify({Title = "High Ping Warning", Content = "Server latency exceeded 140ms."}) end})
Toasts:CreateButton({Name = "Error Notification", ButtonText = "Trigger Error", Callback = function() Window:Notify({Title = "Hook Failed", Content = "Target event was not found."}) end})

-- 08. MODALS
local Modals = Window:CreateTab({Name = "Modals", Icon = "▣"})
local Dialogs = Modals:CreateSection("DIALOGS, MODALS & CONTEXT MENUS")
Dialogs:CreateButton({Name = "Confirmation Dialog", Description = "Backdrop dim and confirmation card.", ButtonText = "Open", Callback = function()
    Window:ShowDialog({Title = "Unload AETHER UI?", Content = "This will disconnect active UI callbacks and destroy the ScreenGui.", CancelText = "Cancel", ConfirmText = "Confirm", Callback = function() Window:Destroy() end})
end})
Dialogs:CreateModal({Name = "Input Form Modal", Title = "Export Cloud Config", Content = "Generate a share token for the current profile.", Callback = function() Window:Notify({Title = "Token Ready", Content = "Configuration export prepared."}) end})
Dialogs:CreateContextMenu({Name = "Context Menu Preview", Options = {"Copy Flag ID", "Reset Default", "Unbind Key"}})

Window:Notify({Title = "Aether UI Initialized", Content = "Loaded 8 screens and interactive controls.", Duration = 4})
