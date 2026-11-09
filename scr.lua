-- ==========================================
-- IROSHIDA v10.0
-- Engine: HYBRID (HappyHub farm/roles + ELITE ESP + PROTO config)
-- UI: свой (Iroshida v9)
-- ==========================================

local Players            = game:GetService("Players")
local RunService         = game:GetService("RunService")
local TweenService       = game:GetService("TweenService")
local UserInputService   = game:GetService("UserInputService")
local Workspace          = game:GetService("Workspace")
local Lighting           = game:GetService("Lighting")
local ReplicatedStorage  = game:GetService("ReplicatedStorage")
local HttpService        = game:GetService("HttpService")
local VirtualUser        = game:GetService("VirtualUser")

local LocalPlayer = Players.LocalPlayer
local Camera      = Workspace.CurrentCamera

if not game:IsLoaded() then game.Loaded:Wait() end

-- ==========================================
-- 1. CONFIG (PROTO)
-- ==========================================
local ConfigFile = "Iroshida_v10.json"
local AutoExecFile = "Iroshida_v10_auto.lua"

local Settings = {
    -- Farm
    FarmEnabled    = false,
    FarmSpeed      = 26,
    CoinLimit      = 50,
    AutoEvade      = true,
    EvadeRadius    = 22,

    -- Roles
    KillAll        = false,   -- Murderer: kill everyone
    AutoShoot      = false,   -- Sheriff: shoot murderer
    AutoGun        = false,   -- Innocent: grab gun

    -- Movement
    FlyEnabled     = false,
    FlySpeed       = 50,
    Noclip         = true,
    AntiVoid       = true,
    AntiAFK        = true,

    -- Visuals
    RoleESP        = false,
    CoinESP        = false,
    GunESP         = false,
    ShowTracer     = false,

    -- Performance
    PlasticMode    = false,
    KillShadows    = false,

    -- Meta
    AutoExec       = true,
}

local function SaveConfig()
    if not writefile then return end
    pcall(function()
        writefile(ConfigFile, HttpService:JSONEncode(Settings))
    end)
end

local function LoadConfig()
    if not (isfile and readfile and isfile(ConfigFile)) then return end
    pcall(function()
        local data = HttpService:JSONDecode(readfile(ConfigFile))
        if type(data) == "table" then
            for k, v in pairs(data) do
                if Settings[k] ~= nil then Settings[k] = v end
            end
        end
    end)
end

LoadConfig()

-- ==========================================
-- 2. AUTO-EXEC ON TELEPORT (PROTO)
-- ==========================================
local QueueTeleport = queue_on_teleport or (syn and syn.queue_on_teleport) or (fluxus and fluxus.queue_on_teleport)
if QueueTeleport then
    LocalPlayer.OnTeleport:Connect(function()
        if not Settings.AutoExec then return end
        pcall(function()
            if isfile and isfile(AutoExecFile) then
                QueueTeleport('if readfile and isfile("' .. AutoExecFile .. '") then loadstring(readfile("' .. AutoExecFile .. '"))() end')
            end
        end)
    end)
end

-- ==========================================
-- 3. STATE + CONNECTION REGISTRY (Happy Hub)
-- ==========================================
local Connections = {}
local Threads     = {}

local function trackConn(key, conn)
    if not conn then return conn end
    if key then
        if Connections[key] then pcall(function() Connections[key]:Disconnect() end) end
        Connections[key] = conn
    end
    return conn
end

local function dropConn(key)
    if Connections[key] then
        pcall(function() Connections[key]:Disconnect() end)
        Connections[key] = nil
    end
end

local function trackThread(t)
    if t then table.insert(Threads, t) end
    return t
end

local S = {
    roleCache       = {},   -- [plr] = { Role = "Murderer"/"Sheriff"/"Hero"/"Innocent", Dead = bool }
    roundActive     = false,
    roundStartedAt  = 0,
    totalCoins      = 0,
    bagProgress     = {},

    -- Farm
    farmBV          = nil,
    farmGyro        = nil,
    farmTarget      = nil,
    farmTargetAt    = 0,
    farmBlacklist   = {},   -- [coin] = tick
    farmTouched     = {},   -- [coin] = tick

    -- Fly
    flyBV           = nil,
    flyBG           = nil,
    flyConn         = nil,
    mobileFlyDragging = false,
    mobileFlyVec    = Vector3.zero,

    -- Combat
    lastKillTick    = 0,
    lastShotTick    = 0,
    killAllRunning  = false,

    -- Anti-void
    lastSafeCFrame  = nil,

    -- ESP
    highlights      = {},   -- [plr] = Highlight
    coinTags        = {},   -- [coin] = Drawing.Text
    gunTag          = nil,

    -- Tracer
    tracer          = nil,
}

if Drawing then
    local ok, ln = pcall(function() return Drawing.new("Line") end)
    if ok and ln then
        S.tracer = ln
        S.tracer.Thickness = 1.5
        S.tracer.Color = Color3.fromRGB(180, 100, 255)
        S.tracer.Transparency = 0.4
        S.tracer.Visible = false
    end
end

-- ==========================================
-- 4. HELPERS
-- ==========================================
local function getHRP(plr)
    plr = plr or LocalPlayer
    local c = plr.Character
    return c and c:FindFirstChild("HumanoidRootPart")
end

local function getHum(plr)
    plr = plr or LocalPlayer
    local c = plr.Character
    return c and c:FindFirstChildOfClass("Humanoid")
end

local function isAlive(plr)
    local h = getHum(plr)
    return h and h.Health > 0
end

