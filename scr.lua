-- ==========================================
-- IROSHIDA v7.0 (Ultimate Hybrid)
-- Engine: PROTO | Roles: ELITE | Logic: Nick9l
-- ==========================================

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")
local Lighting = game:GetService("Lighting")
local LocalPlayer = Players.LocalPlayer
local VirtualUser = game:GetService("VirtualUser")

if not game:IsLoaded() then game.Loaded:Wait() end

-- ==========================================
-- 1. НАСТРОЙКИ (Config)
-- ==========================================
local Settings = {
    FarmEnabled = false,
    CoinLimit = 50,
    FlySpeed = 40, -- Скорость Tween
    Noclip = true,
    
    -- Тактические фишки
    AutoGun = true,      -- Подбор пистолета (Невиновный)
    AutoShoot = true,    -- Стрельба в убийцу (Шериф)
    KillAll = true,      -- Убить всех (Убийца)
    Magnet = true,       -- Магнит (Зомби)
    
    -- Перфоманс
    PlasticMode = false,
    KillShadows = false,
    GreySky = false
}

local CurrentTween = nil
local VisitedCoins = {}
local AutoFarmThread = nil
local RoleLogicThread = nil
local currentRole = "Innocent"
local isInfection = false
local collectedCount = 0

-- ==========================================
-- 2. ЗАГРУЗОЧНЫЙ ЭКРАН
-- ==========================================
local Splash = Instance.new("ScreenGui")
Splash.Parent = LocalPlayer:WaitForChild("PlayerGui")
Splash.IgnoreGuiInset = true

local SplashText = Instance.new("TextLabel")
SplashText.Parent = Splash
SplashText.Size = UDim2.new(1, 0, 1, 0)
SplashText.BackgroundColor3 = Color3.fromRGB(15, 15, 20)
SplashText.Text = "Привет."
SplashText.TextColor3 = Color3.fromRGB(255, 255, 255)
SplashText.Font = Enum.Font.GothamBold
SplashText.TextSize = 36

task.wait(1)
SplashText.Text = "Загрузка..."
task.wait(0.5)
SplashText.Text = "Iroshida v7.0"
task.wait(1)
Splash:Destroy()

-- ==========================================
-- 3. ЛЕГКИЙ GUI (Без Linoria/Fluent)
-- ==========================================
local ScreenGui = Instance.new("ScreenGui")
ScreenGui.Name = "Iroshida_UI"
ScreenGui.ResetOnSpawn = false
ScreenGui.Parent = LocalPlayer:WaitForChild("PlayerGui")

local MainFrame = Instance.new("Frame")
MainFrame.Size = UDim2.new(0, 320, 0, 280)
MainFrame.Position = UDim2.new(0.5, -160, 0.5, -140)
MainFrame.BackgroundColor3 = Color3.fromRGB(20, 20, 25)
MainFrame.BorderSizePixel = 0
MainFrame.Active = true
MainFrame.Draggable = true
MainFrame.Parent = ScreenGui
Instance.new("UICorner", MainFrame).CornerRadius = UDim.new(0, 10)

local TitleBar = Instance.new("Frame")
TitleBar.Size = UDim2.new(1, 0, 0, 35)
TitleBar.BackgroundColor3 = Color3.fromRGB(30, 30, 40)
TitleBar.Parent = MainFrame
Instance.new("UICorner", TitleBar).CornerRadius = UDim.new(0, 10)

local Title = Instance.new("TextLabel")
Title.Size = UDim2.new(1, -20, 1, 0)
Title.Position = UDim2.new(0, 10, 0, 0)
Title.BackgroundTransparency = 1
Title.Text = "Iroshida | v7.0"
Title.TextColor3 = Color3.fromRGB(180, 100, 255)
Title.Font = Enum.Font.GothamBold
Title.TextSize = 15
Title.TextXAlignment = Enum.TextXAlignment.Left
Title.Parent = TitleBar

local Content = Instance.new("Frame")
Content.Size = UDim2.new(1, -20, 1, -45)
Content.Position = UDim2.new(0, 10, 0, 40)
Content.BackgroundTransparency = 1
Content.Parent = MainFrame
local UIList = Instance.new("UIListLayout", Content)
UIList.Padding = UDim.new(0, 6)
UIList.SortOrder = Enum.SortOrder.LayoutOrder

-- Функция создания Toggle
local function CreateToggle(text, key, callback)
    local Btn = Instance.new("TextButton")
    Btn.Size = UDim2.new(1, 0, 0, 30)
    Btn.BackgroundColor3 = Color3.fromRGB(35, 35, 45)
    Btn.TextColor3 = Color3.fromRGB(200, 200, 200)
    Btn.Font = Enum.Font.Gotham
    Btn.TextSize = 13
    Btn.Parent = Content
    Instance.new("UICorner", Btn).CornerRadius = UDim.new(0, 6)

    local function Update()
        Btn.Text = text .. (Settings[key] and " : ON" or " : OFF")
        Btn.BackgroundColor3 = Settings[key] and Color3.fromRGB(100, 50, 150) or Color3.fromRGB(35, 35, 45)
        Btn.TextColor3 = Settings[key] and Color3.fromRGB(255, 255, 255) or Color3.fromRGB(200, 200, 200)
    end

    Btn.MouseButton1Click:Connect(function()
        Settings[key] = not Settings[key]
        Update()
        if callback then callback(Settings[key]) end
    end)
    Update()
