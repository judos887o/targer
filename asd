local RunService = game:GetService("RunService")
local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")
local VirtualUser = game:GetService("VirtualUser")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local VirtualInputManager = game:GetService("VirtualInputManager")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local SoundService = game:GetService("SoundService")
local CoreGui = game:GetService("CoreGui")

local MainEvent = ReplicatedStorage:FindFirstChild("MainEvent") or ReplicatedStorage:FindFirstChild("MAINEVENT")
if not MainEvent then
    MainEvent = ReplicatedStorage:WaitForChild("MainEvent", 1)
end

local lp = Players.LocalPlayer
local Shared = getgenv().SchmecktHubPC or {}
getgenv().SchmecktHubPC = Shared
local key = "TargetScript"

local IS_MOBILE = Shared.Platform == "Mobile" or UserInputService.TouchEnabled
local SCALE = IS_MOBILE and (1 / 2.2) or 1
local function s(v) return math.floor(v * SCALE) end

local CLICK_SOUND_ID = "rbxassetid://100809160609628"
local INTRO_LOGO_ASSET = "rbxassetid://121759217057084"

local clickSound = SoundService:FindFirstChild("SchmecktClickSound")
if not clickSound then
    clickSound = Instance.new("Sound")
    clickSound.Name = "SchmecktClickSound"
    clickSound.SoundId = CLICK_SOUND_ID
    clickSound.Volume = 0.5
    clickSound.Parent = SoundService
end

local function playClick()
    task.spawn(function() pcall(function() clickSound:Stop() clickSound:Play() end) end)
end

if Shared.Connections and Shared.Connections[key] then
    for _, c in pairs(Shared.Connections[key]) do pcall(function() c:Disconnect() end) end
end
Shared.Connections = Shared.Connections or {}
Shared.Connections[key] = {}

if lp:WaitForChild("PlayerGui"):FindFirstChild("TargetGui") then
    lp.PlayerGui.TargetGui:Destroy()
end

Shared.Fling = Shared.Fling or false
Shared.OPKill = Shared.OPKill or false
Shared.HighlightTarget = Shared.HighlightTarget or false
Shared.ViewTarget = Shared.ViewTarget or false
Shared.AutoKatanaKill = Shared.AutoKatanaKill or false
Shared.TargetUsername = Shared.TargetUsername or nil

local COL = {
    BgMain = Color3.fromRGB(14, 10, 10),
    StrokeMain = Color3.fromRGB(150, 30, 30),
    Div = Color3.fromRGB(60, 15, 15),
    RowBg = Color3.fromRGB(20, 14, 14),
    RowStroke = Color3.fromRGB(50, 20, 20),
    TextOn = Color3.fromRGB(255, 255, 255),
    TextOff = Color3.fromRGB(160, 120, 120),
    ToggleBgOn = Color3.fromRGB(200, 40, 40),
    ToggleBgOff = Color3.fromRGB(40, 20, 20),
    Dot = Color3.fromRGB(255, 255, 255),
    InputBg = Color3.fromRGB(30, 15, 15),
    InputFocus = Color3.fromRGB(255, 60, 60),
    Danger = Color3.fromRGB(255, 50, 50),
    Success = Color3.fromRGB(50, 255, 120),
    BtnActive = Color3.fromRGB(150, 30, 30)
}

local function corner(inst, px)
    local c = Instance.new("UICorner")
    c.CornerRadius = UDim.new(0, px or s(10))
    c.Parent = inst
    return c
end

local function strokeUI(inst, color, thickness, transparency)
    local st = Instance.new("UIStroke")
    st.Color = color
    st.Thickness = thickness or 1
    st.Transparency = transparency or 0
    st.Parent = inst
    return st
end

local highlight = nil
local flingActive = false
local flingLoop = nil
local katanaLoop = nil
local defaultCollisions = setmetatable({}, {__mode = "k"})
local noclipActive = false
local opAngle = 0
local lastReloadTime = 0
local lastHighlightTarget = nil

