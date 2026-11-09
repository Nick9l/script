-- ==========================================
-- IROSHIDA v9.0 (Ultimate Stable Build)
-- Engine: PROTO | Logic: ELITE + Custom
-- ==========================================

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
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
    FlySpeed = 30,
    Radius = 80,
    Noclip = true,
    
    AutoGun = true,
    AutoShoot = true,
    KillAll = true,
    Magnet = true,
    
    YProtect = true,
    MinY = -50,
    MaxY = 500,
    ShowTracer = false,
    
    PlasticMode = false,
    KillShadows = false,
    KillLight = false
}

local CurrentTween = nil
local VisitedCoins = {}
local AutoFarmThread = nil
local RoleLogicThread = nil
local currentRole = "Innocent"
local collectedCount = 0
local originalMaterials = {}
local tracerLine = nil

-- Безопасное создание линии для трассера
if Drawing then
    local ok, obj = pcall(function() return Drawing.new("Line") end)
    if ok then
        tracerLine = obj
        tracerLine.Thickness = 1.5
        tracerLine.Color = Color3.fromRGB(180, 100, 255)
        tracerLine.Transparency = 0.5
        tracerLine.Visible = false
    end
end

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
SplashText.Text = "Iroshida v9.0"
task.wait(1)
Splash:Destroy()

-- ==========================================
-- 3. ЛОГИКА РОЛЕЙ
-- ==========================================
local function getRole()
    local hasKnife, hasGun = false, false
    local backpack = LocalPlayer:FindFirstChild("Backpack")
    if backpack then
        for _, tool in ipairs(backpack:GetChildren()) do
            local n = string.lower(tool.Name)
            if n:find("knife") or n:find("blade") then hasKnife = true end
            if n:find("gun") or n:find("revolver") then hasGun = true end
        end
    end
    local char = LocalPlayer.Character
    if char then
        for _, tool in ipairs(char:GetChildren()) do
            if tool:IsA("Tool") then
                local n = string.lower(tool.Name)
                if n:find("knife") or n:find("blade") then hasKnife = true end
                if n:find("gun") or n:find("revolver") then hasGun = true end
            end
        end
        -- Проверка атрибутов (как в ELITE)
        local roleAttr = char:GetAttribute("Role") or LocalPlayer:GetAttribute("Role")
        if roleAttr then
            local l = string.lower(tostring(roleAttr))
            if l:find("murder") then hasKnife = true end
            if l:find("sheriff") then hasGun = true end
        end
    end

    if hasKnife then currentRole = "Murderer"
    elseif hasGun then currentRole = "Sheriff"
    else currentRole = "Innocent" end
end

-- ==========================================
-- 4. ФАРМ (С проверкой TouchTransmitter)
-- ==========================================
local function getCoinContainer()
    local normal = Workspace:FindFirstChild("Normal")
    if normal then
        return normal:FindFirstChild("CoinContainer") or normal:FindFirstChild("CandyContainer")
    end
    return nil
end

