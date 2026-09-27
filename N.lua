--[[
    PLAYERS ESP + AUTO ACTIONS + UI
    Версия: 3.2 (прицел без чёрного квадрата + клик по координатам)
    Для Delta Executor
--]]

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")
local CoreGui = game:GetService("CoreGui")
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
}

-- ═══════════════════════════════════════════════════════
-- ⚙️ НАСТРОЙКИ
-- ═══════════════════════════════════════════════════════
local Settings = {
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

    Buttons = {
        Activate = nil,
        GiveTicket = nil,
        CheckWeapon = nil,
        Deactivate = nil,
    },

    CrosshairColor = Color3.fromRGB(0, 255, 100),
    CrosshairSize = 80,
    CrosshairBoxSize = 180,
}

local ESPCache = {}
local CurrentTarget = nil
local ActionState = "idle"
local StateTimer = 0
local InitialDistance = 0

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
-- 🔍 ПОИСК И КЛИК ПО КНОПКЕ ПО КООРДИНАТАМ
-- ═══════════════════════════════════════════════════════
local function findButtonAtPosition(x, y)
    local candidates = {}

    -- PlayerGui
    pcall(function()
        for _, gui in pairs(LocalPlayer.PlayerGui:GetChildren()) do
            if gui:IsA("ScreenGui") and gui.Enabled then
                local objs = gui:GetGuiObjectsAtPosition(x, y)
                for _, o in pairs(objs) do
                    table.insert(candidates, o)
                end
            end
        end
    end)

    -- CoreGui
    pcall(function()
        for _, gui in pairs(CoreGui:GetChildren()) do
            if gui:IsA("ScreenGui") and gui.Enabled then
                local objs = gui:GetGuiObjectsAtPosition(x, y)
                for _, o in pairs(objs) do
                    table.insert(candidates, o)
                end
            end
        end
    end)

    -- Ищем кнопку или её родителя-кнопку
    for _, obj in ipairs(candidates) do
        if obj:IsA("GuiButton") then
            return obj
        end
        local p = obj.Parent
        while p and p ~= game do
            if p:IsA("GuiButton") then
                return p
            end
            p = p.Parent
        end
    end
    return nil
end

local function simulateClick(button, x, y)
    if not button then return false end
    pcall(function() button.MouseButton1Click:Fire() end)
    pcall(function()
        button.MouseButton1Down:Fire(x or 0, y or 0)
        button.MouseButton1Up:Fire(x or 0, y or 0)
    end)
    pcall(function()
        if button.Activate then button:Activate() end
    end)
    return true
end

function fireButtonAction(btnData)
    if not btnData then return false end

    -- Приоритет: координаты
    if btnData.Pos then
        local x, y = btnData.Pos.X, btnData.Pos.Y
        local button = findButtonAtPosition(x, y)
        if button then
            simulateClick(button, x, y)
            log("✓ Клик: " .. button.Name .. " (" .. button.ClassName .. ")", Theme.Success)
            return true
        end
        log("⚠ Кнопка не найдена на X=" .. x .. ", Y=" .. y, Theme.Danger)
    end

    -- Резерв: по пути
    if btnData.Path and btnData.Path ~= "" then
        local parts = {}
        for part in string.gmatch(btnData.Path, "[^%.]+") do
            table.insert(parts, part)
        end
        local obj = LocalPlayer.PlayerGui
        for _, part in ipairs(parts) do
            if obj then obj = obj:FindFirstChild(part) end
        end
        if obj and obj:IsA("GuiButton") then
            simulateClick(obj)
            return true
        end
    end

    return false
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
MainFrame.Size = UDim2.new(0, 460, 0, 380)
MainFrame.Position = UDim2.new(0.5, -230, 0.5, -190)
MainFrame.BackgroundColor3 = Theme.Bg
MainFrame.BorderSizePixel = 0
MainFrame.Active = true
MainFrame.Parent = MainGui
addCorner(MainFrame, 12)
addStroke(MainFrame, Theme.Border, 1.5)
makeDraggable(MainFrame)

