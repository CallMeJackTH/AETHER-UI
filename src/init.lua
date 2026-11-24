-- AETHER UI v1.0.0 | Modular Roblox UI framework
-- Intended for Roblox Studio / experiences. No executor-only APIs are required.
local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")
local Theme = require(script.Core.Theme)
local Janitor = require(script.Modules.Janitor)
local Factory = require(script.Components.Factory)

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
    corner(f,8); stroke(f,Color3.fromRGB(30,36,46),.18)
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
    local frame=make("Frame",{Name="Toast",Size=UDim2.fromOffset(270,64),BackgroundColor3=Color3.fromRGB(14,17,23),BackgroundTransparency=.04,ZIndex=50,LayoutOrder=-math.floor(os.clock()*1000)},self.ToastLayer)
    corner(frame,9); stroke(frame,Color3.fromRGB(34,41,54),.05)
    local icon=make("Frame",{BackgroundColor3=Color3.fromRGB(25,37,61),Position=UDim2.fromOffset(10,10),Size=UDim2.fromOffset(24,24),ZIndex=51},frame); corner(icon,6); stroke(icon,self.Theme.Accent,.25)
    local glyph=text(icon,"OK",13,self.Theme.Accent,true); glyph.TextXAlignment=Enum.TextXAlignment.Center; glyph.Size=UDim2.fromScale(1,1); glyph.ZIndex=52
    local title=text(frame,config.Title or "AETHER UI",12,self.Theme.Text,true); title.Position=UDim2.fromOffset(44,8); title.Size=UDim2.new(1,-56,0,18); title.ZIndex=51
    local body=text(frame,config.Content or config.Description or "Notification",10,self.Theme.Muted,false); body.Position=UDim2.fromOffset(44,27); body.Size=UDim2.new(1,-54,0,26); body.TextWrapped=true; body.ZIndex=51
    local timer=make("Frame",{BackgroundColor3=self.Theme.Accent,BorderSizePixel=0,Position=UDim2.new(0,0,1,-2),Size=UDim2.new(1,0,0,2),ZIndex=52},frame)
    local duration=tonumber(config.Duration) or 3
    tween(frame,.2,{BackgroundTransparency=0})
    tween(timer,duration,{Size=UDim2.new(0,0,0,2)})
    task.delay(duration,function() if frame.Parent then tween(frame,.18,{BackgroundTransparency=1}); task.delay(.2,function() if frame.Parent then frame:Destroy() end end) end end)
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
    selfWindow.NavGroups={}
    selfWindow.Values={}
    selfWindow.Configurations={}
    selfWindow.CurrentConfig=nil
    local gui=make("ScreenGui",{Name="AETHER_UI",ResetOnSpawn=false,IgnoreGuiInset=true,ZIndexBehavior=Enum.ZIndexBehavior.Sibling},player:WaitForChild("PlayerGui"))
    selfWindow.Gui=gui; selfWindow.Janitor:Add(gui)
    local toast=make("Frame",{Name="ToastLayer",BackgroundTransparency=1,Size=UDim2.fromScale(1,1),ZIndex=50},gui); selfWindow.ToastLayer=toast
    make("UIListLayout",{FillDirection=Enum.FillDirection.Vertical,HorizontalAlignment=Enum.HorizontalAlignment.Right,VerticalAlignment=Enum.VerticalAlignment.Bottom,Padding=UDim.new(0,8),SortOrder=Enum.SortOrder.LayoutOrder},toast)
    make("UIPadding",{PaddingRight=UDim.new(0,18),PaddingBottom=UDim.new(0,18)},toast)
    local theme=selfWindow.Theme
    local main=make("Frame",{Name="MainWindow",AnchorPoint=Vector2.new(.5,.5),Position=UDim2.fromScale(.5,.5),Size=config.Size or (UserInputService.TouchEnabled and UDim2.fromOffset(460,320) or UDim2.fromOffset(680,440)),BackgroundColor3=theme.Background,BackgroundTransparency=config.Acrylic==false and 0 or .10,ClipsDescendants=true},gui)
    selfWindow.Main=main; corner(main,12); stroke(main,theme.Border,.15)
    -- Floating launcher follows the web reference: dark acrylic pill with an accent status dot.
    local floatingToggle=make("TextButton",{Name="AetherToggle",AutoButtonColor=false,Text="Aether Toggle",Font=Enum.Font.GothamMedium,TextSize=11,TextColor3=Color3.fromRGB(230,234,240),TextXAlignment=Enum.TextXAlignment.Left,BackgroundColor3=Color3.fromRGB(11,13,16),BackgroundTransparency=.12,Size=UDim2.fromOffset(116,32),Position=UDim2.fromOffset(18,18),ZIndex=60},gui)
    corner(floatingToggle,18); stroke(floatingToggle,Color3.fromRGB(38,46,59),.08)
    floatingToggle.MouseEnter:Connect(function() tween(floatingToggle,.12,{BackgroundColor3=Color3.fromRGB(20,24,32)}) end)
    floatingToggle.MouseLeave:Connect(function() tween(floatingToggle,.12,{BackgroundColor3=Color3.fromRGB(11,13,16)}) end)
    local togglePadding=make("UIPadding",{PaddingLeft=UDim.new(0,25),PaddingRight=UDim.new(0,9)},floatingToggle)
    local toggleDot=make("Frame",{Name="StatusDot",BackgroundColor3=theme.Accent,BorderSizePixel=0,Position=UDim2.fromOffset(10,12),Size=UDim2.fromOffset(8,8),ZIndex=61},floatingToggle); corner(toggleDot,4)
    local toggleDragging,toggleMoved,toggleDragStart,toggleStartPos=false,false,nil,nil
    floatingToggle.InputBegan:Connect(function(input)
        if input.UserInputType==Enum.UserInputType.MouseButton1 or input.UserInputType==Enum.UserInputType.Touch then
            toggleDragging=true; toggleMoved=false; toggleDragStart=input.Position; toggleStartPos=floatingToggle.Position
        end
    end)
    floatingToggle.MouseButton1Click:Connect(function()
        if toggleMoved then toggleMoved=false; return end
        main.Visible=not main.Visible; selfWindow.Minimized=not main.Visible
    end)
    if config.Acrylic~=false then
        local gradient=make("UIGradient",{Rotation=35,Color=ColorSequence.new({ColorSequenceKeypoint.new(0,theme.Surface),ColorSequenceKeypoint.new(1,theme.Background)}),Transparency=NumberSequence.new({NumberSequenceKeypoint.new(0,.18),NumberSequenceKeypoint.new(1,.02)})},main)
    end
    local titlebar=make("Frame",{Name="TitleBar",Size=UDim2.new(1,0,0,38),BackgroundColor3=Color3.fromRGB(14,17,22),BackgroundTransparency=.35,BorderSizePixel=0},main)
    local titleLine=make("Frame",{BackgroundColor3=Color3.fromRGB(26,31,40),BorderSizePixel=0,Position=UDim2.new(0,0,1,-1),Size=UDim2.new(1,0,0,1)},titlebar)
    local logo=make("Frame",{BackgroundColor3=Color3.fromRGB(25,37,61),Position=UDim2.fromOffset(14,9),Size=UDim2.fromOffset(20,20)},titlebar); corner(logo,6); stroke(logo,theme.Accent,.35)
    local logoText=text(logo,"A",11,theme.Accent,true); logoText.TextXAlignment=Enum.TextXAlignment.Center; logoText.Size=UDim2.fromScale(1,1)
    local brand=text(titlebar,config.Title or "Aether Framework",13,theme.Text,true); brand.Position=UDim2.fromOffset(42,0); brand.Size=UDim2.new(0,180,1,0)
    local version=make("TextLabel",{BackgroundColor3=Color3.fromRGB(22,27,35),BorderSizePixel=0,Position=UDim2.fromOffset(224,9),Size=UDim2.fromOffset(38,19),Text="v2.4",Font=Enum.Font.Code,TextSize=10,TextColor3=theme.Muted},titlebar); corner(version,4); stroke(version,theme.Border,.2)
    local search=button(titlebar,"Search  /  Ctrl K",theme,24); search.Size=UDim2.fromOffset(132,24); search.Position=UDim2.new(1,-190,0,7); search.TextSize=10; search.TextColor3=theme.Muted
    local min=button(titlebar,"-",theme,24); min.Size=UDim2.fromOffset(24,24); min.Position=UDim2.new(1,-52,0,7)
    local close=button(titlebar,"X",theme,24); close.Size=UDim2.fromOffset(24,24); close.Position=UDim2.new(1,-26,0,7); close.TextColor3=theme.Muted
    min.MouseButton1Click:Connect(function()
        selfWindow.Minimized=true; main.Visible=false
    end)
    close.MouseButton1Click:Connect(function()
        selfWindow:ShowDialog({Title="Unload AETHER UI?",Content="This will disconnect active UI callbacks and destroy the ScreenGui.",CancelText="Cancel",ConfirmText="Confirm Unload",Callback=function() selfWindow:Destroy() end})
    end)
    local dragging, dragStart, startPos=false,nil,nil
    selfWindow.Janitor:Add(titlebar.InputBegan:Connect(function(input)
        if input.UserInputType==Enum.UserInputType.MouseButton1 or input.UserInputType==Enum.UserInputType.Touch then dragging=true; dragStart=input.Position; startPos=main.Position end
    end))
    selfWindow.Janitor:Add(UserInputService.InputChanged:Connect(function(input)
        if dragging and (input.UserInputType==Enum.UserInputType.MouseMovement or input.UserInputType==Enum.UserInputType.Touch) then
            local delta=input.Position-dragStart; main.Position=UDim2.new(startPos.X.Scale,startPos.X.Offset+delta.X,startPos.Y.Scale,startPos.Y.Offset+delta.Y)
        end
        if toggleDragging and (input.UserInputType==Enum.UserInputType.MouseMovement or input.UserInputType==Enum.UserInputType.Touch) then
            local delta=input.Position-toggleDragStart
            if math.abs(delta.X)+math.abs(delta.Y)>5 then toggleMoved=true end
            if toggleMoved then floatingToggle.Position=UDim2.new(toggleStartPos.X.Scale,toggleStartPos.X.Offset+delta.X,toggleStartPos.Y.Scale,toggleStartPos.Y.Offset+delta.Y) end
        end
    end))
    selfWindow.Janitor:Add(UserInputService.InputEnded:Connect(function(input)
        if input.UserInputType==Enum.UserInputType.MouseButton1 or input.UserInputType==Enum.UserInputType.Touch then
            dragging=false; toggleDragging=false
        end
    end))
    local body=make("Frame",{Name="Body",Position=UDim2.fromOffset(0,38),Size=UDim2.new(1,0,1,-38),BackgroundTransparency=1},main); selfWindow.Body=body
    local sidebar=make("Frame",{Name="Sidebar",Size=UDim2.new(0,165,1,0),BackgroundColor3=Color3.fromRGB(13,16,21),BackgroundTransparency=.25,BorderSizePixel=0},body); selfWindow.Sidebar=sidebar
    local sideLine=make("Frame",{BackgroundColor3=Color3.fromRGB(26,31,40),BorderSizePixel=0,Position=UDim2.new(1,-1,0,0),Size=UDim2.new(0,1,1,0)},sidebar)
    local nav=make("ScrollingFrame",{Name="Navigation",BackgroundTransparency=1,BorderSizePixel=0,Position=UDim2.fromOffset(0,0),Size=UDim2.new(1,0,1,-54),CanvasSize=UDim2.new(),ScrollBarThickness=2,ScrollBarImageColor3=theme.Accent},sidebar)
    local navLayout=make("UIListLayout",{Padding=UDim.new(0,2),SortOrder=Enum.SortOrder.LayoutOrder},nav); make("UIPadding",{PaddingTop=UDim.new(0,9),PaddingLeft=UDim.new(0,8),PaddingRight=UDim.new(0,8),PaddingBottom=UDim.new(0,8)},nav); setCanvas(nav,navLayout)
    local footerCard=make("Frame",{Name="UserStatus",Position=UDim2.new(0,8,1,-46),Size=UDim2.new(1,-16,0,38),BackgroundColor3=Color3.fromRGB(18,22,29),BorderSizePixel=0},sidebar); corner(footerCard,8); stroke(footerCard,Color3.fromRGB(29,35,46),0)
    local avatar=make("Frame",{BackgroundColor3=Color3.fromRGB(48,60,81),Position=UDim2.fromOffset(8,7),Size=UDim2.fromOffset(24,24)},footerCard); corner(avatar,12)
    local avatarText=text(avatar,"K",10,Color3.fromRGB(245,247,251),true); avatarText.TextXAlignment=Enum.TextXAlignment.Center; avatarText.Size=UDim2.fromScale(1,1)
    local userName=text(footerCard,config.UserName or "KairoDev",11,theme.Text,true); userName.Position=UDim2.fromOffset(39,4); userName.Size=UDim2.new(1,-44,0,15)
    local userMeta=text(footerCard,"Lifetime  |  UID 0142",9,theme.Muted,false); userMeta.Position=UDim2.fromOffset(39,19); userMeta.Size=UDim2.new(1,-44,0,13)
    local content=make("Frame",{Name="Content",Position=UDim2.new(0,165,0,0),Size=UDim2.new(1,-165,1,0),BackgroundTransparency=1},body); selfWindow.Content=content
    local scale=make("UIScale",{Scale=1},main)
    local compact=false
    local function applyResponsive()
        local camera=workspace.CurrentCamera
        local viewport=camera and camera.ViewportSize or Vector2.new(1280,720)
        compact=UserInputService.TouchEnabled or viewport.X<768
        local rail=compact and 46 or 165
        sidebar.Size=UDim2.new(0,rail,1,0)
        content.Position=UDim2.new(0,rail,0,0); content.Size=UDim2.new(1,-rail,1,0)
        footerCard.Size=compact and UDim2.fromOffset(30,30) or UDim2.new(1,-16,0,38)
        footerCard.Position=compact and UDim2.new(0,8,1,-38) or UDim2.new(0,8,1,-46)
        avatar.Position=compact and UDim2.fromOffset(3,3) or UDim2.fromOffset(8,7)
        userName.Visible=not compact; userMeta.Visible=not compact
        floatingToggle.Size=compact and UDim2.fromOffset(36,36) or UDim2.fromOffset(116,32)
        floatingToggle.Text=compact and "A" or "Aether Toggle"
        floatingToggle.TextXAlignment=compact and Enum.TextXAlignment.Center or Enum.TextXAlignment.Left
        floatingToggle.TextSize=compact and 14 or 11
        toggleDot.Visible=true
        toggleDot.Size=compact and UDim2.fromOffset(5,5) or UDim2.fromOffset(8,8)
        toggleDot.Position=compact and UDim2.fromOffset(25,6) or UDim2.fromOffset(10,12)
        togglePadding.PaddingLeft=UDim.new(0,compact and 0 or 25)
        floatingToggle:FindFirstChildOfClass("UICorner").CornerRadius=UDim.new(0,compact and 18 or 18)
        scale.Scale=compact and math.min(1,(viewport.X-24)/460,(viewport.Y-48)/320) or 1
        search.Size=compact and UDim2.fromOffset(94,24) or UDim2.fromOffset(132,24)
        search.Position=compact and UDim2.new(1,-152,0,7) or UDim2.new(1,-190,0,7)
        search.Text=compact and "Search" or "Search  /  Ctrl K"
        version.Visible=not compact
        brand.Size=UDim2.new(0,compact and 150 or 180,1,0)
        for _,child in ipairs(nav:GetChildren()) do
            if child:IsA("TextLabel") and string.sub(child.Name,1,9)=="NavGroup_" then child.Visible=not compact end
        end
        for _,t in ipairs(selfWindow.Tabs) do
            if t.Nav then
                t.Nav.Text=compact and t.Glyph or ("   "..t.Glyph.."    "..t.Name)
                t.Nav.TextXAlignment=compact and Enum.TextXAlignment.Center or Enum.TextXAlignment.Left
                t.Nav.TextSize=12
                t.Nav.Size=UDim2.new(1,0,0,compact and 40 or 30)
            end
        end
    end
    applyResponsive()
    if workspace.CurrentCamera then
        selfWindow.Janitor:Add(workspace.CurrentCamera:GetPropertyChangedSignal("ViewportSize"):Connect(applyResponsive))
    end
    selfWindow.Janitor:Add(UserInputService:GetPropertyChangedSignal("TouchEnabled"):Connect(applyResponsive))
    local function selectTab(tab)
        for _,t in ipairs(selfWindow.Tabs) do
            t.Page.Visible=(t==tab)
            tween(t.Nav,.12,{BackgroundColor3=t==tab and Color3.fromRGB(21,26,35) or Color3.fromRGB(13,16,21),TextColor3=t==tab and theme.Text or Color3.fromRGB(136,148,168)})
            if t.Indicator then t.Indicator.Visible=(t==tab) end
        end
        selfWindow.ActiveTab=tab
    end
    local searchOverlay=make("Frame",{Name="CommandPaletteBackdrop",Visible=false,BackgroundColor3=Color3.new(0,0,0),BackgroundTransparency=.42,Size=UDim2.fromScale(1,1),ZIndex=40},main)
    local searchPanel=make("Frame",{Name="CommandPalette",AnchorPoint=Vector2.new(.5,0),Position=UDim2.new(.5,0,0,42),Size=UDim2.fromOffset(340,210),BackgroundColor3=Color3.fromRGB(16,20,28),ZIndex=41},searchOverlay); corner(searchPanel,10); stroke(searchPanel,Color3.fromRGB(40,50,66),.05)
    local searchInput=make("TextBox",{Position=UDim2.fromOffset(10,10),Size=UDim2.new(1,-20,0,30),BackgroundColor3=Color3.fromRGB(11,14,20),TextColor3=theme.Text,PlaceholderColor3=theme.Muted,PlaceholderText="Search flags, tabs or settings...",Text="",ClearTextOnFocus=false,Font=Enum.Font.Gotham,TextSize=11,ZIndex=42},searchPanel); corner(searchInput,6); stroke(searchInput,theme.Border,.15)
    local searchResults=make("ScrollingFrame",{Position=UDim2.fromOffset(8,48),Size=UDim2.new(1,-16,1,-56),BackgroundTransparency=1,BorderSizePixel=0,CanvasSize=UDim2.new(),ScrollBarThickness=2,ZIndex=42},searchPanel)
    local searchLayout=make("UIListLayout",{Padding=UDim.new(0,3),SortOrder=Enum.SortOrder.LayoutOrder},searchResults)
    setCanvas(searchResults,searchLayout)
    local function refreshSearch()
        for _,child in ipairs(searchResults:GetChildren()) do if child:IsA("TextButton") then child:Destroy() end end
        local query=string.lower(searchInput.Text)
        for _,tab in ipairs(selfWindow.Tabs) do
            if query=="" or string.find(string.lower(tab.Name),query,1,true) then
                local result=button(searchResults,"Open "..tab.Name.."     >     Navigation",theme,28)
                result.TextXAlignment=Enum.TextXAlignment.Left; result.TextSize=11; result.ZIndex=43
                result.MouseButton1Click:Connect(function() selectTab(tab); searchOverlay.Visible=false end)
            end
        end
    end
    searchInput:GetPropertyChangedSignal("Text"):Connect(refreshSearch)
    search.MouseButton1Click:Connect(function() searchInput.Text=""; refreshSearch(); searchOverlay.Visible=true; searchInput:CaptureFocus() end)
    searchOverlay.InputBegan:Connect(function(input) if input.UserInputType==Enum.UserInputType.MouseButton1 then searchOverlay.Visible=false end end)
    selfWindow.Janitor:Add(UserInputService.InputBegan:Connect(function(input,processed)
        if not processed and input.KeyCode==Enum.KeyCode.Escape then searchOverlay.Visible=false end
    end))
    function selfWindow:CreateTab(tabConfig)
        tabConfig=tabConfig or {}
        local page=make("ScrollingFrame",{Name="Page_"..(tabConfig.Name or "Tab"),Visible=#selfWindow.Tabs==0,BackgroundTransparency=1,BorderSizePixel=0,Size=UDim2.fromScale(1,1),CanvasSize=UDim2.new(),ScrollBarThickness=3,ScrollBarImageColor3=theme.Accent},content)
        local layout=make("UIListLayout",{Padding=UDim.new(0,6),SortOrder=Enum.SortOrder.LayoutOrder},page); make("UIPadding",{PaddingTop=UDim.new(0,12),PaddingBottom=UDim.new(0,12),PaddingLeft=UDim.new(0,14),PaddingRight=UDim.new(0,14)},page); setCanvas(page,layout)
        local tabName=tabConfig.Name or "Tab"
        local group=({Dashboard="MAIN",Combat="FEATURES",Visuals="FEATURES",Components="FEATURES",Showcase="FEATURES",Configs="SYSTEM",Settings="SYSTEM",Notifications="SYSTEM",Modals="SYSTEM"})[tabName]
        local groupOrder={MAIN=0,FEATURES=10,SYSTEM=20}
        local tabOrder={Dashboard=1,Combat=11,Visuals=12,Components=13,Showcase=13,Configs=21,Settings=22,Notifications=23,Modals=24}
        if group and not selfWindow.NavGroups[group] then
            local sectionLabel=text(nav,group,10,Color3.fromRGB(92,103,121),true); sectionLabel.Name="NavGroup_"..group; sectionLabel.Size=UDim2.new(1,0,0,20); sectionLabel.TextXAlignment=Enum.TextXAlignment.Left; sectionLabel.LayoutOrder=groupOrder[group] or (#selfWindow.Tabs*2)
            selfWindow.NavGroups[group]=true
        end
        local glyph=tabConfig.Icon or ({Dashboard="D",Combat="C",Visuals="V",Components="UI",Showcase="S",Configs="CF",Settings="ST",Notifications="N",Modals="M"})[tabName] or "A"
        local navButton=button(nav,"   "..glyph.."    "..tabName,theme,30); navButton.Name="Nav_"..tabName; navButton.TextXAlignment=Enum.TextXAlignment.Left; navButton.TextTruncate=Enum.TextTruncate.AtEnd; navButton.TextSize=12; navButton.LayoutOrder=tabOrder[tabName] or (30+#selfWindow.Tabs*2)
        local activeMark=make("Frame",{Name="ActiveIndicator",BackgroundColor3=theme.Accent,BorderSizePixel=0,Position=UDim2.fromOffset(0,7),Size=UDim2.fromOffset(3,16),Visible=#selfWindow.Tabs==0},navButton); corner(activeMark,2)
        local tab={Name=tabName,Page=page,Nav=navButton,Indicator=activeMark,Glyph=glyph,Window=selfWindow}
        table.insert(selfWindow.Tabs,tab)
        applyResponsive()
        navButton.MouseButton1Click:Connect(function() selectTab(tab) end)
        function tab:CreateSection(name)
            local section={Tab=self,Name=name or "Section",Window=selfWindow,Parent=page}
            local header=text(page,string.upper(section.Name),10,theme.Muted,true); header.Size=UDim2.new(1,0,0,18)
            local container=make("Frame",{BackgroundTransparency=1,Size=UDim2.new(1,0,0,0)},page)
            local ll=make("UIListLayout",{Padding=UDim.new(0,7),SortOrder=Enum.SortOrder.LayoutOrder},container)
            ll:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function() container.Size=UDim2.new(1,0,0,ll.AbsoluteContentSize.Y) end)
            section.Container=container
            local function row(name,desc,height)
                local f=card(container,theme,height or 54); f.BackgroundColor3=Color3.fromRGB(19,23,30); f.BackgroundTransparency=.15
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
                local b=button(f,tostring(current or "Select...").."  v",theme,28); b.Size=UDim2.fromOffset(140,28); b.Position=UDim2.new(1,-150,.5,-14)
                local popup=make("Frame",{Visible=false,Position=UDim2.new(1,-150,1,2),Size=UDim2.fromOffset(140,0),BackgroundColor3=theme.Elevated,ZIndex=8},f); corner(popup,7); stroke(popup,theme.Border,.1)
                local pl=make("UIListLayout",{SortOrder=Enum.SortOrder.LayoutOrder},popup)
                local function refresh() for _,v in ipairs(popup:GetChildren()) do if v:IsA("TextButton") then v:Destroy() end end
                    for _,option in ipairs(c.Options or {}) do local ob=make("TextButton",{Text=tostring(option),Font=Enum.Font.Gotham,TextSize=11,TextColor3=theme.Text,BackgroundTransparency=1,Size=UDim2.new(1,0,0,27),ZIndex=9},popup); ob.MouseButton1Click:Connect(function() current=option; b.Text=tostring(option).."  v"; popup.Visible=false; selfWindow.Values[c.Name or "Dropdown"]=current; safeCallback(c.Callback,current) end) end
                    popup.Size=UDim2.fromOffset(140,math.min(#(c.Options or {})*27,135))
                end
                refresh(); b.MouseButton1Click:Connect(function() popup.Visible=not popup.Visible end)
                return {Instance=f,GetValue=function() return current end,SetValue=function(v) current=v; b.Text=tostring(v).."  v"; safeCallback(c.Callback,v) end}
            end
            function section:CreateMultiDropdown(c)
                c=c or {}; local selected={}; for _,v in ipairs(c.Default or {}) do selected[v]=true end
                local f=row(c.Name,c.Description,64); local b=button(f,"Choose options...  v",theme,28); b.Position=UDim2.new(1,-150,.5,-14); b.Size=UDim2.fromOffset(140,28)
                local popup=make("Frame",{Visible=false,Position=UDim2.new(1,-150,1,2),Size=UDim2.fromOffset(140,0),BackgroundColor3=theme.Elevated,ZIndex=8},f); corner(popup,7)
                for _,option in ipairs(c.Options or {}) do local ob=make("TextButton",{Text=(selected[option] and "[x] " or "[ ] ")..tostring(option),Font=Enum.Font.Gotham,TextSize=11,TextColor3=theme.Text,BackgroundTransparency=1,Size=UDim2.new(1,0,0,27),ZIndex=9},popup); ob.MouseButton1Click:Connect(function() selected[option]=not selected[option]; ob.Text=(selected[option] and "[x] " or "[ ] ")..tostring(option); local values={}; for _,v in ipairs(c.Options) do if selected[v] then table.insert(values,v) end end; b.Text=#values.." selected  v"; safeCallback(c.Callback,values) end) end
                popup.Size=UDim2.fromOffset(140,math.min(#(c.Options or {})*27,135)); b.MouseButton1Click:Connect(function() popup.Visible=not popup.Visible end)
                return {Instance=f,GetValue=function() local a={}; for _,v in ipairs(c.Options or {}) do if selected[v] then table.insert(a,v) end end; return a end}
            end
            function section:CreateTextbox(c)
                c=c or {}; local f=row(c.Name,c.Description,62); local input=make("TextBox",{Position=UDim2.new(0,10,1,-34),Size=UDim2.new(1,-20,0,26),BackgroundColor3=theme.Elevated,TextColor3=theme.Text,PlaceholderColor3=theme.Muted,PlaceholderText=c.Placeholder or "Enter text...",Text=c.Default or "",Font=Enum.Font.Gotham,TextSize=11,ClearTextOnFocus=false},f); corner(input,6); stroke(input,theme.Border,.2)
                input.FocusLost:Connect(function(enter) selfWindow.Values[c.Name or "Textbox"]=input.Text; safeCallback(c.Callback,input.Text,enter) end)
                return {Instance=f,Input=input,GetValue=function() return input.Text end,SetValue=function(v) input.Text=tostring(v) end}
            end
            function section:CreateKeybind(c)
                c=c or {}; local f=row(c.Name,c.Description,48); local key=c.Default or Enum.KeyCode.RightShift; local listening=false
                local b=button(f,key.Name,theme,28); b.Size=UDim2.fromOffset(90,28); b.Position=UDim2.new(1,-100,.5,-14)
                b.MouseButton1Click:Connect(function() listening=true; b.Text="Press key..." end)
                local conn=UserInputService.InputBegan:Connect(function(input,processed) if listening and not processed and input.UserInputType==Enum.UserInputType.Keyboard then key=input.KeyCode; listening=false; b.Text=key.Name; safeCallback(c.Callback,key) elseif not processed and input.KeyCode==key then safeCallback(c.Callback,key) end end); selfWindow.Janitor:Add(conn)
                return {Instance=f,GetValue=function() return key end}
            end
            function section:CreateColorPicker(c)
                c=c or {}; local f=row(c.Name,c.Description,48); local color=c.Default or theme.Accent
                local swatch=button(f,"",theme,24); swatch.Size=UDim2.fromOffset(24,16); swatch.Position=UDim2.new(1,-36,.5,-8); swatch.BackgroundColor3=color
                local palette=make("Frame",{Visible=false,Position=UDim2.new(1,-148,1,2),Size=UDim2.fromOffset(140,42),BackgroundColor3=Color3.fromRGB(17,21,29),ZIndex=18},f); corner(palette,8); stroke(palette,Color3.fromRGB(40,49,64),.05)
                local colors={Color3.fromRGB(94,139,255),Color3.fromRGB(52,211,153),Color3.fromRGB(244,63,94),Color3.fromRGB(251,191,36),Color3.fromRGB(167,139,250)}
                for index,preset in ipairs(colors) do
                    local chip=make("TextButton",{AutoButtonColor=false,Text="",BackgroundColor3=preset,Position=UDim2.fromOffset(8+(index-1)*25,9),Size=UDim2.fromOffset(20,20),ZIndex=19},palette); corner(chip,5); stroke(chip,Color3.fromRGB(255,255,255),.7)
                    chip.MouseButton1Click:Connect(function() color=preset; swatch.BackgroundColor3=color; palette.Visible=false; selfWindow.Values[c.Name or "ColorPicker"]=color; safeCallback(c.Callback,color) end)
                end
                swatch.MouseButton1Click:Connect(function() palette.Visible=not palette.Visible end)
                return {Instance=f,GetValue=function() return color end,SetValue=function(v) if typeof(v)=="Color3" then color=v; swatch.BackgroundColor3=v; safeCallback(c.Callback,v) end end}
            end
            function section:CreateLabel(c) c=type(c)=="string" and {Text=c} or (c or {}); local f=card(container,theme,30); local l=text(f,c.Text or c.Name or "Label",12,theme.Text,false); l.Position=UDim2.fromOffset(10,0); return {Instance=f,SetText=function(v) l.Text=tostring(v) end} end
            function section:CreateParagraph(c) c=c or {}; local f=card(container,theme,64); local t=text(f,c.Title or c.Name or "Information",12,theme.Text,true); t.Position=UDim2.fromOffset(10,5); local d=text(f,c.Content or c.Description or "",10,theme.Muted,false); d.Position=UDim2.fromOffset(10,25); d.Size=UDim2.new(1,-20,0,34); d.TextWrapped=true; d.TextYAlignment=Enum.TextYAlignment.Top; return {Instance=f} end
            function section:CreateDivider() local f=make("Frame",{BackgroundColor3=theme.Border,BorderSizePixel=0,Size=UDim2.new(1,0,0,1)},container); return {Instance=f} end
            function section:CreateProgressBar(c) c=c or {}; local f=row(c.Name,c.Description,54); local track=make("Frame",{Position=UDim2.new(0,10,1,-17),Size=UDim2.new(1,-20,0,6),BackgroundColor3=theme.Border},f); corner(track,4); local fill=make("Frame",{Size=UDim2.new(math.clamp(c.Value or 0,0,100)/100,0,1,0),BackgroundColor3=theme.Accent},track); corner(fill,4); return {Instance=f,SetValue=function(_,v) fill.Size=UDim2.new(math.clamp(v,0,100)/100,0,1,0); safeCallback(c.Callback,v) end} end
            function section:CreateLoadingIndicator(c) c=c or {}; local f=row(c.Name or "Loading",c.Description,42); local spin=text(f,"O",20,theme.Accent,true); spin.Position=UDim2.new(1,-34,0,4); spin.Size=UDim2.fromOffset(24,28); local active=true; task.spawn(function() while active and spin.Parent do spin.Rotation=(spin.Rotation+8)%360; RunService.Heartbeat:Wait() end end); return {Instance=f,Stop=function() active=false; f:Destroy() end} end
            function section:CreateTooltip(c)
                c=c or {}; local f=row(c.Name or "Hover for details",c.Description,42)
                local trigger=button(f,"?",theme,22); trigger.Size=UDim2.fromOffset(22,22); trigger.Position=UDim2.new(1,-32,.5,-11); trigger.TextSize=11
                local tip=make("Frame",{Visible=false,Position=UDim2.new(1,-190,0,4),Size=UDim2.fromOffset(180,32),BackgroundColor3=Color3.fromRGB(17,21,29),ZIndex=20},f); corner(tip,6); stroke(tip,theme.Border,.05)
                local tipText=text(tip,c.Tooltip or "Tooltip",10,theme.Text,false); tipText.Position=UDim2.fromOffset(8,2); tipText.Size=UDim2.new(1,-16,1,-4); tipText.TextWrapped=true; tipText.ZIndex=21
                trigger.MouseEnter:Connect(function() tip.Visible=true end); trigger.MouseLeave:Connect(function() tip.Visible=false end)
                return {Instance=f}
            end
            function section:CreateContextMenu(c)
                c=c or {}; local f=row(c.Name or "Context menu",c.Description,42)
                local b=button(f,"Open menu",theme,26); b.Size=UDim2.fromOffset(100,26); b.Position=UDim2.new(1,-110,.5,-13)
                local popup=make("Frame",{Visible=false,Position=UDim2.new(1,-184,1,2),Size=UDim2.fromOffset(175,0),BackgroundColor3=Color3.fromRGB(17,21,29),ZIndex=20},f); corner(popup,8); stroke(popup,Color3.fromRGB(36,44,59),.05)
                local layout=make("UIListLayout",{Padding=UDim.new(0,2),SortOrder=Enum.SortOrder.LayoutOrder},popup); make("UIPadding",{PaddingTop=UDim.new(0,4),PaddingBottom=UDim.new(0,4),PaddingLeft=UDim.new(0,4),PaddingRight=UDim.new(0,4)},popup)
                for _,option in ipairs(c.Options or {"Copy","Reset"}) do
                    local item=make("TextButton",{AutoButtonColor=false,Text=tostring(option),TextXAlignment=Enum.TextXAlignment.Left,Font=Enum.Font.Gotham,TextSize=11,TextColor3=theme.Text,BackgroundColor3=Color3.fromRGB(17,21,29),Size=UDim2.new(1,0,0,26),ZIndex=21},popup); corner(item,5)
                    item.MouseEnter:Connect(function() item.BackgroundColor3=Color3.fromRGB(27,33,45) end); item.MouseLeave:Connect(function() item.BackgroundColor3=Color3.fromRGB(17,21,29) end)
                    item.MouseButton1Click:Connect(function() popup.Visible=false; safeCallback(c.Callback,option); selfWindow:Notify({Title="Context menu",Content=tostring(option)}) end)
                end
                popup.Size=UDim2.fromOffset(175,math.min(#(c.Options or {"Copy","Reset"})*28+8,140))
                b.MouseButton1Click:Connect(function() popup.Visible=not popup.Visible end)
                b.MouseButton2Click:Connect(function() popup.Visible=not popup.Visible end)
                return {Instance=f}
            end
            function section:CreateModal(c) c=c or {}; local f=row(c.Name or "Modal",c.Description,42); local b=button(f,"Open modal",theme,28); b.Size=UDim2.fromOffset(100,28); b.Position=UDim2.new(1,-110,.5,-14); b.MouseButton1Click:Connect(function() selfWindow:ShowDialog(c) end); return {Instance=f} end
            function section:CreateSearchBar(c) c=c or {}; local f=row(c.Name or "Search",c.Description,58); local input=make("TextBox",{Position=UDim2.fromOffset(10,27),Size=UDim2.new(1,-20,0,24),BackgroundColor3=theme.Elevated,TextColor3=theme.Text,PlaceholderText=c.Placeholder or "Search...",Text="",Font=Enum.Font.Gotham,TextSize=11},f); corner(input,6); input:GetPropertyChangedSignal("Text"):Connect(function() safeCallback(c.Callback,input.Text) end); return {Instance=f,Input=input} end
            function section:CreateConfigurationManager(c) c=c or {}; local f=row(c.Name or "Configurations",c.Description,58); local b=button(f,"Save current",theme,28); b.Size=UDim2.fromOffset(110,28); b.Position=UDim2.new(1,-120,.5,-14); b.MouseButton1Click:Connect(function() selfWindow:SaveConfiguration(c.ConfigName or "Default"); selfWindow:Notify({Title="Configuration saved",Content=c.ConfigName or "Default"}) end); return {Instance=f} end
            function section:CreateThemeManager() local f=row("Theme Manager","Switch the active interface palette.",52); local b=button(f,"Cycle theme",theme,28); b.Size=UDim2.fromOffset(110,28); b.Position=UDim2.new(1,-120,.5,-14); b.MouseButton1Click:Connect(function() local names={"Dark","Midnight","Light"}; local index=table.find(names,selfWindow.ThemeName) or 1; selfWindow:SetTheme(names[index%#names+1]) end); return {Instance=f} end
            return section
        end
        if #selfWindow.Tabs==1 then selfWindow.ActiveTab=tab end
        return tab
    end
    function selfWindow:ShowDialog(c)
        c=c or {}; local overlay=make("Frame",{Name="ModalBackdrop",BackgroundColor3=Color3.new(0,0,0),BackgroundTransparency=.42,Size=UDim2.fromScale(1,1),ZIndex=45},main)
        local panel=make("Frame",{AnchorPoint=Vector2.new(.5,.5),Position=UDim2.fromScale(.5,.5),Size=UDim2.fromOffset(310,148),BackgroundColor3=Color3.fromRGB(17,21,29),ZIndex=46},overlay); corner(panel,10); stroke(panel,Color3.fromRGB(39,48,64),.05)
        local t=text(panel,c.Title or "Confirm action",13,theme.Text,true); t.Position=UDim2.fromOffset(14,12); t.Size=UDim2.new(1,-28,0,24); t.ZIndex=47
        local d=text(panel,c.Content or c.Description or "Are you sure you want to continue?",11,theme.Muted,false); d.Position=UDim2.fromOffset(14,42); d.Size=UDim2.new(1,-28,0,50); d.TextWrapped=true; d.ZIndex=47
        local cancel=button(panel,c.CancelText or "Cancel",theme,28); cancel.Position=UDim2.new(0,14,1,-42); cancel.Size=UDim2.new(.5,-20,0,28); cancel.ZIndex=47
        local confirm=button(panel,c.ConfirmText or "Confirm",theme,28); confirm.Position=UDim2.new(.5,6,1,-42); confirm.Size=UDim2.new(.5,-20,0,28); confirm.BackgroundColor3=theme.Accent; confirm.ZIndex=47
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
