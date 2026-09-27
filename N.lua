--[[
    PLAYERS ESP + AUTO ACTIONS + UI
    Версия для Delta Executor
    Репозиторий: thecat04126-jpg/Scrpt-world
--]]

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local CoreGui = game:GetService("CoreGui")
local LocalPlayer = Players.LocalPlayer
local Camera = workspace.CurrentCamera
local Mouse = LocalPlayer:GetMouse()

-- ═══════════════════════════════════════════════════════
-- ⚙️ НАСТРОЙКИ
-- ═══════════════════════════════════════════════════════
local Settings = {
    -- ESP
    Enabled = true,
    ShowName = true,
    ShowHealth = true,
    ShowDistance = true,
    TeamCheck = false,
    MaxDistance = 1000,
    NameColor = Color3.fromRGB(255, 255, 255),
    HealthColor = Color3.fromRGB(0, 255, 0),
    TextSize = 14,
    HeadOffset = 3,

    -- Автодействия
    AutoActions = false,       -- главный выключатель
    TriggerRadius = 100,       -- радиус обнаружения игрока
    ApproachThreshold = 10,    -- на сколько метров должен приблизиться
    DoActivate = true,         -- нажимать "Активировать"
    DoGiveTicket = true,       -- нажимать "Выдать билет"
    DoCheckWeapon = true,      -- нажимать "Проверить оружие"
    DoDeactivate = true,       -- нажимать "Деактивировать"
    WaitAfterActivate = 10,    -- сек ожидания после "Активировать"
    WaitBeforeCheck = 3,       -- сек между "Выдать билет" и "Проверить оружие"
    WaitBeforeDeactivate = 3,  -- сек между "Проверить оружие" и "Деактивировать"
    WaitLeftWithoutApproach = 5, -- сек ожидания, если игрок ушёл

    -- Координаты кнопок (заполняются через UI)
    Buttons = {
        Activate = nil,        -- {Path = "...", Pos = {X,Y}}
        GiveTicket = nil,
        CheckWeapon = nil,
        Deactivate = nil,
    },

    -- Прицел
    CrosshairEnabled = false,
    CrosshairColor = Color3.fromRGB(0, 255, 0),
}

local ESPCache = {}
local CurrentTarget = nil
local ActionState = "idle"     -- idle / waiting / acting
local StateTimer = 0
local StateData = {}
local InitialDistance = 0

-- ═══════════════════════════════════════════════════════
-- 🖥️ UI: ГЛАВНОЕ ОКНО
-- ═══════════════════════════════════════════════════════
local function makeDraggable(frame)
    local dragging, dragStart, startPos
    frame.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1
           or input.UserInputType == Enum.UserInputType.Touch then
            dragging = true
            dragStart = input.Position
            startPos = frame.Position
        end
    end)
    frame.InputChanged:Connect(function(input)
        if dragging and (input.UserInputType == Enum.UserInputType.MouseMovement
           or input.UserInputType == Enum.UserInputType.Touch) then
            local delta = input.Position - dragStart
            frame.Position = UDim2.new(
                startPos.X.Scale, startPos.X.Offset + delta.X,
                startPos.Y.Scale, startPos.Y.Offset + delta.Y
            )
        end
    end)
    frame.InputEnded:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1
           or input.UserInputType == Enum.UserInputType.Touch then
            dragging = false
        end
    end)
end

local function makeButton(parent, text, pos, size, callback, color)
    local btn = Instance.new("TextButton")
    btn.Text = text
    btn.Size = size or UDim2.new(1, -10, 0, 30)
    btn.Position = pos
    btn.BackgroundColor3 = color or Color3.fromRGB(45, 45, 55)
    btn.TextColor3 = Color3.fromRGB(255, 255, 255)
    btn.Font = Enum.Font.Gotham
    btn.TextSize = 13
    btn.BorderSizePixel = 0
    btn.AutoButtonColor = true
    btn.Parent = parent
    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, 6)
    corner.Parent = btn
    btn.MouseButton1Click:Connect(callback)
    return btn
end

local MainGui = Instance.new("ScreenGui")
MainGui.Name = "ESP_MainUI"
MainGui.ResetOnSpawn = false
MainGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
pcall(function() MainGui.Parent = CoreGui end)
if not MainGui.Parent then MainGui.Parent = LocalPlayer:WaitForChild("PlayerGui") end

local MainFrame = Instance.new("Frame")
MainFrame.Name = "MainFrame"
MainFrame.Size = UDim2.new(0, 400, 0, 320)
MainFrame.Position = UDim2.new(0.5, -200, 0.5, -160)
MainFrame.BackgroundColor3 = Color3.fromRGB(25, 25, 30)
MainFrame.BorderSizePixel = 0
MainFrame.Active = true
MainFrame.Draggable = true
MainFrame.Parent = MainGui
makeDraggable(MainFrame)

local corner = Instance.new("UICorner")
corner.CornerRadius = UDim.new(0, 10)
corner.Parent = MainFrame

local stroke = Instance.new("UIStroke")
stroke.Color = Color3.fromRGB(80, 80, 100)
stroke.Thickness = 1
stroke.Parent = MainFrame