-- Заголовок
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
Title.Text = "ESP  •  AUTO ACTIONS"
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

-- Вкладки
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

-- Консоль
local ConsoleTab = Instance.new("ScrollingFrame")
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

function log(text, color)
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

log("Консоль инициализирована", Theme.TextDim)

-- Тест
local TestTab = Instance.new("ScrollingFrame")
TestTab.Size = UDim2.new(1, -12, 1, -12)
TestTab.Position = UDim2.new(0, 6, 0, 6)
TestTab.BackgroundTransparency = 1
TestTab.BorderSizePixel = 0
TestTab.ScrollBarThickness = 5
TestTab.ScrollBarImageColor3 = Theme.Accent
TestTab.CanvasSize = UDim2.new(0, 0, 0, 400)
TestTab.Visible = false
TestTab.Parent = ContentFrame

local TestLayout = Instance.new("UIListLayout")
TestLayout.Padding = UDim.new(0, 8)
TestLayout.Parent = TestTab

-- Настройки
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
local function makeSection(text)
    local s = Instance.new("TextLabel")
    s.Text = "  " .. text
    s.Size = UDim2.new(1, 0, 0, 26)
    s.BackgroundColor3 = Theme.Bg
    s.TextColor3 = Theme.Accent
    s.Font = Enum.Font.GothamBold
    s.TextSize = 12
    s.TextXAlignment = Enum.TextXAlignment.Left
    s.BorderSizePixel = 0
    s.Parent = SettingsTab
    addCorner(s, 6)
    return s
end

local function makeButton(parent, text, callback, color)
    local btn = Instance.new("TextButton")
    btn.Text = text
    btn.Size = UDim2.new(1, 0, 0, 34)
    btn.BackgroundColor3 = color or Theme.BgLighter
    btn.TextColor3 = Theme.Text
    btn.Font = Enum.Font.Gotham
    btn.TextSize = 13
    btn.BorderSizePixel = 0
    btn.AutoButtonColor = false
    btn.Parent = parent
    addCorner(btn, 8)

    btn.MouseEnter:Connect(function()
        TweenService:Create(btn, TweenInfo.new(0.15), {
            BackgroundColor3 = Theme.AccentHover
        }):Play()
    end)
    btn.MouseLeave:Connect(function()
        TweenService:Create(btn, TweenInfo.new(0.15), {
            BackgroundColor3 = btn:GetAttribute("BaseColor") or color or Theme.BgLighter
        }):Play()
    end)
    btn:SetAttribute("BaseColor", color or Theme.BgLighter)
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
-- 🎯 ОКНО ПРИЦЕЛА (без чёрного квадрата)
-- ═══════════════════════════════════════════════════════
local CrosshairGui = Instance.new("ScreenGui")
CrosshairGui.Name = "ESP_Crosshair"
CrosshairGui.ResetOnSpawn = false
CrosshairGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
CrosshairGui.IgnoreGuiInset = true
CrosshairGui.Enabled = false
pcall(function() CrosshairGui.Parent = CoreGui end)
if not CrosshairGui.Parent then CrosshairGui.Parent = LocalPlayer:WaitForChild("PlayerGui") end

-- ─── Окно ───
local CrossFrame = Instance.new("Frame")
CrossFrame.Size = UDim2.new(0, 320, 0, 380)
CrossFrame.Position = UDim2.new(0.5, -160, 0.5, -190)
CrossFrame.BackgroundColor3 = Theme.Bg
CrossFrame.BorderSizePixel = 0
CrossFrame.Active = true
CrossFrame.Parent = CrosshairGui
addCorner(CrossFrame, 12)
addStroke(CrossFrame, Theme.Border, 1.5)
makeDraggable(CrossFrame)