end

-- Функция создания Slider (через кнопку, чтобы не усложнять)
local function CreateSpeedBtn()
    local Btn = Instance.new("TextButton")
    Btn.Size = UDim2.new(1, 0, 0, 30)
    Btn.BackgroundColor3 = Color3.fromRGB(35, 35, 45)
    Btn.TextColor3 = Color3.fromRGB(200, 200, 200)
    Btn.Font = Enum.Font.Gotham
    Btn.TextSize = 13
    Btn.Text = "Скорость полета: " .. Settings.FlySpeed
    Btn.Parent = Content
    Instance.new("UICorner", Btn).CornerRadius = UDim.new(0, 6)

    Btn.MouseButton1Click:Connect(function()
        Settings.FlySpeed = Settings.FlySpeed + 10
        if Settings.FlySpeed > 100 then Settings.FlySpeed = 20 end
        Btn.Text = "Скорость полета: " .. Settings.FlySpeed
    end)
end

CreateToggle("🪙 Включить автофарм", "FarmEnabled", function(val)
    if val then
        collectedCount = 0
        VisitedCoins = {}
        startFarm()
        startRoleLogic()
    else
        if CurrentTween then CurrentTween:Cancel() end
    end
end)
CreateSpeedBtn()

CreateToggle("🔫 Подбор пистолета (Невиновный)", "AutoGun")
CreateToggle("🎯 Стрельба в убийцу (Шериф)", "AutoShoot")
CreateToggle("🔪 Убить всех (Убийца/Зомби)", "KillAll")
CreateToggle("🧲 Магнит (Инфекция)", "Magnet")

CreateToggle("👻 Noclip", "Noclip")
CreateToggle("🧊 Пластиковый мир (FPS)", "PlasticMode", function(val)
    if val then
        for _, obj in pairs(Workspace:GetDescendants()) do
            if obj:IsA("BasePart") then obj.Material = Enum.Material.Plastic end
        end
    end
end)

-- ==========================================
-- 4. ОПРЕДЕЛЕНИЕ РОЛЕЙ (От ELITE)
-- ==========================================
local function getRole()
    local hasKnife, hasGun = false, false
    
    -- Проверяем рюкзак и руки
    for _, tool in ipairs(LocalPlayer.Backpack:GetChildren()) do
        local n = string.lower(tool.Name)
        if n:find("knife") then hasKnife = true end
        if n:find("gun") or n:find("revolver") then hasGun = true end
    end
    local char = LocalPlayer.Character
    if char then
        for _, tool in ipairs(char:GetChildren()) do
            if tool:IsA("Tool") then
                local n = string.lower(tool.Name)
                if n:find("knife") then hasKnife = true end
                if n:find("gun") or n:find("revolver") then hasGun = true end
            end
        end
    end

    -- Считаем врагов для определения режима (Инфекция)
    local totalKnives = 0
    local totalGuns = 0
    for _, plr in ipairs(Players:GetPlayers()) do
        if plr.Backpack then
            if plr.Backpack:FindFirstChild("Knife") then totalKnives = totalKnives + 1 end
            if plr.Backpack:FindFirstChild("Gun") then totalGuns = totalGuns + 1 end
        end
    end
    isInfection = (totalKnives >= 2 or totalGuns >= 2)

    if hasKnife then
        currentRole = isInfection and "Zombie" or "Murderer"
    elseif hasGun then
        currentRole = isInfection and "Survivor" or "Sheriff"
    else
        currentRole = "Innocent"
    end
end

-- ==========================================
-- 5. ДВИГАТЕЛЬ PROTO (Поиск и Tween)
-- ==========================================
local function getMap()
    for _, v in pairs(Workspace:GetDescendants()) do
        if v.Name == "Spawns" and v.Parent.Name ~= "Lobby" then return v.Parent end
    end
    return nil
end

local function getCoinContainer()
    local map = getMap()
    if not map then return nil end
    return map:FindFirstChild("CoinContainer") or map:FindFirstChild("CandyContainer")
end

