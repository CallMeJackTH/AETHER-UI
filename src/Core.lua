--[[
	Core.lua
	Assembles one AETHER UI instance (the "Library"):

	  * creates the ScreenGui (gethui -> CoreGui -> PlayerGui, or options.Parent)
	  * builds the shared context `ctx` and injects it into every module
	  * owns the metrics loop (FPS / ping / memory) used by footer + dashboard
	  * exposes the public API: CreateWindow, Notify, Dialog, Modal, ContextMenu,
	    SetTheme, SetAccent, SaveConfig, LoadConfig, DeleteConfig, ListConfigs,
	    LoadAutoload, Destroy

	Core.new(options)
	  options: Name, Parent, Folder (config folder), Theme (overrides, e.g. { Preset = "Midnight" }),
	           Replace (destroy the previous default instance first)
]]

local RunService = game:GetService("RunService")
local Stats = game:GetService("Stats")
local Players = game:GetService("Players")

local Theme = require(script.Parent.Theme)
local Animation = require(script.Parent.Animation)
local Utils = require(script.Parent.Utils)
local ConfigManager = require(script.Parent.ConfigManager)
local Overlay = require(script.Parent.Overlay)
local Notifications = require(script.Parent.Notifications)
local Sidebar = require(script.Parent.Sidebar)
-- `Components.lua` sits beside a `Components/` folder of the same name, so pick
-- the ModuleScript explicitly instead of trusting name lookup.
local function siblingModule(name)
	for _, child in ipairs(script.Parent:GetChildren()) do
		if child.Name == name and child:IsA("ModuleScript") then
			return require(child)
		end
	end
	error("[AetherUI] missing module: " .. name)
end

local Components = siblingModule("Components")
local Window = require(script.Parent.Window)
local Pages = require(script.Parent.Pages)
local ESP = require(script.Parent.ESP)

local Core = {}
Core.__index = Core
Core.Version = "1.0.0"

local function envLookup(name)
	local ok, value = pcall(function()
		return getfenv(0)[name]
	end)
	if ok and value ~= nil then
		return value
	end
	return nil
end

local function resolveParent(options)
	if options.Parent then
		return options.Parent
	end

	local gethui = envLookup("gethui")
	if type(gethui) == "function" then
		local ok, result = pcall(gethui)
		if ok and typeof(result) == "Instance" then
			return result
		end
	end

	local ok, coreGui = pcall(function()
		local service = game:GetService("CoreGui")
		local probe = Instance.new("Folder")
		probe.Parent = service
		probe:Destroy()
		return service
	end)
	if ok and coreGui then
		return coreGui
	end

	local player = Players.LocalPlayer
	if player then
		return player:WaitForChild("PlayerGui")
	end
	error("[AetherUI] could not find a parent for the ScreenGui; pass options.Parent")
end

function Core.new(options)
	options = options or {}

	-- options.Replace (set by init.lua): re-executing the script replaces the
	-- previous default instance instead of stacking UIs.
	if options.Replace then
		pcall(function()
			local previous = _G.__AetherUIInstance
			if previous and previous.Destroy and not previous._destroyed then
				previous:Destroy()
			end
		end)
	end

	local self = setmetatable({}, Core)
	self.Version = Core.Version
	self.Maid = Utils.Maid.new()
	self.Windows = {}
	self._destroyed = false

	self.Theme = Theme.new(options.Theme)
	self.Animation = Animation.new(self.Theme)
	self.Utils = Utils
	self.Components = Components
	self.ThemeChanged = Utils.Signal.new()
	self.Maid:Give(self.ThemeChanged)

	local touch = Utils.IsTouch()
	local layout = self.Theme.Layout

	local ctx = {
		Library = self,
		Theme = self.Theme,
		Animation = self.Animation,
		Utils = Utils,
		Components = Components,
		Sidebar = Sidebar,
		Pages = Pages,
		Touch = touch,
		RowHeight = touch and layout.RowHeightTouch or layout.RowHeight,
		ControlHeight = touch and layout.ControlHeightTouch or layout.ControlHeight,
		ButtonHeight = touch and layout.ButtonHeightTouch or layout.ButtonHeight,
		Settings = {
			NotificationDuration = 4,
			Tooltips = true,
			AnimationSpeed = 1,
		},
		State = { CapturingKey = false },
		Metrics = { FPS = 60, Ping = 0, Memory = 0, Uptime = 0 },
		MetricsChanged = Utils.Signal.new(),
	}
	self.Ctx = ctx
	self.Settings = ctx.Settings
	self.Maid:Give(ctx.MetricsChanged)

	local gui = Instance.new("ScreenGui")
	gui.Name = options.Name or "AetherUI"
	gui.ResetOnSpawn = false
	gui.IgnoreGuiInset = true
	gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	gui.DisplayOrder = 10000
	gui.Parent = resolveParent(options)
	self.Gui = gui
	ctx.Gui = gui

	ctx.Config = ConfigManager.new(ctx, { Folder = options.Folder })
	ctx.Overlay = Overlay.new(ctx, gui)
	ctx.Notifications = Notifications.new(ctx, gui)
	self.Config = ctx.Config
	self.Overlay = ctx.Overlay
	self.Notifications = ctx.Notifications

	-- Metrics: sampled twice per second.
	local frames, elapsed, started = 0, 0, os.clock()
	self.Maid:Give(RunService.Heartbeat:Connect(function(dt)
		frames = frames + 1
		elapsed = elapsed + dt
		if elapsed < 0.5 then
			return
		end
		local metrics = ctx.Metrics
		metrics.FPS = math.floor(frames / elapsed + 0.5)
		metrics.Uptime = os.clock() - started
		pcall(function()
			metrics.Ping = math.floor(Stats.Network.ServerStatsItem["Data Ping"]:GetValue() + 0.5)
		end)
		pcall(function()
			metrics.Memory = math.floor(Stats:GetTotalMemoryUsageMb() + 0.5)
		end)
		frames, elapsed = 0, 0
		ctx.MetricsChanged:Fire(metrics)
	end))

	if options.Replace then
		pcall(function()
			_G.__AetherUIInstance = self
		end)
	end

	return self
