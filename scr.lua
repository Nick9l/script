-- ==========================================
-- IROSHIDA v8.0 (Modern UI Build)
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
-- 1. НАСТРОЙКИ
-- ==========================================
local Settings = {
    FarmEnabled = false,
    CoinLimit = 50,
    FlySpeed = 40,
    Noclip = true,
    
    AutoGun = true,
    AutoShoot = true,
    KillAll = true,
    Magnet = true,
    
    PlasticMode = false,
    KillShadows = false,
    KillLight = false,
    GreySky = false
}

local CurrentTween = nil
local VisitedCoins = {}
local AutoFarmThread = nil
local RoleLogicThread = nil
local currentRole = "Innocent"
local isInfection = false
local collectedCount = 0
local originalMaterials = {}

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
SplashText.Text = "Iroshida v8.0"
task.wait(1)
Splash:Destroy()

-- ==========================================
-- 3. СОВРЕМЕННЫЙ UI (Вкладки)
-- ==========================================
local ScreenGui = Instance.new("ScreenGui")
ScreenGui.Name = "Iroshida_UI"
ScreenGui.ResetOnSpawn = false
ScreenGui.Parent = LocalPlayer:WaitForChild("PlayerGui")

local MainFrame = Instance.new("Frame")
MainFrame.Size = UDim2.new(0, 400, 0, 300)
MainFrame.Position = UDim2.new(0.5, -200, 0.5, -150)
MainFrame.BackgroundColor3 = Color3.fromRGB(20, 20, 25)
MainFrame.BorderSizePixel = 0
MainFrame.Active = true
MainFrame.Draggable = true
MainFrame.Parent = ScreenGui
Instance.new("UICorner", MainFrame).CornerRadius = UDim.new(0, 10)

-- Заголовок
local TitleBar = Instance.new("Frame")
TitleBar.Size = UDim2.new(1, 0, 0, 35)
TitleBar.BackgroundColor3 = Color3.fromRGB(30, 30, 40)
TitleBar.Parent = MainFrame
Instance.new("UICorner", TitleBar).CornerRadius = UDim.new(0, 10)

local Title = Instance.new("TextLabel")
Title.Size = UDim2.new(1, -20, 1, 0)
Title.Position = UDim2.new(0, 15, 0, 0)
Title.BackgroundTransparency = 1
Title.Text = "Iroshida | v8.0"
Title.TextColor3 = Color3.fromRGB(180, 100, 255)
Title.Font = Enum.Font.GothamBold
Title.TextSize = 14
Title.TextXAlignment = Enum.TextXAlignment.Left
Title.Parent = TitleBar

-- Панель вкладок (слева)
local TabBar = Instance.new("Frame")
TabBar.Size = UDim2.new(0, 100, 1, -40)
TabBar.Position = UDim2.new(0, 0, 0, 35)
TabBar.BackgroundColor3 = Color3.fromRGB(25, 25, 30)
TabBar.Parent = MainFrame
Instance.new("UICorner", TabBar).CornerRadius = UDim.new(0, 10)

local TabList = Instance.new("UIListLayout", TabBar)
TabList.Padding = UDim.new(0, 5)
TabList.SortOrder = Enum.SortOrder.LayoutOrder

-- Контент (справа)
local Content = Instance.new("Frame")
Content.Size = UDim2.new(1, -110, 1, -45)
Content.Position = UDim2.new(0, 105, 0, 40)
Content.BackgroundTransparency = 1
Content.Parent = MainFrame

-- Хранилище страниц
local Pages = {}
local ActivePage = nil

-- Функция создания вкладки
local function CreateTab(name, iconText)
    local TabBtn = Instance.new("TextButton")
    TabBtn.Size = UDim2.new(1, -10, 0, 30)
    TabBtn.Position = UDim2.new(0, 5, 0, 0)
    TabBtn.BackgroundColor3 = Color3.fromRGB(35, 35, 45)
    TabBtn.TextColor3 = Color3.fromRGB(180, 180, 180)
    TabBtn.Font = Enum.Font.GothamBold
    TabBtn.TextSize = 12
    TabBtn.Text = iconText .. " " .. name
    TabBtn.Parent = TabBar
    Instance.new("UICorner", TabBtn).CornerRadius = UDim.new(0, 6)

    local Page = Instance.new("ScrollingFrame")
    Page.Size = UDim2.new(1, 0, 1, 0)
    Page.BackgroundTransparency = 1
    Page.Visible = false
    Page.CanvasSize = UDim2.new(0, 0, 0, 0)
    Page.ScrollBarThickness = 0
    Page.Parent = Content
    
    local PageList = Instance.new("UIListLayout", Page)
    PageList.Padding = UDim.new(0, 6)
    PageList.SortOrder = Enum.SortOrder.LayoutOrder

    Pages[name] = Page

    TabBtn.MouseButton1Click:Connect(function()
        for _, p in pairs(Pages) do p.Visible = false end
        Page.Visible = true
        ActivePage = Page
        
        for _, child in ipairs(TabBar:GetChildren()) do
            if child:IsA("TextButton") then
                child.BackgroundColor3 = Color3.fromRGB(35, 35, 45)
                child.TextColor3 = Color3.fromRGB(180, 180, 180)
            end
        end
        TabBtn.BackgroundColor3 = Color3.fromRGB(100, 50, 150)
        TabBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
    end)
    
    return Page
