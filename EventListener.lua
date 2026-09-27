--[[
    EventListener.lua — Список всех кнопок в игре
    Просто сканирует и показывает все GuiButton
    Тап по кнопке в списке → инфо (путь, размер, координаты)
    Для Delta Executor
--]]

if getgenv().EVENT_LISTENER_LOADED then
    pcall(function()
        if getgenv().EventListener and getgenv().EventListener.Destroy then
            getgenv().EventListener.Destroy()
        end
    end)
    task.wait(0.2)
end
getgenv().EVENT_LISTENER_LOADED = true

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")
local CoreGui = game:GetService("CoreGui")
local VirtualInputManager = game:GetService("VirtualInputManager")
local LocalPlayer = Players.LocalPlayer

-- ═══════════════════════════════════════════════════════
-- 🎨 ЦВЕТА
-- ═══════════════════════════════════════════════════════
local Colors = {
    Bg        = Color3.fromRGB(20, 20, 28),
    BgLight   = Color3.fromRGB(30, 30, 40),
    BgLighter = Color3.fromRGB(42, 42, 55),
    Accent    = Color3.fromRGB(90, 130, 220),
    AccentHover = Color3.fromRGB(120, 160, 255),
    Success   = Color3.fromRGB(0, 200, 100),
    Danger    = Color3.fromRGB(210, 70, 70),
    Warning   = Color3.fromRGB(240, 170, 60),
    Text      = Color3.fromRGB(240, 240, 245),
    TextDim   = Color3.fromRGB(150, 150, 165),
    Border    = Color3.fromRGB(60, 60, 80),
    LogText   = Color3.fromRGB(180, 220, 180),
    ButtonCol = Color3.fromRGB(120, 200, 255),
    CodeCol   = Color3.fromRGB(180, 255, 200),
}

-- ═══════════════════════════════════════════════════════
-- 🔧 ХЕЛПЕРЫ
-- ═══════════════════════════════════════════════════════
local function addCorner(parent, r)
    local c = Instance.new("UICorner")
    c.CornerRadius = UDim.new(0, r or 8)
    c.Parent = parent
    return c
end

local function addStroke(parent, color, thickness)
    local s = Instance.new("UIStroke")
    s.Color = color or Colors.Border
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
-- 🔍 АНАЛИЗ КНОПКИ
-- ═══════════════════════════════════════════════════════
local function analyzeButton(obj)
    if not obj or not obj:IsA("GuiButton") then return nil end

    local info = {
        ClassName = obj.ClassName,
        Name = obj.Name,
        FullPath = obj:GetFullName(),
        PlayerGuiPath = nil,
        CoreGuiPath = nil,
        Visible = obj.Visible,
        Active = obj.Active,
        Interactable = obj.Interactable,
        Size = obj.AbsoluteSize,
        Position = obj.AbsolutePosition,
        ZIndex = obj.ZIndex,
        ParentName = obj.Parent and obj.Parent.Name or "nil",
        ParentClass = obj.Parent and obj.Parent.ClassName or "nil",
        ScreenGui = nil,
    }

    -- Строим путь
    local objPath = {}
    local current = obj
    while current and current ~= LocalPlayer.PlayerGui and current ~= CoreGui and current ~= game do
        table.insert(objPath, 1, current.Name)
        current = current.Parent
    end

    if current == LocalPlayer.PlayerGui then
        info.PlayerGuiPath = table.concat(objPath, ".")
    elseif current == CoreGui then
        info.CoreGuiPath = table.concat(objPath, ".")
    end

    -- ScreenGui родитель
    local parent = obj.Parent
    while parent and parent ~= game do
        if parent:IsA("ScreenGui") then
            info.ScreenGui = parent.Name
            break
        end
        parent = parent.Parent
    end

    return info
end

-- ═══════════════════════════════════════════════════════
-- 🔍 СКАНИРОВАНИЕ ВСЕХ КНОПОК
-- ═══════════════════════════════════════════════════════
local OurGuiNames = {
    "eventlistener", "event_listener", "objinspector", "obj_inf",
    "esp_mainui", "esp_crosshair", "esp_clickindicator",
    "routeauto", "aim", "esp_",
}

local function isOurGui(gui)
    if gui == MainGui or gui == NotifGui then return true end
    local n = (gui.Name or ""):lower()
    for _, fname in ipairs(OurGuiNames) do
        if n:find(fname, 1, true) then return true end
    end
    return false
end

