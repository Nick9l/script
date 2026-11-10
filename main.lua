
-- ==========================================
-- IraShida: Main Core & UI
-- ==========================================

local IraShida = {
    Modules = {},
    Settings = {},
    Connections = {},
    Version = "0.1.0"
}

-- 1. Загрузка конфигурации (settings.lua)
local configUrl = "https://raw.githubusercontent.com/ТВОЙ_НИК/IraShida/main/config/settings.lua"
local ok, config = pcall(function()
    return loadstring(game:HttpGet(configUrl))()
end)
if ok and type(config) == "table" then
    IraShida.Settings = config
else
    warn("[IraShida] Не удалось загрузить settings.lua, используем дефолт.")
    IraShida.Settings = {
        ApiKey = "",
        Theme = "Darker"
    }
end

-- 2. Загрузчик модулей
local function LoadModule(name)
    local url = "https://raw.githubusercontent.com/ТВОЙ_НИК/IraShida/main/modules/" .. name .. ".lua"
    local success, code = pcall(function() return game:HttpGet(url) end)
    if not success then
        warn("[IraShida] Модуль не найден (404): " .. name)
        return nil
    end
    local func, err = loadstring(code)
    if not func then
        warn("[IraShida] Синтаксическая ошибка в модуле " .. name .. ": " .. tostring(err))
        return nil
    end
    
    local moduleTable = func()
    if type(moduleTable) == "table" then
        print("[IraShida] Модуль загружен: " .. name)
        return moduleTable
    else
        warn("[IraShida] Модуль " .. name .. " вернул не таблицу.")
        return nil
    end
end

-- Загружаем модули (если файла нет, скрипт не упадет, просто выдаст warn)
IraShida.Modules.AutoFarm = LoadModule("auto_farm")
IraShida.Modules.Combat = LoadModule("combat")
IraShida.Modules.TradeHelper = LoadModule("trade_helper")
IraShida.Modules.Movement = LoadModule("movement")

-- 3. Загрузка Fluent UI
local Fluent = loadstring(game:HttpGet("https://github.com/dawid-scripts/Fluent/releases/latest/download/main.lua"))()
local SaveManager = loadstring(game:HttpGet("https://raw.githubusercontent.com/dawid-scripts/Fluent/master/Addons/SaveManager.lua"))()
local InterfaceManager = loadstring(game:HttpGet("https://raw.githubusercontent.com/dawid-scripts/Fluent/master/Addons/InterfaceManager.lua"))()

local Window = Fluent:CreateWindow({
    Title = "IraShida",
    SubTitle = "v" .. IraShida.Version .. " | MM2 Suite",
    TabWidth = 140,
    Size = UDim2.fromOffset(520, 400),
    Acrylic = true,
    Theme = IraShida.Settings.Theme or "Darker",
    MinimizeKey = Enum.KeyCode.LeftControl
})

local Tabs = {
    Home    = Window:AddTab({ Title = "Home", Icon = "home" }),
    Combat  = Window:AddTab({ Title = "Combat", Icon = "crosshair" }),
    Visuals = Window:AddTab({ Title = "Visuals", Icon = "eye" }),
    Farm    = Window:AddTab({ Title = "Farm", Icon = "coins" }),
    Trade   = Window:AddTab({ Title = "Trade", Icon = "repeat" }),
    Settings= Window:AddTab({ Title = "Settings", Icon = "settings" })
}

local Options = Fluent.Options

-- ==========================================
-- ВКЛАДКА: HOME
-- ==========================================
do
    Tabs.Home:AddSection("IraShida Suite")
    Tabs.Home:AddParagraph({
        Title = "Добро пожаловать!",
        Content = "Модульный чит для Murder Mystery 2.\nВерсия: " .. IraShida.Version
    })
    
    Tabs.Home:AddToggle("QuickESP", {
        Title = "Быстрый ESP (Роли)",
        Default = false,
        Callback = function(v)
            if IraShida.Modules.Combat and IraShida.Modules.Combat.SetESP then
                IraShida.Modules.Combat.SetESP(v)
            end
        end
    })
    Tabs.Home:AddToggle("QuickFarm", {
        Title = "Быстрый Автофарм",
        Default = false,
        Callback = function(v)
            if IraShida.Modules.AutoFarm then
                IraShida.Modules.AutoFarm.Settings.Enabled = v
            end
        end
    })
end