local function startFarm()
    if AutoFarmThread then task.cancel(AutoFarmThread) end
    AutoFarmThread = task.spawn(function()
        local cachedContainer = nil
        
        while Settings.FarmEnabled do
            -- Обновляем контейнер, если он пропал
            if not cachedContainer or not cachedContainer.Parent then
                cachedContainer = getCoinContainer()
            end

            local char = LocalPlayer.Character
            local hrp = char and char:FindFirstChild("HumanoidRootPart")

            if cachedContainer and hrp then
                local nearestPart, nearestItem, shortestDist = nil, nil, math.huge
                
                for _, item in ipairs(cachedContainer:GetChildren()) do
                    if not VisitedCoins[item] then
                        -- ГЛАВНАЯ ПРОВЕРКА: есть ли TouchTransmitter?
                        local touch = item:FindFirstChildWhichIsA("TouchTransmitter")
                        if touch then
                            local part = item:FindFirstChild("CoinVisual") or item
                            if part and part:IsA("BasePart") then
                                -- Проверка Y (защита от фантомов)
                                local posY = part.Position.Y
                                local yValid = true
                                if Settings.YProtect then
                                    if posY < Settings.MinY or posY > Settings.MaxY then
                                        yValid = false
                                    end
                                end
                                
                                if yValid then
                                    local dist = (hrp.Position - part.Position).Magnitude
                                    if dist <= Settings.Radius and dist < shortestDist then
                                        shortestDist = dist
                                        nearestPart = part
                                        nearestItem = item
                                    end
                                end
                            end
                        else
                            -- Монета уже собрана (кем-то другим)
                            VisitedCoins[item] = true
                        end
                    end
                end

                if nearestPart then
                    -- Линия к цели (Tracer)
                    if Settings.ShowTracer and tracerLine then
                        tracerLine.From = Vector2.new(Workspace.CurrentCamera.ViewportSize.X / 2, Workspace.CurrentCamera.ViewportSize.Y)
                        local screenPoint, onScreen = Workspace.CurrentCamera:WorldToViewportPoint(nearestPart.Position)
                        if onScreen then
                            tracerLine.To = Vector2.new(screenPoint.X, screenPoint.Y)
                            tracerLine.Visible = true
                        end
                    end

                    local duration = math.clamp(shortestDist / Settings.FlySpeed, 0.05, 3)
                    CurrentTween = TweenService:Create(hrp, TweenInfo.new(duration, Enum.EasingStyle.Linear), {CFrame = CFrame.new(nearestPart.Position)})
                    CurrentTween:Play()
                    
                    task.wait(duration + 0.1)
                    
                    if tracerLine then tracerLine.Visible = false end
                    
                    VisitedCoins[nearestItem] = true
                    collectedCount = collectedCount + 1
                    task.wait(0.1)
                else 
                    if tracerLine then tracerLine.Visible = false end
                    task.wait(0.5) -- Ждем появления монет
                end
            else 
                task.wait(0.5) 
            end
        end
        if tracerLine then tracerLine.Visible = false end
    end)
end

-- ==========================================
-- 5. ЛОГИКА ДЕЙСТВИЙ ПО РОЛЯМ
-- ==========================================
local function startRoleLogic()
    if RoleLogicThread then task.cancel(RoleLogicThread) end
    RoleLogicThread = task.spawn(function()
        while Settings.FarmEnabled do
            task.wait(0.5)
            getRole()
            
            if collectedCount >= Settings.CoinLimit then
                -- 1. УБИЙЦА
                if currentRole == "Murderer" and Settings.KillAll then
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
            end
        end
    end)
end

-- ==========================================
-- 6. UI (Вкладки, Тумблеры, Слайдеры)
-- ==========================================
local ScreenGui = Instance.new("ScreenGui")
ScreenGui.Name = "Iroshida_UI"
ScreenGui.ResetOnSpawn = false
ScreenGui.Parent = LocalPlayer:WaitForChild("PlayerGui")

local MainFrame = Instance.new("Frame")
MainFrame.Size = UDim2.new(0, 420, 0, 320)
MainFrame.Position = UDim2.new(0.5, -210, 0.5, -160)
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
Title.Position = UDim2.new(0, 15, 0, 0)
Title.BackgroundTransparency = 1
Title.Text = "Iroshida | v9.0"
Title.TextColor3 = Color3.fromRGB(180, 100, 255)
Title.Font = Enum.Font.GothamBold
Title.TextSize = 14
Title.TextXAlignment = Enum.TextXAlignment.Left
Title.Parent = TitleBar

local TabBar = Instance.new("Frame")
TabBar.Size = UDim2.new(0, 110, 1, -40)
TabBar.Position = UDim2.new(0, 0, 0, 35)
TabBar.BackgroundColor3 = Color3.fromRGB(25, 25, 30)
TabBar.Parent = MainFrame
Instance.new("UICorner", TabBar).CornerRadius = UDim.new(0, 10)
Instance.new("UIListLayout", TabBar).Padding = UDim.new(0, 5)

local Content = Instance.new("Frame")
Content.Size = UDim2.new(1, -120, 1, -45)
Content.Position = UDim2.new(0, 115, 0, 40)
Content.BackgroundTransparency = 1
Content.Parent = MainFrame

