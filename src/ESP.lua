--[[
    AETHER UI - Player ESP
    Optional world-space player overlay service.

    Usage:
        local ESP = Library:CreateESP({
            ShowName = true,
            ShowHealth = true,
            ShowDevice = true,
            ShowPing = true,
            ShowStreak = true,
            ShowDeathCounter = true,
            ShowUltimate = true,
        })

        ESP:SetEnabled(false)
        ESP:SetOption("ShowDevice", false)
        ESP:Destroy()

    Device classification is read from the target Player's "Mobile" attribute:
      true  = mobile
      false = desktop
      nil   = unknown (device icon hidden)
]]

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local ESP = {}
ESP.__index = ESP

local DEFAULTS = {
    Enabled = true,
    ExcludeLocalPlayer = true,
    MaxDistance = 250,
    UpdateInterval = 0.12,
    ShowName = true,
    ShowHealth = true,
    ShowDevice = true,
    ShowPing = true,
    ShowStreak = true,
    ShowDeathCounter = true,
    ShowUltimate = true,
    BackgroundColor = Color3.fromRGB(15, 17, 23),
    BorderColor = Color3.fromRGB(55, 61, 75),
    TextColor = Color3.fromRGB(240, 243, 250),
    MutedColor = Color3.fromRGB(155, 163, 180),
    AccentColor = Color3.fromRGB(168, 181, 255),
    GreenColor = Color3.fromRGB(100, 220, 160),
    RedColor = Color3.fromRGB(255, 105, 105),
}

local function create(className, properties, parent)
    local object = Instance.new(className)
    for key, value in pairs(properties or {}) do
        object[key] = value
    end
    object.Parent = parent
    return object
end

local function round(instance, radius)
    create("UICorner", { CornerRadius = UDim.new(0, radius or 5) }, instance)
end

local function stroke(instance, color, transparency)
    create("UIStroke", {
        Color = color,
        Thickness = 1,
        Transparency = transparency or 0.25,
    }, instance)
end

local function makeLabel(parent, name, position, size, color, textSize, bold)
    return create("TextLabel", {
        Name = name,
        BackgroundTransparency = 1,
        BorderSizePixel = 0,
        Position = position,
        Size = size,
        Font = bold and Enum.Font.GothamSemibold or Enum.Font.Gotham,
        Text = "",
        TextColor3 = color,
        TextSize = textSize or 11,
        TextXAlignment = Enum.TextXAlignment.Left,
        TextYAlignment = Enum.TextYAlignment.Center,
        TextTruncate = Enum.TextTruncate.AtEnd,
    }, parent)
end

local function makeDeviceIcon(parent, palette)
    local holder = create("Frame", {
        Name = "DeviceIcon",
        BackgroundTransparency = 1,
        BorderSizePixel = 0,
        Position = UDim2.fromOffset(0, 0),
        Size = UDim2.fromOffset(20, 20),
        Visible = false,
    }, parent)

    local pc = create("Frame", {
        Name = "Computer",
        BackgroundTransparency = 1,
        Size = UDim2.fromScale(1, 1),
        Visible = false,
    }, holder)
    local monitor = create("Frame", {
        Name = "Monitor",
        Position = UDim2.fromOffset(2, 2),
        Size = UDim2.fromOffset(16, 11),
        BackgroundColor3 = palette.AccentColor,
        BorderSizePixel = 0,
    }, pc)
    round(monitor, 2)
    create("Frame", {
        Name = "Screen",
        Position = UDim2.fromOffset(2, 2),
        Size = UDim2.new(1, -4, 1, -4),
        BackgroundColor3 = palette.BackgroundColor,
        BorderSizePixel = 0,
    }, monitor)
    create("Frame", {
        Name = "Stand",
        AnchorPoint = Vector2.new(0.5, 0),
        Position = UDim2.fromOffset(10, 13),
        Size = UDim2.fromOffset(2, 3),
        BackgroundColor3 = palette.AccentColor,
        BorderSizePixel = 0,
    }, pc)
    create("Frame", {
        Name = "Base",
        AnchorPoint = Vector2.new(0.5, 0),
        Position = UDim2.fromOffset(10, 16),
        Size = UDim2.fromOffset(8, 2),
        BackgroundColor3 = palette.AccentColor,
        BorderSizePixel = 0,
    }, pc)

    local mobile = create("Frame", {
        Name = "Mobile",
        BackgroundTransparency = 1,
        Size = UDim2.fromScale(1, 1),
        Visible = false,
    }, holder)
    local phone = create("Frame", {
        Name = "Phone",
        Position = UDim2.fromOffset(5, 1),
        Size = UDim2.fromOffset(10, 18),
        BackgroundColor3 = palette.GreenColor,
        BorderSizePixel = 0,
    }, mobile)
    round(phone, 3)
    create("Frame", {
        Name = "Screen",
        Position = UDim2.fromOffset(2, 2),
        Size = UDim2.new(1, -4, 1, -5),
        BackgroundColor3 = palette.BackgroundColor,
        BorderSizePixel = 0,
    }, phone)
    create("Frame", {
        Name = "HomeIndicator",
        AnchorPoint = Vector2.new(0.5, 1),
        Position = UDim2.new(0.5, 0, 1, -1),
        Size = UDim2.fromOffset(3, 1),
        BackgroundColor3 = palette.GreenColor,
        BorderSizePixel = 0,
    }, phone)

    return holder