function startFarm()
    if AutoFarmThread then task.cancel(AutoFarmThread) end
    AutoFarmThread = task.spawn(function()
        while Settings.FarmEnabled do
            local container = getCoinContainer()
            local char = LocalPlayer.Character
            local hrp = char and char:FindFirstChild("HumanoidRootPart")
            
            if container and hrp then
                local nearestPart, nearestItem, shortestDist = nil, nil, math.huge
                
                for _, item in ipairs(container:GetChildren()) do
                    if not VisitedCoins[item] then
                        local part = item:FindFirstChild("CoinVisual") or item
                        if part and part:IsA("BasePart") and part.Transparency < 0.5 then
                            local dist = (hrp.Position - part.Position).Magnitude
                            if dist < shortestDist and dist < 300 then
                                shortestDist = dist
                                nearestPart = part
                                nearestItem = item
                            end
                        end
                    end
                end

                if nearestPart then
                    local duration = math.clamp(shortestDist / Settings.FlySpeed, 0.05, 3)
                    CurrentTween = TweenService:Create(hrp, TweenInfo.new(duration, Enum.EasingStyle.Linear), {
                        CFrame = CFrame.new(nearestPart.Position)
                    })
                    CurrentTween:Play()
                    
                    task.wait(duration + 0.1) -- Ждем долета
                    VisitedCoins[nearestItem] = true
                    collectedCount = collectedCount + 1
                    task.wait(0.1) -- Задержка на сбор
                else
                    task.wait(0.5) -- Ждем появления монет
                end
            else
                task.wait(0.5) -- Ждем загрузки карты
            end
        end
    end)
end

-- ==========================================
-- 6. ЛОГИКА РОЛЕЙ (Твои фишки)
-- ==========================================
function startRoleLogic()
    if RoleLogicThread then task.cancel(RoleLogicThread) end
    RoleLogicThread = task.spawn(function()
        while Settings.FarmEnabled do
            task.wait(0.5)
            getRole() -- Обновляем роль
            
            -- Если нафармили лимит, начинаем действовать
            if collectedCount >= Settings.CoinLimit then
                
                -- 1. УБИЙЦА / ЗОМБИ (Магнит)
                if (currentRole == "Murderer" or currentRole == "Zombie") and Settings.KillAll then
                    for _, plr in pairs(Players:GetPlayers()) do
                        if plr ~= LocalPlayer and plr.Character and plr.Character:FindFirstChild("HumanoidRootPart") then
                            LocalPlayer.Character.HumanoidRootPart.CFrame = plr.Character.HumanoidRootPart.CFrame
                            task.wait(0.05)
                            VirtualUser:Button1Down(Vector2.new(0,0), workspace.CurrentCamera.CFrame)
                            VirtualUser:Button1Up(Vector2.new(0,0), workspace.CurrentCamera.CFrame)
                            task.wait(0.2)
                        end
                    end
                end
                
                -- 2. ШЕРИФ
                if currentRole == "Sheriff" and Settings.AutoShoot then
                    for _, plr in pairs(Players:GetPlayers()) do
                        if plr.Backpack and plr.Backpack:FindFirstChild("Knife") and plr.Character then
                            LocalPlayer.Character.HumanoidRootPart.CFrame = CFrame.new(LocalPlayer.Character.HumanoidRootPart.Position, plr.Character.HumanoidRootPart.Position)
                            task.wait(0.1)
                            VirtualUser:Button1Down(Vector2.new(0,0), workspace.CurrentCamera.CFrame)
                            VirtualUser:Button1Up(Vector2.new(0,0), workspace.CurrentCamera.CFrame)
                        end
                    end
                end
                
                -- 3. НЕВИНОВНЫЙ (Пистолет)
                if currentRole == "Innocent" and Settings.AutoGun then
                    local gunDrop = Workspace:FindFirstChild("Normal") and Workspace.Normal:FindFirstChild("GunDrop")
                    if gunDrop then
                        LocalPlayer.Character.HumanoidRootPart.CFrame = gunDrop.CFrame
                        task.wait(0.2)
                        -- Подобрали, стреляем
                        for _, plr in pairs(Players:GetPlayers()) do
                            if plr.Backpack and plr.Backpack:FindFirstChild("Knife") and plr.Character then
                                LocalPlayer.Character.HumanoidRootPart.CFrame = CFrame.new(LocalPlayer.Character.HumanoidRootPart.Position, plr.Character.HumanoidRootPart.Position)
                                VirtualUser:Button1Down(Vector2.new(0,0), workspace.CurrentCamera.CFrame)
                                VirtualUser:Button1Up(Vector2.new(0,0), workspace.CurrentCamera.CFrame)
                            end
                        end
                    end
                end
                
                -- 4. ВЫЖИВШИЙ (Инфекция - заразиться)
                if currentRole == "Survivor" then
                    for _, plr in pairs(Players:GetPlayers()) do
                        if plr.Backpack and plr.Backpack:FindFirstChild("Knife") and plr.Character then
                            LocalPlayer.Character.HumanoidRootPart.CFrame = plr.Character.HumanoidRootPart.CFrame
                            task.wait(0.5)
                            break
                        end
                    end
                end
            end
        end
    end)
end

-- ==========================================
-- 7. ФИЗИКА И NOCLIP (PROTO)
-- ==========================================
RunService.Stepped:Connect(function()
    if Settings.FarmEnabled and LocalPlayer.Character then
        local hrp = LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
        if hrp then
            hrp.Velocity = Vector3.zero
            hrp.RotVelocity = Vector3.zero
        end
        
        if Settings.Noclip then
            for _, part in ipairs(LocalPlayer.Character:GetDescendants()) do
                if part:IsA("BasePart") then part.CanCollide = false end
            end
        end
    end
end)

print("[Iroshida v7.0] Загружен! Все системы в норме.")
