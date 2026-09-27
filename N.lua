--[[
    N.lua — ESP + AUTO ACTIONS + ROUTES + DOOR WATCHER
    Версия: 8.3 (исправлены все баги, кнопки на месте)
    Для Delta Executor
--]]

if getgenv().ESP_LOADED then
    pcall(function()
        if getgenv().ESP and getgenv().ESP.Destroy then
            getgenv().ESP.Destroy()
        end
    end)
    task.wait(0.3)
end
getgenv().ESP_LOADED = true

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")
local CoreGui = game:GetService("CoreGui")
local GuiService = game:GetService("GuiService")
local VirtualInputManager = game:GetService("VirtualInputManager")
local LocalPlayer = Players.LocalPlayer
local Camera = workspace.CurrentCamera

-- ═══════════════════════════════════════════════════════
-- 🎨 ТЕМА
-- ═══════════════════════════════════════════════════════
local Theme = {
    Bg          = Color3.fromRGB(20, 20, 28),
    BgLight     = Color3.fromRGB(30, 30, 40),
    BgLighter   = Color3.fromRGB(42, 42, 55),
    Accent      = Color3.fromRGB(90, 130, 220),
    AccentHover = Color3.fromRGB(120, 160, 255),
    Success     = Color3.fromRGB(0, 180, 100),
    Danger      = Color3.fromRGB(210, 70, 70),
    Warning     = Color3.fromRGB(240, 170, 60),
    Text        = Color3.fromRGB(240, 240, 245),
    TextDim     = Color3.fromRGB(150, 150, 165),
    Border      = Color3.fromRGB(60, 60, 80),
    BoxColor    = Color3.fromRGB(0, 255, 100),
    HighlightColor = Color3.fromRGB(255, 0, 0),
}

-- ═══════════════════════════════════════════════════════
-- ⚙️ НАСТРОЙКИ
-- ═══════════════════════════════════════════════════════
local Settings = {
    Enabled = true,
    ShowName = true,
    ShowHealth = true,
    ShowDistance = true,
    ShowStatus = true,
    ShowHighlight = true,
    TeamCheck = false,
    MaxDistance = 1000,
    NameColor = Color3.fromRGB(255, 255, 255),
    HealthColor = Color3.fromRGB(0, 255, 0),
    TextSize = 14,
    HeadOffset = 3,

    AutoActions = false,
    TriggerRadius = 100,
    ApproachThreshold = 10,
    DoActivate = true,
    DoGiveTicket = true,
    DoCheckWeapon = true,
    DoDeactivate = true,
    WaitAfterActivate = 10,
    WaitBeforeCheck = 3,
    WaitBeforeDeactivate = 3,
    WaitLeftWithoutApproach = 5,
    QueueDelay = 5,
    IgnoreDuration = 40,

    Buttons = {
        Activate = nil,
        GiveTicket = nil,
        CheckWeapon = nil,
        Deactivate = nil,
        NumberUp = nil,
    },

    CrosshairColor = Color3.fromRGB(0, 255, 100),
    ShowClickIndicator = true,
    CrosshairOffsetY = 0,
    CrosshairOffsetX = 0,
}

local RouteSettings = {
    DoorName = "RoomExit",
    CurrentRoom = 1,
    StepSize = 10,
    StepDelay = 0.05,
    StopLeftOffset = 3,
    StopBackOffset = 2,
    StopHeightOffset = 3,
    HomePosition = nil,
    WatchDoors = true,
    DoorRotationThreshold = 5,
    DoorMoveThreshold = 1,
    ReturnHomeOnPlayerLeft = true,
    NumberUpRetryCount = 3,
    NumberUpRetryDelay = 0.5,
}

local Doors = {}
local DoorWatcherData = {}
local doorOpenHandled = {}

local ESPCache = {}
local ActionState = "idle"
local StateTimer = 0
local InitialDistance = 0
local ProcessedPlayers = {}
local IgnoredPlayers = {}
local Queue = {}
local CurrentTarget = nil

-- ═══════════════════════════════════════════════════════
-- 🔧 ХЕЛПЕРЫ
-- ═══════════════════════════════════════════════════════
local function addCorner(parent, radius)
    local c = Instance.new("UICorner")
    c.CornerRadius = UDim.new(0, radius or 8)
    c.Parent = parent
    return c
end

local function addStroke(parent, color, thickness)
    local s = Instance.new("UIStroke")
    s.Color = color or Theme.Border
    s.Thickness = thickness or 1
    s.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
    s.Parent = parent
    return s
end

local function makeDraggable(frame, handle)
    handle = handle or frame
    local dragging, dragStart, startPos
    handle.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1
           or input.UserInputType == Enum.UserInputType.Touch then
            dragging = true
            dragStart = input.Position
            startPos = frame.Position
        end
    end)
    handle.InputChanged:Connect(function(input)
        if dragging and (input.UserInputType == Enum.UserInputType.MouseMovement
           or input.UserInputType == Enum.UserInputType.Touch) then
            local delta = input.Position - dragStart
            frame.Position = UDim2.new(
                startPos.X.Scale, startPos.X.Offset + delta.X,
                startPos.Y.Scale, startPos.Y.Offset + delta.Y
            )
        end
    end)
    handle.InputEnded:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1
           or input.UserInputType == Enum.UserInputType.Touch then
            dragging = false
        end
    end)
end

-- ═══════════════════════════════════════════════════════
-- 📋 ЛОГ
-- ═══════════════════════════════════════════════════════
local ConsoleTab

local function log(text, color)
    if not ConsoleTab then
        print("[ESP] " .. tostring(text))
        return
    end
    local label = Instance.new("TextLabel")
    label.Size = UDim2.new(1, -8, 0, 20)
    label.BackgroundTransparency = 1
    label.Text = "> " .. tostring(text)
    label.TextColor3 = color or Theme.Text
    label.Font = Enum.Font.Code
    label.TextSize = 12
    label.TextXAlignment = Enum.TextXAlignment.Left
    label.Parent = ConsoleTab
    local children = ConsoleTab:GetChildren()
    if #children > 105 then
        for i = 1, 10 do
            if children[i] and children[i]:IsA("TextLabel") then
                children[i]:Destroy()
            end
        end
    end
end

-- ═══════════════════════════════════════════════════════
-- 🎯 ИНДИКАТОР КЛИКА
-- ═══════════════════════════════════════════════════════
local ClickIndicatorGui = Instance.new("ScreenGui")
ClickIndicatorGui.Name = "ESP_ClickIndicator"
ClickIndicatorGui.ResetOnSpawn = false
ClickIndicatorGui.IgnoreGuiInset = true
ClickIndicatorGui.DisplayOrder = 9999
pcall(function() ClickIndicatorGui.Parent = CoreGui end)
if not ClickIndicatorGui.Parent then ClickIndicatorGui.Parent = LocalPlayer:WaitForChild("PlayerGui") end

local function showClickIndicator(x, y)
    if not Settings.ShowClickIndicator then return end
    local dot = Instance.new("Frame")
    dot.Size = UDim2.new(0, 40, 0, 40)
    dot.Position = UDim2.new(0, x - 20, 0, y - 20)
    dot.BackgroundColor3 = Color3.fromRGB(255, 50, 50)
    dot.BackgroundTransparency = 0.4
    dot.BorderSizePixel = 3
    dot.BorderColor3 = Color3.fromRGB(255, 255, 0)
    dot.ZIndex = 10000
    dot.Parent = ClickIndicatorGui
    addCorner(dot, 20)
    task.spawn(function()
        task.wait(0.8)
        TweenService:Create(dot, TweenInfo.new(0.4), {
            BackgroundTransparency = 1,
            Size = UDim2.new(0, 60, 0, 60),
            Position = UDim2.new(0, x - 30, 0, y - 30),
        }):Play()
        task.wait(0.5)
        dot:Destroy()
    end)
end

