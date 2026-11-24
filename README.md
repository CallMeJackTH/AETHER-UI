# AETHER UI

A modular, premium dark-minimal Roblox UI library with a standalone HTML5 prototype. Version **1.0.0**.

## Contents
- `src/` — modular Roblox Lua implementation.
- `build/AetherUI.lua` — standalone bundled Lua source.
- `prototype/index.html` — open directly in a modern browser; no backend or external libraries.
- `examples/` — Basic, Advanced and FullShowcase examples.
- `docs/` — API and architecture references.

## Installation (Roblox Studio)
1. Create a Folder named `AETHER_UI` in `ReplicatedStorage`.
2. Copy `src/init.lua` into a ModuleScript named `init` inside that folder.
3. Add folders `Core`, `Modules`, and `Components`, then place the matching Lua files in them.
4. Require it from a LocalScript: `local Aether = require(game.ReplicatedStorage.AETHER_UI)`.
5. Run an example from `examples/` in a LocalScript.

For the bundled build, place `build/AetherUI.lua` into a ModuleScript and require that ModuleScript. The `loadstring(HttpGet())` bootstrap in some executor environments is not a Roblox Studio deployment recommendation and may be disabled by the platform.

## Quick start
```lua
local Aether = require(game.ReplicatedStorage.AETHER_UI)
local Window = Aether:CreateWindow({
    Title = "AETHER UI",
    Subtitle = "Premium Interface Framework",
    Size = UDim2.fromOffset(600, 440),
    Acrylic = true,
    Theme = "Dark"
})
local Tab = Window:CreateTab({Name = "Main", Icon = "house"})
local Section = Tab:CreateSection("General")
Section:CreateButton({Name = "Example", Callback = function() print("Clicked") end})
Section:CreateToggle({Name = "Enabled", Default = false, Callback = function(Value) print(Value) end})
```

## Prototype
Open `prototype/index.html` directly. It uses only HTML5, CSS3 and Vanilla JavaScript. Theme selection, navigation, component interactions, toast notifications, modal confirmation, configuration switching, and responsive layout are implemented locally. Configurations persist for the active page session only.

## Components and API
See [docs/API.md](docs/API.md). Architecture notes are in [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md).

## Validation
The prototype is designed to run from `file://` without network access. Source files were generated and static checks were run during packaging; this environment does not include Roblox Studio or a Luau runtime, so Roblox execution, visual parity on actual devices, and live input behavior still require Studio/device validation. The library's configuration manager is intentionally in-memory (no fake DataStore persistence).

## License
MIT. See [LICENSE](LICENSE).
