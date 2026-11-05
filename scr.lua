-- ==========================================
-- MM2 TRADE HELPER v4.1 (Debug Edition)
-- ==========================================

local YOUR_NAME = "Nick9l"
local key_p1 = "rbx_" 
local key_p2 = "5853d75be1c90cdaf60d8f62a89507bbdc2818578a4142e2" -- Напоминаю, без 'rbx_'
local API_KEY = key_p1 .. key_p2
local API_URL = "https://api.rblxvalue.com/v2/items/"

local RARITY_COLORS = {
    ["Common"] = Color3.fromRGB(150, 150, 150),
    ["Uncommon"] = Color3.fromRGB(0, 255, 255),
    ["Rare"] = Color3.fromRGB(0, 255, 0),
    ["Legendary"] = Color3.fromRGB(255, 50, 50),
    ["Godly"] = Color3.fromRGB(170, 0, 255),
    ["Chroma"] = Color3.fromRGB(255, 0, 128),
    ["Ancient"] = Color3.fromRGB(255, 165, 0),
}

-- Загрузочный экран
local SplashGui = Instance.new("ScreenGui")
SplashGui.Parent = game.CoreGui
local SplashFrame = Instance.new("Frame")
SplashFrame.Parent = SplashGui
SplashFrame.Size = UDim2.new(1, 0, 1, 0)
SplashFrame.BackgroundColor3 = Color3.fromRGB(20, 20, 20)
local SplashText = Instance.new("TextLabel")
SplashText.Parent = SplashFrame
SplashText.Size = UDim2.new(1, 0, 1, 0)
SplashText.BackgroundTransparency = 1
SplashText.Text = "Добро пожаловать, " .. YOUR_NAME .. "!"
SplashText.TextColor3 = Color3.fromRGB(255, 255, 255)
SplashText.Font = Enum.Font.SourceSansBold
SplashText.TextSize = 30
task.wait(1.5)
SplashGui:Destroy()

-- Интерфейс
local ScreenGui = Instance.new("ScreenGui")
ScreenGui.Parent = game.CoreGui
local MainFrame = Instance.new("Frame")
MainFrame.Parent = ScreenGui
MainFrame.Size = UDim2.new(0, 520, 0, 450)
MainFrame.Position = UDim2.new(0.5, -260, 0.5, -225)
MainFrame.BackgroundColor3 = Color3.fromRGB(25, 25, 25)
MainFrame.BorderSizePixel = 2
MainFrame.BorderColor3 = Color3.fromRGB(255, 255, 255)
MainFrame.Active = true
MainFrame.Draggable = true

local Title = Instance.new("TextLabel")
Title.Parent = MainFrame
Title.Size = UDim2.new(1, 0, 0, 35)
Title.BackgroundColor3 = Color3.fromRGB(40, 40, 40)
Title.Text = "MM2 Trade Helper | " .. YOUR_NAME
Title.TextColor3 = Color3.fromRGB(255, 255, 255)
Title.Font = Enum.Font.SourceSansBold
Title.TextSize = 18

local function createTradeSide(xOffset, titleText)
    local SideFrame = Instance.new("Frame")
    SideFrame.Parent = MainFrame
    SideFrame.Size = UDim2.new(0.45, 0, 0.6, 0)
    SideFrame.Position = UDim2.new(xOffset, 0, 0.1, 0)
    SideFrame.BackgroundColor3 = Color3.fromRGB(35, 35, 35)
    
    local SideTitle = Instance.new("TextLabel")
    SideTitle.Parent = SideFrame
    SideTitle.Size = UDim2.new(1, 0, 0, 25)
    SideTitle.BackgroundColor3 = Color3.fromRGB(50, 50, 50)
    SideTitle.Text = titleText
    SideTitle.TextColor3 = Color3.fromRGB(255, 255, 255)
    SideTitle.Font = Enum.Font.SourceSansBold
    
    local InputBox = Instance.new("TextBox")
    InputBox.Parent = SideFrame
    InputBox.Size = UDim2.new(0.65, 0, 0, 30)
    InputBox.Position = UDim2.new(0.05, 0, 0.1, 0)
    InputBox.PlaceholderText = "Название..."
    InputBox.BackgroundColor3 = Color3.fromRGB(60, 60, 60)
    InputBox.TextColor3 = Color3.fromRGB(255, 255, 255)
    
    local AddBtn = Instance.new("TextButton")
    AddBtn.Parent = SideFrame
    AddBtn.Size = UDim2.new(0.25, 0, 0, 30)
    AddBtn.Position = UDim2.new(0.72, 0, 0.1, 0)
    AddBtn.Text = "+"
    AddBtn.BackgroundColor3 = Color3.fromRGB(0, 150, 0)
    AddBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
    AddBtn.Font = Enum.Font.SourceSansBold
    AddBtn.TextSize = 20
    
    local ListFrame = Instance.new("ScrollingFrame")
    ListFrame.Parent = SideFrame
    ListFrame.Size = UDim2.new(0.9, 0, 0.7, 0)
    ListFrame.Position = UDim2.new(0.05, 0, 0.22, 0)
    ListFrame.BackgroundTransparency = 1
    ListFrame.CanvasSize = UDim2.new(0, 0, 0, 0)
    
    local UIListLayout = Instance.new("UIListLayout")
    UIListLayout.Parent = ListFrame
    UIListLayout.SortOrder = Enum.SortOrder.LayoutOrder
    UIListLayout.Padding = UDim.new(0, 2)
    
    local SideSum = Instance.new("TextLabel")
    SideSum.Parent = SideFrame
    SideSum.Size = UDim2.new(1, 0, 0, 25)
    SideSum.Position = UDim2.new(0, 0, 0.95, 0)
    SideSum.BackgroundColor3 = Color3.fromRGB(45, 45, 45)
    SideSum.Text = "Сумма: 0"
    SideSum.TextColor3 = Color3.fromRGB(255, 255, 255)
    SideSum.Font = Enum.Font.SourceSansBold

    return InputBox, AddBtn, ListFrame, SideSum