local katanaPatterns = {
    function(tHRP, time) return tHRP.Position + Vector3.new(math.sin(time*47)*math.random(3,8),-3.2+math.cos(time*31)*math.random(1,5),math.sin(time*53)*math.random(3,8)) end,
    function(tHRP, time) return tHRP.Position + Vector3.new(math.random(-10,10),-3.2+math.random(-3,7),math.random(-10,10)) end,
    function(tHRP, time) local a=time*math.random(5,25) local r=math.random(1,6) return tHRP.Position+Vector3.new(math.cos(a)*r,-3.2+math.sin(time*math.random(3,9))*2,math.sin(a)*r) end,
    function(tHRP, time) return tHRP.Position+Vector3.new(math.sin(time*17)*math.cos(time*13)*5,-3.2+math.sin(time*19)*math.random(1,4),math.cos(time*23)*math.sin(time*11)*5) end
}

local flingPatterns = {
    function(tHRP, time) return tHRP.Position+Vector3.new(math.sin(time*47)*math.random(3,8),-3.2+math.cos(time*31)*math.random(1,5),math.sin(time*53)*math.random(3,8)) end,
    function(tHRP, time) return tHRP.Position+Vector3.new(math.random(-10,10),-3.2+math.random(-3,7),math.random(-10,10)) end,
    function(tHRP, time) local a=time*math.random(5,25) local r=math.random(1,6) return tHRP.Position+Vector3.new(math.cos(a)*r,-3.2+math.sin(time*math.random(3,9))*2,math.sin(a)*r) end
}

