-- ==========================================
-- IROSHIDA v11.0 · Farm-first rebuild
-- Farm engine: Happy Hub MM2 (open source) 1:1
-- Memory: connection registry, purge, watchdog
-- ==========================================

if not game:IsLoaded() then game.Loaded:Wait() end

local Players            = game:GetService("Players")
local RunService         = game:GetService("RunService")
local UserInputService   = game:GetService("UserInputService")
local ReplicatedStorage  = game:GetService("ReplicatedStorage")
local Workspace          = game:GetService("Workspace")
local Lighting           = game:GetService("Lighting")
local VirtualUser        = game:GetService("VirtualUser")

local LocalPlayer = Players.LocalPlayer

-- ==========================================
-- 0. CLEANUP ОТ ПРОШЛОГО ЗАПУСКА
-- ==========================================
do
    local old = getgenv and getgenv().__IROSHIDA_STATE
    if old then
        pcall(function()
            for _, c in ipairs(old.connections or {}) do
                if c and c.Disconnect then c:Disconnect() end
            end
            for _, t in ipairs(old.threads or {}) do
                if t then pcall(task.cancel, t) end
            end
            for _, g in ipairs(old.guis or {}) do
                if g then g:Destroy() end
            end
        end)
        if getgenv then getgenv().__IROSHIDA_STATE = nil end
        task.wait(0.2)
    end
end

getgenv().__IROSHIDA_STATE = { connections = {}, threads = {}, guis = {} }

local Registry = {}

