local Factory = {}
function Factory.Create(className, props, parent)
    local object = Instance.new(className)
    for key, value in pairs(props or {}) do
        local ok = pcall(function() object[key] = value end)
        if not ok then warn("[AETHER] Invalid property:", key) end
    end
    object.Parent = parent
    return object
end
function Factory.Corner(parent, radius)
    return Factory.Create("UICorner", {CornerRadius=UDim.new(0, radius or 8)}, parent)
end
function Factory.Stroke(parent, color, transparency)
    return Factory.Create("UIStroke", {Color=color, Transparency=transparency or 0, Thickness=1}, parent)
end
return Factory
