-- ==========================================
-- IROSHIDA v2.0 (Monolith Build)
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
-- 2. НАСТРОЙКИ (Центральный блок)
-- ==========================================
local Settings = {
    FarmEnabled = false,
    CoinLimit = 50,
    FlySpeed = 50,
    Cooldown = 0.1,
    FarmMode = "Быстрый", -- "Быстрый" или "Аккуратный"
    
    AutoShoot = true,     -- Автострельба за шерифа
    AutoGun = true,       -- Подбор пистолета за невиновного
    KillAll = true,       -- Убить всех за убийцу
    Magnet = false,       -- Магнит для зомби
    FarmExp = true,       -- Режим EXP (не делать reset)
    
    RamMode = "Off",
    RamInterval = 30
}

local currentCoins = 0
local isInfection = false
local myRole = "Innocent" 

-- ==========================================
-- 3. ЗАГРУЗКА UI (LINORIA)
-- ==========================================
local repo = 'https://raw.githubusercontent.com/mstudio45/LinoriaLib/main/'
local Library = loadstring(game:HttpGet(repo .. 'Library.lua'))()
local ThemeManager = loadstring(game:HttpGet(repo .. 'addons/ThemeManager.lua'))()
local SaveManager = loadstring(game:HttpGet(repo .. 'addons/SaveManager.lua'))()

local Window = Library:CreateWindow({
    Title = 'Iroshida v2.0',
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
-- 5. УНИВЕРСАЛЬНЫЙ ПОИСК (Монеты, Конфеты, Мячи)
-- ==========================================
local cachedCoinContainer = nil

local function getClosestItem(mode)
    if not cachedCoinContainer or not cachedCoinContainer.Parent then
        cachedCoinContainer = nil
        for _, obj in pairs(Workspace:GetDescendants()) do
            if obj.Name == "CoinContainer" or obj.Name == "CandyContainer" or obj.Name == "Coins" or obj.Name == "Normal" then
                -- Если это Normal, проверяем есть ли внутри Coin/Candy
                if obj.Name == "Normal" then
                    local container = obj:FindFirstChild("CoinContainer") or obj:FindFirstChild("CandyContainer")
                    if container then
                        cachedCoinContainer = container
                        break
                    end
                else
                    cachedCoinContainer = obj
                    break
                end
            elseif obj.Name == "Coin" or obj.Name == "Candy" or obj.Name == "Beachball" then
                cachedCoinContainer = obj.Parent
                break
            end
        end
    end

    if not cachedCoinContainer then return nil end

    local hrp = LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
    if not hrp then return nil end

    local allItems = {}
    for _, item in pairs(cachedCoinContainer:GetChildren()) do
        if item:IsA("BasePart") then
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
-- 6. МОДУЛЬ ПОЛЕТА (ФАРМ)
-- ==========================================
local function startFarmLoop()
    task.spawn(function()
        while Settings.FarmEnabled do
            task.wait(Settings.Cooldown)
            
            if currentCoins >= Settings.CoinLimit then
                Settings.FarmEnabled = false
                Library:Notify("Лимит монет достигнут!", 3)
                break
            end

            local targetItem = getClosestItem(Settings.FarmMode)
            local character = LocalPlayer.Character
            local hrp = character and character:FindFirstChild("HumanoidRootPart")
            
            if targetItem and hrp then
                local bv = hrp:FindFirstChild("IroshidaVelocity") or Instance.new("BodyVelocity")
                bv.Name = "IroshidaVelocity"
                bv.Parent = hrp
                bv.MaxForce = Vector3.new(math.huge, math.huge, math.huge)
                
                local direction = (targetItem.Position - hrp.Position).Unit
                bv.Velocity = direction * Settings.FlySpeed
                
                if (targetItem.Position - hrp.Position).Magnitude < 5 then
                    bv.Velocity = Vector3.new(0, 0, 0)
                    currentCoins = currentCoins + 1 
                end
            else
                -- Если цель не найдена, просто зависаем на месте
                local bv = hrp and hrp:FindFirstChild("IroshidaVelocity")
                if bv then bv.Velocity = Vector3.new(0, 0, 0) end
            end
        end
        
        if LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart") then
            local bv = LocalPlayer.Character.HumanoidRootPart:FindFirstChild("IroshidaVelocity")
            if bv then bv:Destroy() end
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

            -- Если лимит не достигнут, ничего не делаем (ждем фарм)
            if currentCoins < Settings.CoinLimit then continue end 

            if not isInfection then
                -- КЛАССИКА
                if myRole == "Murderer" and Settings.KillAll then
                    -- Терминатор (Убийца)
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
                    -- Стрельба в убийцу (Шериф)
                    for _, player in pairs(Players:GetPlayers()) do
                        if player.Backpack and player.Backpack:FindFirstChild("Knife") and player.Character then
                            LocalPlayer.Character.HumanoidRootPart.CFrame = CFrame.new(LocalPlayer.Character.HumanoidRootPart.Position, player.Character.HumanoidRootPart.Position)
                            task.wait(0.1)
                            VirtualUser:Button1Down(Vector2.new(0,0), workspace.CurrentCamera.CFrame)
                            VirtualUser:Button1Up(Vector2.new(0,0), workspace.CurrentCamera.CFrame)
                        end
                    end
                elseif myRole == "Innocent" and Settings.AutoGun then
                    -- Логика невиновного
                    local gunDrop = Workspace:FindFirstChild("Normal") and Workspace.Normal:FindFirstChild("GunDrop")
                    if gunDrop then
                        LocalPlayer.Character.HumanoidRootPart.CFrame = gunDrop.CFrame
                        task.wait(0.5)
                        -- Стреляем в убийцу
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
                            LocalPlayer.Character:BreakJoints() -- Reset, если EXP не включен
                        end
                    end
                end
            else
                -- ИНФЕКЦИЯ
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
-- 10. НАСТРОЙКИ UI (SaveManager)
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

print("[Iroshida v2.0] Загружен успешно!")
