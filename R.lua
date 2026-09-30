-- RoundAbout v3 — Delta Executor Edition
-- Перехватывает телепорты в под-плейсы (Doors и подобные)

local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local HttpService = game:GetService("HttpService")
local TeleportService = game:GetService("TeleportService")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

local old = playerGui:FindFirstChild("RoundAboutGui")
if old then old:Destroy() end

local SAVE_FILE = "RoundAbout_Delta_v3.json"

-- ============ Хранилище ============
local function loadSaves()
    if isfile and isfile(SAVE_FILE) then
        local ok, data = pcall(function()
            return HttpService:JSONDecode(readfile(SAVE_FILE))
        end)
        if ok and type(data) == "table" then return data end
    end
    return {}
end

local function saveSaves(saves)
    if writefile then
        pcall(function()
            writefile(SAVE_FILE, HttpService:JSONEncode(saves))
        end)
    end
end

local saves = loadSaves()

-- ============ Информация о текущем месте ============
local function getCurrentPlaceInfo()
    return {
        placeId = game.PlaceId,
        gameId = game.GameId,
        jobId = game.JobId,
        teleportData = _G.RoundAbout_LastTeleportData or nil,
    }
end

-- ============ Перехват телепортов (Delta) ============
-- Delta имеет getrawmetatable и newcclosure — используем namecall hook
local lastTeleport = {
    placeId = nil,
    jobId = nil,
    teleportData = nil,
    timestamp = 0,
}

local hookActive = false

local function installTeleportHook()
    if hookActive then return end

    local success, err = pcall(function()
        local mt = getrawmetatable(game)
        if not mt then
            error("getrawmetatable недоступен")
        end

        local oldNamecall = mt.__namecall
        setreadonly(mt, false)

        mt.__namecall = newcclosure(function(self, ...)
            local method = getnamecallmethod()

            if self == TeleportService and (method == "Teleport" or method == "TeleportToPlaceInstance" or method == "TeleportAsync") then
                local args = {...}

                if method == "TeleportAsync" then
                    -- Сигнатура: TeleportAsync(placeId, playersTable, options)
                    local pId = args[1]
                    local tOpts = args[3]
                    local tData = nil

                    if tOpts and typeof(tOpts) == "Instance" then
                        pcall(function()
                            tData = tOpts:GetTeleportData()
                        end)
                    end

                    lastTeleport.placeId = pId or lastTeleport.placeId
                    lastTeleport.jobId = nil -- Async может не иметь JobId
                    lastTeleport.teleportData = tData
                    lastTeleport.timestamp = os.time()

                    print("[RoundAbout] Перехвачен TeleportAsync → PlaceId:", pId)

                elseif method == "TeleportToPlaceInstance" then
                    -- Сигнатура: TeleportToPlaceInstance(placeId, jobId, player, options)
                    local pId = args[1]
                    local jId = args[2]
                    local tOpts = args[4]
                    local tData = nil

                    if tOpts and typeof(tOpts) == "Instance" then
                        pcall(function()
                            tData = tOpts:GetTeleportData()
                        end)
                    end

                    lastTeleport.placeId = pId or lastTeleport.placeId
                    lastTeleport.jobId = jId
                    lastTeleport.teleportData = tData
                    lastTeleport.timestamp = os.time()

                    print("[RoundAbout] Перехвачен TeleportToPlaceInstance → PlaceId:", pId, "JobId:", jId)

                elseif method == "Teleport" then
                    -- Сигнатура: Teleport(placeId, player, teleportData, customLoadingScreen)
                    local pId = args[1]
                    local tData = args[3]
                    if type(tData) ~= "table" then tData = nil end

                    lastTeleport.placeId = pId or lastTeleport.placeId
                    lastTeleport.jobId = nil
                    lastTeleport.teleportData = tData
                    lastTeleport.timestamp = os.time()

                    print("[RoundAbout] Перехвачен Teleport → PlaceId:", pId)
                end

                -- Сохраняем в глобал для getCurrentPlaceInfo
                _G.RoundAbout_LastTeleportData = lastTeleport.teleportData
            end

            return oldNamecall(self, ...)
        end)

        setreadonly(mt, true)
        hookActive = true
        print("[RoundAbout] Хук на TeleportService установлен")
    end)

    if not success then
        warn("[RoundAbout] Не удалось установить хук:", err)
    end
