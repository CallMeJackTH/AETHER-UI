-- AETHER UI - Player ESP example
-- The library bundle now exposes Library:CreateESP(options).

local Library = loadstring(game:HttpGet(
    "https://raw.githubusercontent.com/CallMeJackTH/AETHER-UI/main/build/AetherUI.lua"
))()

local Window = Library:CreateWindow({
    Title = "AETHER UI | Player ESP",
    Size = Vector2.new(650, 460),
    ToggleKey = Enum.KeyCode.RightShift,
})

local CombatTab = Window:CreateTab({
    Name = "Combat",
    Icon = "crosshair",
    Description = "Player overlay settings",
})

local ESPSection = CombatTab:CreateSection("Player ESP")

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

ESPSection:CreateToggle({
    Name = "Enable ESP",
    Flag = "PlayerESP_Enabled",
    Default = true,
    Callback = function(value)
        ESP:SetEnabled(value)
    end,
})

local options = {
    { Name = "Player Name", Key = "ShowName", Flag = "PlayerESP_Name" },
    { Name = "Health Bar", Key = "ShowHealth", Flag = "PlayerESP_Health" },
    { Name = "Device Icon", Key = "ShowDevice", Flag = "PlayerESP_Device" },
    { Name = "Ping", Key = "ShowPing", Flag = "PlayerESP_Ping" },
    { Name = "Streak", Key = "ShowStreak", Flag = "PlayerESP_Streak" },
    { Name = "Death Counter", Key = "ShowDeathCounter", Flag = "PlayerESP_Counter" },
    { Name = "Ultimate Bar", Key = "ShowUltimate", Flag = "PlayerESP_Ultimate" },
}

for _, option in ipairs(options) do
    ESPSection:CreateToggle({
        Name = option.Name,
        Flag = option.Flag,
        Default = true,
        Callback = function(value)
            ESP:SetOption(option.Key, value)
        end,
    })
end

ESPSection:CreateSlider({
    Name = "Max Distance",
    Flag = "PlayerESP_MaxDistance",
    Min = 50,
    Max = 500,
    Default = 250,
    Increment = 10,
    Suffix = " studs",
    Callback = function(value)
        ESP:SetOption("MaxDistance", value)
    end,
})

ESPSection:CreateButton({
    Name = "Refresh ESP",
    Icon = "refresh-cw",
    Callback = function()
        ESP:Refresh()
    end,
})

ESPSection:CreateButton({
    Name = "Destroy ESP",
    Style = "Danger",
    Icon = "trash-2",
    Callback = function()
        ESP:Destroy()
    end,
})

Library:Notify({
    Title = "AETHER UI",
    Content = "Player ESP loaded.",
    Type = "Success",
    Duration = 3,
})
