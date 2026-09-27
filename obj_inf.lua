--[[
    obj_inf.lua — Инспектор объектов + E-прицел
    Версия: 3.3
    Для Delta Executor
--]]

if getgenv().OBJ_INF_LOADED then
    pcall(function()
        if getgenv().ObjInf and getgenv().ObjInf.Destroy then
            getgenv().ObjInf.Destroy()
        end
    end)
    task.wait(0.2)
end
getgenv().OBJ_INF_LOADED = true

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")
local CoreGui = game:GetService("CoreGui")
local VirtualInputManager = game:GetService("VirtualInputManager")
local LocalPlayer = Players.LocalPlayer
local Camera = workspace.CurrentCamera

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
    Highlight = Color3.fromRGB(0, 255, 150),
    LogText   = Color3.fromRGB(180, 220, 180),
    EColor    = Color3.fromRGB(255, 220, 80),
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
-- 📦 ФОРМАТИРОВАНИЕ
-- ═══════════════════════════════════════════════════════
local function formatValue(val)
    local t = typeof(val)
    if t == "Vector3" then
        return string.format("Vector3(%.3f, %.3f, %.3f)", val.X, val.Y, val.Z)
    elseif t == "Vector2" then
        return string.format("Vector2(%.3f, %.3f)", val.X, val.Y)
    elseif t == "CFrame" then
        return string.format("CFrame Pos(%.3f, %.3f, %.3f)", val.Position.X, val.Position.Y, val.Position.Z)
    elseif t == "Color3" then
        return string.format("Color3(%d, %d, %d)",
            math.floor(val.R * 255), math.floor(val.G * 255), math.floor(val.B * 255))
    elseif t == "EnumItem" then
        return "Enum." .. tostring(val)
    elseif t == "Instance" then
        return val.ClassName .. " [" .. val.Name .. "]"
    elseif t == "table" then
        local count = 0
        for _ in pairs(val) do count = count + 1 end
        return "table (" .. count .. " items)"
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
        IsButton = true,
        ClassName = obj.ClassName,
        Name = obj.Name,
        FullPath = obj:GetFullName(),
        PlayerGuiPath = nil,
        CoreGuiPath = nil,
        Visible = obj.Visible,
        Active = obj.Active,
        Interactable = obj.Interactable,
        AutoButtonColor = obj.AutoButtonColor,
        Size = obj.AbsoluteSize,
        Position = obj.AbsolutePosition,
        ZIndex = obj.ZIndex,
        Parent = obj.Parent and obj.Parent.Name or "nil",
        ParentClass = obj.Parent and obj.Parent.ClassName or "nil",
        ScreenGui = nil,
        ScreenGuiName = nil,
        ScreenGuiEnabled = nil,
        Signals = {},
        LikelyHandler = nil,
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
            info.ScreenGuiName = parent.Name
            info.ScreenGuiEnabled = parent.Enabled
            break
        end
        parent = parent.Parent
    end

    info.Signals = {
        "Activated", "MouseButton1Click", "MouseButton1Down", "MouseButton1Up",
        "MouseButton2Click", "InputBegan", "InputEnded", "TouchTap",
    }

    if obj:IsA("TextButton") or obj:IsA("ImageButton") then
        info.LikelyHandler = true
    end

    return info
end

-- ═══════════════════════════════════════════════════════
-- 🖱️ ТЕСТОВЫЙ КЛИК
-- ═══════════════════════════════════════════════════════
local function testClickButton(obj)
    if not obj or not obj:IsA("GuiButton") then
        return false, "Не GuiButton"
    end

    local results = {}

    local ok1 = pcall(function() obj.Activated:Fire() end)
    table.insert(results, "Activated: " .. (ok1 and "OK" or "fail"))

    local ok2 = pcall(function() obj.MouseButton1Click:Fire() end)
    table.insert(results, "MouseButton1Click: " .. (ok2 and "OK" or "fail"))

    local ok3 = pcall(function()
        local pos = obj.AbsolutePosition + obj.AbsoluteSize / 2
        obj.MouseButton1Down:Fire(pos.X, pos.Y)
        obj.MouseButton1Up:Fire(pos.X, pos.Y)
    end)
    table.insert(results, "MouseButton1Down/Up: " .. (ok3 and "OK" or "fail"))

    local ok4 = pcall(function()
        if obj.Activate then obj:Activate() end
    end)
    table.insert(results, "Activate(): " .. (ok4 and "OK" or "fail"))

    local ok5 = pcall(function()
        if obj.Select then obj:Select() end
    end)
    table.insert(results, "Select(): " .. (ok5 and "OK" or "fail"))

    local ok6 = pcall(function()
        local pos = obj.AbsolutePosition + obj.AbsoluteSize / 2
        VirtualInputManager:SendMouseButtonEvent(pos.X, pos.Y, 0, true, game, 1)
        task.wait(0.05)
        VirtualInputManager:SendMouseButtonEvent(pos.X, pos.Y, 0, false, game, 1)
    end)
    table.insert(results, "VirtualInput: " .. (ok6 and "OK" or "fail"))

    return true, table.concat(results, "\n")
end

-- ═══════════════════════════════════════════════════════
-- 🖥️ ГЛАВНОЕ ОКНО
-- ═══════════════════════════════════════════════════════
local MainGui = Instance.new("ScreenGui")
MainGui.Name = "ObjInspector_Main"
MainGui.ResetOnSpawn = false
MainGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
MainGui.DisplayOrder = 100
pcall(function() MainGui.Parent = CoreGui end)
if not MainGui.Parent then MainGui.Parent = LocalPlayer:WaitForChild("PlayerGui") end

local MainFrame = Instance.new("Frame")
MainFrame.Size = UDim2.new(0, 560, 0, 680)
MainFrame.Position = UDim2.new(0, 20, 0, 60)
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
TitleLbl.Text = "🔍 ИНСПЕКТОР ОБЪЕКТОВ v3.3"
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

local TabBar = Instance.new("Frame")
TabBar.Size = UDim2.new(1, -24, 0, 34)
TabBar.Position = UDim2.new(0, 12, 0, 50)
TabBar.BackgroundColor3 = Colors.BgLight
TabBar.BorderSizePixel = 0
TabBar.Parent = MainFrame
addCorner(TabBar, 8)

local ContentFrame = Instance.new("Frame")
ContentFrame.Size = UDim2.new(1, -24, 1, -108)
ContentFrame.Position = UDim2.new(0, 12, 0, 92)
ContentFrame.BackgroundColor3 = Colors.BgLight
ContentFrame.BorderSizePixel = 0
ContentFrame.Parent = MainFrame
addCorner(ContentFrame, 10)

-- ═══════════════════════════════════════════════════════
-- 📋 ВКЛАДКА "ИНСПЕКТОР"
-- ═══════════════════════════════════════════════════════
local InspectorTab = Instance.new("Frame")
InspectorTab.Size = UDim2.new(1, -12, 1, -12)
InspectorTab.Position = UDim2.new(0, 6, 0, 6)
InspectorTab.BackgroundTransparency = 1
InspectorTab.Visible = true
InspectorTab.Parent = ContentFrame

local StatusFrame = Instance.new("Frame")
StatusFrame.Size = UDim2.new(1, 0, 0, 60)
StatusFrame.BackgroundColor3 = Colors.Bg
StatusFrame.BorderSizePixel = 0
StatusFrame.Parent = InspectorTab
addCorner(StatusFrame, 8)

local StatusTitle = Instance.new("TextLabel")
StatusTitle.Text = "Активный объект:"
StatusTitle.Size = UDim2.new(1, -16, 0, 16)
StatusTitle.Position = UDim2.new(0, 8, 0, 4)
StatusTitle.BackgroundTransparency = 1
StatusTitle.TextColor3 = Colors.TextDim
StatusTitle.Font = Enum.Font.Gotham
StatusTitle.TextSize = 11
StatusTitle.TextXAlignment = Enum.TextXAlignment.Left
StatusTitle.Parent = StatusFrame

