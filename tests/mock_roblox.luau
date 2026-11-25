--!nocheck
--[[
	Minimal Roblox API mock used to EXECUTE the library inside the stock Luau VM.
	It is NOT Roblox: no rendering, layout, input routing or replication. It models
	just enough (Instances, properties, signals, tweens with a virtual clock, services)
	to catch nil-index errors, wrong method names, bad arguments and cleanup leaks.
]]

----------------------------------------------------------------------
-- Virtual scheduler (task library)
----------------------------------------------------------------------
local Clock = { now = 0, seq = 0, queue = {} }
local function schedule(at, fn)
	Clock.seq += 1
	local item = { at = at, seq = Clock.seq, fn = fn, alive = true }
	table.insert(Clock.queue, item)
	return item
end
local function runDue()
	while true do
		local best
		for _, item in ipairs(Clock.queue) do
			if item.alive and item.at <= Clock.now and (not best or item.at < best.at or (item.at == best.at and item.seq < best.seq)) then
				best = item
			end
		end
		if not best then break end
		best.alive = false
		best.fn()
	end
	local keep = {}
	for _, item in ipairs(Clock.queue) do if item.alive then table.insert(keep, item) end end
	Clock.queue = keep
end

local function resume(co, ...)
	local ok, err = coroutine.resume(co, ...)
	if not ok then print("[mock] task error: " .. tostring(err) .. "\n" .. debug.traceback(co)) ; MOCK_ERRORS = (MOCK_ERRORS or 0) + 1 end
end

task = {
	spawn = function(fn, ...)
		local co = type(fn) == "thread" and fn or coroutine.create(fn)
		resume(co, ...)
		return co
	end,
	defer = function(fn, ...)
		local args = { ... }
		local co = type(fn) == "thread" and fn or coroutine.create(fn)
		local item = schedule(Clock.now, function() resume(co, table.unpack(args)) end)
		return item
	end,
	delay = function(t, fn, ...)
		local args = { ... }
		local co = type(fn) == "thread" and fn or coroutine.create(fn)
		return schedule(Clock.now + (t or 0), function() resume(co, table.unpack(args)) end)
	end,
	wait = function(t)
		local co = coroutine.running()
		schedule(Clock.now + (t or 0), function() resume(co) end)
		coroutine.yield()
		return t or 0
	end,
	cancel = function(item) if type(item) == "table" then item.alive = false end end,
}

----------------------------------------------------------------------
-- Signals
----------------------------------------------------------------------
local Signal = {}
Signal.__index = Signal
Signal.__tname = "RBXScriptSignal"
local Connection = {}
Connection.__index = Connection
Connection.__tname = "RBXScriptConnection"
function Connection:Disconnect() self.Connected = false; self._signal._list[self] = nil; self._signal._count -= 1 end

local function newSignal() return setmetatable({ _list = {}, _order = {}, _count = 0 }, Signal) end
function Signal:Connect(fn)
	local c = setmetatable({ Connected = true, _signal = self, _fn = fn }, Connection)
	self._list[c] = true; self._count += 1
	table.insert(self._order, c)
	return c
end
function Signal:Once(fn)
	local c
	c = self:Connect(function(...) c:Disconnect(); fn(...) end)
	return c
end
function Signal:Wait() local co = coroutine.running(); self:Once(function(...) resume(co, ...) end); return coroutine.yield() end
function Signal:Fire(...)
	for _, c in ipairs(table.clone(self._order)) do
		if c.Connected then
			local ok, err = pcall(c._fn, ...)
			if not ok then print("[mock] signal handler error: " .. tostring(err)); MOCK_ERRORS = (MOCK_ERRORS or 0) + 1 end
		end
	end
	-- compact
	local keep = {}
	for _, c in ipairs(self._order) do if c.Connected then table.insert(keep, c) end end
	self._order = keep
end
function Signal:Count() return self._count end
MockSignal = newSignal