end

local function getDevice(player)
    local mobile = player:GetAttribute("Mobile")
    if mobile == true then
        return "Mobile"
    elseif mobile == false then
        return "PC"
    end
    return "Unknown"
end

local function getStreak(player)
    local liveFolder = Workspace:FindFirstChild("Live")
    local liveCharacter = liveFolder and liveFolder:FindFirstChild(player.Name)
    if liveCharacter then
        local value = liveCharacter:GetAttribute("CurrentStreak")
        if value ~= nil then
            return tonumber(value) or 0
        end
    end
    return tonumber(player:GetAttribute("CurrentStreak")) or 0
end

local function getCounter(character)
    local counter = character and character:FindFirstChild("Counter")
    if not counter then
        return nil
    end
    if counter:IsA("ValueBase") then
        return tostring(counter.Value)
    end
    local value = counter:GetAttribute("Value")
    if value ~= nil then
        return tostring(value)
    end
    return "ACTIVE"
end

function ESP.new(ctx, options)
    options = options or {}

    local self = setmetatable({}, ESP)
    self.Context = ctx
    self.Options = table.clone(DEFAULTS)
    self.Entries = {}
    self.Connections = {}
    self._destroyed = false
    self._elapsed = 0

    for key, value in pairs(options) do
        if self.Options[key] ~= nil then
            self.Options[key] = value
        end
    end

    self.Players = Players
    self.LocalPlayer = Players.LocalPlayer
    self.Camera = Workspace.CurrentCamera
    self.GuiParent = ctx.Gui and ctx.Gui.Parent or self.LocalPlayer:WaitForChild("PlayerGui")

    self:_bindPlayers()
    return self
end

function ESP:_track(connection)
    table.insert(self.Connections, connection)
    return connection
end