-- ═══════════════════════════════════════════════════════
-- 🖱️ ТАП
-- ═══════════════════════════════════════════════════════
local function clickAtScreenPosition(x, y)
    if not x or not y then return false end
    local topInset = GuiService:GetGuiInset().Y
    local realX = x + (Settings.CrosshairOffsetX or 0)
    local realY = y + topInset + (Settings.CrosshairOffsetY or 0)
    showClickIndicator(realX, realY)

    local used = false
    pcall(function()
        if typeof(tap) == "function" then
            tap(realX, realY); used = true
        end
    end)
    if used then return true end

    pcall(function()
        if typeof(touch) == "function" then
            touch(realX, realY); used = true
        end
    end)
    if used then return true end

    pcall(function()
        VirtualInputManager:SendTouchEvent(
            Enum.UserInputType.Touch,
            Enum.UserInputState.Begin,
            Vector2.new(realX, realY)
        )
        task.wait(0.08)
        VirtualInputManager:SendTouchEvent(
            Enum.UserInputType.Touch,
            Enum.UserInputState.End,
            Vector2.new(realX, realY)
        )
    end)

    pcall(function()
        VirtualInputManager:SendMouseButtonEvent(realX, realY, 0, true, game, 1)
        task.wait(0.05)
        VirtualInputManager:SendMouseButtonEvent(realX, realY, 0, false, game, 1)
    end)

    return true
end

local function fireButtonAction(btnData)
    if not btnData or not btnData.Pos then return false end
    clickAtScreenPosition(btnData.Pos.X, btnData.Pos.Y)
    log("Tap X=" .. btnData.Pos.X .. ", Y=" .. btnData.Pos.Y, Theme.Success)
    return true
end

-- ═══════════════════════════════════════════════════════
-- 🎯 КЛИК ПО GUI-КНОПКЕ
-- ═══════════════════════════════════════════════════════
local function tryClickGuiButton(button)
    if not button or not button:IsA("GuiButton") then return false end

    log("Click: " .. button.ClassName .. " [" .. button.Name .. "]", Theme.Warning)
    local pos = button.AbsolutePosition + button.AbsoluteSize / 2

    pcall(function() button.Activated:Fire() end)
    task.wait(0.1)
    pcall(function() button.MouseButton1Click:Fire() end)
    task.wait(0.1)
    pcall(function()
        button.MouseButton1Down:Fire(pos.X, pos.Y)
        button.MouseButton1Up:Fire(pos.X, pos.Y)
    end)
    task.wait(0.1)
    pcall(function() if button.Activate then button:Activate() end end)
    task.wait(0.1)
    pcall(function() if button.Select then button:Select() end end)
    task.wait(0.1)

    pcall(function()
        local topInset = GuiService:GetGuiInset().Y
        local rx = pos.X + (Settings.CrosshairOffsetX or 0)
        local ry = pos.Y + topInset + (Settings.CrosshairOffsetY or 0)
        VirtualInputManager:SendMouseButtonEvent(rx, ry, 0, true, game, 1)
        task.wait(0.05)
        VirtualInputManager:SendMouseButtonEvent(rx, ry, 0, false, game, 1)
    end)

    pcall(function()
        for _, child in ipairs(button:GetDescendants()) do
            if child:IsA("RemoteEvent") then
                child:FireServer()
                log("  RemoteEvent: " .. child.Name, Theme.Success)
            end
        end
    end)

    return true
end

local function findButtonByName(namePattern)
    local found = {}
    local function scanGui(gui)
        pcall(function()
            if not gui:IsA("ScreenGui") then return end
            for _, desc in ipairs(gui:GetDescendants()) do
                if desc:IsA("GuiButton") and desc.Name:lower():find(namePattern:lower(), 1, true) then
                    table.insert(found, desc)
                end
            end
        end)
    end
    pcall(function()
        for _, gui in ipairs(LocalPlayer.PlayerGui:GetChildren()) do scanGui(gui) end
    end)
    pcall(function()
        for _, gui in ipairs(CoreGui:GetChildren()) do scanGui(gui) end
    end)
    return found
end

-- ═══════════════════════════════════════════════════════
-- 🚪 ДВЕРИ
-- ═══════════════════════════════════════════════════════
local function findDoors()
    Doors = {}
    local count = 0
    for _, obj in ipairs(workspace:GetDescendants()) do
        if obj.Name == RouteSettings.DoorName
           and (obj:IsA("BasePart") or obj:IsA("MeshPart")) then
            local fullPath = obj:GetFullName()
            local roomNum = tonumber(fullPath:match("Hotel%.(%d+)%."))
            if roomNum then
                Doors[roomNum] = {
                    Instance = obj, Position = obj.Position,
                    CFrame = obj.CFrame, FullPath = fullPath,
                }
                count = count + 1
            end
        end
    end
    return count
end

local function calculateStopPoint(door)
    if not door or not door.CFrame then return nil end
    local doorLook = door.CFrame.LookVector
    local doorRight = door.CFrame.RightVector
    return door.Position
        - doorLook * RouteSettings.StopBackOffset
        - doorRight * RouteSettings.StopLeftOffset
        + Vector3.new(0, RouteSettings.StopHeightOffset, 0)
end

local function buildPath(fromPos, toPos)
    local path = {}
    local totalDistance = (toPos - fromPos).Magnitude
    if totalDistance < RouteSettings.StepSize then
        table.insert(path, toPos)
        return path
    end
    local direction = (toPos - fromPos).Unit
    local steps = math.floor(totalDistance / RouteSettings.StepSize)
    for i = 1, steps do
        table.insert(path, fromPos + direction * RouteSettings.StepSize * i)
    end
    table.insert(path, toPos)
    return path
end

local function teleportAlongPath(path)
    local myChar = LocalPlayer.Character
    local myHRP = myChar and myChar:FindFirstChild("HumanoidRootPart")
    if not myHRP then return false end
    for _, point in ipairs(path) do
        if not myHRP or not myHRP.Parent then return false end
        myHRP.CFrame = CFrame.new(point)
        task.wait(RouteSettings.StepDelay)
    end
    return true
end

local function goToRoom(roomNum)
    roomNum = roomNum or RouteSettings.CurrentRoom
    if next(Doors) == nil then
        local c = findDoors()
        log("Doors found: " .. c, Theme.Success)
    end
    local door = Doors[roomNum]
    if not door then
        log("Door " .. roomNum .. " not found", Theme.Danger)
        return false
    end
    local myHRP = LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
    if not myHRP then return false end
    local stopPos = calculateStopPoint(door)
    if not stopPos then return false end
    log("Going to room " .. roomNum, Theme.Warning)
    local path = buildPath(myHRP.Position, stopPos)
    teleportAlongPath(path)
    log("Arrived at room " .. roomNum, Theme.Success)
    return true
end

local function goToNextRoom()
    RouteSettings.CurrentRoom = RouteSettings.CurrentRoom + 1
    log("Room: " .. RouteSettings.CurrentRoom, Theme.Warning)
    return goToRoom(RouteSettings.CurrentRoom)
end

-- ═══════════════════════════════════════════════════════
-- 👁️ WATCHER
-- ═══════════════════════════════════════════════════════
local function initDoorWatcher()
    DoorWatcherData = {}
    local count = 0
    for num, door in pairs(Doors) do
        if door.Instance and door.Instance.Parent then
            DoorWatcherData[door.Instance] = {
                Position = door.Instance.Position,
                Rotation = door.Instance.Orientation,
                RoomNum = num,
            }
            count = count + 1
        end
    end
    log("Watcher active for " .. count .. " doors", Theme.Success)
end

local function onDoorOpened(roomNum)
    local now = tick()
    if doorOpenHandled[roomNum] and now - doorOpenHandled[roomNum] < 3 then return end
    doorOpenHandled[roomNum] = now

    log("DOOR " .. roomNum .. " OPENED! NumberUp", Theme.Success)

    task.spawn(function()
        if Settings.Buttons.NumberUp and Settings.Buttons.NumberUp.Pos then
            log("Method 1: tap by coords", Theme.TextDim)
            for i = 1, (RouteSettings.NumberUpRetryCount or 3) do
                fireButtonAction(Settings.Buttons.NumberUp)
                task.wait(RouteSettings.NumberUpRetryDelay or 0.5)
            end
        end

        log("Method 2: search by name", Theme.TextDim)
        local btns = findButtonByName("NumberUp")
        if #btns == 0 then btns = findButtonByName("Increase") end
        if #btns == 0 then btns = findButtonByName("Up") end

        for _, btn in ipairs(btns) do
            log("  Found: " .. btn:GetFullName(), Theme.Success)
            tryClickGuiButton(btn)
            task.wait(0.3)
        end
    end)
end