end

installTeleportHook()

-- ============ GUI ============
local screenGui = Instance.new("ScreenGui")
screenGui.Name = "RoundAboutGui"
screenGui.ResetOnSpawn = false
screenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
screenGui.Parent = playerGui

-- Кнопка
local mainButton = Instance.new("TextButton")
mainButton.Size = UDim2.new(0, 60, 0, 60)
mainButton.Position = UDim2.new(0, 100, 0, 100)
mainButton.BackgroundColor3 = Color3.fromRGB(35, 35, 45)
mainButton.BorderSizePixel = 0
mainButton.Text = "RA"
mainButton.TextColor3 = Color3.fromRGB(0, 200, 255)
mainButton.TextSize = 22
mainButton.Font = Enum.Font.GothamBold
mainButton.AutoButtonColor = false
mainButton.Active = true
mainButton.Parent = screenGui

local corner = Instance.new("UICorner")
corner.CornerRadius = UDim.new(1, 0)
corner.Parent = mainButton

local stroke = Instance.new("UIStroke")
stroke.Color = Color3.fromRGB(0, 200, 255)
stroke.Thickness = 2
stroke.Parent = mainButton

-- Меню
local menu = Instance.new("Frame")
menu.Size = UDim2.new(0, 340, 0, 460)
menu.Position = UDim2.new(0.5, -170, 0.5, -230)
menu.BackgroundColor3 = Color3.fromRGB(25, 25, 33)
menu.BorderSizePixel = 0
menu.Visible = false
menu.Active = true
menu.Draggable = true
menu.Parent = screenGui

local menuCorner = Instance.new("UICorner")
menuCorner.CornerRadius = UDim.new(0, 12)
menuCorner.Parent = menu

local menuStroke = Instance.new("UIStroke")
menuStroke.Color = Color3.fromRGB(0, 200, 255)
menuStroke.Thickness = 2
menuStroke.Parent = menu

local title = Instance.new("TextLabel")
title.Size = UDim2.new(1, 0, 0, 40)
title.BackgroundTransparency = 1
title.Text = "RoundAbout • Delta"
title.TextColor3 = Color3.fromRGB(0, 200, 255)
title.TextSize = 20
title.Font = Enum.Font.GothamBold
title.Parent = menu

local closeBtn = Instance.new("TextButton")
closeBtn.Size = UDim2.new(0, 30, 0, 30)
closeBtn.Position = UDim2.new(1, -35, 0, 5)
closeBtn.BackgroundColor3 = Color3.fromRGB(200, 50, 50)
closeBtn.Text = "X"
closeBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
closeBtn.TextSize = 16
closeBtn.Font = Enum.Font.GothamBold
closeBtn.BorderSizePixel = 0
closeBtn.Parent = menu
local cc = Instance.new("UICorner")
cc.CornerRadius = UDim.new(1, 0)
cc.Parent = closeBtn

-- Вкладки
local tabsFrame = Instance.new("Frame")
tabsFrame.Size = UDim2.new(1, -20, 0, 35)
tabsFrame.Position = UDim2.new(0, 10, 0, 45)
tabsFrame.BackgroundTransparency = 1
tabsFrame.Parent = menu