local function hasTool(plr, toolName)
    if not plr then return false end
    toolName = string.lower(toolName)
    local char = plr.Character
    local bp = plr:FindFirstChildOfClass("Backpack")
    for _, container in ipairs({char, bp}) do
        if container then
            for _, t in ipairs(container:GetChildren()) do
                if t:IsA("Tool") and string.lower(t.Name):find(toolName, 1, true) then
                    return true, t
                end
            end
        end
    end
    return false, nil
end

-- ==========================================
-- 5. ROLE DETECTION (Happy Hub)
-- ==========================================
local function getMM2Role(plr)
    if plr == LocalPlayer then return "Local" end
    local cached = S.roleCache[plr]
    if cached and cached.Role then return cached.Role end

    local hasKnife = hasTool(plr, "knife")
    local hasGun = hasTool(plr, "gun") or hasTool(plr, "revolver") or hasTool(plr, "pistol")
    if hasKnife then return "Murderer" end
    if hasGun then
        -- если sheriff уже мёртв — этот с пушкой Hero
        local sheriffDead = false
        for p, info in pairs(S.roleCache) do
            if info.Role == "Sheriff" and info.Dead then sheriffDead = true; break end
            if info.Role == "Sheriff" and p ~= plr then sheriffDead = false; break end
        end
        if sheriffDead then return "Hero" end
        return "Sheriff"
    end
    return "Innocent"
end

local function getMurderer()
    for _, plr in ipairs(Players:GetPlayers()) do
        if plr ~= LocalPlayer and getMM2Role(plr) == "Murderer" and isAlive(plr) then
            return plr
        end
    end
    return nil
end

local function getSheriff()
    for _, plr in ipairs(Players:GetPlayers()) do
        if plr ~= LocalPlayer then
            local r = getMM2Role(plr)
            if (r == "Sheriff" or r == "Hero") and isAlive(plr) then return plr end
        end
    end
    return nil
end

local function isLocalMurderer() return hasTool(LocalPlayer, "knife") end
local function isLocalSheriff()  return hasTool(LocalPlayer, "gun") or hasTool(LocalPlayer, "revolver") end

-- ==========================================
-- 6. FADE EVENT HOOK (роли от сервера)
-- ==========================================
local function hookFade()
    dropConn("fade")
    local remotes = ReplicatedStorage:FindFirstChild("Remotes")
    local gameplay = remotes and remotes:FindFirstChild("Gameplay")
    local fade = gameplay and gameplay:FindFirstChild("Fade")
    if not fade then return end
    trackConn("fade", fade.OnClientEvent:Connect(function(data)
        if type(data) ~= "table" then return end
        for username, info in pairs(data) do
            if type(info) == "table" and info.Role then
                local plr
                for _, p in ipairs(Players:GetPlayers()) do
                    if p.Name == username then plr = p; break end
                end
                if plr then
                    S.roleCache[plr] = {
                        Role = info.Role,
                        Dead = info.Dead or false,
                    }
                end
            end
        end
        refreshAllESP()
    end))
end

-- ==========================================
-- 7. SPLASH
-- ==========================================
local Splash = Instance.new("ScreenGui")
Splash.IgnoreGuiInset = true
Splash.Parent = LocalPlayer:WaitForChild("PlayerGui")

local SplashText = Instance.new("TextLabel")
SplashText.Size = UDim2.new(1, 0, 1, 0)
SplashText.BackgroundColor3 = Color3.fromRGB(15, 15, 20)
SplashText.Text = "Привет."
SplashText.TextColor3 = Color3.fromRGB(255, 255, 255)
SplashText.Font = Enum.Font.GothamBold
SplashText.TextSize = 32
SplashText.Parent = Splash

task.wait(0.7)
SplashText.Text = "Iroshida v10.0"
task.wait(0.7)
SplashText.Text = "Загрузка..."
task.wait(0.4)
Splash:Destroy()

-- ==========================================
-- 8. FLY (Happy Hub адаптация)
-- ==========================================
local MOBILE = UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled

local function attachFly()
    local hrp, hum = getHRP(), getHum()
    if not hrp or not hum then return end
    hum.PlatformStand = true
    if S.flyBV then S.flyBV:Destroy() end
    if S.flyBG then S.flyBG:Destroy() end
    S.flyBV = Instance.new("BodyVelocity")
    S.flyBV.Velocity = Vector3.zero
    S.flyBV.MaxForce = Vector3.new(1e5, 1e5, 1e5)
    S.flyBV.Parent = hrp
    S.flyBG = Instance.new("BodyGyro")
    S.flyBG.MaxTorque = Vector3.new(1e5, 1e5, 1e5)
    S.flyBG.P = 1e4
    S.flyBG.CFrame = hrp.CFrame
    S.flyBG.Parent = hrp
end

local function detachFly()
    if S.flyBV then S.flyBV:Destroy(); S.flyBV = nil end
    if S.flyBG then S.flyBG:Destroy(); S.flyBG = nil end
    local hum = getHum()
    if hum then hum.PlatformStand = false end
end

local function getFlyInput()
    local mv = Vector3.zero
    if MOBILE then
        if S.mobileFlyDragging and S.mobileFlyVec.Magnitude > 0.1 then mv = S.mobileFlyVec end
        return mv
    end
    local cf = Camera.CFrame
    if UserInputService:IsKeyDown(Enum.KeyCode.W) then mv += cf.LookVector end
    if UserInputService:IsKeyDown(Enum.KeyCode.S) then mv -= cf.LookVector end
    if UserInputService:IsKeyDown(Enum.KeyCode.A) then mv -= cf.RightVector end
    if UserInputService:IsKeyDown(Enum.KeyCode.D) then mv += cf.RightVector end
    if UserInputService:IsKeyDown(Enum.KeyCode.Space) then mv += Vector3.yAxis end
    if UserInputService:IsKeyDown(Enum.KeyCode.LeftControl) then mv -= Vector3.yAxis end
    return mv
