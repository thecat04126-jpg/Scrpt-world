--[[
    PLAYERS ESP — версия для Delta Executor
    Работает через BillboardGui (без Drawing API)
--]]

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local Camera = workspace.CurrentCamera
local LocalPlayer = Players.LocalPlayer

-- ⚙️ НАСТРОЙКИ
local Settings = {
    Enabled = true,
    ShowName = true,
    ShowHealth = true,
    ShowDistance = true,
    TeamCheck = false,        -- не показывать союзников
    MaxDistance = 1000,       -- макс. дистанция
    NameColor = Color3.fromRGB(255, 255, 255),
    HealthColor = Color3.fromRGB(0, 255, 0),
    TextSize = 14,
    HeadOffset = 3,           -- высота над головой
}

local ESPCache = {}

-- 🎨 Создание ESP для игрока
local function createESP(player)
    if player == LocalPlayer then return end
    
    local esp = {}
    
    -- 📛 Основной Billboard (имя + дистанция)
    local billboard = Instance.new("BillboardGui")
    billboard.Name = "ESP_Billboard"
    billboard.AlwaysOnTop = true
    billboard.Size = UDim2.new(0, 200, 0, 50)
    billboard.StudsOffset = Vector3.new(0, Settings.HeadOffset, 0)
    billboard.Enabled = false
    billboard.Parent = game:GetService("CoreGui") -- не мешает игре
    
    -- Имя
    local nameLabel = Instance.new("TextLabel")
    nameLabel.Name = "NameLabel"
    nameLabel.BackgroundTransparency = 1
    nameLabel.Size = UDim2.new(1, 0, 0.5, 0)
    nameLabel.Font = Enum.Font.SourceSansBold
    nameLabel.TextSize = Settings.TextSize
    nameLabel.TextColor3 = Settings.NameColor
    nameLabel.TextStrokeTransparency = 0
    nameLabel.TextStrokeColor3 = Color3.fromRGB(0, 0, 0)
    nameLabel.Parent = billboard
    
    -- Дистанция
    local distLabel = Instance.new("TextLabel")
    distLabel.Name = "DistLabel"
    distLabel.BackgroundTransparency = 1
    distLabel.Size = UDim2.new(1, 0, 0.5, 0)
    distLabel.Position = UDim2.new(0, 0, 0.5, 0)
    distLabel.Font = Enum.Font.SourceSans
    distLabel.TextSize = Settings.TextSize - 2
    distLabel.TextColor3 = Color3.fromRGB(200, 200, 200)
    distLabel.TextStrokeTransparency = 0
    distLabel.TextStrokeColor3 = Color3.fromRGB(0, 0, 0)
    distLabel.Parent = billboard
    
    esp.Billboard = billboard
    esp.NameLabel = nameLabel
    esp.DistLabel = distLabel
    
    -- ❤️ Полоса здоровья (слева от ника)
    local healthBg = Instance.new("Frame")
    healthBg.Name = "HealthBg"
    healthBg.BackgroundColor3 = Color3.fromRGB(60, 60, 60)
    healthBg.BorderSizePixel = 0
    healthBg.Size = UDim2.new(0, 4, 1, 0)
    healthBg.Position = UDim2.new(-0.05, 0, 0, 0)
    healthBg.Parent = billboard
    
    local healthFill = Instance.new("Frame")
    healthFill.Name = "HealthFill"
    healthFill.BackgroundColor3 = Settings.HealthColor
    healthFill.BorderSizePixel = 0
    healthFill.Size = UDim2.new(1, 0, 1, 0)
    healthFill.AnchorPoint = Vector2.new(0, 1)
    healthFill.Position = UDim2.new(0, 0, 1, 0)
    healthFill.Parent = healthBg
    
    esp.HealthBg = healthBg
    esp.HealthFill = healthFill
    
    ESPCache[player] = esp
end

-- ❌ Удаление ESP
local function removeESP(player)
    local esp = ESPCache[player]
    if not esp then return end
    if esp.Billboard then
        esp.Billboard:Destroy()
    end
    ESPCache[player] = nil
end

-- 🔄 Основной цикл
RunService.RenderStepped:Connect(function()
    if not Settings.Enabled then
        for _, esp in pairs(ESPCache) do
            if esp.Billboard then esp.Billboard.Enabled = false end
        end
        return
    end
    
    for player, esp in pairs(ESPCache) do
        local character = player.Character
        local hrp = character and character:FindFirstChild("HumanoidRootPart")
        local head = character and character:FindFirstChild("Head")
        local humanoid = character and character:FindFirstChildOfClass("Humanoid")
        
        -- Проверки
        if not hrp or not head or not humanoid or humanoid.Health <= 0 then
            esp.Billboard.Enabled = false
            continue
        end
        
        if Settings.TeamCheck and player.Team == LocalPlayer.Team then
            esp.Billboard.Enabled = false
            continue
        end
        
        local distance = (Camera.CFrame.Position - hrp.Position).Magnitude
        if distance > Settings.MaxDistance then
            esp.Billboard.Enabled = false
            continue
        end
        
        -- Привязка и включение
        esp.Billboard.Adornee = head
        esp.Billboard.Enabled = true
        
        -- Имя и дистанция
        esp.NameLabel.Text = player.Name
        esp.NameLabel.Visible = Settings.ShowName
        esp.DistLabel.Text = string.format("[%d m]", distance)
        esp.DistLabel.Visible = Settings.ShowDistance
        
        -- Здоровье
        local hp = humanoid.Health / humanoid.MaxHealth
        esp.HealthFill.Size = UDim2.new(1, 0, hp, 0)
        esp.HealthFill.BackgroundColor3 = Color3.fromRGB(
            255 * (1 - hp),
            255 * hp,
            0
        )
        esp.HealthBg.Visible = Settings.ShowHealth
    end
end)

-- 🎧 События
Players.PlayerAdded:Connect(createESP)
Players.PlayerRemoving:Connect(removeESP)

-- Инициализация для уже зашедших игроков
for _, player in pairs(Players:GetPlayers()) do
    createESP(player)
end

-- 🔧 Управление из консоли
getgenv().ESP = {
    Settings = Settings,
    
    Toggle = function()
        Settings.Enabled = not Settings.Enabled
        print("[ESP] Включён:", Settings.Enabled)
    end,
    
    SetDistance = function(dist)
        Settings.MaxDistance = dist
        print("[ESP] Дистанция:", dist)
    end,
    
    Destroy = function()
        for player, _ in pairs(ESPCache) do
            removeESP(player)
        end
        print("[ESP] Удалён")
    end,
}

print("[ESP] Загружен для Delta! Управление: getgenv().ESP.Toggle()")
