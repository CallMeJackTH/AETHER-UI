# AETHER UI

A modular, premium dark-minimal Roblox UI library with a standalone HTML5 prototype. Version **1.0.0**.

## Contents
- `src/` — modular Roblox Lua implementation.
- `build/AetherUI.lua` — standalone bundled Lua source.
- `prototype/index.html` — open directly in a modern browser; no backend or external libraries.
- `examples/` — Basic, Advanced and FullShowcase examples.
- `docs/` — API and architecture references.

## Installation (Roblox Studio)
**Option A — modular source**
1. Create a **ModuleScript** named `AETHER_UI` directly inside `ReplicatedStorage` (not a Folder).
2. Paste the contents of `src/init.lua` into that ModuleScript.
3. Add child Folders named `Core`, `Modules`, and `Components` under the `AETHER_UI` ModuleScript.
4. Place `Theme.lua` inside `Core`, `Janitor.lua` inside `Modules`, and `Factory.lua` inside `Components`.
5. In a LocalScript, use `local Aether = require(game.ReplicatedStorage.AETHER_UI)`.

**Option B — standalone build**
1. Create a ModuleScript named `AETHER_UI` in `ReplicatedStorage`.
2. Paste the complete contents of `build/AetherUI.lua` into it.
3. Require it from a LocalScript with `local Aether = require(game.ReplicatedStorage.AETHER_UI)`.

Run `examples/FullShowcase.lua` as a LocalScript to display the eight reference screens. `AetherShowcaseLoader.lua` is an optional remote loader for executor-style environments; it is not the Roblox Studio installation path.

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