end

local function startFly()
    dropConn("fly")
    attachFly()
    trackConn("fly", RunService.Heartbeat:Connect(function()
        if not Settings.FlyEnabled then return end
        local hrp = getHRP()
        if not hrp then return end
        if not S.flyBV or not S.flyBV.Parent then attachFly() end
        if not S.flyBV then return end
        local mv = getFlyInput()
        S.flyBV.Velocity = mv.Magnitude > 0 and mv.Unit * Settings.FlySpeed or Vector3.zero
        S.flyBG.CFrame = Camera.CFrame
        -- пауза фарма: не двигаем hrp одновременно
        if S.farmBV then S.farmBV.Velocity = Vector3.zero end
    end))
end

local function stopFly() dropConn("fly"); detachFly() end

if MOBILE then
    local dragStart
    UserInputService.TouchStarted:Connect(function(i, gp)
        if gp or not Settings.FlyEnabled then return end
        dragStart = i.Position
        S.mobileFlyDragging = true
    end)
    UserInputService.TouchMoved:Connect(function(i, gp)
        if gp or not S.mobileFlyDragging or not Settings.FlyEnabled then return end
        local d = i.Position - dragStart
        S.mobileFlyVec = Camera.CFrame.LookVector * (-d.Y * 0.05)
                       + Camera.CFrame.RightVector * (d.X * 0.05)
    end)
    UserInputService.TouchEnded:Connect(function()
        S.mobileFlyDragging = false
        S.mobileFlyVec = Vector3.zero
    end)
end

UserInputService.InputBegan:Connect(function(i, gp)
    if gp then return end
    if i.KeyCode == Enum.KeyCode.F then
        Settings.FlyEnabled = not Settings.FlyEnabled
        if Settings.FlyEnabled then startFly() else stopFly() end
        if UI and UI.refreshFlyToggle then UI.refreshFlyToggle() end
        SaveConfig()
    end
end)

-- ==========================================
-- 9. FARM (Happy Hub — BodyVelocity + firetouchinterest)
-- ==========================================
local FARM_RADIUS       = 25
local FARM_ARRIVE       = 5
local FARM_STUCK_TIME   = 3
local FARM_STUCK_DIST   = 2.5
local FARM_BLACKLIST    = 5
local FARM_TARGET_TTL   = 8
local FARM_TOUCH_CD     = 0.28

local function getCoinContainer()
    local maps = {
        "ResearchFacility","House2","Mansion2","Hotel","MilBase","Bank2",
        "BioLab","Factory","Workplace","PoliceStation","Office3",
        "Hospital3","Town","Town2","Mansion","House",
    }
    for _, name in ipairs(maps) do
        local m = Workspace:FindFirstChild(name)
        if m then
            local c = m:FindFirstChild("CoinContainer", true)
            if c then return c end
        end
    end
    return Workspace:FindFirstChild("CoinContainer", true)
end

local function isCoinValid(coin)
    if not coin or not coin.Parent then return false end
    if coin:GetAttribute("Collected") then return false end
    return coin:FindFirstChildWhichIsA("TouchTransmitter") ~= nil
end

local function isBlacklisted(coin)
    local t = S.farmBlacklist[coin]
    if not t then return false end
    if tick() - t > FARM_BLACKLIST then S.farmBlacklist[coin] = nil; return false end
    return true
end

local function getAllCoins()
    local c = getCoinContainer()
    if not c then return {} end
    local out = {}
    for _, ch in ipairs(c:GetChildren()) do
        local p
        if ch:IsA("BasePart") then p = ch
        elseif ch:IsA("Model") then p = ch.PrimaryPart or ch:FindFirstChildWhichIsA("BasePart") end
        if p and p:IsA("BasePart") then table.insert(out, p) end
    end
    return out
end

local function attachFarmBody()
    local hrp, hum = getHRP(), getHum()
    if not hrp then return end
    if hum then hum.PlatformStand = true end
    if not S.farmBV or not S.farmBV.Parent then
        S.farmBV = Instance.new("BodyVelocity")
        S.farmBV.MaxForce = Vector3.new(1e5, 1e5, 1e5)
        S.farmBV.P = 500
        S.farmBV.Parent = hrp
    end
    if not S.farmGyro or not S.farmGyro.Parent then
        S.farmGyro = Instance.new("BodyGyro")
        S.farmGyro.MaxTorque = Vector3.new(1e6, 1e6, 1e6)
        S.farmGyro.P = 1e5
        S.farmGyro.D = 500
        S.farmGyro.CFrame = CFrame.new(hrp.Position)
        S.farmGyro.Parent = hrp
    end
end

local function detachFarmBody()
    if S.farmBV then S.farmBV:Destroy(); S.farmBV = nil end
    if S.farmGyro then S.farmGyro:Destroy(); S.farmGyro = nil end
    local hum = getHum()
    if hum then hum.PlatformStand = false end
    S.farmTarget = nil
    S.farmTouched = {}
    S.farmBlacklist = {}
end