local Pages = {}
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
    Page.AutomaticCanvasSize = Enum.AutomaticSize.Y
    Page.ScrollBarThickness = 0
    Page.Parent = Content
    Instance.new("UIListLayout", Page).Padding = UDim.new(0, 6)

    Pages[name] = Page

    TabBtn.MouseButton1Click:Connect(function()
        for _, p in pairs(Pages) do p.Visible = false end
        Page.Visible = true
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

local function AddSlider(parent, text, min, max, default, callback)
    local SliderFrame = Instance.new("Frame")
    SliderFrame.Size = UDim2.new(1, 0, 0, 40)
    SliderFrame.BackgroundColor3 = Color3.fromRGB(35, 35, 45)
    SliderFrame.Parent = parent
    Instance.new("UICorner", SliderFrame).CornerRadius = UDim.new(0, 6)

    local Label = Instance.new("TextLabel")
    Label.Size = UDim2.new(1, -10, 0, 15)
    Label.Position = UDim2.new(0, 5, 0, 3)
    Label.BackgroundTransparency = 1
    Label.Text = text .. ": " .. default
    Label.TextColor3 = Color3.fromRGB(200, 200, 200)
    Label.Font = Enum.Font.Gotham
    Label.TextSize = 12
    Label.TextXAlignment = Enum.TextXAlignment.Left
    Label.Parent = SliderFrame

    local Bar = Instance.new("Frame")
    Bar.Size = UDim2.new(1, -10, 0, 8)
    Bar.Position = UDim2.new(0, 5, 0, 22)
    Bar.BackgroundColor3 = Color3.fromRGB(50, 50, 60)
    Bar.Parent = SliderFrame
    Instance.new("UICorner", Bar).CornerRadius = UDim.new(0, 4)

    local Fill = Instance.new("Frame")
    Fill.Size = UDim2.new((default - min) / (max - min), 0, 1, 0)
    Fill.BackgroundColor3 = Color3.fromRGB(100, 50, 150)
    Fill.Parent = Bar
    Instance.new("UICorner", Fill).CornerRadius = UDim.new(0, 4)

    local Knob = Instance.new("Frame")
    Knob.Size = UDim2.new(0, 14, 0, 14)
    Knob.Position = UDim2.new((default - min) / (max - min), -7, 0.5, -7)
    Knob.BackgroundColor3 = Color3.fromRGB(180, 100, 255)
    Knob.Parent = Bar
    Instance.new("UICorner", Knob).CornerRadius = UDim.new(1, 0)

    local dragging = false
    Bar.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            dragging = true
        end
    end)
    UserInputService.InputEnded:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            dragging = false
        end
    end)
    UserInputService.InputChanged:Connect(function(input)
        if dragging and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
            local mouseX = input.Position.X
            local barPos = Bar.AbsolutePosition.X
            local barSize = Bar.AbsoluteSize.X
            local percent = math.clamp((mouseX - barPos) / barSize, 0, 1)
            local value = math.floor(min + (max - min) * percent)
            Fill.Size = UDim2.new(percent, 0, 1, 0)
            Knob.Position = UDim2.new(percent, -7, 0.5, -7)
            Label.Text = text .. ": " .. value
            if callback then callback(value) end
        end
    end)
end

-- Создание вкладок
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
AddSlider(FarmPage, "Скорость полета", 10, 50, Settings.FlySpeed, function(val) Settings.FlySpeed = val end)
AddSlider(FarmPage, "Радиус поиска", 20, 150, Settings.Radius, function(val) Settings.Radius = val end)
AddToggle(FarmPage, "Защита от фантомов (Y)", "YProtect")
AddSlider(FarmPage, "Нижний порог Y", -100, 0, Settings.MinY, function(val) Settings.MinY = val end)
AddSlider(FarmPage, "Верхний порог Y", 100, 1000, Settings.MaxY, function(val) Settings.MaxY = val end)
AddToggle(FarmPage, "Показывать линию к цели", "ShowTracer")

local RolePage = CreateTab("Роли", "🎭")
AddToggle(RolePage, "Подбор пистолета (Невиновный)", "AutoGun")
AddToggle(RolePage, "Стрельба в убийцу (Шериф)", "AutoShoot")
AddToggle(RolePage, "Убить всех (Убийца)", "KillAll")

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

local SetPage = CreateTab("Настройки", "🛠")
AddToggle(SetPage, "Noclip", "Noclip")

-- Активация первой вкладки
Pages["AutoFarm"].Visible = true
for _, child in ipairs(TabBar:GetChildren()) do
    if child:IsA("TextButton") and string.find(child.Text, "AutoFarm") then
        child.BackgroundColor3 = Color3.fromRGB(100, 50, 150)
        child.TextColor3 = Color3.fromRGB(255, 255, 255)
    end
end

-- ==========================================
-- 7. ФИЗИКА И NOCLIP
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

print("[Iroshida v9.0] Загружен! Готов к работе.")