local function collectAllButtons()
    local buttons = {}

    local function scanGui(gui)
        pcall(function()
            if not gui:IsA("ScreenGui") then return end
            if isOurGui(gui) then return end

            for _, obj in ipairs(gui:GetDescendants()) do
                if obj:IsA("GuiButton") then
                    -- Пропускаем кнопки из наших GUI
                    local isOurs = false
                    local p = obj
                    while p and p ~= game do
                        if isOurGui(p) then isOurs = true; break end
                        p = p.Parent
                    end
                    if not isOurs then
                        table.insert(buttons, obj)
                    end
                end
            end
        end)
    end

    pcall(function()
        for _, gui in pairs(LocalPlayer.PlayerGui:GetChildren()) do
            scanGui(gui)
        end
    end)
    pcall(function()
        for _, gui in pairs(CoreGui:GetChildren()) do
            scanGui(gui)
        end
    end)

    return buttons
end

-- ═══════════════════════════════════════════════════════
-- 🖥️ UI
-- ═══════════════════════════════════════════════════════
local MainGui = Instance.new("ScreenGui")
MainGui.Name = "EventListener_UI"
MainGui.ResetOnSpawn = false
MainGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
MainGui.DisplayOrder = 100
pcall(function() MainGui.Parent = CoreGui end)
if not MainGui.Parent then MainGui.Parent = LocalPlayer:WaitForChild("PlayerGui") end

local MainFrame = Instance.new("Frame")
MainFrame.Size = UDim2.new(0, 520, 0, 620)
MainFrame.Position = UDim2.new(0, 20, 0, 60)
MainFrame.BackgroundColor3 = Colors.Bg
MainFrame.BorderSizePixel = 0
MainFrame.Active = true
MainFrame.Parent = MainGui
addCorner(MainFrame, 12)
addStroke(MainFrame, Colors.Border, 1.5)
makeDraggable(MainFrame)

-- Заголовок
local TitleBar = Instance.new("Frame")
TitleBar.Size = UDim2.new(1, 0, 0, 42)
TitleBar.BackgroundColor3 = Colors.BgLight
TitleBar.BorderSizePixel = 0
TitleBar.Parent = MainFrame
addCorner(TitleBar, 12)

local TitleFix = Instance.new("Frame")
TitleFix.Size = UDim2.new(1, 0, 0, 12)
TitleFix.Position = UDim2.new(0, 0, 1, -12)
TitleFix.BackgroundColor3 = Colors.BgLight
TitleFix.BorderSizePixel = 0
TitleFix.Parent = TitleBar

local TitleLbl = Instance.new("TextLabel")
TitleLbl.Text = "🎧 СПИСОК ВСЕХ КНОПОК"
TitleLbl.Size = UDim2.new(1, -150, 1, 0)
TitleLbl.Position = UDim2.new(0, 12, 0, 0)
TitleLbl.BackgroundTransparency = 1
TitleLbl.TextColor3 = Colors.Text
TitleLbl.Font = Enum.Font.GothamBold
TitleLbl.TextSize = 15
TitleLbl.TextXAlignment = Enum.TextXAlignment.Left
TitleLbl.Parent = TitleBar

local MinBtn = Instance.new("TextButton")
MinBtn.Text = "—"
MinBtn.Size = UDim2.new(0, 28, 0, 28)
MinBtn.Position = UDim2.new(1, -66, 0.5, -14)
MinBtn.BackgroundColor3 = Colors.BgLighter
MinBtn.TextColor3 = Colors.Text
MinBtn.Font = Enum.Font.GothamBold
MinBtn.TextSize = 16
MinBtn.BorderSizePixel = 0
MinBtn.Parent = TitleBar
addCorner(MinBtn, 6)

local CloseBtn = Instance.new("TextButton")
CloseBtn.Text = "✕"
CloseBtn.Size = UDim2.new(0, 28, 0, 28)
CloseBtn.Position = UDim2.new(1, -34, 0.5, -14)
CloseBtn.BackgroundColor3 = Colors.Danger
CloseBtn.TextColor3 = Colors.Text
CloseBtn.Font = Enum.Font.GothamBold
CloseBtn.TextSize = 14
CloseBtn.BorderSizePixel = 0
CloseBtn.Parent = TitleBar
addCorner(CloseBtn, 6)

