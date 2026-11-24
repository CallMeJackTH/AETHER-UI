local Theme = {}
Theme.Presets = {
    Dark = {Background=Color3.fromRGB(9,10,13), Surface=Color3.fromRGB(16,18,22), Elevated=Color3.fromRGB(21,24,30), Border=Color3.fromRGB(37,42,51), Text=Color3.fromRGB(241,243,247), Muted=Color3.fromRGB(145,153,168), Accent=Color3.fromRGB(168,181,255)},
    Midnight = {Background=Color3.fromRGB(6,8,17), Surface=Color3.fromRGB(12,16,31), Elevated=Color3.fromRGB(19,25,45), Border=Color3.fromRGB(39,49,77), Text=Color3.fromRGB(235,240,255), Muted=Color3.fromRGB(135,151,190), Accent=Color3.fromRGB(125,154,255)},
    Light = {Background=Color3.fromRGB(238,241,247), Surface=Color3.fromRGB(250,251,253), Elevated=Color3.fromRGB(231,235,243), Border=Color3.fromRGB(211,217,228), Text=Color3.fromRGB(28,32,42), Muted=Color3.fromRGB(103,112,129), Accent=Color3.fromRGB(79,102,210)}
}
function Theme.Resolve(name, custom)
    local base = Theme.Presets[name] or Theme.Presets.Dark
    local result = {}
    for k,v in pairs(base) do result[k] = v end
    if type(custom) == "table" then
        for k,v in pairs(custom) do if result[k] ~= nil and typeof(v) == "Color3" then result[k] = v end end
    end
    return result
end
return Theme
