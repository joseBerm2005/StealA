local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")
local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")

-- Module imports
local RS_Modules = ReplicatedStorage.Modules
local SSS_Modules = script.Parent.Modules

local networkManager = require(SSS_Modules.Core.MoveServer.NetworkManager)
local npcManager = require(SSS_Modules.Core.MoveServer.NPCManager)
local BaseModule = require(SSS_Modules.Core.Bases)

-- Events
local NPCPlacement = ReplicatedStorage.Events.NPCPlacement

-- Constants
local CONSTANTS = {
	MAIN_PAD_COOLDOWN = 1, -- seconds
	COLLECT_PAD_COOLDOWN = 1, -- seconds
	PLOTS = Workspace.Plots
}

-- State management
local CooldownManager = {
	mainPadCooldowns = {},
	collectPadCooldowns = {}
}

-- Utility functions
local Utils = {}

function Utils.getPlayerFromHit(hit)
	local humanoid = hit.Parent:FindFirstChild("Humanoid")
	if not humanoid then
		return nil
	end
	return Players:GetPlayerFromCharacter(hit.Parent)
end

function Utils.isOnCooldown(cooldownTable, player, cooldownTime)
	local lastTouchTime = cooldownTable[player.UserId]
	if lastTouchTime and tick() - lastTouchTime < cooldownTime then
		return true
	end
	return false
end

function Utils.setCooldown(cooldownTable, player)
	cooldownTable[player.UserId] = tick()
end

function Utils.isPlayerBase(item, player, depth)
	local PlayerBase = BaseModule.Get_Player_Plot(player)
	if not PlayerBase then 
		return false 
	end

	local parent = item
	for i = 1, depth do
		parent = parent.Parent
		if not parent then
			return false
		end
	end

	return parent == PlayerBase
end

function Utils.findNpcNameById(activeNpcs, targetId)
	for _, npc in pairs(activeNpcs) do
		if npc.ID == targetId then
			return npc.NpcName
		end
	end
	return nil
end

-- Money management
local MoneyManager = {}

function MoneyManager.collectPendingMoney(player, collectpad)
	local PendingMoneyTbl = BaseModule.pendingMoneyTbl
	local playerDataServerStorage = require(ServerStorage.Modules.Data.PlayerManager)
	local totalMoney = 0

	for npcid, info in pairs(PendingMoneyTbl) do
		
		if collectpad then
			if collectpad ~= info.spot then	continue end
		end
			
			
		if info.player ~= player then 
			continue 
		end

		totalMoney += info.money
		info.money = 0
		
		PendingMoneyTbl[npcid].spot.Collect.BillboardGui.CashLabel.Text = 0
	end

	if totalMoney > 0 then
		playerDataServerStorage.AddMoney(player, totalMoney)
		print("Added", totalMoney, "money to", player.Name)
	end
	
	return totalMoney
end

-- Touch handlers
local TouchHandlers = {}

function TouchHandlers.handleMainPadTouch(hit, mainPad)
	local player = Utils.getPlayerFromHit(hit)
	if not player then
		return
	end

	print("Player", player.Name, "touched main pad")

	-- Check cooldown
	if Utils.isOnCooldown(CooldownManager.mainPadCooldowns, player, CONSTANTS.MAIN_PAD_COOLDOWN) then
		return
	end

	-- Verify ownership (5 levels up: mainPad -> Parent -> Parent -> Parent -> Parent -> Parent)
	if not Utils.isPlayerBase(mainPad, player, 5) then
		print("Not your base")
		return
	end

	-- Set cooldown
	Utils.setCooldown(CooldownManager.mainPadCooldowns, player)

	local PlayerBase = BaseModule.Get_Player_Plot(player)

	-- Process stolen NPCs and move them back to plots
	for npcId, npcInfo in pairs(npcManager.StolenNPCsOutOfPlots) do
		if npcInfo.Player == player then
			print("Processing stolen NPC:", npcId)

			-- Move NPC from stolen to plot
			npcManager.NPCsInPlots[npcId] = {
				player = player,
				Base = PlayerBase,
				spot = mainPad.Parent,
				npcName = npcManager.StolenNPCsOutOfPlots[npcId].npcName
			}

			-- Remove from stolen table
			npcManager.StolenNPCsOutOfPlots[npcId] = nil

			-- Update NPC placement
			if npcManager.NPCsInPlots[npcId].npcName then
				print("Setting NPC attribute:", npcManager.NPCsInPlots[npcId].npcName)
				mainPad.Parent:SetAttribute("NPC", npcManager.NPCsInPlots[npcId].npcName)
				NPCPlacement:FireAllClients(npcId, mainPad, player.Character)
				networkManager.UpdatePromixities()
			end
		end
	end
