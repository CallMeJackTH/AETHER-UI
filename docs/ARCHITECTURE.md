# Architecture and implementation notes

- `src/init.lua`: window lifecycle, public API, layout and control construction.
- `src/Core/Theme.lua`: theme presets and custom palette resolution.
- `src/Modules/Janitor.lua`: reverse-order cleanup of connections and instances.
- `src/Components/Factory.lua`: guarded instance construction and shared primitives.
- `build/AetherUI.lua`: self-contained source bundle with embedded module dependencies.
- `prototype/`: standalone HTML/CSS/Vanilla JS prototype.

Roblox uses native `ScreenGui`, `Frame`, `ScrollingFrame`, `UIStroke`, `UICorner`, `UIGradient`, `TweenService`, and `UserInputService`. Window dragging supports mouse and touch. Responsive layout uses Roblox scale sizing and the caller-provided window dimensions; use a compact `Size` for narrow screens. The web prototype is responsive with CSS breakpoints and stores configuration snapshots in runtime memory only.

The prototype is intentionally dependency-free: no CDN fonts, frameworks, remote scripts, or backend. Acrylic blur is represented by translucent layered surfaces and ambient gradients; Roblox's native GUI does not provide browser-equivalent backdrop-filter blur, so the Lua surface uses transparency and gradient sheen instead.