local StatusText = Instance.new("TextLabel")
StatusText.Text = "Кликни по объекту в мире"
StatusText.Size = UDim2.new(1, -16, 0, 20)
StatusText.Position = UDim2.new(0, 8, 0, 20)
StatusText.BackgroundTransparency = 1
StatusText.TextColor3 = Colors.Warning
StatusText.Font = Enum.Font.GothamBold
StatusText.TextSize = 13
StatusText.TextXAlignment = Enum.TextXAlignment.Left
StatusText.TextTruncate = Enum.TextTruncate.AtEnd
StatusText.Parent = StatusFrame

local StatusPos = Instance.new("TextLabel")
StatusPos.Text = ""
StatusPos.Size = UDim2.new(1, -16, 0, 16)
StatusPos.Position = UDim2.new(0, 8, 0, 40)
StatusPos.BackgroundTransparency = 1
StatusPos.TextColor3 = Colors.Success
StatusPos.Font = Enum.Font.Code
StatusPos.TextSize = 11
StatusPos.TextXAlignment = Enum.TextXAlignment.Left
StatusPos.Parent = StatusFrame

local BtnBar = Instance.new("Frame")
BtnBar.Size = UDim2.new(1, 0, 0, 34)
BtnBar.Position = UDim2.new(0, 0, 0, 68)
BtnBar.BackgroundTransparency = 1
BtnBar.Parent = InspectorTab

local SelectModeBtn = Instance.new("TextButton")
SelectModeBtn.Text = "🎯 ВЫБОР: ВКЛ"
SelectModeBtn.Size = UDim2.new(0.25, -2, 1, 0)
SelectModeBtn.Position = UDim2.new(0, 0, 0, 0)
SelectModeBtn.BackgroundColor3 = Colors.Success
SelectModeBtn.TextColor3 = Colors.Text
SelectModeBtn.Font = Enum.Font.GothamBold
SelectModeBtn.TextSize = 10
SelectModeBtn.BorderSizePixel = 0
SelectModeBtn.AutoButtonColor = false
SelectModeBtn.Parent = BtnBar
addCorner(SelectModeBtn, 8)

local EToAllBtn = Instance.new("TextButton")
EToAllBtn.Text = "📌 E to all"
EToAllBtn.Size = UDim2.new(0.25, -2, 1, 0)
EToAllBtn.Position = UDim2.new(0.25, 1, 0, 0)
EToAllBtn.BackgroundColor3 = Colors.Warning
EToAllBtn.TextColor3 = Colors.Text
EToAllBtn.Font = Enum.Font.GothamBold
EToAllBtn.TextSize = 10
EToAllBtn.BorderSizePixel = 0
EToAllBtn.AutoButtonColor = false
EToAllBtn.Parent = BtnBar
addCorner(EToAllBtn, 8)

local EToButtonsBtn = Instance.new("TextButton")
EToButtonsBtn.Text = "🎯 E-прицел"
EToButtonsBtn.Size = UDim2.new(0.25, -2, 1, 0)
EToButtonsBtn.Position = UDim2.new(0.5, 1, 0, 0)
EToButtonsBtn.BackgroundColor3 = Colors.ButtonCol
EToButtonsBtn.TextColor3 = Colors.Text
EToButtonsBtn.Font = Enum.Font.GothamBold
EToButtonsBtn.TextSize = 10
EToButtonsBtn.BorderSizePixel = 0
EToButtonsBtn.AutoButtonColor = false
EToButtonsBtn.Parent = BtnBar
addCorner(EToButtonsBtn, 8)

local CopyBtn = Instance.new("TextButton")
CopyBtn.Text = "📋 Лог"
CopyBtn.Size = UDim2.new(0.25, -2, 1, 0)
CopyBtn.Position = UDim2.new(0.75, 1, 0, 0)
CopyBtn.BackgroundColor3 = Colors.Accent
CopyBtn.TextColor3 = Colors.Text
CopyBtn.Font = Enum.Font.GothamBold
CopyBtn.TextSize = 10
CopyBtn.BorderSizePixel = 0
CopyBtn.AutoButtonColor = false
CopyBtn.Parent = BtnBar
addCorner(CopyBtn, 8)

local ButtonPanel = Instance.new("Frame")
ButtonPanel.Size = UDim2.new(1, 0, 0, 100)
ButtonPanel.Position = UDim2.new(0, 0, 0, 108)
ButtonPanel.BackgroundColor3 = Colors.Bg
ButtonPanel.BorderSizePixel = 0
ButtonPanel.Visible = false
ButtonPanel.Parent = InspectorTab
addCorner(ButtonPanel, 8)
addStroke(ButtonPanel, Colors.ButtonCol, 2)

local BP_Title = Instance.new("TextLabel")
BP_Title.Text = "🖱 ИНФО О КНОПКЕ"
BP_Title.Size = UDim2.new(1, -16, 0, 18)
BP_Title.Position = UDim2.new(0, 8, 0, 4)
BP_Title.BackgroundTransparency = 1
BP_Title.TextColor3 = Colors.ButtonCol
BP_Title.Font = Enum.Font.GothamBold
BP_Title.TextSize = 11
BP_Title.TextXAlignment = Enum.TextXAlignment.Left
BP_Title.Parent = ButtonPanel

local BP_Path = Instance.new("TextLabel")
BP_Path.Text = ""
BP_Path.Size = UDim2.new(1, -16, 0, 16)
BP_Path.Position = UDim2.new(0, 8, 0, 22)
BP_Path.BackgroundTransparency = 1
BP_Path.TextColor3 = Colors.CodeCol
BP_Path.Font = Enum.Font.Code
BP_Path.TextSize = 10
BP_Path.TextXAlignment = Enum.TextXAlignment.Left
BP_Path.TextTruncate = Enum.TextTruncate.AtEnd
BP_Path.Parent = ButtonPanel

local BP_Info = Instance.new("TextLabel")
BP_Info.Text = ""
BP_Info.Size = UDim2.new(1, -16, 0, 16)
BP_Info.Position = UDim2.new(0, 8, 0, 38)
BP_Info.BackgroundTransparency = 1
BP_Info.TextColor3 = Colors.Text
BP_Info.Font = Enum.Font.Gotham
BP_Info.TextSize = 10
BP_Info.TextXAlignment = Enum.TextXAlignment.Left
BP_Info.Parent = ButtonPanel

local BP_CopyCodeBtn = Instance.new("TextButton")
BP_CopyCodeBtn.Text = "📋 Копировать код вызова"
BP_CopyCodeBtn.Size = UDim2.new(0.5, -12, 0, 24)
BP_CopyCodeBtn.Position = UDim2.new(0, 8, 1, -30)
BP_CopyCodeBtn.BackgroundColor3 = Colors.Success
BP_CopyCodeBtn.TextColor3 = Colors.Text
BP_CopyCodeBtn.Font = Enum.Font.GothamBold
BP_CopyCodeBtn.TextSize = 10
BP_CopyCodeBtn.BorderSizePixel = 0
BP_CopyCodeBtn.AutoButtonColor = false
BP_CopyCodeBtn.Parent = ButtonPanel
addCorner(BP_CopyCodeBtn, 6)

local BP_TestClickBtn = Instance.new("TextButton")
BP_TestClickBtn.Text = "🧪 Проверить клик"
BP_TestClickBtn.Size = UDim2.new(0.5, -12, 0, 24)
BP_TestClickBtn.Position = UDim2.new(0.5, 4, 1, -30)
BP_TestClickBtn.BackgroundColor3 = Colors.Warning
BP_TestClickBtn.TextColor3 = Colors.Text
BP_TestClickBtn.Font = Enum.Font.GothamBold
BP_TestClickBtn.TextSize = 10
BP_TestClickBtn.BorderSizePixel = 0
BP_TestClickBtn.AutoButtonColor = false
BP_TestClickBtn.Parent = ButtonPanel
addCorner(BP_TestClickBtn, 6)

local TabSwitch = Instance.new("Frame")
TabSwitch.Size = UDim2.new(1, 0, 0, 30)
TabSwitch.Position = UDim2.new(0, 0, 0, 216)
TabSwitch.BackgroundTransparency = 1
TabSwitch.Visible = false
TabSwitch.Parent = InspectorTab