-- Заголовок окна
local CrossTitle = Instance.new("Frame")
CrossTitle.Size = UDim2.new(1, 0, 0, 38)
CrossTitle.BackgroundColor3 = Theme.BgLight
CrossTitle.BorderSizePixel = 0
CrossTitle.Parent = CrossFrame
addCorner(CrossTitle, 12)

local CrossTitleFix = Instance.new("Frame")
CrossTitleFix.Size = UDim2.new(1, 0, 0, 10)
CrossTitleFix.Position = UDim2.new(0, 0, 1, -10)
CrossTitleFix.BackgroundColor3 = Theme.BgLight
CrossTitleFix.BorderSizePixel = 0
CrossTitleFix.Parent = CrossTitle

local CrossTitleLbl = Instance.new("TextLabel")
CrossTitleLbl.Text = "🎯 ПРИЦЕЛ"
CrossTitleLbl.Size = UDim2.new(1, -20, 1, 0)
CrossTitleLbl.Position = UDim2.new(0, 10, 0, 0)
CrossTitleLbl.BackgroundTransparency = 1
CrossTitleLbl.TextColor3 = Theme.Text
CrossTitleLbl.Font = Enum.Font.GothamBold
CrossTitleLbl.TextSize = 14
CrossTitleLbl.TextXAlignment = Enum.TextXAlignment.Center
CrossTitleLbl.Parent = CrossTitle

-- ─── Область прицела (БЕЗ фона, БЕЗ рамки — только для центрирования креста) ───
local SquareArea = Instance.new("Frame")
SquareArea.Name = "SquareArea"
SquareArea.Size = UDim2.new(0, Settings.CrosshairBoxSize, 0, Settings.CrosshairBoxSize)
SquareArea.Position = UDim2.new(0.5, -Settings.CrosshairBoxSize/2, 0, 60)
SquareArea.BackgroundTransparency = 1     -- ⬅️ полностью прозрачный
SquareArea.BorderSizePixel = 0
SquareArea.Parent = CrossFrame
-- UIStroke не добавляем — рамки нет

-- ─── Крест ───
local CrossH = Instance.new("Frame")
CrossH.Name = "CrossH"
CrossH.Size = UDim2.new(0, Settings.CrosshairSize, 0, 2)
CrossH.Position = UDim2.new(0.5, -Settings.CrosshairSize/2, 0.5, -1)
CrossH.BackgroundColor3 = Settings.CrosshairColor
CrossH.BorderSizePixel = 0
CrossH.Parent = SquareArea

local CrossV = Instance.new("Frame")
CrossV.Name = "CrossV"
CrossV.Size = UDim2.new(0, 2, 0, Settings.CrosshairSize)
CrossV.Position = UDim2.new(0.5, -1, 0.5, -Settings.CrosshairSize/2)
CrossV.BackgroundColor3 = Settings.CrosshairColor
CrossV.BorderSizePixel = 0
CrossV.Parent = SquareArea

-- Центральная точка (координаты)
local CrossDot = Instance.new("Frame")
CrossDot.Name = "CrossDot"
CrossDot.Size = UDim2.new(0, 6, 0, 6)
CrossDot.Position = UDim2.new(0.5, -3, 0.5, -3)
CrossDot.BackgroundColor3 = Color3.fromRGB(255, 255, 0)
CrossDot.BorderSizePixel = 0
CrossDot.Parent = SquareArea
addCorner(CrossDot, 3)

-- Обводка для видимости
local dotStroke = Instance.new("UIStroke")
dotStroke.Color = Color3.fromRGB(0, 0, 0)
dotStroke.Thickness = 1.5
dotStroke.Parent = CrossDot

local hStroke = Instance.new("UIStroke")
hStroke.Color = Color3.fromRGB(0, 0, 0)
hStroke.Thickness = 1.5
hStroke.Parent = CrossH

local vStroke = Instance.new("UIStroke")
vStroke.Color = Color3.fromRGB(0, 0, 0)
vStroke.Thickness = 1.5
vStroke.Parent = CrossV