-- Заголовок
local TitleBar = Instance.new("Frame")
TitleBar.Size = UDim2.new(1, 0, 0, 35)
TitleBar.BackgroundColor3 = Color3.fromRGB(35, 35, 45)
TitleBar.BorderSizePixel = 0
TitleBar.Parent = MainFrame
local titleCorner = Instance.new("UICorner")
titleCorner.CornerRadius = UDim.new(0, 10)
titleCorner.Parent = TitleBar

local Title = Instance.new("TextLabel")
Title.Text = "🎯 ESP + AUTO ACTIONS"
Title.Size = UDim2.new(1, -40, 1, 0)
Title.Position = UDim2.new(0, 10, 0, 0)
Title.BackgroundTransparency = 1
Title.TextColor3 = Color3.fromRGB(255, 255, 255)
Title.Font = Enum.Font.GothamBold
Title.TextSize = 15
Title.TextXAlignment = Enum.TextXAlignment.Left
Title.Parent = TitleBar

-- Кнопка свернуть
local MinimizeBtn = Instance.new("TextButton")
MinimizeBtn.Text = "—"
MinimizeBtn.Size = UDim2.new(0, 25, 0, 25)
MinimizeBtn.Position = UDim2.new(1, -60, 0, 5)
MinimizeBtn.BackgroundColor3 = Color3.fromRGB(60, 60, 75)
MinimizeBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
MinimizeBtn.Font = Enum.Font.GothamBold
MinimizeBtn.TextSize = 14
MinimizeBtn.BorderSizePixel = 0
MinimizeBtn.Parent = TitleBar
local minCorner = Instance.new("UICorner")
minCorner.CornerRadius = UDim.new(0, 5)
minCorner.Parent = MinimizeBtn

-- Кнопка закрыть
local CloseBtn = Instance.new("TextButton")
CloseBtn.Text = "✕"
CloseBtn.Size = UDim2.new(0, 25, 0, 25)
CloseBtn.Position = UDim2.new(1, -30, 0, 5)
CloseBtn.BackgroundColor3 = Color3.fromRGB(180, 50, 50)
CloseBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
CloseBtn.Font = Enum.Font.GothamBold
CloseBtn.TextSize = 14
CloseBtn.BorderSizePixel = 0
CloseBtn.Parent = TitleBar
local closeCorner = Instance.new("UICorner")
closeCorner.CornerRadius = UDim.new(0, 5)
closeCorner.Parent = CloseBtn

-- Контейнер вкладок
local TabBar = Instance.new("Frame")
TabBar.Size = UDim2.new(1, -20, 0, 32)
TabBar.Position = UDim2.new(0, 10, 0, 42)
TabBar.BackgroundTransparency = 1
TabBar.Parent = MainFrame

local ContentFrame = Instance.new("Frame")
ContentFrame.Size = UDim2.new(1, -20, 1, -85)
ContentFrame.Position = UDim2.new(0, 10, 0, 78)
ContentFrame.BackgroundColor3 = Color3.fromRGB(18, 18, 22)
ContentFrame.BorderSizePixel = 0
ContentFrame.Parent = MainFrame
local contentCorner = Instance.new("UICorner")
contentCorner.CornerRadius = UDim.new(0, 6)
contentCorner.Parent = ContentFrame

-- ─── ВКЛАДКА: КОНСОЛЬ ───
local ConsoleTab = Instance.new("ScrollingFrame")
ConsoleTab.Size = UDim2.new(1, -10, 1, -10)
ConsoleTab.Position = UDim2.new(0, 5, 0, 5)
ConsoleTab.BackgroundTransparency = 1
ConsoleTab.BorderSizePixel = 0
ConsoleTab.ScrollBarThickness = 4
ConsoleTab.CanvasSize = UDim2.new(0, 0, 0, 0)
ConsoleTab.AutomaticCanvasSize = Enum.AutomaticSize.Y
ConsoleTab.Visible = true
ConsoleTab.Parent = ContentFrame

local ConsoleLayout = Instance.new("UIListLayout")
ConsoleLayout.Padding = UDim.new(0, 3)
ConsoleLayout.SortOrder = Enum.SortOrder.LayoutOrder
ConsoleLayout.Parent = ConsoleTab

local function log(text)
    local label = Instance.new("TextLabel")
    label.Size = UDim2.new(1, -5, 0, 18)
    label.BackgroundTransparency = 1
    label.Text = "[" .. os.date("%H:%M:%S") .. "] " .. tostring(text)
    label.TextColor3 = Color3.fromRGB(180, 220, 180)
    label.Font = Enum.Font.Code
    label.TextSize = 12
    label.TextXAlignment = Enum.TextXAlignment.Left
    label.Parent = ConsoleTab
    -- Ограничение: не более 100 строк
    local children = ConsoleTab:GetChildren()
    if #children > 105 then
        for i = 1, 10 do
            if children[i] and children[i]:IsA("TextLabel") then
                children[i]:Destroy()
            end
        end
    end
end

log("Консоль инициализирована")
log("Ожидание действий...")