local PropsTabBtn = Instance.new("TextButton")
PropsTabBtn.Text = "Свойства"
PropsTabBtn.Size = UDim2.new(0.5, -2, 1, 0)
PropsTabBtn.BackgroundColor3 = Colors.Accent
PropsTabBtn.TextColor3 = Colors.Text
PropsTabBtn.Font = Enum.Font.GothamBold
PropsTabBtn.TextSize = 12
PropsTabBtn.BorderSizePixel = 0
PropsTabBtn.AutoButtonColor = false
PropsTabBtn.Parent = TabSwitch
addCorner(PropsTabBtn, 6)

local ChildrenTabBtn = Instance.new("TextButton")
ChildrenTabBtn.Text = "Дети"
ChildrenTabBtn.Size = UDim2.new(0.5, -2, 1, 0)
ChildrenTabBtn.Position = UDim2.new(0.5, 2, 0, 0)
ChildrenTabBtn.BackgroundColor3 = Colors.BgLighter
ChildrenTabBtn.TextColor3 = Colors.Text
ChildrenTabBtn.Font = Enum.Font.GothamBold
ChildrenTabBtn.TextSize = 12
ChildrenTabBtn.BorderSizePixel = 0
ChildrenTabBtn.AutoButtonColor = false
ChildrenTabBtn.Parent = TabSwitch
addCorner(ChildrenTabBtn, 6)

local SearchBox = Instance.new("TextBox")
SearchBox.Size = UDim2.new(1, 0, 0, 28)
SearchBox.Position = UDim2.new(0, 0, 0, 252)
SearchBox.BackgroundColor3 = Colors.BgLighter
SearchBox.PlaceholderText = "🔎 Поиск свойства..."
SearchBox.PlaceholderColor3 = Colors.TextDim
SearchBox.Text = ""
SearchBox.TextColor3 = Colors.Text
SearchBox.Font = Enum.Font.Gotham
SearchBox.TextSize = 13
SearchBox.BorderSizePixel = 0
SearchBox.ClearTextOnFocus = false
SearchBox.Parent = InspectorTab
addCorner(SearchBox, 6)

local PropsList = Instance.new("ScrollingFrame")
PropsList.Size = UDim2.new(1, 0, 1, -288)
PropsList.Position = UDim2.new(0, 0, 0, 286)
PropsList.BackgroundColor3 = Colors.Bg
PropsList.BorderSizePixel = 0
PropsList.ScrollBarThickness = 6
PropsList.ScrollBarImageColor3 = Colors.Accent
PropsList.CanvasSize = UDim2.new(0, 0, 0, 0)
PropsList.AutomaticCanvasSize = Enum.AutomaticSize.Y
PropsList.Parent = InspectorTab
addCorner(PropsList, 8)

local PropsLayout = Instance.new("UIListLayout")
PropsLayout.Padding = UDim.new(0, 4)
PropsLayout.SortOrder = Enum.SortOrder.LayoutOrder
PropsLayout.Parent = PropsList

local ChildrenList = Instance.new("ScrollingFrame")
ChildrenList.Size = UDim2.new(1, 0, 1, -288)
ChildrenList.Position = UDim2.new(0, 0, 0, 286)
ChildrenList.BackgroundColor3 = Colors.Bg
ChildrenList.BorderSizePixel = 0
ChildrenList.ScrollBarThickness = 6
ChildrenList.ScrollBarImageColor3 = Colors.Accent
ChildrenList.CanvasSize = UDim2.new(0, 0, 0, 0)
ChildrenList.AutomaticCanvasSize = Enum.AutomaticSize.Y
ChildrenList.Visible = false
ChildrenList.Parent = InspectorTab
addCorner(ChildrenList, 8)

local ChildrenLayout = Instance.new("UIListLayout")
ChildrenLayout.Padding = UDim.new(0, 4)
ChildrenLayout.SortOrder = Enum.SortOrder.LayoutOrder
ChildrenLayout.Parent = ChildrenList

-- ═══════════════════════════════════════════════════════
-- 📋 ВКЛАДКА "КОНСОЛЬ"
-- ═══════════════════════════════════════════════════════
local ConsoleTab = Instance.new("Frame")
ConsoleTab.Size = UDim2.new(1, -12, 1, -12)
ConsoleTab.Position = UDim2.new(0, 6, 0, 6)
ConsoleTab.BackgroundTransparency = 1
ConsoleTab.Visible = false
ConsoleTab.Parent = ContentFrame

local ConsoleTopBar = Instance.new("Frame")
ConsoleTopBar.Size = UDim2.new(1, 0, 0, 34)
ConsoleTopBar.BackgroundColor3 = Colors.Bg
ConsoleTopBar.BorderSizePixel = 0
ConsoleTopBar.Parent = ConsoleTab
addCorner(ConsoleTopBar, 8)

local ConsoleTitle = Instance.new("TextLabel")
ConsoleTitle.Text = "📃 КОНСОЛЬ"
ConsoleTitle.Size = UDim2.new(0.5, -10, 1, 0)
ConsoleTitle.Position = UDim2.new(0, 10, 0, 0)
ConsoleTitle.BackgroundTransparency = 1
ConsoleTitle.TextColor3 = Colors.Text
ConsoleTitle.Font = Enum.Font.GothamBold
ConsoleTitle.TextSize = 13
ConsoleTitle.TextXAlignment = Enum.TextXAlignment.Left
ConsoleTitle.Parent = ConsoleTopBar

local ClearConsoleBtn = Instance.new("TextButton")
ClearConsoleBtn.Text = "🗑 Очистить"
ClearConsoleBtn.Size = UDim2.new(0.5, -5, 0, 26)
ClearConsoleBtn.Position = UDim2.new(0.5, 0, 0.5, -13)
ClearConsoleBtn.BackgroundColor3 = Colors.Danger
ClearConsoleBtn.TextColor3 = Colors.Text
ClearConsoleBtn.Font = Enum.Font.GothamBold
ClearConsoleBtn.TextSize = 11
ClearConsoleBtn.BorderSizePixel = 0
ClearConsoleBtn.AutoButtonColor = false
ClearConsoleBtn.Parent = ConsoleTopBar
addCorner(ClearConsoleBtn, 6)

local ConsoleList = Instance.new("ScrollingFrame")
ConsoleList.Size = UDim2.new(1, 0, 1, -42)
ConsoleList.Position = UDim2.new(0, 0, 0, 42)
ConsoleList.BackgroundColor3 = Colors.Bg
ConsoleList.BorderSizePixel = 0
ConsoleList.ScrollBarThickness = 6
ConsoleList.ScrollBarImageColor3 = Colors.Accent
ConsoleList.CanvasSize = UDim2.new(0, 0, 0, 0)
ConsoleList.AutomaticCanvasSize = Enum.AutomaticSize.Y
ConsoleList.Parent = ConsoleTab
addCorner(ConsoleList, 8)

local ConsoleLayout = Instance.new("UIListLayout")
ConsoleLayout.Padding = UDim.new(0, 2)
ConsoleLayout.SortOrder = Enum.SortOrder.LayoutOrder
ConsoleLayout.Parent = ConsoleList

-- ═══════════════════════════════════════════════════════
-- 📃 GUI-КОНСОЛЬ
-- ═══════════════════════════════════════════════════════
local LogCount = 0
local function guiLog(text, color)
    LogCount = LogCount + 1
    local label = Instance.new("TextLabel")
    label.Size = UDim2.new(1, -8, 0, 18)
    label.BackgroundTransparency = 1
    label.Text = "[" .. os.date("%H:%M:%S") .. "]  " .. tostring(text)
    label.TextColor3 = color or Colors.LogText
    label.Font = Enum.Font.Code
    label.TextSize = 11
    label.TextXAlignment = Enum.TextXAlignment.Left
    label.TextWrapped = true
    label.Parent = ConsoleList

    task.defer(function()
        ConsoleList.CanvasPosition = Vector2.new(0, ConsoleList.AbsoluteCanvasSize.Y)
    end)

    if LogCount > 200 then
        local first = ConsoleList:FindFirstChildOfClass("TextLabel")
        if first then first:Destroy() end
        LogCount = LogCount - 1
    end
