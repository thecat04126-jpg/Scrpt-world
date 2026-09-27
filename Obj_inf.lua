--[[
    obj_inf.lua — Инспектор объектов
    Клик по объекту → показ всех свойств
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
    Success   = Color3.fromRGB(0, 200, 100),
    Danger    = Color3.fromRGB(210, 70, 70),
    Warning   = Color3.fromRGB(240, 170, 60),
    Text      = Color3.fromRGB(240, 240, 245),
    TextDim   = Color3.fromRGB(150, 150, 165),
    Border    = Color3.fromRGB(60, 60, 80),
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
-- 📦 ФОРМАТИРОВАНИЕ ЗНАЧЕНИЙ
-- ═══════════════════════════════════════════════════════
local function formatValue(val)
    local t = typeof(val)
    if t == "Vector3" then
        return string.format("Vector3(%.3f, %.3f, %.3f)", val.X, val.Y, val.Z)
    elseif t == "Vector2" then
        return string.format("Vector2(%.3f, %.3f)", val.X, val.Y)
    elseif t == "CFrame" then
        return string.format("CFrame\n  Pos: (%.3f, %.3f, %.3f)\n  Look: (%.3f, %.3f, %.3f)",
            val.Position.X, val.Position.Y, val.Position.Z,
            val.LookVector.X, val.LookVector.Y, val.LookVector.Z)
    elseif t == "Color3" then
        return string.format("Color3(%d, %d, %d)  #%02X%02X%02X",
            math.floor(val.R * 255), math.floor(val.G * 255), math.floor(val.B * 255),
            math.floor(val.R * 255), math.floor(val.G * 255), math.floor(val.B * 255))
    elseif t == "EnumItem" then
        return "Enum." .. tostring(val)
    elseif t == "Instance" then
        if val == nil then return "nil" end
        return val.ClassName .. " [" .. val.Name .. "]"
    elseif t == "table" then
        local count = 0
        for _ in pairs(val) do count = count + 1 end
        return "table (" .. count .. " items)"
    elseif t == "userdata" or t == "function" then
        return tostring(val)
    elseif t == "number" then
        if val == math.floor(val) then return tostring(val) end
        return string.format("%.4f", val)
    else
        return tostring(val)
    end
end

-- ═══════════════════════════════════════════════════════
-- 📋 ИНСПЕКТОР
-- ═══════════════════════════════════════════════════════
local MainGui = Instance.new("ScreenGui")
MainGui.Name = "ObjInspector_UI"
MainGui.ResetOnSpawn = false
MainGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
pcall(function() MainGui.Parent = CoreGui end)
if not MainGui.Parent then MainGui.Parent = LocalPlayer:WaitForChild("PlayerGui") end

-- Главное окно
local MainFrame = Instance.new("Frame")
MainFrame.Size = UDim2.new(0, 520, 0, 600)
MainFrame.Position = UDim2.new(0, 20, 0, 80)
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
TitleLbl.Text = "🔍 ИНСПЕКТОР ОБЪЕКТОВ"
TitleLbl.Size = UDim2.new(1, -120, 1, 0)
TitleLbl.Position = UDim2.new(0, 12, 0, 0)
TitleLbl.BackgroundTransparency = 1
TitleLbl.TextColor3 = Colors.Text
TitleLbl.Font = Enum.Font.GothamBold
TitleLbl.TextSize = 15
TitleLbl.TextXAlignment = Enum.TextXAlignment.Left
TitleLbl.Parent = TitleBar

-- Кнопка свернуть
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

-- Кнопка закрыть
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

-- Панель статуса
local StatusFrame = Instance.new("Frame")
StatusFrame.Size = UDim2.new(1, -24, 0, 60)
StatusFrame.Position = UDim2.new(0, 12, 0, 52)
StatusFrame.BackgroundColor3 = Colors.BgLight
StatusFrame.BorderSizePixel = 0
StatusFrame.Parent = MainFrame
addCorner(StatusFrame, 8)

local StatusTitle = Instance.new("TextLabel")
StatusTitle.Text = "Активный объект:"
StatusTitle.Size = UDim2.new(1, -16, 0, 18)
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

-- Кнопки управления
local BtnBar = Instance.new("Frame")
BtnBar.Size = UDim2.new(1, -24, 0, 34)
BtnBar.Position = UDim2.new(0, 12, 0, 120)
BtnBar.BackgroundTransparency = 1
BtnBar.Parent = MainFrame

local SelectModeBtn = Instance.new("TextButton")
SelectModeBtn.Text = "🎯 РЕЖИМ ВЫБОРА: ВКЛ"
SelectModeBtn.Size = UDim2.new(0.5, -4, 1, 0)
SelectModeBtn.BackgroundColor3 = Colors.Success
SelectModeBtn.TextColor3 = Colors.Text
SelectModeBtn.Font = Enum.Font.GothamBold
SelectModeBtn.TextSize = 12
SelectModeBtn.BorderSizePixel = 0
SelectModeBtn.AutoButtonColor = false
SelectModeBtn.Parent = BtnBar
addCorner(SelectModeBtn, 8)

local CopyBtn = Instance.new("TextButton")
CopyBtn.Text = "📋 Скопировать в консоль"
CopyBtn.Size = UDim2.new(0.5, -4, 1, 0)
CopyBtn.Position = UDim2.new(0.5, 4, 0, 0)
CopyBtn.BackgroundColor3 = Colors.Accent
CopyBtn.TextColor3 = Colors.Text
CopyBtn.Font = Enum.Font.GothamBold
CopyBtn.TextSize = 12
CopyBtn.BorderSizePixel = 0
CopyBtn.AutoButtonColor = false
CopyBtn.Parent = BtnBar
addCorner(CopyBtn, 8)

-- Поиск свойств
local SearchBox = Instance.new("TextBox")
SearchBox.Size = UDim2.new(1, -24, 0, 30)
SearchBox.Position = UDim2.new(0, 12, 0, 162)
SearchBox.BackgroundColor3 = Colors.BgLighter
SearchBox.PlaceholderText = "🔎 Поиск свойства..."
SearchBox.PlaceholderColor3 = Colors.TextDim
SearchBox.Text = ""
SearchBox.TextColor3 = Colors.Text
SearchBox.Font = Enum.Font.Gotham
SearchBox.TextSize = 13
SearchBox.BorderSizePixel = 0
SearchBox.ClearTextOnFocus = false
SearchBox.Parent = MainFrame
addCorner(SearchBox, 6)

-- Список свойств
local PropsList = Instance.new("ScrollingFrame")
PropsList.Size = UDim2.new(1, -24, 1, -230)
PropsList.Position = UDim2.new(0, 12, 0, 200)
PropsList.BackgroundColor3 = Colors.BgLight
PropsList.BorderSizePixel = 0
PropsList.ScrollBarThickness = 6
PropsList.ScrollBarImageColor3 = Colors.Accent
PropsList.CanvasSize = UDim2.new(0, 0, 0, 0)
PropsList.AutomaticCanvasSize = Enum.AutomaticSize.Y
PropsList.Parent = MainFrame
addCorner(PropsList, 8)

local PropsLayout = Instance.new("UIListLayout")
PropsLayout.Padding = UDim.new(0, 4)
PropsLayout.SortOrder = Enum.SortOrder.LayoutOrder
PropsLayout.Parent = PropsList

-- Дочерние объекты
local ChildrenList = Instance.new("ScrollingFrame")
ChildrenList.Size = UDim2.new(1, -24, 1, -230)
ChildrenList.Position = UDim2.new(0, 12, 0, 200)
ChildrenList.BackgroundColor3 = Colors.BgLight
ChildrenList.BorderSizePixel = 0
ChildrenList.ScrollBarThickness = 6
ChildrenList.ScrollBarImageColor3 = Colors.Accent
ChildrenList.CanvasSize = UDim2.new(0, 0, 0, 0)
ChildrenList.AutomaticCanvasSize = Enum.AutomaticSize.Y
ChildrenList.Visible = false
ChildrenList.Parent = MainFrame
addCorner(ChildrenList, 8)

local ChildrenLayout = Instance.new("UIListLayout")
ChildrenLayout.Padding = UDim.new(0, 4)
ChildrenLayout.SortOrder = Enum.SortOrder.LayoutOrder
ChildrenLayout.Parent = ChildrenList

-- Переключатель вкладок внутри списка
local TabSwitch = Instance.new("Frame")
TabSwitch.Size = UDim2.new(1, -24, 0, 30)
TabSwitch.Position = UDim2.new(0, 12, 0, 168)
TabSwitch.BackgroundTransparency = 1
TabSwitch.Visible = false  -- покажем после выбора объекта
TabSwitch.Parent = MainFrame

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

-- ═══════════════════════════════════════════════════════
-- 🎯 ВЫДЕЛЕНИЕ ОБЪЕКТА
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
-- 🖱️ КЛИК ПО МИРУ
-- ═══════════════════════════════════════════════════════
local SelectMode = true
local CurrentObject = nil
local AllProps = {}
local AllChildren = {}

local function clearList(list)
    for _, child in pairs(list:GetChildren()) do
        if child:IsA("Frame") or child:IsA("TextLabel") or child:IsA("TextButton") then
            child:Destroy()
        end
    end
end

local function addPropRow(parent, propName, propValue, isSection)
    local row = Instance.new("Frame")
    row.Size = UDim2.new(1, -8, 0, isSection and 22 or 42)
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
        valLbl.TextColor3 = Colors.Success
        valLbl.Font = Enum.Font.Code
        valLbl.TextSize = 10
        valLbl.TextXAlignment = Enum.TextXAlignment.Left
        valLbl.TextYAlignment = Enum.TextYAlignment.Top
        valLbl.TextWrapped = true
        valLbl.Parent = row
    end

    return row
end

local function showObject(obj)
    CurrentObject = obj
    SelectionBox.Adornee = obj
    SelectionBox.Visible = true

    StatusText.Text = obj.ClassName .. "  ▸  " .. obj.Name
    StatusText.TextColor3 = Colors.Success

    if obj:IsA("BasePart") then
        local p = obj.Position
        StatusPos.Text = string.format("📍 Position: (%.3f, %.3f, %.3f)   Size: (%.2f, %.2f, %.2f)",
            p.X, p.Y, p.Z, obj.Size.X, obj.Size.Y, obj.Size.Z)
    elseif obj:IsA("Model") then
        local pivot = obj:GetPivot().Position
        StatusPos.Text = string.format("📍 Pivot: (%.3f, %.3f, %.3f)", pivot.X, pivot.Y, pivot.Z)
    else
        StatusPos.Text = ""
    end

    -- Заполняем свойства
    clearList(PropsList)
    AllProps = {}

    -- Основные свойства в начале
    addPropRow(PropsList, "🆔 ОСНОВНЫЕ", "", true)
    table.insert(AllProps, {Name = "Name", Value = obj.Name})
    table.insert(AllProps, {Name = "ClassName", Value = obj.ClassName})
    table.insert(AllProps, {Name = "Parent", Value = obj.Parent and obj.Parent.Name or "nil"})

    addPropRow(PropsList, "Name", obj.Name, false)
    addPropRow(PropsList, "ClassName", obj.ClassName, false)
    addPropRow(PropsList, "Parent", obj.Parent and (obj.Parent.ClassName .. " [" .. obj.Parent.Name .. "]") or "nil", false)

    -- Полный путь
    local fullPath = obj:GetFullName()
    addPropRow(PropsList, "FullName", fullPath, false)
    table.insert(AllProps, {Name = "FullName", Value = fullPath})

    -- Позиция для BasePart
    if obj:IsA("BasePart") then
        addPropRow(PropsList, "📍 ПОЗИЦИЯ", "", true)
        local posStr = string.format("Vector3(%.3f, %.3f, %.3f)", obj.Position.X, obj.Position.Y, obj.Position.Z)
        local cfStr = string.format("CFrame(%.3f, %.3f, %.3f)", obj.CFrame.Position.X, obj.CFrame.Position.Y, obj.CFrame.Position.Z)
        local sizeStr = string.format("Vector3(%.2f, %.2f, %.2f)", obj.Size.X, obj.Size.Y, obj.Size.Z)
        addPropRow(PropsList, "Position", posStr, false)
        addPropRow(PropsList, "CFrame", cfStr, false)
        addPropRow(PropsList, "Size", sizeStr, false)
        addPropRow(PropsList, "Rotation", string.format("Vector3(%.1f, %.1f, %.1f)", obj.Orientation.X, obj.Orientation.Y, obj.Orientation.Z), false)
        table.insert(AllProps, {Name = "Position", Value = posStr})
        table.insert(AllProps, {Name = "Size", Value = sizeStr})
        table.insert(AllProps, {Name = "CFrame", Value = cfStr})
    end

    -- Модель
    if obj:IsA("Model") then
        addPropRow(PropsList, "📍 МОДЕЛЬ", "", true)
        local pivot = obj:GetPivot()
        local pivotStr = string.format("Vector3(%.3f, %.3f, %.3f)", pivot.Position.X, pivot.Position.Y, pivot.Position.Z)
        addPropRow(PropsList, "Pivot", pivotStr, false)
        table.insert(AllProps, {Name = "Pivot", Value = pivotStr})

        -- Границы модели
        local ok, size = pcall(function() return obj:GetExtentsSize() end)
        if ok then
            local sizeStr = string.format("Vector3(%.2f, %.2f, %.2f)", size.X, size.Y, size.Z)
            addPropRow(PropsList, "ExtentsSize", sizeStr, false)
            table.insert(AllProps, {Name = "ExtentsSize", Value = sizeStr})
        end
    end

    -- Все остальные свойства
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

    if not success then
        addPropRow(PropsList, "⚠ Ошибка", tostring(err), false)
    end

    -- Дети
    clearList(ChildrenList)
    AllChildren = {}
    for _, child in ipairs(obj:GetChildren()) do
        table.insert(AllChildren, child)
    end

    if #AllChildren == 0 then
        addPropRow(ChildrenList, "Детей нет", "", false)
    else
        for i, child in ipairs(AllChildren) do
            local row = addPropRow(ChildrenList, child.Name, child.ClassName, false)
            row.BackgroundColor3 = Colors.BgLighter
            -- Клик по ребёнку — выбрать его
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
-- 🔍 ПОИСК СВОЙСТВА
-- ═══════════════════════════════════════════════════════
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
-- 🖱️ РЕЖИМ ВЫБОРА (тап по миру)
-- ═══════════════════════════════════════════════════════
local function raycastFromScreen(x, y)
    -- Луч из камеры через точку экрана
    local unitRay = Camera:ViewportPointToRay(x, y)
    local rayParams = RaycastParams.new()
    rayParams.FilterType = Enum.RaycastFilterType.Exclude
    rayParams.FilterDescendantsInstances = {LocalPlayer.Character, MainGui, HighlightGui}
    rayParams.IgnoreWater = true

    local result = workspace:Raycast(unitRay.Origin, unitRay.Direction * 5000, rayParams)
    if result then
        return result.Instance, result.Position
    end
    return nil, nil
end

-- Отслеживание кликов по экрану
local selectConn = UserInputService.InputBegan:Connect(function(input, gpe)
    if gpe then return end
    if not SelectMode then return end

    if input.UserInputType == Enum.UserInputType.MouseButton1
       or input.UserInputType == Enum.UserInputType.Touch then
        -- Проверяем, что клик не попал по нашему UI
        local mousePos = UserInputService:GetMouseLocation()
        local guiAtPos = LocalPlayer.PlayerGui:GetGuiObjectsAtPosition(mousePos.X, mousePos.Y)
        for _, obj in pairs(guiAtPos) do
            if obj:IsDescendantOf(MainGui) then return end
        end

        task.wait(0.05)  -- небольшая задержка, чтобы клик завершился
        local instance, hitPos = raycastFromScreen(mousePos.X, mousePos.Y)
        if instance then
            showObject(instance)
        end
    end
end)

-- ═══════════════════════════════════════════════════════
-- 🎛️ КНОПКИ УПРАВЛЕНИЯ
-- ═══════════════════════════════════════════════════════
SelectModeBtn.MouseButton1Click:Connect(function()
    SelectMode = not SelectMode
    if SelectMode then
        SelectModeBtn.Text = "🎯 РЕЖИМ ВЫБОРА: ВКЛ"
        SelectModeBtn.BackgroundColor3 = Colors.Success
    else
        SelectModeBtn.Text = "🎯 РЕЖИМ ВЫБОРА: ВЫКЛ"
        SelectModeBtn.BackgroundColor3 = Colors.Danger
    end
end)

CopyBtn.MouseButton1Click:Connect(function()
    if not CurrentObject then
        StatusText.Text = "⚠ Сначала выбери объект"
        StatusText.TextColor3 = Colors.Danger
        return
    end
    print("════════════════════════════════════════")
    print("📦 ОБЪЕКТ: " .. CurrentObject:GetFullName())
    print("════════════════════════════════════════")
    for _, p in ipairs(AllProps) do
        print(string.format("%-30s = %s", p.Name, p.Value))
    end
    print("────────────────────────────────────────")
    print("Дети (" .. #AllChildren .. "):")
    for _, child in ipairs(AllChildren) do
        print("  • " .. child.ClassName .. " [" .. child.Name .. "]")
    end
    print("════════════════════════════════════════")

    StatusText.Text = "✓ Скопировано в консоль"
    StatusText.TextColor3 = Colors.Success
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

-- Свернуть
local minimized = false
local originalSize = MainFrame.Size
MinBtn.MouseButton1Click:Connect(function()
    minimized = not minimized
    if minimized then
        TweenService:Create(MainFrame, TweenInfo.new(0.2), {Size = UDim2.new(0, 520, 0, 42)}):Play()
        StatusFrame.Visible = false
        BtnBar.Visible = false
        SearchBox.Visible = false
        PropsList.Visible = false
        ChildrenList.Visible = false
        TabSwitch.Visible = false
    else
        TweenService:Create(MainFrame, TweenInfo.new(0.2), {Size = originalSize}):Play()
        StatusFrame.Visible = true
        BtnBar.Visible = true
        SearchBox.Visible = true
        if CurrentObject then
            PropsList.Visible = PropsTabBtn.BackgroundColor3 == Colors.Accent
            ChildrenList.Visible = ChildrenTabBtn.BackgroundColor3 == Colors.Accent
            TabSwitch.Visible = true
        end
    end
end)

CloseBtn.MouseButton1Click:Connect(function()
    MainGui.Enabled = false
    SelectionBox.Visible = false
end)

-- ═══════════════════════════════════════════════════════
-- 🌐 ПУБЛИЧНОЕ API
-- ═══════════════════════════════════════════════════════
getgenv().ObjInf = {
    Show = function() MainGui.Enabled = true end,
    Hide = function() MainGui.Enabled = false end,
    Destroy = function()
        if selectConn then selectConn:Disconnect() end
        pcall(function() SelectionBox:Destroy() end)
        pcall(function() MainGui:Destroy() end)
        getgenv().OBJ_INF_LOADED = false
    end,
    Inspect = showObject,
}

-- Программный вызов
getgenv().InspectPart = function(part)
    if part and typeof(part) == "Instance" then
        showObject(part)
    end
end

print("[ObjInf] ✅ Инспектор загружен!")
print("[ObjInf] Клик по объекту в мире → показ свойств")
print("[ObjInf] Скрыть: getgenv().ObjInf.Hide()")
print("[ObjInf] Показать: getgenv().ObjInf.Show()")
print("[ObjInf] Программно: getgenv().InspectPart(game.Workspace.Part)")