-- Подпись координат
local CoordLabel = Instance.new("TextLabel")
CoordLabel.Name = "CoordLabel"
CoordLabel.Size = UDim2.new(1, -20, 0, 24)
CoordLabel.Position = UDim2.new(0, 10, 0, 60 + Settings.CrosshairBoxSize + 6)
CoordLabel.BackgroundColor3 = Theme.BgLight
CoordLabel.Text = "X: —   Y: —"
CoordLabel.TextColor3 = Theme.Text
CoordLabel.Font = Enum.Font.Code
CoordLabel.TextSize = 13
CoordLabel.BorderSizePixel = 0
CoordLabel.Parent = CrossFrame
addCorner(CoordLabel, 6)

-- Кнопка "Выбрать"
local SelectBtn = Instance.new("TextButton")
SelectBtn.Name = "SelectBtn"
SelectBtn.Text = "Выбрать (текущие координаты)"
SelectBtn.Size = UDim2.new(1, -20, 0, 40)
SelectBtn.Position = UDim2.new(0, 10, 1, -52)
SelectBtn.BackgroundColor3 = Theme.Accent
SelectBtn.TextColor3 = Theme.Text
SelectBtn.Font = Enum.Font.GothamBold
SelectBtn.TextSize = 13
SelectBtn.BorderSizePixel = 0
SelectBtn.AutoButtonColor = false
SelectBtn.Parent = CrossFrame
addCorner(SelectBtn, 8)

SelectBtn.MouseEnter:Connect(function()
    TweenService:Create(SelectBtn, TweenInfo.new(0.15), {
        BackgroundColor3 = Theme.AccentHover
    }):Play()
end)
SelectBtn.MouseLeave:Connect(function()
    TweenService:Create(SelectBtn, TweenInfo.new(0.15), {
        BackgroundColor3 = Theme.Accent
    }):Play()
end)

-- ─── Переменные выбора ───
local currentPickKey = nil
local currentPickName = nil

local function updateCoordLabel()
    if not currentPickKey then return end
    local centerScreen = SquareArea.AbsolutePosition + SquareArea.AbsoluteSize/2
    CoordLabel.Text = string.format("X: %d   Y: %d", centerScreen.X, centerScreen.Y)
end

RunService.RenderStepped:Connect(function()
    if CrosshairGui.Enabled then
        updateCoordLabel()
    end
end)

-- ─── Открытие окна ───
local function openCrosshairPicker(key, displayName)
    currentPickKey = key
    currentPickName = displayName
    CrossTitleLbl.Text = "🎯 ПРИЦЕЛ — " .. displayName
    CrosshairGui.Enabled = true
    MainGui.Enabled = false
    log("🎯 Выбор координат для: " .. displayName, Theme.Warning)
    task.wait(0.1)
    updateCoordLabel()
end

-- ─── Сохранение координат ───
SelectBtn.MouseButton1Click:Connect(function()
    if not currentPickKey then
        log("❌ Не выбрана цель", Theme.Danger)
        return
    end

    local centerScreen = SquareArea.AbsolutePosition + SquareArea.AbsoluteSize/2
    local x = math.floor(centerScreen.X)
    local y = math.floor(centerScreen.Y)

    -- Ищем кнопку прямо сейчас и сохраняем путь
    local foundButton = findButtonAtPosition(x, y)
    local path = nil
    if foundButton then
        local parts = {}
        local obj = foundButton
        while obj and obj ~= LocalPlayer.PlayerGui and obj ~= CoreGui and obj ~= game do
            table.insert(parts, 1, obj.Name)
            obj = obj.Parent
        end
        if #parts > 0 then
            path = table.concat(parts, ".")
        end
        log("✓ Найдена кнопка: " .. foundButton.Name, Theme.Success)
    end

    Settings.Buttons[currentPickKey] = {
        Path = path,
        Pos = {X = x, Y = y},
    }

    log(string.format("✓ %s: X=%d, Y=%d", currentPickName, x, y), Theme.Success)

    if getgenv().refreshButtonLabels then
        getgenv().refreshButtonLabels()
    end

    CrosshairGui.Enabled = false
    MainGui.Enabled = true
    currentPickKey = nil
    currentPickName = nil
end)

