-- AETHER UI - Executor Showcase Loader
-- Run this file directly in your executor.
-- This loader does not use ReplicatedStorage or require().

local SHOWCASE_URL = "https://raw.githubusercontent.com/CallMeJackTH/AETHER-UI/main/examples/FullShowcase.lua"

local function runShowcase()
    local source = game:HttpGet(SHOWCASE_URL)

    assert(type(source) == "string" and #source > 0, "[AETHER UI] Empty Showcase source.")

    local chunk, compileError = loadstring(source)
    assert(type(chunk) == "function", "[AETHER UI] Showcase compile failed: " .. tostring(compileError))

    return chunk()
end

local success, result = pcall(runShowcase)

if not success then
    warn("[AETHER UI] Loader failed: " .. tostring(result))
end
