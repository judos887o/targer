local RunService = game:GetService("RunService")
local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")
local VirtualUser = game:GetService("VirtualUser")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local VirtualInputManager = game:GetService("VirtualInputManager")

local MainEvent = ReplicatedStorage:FindFirstChild("MainEvent") or ReplicatedStorage:FindFirstChild("MAINEVENT")
if not MainEvent then 
    MainEvent = ReplicatedStorage:WaitForChild("MainEvent", 1) 
end

local lp = Players.LocalPlayer
local Shared = getgenv().SchmecktHubPC or {}

if getgenv().SchmecktTargetLoaded then return end
getgenv().SchmecktTargetLoaded = true

Shared.Fling = Shared.Fling or false
Shared.OPKill = Shared.OPKill or false
Shared.Aura = Shared.Aura or false
Shared.AutoReload = Shared.AutoReload or false

local highlight = nil
local camViewConn = nil
local autoKatClickLoopRunning = false
local flingActive = false
local flingLoop = nil
local defaultCollisions = setmetatable({}, {__mode = "k"})
local noclipActive = false

local opAngle = 0
local katanaTick = 0
local lastReloadTime = 0

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

local function stopView()
    if camViewConn then camViewConn:Disconnect() end
    camViewConn = nil
end

local function updateHighlight()
    if not Shared.HighlightTarget then
        if highlight then highlight:Destroy() end
        highlight = nil
        return
    end
    local target = getTarget()
    local char = target and target.Character
    if not char then return end
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

local function getKatanaOffset()
    return Vector3.new((math.random() - 0.5) * 5, -2 + (math.random() - 0.5), (math.random() - 0.5) * 5)
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
                Workspace.CurrentCamera.CameraSubject = target.Character:FindFirstChild("Humanoid")
                local flingPos = tHRP.Position + Vector3.new(math.random(-2,2), math.random(-2,2), math.random(-2,2))
                hrp.CFrame = CFrame.new(flingPos, tHRP.Position)
                hrp.Velocity = Vector3.new(15000, 15000, 15000)
                hrp.RotVelocity = Vector3.new(15000, 15000, 15000)
            end
            task.wait()
        end
    end)
end

local function stopFling()
    if flingLoop then task.cancel(flingLoop) flingLoop = nil end
    if lp.Character then
        local hrp = lp.Character:FindFirstChild("HumanoidRootPart")
        if hrp then hrp.Velocity = Vector3.zero; hrp.RotVelocity = Vector3.zero end
        local hum = lp.Character:FindFirstChild("Humanoid")
        if hum then Workspace.CurrentCamera.CameraSubject = hum end
    end
end

local function performOpKill(dt)
    local target = getTarget()
    if not target or not target.Character then return end
    
    local tHRP = target.Character:FindFirstChild("HumanoidRootPart")
    local tHum = target.Character:FindFirstChild("Humanoid")
    local myHRP = getLocalHRP()
    
    if tHRP and myHRP and tHum then
        Workspace.CurrentCamera.CameraSubject = tHum
        
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
                -- Reload Logic in OP Kill
                if (tick() - lastReloadTime) > 2 then
                    lastReloadTime = tick()
                    task.spawn(function()
                        VirtualInputManager:SendKeyEvent(true, Enum.KeyCode.R, false, game)
                        task.wait(0.1)
                        VirtualInputManager:SendKeyEvent(false, Enum.KeyCode.R, false, game)
                    end)
                end
                return -- Stop shooting while reloading
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

local function performAura(dt)
    local target = getTarget()
    if not target or not target.Character then return end
    local tHRP = target.Character:FindFirstChild("HumanoidRootPart")
    local myHRP = getLocalHRP()
    
    if tHRP and myHRP then
        opAngle = opAngle + (11 * dt)
        local x = math.cos(opAngle) * 4
        local z = math.sin(opAngle) * 4
        local newPos = tHRP.Position + Vector3.new(x, 0, z)
        
        myHRP.CFrame = CFrame.new(newPos, newPos * 2 - tHRP.Position)
        myHRP.Velocity = Vector3.zero
        myHRP.RotVelocity = Vector3.zero
    end