-- ═══════════════════════════════════════════════════════
-- 📋 ВКЛАДКА "ТЕСТ"
-- ═══════════════════════════════════════════════════════
local function makeTestBtn(text, callback, color)
    return makeButton(TestTab, text, callback, color)
end

makeTestBtn("🧪 Найти игроков в радиусе", function()
    local found = 0
    for _, p in pairs(Players:GetPlayers()) do
        if p ~= LocalPlayer and p.Character then
            local hrp = p.Character:FindFirstChild("HumanoidRootPart")
            if hrp then
                local d = (Camera.CFrame.Position - hrp.Position).Magnitude
                if d <= Settings.TriggerRadius then
                    found = found + 1
                    log("Найден: " .. p.Name .. " (" .. math.floor(d) .. "м)", Theme.Warning)
                end
            end
        end
    end
    log("Всего в радиусе: " .. found, found > 0 and Theme.Success or Theme.TextDim)
end)

makeTestBtn("▶  Активировать", function()
    if Settings.Buttons.Activate then
        fireButtonAction(Settings.Buttons.Activate)
        log("Тест: Активировать", Theme.Accent)
    else
        log("❌ Координаты не заданы", Theme.Danger)
    end
end)

makeTestBtn("🎫 Выдать билет", function()
    if Settings.Buttons.GiveTicket then
        fireButtonAction(Settings.Buttons.GiveTicket)
        log("Тест: Выдать билет", Theme.Accent)
    else
        log("❌ Координаты не заданы", Theme.Danger)
    end
end)

makeTestBtn("🔫 Проверить оружие", function()
    if Settings.Buttons.CheckWeapon then
        fireButtonAction(Settings.Buttons.CheckWeapon)
        log("Тест: Проверить оружие", Theme.Accent)
    else
        log("❌ Координаты не заданы", Theme.Danger)
    end
end)

makeTestBtn("⏹  Деактивировать", function()
    if Settings.Buttons.Deactivate then
        fireButtonAction(Settings.Buttons.Deactivate)
        log("Тест: Деактивировать", Theme.Accent)
    else
        log("❌ Координаты не заданы", Theme.Danger)
    end
end)

makeTestBtn("🔄 Сбросить состояние", function()
    ActionState = "idle"
    CurrentTarget = nil
    StateTimer = 0
    log("Состояние сброшено", Theme.Warning)
end, Theme.Danger)

-- ═══════════════════════════════════════════════════════
-- 📋 ВКЛАДКА "НАСТРОЙКИ"
-- ═══════════════════════════════════════════════════════
makeSection("АВТОДЕЙСТВИЯ")
makeToggle(SettingsTab, "Автодействия ВКЛ", Settings.AutoActions, function(v)
    Settings.AutoActions = v
    log("Автодействия: " .. (v and "ВКЛ" or "ВЫКЛ"), v and Theme.Success or Theme.TextDim)
end)
makeToggle(SettingsTab, "Нажимать «Активировать»", Settings.DoActivate, function(v) Settings.DoActivate = v end)
makeToggle(SettingsTab, "Нажимать «Выдать билет»", Settings.DoGiveTicket, function(v) Settings.DoGiveTicket = v end)
makeToggle(SettingsTab, "Нажимать «Проверить оружие»", Settings.DoCheckWeapon, function(v) Settings.DoCheckWeapon = v end)
makeToggle(SettingsTab, "Нажимать «Деактивировать»", Settings.DoDeactivate, function(v) Settings.DoDeactivate = v end)