local saveTab = Instance.new("TextButton")
saveTab.Size = UDim2.new(0.5, -5, 1, 0)
saveTab.BackgroundColor3 = Color3.fromRGB(0, 200, 255)
saveTab.Text = "Запомнить"
saveTab.TextColor3 = Color3.fromRGB(0, 0, 0)
saveTab.TextSize = 14
saveTab.Font = Enum.Font.GothamBold
saveTab.BorderSizePixel = 0
saveTab.Parent = tabsFrame
local stc = Instance.new("UICorner")
stc.CornerRadius = UDim.new(0, 6)
stc.Parent = saveTab

local reboundTab = Instance.new("TextButton")
reboundTab.Size = UDim2.new(0.5, -5, 1, 0)
reboundTab.Position = UDim2.new(0.5, 5, 0, 0)
reboundTab.BackgroundColor3 = Color3.fromRGB(45, 45, 60)
reboundTab.Text = "Rebound"
reboundTab.TextColor3 = Color3.fromRGB(255, 255, 255)
reboundTab.TextSize = 14
reboundTab.Font = Enum.Font.GothamBold
reboundTab.BorderSizePixel = 0
reboundTab.Parent = tabsFrame
local rtc = Instance.new("UICorner")
rtc.CornerRadius = UDim.new(0, 6)
rtc.Parent = reboundTab

-- ============ Страница "Запомнить" ============
local savePage = Instance.new("Frame")
savePage.Size = UDim2.new(1, -20, 1, -95)
savePage.Position = UDim2.new(0, 10, 0, 85)
savePage.BackgroundTransparency = 1
savePage.Parent = menu

local function makeLabel(text, y)
    local lbl = Instance.new("TextLabel")
    lbl.Size = UDim2.new(1, 0, 0, 20)
    lbl.Position = UDim2.new(0, 0, 0, y)
    lbl.BackgroundTransparency = 1
    lbl.Text = text
    lbl.TextColor3 = Color3.fromRGB(200, 200, 200)
    lbl.TextSize = 13
    lbl.Font = Enum.Font.Gotham
    lbl.TextXAlignment = Enum.TextXAlignment.Left
    lbl.Parent = savePage
    return lbl
end

makeLabel("Имя локации:", 0)

local nameBox = Instance.new("TextBox")
nameBox.Size = UDim2.new(1, 0, 0, 32)
nameBox.Position = UDim2.new(0, 0, 0, 22)
nameBox.BackgroundColor3 = Color3.fromRGB(40, 40, 55)
nameBox.TextColor3 = Color3.fromRGB(255, 255, 255)
nameBox.PlaceholderText = "Например: Лифт этаж 50"
nameBox.Text = ""
nameBox.TextSize = 14
nameBox.Font = Enum.Font.Gotham
nameBox.BorderSizePixel = 0
nameBox.Parent = savePage
local nbc = Instance.new("UICorner")
nbc.CornerRadius = UDim.new(0, 6)
nbc.Parent = nameBox

-- Инфо-панель
local infoFrame = Instance.new("Frame")
infoFrame.Size = UDim2.new(1, 0, 0, 100)
infoFrame.Position = UDim2.new(0, 0, 0, 65)
infoFrame.BackgroundColor3 = Color3.fromRGB(35, 35, 48)
infoFrame.BorderSizePixel = 0
infoFrame.Parent = savePage
local ifc = Instance.new("UICorner")
ifc.CornerRadius = UDim.new(0, 6)
ifc.Parent = infoFrame

local infoLabel = Instance.new("TextLabel")
infoLabel.Size = UDim2.new(1, -10, 1, -10)
infoLabel.Position = UDim2.new(0, 5, 0, 5)
infoLabel.BackgroundTransparency = 1
infoLabel.TextColor3 = Color3.fromRGB(180, 220, 255)
infoLabel.TextSize = 12
infoLabel.Font = Enum.Font.Code
infoLabel.TextXAlignment = Enum.TextXAlignment.Left
infoLabel.TextYAlignment = Enum.TextYAlignment.Top
infoLabel.TextWrapped = true
infoLabel.Parent = infoFrame

