--!nolint
local Players           = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService      = game:GetService("TweenService")
local UserInputService  = game:GetService("UserInputService")

local player  = Players.LocalPlayer
local remotes = ReplicatedStorage:WaitForChild("Remotes")
local RollRequest = remotes:WaitForChild("RollRequest")
local RollResult  = remotes:WaitForChild("RollResult")
local StateUpdate = remotes:WaitForChild("StateUpdate")

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

local title = makeLabel({ Position = UDim2.fromOffset(12, 10), Size = UDim2.fromOffset(276, 24), Text = "RNG — 1x luck", Font = Enum.Font.GothamBold, TextSize = 17 })
title.Parent = frame

local resultLabel = makeLabel({ Position = UDim2.fromOffset(12, 40), Size = UDim2.fromOffset(276, 66), Text = "Press Roll", Font = Enum.Font.GothamBlack, TextSize = 26, TextXAlignment = Enum.TextXAlignment.Center, TextYAlignment = Enum.TextYAlignment.Center })
resultLabel.Parent = frame

local rollButton = Instance.new("TextButton")
rollButton.Position = UDim2.fromOffset(12, 116)
rollButton.Size = UDim2.fromOffset(276, 44)
rollButton.BackgroundColor3 = Color3.fromRGB(70, 130, 255)
rollButton.BorderSizePixel = 0
rollButton.Font = Enum.Font.GothamBold
rollButton.TextSize = 16
rollButton.TextColor3 = Color3.fromRGB(255, 255, 255)
rollButton.Text = "ROLL"
rollButton.Parent = frame
Instance.new("UICorner", rollButton).CornerRadius = UDim.new(0, 8)

local oddsLabel = makeLabel({ Position = UDim2.fromOffset(12, 172), Size = UDim2.fromOffset(276, 150), Text = "", TextSize = 13, TextColor3 = Color3.fromRGB(200, 200, 215) })
oddsLabel.Parent = frame

local invLabel = makeLabel({ Position = UDim2.fromOffset(12, 328), Size = UDim2.fromOffset(276, 120), Text = "", TextSize = 13, TextColor3 = Color3.fromRGB(200, 200, 215) })
invLabel.Parent = frame

local messageLabel = makeLabel({ Position = UDim2.fromOffset(12, 446), Size = UDim2.fromOffset(276, 20), Text = "", TextSize = 12, TextColor3 = Color3.fromRGB(255, 160, 160) })
messageLabel.Parent = frame

local function renderOdds(odds)
	if not odds then return end
	local lines = { "Chances:" }
	for _, row in ipairs(odds) do table.insert(lines, string.format("%s — %.4f%%", row.display, row.chance * 100)) end
	oddsLabel.Text = table.concat(lines, "\n")
end

local function renderInventory(inv)
	if not inv then return end
	local parts = {}
	for id, count in pairs(inv) do if count > 0 then table.insert(parts, string.format("%s x%d", id, count)) end end
	table.sort(parts)
	invLabel.Text = #parts > 0 and ("Inventory:\n" .. table.concat(parts, "\n")) or "Inventory: empty"
end

local function showMessage(text)
	messageLabel.Text = text
	task.delay(2.5, function() if messageLabel.Text == text then messageLabel.Text = "" end end)
end

rollButton.Activated:Connect(function() RollRequest:FireServer() end)
UserInputService.InputBegan:Connect(function(input, processed)
	if processed then return end
	if input.KeyCode == Enum.KeyCode.R then RollRequest:FireServer() end
end)

RollResult.OnClientEvent:Connect(function(data)
	resultLabel.Text = string.format("%s\n1 in %d", data.display, data.oneIn)
	resultLabel.TextColor3 = data.color
	resultLabel.TextSize = 34
	TweenService:Create(resultLabel, TweenInfo.new(0.35), { TextSize = 26 }):Play()
	renderInventory(data.inventory)
end)

StateUpdate.OnClientEvent:Connect(function(data)
	if data.type == "init" or data.type == "state" then
		title.Text = string.format("RNG — %sx luck", data.luck)
		renderOdds(data.odds)
		renderInventory(data.inventory)
	elseif data.type == "message" then
		showMessage(data.text)
	end
end)
