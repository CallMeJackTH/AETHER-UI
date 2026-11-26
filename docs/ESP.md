# Player ESP

AETHER UI includes an optional world-space Player ESP service. It is separate from the window widgets, so scripts can create it once and control it with ordinary AETHER UI toggles.

## Quick start

```lua
local ESP = Library:CreateESP({
    Enabled = true,
    MaxDistance = 250,

    ShowName = true,
    ShowHealth = true,
    ShowDevice = true,
    ShowPing = true,
    ShowStreak = true,
    ShowDeathCounter = true,
    ShowUltimate = true,
})
```

The returned controller supports:

```lua
ESP:SetEnabled(false)
ESP:SetOption("ShowDevice", false)
ESP:SetOption("MaxDistance", 150)
print(ESP:GetOption("ShowDevice"))
ESP:Refresh()
ESP:Destroy()
```

The controller is registered with its creating Library instance and is automatically destroyed when that Library is destroyed. Calling `ESP:Destroy()` earlier is also supported.

## Options

| Option | Default | Description |
|---|---:|---|
| Enabled | true | Enables or disables all player billboards |
| ExcludeLocalPlayer | true | Does not draw an ESP for the local player |
| MaxDistance | 250 | Maximum camera-to-player distance in studs |
| UpdateInterval | 0.12 | Minimum time between visual refreshes |
| ShowName | true | Display name and username |
| ShowHealth | true | Health bar |
| ShowDevice | true | Computer or mobile device icon |
| ShowPing | true | Ping attribute in milliseconds |
| ShowStreak | true | Current streak attribute |
| ShowDeathCounter | true | Character Counter object, when present |
| ShowUltimate | true | Ultimate attribute and progress bar |

Color options are also configurable: `BackgroundColor`, `BorderColor`, `TextColor`, `MutedColor`, `AccentColor`, `GreenColor`, and `RedColor`.

## Device detection

The device icon uses the target Player's replicated `Mobile` attribute:

- `true`: mobile phone icon.
- `false`: desktop computer icon.
- `nil`: unknown; the icon is hidden.

The library does not guess another player's device from the local device's input settings. Your game must set/replicate the `Mobile` attribute for each player.

## Game-specific attributes

- Ping: `Player:GetAttribute("Ping")`
- Streak: `Workspace.Live[player.Name]:GetAttribute("CurrentStreak")`, with a fallback to the Player attribute
- Ultimate: `Player:GetAttribute("Ultimate")`, with a fallback to the Character attribute
- Death counter: a child named `Counter` under the Character; ValueBase objects display their Value, otherwise the label displays ACTIVE

Missing attributes are safely omitted or shown as zero/unknown. ESP only reads replicated client-visible data; it does not invoke remotes or change other players' characters.