end

-- Вспомогательные функции для UI
local function AddToggle(parent, text, key, callback)
    local Btn = Instance.new("TextButton")
    Btn.Size = UDim2.new(1, 0, 0, 32)
    Btn.BackgroundColor3 = Color3.fromRGB(35, 35, 45)
    Btn.TextColor3 = Color3.fromRGB(200, 200, 200)
    Btn.Font = Enum.Font.Gotham
    Btn.TextSize = 13
    Btn.Text = text .. (Settings[key] and " : ON" or " : OFF")
    Btn.Parent = parent
    Instance.new("UICorner", Btn).CornerRadius = UDim.new(0, 6)

    local function Update()
        Btn.Text = text .. (Settings[key] and " : ON" or " : OFF")
        Btn.BackgroundColor3 = Settings[key] and Color3.fromRGB(80, 50, 120) or Color3.fromRGB(35, 35, 45)
    end

    Btn.MouseButton1Click:Connect(function()
        Settings[key] = not Settings[key]
        Update()
        if callback then callback(Settings[key]) end
    end)
    Update()
end

local function AddSpeedButton(parent)
    local Btn = Instance.new("TextButton")
    Btn.Size = UDim2.new(1, 0, 0, 32)
    Btn.BackgroundColor3 = Color3.fromRGB(35, 35, 45)
    Btn.TextColor3 = Color3.fromRGB(200, 200, 200)
    Btn.Font = Enum.Font.Gotham
    Btn.TextSize = 13
    Btn.Text = "Скорость полета: " .. Settings.FlySpeed
    Btn.Parent = parent
    Instance.new("UICorner", Btn).CornerRadius = UDim.new(0, 6)

    Btn.MouseButton1Click:Connect(function()
        Settings.FlySpeed = Settings.FlySpeed + 10
        if Settings.FlySpeed > 100 then Settings.FlySpeed = 10 end
        Btn.Text = "Скорость полета: " .. Settings.FlySpeed
    end)
end

-- ==========================================
-- 4. СОЗДАНИЕ ВКЛАДОК И КНОПОК
-- ==========================================

-- Вкладка 1: Farm
local FarmPage = CreateTab("AutoFarm", "🪙")
AddToggle(FarmPage, "Включить автофарм", "FarmEnabled", function(val)
    if val then
        collectedCount = 0
        VisitedCoins = {}
        startFarm()
        startRoleLogic()
    else
        if CurrentTween then CurrentTween:Cancel() end
    end
end)
AddSpeedButton(FarmPage)

-- Вкладка 2: Roles
local RolePage = CreateTab("Роли", "🎭")
AddToggle(RolePage, "Подбор пистолета (Невиновный)", "AutoGun")
AddToggle(RolePage, "Стрельба в убийцу (Шериф)", "AutoShoot")
AddToggle(RolePage, "Убить всех (Убийца/Зомби)", "KillAll")
AddToggle(RolePage, "Магнит (Инфекция)", "Magnet")

-- Вкладка 3: Performance
local PerfPage = CreateTab("Графика", "⚙️")
AddToggle(PerfPage, "Пластиковый мир", "PlasticMode", function(val)
    if val then
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
end)
AddToggle(PerfPage, "Убрать тени", "KillShadows", function(val) Lighting.GlobalShadows = not val end)
AddToggle(PerfPage, "Убрать освещение", "KillLight", function(val)
    if val then
        Lighting.Ambient = Color3.new(0.5, 0.5, 0.5)
        Lighting.OutdoorAmbient = Color3.new(0.5, 0.5, 0.5)
        Lighting.Brightness = 1
        Lighting.ClockTime = 12
    else
        Lighting.Brightness = 2
    end
end)
AddToggle(PerfPage, "Серое небо", "GreySky", function(val)
    if val then
        local sky = Instance.new("Sky")
        sky.SkyboxBk = ""; sky.SkyboxDn = ""; sky.SkyboxFt = ""; sky.SkyboxLf = ""; sky.SkyboxRt = ""; sky.SkyboxUp = ""
        sky.Parent = Lighting
        Lighting.FogColor = Color3.new(0.5, 0.5, 0.5)
        Lighting.FogEnd = 10000
    else
        local sky = Lighting:FindFirstChildOfClass("Sky")
        if sky then sky:Destroy() end
    end
end)