end

function TouchHandlers.handleCollectPadTouch(hit, collectPad)
	local player = Utils.getPlayerFromHit(hit)
	if not player then
		return
	end

	print("Player", player.Name, "touched collect pad")

	-- Check cooldown
	if Utils.isOnCooldown(CooldownManager.collectPadCooldowns, player, CONSTANTS.COLLECT_PAD_COOLDOWN) then
		return
	end

	-- Verify ownership (5 levels up: collectPad -> Parent -> Parent -> Parent -> Parent -> Parent)
	if not Utils.isPlayerBase(collectPad, player, 5) then
		print("Not your base")
		return
	end

	-- Set cooldown
	Utils.setCooldown(CooldownManager.collectPadCooldowns, player)

	-- Collect pending money
	MoneyManager.collectPendingMoney(player, collectPad)
	
end

function TouchHandlers.handleCollectZoneTouch(hit, collectZone)
	local player = Utils.getPlayerFromHit(hit)
	if not player then
		return
	end

	print("Player", player.Name, "touched collect zone")

	-- Check cooldown
	if Utils.isOnCooldown(CooldownManager.mainPadCooldowns, player, CONSTANTS.MAIN_PAD_COOLDOWN) then
		return
	end

	-- Verify ownership (4 levels up: collectZone -> Parent -> Parent -> Parent -> Parent)
	if not Utils.isPlayerBase(collectZone, player, 4) then
		print("Not your base")
		return
	end

	-- Set cooldown
	Utils.setCooldown(CooldownManager.mainPadCooldowns, player)

	-- Collect pending money
	MoneyManager.collectPendingMoney(player)
end

-- Connection setup
local ConnectionManager = {}

function ConnectionManager.setupPadConnections(item)
	if item:FindFirstChild("Mains") then
		item.Touched:Connect(function(hit)
			TouchHandlers.handleMainPadTouch(hit, item)
		end)
	elseif item.Name == "MainCollect" then
		item.Touched:Connect(function(hit)
			TouchHandlers.handleCollectPadTouch(hit, item)
		end)
	end
end

function ConnectionManager.setupCollectZoneConnections(item)
	item.Touched:Connect(function(hit)
		TouchHandlers.handleCollectZoneTouch(hit, item)
	end)
end

function ConnectionManager.processPlotItem(item)
	if item.Parent.Parent.Name == "Pads" then
		ConnectionManager.setupPadConnections(item)
	elseif item.Parent.Name == "CollectZone" then
		ConnectionManager.setupCollectZoneConnections(item)
	end
end

-- Initialization function
local function initializePlotSystem()
	-- Setup existing plot items
	for _, item in pairs(CONSTANTS.PLOTS:GetDescendants()) do
		ConnectionManager.processPlotItem(item)
	end

	-- Handle new items added to plots
	CONSTANTS.PLOTS.DescendantAdded:Connect(function(item)
		ConnectionManager.processPlotItem(item)
	end)

	-- Clean up cooldowns when players leave
	Players.PlayerRemoving:Connect(function(player)
		CooldownManager.mainPadCooldowns[player.UserId] = nil
		CooldownManager.collectPadCooldowns[player.UserId] = nil
	end)

	print("Plot system initialized successfully")
end

-- Start the system
initializePlotSystem()