local RunService = game:GetService("RunService")
local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")
local VirtualUser = game:GetService("VirtualUser")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local VirtualInputManager = game:GetService("VirtualInputManager")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")

local MainEvent = ReplicatedStorage:FindFirstChild("MainEvent") or ReplicatedStorage:FindFirstChild("MAINEVENT")
if not MainEvent then 
    MainEvent = ReplicatedStorage:WaitForChild("MainEvent", 1) 
end

local lp = Players.LocalPlayer
local Shared = getgenv().SchmecktHubPC or {}
getgenv().SchmecktHubPC = Shared
local key = "TargetScript"

if Shared.Connections and Shared.Connections[key] then
    for _, c in pairs(Shared.Connections[key]) do
        pcall(function() c:Disconnect() end)
    end
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

local Theme = {
    Background = Color3.fromRGB(20, 5, 15),
    Card = Color3.fromRGB(45, 12, 35),
    Accent = Color3.fromRGB(255, 20, 147),
    Purple = Color3.fromRGB(180, 50, 255),
    PurpleLight = Color3.fromRGB(220, 130, 255),
    Text = Color3.fromRGB(255, 255, 255),
    SubText = Color3.fromRGB(255, 150, 180),
    Stroke = Color3.fromRGB(150, 30, 100),
    Shadow = Color3.fromRGB(0, 0, 0),
    Success = Color3.fromRGB(50, 255, 150),
    Danger = Color3.fromRGB(255, 50, 80),
    Orange = Color3.fromRGB(255, 150, 50)
}

local LOGO_ASSET = "rbxassetid://121759217057084"
local LOGO2_ASSET = "rbxassetid://118676632373972"

local highlight = nil
local flingActive = false
local flingLoop = nil
local katanaLoop = nil
local defaultCollisions = setmetatable({}, {__mode = "k"})
local noclipActive = false
local opAngle = 0
local lastReloadTime = 0

local katanaPatterns = {
    function(tHRP, time)
        return tHRP.Position + Vector3.new(
            math.sin(time * 47) * math.random(3, 8),
            -3.2 + math.cos(time * 31) * math.random(1, 5),
            math.sin(time * 53) * math.random(3, 8)
        )
    end,
    function(tHRP, time)
        return tHRP.Position + Vector3.new(
            math.random(-10, 10),
            -3.2 + math.random(-3, 7),
            math.random(-10, 10)
        )
    end,
    function(tHRP, time)
        local angle = time * math.random(5, 25)
        local radius = math.random(1, 6)
        return tHRP.Position + Vector3.new(
            math.cos(angle) * radius,
            -3.2 + math.sin(time * math.random(3, 9)) * 2,
            math.sin(angle) * radius
        )
    end,
    function(tHRP, time)
        return tHRP.Position + Vector3.new(
            math.sin(time * 17) * math.cos(time * 13) * 5,
            -3.2 + math.sin(time * 19) * math.random(1, 4),
            math.cos(time * 23) * math.sin(time * 11) * 5
        )
    end
}

local flingPatterns = {
    function(tHRP, time)
        return tHRP.Position + Vector3.new(
            math.sin(time * 47) * math.random(3, 8),
            -3.2 + math.cos(time * 31) * math.random(1, 5),
            math.sin(time * 53) * math.random(3, 8)
        )
    end,
    function(tHRP, time)
        return tHRP.Position + Vector3.new(
            math.random(-10, 10),
            -3.2 + math.random(-3, 7),
            math.random(-10, 10)
        )
    end,
    function(tHRP, time)
        local angle = time * math.random(5, 25)
        local radius = math.random(1, 6)
        return tHRP.Position + Vector3.new(
            math.cos(angle) * radius,
            -3.2 + math.sin(time * math.random(3, 9)) * 2,
            math.sin(angle) * radius
        )
    end
}