end

guiLog("✅ Инспектор v3.3 загружен!", Colors.Success)
guiLog("🎯 Клик по объекту → инфа", Colors.Warning)

-- ═══════════════════════════════════════════════════════
-- 🎯 ВЫДЕЛЕНИЕ
-- ═══════════════════════════════════════════════════════
local HighlightGui = Instance.new("ScreenGui")
HighlightGui.Name = "ObjInspector_Highlight"
HighlightGui.ResetOnSpawn = false
HighlightGui.Parent = MainGui

local SelectionBox = Instance.new("SelectionBox")
SelectionBox.Name = "InspectorSelection"
SelectionBox.LineThickness = 0.1
SelectionBox.Color3 = Colors.Highlight
SelectionBox.Transparency = 0.3
SelectionBox.Visible = false
SelectionBox.Parent = HighlightGui

-- ═══════════════════════════════════════════════════════
-- 📌 E-МАРКЕРЫ ДЛЯ 3D ОБЪЕКТОВ
-- ═══════════════════════════════════════════════════════
local EMarkersGui = Instance.new("ScreenGui")
EMarkersGui.Name = "ObjInspector_EMarkers"
EMarkersGui.ResetOnSpawn = false
EMarkersGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
EMarkersGui.DisplayOrder = 105
pcall(function() EMarkersGui.Parent = CoreGui end)
if not EMarkersGui.Parent then EMarkersGui.Parent = LocalPlayer:WaitForChild("PlayerGui") end

local EMarkers = {}
local EMarkersEnabled = false
local MaxEMarkers = 150

local function createEMarker(instance)
    if EMarkers[instance] then return end
    if not instance or not instance.Parent then return end
    if not (instance:IsA("BasePart") or instance:IsA("Model")) then return end
    if instance:IsDescendantOf(LocalPlayer.Character) then return end

    local adornee = nil
    local offset = Vector3.new(0, 3, 0)

    if instance:IsA("BasePart") then
        adornee = instance
        offset = Vector3.new(0, instance.Size.Y / 2 + 1.5, 0)
    elseif instance:IsA("Model") then
        local primary = instance.PrimaryPart or instance:FindFirstChildWhichIsA("BasePart")
        if not primary then return end
        adornee = primary
        offset = Vector3.new(0, primary.Size.Y / 2 + 1.5, 0)
    end

    if not adornee then return end

    local billboard = Instance.new("BillboardGui")
    billboard.Name = "EMarker"
    billboard.Size = UDim2.new(0, 40, 0, 40)
    billboard.StudsOffset = offset
    billboard.AlwaysOnTop = true
    billboard.MaxDistance = 200
    billboard.Adornee = adornee
    billboard.Parent = EMarkersGui

    local bg = Instance.new("Frame")
    bg.Size = UDim2.new(1, 0, 1, 0)
    bg.BackgroundColor3 = Color3.fromRGB(30, 30, 40)
    bg.BackgroundTransparency = 0.2
    bg.BorderSizePixel = 0
    bg.Parent = billboard
    addCorner(bg, 20)
    addStroke(bg, Colors.EColor, 2)

    local lbl = Instance.new("TextLabel")
    lbl.Size = UDim2.new(1, 0, 1, 0)
    lbl.BackgroundTransparency = 1
    lbl.Text = "E"
    lbl.TextColor3 = Colors.EColor
    lbl.Font = Enum.Font.GothamBold
    lbl.TextSize = 20
    lbl.TextStrokeTransparency = 0
    lbl.TextStrokeColor3 = Color3.fromRGB(0, 0, 0)
    lbl.Parent = billboard

    local clickBtn = Instance.new("TextButton")
    clickBtn.Size = UDim2.new(1, 0, 1, 0)
    clickBtn.BackgroundTransparency = 1
    clickBtn.Text = ""
    clickBtn.Parent = billboard

    clickBtn.MouseButton1Click:Connect(function()
        guiLog("📌 E-клик по: " .. instance.ClassName .. " [" .. instance.Name .. "]", Colors.EColor)
        showObject(instance)
        selectTab(1)
    end)

    EMarkers[instance] = {Gui = billboard, Adornee = adornee}
end

local function clearAllEMarkers()
    for instance, marker in pairs(EMarkers) do
        pcall(function() marker.Gui:Destroy() end)
    end
    EMarkers = {}
end

local function eToAll()
    clearAllEMarkers()
    local count = 0
    for _, obj in ipairs(workspace:GetDescendants()) do
        if count >= MaxEMarkers then break end
        if obj:IsA("BasePart") and not obj:IsDescendantOf(LocalPlayer.Character) then
            local isCharPart = false
            for _, plr in ipairs(Players:GetPlayers()) do
                if plr.Character and obj:IsDescendantOf(plr.Character) then
                    isCharPart = true
                    break
                end
            end
            if not isCharPart and obj.Name ~= "Terrain" and obj.Size.Magnitude > 1 then
                createEMarker(obj)
                count = count + 1
            end
        end
    end
    guiLog("📌 E to all: " .. count .. " маркеров", Colors.EColor)
end

-- ═══════════════════════════════════════════════════════
-- 🎯 E-ПРИЦЕЛ (поверх всего)
-- ═══════════════════════════════════════════════════════
local AimGui = Instance.new("ScreenGui")
AimGui.Name = "ObjInspector_Aim"
AimGui.ResetOnSpawn = false
AimGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
AimGui.IgnoreGuiInset = true
AimGui.DisplayOrder = 99999         -- ⬅️ ВЫШЕ ВСЕХ
pcall(function() AimGui.Parent = CoreGui end)
if not AimGui.Parent then AimGui.Parent = LocalPlayer:WaitForChild("PlayerGui") end

local AimActive = false

local AimSquare = Instance.new("Frame")
AimSquare.Name = "AimSquare"
AimSquare.Size = UDim2.new(0, 250, 0, 250)
AimSquare.Position = UDim2.new(0.5, -125, 0.5, -125)
AimSquare.BackgroundColor3 = Color3.fromRGB(90, 180, 255)
AimSquare.BackgroundTransparency = 0.85
AimSquare.BorderSizePixel = 0
AimSquare.Active = true
AimSquare.Visible = false
AimSquare.ZIndex = 100
AimSquare.Parent = AimGui
addCorner(AimSquare, 8)
addStroke(AimSquare, Colors.ButtonCol, 2)

-- Контейнер для маркеров — БЕЗ обрезки
local AimMarkersContainer = Instance.new("Frame")
AimMarkersContainer.Name = "MarkersContainer"
AimMarkersContainer.Size = UDim2.new(1, 0, 1, 0)
AimMarkersContainer.Position = UDim2.new(0, 0, 0, 0)
AimMarkersContainer.BackgroundTransparency = 1
AimMarkersContainer.ClipsDescendants = false    -- ⬅️ НЕ ОБРЕЗАЕМ
AimMarkersContainer.ZIndex = 105
AimMarkersContainer.Parent = AimSquare

local AimResize = Instance.new("TextButton")
AimResize.Size = UDim2.new(0, 30, 0, 30)
AimResize.Position = UDim2.new(1, -30, 1, -30)
AimResize.BackgroundColor3 = Color3.fromRGB(255, 180, 60)
AimResize.BackgroundTransparency = 0.2
AimResize.Text = "◢"
AimResize.TextColor3 = Color3.fromRGB(255, 255, 255)
AimResize.TextStrokeTransparency = 0
AimResize.Font = Enum.Font.GothamBold
AimResize.TextSize = 18
AimResize.BorderSizePixel = 0
AimResize.AutoButtonColor = false
AimResize.ZIndex = 110
AimResize.Parent = AimSquare
addCorner(AimResize, 6)

local AimHeader = Instance.new("TextLabel")
AimHeader.Size = UDim2.new(1, 0, 0, 20)
AimHeader.Position = UDim2.new(0, 0, 0, -22)
AimHeader.BackgroundTransparency = 1
AimHeader.Text = "🎯 ПРИЦЕЛ — найдено кнопок: 0"
AimHeader.TextColor3 = Colors.ButtonCol
AimHeader.TextStrokeTransparency = 0
AimHeader.TextStrokeColor3 = Color3.fromRGB(0, 0, 0)
AimHeader.Font = Enum.Font.GothamBold
AimHeader.TextSize = 12
AimHeader.ZIndex = 110
AimHeader.Parent = AimSquare

