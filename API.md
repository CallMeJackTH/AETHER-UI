# API Reference

## Bootstrap
```lua
local Aether = require(path.to.AETHER_UI)
local Window = Aether:CreateWindow({
  Title = "AETHER UI", Subtitle = "Premium Interface Framework",
  Size = UDim2.fromOffset(600, 440), Acrylic = true, Theme = "Dark"
})
local Tab = Window:CreateTab({Name = "Main", Icon = "house"})
local Section = Tab:CreateSection("General")
```
The executor-style `loadstring(game:HttpGet(RAW_URL))()` pattern is intentionally not required. Publish `build/AetherUI.lua` at a trusted raw URL and use it only in environments where `loadstring` and HTTP execution are explicitly enabled; normal Roblox experiences should use ModuleScripts.

## Window methods
- `CreateTab({Name, Icon})` creates a page and navigation entry.
- `Notify({Title, Content, Duration})` displays a transient toast.
- `ShowDialog({Title, Content, ConfirmText, CancelText, Callback, OnCancel})` displays a confirmation modal.
- `SetTheme("Dark"|"Midnight"|"Light", customColors?)` changes the palette.
- `SaveConfiguration(name)`, `LoadConfiguration(name)`, `GetValue(name)`, `Destroy()`.

## Section component methods
All controls accept `Name`, optional `Description`, and callbacks as documented.
- `CreateButton({Name, Description, ButtonText, Callback})`
- `CreateToggle({Name, Default, Callback})` returns `GetValue()` and `SetValue(value)`.
- `CreateSlider({Name, Min, Max, Default, Callback})` returns `GetValue()` and `SetValue(value)`.
- `CreateDropdown({Name, Options, Default, Callback})` returns `GetValue()` and `SetValue(value)`.
- `CreateMultiDropdown({Name, Options, Default, Callback})` returns `GetValue()`.
- `CreateTextbox({Name, Placeholder, Default, Callback})` returns `GetValue()` and `SetValue(value)`.
- `CreateKeybind({Name, Default, Callback})` returns `GetValue()`. Click the key button to rebind.
- `CreateColorPicker({Name, Default, Callback})` returns `GetValue()` and `SetValue(Color3)`. Click swatch to cycle hue.
- `CreateLabel(string | {Text})`, `CreateParagraph({Title, Content})`, `CreateDivider()`.
- `CreateSearchBar({Name, Placeholder, Callback})`
- `CreateProgressBar({Name, Value, Callback})` returns `SetValue(value)` (0–100).
- `CreateLoadingIndicator({Name})` returns `Stop()`.
- `CreateTooltip({Name, Tooltip})`, `CreateContextMenu({Name, Options})`.
- `CreateModal({Name, Title, Content, Callback})`
- `CreateConfigurationManager({ConfigName})`, `CreateThemeManager()`.

Callbacks are protected with `pcall`; callback errors are sent to `warn`. Control state is exposed by returned handles where available and mirrored into `Window:GetValue(name)` for toggles and sliders. Configurations are in-memory snapshots for the lifetime of the window; persistence across sessions is not provided by Roblox client scripts without a server or permitted DataStore layer.

## Themes
Built-in themes: Dark, Midnight, Light. Custom theme keys: `Background`, `Surface`, `Elevated`, `Border`, `Text`, `Muted`, `Accent`, each a `Color3`. Example:
```lua
Window:SetTheme("Dark", {Accent = Color3.fromRGB(168,181,255)})
```