-- ─── ВКЛАДКА: ТЕСТ ───
local TestTab = Instance.new("ScrollingFrame")
TestTab.Size = UDim2.new(1, -10, 1, -10)
TestTab.Position = UDim2.new(0, 5, 0, 5)
TestTab.BackgroundTransparency = 1
TestTab.BorderSizePixel = 0
TestTab.ScrollBarThickness = 4
TestTab.CanvasSize = UDim2.new(0, 0, 0, 300)
TestTab.Visible = false
TestTab.Parent = ContentFrame

local TestLayout = Instance.new("UIListLayout")
TestLayout.Padding = UDim.new(0, 6)
TestLayout.Parent = TestTab

local function testBtn(text, callback, color)
    return makeButton(TestTab, text, UDim2.new(0, 5, 0, 0), UDim2.new(1, -10, 0, 32), callback, color)
end

testBtn("🧪 Тест: Показать игроков в радиусе 100м", function()
    local found = 0
    for _, p in pairs(Players:GetPlayers()) do
        if p ~= LocalPlayer and p.Character then
            local hrp = p.Character:FindFirstChild("HumanoidRootPart")
            if hrp then
                local d = (Camera.CFrame.Position - hrp.Position).Magnitude
                if d <= Settings.TriggerRadius then
                    found = found + 1
                    log("Найден: " .. p.Name .. " (" .. math.floor(d) .. "м)")
                end
            end
        end
    end
    log("Всего в радиусе: " .. found)
end)

testBtn("🧪 Тест: Нажать 'Активировать'", function()
    if Settings.Buttons.Activate then
        fireButtonAction(Settings.Buttons.Activate)
        log("Тест: Активировать нажата")
    else
        log("❌ Координаты 'Активировать' не заданы")
    end
end)

testBtn("🧪 Тест: Нажать 'Выдать билет'", function()
    if Settings.Buttons.GiveTicket then
        fireButtonAction(Settings.Buttons.GiveTicket)
        log("Тест: Выдать билет нажата")
    else
        log("❌ Координаты 'Выдать билет' не заданы")
    end
end)

testBtn("🧪 Тест: Нажать 'Проверить оружие'", function()
    if Settings.Buttons.CheckWeapon then
        fireButtonAction(Settings.Buttons.CheckWeapon)
        log("Тест: Проверить оружие нажата")
    else
        log("❌ Координаты 'Проверить оружие' не заданы")
    end
end)

testBtn("🧪 Тест: Нажать 'Деактивировать'", function()
    if Settings.Buttons.Deactivate then
        fireButtonAction(Settings.Buttons.Deactivate)
        log("Тест: Деактивировать нажата")
    else
        log("❌ Координаты 'Деактивировать' не заданы")
    end
end)

testBtn("🧪 Тест: Сбросить состояние", function()
    ActionState = "idle"
    CurrentTarget = nil
    StateData = {}
    log("Состояние сброшено")
end, Color3.fromRGB(120, 60, 60))

-- ─── ВКЛАДКА: НАСТРОЙКИ ───
local SettingsTab = Instance.new("ScrollingFrame")
SettingsTab.Size = UDim2.new(1, -10, 1, -10)
SettingsTab.Position = UDim2.new(0, 5, 0, 5)
SettingsTab.BackgroundTransparency = 1
SettingsTab.BorderSizePixel = 0
SettingsTab.ScrollBarThickness = 4
SettingsTab.CanvasSize = UDim2.new(0, 0, 0, 800)
SettingsTab.Visible = false
SettingsTab.Parent = ContentFrame

local SettingsLayout = Instance.new("UIListLayout")
SettingsLayout.Padding = UDim.new(0, 5)
SettingsLayout.Parent = SettingsTab

local function makeToggle(parent, text, default, callback)
    local row = Instance.new("Frame")
    row.Size = UDim2.new(1, -10, 0, 30)
    row.BackgroundColor3 = Color3.fromRGB(30, 30, 38)
    row.BorderSizePixel = 0
    row.Parent = parent
    local rc = Instance.new("UICorner")
    rc.CornerRadius = UDim.new(0, 5)
    rc.Parent = row

    local lbl = Instance.new("TextLabel")
    lbl.Text = text
    lbl.Size = UDim2.new(1, -70, 1, 0)
    lbl.Position = UDim2.new(0, 8, 0, 0)
    lbl.BackgroundTransparency = 1
    lbl.TextColor3 = Color3.fromRGB(220, 220, 220)
    lbl.Font = Enum.Font.Gotham
    lbl.TextSize = 13
    lbl.TextXAlignment = Enum.TextXAlignment.Left
    lbl.Parent = row

    local state = default
    local btn = Instance.new("TextButton")
    btn.Size = UDim2.new(0, 50, 0, 22)
    btn.Position = UDim2.new(1, -58, 0.5, -11)
    btn.BackgroundColor3 = state and Color3.fromRGB(0, 170, 90) or Color3.fromRGB(80, 80, 90)
    btn.Text = state and "ВКЛ" or "ВЫКЛ"
    btn.TextColor3 = Color3.fromRGB(255, 255, 255)
    btn.Font = Enum.Font.GothamBold
    btn.TextSize = 11
    btn.BorderSizePixel = 0
    btn.Parent = row
    local bc = Instance.new("UICorner")
    bc.CornerRadius = UDim.new(0, 4)
    bc.Parent = btn

    btn.MouseButton1Click:Connect(function()
        state = not state
        btn.BackgroundColor3 = state and Color3.fromRGB(0, 170, 90) or Color3.fromRGB(80, 80, 90)
        btn.Text = state and "ВКЛ" or "ВЫКЛ"
        callback(state)
    end)
    return row
