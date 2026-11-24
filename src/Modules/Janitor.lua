local Janitor = {}
Janitor.__index = Janitor
function Janitor.new() return setmetatable({items={}, dead=false}, Janitor) end
function Janitor:Add(item)
    if self.dead then
        if typeof(item) == "RBXScriptConnection" then item:Disconnect()
        elseif typeof(item) == "Instance" then item:Destroy()
        elseif type(item) == "function" then pcall(item) end
        return item
    end
    table.insert(self.items, item)
    return item
end
function Janitor:Cleanup()
    if self.dead then return end
    self.dead = true
    for i=#self.items,1,-1 do
        local item = self.items[i]
        if typeof(item) == "RBXScriptConnection" then pcall(function() item:Disconnect() end)
        elseif typeof(item) == "Instance" then pcall(function() item:Destroy() end)
        elseif type(item) == "function" then pcall(item)
        elseif type(item) == "table" and item.Destroy then pcall(function() item:Destroy() end) end
    end
    table.clear(self.items)
end
return Janitor