local function updateInfo()
    local cur = getCurrentPlaceInfo()
    local lines = {
        "PlaceId:  " .. tostring(cur.placeId),
        "GameId:   " .. tostring(cur.gameId),
        "JobId:    " .. (cur.jobId ~= "" and cur.jobId:sub(1, 16) .. "..." or "(нет)"),
    }
    if lastTeleport.placeId and os.time() - lastTeleport.timestamp < 120 then
        table.insert(lines, "📡 Перехвачен: " .. tostring(lastTeleport.placeId))
        if lastTeleport.teleportData then
            table.insert(lines, "📦 TeleportData: есть")
        end
    end
    infoLabel.Text = table.concat(lines, "\n")
end

updateInfo()
task.spawn(function()
    while task.wait(2) do updateInfo() end
end)

-- Кнопка сохранения
local saveBtn = Instance.new("TextButton")
saveBtn.Size = UDim2.new(1, 0, 0, 40)
saveBtn.Position = UDim2.new(0, 0, 0, 175)
saveBtn.BackgroundColor3 = Color3.fromRGB(0, 200, 255)
saveBtn.Text = "💾 Сохранить локацию"
saveBtn.TextColor3 = Color3.fromRGB(0, 0, 0)
saveBtn.TextSize = 15
saveBtn.Font = Enum.Font.GothamBold
saveBtn.BorderSizePixel = 0
saveBtn.Parent = savePage
local sbc = Instance.new("UICorner")
sbc.CornerRadius = UDim.new(0, 6)
sbc.Parent = saveBtn

-- Кнопка "Запомнить следующий телепорт"
local armBtn = Instance.new("TextButton")
armBtn.Size = UDim2.new(1, 0, 0, 36)
armBtn.Position = UDim2.new(0, 0, 0, 225)
armBtn.BackgroundColor3 = Color3.fromRGB(255, 180, 0)
armBtn.Text = "🎯 Запомнить следующий телепорт"
armBtn.TextColor3 = Color3.fromRGB(0, 0, 0)
armBtn.TextSize = 13
armBtn.Font = Enum.Font.GothamBold
armBtn.BorderSizePixel = 0
armBtn.Parent = savePage
local abc = Instance.new("UICorner")
abc.CornerRadius = UDim.new(0, 6)
abc.Parent = armBtn

local armed = false

local statusLabel = Instance.new("TextLabel")
statusLabel.Size = UDim2.new(1, 0, 0, 20)
statusLabel.Position = UDim2.new(0, 0, 0, 270)
statusLabel.BackgroundTransparency = 1
statusLabel.Text = ""
statusLabel.TextColor3 = Color3.fromRGB(0, 255, 100)
statusLabel.TextSize = 12
statusLabel.Font = Enum.Font.Gotham
statusLabel.TextWrapped = true
statusLabel.Parent = savePage

-- ============ Страница "Rebound" ============
local reboundPage = Instance.new("Frame")
reboundPage.Size = UDim2.new(1, -20, 1, -95)
reboundPage.Position = UDim2.new(0, 10, 0, 85)
reboundPage.BackgroundTransparency = 1
reboundPage.Visible = false
reboundPage.Parent = menu

local scroll = Instance.new("ScrollingFrame")
scroll.Size = UDim2.new(1, 0, 1, 0)
scroll.BackgroundTransparency = 1
scroll.BorderSizePixel = 0
scroll.ScrollBarThickness = 4
scroll.ScrollBarImageColor3 = Color3.fromRGB(0, 200, 255)
scroll.CanvasSize = UDim2.new(0, 0, 0, 0)
scroll.AutomaticCanvasSize = Enum.AutomaticSize.Y
scroll.Parent = reboundPage

local listLayout = Instance.new("UIListLayout")
listLayout.Padding = UDim.new(0, 8)
listLayout.SortOrder = Enum.SortOrder.LayoutOrder
listLayout.Parent = scroll