function ESP:_makeEntry(player)
    if self._destroyed or self.Entries[player] then
        return
    end
    if self.Options.ExcludeLocalPlayer and player == self.LocalPlayer then
        return
    end

    local billboard = create("BillboardGui", {
        Name = "AETHER_PlayerESP_" .. player.UserId,
        Adornee = nil,
        AlwaysOnTop = true,
        LightInfluence = 0,
        MaxDistance = self.Options.MaxDistance,
        Size = UDim2.fromOffset(210, 104),
        StudsOffset = Vector3.new(0, 3.25, 0),
        Enabled = false,
    }, self.GuiParent)

    local root = create("Frame", {
        Name = "Panel",
        Size = UDim2.fromScale(1, 1),
        BackgroundColor3 = self.Options.BackgroundColor,
        BackgroundTransparency = 0.12,
        BorderSizePixel = 0,
    }, billboard)
    round(root, 7)
    stroke(root, self.Options.BorderColor, 0.15)

    local scale = create("UIScale", { Scale = 1 }, root)

    local name = makeLabel(root, "PlayerName", UDim2.fromOffset(8, 4), UDim2.new(1, -38, 0, 17), self.Options.TextColor, 12, true)
    local deviceIcon = makeDeviceIcon(root, self.Options)
    deviceIcon.Position = UDim2.new(1, -27, 0, 2)

    local healthTrack = create("Frame", {
        Name = "HealthTrack",
        Position = UDim2.fromOffset(8, 25),
        Size = UDim2.new(1, -16, 0, 5),
        BackgroundColor3 = self.Options.BorderColor,
        BorderSizePixel = 0,
        ClipsDescendants = true,
    }, root)
    round(healthTrack, 3)
    local healthFill = create("Frame", {
        Name = "HealthFill",
        Size = UDim2.fromScale(1, 1),
        BackgroundColor3 = self.Options.GreenColor,
        BorderSizePixel = 0,
    }, healthTrack)
    round(healthFill, 3)

    local status = makeLabel(root, "Status", UDim2.fromOffset(8, 33), UDim2.new(1, -16, 0, 14), self.Options.MutedColor, 10, false)
    local counter = makeLabel(root, "DeathCounter", UDim2.fromOffset(8, 49), UDim2.new(1, -16, 0, 13), self.Options.RedColor, 10, true)
    local ultimateText = makeLabel(root, "UltimateText", UDim2.fromOffset(8, 64), UDim2.new(1, -16, 0, 12), self.Options.AccentColor, 9, true)

    local ultimateTrack = create("Frame", {
        Name = "UltimateTrack",
        Position = UDim2.fromOffset(8, 80),
        Size = UDim2.new(1, -16, 0, 5),
        BackgroundColor3 = self.Options.BorderColor,
        BorderSizePixel = 0,
        ClipsDescendants = true,
    }, root)
    round(ultimateTrack, 3)
    local ultimateFill = create("Frame", {
        Name = "UltimateFill",
        Size = UDim2.fromScale(0, 1),
        BackgroundColor3 = self.Options.AccentColor,
        BorderSizePixel = 0,
    }, ultimateTrack)
    round(ultimateFill, 3)

    self.Entries[player] = {
        Billboard = billboard,
        Scale = scale,
        Name = name,
        DeviceIcon = deviceIcon,
        HealthTrack = healthTrack,
        HealthFill = healthFill,
        Status = status,
        Counter = counter,
        UltimateText = ultimateText,
        UltimateTrack = ultimateTrack,
        UltimateFill = ultimateFill,
        Character = nil,
        Humanoid = nil,
    }

    self:_bindCharacter(player)
end

function ESP:_bindCharacter(player)
    local entry = self.Entries[player]
    if not entry then
        return
    end

    local character = player.Character
    if not character then
        entry.Billboard.Enabled = false
        return
    end

    local adornee = character:FindFirstChild("Head") or character:FindFirstChild("HumanoidRootPart")
    local humanoid = character:FindFirstChildOfClass("Humanoid")
    if not adornee then
        entry.Billboard.Enabled = false
        return
    end

    entry.Character = character
    entry.Humanoid = humanoid
    entry.Billboard.Adornee = adornee
    entry.Billboard.Enabled = adornee ~= nil and self.Options.Enabled
end

function ESP:_updateEntry(player, entry)
    local character = player.Character
    if not character or character ~= entry.Character or not entry.Billboard.Adornee or not entry.Billboard.Adornee.Parent then
        self:_bindCharacter(player)
        character = player.Character
    end
    if not character then
        entry.Billboard.Enabled = false
        return
    end

    local humanoid = character:FindFirstChildOfClass("Humanoid")
    local head = character:FindFirstChild("Head") or character:FindFirstChild("HumanoidRootPart")
    local camera = Workspace.CurrentCamera
    if not humanoid or not head or not camera then
        entry.Billboard.Enabled = false
        return
    end

    local distance = (camera.CFrame.Position - head.Position).Magnitude
    local withinDistance = distance <= (tonumber(self.Options.MaxDistance) or 250)
    entry.Billboard.Enabled = self.Options.Enabled and withinDistance
    if not entry.Billboard.Enabled then
        return
    end

    entry.Billboard.Adornee = head
    entry.Billboard.MaxDistance = self.Options.MaxDistance
    entry.Scale.Scale = math.clamp(32 / math.max(distance, 1), 0.55, 1)

    entry.Name.Visible = self.Options.ShowName
    entry.Name.Text = player.DisplayName ~= player.Name
        and (player.DisplayName .. "  @" .. player.Name)
        or player.Name

    local device = getDevice(player)
    entry.DeviceIcon.Visible = self.Options.ShowDevice and device ~= "Unknown"
    entry.DeviceIcon.Computer.Visible = device == "PC"
    entry.DeviceIcon.Mobile.Visible = device == "Mobile"

    local health = math.max(0, humanoid.Health)
    local maxHealth = math.max(1, humanoid.MaxHealth)
    local healthRatio = math.clamp(health / maxHealth, 0, 1)
    entry.HealthTrack.Visible = self.Options.ShowHealth
    entry.HealthFill.Size = UDim2.fromScale(healthRatio, 1)
    entry.HealthFill.BackgroundColor3 = healthRatio > 0.6
        and self.Options.GreenColor
        or (healthRatio > 0.3 and Color3.fromRGB(255, 190, 90) or self.Options.RedColor)

    local statusParts = {}
    if self.Options.ShowPing then
        local ping = player:GetAttribute("Ping")
        table.insert(statusParts, "PING " .. (ping ~= nil and tostring(math.floor(tonumber(ping) or 0)) .. "ms" or "--"))
    end
    if self.Options.ShowStreak then
        table.insert(statusParts, "STREAK " .. tostring(getStreak(player)))
    end
    entry.Status.Visible = #statusParts > 0
    entry.Status.Text = table.concat(statusParts, "   •   ")

    local counterValue = self.Options.ShowDeathCounter and getCounter(character) or nil
    entry.Counter.Visible = counterValue ~= nil
    entry.Counter.Text = counterValue and ("DEATH COUNTER  " .. counterValue) or ""

    local ultimate = tonumber(player:GetAttribute("Ultimate"))
    if ultimate == nil then
        ultimate = tonumber(character:GetAttribute("Ultimate"))
    end
    local hasUltimate = self.Options.ShowUltimate and ultimate ~= nil
    entry.UltimateText.Visible = hasUltimate
    entry.UltimateTrack.Visible = hasUltimate
    if hasUltimate then
        local ratio = math.clamp(ultimate / 100, 0, 1)
        entry.UltimateText.Text = "ULTIMATE  " .. tostring(math.floor(ratio * 100 + 0.5)) .. "%"
        entry.UltimateFill.Size = UDim2.fromScale(ratio, 1)
    end
