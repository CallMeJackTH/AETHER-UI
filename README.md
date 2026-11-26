# AETHER UI

A modern dark Roblox Luau UI library with a responsive window, sidebar tabs, sections, built-in components, notifications, themes, and configuration helpers.

The examples below match the public API in the current **build/AetherUI.lua** bundle.

## Installation

~~~lua
local Library = loadstring(game:HttpGet(
    "https://raw.githubusercontent.com/CallMeJackTH/AETHER-UI/main/build/AetherUI.lua"
))()
~~~

The execution environment must support **loadstring** and **game:HttpGet**. This is not a normal Roblox Studio LocalScript loader.

## Quick start

~~~lua
local Library = loadstring(game:HttpGet(
    "https://raw.githubusercontent.com/CallMeJackTH/AETHER-UI/main/build/AetherUI.lua"
))()

local Window = Library:CreateWindow({
    Title = "My AETHER Script",
    Size = Vector2.new(650, 420),
    ToggleKey = Enum.KeyCode.RightShift,
})

local MainTab = Window:CreateTab({
    Name = "Main",
    Icon = "house",
    Description = "Main controls",
})

local MainSection = MainTab:CreateSection("General")

MainSection:CreateButton({
    Name = "Say hello",
    Description = "Print a message to the console",
    Style = "Primary",
    Callback = function()
        print("Hello from AETHER UI")
    end,
})

MainSection:CreateToggle({
    Name = "Example toggle",
    Default = false,
    Callback = function(enabled)
        print("Enabled:", enabled)
    end,
})

Library:Notify({
    Title = "AETHER UI",
    Content = "The interface loaded successfully.",
    Type = "Success",
    Duration = 4,
})
~~~

## Documentation

- [Getting Started](docs/GETTING_STARTED.md) — installation, window setup, tabs, sections, and a complete example.
- [Components Reference](docs/COMPONENTS.md) — component options, callbacks, and shared methods.
- [Player ESP](docs/ESP.md) — world-space player overlays, device icons, and controller API.

## Optional systems

- Player ESP — name, health, PC/mobile device icon, ping, streak, death counter, and ultimate bar. See [Player ESP docs](docs/ESP.md) and `examples/PlayerESP.lua`.

## Built-in components

Button, Toggle, Slider, Dropdown, MultiDropdown, Textbox, Keybind, ColorPicker, Label, Paragraph, Divider, SearchBar, ProgressBar, and LoadingIndicator.

Create components through a section, for example **Section:CreateButton({...})**.

## Repository layout

- **build/AetherUI.lua** — generated single-file bundle used by the loader.
- **src/** — framework source modules.
- **src/Components/** — built-in component modules.
- **docs/** — usage and API documentation.
- **examples/** — runnable usage examples.
- **tools/bundle.py** — bundle generator.
- **tests/** — project tests.

After changing source modules, regenerate the bundle:

~~~bash
python tools/bundle.py
~~~

Commit both the source changes and the regenerated **build/AetherUI.lua** so the GitHub loader receives the latest implementation.

## API naming

AETHER UI uses the **Create...** naming convention:

~~~lua
local Window = Library:CreateWindow({...})
local Tab = Window:CreateTab({...})
local Section = Tab:CreateSection("General")
local Button = Section:CreateButton({...})
~~~

Methods named AddTab, AddSection, and AddButton are not part of this build's public API.