-- Вкладка 4: Settings
local SetPage = CreateTab("Настройки", "🛠")
AddToggle(SetPage, "Noclip", "Noclip")

-- Автовыбор первой вкладки
for _, child in ipairs(TabBar:GetChildren()) do
    if child:IsA("TextButton") then
        child.MouseButton1Click:Fire() -- Активируем первую вкладку при загрузке (нужно вызвать событие)
        -- Обычный FireEvent не сработает для MouseButton1Click, сделаем вручную:
        break
    end
end
-- Принудительно открываем Farm
for _, p in pairs(Pages) do p.Visible = false end
Pages["AutoFarm"].Visible = true
for _, child in ipairs(TabBar:GetChildren()) do
    if child:IsA("TextButton") and string.find(child.Text, "AutoFarm") then
        child.BackgroundColor3 = Color3.fromRGB(100, 50, 150)
        child.TextColor3 = Color3.fromRGB(255, 255, 255)
    end
end

-- ==========================================
-- 5. ЛОГИКА (Без изменений, копия v7.0)
-- ==========================================
local function getRole()
    local hasKnife, hasGun = false, false
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
    local totalKnives, totalGuns = 0, 0
    for _, plr in ipairs(Players:GetPlayers()) do
        if plr.Backpack then
            if plr.Backpack:FindFirstChild("Knife") then totalKnives = totalKnives + 1 end
            if plr.Backpack:FindFirstChild("Gun") then totalGuns = totalGuns + 1 end
        end
    end
    isInfection = (totalKnives >= 2 or totalGuns >= 2)
    if hasKnife then currentRole = isInfection and "Zombie" or "Murderer"
    elseif hasGun then currentRole = isInfection and "Survivor" or "Sheriff"
    else currentRole = "Innocent" end
end

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
                                shortestDist = dist; nearestPart = part; nearestItem = item
                            end
                        end
                    end
                end
                if nearestPart then
                    local duration = math.clamp(shortestDist / Settings.FlySpeed, 0.05, 3)
                    CurrentTween = TweenService:Create(hrp, TweenInfo.new(duration, Enum.EasingStyle.Linear), {CFrame = CFrame.new(nearestPart.Position)})
                    CurrentTween:Play()
                    task.wait(duration + 0.1)
                    VisitedCoins[nearestItem] = true
                    collectedCount = collectedCount + 1
                    task.wait(0.1)
                else task.wait(0.5) end
            else task.wait(0.5) end
        end
    end)
end

function startRoleLogic()
    if RoleLogicThread then task.cancel(RoleLogicThread) end
    RoleLogicThread = task.spawn(function()
        while Settings.FarmEnabled do
            task.wait(0.5)
            getRole()
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
                -- 3. НЕВИНОВНЫЙ
                if currentRole == "Innocent" and Settings.AutoGun then
                    local gunDrop = Workspace:FindFirstChild("Normal") and Workspace.Normal:FindFirstChild("GunDrop")
                    if gunDrop then
                        LocalPlayer.Character.HumanoidRootPart.CFrame = gunDrop.CFrame
                        task.wait(0.2)
                        for _, plr in pairs(Players:GetPlayers()) do
                            if plr.Backpack and plr.Backpack:FindFirstChild("Knife") and plr.Character then
                                LocalPlayer.Character.HumanoidRootPart.CFrame = CFrame.new(LocalPlayer.Character.HumanoidRootPart.Position, plr.Character.HumanoidRootPart.Position)
                                VirtualUser:Button1Down(Vector2.new(0,0), workspace.CurrentCamera.CFrame)
                                VirtualUser:Button1Up(Vector2.new(0,0), workspace.CurrentCamera.CFrame)
                            end
                        end
                    end
                end
                -- 4. ВЫЖИВШИЙ
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

RunService.Stepped:Connect(function()
    if Settings.FarmEnabled and LocalPlayer.Character then
        local hrp = LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
        if hrp then hrp.Velocity = Vector3.zero; hrp.RotVelocity = Vector3.zero end
        if Settings.Noclip then
            for _, part in ipairs(LocalPlayer.Character:GetDescendants()) do
                if part:IsA("BasePart") then part.CanCollide = false end
            end
        end
    end
end)

print("[Iroshida v8.0] Загружен! Все системы в норме.")