-- ============ Телепорт (Delta-версия) ============
local function doTeleport(data, name)
    local curPlace = game.PlaceId

    -- 1) Уже в нужном place — двигаем персонажа
    if data.placeId == curPlace then
        local char = player.Character
        local hrp = char and char:FindFirstChild("HumanoidRootPart")
        if hrp and data.pos then
            hrp.CFrame = CFrame.new(data.pos.x, data.pos.y + 3, data.pos.z)
            return true, "✅ Возвращён в: " .. name
        end
        return false, "❌ Персонаж не найден"
    end

    -- 2) Создаём TeleportOptions (Delta поддерживает Instance.new)
    local teleportOptions = Instance.new("TeleportOptions")

    if data.jobId and data.jobId ~= "" then
        pcall(function()
            teleportOptions.ServerInstanceId = data.jobId
        end)
    end

    if data.teleportData then
        pcall(function()
            teleportOptions:SetTeleportData(data.teleportData)
        end)
    end

    -- 3) TeleportToPlaceInstance (работает на клиенте в Delta)
    local success, err = pcall(function()
        if data.jobId and data.jobId ~= "" then
            TeleportService:TeleportToPlaceInstance(data.placeId, data.jobId, player, teleportOptions)
        else
            TeleportService:Teleport(data.placeId, player, data.teleportData, nil)
        end
    end)

    if success then
        return true, "⏳ Телепорт в " .. name .. "..."
    end

    -- 4) Fallback: TeleportAsync (Delta позволяет клиентский вызов)
    if data.placeId then
        local ok2 = pcall(function()
            TeleportService:TeleportAsync(data.placeId, {player}, teleportOptions)
        end)
        if ok2 then
            return true, "⏳ Телепорт (Async) в " .. name
        end
    end

    return false, "❌ Ошибка телепорта: " .. tostring(err)
end