-- Перетаскивание прицела
local aimDragging = false
local aimDragStart, aimStartPos
AimSquare.InputBegan:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1
       or input.UserInputType == Enum.UserInputType.Touch then
        local absPos = AimSquare.AbsolutePosition
        local absSize = AimSquare.AbsoluteSize
        local mx, my = input.Position.X, input.Position.Y
        local relX = (mx - absPos.X) / absSize.X
        local relY = (my - absPos.Y) / absSize.Y
        if relX > 0.82 and relY > 0.82 then return end
        aimDragging = true
        aimDragStart = input.Position
        aimStartPos = AimSquare.Position
    end
end)
AimSquare.InputChanged:Connect(function(input)
    if aimDragging and (input.UserInputType == Enum.UserInputType.MouseMovement
       or input.UserInputType == Enum.UserInputType.Touch) then
        local delta = input.Position - aimDragStart
        AimSquare.Position = UDim2.new(
            aimStartPos.X.Scale, aimStartPos.X.Offset + delta.X,
            aimStartPos.Y.Scale, aimStartPos.Y.Offset + delta.Y
        )
    end
end)
AimSquare.InputEnded:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1
       or input.UserInputType == Enum.UserInputType.Touch then
        aimDragging = false
    end
end)

-- Ресайз
local aimResizing = false
local aimResizeStart, aimStartSize
AimResize.InputBegan:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1
       or input.UserInputType == Enum.UserInputType.Touch then
        aimResizing = true
        aimResizeStart = input.Position
        aimStartSize = AimSquare.AbsoluteSize
    end
end)
AimResize.InputChanged:Connect(function(input)
    if aimResizing and (input.UserInputType == Enum.UserInputType.MouseMovement
       or input.UserInputType == Enum.UserInputType.Touch) then
        local delta = input.Position - aimResizeStart
        local newW = math.max(80, math.min(800, aimStartSize.X + delta.X))
        local newH = math.max(80, math.min(800, aimStartSize.Y + delta.Y))
        AimSquare.Size = UDim2.new(0, newW, 0, newH)
        AimResize.Position = UDim2.new(1, -30, 1, -30)
    end
end)
AimResize.InputEnded:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1
       or input.UserInputType == Enum.UserInputType.Touch then
        aimResizing = false
    end
end)

-- ═══════════════════════════════════════════════════════
-- 🎯 СБОР И ФИЛЬТРАЦИЯ КНОПОК
-- ═══════════════════════════════════════════════════════
local InsideMarkers = {}

-- Список запрещённых имён GUI (наши)
local FORBIDDEN_NAMES = {
    "objinspector", "obj_inf", "objinspector_main", "objinspector_aim",
    "objinspector_emarker", "objinspector_highlight",
    "esp_mainui", "esp_crosshair", "esp_clickindicator",
    "espclickindicator", "espmainui", "esp_routevisuals",
    "routeauto", "aim",
}

-- Собираем ссылки на наши GUI
local function isOurGui(gui)
    if gui == MainGui or gui == EMarkersGui or gui == AimGui 
       or gui == HighlightGui or gui == ClickIndicatorGui then
        return true
    end
    local n = (gui.Name or ""):lower()
    for _, fname in ipairs(FORBIDDEN_NAMES) do
        if n:find(fname, 1, true) then return true end
    end
    return false
end

local function isInsideOurGui(obj)
    local p = obj
    while p and p ~= game do
        if isOurGui(p) then return true end
        p = p.Parent
    end
    return false
end

local function collectAllButtons()
    local buttons = {}

    pcall(function()
        for _, gui in pairs(LocalPlayer.PlayerGui:GetChildren()) do
            if gui:IsA("ScreenGui") and gui.Enabled and not isOurGui(gui) then
                for _, obj in ipairs(gui:GetDescendants()) do
                    if obj:IsA("GuiButton") and obj.Visible and obj.Active then
                        if not isInsideOurGui(obj) then
                            local s = obj.AbsoluteSize
                            if s.X >= 30 and s.Y >= 25 and s.X < 500 and s.Y < 400 then
                                table.insert(buttons, obj)
                            end
                        end
                    end
                end
            end
        end
    end)

    pcall(function()
        for _, gui in pairs(CoreGui:GetChildren()) do
            if gui:IsA("ScreenGui") and gui.Enabled and not isOurGui(gui) then
                for _, obj in ipairs(gui:GetDescendants()) do
                    if obj:IsA("GuiButton") and obj.Visible and obj.Active then
                        if not isInsideOurGui(obj) then
                            local s = obj.AbsoluteSize
                            if s.X >= 30 and s.Y >= 25 and s.X < 500 and s.Y < 400 then
                                table.insert(buttons, obj)
                            end
                        end
                    end
                end
            end
        end
    end)

    return buttons
end

local function isInsideAim(button)
    local ap = AimSquare.AbsolutePosition
    local as = AimSquare.AbsoluteSize
    local bpos = button.AbsolutePosition
    local bs = button.AbsoluteSize
    local cx = bpos.X + bs.X / 2
    local cy = bpos.Y + bs.Y / 2
    return cx >= ap.X and cx <= ap.X + as.X
       and cy >= ap.Y and cy <= ap.Y + as.Y
end

local function clearInsideMarkers()
    for btn, data in pairs(InsideMarkers) do
        pcall(function() data.Marker:Destroy() end)
    end
    InsideMarkers = {}
end

local function createInsideMarker(button)
    if InsideMarkers[button] then
        -- Обновить позицию
        local data = InsideMarkers[button]
        local ap = AimSquare.AbsolutePosition
        local bp = button.AbsolutePosition
        local bs = button.AbsoluteSize
        local centerX = bp.X + bs.X / 2
        local centerY = bp.Y + bs.Y / 2
        local relX = centerX - ap.X
        local relY = centerY - ap.Y
        data.Marker.Position = UDim2.new(0, relX - 13, 0, relY - 13)
        return
    end

    local ap = AimSquare.AbsolutePosition
    local bp = button.AbsolutePosition
    local bs = button.AbsoluteSize
    local centerX = bp.X + bs.X / 2
    local centerY = bp.Y + bs.Y / 2
    local relX = centerX - ap.X
    local relY = centerY - ap.Y

    local marker = Instance.new("TextButton")
    marker.Name = "InsideEMarker"
    marker.Size = UDim2.new(0, 26, 0, 26)
    marker.Position = UDim2.new(0, relX - 13, 0, relY - 13)
    marker.BackgroundColor3 = Color3.fromRGB(255, 60, 60)   -- красный чтобы видеть
    marker.BackgroundTransparency = 0.1
    marker.Text = "E"
    marker.TextColor3 = Color3.fromRGB(255, 255, 255)
    marker.TextStrokeTransparency = 0
    marker.TextStrokeColor3 = Color3.fromRGB(0, 0, 0)
    marker.Font = Enum.Font.GothamBold
    marker.TextSize = 14
    marker.BorderSizePixel = 0
    marker.AutoButtonColor = false
    marker.ZIndex = 106
    marker.Parent = AimMarkersContainer
    addCorner(marker, 13)
    addStroke(marker, Color3.fromRGB(255, 220, 0), 2)

    local touchStart = nil
    marker.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1
           or input.UserInputType == Enum.UserInputType.Touch then
            touchStart = input.Position
        end
    end)
    marker.InputEnded:Connect(function(input)
        if touchStart then
            local delta = (Vector2.new(input.Position.X, input.Position.Y) 
                         - Vector2.new(touchStart.X, touchStart.Y)).Magnitude
            if delta < 10 then
                guiLog("🖱 E-клик: " .. button.Name, Colors.ButtonCol)
                showObject(button)
                selectTab(1)
            end
            touchStart = nil
        end
    end)

    InsideMarkers[button] = {Marker = marker, Button = button}
end

