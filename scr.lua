-- ==========================================
-- IROSHIDA v4.0 (Zynic Engine)
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
    CoinLimit = 50, -- Лимит (будет сверяться с UI игры)
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

local isInfection = false
local myRole = "Innocent" 
local collectedCoins = {}
local AutoFarmThread = nil

-- ==========================================
-- 3. ЗАГРУЗКА UI (LINORIA)
-- ==========================================
local repo = 'https://raw.githubusercontent.com/mstudio45/LinoriaLib/main/'
local Library = loadstring(game:HttpGet(repo .. 'Library.lua'))()
local ThemeManager = loadstring(game:HttpGet(repo .. 'addons/ThemeManager.lua'))()
local SaveManager = loadstring(game:HttpGet(repo .. 'addons/SaveManager.lua'))()

local Window = Library:CreateWindow({
    Title = 'Iroshida v4.0',
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
-- 5. ФУНКЦИИ ZYNIC (Поиск карты и проверка)
-- ==========================================
-- Ищем карту (папку Spawns вне лобби)
local function getMap()
    for _, v in pairs(Workspace:GetDescendants()) do
        if v.Name == "Spawns" and v.Parent.Name ~= "Lobby" then
            return v.Parent
        end
    end
    return nil
end

-- Проверяем, идет ли раунд
local function checkIfGameInProgress()
    if getMap() then return true end
    return false
end

-- Функция плавного движения (Копия от Zynic)
local function moveToPositionSlowly(targetPosition, duration)
    local character = LocalPlayer.Character
    if not character or not character.PrimaryPart then return end
    
    local startPosition = character.PrimaryPart.Position
    local startTime = tick()
    
    while true do
        local elapsedTime = tick() - startTime
        local alpha = math.min(elapsedTime / duration, 1)
        
        if not character or not character.PrimaryPart then break end
        character:PivotTo(CFrame.new(startPosition:Lerp(targetPosition, alpha)))
        
        if alpha >= 1 then
            task.wait(0.1) -- Ждем касания
            break
        end
        task.wait()
    end
end

-- ==========================================
-- 6. МОДУЛЬ ПОЛЕТА (ZYNIC ENGINE)
-- ==========================================
local function startFarmLoop()
    if AutoFarmThread then task.cancel(AutoFarmThread) end
    
    AutoFarmThread = task.spawn(function()
        -- Ждем, пока загрузится карта
        while Settings.FarmEnabled and not checkIfGameInProgress() do
            task.wait(1)
        end

        local map = getMap()
        if not map then return end

        local coinContainer = map:FindFirstChild("CoinContainer")
        if not coinContainer then return end

        -- Слушатель для новых монет
        local addedConn = coinContainer.DescendantAdded:Connect(function(descendant)
            if descendant:IsA("TouchTransmitter") then
                collectedCoins[descendant.Parent] = nil
            end
        end)

        while Settings.FarmEnabled and checkIfGameInProgress() do
            -- Находим ближайшую монету
            local closestCoin = nil
            local shortestDistance = math.huge
            local hrp = LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
            
            if hrp then
                for _, coin in pairs(coinContainer:GetChildren()) do
                    if coin:IsA("BasePart") and not collectedCoins[coin] then
                        local distance = (coin.Position - hrp.Position).Magnitude
                        if distance < shortestDistance then
                            shortestDistance = distance
                            closestCoin = coin
                        end
                    end
                end
            end

            if closestCoin and hrp then
                -- Высчитываем время полета (Zynic формула)
                local duration = shortestDistance / (Settings.FlySpeed * 0.6) -- Чем больше скорость, тем быстрее
                
                -- Летим
                moveToPositionSlowly(closestCoin.Position, duration)
                
                -- Помечаем как собранную (ждем, пока игра удалит TouchTransmitter)
                collectedCoins[closestCoin] = true
                task.wait(0.1)
            else
                task.wait(1) -- Ждем появления монет
            end
        end
        
        addedConn:Disconnect()
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

            -- Если фарм не включен, ничего не делаем
            if not Settings.FarmEnabled then continue end 

            -- Ждем, пока не нафармим (смотрим на UI игры)
            -- (Упрощенно: ждем 5 секунд после старта фарма, чтобы не спамить)
            
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
            collectedCoins = {}
            startFarmLoop()
            handleRoleLogic()
        end
    end
})

FarmGroup:AddSlider('FlySpeedSlider', {
    Text = 'Скорость полета',
    Default = 50,
    Min = 1,
    Max = 100,
    Rounding = 0,
    Callback = function(Value) Settings.FlySpeed = Value end
})

-- ==========================================
-- 9. МОДУЛЬ NOCLIP (Отключен по умолчанию, чтобы не ломать Zynic-двигатель)
-- ==========================================
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
-- 10. НАСТРОЙКИ UI
-- ==========================================
local MenuGroup = Tabs.Settings:AddLeftGroupbox('Menu')
MenuGroup:AddButton('Unload', function() Library:Unload() end)

print("[Iroshida v4.0 - Zynic Engine] Загружен успешно!")
