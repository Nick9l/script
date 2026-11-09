-- ==========================================
-- IROSHIDA v1.0 (Beta Build)
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
-- 2. ЗАГРУЗКА UI (LINORIA)
-- ==========================================
local repo = 'https://raw.githubusercontent.com/mstudio45/LinoriaLib/main/'
local Library = loadstring(game:HttpGet(repo .. 'Library.lua'))()
local ThemeManager = loadstring(game:HttpGet(repo .. 'addons/ThemeManager.lua'))()
local SaveManager = loadstring(game:HttpGet(repo .. 'addons/SaveManager.lua'))()

local Window = Library:CreateWindow({
    Title = 'Iroshida v1.0',
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
-- 3. ПЕРЕМЕННЫЕ И НАСТРОЙКИ
-- ==========================================
local Settings = {
    FarmEnabled = false,
    CoinLimit = 50,
    FlySpeed = 50,
    Cooldown = 0.1,
    MagnetEnabled = false,
    AutoShoot = true,
    InnocentTimeout = 35,
    RamMode = "Off",
    RamInterval = 30
}

local currentCoins = 0
local isInfection = false
local myRole = "Innocent" -- Innocent, Sheriff, Murderer, Survivor, Zombie

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

    -- Определение своей роли
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
-- 5. МОДУЛЬ ФАРМА (ПОЛЕТ К МОНЕТАМ)
-- ==========================================
local function getClosestCoin()
    local coinContainer = Workspace:FindFirstChild("Normal") and Workspace.Normal:FindFirstChild("CoinContainer")
    if not coinContainer then return nil end

    local closestCoin = nil
    local shortestDistance = math.huge
    local hrp = LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
    if not hrp then return nil end

    for _, coin in pairs(coinContainer:GetChildren()) do
        if coin:IsA("BasePart") then
            local distance = (coin.Position - hrp.Position).Magnitude
            if distance < shortestDistance then
                shortestDistance = distance
                closestCoin = coin
            end
        end
    end
    return closestCoin
end

local function startFarmLoop()
    task.spawn(function()
        while Settings.FarmEnabled do
            task.wait(Settings.Cooldown)
            
            if currentCoins >= Settings.CoinLimit then
                Settings.FarmEnabled = false
                Library:Notify("Лимит монет достигнут!", 3)
                break
            end

            local targetCoin = getClosestCoin()
            local character = LocalPlayer.Character
            local hrp = character and character:FindFirstChild("HumanoidRootPart")
            
            if targetCoin and hrp then
                -- Плавный полет через BodyVelocity
                local bv = hrp:FindFirstChild("IroshidaVelocity") or Instance.new("BodyVelocity")
                bv.Name = "IroshidaVelocity"
                bv.Parent = hrp
                bv.MaxForce = Vector3.new(math.huge, math.huge, math.huge)
                
                -- Направление к монете
                local direction = (targetCoin.Position - hrp.Position).Unit
                bv.Velocity = direction * Settings.FlySpeed
                
                -- Если долетели, отключаем скорость
                if (targetCoin.Position - hrp.Position).Magnitude < 5 then
                    bv.Velocity = Vector3.new(0, 0, 0)
                    currentCoins = currentCoins + 1 -- Условный подсчет
                end
            end
        end
        
        -- Очистка при выключении
        if LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart") then
            local bv = LocalPlayer.Character.HumanoidRootPart:FindFirstChild("IroshidaVelocity")
            if bv then bv:Destroy() end
        end
    end)
end

-- ==========================================
-- 6. ЛОГИКА РОЛЕЙ (КЛАССИКА И ИНФЕКЦИЯ)
-- ==========================================
local function handleRoleLogic()
    task.spawn(function()
        while true do
            task.wait(0.5)
            if not Settings.FarmEnabled then continue end -- Ждем, пока нафармит

            updateGameState()

            if not isInfection then
                -- КЛАССИКА
                if myRole == "Murderer" then
                    -- Терминатор
                    for _, player in pairs(Players:GetPlayers()) do
                        if player ~= LocalPlayer and player.Character and player.Character:FindFirstChild("HumanoidRootPart") then
                            LocalPlayer.Character.HumanoidRootPart.CFrame = player.Character.HumanoidRootPart.CFrame
                            task.wait(0.2)
                            VirtualUser:Button1Down(Vector2.new(0,0), workspace.CurrentCamera.CFrame)
                            VirtualUser:Button1Up(Vector2.new(0,0), workspace.CurrentCamera.CFrame)
                            task.wait(0.5)
                        end
                    end
                elseif myRole == "Sheriff" and Settings.AutoShoot then
                    -- Стрельба в убийцу
                    for _, player in pairs(Players:GetPlayers()) do
                        if player.Backpack and player.Backpack:FindFirstChild("Knife") and player.Character then
                            LocalPlayer.Character.HumanoidRootPart.CFrame = CFrame.new(LocalPlayer.Character.HumanoidRootPart.Position, player.Character.HumanoidRootPart.Position)
                            task.wait(0.1)
                            VirtualUser:Button1Down(Vector2.new(0,0), workspace.CurrentCamera.CFrame)
                            VirtualUser:Button1Up(Vector2.new(0,0), workspace.CurrentCamera.CFrame)
                        end
                    end
                elseif myRole == "Innocent" and Settings.AutoShoot then
                    -- Ждем пистолет
                    local gunDrop = Workspace:FindFirstChild("Normal") and Workspace.Normal:FindFirstChild("GunDrop")
                    if gunDrop then
                        LocalPlayer.Character.HumanoidRootPart.CFrame = gunDrop.CFrame
                        task.wait(0.5)
                        -- После подбора стреляем
                    else
                        task.wait(Settings.InnocentTimeout) -- Ждем тайм-аут
                        if myRole == "Innocent" and not gunDrop then
                            LocalPlayer.Character:BreakJoints() -- Reset
                        end
                    end
                end
            else
                -- ИНФЕКЦИЯ
                if myRole == "Survivor" then
                    -- Идем заражаться
                    for _, player in pairs(Players:GetPlayers()) do
                        if player.Backpack and player.Backpack:FindFirstChild("Knife") and player.Character then
                            LocalPlayer.Character.HumanoidRootPart.CFrame = player.Character.HumanoidRootPart.CFrame
                            break
                        end
                    end
                elseif myRole == "Zombie" and Settings.MagnetEnabled then
                    -- Магнит (убиваем всех)
                    for _, player in pairs(Players:GetPlayers()) do
                        if player ~= LocalPlayer and player.Character and player.Character:FindFirstChild("HumanoidRootPart") then
                            LocalPlayer.Character.HumanoidRootPart.CFrame = player.Character.HumanoidRootPart.CFrame
                            task.wait(0.1)
                            VirtualUser:Button1Down(Vector2.new(0,0), workspace.CurrentCamera.CFrame)
                            VirtualUser:Button1Up(Vector2.new(0,0), workspace.CurrentCamera.CFrame)
                        end
                    end
                end
            end
        end
    end)
end

-- ==========================================
-- 7. ИНТЕРФЕЙС AUTO FARM
-- ==========================================
local FarmGroup = Tabs.Farm:AddLeftGroupbox('Farm Settings')

FarmGroup:AddToggle('FarmToggle', {
    Text = 'Включить фарм',
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
    Text = 'Авто-Стрельба / Убийство',
    Default = true,
    Callback = function(Value) Settings.AutoShoot = Value end
})

RoleGroup:AddToggle('MagnetToggle', {
    Text = 'Магнит (Инфекция)',
    Default = false,
    Callback = function(Value) Settings.MagnetEnabled = Value end
})

-- ==========================================
-- 8. ИНТЕРФЕЙС PERFORMANCE
-- ==========================================
local PerformanceGroup = Tabs.Performance:AddLeftGroupbox('Optimization')

local plasticEnabled = false
local originalMaterials = {}

local function applyPlastic()
    for _, obj in pairs(Workspace:GetDescendants()) do
        if obj:IsA("BasePart") and obj.Material ~= Enum.Material.Plastic then
            if not originalMaterials[obj] then originalMaterials[obj] = obj.Material end
            obj.Material = Enum.Material.Plastic
        end
    end
end

local function restoreVisuals()
    for obj, mat in pairs(originalMaterials) do
        if obj and obj.Parent then obj.Material = mat end
    end
    originalMaterials = {}
end

PerformanceGroup:AddToggle('PlasticMode', {
    Text = 'Plastic World (FPS Boost)',
    Default = false,
    Callback = function(Value)
        plasticEnabled = Value
        if plasticEnabled then applyPlastic() else restoreVisuals() end
    end
})

PerformanceGroup:AddDropdown('RAMMode', {
    Text = 'RAM Cleanup Mode',
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

-- Цикл очистки памяти
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
-- 9. НАСТРОЙКИ UI
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

print("[Iroshida] Успешно загружен!")
