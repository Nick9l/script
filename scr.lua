-- Мой Trade Helper
local ScreenGui = Instance.new("ScreenGui")
ScreenGui.Parent = game.CoreGui
ScreenGui.Name = "MyTradeHelper"

-- Главное окно
local MainFrame = Instance.new("Frame")
MainFrame.Parent = ScreenGui
MainFrame.Size = UDim2.new(0, 320, 0, 260)
MainFrame.Position = UDim2.new(0.5, -160, 0.5, -130)
MainFrame.BackgroundColor3 = Color3.fromRGB(30, 30, 30)
MainFrame.BorderSizePixel = 2
MainFrame.BorderColor3 = Color3.fromRGB(255, 255, 255)
MainFrame.Active = true
MainFrame.Draggable = true

-- Заголовок
local Title = Instance.new("TextLabel")
Title.Parent = MainFrame
Title.Size = UDim2.new(1, 0, 0, 35)
Title.BackgroundColor3 = Color3.fromRGB(50, 50, 50)
Title.Text = "MM2 Trade Helper v1.0"
Title.TextColor3 = Color3.fromRGB(255, 255, 255)
Title.Font = Enum.Font.SourceSansBold
Title.TextSize = 18

-- Поле для твоего предмета
local MyItemBox = Instance.new("TextBox")
MyItemBox.Parent = MainFrame
MyItemBox.Size = UDim2.new(0.8, 0, 0, 35)
MyItemBox.Position = UDim2.new(0.1, 0, 0.2, 0)
MyItemBox.PlaceholderText = "Твой предмет"
MyItemBox.Text = ""
MyItemBox.BackgroundColor3 = Color3.fromRGB(60, 60, 60)
MyItemBox.TextColor3 = Color3.fromRGB(255, 255, 255)
MyItemBox.Font = Enum.Font.SourceSans
MyItemBox.TextSize = 14

-- Поле для его предмета
local HisItemBox = Instance.new("TextBox")
HisItemBox.Parent = MainFrame
HisItemBox.Size = UDim2.new(0.8, 0, 0, 35)
HisItemBox.Position = UDim2.new(0.1, 0, 0.38, 0)
HisItemBox.PlaceholderText = "Его предмет"
HisItemBox.Text = ""
HisItemBox.BackgroundColor3 = Color3.fromRGB(60, 60, 60)
HisItemBox.TextColor3 = Color3.fromRGB(255, 255, 255)
HisItemBox.Font = Enum.Font.SourceSans
HisItemBox.TextSize = 14

-- Кнопка
local CalcButton = Instance.new("TextButton")
CalcButton.Parent = MainFrame
CalcButton.Size = UDim2.new(0.8, 0, 0, 35)
CalcButton.Position = UDim2.new(0.1, 0, 0.6, 0)
CalcButton.Text = "Посчитать"
CalcButton.BackgroundColor3 = Color3.fromRGB(0, 150, 0)
CalcButton.TextColor3 = Color3.fromRGB(255, 255, 255)
CalcButton.Font = Enum.Font.SourceSansBold
CalcButton.TextSize = 16

-- Поле для результата
local ResultLabel = Instance.new("TextLabel")
ResultLabel.Parent = MainFrame
ResultLabel.Size = UDim2.new(0.8, 0, 0, 50)
ResultLabel.Position = UDim2.new(0.1, 0, 0.8, 0)
ResultLabel.BackgroundColor3 = Color3.fromRGB(40, 40, 40)
ResultLabel.Text = "Результат"
ResultLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
ResultLabel.Font = Enum.Font.SourceSans
ResultLabel.TextSize = 14
ResultLabel.TextWrapped = true

-- Логика кнопки (пока заглушка)
CalcButton.MouseButton1Click:Connect(function()
    local myItem = MyItemBox.Text
    local hisItem = HisItemBox.Text
    
    if myItem == "" or hisItem == "" then
        ResultLabel.Text = "Введи названия предметов!"
        return
    end
    
    ResultLabel.Text = "Ты: " .. myItem .. "\nОн: " .. hisItem .. "\n(Тут будет подсчёт)"
end)