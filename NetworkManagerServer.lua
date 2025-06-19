local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Events = ReplicatedStorage:WaitForChild("Events")

local Plots = game.Workspace:WaitForChild("Plots")

local Sera = require(ReplicatedStorage.Modules.Replication.Sera)

local Config = require(script.Parent.Config)
local Schemas = require(script.Parent.Schemas)
local Bases = require(script.Parent.Parent.Bases)

local NetworkManager = {}

-- // server receieve npc spawn

-- Update the BuyNPC event handler:

function NetworkManager.UpdatePromixities()
	local NPCManager = require(script.Parent.NPCManager)

	-- Pre-calculate all players to avoid multiple iterations
	local allPlayers = game.Players:GetPlayers()

	-- Initialize data structures for all players
	local npcSellOrSteal = {}
	local hideProxFrom = {}

	for _, plr in ipairs(allPlayers) do
		npcSellOrSteal[plr] = {}
		hideProxFrom[plr] = {}
	end

	-- Process NPCs in plots - determine buy/steal status
	for npcId, npcInfo in pairs(NPCManager.NPCsInPlots) do
		local npcOwner = npcInfo.player

		for _, plr in ipairs(allPlayers) do
			print(plr)
			print(npcOwner)
			print(plr == npcOwner)
			
			if npcOwner == plr then
				npcSellOrSteal[plr][npcId] = "Sell"
				print(plr)
				print("Sell")
			else
				npcSellOrSteal[plr][npcId] = "Steal"
				
				print("STEAL") print(plr)
			end
			
			print(npcSellOrSteal[plr])
		end
	end

	-- Process stolen NPCs - determine visibility
	for npcId, npcInfo in pairs(NPCManager.StolenNPCsOutOfPlots) do
		local thief = npcInfo.Player

		for _, plr in ipairs(allPlayers) do
			-- Hide steal prompt from the player who is already stealing this NPC
			
			hideProxFrom[plr][npcId] = (plr == thief)
		end
	end

	-- Send updates to all clients
	for _, plr in ipairs(allPlayers) do
		Events.UpdatePromiximities:FireClient(plr, npcSellOrSteal[plr], hideProxFrom[plr])
	end
end

-- NEW: Add function to send redirect batch
Events.BuyNPC.OnServerEvent:Connect(function(player, npcID)


	local NPCManager = require(script.Parent.NPCManager)

	-- Check if the NPC exists and can be purchased
	local npcState = NPCManager.NPCStates[npcID]
	if not npcState then
	
		return
	end

	
	if npcState.Finished or npcState.SwitchToBase or npcState.RedirectRequested then
		--print("ERROR: NPC already finished, purchased, or redirect pending!")
		return
	end

	-- Add purchase validation here (check player money, etc.)
	local canPurchase = true -- Replace with your purchase logic

	if canPurchase then
		--print("Attempting to request redirect...")
		local success = NPCManager:RequestNPCRedirect(npcID, player)
		if success then
		--	print("SUCCESS: Redirect requested for NPC", npcID, "to", player.Name, "'s base")
			-- Deduct money from player here if needed
		else
			--print("ERROR: Failed to request NPC redirect")
		end
	else
		--print("ERROR: Player cannot purchase NPC")
	end
--	print("=== END BUY NPC EVENT ===")
end)


-- // so how this jon will work is the following:
-- * I will check if the NPC exists in the NPCStates table
-- * if it does then, I will check if the player is near the base that the npc is at //

-- // Now, if the npc is out of the plot, then we check NPCManager.StolenNPCsOutOfPlots //
Events.StealNPC.OnServerEvent:Connect(function(player, NPCToSteal)
	print("maybe player")
	if not player then return end
	print("PLAYER")
	
	local Character = player.Character
	
	local PlayerBase = Bases.Get_Player_Plot(player)
	
	local NPCManager = require(script.Parent.NPCManager)
	
	print("hiiii")
	
	if not PlayerBase then return end
	
	if NPCManager.StolenNPCsOutOfPlots[NPCToSteal] then
		if NPCManager.StolenNPCsOutOfPlots[NPCToSteal].Player == player then return print("you're already stealing this npc") end
	end
	
	print("Base???")
	
	-- // check if npc is inside a plot
	if NPCManager.NPCsInPlots[NPCToSteal] then
		print("yes")
		
		local NPCTable = NPCManager.NPCsInPlots[NPCToSteal]
		
		if Bases.IsBaseLocked(NPCTable.player) then return print("base locked") end
		
		if NPCTable.Base then
			local FloorPart = NPCTable.Base.Floor1:FindFirstChild("Floor").FloorPart :: Part
			
			print((Character.HumanoidRootPart.Position -  FloorPart.Position).Magnitude)
			
			if (Character.HumanoidRootPart.Position -  FloorPart.Position).Magnitude <= 45 then
				print("very epic")
				
				NPCManager.StolenNPCsOutOfPlots[NPCToSteal] = {
					Player = player,
					Base = NPCTable.Base,
					OriginalOwner = NPCTable.player,
					npcName = NPCTable.npcName,
					Spot = NPCTable.spot
				}
				
				NPCManager.NPCsInPlots[NPCToSteal] = nil
				
				print("printing it fr")
				
				Events.StealNPC:FireAllClients(player, NPCToSteal)
				
				NetworkManager.UpdatePromixities()
				
				return
			end
		end
		
	end
	
	-- // otherwise, check if the npc is in the table of stolen npcs
	if NPCManager.StolenNPCsOutOfPlots[NPCToSteal] then
		NPCManager.StolenNPCsOutOfPlots[NPCToSteal] = nil
		
		NPCManager.StolenNPCsOutOfPlots[NPCToSteal] = {
			Player = player,
			Base = NPCManager.StolenNPCsOutOfPlots[NPCToSteal].Base,
			OriginalOwner = NPCManager.StolenNPCsOutOfPlots[NPCToSteal].OriginalOwner,
			npcName = NPCManager.StolenNPCsOutOfPlots[NPCToSteal].npcName
		}
		
		Events.StealNPC:FireAllClients(player, NPCToSteal)
		
		NetworkManager.UpdatePromixities()
		
		return
	end
end)

