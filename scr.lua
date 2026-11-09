-- ==========================================
-- IROSHIDA v2.6 (Final Stable Build)
-- Script made by Nick9l
-- ==========================================

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")
local Lighting = game:GetService("Lighting")
local CoreGui = game:GetService("CoreGui")
local LocalPlayer = Players.LocalPlayer
local VirtualUser = game:GetService("VirtualUser")

-- ==========================================
-- 1. ЗАГРУЗОЧНЫЙ ЭКРАН
-- ==========================================
local Splash = Instance.new("ScreenGui")
Splash.Parent = CoreGui
Splash.IgnoreGuiInset = true

local SplashText = Instance.new("TextLabel")
SplashText.Parent = Splash
SplashText.Size = UDim2.new(1, 0, 1, 0)
SplashText.BackgroundColor3 = Color3.fromRGB(15, 15, 15)
SplashText.Text = "Привет."
SplashText.TextColor3 = Color3.fromRGB(255, 255, 255)
SplashText.Font = Enum.Font.SourceSansBold
SplashText.TextSize = 40

task.wait(1.5)
SplashText.Text = "Загрузка..."
task.wait(1)
SplashText.Text = "Iroshida | made by Nick9l"
task.wait(1.5)
Splash:Destroy()

-- ==========================================
-- 2. НАСТРОЙКИ
-- ==========================================
local Settings = {
    FarmEnabled = false,
    CoinLimit = 50,
    FlySpeed = 50,
    Cooldown = 0.1,
    FarmMode = "Быстрый",
    
    AutoShoot = true,
    AutoGun = true,
    KillAll = true,
    Magnet = false,
    FarmExp = true,
    InnocentTimeout = 35,
    
    Noclip = true,
    RamMode = "Off",
    RamInterval = 30
}

local currentCoins = 0
local isInfection = false
local myRole = "Innocent" 
local collectedCoins = {}

-- ==========================================
-- 3. ЗАГРУЗКА UI (LINORIA)
-- ==========================================
local repo = 'https://raw.githubusercontent.com/mstudio45/LinoriaLib/main/'
local Library = loadstring(game:HttpGet(repo .. 'Library.lua'))()
local ThemeManager = loadstring(game:HttpGet(repo .. 'addons/ThemeManager.lua'))()
local SaveManager = loadstring(game:HttpGet(repo .. 'addons/SaveManager.lua'))()

local Window = Library:CreateWindow({
    Title = 'Iroshida v2.6',
    Center = true,
    AutoShow = true,
    TabPadding = 8,
    MenuFadeTime = 0.1
})

local Tabs = {
    Farm = Window:AddTab('AutoFarm'),
    Performance = Window:AddTab('Performance'),
    Settings = Window:AddTab('Settings'),
}

-- ==========================================
-- 4. ЯДРО (ОПРЕДЕЛЕНИЕ РЕЖИМА И РОЛИ)
-- ==========================================
local function updateGameState()
    local knives = 0
    local guns = 0
    myRole = "Innocent"

    for _, player in pairs(Players:GetPlayers()) do
        if player.Backpack then
            if player.Backpack:FindFirstChild("Knife") then knives = knives + 1 end
            if player.Backpack:FindFirstChild("Gun") then guns = guns + 1 end
        end
    end

    isInfection = (knives >= 2 or guns >= 2)

    if LocalPlayer.Backpack then
        if LocalPlayer.Backpack:FindFirstChild("Knife") then
            myRole = isInfection and "Zombie" or "Murderer"
        elseif LocalPlayer.Backpack:FindFirstChild("Gun") then
            myRole = isInfection and "Survivor" or "Sheriff"
        else
            myRole = "Innocent"
        end
    end
end

-- ==========================================
-- 5. УМНЫЙ ПОИСК (Защита от лагов в лобби)
-- ==========================================
local cachedCoinContainer = nil
local lastSearchTime = 0

