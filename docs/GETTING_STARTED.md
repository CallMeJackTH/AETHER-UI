# Getting Started

This guide walks through loading AETHER UI and building an interface. Examples match the API exposed by the current build/AetherUI.lua bundle.

## 1. Load the library

~~~lua
local Library = loadstring(game:HttpGet(
    "https://raw.githubusercontent.com/CallMeJackTH/AETHER-UI/main/build/AetherUI.lua"
))()
~~~

The environment running the script must support both loadstring and game:HttpGet.

## 2. Create a window

~~~lua
local Window = Library:CreateWindow({
    Title = "My Script",
    Size = Vector2.new(650, 420),
    ToggleKey = Enum.KeyCode.RightShift,
    ConfirmClose = true,
})
~~~

Window options:

| Option | Meaning |
| --- | --- |
| Title | Text shown in the title bar |
| Size | Window size as Vector2 or UDim2 |
| Version | Optional version label |
| Position | Optional center position as Vector2 |
| ToggleKey | Key used to minimize/restore; defaults to RightShift |
| ConfirmClose | Confirmation before closing; defaults to true |
| Pages | Built-in pages configuration; false disables built-in pages |

Window methods include Minimize, Restore, Toggle, Close(true), Destroy, SetTitle, SetStatus, SetToggleKey, SetSize, SetTransparency, SetBlur, Search, and Notify.

## 3. Create tabs

~~~lua
local MainTab = Window:CreateTab({
    Name = "Main",
    Icon = "house",
    Description = "Main controls",
})

local SettingsTab = Window:CreateTab({
    Name = "Settings",
    Icon = "settings",
})
~~~

Tab options: Name, Icon, Description, Section, and Order. Select a tab with:

~~~lua
Window:SelectTab("Settings")
-- or:
SettingsTab:Select()
~~~

## 4. Create sections

~~~lua
local General = MainTab:CreateSection("General")
local Movement = MainTab:CreateSection("Movement")

local Info = MainTab:CreateSection("Information", {
    Description = "A short description under the section heading",
})
~~~

## 5. Add components

Use Create followed by the component name on a Section:

~~~lua
General:CreateButton({
    Name = "Print hello",
    Callback = function()
        print("Hello!")
    end,
})

General:CreateToggle({
    Name = "Auto feature",
    Default = false,
    Callback = function(value)
        print("Auto feature:", value)
    end,
})
~~~

See [Components Reference](COMPONENTS.md) for every built-in component and its options.

## 6. Read and update component values

Keep the returned component object when you need to read or change it later:

~~~lua
local AutoToggle = General:CreateToggle({
    Name = "Auto farm",
    Default = false,
    Callback = function(value)
        print("Auto farm:", value)
    end,
})

print(AutoToggle:Get())
AutoToggle:Set(true)
AutoToggle:Set(false, true) -- true suppresses the callback
~~~

Common shared methods:

- SetDisabled(true/false), IsDisabled()
- SetVisible(true/false), IsVisible()
- SetTooltip("Help text")
- SetName("New name"), SetDescription("New description")
- Destroy()

Some components also provide methods such as SetOptions, SetRange, Focus, and Open. Check the component reference.

## 7. Notifications

~~~lua
Library:Notify({
    Title = "Saved",
    Content = "Your settings have been saved.",
    Type = "Success",
    Duration = 4,
})

Window:Notify({
    Title = "Warning",
    Content = "Check your settings.",
    Type = "Warning",
})
~~~

Notification options are Title, Content, Type, and Duration. Duration defaults to four seconds.

## 8. Themes

~~~lua
print("Current theme:", Library:GetTheme())
print("Available themes:", table.concat(Library:GetThemeNames(), ", "))

Library:SetTheme("Dark")
Library:SetAccent(Color3.fromRGB(168, 181, 255))
~~~

Use a theme name returned by Library:GetThemeNames().

## 9. Save and load configuration

Value components register with the configuration manager automatically unless Flag = false is supplied. Give a component a stable custom flag:

~~~lua
General:CreateToggle({
    Name = "Auto collect",
    Flag = "auto_collect",
    Default = false,
})
~~~

Configuration methods:

~~~lua
Library:SaveConfig("default")
Library:LoadConfig("default")
print(table.concat(Library:ListConfigs(), ", "))
Library:DeleteConfig("default")
~~~

Use unique flags for values that should be stored independently.

## 10. Complete example

~~~lua
local Library = loadstring(game:HttpGet(
    "https://raw.githubusercontent.com/CallMeJackTH/AETHER-UI/main/build/AetherUI.lua"
))()

local Window = Library:CreateWindow({
    Title = "AETHER Example",
    Size = Vector2.new(650, 420),
})

local MainTab = Window:CreateTab({
    Name = "Main",
    Icon = "house",
    Description = "Example controls",
})

local General = MainTab:CreateSection("General")

General:CreateParagraph({
    Title = "Welcome",
    Content = "This demonstrates the AETHER UI component API.",
})

General:CreateButton({
    Name = "Notify",
    Style = "Primary",
    Callback = function()
        Window:Notify({
            Title = "Hello",
            Content = "The button callback ran.",
            Type = "Success",
        })
    end,
})

General:CreateToggle({
    Name = "Enabled",
    Flag = "example_enabled",
    Default = false,
    Callback = function(value)
        print("Enabled:", value)
    end,
})

General:CreateSlider({
    Name = "Walk speed",
    Min = 0,
    Max = 100,
    Default = 16,
    Increment = 1,
    Callback = function(value)
        print("Slider value:", value)
    end,
})

General:CreateDropdown({
    Name = "Mode",
    Options = { "Easy", "Normal", "Hard" },
    Default = "Normal",
    Callback = function(value)
        print("Selected mode:", value)
    end,
})

local Settings = Window:CreateTab({
    Name = "Settings",
    Icon = "settings",
})

local ConfigSection = Settings:CreateSection("Configuration")

ConfigSection:CreateButton({
    Name = "Save configuration",
    Callback = function()
        print("Saved:", Library:SaveConfig("default"))
    end,
})

ConfigSection:CreateButton({
    Name = "Load configuration",
    Callback = function()
        print("Loaded:", Library:LoadConfig("default"))
    end,
})
~~~

## Troubleshooting

### attempt to call a nil value

Check method spelling and capitalization. This library uses CreateTab, CreateSection, and CreateButton — not AddTab, AddSection, or AddButton.

### Raw GitHub URL returns an error

Confirm the repository is public, the file exists at build/AetherUI.lua on the main branch, and the URL uses the exact capitalization.

### The UI does not appear

Check the first error in the executor output, confirm loadstring and game:HttpGet are supported, and verify the bundle was regenerated after source changes.

### Updating the published bundle

Edit source modules under src/, run python tools/bundle.py, then commit the updated build/AetherUI.lua. The loader downloads that generated bundle.