local function getUnpredictableVelocity(time)
    local patterns = {
        Vector3.new(math.random(-150000, 150000), math.random(80000, 150000), math.random(-150000, 150000)),
        Vector3.new(math.sin(time * 7) * 120000, 100000 + math.cos(time * 5) * 50000, math.cos(time * 11) * 120000),
        Vector3.new(math.random(-200000, 200000), math.random(100000, 200000), math.random(-200000, 200000))
    }
    return patterns[math.random(1, #patterns)]
end

local function getKatanaVelocity(time)
    return Vector3.new(
        math.sin(time * math.random(5, 15)) * math.random(50, 150),
        math.random(30, 80),
        math.cos(time * math.random(5, 15)) * math.random(50, 150)
    )
end

local function getTarget()
    if not Shared.TargetUsername then return nil end
    return Players:FindFirstChild(Shared.TargetUsername)
end

local function getTargetHRP()
    local target = getTarget()
    if not target then return nil end
    local char = target.Character
    if not char then return nil end
    return char:FindFirstChild("HumanoidRootPart")
end

local function getLocalHRP()
    if not lp then return nil end
    local char = lp.Character
    if not char then return nil end
    return char:FindFirstChild("HumanoidRootPart")
end

local function applyNoclipState(char, state)
    for _, p in ipairs(char:GetDescendants()) do
        if p:IsA("BasePart") then
            if state then
                if defaultCollisions[p] == nil then defaultCollisions[p] = p.CanCollide end
                p.CanCollide = false
            else
                local def = defaultCollisions[p]
                if def ~= nil then p.CanCollide = def end
            end
        end
    end
end

local function updateHighlight()
    if not Shared.HighlightTarget then
        if highlight then highlight:Destroy() end
        highlight = nil
        return
    end
    local target = getTarget()
    local char = target and target.Character
    if not char then 
        if highlight then highlight:Destroy() end
        highlight = nil
        return 
    end
    if not highlight then
        highlight = Instance.new("Highlight")
        highlight.FillColor = Color3.fromRGB(255, 70, 70)
        highlight.OutlineColor = Color3.new(1, 1, 1)
        highlight.FillTransparency = 0.5
        highlight.OutlineTransparency = 0
        highlight.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
        highlight.Parent = Workspace
    end
    highlight.Adornee = char
end

local function getKatanaTool(char)
    for _, t in ipairs(char:GetChildren()) do
        if t:IsA("Tool") and string.lower(t.Name):find("katana") then return t end
    end
    for _, t in ipairs(lp.Backpack:GetChildren()) do
        if t:IsA("Tool") and string.lower(t.Name):find("katana") then return t end
    end
    return nil
end

local function fireTouchFast(tool, targetChar)
    if not firetouchinterest then return end
    local handle = tool and tool:FindFirstChild("Handle")
    if not handle then return end
    local tHRP = targetChar:FindFirstChild("HumanoidRootPart")
    if tHRP then
        pcall(firetouchinterest, handle, tHRP, 0)
        pcall(firetouchinterest, handle, tHRP, 1)
    end
end

local function spectateTarget()
    local target = getTarget()
    if target and target.Character then
        local tHum = target.Character:FindFirstChildOfClass("Humanoid")
        if tHum then
            Workspace.CurrentCamera.CameraSubject = tHum
        end
    end
end

local function spectateSelf()
    local hum = lp.Character and lp.Character:FindFirstChildOfClass("Humanoid")
    if hum then
        Workspace.CurrentCamera.CameraSubject = hum
    end
end

local function startKatanaLoop()
    if katanaLoop then return end
    katanaLoop = task.spawn(function()
        while Shared.AutoKatanaKill do
            local char = lp.Character
            local hrp = char and char:FindFirstChild("HumanoidRootPart")
            local hum = char and char:FindFirstChildOfClass("Humanoid")
            local target = getTarget()
            local tChar = target and target.Character
            local tHRP = tChar and tChar:FindFirstChild("HumanoidRootPart")
            local tHum = tChar and tChar:FindFirstChildOfClass("Humanoid")
            if hrp and hum and tHRP and tHum and tHum.Health > 0 then
                spectateTarget()
                local tool = getKatanaTool(char)
                if tool then
                    if tool.Parent ~= char then hum:EquipTool(tool) end
                    local time = tick()
                    local pattern = katanaPatterns[math.random(1, #katanaPatterns)]
                    local position = pattern(tHRP, time)
                    local velocity = getKatanaVelocity(time)
                    hrp.CFrame = CFrame.new(position, tHRP.Position)
                    hrp.Velocity = velocity
                    hrp.RotVelocity = Vector3.new(math.random(-500, 500), math.random(-500, 500), math.random(-500, 500))
                    pcall(function() tool:Activate() end)
                    fireTouchFast(tool, tChar)
                    pcall(function() VirtualUser:CaptureController() VirtualUser:Button1Down(Vector2.new(0, 0)) end)
                    task.wait(0.02)
                    pcall(function() VirtualUser:Button1Up(Vector2.new(0, 0)) end)
                end
            end
            task.wait(0.03)
        end
    end)
end

local function stopKatanaLoop()
    if katanaLoop then task.cancel(katanaLoop) katanaLoop = nil end
    spectateSelf()
    if lp.Character then
        local hrp = lp.Character:FindFirstChild("HumanoidRootPart")
        if hrp then hrp.Velocity = Vector3.zero hrp.RotVelocity = Vector3.zero end
    end
end

local function startFling()
    if flingLoop then return end
    flingLoop = task.spawn(function()
        while Shared.Fling do
            local char = lp.Character
            local hrp = char and char:FindFirstChild("HumanoidRootPart")
            local target = getTarget()
            local tHRP = target and target.Character and target.Character:FindFirstChild("HumanoidRootPart")
            if hrp and tHRP then
                spectateTarget()
                local time = tick()
                local pattern = flingPatterns[math.random(1, #flingPatterns)]
                local position = pattern(tHRP, time)
                local velocity = getUnpredictableVelocity(time)
                hrp.CFrame = CFrame.new(position, tHRP.Position)
                hrp.Velocity = velocity
                hrp.RotVelocity = Vector3.new(math.random(-10000, 10000), math.random(-10000, 10000), math.random(-10000, 10000))
            end
            task.wait()
        end
    end)
end

local function stopFling()
    if flingLoop then task.cancel(flingLoop) flingLoop = nil end
    spectateSelf()
    if lp.Character then
        local hrp = lp.Character:FindFirstChild("HumanoidRootPart")
        if hrp then hrp.Velocity = Vector3.zero hrp.RotVelocity = Vector3.zero end
    end
end

local function performOpKill(dt)
    local target = getTarget()
    if not target or not target.Character then return end
    local tHRP = target.Character:FindFirstChild("HumanoidRootPart")
    local tHum = target.Character:FindFirstChild("Humanoid")
    local myHRP = getLocalHRP()
    if tHRP and myHRP and tHum then
        spectateTarget()
        opAngle = opAngle + (25 * dt)
        local radius = 6.5
        local height = 3.5
        local offsetX = math.cos(opAngle) * radius
        local offsetZ = math.sin(opAngle) * radius
        local jitter = Vector3.new(math.random()-0.5, math.random()-0.5, math.random()-0.5) * 2
        local newPos = tHRP.Position + Vector3.new(offsetX, height, offsetZ) + jitter
        myHRP.CFrame = CFrame.lookAt(newPos, tHRP.Position)
        myHRP.Velocity = Vector3.zero
        myHRP.RotVelocity = Vector3.zero
        local tool = lp.Character:FindFirstChildOfClass("Tool")
        if tool then
            local ammo = tool:FindFirstChild("Ammo") or tool:FindFirstChild("AMMO")
            if ammo and tonumber(ammo.Value) <= 0 then
                if (tick() - lastReloadTime) > 2 then
                    lastReloadTime = tick()
                    task.spawn(function()
                        VirtualInputManager:SendKeyEvent(true, Enum.KeyCode.R, false, game)
                        task.wait(0.1)
                        VirtualInputManager:SendKeyEvent(false, Enum.KeyCode.R, false, game)
                    end)
                end
                return
            end
            tool:Activate()
        else
            local bpTool = lp.Backpack:FindFirstChildOfClass("Tool")
            if bpTool and lp.Character:FindFirstChild("Humanoid") then
                lp.Character.Humanoid:EquipTool(bpTool)
            end
        end
        if MainEvent then MainEvent:FireServer("Stomp") end
    end
end

local TargetGui = Instance.new("ScreenGui")
TargetGui.Name = "TargetGui"
TargetGui.ResetOnSpawn = false
TargetGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
TargetGui.Parent = lp:WaitForChild("PlayerGui")

local MainShadow = Instance.new("Frame")
MainShadow.Name = "Shadow"
MainShadow.Size = UDim2.new(0, 260, 0, 340)
MainShadow.Position = UDim2.new(1, -520, 1, -355)
MainShadow.BackgroundColor3 = Theme.Shadow
MainShadow.BackgroundTransparency = 0.5
MainShadow.BorderSizePixel = 0
MainShadow.Parent = TargetGui
Instance.new("UICorner", MainShadow).CornerRadius = UDim.new(0, 16)

local MainFrame = Instance.new("Frame")
MainFrame.Name = "MainFrame"
MainFrame.Size = UDim2.new(0, 250, 0, 330)
MainFrame.Position = UDim2.new(1, -515, 1, -350)
MainFrame.BackgroundColor3 = Theme.Background
MainFrame.BackgroundTransparency = 0.02
MainFrame.BorderSizePixel = 0
MainFrame.Parent = TargetGui

Instance.new("UICorner", MainFrame).CornerRadius = UDim.new(0, 14)

local MainStroke = Instance.new("UIStroke")
MainStroke.Thickness = 2
MainStroke.Transparency = 0
MainStroke.Parent = MainFrame

local mainStrokeGrad = Instance.new("UIGradient")
mainStrokeGrad.Rotation = 90
mainStrokeGrad.Color = ColorSequence.new({
    ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 20, 147)),
    ColorSequenceKeypoint.new(0.5, Color3.fromRGB(180, 50, 255)),
    ColorSequenceKeypoint.new(1, Color3.fromRGB(220, 20, 60))
})
mainStrokeGrad.Parent = MainStroke

local HeaderFrame = Instance.new("Frame")
HeaderFrame.Name = "Header"
HeaderFrame.Size = UDim2.new(1, 0, 0, 50)
HeaderFrame.BackgroundColor3 = Theme.Card
HeaderFrame.BorderSizePixel = 0
HeaderFrame.Parent = MainFrame
Instance.new("UICorner", HeaderFrame).CornerRadius = UDim.new(0, 14)

local headerGlow = Instance.new("Frame")
headerGlow.Size = UDim2.new(1, 0, 1, 0)
headerGlow.BackgroundColor3 = Theme.Purple
headerGlow.BackgroundTransparency = 0.88
headerGlow.BorderSizePixel = 0
headerGlow.Parent = HeaderFrame
Instance.new("UICorner", headerGlow).CornerRadius = UDim.new(0, 14)

local HeaderLogo1 = Instance.new("ImageLabel")
HeaderLogo1.Size = UDim2.new(0, 28, 0, 28)
HeaderLogo1.Position = UDim2.new(0, 10, 0.5, -14)
HeaderLogo1.BackgroundColor3 = Theme.Background
HeaderLogo1.Image = LOGO_ASSET
HeaderLogo1.ScaleType = Enum.ScaleType.Crop
HeaderLogo1.Parent = HeaderFrame
Instance.new("UICorner", HeaderLogo1).CornerRadius = UDim.new(0, 6)

local HeaderX = Instance.new("TextLabel")
HeaderX.Size = UDim2.new(0, 14, 0, 28)
HeaderX.Position = UDim2.new(0, 40, 0.5, -14)
HeaderX.BackgroundTransparency = 1
HeaderX.Text = "X"
HeaderX.Font = Enum.Font.GothamBlack
HeaderX.TextSize = 10
HeaderX.TextColor3 = Theme.Purple
HeaderX.Parent = HeaderFrame

local HeaderLogo2 = Instance.new("ImageLabel")
HeaderLogo2.Size = UDim2.new(0, 24, 0, 24)
HeaderLogo2.Position = UDim2.new(0, 56, 0.5, -12)
HeaderLogo2.BackgroundTransparency = 1
HeaderLogo2.Image = LOGO2_ASSET
HeaderLogo2.ScaleType = Enum.ScaleType.Fit
HeaderLogo2.Parent = HeaderFrame
Instance.new("UICorner", HeaderLogo2).CornerRadius = UDim.new(1, 0)

local HeaderText = Instance.new("TextLabel")
HeaderText.Size = UDim2.new(1, -90, 0, 18)
HeaderText.Position = UDim2.new(0, 88, 0, 8)
HeaderText.BackgroundTransparency = 1
HeaderText.Text = "TARGET PANEL"
HeaderText.Font = Enum.Font.GothamBlack
HeaderText.TextSize = 11
HeaderText.TextColor3 = Theme.Accent
HeaderText.TextXAlignment = Enum.TextXAlignment.Left
HeaderText.Parent = HeaderFrame

local headerTextGrad = Instance.new("UIGradient")
headerTextGrad.Rotation = 0
headerTextGrad.Color = ColorSequence.new({
    ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 20, 147)),
    ColorSequenceKeypoint.new(0.5, Color3.fromRGB(180, 50, 255)),
    ColorSequenceKeypoint.new(1, Color3.fromRGB(255, 105, 180))
})
headerTextGrad.Parent = HeaderText

local HeaderSub = Instance.new("TextLabel")
HeaderSub.Size = UDim2.new(1, -90, 0, 14)
HeaderSub.Position = UDim2.new(0, 88, 0, 26)
HeaderSub.BackgroundTransparency = 1
HeaderSub.Text = "Meulios X ShadowPepper"
HeaderSub.Font = Enum.Font.GothamMedium
HeaderSub.TextSize = 9
HeaderSub.TextColor3 = Theme.SubText
HeaderSub.TextXAlignment = Enum.TextXAlignment.Left
HeaderSub.Parent = HeaderFrame

local InputSection = Instance.new("Frame")
InputSection.Name = "InputSection"
InputSection.Size = UDim2.new(1, -16, 0, 40)
InputSection.Position = UDim2.new(0, 8, 0, 56)
InputSection.BackgroundColor3 = Theme.Card
InputSection.BorderSizePixel = 0
InputSection.Parent = MainFrame
Instance.new("UICorner", InputSection).CornerRadius = UDim.new(0, 10)

local InputStroke = Instance.new("UIStroke")
InputStroke.Color = Theme.Stroke
InputStroke.Thickness = 1.5
InputStroke.Transparency = 0.3
InputStroke.Parent = InputSection

local InputIcon = Instance.new("TextLabel")
InputIcon.Size = UDim2.new(0, 30, 1, 0)
InputIcon.Position = UDim2.new(0, 8, 0, 0)
InputIcon.BackgroundTransparency = 1
InputIcon.Text = "T"
InputIcon.Font = Enum.Font.GothamBlack
InputIcon.TextSize = 18
InputIcon.TextColor3 = Theme.Purple
InputIcon.Parent = InputSection

local TargetInput = Instance.new("TextBox")
TargetInput.Name = "TargetInput"
TargetInput.Size = UDim2.new(1, -50, 1, -10)
TargetInput.Position = UDim2.new(0, 42, 0, 5)
TargetInput.BackgroundTransparency = 1
TargetInput.Text = Shared.TargetUsername or ""
TargetInput.PlaceholderText = "Enter player name..."
TargetInput.Font = Enum.Font.GothamMedium
TargetInput.TextSize = 13
TargetInput.TextColor3 = Theme.Text
TargetInput.PlaceholderColor3 = Theme.SubText
TargetInput.TextXAlignment = Enum.TextXAlignment.Left
TargetInput.ClearTextOnFocus = false
TargetInput.Parent = InputSection

local function findPlayer(txt)
    if txt == "" then return nil end
    local lower = string.lower(txt)
    for _, p in pairs(Players:GetPlayers()) do
        if p ~= lp then
            if string.lower(p.Name) == lower or string.lower(p.DisplayName) == lower then
                return p
            end
        end
    end
    for _, p in pairs(Players:GetPlayers()) do
        if p ~= lp then
            if string.lower(p.Name):find(lower) or string.lower(p.DisplayName):find(lower) then
                return p
            end
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
        InputStroke.Color = Theme.Success
    else
        Shared.TargetUsername = nil
        InputStroke.Color = Theme.Danger
    end
    TargetInput:ReleaseFocus()
    task.delay(0.5, function()
        TweenService:Create(InputStroke, TweenInfo.new(0.3), {Color = Theme.Stroke}):Play()
    end)
end

TargetInput.Focused:Connect(function()
    TweenService:Create(InputStroke, TweenInfo.new(0.2), {Color = Theme.Purple, Transparency = 0}):Play()
end)

TargetInput.FocusLost:Connect(function(enterPressed)
    if enterPressed then
        saveTarget()
    else
        TweenService:Create(InputStroke, TweenInfo.new(0.2), {Color = Theme.Stroke, Transparency = 0.3}):Play()
    end
end)

local ButtonContainer = Instance.new("Frame")
ButtonContainer.Name = "ButtonContainer"
ButtonContainer.Size = UDim2.new(1, -16, 0, 220)
ButtonContainer.Position = UDim2.new(0, 8, 0, 102)
ButtonContainer.BackgroundTransparency = 1
ButtonContainer.Parent = MainFrame

local ListLayout = Instance.new("UIListLayout")
ListLayout.SortOrder = Enum.SortOrder.LayoutOrder
ListLayout.Padding = UDim.new(0, 6)
ListLayout.Parent = ButtonContainer

local function CreateActionButton(text, callback)
    local BtnFrame = Instance.new("Frame")
    BtnFrame.Size = UDim2.new(1, 0, 0, 32)
    BtnFrame.BackgroundColor3 = Theme.Card
    BtnFrame.BorderSizePixel = 0
    BtnFrame.Parent = ButtonContainer
    Instance.new("UICorner", BtnFrame).CornerRadius = UDim.new(0, 8)
    local BtnStroke = Instance.new("UIStroke")
    BtnStroke.Color = Theme.Stroke
    BtnStroke.Thickness = 1.5
    BtnStroke.Transparency = 0.3
    BtnStroke.Parent = BtnFrame
    local TextLabel = Instance.new("TextLabel")
    TextLabel.Size = UDim2.new(1, -50, 1, 0)
    TextLabel.Position = UDim2.new(0, 12, 0, 0)
    TextLabel.BackgroundTransparency = 1
    TextLabel.Text = text
    TextLabel.Font = Enum.Font.GothamBold
    TextLabel.TextSize = 11
    TextLabel.TextColor3 = Theme.Text
    TextLabel.TextXAlignment = Enum.TextXAlignment.Left
    TextLabel.Parent = BtnFrame
    local ActionBadge = Instance.new("TextLabel")
    ActionBadge.Size = UDim2.new(0, 30, 0, 14)
    ActionBadge.Position = UDim2.new(1, -38, 0.5, -7)
    ActionBadge.BackgroundColor3 = Theme.Purple
    ActionBadge.BorderSizePixel = 0
    ActionBadge.Text = "GO"
    ActionBadge.Font = Enum.Font.GothamBlack
    ActionBadge.TextSize = 8
    ActionBadge.TextColor3 = Theme.Text
    ActionBadge.Parent = BtnFrame
    Instance.new("UICorner", ActionBadge).CornerRadius = UDim.new(0, 4)
    local Button = Instance.new("TextButton")
    Button.Size = UDim2.new(1, 0, 1, 0)
    Button.BackgroundTransparency = 1
    Button.Text = ""
    Button.Parent = BtnFrame
    Button.MouseButton1Click:Connect(function()
        TweenService:Create(BtnFrame, TweenInfo.new(0.08), {BackgroundColor3 = Theme.Purple}):Play()
        task.wait(0.08)
        TweenService:Create(BtnFrame, TweenInfo.new(0.08), {BackgroundColor3 = Theme.Card}):Play()
        callback()
    end)
    Button.MouseEnter:Connect(function()
        TweenService:Create(BtnStroke, TweenInfo.new(0.15), {Color = Theme.Purple, Transparency = 0}):Play()
    end)
    Button.MouseLeave:Connect(function()
        TweenService:Create(BtnStroke, TweenInfo.new(0.15), {Color = Theme.Stroke, Transparency = 0.3}):Play()
    end)
    return BtnFrame
end

local function CreateToggleButton(text, sharedKey)
    local BtnFrame = Instance.new("Frame")
    BtnFrame.Size = UDim2.new(1, 0, 0, 32)
    BtnFrame.BackgroundColor3 = Theme.Card
    BtnFrame.BorderSizePixel = 0
    BtnFrame.Parent = ButtonContainer
    Instance.new("UICorner", BtnFrame).CornerRadius = UDim.new(0, 8)
    local BtnStroke = Instance.new("UIStroke")
    BtnStroke.Color = Shared[sharedKey] and Theme.Purple or Theme.Stroke
    BtnStroke.Thickness = 1.5
    BtnStroke.Transparency = Shared[sharedKey] and 0 or 0.3
    BtnStroke.Parent = BtnFrame
    local TextLabel = Instance.new("TextLabel")
    TextLabel.Size = UDim2.new(1, -55, 1, 0)
    TextLabel.Position = UDim2.new(0, 12, 0, 0)
    TextLabel.BackgroundTransparency = 1
    TextLabel.Text = text
    TextLabel.Font = Enum.Font.GothamBold
    TextLabel.TextSize = 11
    TextLabel.TextColor3 = Theme.Text
    TextLabel.TextXAlignment = Enum.TextXAlignment.Left
    TextLabel.Parent = BtnFrame
    local ToggleBg = Instance.new("Frame")
    ToggleBg.Size = UDim2.new(0, 36, 0, 18)
    ToggleBg.Position = UDim2.new(1, -44, 0.5, -9)
    ToggleBg.BackgroundColor3 = Shared[sharedKey] and Theme.Purple or Color3.fromRGB(40, 20, 30)
    ToggleBg.BorderSizePixel = 0
    ToggleBg.Parent = BtnFrame
    Instance.new("UICorner", ToggleBg).CornerRadius = UDim.new(1, 0)
    local ToggleCircle = Instance.new("Frame")
    ToggleCircle.Size = UDim2.new(0, 14, 0, 14)
    ToggleCircle.Position = Shared[sharedKey] and UDim2.new(0, 20, 0.5, -7) or UDim2.new(0, 2, 0.5, -7)
    ToggleCircle.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
    ToggleCircle.BorderSizePixel = 0
    ToggleCircle.Parent = ToggleBg
    Instance.new("UICorner", ToggleCircle).CornerRadius = UDim.new(1, 0)
    local Button = Instance.new("TextButton")
    Button.Size = UDim2.new(1, 0, 1, 0)
    Button.BackgroundTransparency = 1
    Button.Text = ""
    Button.Parent = BtnFrame
    Button.MouseButton1Click:Connect(function()
        Shared[sharedKey] = not Shared[sharedKey]
        local enabled = Shared[sharedKey]
        TweenService:Create(ToggleCircle, TweenInfo.new(0.2, Enum.EasingStyle.Quart), {
            Position = enabled and UDim2.new(0, 20, 0.5, -7) or UDim2.new(0, 2, 0.5, -7)
        }):Play()
        TweenService:Create(ToggleBg, TweenInfo.new(0.2, Enum.EasingStyle.Quart), {
            BackgroundColor3 = enabled and Theme.Purple or Color3.fromRGB(40, 20, 30)
        }):Play()
        TweenService:Create(BtnStroke, TweenInfo.new(0.2), {
            Color = enabled and Theme.Purple or Theme.Stroke,
            Transparency = enabled and 0 or 0.3
        }):Play()
    end)
    Button.MouseEnter:Connect(function()
        if not Shared[sharedKey] then
            TweenService:Create(BtnStroke, TweenInfo.new(0.15), {Color = Theme.Purple, Transparency = 0}):Play()
        end
    end)
    Button.MouseLeave:Connect(function()
        if not Shared[sharedKey] then
            TweenService:Create(BtnStroke, TweenInfo.new(0.15), {Color = Theme.Stroke, Transparency = 0.3}):Play()
        end
    end)
    return BtnFrame
end

CreateActionButton("Teleport", function()
    local myHRP = getLocalHRP()
    local targetHRP = getTargetHRP()
    if myHRP and targetHRP then myHRP.CFrame = targetHRP.CFrame + Vector3.new(0, 3, 0) end
end)

CreateToggleButton("Spectate", "ViewTarget")
CreateToggleButton("Highlight", "HighlightTarget")
CreateToggleButton("Auto Katana", "AutoKatanaKill")
CreateToggleButton("Fling", "Fling")
CreateToggleButton("OP Kill", "OPKill")

local mainColorPhase = 0
local mainColorConnection = RunService.Heartbeat:Connect(function(dt)
    if not MainFrame.Parent then
        mainColorConnection:Disconnect()
        return
    end
    mainColorPhase = (mainColorPhase + dt * 0.6) % 1
    local function lerpColor(t)
        local colors = {
            Color3.fromRGB(255, 20, 147),
            Color3.fromRGB(220, 20, 60),
            Color3.fromRGB(180, 50, 255),
            Color3.fromRGB(255, 105, 180),
        }
        local index = math.floor(t * #colors) + 1
        local nextIndex = (index % #colors) + 1
        local localT = (t * #colors) % 1
        return colors[index]:Lerp(colors[nextIndex], localT)
    end
    local o1 = mainColorPhase
    local o2 = (mainColorPhase + 0.33) % 1
    local o3 = (mainColorPhase + 0.66) % 1
    mainStrokeGrad.Color = ColorSequence.new({
        ColorSequenceKeypoint.new(0, lerpColor(o1)),
        ColorSequenceKeypoint.new(0.5, lerpColor(o2)),
        ColorSequenceKeypoint.new(1, lerpColor(o3))
    })
    headerTextGrad.Color = ColorSequence.new({
        ColorSequenceKeypoint.new(0, lerpColor(o1)),
        ColorSequenceKeypoint.new(0.5, lerpColor(o2)),
        ColorSequenceKeypoint.new(1, lerpColor(o3))
    })
end)
table.insert(Shared.Connections[key], mainColorConnection)

local dragging, dragInput, dragStart, startPos, shadowStartPos
MainFrame.InputBegan:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
        dragging = true
        dragStart = input.Position
        startPos = MainFrame.Position
        shadowStartPos = MainShadow.Position
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
        MainShadow.Position = UDim2.new(shadowStartPos.X.Scale, shadowStartPos.X.Offset + delta.X, shadowStartPos.Y.Scale, shadowStartPos.Y.Offset + delta.Y)
    end
end)
UserInputService.InputEnded:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
        dragging = false
    end
end)

MainFrame.Size = UDim2.new(0, 0, 0, 0)
MainShadow.Size = UDim2.new(0, 0, 0, 0)
MainShadow.BackgroundTransparency = 1
TweenService:Create(MainFrame, TweenInfo.new(0.5, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {Size = UDim2.new(0, 250, 0, 330)}):Play()
TweenService:Create(MainShadow, TweenInfo.new(0.5, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {Size = UDim2.new(0, 260, 0, 340)}):Play()
TweenService:Create(MainShadow, TweenInfo.new(0.5, Enum.EasingStyle.Quad), {BackgroundTransparency = 0.5}):Play()

local mainLoop = RunService.Heartbeat:Connect(function(dt)
    local isDoingAttack = Shared.AutoKatanaKill or Shared.Fling or Shared.OPKill
    
    if Shared.ViewTarget and not isDoingAttack then
        spectateTarget()
    elseif not isDoingAttack then
        spectateSelf()
    end

    updateHighlight()

    local char = lp and lp.Character
    if not char then return end
    local hrp = char:FindFirstChild("HumanoidRootPart")
    local hum = char:FindFirstChildOfClass("Humanoid")
    if not hrp or not hum then return end
    local doingNoclip = false

    if Shared.OPKill then
        doingNoclip = true
        performOpKill(dt)
    end

    if Shared.AutoKatanaKill then
        doingNoclip = true
        if not katanaLoop then
            startKatanaLoop()
        end
    else
        if katanaLoop then
            stopKatanaLoop()
        end
    end

    if Shared.Fling then
        doingNoclip = true
        if not flingActive then
            flingActive = true
            startFling()
        end
    else
        if flingActive then
            flingActive = false
            stopFling()
        end
    end

    if doingNoclip then
        if not noclipActive then applyNoclipState(char, true) noclipActive = true end
    else
        if noclipActive then applyNoclipState(char, false) noclipActive = false end
    end
end)
table.insert(Shared.Connections[key], mainLoop)

local playerRemoving = Players.PlayerRemoving:Connect(function(plr)
    if Shared.TargetUsername and plr.Name == Shared.TargetUsername then
        if highlight then highlight:Destroy() highlight = nil end
        stopKatanaLoop()
        stopFling()
        Shared.TargetUsername = nil
        TargetInput.Text = ""
        spectateSelf()
    end
end)
table.insert(Shared.Connections[key], playerRemoving)