local function getClosestItem(mode)
    if not Settings.FarmEnabled then return nil end

    if not cachedCoinContainer or not cachedCoinContainer.Parent then
        if tick() - lastSearchTime < 2 then return nil end
        lastSearchTime = tick()

        cachedCoinContainer = nil
        local normal = Workspace:FindFirstChild("Normal")
        if normal then
            cachedCoinContainer = normal:FindFirstChild("CoinContainer") 
                               or normal:FindFirstChild("CandyContainer") 
                               or normal:FindFirstChild("Coins")
        end
        
        if not cachedCoinContainer then return nil end
    end

    local hrp = LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
    if not hrp then return nil end

    local allItems = {}
    for _, item in pairs(cachedCoinContainer:GetChildren()) do
        if item:IsA("BasePart") and not collectedCoins[item] then
            table.insert(allItems, item)
        end
    end

    if #allItems == 0 then return nil end

    if mode == "Аккуратный" then
        return allItems[math.random(1, #allItems)]
    end

    local closestCoin = nil
    local shortestDistance = math.huge

    for _, coin in pairs(allItems) do
        local distance = (coin.Position - hrp.Position).Magnitude
        if distance < shortestDistance then
            shortestDistance = distance
            closestCoin = coin
        end
    end
    return closestCoin
end

-- ==========================================
-- 6. МОДУЛЬ ПОЛЕТА (Без CFrame, без вылетов)
-- ==========================================
local flyConnection = nil
local currentTarget = nil
local targetSearchTimer = 0

local function startFarmLoop()
    local character = LocalPlayer.Character
    local hrp = character and character:FindFirstChild("HumanoidRootPart")
    if not hrp then return end

    local bv = hrp:FindFirstChild("IroshidaVelocity") or Instance.new("BodyVelocity")
    bv.Name = "IroshidaVelocity"
    bv.Parent = hrp
    bv.MaxForce = Vector3.new(math.huge, math.huge, math.huge)

    if flyConnection then flyConnection:Disconnect() end
    
    flyConnection = RunService.Heartbeat:Connect(function(deltaTime)
        if not Settings.FarmEnabled then
            bv.Velocity = Vector3.new(0, 0, 0)
            return
        end

        if currentCoins >= Settings.CoinLimit then
            Settings.FarmEnabled = false
            bv.Velocity = Vector3.new(0, 0, 0)
            Library:Notify("Лимит монет достигнут!", 3)
            return
        end

        -- Поиск цели раз в 0.2 сек
        targetSearchTimer = targetSearchTimer + deltaTime
        if targetSearchTimer > 0.2 or not currentTarget or not currentTarget.Parent then
            currentTarget = getClosestItem(Settings.FarmMode)
            targetSearchTimer = 0
        end
        
        if currentTarget and hrp then
            local distance = (currentTarget.Position - hrp.Position).Magnitude
            
            -- Радиус 1 стад (просто пролетаем сквозь)
            if distance < 1 then
                if not collectedCoins[currentTarget] then
                    collectedCoins[currentTarget] = true
                    currentCoins = currentCoins + 1 
                    currentTarget = nil 
                end
            else
                -- Летим на полной скорости
                local direction = (currentTarget.Position - hrp.Position).Unit
                bv.Velocity = direction * Settings.FlySpeed
            end
        else
            bv.Velocity = Vector3.new(0, 0, 0)
        end
    end)
end

-- ==========================================
-- 7. ЛОГИКА РОЛЕЙ (Мозг)
-- ==========================================
local function handleRoleLogic()
    task.spawn(function()
        while true do
            task.wait(0.5)
            updateGameState()

            if currentCoins < Settings.CoinLimit then continue end 

            if not isInfection then
                if myRole == "Murderer" and Settings.KillAll then
                    for _, player in pairs(Players:GetPlayers()) do
                        if player ~= LocalPlayer and player.Character and player.Character:FindFirstChild("HumanoidRootPart") then
                            LocalPlayer.Character.HumanoidRootPart.CFrame = player.Character.HumanoidRootPart.CFrame
                            task.wait(0.1)
                            VirtualUser:Button1Down(Vector2.new(0,0), workspace.CurrentCamera.CFrame)
                            VirtualUser:Button1Up(Vector2.new(0,0), workspace.CurrentCamera.CFrame)
                            task.wait(0.3)
                        end
                    end
                elseif myRole == "Sheriff" and Settings.AutoShoot then
                    for _, player in pairs(Players:GetPlayers()) do
                        if player.Backpack and player.Backpack:FindFirstChild("Knife") and player.Character then
                            LocalPlayer.Character.HumanoidRootPart.CFrame = CFrame.new(LocalPlayer.Character.HumanoidRootPart.Position, player.Character.HumanoidRootPart.Position)
                            task.wait(0.1)
                            VirtualUser:Button1Down(Vector2.new(0,0), workspace.CurrentCamera.CFrame)
                            VirtualUser:Button1Up(Vector2.new(0,0), workspace.CurrentCamera.CFrame)
                        end
                    end
                elseif myRole == "Innocent" and Settings.AutoGun then
                    local gunDrop = Workspace:FindFirstChild("Normal") and Workspace.Normal:FindFirstChild("GunDrop")
                    if gunDrop then
                        LocalPlayer.Character.HumanoidRootPart.CFrame = gunDrop.CFrame
                        task.wait(0.5)
                        for _, player in pairs(Players:GetPlayers()) do
                            if player.Backpack and player.Backpack:FindFirstChild("Knife") and player.Character then
                                LocalPlayer.Character.HumanoidRootPart.CFrame = CFrame.new(LocalPlayer.Character.HumanoidRootPart.Position, player.Character.HumanoidRootPart.Position)
                                VirtualUser:Button1Down(Vector2.new(0,0), workspace.CurrentCamera.CFrame)
                                VirtualUser:Button1Up(Vector2.new(0,0), workspace.CurrentCamera.CFrame)
                            end
                        end
                    else
                        task.wait(Settings.InnocentTimeout)
                        if not Settings.FarmExp then
                            LocalPlayer.Character:BreakJoints()
                        end
                    end
                end
            else
                if myRole == "Survivor" then
                    for _, player in pairs(Players:GetPlayers()) do
                        if player.Backpack and player.Backpack:FindFirstChild("Knife") and player.Character then
                            LocalPlayer.Character.HumanoidRootPart.CFrame = player.Character.HumanoidRootPart.CFrame
                            break
                        end
                    end
                elseif myRole == "Zombie" and Settings.Magnet then
                    for _, player in pairs(Players:GetPlayers()) do
                        if player ~= LocalPlayer and player.Character and player.Character:FindFirstChild("HumanoidRootPart") then
                            LocalPlayer.Character.HumanoidRootPart.CFrame = player.Character.HumanoidRootPart.CFrame
                            task.wait(0.1)
                            VirtualUser:Button1Down(Vector2.new(0,0), workspace.CurrentCamera.CFrame)
                            VirtualUser:Button1Up(Vector2.new(0,0), workspace.CurrentCamera.CFrame)
                            task.wait(0.3)
                        end
                    end
                end
            end
        end
    end)
end

-- ==========================================
-- 8. ИНТЕРФЕЙС AUTO FARM
-- ==========================================
local FarmGroup = Tabs.Farm:AddLeftGroupbox('Farm Settings')

FarmGroup:AddToggle('FarmToggle', {
    Text = 'Включить автофарм',
    Default = false,
    Callback = function(Value)
        Settings.FarmEnabled = Value
        if Value then
            currentCoins = 0
            collectedCoins = {}
            startFarmLoop()
            handleRoleLogic()
        end
    end
})

FarmGroup:AddInput('CoinLimitInput', {
    Default = "50",
    Numeric = true,
    Text = 'Лимит монет',
    Callback = function(Value) Settings.CoinLimit = tonumber(Value) or 50 end
})

FarmGroup:AddDropdown('FarmMode', {
    Text = 'Режим сбора',
    Default = 'Быстрый',
    Values = { 'Быстрый', 'Аккуратный' },
    Callback = function(Value) Settings.FarmMode = Value end
})

FarmGroup:AddSlider('FlySpeedSlider', {
    Text = 'Скорость полета',
    Default = 50,
    Min = 1,
    Max = 100,
    Rounding = 0,
    Callback = function(Value) Settings.FlySpeed = Value end
})

FarmGroup:AddSlider('CooldownSlider', {
    Text = 'Задержка (сек)',
    Default = 0.1,
    Min = 0,
    Max = 2,
    Rounding = 1,
    Callback = function(Value) Settings.Cooldown = Value end
})

local RoleGroup = Tabs.Farm:AddRightGroupbox('Role Logic')

RoleGroup:AddToggle('AutoShootToggle', {
    Text = 'Авто-Стрельба (Шериф)',
    Default = true,
    Callback = function(Value) Settings.AutoShoot = Value end
})

RoleGroup:AddToggle('AutoGunToggle', {
    Text = 'Подбор пистолета (Невиновный)',
    Default = true,
    Callback = function(Value) Settings.AutoGun = Value end
})

RoleGroup:AddToggle('KillAllToggle', {
    Text = 'Убить всех (Убийца)',
    Default = true,
    Callback = function(Value) Settings.KillAll = Value end
})

RoleGroup:AddToggle('MagnetToggle', {
    Text = 'Магнит (Инфекция/Зомби)',
    Default = false,
    Callback = function(Value) Settings.Magnet = Value end
})

RoleGroup:AddToggle('FarmExpToggle', {
    Text = 'Фарм EXP (Без Reset)',
    Default = true,
    Tooltip = 'Если включено, невиновный не будет умирать после сбора монет.',
    Callback = function(Value) Settings.FarmExp = Value end
})

-- ==========================================
-- 9. ИНТЕРФЕЙС PERFORMANCE
-- ==========================================
local PerformanceGroup = Tabs.Performance:AddLeftGroupbox('Optimization')
local originalMaterials = {}

PerformanceGroup:AddToggle('PlasticMode', {
    Text = 'Plastic World (FPS Boost)',
    Default = false,
    Callback = function(Value)
        if Value then
            for _, obj in pairs(Workspace:GetDescendants()) do
                if obj:IsA("BasePart") and obj.Material ~= Enum.Material.Plastic then
                    if not originalMaterials[obj] then originalMaterials[obj] = obj.Material end
                    obj.Material = Enum.Material.Plastic
                end
            end
        else
            for obj, mat in pairs(originalMaterials) do
                if obj and obj.Parent then obj.Material = mat end
            end
            originalMaterials = {}
        end
    end
})

PerformanceGroup:AddToggle('KillShadows', {
    Text = 'Убить тени',
    Default = false,
    Callback = function(Value) Lighting.GlobalShadows = not Value end
})

PerformanceGroup:AddToggle('KillLight', {
    Text = 'Плоское освещение',
    Default = false,
    Callback = function(Value)
        if Value then
            Lighting.Ambient = Color3.new(0.5, 0.5, 0.5)
            Lighting.OutdoorAmbient = Color3.new(0.5, 0.5, 0.5)
            Lighting.Brightness = 1
            Lighting.ClockTime = 12
        else
            Lighting.Brightness = 2
        end
    end
})

PerformanceGroup:AddToggle('GreySky', {
    Text = 'Серое небо (FPS)',
    Default = false,
    Callback = function(Value)
        if Value then
            local sky = Instance.new("Sky")
            sky.SkyboxBk = ""; sky.SkyboxDn = ""; sky.SkyboxFt = ""; sky.SkyboxLf = ""; sky.SkyboxRt = ""; sky.SkyboxUp = ""
            sky.Parent = Lighting
            Lighting.FogColor = Color3.new(0.5, 0.5, 0.5)
            Lighting.FogEnd = 10000
        else
            local sky = Lighting:FindFirstChildOfClass("Sky")
            if sky then sky:Destroy() end
        end
    end
})

PerformanceGroup:AddToggle('NoclipToggle', {
    Text = 'Noclip (Проход сквозь стены)',
    Default = true,
    Callback = function(Value) Settings.Noclip = Value end
})

PerformanceGroup:AddButton('Убить эффекты (Дым/Огонь)', function()
    for _, obj in pairs(Workspace:GetDescendants()) do
        if obj:IsA("ParticleEmitter") or obj:IsA("Smoke") or obj:IsA("Fire") then
            obj.Enabled = false
        end
    end
    Library:Notify("Эффекты отключены", 3)
end)

PerformanceGroup:AddDropdown('RAMMode', {
    Text = 'RAM Cleanup',
    Default = 'Off',
    Values = { 'Off', 'Smart', 'Aggressive' },
    Callback = function(Value) Settings.RamMode = Value end
})

PerformanceGroup:AddSlider('RAMInterval', {
    Text = 'Cleanup Interval (sec)',
    Default = 30,
    Min = 5,
    Max = 120,
    Rounding = 0,
    Callback = function(Value) Settings.RamInterval = Value end
})

task.spawn(function()
    while task.wait(Settings.RamInterval) do
        if Settings.RamMode == "Smart" then
            collectgarbage("step")
        elseif Settings.RamMode == "Aggressive" then
            collectgarbage("collect")
        end
    end
end)

-- ==========================================
-- 10. ОПТИМИЗИРОВАННЫЙ NOCLIP (БЕЗ ЛАГОВ)
-- ==========================================
-- Убрали тяжелый RunService.Stepped, который вешал игру. 
-- Теперь Noclip проверяется раз в 0.5 секунды в отдельном потоке.
task.spawn(function()
    while task.wait(0.5) do
        if LocalPlayer.Character then
            local shouldCollide = not (Settings.FarmEnabled and Settings.Noclip)
            for _, part in pairs(LocalPlayer.Character:GetDescendants()) do
                if part:IsA("BasePart") and not part:FindFirstAncestorOfClass("Accessory") then
                    part.CanCollide = shouldCollide
                end
            end
        end
    end
end)

-- ==========================================
-- 11. НАСТРОЙКИ UI (SaveManager)
-- ==========================================
local MenuGroup = Tabs.Settings:AddLeftGroupbox('Menu')
MenuGroup:AddButton('Unload', function() Library:Unload() end)
MenuGroup:AddLabel('Menu bind'):AddKeyPicker('MenuKeybind', { Default = 'RightShift', NoUI = true, Text = 'Menu keybind' })
Library.ToggleKeybind = Options.MenuKeybind

ThemeManager:SetLibrary(Library)
SaveManager:SetLibrary(Library)
SaveManager:IgnoreThemeSettings()
SaveManager:SetIgnoreIndexes({ 'MenuKeybind' })
ThemeManager:SetFolder('Iroshida')
SaveManager:SetFolder('Iroshida/configs')
SaveManager:BuildConfigSection(Tabs.Settings)
ThemeManager:ApplyToTab(Tabs.Settings)
SaveManager:LoadAutoloadConfig()

print("[Iroshida v2.6] Загружен успешно!")