----------------------------------------------------------------------
-- Value types
----------------------------------------------------------------------
local TYPE_NAMES = setmetatable({}, { __mode = "k" })
local function def(name) local mt = { __tname = name }; mt.__index = mt; return mt end

local Vector2Mt = def("Vector2")
local function V2(x, y) return setmetatable({ X = x, Y = y }, Vector2Mt) end
Vector2Mt.__add = function(a, b) return V2(a.X + b.X, a.Y + b.Y) end
Vector2Mt.__sub = function(a, b) return V2(a.X - b.X, a.Y - b.Y) end
Vector2Mt.__mul = function(a, b) if type(a) == "number" then return V2(a * b.X, a * b.Y) elseif type(b) == "number" then return V2(a.X * b, a.Y * b) end return V2(a.X * b.X, a.Y * b.Y) end
Vector2Mt.__div = function(a, b) if type(b) == "number" then return V2(a.X / b, a.Y / b) end return V2(a.X / b.X, a.Y / b.Y) end
Vector2Mt.__unm = function(a) return V2(-a.X, -a.Y) end
Vector2Mt.__eq = function(a, b) return a.X == b.X and a.Y == b.Y end
Vector2Mt.__index = function(t, k) if k == "Magnitude" then return math.sqrt(t.X * t.X + t.Y * t.Y) end return Vector2Mt[k] end
Vector2 = { new = function(x, y) return V2(x or 0, y or 0) end, zero = V2(0, 0) }

local UDimMt = def("UDim")
local function UD(s, o) return setmetatable({ Scale = s, Offset = o }, UDimMt) end
UDimMt.__eq = function(a, b) return a.Scale == b.Scale and a.Offset == b.Offset end
UDim = { new = function(s, o) return UD(s or 0, o or 0) end }

local UDim2Mt = def("UDim2")
local function U2(xs, xo, ys, yo) return setmetatable({ X = UD(xs, xo), Y = UD(ys, yo) }, UDim2Mt) end
UDim2Mt.__eq = function(a, b) return a.X == b.X and a.Y == b.Y end
UDim2Mt.__add = function(a, b) return U2(a.X.Scale + b.X.Scale, a.X.Offset + b.X.Offset, a.Y.Scale + b.Y.Scale, a.Y.Offset + b.Y.Offset) end
UDim2 = {
	new = function(xs, xo, ys, yo)
		if typeof(xs) == "UDim" then return setmetatable({ X = xs, Y = xo }, UDim2Mt) end
		return U2(xs or 0, xo or 0, ys or 0, yo or 0)
	end,
	fromOffset = function(x, y) return U2(0, x or 0, 0, y or 0) end,
	fromScale = function(x, y) return U2(x or 0, 0, y or 0, 0) end,
}

local Color3Mt = def("Color3")
local function C3(r, g, b) return setmetatable({ R = r, G = g, B = b }, Color3Mt) end
Color3Mt.__eq = function(a, b) return math.abs(a.R - b.R) < 1e-6 and math.abs(a.G - b.G) < 1e-6 and math.abs(a.B - b.B) < 1e-6 end
function Color3Mt:Lerp(o, t) return C3(self.R + (o.R - self.R) * t, self.G + (o.G - self.G) * t, self.B + (o.B - self.B) * t) end
function Color3Mt:ToHSV()
	local r, g, b = self.R, self.G, self.B
	local mx, mn = math.max(r, g, b), math.min(r, g, b)
	local d = mx - mn
	local h = 0
	if d > 0 then
		if mx == r then h = ((g - b) / d) % 6 elseif mx == g then h = (b - r) / d + 2 else h = (r - g) / d + 4 end
		h = h / 6
	end
	return h, mx == 0 and 0 or d / mx, mx
end
local function hsv(h, s, v)
	local i = math.floor(h * 6); local f = h * 6 - i
	local p, q, t = v * (1 - s), v * (1 - f * s), v * (1 - (1 - f) * s)
	i = i % 6
	if i == 0 then return C3(v, t, p) elseif i == 1 then return C3(q, v, p) elseif i == 2 then return C3(p, v, t)
	elseif i == 3 then return C3(p, q, v) elseif i == 4 then return C3(t, p, v) end
	return C3(v, p, q)