makeSection("ПАРАМЕТРЫ")
makeInput(SettingsTab, "Радиус обнаружения (м)", Settings.TriggerRadius, function(v) Settings.TriggerRadius = v end)
makeInput(SettingsTab, "Порог приближения (м)", Settings.ApproachThreshold, function(v) Settings.ApproachThreshold = v end)
makeInput(SettingsTab, "Ожидание после Активировать (с)", Settings.WaitAfterActivate, function(v) Settings.WaitAfterActivate = v end)
makeInput(SettingsTab, "Ожидание перед Проверить (с)", Settings.WaitBeforeCheck, function(v) Settings.WaitBeforeCheck = v end)
makeInput(SettingsTab, "Ожидание перед Деактивировать (с)", Settings.WaitBeforeDeactivate, function(v) Settings.WaitBeforeDeactivate = v end)
makeInput(SettingsTab, "Ожидание если ушёл (с)", Settings.WaitLeftWithoutApproach, function(v) Settings.WaitLeftWithoutApproach = v end)

makeSection("ESP")
makeToggle(SettingsTab, "ESP включён", Settings.Enabled, function(v) Settings.Enabled = v end)
makeToggle(SettingsTab, "Проверка команды", Settings.TeamCheck, function(v) Settings.TeamCheck = v end)

makeSection("КООРДИНАТЫ КНОПОК")

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
    btn.Text = Settings.Buttons[key] and "✓ Задано" or "Выбрать"
    btn.TextColor3 = Theme.Text
    btn.Font = Enum.Font.GothamBold
    btn.TextSize = 12
    btn.BorderSizePixel = 0
    btn.AutoButtonColor = false
    btn.Parent = row
    addCorner(btn, 6)

    btn.MouseEnter:Connect(function()
        TweenService:Create(btn, TweenInfo.new(0.15), {
            BackgroundColor3 = Theme.AccentHover
        }):Play()
    end)
    btn.MouseLeave:Connect(function()
        local baseColor = Settings.Buttons[key] and Theme.Success or Theme.Warning
        TweenService:Create(btn, TweenInfo.new(0.15), {
            BackgroundColor3 = baseColor
        }):Play()
    end)

    btn.MouseButton1Click:Connect(function()
        openCrosshairPicker(key, name)
    end)

    buttonLabelRefs[key] = {btn = btn, name = name}
end

makeButtonSetter("Активировать", "Activate")
makeButtonSetter("Выдать билет", "GiveTicket")
makeButtonSetter("Проверить оружие", "CheckWeapon")
makeButtonSetter("Деактивировать", "Deactivate")

getgenv().refreshButtonLabels = function()
    for key, ref in pairs(buttonLabelRefs) do
        local data = Settings.Buttons[key]
        if data and data.Pos then
            ref.btn.Text = string.format("✓ X=%d, Y=%d", data.Pos.X, data.Pos.Y)
            ref.btn.BackgroundColor3 = Theme.Success
        else
            ref.btn.Text = "Выбрать"
            ref.btn.BackgroundColor3 = Theme.Warning
        end
    end
end

