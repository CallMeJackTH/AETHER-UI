--[[
	AETHER UI  -  init.lua
	Entry point. Requiring this module returns a ready-to-use Library:

	    local Library = require(path.to.AETHER-UI)
	    local Window = Library:CreateWindow({ Title = "AETHER", Size = Vector2.new(650, 420) })
	    local Tab = Window:CreateTab({ Name = "Main", Icon = "dashboard" })
	    local Section = Tab:CreateSection("General")
	    Section:CreateButton({ Name = "Hello", Callback = function() print("hi") end })
	    Section:CreateToggle({ Name = "Enabled", Default = true, Callback = print })

	Library.new(options) creates an additional, independent instance.
]]

local Core = require(script.Core)

return Core.new({ Replace = true })
