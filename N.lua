--[[
    N.lua — ESP + AUTO ACTIONS + ROUTES + DOOR WATCHER
    Версия: 7.1 (сдвиг X/Y + Home Position + Door Watch)
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
    PathLine    = Color3.fromRGB(0, 220, 100),
    StopMark    = Color3.fromRGB(255, 80, 80),
    DoorMark    = Color3.fromRGB(255, 200, 80),
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
    CrosshairOffsetY = 0,       -- сдвиг по Y
    CrosshairOffsetX = 0,       -- ⬅️ НОВОЕ: сдвиг по X (например -50)
}

-- ═══════════════════════════════════════════════════════
-- 🚪 НАСТРОЙКИ МАРШРУТА + HOME POSITION
-- ═══════════════════════════════════════════════════════
local RouteSettings = {
    DoorName = "RoomExit",
    CurrentRoom = 1,
    StepSize = 10,
    StepDelay = 0.05,
    StopLeftOffset = 3,
    StopBackOffset = 2,
    StopHeightOffset = 3,
    AutoNextRoom = false,

    -- Home Position — исходная точка (задаётся в настройках)
    HomePosition = nil,         -- Vector3 или nil

    -- Watcher дверей
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
    label.Text = "›  " .. tostring(text)
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
-- 🖱️ ТОЧНЫЙ ТАП (с учётом сдвигов X и Y)
-- ═══════════════════════════════════════════════════════
local function clickAtScreenPosition(x, y)
    if not x or not y then return false end
    local topInset = GuiService:GetGuiInset().Y
    local realX = x + (Settings.CrosshairOffsetX or 0)   -- ⬅️ СДВИГ ПО X
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

function fireButtonAction(btnData)
    if not btnData or not btnData.Pos then return false end
    clickAtScreenPosition(btnData.Pos.X, btnData.Pos.Y)
    log("✓ Тап X=" .. btnData.Pos.X .. ", Y=" .. btnData.Pos.Y, Theme.Success)
    return true
end

-- ═══════════════════════════════════════════════════════
-- 🎯 КЛИК ПО GUI-КНОПКЕ (всеми способами)
-- ═══════════════════════════════════════════════════════
local function tryClickGuiButton(button)
    if not button or not button:IsA("GuiButton") then return false end

    log("🖱 Пробую нажать: " .. button.ClassName .. " [" .. button.Name .. "]", Theme.Warning)

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

    -- VirtualInput
    pcall(function()
        local topInset = GuiService:GetGuiInset().Y
        local rx = pos.X + (Settings.CrosshairOffsetX or 0)
        local ry = pos.Y + topInset + (Settings.CrosshairOffsetY or 0)
        VirtualInputManager:SendMouseButtonEvent(rx, ry, 0, true, game, 1)
        task.wait(0.05)
        VirtualInputManager:SendMouseButtonEvent(rx, ry, 0, false, game, 1)
    end)

    -- tap/touch
    pcall(function()
        local topInset = GuiService:GetGuiInset().Y
        local rx = pos.X + (Settings.CrosshairOffsetX or 0)
        local ry = pos.Y + topInset + (Settings.CrosshairOffsetY or 0)
        if typeof(tap) == "function" then tap(rx, ry)
        elseif typeof(touch) == "function" then touch(rx, ry) end
    end)

    -- Ищем RemoteEvent внутри
    pcall(function()
        for _, child in ipairs(button:GetDescendants()) do
            if child:IsA("RemoteEvent") then
                child:FireServer()
                log("  → RemoteEvent: " .. child.Name, Theme.Success)
            end
        end
    end)

    return true
end

-- ═══════════════════════════════════════════════════════
-- 🔍 ПОИСК КНОПКИ ПО ИМЕНИ (для NumberUp)
-- ═══════════════════════════════════════════════════════
local function findButtonByName(namePattern)
    local found = {}

    local function scanGui(gui)
        pcall(function()
            if not gui:IsA("ScreenGui") then return end
            for _, desc in ipairs(gui:GetDescendants()) do
                if desc:IsA("GuiButton") then
                    local n = desc.Name:lower()
                    if n:find(namePattern:lower(), 1, true) then
                        table.insert(found, desc)
                    end
                end
            end
        end)
    end

    pcall(function()
        for _, gui in ipairs(LocalPlayer.PlayerGui:GetChildren()) do
            scanGui(gui)
        end
    end)
    pcall(function()
        for _, gui in ipairs(CoreGui:GetChildren()) do
            scanGui(gui)
        end
    end)

    return found
end

-- ═══════════════════════════════════════════════════════
-- 🚪 ПОИСК ДВЕРЕЙ
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
                    Instance = obj,
                    Position = obj.Position,
                    CFrame = obj.CFrame,
                    FullPath = fullPath,
                }
                count = count + 1
            end
        end
    end
    return count
end

local function getDoor(roomNum)
    return Doors[roomNum]
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
        myHRP.CFrame = CFrame.new(point)
        task.wait(RouteSettings.StepDelay)
    end
    return true
end

-- ═══════════════════════════════════════════════════════
-- 👁️ WATCHER ДВЕРЕЙ
-- ═══════════════════════════════════════════════════════
local function initDoorWatcher()
    DoorWatcherData = {}
    local count = 0
    for num, door in pairs(Doors) do
        if door.Instance and door.Instance.Parent then
            DoorWatcherData[door.Instance] = {
                CFrame = door.Instance.CFrame,
                Position = door.Instance.Position,
                Rotation = door.Instance.Orientation,
                RoomNum = num,
            }
            count = count + 1
        end
    end
    log("👁️ Watcher инициализирован для " .. count .. " дверей", Theme.Success)
end

-- Что делать при открытии двери
local function onDoorOpened(roomNum, doorInstance)
    local now = tick()
    if doorOpenHandled[roomNum] and now - doorOpenHandled[roomNum] < 3 then
        return
    end
    doorOpenHandled[roomNum] = now

    log("🚪 ДВЕРЬ " .. roomNum .. " ОТКРЫЛАСЬ! Пробую NumberUp", Theme.Success)

    task.spawn(function()
        -- Способ 1: по сохранённым координатам
        if Settings.Buttons.NumberUp and Settings.Buttons.NumberUp.Pos then
            log("📌 Способ 1: тап по координатам", Theme.TextDim)
            for i = 1, RouteSettings.NumberUpRetryCount do
                fireButtonAction(Settings.Buttons.NumberUp)
                task.wait(RouteSettings.NumberUpRetryDelay)
            end
        end

        -- Способ 2: поиск кнопки по имени
        log("🔍 Способ 2: поиск кнопки по имени", Theme.TextDim)
        local buttons = findButtonByName("NumberUp")
        if #buttons == 0 then
            buttons = findButtonByName("Increase")
        end
        if #buttons == 0 then
            buttons = findButtonByName("Up")
        end

        for _, btn in ipairs(buttons) do
            log("  Найдена: " .. btn:GetFullName(), Theme.Success)
            tryClickGuiButton(btn)
            task.wait(0.3)
        end

        if #buttons == 0 then
            log("  ❌ Кнопка не найдена", Theme.Danger)
        end
    end)
end

-- Проверка изменений дверей
local function checkDoorChanges()
    if not RouteSettings.WatchDoors then return end

    for doorInstance, data in pairs(DoorWatcherData) do
        if not doorInstance or not doorInstance.Parent then
            DoorWatcherData[doorInstance] = nil
        else
            local currentPos = doorInstance.Position
            local currentRot = doorInstance.Orientation

            local posDiff = (currentPos - data.Position).Magnitude
            local rotDiff = (currentRot - data.Rotation).Magnitude

            if posDiff > RouteSettings.DoorMoveThreshold or rotDiff > RouteSettings.DoorRotationThreshold then
                log(string.format("🚪 ДВЕРЬ %s ИЗМЕНИЛАСЬ! (pos=%.2f, rot=%.2f)",
                    data.RoomNum, posDiff, rotDiff), Theme.Success)

                data.Position = currentPos
                data.Rotation = currentRot
                data.CFrame = doorInstance.CFrame

                onDoorOpened(data.RoomNum, doorInstance)
            end
        end
    end
end

-- ═══════════════════════════════════════════════════════
-- 🏠 HOME POSITION
-- ═══════════════════════════════════════════════════════
local function setHomePosition(pos)
    RouteSettings.HomePosition = pos
    log("🏠 Home Position установлена: " .. tostring(pos), Theme.Success)
end

local function teleportToHome()
    if not RouteSettings.HomePosition then
        log("⚠ Home Position не задана", Theme.Warning)
        return false
    end

    local myHRP = LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
    if not myHRP then return false end

    -- Проверяем что там нет стены
    local path = buildPath(myHRP.Position, RouteSettings.HomePosition)
    teleportAlongPath(path)
    log("🏠 Вернулся на Home Position", Theme.Success)
    return true
end

-- Запомнить текущую позицию как Home
local function rememberHomeFromNow()
    local myHRP = LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
    if not myHRP then
        log("❌ Нет персонажа", Theme.Danger)
        return
    end
    setHomePosition(myHRP.Position)
end

-- ═══════════════════════════════════════════════════════
-- 🚗 ЕХАТЬ К КОМНАТЕ
-- ═══════════════════════════════════════════════════════
function goToRoom(roomNum)
    roomNum = roomNum or RouteSettings.CurrentRoom

    if next(Doors) == nil then
        local c = findDoors()
        log("🔍 Найдено дверей: " .. c, Theme.Success)
    end

    local door = getDoor(roomNum)
    if not door then
        log("❌ Дверь комнаты " .. roomNum .. " не найдена", Theme.Danger)
        return false
    end

    local myHRP = LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
    if not myHRP then return false end

    local myPos = myHRP.Position
    local stopPos = calculateStopPoint(door)

    log("🚪 Едем к комнате " .. roomNum, Theme.Warning)
    log(string.format("📍 Я: (%.1f, %.1f, %.1f)", myPos.X, myPos.Y, myPos.Z), Theme.TextDim)
    log(string.format("🛑 Стоп: (%.1f, %.1f, %.1f)", stopPos.X, stopPos.Y, stopPos.Z), Theme.TextDim)

    local path = buildPath(myPos, stopPos)
    teleportAlongPath(path)
    log("✅ Достигли точки стопа комнаты " .. roomNum, Theme.Success)
    return true
end

function goToNextRoom()
    RouteSettings.CurrentRoom = RouteSettings.CurrentRoom + 1
    log("➡ Комната: " .. RouteSettings.CurrentRoom, Theme.Warning)
    return goToRoom(RouteSettings.CurrentRoom)
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
TitleIcon.Text = "🎯"
TitleIcon.Size = UDim2.new(0, 30, 1, 0)
TitleIcon.Position = UDim2.new(0, 12, 0, 0)
TitleIcon.BackgroundTransparency = 1
TitleIcon.TextColor3 = Theme.Accent
TitleIcon.Font = Enum.Font.GothamBold
TitleIcon.TextSize = 18
TitleIcon.Parent = TitleBar

local Title = Instance.new("TextLabel")
Title.Text = "ESP  •  AUTO  •  v7.1"
Title.Size = UDim2.new(1, -150, 1, 0)
Title.Position = UDim2.new(0, 46, 0, 0)
Title.BackgroundTransparency = 1
Title.TextColor3 = Theme.Text
Title.Font = Enum.Font.GothamBold
Title.TextSize = 15
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
CloseBtn.Text = "✕"
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

log("Консоль инициализирована", Theme.TextDim)

local TestTab = Instance.new("ScrollingFrame")
TestTab.Size = UDim2.new(1, -12, 1, -12)
TestTab.Position = UDim2.new(0, 6, 0, 6)
TestTab.BackgroundTransparency = 1
TestTab.BorderSizePixel = 0
TestTab.ScrollBarThickness = 5
TestTab.ScrollBarImageColor3 = Theme.Accent
TestTab.CanvasSize = UDim2.new(0, 0, 0, 800)
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
    btn.MouseButton1Click:Connect(callback)
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
    toggle.Text = state and "ВКЛ" or "ВЫКЛ"
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
        toggle.Text = state and "ВКЛ" or "ВЫКЛ"
        callback(state)
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
    input.Text = tostring(default)
    input.TextColor3 = Theme.Text
    input.Font = Enum.Font.Gotham
    input.TextSize = 12
    input.BorderSizePixel = 0
    input.ClearTextOnFocus = false
    input.Parent = row
    addCorner(input, 6)

    input.FocusLost:Connect(function()
        local num = tonumber(input.Text)
        if num then callback(num) end
    end)
    return row
end

-- ═══════════════════════════════════════════════════════
-- 📋 ВКЛАДКА "ТЕСТ"
-- ═══════════════════════════════════════════════════════
local function makeTestBtn(text, callback, color)
    return makeButton(TestTab, text, callback, color)
end

makeSection(TestTab, "МАРШРУТ")

makeTestBtn("🚪 К комнате", function()
    goToRoom(RouteSettings.CurrentRoom)
end, Theme.Success)

makeTestBtn("➡ Следующая комната", function()
    goToNextRoom()
end, Theme.Warning)

makeTestBtn("🏠 Запомнить Home Position (текущая)", function()
    rememberHomeFromNow()
end, Theme.Accent)

makeTestBtn("🏠 Вернуться на Home Position", function()
    teleportToHome()
end, Theme.Warning)

makeTestBtn("👁️ Начать слежение за дверями", function()
    local c = findDoors()
    log("🔍 Найдено дверей: " .. c, Theme.Success)
    initDoorWatcher()
end, Theme.Accent)

makeTestBtn("🎯 Нажать NumberUp (ручной тест)", function()
    local buttons = findButtonByName("NumberUp")
    if #buttons == 0 then
        buttons = findButtonByName("Increase")
    end
    if #buttons == 0 then
        buttons = findButtonByName("Up")
    end

    if #buttons == 0 then
        log("❌ Кнопка NumberUp не найдена", Theme.Danger)
        -- Пробуем по координатам
        if Settings.Buttons.NumberUp then
            log("📌 Пробую по сохранённым координатам", Theme.Warning)
            fireButtonAction(Settings.Buttons.NumberUp)
        end
        return
    end

    for _, btn in ipairs(buttons) do
        log("🔍 Найдена: " .. btn:GetFullName(), Theme.Success)
        tryClickGuiButton(btn)
    end
end, Theme.Warning)

makeSection(TestTab, "КООРДИНАТЫ КНОПОК")

makeTestBtn("▶  Активировать", function()
    if Settings.Buttons.Activate then
        fireButtonAction(Settings.Buttons.Activate)
    else
        log("❌ Координаты не заданы", Theme.Danger)
    end
end)

makeTestBtn("🎫 Выдать билет", function()
    if Settings.Buttons.GiveTicket then
        fireButtonAction(Settings.Buttons.GiveTicket)
    else
        log("❌ Координаты не заданы", Theme.Danger)
    end
end)

makeTestBtn("🔫 Проверить оружие", function()
    if Settings.Buttons.CheckWeapon then
        fireButtonAction(Settings.Buttons.CheckWeapon)
    else
        log("❌ Координаты не заданы", Theme.Danger)
    end
end)

makeTestBtn("⏹  Деактивировать", function()
    if Settings.Buttons.Deactivate then
        fireButtonAction(Settings.Buttons.Deactivate)
    else
        log("❌ Координаты не заданы", Theme.Danger)
    end
end)

makeTestBtn("🔢 Увеличение номера (тап по координатам)", function()
    if Settings.Buttons.NumberUp then
        fireButtonAction(Settings.Buttons.NumberUp)
    else
        log("❌ Координаты не заданы", Theme.Danger)
    end
end)

makeTestBtn("🔄 Сбросить состояние", function()
    ActionState = "idle"
    StateTimer = 0
    ProcessedPlayers = {}
    IgnoredPlayers = {}
    Queue = {}
    doorOpenHandled = {}
    log("Состояние сброшено", Theme.Warning)
end, Theme.Danger)

-- ═══════════════════════════════════════════════════════
-- 📋 ВКЛАДКА "НАСТРОЙКИ"
-- ═══════════════════════════════════════════════════════
makeSection(SettingsTab, "СДВИГИ КООРДИНАТ")
makeInput(SettingsTab, "Сдвиг по X (например -50)", Settings.CrosshairOffsetX, function(v)
    Settings.CrosshairOffsetX = v
    log("Сдвиг X: " .. v, Theme.Warning)
end)
makeInput(SettingsTab, "Сдвиг по Y (например 50)", Settings.CrosshairOffsetY, function(v)
    Settings.CrosshairOffsetY = v
    log("Сдвиг Y: " .. v, Theme.Warning)
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
makeTestBtn("📍 Запомнить текущую как Home", function()
    rememberHomeFromNow()
end, Theme.Success)

makeSection(SettingsTab, "WATCHER ДВЕРЕЙ")
makeToggle(SettingsTab, "Следить за дверями", RouteSettings.WatchDoors, function(v)
    RouteSettings.WatchDoors = v
    if v then
        initDoorWatcher()
    end
end)
makeInput(SettingsTab, "Порог поворота (градусы)", RouteSettings.DoorRotationThreshold, function(v)
    RouteSettings.DoorRotationThreshold = v
end)
makeInput(SettingsTab, "Порог смещения (studs)", RouteSettings.DoorMoveThreshold, function(v)
    RouteSettings.DoorMoveThreshold = v
end)
makeInput(SettingsTab, "Попыток NumberUp", RouteSettings.NumberUpRetryCount, function(v)
    RouteSettings.NumberUpRetryCount = v
end)
makeInput(SettingsTab, "Задержка между попытками (сек)", RouteSettings.NumberUpRetryDelay, function(v)
    RouteSettings.NumberUpRetryDelay = v
end)
makeToggle(SettingsTab, "Возврат на Home если игрок исчез", RouteSettings.ReturnHomeOnPlayerLeft, function(v)
    RouteSettings.ReturnHomeOnPlayerLeft = v
end)

makeSection(SettingsTab, "МАРШРУТ")
makeInput(SettingsTab, "Текущая комната", RouteSettings.CurrentRoom, function(v)
    RouteSettings.CurrentRoom = v
end)
makeInput(SettingsTab, "Шаг телепорта (studs)", RouteSettings.StepSize, function(v)
    RouteSettings.StepSize = v
end)
makeInput(SettingsTab, "Сдвиг влево от двери", RouteSettings.StopLeftOffset, function(v)
    RouteSettings.StopLeftOffset = v
end)
makeInput(SettingsTab, "Сдвиг назад от двери", RouteSettings.StopBackOffset, function(v)
    RouteSettings.StopBackOffset = v
end)

makeSection(SettingsTab, "АВТОДЕЙСТВИЯ")
makeToggle(SettingsTab, "Автодействия ВКЛ", Settings.AutoActions, function(v)
    Settings.AutoActions = v
    log("Автодействия: " .. (v and "ВКЛ" or "ВЫКЛ"), v and Theme.Success or Theme.TextDim)
end)
makeToggle(SettingsTab, "Нажимать «Активировать»", Settings.DoActivate, function(v) Settings.DoActivate = v end)
makeToggle(SettingsTab, "Нажимать «Выдать билет»", Settings.DoGiveTicket, function(v) Settings.DoGiveTicket = v end)
makeToggle(SettingsTab, "Нажимать «Проверить оружие»", Settings.DoCheckWeapon, function(v) Settings.DoCheckWeapon = v end)
makeToggle(SettingsTab, "Нажимать «Деактивировать»", Settings.DoDeactivate, function(v) Settings.DoDeactivate = v end)

makeSection(SettingsTab, "ПАРАМЕТРЫ")
makeInput(SettingsTab, "Радиус обнаружения (м)", Settings.TriggerRadius, function(v) Settings.TriggerRadius = v end)
makeInput(SettingsTab, "Порог приближения (м)", Settings.ApproachThreshold, function(v) Settings.ApproachThreshold = v end)
makeInput(SettingsTab, "Ожидание после Активировать (с)", Settings.WaitAfterActivate, function(v) Settings.WaitAfterActivate = v end)
makeInput(SettingsTab, "Ожидание перед Проверить (с)", Settings.WaitBeforeCheck, function(v) Settings.WaitBeforeCheck = v end)
makeInput(SettingsTab, "Ожидание перед Деактивировать (с)", Settings.WaitBeforeDeactivate, function(v) Settings.WaitBeforeDeactivate = v end)
makeInput(SettingsTab, "Ожидание если ушёл (с)", Settings.WaitLeftWithoutApproach, function(v) Settings.WaitLeftWithoutApproach = v end)
makeInput(SettingsTab, "Задержка между игроками (с)", Settings.QueueDelay, function(v) Settings.QueueDelay = v end)
makeInput(SettingsTab, "Игнор после деактивации (с)", Settings.IgnoreDuration, function(v) Settings.IgnoreDuration = v end)

makeSection(SettingsTab, "ESP")
makeToggle(SettingsTab, "ESP включён", Settings.Enabled, function(v) Settings.Enabled = v end)
makeToggle(SettingsTab, "Показывать имя", Settings.ShowName, function(v) Settings.ShowName = v end)
makeToggle(SettingsTab, "Показывать здоровье", Settings.ShowHealth, function(v) Settings.ShowHealth = v end)
makeToggle(SettingsTab, "Показывать дистанцию", Settings.ShowDistance, function(v) Settings.ShowDistance = v end)
makeToggle(SettingsTab, "Показывать статус", Settings.ShowStatus, function(v) Settings.ShowStatus = v end)

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
CrossTitleLbl.Text = "🎯 ПРИЦЕЛ"
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
CoordLabel.Text = "X: —   Y: —"
CoordLabel.TextColor3 = Color3.fromRGB(255, 255, 100)
CoordLabel.Font = Enum.Font.Code
CoordLabel.TextSize = 14
CoordLabel.Parent = CrossPanel

local OffsetInfo = Instance.new("TextLabel")
OffsetInfo.Size = UDim2.new(1, -20, 0, 18)
OffsetInfo.Position = UDim2.new(0, 10, 0, 54)
OffsetInfo.BackgroundTransparency = 1
OffsetInfo.Text = "Сдвиг X: 0  Y: 0"
OffsetInfo.TextColor3 = Theme.TextDim
OffsetInfo.Font = Enum.Font.Code
OffsetInfo.TextSize = 11
OffsetInfo.Parent = CrossPanel

local SelectBtn = Instance.new("TextButton")
SelectBtn.Text = "Выбрать (текущие координаты)"
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

local currentPickKey = nil
local currentPickName = nil

SelectBtn.MouseButton1Click:Connect(function()
    if not currentPickKey then return end
    local pos = CrossHandle.AbsolutePosition + CrossHandle.AbsoluteSize / 2
    local x, y = math.floor(pos.X), math.floor(pos.Y)
    Settings.Buttons[currentPickKey] = {Pos = {X = x, Y = y}}
    log(string.format("✓ %s: X=%d, Y=%d", currentPickName, x, y), Theme.Success)
    CrosshairGui.Enabled = false
    MainGui.Enabled = true
    currentPickKey = nil
    currentPickName = nil
end)

function openCrosshairPicker(key, displayName)
    currentPickKey = key
    currentPickName = displayName
    CrossTitleLbl.Text = "🎯 ПРИЦЕЛ — " .. displayName
    CrosshairGui.Enabled = true
    MainGui.Enabled = false
    CrossHandle.Position = UDim2.new(0.5, -40, 0.5, -40)
    log("🎯 Перетащи крест и жми «Выбрать»", Theme.Warning)
end

RunService.RenderStepped:Connect(function()
    if not CrosshairGui.Enabled then return end
    local pos = CrossHandle.AbsolutePosition + CrossHandle.AbsoluteSize / 2
    CoordLabel.Text = string.format("X: %d   Y: %d", pos.X, pos.Y)
    OffsetInfo.Text = string.format("Сдвиг X: %d  Y: %d", 
        Settings.CrosshairOffsetX or 0, Settings.CrosshairOffsetY or 0)
end)

-- ═══════════════════════════════════════════════════════
-- 🎨 ESP
-- ═══════════════════════════════════════════════════════
local function createESP(player)
    if player == LocalPlayer then return end
    local esp = {}

    local billboard = Instance.new("BillboardGui")
    billboard.Name = "ESP_Billboard"
    billboard.AlwaysOnTop = true
    billboard.Size = UDim2.new(0, 200, 0, 70)
    billboard.StudsOffset = Vector3.new(0, Settings.HeadOffset + 2, 0)
    billboard.Enabled = false
    billboard.Parent = MainGui

    local statusLabel = Instance.new("TextLabel")
    statusLabel.Size = UDim2.new(1, 0, 0, 22)
    statusLabel.BackgroundTransparency = 1
    statusLabel.Font = Enum.Font.GothamBold
    statusLabel.TextSize = 16
    statusLabel.TextColor3 = Color3.fromRGB(255, 220, 80)
    statusLabel.TextStrokeTransparency = 0
    statusLabel.TextStrokeColor3 = Color3.fromRGB(0, 0, 0)
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
    distLabel.Size = UDim2.new(1, 0, 0, 20)
    distLabel.Position = UDim2.new(0, 0, 0, 44)
    distLabel.BackgroundTransparency = 1
    distLabel.Font = Enum.Font.Gotham
    distLabel.TextSize = Settings.TextSize - 2
    distLabel.TextColor3 = Color3.fromRGB(200, 200, 200)
    distLabel.TextStrokeTransparency = 0
    distLabel.TextStrokeColor3 = Color3.fromRGB(0, 0, 0)
    distLabel.Parent = billboard

    esp.Billboard = billboard
    esp.StatusLabel = statusLabel
    esp.NameLabel = nameLabel
    esp.DistLabel = distLabel
    esp.StatusText = ""

    ESPCache[player] = esp
end

local function removeESP(player)
    local esp = ESPCache[player]
    if not esp then return end
    if esp.Billboard then esp.Billboard:Destroy() end
    ESPCache[player] = nil
end

local function setPlayerStatus(player, text, color)
    local esp = ESPCache[player]
    if not esp or not esp.StatusLabel then return end
    esp.StatusText = text or ""
    esp.StatusLabel.Text = text or ""
    esp.StatusLabel.TextColor3 = color or Color3.fromRGB(255, 220, 80)
end

local function clearPlayerStatus(player)
    setPlayerStatus(player, "", nil)
end

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
                esp.Billboard.Enabled = false
            elseif Settings.TeamCheck and player.Team == LocalPlayer.Team then
                esp.Billboard.Enabled = false
            else
                local d = (Camera.CFrame.Position - hrp.Position).Magnitude
                if d > Settings.MaxDistance then
                    esp.Billboard.Enabled = false
                else
                    esp.Billboard.Adornee = head
                    esp.Billboard.Enabled = true
                    esp.NameLabel.Text = player.Name
                    esp.NameLabel.Visible = Settings.ShowName
                    esp.DistLabel.Text = string.format("[%d m]", d)
                    esp.DistLabel.Visible = Settings.ShowDistance
                    esp.StatusLabel.Visible = Settings.ShowStatus and (esp.StatusText ~= "")
                end
            end
        end
    else
        for _, esp in pairs(ESPCache) do
            if esp.Billboard then esp.Billboard.Enabled = false end
        end
    end

    -- Door Watcher — проверяем изменения каждый кадр
    checkDoorChanges()

    -- Автодействия
    if not Settings.AutoActions then return end
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
                            log("📋 В очередь: " .. p.Name, Theme.Warning)
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
                    log("👤 Обработка: " .. p.Name, Theme.Warning)
                    setPlayerStatus(p, "АКТИВАЦИЯ...", Color3.fromRGB(255, 220, 80))
                    if Settings.DoActivate and Settings.Buttons.Activate then
                        fireButtonAction(Settings.Buttons.Activate)
                    end
                end
            end
        elseif #Queue == 0 then
            StateTimer = 0
        end
    end

    -- Проверяем что target жив
    if CurrentTarget and ActionState ~= "idle" then
        if not CurrentTarget.Parent or not CurrentTarget.Character or not CurrentTarget.Character:FindFirstChild("HumanoidRootPart") then
            log("💨 Игрок исчез — возврат на Home Position", Theme.Danger)
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
        setPlayerStatus(CurrentTarget, "АКТИВАЦИЯ " .. math.floor(Settings.WaitAfterActivate - StateTimer) .. "с", Color3.fromRGB(255, 220, 80))
        if StateTimer >= Settings.WaitAfterActivate then
            local hrp = CurrentTarget.Character and CurrentTarget.Character:FindFirstChild("HumanoidRootPart")
            if hrp then
                local d = (Camera.CFrame.Position - hrp.Position).Magnitude
                if d < InitialDistance - Settings.ApproachThreshold then
                    setPlayerStatus(CurrentTarget, "ВЫДАЧА БИЛЕТА", Color3.fromRGB(80, 200, 255))
                    if Settings.DoGiveTicket and Settings.Buttons.GiveTicket then
                        fireButtonAction(Settings.Buttons.GiveTicket)
                    end
                    ActionState = "ticket"
                    StateTimer = 0
                else
                    setPlayerStatus(CurrentTarget, "НЕ ПОДОШЁЛ", Color3.fromRGB(200, 100, 100))
                    ActionState = "waitLeft"
                    StateTimer = 0
                end
            end
        end
    end

    -- TICKET
    if ActionState == "ticket" and StateTimer >= Settings.WaitBeforeCheck then
        if CurrentTarget then setPlayerStatus(CurrentTarget, "ПРОВЕРКА ОРУЖИЯ", Color3.fromRGB(255, 180, 80)) end
        if Settings.DoCheckWeapon and Settings.Buttons.CheckWeapon then
            fireButtonAction(Settings.Buttons.CheckWeapon)
        end
        ActionState = "weapon"
        StateTimer = 0
    end

    -- WEAPON
    if ActionState == "weapon" and StateTimer >= Settings.WaitBeforeDeactivate then
        if CurrentTarget then setPlayerStatus(CurrentTarget, "ДЕАКТИВАЦИЯ", Color3.fromRGB(200, 130, 255)) end
        if Settings.DoDeactivate and Settings.Buttons.Deactivate then
            fireButtonAction(Settings.Buttons.Deactivate)
        end
        ActionState = "cooldown"
        StateTimer = 0
    end

    -- WAIT LEFT
    if ActionState == "waitLeft" and StateTimer >= Settings.WaitLeftWithoutApproach then
        if CurrentTarget then setPlayerStatus(CurrentTarget, "ДЕАКТИВАЦИЯ (ушёл)", Color3.fromRGB(200, 130, 255)) end
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
            log("🚫 " .. CurrentTarget.Name .. " в игноре", Theme.TextDim)
        end
        CurrentTarget = nil
        ActionState = "idle"
        StateTimer = 0
    end
end)

-- ═══════════════════════════════════════════════════════
-- 🎧 СОБЫТИЯ
-- ═══════════════════════════════════════════════════════
Players.PlayerAdded:Connect(createESP)
Players.PlayerRemoving:Connect(function(player)
    removeESP(player)
    ProcessedPlayers[player] = nil
    IgnoredPlayers[player] = nil
    for i = #Queue, 1, -1 do
        if Queue[i] == player then table.remove(Queue, i) end
    end
end)
for _, p in pairs(Players:GetPlayers()) do createESP(p) end

-- ═══════════════════════════════════════════════════════
-- 🔄 ВКЛАДКИ
-- ═══════════════════════════════════════════════════════
local tabs = {
    {Name = "Консоль", Frame = ConsoleTab},
    {Name = "Тест", Frame = TestTab},
    {Name = "Настройки", Frame = SettingsTab},
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
    log("UI скрыт. Вернуть: getgenv().ShowUI()", Theme.Warning)
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
    ClickNumberUp = function()
        local btns = findButtonByName("NumberUp")
        for _, b in ipairs(btns) do tryClickGuiButton(b) end
    end,
    Destroy = function()
        for p, _ in pairs(ESPCache) do removeESP(p) end
        pcall(function() MainGui:Destroy() end)
        pcall(function() CrosshairGui:Destroy() end)
        pcall(function() ClickIndicatorGui:Destroy() end)
        getgenv().ESP_LOADED = false
    end,
}

getgenv().ShowUI = function() MainGui.Enabled = true end
getgenv().HideUI = function() MainGui.Enabled = false end

log("✅ Скрипт v7.1 загружен!", Theme.Success)
log("Сдвиг X/Y в Настройках", Theme.Warning)
log("Home Position — запомни через кнопку в Тесте", Theme.Warning)
log("Watcher дверей — включи и следи за RoomExit", Theme.Success)