end
Color3 = {
	new = function(r, g, b) return C3(r or 0, g or 0, b or 0) end,
	fromRGB = function(r, g, b) return C3(r / 255, g / 255, b / 255) end,
	fromHSV = hsv,
	fromHex = function(hex)
		hex = hex:gsub("#", "")
		assert(#hex == 6, "bad hex " .. hex)
		return C3(tonumber(hex:sub(1, 2), 16) / 255, tonumber(hex:sub(3, 4), 16) / 255, tonumber(hex:sub(5, 6), 16) / 255)
	end,
}

local CSKMt = def("ColorSequenceKeypoint")
ColorSequenceKeypoint = { new = function(t, v) return setmetatable({ Time = t, Value = v }, CSKMt) end }
local CSMt = def("ColorSequence")
ColorSequence = { new = function(a, b)
	if type(a) == "table" and getmetatable(a) == nil then return setmetatable({ Keypoints = a }, CSMt) end
	return setmetatable({ Keypoints = { ColorSequenceKeypoint.new(0, a), ColorSequenceKeypoint.new(1, b or a) } }, CSMt)
end }
local NSKMt = def("NumberSequenceKeypoint")
NumberSequenceKeypoint = { new = function(t, v, e) return setmetatable({ Time = t, Value = v, Envelope = e or 0 }, NSKMt) end }
local NSMt = def("NumberSequence")
NumberSequence = { new = function(a, b)
	if type(a) == "table" then return setmetatable({ Keypoints = a }, NSMt) end
	return setmetatable({ Keypoints = { NumberSequenceKeypoint.new(0, a), NumberSequenceKeypoint.new(1, b or a) } }, NSMt)
end }
local TweenInfoMt = def("TweenInfo")
TweenInfo = { new = function(t, style, dir, rep, rev, delay)
	return setmetatable({ Time = t or 1, EasingStyle = style, EasingDirection = dir, RepeatCount = rep or 0, Reverses = rev or false, DelayTime = delay or 0 }, TweenInfoMt)
end }

-- Enum
local EnumItemMt = def("EnumItem")
Enum = setmetatable({}, { __index = function(t, enumName)
	local enumType = { Name = enumName }
	local items = {}
	setmetatable(enumType, { __index = function(_, itemName)
		if items[itemName] == nil then
			items[itemName] = setmetatable({ Name = itemName, EnumType = enumType, Value = #items }, EnumItemMt)
		end
		return items[itemName]
	end, __tname = "Enum" })
	rawset(t, enumName, enumType)
	return enumType
end })

local luauTypeof = typeof
typeof = function(v)
	if type(v) == "table" then
		local mt = getmetatable(v)
		if mt and mt.__tname then return mt.__tname end
		if mt and rawget(mt, "__tname") then return rawget(mt, "__tname") end
	end
	return luauTypeof(v)
end

----------------------------------------------------------------------
-- Instances
----------------------------------------------------------------------
local PARENT = {
	GuiObject = "Instance", GuiButton = "GuiObject", Frame = "GuiObject", CanvasGroup = "GuiObject", TextLabel = "GuiObject",
	TextButton = "GuiButton", TextBox = "GuiObject", ImageLabel = "GuiObject", ImageButton = "GuiButton", ScrollingFrame = "GuiObject",
	ScreenGui = "Instance", UICorner = "Instance", UIStroke = "Instance", UIGradient = "Instance", UIListLayout = "Instance",
	UIPadding = "Instance", UIScale = "Instance", Folder = "Instance", BlurEffect = "Instance", ModuleScript = "Instance",
}
local EVENTS = {
	MouseEnter = 1, MouseLeave = 1, MouseMoved = 1, InputBegan = 1, InputEnded = 1, InputChanged = 1, Activated = 1,
	MouseButton1Click = 1, MouseButton2Click = 1, MouseButton1Down = 1, MouseButton1Up = 1, Destroying = 1, ChildAdded = 1,
	ChildRemoved = 1, DescendantAdded = 1, FocusLost = 1, Focused = 1, AncestryChanged = 1, Changed = 1,
}
local DEFAULTS = {
	Visible = true, Text = "", ZIndex = 1, Rotation = 0, LayoutOrder = 0, Active = false, ClipsDescendants = false,
	BackgroundTransparency = 0, GroupTransparency = 0, Transparency = 0, Thickness = 1, Scale = 1, TextSize = 14,
	TextTransparency = 0, ImageTransparency = 0, Size = UDim2.new(0, 0, 0, 0), Position = UDim2.new(0, 0, 0, 0),
	AnchorPoint = Vector2.new(0, 0), BackgroundColor3 = Color3.new(0.63, 0.63, 0.63), TextColor3 = Color3.new(0, 0, 0),
	ImageColor3 = Color3.new(1, 1, 1), PlaceholderColor3 = Color3.new(0.7, 0.7, 0.7), ScrollBarImageColor3 = Color3.new(0, 0, 0),
	Color = Color3.new(1, 1, 1), CanvasSize = UDim2.new(0, 0, 0, 0), TextEditable = true, PlaceholderText = "",
	AutomaticSize = Enum.AutomaticSize.None, ScrollBarThickness = 12, Name = "", Size_ = nil, Offset = nil,
	DisplayOrder = 0, Padding = UDim.new(0, 0), BorderSizePixel = 1, Image = "", Brightness = 0, Enabled = true,
}
local InstanceMt = def("Instance")

local function isA(inst, className)
	local c = rawget(inst, "_class")
	while c do
		if c == className then return true end
		c = PARENT[c]
	end
	return className == "Instance"
end

local function absSize(inst)
	local size = rawget(inst, "_props").Size or DEFAULTS.Size
	local parent = rawget(inst, "_parent")
	local pw, ph = 1280, 720
	if parent then
		local ps = parent.AbsoluteSize
		pw, ph = ps.X, ps.Y
	end
	if rawget(inst, "_class") == "ScreenGui" then return V2(1280, 720) end
	return V2(size.X.Scale * pw + size.X.Offset, size.Y.Scale * ph + size.Y.Offset)
end
local function absPos(inst)
	local pos = rawget(inst, "_props").Position or DEFAULTS.Position
	local parent = rawget(inst, "_parent")
	local ox, oy = 0, 0
	local pw, ph = 1280, 720
	if parent then
		local pp, ps = parent.AbsolutePosition, parent.AbsoluteSize
		ox, oy, pw, ph = pp.X, pp.Y, ps.X, ps.Y
	end
	return V2(ox + pos.X.Scale * pw + pos.X.Offset, oy + pos.Y.Scale * ph + pos.Y.Offset)
end

local ALL_INSTANCES = setmetatable({}, { __mode = "k" })
local destroyedCount = 0

local function descendants(inst, out)
	for _, child in ipairs(rawget(inst, "_children")) do
		table.insert(out, child)
		descendants(child, out)
	end
	return out
end

local methods = {}
function methods.IsA(self, c) return isA(self, c) end
function methods.GetChildren(self) return table.clone(rawget(self, "_children")) end
function methods.GetDescendants(self) return descendants(self, {}) end
function methods.FindFirstChild(self, name, recursive)
	for _, child in ipairs(rawget(self, "_children")) do if child.Name == name then return child end end
	if recursive then for _, child in ipairs(descendants(self, {})) do if child.Name == name then return child end end end
	return nil
end
function methods.WaitForChild(self, name) return methods.FindFirstChild(self, name) end
function methods.FindFirstChildOfClass(self, class)
	for _, child in ipairs(rawget(self, "_children")) do if isA(child, class) then return child end end
end
function methods.FindFirstChildWhichIsA(self, class, recursive)
	for _, child in ipairs(recursive and descendants(self, {}) or rawget(self, "_children")) do if isA(child, class) then return child end end
end
function methods.FindFirstAncestorWhichIsA(self, class)
	local p = rawget(self, "_parent")
	while p do if isA(p, class) then return p end p = rawget(p, "_parent") end
end
function methods.IsDescendantOf(self, other)
	local p = rawget(self, "_parent")
	while p do if p == other then return true end p = rawget(p, "_parent") end
	return false
end
function methods.GetAttribute(self, k) return rawget(self, "_attrs")[k] end
function methods.SetAttribute(self, k, v) rawget(self, "_attrs")[k] = v end
function methods.ClearAllChildren(self) for _, c in ipairs(table.clone(rawget(self, "_children"))) do c:Destroy() end end
function methods.GetPropertyChangedSignal(self, prop)
	local sigs = rawget(self, "_propSignals")
	if not sigs[prop] then sigs[prop] = newSignal() end
	return sigs[prop]
end
function methods.CaptureFocus(self) rawget(self, "_props")._focused = true; self.Focused:Fire() end
function methods.ReleaseFocus(self) rawget(self, "_props")._focused = false; self.FocusLost:Fire(false) end
function methods.IsFocused(self) return rawget(self, "_props")._focused == true end
function methods.GetFullName(self) return self.Name end
function methods.Destroy(self)
	if rawget(self, "_destroyed") then return end
	rawset(self, "_destroyed", true)
	destroyedCount += 1
	self.Destroying:Fire()
	for _, c in ipairs(table.clone(rawget(self, "_children"))) do c:Destroy() end
	self.Parent = nil
	for _, sig in pairs(rawget(self, "_signals")) do sig._order = {}; sig._list = {}; sig._count = 0 end
end

InstanceMt.__index = function(self, key)
	local m = methods[key]
	if m then return m end
	local props = rawget(self, "_props")
	if key == "Parent" then return rawget(self, "_parent") end
	if key == "ClassName" then return rawget(self, "_class") end
	if key == "AbsoluteSize" then return props.AbsoluteSize or absSize(self) end
	if key == "AbsolutePosition" then return absPos(self) end
	if key == "AbsoluteCanvasSize" then return absSize(self) end
	if key == "TextBounds" then return V2(#(props.Text or "") * (props.TextSize or 14) * 0.55, props.TextSize or 14) end
	if key == "UserInputState" then return props.UserInputState end
	if EVENTS[key] then
		local sigs = rawget(self, "_signals")
		if not sigs[key] then sigs[key] = newSignal() end
		return sigs[key]
	end
	local v = props[key]
	if v ~= nil then return v end
	return DEFAULTS[key]
end
InstanceMt.__newindex = function(self, key, value)
	if key == "Parent" then
		local old = rawget(self, "_parent")
		if old == value then return end
		if old then
			local list = rawget(old, "_children")
			table.remove(list, table.find(list, self))
			old.ChildRemoved:Fire(self)
		end
		rawset(self, "_parent", value)
		if value then
			table.insert(rawget(value, "_children"), self)
			value.ChildAdded:Fire(self)
		end
		return
	end
	local props = rawget(self, "_props")
	local prev = props[key]
	props[key] = value
	if prev ~= value then
		local sigs = rawget(self, "_propSignals")
		if sigs[key] then sigs[key]:Fire() end
	end
end

local liveCount = 0
Instance = {
	new = function(class, parent)
		assert(PARENT[class] or class == "Instance", "mock: unknown class " .. tostring(class))
		local inst = setmetatable({ _class = class, _props = {}, _children = {}, _signals = {}, _propSignals = {}, _attrs = {} }, InstanceMt)
		ALL_INSTANCES[inst] = true
		rawget(inst, "_props").Name = class
		if class == "UIGradient" then rawget(inst, "_props").Color = ColorSequence.new(C3(1, 1, 1), C3(1, 1, 1)) end
		if parent then inst.Parent = parent end
		return inst
	end,
}
function MockInstanceStats()
	local alive = 0
	for inst in pairs(ALL_INSTANCES) do if not rawget(inst, "_destroyed") then alive += 1 end end
	return { Alive = alive, Destroyed = destroyedCount }
end
function MockAliveInstances()
	local list = {}
	for inst in pairs(ALL_INSTANCES) do if not rawget(inst, "_destroyed") then table.insert(list, inst) end end
	return list
end

----------------------------------------------------------------------
-- Tweens
----------------------------------------------------------------------
local ActiveTweens = 0
local TweenMt = def("Tween")
TweenMt.__index = function(self, k)
	if k == "Completed" then return rawget(self, "_completed") end
	return TweenMt[k] or rawget(self, k)
end
function TweenMt:Play()
	if self._state == "Playing" then return end
	self._state = "Playing"
	ActiveTweens += 1
	local info = self._info
	if info.RepeatCount ~= 0 then return end -- looping: never completes by itself
	local at = Clock.now + (info.Time or 0) + (info.DelayTime or 0)
	self._item = schedule(at, function()
		if self._state ~= "Playing" then return end
		self._state = "Completed"; ActiveTweens -= 1
		for k, v in pairs(self._goal) do pcall(function() self._inst[k] = v end) end
		self._completed:Fire(Enum.PlaybackState.Completed)
	end)
end
function TweenMt:Cancel()
	if self._state == "Playing" then
		self._state = "Cancelled"; ActiveTweens -= 1
		if self._item then self._item.alive = false end
		self._completed:Fire(Enum.PlaybackState.Cancelled)
	end
end
function MockActiveTweens() return ActiveTweens end

----------------------------------------------------------------------
-- Services
----------------------------------------------------------------------
local services = {}
services.TweenService = { Create = function(_, inst, info, goal)
	return setmetatable({ _inst = inst, _info = info, _goal = goal, _state = "Idle", _completed = newSignal() }, TweenMt)
end }

local UIS = { TouchEnabled = MOCK_TOUCH == true, KeyboardEnabled = MOCK_TOUCH ~= true, MouseEnabled = MOCK_TOUCH ~= true, InputBegan = newSignal(), InputEnded = newSignal(), InputChanged = newSignal(), _focused = nil }
function UIS:GetMouseLocation() return V2(640, 360) end
function UIS:GetFocusedTextBox() return self._focused end
services.UserInputService = UIS
services.RunService = { Heartbeat = newSignal(), RenderStepped = newSignal() }
services.GuiService = { GetGuiInset = function() return V2(0, 0) end }
services.TextService = { GetTextSize = function(_, text, size, font, bounds)
	local w = #text * size * 0.55
	local lines = 1
	if bounds and bounds.X < 1e6 and w > bounds.X then lines = math.ceil(w / math.max(bounds.X, 1)); w = bounds.X end
	return V2(w, lines * (size + 2))
end }

-- Compact JSON for HttpService
local function jsonEncode(v)
	local t = type(v)
	if t == "nil" then return "null" elseif t == "boolean" then return tostring(v)
	elseif t == "number" then assert(v == v and v ~= math.huge and v ~= -math.huge, "JSON number invalid"); return tostring(v)
	elseif t == "string" then return '"' .. v:gsub('[%c"\\]', function(c) return string.format("\\u%04x", c:byte()) end) .. '"'
	elseif t == "table" then
		assert(getmetatable(v) == nil, "JSON cannot encode " .. typeof(v))
		if #v > 0 or next(v) == nil then
			local out = {}
			for _, item in ipairs(v) do table.insert(out, jsonEncode(item)) end
			return "[" .. table.concat(out, ",") .. "]"
		end
		local keys = {}
		for k in pairs(v) do table.insert(keys, k) end
		table.sort(keys)
		local out = {}
		for _, k in ipairs(keys) do table.insert(out, jsonEncode(tostring(k)) .. ":" .. jsonEncode(v[k])) end
		return "{" .. table.concat(out, ",") .. "}"
	end
	error("JSON cannot encode " .. t)
end
local function jsonDecode(s)
	local i = 1
	local function ws() i = s:find("%S", i) or #s + 1 end
	local value
	local function str()
		local out = {}
		i += 1
		while true do
			local c = s:sub(i, i)
			if c == '"' then i += 1 break end
			if c == "\\" then
				local n = s:sub(i + 1, i + 1)
				if n == "u" then table.insert(out, string.char(tonumber(s:sub(i + 2, i + 5), 16))); i += 6
				else table.insert(out, ({ n = "\n", t = "\t", r = "\r" })[n] or n); i += 2 end
			else table.insert(out, c); i += 1 end
			if i > #s then error("unterminated string") end
		end
		return table.concat(out)
	end
	function value()
		ws()
		local c = s:sub(i, i)
		if c == "{" then
			local t = {}; i += 1; ws()
			if s:sub(i, i) == "}" then i += 1 return t end
			while true do
				ws(); local k = str(); ws(); assert(s:sub(i, i) == ":", "expected :"); i += 1
				t[k] = value(); ws()
				local d = s:sub(i, i); i += 1
				if d == "}" then break end
				assert(d == ",", "expected ,")
			end
			return t
		elseif c == "[" then
			local t = {}; i += 1; ws()
			if s:sub(i, i) == "]" then i += 1 return t end
			while true do
				table.insert(t, value()); ws()
				local d = s:sub(i, i); i += 1
				if d == "]" then break end
				assert(d == ",", "expected ,")
			end
			return t
		elseif c == '"' then return str()
		elseif s:sub(i, i + 3) == "true" then i += 4 return true
		elseif s:sub(i, i + 4) == "false" then i += 5 return false
		elseif s:sub(i, i + 3) == "null" then i += 4 return nil
		else
			local num = s:match("^-?%d+%.?%d*[eE]?[+-]?%d*", i)
			assert(num and #num > 0, "bad JSON at " .. i)
			i += #num
			return tonumber(num)
		end
	end
	local v = value(); ws()
	assert(i > #s, "trailing JSON data")
	return v
end
services.HttpService = { JSONEncode = function(_, v) return jsonEncode(v) end, JSONDecode = function(_, s) return jsonDecode(s) end }

services.Stats = {
	Network = { ServerStatsItem = { ["Data Ping"] = { GetValue = function() return 42 end } } },
	GetTotalMemoryUsageMb = function() return 512 end,
}
services.Lighting = Instance.new("Folder")
services.CoreGui = Instance.new("Folder")
local playerGui = Instance.new("Folder")
services.Players = { LocalPlayer = { DisplayName = "Tester", Name = "tester", PlayerGui = playerGui, WaitForChild = function(self) return self.PlayerGui end } }

local camera = { ViewportSize = V2(1280, 720) }
workspace = { CurrentCamera = camera }

game = { GetService = function(_, name) return assert(services[name], "mock: no service " .. name) end }
function MockServices() return services end
function MockPlayerGui() return playerGui end

----------------------------------------------------------------------
-- Test controls
----------------------------------------------------------------------
function MockStep(seconds, stepSize)
	stepSize = stepSize or 0.05
	local remaining = seconds
	while remaining > 1e-9 do
		local dt = math.min(stepSize, remaining)
		Clock.now += dt
		runDue()
		services.RunService.Heartbeat:Fire(dt)
		runDue()
		remaining -= dt
	end
	runDue()
end
function MockNow() return Clock.now end
function MockInput(kind, extra)
	local input = { UserInputType = kind, KeyCode = Enum.KeyCode.Unknown, Position = V2(0, 0), UserInputState = Enum.UserInputState.Begin }
	for k, v in pairs(extra or {}) do input[k] = v end
	return input
end
function MockPressKey(keyCode)
	local input = MockInput(Enum.UserInputType.Keyboard, { KeyCode = keyCode })
	UIS.InputBegan:Fire(input, false)
	runDue()
	local up = MockInput(Enum.UserInputType.Keyboard, { KeyCode = keyCode, UserInputState = Enum.UserInputState.End })
	UIS.InputEnded:Fire(up, false)
	runDue()
end