local function getUnpredictableVelocity(time)
    local p={Vector3.new(math.random(-150000,150000),math.random(80000,150000),math.random(-150000,150000)),Vector3.new(math.sin(time*7)*120000,100000+math.cos(time*5)*50000,math.cos(time*11)*120000),Vector3.new(math.random(-200000,200000),math.random(100000,200000),math.random(-200000,200000))}
    return p[math.random(1,#p)]
end

local function getKatanaVelocity(time)
    return Vector3.new(math.sin(time*math.random(5,15))*math.random(50,150),math.random(30,80),math.cos(time*math.random(5,15))*math.random(50,150))
end

local function getTarget()
    if not Shared.TargetUsername then return nil end
    return Players:FindFirstChild(Shared.TargetUsername)
end

local function getTargetHRP()
    local t=getTarget() if not t then return nil end
    local c=t.Character if not c then return nil end
    return c:FindFirstChild("HumanoidRootPart")
end

local function getLocalHRP()
    if not lp then return nil end
    local c=lp.Character if not c then return nil end
    return c:FindFirstChild("HumanoidRootPart")
end

local function applyNoclipState(char, state)
    for _,p in ipairs(char:GetDescendants()) do
        if p:IsA("BasePart") then
            if state then
                if defaultCollisions[p]==nil then defaultCollisions[p]=p.CanCollide end
                p.CanCollide=false
            else
                local def=defaultCollisions[p]
                if def~=nil then p.CanCollide=def end
            end
        end
    end
end

local function updateHighlight()
    if not Shared.HighlightTarget then
        if highlight then highlight:Destroy() highlight=nil end
        lastHighlightTarget=nil
        return
    end
    local t=getTarget() local c=t and t.Character
    if not c then
        if highlight then highlight:Destroy() highlight=nil end
        lastHighlightTarget=nil
        return
    end
    if lastHighlightTarget==c and highlight and highlight.Parent then return end
    if highlight then highlight:Destroy() end
    highlight=Instance.new("Highlight")
    highlight.FillColor=Color3.fromRGB(255,70,70)
    highlight.OutlineColor=Color3.new(1,1,1)
    highlight.FillTransparency=0.5
    highlight.OutlineTransparency=0
    highlight.DepthMode=Enum.HighlightDepthMode.AlwaysOnTop
    highlight.Adornee=c
    highlight.Parent=Workspace
    lastHighlightTarget=c
end

local function getKatanaTool(char)
    for _,t in ipairs(char:GetChildren()) do if t:IsA("Tool") and string.lower(t.Name):find("katana") then return t end end
    for _,t in ipairs(lp.Backpack:GetChildren()) do if t:IsA("Tool") and string.lower(t.Name):find("katana") then return t end end
    return nil
end

local function fireTouchFast(tool, targetChar)
    if not firetouchinterest then return end
    local handle=tool and tool:FindFirstChild("Handle")
    if not handle then return end
    local tHRP=targetChar:FindFirstChild("HumanoidRootPart")
    if tHRP then pcall(firetouchinterest,handle,tHRP,0) pcall(firetouchinterest,handle,tHRP,1) end
end

local function spectateSelf()
    local h=lp.Character and lp.Character:FindFirstChildOfClass("Humanoid")
    if h then Workspace.CurrentCamera.CameraSubject=h end
end

-- Verbessertes Spectate mit Fallback, falls Target nicht im Server ist
local function spectateTarget()
    local t=getTarget()
    if t and t.Character then 
        local h=t.Character:FindFirstChildOfClass("Humanoid") 
        if h then 
            Workspace.CurrentCamera.CameraSubject=h 
            return
        end 
    end
    spectateSelf() -- Fallback auf sich selbst
end

local function startKatanaLoop()
    if katanaLoop then return end
    katanaLoop=task.spawn(function()
        while Shared.AutoKatanaKill do
            local char=lp.Character local hrp=char and char:FindFirstChild("HumanoidRootPart") local hum=char and char:FindFirstChildOfClass("Humanoid")
            local target=getTarget() local tChar=target and target.Character local tHRP=tChar and tChar:FindFirstChild("HumanoidRootPart") local tHum=tChar and tChar:FindFirstChildOfClass("Humanoid")
            if hrp and hum and tHRP and tHum and tHum.Health>0 then
                spectateTarget()
                local tool=getKatanaTool(char)
                if tool then
                    if tool.Parent~=char then hum:EquipTool(tool) end
                    local time=tick() local pattern=katanaPatterns[math.random(1,#katanaPatterns)] local position=pattern(tHRP,time) local velocity=getKatanaVelocity(time)
                    hrp.CFrame=CFrame.new(position,tHRP.Position) hrp.Velocity=velocity hrp.RotVelocity=Vector3.new(math.random(-500,500),math.random(-500,500),math.random(-500,500))
                    pcall(function() tool:Activate() end) fireTouchFast(tool,tChar)
                    pcall(function() VirtualUser:CaptureController() VirtualUser:Button1Down(Vector2.new(0,0)) end)
                    task.wait(0.02)
                    pcall(function() VirtualUser:Button1Up(Vector2.new(0,0)) end)
                end
            end
            task.wait(0.03)
        end
    end)
end

local function stopKatanaLoop()
    if katanaLoop then task.cancel(katanaLoop) katanaLoop=nil end
    spectateSelf()
    if lp.Character then local hrp=lp.Character:FindFirstChild("HumanoidRootPart") if hrp then hrp.Velocity=Vector3.zero hrp.RotVelocity=Vector3.zero end end
end

local function startFling()
    if flingLoop then return end
    flingLoop=task.spawn(function()
        while Shared.Fling do
            local char=lp.Character local hrp=char and char:FindFirstChild("HumanoidRootPart")
            local target=getTarget() local tHRP=target and target.Character and target.Character:FindFirstChild("HumanoidRootPart")
            if hrp and tHRP then
                spectateTarget()
                local time=tick() local pattern=flingPatterns[math.random(1,#flingPatterns)] local position=pattern(tHRP,time) local velocity=getUnpredictableVelocity(time)
                hrp.CFrame=CFrame.new(position,tHRP.Position) hrp.Velocity=velocity hrp.RotVelocity=Vector3.new(math.random(-10000,10000),math.random(-10000,10000),math.random(-10000,10000))
            end
            task.wait()
        end
    end)
end

local function stopFling()
    if flingLoop then task.cancel(flingLoop) flingLoop=nil end
    spectateSelf()
    if lp.Character then local hrp=lp.Character:FindFirstChild("HumanoidRootPart") if hrp then hrp.Velocity=Vector3.zero hrp.RotVelocity=Vector3.zero end end
end

local function performOpKill(dt)
    local target=getTarget() if not target or not target.Character then return end
    local tHRP=target.Character:FindFirstChild("HumanoidRootPart") local tHum=target.Character:FindFirstChild("Humanoid") local myHRP=getLocalHRP()
    if tHRP and myHRP and tHum then
        spectateTarget()
        opAngle=opAngle+(25*dt)
        local radius=6.5 local height=3.5
        local offsetX=math.cos(opAngle)*radius local offsetZ=math.sin(opAngle)*radius
        local jitter=Vector3.new(math.random()-0.5,math.random()-0.5,math.random()-0.5)*2
        local newPos=tHRP.Position+Vector3.new(offsetX,height,offsetZ)+jitter
        myHRP.CFrame=CFrame.lookAt(newPos,tHRP.Position) myHRP.Velocity=Vector3.zero myHRP.RotVelocity=Vector3.zero
        local tool=lp.Character:FindFirstChildOfClass("Tool")
        if tool then
            local ammo=tool:FindFirstChild("Ammo") or tool:FindFirstChild("AMMO")
            if ammo and tonumber(ammo.Value)<=0 then
                if (tick()-lastReloadTime)>2 then
                    lastReloadTime=tick()
                    task.spawn(function() VirtualInputManager:SendKeyEvent(true,Enum.KeyCode.R,false,game) task.wait(0.1) VirtualInputManager:SendKeyEvent(false,Enum.KeyCode.R,false,game) end)
                end
                return
            end
            tool:Activate()
        else
            local bpTool=lp.Backpack:FindFirstChildOfClass("Tool")
            if bpTool and lp.Character:FindFirstChild("Humanoid") then lp.Character.Humanoid:EquipTool(bpTool) end
        end
        if MainEvent then MainEvent:FireServer("Stomp") end
    end
end

local TargetGui = Instance.new("ScreenGui")
TargetGui.Name = "TargetGui"
TargetGui.ResetOnSpawn = false
TargetGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
TargetGui.Parent = lp:WaitForChild("PlayerGui")

local ROW_H = s(36)
local GAP = s(6)
local headerH = s(40)
local inputH = s(36)
local rowCount = 6
local contentPad = s(10)
local contentInner = inputH + GAP + (ROW_H * rowCount) + (GAP * (rowCount - 1)) + contentPad * 2
local panelW = s(250)
local panelH = headerH + contentInner + s(2)

local MainFrame = Instance.new("Frame")
MainFrame.Name = "MainFrame"
MainFrame.Size = UDim2.new(0, panelW, 0, panelH)
MainFrame.Position = UDim2.new(1, -s(290), 1, -panelH - s(20))
MainFrame.BackgroundColor3 = COL.BgMain
MainFrame.BorderSizePixel = 0
MainFrame.Active = true
MainFrame.Draggable = true
MainFrame.Parent = TargetGui
corner(MainFrame, s(8))
strokeUI(MainFrame, COL.StrokeMain, 1, 0)

local PanelTitle = Instance.new("TextLabel", MainFrame)
PanelTitle.Size = UDim2.new(1, -s(20), 0, s(40))
PanelTitle.Position = UDim2.new(0, s(16), 0, 0)
PanelTitle.BackgroundTransparency = 1
PanelTitle.Text = "Target Panel"
PanelTitle.TextColor3 = COL.TextOn
PanelTitle.Font = Enum.Font.GothamBold
PanelTitle.TextSize = s(14)
PanelTitle.TextXAlignment = Enum.TextXAlignment.Left

local PanelDiv = Instance.new("Frame", MainFrame)
PanelDiv.Size = UDim2.new(1, 0, 0, math.max(1, s(1)))
PanelDiv.Position = UDim2.new(0, 0, 0, s(40))
PanelDiv.BackgroundColor3 = COL.Div
PanelDiv.BorderSizePixel = 0

local InnerContainer = Instance.new("Frame", MainFrame)
InnerContainer.Size = UDim2.new(1, 0, 1, -s(41))
InnerContainer.Position = UDim2.new(0, 0, 0, s(41))
InnerContainer.BackgroundTransparency = 1
InnerContainer.Parent = MainFrame

local ListLayout = Instance.new("UIListLayout", InnerContainer)
ListLayout.SortOrder = Enum.SortOrder.LayoutOrder
ListLayout.Padding = UDim.new(0, s(6))
ListLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
Instance.new("UIPadding", InnerContainer).PaddingTop = UDim.new(0, s(10))

local InputSection = Instance.new("Frame", InnerContainer)
InputSection.Size = UDim2.new(0.9, 0, 0, inputH)
InputSection.BackgroundColor3 = COL.InputBg
InputSection.LayoutOrder = 0
corner(InputSection, s(6))
local inputStroke = strokeUI(InputSection, COL.RowStroke, 1, 0)

local InputIcon = Instance.new("TextLabel", InputSection)
InputIcon.Size = UDim2.new(0, s(26), 1, 0)
InputIcon.Position = UDim2.new(0, s(6), 0, 0)
InputIcon.BackgroundTransparency = 1
InputIcon.Text = "T"
InputIcon.Font = Enum.Font.GothamBlack
InputIcon.TextSize = s(14)
InputIcon.TextColor3 = COL.TextOn

local TargetInput = Instance.new("TextBox", InputSection)
TargetInput.Size = UDim2.new(1, -s(40), 1, 0)
TargetInput.Position = UDim2.new(0, s(34), 0, 0)
TargetInput.BackgroundTransparency = 1
TargetInput.Text = Shared.TargetUsername or ""
TargetInput.PlaceholderText = "Enter player name..."
TargetInput.Font = Enum.Font.GothamSemibold
TargetInput.TextSize = s(12)
TargetInput.TextColor3 = COL.TextOn
TargetInput.PlaceholderColor3 = COL.TextOff
TargetInput.TextXAlignment = Enum.TextXAlignment.Left
TargetInput.ClearTextOnFocus = false

local function findPlayer(txt)
    if txt == "" then return nil end
    local lower = string.lower(txt)
    for _, p in pairs(Players:GetPlayers()) do
        if p ~= lp then
            if string.lower(p.Name) == lower or string.lower(p.DisplayName) == lower then return p end
        end
    end
    for _, p in pairs(Players:GetPlayers()) do
        if p ~= lp then
            if string.lower(p.Name):find(lower) or string.lower(p.DisplayName):find(lower) then return p end
        end
    end
    return nil
end

local function saveTarget()
    local txt = TargetInput.Text
    local found = findPlayer(txt)
    if found then
        Shared.TargetUsername = found.Name
        TargetInput.Text = found.DisplayName
        inputStroke.Color = COL.Success
    else
        Shared.TargetUsername = nil
        inputStroke.Color = COL.Danger
    end
    TargetInput:ReleaseFocus()
    task.delay(0.5, function()
        TweenService:Create(inputStroke, TweenInfo.new(0.3), {Color = COL.RowStroke}):Play()
    end)
end

TargetInput.Focused:Connect(function()
    playClick()
    TweenService:Create(inputStroke, TweenInfo.new(0.2), {Color = COL.InputFocus}):Play()
end)

TargetInput.FocusLost:Connect(function(enterPressed)
    if enterPressed then
        saveTarget()
    else
        TweenService:Create(inputStroke, TweenInfo.new(0.2), {Color = COL.RowStroke}):Play()
    end
end)

local function CreateActionButton(text, order, callback)
    local Row = Instance.new("Frame", InnerContainer)
    Row.Size = UDim2.new(0.9, 0, 0, ROW_H)
    Row.BackgroundColor3 = COL.RowBg
    Row.LayoutOrder = order
    corner(Row, s(6))
    strokeUI(Row, COL.RowStroke, 1, 0)

    local Label = Instance.new("TextLabel", Row)
    Label.Size = UDim2.new(1, -s(70), 1, 0)
    Label.Position = UDim2.new(0, s(12), 0, 0)
    Label.BackgroundTransparency = 1
    Label.Text = text
    Label.Font = Enum.Font.GothamSemibold
    Label.TextSize = s(13)
    Label.TextColor3 = COL.TextOn
    Label.TextXAlignment = Enum.TextXAlignment.Left

    local btn = Instance.new("TextButton", Row)
    btn.AutoButtonColor = false
    btn.AnchorPoint = Vector2.new(1, 0.5)
    btn.Position = UDim2.new(1, -s(6), 0.5, 0)
    btn.Size = UDim2.new(0, s(50), 0, s(22))
    btn.BackgroundColor3 = COL.BtnActive
    btn.Font = Enum.Font.GothamBold
    btn.Text = "RUN"
    btn.TextSize = s(10)
    btn.TextColor3 = COL.TextOn
    corner(btn, s(4))

    btn.MouseButton1Click:Connect(function()
        playClick()
        TweenService:Create(btn, TweenInfo.new(0.1), {BackgroundColor3 = COL.ToggleBgOn}):Play()
        task.wait(0.12)
        TweenService:Create(btn, TweenInfo.new(0.15), {BackgroundColor3 = COL.BtnActive}):Play()
        callback()
    end)
end

local function CreateToggleButton(text, order, sharedKey)
    local Row = Instance.new("Frame", InnerContainer)
    Row.Size = UDim2.new(0.9, 0, 0, ROW_H)
    Row.BackgroundColor3 = COL.RowBg
    Row.LayoutOrder = order
    corner(Row, s(6))
    strokeUI(Row, COL.RowStroke, 1, 0)

    local Label = Instance.new("TextLabel", Row)
    Label.Size = UDim2.new(0.65, 0, 1, 0)
    Label.Position = UDim2.new(0, s(12), 0, 0)
    Label.BackgroundTransparency = 1
    Label.Text = text
    Label.Font = Enum.Font.GothamSemibold
    Label.TextSize = s(13)
    Label.TextColor3 = Shared[sharedKey] and COL.TextOn or COL.TextOff
    Label.TextXAlignment = Enum.TextXAlignment.Left

    local ToggleBg = Instance.new("Frame", Row)
    ToggleBg.Size = UDim2.new(0, s(40), 0, s(20))
    ToggleBg.Position = UDim2.new(1, -s(50), 0.5, -s(10))
    ToggleBg.BackgroundColor3 = Shared[sharedKey] and COL.ToggleBgOn or COL.ToggleBgOff
    corner(ToggleBg, 1)

    local ToggleDot = Instance.new("Frame", ToggleBg)
    ToggleDot.Size = UDim2.new(0, s(14), 0, s(14))
    ToggleDot.Position = Shared[sharedKey] and UDim2.new(0, s(23), 0.5, -s(7)) or UDim2.new(0, s(3), 0.5, -s(7))
    ToggleDot.BackgroundColor3 = COL.Dot
    corner(ToggleDot, 1)

    local btn = Instance.new("TextButton", Row)
    btn.Size = UDim2.new(1, 0, 1, 0)
    btn.BackgroundTransparency = 1
    btn.Text = ""

    btn.MouseButton1Click:Connect(function()
        playClick()
        Shared[sharedKey] = not Shared[sharedKey]
        local st = Shared[sharedKey]
        
        TweenService:Create(ToggleDot, TweenInfo.new(0.2), {Position = st and UDim2.new(0, s(23), 0.5, -s(7)) or UDim2.new(0, s(3), 0.5, -s(7))}):Play()
        TweenService:Create(ToggleBg, TweenInfo.new(0.2), {BackgroundColor3 = st and COL.ToggleBgOn or COL.ToggleBgOff}):Play()
        TweenService:Create(Label, TweenInfo.new(0.2), {TextColor3 = st and COL.TextOn or COL.TextOff}):Play()
    end)
end

CreateActionButton("Teleport", 1, function()
    local myHRP = getLocalHRP()
    local targetHRP = getTargetHRP()
    if myHRP and targetHRP then myHRP.CFrame = targetHRP.CFrame + Vector3.new(0, 3, 0) end
end)

CreateToggleButton("Spectate", 2, "ViewTarget")
CreateToggleButton("Highlight", 3, "HighlightTarget")
CreateToggleButton("Auto Katana", 4, "AutoKatanaKill")
CreateToggleButton("Fling", 5, "Fling")
CreateToggleButton("OP Kill", 6, "OPKill")

local dragging, dragInput, dragStart, startPos
MainFrame.InputBegan:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
        dragging = true
        dragStart = input.Position
        startPos = MainFrame.Position
        input.Changed:Connect(function()
            if input.UserInputState == Enum.UserInputState.End then dragging = false end
        end)
    end
end)
MainFrame.InputChanged:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch then
        dragInput = input
    end
end)
UserInputService.InputChanged:Connect(function(input)
    if input == dragInput and dragging then
        local delta = input.Position - dragStart
        MainFrame.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + delta.X, startPos.Y.Scale, startPos.Y.Offset + delta.Y)
    end
end)

local FINAL_SIZE = UDim2.new(0, panelW, 0, panelH)
MainFrame.Size = UDim2.new(0, 0, 0, 0)
TweenService:Create(MainFrame, TweenInfo.new(0.5, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {Size = FINAL_SIZE}):Play()

local lastHighlightUpdate = 0
local mainLoop = RunService.Heartbeat:Connect(function(dt)
    local isDoingAttack = Shared.AutoKatanaKill or Shared.Fling or Shared.OPKill
    if Shared.ViewTarget and not isDoingAttack then spectateTarget()
    elseif not isDoingAttack then spectateSelf() end

    lastHighlightUpdate = lastHighlightUpdate + dt
    if lastHighlightUpdate > 0.5 then lastHighlightUpdate = 0 updateHighlight() end

    local char = lp and lp.Character
    if not char then return end
    local hrp = char:FindFirstChild("HumanoidRootPart")
    local hum = char:FindFirstChildOfClass("Humanoid")
    if not hrp or not hum then return end
    local doingNoclip = false

    if Shared.OPKill then doingNoclip = true performOpKill(dt) end

    if Shared.AutoKatanaKill then
        doingNoclip = true
        if not katanaLoop then startKatanaLoop() end
    else
        if katanaLoop then stopKatanaLoop() end
    end

    if Shared.Fling then
        doingNoclip = true
        if not flingActive then flingActive = true startFling() end
    else
        if flingActive then flingActive = false stopFling() end
    end

    if doingNoclip then
        if not noclipActive then applyNoclipState(char, true) noclipActive = true end
    else
        if noclipActive then applyNoclipState(char, false) noclipActive = false end
    end
end)
table.insert(Shared.Connections[key], mainLoop)

-- FIX: Verlässt der Spieler das Spiel, bleibt sein Name im System eingespeichert!
local playerRemoving = Players.PlayerRemoving:Connect(function(plr)
    if Shared.TargetUsername and plr.Name == Shared.TargetUsername then
        -- Nur visuelle Effekte bereinigen, damit das Spiel flüssig weiterläuft
        if highlight then highlight:Destroy() highlight = nil end
        lastHighlightTarget = nil
        spectateSelf()
        
        -- HINWEIS: Shared.TargetUsername & UI-Text werden NICHT mehr gelöscht!
        -- Sobald der Spieler wieder joint, wird er sofort wieder getargeted.
    end
end)
table.insert(Shared.Connections[key], playerRemoving)

return Shared