end

local MyInput, MyAdd, MyList, MySumLabel = createTradeSide(0.02, "Твои предметы")
local HisInput, HisAdd, HisList, HisSumLabel = createTradeSide(0.53, "Предметы оппонента")

-- Шкала
local BarBackground = Instance.new("Frame")
BarBackground.Parent = MainFrame
BarBackground.Size = UDim2.new(0.9, 0, 0, 20)
BarBackground.Position = UDim2.new(0.05, 0, 0.75, 0)
BarBackground.BackgroundColor3 = Color3.fromRGB(50, 50, 50)

local BarFill = Instance.new("Frame")
BarFill.Parent = BarBackground
BarFill.Size = UDim2.new(0.5, 0, 1, 0)
BarFill.Position = UDim2.new(0.5, 0, 0, 0)
BarFill.BackgroundColor3 = Color3.fromRGB(255, 255, 255)

local ResultText = Instance.new("TextLabel")
ResultText.Parent = MainFrame
ResultText.Size = UDim2.new(0.9, 0, 0, 40)
ResultText.Position = UDim2.new(0.05, 0, 0.83, 0)
ResultText.BackgroundTransparency = 1
ResultText.Text = "Ожидание..."
ResultText.TextColor3 = Color3.fromRGB(255, 255, 255)
ResultText.Font = Enum.Font.SourceSansBold
ResultText.TextSize = 16
ResultText.TextWrapped = true

local myItems = {}
local hisItems = {}

local function getItemData(name)
    local encodedName = string.gsub(name, " ", "%%20")
    local url = API_URL .. encodedName
    
    local success, response = pcall(function()
        -- Добавил true для HttpGetAsync, чтобы он не крашил игру
        return game:HttpGetAsync(url, true, {["X-Api-Key"] = API_KEY})
    end)

    if success then
        -- Пытаемся найти цену
        local value = string.match(response, '"value":%s*(%d+)')
        if not value then value = string.match(response, '"price":%s*(%d+)') end
        
        local rarity = string.match(response, '"rarity":"([^"]+)"')
        
        if value then
            return tonumber(value), rarity or "Unknown", "OK"
        else
            -- Если ответ есть, но цены нет, возможно предмет не найден
            return 0, "Unknown", "Предмет не найден (или неверное имя)"
        end
    else
        -- Если запрос не прошел, выводим ошибку
        return 0, "Unknown", "Ошибка API: " .. tostring(response)
    end
end

