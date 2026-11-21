--!nolint
local Players           = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local DataStoreService  = game:GetService("DataStoreService")
local TextChatService   = game:GetService("TextChatService")

local CONFIG = {
	RollCooldown      = 1.5,
	MaxRollsPerMinute = 30,
	CommandPrefix     = "!roll",
	MaxBatch          = 10,
	BaseLuck          = 1,
	MaxLuck           = 1000,
	DataStoreName     = "RNG_PlayerData_v1",
	SaveInterval      = 120,
	AdminUserIds      = {
		-- [123456789] = true,   <-- put your UserId here to use !roll setluck
	},
	Rarities = {
		{ id = "Common",       display = "Common",       oneIn = 1,       color = Color3.fromRGB(190,190,190) },
		{ id = "Uncommon",     display = "Uncommon",     oneIn = 4,       color = Color3.fromRGB(120,220,120) },
		{ id = "Rare",         display = "Rare",         oneIn = 25,      color = Color3.fromRGB(90,160,255) },
		{ id = "Epic",         display = "Epic",         oneIn = 150,     color = Color3.fromRGB(180,110,255) },
		{ id = "Legendary",    display = "Legendary",    oneIn = 1000,    color = Color3.fromRGB(255,190,60) },
		{ id = "Mythic",       display = "Mythic",       oneIn = 10000,   color = Color3.fromRGB(255,80,80) },
		{ id = "Divine",       display = "Divine",       oneIn = 100000,  color = Color3.fromRGB(120,255,255) },
		{ id = "Transcendent", display = "Transcendent", oneIn = 1000000, color = Color3.fromRGB(255,255,255) },
	},
}

local dataStore = DataStoreService:GetDataStore(CONFIG.DataStoreName)

local remotesFolder = ReplicatedStorage:FindFirstChild("Remotes")
if not remotesFolder then
	remotesFolder = Instance.new("Folder")
	remotesFolder.Name = "Remotes"
	remotesFolder.Parent = ReplicatedStorage
end

local function ensureRemote(name)
	local r = remotesFolder:FindFirstChild(name)
	if not r then
		r = Instance.new("RemoteEvent")
		r.Name = name
		r.Parent = remotesFolder
	end
	return r
end

local RollRequest = ensureRemote("RollRequest")
local RollResult  = ensureRemote("RollResult")
local StateUpdate = ensureRemote("StateUpdate")

local function getWeights(luck)
	local weights, total = {}, 0
	for i, rarity in ipairs(CONFIG.Rarities) do
		local w = 1 / rarity.oneIn
		if rarity.oneIn > 1 then w *= luck end
		weights[i] = w
		total += w
	end
	return weights, total
end