-- Кнопки управления
local RefreshBtn = Instance.new("TextButton")
RefreshBtn.Text = "🔄 Обновить список"
RefreshBtn.Size = UDim2.new(0.5, -16, 0, 40)
RefreshBtn.Position = UDim2.new(0, 12, 0, 54)
RefreshBtn.BackgroundColor3 = Colors.Success
RefreshBtn.TextColor3 = Colors.Text
RefreshBtn.Font = Enum.Font.GothamBold
RefreshBtn.TextSize = 13
RefreshBtn.BorderSizePixel = 0
RefreshBtn.AutoButtonColor = false
RefreshBtn.Parent = MainFrame
addCorner(RefreshBtn, 8)

local AutoRefreshBtn = Instance.new("TextButton")
AutoRefreshBtn.Text = "🔁 Авто-обновление: ВЫКЛ"
AutoRefreshBtn.Size = UDim2.new(0.5, -16, 0, 40)
AutoRefreshBtn.Position = UDim2.new(0.5, 4, 0, 54)
AutoRefreshBtn.BackgroundColor3 = Colors.BgLighter
AutoRefreshBtn.TextColor3 = Colors.Text
AutoRefreshBtn.Font = Enum.Font.GothamBold
AutoRefreshBtn.TextSize = 12
AutoRefreshBtn.BorderSizePixel = 0
AutoRefreshBtn.AutoButtonColor = false
AutoRefreshBtn.Parent = MainFrame
addCorner(AutoRefreshBtn, 8)

-- Поиск
local SearchBox = Instance.new("TextBox")
SearchBox.Size = UDim2.new(1, -24, 0, 34)
SearchBox.Position = UDim2.new(0, 12, 0, 104)
SearchBox.BackgroundColor3 = Colors.BgLighter
SearchBox.PlaceholderText = "🔎 Поиск по имени кнопки..."
SearchBox.PlaceholderColor3 = Colors.TextDim
SearchBox.Text = ""
SearchBox.TextColor3 = Colors.Text
SearchBox.Font = Enum.Font.Gotham
SearchBox.TextSize = 13
SearchBox.BorderSizePixel = 0
SearchBox.ClearTextOnFocus = false
SearchBox.Parent = MainFrame
addCorner(SearchBox, 8)

-- Статистика
local StatsLabel = Instance.new("TextLabel")
StatsLabel.Text = "Найдено кнопок: 0"
StatsLabel.Size = UDim2.new(1, -24, 0, 22)
StatsLabel.Position = UDim2.new(0, 12, 0, 144)
StatsLabel.BackgroundTransparency = 1
StatsLabel.TextColor3 = Colors.Warning
StatsLabel.Font = Enum.Font.GothamBold
StatsLabel.TextSize = 12
StatsLabel.TextXAlignment = Enum.TextXAlignment.Left
StatsLabel.Parent = MainFrame

-- Список кнопок
local ButtonsList = Instance.new("ScrollingFrame")
ButtonsList.Size = UDim2.new(1, -24, 1, -180)
ButtonsList.Position = UDim2.new(0, 12, 0, 170)
ButtonsList.BackgroundColor3 = Colors.BgLight
ButtonsList.BorderSizePixel = 0
ButtonsList.ScrollBarThickness = 6
ButtonsList.ScrollBarImageColor3 = Colors.Accent
ButtonsList.CanvasSize = UDim2.new(0, 0, 0, 0)
ButtonsList.AutomaticCanvasSize = Enum.AutomaticSize.Y
ButtonsList.Parent = MainFrame
addCorner(ButtonsList, 8)

local ButtonsLayout = Instance.new("UIListLayout")
ButtonsLayout.Padding = UDim.new(0, 4)
ButtonsLayout.SortOrder = Enum.SortOrder.LayoutOrder
ButtonsLayout.Parent = ButtonsList

-- ═══════════════════════════════════════════════════════
-- 📋 ИНФО-ОКНО (для выбранной кнопки)
-- ═══════════════════════════════════════════════════════
local NotifGui = Instance.new("ScreenGui")
NotifGui.Name = "EventListener_Notif"
NotifGui.ResetOnSpawn = false
NotifGui.DisplayOrder = 101
pcall(function() NotifGui.Parent = CoreGui end)
if not NotifGui.Parent then NotifGui.Parent = LocalPlayer:WaitForChild("PlayerGui") end

