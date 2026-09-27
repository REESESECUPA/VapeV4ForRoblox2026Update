--[[
    SelfBackTrack (Desync Hook) - integrated into Vape UI
    WARNING: This script has not been verified by ScriptBlox. Use at your own risk!

    Replaces the standalone UI with a Vape network module. Toggle the module
    to enable/disable desync. Use the "Custom" toggle to set manual offsets
    and "ServerPos" to visualize the server position.
]]

local RunService = game:GetService("RunService")
local Players = game:GetService("Players")
local LocalPlayer = Players.LocalPlayer

-- state
local desyncT = { enabled = false, loc = CFrame.new() }
local customDesyncEnabled = false
local serverIndicatorEnabled = false

-- server visualizer
local serverIndicator
local function createServerIndicator()
    if serverIndicator then
        serverIndicator:Destroy()
        serverIndicator = nil
    end

    local indicator = Instance.new("Part")
    indicator.Name = "ServerPositionIndicator"
    indicator.Size = Vector3.new(2, 5, 1)
    indicator.Anchored = true
    indicator.CanCollide = false
    indicator.CanQuery = false
    indicator.CanTouch = false
    indicator.CastShadow = false
    indicator.Transparency = 0.4
    indicator.Material = Enum.Material.Neon
    indicator.Color = Color3.fromRGB(255, 50, 50)
    indicator.Parent = workspace

    local billboard = Instance.new("BillboardGui")
    billboard.Size = UDim2.new(0, 80, 0, 30)
    billboard.StudsOffset = Vector3.new(0, 4, 0)
    billboard.AlwaysOnTop = true
    billboard.Parent = indicator

    local label = Instance.new("TextLabel")
    label.Size = UDim2.new(1, 0, 1, 0)
    label.BackgroundTransparency = 1
    label.Text = "SERVER"
    label.TextColor3 = Color3.fromRGB(255, 50, 50)
    label.Font = Enum.Font.SourceSansBold
    label.TextSize = 16
    label.TextStrokeTransparency = 0
    label.Parent = billboard

    local selection = Instance.new("SelectionBox")
    selection.Color3 = Color3.fromRGB(255, 50, 50)
    selection.LineThickness = 0.05
    selection.Adornee = indicator
    selection.Parent = indicator

    serverIndicator = indicator
    return indicator
end

local function removeServerIndicator()
    if serverIndicator then
        serverIndicator:Destroy()
        serverIndicator = nil
    end
end

local function updateIndicator(cf)
    if not serverIndicator then return end
    if not serverIndicator.Parent then
        createServerIndicator()
        return
    end
    serverIndicator.CFrame = cf
end

-- offsets
local offsetX, offsetY, offsetZ = 0, 0, 0
local function getOffsetCFrame()
    if customDesyncEnabled then
        return CFrame.new(offsetX, offsetY, offsetZ)
    else
        local ping = LocalPlayer:GetNetworkPing() * 1000
        if ping < 100 then return CFrame.new(0, 0, 3.5)
        elseif ping <= 170 then return CFrame.new(0, 0, 4)
        else return CFrame.new(0, 0, 4) end
    end
end

-- spinning detection
local prevLookVector
local isSpinning = false
local spinThreshold = 15

-- connections
local heartbeatConn, charAddedConn

-- hook
local desynchook
local hookInstalled = false
local function installHook()
    if hookInstalled then return end
    hookInstalled = true
    desynchook = hookmetamethod(game, "__index", newcclosure(function(self, key)
        if desyncT.enabled and not checkcaller() and
           key == "CFrame" and
           LocalPlayer.Character and
           self == LocalPlayer.Character:FindFirstChild("HumanoidRootPart") and
           not isSpinning then
            return desyncT.loc
        end
        return desynchook(self, key)
    end))
end

-- heartbeat logic
local function heartbeatStep()
    if not desyncT.enabled or not LocalPlayer.Character then
        if serverIndicator and not desyncT.enabled then
            removeServerIndicator()
        end
        return
    end

    local character = LocalPlayer.Character
    local root = character:FindFirstChild("HumanoidRootPart")
    if not root then return end

    local currentLook = root.CFrame.LookVector
    if prevLookVector then
        local dot = math.clamp(prevLookVector:Dot(currentLook), -1, 1)
        local angleDiff = math.deg(math.acos(dot))
        isSpinning = angleDiff > spinThreshold
    end
    prevLookVector = currentLook

    if isSpinning then return end

    desyncT.loc = root.CFrame

    if serverIndicatorEnabled and serverIndicator then
        updateIndicator(desyncT.loc)
    end

    local offset = getOffsetCFrame()
    local newCFrame = desyncT.loc * offset
    root.CFrame = newCFrame

    RunService.RenderStepped:Wait()
    root.CFrame = desyncT.loc
end

-- register module in vape network category
SelfBackTrack = vape.Categories.network:CreateModule({
    Name = 'SelfBackTrack',
    Function = function(callback)
        desyncT.enabled = callback

        if callback then
            installHook()

            if serverIndicatorEnabled then
                createServerIndicator()
            end

            if heartbeatConn then heartbeatConn:Disconnect() heartbeatConn = nil end
            heartbeatConn = RunService.Heartbeat:Connect(heartbeatStep)

            if charAddedConn then charAddedConn:Disconnect() charAddedConn = nil end
            charAddedConn = LocalPlayer.CharacterAdded:Connect(function()
                task.wait(1)
                prevLookVector = nil
                isSpinning = false
                if serverIndicatorEnabled and desyncT.enabled then
                    createServerIndicator()
                end
            end)
        else
            removeServerIndicator()
            if heartbeatConn then heartbeatConn:Disconnect() heartbeatConn = nil end
            if charAddedConn then charAddedConn:Disconnect() charAddedConn = nil end
        end
    end,
    Tooltip = 'Hook-based clientside desync with server visualizer'
})

-- custom toggle
local customToggle = SelfBackTrack:CreateToggle({
    Name = 'Custom',
    Function = function(val)
        customDesyncEnabled = val
        -- toggle visibility of textboxes
        if tbX and tbY and tbZ and tbX.Object and tbY.Object and tbZ.Object then
            tbX.Object.Visible = val
            tbY.Object.Visible = val
            tbZ.Object.Visible = val
        end
    end
})

-- textboxes (created hidden by default)
local tbX = SelfBackTrack:CreateTextBox({
    Name = 'Offset X',
    Default = '0',
    Function = function(val)
        offsetX = tonumber(val) or 0
    end,
    Visible = false
})

local tbY = SelfBackTrack:CreateTextBox({
    Name = 'Offset Y',
    Default = '0',
    Function = function(val)
        offsetY = tonumber(val) or 0
    end,
    Visible = false
})

local tbZ = SelfBackTrack:CreateTextBox({
    Name = 'Offset Z',
    Default = '0',
    Function = function(val)
        offsetZ = tonumber(val) or 0
    end,
    Visible = false
})

-- server position toggle
local serverToggle = SelfBackTrack:CreateToggle({
    Name = 'ServerPos',
    Function = function(val)
        serverIndicatorEnabled = val
        if val and desyncT.enabled then
            createServerIndicator()
        else
            removeServerIndicator()
        end
    end
})

-- spin threshold slider
SelfBackTrack:CreateSlider({
    Name = 'Spin Threshold',
    Min = 1,
    Max = 90,
    Default = spinThreshold,
    Function = function(val)
        spinThreshold = val
    end,
    Suffix = 'deg'
})

print('SelfBackTrack module loaded')