local function checkDoorChanges()
    if not RouteSettings.WatchDoors then return end
    for doorInstance, data in pairs(DoorWatcherData) do
        if not doorInstance or not doorInstance.Parent then
            DoorWatcherData[doorInstance] = nil
        else
            local posDiff = (doorInstance.Position - data.Position).Magnitude
            local rotDiff = (doorInstance.Orientation - data.Rotation).Magnitude

            if posDiff > RouteSettings.DoorMoveThreshold or rotDiff > RouteSettings.DoorRotationThreshold then
                log(string.format("Door %s: pos=%.1f rot=%.1f", data.RoomNum, posDiff, rotDiff), Theme.Success)
                data.Position = doorInstance.Position
                data.Rotation = doorInstance.Orientation
                onDoorOpened(data.RoomNum)
            end
        end
    end
end

-- ═══════════════════════════════════════════════════════
-- 🏠 HOME
-- ═══════════════════════════════════════════════════════
local function setHomePosition(pos)
    RouteSettings.HomePosition = pos
    log("Home: " .. tostring(pos), Theme.Success)
end

local function teleportToHome()
    if not RouteSettings.HomePosition then
        log("Home not set", Theme.Warning)
        return false
    end
    local myHRP = LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
    if not myHRP then return false end
    local path = buildPath(myHRP.Position, RouteSettings.HomePosition)
    teleportAlongPath(path)
    log("Returned home", Theme.Success)
    return true
end

local function rememberHomeFromNow()
    local myHRP = LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
    if not myHRP then log("No character", Theme.Danger); return end
    setHomePosition(myHRP.Position)
end

-- ═══════════════════════════════════════════════════════
-- 🖥️ ГЛАВНОЕ ОКНО
-- ═══════════════════════════════════════════════════════
local MainGui = Instance.new("ScreenGui")
MainGui.Name = "ESP_MainUI"
MainGui.ResetOnSpawn = false
MainGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
pcall(function() MainGui.Parent = CoreGui end)
if not MainGui.Parent then MainGui.Parent = LocalPlayer:WaitForChild("PlayerGui") end

local MainFrame = Instance.new("Frame")
MainFrame.Size = UDim2.new(0, 480, 0, 420)
MainFrame.Position = UDim2.new(0.5, -240, 0.5, -210)
MainFrame.BackgroundColor3 = Theme.Bg
MainFrame.BorderSizePixel = 0
MainFrame.Active = true
MainFrame.Parent = MainGui
addCorner(MainFrame, 12)
addStroke(MainFrame, Theme.Border, 1.5)
makeDraggable(MainFrame)

local TitleBar = Instance.new("Frame")
TitleBar.Size = UDim2.new(1, 0, 0, 42)
TitleBar.BackgroundColor3 = Theme.BgLight
TitleBar.BorderSizePixel = 0
TitleBar.Parent = MainFrame
addCorner(TitleBar, 12)

local TitleFix = Instance.new("Frame")
TitleFix.Size = UDim2.new(1, 0, 0, 12)
TitleFix.Position = UDim2.new(0, 0, 1, -12)
TitleFix.BackgroundColor3 = Theme.BgLight
TitleFix.BorderSizePixel = 0
TitleFix.Parent = TitleBar

local TitleIcon = Instance.new("TextLabel")
TitleIcon.Text = "ESP"
TitleIcon.Size = UDim2.new(0, 50, 1, 0)
TitleIcon.Position = UDim2.new(0, 12, 0, 0)
TitleIcon.BackgroundTransparency = 1
TitleIcon.TextColor3 = Theme.Accent
TitleIcon.Font = Enum.Font.GothamBold
TitleIcon.TextSize = 16
TitleIcon.TextXAlignment = Enum.TextXAlignment.Left
TitleIcon.Parent = TitleBar

local Title = Instance.new("TextLabel")
Title.Text = "ESP + AUTO ACTIONS v8.3"
Title.Size = UDim2.new(1, -150, 1, 0)
Title.Position = UDim2.new(0, 60, 0, 0)
Title.BackgroundTransparency = 1
Title.TextColor3 = Theme.Text
Title.Font = Enum.Font.GothamBold
Title.TextSize = 14
Title.TextXAlignment = Enum.TextXAlignment.Left
Title.Parent = TitleBar

local MinimizeBtn = Instance.new("TextButton")
MinimizeBtn.Text = "—"
MinimizeBtn.Size = UDim2.new(0, 28, 0, 28)
MinimizeBtn.Position = UDim2.new(1, -66, 0.5, -14)
MinimizeBtn.BackgroundColor3 = Theme.BgLighter
MinimizeBtn.TextColor3 = Theme.Text
MinimizeBtn.Font = Enum.Font.GothamBold
MinimizeBtn.TextSize = 16
MinimizeBtn.BorderSizePixel = 0
MinimizeBtn.Parent = TitleBar
addCorner(MinimizeBtn, 6)

local CloseBtn = Instance.new("TextButton")
CloseBtn.Text = "X"
CloseBtn.Size = UDim2.new(0, 28, 0, 28)
CloseBtn.Position = UDim2.new(1, -34, 0.5, -14)
CloseBtn.BackgroundColor3 = Theme.Danger
CloseBtn.TextColor3 = Theme.Text
CloseBtn.Font = Enum.Font.GothamBold
CloseBtn.TextSize = 14
CloseBtn.BorderSizePixel = 0
CloseBtn.Parent = TitleBar
addCorner(CloseBtn, 6)

local TabBar = Instance.new("Frame")
TabBar.Size = UDim2.new(1, -24, 0, 36)
TabBar.Position = UDim2.new(0, 12, 0, 50)
TabBar.BackgroundColor3 = Theme.BgLight
TabBar.BorderSizePixel = 0
TabBar.Parent = MainFrame
addCorner(TabBar, 8)

local ContentFrame = Instance.new("Frame")
ContentFrame.Size = UDim2.new(1, -24, 1, -108)
ContentFrame.Position = UDim2.new(0, 12, 0, 94)
ContentFrame.BackgroundColor3 = Theme.BgLight
ContentFrame.BorderSizePixel = 0
ContentFrame.Parent = MainFrame
addCorner(ContentFrame, 10)

ConsoleTab = Instance.new("ScrollingFrame")
ConsoleTab.Size = UDim2.new(1, -12, 1, -12)
ConsoleTab.Position = UDim2.new(0, 6, 0, 6)
ConsoleTab.BackgroundTransparency = 1
ConsoleTab.BorderSizePixel = 0
ConsoleTab.ScrollBarThickness = 5
ConsoleTab.ScrollBarImageColor3 = Theme.Accent
ConsoleTab.CanvasSize = UDim2.new(0, 0, 0, 0)
ConsoleTab.AutomaticCanvasSize = Enum.AutomaticSize.Y
ConsoleTab.Visible = true
ConsoleTab.Parent = ContentFrame

local ConsoleLayout = Instance.new("UIListLayout")
ConsoleLayout.Padding = UDim.new(0, 3)
ConsoleLayout.SortOrder = Enum.SortOrder.LayoutOrder
ConsoleLayout.Parent = ConsoleTab

log("Console ready", Theme.TextDim)

local TestTab = Instance.new("ScrollingFrame")
TestTab.Size = UDim2.new(1, -12, 1, -12)
TestTab.Position = UDim2.new(0, 6, 0, 6)
TestTab.BackgroundTransparency = 1
TestTab.BorderSizePixel = 0
TestTab.ScrollBarThickness = 5
TestTab.ScrollBarImageColor3 = Theme.Accent
TestTab.CanvasSize = UDim2.new(0, 0, 0, 0)
TestTab.AutomaticCanvasSize = Enum.AutomaticSize.Y
TestTab.Visible = false
TestTab.Parent = ContentFrame

local TestLayout = Instance.new("UIListLayout")
TestLayout.Padding = UDim.new(0, 8)
TestLayout.Parent = TestTab

local SettingsTab = Instance.new("ScrollingFrame")
SettingsTab.Size = UDim2.new(1, -12, 1, -12)
SettingsTab.Position = UDim2.new(0, 6, 0, 6)
SettingsTab.BackgroundTransparency = 1
SettingsTab.BorderSizePixel = 0
SettingsTab.ScrollBarThickness = 5
SettingsTab.ScrollBarImageColor3 = Theme.Accent
SettingsTab.CanvasSize = UDim2.new(0, 0, 0, 0)
SettingsTab.AutomaticCanvasSize = Enum.AutomaticSize.Y
SettingsTab.Visible = false
SettingsTab.Parent = ContentFrame