end

local function makeInput(parent, text, default, callback)
    local row = Instance.new("Frame")
    row.Size = UDim2.new(1, -10, 0, 30)
    row.BackgroundColor3 = Color3.fromRGB(30, 30, 38)
    row.BorderSizePixel = 0
    row.Parent = parent
    local rc = Instance.new("UICorner")
    rc.CornerRadius = UDim.new(0, 5)
    rc.Parent = row

    local lbl = Instance.new("TextLabel")
    lbl.Text = text
    lbl.Size = UDim2.new(0.5, -10, 1, 0)
    lbl.Position = UDim2.new(0, 8, 0, 0)
    lbl.BackgroundTransparency = 1
    lbl.TextColor3 = Color3.fromRGB(220, 220, 220)
    lbl.Font = Enum.Font.Gotham
    lbl.TextSize = 12
    lbl.TextXAlignment = Enum.TextXAlignment.Left
    lbl.Parent = row

    local input = Instance.new("TextBox")
    input.Size = UDim2.new(0.5, -10, 0, 22)
    input.Position = UDim2.new(0.5, 0, 0.5, -11)
    input.BackgroundColor3 = Color3.fromRGB(45, 45, 55)
    input.Text = tostring(default)
    input.TextColor3 = Color3.fromRGB(255, 255, 255)
    input.Font = Enum.Font.Gotham
    input.TextSize = 12
    input.BorderSizePixel = 0
    input.ClearTextOnFocus = false
    input.Parent = row
    local ic = Instance.new("UICorner")
    ic.CornerRadius = UDim.new(0, 4)
    ic.Parent = input

    input.FocusLost:Connect(function()
        local num = tonumber(input.Text)
        if num then callback(num) end
    end)
    return row
end

-- Автодействия
local section1 = Instance.new("TextLabel")
section1.Text = "── АВТОДЕЙСТВИЯ ──"
section1.Size = UDim2.new(1, -10, 0, 22)
section1.BackgroundTransparency = 1
section1.TextColor3 = Color3.fromRGB(255, 200, 100)
section1.Font = Enum.Font.GothamBold
section1.TextSize = 13
section1.Parent = SettingsTab

makeToggle(SettingsTab, "Автодействия ВКЛ", Settings.AutoActions, function(v) Settings.AutoActions = v; log("Автодействия: " .. tostring(v)) end)
makeToggle(SettingsTab, "Нажимать 'Активировать'", Settings.DoActivate, function(v) Settings.DoActivate = v end)
makeToggle(SettingsTab, "Нажимать 'Выдать билет'", Settings.DoGiveTicket, function(v) Settings.DoGiveTicket = v end)
makeToggle(SettingsTab, "Нажимать 'Проверить оружие'", Settings.DoCheckWeapon, function(v) Settings.DoCheckWeapon = v end)
makeToggle(SettingsTab, "Нажимать 'Деактивировать'", Settings.DoDeactivate, function(v) Settings.DoDeactivate = v end)

makeInput(SettingsTab, "Радиус обнаружения (м)", Settings.TriggerRadius, function(v) Settings.TriggerRadius = v end)
makeInput(SettingsTab, "Порог приближения (м)", Settings.ApproachThreshold, function(v) Settings.ApproachThreshold = v end)
makeInput(SettingsTab, "Ожидание после Активировать (с)", Settings.WaitAfterActivate, function(v) Settings.WaitAfterActivate = v end)
makeInput(SettingsTab, "Ожидание перед Проверить (с)", Settings.WaitBeforeCheck, function(v) Settings.WaitBeforeCheck = v end)
makeInput(SettingsTab, "Ожидание перед Деактивировать (с)", Settings.WaitBeforeDeactivate, function(v) Settings.WaitBeforeDeactivate = v end)
makeInput(SettingsTab, "Ожидание если ушёл (с)", Settings.WaitLeftWithoutApproach, function(v) Settings.WaitLeftWithoutApproach = v end)

-- ESP
local section2 = Instance.new("TextLabel")
section2.Text = "── ESP ──"
section2.Size = UDim2.new(1, -10, 0, 22)
section2.BackgroundTransparency = 1
section2.TextColor3 = Color3.fromRGB(255, 200, 100)
section2.Font = Enum.Font.GothamBold
section2.TextSize = 13
section2.Parent = SettingsTab

makeToggle(SettingsTab, "ESP включён", Settings.Enabled, function(v) Settings.Enabled = v end)
makeToggle(SettingsTab, "Проверка команды", Settings.TeamCheck, function(v) Settings.TeamCheck = v end)

-- Координаты кнопок
local section3 = Instance.new("TextLabel")
section3.Text = "── КООРДИНАТЫ КНОПОК ──"
section3.Size = UDim2.new(1, -10, 0, 22)
section3.BackgroundTransparency = 1
section3.TextColor3 = Color3.fromRGB(255, 200, 100)
section3.Font = Enum.Font.GothamBold
section3.TextSize = 13
section3.Parent = SettingsTab