end

----------------------------------------------------------------------
-- Windows
----------------------------------------------------------------------

function Core:CreateWindow(config)
	assert(not self._destroyed, "[AetherUI] this Library has been destroyed")
	local window = Window.new(self.Ctx, config)
	table.insert(self.Windows, window)
	window.OnDestroyed:Connect(function()
		local index = table.find(self.Windows, window)
		if index then
			table.remove(self.Windows, index)
		end
	end)
	return window
end

function Core:GetWindows()
	return table.clone(self.Windows)
end

-- Create a world-space ESP controller. The controller is owned by this
-- Library instance and is automatically destroyed with it.
function Core:CreateESP(options)
	assert(not self._destroyed, "[AetherUI] this Library has been destroyed")
	local controller = ESP.new(self.Ctx, options)
	self.Maid:Give(controller)
	return controller
end

----------------------------------------------------------------------
-- Overlays
----------------------------------------------------------------------

function Core:Notify(config)
	return self.Notifications:Notify(config)
end

function Core:Dialog(config)
	return self.Overlay:Dialog(config)
end

function Core:Modal(config)
	return self.Overlay:Modal(config)
end

function Core:ContextMenu(items, position)
	return self.Overlay:ContextMenu(items, position)
end

function Core:AttachTooltip(gui, text, delay)
	return self.Overlay:AttachTooltip(gui, text, delay)
end

----------------------------------------------------------------------
-- Theme
----------------------------------------------------------------------

function Core:SetTheme(name)
	self.Animation:Flush()
	local ok = self.Theme:SetTheme(name, self.Gui)
	if ok then
		self.ThemeChanged:Fire(self.Theme.Name)
	end
	return ok
end

function Core:SetAccent(color)
	self.Animation:Flush()
	self.Theme:SetAccent(color, self.Gui)
	self.ThemeChanged:Fire(self.Theme.Name)
end

function Core:Override(overrides)
	self.Animation:Flush()
	self.Theme:Override(overrides, self.Gui)
	self.ThemeChanged:Fire(self.Theme.Name)
end

function Core:GetTheme()
	return self.Theme.Name
end

function Core:GetThemeNames()
	return self.Theme:GetThemeNames()
end

----------------------------------------------------------------------
-- Configuration (thin wrappers over ConfigManager)
----------------------------------------------------------------------

function Core:SaveConfig(name)
	return self.Config:Save(name)
end

function Core:LoadConfig(name)
	return self.Config:Load(name)
end

function Core:DeleteConfig(name)
	return self.Config:Delete(name)
end

function Core:ListConfigs()
	return self.Config:List()
end

function Core:LoadAutoload()
	return self.Config:LoadAutoload()
end

----------------------------------------------------------------------
-- Lifetime
----------------------------------------------------------------------

function Core:Destroy()
	if self._destroyed then
		return
	end
	self._destroyed = true

	for _, window in ipairs(table.clone(self.Windows)) do
		window:Destroy()
	end
	self.Windows = {}

	self.Notifications:Destroy()
	self.Overlay:Destroy()
	self.Config:Destroy()
	self.Maid:Destroy()
	self.Animation:Destroy()

	if self.Gui then
		self.Gui:Destroy()
		self.Gui = nil
	end

	pcall(function()
		if _G.__AetherUIInstance == self then
			_G.__AetherUIInstance = nil
		end
	end)
end

return Core