-- Основной цикл обновления
local updateTimer = 0
local diagTimer = 0
RunService.RenderStepped:Connect(function(dt)
    if not AimActive then return end

    -- Обновление маркеров 10 раз в секунду
    updateTimer = updateTimer + dt
    if updateTimer < 0.1 then return end
    updateTimer = 0

    -- Обновить позиции существующих маркеров
    for btn, data in pairs(InsideMarkers) do
        if not btn.Parent or not btn.Visible then
            pcall(function() data.Marker:Destroy() end)
            InsideMarkers[btn] = nil
        else
            local ap = AimSquare.AbsolutePosition
            local bp = btn.AbsolutePosition
            local bs = btn.AbsoluteSize
            local centerX = bp.X + bs.X / 2
            local centerY = bp.Y + bs.Y / 2
            local relX = centerX - ap.X
            local relY = centerY - ap.Y
            data.Marker.Position = UDim2.new(0, relX - 13, 0, relY - 13)
        end
    end

    -- Найти все кнопки
    local buttons = collectAllButtons()

    -- Убрать маркеры у кнопок, которые вышли из прицела
    for btn, data in pairs(InsideMarkers) do
        if not isInsideAim(btn) then
            pcall(function() data.Marker:Destroy() end)
            InsideMarkers[btn] = nil
        end
    end

    -- Добавить маркеры для новых кнопок
    for _, btn in ipairs(buttons) do
        if isInsideAim(btn) and not InsideMarkers[btn] then
            createInsideMarker(btn)
        end
    end

    -- Обновить заголовок
    local count = 0
    for _ in pairs(InsideMarkers) do count = count + 1 end
    AimHeader.Text = "🎯 ПРИЦЕЛ — найдено кнопок: " .. count

    -- ДИАГНОСТИКА — раз в 3 сек показываем в консоли что нашли
    diagTimer = diagTimer + 0.1
    if diagTimer >= 3 then
        diagTimer = 0
        local shown = 0
        for btn, data in pairs(InsideMarkers) do
            if shown < 10 then
                local s = btn.AbsoluteSize
                guiLog(string.format("🔍 %s [%dx%d] %s", btn.Name, s.X, s.Y, btn:GetFullName()), Colors.TextDim)
                shown = shown + 1
            end
        end
        if shown > 0 then
            guiLog("... всего " .. count .. " кнопок", Colors.TextDim)
        end
    end
end)

-- ═══════════════════════════════════════════════════════
-- 🎯 ПОКАЗ / СКРЫТИЕ ПРИЦЕЛА
-- ═══════════════════════════════════════════════════════
local minimized = false
local originalSize = MainFrame.Size

local function showAim()
    AimActive = true
    AimSquare.Visible = true
    AimSquare.Position = UDim2.new(0.5, -125, 0.5, -125)

    -- Сворачиваем инспектор чтобы не мешал
    if not minimized then
        minimized = true
        TweenService:Create(MainFrame, TweenInfo.new(0.2), {Size = UDim2.new(0, 560, 0, 42)}):Play()
        TabBar.Visible = false
        ContentFrame.Visible = false
    end

    guiLog("🎯 E-прицел активирован (инспектор свёрнут)", Colors.ButtonCol)
end

local function hideAim()
    AimActive = false
    AimSquare.Visible = false
    clearInsideMarkers()

    -- Разворачиваем инспектор
    if minimized then
        minimized = false
        TweenService:Create(MainFrame, TweenInfo.new(0.2), {Size = originalSize}):Play()
        TabBar.Visible = true
        ContentFrame.Visible = true
    end
end

local function toggleAim()
    if AimActive then hideAim() else showAim() end
end

local function eToButtons()
    toggleAim()
end

local function clearAllButtonMarkers()
    hideAim()
end

-- ═══════════════════════════════════════════════════════
-- 🖱️ ЛОГИКА ВЫБОРА
-- ═══════════════════════════════════════════════════════
local SelectMode = true
local CurrentObject = nil
local CurrentButtonInfo = nil
local AllProps = {}
local AllChildren = {}

local function clearList(list)
    for _, child in pairs(list:GetChildren()) do
        if child:IsA("Frame") or child:IsA("TextButton") then
            child:Destroy()
        end
    end
end

local function addPropRow(parent, propName, propValue, isSection, valueColor)
    local row = Instance.new("Frame")
    row.Size = UDim2.new(1, -8, 0, isSection and 22 or 44)
    row.BackgroundColor3 = isSection and Colors.Bg or Colors.BgLighter
    row.BackgroundTransparency = isSection and 1 or 0.3
    row.BorderSizePixel = 0
    row.Parent = parent
    addCorner(row, 6)

    local nameLbl = Instance.new("TextLabel")
    nameLbl.Text = propName
    nameLbl.Size = UDim2.new(0.4, -8, 1, 0)
    nameLbl.Position = UDim2.new(0, 8, 0, 0)
    nameLbl.BackgroundTransparency = 1
    nameLbl.TextColor3 = isSection and Colors.Accent or Colors.Text
    nameLbl.Font = Enum.Font.GothamBold
    nameLbl.TextSize = isSection and 12 or 11
    nameLbl.TextXAlignment = Enum.TextXAlignment.Left
    nameLbl.TextTruncate = Enum.TextTruncate.AtEnd
    nameLbl.Parent = row

    if not isSection then
        local valLbl = Instance.new("TextLabel")
        valLbl.Text = propValue
        valLbl.Size = UDim2.new(0.6, -8, 1, 0)
        valLbl.Position = UDim2.new(0.4, 0, 0, 0)
        valLbl.BackgroundTransparency = 1
        valLbl.TextColor3 = valueColor or Colors.Success
        valLbl.Font = Enum.Font.Code
        valLbl.TextSize = 10
        valLbl.TextXAlignment = Enum.TextXAlignment.Left
        valLbl.TextYAlignment = Enum.TextYAlignment.Center
        valLbl.TextWrapped = true
        valLbl.Parent = row
    end

    return row
end

