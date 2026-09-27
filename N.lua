--[[
    PLAYERS ESP + AUTO ACTIONS + UI
    Версия: 4.0 (очередь, игнор 40с, статус над игроками, автосдвиг)
    Для Delta Executor (телефон)
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
}

-- ═══════════════════════════════════════════════════════
-- ⚙️ НАСТРОЙКИ
-- ═══════════════════════════════════════════════════════
local Settings = {
    Enabled = true,
    ShowName = true,
    ShowHealth = true,
    ShowDistance = true,
    ShowStatus = true,          -- ⬅️ НОВОЕ: статус над игроком
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
    QueueDelay = 5,             -- ⬅️ НОВОЕ: задержка между игроками
    IgnoreDuration = 40,        -- ⬅️ НОВОЕ: игнор после деактивации (сек)

    Buttons = {
        Activate = nil,
        GiveTicket = nil,
        CheckWeapon = nil,
        Deactivate = nil,
    },

    CrosshairColor = Color3.fromRGB(0, 255, 100),
    ShowClickIndicator = true,
    CrosshairOffsetY = 0,
}

local ESPCache = {}
local ActionState = "idle"
local StateTimer = 0
local InitialDistance = 0
local ProcessedPlayers = {}     -- {[player] = true} — для одноразовой обработки
local IgnoredPlayers = {}       -- {[player] = timestamp} — когда можно снова обрабатывать
local Queue = {}                -- очередь игроков: {player1, player2, ...}

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
-- 🖱️ ТОЧНЫЙ ТАП С УЧЁТОМ ИНСЕТА
-- ═══════════════════════════════════════════════════════
local function clickAtScreenPosition(x, y)
    if not x or not y then return false end
    local topInset = GuiService:GetGuiInset().Y
    local realY = y + topInset + (Settings.CrosshairOffsetY or 0)
    showClickIndicator(x, realY)

    local used = false
    pcall(function()
        if typeof(tap) == "function" then
            tap(x, realY); used = true
        end
    end)
    if used then return true end

    pcall(function()
        if typeof(touch) == "function" then
            touch(x, realY); used = true
        end
    end)
    if used then return true end

    pcall(function()
        VirtualInputManager:SendTouchEvent(
            Enum.UserInputType.Touch,
            Enum.UserInputState.Begin,
            Vector2.new(x, realY)
        )
        task.wait(0.08)
        VirtualInputManager:SendTouchEvent(
            Enum.UserInputType.Touch,
            Enum.UserInputState.End,
            Vector2.new(x, realY)
        )
    end)

    pcall(function()
        VirtualInputManager:SendMouseButtonEvent(x, realY, 0, true, game, 1)
        task.wait(0.05)
        VirtualInputManager:SendMouseButtonEvent(x, realY, 0, false, game, 1)
    end)

    return true
end

-- ═══════════════════════════════════════════════════════
-- 🎯 ВЫПОЛНЕНИЕ ДЕЙСТВИЯ
-- ═══════════════════════════════════════════════════════
function fireButtonAction(btnData)
    if not btnData or not btnData.Pos then return false end
    clickAtScreenPosition(btnData.Pos.X, btnData.Pos.Y)
    log("✓ Тап X=" .. btnData.Pos.X .. ", Y=" .. btnData.Pos.Y, Theme.Success)
    return true
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
TestTab.CanvasSize = UDim2.new(0, 0, 0, 700)
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
-- 🎯 ПРИЦЕЛ
-- ═══════════════════════════════════════════════════════
local CrosshairGui = Instance.new("ScreenGui")
CrosshairGui.Name = "ESP_Crosshair"
CrosshairGui.ResetOnSpawn = false
CrosshairGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
CrosshairGui.IgnoreGuiInset = true
CrosshairGui.DisplayOrder = 999
CrosshairGui.Enabled = false
pcall(function() CrosshairGui.Parent = CoreGui end)
if not CrosshairGui.Parent then CrosshairGui.Parent = LocalPlayer:WaitForChild("PlayerGui") end

local CrossHandle = Instance.new("TextButton")
CrossHandle.Name = "CrossHandle"
CrossHandle.Size = UDim2.new(0, 80, 0, 80)
CrossHandle.Position = UDim2.new(0.5, -40, 0.5, -40)
CrossHandle.BackgroundTransparency = 1
CrossHandle.Text = ""
CrossHandle.AutoButtonColor = false
CrossHandle.Active = true
CrossHandle.ZIndex = 100
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
CrossDot.ZIndex = 101
CrossDot.Parent = CrossHandle
addCorner(CrossDot, 4)

local dotStroke = Instance.new("UIStroke")
dotStroke.Color = Color3.fromRGB(0, 0, 0); dotStroke.Thickness = 2; dotStroke.Parent = CrossDot
local hStroke = Instance.new("UIStroke")
hStroke.Color = Color3.fromRGB(0, 0, 0); hStroke.Thickness = 2; hStroke.Parent = CrossH
local vStroke = Instance.new("UIStroke")
vStroke.Color = Color3.fromRGB(0, 0, 0); vStroke.Thickness = 2; vStroke.Parent = CrossV

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
CrossPanel.Size = UDim2.new(0, 320, 0, 110)
CrossPanel.Position = UDim2.new(0.5, -160, 1, -130)
CrossPanel.BackgroundColor3 = Theme.Bg
CrossPanel.BackgroundTransparency = 0.05
CrossPanel.BorderSizePixel = 0
CrossPanel.Active = true
CrossPanel.ZIndex = 50
CrossPanel.Parent = CrosshairGui
addCorner(CrossPanel, 12)
addStroke(CrossPanel, Theme.Accent, 2)
makeDraggable(CrossPanel)

local CrossTitleLbl = Instance.new("TextLabel")
CrossTitleLbl.Text = "🎯 ПРИЦЕЛ — Активировать"
CrossTitleLbl.Size = UDim2.new(1, -20, 0, 26)
CrossTitleLbl.Position = UDim2.new(0, 10, 0, 6)
CrossTitleLbl.BackgroundTransparency = 1
CrossTitleLbl.TextColor3 = Theme.Text
CrossTitleLbl.Font = Enum.Font.GothamBold
CrossTitleLbl.TextSize = 13
CrossTitleLbl.TextXAlignment = Enum.TextXAlignment.Center
CrossTitleLbl.Parent = CrossPanel

local CoordLabel = Instance.new("TextLabel")
CoordLabel.Size = UDim2.new(1, -20, 0, 22)
CoordLabel.Position = UDim2.new(0, 10, 0, 34)
CoordLabel.BackgroundTransparency = 1
CoordLabel.Text = "X: —   Y: —"
CoordLabel.TextColor3 = Color3.fromRGB(255, 255, 100)
CoordLabel.Font = Enum.Font.Code
CoordLabel.TextSize = 14
CoordLabel.Parent = CrossPanel

local SelectBtn = Instance.new("TextButton")
SelectBtn.Text = "Выбрать (текущие координаты)"
SelectBtn.Size = UDim2.new(1, -20, 0, 36)
SelectBtn.Position = UDim2.new(0, 10, 1, -44)
SelectBtn.BackgroundColor3 = Theme.Accent
SelectBtn.TextColor3 = Theme.Text
SelectBtn.Font = Enum.Font.GothamBold
SelectBtn.TextSize = 13
SelectBtn.BorderSizePixel = 0
SelectBtn.AutoButtonColor = false
SelectBtn.Parent = CrossPanel
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

local function getCrossCenter()
    local pos = CrossHandle.AbsolutePosition + CrossHandle.AbsoluteSize / 2
    return math.floor(pos.X), math.floor(pos.Y)
end

local currentPickKey = nil
local currentPickName = nil

RunService.RenderStepped:Connect(function()
    if not CrosshairGui.Enabled then return end
    local x, y = getCrossCenter()
    CoordLabel.Text = string.format("X: %d   Y: %d", x, y)
end)

local function openCrosshairPicker(key, displayName)
    currentPickKey = key
    currentPickName = displayName
    CrossTitleLbl.Text = "🎯 ПРИЦЕЛ — " .. displayName
    CrosshairGui.Enabled = true
    MainGui.Enabled = false
    CrossHandle.Position = UDim2.new(0.5, -40, 0.5, -40)
    log("🎯 Перетащи крест на кнопку и жми «Выбрать»", Theme.Warning)
end

SelectBtn.MouseButton1Click:Connect(function()
    if not currentPickKey then return end
    local x, y = getCrossCenter()
    Settings.Buttons[currentPickKey] = {
        Path = nil,
        Pos = {X = x, Y = y},
    }
    log(string.format("✓ %s: X=%d, Y=%d", currentPickName, x, y), Theme.Success)
    if getgenv().refreshButtonLabels then getgenv().refreshButtonLabels() end
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

makeTestBtn("🔄 Сбросить состояние", function()
    ActionState = "idle"
    StateTimer = 0
    ProcessedPlayers = {}
    IgnoredPlayers = {}
    Queue = {}
    for _, esp in pairs(ESPCache) do
        if esp.StatusLabel then esp.StatusLabel.Visible = false end
    end
    log("Состояние сброшено", Theme.Warning)
end, Theme.Danger)

makeTestBtn("🗑 Очистить игнор-лист", function()
    IgnoredPlayers = {}
    log("Игнор-лист очищен", Theme.Warning)
end, Theme.Warning)

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
makeInput(SettingsTab, "Задержка между игроками (с)", Settings.QueueDelay, function(v) Settings.QueueDelay = v end)
makeInput(SettingsTab, "Игнор после деактивации (с)", Settings.IgnoreDuration, function(v) Settings.IgnoreDuration = v end)

makeSection("ESP")
makeToggle(SettingsTab, "ESP включён", Settings.Enabled, function(v) Settings.Enabled = v end)
makeToggle(SettingsTab, "Показывать имя", Settings.ShowName, function(v) Settings.ShowName = v end)
makeToggle(SettingsTab, "Показывать здоровье", Settings.ShowHealth, function(v) Settings.ShowHealth = v end)
makeToggle(SettingsTab, "Показывать дистанцию", Settings.ShowDistance, function(v) Settings.ShowDistance = v end)
makeToggle(SettingsTab, "Показывать статус", Settings.ShowStatus, function(v) Settings.ShowStatus = v end)
makeToggle(SettingsTab, "Проверка команды", Settings.TeamCheck, function(v) Settings.TeamCheck = v end)

makeSection("ОТЛАДКА")
makeToggle(SettingsTab, "Показывать индикатор клика", Settings.ShowClickIndicator, function(v)
    Settings.ShowClickIndicator = v
end)
makeInput(SettingsTab, "Сдвиг по Y (если не попадает)", Settings.CrosshairOffsetY, function(v)
    Settings.CrosshairOffsetY = v
    log("Сдвиг по Y: " .. v, Theme.Warning)
end)

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
-- 🎨 ESP + СТАТУС
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

    -- СТАТУС (самый верх)
    local statusLabel = Instance.new("TextLabel")
    statusLabel.Name = "StatusLabel"
    statusLabel.Size = UDim2.new(1, 0, 0, 22)
    statusLabel.Position = UDim2.new(0, 0, 0, 0)
    statusLabel.BackgroundTransparency = 1
    statusLabel.Font = Enum.Font.GothamBold
    statusLabel.TextSize = 16
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
    distLabel.Size = UDim2.new(1, 0, 0, 20)
    distLabel.Position = UDim2.new(0, 0, 0, 44)
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
    esp.StatusLabel = statusLabel
    esp.NameLabel = nameLabel
    esp.DistLabel = distLabel
    esp.HealthBg = healthBg
    esp.HealthFill = healthFill
    esp.StatusText = ""           -- текущий текст статуса

    ESPCache[player] = esp
end

local function removeESP(player)
    local esp = ESPCache[player]
    if not esp then return end
    if esp.Billboard then esp.Billboard:Destroy() end
    ESPCache[player] = nil
end

-- Установить статус игроку
local function setPlayerStatus(player, text, color)
    local esp = ESPCache[player]
    if not esp or not esp.StatusLabel then return end
    esp.StatusText = text or ""
    esp.StatusLabel.Text = text or ""
    esp.StatusLabel.TextColor3 = color or Color3.fromRGB(255, 220, 80)
    esp.StatusLabel.Visible = (text ~= nil and text ~= "")
end

-- Очистить статус
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

    -- Чистим истёкшие игноры
    local now = tick()
    for p, expireAt in pairs(IgnoredPlayers) do
        if now >= expireAt then
            IgnoredPlayers[p] = nil
        end
    end

    -- IDLE: наполняем очередь игроками в радиусе, которые не обработаны и не в игноре
    if ActionState == "idle" then
        for _, p in pairs(Players:GetPlayers()) do
            if p ~= LocalPlayer and p.Character
               and not ProcessedPlayers[p]
               and not IgnoredPlayers[p] then
                local hrp = p.Character:FindFirstChild("HumanoidRootPart")
                if hrp then
                    local d = (Camera.CFrame.Position - hrp.Position).Magnitude
                    if d <= Settings.TriggerRadius then
                        -- Проверяем, что его нет уже в очереди
                        local inQueue = false
                        for _, qp in ipairs(Queue) do
                            if qp == p then inQueue = true; break end
                        end
                        if not inQueue then
                            table.insert(Queue, p)
                            log("📋 В очередь: " .. p.Name .. " (" .. math.floor(d) .. "м)", Theme.Warning)
                        end
                    end
                end
            end
        end

        -- Если очередь не пуста и есть задержка — берём первого
        if #Queue > 0 then
            -- Задержка 5 сек между игроками (в начале очереди — без задержки)
            if StateTimer >= Settings.QueueDelay then
                local p = table.remove(Queue, 1)
                if p and p.Character and p.Parent then
                    local hrp = p.Character:FindFirstChild("HumanoidRootPart")
                    if hrp then
                        local d = (Camera.CFrame.Position - hrp.Position).Magnitude
                        CurrentTarget = p
                        InitialDistance = d
                        ActionState = "activating"
                        StateTimer = 0
                        ProcessedPlayers[p] = true
                        log("👤 Обработка: " .. p.Name .. " (" .. math.floor(d) .. "м)", Theme.Warning)

                        setPlayerStatus(p, "АКТИВАЦИЯ...", Color3.fromRGB(255, 220, 80))

                        if Settings.DoActivate and Settings.Buttons.Activate then
                            fireButtonAction(Settings.Buttons.Activate)
                            log("▶ Активировать", Theme.Accent)
                        end
                    end
                end
            end
        else
            -- Очередь пуста — сбрасываем таймер, чтобы при следующем игроке задержка не сработала
            StateTimer = 0
        end
    end

    -- АКТИВАЦИЯ: ждём 10 сек
    if ActionState == "activating" and CurrentTarget then
        setPlayerStatus(CurrentTarget, "АКТИВАЦИЯ " .. math.floor(Settings.WaitAfterActivate - StateTimer) .. "с", Color3.fromRGB(255, 220, 80))
        if StateTimer >= Settings.WaitAfterActivate then
            local char = CurrentTarget.Character
            local hrp = char and char:FindFirstChild("HumanoidRootPart")
            if hrp then
                local d = (Camera.CFrame.Position - hrp.Position).Magnitude
                if d < InitialDistance - Settings.ApproachThreshold then
                    log("👣 " .. CurrentTarget.Name .. " подошёл", Theme.Success)
                    setPlayerStatus(CurrentTarget, "ВЫДАЧА БИЛЕТА", Color3.fromRGB(80, 200, 255))
                    if Settings.DoGiveTicket and Settings.Buttons.GiveTicket then
                        fireButtonAction(Settings.Buttons.GiveTicket)
                        log("🎫 Выдать билет", Theme.Accent)
                    end
                    ActionState = "ticket"
                    StateTimer = 0
                else
                    log("💨 " .. CurrentTarget.Name .. " не подошёл", Theme.TextDim)
                    setPlayerStatus(CurrentTarget, "НЕ ПОДОШЁЛ", Color3.fromRGB(200, 100, 100))
                    ActionState = "waitLeft"
                    StateTimer = 0
                end
            else
                setPlayerStatus(CurrentTarget, "УШЁЛ", Color3.fromRGB(200, 100, 100))
                ActionState = "waitLeft"
                StateTimer = 0
            end
        end
    end

    -- БИЛЕТ: 3 сек → проверка оружия
    if ActionState == "ticket" and StateTimer >= Settings.WaitBeforeCheck then
        if CurrentTarget then
            setPlayerStatus(CurrentTarget, "ПРОВЕРКА ОРУЖИЯ", Color3.fromRGB(255, 180, 80))
        end
        if Settings.DoCheckWeapon and Settings.Buttons.CheckWeapon then
            fireButtonAction(Settings.Buttons.CheckWeapon)
            log("🔫 Проверить оружие", Theme.Accent)
        end
        ActionState = "weapon"
        StateTimer = 0
    end

    -- ОРУЖИЕ: 3 сек → деактивация
    if ActionState == "weapon" and StateTimer >= Settings.WaitBeforeDeactivate then
        if CurrentTarget then
            setPlayerStatus(CurrentTarget, "ДЕАКТИВАЦИЯ", Color3.fromRGB(200, 130, 255))
        end
        if Settings.DoDeactivate and Settings.Buttons.Deactivate then
            fireButtonAction(Settings.Buttons.Deactivate)
            log("⏹ Деактивировать", Theme.Accent)
        end
        ActionState = "cooldown"
        StateTimer = 0
    end

    -- WAIT LEFT: 5 сек → деактивация
    if ActionState == "waitLeft" and StateTimer >= Settings.WaitLeftWithoutApproach then
        if CurrentTarget then
            setPlayerStatus(CurrentTarget, "ДЕАКТИВАЦИЯ (ушёл)", Color3.fromRGB(200, 130, 255))
        end
        if Settings.DoDeactivate and Settings.Buttons.Deactivate then
            fireButtonAction(Settings.Buttons.Deactivate)
            log("⏹ Деактивировать (ушёл)", Theme.Accent)
        end
        ActionState = "cooldown"
        StateTimer = 0
    end

    -- COOLDOWN: 5 сек чтобы игрок вышел из зоны, потом снимаем статус, добавляем в игнор и возвращаемся в idle
    if ActionState == "cooldown" and StateTimer >= 5 then
        if CurrentTarget then
            local p = CurrentTarget
            clearPlayerStatus(p)
            -- Добавляем в игнор на 40 сек
            IgnoredPlayers[p] = tick() + Settings.IgnoreDuration
            log("🚫 " .. p.Name .. " в игноре на " .. Settings.IgnoreDuration .. "с", Theme.TextDim)
        end
        CurrentTarget = nil
        ActionState = "idle"
        StateTimer = 0
        -- Очередь не трогаем — продолжаем с другими игроками
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
        if Queue[i] == player then
            table.remove(Queue, i)
        end
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
        pcall(function() MainGui:Destroy() end)
        pcall(function() CrosshairGui:Destroy() end)
        pcall(function() ClickIndicatorGui:Destroy() end)
        getgenv().ESP_LOADED = false
    end,
}

getgenv().ShowUI = function() MainGui.Enabled = true end
getgenv().HideUI = function() MainGui.Enabled = false end

log("✅ Скрипт загружен!", Theme.Success)
log("UI: getgenv().ShowUI()", Theme.TextDim)