end

function ESP:_removeEntry(player)
    local entry = self.Entries[player]
    if not entry then
        return
    end
    self.Entries[player] = nil
    if entry.Billboard then
        entry.Billboard:Destroy()
    end
end

function ESP:_bindPlayers()
    for _, player in ipairs(self.Players:GetPlayers()) do
        self:_makeEntry(player)
    end

    self:_track(self.Players.PlayerAdded:Connect(function(player)
        self:_makeEntry(player)
        self:_track(player.CharacterAdded:Connect(function()
            task.defer(function()
                self:_bindCharacter(player)
            end)
        end))
    end))

    self:_track(self.Players.PlayerRemoving:Connect(function(player)
        self:_removeEntry(player)
    end))

    for player in pairs(self.Entries) do
        self:_track(player.CharacterAdded:Connect(function()
            task.defer(function()
                self:_bindCharacter(player)
            end)
        end))
    end

    self:_track(RunService.Heartbeat:Connect(function(dt)
        if self._destroyed then
            return
        end
        self._elapsed = self._elapsed + dt
        if self._elapsed < (tonumber(self.Options.UpdateInterval) or 0.12) then
            return
        end
        self._elapsed = 0
        for player, entry in pairs(self.Entries) do
            if player.Parent == self.Players then
                self:_updateEntry(player, entry)
            else
                self:_removeEntry(player)
            end
        end
    end))
end

function ESP:SetEnabled(enabled)
    self.Options.Enabled = enabled and true or false
    for _, entry in pairs(self.Entries) do
        entry.Billboard.Enabled = self.Options.Enabled
    end
end

function ESP:SetOption(name, value)
    assert(DEFAULTS[name] ~= nil, "[AetherUI ESP] unknown option: " .. tostring(name))
    self.Options[name] = value

    if name == "MaxDistance" then
        for _, entry in pairs(self.Entries) do
            entry.Billboard.MaxDistance = tonumber(value) or DEFAULTS.MaxDistance
        end
    end

    if name == "Enabled" then
        self:SetEnabled(value)
    end
end

function ESP:GetOption(name)
    return self.Options[name]
end

function ESP:Refresh()
    for player in pairs(self.Entries) do
        self:_updateEntry(player, self.Entries[player])
    end
end

function ESP:Destroy()
    if self._destroyed then
        return
    end
    self._destroyed = true

    for _, connection in ipairs(self.Connections) do
        pcall(function()
            connection:Disconnect()
        end)
    end
    table.clear(self.Connections)

    for player in pairs(self.Entries) do
        self:_removeEntry(player)
    end
    table.clear(self.Entries)
end

return ESP