function showObject(obj)
    CurrentObject = obj
    SelectionBox.Adornee = obj
    SelectionBox.Visible = true

    StatusText.Text = obj.ClassName .. "  ▸  " .. obj.Name
    StatusText.TextColor3 = Colors.Success

    if obj:IsA("BasePart") then
        local p = obj.Position
        StatusPos.Text = string.format("📍 (%.2f, %.2f, %.2f)  Size: (%.1f, %.1f, %.1f)",
            p.X, p.Y, p.Z, obj.Size.X, obj.Size.Y, obj.Size.Z)
    elseif obj:IsA("GuiObject") then
        local ap = obj.AbsolutePosition
        local as = obj.AbsoluteSize
        StatusPos.Text = string.format("📱 Экран: (%.0f, %.0f)  Size: (%.0f, %.0f)",
            ap.X, ap.Y, as.X, as.Y)
    elseif obj:IsA("Model") then
        local pivot = obj:GetPivot().Position
        StatusPos.Text = string.format("📍 Pivot: (%.2f, %.2f, %.2f)", pivot.X, pivot.Y, pivot.Z)
    else
        StatusPos.Text = ""
    end

    guiLog("📦 Выбран: " .. obj.ClassName .. " [" .. obj.Name .. "]", Colors.Success)

    local btnInfo = analyzeButton(obj)
    CurrentButtonInfo = btnInfo

    if btnInfo then
        ButtonPanel.Visible = true

        local mainPath = btnInfo.PlayerGuiPath or btnInfo.CoreGuiPath or btnInfo.FullPath
        local prefix = btnInfo.PlayerGuiPath and "PlayerGui." or (btnInfo.CoreGuiPath and "CoreGui." or "")
        BP_Path.Text = "📍 " .. prefix .. mainPath

        BP_Info.Text = string.format("👁 %s  |  🎯 %s  |  🖱 %s  |  📐 %dx%d",
            btnInfo.Visible and "видна" or "СКРЫТА",
            btnInfo.Active and "активна" or "НЕАКТИВНА",
            btnInfo.Interactable and "кликабельна" or "некликабельна",
            btnInfo.Size.X, btnInfo.Size.Y
        )

        BP_Path.TextColor3 = btnInfo.Visible and Colors.CodeCol or Colors.Danger

        guiLog("🖱 КНОПКА НАЙДЕНА!", Colors.ButtonCol)
        guiLog("   Путь: " .. prefix .. mainPath, Colors.CodeCol)

        TabSwitch.Position = UDim2.new(0, 0, 0, 216)
        SearchBox.Position = UDim2.new(0, 0, 0, 252)
        PropsList.Position = UDim2.new(0, 0, 0, 286)
        ChildrenList.Position = UDim2.new(0, 0, 0, 286)
    else
        ButtonPanel.Visible = false
        TabSwitch.Position = UDim2.new(0, 0, 0, 108)
        SearchBox.Position = UDim2.new(0, 0, 0, 144)
        PropsList.Position = UDim2.new(0, 0, 0, 178)
        ChildrenList.Position = UDim2.new(0, 0, 0, 178)
    end

    clearList(PropsList)
    AllProps = {}

    addPropRow(PropsList, "🆔 ОСНОВНЫЕ", "", true)
    addPropRow(PropsList, "Name", obj.Name, false)
    addPropRow(PropsList, "ClassName", obj.ClassName, false)
    addPropRow(PropsList, "FullName", obj:GetFullName(), false)
    addPropRow(PropsList, "Parent", obj.Parent and (obj.Parent.ClassName .. " [" .. obj.Parent.Name .. "]") or "nil", false)

    table.insert(AllProps, {Name = "Name", Value = obj.Name})
    table.insert(AllProps, {Name = "ClassName", Value = obj.ClassName})
    table.insert(AllProps, {Name = "FullName", Value = obj:GetFullName()})

    if btnInfo then
        addPropRow(PropsList, "🖱 ИНФО О КНОПКЕ", "", true)

        if btnInfo.PlayerGuiPath then
            addPropRow(PropsList, "PlayerGuiPath", btnInfo.PlayerGuiPath, false, Colors.CodeCol)
        end
        if btnInfo.CoreGuiPath then
            addPropRow(PropsList, "CoreGuiPath", btnInfo.CoreGuiPath, false, Colors.CodeCol)
        end

        addPropRow(PropsList, "Visible", tostring(btnInfo.Visible), false,
            btnInfo.Visible and Colors.Success or Colors.Danger)
        addPropRow(PropsList, "Active", tostring(btnInfo.Active), false,
            btnInfo.Active and Colors.Success or Colors.Danger)
        addPropRow(PropsList, "Interactable", tostring(btnInfo.Interactable), false,
            btnInfo.Interactable and Colors.Success or Colors.Danger)

        addPropRow(PropsList, "💻 КОД ДЛЯ ВЫЗОВА", "", true)
        local mainPath2 = btnInfo.PlayerGuiPath or btnInfo.CoreGuiPath or obj.Name
        local basePath = btnInfo.PlayerGuiPath and "game.Players.LocalPlayer.PlayerGui." 
            or (btnInfo.CoreGuiPath and "game:GetService('CoreGui')." or "game.")
        local fullCode = basePath .. mainPath2
        addPropRow(PropsList, "Путь в Lua", fullCode, false, Colors.CodeCol)
    end

    if obj:IsA("BasePart") then
        addPropRow(PropsList, "📍 ПОЗИЦИЯ", "", true)
        local posStr = string.format("Vector3(%.3f, %.3f, %.3f)", obj.Position.X, obj.Position.Y, obj.Position.Z)
        local sizeStr = string.format("Vector3(%.2f, %.2f, %.2f)", obj.Size.X, obj.Size.Y, obj.Size.Z)
        addPropRow(PropsList, "Position", posStr, false)
        addPropRow(PropsList, "Size", sizeStr, false)
        table.insert(AllProps, {Name = "Position", Value = posStr})
    end

    addPropRow(PropsList, "⚙ ВСЕ СВОЙСТВА", "", true)

    local success, err = pcall(function()
        for _, prop in ipairs(obj:GetProperties()) do
            if prop ~= "Parent" and prop ~= "Name" and prop ~= "ClassName" then
                local ok, value = pcall(function() return obj[prop] end)
                if ok and value ~= nil then
                    local valStr = formatValue(value)
                    addPropRow(PropsList, prop, valStr, false)
                    table.insert(AllProps, {Name = prop, Value = valStr})
                end
            end
        end
    end)

    clearList(ChildrenList)
    AllChildren = {}
    for _, child in ipairs(obj:GetChildren()) do
        table.insert(AllChildren, child)
    end

    if #AllChildren == 0 then
        local emptyRow = Instance.new("Frame")
        emptyRow.Size = UDim2.new(1, -8, 0, 30)
        emptyRow.BackgroundTransparency = 1
        emptyRow.Parent = ChildrenList
        local lbl = Instance.new("TextLabel")
        lbl.Size = UDim2.new(1, 0, 1, 0)
        lbl.BackgroundTransparency = 1
        lbl.Text = "Детей нет"
        lbl.TextColor3 = Colors.TextDim
        lbl.Font = Enum.Font.Gotham
        lbl.TextSize = 12
        lbl.Parent = emptyRow
    else
        for i, child in ipairs(AllChildren) do
            local row = addPropRow(ChildrenList, child.Name, child.ClassName, false)
            local clickBtn = Instance.new("TextButton")
            clickBtn.Size = UDim2.new(1, 0, 1, 0)
            clickBtn.BackgroundTransparency = 1
            clickBtn.Text = ""
            clickBtn.Parent = row
            clickBtn.MouseButton1Click:Connect(function()
                showObject(child)
            end)
        end
    end

    TabSwitch.Visible = true
end

-- ═══════════════════════════════════════════════════════
-- 🎛️ КНОПКИ
-- ═══════════════════════════════════════════════════════
SelectModeBtn.MouseButton1Click:Connect(function()
    SelectMode = not SelectMode
    if SelectMode then
        SelectModeBtn.Text = "🎯 ВЫБОР: ВКЛ"
        SelectModeBtn.BackgroundColor3 = Colors.Success
        guiLog("🎯 Режим выбора ВКЛ", Colors.Success)
    else
        SelectModeBtn.Text = "🎯 ВЫБОР: ВЫКЛ"
        SelectModeBtn.BackgroundColor3 = Colors.Danger
        guiLog("🎯 Режим выбора ВЫКЛ", Colors.Danger)
    end
end)

EToAllBtn.MouseButton1Click:Connect(function()
    EMarkersEnabled = not EMarkersEnabled
    if EMarkersEnabled then
        EToAllBtn.Text = "📌 E: ВКЛ"
        EToAllBtn.BackgroundColor3 = Colors.Success
        eToAll()
    else
        EToAllBtn.Text = "📌 E to all"
        EToAllBtn.BackgroundColor3 = Colors.Warning
        clearAllEMarkers()
        guiLog("📌 E-маркеры удалены", Colors.Warning)
    end
end)

EToButtonsBtn.MouseButton1Click:Connect(function()
    toggleAim()
    if AimActive then
        EToButtonsBtn.Text = "🎯 E-прицел: ВКЛ"
        EToButtonsBtn.BackgroundColor3 = Colors.Success
    else
        EToButtonsBtn.Text = "🎯 E-прицел"
        EToButtonsBtn.BackgroundColor3 = Colors.ButtonCol
    end
end)

CopyBtn.MouseButton1Click:Connect(function()
    if not CurrentObject then
        guiLog("⚠ Сначала выбери объект", Colors.Danger)
        return
    end
    guiLog("════════════════════════════", Colors.TextDim)
    guiLog("📦 " .. CurrentObject:GetFullName(), Colors.Success)
    guiLog("════════════════════════════", Colors.TextDim)
    if CurrentButtonInfo then
        guiLog("🖱 КНОПКА!", Colors.ButtonCol)
        if CurrentButtonInfo.PlayerGuiPath then
            guiLog("   PlayerGui: " .. CurrentButtonInfo.PlayerGuiPath, Colors.CodeCol)
        end
        if CurrentButtonInfo.CoreGuiPath then
            guiLog("   CoreGui: " .. CurrentButtonInfo.CoreGuiPath, Colors.CodeCol)
        end
    end
    for _, p in ipairs(AllProps) do
        guiLog(string.format("%s = %s", p.Name, p.Value), Colors.LogText)
    end
end)

