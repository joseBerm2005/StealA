local Players = game:GetService("Players")

local Config = require(script.Parent.Config)
local NetworkManager = require(script.Parent.NetworkManager)
local NPCManager = require(script.Parent.NPCManager)

local DataLoader = require(script.Parent.Parent.Parent.Data.DataLoader)

local PlayerManager = {}


local PlayersAwaitingSync = {}

function PlayerManager:Initialize()
	self:SetupEventConnections()
	self:StartBackupSyncSystem()
end

function PlayerManager:SetupEventConnections()
	
	Config.Events.ClientReady.OnServerEvent:Connect(function(player)
		self:HandleClientReady(player)
	end)


	Players.PlayerAdded:Connect(function(player)
		self:HandlePlayerAdded(player)
	end)

	
	Players.PlayerRemoving:Connect(function(player)
		self:HandlePlayerRemoving(player)
	end)

	
	Config.Events.NPCSyncRequest.OnServerEvent:Connect(function(player)
		self:HandleManualSyncRequest(player)
	end)
end

function PlayerManager:HandleClientReady(player)
	print("Client ready:", player.Name)
	PlayersAwaitingSync[player] = nil

	NetworkManager:SendTimeSync(player)
	task.wait(Config.SYNC_DELAY)
	self:SyncActiveNPCsToPlayer(player)
end

-- load in player data like NPCs and stuff
function PlayerManager:HandlePlayerAdded(player : Player)
	
	repeat task.wait() until player.Character
	
	local npcsTospawn = {}
	
	-- load in npcs for the players that just joined
	if NPCManager.NPCsInPlots ~= {} then
		
	end
	
	PlayersAwaitingSync[player] = tick() + Config.PLAYER_SYNC_TIMEOUT
end

function PlayerManager:HandlePlayerRemoving(player)
	
	local plrData = DataLoader.GetReplica(player)
	
	for id, info in pairs(NPCManager.NPCsInPlots) do
		if info.player ~= player then continue end
		
		if plrData.Data.NPCS[info.npcName] then
			--plrData.Data.NPCS[info.npcName]
		else
			plrData.Data.NPCS[info.npcName] = {
				spots = {info.spot},
				count = 1,
			}
		end
	end
	
	PlayersAwaitingSync[player] = nil
end

function PlayerManager:HandleManualSyncRequest(player)
	
	NetworkManager:SendTimeSync(player)
	
	task.wait(Config.SYNC_DELAY)
	
	repeat task.wait() until player.Character
	
	self:SyncActiveNPCsToPlayer(player)
	
	NetworkManager.UpdatePromixities() -- update the promixities for the player
end

function PlayerManager:SyncActiveNPCsToPlayer(player)
	local NPCManager = require(script.Parent.NPCManager)
	local activeNPCs, serverTime = NPCManager:GetActiveNPCs()
	NetworkManager:SendNPCBulkSync(player, activeNPCs, serverTime)
end

function PlayerManager:StartBackupSyncSystem()
	task.spawn(function()
		while true do
			task.wait(2)
			local currentTime = tick()

			for player, timeoutTime in pairs(PlayersAwaitingSync) do
				if currentTime > timeoutTime then
					
					self:SyncActiveNPCsToPlayer(player)
					PlayersAwaitingSync[player] = nil
				end
			end
		end
	end)
end

return PlayerManager