local function farmStep()
    if not Settings.FarmEnabled then return end
    if Settings.FlyEnabled then
        -- полёт приоритетнее, фарм стоит
        if S.farmBV then S.farmBV.Velocity = Vector3.zero end
        return
    end
    local hrp = getHRP()
    if not hrp then return end
    if S.totalCoins >= Settings.CoinLimit then return end
    if not S.farmBV or not S.farmBV.Parent then attachFarmBody() end
    if not S.farmBV then return end

    local now = tick()
    local myPos = hrp.Position
    local coins = getAllCoins()
    S.farmGyro.CFrame = CFrame.new(myPos)

    -- эвейд от убийцы
    if Settings.AutoEvade and not isLocalMurderer() then
        local m = getMurderer()
        local mHRP = m and getHRP(m)
        if mHRP and (mHRP.Position - myPos).Magnitude < Settings.EvadeRadius then
            local away = Vector3.new(myPos.X - mHRP.Position.X, 0, myPos.Z - mHRP.Position.Z)
            if away.Magnitude < 0.1 then away = Vector3.new(1, 0, 0) end
            S.farmBV.Velocity = away.Unit * Settings.FarmSpeed * 2 + Vector3.new(0, 4, 0)
            return
        end
    end

    -- touch ко всему в радиусе
    for _, coin in ipairs(coins) do
        if (coin.Position - myPos).Magnitude <= FARM_RADIUS then
            local last = S.farmTouched[coin]
            if not last or now - last > FARM_TOUCH_CD then
                S.farmTouched[coin] = now
                task.spawn(function()
                    pcall(firetouchinterest, hrp, coin, 0)
                    task.wait(0.02)
                    if coin and coin.Parent then
                        pcall(firetouchinterest, hrp, coin, 1)
                    end
                end)
            end
        end
    end

    -- чистим кэши
    for c, t in pairs(S.farmTouched) do
        if now - t > 5 or not c or not c.Parent then S.farmTouched[c] = nil end
    end

    -- таймаут цели
    if S.farmTarget and (now - S.farmTargetAt) > FARM_TARGET_TTL then
        S.farmBlacklist[S.farmTarget] = now
        S.farmTarget = nil
    end

    -- выбор ближайшей
    if not S.farmTarget or not S.farmTarget.Parent or not isCoinValid(S.farmTarget) then
        S.farmTarget = nil
        local best, bd = nil, math.huge
        for _, coin in ipairs(coins) do
            if isCoinValid(coin) and not isBlacklisted(coin) then
                local d = (coin.Position - myPos).Magnitude
                if d < bd then bd = d; best = coin end
            end
        end
        if best then
            S.farmTarget = best
            S.farmTargetAt = now
        end
    end

    local target = S.farmTarget
    if not target then
        S.farmBV.Velocity = Vector3.zero
        return
    end

    local delta = target.Position + Vector3.new(0, -1.5, 0) - myPos
    local hDist = (Vector3.new(delta.X, 0, delta.Z)).Magnitude
    if hDist > 0.5 then
        S.farmBV.Velocity = Vector3.new(delta.X, math.clamp(delta.Y * 2, -8, 8), delta.Z).Unit * math.min(Settings.FarmSpeed, hDist * 5)
    else
        S.farmBV.Velocity = Vector3.new(0, math.clamp(delta.Y * 2, -8, 8), 0)
    end

    -- застревание
    if not S._stuckPos then
        S._stuckPos = myPos; S._stuckAt = now
    elseif (myPos - S._stuckPos).Magnitude > FARM_STUCK_DIST then
        S._stuckPos = myPos; S._stuckAt = now
    elseif now - S._stuckAt > FARM_STUCK_TIME then
        S.farmBlacklist[S.farmTarget] = now
        S.farmTarget = nil
        S._stuckPos = nil; S._stuckAt = 0
    end

    -- трассер
    if Settings.ShowTracer and S.tracer and Camera then
        local sp, on = Camera:WorldToViewportPoint(target.Position)
        if on then
            S.tracer.From = Vector2.new(Camera.ViewportSize.X / 2, Camera.ViewportSize.Y)
            S.tracer.To = Vector2.new(sp.X, sp.Y)
            S.tracer.Visible = true
        else
            S.tracer.Visible = false
        end
    elseif S.tracer then
        S.tracer.Visible = false
    end
end

-- ==========================================
-- 10. MURDERER (Happy Hub — через Knife remotes)
-- ==========================================
local function getLocalKnife()
    local char = LocalPlayer.Character
    if not char then return nil end
    for _, t in ipairs(char:GetChildren()) do
        if t:IsA("Tool") and string.lower(t.Name):find("knife", 1, true) then return t end
    end
    return nil
end

local function equipKnife()
    if getLocalKnife() then return true end
    local bp = LocalPlayer:FindFirstChildOfClass("Backpack")
    if not bp then return false end
    for _, t in ipairs(bp:GetChildren()) do
        if t:IsA("Tool") and string.lower(t.Name):find("knife", 1, true) then
            local hum = getHum()
            if hum then pcall(function() hum:EquipTool(t) end) end
            task.wait(0.2)
            return true
        end
    end
    return false
end

local function murderTick()
    if not (Settings.KillAll) then return end
    if tick() - S.lastKillTick < 0.05 then return end
    S.lastKillTick = tick()

    local knife = getLocalKnife()
    if not knife then
        equipKnife()
        knife = getLocalKnife()
        if not knife then return end
    end

    local events = knife:FindFirstChild("Events")
    local stab  = events and events:FindFirstChild("KnifeStabbed")
    local touch = events and events:FindFirstChild("HandleTouched")
    local handle = knife:FindFirstChild("Handle")

    pcall(function() knife:Activate() end)
    if stab then pcall(function() stab:FireServer() end) end

    for _, plr in ipairs(Players:GetPlayers()) do
        if plr ~= LocalPlayer and isAlive(plr) then
            local hrp = getHRP(plr)
            local head = plr.Character:FindFirstChild("Head")
            if touch then
                if hrp then pcall(function() touch:FireServer(hrp) end) end
                if head then pcall(function() touch:FireServer(head) end) end
            end
            if handle then
                if hrp then
                    pcall(firetouchinterest, hrp, handle, 0)
                    pcall(firetouchinterest, hrp, handle, 1)
                    pcall(firetouchinterest, handle, hrp, 0)
                    pcall(firetouchinterest, handle, hrp, 1)
                end
            end
        end
    end