PropsTabBtn.MouseButton1Click:Connect(function()
    PropsList.Visible = true
    ChildrenList.Visible = false
    PropsTabBtn.BackgroundColor3 = Colors.Accent
    ChildrenTabBtn.BackgroundColor3 = Colors.BgLighter
end)

ChildrenTabBtn.MouseButton1Click:Connect(function()
    PropsList.Visible = false
    ChildrenList.Visible = true
    PropsTabBtn.BackgroundColor3 = Colors.BgLighter
    ChildrenTabBtn.BackgroundColor3 = Colors.Accent
end)

ClearConsoleBtn.MouseButton1Click:Connect(function()
    clearList(ConsoleList)
    LogCount = 0
    guiLog("🗑 Консоль очищена", Colors.Warning)
end)

BP_CopyCodeBtn.MouseButton1Click:Connect(function()
    if not CurrentButtonInfo then
        guiLog("⚠ Сначала выбери кнопку", Colors.Danger)
        return
    end
    local mainPath = CurrentButtonInfo.PlayerGuiPath or CurrentButtonInfo.CoreGuiPath
    local base = CurrentButtonInfo.PlayerGuiPath and "game.Players.LocalPlayer.PlayerGui." 
        or "game:GetService('CoreGui')."
    local fullPath = base .. mainPath
    guiLog("💻 КОД ДЛЯ ВЫЗОВА КНОПКИ:", Colors.CodeCol)
    guiLog("local btn = " .. fullPath, Colors.CodeCol)
    guiLog("btn.Activated:Fire()", Colors.CodeCol)
    guiLog("-- или", Colors.TextDim)
    guiLog("btn.MouseButton1Click:Fire()", Colors.CodeCol)
    guiLog("-- или", Colors.TextDim)
    guiLog("btn:Activate()", Colors.CodeCol)
    selectTab(2)
end)

BP_TestClickBtn.MouseButton1Click:Connect(function()
    if not CurrentObject or not CurrentObject:IsA("GuiButton") then
        guiLog("⚠ Выбранный объект не кнопка", Colors.Danger)
        return
    end
    guiLog("🧪 Тест клика по: " .. CurrentObject.Name, Colors.Warning)
    local ok, results = testClickButton(CurrentObject)
    if ok then
        for line in results:gmatch("[^\n]+") do
            guiLog("   " .. line, Colors.LogText)
        end
        guiLog("✅ Тест завершён", Colors.Success)
    else
        guiLog("❌ Ошибка: " .. tostring(results), Colors.Danger)
    end
end)

SearchBox:GetPropertyChangedSignal("Text"):Connect(function()
    local query = SearchBox.Text:lower()
    for _, row in ipairs(PropsList:GetChildren()) do
        if row:IsA("Frame") then
            local nameLbl = row:FindFirstChildOfClass("TextLabel")
            if nameLbl then
                local match = query == "" or nameLbl.Text:lower():find(query, 1, true)
                row.Visible = match
            end
        end
    end
end)

-- ═══════════════════════════════════════════════════════
-- 🖱️ RAYCAST
-- ═══════════════════════════════════════════════════════
local function raycastFromScreen(x, y)
    local unitRay = Camera:ViewportPointToRay(x, y)
    local rayParams = RaycastParams.new()
    rayParams.FilterType = Enum.RaycastFilterType.Exclude
    rayParams.FilterDescendantsInstances = {LocalPlayer.Character, MainGui, HighlightGui, EMarkersGui, AimGui}
    rayParams.IgnoreWater = true
    local result = workspace:Raycast(unitRay.Origin, unitRay.Direction * 5000, rayParams)
    if result then
        return result.Instance, result.Position
    end
    return nil, nil
end

local selectConn = UserInputService.InputBegan:Connect(function(input, gpe)
    if gpe then return end
    if not SelectMode then return end

    if input.UserInputType == Enum.UserInputType.MouseButton1
       or input.UserInputType == Enum.UserInputType.Touch then
        local mousePos = UserInputService:GetMouseLocation()
        local guiAtPos = LocalPlayer.PlayerGui:GetGuiObjectsAtPosition(mousePos.X, mousePos.Y)
        for _, obj in pairs(guiAtPos) do
            if obj:IsDescendantOf(MainGui) or obj:IsDescendantOf(EMarkersGui) or obj:IsDescendantOf(AimGui) then return end
        end

        local buttonFound = nil
        for _, obj in pairs(guiAtPos) do
            if obj:IsA("GuiButton") then
                buttonFound = obj
                break
            end
        end

        if buttonFound then
            guiLog("🖱 Клик по GUI-кнопке: " .. buttonFound.Name, Colors.ButtonCol)
            showObject(buttonFound)
            return
        end

        task.wait(0.05)
        local instance, hitPos = raycastFromScreen(mousePos.X, mousePos.Y)
        if instance then
            showObject(instance)
        end
    end
end)

-- ═══════════════════════════════════════════════════════
-- 📑 ВКЛАДКИ
-- ═══════════════════════════════════════════════════════
local Tabs = {
    {Name = "Инспектор", Frame = InspectorTab},
    {Name = "Консоль", Frame = ConsoleTab},
}

function selectTab(index)
    for i, tab in ipairs(Tabs) do
        tab.Frame.Visible = (i == index)
        if tab.Button then
            TweenService:Create(tab.Button, TweenInfo.new(0.15), {
                BackgroundColor3 = (i == index) and Colors.Accent or Colors.BgLighter
            }):Play()
        end
    end
end

for i, tab in ipairs(Tabs) do
    local btn = Instance.new("TextButton")
    btn.Text = tab.Name
    btn.Size = UDim2.new(1/#Tabs, -4, 1, 0)
    btn.Position = UDim2.new((i-1)/#Tabs, 2, 0, 0)
    btn.BackgroundColor3 = Colors.BgLighter
    btn.TextColor3 = Colors.Text
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

MinBtn.MouseButton1Click:Connect(function()
    minimized = not minimized
    if minimized then
        TweenService:Create(MainFrame, TweenInfo.new(0.2), {Size = UDim2.new(0, 560, 0, 42)}):Play()
        TabBar.Visible = false
        ContentFrame.Visible = false
    else
        TweenService:Create(MainFrame, TweenInfo.new(0.2), {Size = originalSize}):Play()
        TabBar.Visible = true
        ContentFrame.Visible = true
    end
end)

CloseBtn.MouseButton1Click:Connect(function()
    MainGui.Enabled = false
    SelectionBox.Visible = false
    hideAim()
    guiLog("🚪 Окно скрыто. Вернуть: getgenv().ObjInf.Show()", Colors.Warning)
end)

-- ═══════════════════════════════════════════════════════
-- 🌐 API
-- ═══════════════════════════════════════════════════════
getgenv().ObjInf = {
    Show = function() MainGui.Enabled = true end,
    Hide = function() MainGui.Enabled = false end,
    Destroy = function()
        if selectConn then selectConn:Disconnect() end
        clearAllEMarkers()
        hideAim()
        pcall(function() SelectionBox:Destroy() end)
        pcall(function() MainGui:Destroy() end)
        pcall(function() EMarkersGui:Destroy() end)
        pcall(function() AimGui:Destroy() end)
        getgenv().OBJ_INF_LOADED = false
    end,
    Inspect = showObject,
    Log = guiLog,
    EToAll = eToAll,
    EToButtons = eToButtons,
    ShowAim = showAim,
    HideAim = hideAim,
    ToggleAim = toggleAim,
    ClearEMarkers = clearAllEMarkers,
    AnalyzeButton = analyzeButton,
    TestClick = testClickButton,
}

getgenv().InspectPart = function(part)
    if part and typeof(part) == "Instance" then
        showObject(part)
    end
end

print("[ObjInf v3.3] ✅ Инспектор загружен!")
print("[ObjInf v3.3] 🎯 E-прицел: кнопка 'E-прицел' в верхней панели")