local SettingsLayout = Instance.new("UIListLayout")
SettingsLayout.Padding = UDim.new(0, 6)
SettingsLayout.Parent = SettingsTab

-- ═══════════════════════════════════════════════════════
-- 🧱 UI-КОМПОНЕНТЫ
-- ═══════════════════════════════════════════════════════
local function makeSection(parent, text)
    local s = Instance.new("TextLabel")
    s.Text = "  " .. text
    s.Size = UDim2.new(1, 0, 0, 26)
    s.BackgroundColor3 = Theme.Bg
    s.TextColor3 = Theme.Accent
    s.Font = Enum.Font.GothamBold
    s.TextSize = 12
    s.TextXAlignment = Enum.TextXAlignment.Left
    s.BorderSizePixel = 0
    s.Parent = parent
    addCorner(s, 6)
    return s
end

local function makeButton(parent, text, callback, color)
    local btn = Instance.new("TextButton")
    btn.Text = text
    btn.Size = UDim2.new(1, 0, 0, 38)
    btn.BackgroundColor3 = color or Theme.BgLighter
    btn.TextColor3 = Theme.Text
    btn.Font = Enum.Font.GothamBold
    btn.TextSize = 13
    btn.BorderSizePixel = 0
    btn.AutoButtonColor = false
    btn.Parent = parent
    addCorner(btn, 8)
    btn:SetAttribute("BaseColor", color or Theme.BgLighter)
    btn.MouseEnter:Connect(function()
        TweenService:Create(btn, TweenInfo.new(0.15), {
            BackgroundColor3 = Theme.AccentHover
        }):Play()
    end)
    btn.MouseLeave:Connect(function()
        TweenService:Create(btn, TweenInfo.new(0.15), {
            BackgroundColor3 = btn:GetAttribute("BaseColor")
        }):Play()
    end)
    btn.MouseButton1Click:Connect(function()
        pcall(callback)
    end)
    return btn
end

local function makeToggle(parent, text, default, callback)
    local row = Instance.new("Frame")
    row.Size = UDim2.new(1, 0, 0, 34)
    row.BackgroundColor3 = Theme.Bg
    row.BorderSizePixel = 0
    row.Parent = parent
    addCorner(row, 8)

    local lbl = Instance.new("TextLabel")
    lbl.Text = text
    lbl.Size = UDim2.new(1, -80, 1, 0)
    lbl.Position = UDim2.new(0, 12, 0, 0)
    lbl.BackgroundTransparency = 1
    lbl.TextColor3 = Theme.Text
    lbl.Font = Enum.Font.Gotham
    lbl.TextSize = 13
    lbl.TextXAlignment = Enum.TextXAlignment.Left
    lbl.Parent = row

    local state = default
    local toggle = Instance.new("TextButton")
    toggle.Size = UDim2.new(0, 54, 0, 22)
    toggle.Position = UDim2.new(1, -64, 0.5, -11)
    toggle.BackgroundColor3 = state and Theme.Success or Theme.BgLighter
    toggle.Text = state and "ON" or "OFF"
    toggle.TextColor3 = Theme.Text
    toggle.Font = Enum.Font.GothamBold
    toggle.TextSize = 11
    toggle.BorderSizePixel = 0
    toggle.AutoButtonColor = false
    toggle.Parent = row
    addCorner(toggle, 11)
    toggle.MouseButton1Click:Connect(function()
        state = not state
        TweenService:Create(toggle, TweenInfo.new(0.15), {
            BackgroundColor3 = state and Theme.Success or Theme.BgLighter
        }):Play()
        toggle.Text = state and "ON" or "OFF"
        pcall(callback, state)
    end)
    return row
end

local function makeInput(parent, text, default, callback)
    local row = Instance.new("Frame")
    row.Size = UDim2.new(1, 0, 0, 34)
    row.BackgroundColor3 = Theme.Bg
    row.BorderSizePixel = 0
    row.Parent = parent
    addCorner(row, 8)

    local lbl = Instance.new("TextLabel")
    lbl.Text = text
    lbl.Size = UDim2.new(0.55, -12, 1, 0)
    lbl.Position = UDim2.new(0, 12, 0, 0)
    lbl.BackgroundTransparency = 1
    lbl.TextColor3 = Theme.Text
    lbl.Font = Enum.Font.Gotham
    lbl.TextSize = 12
    lbl.TextXAlignment = Enum.TextXAlignment.Left
    lbl.Parent = row

    local input = Instance.new("TextBox")
    input.Size = UDim2.new(0.45, -12, 0, 24)
    input.Position = UDim2.new(0.55, 0, 0.5, -12)
    input.BackgroundColor3 = Theme.BgLighter
    input.Text = tostring(default or 0)
    input.TextColor3 = Theme.Text
    input.Font = Enum.Font.Gotham
    input.TextSize = 12
    input.BorderSizePixel = 0
    input.ClearTextOnFocus = false
    input.Parent = row
    addCorner(input, 6)

    input.FocusLost:Connect(function()
        local num = tonumber(input.Text)
        if num then pcall(callback, num) end
    end)
    return row
end

-- ═══════════════════════════════════════════════════════
-- 🎯 ПРИЦЕЛ
-- ═══════════════════════════════════════════════════════
local CrosshairGui = Instance.new("ScreenGui")
CrosshairGui.Name = "ESP_Crosshair"
CrosshairGui.ResetOnSpawn = false
CrosshairGui.IgnoreGuiInset = true
CrosshairGui.DisplayOrder = 999
CrosshairGui.Enabled = false
pcall(function() CrosshairGui.Parent = CoreGui end)
if not CrosshairGui.Parent then CrosshairGui.Parent = LocalPlayer:WaitForChild("PlayerGui") end

local CrossHandle = Instance.new("TextButton")
CrossHandle.Size = UDim2.new(0, 80, 0, 80)
CrossHandle.Position = UDim2.new(0.5, -40, 0.5, -40)
CrossHandle.BackgroundTransparency = 1
CrossHandle.Text = ""
CrossHandle.AutoButtonColor = false
CrossHandle.Active = true
CrossHandle.Parent = CrosshairGui

local CrossH = Instance.new("Frame")
CrossH.Size = UDim2.new(0, 60, 0, 2)
CrossH.Position = UDim2.new(0.5, -30, 0.5, -1)
CrossH.BackgroundColor3 = Settings.CrosshairColor
CrossH.BorderSizePixel = 0
CrossH.Parent = CrossHandle

local CrossV = Instance.new("Frame")
CrossV.Size = UDim2.new(0, 2, 0, 60)
CrossV.Position = UDim2.new(0.5, -1, 0.5, -30)
CrossV.BackgroundColor3 = Settings.CrosshairColor
CrossV.BorderSizePixel = 0
CrossV.Parent = CrossHandle

local CrossDot = Instance.new("Frame")
CrossDot.Size = UDim2.new(0, 8, 0, 8)
CrossDot.Position = UDim2.new(0.5, -4, 0.5, -4)
CrossDot.BackgroundColor3 = Color3.fromRGB(255, 255, 0)
CrossDot.BorderSizePixel = 0
CrossDot.Parent = CrossHandle
addCorner(CrossDot, 4)

local isDragging = false
local dragStart, startPos
CrossHandle.InputBegan:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1
       or input.UserInputType == Enum.UserInputType.Touch then
        isDragging = true
        dragStart = input.Position
        startPos = CrossHandle.Position
    end
end)
CrossHandle.InputChanged:Connect(function(input)
    if isDragging and (input.UserInputType == Enum.UserInputType.MouseMovement
       or input.UserInputType == Enum.UserInputType.Touch) then
        local delta = input.Position - dragStart
        CrossHandle.Position = UDim2.new(
            startPos.X.Scale, startPos.X.Offset + delta.X,
            startPos.Y.Scale, startPos.Y.Offset + delta.Y
        )
    end
end)
CrossHandle.InputEnded:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1
       or input.UserInputType == Enum.UserInputType.Touch then
        isDragging = false
    end
end)

local CrossPanel = Instance.new("Frame")
CrossPanel.Size = UDim2.new(0, 320, 0, 130)
CrossPanel.Position = UDim2.new(0.5, -160, 1, -150)
CrossPanel.BackgroundColor3 = Theme.Bg
CrossPanel.BackgroundTransparency = 0.05
CrossPanel.BorderSizePixel = 0
CrossPanel.ZIndex = 50
CrossPanel.Parent = CrosshairGui
addCorner(CrossPanel, 12)
addStroke(CrossPanel, Theme.Accent, 2)
makeDraggable(CrossPanel)