-- ============ Список сохранений ============
local function refreshList()
    for _, child in ipairs(scroll:GetChildren()) do
        if child:IsA("Frame") then child:Destroy() end
    end

    local count = 0
    for name, data in pairs(saves) do
        count += 1

        local card = Instance.new("Frame")
        card.Size = UDim2.new(1, -5, 0, 95)
        card.BackgroundColor3 = Color3.fromRGB(40, 40, 55)
        card.BorderSizePixel = 0
        card.Parent = scroll
        local c = Instance.new("UICorner")
        c.CornerRadius = UDim.new(0, 8)
        c.Parent = card

        local nameLbl = Instance.new("TextLabel")
        nameLbl.Size = UDim2.new(1, -10, 0, 22)
        nameLbl.Position = UDim2.new(0, 5, 0, 5)
        nameLbl.BackgroundTransparency = 1
        nameLbl.Text = name
        nameLbl.TextColor3 = Color3.fromRGB(255, 255, 255)
        nameLbl.TextSize = 15
        nameLbl.Font = Enum.Font.GothamBold
        nameLbl.TextXAlignment = Enum.TextXAlignment.Left
        nameLbl.Parent = card

        local hasData = data.teleportData and "📦" or ""
        local infoLbl = Instance.new("TextLabel")
        infoLbl.Size = UDim2.new(1, -10, 0, 45)
        infoLbl.Position = UDim2.new(0, 5, 0, 27)
        infoLbl.BackgroundTransparency = 1
        infoLbl.Text = string.format(
            "PlaceId: %s %s\nGameId: %s\nJobId: %s",
            tostring(data.placeId),
            hasData,
            tostring(data.gameId or "?"),
            (data.jobId and data.jobId ~= "") and data.jobId:sub(1, 14) .. "..." or "(нет)"
        )
        infoLbl.TextColor3 = Color3.fromRGB(150, 150, 150)
        infoLbl.TextSize = 10
        infoLbl.Font = Enum.Font.Code
        infoLbl.TextXAlignment = Enum.TextXAlignment.Left
        infoLbl.TextYAlignment = Enum.TextYAlignment.Top
        infoLbl.TextWrapped = true
        infoLbl.Parent = card

        local tpBtn = Instance.new("TextButton")
        tpBtn.Size = UDim2.new(0, 90, 0, 24)
        tpBtn.Position = UDim2.new(1, -100, 0, 68)
        tpBtn.BackgroundColor3 = Color3.fromRGB(0, 200, 255)
        tpBtn.Text = "Rebound"
        tpBtn.TextColor3 = Color3.fromRGB(0, 0, 0)
        tpBtn.TextSize = 12
        tpBtn.Font = Enum.Font.GothamBold
        tpBtn.BorderSizePixel = 0
        tpBtn.Parent = card
        local tc = Instance.new("UICorner")
        tc.CornerRadius = UDim.new(0, 6)
        tc.Parent = tpBtn

        local delBtn = Instance.new("TextButton")
        delBtn.Size = UDim2.new(0, 30, 0, 24)
        delBtn.Position = UDim2.new(1, -135, 0, 68)
        delBtn.BackgroundColor3 = Color3.fromRGB(180, 50, 50)
        delBtn.Text = "🗑"
        delBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
        delBtn.TextSize = 12
        delBtn.Font = Enum.Font.GothamBold
        delBtn.BorderSizePixel = 0
        delBtn.Parent = card
        local dc = Instance.new("UICorner")
        dc.CornerRadius = UDim.new(0, 6)
        dc.Parent = delBtn

        tpBtn.MouseButton1Click:Connect(function()
            local ok, msg = doTeleport(data, name)
            statusLabel.Text = msg
            statusLabel.TextColor3 = ok and Color3.fromRGB(0, 255, 100) or Color3.fromRGB(255, 80, 80)
        end)

        delBtn.MouseButton1Click:Connect(function()
            saves[name] = nil
            saveSaves(saves)
            refreshList()
        end)
    end

    if count == 0 then
        local empty = Instance.new("TextLabel")
        empty.Size = UDim2.new(1, 0, 0, 40)
        empty.BackgroundTransparency = 1
        empty.Text = "Нет сохранённых локаций"
        empty.TextColor3 = Color3.fromRGB(120, 120, 120)
        empty.TextSize = 13
        empty.Font = Enum.Font.Gotham
        empty.Parent = scroll
    end
end

-- ============ Сохранение ============
saveBtn.MouseButton1Click:Connect(function()
    local name = nameBox.Text
    if name == "" then
        statusLabel.Text = "❌ Введите имя"
        statusLabel.TextColor3 = Color3.fromRGB(255, 80, 80)
        return
    end

    local char = player.Character
    local hrp = char and char:FindFirstChild("HumanoidRootPart")
    if not hrp then
        statusLabel.Text = "❌ Персонаж не найден"
        statusLabel.TextColor3 = Color3.fromRGB(255, 80, 80)
        return
    end

    local cur = getCurrentPlaceInfo()
    saves[name] = {
        placeId = cur.placeId,
        gameId = cur.gameId,
        jobId = cur.jobId,
        pos = { x = hrp.Position.X, y = hrp.Position.Y, z = hrp.Position.Z },
        teleportData = lastTeleport.teleportData,
        savedAt = os.time(),
    }
    saveSaves(saves)

    statusLabel.Text = "✅ Сохранено: " .. name
    statusLabel.TextColor3 = Color3.fromRGB(0, 255, 100)
    nameBox.Text = ""
    refreshList()
end)

-- ============ Режим "Запомнить следующий телепорт" ============
armBtn.MouseButton1Click:Connect(function()
    armed = not armed
    if armed then
        armBtn.BackgroundColor3 = Color3.fromRGB(0, 220, 100)
        armBtn.Text = "🎯 ОЖИДАНИЕ ТЕЛЕПОРТА..."
        statusLabel.Text = "Зайди в лифт / сделай действие для телепорта"
        statusLabel.TextColor3 = Color3.fromRGB(255, 200, 0)
        lastTeleport.timestamp = 0
    else
        armBtn.BackgroundColor3 = Color3.fromRGB(255, 180, 0)
        armBtn.Text = "🎯 Запомнить следующий телепорт"
    end
end)

