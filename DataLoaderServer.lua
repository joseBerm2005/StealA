--!strict
local DataLoader = {}

--// Services
local Players = game:GetService("Players")
local ServerStorage = game:GetService("ServerStorage")
local HttpsService = game:GetService("HttpService")



--// Modules
local ProfileStore = require(ServerStorage.Modules.Data:WaitForChild("ProfileStore"))
local DataTemplate = require(ServerStorage.Modules.Data.ProfileTemplate)
local ReplicaServer = require(game.ServerScriptService.ReplicaService)
local GoodSignal = require(game.ReplicatedStorage.Modules.Signals.GoodSignal)
local RebirthDependency = require(game.ReplicatedStorage.Modules.Shared.Rebirths)
local GearInfo = require(game.ReplicatedStorage.Modules.Shared.GearInfo)

DataLoader.LblSignal = GoodSignal.new()

--// Types
export type CancelFunction = () -> boolean

--// State
local PlayerData = ProfileStore.New("PlayerData", DataTemplate)
local Profiles: {[Player]: typeof(PlayerData:StartSessionAsync())} = {}
local CachedReplicas: {[Player]: typeof(ReplicaServer.NewReplica())} = {}

--// Utilities



local function formatProfileData(profile: typeof(PlayerData:StartSessionAsync())): string
	if not profile or not profile.Data then return "No data found!" end

	local summary = {}
	for key, value in pairs(profile.Data) do
		summary[key] = typeof(value) == "table" and "table" or value
	end

	return HttpsService:JSONEncode(summary)
end

local function updateFriendBoost(player: Player)
	local success, pages = pcall(function()
		return Players:GetFriendsAsync(player.UserId)
	end)
	if not success then return end

	local friendCount = 0
	while true do
		for _, friend in pairs(pages:GetCurrentPage()) do
			if Players:GetPlayerByUserId(friend.Id) then
				friendCount += 1
			end
		end
		if pages.IsFinished then break end
		pages:AdvanceToNextPageAsync()
	end
	
	if not CachedReplicas[player] then repeat task.wait() until CachedReplicas[player] end
	
	if friendCount >= 1 then
		CachedReplicas[player]:SetValue({"MoneyBoosts", "FriendBoost"}, 1.15 * friendCount)
	end
	
	DataLoader.LblSignal:Fire(player)
	

	print(`{player.Name} has {friendCount} friend(s) in-game (x{1.15*friendCount} boost)`)
end

local function checkJoiningFriendBoost(joinedPlayer: Player)
	for _, otherPlayer in Players:GetPlayers() do
		if joinedPlayer == otherPlayer then continue end

		task.spawn(function()
			local success, pages = pcall(function()
				return Players:GetFriendsAsync(otherPlayer.UserId)
			end)
			if not success then return end

			while true do
				for _, friend in pairs(pages:GetCurrentPage()) do
					if friend.Id == joinedPlayer.UserId then
						updateFriendBoost(otherPlayer)
						return
					end
				end
				if pages.IsFinished then break end
				pages:AdvanceToNextPageAsync()
			end
		end)
	end
end

--// Core

function DataLoader:MakeReplica(player: Player)
	local uniqueId = HttpsService:GenerateGUID(false)
	local ID_Token = "MainReplica_" .. player.UserId .. "_" .. uniqueId

	local classToken = ReplicaServer.NewClassToken(ID_Token)
	
	game.ReplicatedStorage.Events.Token_ID:FireClient(player, ID_Token)

	local replica = ReplicaServer.NewReplica({
		ClassToken = classToken,
		Tags = {Player = player},
		Data = Profiles[player].Data,
		Replication = {[player] = true}
	})
	
	print(CachedReplicas)
	


	CachedReplicas[player] = replica
	print("Replica created for", player.Name)
end

function DataLoader:SaveReplicaToProfile(player: Player)
	local replica = CachedReplicas[player]
	local profile = Profiles[player]

	if replica and profile then
		for key, value in replica.Data do
			profile.Data[key] = value
		end
		print(`Saved replica data for {player.Name}`)
	else
		warn(`Failed to save data for {player.Name}`)
	end
end

function DataLoader.GetProfile(player: Player)
	repeat task.wait() until Profiles[player]
	return Profiles[player]
end

function DataLoader.GetReplica(Player : Player)
	repeat task.wait() until CachedReplicas[Player]
	return CachedReplicas[Player]
end

function DataLoader:DataCreation(player: Player)
	local cancelFunc: CancelFunction = function()
		return player.Parent ~= Players
	end

	local profile = PlayerData:StartSessionAsync(tostring(player.UserId), {Cancel = cancelFunc})
	if not profile then
		player:Kick("Data failed to load, please rejoin!")
		return
	end

	profile:AddUserId(player.UserId)
	profile:Reconcile()

	profile.OnSessionEnd:Connect(function()
		Profiles[player] = nil
		player:Kick("Session ended - please rejoin!")
	end)

	if player.Parent == Players then
		Profiles[player] = profile
		print(`Profile loaded for {player.Name}`)
		print(formatProfileData(profile))

		self:MakeReplica(player)
		updateFriendBoost(player)
	end
end

--// Connections

for _, player in Players:GetPlayers() do
	task.spawn(function()
		DataLoader:DataCreation(player)
	end)
end

Players.PlayerAdded:Connect(function(player)
	DataLoader:DataCreation(player)
	player:SetAttribute("Cash", 0)
	checkJoiningFriendBoost(player)
end)

Players.PlayerRemoving:Connect(function(player)
	if CachedReplicas[player] then
		DataLoader:SaveReplicaToProfile(player)

		CachedReplicas[player]:Destroy()
		CachedReplicas[player] = nil
	end

	local profile = Profiles[player]
	if profile.Data.MoneyBoosts.FriendBoost then
		profile.Data.MoneyBoosts.FriendBoost = 1
	end
	if profile then
		profile:EndSession()
		Profiles[player] = nil
	end
end)

game.ReplicatedStorage.Events.Rebirth.OnServerEvent:Connect(function(Player : Player)
	if CachedReplicas[Player].Data.Cash >= RebirthDependency.Calculate_Player_Cost(Player, CachedReplicas[Player].Data.Rebirths) then
		CachedReplicas[Player]:SetValue({"Rebirths"}, CachedReplicas[Player].Data.Rebirths + 1)
		CachedReplicas[Player]:SetValue({"Cash"}, 0)
	end
end)

game.ReplicatedStorage.Events.BuyGear.OnServerEvent:Connect(function(Player : Player, GearName : string)
	print(GearName)
	if GearInfo.Gears[GearName] then
		local Replica = CachedReplicas[Player].Data
		if Replica.Cash < GearInfo.Gears[GearName].Price then return end
		local NewTool = game.ReplicatedStorage.Gears[GearName]:Clone()
		NewTool.Parent = Player.Backpack
		Replica.Cash -= GearInfo.Gears[GearName].Price
	end
end)


task.spawn(function()
	while true do
		for _, player in Players:GetPlayers() do
			local replica = CachedReplicas[player]
			if replica then
				 local currentCash = replica.Data.Cash
				 replica:SetValue("Cash", currentCash + 10000)
			end
		end
		task.wait(1)
	end
end)

return DataLoader
