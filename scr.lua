-- ==========================================
-- IROSHIDA v5.0 (PROTO Engine)
-- Script made by Nick9l
-- ==========================================

if not game:IsLoaded() then game.Loaded:Wait() end

local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local RunService = game:GetService("RunService")
local LocalPlayer = Players.LocalPlayer

local Settings = {
    FarmCoins = false,
    FarmCandy = false,
    TweenSpeed = 50,
    Noclip = true
}

local CurrentTween = nil
local VisitedCoins = {}

-- ==========================================
-- 1. Загрузочный экран
-- ==========================================
local Splash = Instance.new("ScreenGui")
Splash.Parent = LocalPlayer:WaitForChild("PlayerGui")
Splash.IgnoreGuiInset = true

local SplashText = Instance.new("TextLabel")
SplashText.Parent = Splash
SplashText.Size = UDim2.new(1, 0, 1, 0)
SplashText.BackgroundColor3 = Color3.fromRGB(15, 15, 15)
SplashText.Text = "Привет."
SplashText.TextColor3 = Color3.fromRGB(255, 255, 255)
SplashText.Font = Enum.Font.SourceSansBold
SplashText.TextSize = 40

task.wait(1)
SplashText.Text = "Iroshida | made by Nick9l"
task.wait(1)
Splash:Destroy()

-- ==========================================
-- 2. Интерфейс (Легкий, без Linoria)
-- ==========================================
local ScreenGui = Instance.new("ScreenGui")
ScreenGui.Name = "Iroshida_UI"
ScreenGui.ResetOnSpawn = false
ScreenGui.Parent = LocalPlayer:WaitForChild("PlayerGui")

local MainFrame = Instance.new("Frame")
MainFrame.Size = UDim2.new(0, 220, 0, 180)
MainFrame.Position = UDim2.new(0.5, -110, 0.3, 0)
MainFrame.BackgroundColor3 = Color3.fromRGB(25, 25, 30)
MainFrame.Active = true
MainFrame.Draggable = true
MainFrame.Parent = ScreenGui
Instance.new("UICorner", MainFrame).CornerRadius = UDim.new(0, 8)

local Title = Instance.new("TextLabel")
Title.Size = UDim2.new(1, 0, 0, 35)
Title.BackgroundColor3 = Color3.fromRGB(40, 40, 50)
Title.Text = "Iroshida | AutoFarm"
Title.TextColor3 = Color3.fromRGB(255, 255, 255)
Title.Font = Enum.Font.GothamBold
Title.Parent = MainFrame
Instance.new("UICorner", Title).CornerRadius = UDim.new(0, 8)

local Content = Instance.new("Frame")
Content.Size = UDim2.new(1, -20, 1, -45)
Content.Position = UDim2.new(0, 10, 0, 40)
Content.BackgroundTransparency = 1
Content.Parent = MainFrame
Instance.new("UIListLayout", Content).Padding = UDim.new(0, 5)

local function CreateToggle(text, key)
    local Btn = Instance.new("TextButton")
    Btn.Size = UDim2.new(1, 0, 0, 35)
    Btn.BackgroundColor3 = Color3.fromRGB(50, 50, 60)
    Btn.TextColor3 = Color3.fromRGB(255, 255, 255)
    Btn.Font = Enum.Font.Gotham
    Btn.TextSize = 14
    Btn.Parent = Content
    Instance.new("UICorner", Btn).CornerRadius = UDim.new(0, 6)

    local function Update()
        Btn.Text = text .. (Settings[key] and " : ON" or " : OFF")
        Btn.BackgroundColor3 = Settings[key] and Color3.fromRGB(0, 150, 0) or Color3.fromRGB(50, 50, 60)
    end

    Btn.MouseButton1Click:Connect(function()
        Settings[key] = not Settings[key]
        Update()
        if not Settings[key] and CurrentTween then
            CurrentTween:Cancel()
            CurrentTween = nil
        end
    end)
    Update()
end

CreateToggle("🪙 Фарм Монет", "FarmCoins")
CreateToggle("🍬 Фарм Конфет", "FarmCandy")
CreateToggle("👻 Noclip", "Noclip")

local SpeedBtn = Instance.new("TextButton")
SpeedBtn.Size = UDim2.new(1, 0, 0, 35)
SpeedBtn.BackgroundColor3 = Color3.fromRGB(50, 50, 60)
SpeedBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
SpeedBtn.Text = "Скорость: 50"
SpeedBtn.Font = Enum.Font.Gotham
SpeedBtn.Parent = Content
Instance.new("UICorner", SpeedBtn).CornerRadius = UDim.new(0, 6)