end

RunService.Heartbeat:Connect(function(dt)
    -- GLOBAL AUTO RELOAD CHECK
    if Shared.AutoReload then
        local tool = lp.Character and lp.Character:FindFirstChildOfClass("Tool")
        if tool then
            local ammo = tool:FindFirstChild("Ammo") or tool:FindFirstChild("AMMO")
            if ammo and tonumber(ammo.Value) <= 0 and (tick() - lastReloadTime) > 2 then
                lastReloadTime = tick()
                task.spawn(function()
                    VirtualInputManager:SendKeyEvent(true, Enum.KeyCode.R, false, game)
                    task.wait(0.1)
                    VirtualInputManager:SendKeyEvent(false, Enum.KeyCode.R, false, game)
                end)
            end
        end
    end

    if Shared.GotoTarget then
        Shared.GotoTarget = false
        local myHRP = getLocalHRP()
        local targetHRP = getTargetHRP()
        if myHRP and targetHRP then myHRP.CFrame = targetHRP.CFrame + Vector3.new(0, 3, 0) end
    end

    if Shared.ViewTarget then
        if not camViewConn then
            camViewConn = RunService.RenderStepped:Connect(function()
                local hrp = getTargetHRP()
                if not hrp then return end
                local cam = Workspace.CurrentCamera
                local offset = Vector3.new(0, 6, 12)
                cam.CFrame = CFrame.new(hrp.Position + offset, hrp.Position)
            end)
        end
    else
        stopView()
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
    else
        if not Shared.Fling and Workspace.CurrentCamera.CameraSubject ~= hum then
             Workspace.CurrentCamera.CameraSubject = hum
        end
    end

    if Shared.Aura then
        doingNoclip = true
        performAura(dt)
    end

    if Shared.AutoKatanaKill then
        local target = getTarget()
        if target and target.Character then
            local tHRP = target.Character:FindFirstChild("HumanoidRootPart")
            local tHum = target.Character:FindFirstChildOfClass("Humanoid")
            if tHRP and tHum and tHum.Health > 0 then
                doingNoclip = true
                katanaTick = katanaTick + 1
                local tool = getKatanaTool(char)
                if tool then
                    if tool.Parent ~= char then hum:EquipTool(tool) end
                    local tPos = tHRP.Position
                    local offset = getKatanaOffset()
                    local newPos = tPos + offset
                    hrp.CFrame = CFrame.new(newPos, tPos)
                    hrp.AssemblyLinearVelocity = Vector3.new(0, 50, 0)
                    hrp.AssemblyAngularVelocity = Vector3.zero
                    pcall(function() tool:Activate() end)
                    fireTouchFast(tool, target.Character)
                end
            end
        end
        if not autoKatClickLoopRunning then
            autoKatClickLoopRunning = true
            task.spawn(function()
                while Shared.AutoKatanaKill do
                    pcall(function() VirtualUser:CaptureController(); VirtualUser:Button1Down(Vector2.new(0, 0)) end)
                    task.wait(0.02)
                    pcall(function() VirtualUser:Button1Up(Vector2.new(0, 0)) end)
                    task.wait(0.02)
                end
                autoKatClickLoopRunning = false
            end)
        end
    else
        katanaTick = 0
    end

    if Shared.Fling then
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

    if Shared.Fling then doingNoclip = true
    elseif Shared.AutoKatanaKill or Shared.OPKill or Shared.Aura then doingNoclip = true end

    if doingNoclip then
        if not noclipActive then applyNoclipState(char, true) noclipActive = true end
    else
        if noclipActive then applyNoclipState(char, false) noclipActive = false end
    end
end)