local function makeButtonSetter(name, key)
    local row = Instance.new("Frame")
    row.Size = UDim2.new(1, -10, 0, 32)
    row.BackgroundColor3 = Color3.fromRGB(30, 30, 38)
    row.BorderSizePixel = 0
    row.Parent = SettingsTab
    local rc = Instance.new("UICorner")
    rc.CornerRadius = UDim.new(0, 5)
    rc.Parent = row

    local lbl = Instance.new("TextLabel")
    lbl.Text = name
    lbl.Size = UDim2.new(0.5, -10, 1, 0)
    lbl.Position = UDim2.new(0, 8, 0, 0)
    lbl.BackgroundTransparency = 1
    lbl.TextColor3 = Color3.fromRGB(220, 220, 220)
    lbl.Font = Enum.Font.Gotham
    lbl.TextSize = 12
    lbl.TextXAlignment = Enum.TextXAlignment.Left
    lbl.Parent = row

    local btn = Instance.new("TextButton")
    btn.Size = UDim2.new(0.5, -10, 0, 24)
    btn.Position = UDim2.new(0.5, 0, 0.5, -12)
    btn.BackgroundColor3 = Settings.Buttons[key] and Color3.fromRGB(0, 140, 80) or Color3.fromRGB(140, 80, 40)
    btn.Text = Settings.Buttons[key] and "✓ Задано" or "Выбрать"
    btn.TextColor3 = Color3.fromRGB(255, 255, 255)
    btn.Font = Enum.Font.GothamBold
    btn.TextSize = 12
    btn.BorderSizePixel = 0
    btn.Parent = row
    local bc = Instance.new("UICorner")
    bc.CornerRadius = UDim.new(0, 4)
    bc.Parent = btn

    btn.MouseButton1Click:Connect(function()
        log("🎯 Кликни по кнопке '" .. name .. "' в игре...")
        -- Дадим UI закрыться на мгновение
        MainGui.Enabled = false
        task.wait(0.3)
        local clicked = false
        local conn
        conn = UserInputService.InputBegan:Connect(function(input, gpe)
            if gpe then return end
            if input.UserInputType == Enum.UserInputType.MouseButton1
               or input.UserInputType == Enum.UserInputType.Touch then
                local gui = LocalPlayer.PlayerGui:GetGuiObjectsAtPosition(input.Position.X, input.Position.Y)
                local nameFound = "?"
                for _, obj in pairs(gui) do
                    if obj:IsA("GuiButton") then
                        -- Собираем путь
                        local path = obj.Name
                        local parent = obj.Parent
                        while parent and parent ~= game do
                            path = parent.Name .. "." .. path
                            parent = parent.Parent
                        end
                        Settings.Buttons[key] = {
                            Path = path,
                            Pos = {X = input.Position.X, Y = input.Position.Y}
                        }
                        nameFound = obj.Name
                        clicked = true
                        break
                    end
                end
                if clicked then
                    log("✓ Задано: " .. nameFound .. " → " .. Settings.Buttons[key].Path)
                else
                    log("❌ Не удалось найти кнопку в этой точке")
                end
                conn:Disconnect()
                MainGui.Enabled = true
                btn.Text = Settings.Buttons[key] and "✓ Задано" or "Выбрать"
                btn.BackgroundColor3 = Settings.Buttons[key] and Color3.fromRGB(0, 140, 80) or Color3.fromRGB(140, 80, 40)
            end
        end)
    end)
end

makeButtonSetter("Активировать", "Activate")
makeButtonSetter("Выдать билет", "GiveTicket")
makeButtonSetter("Проверить оружие", "CheckWeapon")
makeButtonSetter("Деактивировать", "Deactivate")

-- Прицел
local section4 = Instance.new("TextLabel")
section4.Text = "── ПРИЦЕЛ ──"
section4.Size = UDim2.new(1, -10, 0, 22)
section4.BackgroundTransparency = 1
section4.TextColor3 = Color3.fromRGB(255, 200, 100)
section4.Font = Enum.Font.GothamBold
section4.TextSize = 13
section4.Parent = SettingsTab

makeButton(SettingsTab, "🎯 Создать прицел", UDim2.new(0, 5, 0, 0), UDim2.new(1, -10, 0, 32), function()
    getgenv().ShowCrosshair()
    log("Прицел открыт")
end, Color3.fromRGB(60, 90, 140))

-- Кнопки вкладок
local tabs = {
    {Name = "Консоль", Frame = ConsoleTab, Button = nil},
    {Name = "Тест", Frame = TestTab, Button = nil},
    {Name = "Настройки", Frame = SettingsTab, Button = nil},
}

local function selectTab(index)
    for i, tab in ipairs(tabs) do
        tab.Frame.Visible = (i == index)
        if tab.Button then
            tab.Button.BackgroundColor3 = (i == index) and Color3.fromRGB(60, 90, 140) or Color3.fromRGB(40, 40, 50)
        end
    end
end