local InfoFrame = Instance.new("Frame")
InfoFrame.Size = UDim2.new(0, 420, 0, 160)
InfoFrame.Position = UDim2.new(0.5, -210, 0, 20)
InfoFrame.BackgroundColor3 = Colors.Bg
InfoFrame.BackgroundTransparency = 0.05
InfoFrame.BorderSizePixel = 0
InfoFrame.Visible = false
InfoFrame.ZIndex = 9999
InfoFrame.Parent = NotifGui
addCorner(InfoFrame, 10)
addStroke(InfoFrame, Colors.ButtonCol, 2)
makeDraggable(InfoFrame)

local InfoTitle = Instance.new("TextLabel")
InfoTitle.Text = "🖱 КНОПКА"
InfoTitle.Size = UDim2.new(1, -16, 0, 24)
InfoTitle.Position = UDim2.new(0, 8, 0, 6)
InfoTitle.BackgroundTransparency = 1
InfoTitle.TextColor3 = Colors.ButtonCol
InfoTitle.Font = Enum.Font.GothamBold
InfoTitle.TextSize = 13
InfoTitle.TextXAlignment = Enum.TextXAlignment.Left
InfoTitle.ZIndex = 10000
InfoTitle.Parent = InfoFrame

local InfoPath = Instance.new("TextLabel")
InfoPath.Text = ""
InfoPath.Size = UDim2.new(1, -16, 0, 32)
InfoPath.Position = UDim2.new(0, 8, 0, 32)
InfoPath.BackgroundTransparency = 1
InfoPath.TextColor3 = Colors.CodeCol
InfoPath.Font = Enum.Font.Code
InfoPath.TextSize = 10
InfoPath.TextXAlignment = Enum.TextXAlignment.Left
InfoPath.TextWrapped = true
InfoPath.ZIndex = 10000
InfoPath.Parent = InfoFrame

local InfoDetails = Instance.new("TextLabel")
InfoDetails.Text = ""
InfoDetails.Size = UDim2.new(1, -16, 0, 40)
InfoDetails.Position = UDim2.new(0, 8, 0, 68)
InfoDetails.BackgroundTransparency = 1
InfoDetails.TextColor3 = Colors.Text
InfoDetails.Font = Enum.Font.Gotham
InfoDetails.TextSize = 11
InfoDetails.TextXAlignment = Enum.TextXAlignment.Left
InfoDetails.TextWrapped = true
InfoDetails.ZIndex = 10000
InfoDetails.Parent = InfoFrame

local InfoCopyBtn = Instance.new("TextButton")
InfoCopyBtn.Text = "📋 Копировать код"
InfoCopyBtn.Size = UDim2.new(0.5, -12, 0, 28)
InfoCopyBtn.Position = UDim2.new(0, 8, 1, -36)
InfoCopyBtn.BackgroundColor3 = Colors.Success
InfoCopyBtn.TextColor3 = Colors.Text
InfoCopyBtn.Font = Enum.Font.GothamBold
InfoCopyBtn.TextSize = 11
InfoCopyBtn.BorderSizePixel = 0
InfoCopyBtn.AutoButtonColor = false
InfoCopyBtn.ZIndex = 10000
InfoCopyBtn.Parent = InfoFrame
addCorner(InfoCopyBtn, 6)

local InfoCloseBtn = Instance.new("TextButton")
InfoCloseBtn.Text = "✕ Закрыть"
InfoCloseBtn.Size = UDim2.new(0.5, -12, 0, 28)
InfoCloseBtn.Position = UDim2.new(0.5, 4, 1, -36)
InfoCloseBtn.BackgroundColor3 = Colors.Danger
InfoCloseBtn.TextColor3 = Colors.Text
InfoCloseBtn.Font = Enum.Font.GothamBold
InfoCloseBtn.TextSize = 11
InfoCloseBtn.BorderSizePixel = 0
InfoCloseBtn.AutoButtonColor = false
InfoCloseBtn.ZIndex = 10000
InfoCloseBtn.Parent = InfoFrame
addCorner(InfoCloseBtn, 6)

-- ═══════════════════════════════════════════════════════
-- 📋 ЛОГИКА
-- ═══════════════════════════════════════════════════════
local AllButtons = {}
local SelectedButton = nil
local AutoRefresh = false
local SearchQuery = ""