end

-- ==========================================
-- 11. SHERIFF (Happy Hub — через Shoot remote)
-- ==========================================
local function getGun()
    local char = LocalPlayer.Character
    if char then
        for _, t in ipairs(char:GetChildren()) do
            if t:IsA("Tool") then
                local n = string.lower(t.Name)
                if n:find("gun") or n:find("revolver") or n:find("pistol") then return t end
            end
        end
    end
    local bp = LocalPlayer:FindFirstChildOfClass("Backpack")
    if bp then
        for _, t in ipairs(bp:GetChildren()) do
            if t:IsA("Tool") then
                local n = string.lower(t.Name)
                if n:find("gun") or n:find("revolver") or n:find("pistol") then return t end
            end
        end
    end
    return nil
end

local function equipGun()
    local char = LocalPlayer.Character
    local gun = getGun()
    if gun and gun.Parent == char then return gun end
    if gun then
        local hum = getHum()
        if hum then pcall(function() hum:EquipTool(gun) end) end
        task.wait(0.15)
        return getGun()
    end
    return nil
end

local function shootAt(targetPlr)
    local gun = equipGun()
    if not gun then return false end
    local targetHRP = getHRP(targetPlr)
    if not targetHRP then return false end
    local shoot = gun:FindFirstChild("Shoot") or gun:FindFirstChild("Shoot", true)
    if not shoot then return false end
    local origin = getHRP()
    if not origin then return false end
    local originCF = origin.CFrame
    local targetCF = CFrame.new(targetHRP.Position)
    if shoot:IsA("RemoteEvent") then
        pcall(function() shoot:FireServer(originCF, targetCF) end)
        return true
    end
    return false
end

local function sheriffTick()
    if not Settings.AutoShoot then return end
    if tick() - S.lastShotTick < 0.12 then return end
    S.lastShotTick = tick()
    local m = getMurderer()
    if m then shootAt(m) end
end

-- ==========================================
-- 12. INNOCENT (подбор пушки)
-- ==========================================
local function findGunDrop()
    return Workspace:FindFirstChild("GunDrop", true)
end

local function innocentTick()
    if not Settings.AutoGun then return end
    if isLocalSheriff() or isLocalMurderer() then return end
    local gd = findGunDrop()
    local hrp = getHRP()
    if not (gd and hrp) then return end
    if (gd.Position - hrp.Position).Magnitude > 5 then
        hrp.CFrame = CFrame.new(gd.Position + Vector3.new(0, 2, 0))
    end
end

-- ==========================================
-- 13. NOCLIP / ANTI-VOID / ANTI-AFK
-- ==========================================
local function noclipStep()
    if not Settings.Noclip then return end
    local char = LocalPlayer.Character
    if not char then return end
    for _, p in ipairs(char:GetDescendants()) do
        if p:IsA("BasePart") then p.CanCollide = false end
    end
end

local function antiVoidStep()
    if not Settings.AntiVoid then return end
    local hrp = getHRP()
    if not hrp then S.lastSafeCFrame = nil; return end
    if hrp.Position.Y >= 10 then
        S.lastSafeCFrame = hrp.CFrame
    elseif hrp.Position.Y <= -30 and S.lastSafeCFrame then
        hrp.CFrame = S.lastSafeCFrame
        hrp.Velocity = Vector3.zero
        hrp.RotVelocity = Vector3.zero
    end
end

-- Anti-AFK
LocalPlayer.Idled:Connect(function()
    if not Settings.AntiAFK then return end
    VirtualUser:Button2Down(Vector2.new(0, 0), Camera.CFrame)
    task.wait(1)
    VirtualUser:Button2Up(Vector2.new(0, 0), Camera.CFrame)
end)

-- ==========================================
-- 14. ESP (Highlight по ролям + Coin/Gun)
-- ==========================================
local ESP_COLORS = {
    Murderer = Color3.fromRGB(255, 55, 55),
    Sheriff  = Color3.fromRGB(55, 140, 255),
    Hero     = Color3.fromRGB(255, 200, 0),
    Innocent = Color3.fromRGB(80, 220, 120),
    Coin     = Color3.fromRGB(255, 215, 60),
    Gun      = Color3.fromRGB(255, 200, 0),
}

local function clearHighlight(plr)
    if S.highlights[plr] then
        pcall(function() S.highlights[plr]:Destroy() end)
        S.highlights[plr] = nil
    end
end

local function applyRoleESP(plr)
    if plr == LocalPlayer or not plr.Character then clearHighlight(plr); return end
    local role = getMM2Role(plr)
    local col = ESP_COLORS[role] or ESP_COLORS.Innocent
    if not S.highlights[plr] then
        local h = Instance.new("Highlight")
        h.Name = "Iroshida_ESP"
        h.FillColor = col
        h.FillTransparency = 0.35
        h.OutlineTransparency = 1
        h.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
        h.Parent = plr.Character
        S.highlights[plr] = h
    else
        S.highlights[plr].FillColor = col
    end
end

function refreshAllESP()
    for _, plr in ipairs(Players:GetPlayers()) do
        if Settings.RoleESP then applyRoleESP(plr) else clearHighlight(plr) end
    end
end