local CrossTitleLbl = Instance.new("TextLabel")
CrossTitleLbl.Text = "CROSSHAIR"
CrossTitleLbl.Size = UDim2.new(1, -20, 0, 24)
CrossTitleLbl.Position = UDim2.new(0, 10, 0, 6)
CrossTitleLbl.BackgroundTransparency = 1
CrossTitleLbl.TextColor3 = Theme.Text
CrossTitleLbl.Font = Enum.Font.GothamBold
CrossTitleLbl.TextSize = 13
CrossTitleLbl.TextXAlignment = Enum.TextXAlignment.Center
CrossTitleLbl.Parent = CrossPanel

local CoordLabel = Instance.new("TextLabel")
CoordLabel.Size = UDim2.new(1, -20, 0, 22)
CoordLabel.Position = UDim2.new(0, 10, 0, 32)
CoordLabel.BackgroundTransparency = 1
CoordLabel.Text = "X: - Y: -"
CoordLabel.TextColor3 = Color3.fromRGB(255, 255, 100)
CoordLabel.Font = Enum.Font.Code
CoordLabel.TextSize = 14
CoordLabel.Parent = CrossPanel

local OffsetInfo = Instance.new("TextLabel")
OffsetInfo.Size = UDim2.new(1, -20, 0, 18)
OffsetInfo.Position = UDim2.new(0, 10, 0, 54)
OffsetInfo.BackgroundTransparency = 1
OffsetInfo.Text = "Offset X: 0 Y: 0"
OffsetInfo.TextColor3 = Theme.TextDim
OffsetInfo.Font = Enum.Font.Code
OffsetInfo.TextSize = 11
OffsetInfo.Parent = CrossPanel

local SelectBtn = Instance.new("TextButton")
SelectBtn.Text = "Select current coordinates"
SelectBtn.Size = UDim2.new(1, -20, 0, 34)
SelectBtn.Position = UDim2.new(0, 10, 1, -42)
SelectBtn.BackgroundColor3 = Theme.Accent
SelectBtn.TextColor3 = Theme.Text
SelectBtn.Font = Enum.Font.GothamBold
SelectBtn.TextSize = 12
SelectBtn.BorderSizePixel = 0
SelectBtn.AutoButtonColor = false
SelectBtn.Parent = CrossPanel
addCorner(SelectBtn, 8)

-- ✅ ВАЖНО: объявляем переменные ЗАРАНЕЕ, чтобы замыкания их видели
local currentPickKey = nil
local currentPickName = nil
local refreshButtonLabels = function() end
local openCrosshairPicker -- объявляем, значение присвоим позже

SelectBtn.MouseButton1Click:Connect(function()
    if not currentPickKey then return end
    local pos = CrossHandle.AbsolutePosition + CrossHandle.AbsoluteSize / 2
    local x, y = math.floor(pos.X), math.floor(pos.Y)
    Settings.Buttons[currentPickKey] = {Pos = {X = x, Y = y}}
    log(string.format("%s: X=%d, Y=%d", currentPickName, x, y), Theme.Success)

    if refreshButtonLabels then refreshButtonLabels() end

    CrosshairGui.Enabled = false
    MainGui.Enabled = true
    currentPickKey = nil
    currentPickName = nil
end)

-- ✅ присваиваем значение (замыкание уже видит переменную)
openCrosshairPicker = function(key, displayName)
    currentPickKey = key
    currentPickName = displayName
    CrossTitleLbl.Text = "CROSSHAIR - " .. displayName
    CrosshairGui.Enabled = true
    MainGui.Enabled = false
    CrossHandle.Position = UDim2.new(0.5, -40, 0.5, -40)
    log("Drag crosshair and press Select", Theme.Warning)
end

RunService.RenderStepped:Connect(function()
    if not CrosshairGui.Enabled then return end
    local pos = CrossHandle.AbsolutePosition + CrossHandle.AbsoluteSize / 2
    CoordLabel.Text = string.format("X: %d   Y: %d", pos.X, pos.Y)
    OffsetInfo.Text = string.format("Offset X: %d  Y: %d",
        Settings.CrosshairOffsetX or 0, Settings.CrosshairOffsetY or 0)
end)

-- ═══════════════════════════════════════════════════════
-- 🎨 ESP
-- ═══════════════════════════════════════════════════════
local function createESP(player)
    if player == LocalPlayer then return end
    if ESPCache[player] then return end

    local esp = {}

    local highlight = Instance.new("Highlight")
    highlight.Name = "ESP_Highlight"
    highlight.FillColor = Settings.HighlightColor
    highlight.FillTransparency = 0.85
    highlight.OutlineColor = Theme.BoxColor
    highlight.OutlineTransparency = 0
    highlight.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
    highlight.Enabled = false
    highlight.Parent = MainGui

    esp.Highlight = highlight

    local billboard = Instance.new("BillboardGui")
    billboard.Name = "ESP_Billboard"
    billboard.AlwaysOnTop = true
    billboard.Size = UDim2.new(0, 200, 0, 90)
    billboard.StudsOffsetWorldSpace = Vector3.new(0, 3.2, 0)
    billboard.Enabled = false
    billboard.Parent = MainGui

    local bg = Instance.new("Frame")
    bg.Size = UDim2.new(1, -20, 1, -10)
    bg.Position = UDim2.new(0, 10, 0, 5)
    bg.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
    bg.BackgroundTransparency = 0.6
    bg.BorderSizePixel = 0
    bg.Parent = billboard
    addCorner(bg, 6)

    local statusLabel = Instance.new("TextLabel")
    statusLabel.Size = UDim2.new(1, 0, 0, 22)
    statusLabel.Position = UDim2.new(0, 0, 0, 0)
    statusLabel.BackgroundTransparency = 1
    statusLabel.Font = Enum.Font.GothamBold
    statusLabel.TextSize = 15
    statusLabel.TextColor3 = Color3.fromRGB(255, 220, 80)
    statusLabel.TextStrokeTransparency = 0
    statusLabel.TextStrokeColor3 = Color3.fromRGB(0, 0, 0)
    statusLabel.Text = ""
    statusLabel.Visible = false
    statusLabel.Parent = billboard

    local nameLabel = Instance.new("TextLabel")
    nameLabel.Size = UDim2.new(1, 0, 0, 22)
    nameLabel.Position = UDim2.new(0, 0, 0, 22)
    nameLabel.BackgroundTransparency = 1
    nameLabel.Font = Enum.Font.GothamBold
    nameLabel.TextSize = Settings.TextSize
    nameLabel.TextColor3 = Settings.NameColor
    nameLabel.TextStrokeTransparency = 0
    nameLabel.TextStrokeColor3 = Color3.fromRGB(0, 0, 0)
    nameLabel.Parent = billboard

    local distLabel = Instance.new("TextLabel")
    distLabel.Size = UDim2.new(1, 0, 0, 18)
    distLabel.Position = UDim2.new(0, 0, 0, 44)
    distLabel.BackgroundTransparency = 1
    distLabel.Font = Enum.Font.Gotham
    distLabel.TextSize = Settings.TextSize - 3
    distLabel.TextColor3 = Color3.fromRGB(200, 200, 200)
    distLabel.TextStrokeTransparency = 0
    distLabel.TextStrokeColor3 = Color3.fromRGB(0, 0, 0)
    distLabel.Parent = billboard

    local healthBg = Instance.new("Frame")
    healthBg.BackgroundColor3 = Color3.fromRGB(40, 40, 40)
    healthBg.BorderSizePixel = 0
    healthBg.Size = UDim2.new(1, -20, 0, 6)
    healthBg.Position = UDim2.new(0, 10, 0, 66)
    healthBg.Parent = billboard
    addCorner(healthBg, 3)

    local healthFill = Instance.new("Frame")
    healthFill.BackgroundColor3 = Settings.HealthColor
    healthFill.BorderSizePixel = 0
    healthFill.Size = UDim2.new(1, 0, 1, 0)
    healthFill.Parent = healthBg
    addCorner(healthFill, 3)

    esp.Billboard = billboard
    esp.StatusLabel = statusLabel
    esp.NameLabel = nameLabel
    esp.DistLabel = distLabel
    esp.HealthBg = healthBg
    esp.HealthFill = healthFill
    esp.StatusText = ""

    ESPCache[player] = esp

    if player.Character then
        highlight.Adornee = player.Character
        local head = player.Character:FindFirstChild("Head")
        if head then
            billboard.Adornee = head
        end
    end

    player.CharacterAdded:Connect(function(character)
        task.wait(0.5)
        if esp.Highlight then esp.Highlight.Adornee = character end
        local head = character:WaitForChild("Head", 5)
        if head and esp.Billboard then esp.Billboard.Adornee = head end
    end)