local function updateUI()
    for _, child in ipairs(MyList:GetChildren()) do if child:IsA("TextLabel") then child:Destroy() end end
    for _, child in ipairs(HisList:GetChildren()) do if child:IsA("TextLabel") then child:Destroy() end end

    local myTotal = 0
    local hisTotal = 0
    local lastError = ""

    for i, item in ipairs(myItems) do
        local val, rarity, status = getItemData(item.name)
        if status ~= "OK" then lastError = status end
        myTotal = myTotal + (val * item.count)
        
        local lbl = Instance.new("TextLabel")
        lbl.Parent = MyList
        lbl.Size = UDim2.new(0.8, 0, 0, 25)
        lbl.BackgroundTransparency = 1
        lbl.Text = item.name .. (item.count > 1 and " x" .. item.count or "") .. " (" .. val .. ")"
        lbl.TextColor3 = RARITY_COLORS[rarity] or Color3.fromRGB(255, 255, 255)
        lbl.TextXAlignment = Enum.TextXAlignment.Left
        lbl.LayoutOrder = i
        
        -- Кнопка добавления
        local plusBtn = Instance.new("TextButton")
        plusBtn.Parent = lbl
        plusBtn.Size = UDim2.new(0.1, 0, 1, 0)
        plusBtn.Position = UDim2.new(0.6, 0, 0, 0)
        plusBtn.BackgroundColor3 = Color3.fromRGB(0, 100, 0)
        plusBtn.Text = "+"
        plusBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
        plusBtn.MouseButton1Click:Connect(function()
            item.count = item.count + 1
            updateUI()
        end)

        -- Кнопка удаления (корзина)
        local delBtn = Instance.new("TextButton")
        delBtn.Parent = lbl
        delBtn.Size = UDim2.new(0.1, 0, 1, 0)
        delBtn.Position = UDim2.new(0.85, 0, 0, 0)
        delBtn.BackgroundColor3 = Color3.fromRGB(150, 0, 0)
        delBtn.Text = "X"
        delBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
        delBtn.MouseButton1Click:Connect(function()
            table.remove(myItems, i)
            updateUI()
        end)
    end
    MyList.CanvasSize = UDim2.new(0, 0, 0, #myItems * 27)

    for i, item in ipairs(hisItems) do
        local val, rarity, status = getItemData(item.name)
        if status ~= "OK" then lastError = status end
        hisTotal = hisTotal + (val * item.count)
        
        local lbl = Instance.new("TextLabel")
        lbl.Parent = HisList
        lbl.Size = UDim2.new(0.8, 0, 0, 25)
        lbl.BackgroundTransparency = 1
        lbl.Text = item.name .. (item.count > 1 and " x" .. item.count or "") .. " (" .. val .. ")"
        lbl.TextColor3 = RARITY_COLORS[rarity] or Color3.fromRGB(255, 255, 255)
        lbl.TextXAlignment = Enum.TextXAlignment.Left
        lbl.LayoutOrder = i
        
        local plusBtn = Instance.new("TextButton")
        plusBtn.Parent = lbl
        plusBtn.Size = UDim2.new(0.1, 0, 1, 0)
        plusBtn.Position = UDim2.new(0.6, 0, 0, 0)
        plusBtn.BackgroundColor3 = Color3.fromRGB(0, 100, 0)
        plusBtn.Text = "+"
        plusBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
        plusBtn.MouseButton1Click:Connect(function()
            item.count = item.count + 1
            updateUI()
        end)

        local delBtn = Instance.new("TextButton")
        delBtn.Parent = lbl
        delBtn.Size = UDim2.new(0.1, 0, 1, 0)
        delBtn.Position = UDim2.new(0.85, 0, 0, 0)
        delBtn.BackgroundColor3 = Color3.fromRGB(150, 0, 0)
        delBtn.Text = "X"
        delBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
        delBtn.MouseButton1Click:Connect(function()
            table.remove(hisItems, i)
            updateUI()
        end)
    end
    HisList.CanvasSize = UDim2.new(0, 0, 0, #hisItems * 27)

    MySumLabel.Text = "Сумма: " .. myTotal
    HisSumLabel.Text = "Сумма: " .. hisTotal

    local total = myTotal + hisTotal
    if total > 0 then
        local myRatio = myTotal / total
        BarFill.Size = UDim2.new(myRatio, 0, 1, 0)
        BarFill.Position = UDim2.new(1 - myRatio, 0, 0, 0)
    else
        BarFill.Size = UDim2.new(0.5, 0, 1, 0)
        BarFill.Position = UDim2.new(0.5, 0, 0, 0)
    end

    if myTotal > hisTotal then
        ResultText.Text = "🔥 Ты выигрываешь на " .. (myTotal - hisTotal) .. "!"
        ResultText.TextColor3 = Color3.fromRGB(0, 255, 0)
        BarFill.BackgroundColor3 = Color3.fromRGB(0, 255, 0)
    elseif myTotal < hisTotal then
        ResultText.Text = "❌ Ты проигрываешь на " .. (hisTotal - myTotal) .. "!"
        ResultText.TextColor3 = Color3.fromRGB(255, 50, 50)
        BarFill.BackgroundColor3 = Color3.fromRGB(255, 50, 50)
    else
        ResultText.Text = "⚖️ Равный обмен"
        ResultText.TextColor3 = Color3.fromRGB(255, 255, 255)
        BarFill.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
    end
    
    -- Если была ошибка API, выводим её внизу красным
    if lastError ~= "" then
        ResultText.Text = ResultText.Text .. "\n(" .. lastError .. ")"
        ResultText.TextColor3 = Color3.fromRGB(255, 150, 0) -- Оранжевый
    end
end

MyAdd.MouseButton1Click:Connect(function()
    if MyInput.Text ~= "" then
        table.insert(myItems, {name = MyInput.Text, count = 1})
        MyInput.Text = ""
        updateUI()
    end
end)

HisAdd.MouseButton1Click:Connect(function()
    if HisInput.Text ~= "" then
        table.insert(hisItems, {name = HisInput.Text, count = 1})
        HisInput.Text = ""
        updateUI()
    end
end)