local function updateCoinESP()
    if not Settings.CoinESP then
        for coin, tag in pairs(S.coinTags) do pcall(function() tag:Remove() end); S.coinTags[coin] = nil end
        return
    end
    if not Drawing then return end
    local seen = {}
    for _, coin in ipairs(getAllCoins()) do
        seen[coin] = true
        if not S.coinTags[coin] then
            local ok, t = pcall(function() return Drawing.new("Text") end)
            if ok and t then
                t.Size = 12; t.Center = true; t.Outline = true
                t.Color = ESP_COLORS.Coin; t.Text = "COIN"
                S.coinTags[coin] = t
            end
        end
        local tag = S.coinTags[coin]
        if tag then
            local sp, on = Camera:WorldToViewportPoint(coin.Position)
            tag.Visible = on
            if on then tag.Position = Vector2.new(sp.X, sp.Y) end
        end
    end
    for coin, tag in pairs(S.coinTags) do
        if not seen[coin] or not coin.Parent then
            pcall(function() tag:Remove() end)
            S.coinTags[coin] = nil
        end
    end
end

local function updateGunESP()
    if not Settings.GunESP then
        if S.gunTag then pcall(function() S.gunTag:Remove() end); S.gunTag = nil end
        return
    end
    if not Drawing then return end
    local gd = findGunDrop()
    if not gd then
        if S.gunTag then S.gunTag.Visible = false end
        return
    end
    if not S.gunTag then
        local ok, t = pcall(function() return Drawing.new("Text") end)
        if ok and t then
            t.Size = 13; t.Center = true; t.Outline = true
            t.Color = ESP_COLORS.Gun; t.Text = "GUN"
            S.gunTag = t
        end
    end
    if S.gunTag then
        local sp, on = Camera:WorldToViewportPoint(gd.Position)
        S.gunTag.Visible = on
        if on then S.gunTag.Position = Vector2.new(sp.X, sp.Y) end
    end
end

-- ==========================================
-- 15. UI
-- ==========================================
local ScreenGui = Instance.new("ScreenGui")
ScreenGui.Name = "Iroshida_UI_v10"
ScreenGui.ResetOnSpawn = false
ScreenGui.Parent = LocalPlayer:WaitForChild("PlayerGui")

local Main = Instance.new("Frame")
Main.Size = UDim2.new(0, 460, 0, 340)
Main.Position = UDim2.new(0.5, -230, 0.5, -170)
Main.BackgroundColor3 = Color3.fromRGB(20, 20, 25)
Main.BorderSizePixel = 0
Main.Active = true
Main.Draggable = true
Main.Parent = ScreenGui
Instance.new("UICorner", Main).CornerRadius = UDim.new(0, 10)

local TitleBar = Instance.new("Frame")
TitleBar.Size = UDim2.new(1, 0, 0, 34)
TitleBar.BackgroundColor3 = Color3.fromRGB(30, 30, 40)
TitleBar.Parent = Main
Instance.new("UICorner", TitleBar).CornerRadius = UDim.new(0, 10)

local Title = Instance.new("TextLabel")
Title.Size = UDim2.new(1, -20, 1, 0)
Title.Position = UDim2.new(0, 15, 0, 0)
Title.BackgroundTransparency = 1
Title.Text = "Iroshida | v10.0"
Title.TextColor3 = Color3.fromRGB(180, 100, 255)
Title.Font = Enum.Font.GothamBold
Title.TextSize = 14
Title.TextXAlignment = Enum.TextXAlignment.Left
Title.Parent = TitleBar

local TabBar = Instance.new("Frame")
TabBar.Size = UDim2.new(0, 120, 1, -40)
TabBar.Position = UDim2.new(0, 0, 0, 36)
TabBar.BackgroundColor3 = Color3.fromRGB(25, 25, 30)
TabBar.Parent = Main
Instance.new("UICorner", TabBar).CornerRadius = UDim.new(0, 10)
Instance.new("UIListLayout", TabBar).Padding = UDim.new(0, 5)

local Content = Instance.new("Frame")
Content.Size = UDim2.new(1, -130, 1, -46)
Content.Position = UDim2.new(0, 125, 0, 40)
Content.BackgroundTransparency = 1
Content.Parent = Main

local Pages = {}
local function makeTab(name, icon)
    local btn = Instance.new("TextButton")
    btn.Size = UDim2.new(1, -10, 0, 30)
    btn.Position = UDim2.new(0, 5, 0, 0)
    btn.BackgroundColor3 = Color3.fromRGB(35, 35, 45)
    btn.TextColor3 = Color3.fromRGB(180, 180, 180)
    btn.Font = Enum.Font.GothamBold
    btn.TextSize = 12
    btn.Text = icon .. " " .. name
    btn.Parent = TabBar
    Instance.new("UICorner", btn).CornerRadius = UDim.new(0, 6)

    local page = Instance.new("ScrollingFrame")
    page.Size = UDim2.new(1, 0, 1, 0)
    page.BackgroundTransparency = 1
    page.Visible = false
    page.CanvasSize = UDim2.new(0, 0, 0, 0)
    page.AutomaticCanvasSize = Enum.AutomaticSize.Y
    page.ScrollBarThickness = 3
    page.Parent = Content
    Instance.new("UIListLayout", page).Padding = UDim.new(0, 6)
    Pages[name] = page

    btn.MouseButton1Click:Connect(function()
        for _, p in pairs(Pages) do p.Visible = false end
        page.Visible = true
        for _, c in ipairs(TabBar:GetChildren()) do
            if c:IsA("TextButton") then
                c.BackgroundColor3 = Color3.fromRGB(35, 35, 45)
                c.TextColor3 = Color3.fromRGB(180, 180, 180)
            end
        end
        btn.BackgroundColor3 = Color3.fromRGB(100, 50, 150)
        btn.TextColor3 = Color3.fromRGB(255, 255, 255)
    end)
    return page