-- ═══════════════════════════════════════════════════════
-- 🎨 ESP
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
    nameLabel.Font = Enum.Font.GothamBold
    nameLabel.TextSize = Settings.TextSize
    nameLabel.TextColor3 = Settings.NameColor
    nameLabel.TextStrokeTransparency = 0
    nameLabel.TextStrokeColor3 = Color3.fromRGB(0, 0, 0)
    nameLabel.Parent = billboard

    local distLabel = Instance.new("TextLabel")
    distLabel.Size = UDim2.new(1, 0, 0.5, 0)
    distLabel.Position = UDim2.new(0, 0, 0.5, 0)
    distLabel.BackgroundTransparency = 1
    distLabel.Font = Enum.Font.Gotham
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
                    local hp = hum.Health / hum.MaxHealth
                    esp.HealthFill.Size = UDim2.new(1, 0, hp, 0)
                    esp.HealthFill.BackgroundColor3 = Color3.fromRGB(255 * (1 - hp), 255 * hp, 0)
                    esp.HealthBg.Visible = Settings.ShowHealth
                end
            end
        end
    else
        for _, esp in pairs(ESPCache) do
            if esp.Billboard then esp.Billboard.Enabled = false end
        end
    end

    -- Автодействия
    if not Settings.AutoActions then return end
    StateTimer = StateTimer + dt

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
                        log("👤 Обнаружен: " .. p.Name .. " (" .. math.floor(d) .. "м)", Theme.Warning)
                        if Settings.DoActivate then
                            fireButtonAction(Settings.Buttons.Activate)
                            log("▶ Активировать", Theme.Accent)
                        end
                        break
                    end
                end
            end
        end
    elseif ActionState == "waiting" and CurrentTarget then
        if StateTimer >= Settings.WaitAfterActivate then
            local char = CurrentTarget.Character
            local hrp = char and char:FindFirstChild("HumanoidRootPart")
            if hrp then
                local d = (Camera.CFrame.Position - hrp.Position).Magnitude
                if d < InitialDistance - Settings.ApproachThreshold then
                    log("👣 " .. CurrentTarget.Name .. " подошёл", Theme.Success)
                    if Settings.DoGiveTicket then
                        fireButtonAction(Settings.Buttons.GiveTicket)
                        log("🎫 Выдать билет", Theme.Accent)
                    end
                    ActionState = "checkWeapon"
                    StateTimer = 0
                else
                    log("💨 " .. CurrentTarget.Name .. " не подошёл", Theme.TextDim)
                    ActionState = "waitLeft"
                    StateTimer = 0
                end
            else
                ActionState = "waitLeft"
                StateTimer = 0
            end
        end
    elseif ActionState == "checkWeapon" and StateTimer >= Settings.WaitBeforeCheck then
        if Settings.DoCheckWeapon then
            fireButtonAction(Settings.Buttons.CheckWeapon)
            log("🔫 Проверить оружие", Theme.Accent)
        end
        ActionState = "deactivate"
        StateTimer = 0
    elseif ActionState == "deactivate" and StateTimer >= Settings.WaitBeforeDeactivate then
        if Settings.DoDeactivate then
            fireButtonAction(Settings.Buttons.Deactivate)
            log("⏹ Деактивировать", Theme.Accent)
        end
        ActionState = "idle"
        CurrentTarget = nil
        StateTimer = 0
    elseif ActionState == "waitLeft" and StateTimer >= Settings.WaitLeftWithoutApproach then
        if Settings.DoDeactivate then
            fireButtonAction(Settings.Buttons.Deactivate)
            log("⏹ Деактивировать (ушёл)", Theme.Accent)
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
-- 🔄 ВКЛАДКИ
-- ═══════════════════════════════════════════════════════
local tabs = {
    {Name = "Консоль", Frame = ConsoleTab, Button = nil},
    {Name = "Тест", Frame = TestTab, Button = nil},
    {Name = "Настройки", Frame = SettingsTab, Button = nil},
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

-- Свернуть
local minimized = false
local originalSize = MainFrame.Size
MinimizeBtn.MouseButton1Click:Connect(function()
    minimized = not minimized
    if minimized then
        TweenService:Create(MainFrame, TweenInfo.new(0.2), {Size = UDim2.new(0, 460, 0, 42)}):Play()
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
-- 🌐 ПУБЛИЧНОЕ API
-- ═══════════════════════════════════════════════════════
getgenv().ESP = {
    Settings = Settings,
    Toggle = function() Settings.Enabled = not Settings.Enabled end,
    Destroy = function()
        for p, _ in pairs(ESPCache) do removeESP(p) end
        MainGui:Destroy()
        CrosshairGui:Destroy()
    end,
}

getgenv().ShowUI = function() MainGui.Enabled = true end
getgenv().HideUI = function() MainGui.Enabled = false end

log("✅ Скрипт загружен!", Theme.Success)
log("UI: getgenv().ShowUI()", Theme.TextDim)
