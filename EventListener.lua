--[[
    EventListener.lua — Перехват кликов по GUI-кнопкам
    Кликаешь по любой кнопке → показывает её путь и инфо
    Работает независимо от obj_inf.lua
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
    Highlight = Color3.fromRGB(0, 255, 150),
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
-- 📦 ФОРМАТИРОВАНИЕ
-- ═══════════════════════════════════════════════════════
local function formatValue(val)
    local t = typeof(val)
    if t == "Vector3" then
        return string.format("Vector3(%.3f, %.3f, %.3f)", val.X, val.Y, val.Z)
    elseif t == "Vector2" then
        return string.format("Vector2(%.3f, %.3f)", val.X, val.Y)
    elseif t == "Color3" then
        return string.format("Color3(%d, %d, %d)",
            math.floor(val.R * 255), math.floor(val.G * 255), math.floor(val.B * 255))
    elseif t == "EnumItem" then
        return "Enum." .. tostring(val)
    elseif t == "Instance" then
        return val.ClassName .. " [" .. val.Name .. "]"
    elseif t == "number" then
        if val == math.floor(val) then return tostring(val) end
        return string.format("%.4f", val)
    else
        return tostring(val)
    end
end

-- ═══════════════════════════════════════════════════════
-- 🎯 АНАЛИЗ КНОПКИ
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
        Parent = obj.Parent and obj.Parent.Name or "nil",
        ScreenGui = nil,
        ScreenGuiEnabled = nil,
    }

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

    local parent = obj.Parent
    while parent and parent ~= game do
        if parent:IsA("ScreenGui") then
            info.ScreenGui = parent.Name
            info.ScreenGuiEnabled = parent.Enabled
            break
        end
        parent = parent.Parent
    end

    return info
end

-- ═══════════════════════════════════════════════════════
-- 🖥️ ГЛАВНОЕ ОКНО (список найденных кнопок)
-- ═══════════════════════════════════════════════════════
local MainGui = Instance.new("ScreenGui")
MainGui.Name = "EventListener_UI"
MainGui.ResetOnSpawn = false
MainGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
MainGui.DisplayOrder = 100
pcall(function() MainGui.Parent = CoreGui end)
if not MainGui.Parent then MainGui.Parent = LocalPlayer:WaitForChild("PlayerGui") end

-- Индикатор вверху
local Indicator = Instance.new("Frame")
Indicator.Size = UDim2.new(0, 280, 0, 44)
Indicator.Position = UDim2.new(0.5, -140, 0, 10)
Indicator.BackgroundColor3 = Colors.Bg
Indicator.BackgroundTransparency = 0.05
Indicator.BorderSizePixel = 0
Indicator.Visible = false
Indicator.ZIndex = 9999
Indicator.Parent = MainGui
addCorner(Indicator, 10)
addStroke(Indicator, Colors.Success, 2)

local IndIcon = Instance.new("TextLabel")
IndIcon.Text = "🎧"
IndIcon.Size = UDim2.new(0, 34, 1, 0)
IndIcon.Position = UDim2.new(0, 8, 0, 0)
IndIcon.BackgroundTransparency = 1
IndIcon.TextColor3 = Colors.Success
IndIcon.Font = Enum.Font.GothamBold
IndIcon.TextSize = 20
IndIcon.ZIndex = 10000
IndIcon.Parent = Indicator

local IndLabel = Instance.new("TextLabel")
IndLabel.Text = "СЛУШАЮ КЛИКИ"
IndLabel.Size = UDim2.new(1, -44, 0.5, 0)
IndLabel.Position = UDim2.new(0, 44, 0, 6)
IndLabel.BackgroundTransparency = 1
IndLabel.TextColor3 = Colors.Text
IndLabel.Font = Enum.Font.GothamBold
IndLabel.TextSize = 13
IndLabel.TextXAlignment = Enum.TextXAlignment.Left
IndLabel.ZIndex = 10000
IndLabel.Parent = Indicator

local IndCount = Instance.new("TextLabel")
IndCount.Text = "Найдено: 0"
IndCount.Size = UDim2.new(1, -44, 0.5, 0)
IndCount.Position = UDim2.new(0, 44, 0.5, 0)
IndCount.BackgroundTransparency = 1
IndCount.TextColor3 = Colors.TextDim
IndCount.Font = Enum.Font.Gotham
IndCount.TextSize = 11
IndCount.TextXAlignment = Enum.TextXAlignment.Left
IndCount.ZIndex = 10000
IndCount.Parent = Indicator

-- Уведомление при клике (всплывающее)
local ClickNotif = Instance.new("Frame")
ClickNotif.Size = UDim2.new(0, 360, 0, 70)
ClickNotif.Position = UDim2.new(0.5, -180, 0, 60)
ClickNotif.BackgroundColor3 = Colors.Bg
ClickNotif.BackgroundTransparency = 0.05
ClickNotif.BorderSizePixel = 0
ClickNotif.Visible = false
ClickNotif.ZIndex = 9998
ClickNotif.Parent = MainGui
addCorner(ClickNotif, 10)
addStroke(ClickNotif, Colors.ButtonCol, 2)

local NotifTitle = Instance.new("TextLabel")
NotifTitle.Text = "🎯 КЛИК ПО КНОПКЕ"
NotifTitle.Size = UDim2.new(1, -16, 0, 20)
NotifTitle.Position = UDim2.new(0, 8, 0, 6)
NotifTitle.BackgroundTransparency = 1
NotifTitle.TextColor3 = Colors.ButtonCol
NotifTitle.Font = Enum.Font.GothamBold
NotifTitle.TextSize = 12
NotifTitle.TextXAlignment = Enum.TextXAlignment.Left
NotifTitle.ZIndex = 9999
NotifTitle.Parent = ClickNotif

local NotifPath = Instance.new("TextLabel")
NotifPath.Text = ""
NotifPath.Size = UDim2.new(1, -16, 0, 16)
NotifPath.Position = UDim2.new(0, 8, 0, 26)
NotifPath.BackgroundTransparency = 1
NotifPath.TextColor3 = Colors.CodeCol
NotifPath.Font = Enum.Font.Code
NotifPath.TextSize = 11
NotifPath.TextXAlignment = Enum.TextXAlignment.Left
NotifPath.TextTruncate = Enum.TextTruncate.AtEnd
NotifPath.ZIndex = 9999
NotifPath.Parent = ClickNotif

local NotifInfo = Instance.new("TextLabel")
NotifInfo.Text = ""
NotifInfo.Size = UDim2.new(1, -16, 0, 14)
NotifInfo.Position = UDim2.new(0, 8, 0, 44)
NotifInfo.BackgroundTransparency = 1
NotifInfo.TextColor3 = Colors.TextDim
NotifInfo.Font = Enum.Font.Gotham
NotifInfo.TextSize = 10
NotifInfo.TextXAlignment = Enum.TextXAlignment.Left
NotifInfo.ZIndex = 9999
NotifInfo.Parent = ClickNotif

-- Основное окно (список истории кликов)
local MainFrame = Instance.new("Frame")
MainFrame.Size = UDim2.new(0, 480, 0, 500)
MainFrame.Position = UDim2.new(0, 20, 0, 80)
MainFrame.BackgroundColor3 = Colors.Bg
MainFrame.BorderSizePixel = 0
MainFrame.Active = true
MainFrame.Parent = MainGui
addCorner(MainFrame, 12)
addStroke(MainFrame, Colors.Border, 1.5)
makeDraggable(MainFrame)

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
TitleLbl.Text = "🎧 EVENT LISTENER"
TitleLbl.Size = UDim2.new(1, -150, 1, 0)
TitleLbl.Position = UDim2.new(0, 12, 0, 0)
TitleLbl.BackgroundTransparency = 1
TitleLbl.TextColor3 = Colors.Text
TitleLbl.Font = Enum.Font.GothamBold
TitleLbl.TextSize = 15
TitleLbl.TextXAlignment = Enum.TextXAlignment.Left
TitleLbl.Parent = TitleBar

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

-- Кнопка вкл/выкл
local ToggleBtn = Instance.new("TextButton")
ToggleBtn.Text = "🎧 СЛУШАТЬ: ВЫКЛ"
ToggleBtn.Size = UDim2.new(1, -24, 0, 40)
ToggleBtn.Position = UDim2.new(0, 12, 0, 54)
ToggleBtn.BackgroundColor3 = Colors.BgLighter
ToggleBtn.TextColor3 = Colors.Text
ToggleBtn.Font = Enum.Font.GothamBold
ToggleBtn.TextSize = 13
ToggleBtn.BorderSizePixel = 0
ToggleBtn.AutoButtonColor = false
ToggleBtn.Parent = MainFrame
addCorner(ToggleBtn, 8)

-- Кнопка очистки истории
local ClearBtn = Instance.new("TextButton")
ClearBtn.Text = "🗑 Очистить историю"
ClearBtn.Size = UDim2.new(1, -24, 0, 32)
ClearBtn.Position = UDim2.new(0, 12, 0, 100)
ClearBtn.BackgroundColor3 = Colors.Danger
ClearBtn.TextColor3 = Colors.Text
ClearBtn.Font = Enum.Font.GothamBold
ClearBtn.TextSize = 12
ClearBtn.BorderSizePixel = 0
ClearBtn.AutoButtonColor = false
ClearBtn.Parent = MainFrame
addCorner(ClearBtn, 8)

-- Инфо-панель выбранной кнопки
local InfoPanel = Instance.new("Frame")
InfoPanel.Size = UDim2.new(1, -24, 0, 100)
InfoPanel.Position = UDim2.new(0, 12, 0, 140)
InfoPanel.BackgroundColor3 = Colors.BgLight
InfoPanel.BorderSizePixel = 0
InfoPanel.Parent = MainFrame
addCorner(InfoPanel, 8)
addStroke(InfoPanel, Colors.ButtonCol, 2)

local IP_Title = Instance.new("TextLabel")
IP_Title.Text = "🖱 ИНФО О КНОПКЕ (последний клик)"
IP_Title.Size = UDim2.new(1, -16, 0, 18)
IP_Title.Position = UDim2.new(0, 8, 0, 4)
IP_Title.BackgroundTransparency = 1
IP_Title.TextColor3 = Colors.ButtonCol
IP_Title.Font = Enum.Font.GothamBold
IP_Title.TextSize = 11
IP_Title.TextXAlignment = Enum.TextXAlignment.Left
IP_Title.Parent = InfoPanel

local IP_Path = Instance.new("TextLabel")
IP_Path.Text = ""
IP_Path.Size = UDim2.new(1, -16, 0, 16)
IP_Path.Position = UDim2.new(0, 8, 0, 24)
IP_Path.BackgroundTransparency = 1
IP_Path.TextColor3 = Colors.CodeCol
IP_Path.Font = Enum.Font.Code
IP_Path.TextSize = 10
IP_Path.TextXAlignment = Enum.TextXAlignment.Left
IP_Path.TextTruncate = Enum.TextTruncate.AtEnd
IP_Path.Parent = InfoPanel

local IP_Info = Instance.new("TextLabel")
IP_Info.Text = ""
IP_Info.Size = UDim2.new(1, -16, 0, 16)
IP_Info.Position = UDim2.new(0, 8, 0, 42)
IP_Info.BackgroundTransparency = 1
IP_Info.TextColor3 = Colors.Text
IP_Info.Font = Enum.Font.Gotham
IP_Info.TextSize = 10
IP_Info.TextXAlignment = Enum.TextXAlignment.Left
IP_Info.Parent = InfoPanel

local IP_CopyBtn = Instance.new("TextButton")
IP_CopyBtn.Text = "📋 Копировать код вызова"
IP_CopyBtn.Size = UDim2.new(0.5, -12, 0, 24)
IP_CopyBtn.Position = UDim2.new(0, 8, 1, -30)
IP_CopyBtn.BackgroundColor3 = Colors.Success
IP_CopyBtn.TextColor3 = Colors.Text
IP_CopyBtn.Font = Enum.Font.GothamBold
IP_CopyBtn.TextSize = 10
IP_CopyBtn.BorderSizePixel = 0
IP_CopyBtn.AutoButtonColor = false
IP_CopyBtn.Parent = InfoPanel
addCorner(IP_CopyBtn, 6)

local IP_TestBtn = Instance.new("TextButton")
IP_TestBtn.Text = "🧪 Тестовый клик"
IP_TestBtn.Size = UDim2.new(0.5, -12, 0, 24)
IP_TestBtn.Position = UDim2.new(0.5, 4, 1, -30)
IP_TestBtn.BackgroundColor3 = Colors.Warning
IP_TestBtn.TextColor3 = Colors.Text
IP_TestBtn.Font = Enum.Font.GothamBold
IP_TestBtn.TextSize = 10
IP_TestBtn.BorderSizePixel = 0
IP_TestBtn.AutoButtonColor = false
IP_TestBtn.Parent = InfoPanel
addCorner(IP_TestBtn, 6)

-- Заголовок истории
local HistoryLbl = Instance.new("TextLabel")
HistoryLbl.Text = "📜 ИСТОРИЯ КЛИКОВ:"
HistoryLbl.Size = UDim2.new(1, -24, 0, 20)
HistoryLbl.Position = UDim2.new(0, 12, 0, 248)
HistoryLbl.BackgroundTransparency = 1
HistoryLbl.TextColor3 = Colors.TextDim
HistoryLbl.Font = Enum.Font.GothamBold
HistoryLbl.TextSize = 11
HistoryLbl.TextXAlignment = Enum.TextXAlignment.Left
HistoryLbl.Parent = MainFrame

-- Список истории
local HistoryList = Instance.new("ScrollingFrame")
HistoryList.Size = UDim2.new(1, -24, 1, -290)
HistoryList.Position = UDim2.new(0, 12, 0, 274)
HistoryList.BackgroundColor3 = Colors.BgLight
HistoryList.BorderSizePixel = 0
HistoryList.ScrollBarThickness = 6
HistoryList.ScrollBarImageColor3 = Colors.Accent
HistoryList.CanvasSize = UDim2.new(0, 0, 0, 0)
HistoryList.AutomaticCanvasSize = Enum.AutomaticSize.Y
HistoryList.Parent = MainFrame
addCorner(HistoryList, 8)

local HistoryLayout = Instance.new("UIListLayout")
HistoryLayout.Padding = UDim.new(0, 4)
HistoryLayout.SortOrder = Enum.SortOrder.LayoutOrder
HistoryLayout.Parent = HistoryList

-- ═══════════════════════════════════════════════════════
-- 📋 ЛОГИКА
-- ═══════════════════════════════════════════════════════
local ListenerActive = false
local LastButton = nil
local ClickHistory = {}
local FoundCount = 0

-- Поиск кнопки под точкой
local function findButtonAtScreenPos(x, y)
    local candidates = {}

    local function scanGui(gui)
        pcall(function()
            if not gui:IsA("ScreenGui") or not gui.Enabled then return end
            -- Пропускаем свои GUI
            if gui == MainGui then return end
            local name = (gui.Name or ""):lower()
            if name:find("eventlistener") or name:find("objinspector") 
               or name:find("esp_") or name:find("espmainui") then return end

            local objs = gui:GetGuiObjectsAtPosition(x, y)
            for _, o in pairs(objs) do
                if o:IsA("GuiButton") then
                    table.insert(candidates, o)
                end
                local p = o.Parent
                while p and p ~= game do
                    if p:IsA("GuiButton") then
                        table.insert(candidates, p)
                    end
                    p = p.Parent
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

    local best = nil
    for _, btn in ipairs(candidates) do
        if btn.Visible and btn.Active then
            if not best or (btn.ZIndex or 0) > (best.ZIndex or 0) then
                best = btn
            end
        end
    end
    return best, #candidates
end

-- Добавить клик в историю
local function addToHistory(button, info)
    local mainPath = info.PlayerGuiPath or info.CoreGuiPath or info.FullPath
    local prefix = info.PlayerGuiPath and "PlayerGui." or (info.CoreGuiPath and "CoreGui." or "")

    table.insert(ClickHistory, 1, {
        Button = button,
        Name = button.Name,
        Class = button.ClassName,
        Path = prefix .. mainPath,
        Size = info.Size,
        Time = os.date("%H:%M:%S"),
    })

    if #ClickHistory > 30 then
        table.remove(ClickHistory, 30)
    end

    -- Обновляем UI истории
    for _, child in ipairs(HistoryList:GetChildren()) do
        if child:IsA("TextButton") then child:Destroy() end
    end

    for i, entry in ipairs(ClickHistory) do
        local row = Instance.new("TextButton")
        row.Size = UDim2.new(1, -8, 0, 40)
        row.BackgroundColor3 = Colors.Bg
        row.BorderSizePixel = 0
        row.Text = ""
        row.AutoButtonColor = false
        row.Parent = HistoryList
        addCorner(row, 6)

        local line1 = Instance.new("TextLabel")
        line1.Text = "[" .. entry.Time .. "] " .. entry.Class .. " [" .. entry.Name .. "]"
        line1.Size = UDim2.new(1, -8, 0, 18)
        line1.Position = UDim2.new(0, 8, 0, 2)
        line1.BackgroundTransparency = 1
        line1.TextColor3 = Colors.ButtonCol
        line1.Font = Enum.Font.GothamBold
        line1.TextSize = 11
        line1.TextXAlignment = Enum.TextXAlignment.Left
        line1.TextTruncate = Enum.TextTruncate.AtEnd
        line1.Parent = row

        local line2 = Instance.new("TextLabel")
        line2.Text = entry.Path
        line2.Size = UDim2.new(1, -8, 0, 16)
        line2.Position = UDim2.new(0, 8, 0, 20)
        line2.BackgroundTransparency = 1
        line2.TextColor3 = Colors.CodeCol
        line2.Font = Enum.Font.Code
        line2.TextSize = 10
        line2.TextXAlignment = Enum.TextXAlignment.Left
        line2.TextTruncate = Enum.TextTruncate.AtEnd
        line2.Parent = row

        row.MouseButton1Click:Connect(function()
            LastButton = entry.Button
            InfoPanel_Update(entry.Button, info)
        end)
    end
end

-- Обновление инфо-панели
function InfoPanel_Update(button, info)
    if not button or not info then return end
    local mainPath = info.PlayerGuiPath or info.CoreGuiPath or info.FullPath
    local prefix = info.PlayerGuiPath and "PlayerGui." or (info.CoreGuiPath and "CoreGui." or "")

    IP_Title.Text = "🖱 " .. button.ClassName .. " [" .. button.Name .. "]"
    IP_Path.Text = "📍 " .. prefix .. mainPath
    IP_Info.Text = string.format("📐 %dx%d  |  👁 %s  |  🎯 %s  |  Z: %d",
        info.Size.X, info.Size.Y,
        info.Visible and "видна" or "скрыта",
        info.Active and "активна" or "неактивна",
        info.ZIndex)
end

-- Показ уведомления
local notifTimer = nil
local function showClickNotif(button, info)
    local mainPath = info.PlayerGuiPath or info.CoreGuiPath or info.FullPath
    local prefix = info.PlayerGuiPath and "PlayerGui." or (info.CoreGuiPath and "CoreGui." or "")

    NotifTitle.Text = "🎯 " .. button.ClassName .. " [" .. button.Name .. "]"
    NotifPath.Text = "📍 " .. prefix .. mainPath
    NotifInfo.Text = string.format("📐 %dx%d  |  👁 %s  |  🎯 %s",
        info.Size.X, info.Size.Y,
        info.Visible and "видна" or "скрыта",
        info.Active and "активна" or "неактивна")

    ClickNotif.Visible = true

    if notifTimer then task.cancel(notifTimer) end
    notifTimer = task.delay(3, function()
        ClickNotif.Visible = false
    end)
end

-- ─── Перехват кликов ───
local listenerConn = UserInputService.InputBegan:Connect(function(input, gpe)
    if not ListenerActive then return end
    if gpe then return end

    if input.UserInputType == Enum.UserInputType.MouseButton1
       or input.UserInputType == Enum.UserInputType.Touch then

        local mousePos = UserInputService:GetMouseLocation()

        -- Игнорируем клики по нашему окну
        local guiAtPos = LocalPlayer.PlayerGui:GetGuiObjectsAtPosition(mousePos.X, mousePos.Y)
        for _, obj in pairs(guiAtPos) do
            if obj:IsDescendantOf(MainGui) then return end
        end

        -- Ищем кнопку под точкой клика
        local button = findButtonAtScreenPos(mousePos.X, mousePos.Y)

        if button then
            local info = analyzeButton(button)
            if info then
                LastButton = button
                InfoPanel_Update(button, info)
                addToHistory(button, info)
                showClickNotif(button, info)
                FoundCount = FoundCount + 1
                IndCount.Text = "Найдено: " .. FoundCount
                print("[EventListener] 🎯 Клик по: " .. info.FullPath)
            end
        end
    end
end)

-- ─── Toggle ───
local function showListener()
    ListenerActive = true
    Indicator.Visible = true
    ToggleBtn.Text = "🎧 СЛУШАТЬ: ВКЛ"
    ToggleBtn.BackgroundColor3 = Colors.Success
    print("[EventListener] 🎧 ВКЛ")
end

local function hideListener()
    ListenerActive = false
    Indicator.Visible = false
    ClickNotif.Visible = false
    ToggleBtn.Text = "🎧 СЛУШАТЬ: ВЫКЛ"
    ToggleBtn.BackgroundColor3 = Colors.BgLighter
    print("[EventListener] 🎧 ВЫКЛ")
end

ToggleBtn.MouseButton1Click:Connect(function()
    if ListenerActive then hideListener() else showListener() end
end)

-- Копировать код
IP_CopyBtn.MouseButton1Click:Connect(function()
    if not LastButton then
        IP_Path.Text = "⚠ Сначала кликни по кнопке"
        return
    end
    local info = analyzeButton(LastButton)
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

    IP_Path.Text = "✅ Код скопирован в консоль"
end)

-- Тестовый клик
IP_TestBtn.MouseButton1Click:Connect(function()
    if not LastButton then
        IP_Path.Text = "⚠ Сначала кликни по кнопке"
        return
    end

    local btn = LastButton
    print("🧪 Тест клика по: " .. btn.Name)

    pcall(function() btn.Activated:Fire() end)
    print("  ✓ Activated")
    task.wait(0.05)
    pcall(function() btn.MouseButton1Click:Fire() end)
    print("  ✓ MouseButton1Click")
    task.wait(0.05)
    pcall(function()
        local pos = btn.AbsolutePosition + btn.AbsoluteSize / 2
        btn.MouseButton1Down:Fire(pos.X, pos.Y)
        btn.MouseButton1Up:Fire(pos.X, pos.Y)
    end)
    print("  ✓ MouseButton1Down/Up")
    task.wait(0.05)
    pcall(function() if btn.Activate then btn:Activate() end end)
    print("  ✓ Activate()")
    task.wait(0.05)
    pcall(function() if btn.Select then btn:Select() end end)
    print("  ✓ Select()")
    task.wait(0.05)
    pcall(function()
        local pos = btn.AbsolutePosition + btn.AbsoluteSize / 2
        VirtualInputManager:SendMouseButtonEvent(pos.X, pos.Y, 0, true, game, 1)
        task.wait(0.05)
        VirtualInputManager:SendMouseButtonEvent(pos.X, pos.Y, 0, false, game, 1)
    end)
    print("  ✓ VirtualInputManager")

    IP_Info.Text = "✅ Тест завершён — смотри что в игре произошло"
end)

-- Очистка истории
ClearBtn.MouseButton1Click:Connect(function()
    ClickHistory = {}
    FoundCount = 0
    IndCount.Text = "Найдено: 0"
    for _, child in ipairs(HistoryList:GetChildren()) do
        if child:IsA("TextButton") then child:Destroy() end
    end
    IP_Path.Text = ""
    IP_Info.Text = ""
    LastButton = nil
    print("[EventListener] 🗑 История очищена")
end)

-- ─── Свернуть ───
local minimized = false
local originalSize = MainFrame.Size
MinBtn.MouseButton1Click:Connect(function()
    minimized = not minimized
    if minimized then
        TweenService:Create(MainFrame, TweenInfo.new(0.2), {Size = UDim2.new(0, 480, 0, 42)}):Play()
        ToggleBtn.Visible = false
        ClearBtn.Visible = false
        InfoPanel.Visible = false
        HistoryLbl.Visible = false
        HistoryList.Visible = false
    else
        TweenService:Create(MainFrame, TweenInfo.new(0.2), {Size = originalSize}):Play()
        ToggleBtn.Visible = true
        ClearBtn.Visible = true
        InfoPanel.Visible = true
        HistoryLbl.Visible = true
        HistoryList.Visible = true
    end
end)

CloseBtn.MouseButton1Click:Connect(function()
    MainGui.Enabled = false
    hideListener()
end)

-- ═══════════════════════════════════════════════════════
-- 🌐 API
-- ═══════════════════════════════════════════════════════
getgenv().EventListener = {
    Show = function() MainGui.Enabled = true end,
    Hide = function() MainGui.Enabled = false end,
    Enable = showListener,
    Disable = hideListener,
    Toggle = function()
        if ListenerActive then hideListener() else showListener() end
    end,
    GetHistory = function() return ClickHistory end,
    ClearHistory = function()
        ClickHistory = {}
        FoundCount = 0
        IndCount.Text = "Найдено: 0"
        for _, child in ipairs(HistoryList:GetChildren()) do
            if child:IsA("TextButton") then child:Destroy() end
        end
    end,
    Destroy = function()
        if listenerConn then listenerConn:Disconnect() end
        pcall(function() MainGui:Destroy() end)
        getgenv().EVENT_LISTENER_LOADED = false
    end,
}

print("[EventListener] ✅ Загружен!")
print("[EventListener] 🎧 Жми «СЛУШАТЬ: ВКЛ» и кликай по кнопкам")
print("[EventListener] Показ: getgenv().EventListener.Show()")
print("[EventListener] Вкл: getgenv().EventListener.Enable()")