end

local function addToggle(page, text, key, callback)
    local btn = Instance.new("TextButton")
    btn.Size = UDim2.new(1, 0, 0, 32)
    btn.BackgroundColor3 = Color3.fromRGB(35, 35, 45)
    btn.TextColor3 = Color3.fromRGB(200, 200, 200)
    btn.Font = Enum.Font.Gotham
    btn.TextSize = 13
    btn.Parent = page
    Instance.new("UICorner", btn).CornerRadius = UDim.new(0, 6)

    local function update()
        btn.Text = text .. (Settings[key] and " : ON" or " : OFF")
        btn.BackgroundColor3 = Settings[key] and Color3.fromRGB(80, 50, 120) or Color3.fromRGB(35, 35, 45)
    end
    btn.MouseButton1Click:Connect(function()
        Settings[key] = not Settings[key]
        update()
        if callback then callback(Settings[key]) end
        SaveConfig()
    end)
    update()
    return btn
end

local function addSlider(page, text, min, max, value, key, callback)
    local frame = Instance.new("Frame")
    frame.Size = UDim2.new(1, 0, 0, 42)
    frame.BackgroundColor3 = Color3.fromRGB(35, 35, 45)
    frame.Parent = page
    Instance.new("UICorner", frame).CornerRadius = UDim.new(0, 6)

    local lbl = Instance.new("TextLabel")
    lbl.Size = UDim2.new(1, -10, 0, 15)
    lbl.Position = UDim2.new(0, 5, 0, 3)
    lbl.BackgroundTransparency = 1
    lbl.Text = text .. ": " .. value
    lbl.TextColor3 = Color3.fromRGB(200, 200, 200)
    lbl.Font = Enum.Font.Gotham
    lbl.TextSize = 12
    lbl.TextXAlignment = Enum.TextXAlignment.Left
    lbl.Parent = frame

    local bar = Instance.new("Frame")
    bar.Size = UDim2.new(1, -10, 0, 8)
    bar.Position = UDim2.new(0, 5, 0, 24)
    bar.BackgroundColor3 = Color3.fromRGB(50, 50, 60)
    bar.Parent = frame
    Instance.new("UICorner", bar).CornerRadius = UDim.new(0, 4)

    local pct = (value - min) / (max - min)
    local fill = Instance.new("Frame")
    fill.Size = UDim2.new(pct, 0, 1, 0)
    fill.BackgroundColor3 = Color3.fromRGB(100, 50, 150)
    fill.Parent = bar
    Instance.new("UICorner", fill).CornerRadius = UDim.new(0, 4)

    local knob = Instance.new("Frame")
    knob.Size = UDim2.new(0, 14, 0, 14)
    knob.Position = UDim2.new(pct, -7, 0.5, -7)
    knob.BackgroundColor3 = Color3.fromRGB(180, 100, 255)
    knob.Parent = bar
    Instance.new("UICorner", knob).CornerRadius = UDim.new(1, 0)

    local dragging = false
    bar.InputBegan:Connect(function(i)
        if i.UserInputType == Enum.UserInputType.MouseButton1 or i.UserInputType == Enum.UserInputType.Touch then
            dragging = true
        end
    end)
    UserInputService.InputEnded:Connect(function(i)
        if i.UserInputType == Enum.UserInputType.MouseButton1 or i.UserInputType == Enum.UserInputType.Touch then
            dragging = false
        end
    end)
    UserInputService.InputChanged:Connect(function(i)
        if not dragging then return end
        if i.UserInputType == Enum.UserInputType.MouseMovement or i.UserInputType == Enum.UserInputType.Touch then
            local p = math.clamp((i.Position.X - bar.AbsolutePosition.X) / bar.AbsoluteSize.X, 0, 1)
            local v = math.floor(min + (max - min) * p)
            fill.Size = UDim2.new(p, 0, 1, 0)
            knob.Position = UDim2.new(p, -7, 0.5, -7)
            lbl.Text = text .. ": " .. v
            if key then Settings[key] = v end
            if callback then callback(v) end
        end
    end)
end

-- TAB: Farm
local FarmPage = makeTab("Farm", "🪙")
addToggle(FarmPage, "Автофарм монет", "FarmEnabled", function(v)
    if v then
        S.totalCoins = 0
        S.bagProgress = {}
        attachFarmBody()
    else
        detachFarmBody()
        if S.tracer then S.tracer.Visible = false end
    end
end)
addSlider(FarmPage, "Скорость", 10, 60, Settings.FarmSpeed, "FarmSpeed")
addSlider(FarmPage, "Лимит монет", 10, 200, Settings.CoinLimit, "CoinLimit")
addToggle(FarmPage, "Убегать от убийцы", "AutoEvade")
addSlider(FarmPage, "Радиус побега", 10, 50, Settings.EvadeRadius, "EvadeRadius")
addToggle(FarmPage, "Линия к цели", "ShowTracer")

-- TAB: Roles
local RolePage = makeTab("Роли", "🎭")
addToggle(RolePage, "Убить всех (Убийца)", "KillAll")
addToggle(RolePage, "Стрелять в убийцу (Шериф)", "AutoShoot")
addToggle(RolePage, "Подобрать пистолет (Невиновный)", "AutoGun")