local function trackConn(key, conn)
    if not conn then return nil end
    if key then
        if Registry[key] then
            pcall(function() Registry[key]:Disconnect() end)
        end
        Registry[key] = conn
    end
    local list = getgenv().__IROSHIDA_STATE.connections
    if #list > 100 then
        local alive = {}
        for _, c in ipairs(list) do
            if c then
                local ok, connected = pcall(function() return c.Connected end)
                if ok and connected then alive[#alive + 1] = c end
            end
        end
        getgenv().__IROSHIDA_STATE.connections = alive
    end
    table.insert(list, conn)
    return conn
end

local function dropConn(key)
    if Registry[key] then
        pcall(function() Registry[key]:Disconnect() end)
        Registry[key] = nil
    end
end

local function trackThread(t)
    if t then
        local list = getgenv().__IROSHIDA_STATE.threads
        if #list > 40 then
            local alive = {}
            for _, th in ipairs(list) do
                if th then
                    local ok, status = pcall(function() return coroutine.status(th) end)
                    if ok and status ~= "dead" then alive[#alive + 1] = th end
                end
            end
            getgenv().__IROSHIDA_STATE.threads = alive
        end
        table.insert(list, t)
    end
    return t
end

local function trackGui(g)
    if g then table.insert(getgenv().__IROSHIDA_STATE.guis, g) end
    return g
end

-- ==========================================
-- 1. НАСТРОЙКИ
-- ==========================================
local Settings = {
    -- Farm (главное)
    FarmEnabled      = false,
    CoinLimit        = 50,

    -- Movement (обвес)
    FlyEnabled       = false,
    FlySpeed         = 40,
    Noclip           = true,
    AntiAFK          = true,
    AntiVoid         = true,

    -- Combat (обвес, минимальный)
    KillAll          = false,
    AutoShoot        = false,
    AutoGun          = false,
}

-- ==========================================
-- 2. STATE
-- ==========================================
local S = {
    -- Round
    roundActive      = false,
    roundStartedAt   = 0,
    roleCache        = {},
    bagProgress      = {},
    totalCoins       = 0,

    -- Farm (Happy Hub 1:1)
    coinCollecting       = false,
    coinConnection       = nil,
    coinGyro             = nil,
    farmWalkBV           = nil,
    farmTargetCoin       = nil,
    farmTouchedCoins     = {},
    farmBlacklist        = {},
    farmLastCollectAt    = 0,
    farmStartedAt        = 0,
    farmLastFallbackAt   = 0,
    farmStuckPos         = nil,
    farmStuckAt          = 0,
    farmLastCollectSpeedAt = 0,
    farmTargetStartedAt  = 0,
    lastGyroUpdate       = 0,
    lastCollectTime      = 0,
    savedFarmStates      = nil,

    -- Movement
    flyBV                = nil,
    flyBG                = nil,
    flyConn              = nil,

    -- Anti-void
    lastSafeCFrame       = nil,

    -- Combat
    lastKillTick         = 0,
    lastShotTick         = 0,

    -- UI setters (создаются в UI)
    coinCountSetter      = nil,
    coinStatusSetter     = nil,
}

local MurdererCache     = { plr = nil, time = 0 }
local TargetVisibility  = {}
local VisCache          = {}

-- ==========================================
-- 3. БАЗОВЫЕ ХЕЛПЕРЫ
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

local function hasToolByName(parent, toolName)
    if not parent then return false end
    for _, child in ipairs(parent:GetChildren()) do
        if child:IsA("Tool") then
            local name = child.Name:lower()
            if name == toolName:lower() or name:find(toolName:lower(), 1, true) then return true end
        end
    end
    return false
end

-- ==========================================
-- 4. РОЛИ (из ролевого кэша + Knife fallback)
-- ==========================================
local function getRoleFromCache(plr)
    local info = S.roleCache[plr.Name]
    if info and info.Role then return info.Role end
    return nil
end

local function isLocalMurderer()
    local cached = getRoleFromCache(LocalPlayer)
    if cached == "Murderer" then return true end
    local char = LocalPlayer.Character
    local bp = LocalPlayer:FindFirstChild("Backpack")
    if (char and char:FindFirstChild("Knife")) or (bp and bp:FindFirstChild("Knife")) then
        return true
    end
    return false
end

local function getMurderer()
    for _, plr in ipairs(Players:GetPlayers()) do
        if plr ~= LocalPlayer then
            if getRoleFromCache(plr) == "Murderer" then return plr end
        end
    end
    for _, plr in ipairs(Players:GetPlayers()) do
        if plr ~= LocalPlayer then
            local char = plr.Character
            local bp = plr:FindFirstChild("Backpack")
            if (char and char:FindFirstChild("Knife")) or (bp and bp:FindFirstChild("Knife")) then
                return plr
            end
        end
    end
    return nil
end

local MURDERER_TTL = 0.4

local function getMurdererCached()
    local now = tick()
    local cached = MurdererCache.plr
    if cached and cached.Parent and cached.Character and (now - MurdererCache.time) < MURDERER_TTL then
        return cached
    end
    local fresh = getMurderer()
    MurdererCache.plr = fresh
    MurdererCache.time = now
    return fresh
end

local function markRoundStarted()
    if S.roundStartedAt == 0 or (tick() - S.roundStartedAt) > 15 then
        S.roundStartedAt = tick()
    end
end

-- ==========================================
-- 5. FADE EVENT (роли с сервера)
-- ==========================================
local function hookFade()
    dropConn("fade")
    local remotes = ReplicatedStorage:FindFirstChild("Remotes")
    local gameplay = remotes and remotes:FindFirstChild("Gameplay")
    local fade = gameplay and gameplay:FindFirstChild("Fade")
    if not fade or not fade:IsA("RemoteEvent") then return end

    trackConn("fade", fade.OnClientEvent:Connect(function(data)
        if type(data) ~= "table" then return end
        for username, info in pairs(data) do
            if type(info) == "table" and info.Role then
                local plr
                for _, p in ipairs(Players:GetPlayers()) do
                    if p.Name == username then plr = p; break end
                end
                if plr then
                    S.roleCache[plr] = { Role = info.Role, Dead = info.Dead or false }
                end
            end
        end
    end))
end

-- ==========================================
-- 6. FARM (Happy Hub 1:1)
-- ==========================================
local FARM_GOAL                = Settings.CoinLimit or 50
local FARM_TOUCH_RADIUS        = 25
local FARM_ARRIVE_DIST         = 5
local FARM_FLY_SPEED           = 21
local FARM_DANGER_DIST         = 20
local FARM_GROUND_OFFSET       = -1.5
local FARM_TOUCH_COOLDOWN      = 0.28
local FARM_FALLBACK_TIMEOUT    = 14
local FARM_FALLBACK_COOLDOWN   = 3.5
local FARM_STUCK_TIME          = 3.0
local FARM_STUCK_DIST          = 2.5
local FARM_SLOW_RADIUS         = 15
local FARM_SLOW_AMOUNT         = 3
local FARM_COLLECT_SPEED_RESET_TIME = 0.5
local FARM_BLACKLIST_TIME      = 5
local FARM_TARGET_TIMEOUT      = 8

local MAP_NAMES = {
    "ResearchFacility","House2","Mansion2","Hotel","MilBase","Bank2",
    "BioLab","Factory","Workplace","PoliceStation","Office3",
    "Hospital3","Town","Town2","Mansion","House",
}

local function getCoinContainer()
    for _, mapName in ipairs(MAP_NAMES) do
        local map = Workspace:FindFirstChild(mapName)
        if map then
            local c = map:FindFirstChild("CoinContainer", true)
            if c then return c end
        end
    end
    local c = Workspace:FindFirstChild("CoinContainer", true)
    if c then return c end
    for _, child in ipairs(Workspace:GetChildren()) do
        if child:IsA("Model") and (child.Name:find("Map") or child.Name:find("map")) then
            local c2 = child:FindFirstChild("CoinContainer", true)
            if c2 then return c2 end
        end
    end
    return nil
end

local function getAllCoins()
    local cc = getCoinContainer()
    if not cc then return {} end
    local coins = {}
    for _, child in ipairs(cc:GetChildren()) do
        local part
        if child:IsA("BasePart") then
            part = child
        elseif child:IsA("Model") then
            part = child.PrimaryPart or child:FindFirstChildWhichIsA("BasePart")
        end
        if part and part:IsA("BasePart") then
            table.insert(coins, part)
        end
    end
    return coins
end

local function isCoinValid(coin)
    if not coin or not coin.Parent then return false end
    if coin:GetAttribute("Collected") then return false end
    return coin:FindFirstChildWhichIsA("TouchTransmitter") ~= nil
end

local function isCoinBlacklisted(coin)
    local t = S.farmBlacklist[coin]
    if not t then return false end
    if tick() - t > FARM_BLACKLIST_TIME then
        S.farmBlacklist[coin] = nil
        return false
    end
    return true
end

local function blacklistCoin(coin)
    if coin then S.farmBlacklist[coin] = tick() end
end

local function attachFarmGyro()
    local hrp = getHRP()
    if not hrp then return end
    if S.coinGyro then S.coinGyro:Destroy() end
    S.coinGyro = Instance.new("BodyGyro")
    S.coinGyro.MaxTorque = Vector3.new(1e6, 1e6, 1e6)
    S.coinGyro.P = 1e5
    S.coinGyro.D = 500
    S.coinGyro.CFrame = CFrame.new(hrp.Position)
    S.coinGyro.Parent = hrp
    S.lastGyroUpdate = tick()
end

local function ensureFarmBodyMovers()
    local hrp = getHRP()
    if not hrp then return end
    local hum = getHum()
    if hum and not hum.PlatformStand then hum.PlatformStand = true end
    if not S.farmWalkBV or not S.farmWalkBV.Parent then
        S.farmWalkBV = Instance.new("BodyVelocity")
        S.farmWalkBV.MaxForce = Vector3.new(1e5, 1e5, 1e5)
        S.farmWalkBV.P = 500
        S.farmWalkBV.Parent = hrp
    end
end

local function stopFarmBodyMovers()
    if S.farmWalkBV then
        S.farmWalkBV.Velocity = Vector3.zero
        S.farmWalkBV:Destroy()
        S.farmWalkBV = nil
    end
    local hum = getHum()
    if hum then hum.PlatformStand = false end
    local hrp = getHRP()
    if hrp and hrp.Position.Y < -50 then
        hrp.CFrame = hrp.CFrame + Vector3.new(0, 60, 0)
    end
end

-- Farm helpers (save/restore Noclip/AntiAFK/AntiVoid)
local function getHelperRefs(name)
    if name == "AntiAFK"  then return Settings, "AntiAFK"  end
    if name == "AntiVoid" then return Settings, "AntiVoid" end
    if name == "Noclip"   then return Settings, "Noclip"   end
    return nil, nil
end

local function ensureHelper(name)
    local tbl, key = getHelperRefs(name)
    if not tbl or not key then return end
    S.savedFarmStates = S.savedFarmStates or {}
    if S.savedFarmStates[name] == nil then
        S.savedFarmStates[name] = { orig = tbl[key], forced = false }
    end
    local st = S.savedFarmStates[name]
    if not tbl[key] then
        tbl[key] = true
        st.forced = true
    end
end

local function restoreHelper(name)
    local tbl, key = getHelperRefs(name)
    if not tbl or not key then return end
    S.savedFarmStates = S.savedFarmStates or {}
    local st = S.savedFarmStates[name]
    if not st or not st.forced then
        S.savedFarmStates[name] = nil
        return
    end
    if tbl[key] ~= st.orig then tbl[key] = st.orig end
    S.savedFarmStates[name] = nil
end

local function ensureFarmHelpers()
    ensureHelper("AntiAFK")
    ensureHelper("AntiVoid")
end

local function restoreFarmHelpers()
    restoreHelper("AntiAFK")
    restoreHelper("AntiVoid")
end

local function ensureFarmNoclip()
    if not S.roundActive then return end
    ensureHelper("Noclip")
end

local function restoreFarmNoclip()
    restoreHelper("Noclip")
end

-- Core: stop
local function stopCoinCollector()
    S.coinCollecting = false
    if S.coinConnection then
        pcall(function() S.coinConnection:Disconnect() end)
        S.coinConnection = nil
    end
    if S.coinGyro then
        pcall(function() S.coinGyro:Destroy() end)
        S.coinGyro = nil
    end
    stopFarmBodyMovers()
    S.farmTargetCoin = nil
    S.farmTouchedCoins = {}
    S.farmBlacklist = {}
    S.farmLastCollectAt = 0
    S.farmStartedAt = 0
    S.farmLastFallbackAt = 0
    S.farmStuckPos = nil
    S.farmStuckAt = 0
    S.farmLastCollectSpeedAt = 0
    S.farmTargetStartedAt = 0
    S.lastGyroUpdate = 0
    if S.coinStatusSetter then S.coinStatusSetter("Idle") end
    local hrp = getHRP()
    if hrp then
        hrp.Velocity = Vector3.zero
        hrp.RotVelocity = Vector3.zero
    end
end

-- Core: start
local function startCoinCollector()
    if S.totalCoins >= FARM_GOAL then return end
    if not getCoinContainer() then return end
    if not getHRP() then return end

    if S.coinConnection or S.coinCollecting then
        stopCoinCollector()
    end

    S.coinCollecting = true
    S.farmTargetCoin = nil
    S.farmTouchedCoins = {}
    S.farmBlacklist = {}
    S.farmStartedAt = tick()
    S.farmLastCollectAt = tick()
    S.farmLastFallbackAt = tick()
    S.farmStuckPos = nil
    S.farmStuckAt = 0
    S.farmLastCollectSpeedAt = 0
    S.farmTargetStartedAt = 0
    if S.coinStatusSetter then
        S.coinStatusSetter(isLocalMurderer() and "Murderer · farming..." or "Searching target...")
    end
    ensureFarmHelpers()
    ensureFarmNoclip()
    attachFarmGyro()
    ensureFarmBodyMovers()

    S.coinConnection = RunService.Heartbeat:Connect(function()
        if not S.coinCollecting then return end
        if not S.roundActive then stopCoinCollector() return end
        if S.totalCoins >= FARM_GOAL then
            if S.coinStatusSetter then S.coinStatusSetter("Goal reached") end
            stopCoinCollector()
            return
        end

        local hrp = getHRP()
        if not hrp then return end

        local now = tick()
        local myPos = hrp.Position
        local coins = getAllCoins()

        if S.coinGyro and S.coinGyro.Parent then
            if now - S.lastGyroUpdate > 0.15 then
                S.coinGyro.CFrame = CFrame.new(myPos)
                S.lastGyroUpdate = now
            end
        elseif not S.coinGyro then
            attachFarmGyro()
        end

        if not S.farmWalkBV or not S.farmWalkBV.Parent then
            ensureFarmBodyMovers()
            if not S.farmWalkBV then return end
        end

        -- firetouchinterest в радиусе 25
        for _, coin in ipairs(coins) do
            if coin and coin.Parent then
                if (coin.Position - myPos).Magnitude <= FARM_TOUCH_RADIUS then
                    local lastTouch = S.farmTouchedCoins[coin]
                    if not lastTouch or now - lastTouch > FARM_TOUCH_COOLDOWN then
                        S.farmTouchedCoins[coin] = now
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
        end

        -- чистки кэшей
        for coin, t in pairs(S.farmTouchedCoins) do
            if now - t > 5 or not coin or not coin.Parent then
                S.farmTouchedCoins[coin] = nil
            end
        end
        for coin, t in pairs(S.farmBlacklist) do
            if now - t > FARM_BLACKLIST_TIME + 2 or not coin or not coin.Parent then
                S.farmBlacklist[coin] = nil
            end
        end

        -- anti-focus (эвейд от убийцы)
        local localIsMurderer = isLocalMurderer()
        local murderer = getMurdererCached()
        local mHRP = (not localIsMurderer) and murderer and murderer.Character and murderer.Character:FindFirstChild("HumanoidRootPart")
        local distToMurderer = mHRP and (myPos - mHRP.Position).Magnitude or math.huge

        if mHRP and distToMurderer < FARM_DANGER_DIST then
            local awayDir = Vector3.new(myPos.X - mHRP.Position.X, 0, myPos.Z - mHRP.Position.Z)
            if awayDir.Magnitude < 0.1 then awayDir = Vector3.new(1, 0, 0) end
            awayDir = awayDir.Unit
            S.farmWalkBV.Velocity = awayDir * FARM_FLY_SPEED * 2 + Vector3.new(0, 4, 0)
            if S.coinStatusSetter then S.coinStatusSetter("DANGER · evading") end
            return
        end

        -- таймаут цели
        if S.farmTargetCoin and (now - S.farmTargetStartedAt) > FARM_TARGET_TIMEOUT then
            blacklistCoin(S.farmTargetCoin)
            S.farmTargetCoin = nil
            S.farmTargetStartedAt = 0
            if S.coinStatusSetter then S.coinStatusSetter("Target timeout · new route") end
        end

        -- выбор цели
        if not S.farmTargetCoin or not S.farmTargetCoin.Parent or not isCoinValid(S.farmTargetCoin) then
            S.farmTargetCoin = nil
            local bestCoin, bestDist = nil, math.huge
            for _, coin in ipairs(coins) do
                if isCoinValid(coin) and not isCoinBlacklisted(coin) then
                    local d = (coin.Position - myPos).Magnitude
                    if d < bestDist then bestDist = d; bestCoin = coin end
                end
            end
            if not bestCoin then
                for _, coin in ipairs(coins) do
                    if isCoinValid(coin) then
                        local d = (coin.Position - myPos).Magnitude
                        if d < bestDist then bestDist = d; bestCoin = coin end
                    end
                end
            end
            S.farmTargetCoin = bestCoin
            S.farmTargetStartedAt = tick()
            S.farmStuckPos = nil
            S.farmStuckAt = 0
        end

        local target = S.farmTargetCoin
        if not target then
            S.farmWalkBV.Velocity = Vector3.zero
            if S.coinStatusSetter then S.coinStatusSetter("No valid coins · waiting") end
            return
        end

        local distToTarget = (target.Position - myPos).Magnitude

        -- две ветки движения (Happy Hub)
        if distToTarget < FARM_ARRIVE_DIST then
            local targetPos = target.Position + Vector3.new(0, FARM_GROUND_OFFSET, 0)
            local delta = targetPos - myPos
            S.farmWalkBV.Velocity = Vector3.new(delta.X, delta.Y, delta.Z) * 5
        else
            local targetPos = target.Position + Vector3.new(0, FARM_GROUND_OFFSET, 0)
            local delta = targetPos - myPos
            local horiz = Vector3.new(delta.X, 0, delta.Z)
            local hDist = horiz.Magnitude

            local baseSpeed = FARM_FLY_SPEED
            local justCollected = (now - S.farmLastCollectSpeedAt) < FARM_COLLECT_SPEED_RESET_TIME
            if not justCollected and distToTarget < FARM_SLOW_RADIUS then
                baseSpeed = math.max(1, FARM_FLY_SPEED - FARM_SLOW_AMOUNT)
            end

            if hDist > 0.5 then
                local speed = math.min(baseSpeed, hDist * 5)
                S.farmWalkBV.Velocity = horiz.Unit * speed + Vector3.new(0, math.clamp(delta.Y * 2, -8, 8), 0)
            else
                S.farmWalkBV.Velocity = Vector3.new(0, math.clamp(delta.Y * 2, -8, 8), 0)
            end
        end

        -- детект застревания
        if not S.farmStuckPos then
            S.farmStuckPos = myPos
            S.farmStuckAt = now
        elseif (myPos - S.farmStuckPos).Magnitude > FARM_STUCK_DIST then
            S.farmStuckPos = myPos
            S.farmStuckAt = now
        elseif now - S.farmStuckAt > FARM_STUCK_TIME then
            blacklistCoin(S.farmTargetCoin)
            S.farmTargetCoin = nil
            S.farmStuckPos = nil
            S.farmStuckAt = 0
            S.farmTargetStartedAt = 0
            if S.coinStatusSetter then S.coinStatusSetter("Unsticking · finding new target") end
        end

        -- fallback TP раз в 14 сек
        local timeSinceCollect = now - math.max(S.farmStartedAt, S.lastCollectTime)
        if timeSinceCollect > FARM_FALLBACK_TIMEOUT
            and now - S.farmLastFallbackAt > FARM_FALLBACK_COOLDOWN
            and (localIsMurderer or not mHRP or distToMurderer > 25) then
            S.farmLastFallbackAt = now
            local tpCoin = nil
            local bestDist = math.huge
            for _, c in ipairs(coins) do
                if isCoinValid(c) then
                    if localIsMurderer or not mHRP or (c.Position - mHRP.Position).Magnitude > 25 then
                        local d = (c.Position - hrp.Position).Magnitude
                        if d < bestDist then bestDist = d; tpCoin = c end
                    end
                end
            end
            if tpCoin then
                S.farmTargetCoin = tpCoin
                S.farmTargetStartedAt = tick()
                local d = (tpCoin.Position - hrp.Position).Magnitude
                if d < 60 then
                    hrp.CFrame = CFrame.new(tpCoin.Position + Vector3.new(0, 3, 0))
                end
                S.farmStuckPos = nil
                S.farmStuckAt = 0
                if S.coinStatusSetter then
                    S.coinStatusSetter(localIsMurderer and "Murderer · safe coin TP" or "Fallback TP")
                end
            end
        end

        if S.coinStatusSetter then
            local prefix = localIsMurderer and "Murderer · " or ""
            S.coinStatusSetter(prefix .. "Moving · " .. #coins .. " coins")
        end
    end)
end

-- ==========================================
-- 7. MEMORY PURGE
-- ==========================================
local function purgeMemoryCaches(full)
    pcall(function()
        for k in pairs(TargetVisibility) do TargetVisibility[k] = nil end
        for k in pairs(VisCache) do VisCache[k] = nil end
        if full then
            MurdererCache.plr = nil
            MurdererCache.time = 0
            for k in pairs(S.roleCache) do S.roleCache[k] = nil end
            for k in pairs(S.bagProgress) do S.bagProgress[k] = nil end
        end
        if S.farmTouchedCoins then
            for coin in pairs(S.farmTouchedCoins) do
                if not coin or not coin.Parent then S.farmTouchedCoins[coin] = nil end
            end
        end
        if S.farmBlacklist then
            for coin in pairs(S.farmBlacklist) do
                if not coin or not coin.Parent then S.farmBlacklist[coin] = nil end
            end
        end
    end)
end

-- ==========================================
-- 8. SPLASH
-- ==========================================
local Splash = Instance.new("ScreenGui")
Splash.IgnoreGuiInset = true
Splash.Parent = LocalPlayer:WaitForChild("PlayerGui")
trackGui(Splash)

local SplashText = Instance.new("TextLabel")
SplashText.Size = UDim2.new(1, 0, 1, 0)
SplashText.BackgroundColor3 = Color3.fromRGB(15, 15, 20)
SplashText.Text = "Загрузка..."
SplashText.TextColor3 = Color3.fromRGB(255, 255, 255)
SplashText.Font = Enum.Font.GothamBold
SplashText.TextSize = 28
SplashText.Parent = Splash

task.wait(0.4)
SplashText.Text = "Iroshida v11.0"
task.wait(0.5)
Splash:Destroy()

-- ==========================================
-- 9. UI
-- ==========================================
local ScreenGui = Instance.new("ScreenGui")
ScreenGui.Name = "Iroshida_v11"
ScreenGui.ResetOnSpawn = false
ScreenGui.Parent = LocalPlayer:WaitForChild("PlayerGui")
trackGui(ScreenGui)

local Main = Instance.new("Frame")
Main.Size = UDim2.new(0, 420, 0, 320)
Main.Position = UDim2.new(0.5, -210, 0.5, -160)
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
Title.Text = "Iroshida | v11.0"
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
    trackConn(nil, bar.InputBegan:Connect(function(i)
        if i.UserInputType == Enum.UserInputType.MouseButton1 or i.UserInputType == Enum.UserInputType.Touch then
            dragging = true
        end
    end))
    trackConn(nil, UserInputService.InputEnded:Connect(function(i)
        if i.UserInputType == Enum.UserInputType.MouseButton1 or i.UserInputType == Enum.UserInputType.Touch then
            dragging = false
        end
    end))
    trackConn(nil, UserInputService.InputChanged:Connect(function(i)
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
    end))
end

-- TAB: Farm
local FarmPage = makeTab("Farm", "🪙")

addToggle(FarmPage, "Автофарм монет", "FarmEnabled", function(v)
    if v then
        ensureFarmHelpers()
        ensureFarmNoclip()
        if S.roundActive and not S.coinCollecting then
            startCoinCollector()
        end
    else
        stopCoinCollector()
        restoreFarmNoclip()
        restoreFarmHelpers()
    end
end)

addSlider(FarmPage, "Лимит монет", 10, 200, Settings.CoinLimit, "CoinLimit", function(v)
    FARM_GOAL = v
end)

-- счётчик
local coinCountLbl = Instance.new("TextLabel")
coinCountLbl.Size = UDim2.new(1, 0, 0, 24)
coinCountLbl.BackgroundColor3 = Color3.fromRGB(30, 30, 40)
coinCountLbl.TextColor3 = Color3.fromRGB(255, 215, 60)
coinCountLbl.Font = Enum.Font.Code
coinCountLbl.TextSize = 13
coinCountLbl.Text = "Coins: 0"
coinCountLbl.Parent = FarmPage
Instance.new("UICorner", coinCountLbl).CornerRadius = UDim.new(0, 6)

-- статус
local statusLbl = Instance.new("TextLabel")
statusLbl.Size = UDim2.new(1, 0, 0, 24)
statusLbl.BackgroundColor3 = Color3.fromRGB(30, 30, 40)
statusLbl.TextColor3 = Color3.fromRGB(180, 100, 255)
statusLbl.Font = Enum.Font.Code
statusLbl.TextSize = 12
statusLbl.Text = "Idle"
statusLbl.Parent = FarmPage
Instance.new("UICorner", statusLbl).CornerRadius = UDim.new(0, 6)

S.coinCountSetter = function(n)
    coinCountLbl.Text = "Coins: " .. tostring(n)
end
S.coinStatusSetter = function(txt)
    statusLbl.Text = tostring(txt)
end

-- TAB: Movement
local MovePage = makeTab("Движение", "✈")

addToggle(MovePage, "Полёт (F)", "FlyEnabled", function(v)
    if v then startFly() else stopFly() end
end)
addSlider(MovePage, "Скорость полёта", 10, 200, Settings.FlySpeed, "FlySpeed")
addToggle(MovePage, "Noclip", "Noclip")
addToggle(MovePage, "Anti-AFK", "AntiAFK")
addToggle(MovePage, "Anti-Void", "AntiVoid")

-- TAB: Combat
local CombatPage = makeTab("Бой", "⚔")

addToggle(CombatPage, "Убить всех (Murderer)", "KillAll")
addToggle(CombatPage, "Стрелять в убийцу (Sheriff)", "AutoShoot")
addToggle(CombatPage, "Подобрать пушку (Innocent)", "AutoGun")

-- активируем Farm
Pages["Farm"].Visible = true
for _, c in ipairs(TabBar:GetChildren()) do
    if c:IsA("TextButton") and c.Text:find("Farm") then
        c.BackgroundColor3 = Color3.fromRGB(100, 50, 150)
        c.TextColor3 = Color3.fromRGB(255, 255, 255)
    end
end

-- ==========================================
-- 10. FLY (BodyVelocity + BodyGyro)
-- ==========================================
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

function startFly()
    dropConn("fly")
    attachFly()
    trackConn("fly", RunService.Heartbeat:Connect(function()
        if not Settings.FlyEnabled then return end
        local hrp = getHRP()
        if not hrp then return end
        if not S.flyBV or not S.flyBV.Parent then attachFly() end
        if not S.flyBV then return end
        local mv = Vector3.zero
        local cf = Workspace.CurrentCamera.CFrame
        if UserInputService:IsKeyDown(Enum.KeyCode.W) then mv = mv + cf.LookVector end
        if UserInputService:IsKeyDown(Enum.KeyCode.S) then mv = mv - cf.LookVector end
        if UserInputService:IsKeyDown(Enum.KeyCode.A) then mv = mv - cf.RightVector end
        if UserInputService:IsKeyDown(Enum.KeyCode.D) then mv = mv + cf.RightVector end
        if UserInputService:IsKeyDown(Enum.KeyCode.Space) then mv = mv + Vector3.yAxis end
        if UserInputService:IsKeyDown(Enum.KeyCode.LeftShift) then mv = mv - Vector3.yAxis end
        S.flyBV.Velocity = mv.Magnitude > 0 and mv.Unit * Settings.FlySpeed or Vector3.zero
        S.flyBG.CFrame = Workspace.CurrentCamera.CFrame
    end))
end

function stopFly()
    dropConn("fly")
    detachFly()
end

trackConn("fkey", UserInputService.InputBegan:Connect(function(input, gp)
    if gp then return end
    if input.KeyCode == Enum.KeyCode.F then
        Settings.FlyEnabled = not Settings.FlyEnabled
        if Settings.FlyEnabled then startFly() else stopFly() end
    end
end))

-- ==========================================
-- 11. COMBAT (минимальный)
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
    if not Settings.KillAll then return end
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

local function sheriffTick()
    if not Settings.AutoShoot then return end
    if tick() - S.lastShotTick < 0.12 then return end
    S.lastShotTick = tick()

    local gun = getGun()
    if not gun then return end
    local target = getMurdererCached()
    if not target then return end
    local targetHRP = getHRP(target)
    if not targetHRP then return end
    local char = LocalPlayer.Character
    if not char then return end
    if gun.Parent ~= char then
        local hum = getHum()
        if hum then pcall(function() hum:EquipTool(gun) end) end
        task.wait(0.05)
        gun = getGun()
        if not gun then return end
    end
    local shoot = gun:FindFirstChild("Shoot") or gun:FindFirstChild("Shoot", true)
    if not shoot then return end
    local myHRP = getHRP()
    if not myHRP then return end
    if shoot:IsA("RemoteEvent") then
        pcall(function() shoot:FireServer(myHRP.CFrame, CFrame.new(targetHRP.Position)) end)
    end
end

local function innocentTick()
    if not Settings.AutoGun then return end
    if isLocalMurderer() or getGun() then return end
    local gd = Workspace:FindFirstChild("GunDrop", true)
    local hrp = getHRP()
    if not gd or not hrp then return end
    if (gd.Position - hrp.Position).Magnitude > 5 then
        hrp.CFrame = CFrame.new(gd.Position + Vector3.new(0, 2, 0))
    end
end

-- ==========================================
-- 12. MAIN LOOP (не-farm вещи)
-- ==========================================
trackConn("main", RunService.Heartbeat:Connect(function()
    -- noclip
    if Settings.Noclip then
        local char = LocalPlayer.Character
        if char then
            for _, p in ipairs(char:GetDescendants()) do
                if p:IsA("BasePart") then p.CanCollide = false end
            end
        end
    end

    -- anti-void
    if Settings.AntiVoid then
        local hrp = getHRP()
        if hrp then
            if hrp.Position.Y >= 10 then
                S.lastSafeCFrame = hrp.CFrame
            elseif hrp.Position.Y <= -30 and S.lastSafeCFrame then
                hrp.CFrame = S.lastSafeCFrame
                hrp.Velocity = Vector3.zero
                hrp.RotVelocity = Vector3.zero
            end
        end
    end

    -- combat
    if isLocalMurderer() then murderTick() end
    if getGun() then sheriffTick() end
    innocentTick()
end))

-- Anti-AFK
trackConn("afk", LocalPlayer.Idled:Connect(function()
    if not Settings.AntiAFK then return end
    VirtualUser:Button2Down(Vector2.new(0, 0), Workspace.CurrentCamera.CFrame)
    task.wait(1)
    VirtualUser:Button2Up(Vector2.new(0, 0), Workspace.CurrentCamera.CFrame)
end))

-- ==========================================
-- 13. EVENTS (Happy Hub 1:1)
-- ==========================================
local remotes  = ReplicatedStorage:FindFirstChild("Remotes")
local gameplay = remotes and remotes:FindFirstChild("Gameplay")
local coinsStartedEvent  = gameplay and gameplay:FindFirstChild("CoinsStarted")
local coinCollectedEvent = gameplay and gameplay:FindFirstChild("CoinCollected")
local roundEndFadeEvent  = gameplay and gameplay:FindFirstChild("RoundEndFade")
local roundStartEvent    = gameplay and gameplay:FindFirstChild("RoundStart")

if coinsStartedEvent then
    trackConn("coins_started", coinsStartedEvent.OnClientEvent:Connect(function(data)
        markRoundStarted()
        stopCoinCollector()
        S.bagProgress = {}
        if type(data) == "table" and data.Coin then
            if data.Coin.CollectionLimit then
                FARM_GOAL = data.Coin.CollectionLimit
                Settings.CoinLimit = FARM_GOAL
            end
        end
        S.totalCoins = 0
        S.farmTargetCoin = nil
        S.farmBlacklist = {}
        S.farmTouchedCoins = {}
        S.farmLastCollectSpeedAt = 0
        if S.coinCountSetter then S.coinCountSetter(0) end
        S.roundActive = true
        if Settings.FarmEnabled then
            ensureFarmNoclip()
            startCoinCollector()
        end
    end))
end

if coinCollectedEvent then
    trackConn("coin_collected", coinCollectedEvent.OnClientEvent:Connect(function(bagName, currentCoins)
        S.lastCollectTime = tick()
        S.farmLastCollectAt = tick()
        S.farmLastCollectSpeedAt = tick()
        S.farmTargetCoin = nil
        S.farmTargetStartedAt = 0
        S.farmStuckPos = nil
        S.farmStuckAt = 0
        if type(bagName) == "string" and type(currentCoins) == "number" then
            S.bagProgress[bagName] = currentCoins
        end
        S.totalCoins = 0
        for _, v in pairs(S.bagProgress) do
            if type(v) == "number" then S.totalCoins = S.totalCoins + v end
        end
        if S.coinCountSetter then S.coinCountSetter(S.totalCoins) end
    end))
end

if roundStartEvent then
    trackConn("round_start", roundStartEvent.OnClientEvent:Connect(function()
        markRoundStarted()
        stopCoinCollector()
        S.bagProgress = {}
        S.totalCoins = 0
        S.farmTargetCoin = nil
        S.farmBlacklist = {}
        S.farmTouchedCoins = {}
        S.farmLastCollectSpeedAt = 0
        S.roundActive = true
        if S.coinCountSetter then S.coinCountSetter(0) end
        pcall(function()
            for k in pairs(TargetVisibility) do TargetVisibility[k] = nil end
            for k in pairs(VisCache) do VisCache[k] = nil end
        end)
        if Settings.FarmEnabled then
            ensureFarmNoclip()
            task.wait(0.5)
            startCoinCollector()
        end
    end))
end

if roundEndFadeEvent then
    trackConn("round_end", roundEndFadeEvent.OnClientEvent:Connect(function()
        S.roundActive = false
        S.roundStartedAt = 0
        S.roleCache = {}
        stopCoinCollector()
        if Settings.FarmEnabled then restoreFarmNoclip() end
        task.wait(0.05)
        purgeMemoryCaches(true)
    end))
end

-- Watchdog (Happy Hub): перезапуск фарма если что-то сорвалось
trackThread(task.spawn(function()
    while true do
        task.wait(0.5)
        if Settings.FarmEnabled and S.roundActive and not S.coinCollecting and S.totalCoins < FARM_GOAL then
            startCoinCollector()
        end
    end
end))

-- Периодический purge (Happy Hub)
trackThread(task.spawn(function()
    while true do
        task.wait(45)
        pcall(purgeMemoryCaches, false)
        local list = getgenv().__IROSHIDA_STATE.connections
        if list and #list > 60 then
            local alive = {}
            for _, c in ipairs(list) do
                if c then
                    local ok, connected = pcall(function() return c.Connected end)
                    if ok and connected then alive[#alive + 1] = c end
                end
            end
            getgenv().__IROSHIDA_STATE.connections = alive
        end
    end
end))

-- ==========================================
-- 14. CHARACTER HANDLERS
-- ==========================================
trackConn("char_added", LocalPlayer.CharacterAdded:Connect(function()
    MurdererCache.plr = nil
    MurdererCache.time = 0
    for k in pairs(TargetVisibility) do TargetVisibility[k] = nil end
    for k in pairs(VisCache) do VisCache[k] = nil end
    S.lastSafeCFrame = nil
    S.lastCollectTime = 0
    S.farmTargetCoin = nil
    S.coinCollecting = false
    if S.coinConnection then pcall(function() S.coinConnection:Disconnect() end); S.coinConnection = nil end
    S.coinGyro = nil
    S.farmWalkBV = nil
    pcall(purgeMemoryCaches, false)
    S.farmTouchedCoins = {}
    S.farmBlacklist = {}
    S.farmLastCollectAt = 0
    S.farmStartedAt = 0
    S.farmLastFallbackAt = 0
    S.farmStuckPos = nil
    S.farmStuckAt = 0
    S.farmLastCollectSpeedAt = 0
    S.farmTargetStartedAt = 0
    S.lastGyroUpdate = 0
    stopFarmBodyMovers()

    task.wait(0.6)
    if Settings.FlyEnabled then startFly() end
    if Settings.FarmEnabled and S.roundActive then
        task.wait(0.5)
        if not S.coinCollecting then startCoinCollector() end
    end
end))

trackConn("player_removing", Players.PlayerRemoving:Connect(function(plr)
    S.roleCache[plr] = nil
    TargetVisibility[plr] = nil
    VisCache[plr] = nil
end))

-- ==========================================
-- 15. BOOT
-- ==========================================
hookFade()
trackThread(task.spawn(function()
    while true do
        task.wait(3)
        hookFade()
    end
end))

-- Пытаемся определить roundActive при загрузке в разгаре раунда
trackThread(task.spawn(function()
    task.wait(1)
    local cc = getCoinContainer()
    if cc then
        local coins = getAllCoins()
        if #coins > 0 then
            S.roundActive = true
            if Settings.FarmEnabled and not S.coinCollecting then
                startCoinCollector()
            end
        end
    end
end))

print("[Iroshida v11.0] Готов. Farm: Happy Hub 1:1 · Memory: purge/watchdog active.")