local function showInfo(button)
    SelectedButton = button
    local info = analyzeButton(button)
    if not info then return end

    local mainPath = info.PlayerGuiPath or info.CoreGuiPath or info.FullPath
    local prefix = info.PlayerGuiPath and "PlayerGui." or (info.CoreGuiPath and "CoreGui." or "")

    InfoTitle.Text = "🖱 " .. info.ClassName .. " [" .. info.Name .. "]"
    InfoPath.Text = "📍 " .. prefix .. mainPath
    InfoDetails.Text = string.format(
        "📐 Размер: %dx%d\n👁 Visible: %s  |  🎯 Active: %s  |  📱 Interactable: %s\n📊 ZIndex: %d",
        info.Size.X, info.Size.Y,
        tostring(info.Visible), tostring(info.Active), tostring(info.Interactable),
        info.ZIndex
    )
    InfoFrame.Visible = true
end

local function createButtonRow(button, index)
    local info = analyzeButton(button)
    if not info then return end

    -- Фильтр по поиску
    if SearchQuery ~= "" then
        local nameMatch = info.Name:lower():find(SearchQuery, 1, true)
        local pathMatch = (info.PlayerGuiPath or info.CoreGuiPath or ""):lower():find(SearchQuery, 1, true)
        if not nameMatch and not pathMatch then return end
    end

    local row = Instance.new("TextButton")
    row.Size = UDim2.new(1, -8, 0, 56)
    row.BackgroundColor3 = Colors.Bg
    row.BorderSizePixel = 0
    row.Text = ""
    row.AutoButtonColor = false
    row.Parent = ButtonsList
    addCorner(row, 6)

    -- Строка 1: класс + имя + размер
    local line1 = Instance.new("TextLabel")
    line1.Text = string.format("#%d  %s  [%s]  %dx%d",
        index, info.ClassName, info.Name, info.Size.X, info.Size.Y)
    line1.Size = UDim2.new(1, -8, 0, 18)
    line1.Position = UDim2.new(0, 8, 0, 4)
    line1.BackgroundTransparency = 1
    line1.TextColor3 = info.Visible and Colors.ButtonCol or Colors.Danger
    line1.Font = Enum.Font.GothamBold
    line1.TextSize = 11
    line1.TextXAlignment = Enum.TextXAlignment.Left
    line1.TextTruncate = Enum.TextTruncate.AtEnd
    line1.Parent = row

    -- Строка 2: путь
    local pathText = info.PlayerGuiPath or info.CoreGuiPath or info.FullPath
    local pathPrefix = info.PlayerGuiPath and "PG: " or (info.CoreGuiPath and "CG: " or "")
    local line2 = Instance.new("TextLabel")
    line2.Text = pathPrefix .. pathText
    line2.Size = UDim2.new(1, -8, 0, 16)
    line2.Position = UDim2.new(0, 8, 0, 22)
    line2.BackgroundTransparency = 1
    line2.TextColor3 = Colors.CodeCol
    line2.Font = Enum.Font.Code
    line2.TextSize = 10
    line2.TextXAlignment = Enum.TextXAlignment.Left
    line2.TextTruncate = Enum.TextTruncate.AtEnd
    line2.Parent = row

    -- Строка 3: координаты
    local line3 = Instance.new("TextLabel")
    line3.Text = string.format("📍 X=%.0f Y=%.0f  |  👁 %s  |  🎯 %s  |  Z:%d",
        info.Position.X, info.Position.Y,
        info.Visible and "видна" or "СКРЫТА",
        info.Active and "активна" or "НЕАКТИВНА",
        info.ZIndex)
    line3.Size = UDim2.new(1, -8, 0, 14)
    line3.Position = UDim2.new(0, 8, 0, 38)
    line3.BackgroundTransparency = 1
    line3.TextColor3 = Colors.TextDim
    line3.Font = Enum.Font.Gotham
    line3.TextSize = 10
    line3.TextXAlignment = Enum.TextXAlignment.Left
    line3.Parent = row

    row.MouseButton1Click:Connect(function()
        showInfo(button)
    end)
end

local function refreshList()
    -- Очистить
    for _, child in ipairs(ButtonsList:GetChildren()) do
        if child:IsA("TextButton") then child:Destroy() end
    end

    -- Собрать
    AllButtons = collectAllButtons()

    -- Сортировать: сначала видимые, потом по имени
    table.sort(AllButtons, function(a, b)
        if a.Visible ~= b.Visible then
            return a.Visible
        end
        return a.Name:lower() < b.Name:lower()
    end)

    -- Показать
    local shown = 0
    for i, button in ipairs(AllButtons) do
        local info = analyzeButton(button)
        if info then
            -- Проверка фильтра
            local ok = true
            if SearchQuery ~= "" then
                local nameMatch = info.Name:lower():find(SearchQuery, 1, true)
                local pathMatch = (info.PlayerGuiPath or info.CoreGuiPath or ""):lower():find(SearchQuery, 1, true)
                if not nameMatch and not pathMatch then ok = false end
            end
            if ok then
                createButtonRow(button, i)
                shown = shown + 1
            end
        end
    end

    StatsLabel.Text = "Найдено кнопок: " .. #AllButtons .. "  (показано: " .. shown .. ")"
