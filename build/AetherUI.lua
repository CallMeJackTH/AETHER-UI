-- AETHER UI standalone build. Paste into a ModuleScript or host as a raw source file.
local __AETHER_MODULES = {}
__AETHER_MODULES.Theme = (function()
local Theme = {}
Theme.Presets = {
    Dark = {Background=Color3.fromRGB(11,13,16), Surface=Color3.fromRGB(14,17,22), Elevated=Color3.fromRGB(19,23,30), Border=Color3.fromRGB(30,36,45), Text=Color3.fromRGB(230,234,240), Muted=Color3.fromRGB(142,153,172), Accent=Color3.fromRGB(94,139,255)},
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

end)()
__AETHER_MODULES.Janitor = (function()
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

end)()
__AETHER_MODULES.Factory = (function()
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

end)()
-- AETHER UI v1.0.0 | Modular Roblox UI framework
-- Intended for Roblox Studio / experiences. No executor-only APIs are required.
local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")
local Theme = __AETHER_MODULES.Theme
local Janitor = __AETHER_MODULES.Janitor
local Factory = __AETHER_MODULES.Factory

local Aether = {Version="1.0.0"}
Aether.__index = Aether

local function safeCallback(callback, ...)
    if type(callback) ~= "function" then return end
    local ok, err = pcall(callback, ...)
    if not ok then warn("[AETHER] Callback error: "..tostring(err)) end
end
local function tween(instance, duration, props)
    local t = TweenService:Create(instance, TweenInfo.new(duration or .18, Enum.EasingStyle.Quart, Enum.EasingDirection.Out), props)
    t:Play()
    return t
end
local function make(class, props, parent) return Factory.Create(class, props, parent) end
local function corner(obj, n) Factory.Corner(obj, n) end
local function stroke(obj, color, transparency) Factory.Stroke(obj, color, transparency) end
local function text(parent, value, size, color, bold)
    return make("TextLabel", {BackgroundTransparency=1, Text=value or "", Font=bold and Enum.Font.GothamSemibold or Enum.Font.Gotham, TextSize=size or 12, TextColor3=color, TextXAlignment=Enum.TextXAlignment.Left, TextYAlignment=Enum.TextYAlignment.Center, Size=UDim2.new(1,0,0,20)}, parent)
end
local function button(parent, label, theme, height)
    local b=make("TextButton",{AutoButtonColor=false,Text=label,Font=Enum.Font.GothamMedium,TextSize=12,TextColor3=theme.Text,BackgroundColor3=theme.Elevated,Size=UDim2.new(1,0,0,height or 34)},parent)
    corner(b,7); stroke(b,theme.Border,.15)
    b.MouseEnter:Connect(function() tween(b,.12,{BackgroundColor3=theme.Border}) end)
    b.MouseLeave:Connect(function() tween(b,.12,{BackgroundColor3=theme.Elevated}) end)
    return b
end
local function card(parent, theme, height)
    local f=make("Frame",{BackgroundColor3=theme.Surface,BackgroundTransparency=.08,Size=UDim2.new(1,0,0,height or 58)},parent)
    corner(f,8); stroke(f,theme.Border,.25)
    return f
end
local function list(parent, padding)
    make("UIPadding",{PaddingTop=UDim.new(0,padding or 8),PaddingBottom=UDim.new(0,padding or 8),PaddingLeft=UDim.new(0,8),PaddingRight=UDim.new(0,8)},parent)
    make("UIListLayout",{Padding=UDim.new(0,7),SortOrder=Enum.SortOrder.LayoutOrder},parent)
end
local function setCanvas(sf, layout)
    local function update() sf.CanvasSize=UDim2.fromOffset(0,layout.AbsoluteContentSize.Y+18) end
    layout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(update); update()
end

function Aether:Notify(config)
    config=config or {}
    local frame=make("Frame",{AnchorPoint=Vector2.new(1,0),Position=UDim2.new(1,-18,0,18),Size=UDim2.fromOffset(270,72),BackgroundColor3=self.Theme.Surface,BackgroundTransparency=.04,ZIndex=50},self.ToastLayer)
    corner(frame,9); stroke(frame,self.Theme.Accent,.25)
    local title=text(frame,config.Title or "AETHER UI",13,self.Theme.Text,true); title.Position=UDim2.fromOffset(12,8); title.Size=UDim2.new(1,-24,0,20); title.ZIndex=51
    local body=text(frame,config.Content or config.Description or "Notification",11,self.Theme.Muted,false); body.Position=UDim2.fromOffset(12,31); body.Size=UDim2.new(1,-24,0,30); body.TextWrapped=true; body.ZIndex=51
    frame.Position=UDim2.new(1,300,0,18); tween(frame,.25,{Position=UDim2.new(1,-18,0,18)})
    task.delay(tonumber(config.Duration) or 3,function() if frame.Parent then tween(frame,.2,{Position=UDim2.new(1,300,0,18)}); task.delay(.22,function() if frame.Parent then frame:Destroy() end end) end end)
    return frame
end

function Aether:SetTheme(name, custom)
    local previous=self.Theme
    self.ThemeName=name or self.ThemeName
    self.Theme=Theme.Resolve(self.ThemeName,custom)
    local roles={"Background","Surface","Elevated","Border","Text","Muted","Accent"}
    for _,obj in ipairs(self.ThemeObjects) do
        if obj.instance and obj.instance.Parent then
            local color=self.Theme[obj.role]
            if color then pcall(function() obj.instance[obj.property]=color end) end
        end
    end
    -- Re-map standard palette colors so already-created controls follow theme changes.
    if self.Gui and previous then
        for _,item in ipairs(self.Gui:GetDescendants()) do
            for _,role in ipairs(roles) do
                local old=previous[role]
                if old then
                    if item:IsA("UIStroke") and role=="Border" and item.Color==old then item.Color=self.Theme[role]
                    elseif item:IsA("TextLabel") or item:IsA("TextButton") or item:IsA("TextBox") then
                        if item.TextColor3==old then item.TextColor3=self.Theme[role] end
                    elseif item:IsA("Frame") or item:IsA("ScrollingFrame") then
                        if item.BackgroundColor3==old then item.BackgroundColor3=self.Theme[role] end
                    end
                end
            end
        end
    end
    self:Notify({Title="Theme updated",Content=self.ThemeName.." theme applied.",Duration=2})
end
function Aether:RegisterThemeObject(instance, role, property)
    table.insert(self.ThemeObjects,{instance=instance,role=role,property=property or "BackgroundColor3"})
end

function Aether:CreateWindow(config)
    config=config or {}
    local player=Players.LocalPlayer
    assert(player,"AETHER UI must be initialized by a LocalPlayer")
    local selfWindow=setmetatable({},Aether)
    selfWindow.Version=self.Version
    selfWindow.ThemeName=config.Theme or "Dark"
    selfWindow.Theme=Theme.Resolve(selfWindow.ThemeName,config.CustomTheme)
    selfWindow.ThemeObjects={}
    selfWindow.Janitor=Janitor.new()
    selfWindow.Tabs={}
    selfWindow.Values={}
    selfWindow.Configurations={}
    selfWindow.CurrentConfig=nil
    local gui=make("ScreenGui",{Name="AETHER_UI",ResetOnSpawn=false,IgnoreGuiInset=true,ZIndexBehavior=Enum.ZIndexBehavior.Sibling},player:WaitForChild("PlayerGui"))
    selfWindow.Gui=gui; selfWindow.Janitor:Add(gui)
    local toast=make("Frame",{Name="ToastLayer",BackgroundTransparency=1,Size=UDim2.fromScale(1,1),ZIndex=50},gui); selfWindow.ToastLayer=toast
    local theme=selfWindow.Theme
    local main=make("Frame",{Name="MainWindow",AnchorPoint=Vector2.new(.5,.5),Position=UDim2.fromScale(.5,.5),Size=config.Size or (UserInputService.TouchEnabled and UDim2.fromOffset(460,320) or UDim2.fromOffset(680,440)),BackgroundColor3=theme.Background,BackgroundTransparency=config.Acrylic==false and 0 or .10,ClipsDescendants=true},gui)
    selfWindow.Main=main; corner(main,12); stroke(main,theme.Border,.15)
    if config.Acrylic~=false then
        local gradient=make("UIGradient",{Rotation=35,Color=ColorSequence.new({ColorSequenceKeypoint.new(0,theme.Surface),ColorSequenceKeypoint.new(1,theme.Background)}),Transparency=NumberSequence.new({NumberSequenceKeypoint.new(0,.18),NumberSequenceKeypoint.new(1,.02)})},main)
    end
    local titlebar=make("Frame",{Size=UDim2.new(1,0,0,40),BackgroundColor3=theme.Surface,BackgroundTransparency=.1},main)
    local brand=text(titlebar,"◆  "..(config.Title or "AETHER UI"),13,theme.Text,true); brand.Position=UDim2.fromOffset(14,0); brand.Size=UDim2.new(1,-140,1,0)
    local subtitle=text(titlebar,(config.Subtitle or "Premium Interface Framework").."  •  v"..selfWindow.Version,9,theme.Muted,false); subtitle.Position=UDim2.new(0,14,0,20); subtitle.Size=UDim2.new(1,-150,0,15)
    local min=button(titlebar,"—",theme,25); min.Size=UDim2.fromOffset(28,25); min.Position=UDim2.new(1,-68,0,7)
    local close=button(titlebar,"×",theme,25); close.Size=UDim2.fromOffset(28,25); close.Position=UDim2.new(1,-34,0,7)
    min.MouseButton1Click:Connect(function() selfWindow.Minimized=not selfWindow.Minimized; tween(main,.2,{Size=selfWindow.Minimized and UDim2.new(main.Size.X.Scale,main.Size.X.Offset,0,40) or (config.Size or (UserInputService.TouchEnabled and UDim2.fromOffset(460,320) or UDim2.fromOffset(680,440)))}); selfWindow.Body.Visible=not selfWindow.Minimized end)
    close.MouseButton1Click:Connect(function() selfWindow:Destroy() end)
    local dragging, dragStart, startPos=false,nil,nil
    selfWindow.Janitor:Add(titlebar.InputBegan:Connect(function(input)
        if input.UserInputType==Enum.UserInputType.MouseButton1 or input.UserInputType==Enum.UserInputType.Touch then dragging=true; dragStart=input.Position; startPos=main.Position end
    end))
    selfWindow.Janitor:Add(UserInputService.InputChanged:Connect(function(input)
        if dragging and (input.UserInputType==Enum.UserInputType.MouseMovement or input.UserInputType==Enum.UserInputType.Touch) then
            local delta=input.Position-dragStart; main.Position=UDim2.new(startPos.X.Scale,startPos.X.Offset+delta.X,startPos.Y.Scale,startPos.Y.Offset+delta.Y)
        end
    end))
    selfWindow.Janitor:Add(UserInputService.InputEnded:Connect(function(input) if input.UserInputType==Enum.UserInputType.MouseButton1 or input.UserInputType==Enum.UserInputType.Touch then dragging=false end end))
    local body=make("Frame",{Name="Body",Position=UDim2.fromOffset(0,40),Size=UDim2.new(1,0,1,-40),BackgroundTransparency=1},main); selfWindow.Body=body
    local sidebar=make("Frame",{Size=UDim2.new(0,142,1,0),BackgroundColor3=theme.Surface,BackgroundTransparency=.18},body); selfWindow.Sidebar=sidebar
    local nav=make("ScrollingFrame",{BackgroundTransparency=1,BorderSizePixel=0,Size=UDim2.new(1,0,1,-32),CanvasSize=UDim2.new(),ScrollBarThickness=2},sidebar)
    local navLayout=make("UIListLayout",{Padding=UDim.new(0,4),SortOrder=Enum.SortOrder.LayoutOrder},nav); make("UIPadding",{PaddingTop=UDim.new(0,9),PaddingLeft=UDim.new(0,8),PaddingRight=UDim.new(0,8)},nav); setCanvas(nav,navLayout)
    local footer=text(sidebar,"●  READY  •  "..selfWindow.Version,9,theme.Muted,false); footer.Position=UDim2.new(0,9,1,-27); footer.Size=UDim2.new(1,-18,0,18)
    local content=make("Frame",{Position=UDim2.new(0,142,0,0),Size=UDim2.new(1,-142,1,0),BackgroundTransparency=1},body); selfWindow.Content=content
    local function selectTab(tab)
        for _,t in ipairs(selfWindow.Tabs) do t.Page.Visible=(t==tab); tween(t.Nav,.12,{BackgroundColor3=t==tab and theme.Elevated or theme.Surface,TextColor3=t==tab and theme.Text or theme.Muted}) end
        selfWindow.ActiveTab=tab
    end
    function selfWindow:CreateTab(tabConfig)
        tabConfig=tabConfig or {}
        local page=make("ScrollingFrame",{Name="Page_"..(tabConfig.Name or "Tab"),Visible=#selfWindow.Tabs==0,BackgroundTransparency=1,BorderSizePixel=0,Size=UDim2.fromScale(1,1),CanvasSize=UDim2.new(),ScrollBarThickness=3,ScrollBarImageColor3=theme.Accent},content)
        local layout=make("UIListLayout",{Padding=UDim.new(0,8),SortOrder=Enum.SortOrder.LayoutOrder},page); make("UIPadding",{PaddingTop=UDim.new(0,12),PaddingBottom=UDim.new(0,12),PaddingLeft=UDim.new(0,12),PaddingRight=UDim.new(0,12)},page); setCanvas(page,layout)
        local navButton=button(nav,(tabConfig.Icon and "◇  " or "")..(tabConfig.Name or "Tab"),theme,32); navButton.TextXAlignment=Enum.TextXAlignment.Left; navButton.TextTruncate=Enum.TextTruncate.AtEnd
        local tab={Name=tabConfig.Name or "Tab",Page=page,Nav=navButton,Window=selfWindow}
        table.insert(selfWindow.Tabs,tab)
        navButton.MouseButton1Click:Connect(function() selectTab(tab) end)
        function tab:CreateSection(name)
            local section={Tab=self,Name=name or "Section",Window=selfWindow,Parent=page}
            local header=text(page,string.upper(section.Name),10,theme.Muted,true); header.Size=UDim2.new(1,0,0,18)
            local container=make("Frame",{BackgroundTransparency=1,Size=UDim2.new(1,0,0,0)},page)
            local ll=make("UIListLayout",{Padding=UDim.new(0,7),SortOrder=Enum.SortOrder.LayoutOrder},container)
            ll:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function() container.Size=UDim2.new(1,0,0,ll.AbsoluteContentSize.Y) end)
            section.Container=container
            local function row(name,desc,height)
                local f=card(container,theme,height or 54)
                local title=text(f,name or "Control",12,theme.Text,true); title.Position=UDim2.fromOffset(10,5); title.Size=UDim2.new(1,-20,0,19)
                if desc and desc~="" then local d=text(f,desc,10,theme.Muted,false); d.Position=UDim2.fromOffset(10,25); d.Size=UDim2.new(1,-20,0,18) end
                return f
            end
            function section:CreateButton(c)
                c=c or {}; local f=row(c.Name,c.Description,48); local b=button(f,c.ButtonText or "Run",theme,28); b.Size=UDim2.fromOffset(90,28); b.Position=UDim2.new(1,-100,.5,-14)
                b.MouseButton1Click:Connect(function() safeCallback(c.Callback); selfWindow:Notify({Title=c.Name or "Action",Content="Action completed."}) end); return {Instance=f,Button=b}
            end
            function section:CreateToggle(c)
                c=c or {}; local f=row(c.Name,c.Description,48); local state=c.Default==true
                local b=button(f,state and "ON" or "OFF",theme,27); b.Size=UDim2.fromOffset(54,27); b.Position=UDim2.new(1,-64,.5,-13.5)
                local function set(v) state=not not v; b.Text=state and "ON" or "OFF"; b.BackgroundColor3=state and theme.Accent or theme.Elevated; selfWindow.Values[c.Name or "Toggle"]=state; safeCallback(c.Callback,state) end
                b.MouseButton1Click:Connect(function() set(not state) end); set(state)
                return {Instance=f,GetValue=function() return state end,SetValue=set}
            end
            function section:CreateSlider(c)
                c=c or {}; local min,max=tonumber(c.Min) or 0,tonumber(c.Max) or 100; local value=math.clamp(tonumber(c.Default) or min,min,max)
                local f=row(c.Name,c.Description,66); local read=text(f,tostring(value),11,theme.Accent,true); read.Position=UDim2.new(1,-60,0,6); read.Size=UDim2.fromOffset(50,18); read.TextXAlignment=Enum.TextXAlignment.Right
                local track=make("Frame",{Position=UDim2.new(0,10,1,-18),Size=UDim2.new(1,-20,0,5),BackgroundColor3=theme.Border},f); corner(track,4)
                local fill=make("Frame",{Size=UDim2.new((value-min)/math.max(max-min,1),0,1,0),BackgroundColor3=theme.Accent},track); corner(fill,4)
                local hit=make("TextButton",{BackgroundTransparency=1,Text="",Size=UDim2.new(1,0,0,22),Position=UDim2.new(0,0,.5,-11)},track)
                local function set(v) value=math.clamp(v,min,max); fill.Size=UDim2.new((value-min)/math.max(max-min,1),0,1,0); read.Text=string.format("%g",value); selfWindow.Values[c.Name or "Slider"]=value; safeCallback(c.Callback,value) end
                local function move(input) local p=math.clamp((input.Position.X-track.AbsolutePosition.X)/math.max(track.AbsoluteSize.X,1),0,1); set(min+(max-min)*p) end
                hit.InputBegan:Connect(function(i) if i.UserInputType==Enum.UserInputType.MouseButton1 or i.UserInputType==Enum.UserInputType.Touch then move(i) end end)
                hit.InputChanged:Connect(function(i) if i.UserInputType==Enum.UserInputType.MouseMovement or i.UserInputType==Enum.UserInputType.Touch then if UserInputService:IsMouseButtonPressed(Enum.UserInputType.MouseButton1) then move(i) end end end)
                set(value); return {Instance=f,GetValue=function() return value end,SetValue=set}
            end
            function section:CreateDropdown(c)
                c=c or {}; local f=row(c.Name,c.Description,48); local current=c.Default
                local b=button(f,tostring(current or "Select…").."  ▾",theme,28); b.Size=UDim2.fromOffset(140,28); b.Position=UDim2.new(1,-150,.5,-14)
                local popup=make("Frame",{Visible=false,Position=UDim2.new(1,-150,1,2),Size=UDim2.fromOffset(140,0),BackgroundColor3=theme.Elevated,ZIndex=8},f); corner(popup,7); stroke(popup,theme.Border,.1)
                local pl=make("UIListLayout",{SortOrder=Enum.SortOrder.LayoutOrder},popup)
                local function refresh() for _,v in ipairs(popup:GetChildren()) do if v:IsA("TextButton") then v:Destroy() end end
                    for _,option in ipairs(c.Options or {}) do local ob=make("TextButton",{Text=tostring(option),Font=Enum.Font.Gotham,TextSize=11,TextColor3=theme.Text,BackgroundTransparency=1,Size=UDim2.new(1,0,0,27),ZIndex=9},popup); ob.MouseButton1Click:Connect(function() current=option; b.Text=tostring(option).."  ▾"; popup.Visible=false; selfWindow.Values[c.Name or "Dropdown"]=current; safeCallback(c.Callback,current) end) end
                    popup.Size=UDim2.fromOffset(140,math.min(#(c.Options or {})*27,135))
                end
                refresh(); b.MouseButton1Click:Connect(function() popup.Visible=not popup.Visible end)
                return {Instance=f,GetValue=function() return current end,SetValue=function(v) current=v; b.Text=tostring(v).."  ▾"; safeCallback(c.Callback,v) end}
            end
            function section:CreateMultiDropdown(c)
                c=c or {}; local selected={}; for _,v in ipairs(c.Default or {}) do selected[v]=true end
                local f=row(c.Name,c.Description,64); local b=button(f,"Choose options…  ▾",theme,28); b.Position=UDim2.new(1,-150,.5,-14); b.Size=UDim2.fromOffset(140,28)
                local popup=make("Frame",{Visible=false,Position=UDim2.new(1,-150,1,2),Size=UDim2.fromOffset(140,0),BackgroundColor3=theme.Elevated,ZIndex=8},f); corner(popup,7)
                for _,option in ipairs(c.Options or {}) do local ob=make("TextButton",{Text=(selected[option] and "☑ " or "□ ")..tostring(option),Font=Enum.Font.Gotham,TextSize=11,TextColor3=theme.Text,BackgroundTransparency=1,Size=UDim2.new(1,0,0,27),ZIndex=9},popup); ob.MouseButton1Click:Connect(function() selected[option]=not selected[option]; ob.Text=(selected[option] and "☑ " or "□ ")..tostring(option); local values={}; for _,v in ipairs(c.Options) do if selected[v] then table.insert(values,v) end end; b.Text=#values.." selected  ▾"; safeCallback(c.Callback,values) end) end
                popup.Size=UDim2.fromOffset(140,math.min(#(c.Options or {})*27,135)); b.MouseButton1Click:Connect(function() popup.Visible=not popup.Visible end)
                return {Instance=f,GetValue=function() local a={}; for _,v in ipairs(c.Options or {}) do if selected[v] then table.insert(a,v) end end; return a end}
            end
            function section:CreateTextbox(c)
                c=c or {}; local f=row(c.Name,c.Description,62); local input=make("TextBox",{Position=UDim2.new(0,10,1,-34),Size=UDim2.new(1,-20,0,26),BackgroundColor3=theme.Elevated,TextColor3=theme.Text,PlaceholderColor3=theme.Muted,PlaceholderText=c.Placeholder or "Enter text…",Text=c.Default or "",Font=Enum.Font.Gotham,TextSize=11,ClearTextOnFocus=false},f); corner(input,6); stroke(input,theme.Border,.2)
                input.FocusLost:Connect(function(enter) selfWindow.Values[c.Name or "Textbox"]=input.Text; safeCallback(c.Callback,input.Text,enter) end)
                return {Instance=f,Input=input,GetValue=function() return input.Text end,SetValue=function(v) input.Text=tostring(v) end}
            end
            function section:CreateKeybind(c)
                c=c or {}; local f=row(c.Name,c.Description,48); local key=c.Default or Enum.KeyCode.RightShift; local listening=false
                local b=button(f,key.Name,theme,28); b.Size=UDim2.fromOffset(90,28); b.Position=UDim2.new(1,-100,.5,-14)
                b.MouseButton1Click:Connect(function() listening=true; b.Text="Press key…" end)
                local conn=UserInputService.InputBegan:Connect(function(input,processed) if listening and not processed and input.UserInputType==Enum.UserInputType.Keyboard then key=input.KeyCode; listening=false; b.Text=key.Name; safeCallback(c.Callback,key) elseif not processed and input.KeyCode==key then safeCallback(c.Callback,key) end end); selfWindow.Janitor:Add(conn)
                return {Instance=f,GetValue=function() return key end}
            end
            function section:CreateColorPicker(c)
                c=c or {}; local f=row(c.Name,c.Description,48); local color=c.Default or theme.Accent
                local swatch=button(f,"●",theme,28); swatch.Size=UDim2.fromOffset(54,28); swatch.Position=UDim2.new(1,-64,.5,-14); swatch.BackgroundColor3=color
                swatch.MouseButton1Click:Connect(function() local h,s,v=Color3.toHSV(color); color=Color3.fromHSV((h+.08)%1,s,v); swatch.BackgroundColor3=color; safeCallback(c.Callback,color) end)
                return {Instance=f,GetValue=function() return color end,SetValue=function(v) if typeof(v)=="Color3" then color=v; swatch.BackgroundColor3=v; safeCallback(c.Callback,v) end end}
            end
            function section:CreateLabel(c) c=type(c)=="string" and {Text=c} or (c or {}); local f=card(container,theme,30); local l=text(f,c.Text or c.Name or "Label",12,theme.Text,false); l.Position=UDim2.fromOffset(10,0); return {Instance=f,SetText=function(v) l.Text=tostring(v) end} end
            function section:CreateParagraph(c) c=c or {}; local f=card(container,theme,64); local t=text(f,c.Title or c.Name or "Information",12,theme.Text,true); t.Position=UDim2.fromOffset(10,5); local d=text(f,c.Content or c.Description or "",10,theme.Muted,false); d.Position=UDim2.fromOffset(10,25); d.Size=UDim2.new(1,-20,0,34); d.TextWrapped=true; d.TextYAlignment=Enum.TextYAlignment.Top; return {Instance=f} end
            function section:CreateDivider() local f=make("Frame",{BackgroundColor3=theme.Border,BorderSizePixel=0,Size=UDim2.new(1,0,0,1)},container); return {Instance=f} end
            function section:CreateProgressBar(c) c=c or {}; local f=row(c.Name,c.Description,54); local track=make("Frame",{Position=UDim2.new(0,10,1,-17),Size=UDim2.new(1,-20,0,6),BackgroundColor3=theme.Border},f); corner(track,4); local fill=make("Frame",{Size=UDim2.new(math.clamp(c.Value or 0,0,100)/100,0,1,0),BackgroundColor3=theme.Accent},track); corner(fill,4); return {Instance=f,SetValue=function(_,v) fill.Size=UDim2.new(math.clamp(v,0,100)/100,0,1,0); safeCallback(c.Callback,v) end} end
            function section:CreateLoadingIndicator(c) c=c or {}; local f=row(c.Name or "Loading",c.Description,42); local spin=text(f,"◌",20,theme.Accent,true); spin.Position=UDim2.new(1,-34,0,4); spin.Size=UDim2.fromOffset(24,28); local active=true; task.spawn(function() while active and spin.Parent do spin.Rotation=(spin.Rotation+8)%360; RunService.Heartbeat:Wait() end end); return {Instance=f,Stop=function() active=false; f:Destroy() end} end
            function section:CreateTooltip(c) c=c or {}; local f=row(c.Name or "Hover for details",c.Description,40); local hint=text(f,c.Tooltip or "Tooltip",10,theme.Muted,false); hint.Position=UDim2.fromOffset(10,19); return {Instance=f} end
            function section:CreateContextMenu(c) c=c or {}; local f=row(c.Name or "Context menu",c.Description,42); local b=button(f,"Open menu",theme,28); b.Size=UDim2.fromOffset(100,28); b.Position=UDim2.new(1,-110,.5,-14); b.MouseButton2Click:Connect(function() selfWindow:Notify({Title="Context menu",Content=table.concat(c.Options or {"No actions"}," • ")}) end); return {Instance=f} end
            function section:CreateModal(c) c=c or {}; local f=row(c.Name or "Modal",c.Description,42); local b=button(f,"Open modal",theme,28); b.Size=UDim2.fromOffset(100,28); b.Position=UDim2.new(1,-110,.5,-14); b.MouseButton1Click:Connect(function() selfWindow:ShowDialog(c) end); return {Instance=f} end
            function section:CreateSearchBar(c) c=c or {}; local f=row(c.Name or "Search",c.Description,58); local input=make("TextBox",{Position=UDim2.fromOffset(10,27),Size=UDim2.new(1,-20,0,24),BackgroundColor3=theme.Elevated,TextColor3=theme.Text,PlaceholderText=c.Placeholder or "Search…",Text="",Font=Enum.Font.Gotham,TextSize=11},f); corner(input,6); input:GetPropertyChangedSignal("Text"):Connect(function() safeCallback(c.Callback,input.Text) end); return {Instance=f,Input=input} end
            function section:CreateConfigurationManager(c) c=c or {}; local f=row(c.Name or "Configurations",c.Description,58); local b=button(f,"Save current",theme,28); b.Size=UDim2.fromOffset(110,28); b.Position=UDim2.new(1,-120,.5,-14); b.MouseButton1Click:Connect(function() selfWindow:SaveConfiguration(c.ConfigName or "Default"); selfWindow:Notify({Title="Configuration saved",Content=c.ConfigName or "Default"}) end); return {Instance=f} end
            function section:CreateThemeManager() local f=row("Theme Manager","Switch the active interface palette.",52); local b=button(f,"Cycle theme",theme,28); b.Size=UDim2.fromOffset(110,28); b.Position=UDim2.new(1,-120,.5,-14); b.MouseButton1Click:Connect(function() local names={"Dark","Midnight","Light"}; local index=table.find(names,selfWindow.ThemeName) or 1; selfWindow:SetTheme(names[index%#names+1]) end); return {Instance=f} end
            return section
        end
        if #selfWindow.Tabs==1 then selfWindow.ActiveTab=tab end
        return tab
    end
    function selfWindow:ShowDialog(c)
        c=c or {}; local overlay=make("Frame",{BackgroundColor3=Color3.new(0,0,0),BackgroundTransparency=.35,Size=UDim2.fromScale(1,1),ZIndex=30},gui)
        local panel=make("Frame",{AnchorPoint=Vector2.new(.5,.5),Position=UDim2.fromScale(.5,.5),Size=UDim2.fromOffset(300,150),BackgroundColor3=theme.Surface,ZIndex=31},overlay); corner(panel,10); stroke(panel,theme.Border,.1)
        local t=text(panel,c.Title or "Confirm action",14,theme.Text,true); t.Position=UDim2.fromOffset(14,12); t.Size=UDim2.new(1,-28,0,24); t.ZIndex=32
        local d=text(panel,c.Content or c.Description or "Are you sure you want to continue?",11,theme.Muted,false); d.Position=UDim2.fromOffset(14,42); d.Size=UDim2.new(1,-28,0,50); d.TextWrapped=true; d.ZIndex=32
        local cancel=button(panel,c.CancelText or "Cancel",theme,30); cancel.Position=UDim2.new(0,14,1,-44); cancel.Size=UDim2.new(.5,-20,0,30); cancel.ZIndex=32
        local confirm=button(panel,c.ConfirmText or "Confirm",theme,30); confirm.Position=UDim2.new(.5,6,1,-44); confirm.Size=UDim2.new(.5,-20,0,30); confirm.BackgroundColor3=theme.Accent; confirm.ZIndex=32
        cancel.MouseButton1Click:Connect(function() overlay:Destroy(); safeCallback(c.OnCancel) end)
        confirm.MouseButton1Click:Connect(function() overlay:Destroy(); safeCallback(c.Callback or c.OnConfirm) end)
        return overlay
    end
    function selfWindow:SaveConfiguration(name)
        name=name or "Default"; local snapshot={}; for k,v in pairs(selfWindow.Values) do snapshot[k]=v end; selfWindow.Configurations[name]=snapshot; selfWindow.CurrentConfig=name; return true
    end
    function selfWindow:LoadConfiguration(name)
        local cfg=selfWindow.Configurations[name]; if not cfg then return false,"Configuration not found" end
        for k,v in pairs(cfg) do selfWindow.Values[k]=v end; selfWindow.CurrentConfig=name; selfWindow:Notify({Title="Configuration loaded",Content=name}); return true
    end
    function selfWindow:GetValue(name) return selfWindow.Values[name] end
    function selfWindow:Destroy() selfWindow.Janitor:Cleanup() end
    return selfWindow
end

return setmetatable(Aether,{__call=function(_,...) return Aether:CreateWindow(...) end})
