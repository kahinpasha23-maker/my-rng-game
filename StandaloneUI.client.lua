--!nolint
local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")

local player = Players.LocalPlayer

-- Build UI
local gui = Instance.new("ScreenGui")
gui.Name = "RNGGui"
gui.ResetOnSpawn = false
gui.Parent = player:WaitForChild("PlayerGui")

local frame = Instance.new("Frame")
frame.AnchorPoint = Vector2.new(0, 0.5)
frame.Position = UDim2.new(0, 16, 0.5, 0)
frame.Size = UDim2.fromOffset(300, 460)
frame.BackgroundColor3 = Color3.fromRGB(22, 22, 30)
frame.BackgroundTransparency = 0.08
frame.BorderSizePixel = 0
frame.Parent = gui
Instance.new("UICorner", frame).CornerRadius = UDim.new(0, 10)

local function makeLabel(props)
	local l = Instance.new("TextLabel")
	l.BackgroundTransparency = 1
	l.Font = Enum.Font.GothamMedium
	l.TextColor3 = Color3.fromRGB(235, 235, 245)
	l.TextXAlignment = Enum.TextXAlignment.Left
	l.TextYAlignment = Enum.TextYAlignment.Top
	l.TextWrapped = true
	l.TextSize = 14
	for k, v in pairs(props) do l[k] = v end
	return l
end

local title = makeLabel({Position = UDim2.fromOffset(12, 10), Size = UDim2.fromOffset(276, 24), Text = "RNG — 1x luck", Font = Enum.Font.GothamBold, TextSize = 17})
title.Parent = frame

local resultLabel = makeLabel({Position = UDim2.fromOffset(12, 40), Size = UDim2.fromOffset(276, 66), Text = "Press Roll", Font = Enum.Font.GothamBlack, TextSize = 26, TextXAlignment = Enum.TextXAlignment.Center, TextYAlignment = Enum.TextYAlignment.Center})
resultLabel.Parent = frame

local rollButton = Instance.new("TextButton")
rollButton.Position = UDim2.fromOffset(12, 116)
rollButton.Size = UDim2.fromOffset(276, 44)
rollButton.BackgroundColor3 = Color3.fromRGB(70, 130, 255)
rollButton.BorderSizePixel = 0
rollButton.Font = Enum.Font.GothamBold
rollButton.TextSize = 16
rollButton.TextColor3 = Color3.fromRGB(255, 255, 255)
rollButton.Text = "ROLL (LOCAL FAKE)"
rollButton.Parent = frame
Instance.new("UICorner", rollButton).CornerRadius = UDim.new(0, 8)

local oddsLabel = makeLabel({Position = UDim2.fromOffset(12, 172), Size = UDim2.fromOffset(276, 150), Text = "Chances:\nCommon — 80%\nRare — 15%\nLegendary — 5%", TextSize = 13, TextColor3 = Color3.fromRGB(200, 200, 215)})
oddsLabel.Parent = frame

rollButton.Activated:Connect(function()
    local r = math.random(1, 100)
    if r <= 80 then
        resultLabel.Text = "Common\n1 in 1"
        resultLabel.TextColor3 = Color3.fromRGB(190,190,190)
    elseif r <= 95 then
        resultLabel.Text = "Rare\n1 in 25"
        resultLabel.TextColor3 = Color3.fromRGB(90,160,255)
    else
        resultLabel.Text = "Legendary\n1 in 1000"
        resultLabel.TextColor3 = Color3.fromRGB(255,190,60)
    end
end)