end

local function removeESP(player)
    local esp = ESPCache[player]
    if not esp then return end
    if esp.Highlight then esp.Highlight:Destroy() end
    if esp.Billboard then esp.Billboard:Destroy() end
    ESPCache[player] = nil
end

local function setPlayerStatus(player, text, color)
    local esp = ESPCache[player]
    if not esp or not esp.StatusLabel then return end
    esp.StatusText = text or ""
    esp.StatusLabel.Text = text or ""
    esp.StatusLabel.TextColor3 = color or Color3.fromRGB(255, 220, 80)
    esp.StatusLabel.Visible = (text and text ~= "")
end

local function clearPlayerStatus(player)
    setPlayerStatus(player, "", nil)
end

-- ═══════════════════════════════════════════════════════
-- 📋 ВКЛАДКА "ТЕСТ"
-- ═══════════════════════════════════════════════════════
local function makeTestBtn(text, callback, color)
    return makeButton(TestTab, text, callback, color)
end

makeSection(TestTab, "ROUTE")

makeTestBtn("Go to room", function()
    goToRoom(RouteSettings.CurrentRoom)
end, Theme.Success)

makeTestBtn("Next room", function()
    goToNextRoom()
end, Theme.Warning)

makeTestBtn("Remember Home (current pos)", function()
    rememberHomeFromNow()
end, Theme.Accent)

makeTestBtn("Teleport to Home", function()
    teleportToHome()
end, Theme.Warning)

makeTestBtn("Start Door Watcher", function()
    local c = findDoors()
    log("Doors found: " .. c, Theme.Success)
    initDoorWatcher()
end, Theme.Accent)

makeTestBtn("Test NumberUp click", function()
    local btns = findButtonByName("NumberUp")
    if #btns == 0 then btns = findButtonByName("Increase") end
    if #btns == 0 then btns = findButtonByName("Up") end
    if #btns == 0 then
        log("Button not found", Theme.Danger)
        if Settings.Buttons.NumberUp then
            fireButtonAction(Settings.Buttons.NumberUp)
        end
        return
    end
    for _, btn in ipairs(btns) do
        log("Found: " .. btn:GetFullName(), Theme.Success)
        tryClickGuiButton(btn)
    end
end, Theme.Warning)

makeSection(TestTab, "BUTTON COORDS")

makeTestBtn("Test Activate", function()
    if Settings.Buttons.Activate then fireButtonAction(Settings.Buttons.Activate)
    else log("Coords not set", Theme.Danger) end
end)

makeTestBtn("Test GiveTicket", function()
    if Settings.Buttons.GiveTicket then fireButtonAction(Settings.Buttons.GiveTicket)
    else log("Coords not set", Theme.Danger) end
end)

makeTestBtn("Test CheckWeapon", function()
    if Settings.Buttons.CheckWeapon then fireButtonAction(Settings.Buttons.CheckWeapon)
    else log("Coords not set", Theme.Danger) end
end)

makeTestBtn("Test Deactivate", function()
    if Settings.Buttons.Deactivate then fireButtonAction(Settings.Buttons.Deactivate)
    else log("Coords not set", Theme.Danger) end
end)

makeTestBtn("Test NumberUp", function()
    if Settings.Buttons.NumberUp then fireButtonAction(Settings.Buttons.NumberUp)
    else log("Coords not set", Theme.Danger) end
end)

makeTestBtn("Reset state", function()
    ActionState = "idle"
    StateTimer = 0
    ProcessedPlayers = {}
    IgnoredPlayers = {}
    Queue = {}
    doorOpenHandled = {}
    CurrentTarget = nil
    log("State reset", Theme.Warning)
end, Theme.Danger)

-- ═══════════════════════════════════════════════════════
-- 📋 ВКЛАДКА "НАСТРОЙКИ"
-- ═══════════════════════════════════════════════════════

makeSection(SettingsTab, "BUTTON COORDS")

local buttonLabelRefs = {}

local function makeButtonSetter(name, key)
    local row = Instance.new("Frame")
    row.Size = UDim2.new(1, 0, 0, 34)
    row.BackgroundColor3 = Theme.Bg
    row.BorderSizePixel = 0
    row.Parent = SettingsTab
    addCorner(row, 8)

    local lbl = Instance.new("TextLabel")
    lbl.Text = name
    lbl.Size = UDim2.new(0.5, -12, 1, 0)
    lbl.Position = UDim2.new(0, 12, 0, 0)
    lbl.BackgroundTransparency = 1
    lbl.TextColor3 = Theme.Text
    lbl.Font = Enum.Font.Gotham
    lbl.TextSize = 12
    lbl.TextXAlignment = Enum.TextXAlignment.Left
    lbl.Parent = row

    local btn = Instance.new("TextButton")
    btn.Size = UDim2.new(0.5, -12, 0, 24)
    btn.Position = UDim2.new(0.5, 0, 0.5, -12)
    btn.BackgroundColor3 = Settings.Buttons[key] and Theme.Success or Theme.Warning
    btn.Text = Settings.Buttons[key] and "SET" or "Select"
    btn.TextColor3 = Theme.Text
    btn.Font = Enum.Font.GothamBold
    btn.TextSize = 11
    btn.BorderSizePixel = 0
    btn.AutoButtonColor = false
    btn.Parent = row
    addCorner(btn, 6)

    btn.MouseButton1Click:Connect(function()
        -- ✅ openCrosshairPicker уже объявлена заранее
        if openCrosshairPicker then
            openCrosshairPicker(key, name)
        end
    end)

    buttonLabelRefs[key] = {btn = btn, name = name}
end

-- ✅ переопределяем refreshButtonLabels (объявлена ранее как пустая функция)
refreshButtonLabels = function()
    for key, ref in pairs(buttonLabelRefs) do
        if ref and ref.btn then
            local data = Settings.Buttons[key]
            if data and data.Pos then
                ref.btn.Text = string.format("X=%d Y=%d", data.Pos.X, data.Pos.Y)
                ref.btn.BackgroundColor3 = Theme.Success
            else
                ref.btn.Text = "Select"
                ref.btn.BackgroundColor3 = Theme.Warning
            end
        end
    end
end

makeButtonSetter("Activate", "Activate")
makeButtonSetter("GiveTicket", "GiveTicket")
makeButtonSetter("CheckWeapon", "CheckWeapon")
makeButtonSetter("Deactivate", "Deactivate")
makeButtonSetter("NumberUp", "NumberUp")

refreshButtonLabels()

makeSection(SettingsTab, "TAP OFFSETS")
makeInput(SettingsTab, "Offset X (e.g. -50)", Settings.CrosshairOffsetX, function(v)
    Settings.CrosshairOffsetX = v
    log("Offset X: " .. v, Theme.Warning)
end)
makeInput(SettingsTab, "Offset Y (e.g. 50)", Settings.CrosshairOffsetY, function(v)
    Settings.CrosshairOffsetY = v
    log("Offset Y: " .. v, Theme.Warning)
end)

makeSection(SettingsTab, "HOME POSITION")
makeInput(SettingsTab, "Home X", RouteSettings.HomePosition and RouteSettings.HomePosition.X or 0, function(v)
    local y = RouteSettings.HomePosition and RouteSettings.HomePosition.Y or 0
    local z = RouteSettings.HomePosition and RouteSettings.HomePosition.Z or 0
    setHomePosition(Vector3.new(v, y, z))
end)
makeInput(SettingsTab, "Home Y", RouteSettings.HomePosition and RouteSettings.HomePosition.Y or 0, function(v)
    local x = RouteSettings.HomePosition and RouteSettings.HomePosition.X or 0
    local z = RouteSettings.HomePosition and RouteSettings.HomePosition.Z or 0
    setHomePosition(Vector3.new(x, v, z))
end)
makeInput(SettingsTab, "Home Z", RouteSettings.HomePosition and RouteSettings.HomePosition.Z or 0, function(v)
    local x = RouteSettings.HomePosition and RouteSettings.HomePosition.X or 0
    local y = RouteSettings.HomePosition and RouteSettings.HomePosition.Y or 0
    setHomePosition(Vector3.new(x, y, v))
end)