-- ==========================================
-- ВКЛАДКА: COMBAT (Заглушка)
-- ==========================================
do
    Tabs.Combat:AddSection("Aimbot")
    Tabs.Combat:AddToggle("AimbotToggle", {
        Title = "Enable Aimbot",
        Default = false,
        Callback = function(v)
            -- Сюда мы позже привяжем Combat модуль
            print("Aimbot set to:", v)
        end
    })
    Tabs.Combat:AddParagraph({ Title = "Модуль", Content = "Модуль Combat ещё не подключен." })
end

-- ==========================================
-- ВКЛАДКА: VISUALS (Заглушка)
-- ==========================================
do
    Tabs.Visuals:AddSection("ESP")
    Tabs.Visuals:AddToggle("ESPToggle", {
        Title = "Role ESP",
        Default = false,
        Callback = function(v)
            if IraShida.Modules.Combat and IraShida.Modules.Combat.SetESP then
                IraShida.Modules.Combat.SetESP(v)
            end
        end
    })
end

-- ==========================================
-- ВКЛАДКА: FARM (Подключение к модулю)
-- ==========================================
do
    Tabs.Farm:AddSection("Auto Farm")
    Tabs.Farm:AddToggle("FarmEnable", {
        Title = "Auto Farm Coins",
        Default = false,
        Callback = function(v)
            if IraShida.Modules.AutoFarm then
                IraShida.Modules.AutoFarm.Settings.Enabled = v
            else
                Fluent:Notify({ Title = "Ошибка", Content = "Модуль AutoFarm не загружен!", Duration = 3 })
            end
        end
    })
    Tabs.Farm:AddSlider("FarmSpeed", {
        Title = "Tween Speed",
        Default = 28,
        Min = 10,
        Max = 60,
        Rounding = 0,
        Callback = function(v)
            if IraShida.Modules.AutoFarm then
                IraShida.Modules.AutoFarm.Settings.TweenSpeed = v
            end
        end
    })
end

-- ==========================================
-- ВКЛАДКА: TRADE (Подключение к модулю)
-- ==========================================
do
    Tabs.Trade:AddSection("Trade Helper")
    Tabs.Trade:AddParagraph({
        Title = "Настройка API",
        Content = "Введите свой ключ RBLXValue ниже."
    })
    Tabs.Trade:AddInput("ApiKey", {
        Title = "API Ключ",
        Default = IraShida.Settings.ApiKey or "",
        Placeholder = "rbx_...",
        Callback = function(v)
            IraShida.Settings.ApiKey = v
        end
    })
    Tabs.Trade:AddToggle("TradeHelperEnable", {
        Title = "Включить Trade Helper",
        Default = false,
        Callback = function(v)
            if IraShida.Modules.TradeHelper and IraShida.Modules.TradeHelper.Toggle then
                IraShida.Modules.TradeHelper.Toggle(v)
            else
                Fluent:Notify({ Title = "Ошибка", Content = "Модуль TradeHelper не загружен!", Duration = 3 })
            end
        end
    })
end

-- ==========================================
-- ВКЛАДКА: SETTINGS
-- ==========================================
do
    Tabs.Settings:AddSection("О скрипте")
    Tabs.Settings:AddParagraph({ Title = "IraShida", Content = "Разработано для сообщества.\nМодульная архитектура." })
    
    Tabs.Settings:AddButton({
        Title = "Выгрузить скрипт",
        Description = "Очищает все соединения и UI",
        Callback = function()
            -- Функция очистки
            for _, conn in pairs(IraShida.Connections) do
                pcall(function() conn:Disconnect() end)
            end
            if getgenv().IraShida_UI then
                getgenv().IraShida_UI:Destroy()
            end
            if Fluent then
                Fluent:Destroy()
            end
            print("[IraShida] Скрипт выгружен.")
        end
    })
end

-- Менеджеры конфигов
SaveManager:SetLibrary(Fluent)
InterfaceManager:SetLibrary(Fluent)
SaveManager:IgnoreThemeSettings()
SaveManager:SetFolder("IraShida")
InterfaceManager:BuildInterfaceSection(Tabs.Settings)
SaveManager:BuildConfigSection(Tabs.Settings)

Window:SelectTab(1)

Fluent:Notify({
    Title = "IraShida",
    Content = "Успешно загружен! v" .. IraShida.Version,
    Duration = 4
})

getgenv().IraShida = IraShida