Events.NPCPlacement.OnServerEvent:Connect(function(player, NPCID)
	
end)

Events.UpdatePromiximities.OnServerEvent:Connect(function(player)
	NetworkManager.UpdatePromixities()
end)

-- Enhanced redirect batch sending with debugging:
function NetworkManager:SendNPCRedirectBatch(redirectBatch, timestamp)

	for i, redirectData in ipairs(redirectBatch) do
		redirectData.ServerTime = timestamp
		
		Config.Events.NPCRedirectEvent:FireAllClients(redirectData)
		
	end

end

-- // send to client stuff

function NetworkManager:SendNPCRedirect(redirectData)
	Config.Events.NPCRedirectEvent:FireAllClients(redirectData)
end

function NetworkManager:SendNPCSpawn(spawnData)
	
	local serializedSpawnData = Sera.Serialize(Schemas.NPCSpawnSchema, spawnData)
	if serializedSpawnData then
		
		Config.Events.NPCSpawnEvent:FireAllClients(serializedSpawnData)
	end
end

function NetworkManager:SendNPCBatch(npcBatch, timestamp)
	local packedBatch = self:PackNPCBatch(npcBatch, timestamp)
	if packedBatch then
		local serializedBatch = Sera.Serialize(Schemas.NPCBatchSchema, packedBatch)
		if serializedBatch then
			Config.Events.NPCBatchEvent:FireAllClients(serializedBatch)
		end
	end
end

function NetworkManager:SendNPCDestroy(toDestroy)
	local destroyData = self:PackNPCDestroy(toDestroy)
	if destroyData then
		local serializedDestroy = Sera.Serialize(Schemas.NPCDestroySchema, destroyData)
		if serializedDestroy then
			Config.Events.NPCDestroyEvent:FireAllClients(serializedDestroy)
		end
	end
end

function NetworkManager:SendTimeSync(player)
	local currentTime = tick()
	local relativeTime = currentTime - Config.SERVER_START_TIME
	local syncData = {
		ServerTime = relativeTime
	}
	local serializedSync = Sera.Serialize(Schemas.TimeSyncSchema, syncData)
	if serializedSync then
		if player then
			Config.Events.TimeSync:FireClient(player, serializedSync)
		else
			Config.Events.TimeSync:FireAllClients(serializedSync)
		end
	end
end

function NetworkManager:SendNPCBulkSync(player, activeNPCs, serverTime)
	if #activeNPCs == 0 then
		--print("No active NPCs to sync for", player.Name)
		self:SendTimeSync(player)
		return
	end

	--print("=== SENDING BULK SYNC TO", player.Name, "===")
--	print("Active NPCs count:", #activeNPCs)

	-- Send each NPC as a spawn event with current position
	for i, npcData in ipairs(activeNPCs) do
		local spawnData = {
			ID = npcData.ID,
			StartTime = npcData.StartTime,
			Duration = npcData.Duration,
			ServerTime = serverTime,
			NpcName = npcData.NpcName,
			CurrentPosition = npcData.CurrentPosition, -- Always include current position
		}

		

		local serializedSpawnData = Sera.Serialize(Schemas.NPCSpawnSchema, spawnData)
		if serializedSpawnData then
			Config.Events.NPCSpawnEvent:FireClient(player, serializedSpawnData)
	
		end

		-- Small delay to prevent overwhelming the client
		task.wait(0.02)
	end

	-- Send time sync after all NPCs
	self:SendTimeSync(player)


end

function NetworkManager:PackNPCBatch(npcList, timestamp)
	local count = #npcList
	if count == 0 then return nil end

	local idBuffer = buffer.create(count * 2)
	local posBuffer = buffer.create(count * 12)

	for i, npcData in ipairs(npcList) do
		local idOffset = (i - 1) * 2
		local posOffset = (i - 1) * 12

		buffer.writeu16(idBuffer, idOffset, npcData.ID)
		buffer.writef32(posBuffer, posOffset, npcData.Position.X)
		buffer.writef32(posBuffer, posOffset + 4, npcData.Position.Y)
		buffer.writef32(posBuffer, posOffset + 8, npcData.Position.Z)
	end

	return {
		Timestamp = timestamp,
		Count = count,
		IDs = idBuffer,
		Positions = posBuffer,
	}
end

function NetworkManager:PackNPCDestroy(npcList)
	local count = #npcList
	if count == 0 then return nil end

	local idBuffer = buffer.create(count * 2)
	for i, npcID in ipairs(npcList) do
		local idOffset = (i - 1) * 2
		buffer.writeu16(idBuffer, idOffset, npcID)
	end

	return {
		Count = count,
		IDs = idBuffer,
	}
end

return NetworkManager