makeSection(SettingsTab, "DOOR WATCHER")
makeToggle(SettingsTab, "Watch doors", RouteSettings.WatchDoors, function(v)
    RouteSettings.WatchDoors = v
    if v then initDoorWatcher() end
end)
makeInput(SettingsTab, "Rotation threshold (deg)", RouteSettings.DoorRotationThreshold, function(v) RouteSettings.DoorRotationThreshold = v end)
makeInput(SettingsTab, "Move threshold (studs)", RouteSettings.DoorMoveThreshold, function(v) RouteSettings.DoorMoveThreshold = v end)
makeInput(SettingsTab, "NumberUp retries", RouteSettings.NumberUpRetryCount, function(v) RouteSettings.NumberUpRetryCount = v end)
makeInput(SettingsTab, "Retry delay (sec)", RouteSettings.NumberUpRetryDelay, function(v) RouteSettings.NumberUpRetryDelay = v end)
makeToggle(SettingsTab, "Return home on player left", RouteSettings.ReturnHomeOnPlayerLeft, function(v) RouteSettings.ReturnHomeOnPlayerLeft = v end)

makeSection(SettingsTab, "AUTO ACTIONS")
makeToggle(SettingsTab, "Auto Actions ON", Settings.AutoActions, function(v)
    Settings.AutoActions = v
    log("Auto: " .. (v and "ON" or "OFF"), v and Theme.Success or Theme.TextDim)
end)
makeToggle(SettingsTab, "Press Activate", Settings.DoActivate, function(v) Settings.DoActivate = v end)
makeToggle(SettingsTab, "Press GiveTicket", Settings.DoGiveTicket, function(v) Settings.DoGiveTicket = v end)
makeToggle(SettingsTab, "Press CheckWeapon", Settings.DoCheckWeapon, function(v) Settings.DoCheckWeapon = v end)
makeToggle(SettingsTab, "Press Deactivate", Settings.DoDeactivate, function(v) Settings.DoDeactivate = v end)

makeSection(SettingsTab, "PARAMETERS")
makeInput(SettingsTab, "Trigger radius (m)", Settings.TriggerRadius, function(v) Settings.TriggerRadius = v end)
makeInput(SettingsTab, "Approach threshold (m)", Settings.ApproachThreshold, function(v) Settings.ApproachThreshold = v end)
makeInput(SettingsTab, "Wait after Activate (s)", Settings.WaitAfterActivate, function(v) Settings.WaitAfterActivate = v end)
makeInput(SettingsTab, "Wait before Check (s)", Settings.WaitBeforeCheck, function(v) Settings.WaitBeforeCheck = v end)
makeInput(SettingsTab, "Wait before Deactivate (s)", Settings.WaitBeforeDeactivate, function(v) Settings.WaitBeforeDeactivate = v end)
makeInput(SettingsTab, "Wait if left (s)", Settings.WaitLeftWithoutApproach, function(v) Settings.WaitLeftWithoutApproach = v end)
makeInput(SettingsTab, "Queue delay (s)", Settings.QueueDelay, function(v) Settings.QueueDelay = v end)
makeInput(SettingsTab, "Ignore after deact (s)", Settings.IgnoreDuration, function(v) Settings.IgnoreDuration = v end)

makeSection(SettingsTab, "ESP")
makeToggle(SettingsTab, "ESP ON", Settings.Enabled, function(v) Settings.Enabled = v end)
makeToggle(SettingsTab, "Show name", Settings.ShowName, function(v) Settings.ShowName = v end)
makeToggle(SettingsTab, "Show health", Settings.ShowHealth, function(v) Settings.ShowHealth = v end)
makeToggle(SettingsTab, "Show distance", Settings.ShowDistance, function(v) Settings.ShowDistance = v end)
makeToggle(SettingsTab, "Show status", Settings.ShowStatus, function(v) Settings.ShowStatus = v end)
makeToggle(SettingsTab, "Show highlight", Settings.ShowHighlight, function(v) Settings.ShowHighlight = v end)