end

-- Авто-обновление
task.spawn(function()
    while getgenv().EVENT_LISTENER_LOADED do
        task.wait(3)
        if AutoRefresh then
            refreshList()
        end
    end
end)

-- ═══════════════════════════════════════════════════════
-- 🎛️ КНОПКИ
-- ═══════════════════════════════════════════════════════
RefreshBtn.MouseButton1Click:Connect(function()
    refreshList()
end)

AutoRefreshBtn.MouseButton1Click:Connect(function()
    AutoRefresh = not AutoRefresh
    if AutoRefresh then
        AutoRefreshBtn.Text = "🔁 Авто-обновление: ВКЛ"
        AutoRefreshBtn.BackgroundColor3 = Colors.Success
    else
        AutoRefreshBtn.Text = "🔁 Авто-обновление: ВЫКЛ"
        AutoRefreshBtn.BackgroundColor3 = Colors.BgLighter
    end
end)

SearchBox:GetPropertyChangedSignal("Text"):Connect(function()
    SearchQuery = SearchBox.Text:lower()
    refreshList()
end)

InfoCopyBtn.MouseButton1Click:Connect(function()
    if not SelectedButton then return end
    local info = analyzeButton(SelectedButton)
    if not info then return end

    local mainPath = info.PlayerGuiPath or info.CoreGuiPath
    local base = info.PlayerGuiPath and "game.Players.LocalPlayer.PlayerGui." 
        or "game:GetService('CoreGui')."
    local fullPath = base .. mainPath

    print("════════════════════════════════════════")
    print("💻 КОД ДЛЯ ВЫЗОВА КНОПКИ:")
    print("════════════════════════════════════════")
    print("local btn = " .. fullPath)
    print("btn.Activated:Fire()")
    print("-- или")
    print("btn.MouseButton1Click:Fire()")
    print("-- или")
    print("btn:Activate()")
    print("════════════════════════════════════════")

    InfoPath.Text = "✅ Код скопирован в консоль (F9)"
end)

InfoCloseBtn.MouseButton1Click:Connect(function()
    InfoFrame.Visible = false
end)

-- Свернуть
local minimized = false
local originalSize = MainFrame.Size
MinBtn.MouseButton1Click:Connect(function()
    minimized = not minimized
    if minimized then
        TweenService:Create(MainFrame, TweenInfo.new(0.2), {Size = UDim2.new(0, 520, 0, 42)}):Play()
        RefreshBtn.Visible = false
        AutoRefreshBtn.Visible = false
        SearchBox.Visible = false
        StatsLabel.Visible = false
        ButtonsList.Visible = false
    else
        TweenService:Create(MainFrame, TweenInfo.new(0.2), {Size = originalSize}):Play()
        RefreshBtn.Visible = true
        AutoRefreshBtn.Visible = true
        SearchBox.Visible = true
        StatsLabel.Visible = true
        ButtonsList.Visible = true
    end
end)

CloseBtn.MouseButton1Click:Connect(function()
    MainGui.Enabled = false
    InfoFrame.Visible = false
end)

-- ═══════════════════════════════════════════════════════
-- 🚀 СТАРТ
-- ═══════════════════════════════════════════════════════
task.wait(0.5)
refreshList()

-- ═══════════════════════════════════════════════════════
-- 🌐 API
-- ═══════════════════════════════════════════════════════
getgenv().EventListener = {
    Show = function() MainGui.Enabled = true end,
    Hide = function() MainGui.Enabled = false end,
    Refresh = refreshList,
    GetButtons = function() return AllButtons end,
    Analyze = analyzeButton,
    Destroy = function()
        pcall(function() MainGui:Destroy() end)
        pcall(function() NotifGui:Destroy() end)
        getgenv().EVENT_LISTENER_LOADED = false
    end,
}

print("[EventListener] ✅ Загружен!")
print("[EventListener] Все кнопки собраны в список")
print("[EventListener] Жми «🔄 Обновить список» для рескана")
print("[EventListener] Вкл авто: getgenv().EventListener.Refresh()")
