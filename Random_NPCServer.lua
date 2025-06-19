--!strict

local Random_NPC = {}
local NPC_INFO = require(game.ReplicatedStorage.Modules.Shared.NPC_INFO)


Random_NPC.ServerBoosts = 0

local rng = Random.new()

function Random_NPC:GetRandomNPCName(): string
	local weights = {}
	local totalWeight = 0
	local serverLuck = game.ReplicatedStorage:GetAttribute("ServerLuck") or 1

	for name, data in NPC_INFO.NPCS do
		local baseWeight = 1 / data.rarity_chance
		local luckMultiplier = 1

		if data.rarity_chance <= 10 then 
			luckMultiplier = 1 / math.pow(serverLuck, 0.8)
		elseif data.rarity_chance <= 25 then
			luckMultiplier = 1 / math.pow(serverLuck, 0.5)
		elseif data.rarity_chance <= 100 then 
			luckMultiplier = math.pow(serverLuck, 0.3)
		else 
			luckMultiplier = math.pow(serverLuck, 0.8)
		end

		local finalWeight = baseWeight * luckMultiplier
		weights[name] = finalWeight
		totalWeight += finalWeight
	end

	local choice = rng:NextNumber(0, totalWeight)
	local currentWeight = 0

	for name, weight in weights do
		currentWeight += weight
		if choice <= currentWeight then
			return name
		end
	end

	return "Unknown"
end

local isBoostActive = false

local function startBoostCountdown()
	if isBoostActive then return end
	isBoostActive = true

	task.spawn(function()
		while Random_NPC.ServerBoosts > 0 do
			task.wait(1)
			Random_NPC.ServerBoosts -= 1
		end
		
		game.ReplicatedStorage:SetAttribute("ServerLuck", 1)

		isBoostActive = false
	end)
end

function Random_NPC:AddBoostTime(seconds: number)
	Random_NPC.ServerBoosts += seconds
	startBoostCountdown()
	game.ReplicatedStorage:SetAttribute("ServerLuck", game.ReplicatedStorage:GetAttribute("ServerLuck") * 2) 
end

return Random_NPC