-- ═══════════════════════════════════════════════════════
-- 🔄 ОСНОВНОЙ ЦИКЛ
-- ═══════════════════════════════════════════════════════
RunService.RenderStepped:Connect(function(dt)
    -- ESP
    if Settings.Enabled then
        for player, esp in pairs(ESPCache) do
            local char = player.Character
            local hrp = char and char:FindFirstChild("HumanoidRootPart")
            local head = char and char:FindFirstChild("Head")
            local hum = char and char:FindFirstChildOfClass("Humanoid")

            if not hrp or not head or not hum or hum.Health <= 0 then
                if esp.Billboard then esp.Billboard.Enabled = false end
                if esp.Highlight then esp.Highlight.Enabled = false end
            elseif Settings.TeamCheck and player.Team == LocalPlayer.Team then
                if esp.Billboard then esp.Billboard.Enabled = false end
                if esp.Highlight then esp.Highlight.Enabled = false end
            else
                local d = (Camera.CFrame.Position - hrp.Position).Magnitude
                if d > Settings.MaxDistance then
                    if esp.Billboard then esp.Billboard.Enabled = false end
                    if esp.Highlight then esp.Highlight.Enabled = false end
                else
                    if esp.Billboard then
                        if esp.Billboard.Adornee ~= head then
                            esp.Billboard.Adornee = head
                        end
                        esp.Billboard.Enabled = true
                        esp.NameLabel.Text = player.Name
                        esp.NameLabel.Visible = Settings.ShowName
                        esp.DistLabel.Text = string.format("[%d m]", d)
                        esp.DistLabel.Visible = Settings.ShowDistance
                        esp.StatusLabel.Visible = Settings.ShowStatus and (esp.StatusText ~= "")

                        local hp = hum.Health / hum.MaxHealth
                        esp.HealthFill.Size = UDim2.new(hp, 0, 1, 0)
                        esp.HealthFill.BackgroundColor3 = Color3.fromRGB(
                            math.floor(255 * (1 - hp)),
                            math.floor(255 * hp),
                            0
                        )
                        esp.HealthBg.Visible = Settings.ShowHealth
                    end

                    if esp.Highlight then
                        if esp.Highlight.Adornee ~= char then
                            esp.Highlight.Adornee = char
                        end
                        esp.Highlight.Enabled = Settings.ShowHighlight
                    end
                end
            end
        end
    else
        for _, esp in pairs(ESPCache) do
            if esp.Billboard then esp.Billboard.Enabled = false end
            if esp.Highlight then esp.Highlight.Enabled = false end
        end
    end

    -- Watcher
    checkDoorChanges()

    -- Автодействия
    if not Settings.AutoActions then
        return
    end
    StateTimer = StateTimer + dt

    local now = tick()
    for p, expireAt in pairs(IgnoredPlayers) do
        if now >= expireAt then IgnoredPlayers[p] = nil end
    end

    -- IDLE
    if ActionState == "idle" then
        for _, p in pairs(Players:GetPlayers()) do
            if p ~= LocalPlayer and p.Character and not ProcessedPlayers[p] and not IgnoredPlayers[p] then
                local hrp = p.Character:FindFirstChild("HumanoidRootPart")
                if hrp then
                    local d = (Camera.CFrame.Position - hrp.Position).Magnitude
                    if d <= Settings.TriggerRadius then
                        local inQueue = false
                        for _, qp in ipairs(Queue) do
                            if qp == p then inQueue = true; break end
                        end
                        if not inQueue then
                            table.insert(Queue, p)
                            log("Queue: " .. p.Name, Theme.Warning)
                        end
                    end
                end
            end
        end
        if #Queue > 0 and StateTimer >= Settings.QueueDelay then
            local p = table.remove(Queue, 1)
            if p and p.Character and p.Parent then
                local hrp = p.Character:FindFirstChild("HumanoidRootPart")
                if hrp then
                    CurrentTarget = p
                    InitialDistance = (Camera.CFrame.Position - hrp.Position).Magnitude
                    ActionState = "activating"
                    StateTimer = 0
                    ProcessedPlayers[p] = true
                    log("Processing: " .. p.Name, Theme.Warning)
                    setPlayerStatus(p, "ACTIVATING...", Color3.fromRGB(255, 220, 80))
                    if Settings.DoActivate and Settings.Buttons.Activate then
                        fireButtonAction(Settings.Buttons.Activate)
                    end
                end
            end
        elseif #Queue == 0 then
            StateTimer = 0
        end
    end

    -- Игрок исчез
    if CurrentTarget and ActionState ~= "idle" then
        if not CurrentTarget.Parent or not CurrentTarget.Character
           or not CurrentTarget.Character:FindFirstChild("HumanoidRootPart") then
            log("Player gone - Home + deactivate", Theme.Danger)
            clearPlayerStatus(CurrentTarget)

            if RouteSettings.ReturnHomeOnPlayerLeft then
                task.spawn(function()
                    if Settings.DoDeactivate and Settings.Buttons.Deactivate then
                        fireButtonAction(Settings.Buttons.Deactivate)
                        task.wait(0.5)
                    end
                    if RouteSettings.HomePosition then
                        teleportToHome()
                    end
                end)
            end

            CurrentTarget = nil
            ActionState = "idle"
            StateTimer = 0
        end
    end

    -- ACTIVATING
    if ActionState == "activating" and CurrentTarget then
        setPlayerStatus(CurrentTarget, "ACTIVATING " .. math.floor(Settings.WaitAfterActivate - StateTimer) .. "s", Color3.fromRGB(255, 220, 80))
        if StateTimer >= Settings.WaitAfterActivate then
            local hrp = CurrentTarget.Character and CurrentTarget.Character:FindFirstChild("HumanoidRootPart")
            if hrp then
                local d = (Camera.CFrame.Position - hrp.Position).Magnitude
                if d < InitialDistance - Settings.ApproachThreshold then
                    setPlayerStatus(CurrentTarget, "GIVE TICKET", Color3.fromRGB(80, 200, 255))
                    if Settings.DoGiveTicket and Settings.Buttons.GiveTicket then
                        fireButtonAction(Settings.Buttons.GiveTicket)
                    end
                    ActionState = "ticket"
                    StateTimer = 0
                else
                    setPlayerStatus(CurrentTarget, "DID NOT APPROACH", Color3.fromRGB(200, 100, 100))
                    ActionState = "waitLeft"
                    StateTimer = 0
                end
            end
        end
    end

    -- TICKET
    if ActionState == "ticket" and StateTimer >= Settings.WaitBeforeCheck then
        if CurrentTarget then
            setPlayerStatus(CurrentTarget, "CHECK WEAPON", Color3.fromRGB(255, 180, 80))
        end
        if Settings.DoCheckWeapon and Settings.Buttons.CheckWeapon then
            fireButtonAction(Settings.Buttons.CheckWeapon)
        end
        ActionState = "weapon"
        StateTimer = 0
    end

    -- WEAPON
    if ActionState == "weapon" and StateTimer >= Settings.WaitBeforeDeactivate then
        if CurrentTarget then
            setPlayerStatus(CurrentTarget, "DEACTIVATING", Color3.fromRGB(200, 130, 255))
        end
        if Settings.DoDeactivate and Settings.Buttons.Deactivate then
            fireButtonAction(Settings.Buttons.Deactivate)
        end
        ActionState = "cooldown"
        StateTimer = 0
    end

    -- WAIT LEFT
    if ActionState == "waitLeft" and StateTimer >= Settings.WaitLeftWithoutApproach then
        if CurrentTarget then
            setPlayerStatus(CurrentTarget, "DEACTIVATING (left)", Color3.fromRGB(200, 130, 255))
        end
        if Settings.DoDeactivate and Settings.Buttons.Deactivate then
            fireButtonAction(Settings.Buttons.Deactivate)
        end
        ActionState = "cooldown"
        StateTimer = 0
    end

    -- COOLDOWN
    if ActionState == "cooldown" and StateTimer >= 5 then
        if CurrentTarget then
            clearPlayerStatus(CurrentTarget)
            IgnoredPlayers[CurrentTarget] = tick() + Settings.IgnoreDuration
            log("Ignore: " .. CurrentTarget.Name, Theme.TextDim)
        end
        CurrentTarget = nil
        ActionState = "idle"
        StateTimer = 0
    end
end)

-- ═══════════════════════════════════════════════════════
-- 🎧 СОБЫТИЯ
-- ═══════════════════════════════════════════════════════
Players.PlayerAdded:Connect(function(player)
    createESP(player)
end)
Players.PlayerRemoving:Connect(function(player)
    removeESP(player)
    ProcessedPlayers[player] = nil
    IgnoredPlayers[player] = nil
    for i = #Queue, 1, -1 do
        if Queue[i] == player then table.remove(Queue, i) end
    end
end)
for _, p in pairs(Players:GetPlayers()) do
    createESP(p)
end

-- ═══════════════════════════════════════════════════════
-- 🔄 ВКЛАДКИ
-- ═══════════════════════════════════════════════════════
local tabs = {
    {Name = "Console", Frame = ConsoleTab},
    {Name = "Test", Frame = TestTab},
    {Name = "Settings", Frame = SettingsTab},
}

local function selectTab(index)
    for i, tab in ipairs(tabs) do
        tab.Frame.Visible = (i == index)
        if tab.Button then
            TweenService:Create(tab.Button, TweenInfo.new(0.15), {
                BackgroundColor3 = (i == index) and Theme.Accent or Theme.BgLighter
            }):Play()
        end
    end
end

for i, tab in ipairs(tabs) do
    local btn = Instance.new("TextButton")
    btn.Text = tab.Name
    btn.Size = UDim2.new(1/#tabs, -4, 1, 0)
    btn.Position = UDim2.new((i-1)/#tabs, 2, 0, 0)
    btn.BackgroundColor3 = Theme.BgLighter
    btn.TextColor3 = Theme.Text
    btn.Font = Enum.Font.GothamBold
    btn.TextSize = 13
    btn.BorderSizePixel = 0
    btn.AutoButtonColor = false
    btn.Parent = TabBar
    addCorner(btn, 7)
    btn.MouseButton1Click:Connect(function() selectTab(i) end)
    tab.Button = btn
end
selectTab(1)

local minimized = false
local originalSize = MainFrame.Size
MinimizeBtn.MouseButton1Click:Connect(function()
    minimized = not minimized
    if minimized then
        TweenService:Create(MainFrame, TweenInfo.new(0.2), {Size = UDim2.new(0, 480, 0, 42)}):Play()
        ContentFrame.Visible = false
        TabBar.Visible = false
    else
        TweenService:Create(MainFrame, TweenInfo.new(0.2), {Size = originalSize}):Play()
        ContentFrame.Visible = true
        TabBar.Visible = true
    end
end)

CloseBtn.MouseButton1Click:Connect(function()
    MainGui.Enabled = false
    CrosshairGui.Enabled = false
    log("UI hidden. Show: getgenv().ShowUI()", Theme.Warning)
end)

-- ═══════════════════════════════════════════════════════
-- 🌐 API
-- ═══════════════════════════════════════════════════════
getgenv().ESP = {
    Settings = Settings,
    RouteSettings = RouteSettings,
    Doors = Doors,
    Toggle = function() Settings.Enabled = not Settings.Enabled end,
    GoToRoom = goToRoom,
    GoToNextRoom = goToNextRoom,
    FindDoors = findDoors,
    InitWatcher = initDoorWatcher,
    SetHome = setHomePosition,
    RememberHome = rememberHomeFromNow,
    TeleportHome = teleportToHome,
    SetStatus = setPlayerStatus,
    ClearStatus = clearPlayerStatus,
    Destroy = function()
        for p, _ in pairs(ESPCache) do removeESP(p) end
        pcall(function() MainGui:Destroy() end)
        pcall(function() CrosshairGui:Destroy() end)
        pcall(function() ClickIndicatorGui:Destroy() end)
        getgenv().ESP_LOADED = false
    end,
}

getgenv().ShowUI = function()
    MainGui.Enabled = true
end
getgenv().HideUI = function()
    MainGui.Enabled = false
    CrosshairGui.Enabled = false
end

log("Script v8.3 loaded!", Theme.Success)
log("Settings -> BUTTON COORDS for coordinates", Theme.Warning)
log("Crosshair: press Select", Theme.Warning)