-- Отслеживание перехвата
task.spawn(function()
    while task.wait(0.5) do
        if armed and lastTeleport.placeId and lastTeleport.timestamp > 0 then
            armed = false
            armBtn.BackgroundColor3 = Color3.fromRGB(255, 180, 0)
            armBtn.Text = "🎯 Запомнить следующий телепорт"

            local name = nameBox.Text ~= "" and nameBox.Text or ("Под-плейс " .. tostring(lastTeleport.placeId))

            saves[name] = {
                placeId = lastTeleport.placeId,
                gameId = game.GameId,
                jobId = lastTeleport.jobId,
                pos = nil,
                teleportData = lastTeleport.teleportData,
                savedAt = os.time(),
            }
            saveSaves(saves)

            statusLabel.Text = "✅ Захвачен под-плейс: " .. name
            statusLabel.TextColor3 = Color3.fromRGB(0, 255, 100)
            nameBox.Text = ""
            refreshList()
        end
    end
end)

-- ============ Вкладки ============
saveTab.MouseButton1Click:Connect(function()
    savePage.Visible = true
    reboundPage.Visible = false
    saveTab.BackgroundColor3 = Color3.fromRGB(0, 200, 255)
    saveTab.TextColor3 = Color3.fromRGB(0, 0, 0)
    reboundTab.BackgroundColor3 = Color3.fromRGB(45, 45, 60)
    reboundTab.TextColor3 = Color3.fromRGB(255, 255, 255)
end)

reboundTab.MouseButton1Click:Connect(function()
    savePage.Visible = false
    reboundPage.Visible = true
    reboundTab.BackgroundColor3 = Color3.fromRGB(0, 200, 255)
    reboundTab.TextColor3 = Color3.fromRGB(0, 0, 0)
    saveTab.BackgroundColor3 = Color3.fromRGB(45, 45, 60)
    saveTab.TextColor3 = Color3.fromRGB(255, 255, 255)
    refreshList()
end)

-- ============ Управление меню ============
local function toggleMenu()
    menu.Visible = not menu.Visible
    if menu.Visible then refreshList() end
end

closeBtn.MouseButton1Click:Connect(function()
    menu.Visible = false
end)

-- Перетаскивание кнопки
local dragging, dragStart, startPos = false, nil, nil

mainButton.InputBegan:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1
        or input.UserInputType == Enum.UserInputType.Touch then
        dragging = true
        dragStart = input.Position
        startPos = mainButton.Position
    end
end)

mainButton.InputEnded:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1
        or input.UserInputType == Enum.UserInputType.Touch then
        dragging = false
    end
end)

UserInputService.InputChanged:Connect(function(input)
    if not dragging then return end
    if input.UserInputType ~= Enum.UserInputType.MouseMovement
        and input.UserInputType ~= Enum.UserInputType.Touch then return end
    local delta = input.Position - dragStart
    mainButton.Position = UDim2.new(
        startPos.X.Scale, startPos.X.Offset + delta.X,
        startPos.Y.Scale, startPos.Y.Offset + delta.Y
    )
end)

local pressPos
mainButton.MouseButton1Down:Connect(function()
    pressPos = UserInputService:GetMouseLocation()
end)

mainButton.MouseButton1Up:Connect(function()
    local pos = UserInputService:GetMouseLocation()
    if pressPos and (pos - pressPos).Magnitude < 5 then
        toggleMenu()
    end
end)

UserInputService.InputBegan:Connect(function(input, gp)
    if gp then return end
    if input.KeyCode == Enum.KeyCode.R then
        toggleMenu()
    end
end)

refreshList()
print("[RoundAbout v3 Delta] Загружен. Нажми R или кликни по кнопке.")