SpeedBtn.MouseButton1Click:Connect(function()
    Settings.TweenSpeed = Settings.TweenSpeed + 10
    if Settings.TweenSpeed > 100 then Settings.TweenSpeed = 20 end
    SpeedBtn.Text = "Скорость: " .. Settings.TweenSpeed
end)

-- ==========================================
-- 3. Двигатель PROTO (Killer Physics)
-- ==========================================
RunService.Stepped:Connect(function()
    if (Settings.FarmCoins or Settings.FarmCandy) and LocalPlayer.Character then
        local rootPart = LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
        if rootPart then
            -- Убиваем физику (чтобы не дергало)
            rootPart.Velocity = Vector3.zero
            rootPart.RotVelocity = Vector3.zero
        end
        if Settings.Noclip then
            for _, part in ipairs(LocalPlayer.Character:GetDescendants()) do
                if part:IsA("BasePart") and part.CanCollide then
                    part.CanCollide = false
                end
            end
        end
    end
end)

-- ==========================================
-- 4. Поиск и полет (PROTO Logic)
-- ==========================================
local function FindCoinContainer()
    for _, child in ipairs(workspace:GetChildren()) do
        local container = child:FindFirstChild("CoinContainer") or child:FindFirstChild("CandyContainer")
        if container then return container end
    end
    return workspace:FindFirstChild("CoinContainer", true) or workspace:FindFirstChild("CandyContainer", true)
end

local function GetValidCoinPart(item)
    if VisitedCoins[item] then return nil end
    
    local visual = item:FindFirstChild("CoinVisual") or item
    if visual and visual:IsA("BasePart") then
        if visual.Transparency > 0.5 then return nil end -- Монета уже собрана
        return visual
    end
    return nil
end

local function GetNearestCollectible(container)
    local character = LocalPlayer.Character
    local rootPart = character and character:FindFirstChild("HumanoidRootPart")
    if not rootPart or not container then return nil, nil, nil end

    local nearestPart, nearestItem, shortestDist = nil, nil, math.huge

    for _, item in ipairs(container:GetChildren()) do
        local targetPart = GetValidCoinPart(item)
        if targetPart then
            local dist = (rootPart.Position - targetPart.Position).Magnitude
            if dist < shortestDist and dist < 300 then
                shortestDist = dist
                nearestPart = targetPart
                nearestItem = item
            end
        end
    end
    return nearestPart, nearestItem, shortestDist
end

task.spawn(function()
    while task.wait(0.1) do
        if Settings.FarmCoins or Settings.FarmCandy then
            local character = LocalPlayer.Character
            local rootPart = character and character:FindFirstChild("HumanoidRootPart")
            local humanoid = character and character:FindFirstChildOfClass("Humanoid")
            local container = FindCoinContainer()

            if rootPart and humanoid and humanoid.Health > 0 and container then
                local targetPart, targetItem, dist = GetNearestCollectible(container)
                if targetPart and targetItem and dist then
                    
                    -- Считаем время полета
                    local duration = math.clamp(dist / Settings.TweenSpeed, 0.05, 5)
                    
                    -- Создаем анимацию полета
                    CurrentTween = TweenService:Create(rootPart, TweenInfo.new(duration, Enum.EasingStyle.Linear), {
                        CFrame = CFrame.new(targetPart.Position)
                    })
                    CurrentTween:Play()

                    -- Ждем, пока долетим (или пока монета не исчезнет)
                    local startTime = tick()
                    while CurrentTween and CurrentTween.PlaybackState == Enum.PlaybackState.Playing do
                        if not (Settings.FarmCoins or Settings.FarmCandy) then
                            CurrentTween:Cancel()
                            break
                        end
                        -- Если монета исчезла или стала прозрачной
                        if not targetItem.Parent or targetPart.Transparency > 0.5 or (tick() - startTime) > (duration + 0.5) then
                            CurrentTween:Cancel()
                            break
                        end
                        task.wait(0.05)
                    end

                    -- Защита от повторного сбора
                    VisitedCoins[targetItem] = true
                    task.delay(3, function() VisitedCoins[targetItem] = nil end)
                    
                    -- Задержка, чтобы сервер засчитал
                    task.wait(0.12)
                end
            else
                VisitedCoins = {}
            end
        end
    end
end)

print("[Iroshida v5.0] PROTO Engine Loaded!")