for i, tab in ipairs(tabs) do
    local btn = Instance.new("TextButton")
    btn.Text = tab.Name
    btn.Size = UDim2.new(1/#tabs, -4, 1, 0)
    btn.Position = UDim2.new((i-1)/#tabs, 2, 0, 0)
    btn.BackgroundColor3 = Color3.fromRGB(40, 40, 50)
    btn.TextColor3 = Color3.fromRGB(255, 255, 255)
    btn.Font = Enum.Font.GothamBold
    btn.TextSize = 12
    btn.BorderSizePixel = 0
    btn.Parent = TabBar
    local c = Instance.new("UICorner")
    c.CornerRadius = UDim.new(0, 5)
    c.Parent = btn
    btn.MouseButton1Click:Connect(function() selectTab(i) end)
    tab.Button = btn
end
selectTab(1)

CloseBtn.MouseButton1Click:Connect(function()
    MainGui.Enabled = false
    log("UI скрыт. Для возврата: getgenv().ShowUI()")
end)

-- ═══════════════════════════════════════════════════════
-- 🎯 ОКНО ПРИЦЕЛА
-- ═══════════════════════════════════════════════════════
local CrosshairGui = Instance.new("ScreenGui")
CrosshairGui.Name = "ESP_Crosshair"
CrosshairGui.ResetOnSpawn = false
CrosshairGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
pcall(function() CrosshairGui.Parent = CoreGui end)
if not CrosshairGui.Parent then CrosshairGui.Parent = LocalPlayer:WaitForChild("PlayerGui") end
CrosshairGui.Enabled = false

local CrossFrame = Instance.new("Frame")
CrossFrame.Size = UDim2.new(0, 300, 0, 340)
CrossFrame.Position = UDim2.new(0.5, -150, 0.5, -170)
CrossFrame.BackgroundColor3 = Color3.fromRGB(25, 25, 30)
CrossFrame.BorderSizePixel = 0
CrossFrame.Active = true
CrossFrame.Parent = CrosshairGui
makeDraggable(CrossFrame)
local cc = Instance.new("UICorner")
cc.CornerRadius = UDim.new(0, 10)
cc.Parent = CrossFrame

local cTitle = Instance.new("TextLabel")
cTitle.Text = "🎯 ПРИЦЕЛ"
cTitle.Size = UDim2.new(1, 0, 0, 30)
cTitle.BackgroundColor3 = Color3.fromRGB(35, 35, 45)
cTitle.TextColor3 = Color3.fromRGB(255, 255, 255)
cTitle.Font = Enum.Font.GothamBold
cTitle.TextSize = 14
cTitle.BorderSizePixel = 0
cTitle.Parent = CrossFrame
local ctc = Instance.new("UICorner")
ctc.CornerRadius = UDim.new(0, 10)
ctc.Parent = cTitle

-- Сам прицел
local CrossArea = Instance.new("Frame")
CrossArea.Size = UDim2.new(0, 120, 0, 120)
CrossArea.Position = UDim2.new(0.5, -60, 0, 50)
CrossArea.BackgroundColor3 = Color3.fromRGB(15, 15, 20)
CrossArea.BorderSizePixel = 0
CrossArea.Parent = CrossFrame
local cac = Instance.new("UICorner")
cac.CornerRadius = UDim.new(0, 6)
cac.Parent = CrossArea

local crossX = Instance.new("Frame")
crossX.Size = UDim2.new(0, 80, 0, 2)
crossX.Position = UDim2.new(0.5, -40, 0.5, -1)
crossX.BackgroundColor3 = Settings.CrosshairColor
crossX.BorderSizePixel = 0
crossX.Parent = CrossArea

local crossY = Instance.new("Frame")
crossY.Size = UDim2.new(0, 2, 0, 80)
crossY.Position = UDim2.new(0.5, -1, 0.5, -40)
crossY.BackgroundColor3 = Settings.CrosshairColor
crossY.BorderSizePixel = 0
crossY.Parent = CrossArea

-- Кнопка "Выбрать" под прицелом
local PickBtn = Instance.new("TextButton")
PickBtn.Text = "Выбрать"
PickBtn.Size = UDim2.new(0, 120, 0, 34)
PickBtn.Position = UDim2.new(0.5, -60, 0, 190)
PickBtn.BackgroundColor3 = Color3.fromRGB(60, 90, 140)
PickBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
PickBtn.Font = Enum.Font.GothamBold
PickBtn.TextSize = 13
PickBtn.BorderSizePixel = 0
PickBtn.Parent = CrossFrame
local pbc = Instance.new("UICorner")
pbc.CornerRadius = UDim.new(0, 6)
pbc.Parent = PickBtn

PickBtn.MouseButton1Click:Connect(function()
    CrosshairGui.Enabled = false
    task.wait(0.3)
    log("🎯 Кликни по экрану, чтобы задать координаты для прицела...")
    local conn
    conn = UserInputService.InputBegan:Connect(function(input, gpe)
        if gpe then return end
        if input.UserInputType == Enum.UserInputType.MouseButton1
           or input.UserInputType == Enum.UserInputType.Touch then
            Settings.CrosshairPos = {X = input.Position.X, Y = input.Position.Y}
            log(string.format("✓ Координаты прицела: X=%d Y=%d", input.Position.X, input.Position.Y))
            conn:Disconnect()
            CrosshairGui.Enabled = true
        end
    end)
end)

-- ═══════════════════════════════════════════════════════
-- 🖱️ ВЫПОЛНЕНИЕ КЛИКА ПО КНОПКЕ
-- ═══════════════════════════════════════════════════════
function fireButtonAction(btnData)
    if not btnData then return false end
    local path = btnData.Path
    if not path or path == "" then return false end

    -- Пытаемся найти объект по пути
    local parts = {}
    for part in string.gmatch(path, "[^%.]+") do
        table.insert(parts, part)
    end

    -- Ищем в PlayerGui
    local obj = LocalPlayer.PlayerGui
    for _, part in ipairs(parts) do
        if obj then
            obj = obj:FindFirstChild(part)
        end
    end

    if obj and (obj:IsA("GuiButton") or obj:IsA("TextButton")) then
        -- Симулируем клик
        pcall(function()
            obj.MouseButton1Click:Fire()
        end)
        return true
    end

    -- Альтернатива: клик через VirtualInputManager (не всегда доступно)
    log("⚠ Кнопка не найдена: " .. path)
    return false
end

-- ═══════════════════════════════════════════════════════
-- 🎨 ESP (BillboardGui)
-- ═══════════════════════════════════════════════════════
local function createESP(player)
    if player == LocalPlayer then return end
    local esp = {}

    local billboard = Instance.new("BillboardGui")
    billboard.Name = "ESP_Billboard"
    billboard.AlwaysOnTop = true
    billboard.Size = UDim2.new(0, 200, 0, 50)
    billboard.StudsOffset = Vector3.new(0, Settings.HeadOffset, 0)
    billboard.Enabled = false
    billboard.Parent = MainGui

    local nameLabel = Instance.new("TextLabel")
    nameLabel.Size = UDim2.new(1, 0, 0.5, 0)
    nameLabel.BackgroundTransparency = 1
    nameLabel.Font = Enum.Font.SourceSansBold
    nameLabel.TextSize = Settings.TextSize
    nameLabel.TextColor3 = Settings.NameColor
    nameLabel.TextStrokeTransparency = 0
    nameLabel.TextStrokeColor3 = Color3.fromRGB(0, 0, 0)
    nameLabel.Parent = billboard

    local distLabel = Instance.new("TextLabel")
    distLabel.Size = UDim2.new(1, 0, 0.5, 0)
    distLabel.Position = UDim2.new(0, 0, 0.5, 0)
    distLabel.BackgroundTransparency = 1
    distLabel.Font = Enum.Font.SourceSans
    distLabel.TextSize = Settings.TextSize - 2
    distLabel.TextColor3 = Color3.fromRGB(200, 200, 200)
    distLabel.TextStrokeTransparency = 0
    distLabel.TextStrokeColor3 = Color3.fromRGB(0, 0, 0)
    distLabel.Parent = billboard

    local healthBg = Instance.new("Frame")
    healthBg.BackgroundColor3 = Color3.fromRGB(60, 60, 60)
    healthBg.BorderSizePixel = 0
    healthBg.Size = UDim2.new(0, 4, 1, 0)
    healthBg.Position = UDim2.new(-0.05, 0, 0, 0)
    healthBg.Parent = billboard

    local healthFill = Instance.new("Frame")
    healthFill.BackgroundColor3 = Settings.HealthColor
    healthFill.BorderSizePixel = 0
    healthFill.Size = UDim2.new(1, 0, 1, 0)
    healthFill.AnchorPoint = Vector2.new(0, 1)
    healthFill.Position = UDim2.new(0, 0, 1, 0)
    healthFill.Parent = healthBg

    esp.Billboard = billboard
    esp.NameLabel = nameLabel
    esp.DistLabel = distLabel
    esp.HealthBg = healthBg
    esp.HealthFill = healthFill

    ESPCache[player] = esp
end

local function removeESP(player)
    local esp = ESPCache[player]
    if not esp then return end
    if esp.Billboard then esp.Billboard:Destroy() end
    ESPCache[player] = nil
end

-- ═══════════════════════════════════════════════════════
-- 🔄 ОСНОВНОЙ ЦИКЛ (ESP + АВТОДЕЙСТВИЯ)
-- ═══════════════════════════════════════════════════════
RunService.RenderStepped:Connect(function(dt)
    -- ESP
    if not Settings.Enabled then
        for _, esp in pairs(ESPCache) do
            if esp.Billboard then esp.Billboard.Enabled = false end
        end
    else
        for player, esp in pairs(ESPCache) do
            local char = player.Character
            local hrp = char and char:FindFirstChild("HumanoidRootPart")
            local head = char and char:FindFirstChild("Head")
            local hum = char and char:FindFirstChildOfClass("Humanoid")
            if not hrp or not head or not hum or hum.Health <= 0 then
                esp.Billboard.Enabled = false
                continue
            end
            if Settings.TeamCheck and player.Team == LocalPlayer.Team then
                esp.Billboard.Enabled = false
                continue
            end
            local d = (Camera.CFrame.Position - hrp.Position).Magnitude
            if d > Settings.MaxDistance then
                esp.Billboard.Enabled = false
                continue
            end
            esp.Billboard.Adornee = head
            esp.Billboard.Enabled = true
            esp.NameLabel.Text = player.Name
            esp.NameLabel.Visible = Settings.ShowName
            esp.DistLabel.Text = string.format("[%d m]", d)
            esp.DistLabel.Visible = Settings.ShowDistance
            local hp = hum.Health / hum.MaxHealth
            esp.HealthFill.Size = UDim2.new(1, 0, hp, 0)
            esp.HealthFill.BackgroundColor3 = Color3.fromRGB(255 * (1 - hp), 255 * hp, 0)
            esp.HealthBg.Visible = Settings.ShowHealth
        end
    end

    -- Автодействия
    if not Settings.AutoActions then return end

    StateTimer = StateTimer + dt

    -- IDLE: ищем игрока в радиусе
    if ActionState == "idle" then
        for _, p in pairs(Players:GetPlayers()) do
            if p ~= LocalPlayer and p.Character then
                local hrp = p.Character:FindFirstChild("HumanoidRootPart")
                if hrp then
                    local d = (Camera.CFrame.Position - hrp.Position).Magnitude
                    if d <= Settings.TriggerRadius then
                        CurrentTarget = p
                        InitialDistance = d
                        ActionState = "waiting"
                        StateTimer = 0
                        log("👤 Обнаружен: " .. p.Name .. " (" .. math.floor(d) .. "м)")
                        if Settings.DoActivate then
                            fireButtonAction(Settings.Buttons.Activate)
                            log("▶ Активировать")
                        end
                        break
                    end
                end
            end
        end
    end

    -- WAITING: ждём 10 сек, проверяем приближение
    if ActionState == "waiting" and CurrentTarget then
        if StateTimer >= Settings.WaitAfterActivate then
            local char = CurrentTarget.Character
            local hrp = char and char:FindFirstChild("HumanoidRootPart")
            if hrp then
                local d = (Camera.CFrame.Position - hrp.Position).Magnitude
                if d < InitialDistance - Settings.ApproachThreshold then
                    -- Игрок подошёл
                    log("👣 " .. CurrentTarget.Name .. " подошёл ближе")
                    if Settings.DoGiveTicket then
                        fireButtonAction(Settings.Buttons.GiveTicket)
                        log("🎫 Выдать билет")
                    end
                    ActionState = "checkWeapon"
                    StateTimer = 0
                else
                    -- Не подошёл
                    log("💨 " .. CurrentTarget.Name .. " не подошёл")
                    ActionState = "waitLeft"
                    StateTimer = 0
                end
            else
                ActionState = "waitLeft"
                StateTimer = 0
            end
        end
    end

    -- CHECK WEAPON: через 3 сек нажимаем "Проверить оружие"
    if ActionState == "checkWeapon" and StateTimer >= Settings.WaitBeforeCheck then
        if Settings.DoCheckWeapon then
            fireButtonAction(Settings.Buttons.CheckWeapon)
            log("🔫 Проверить оружие")
        end
        ActionState = "deactivate"
        StateTimer = 0
    end

    -- DEACTIVATE: через 3 сек нажимаем "Деактивировать"
    if ActionState == "deactivate" and StateTimer >= Settings.WaitBeforeDeactivate then
        if Settings.DoDeactivate then
            fireButtonAction(Settings.Buttons.Deactivate)
            log("⏹ Деактивировать")
        end
        ActionState = "idle"
        CurrentTarget = nil
        StateTimer = 0
    end

    -- WAIT LEFT: ждём 5 сек, если игрок ушёл
    if ActionState == "waitLeft" and StateTimer >= Settings.WaitLeftWithoutApproach then
        if Settings.DoDeactivate then
            fireButtonAction(Settings.Buttons.Deactivate)
            log("⏹ Деактивировать (ушёл)")
        end
        ActionState = "idle"
        CurrentTarget = nil
        StateTimer = 0
    end
end)

-- ═══════════════════════════════════════════════════════
-- 🎧 СОБЫТИЯ
-- ═══════════════════════════════════════════════════════
Players.PlayerAdded:Connect(createESP)
Players.PlayerRemoving:Connect(removeESP)
for _, p in pairs(Players:GetPlayers()) do createESP(p) end

-- ═══════════════════════════════════════════════════════
-- 🌐 ГЛОБАЛЬНОЕ API
-- ═══════════════════════════════════════════════════════
getgenv().ESP = {
    Settings = Settings,
    Toggle = function() Settings.Enabled = not Settings.Enabled end,
    ToggleAuto = function() Settings.AutoActions = not Settings.AutoActions; log("Автодействия: " .. tostring(Settings.AutoActions)) end,
    SetDistance = function(d) Settings.MaxDistance = d end,
    Destroy = function()
        for p, _ in pairs(ESPCache) do removeESP(p) end
        MainGui:Destroy()
        CrosshairGui:Destroy()
    end,
}

getgenv().ShowUI = function() MainGui.Enabled = true end
getgenv().HideUI = function() MainGui.Enabled = false end
getgenv().ShowCrosshair = function() CrosshairGui.Enabled = true end
getgenv().HideCrosshair = function() CrosshairGui.Enabled = false end

log("✅ Скрипт загружен!")
log("UI: getgenv().ShowUI() | Скрыть: getgenv().HideUI()")
log("Прицел: getgenv().ShowCrosshair()")