-- TAB: Movement
local MovePage = makeTab("Полёт", "✈️")
local flyBtn = addToggle(MovePage, "Включить полёт (F)", "FlyEnabled", function(v)
    if v then startFly() else stopFly() end
end)
addSlider(MovePage, "Скорость полёта", 10, 200, Settings.FlySpeed, "FlySpeed")
addToggle(MovePage, "Noclip", "Noclip")
addToggle(MovePage, "Anti-Void", "AntiVoid")
addToggle(MovePage, "Anti-AFK", "AntiAFK")

-- TAB: Visuals
local VisPage = makeTab("Визуал", "👁")
addToggle(VisPage, "Role ESP", "RoleESP", function(v)
    Settings.RoleESP = v
    refreshAllESP()
end)
addToggle(VisPage, "Coin ESP", "CoinESP")
addToggle(VisPage, "Gun ESP", "GunESP")
addToggle(VisPage, "Убрать тени", "KillShadows", function(v)
    Lighting.GlobalShadows = not v
end)
addToggle(VisPage, "Пластиковый мир", "PlasticMode", function(v)
    if v then
        for _, obj in ipairs(Workspace:GetDescendants()) do
            if obj:IsA("BasePart") then obj.Material = Enum.Material.Plastic end
        end
    end
end)

-- TAB: Settings
local SetPage = makeTab("Настройки", "🛠")
addToggle(SetPage, "Auto-Execute после телепорта", "AutoExec", function(v)
    if v and writefile and readfile then
        -- даём пользователю сам скрипт в файл
        pcall(function()
            if readfile and isfile and isfile(AutoExecFile) then return end
        end)
    end
end)

-- активируем Farm
Pages["Farm"].Visible = true
for _, c in ipairs(TabBar:GetChildren()) do
    if c:IsA("TextButton") and c.Text:find("Farm") then
        c.BackgroundColor3 = Color3.fromRGB(100, 50, 150)
        c.TextColor3 = Color3.fromRGB(255, 255, 255)
    end
end

UI = { refreshFlyToggle = function() end } -- заглушка

-- ==========================================
-- 16. MAIN LOOP
-- ==========================================
RunService.Heartbeat:Connect(function()
    -- farm
    if Settings.FarmEnabled then farmStep() end

    -- combat
    if isLocalMurderer() then murderTick() end
    if isLocalSheriff() then sheriffTick() end
    innocentTick()

    -- movement
    noclipStep()
    antiVoidStep()

    -- ESP
    if Settings.RoleESP then
        for _, plr in ipairs(Players:GetPlayers()) do
            if plr ~= LocalPlayer then applyRoleESP(plr) end
        end
    end
    updateCoinESP()
    updateGunESP()
end)

-- ==========================================
-- 17. EVENTS (серверные)
-- ==========================================
pcall(function()
    local remotes = ReplicatedStorage:FindFirstChild("Remotes")
    local gameplay = remotes and remotes:FindFirstChild("Gameplay")
    if not gameplay then return end

    local coinsStarted = gameplay:FindFirstChild("CoinsStarted")
    if coinsStarted then
        coinsStarted.OnClientEvent:Connect(function(data)
            S.roundActive = true
            S.roundStartedAt = tick()
            S.totalCoins = 0
            S.bagProgress = {}
            S.farmTarget = nil
            S.farmBlacklist = {}
            if type(data) == "table" and data.Coin and data.Coin.CollectionLimit then
                Settings.CoinLimit = data.Coin.CollectionLimit
            end
            if Settings.FarmEnabled then attachFarmBody() end
        end)
    end

    local coinCollected = gameplay:FindFirstChild("CoinCollected")
    if coinCollected then
        coinCollected.OnClientEvent:Connect(function(bag, n)
            if type(bag) == "string" and type(n) == "number" then
                S.bagProgress[bag] = n
                local total = 0
                for _, v in pairs(S.bagProgress) do total += v end
                S.totalCoins = total
                -- сброс target после сбора — не залипаем
                S.farmTarget = nil
            end
        end)
    end

    local roundStart = gameplay:FindFirstChild("RoundStart")
    if roundStart then
        roundStart.OnClientEvent:Connect(function()
            S.roundActive = true
            S.roundStartedAt = tick()
            S.totalCoins = 0
            S.bagProgress = {}
            S.roleCache = {}
            if Settings.FarmEnabled then attachFarmBody() end
        end)
    end

    local roundEnd = gameplay:FindFirstChild("RoundEndFade")
    if roundEnd then
        roundEnd.OnClientEvent:Connect(function()
            S.roundActive = false
            S.roundStartedAt = 0
            S.roleCache = {}
            S.totalCoins = 0
            S.bagProgress = {}
            detachFarmBody()
            if S.tracer then S.tracer.Visible = false end
            for plr in pairs(S.highlights) do clearHighlight(plr) end
        end)
    end
end)

-- ==========================================
-- 18. CHARACTER HANDLERS
-- ==========================================
LocalPlayer.CharacterAdded:Connect(function()
    S.roleCache = {}
    S.lastSafeCFrame = nil
    S.totalCoins = 0
    S.bagProgress = {}
    S.farmTarget = nil
    S.farmTouched = {}
    S.farmBlacklist = {}
    S._stuckPos = nil
    task.wait(0.6)
    if Settings.FlyEnabled then startFly() end
    if Settings.FarmEnabled then attachFarmBody() end
end)

Players.PlayerRemoving:Connect(function(plr)
    clearHighlight(plr)
    S.roleCache[plr] = nil
end)

-- ==========================================
-- 19. BOOT
-- ==========================================
hookFade()
task.spawn(function()
    while task.wait(3) do
        hookFade()
    end
end)

print("[Iroshida v10.0] Готов. F — полёт. Фарм отдельно.")