local function doRoll(rng, luck)
	local weights, total = getWeights(luck)
	local target = rng:NextNumber() * total
	local acc = 0
	for i, rarity in ipairs(CONFIG.Rarities) do
		acc += weights[i]
		if target <= acc then return rarity end
	end
	return CONFIG.Rarities[#CONFIG.Rarities]
end

local function getChances(luck)
	local weights, total = getWeights(luck)
	local out = {}
	for i, rarity in ipairs(CONFIG.Rarities) do
		table.insert(out, { id = rarity.id, display = rarity.display, color = rarity.color, chance = weights[i] / total })
	end
	return out
end

local playerState = {}
local function defaultData() return { luck = CONFIG.BaseLuck, inventory = {} } end

local function loadData(player)
	local ok, result = pcall(function() return dataStore:GetAsync("player_" .. player.UserId) end)
	if not ok then return defaultData(), true end
	local data = defaultData()
	if type(result) == "table" then
		if type(result.luck) == "number" then data.luck = math.clamp(result.luck, CONFIG.BaseLuck, CONFIG.MaxLuck) end
		if type(result.inventory) == "table" then
			for k, v in pairs(result.inventory) do
				if type(k) == "string" and type(v) == "number" and v > 0 then data.inventory[k] = math.floor(v) end
			end
		end
	end
	return data, false
end

local function saveData(player)
	local state = playerState[player]
	if not state or state.loadFailed then return end
	pcall(function() dataStore:SetAsync("player_" .. player.UserId, { luck = state.luck, inventory = state.inventory }) end)
end

local function sendState(player, kind)
	local state = playerState[player]
	if not state then return end
	StateUpdate:FireClient(player, { type = kind or "state", luck = state.luck, inventory = state.inventory, odds = getChances(state.luck), cooldown = CONFIG.RollCooldown, prefix = CONFIG.CommandPrefix })
end

local function consumeRateSlot(state, now)
	local kept = {}
	for _, t in ipairs(state.rollTimes) do if t > now - 60 then table.insert(kept, t) end end
	state.rollTimes = kept
	if #kept >= CONFIG.MaxRollsPerMinute then return false end
	table.insert(kept, now)
	return true
end

local function performRoll(player, source, skipCooldown)
	local state = playerState[player]
	if not state then return nil, "No data" end
	local now = os.clock()
	if not skipCooldown then
		local elapsed = now - state.lastRoll
		if elapsed < CONFIG.RollCooldown then return nil, ("Wait %.1fs"):format(CONFIG.RollCooldown - elapsed) end
	end
	if not consumeRateSlot(state, now) then return nil, "Rate limit reached" end
	state.lastRoll = now
	local rarity = doRoll(state.rng, state.luck)
	state.inventory[rarity.id] = (state.inventory[rarity.id] or 0) + 1
	RollResult:FireClient(player, { id = rarity.id, display = rarity.display, color = rarity.color, oneIn = rarity.oneIn, luck = state.luck, source = source, inventory = state.inventory })
	return rarity
end

RollRequest.OnServerEvent:Connect(function(player) performRoll(player, "ui", false) end)

local function findPlayer(name)
	name = name:lower()
	for _, p in ipairs(Players:GetPlayers()) do if p.Name:lower():sub(1, #name) == name then return p end end
	return nil
end

local function reply(player, text) StateUpdate:FireClient(player, { type = "message", text = text }) end

local function handleCommand(player, rawText)
	local body = rawText:sub(#CONFIG.CommandPrefix + 1):gsub("^%s+", "")
	local args = {}
	for word in body:gmatch("%S+") do table.insert(args, word) end
	local cmd = (args[1] or ""):lower()
	local state = playerState[player]
	if not state then return end

	if cmd == "roll" then
		local count = math.clamp(tonumber(args[2]) or 1, 1, CONFIG.MaxBatch)
		local rolled = 0
		for i = 1, count do
			local rarity, err = performRoll(player, "chat", i > 1)
			if not rarity then if rolled == 0 then reply(player, err) end break end
			rolled += 1
		end
		if rolled > 1 then reply(player, ("Rolled %d times"):format(rolled)) end
	elseif cmd == "luck" then reply(player, ("Luck: %sx"):format(state.luck))
	elseif cmd == "inv" then
		local parts = {}
		for _, rarity in ipairs(CONFIG.Rarities) do
			local n = state.inventory[rarity.id]
			if n then table.insert(parts, ("%s x%d"):format(rarity.display, n)) end
		end
		reply(player, #parts > 0 and table.concat(parts, " | ") or "Inventory empty")
	elseif cmd == "odds" then
		local parts = {}
		for _, row in ipairs(getChances(state.luck)) do table.insert(parts, ("%s %.4f%%"):format(row.display, row.chance * 100)) end
		reply(player, table.concat(parts, " | "))
	elseif cmd == "setluck" then
		if not CONFIG.AdminUserIds[player.UserId] then reply(player, "Not permitted"); return end
		local target = args[2] and findPlayer(args[2])
		local value  = tonumber(args[3])
		if not target or not value then reply(player, "Usage: !roll setluck <player> <value>"); return end
		local tState = playerState[target]
		if not tState then return end
		tState.luck = math.clamp(value, CONFIG.BaseLuck, CONFIG.MaxLuck)
		sendState(target, "state")
		reply(player, ("%s luck set to %sx"):format(target.Name, tState.luck))
	elseif cmd == "help" then reply(player, "!roll [n] | !roll luck | !roll inv | !roll odds")
	else reply(player, "Unknown command. Try !roll help") end
end

local seen, seenCount = {}, 0
local function markSeen(id)
	if seen[id] then return false end
	seen[id] = true; seenCount += 1
	if seenCount > 2000 then seen, seenCount = {}, 0 end
	return true
end

local function isCommand(text) return text:sub(1, #CONFIG.CommandPrefix):lower() == CONFIG.CommandPrefix:lower() end

if TextChatService.ChatVersion == Enum.ChatVersion.LegacyChatService then
	Players.PlayerAdded:Connect(function(player)
		player.Chatted:Connect(function(msg) if isCommand(msg) then handleCommand(player, msg) end end)
	end)
else
	TextChatService.OnIncomingMessage = function(message)
		local player = Players:GetPlayerByUserId(message.TextSource.UserId)
		if not player then return nil end
		local text = message.Message
		if not isCommand(text) or not markSeen(message.MessageId) then return nil end
		handleCommand(player, text)
		local props = Instance.new("TextChatMessageProperties")
		props.PrefixText = ""; props.Text = ""; props.TextTransparency = 1
		return props
	end
end

local function onPlayerAdded(player)
	local data, loadFailed = loadData(player)
	playerState[player] = { luck = data.luck, inventory = data.inventory, lastRoll = -math.huge, rollTimes = {}, rng = Random.new(os.time() + player.UserId + math.floor(os.clock() * 1000)), loadFailed = loadFailed }
	sendState(player, "init")
end

Players.PlayerAdded:Connect(onPlayerAdded)
Players.PlayerRemoving:Connect(function(player) saveData(player); playerState[player] = nil end)
for _, p in ipairs(Players:GetPlayers()) do task.spawn(onPlayerAdded, p) end

task.spawn(function()
	while true do task.wait(CONFIG.SaveInterval); for p in pairs(playerState) do saveData(p) end end
end)

game:BindToClose(function()
	for p in pairs(playerState) do saveData(p) end
	task.wait(2)
end)
