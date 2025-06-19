local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Sera = require(ReplicatedStorage.Modules.Replication.Sera)

local Config = require(script.Parent.Config)
local Schemas = require(script.Parent.Schemas)
local Utils = require(script.Parent.Utils)
local Promixity = require(script.Parent.Proximity)
local NPCData = require(ReplicatedStorage.Modules.Shared.NPC_INFO)

local NPCManager = {}

local ClientNPCs = {}
local NPCMovementData = {}
local PendingRedirects = {} -- Store pending redirects

-- Create a new NPC on client
-- Add a flag to track if we're in bulk sync mode
local isBulkSyncing = false
local bulkSyncNPCs = {}

local function findSpotwithCorrectID(npcId)
	for _, v in pairs(game.Workspace.Plots:GetDescendants()) do
		if v.Parent.Name == "Pads" then
			if v:GetAttribute("NPCID") == tonumber(npcId) then
				print("found :D")
				return v
			end
		end
	end
	return nil
end

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local player = Players.LocalPlayer
local character = player.Character or player.CharacterAdded:Wait()

-- Update HandleSpawnEvent to handle both regular spawns and bulk sync
function NPCManager:HandleSpawnEvent(serializedData)
	local spawnData = Sera.Deserialize(Schemas.NPCSpawnSchema, serializedData)
	if spawnData then
		require(script.Parent.TimeSync):UpdateTimeSync(spawnData.ServerTime)

		-- Check if this is a bulk sync (NPC already exists in movement data)
		local isBulkSync = NPCMovementData[spawnData.ID] ~= nil or spawnData.CurrentPosition ~= nil

		

		-- Use current position if provided (for bulk sync), otherwise nil (for new spawns)
		local currentPos = spawnData.CurrentPosition

		self:CreateClientNPC(spawnData.ID, spawnData.StartTime, spawnData.Duration, currentPos, spawnData.NpcName)
		
	else
		
	end
end


function NPCManager.Create_BBG(NPC : typeof(ReplicatedStorage.Assets.NPCs.Jandel))
	local NewBBG = ReplicatedStorage.Assets.NPCDataBillboard:Clone()
	NewBBG:FindFirstChild("Name").Text = NPC.Name
	NewBBG.PerSecond.Text = NPCData.NPCS[NPC.Name].Base_Gen .. "$/s"
	NewBBG.Rarity.Text = "Rarity: "..NPCData.NPCS[NPC.Name].rarity_name
	NewBBG.Cost.Text = "$Cost ".. NPCData.NPCS[NPC.Name].Price
	NewBBG.Parent = NPC
	NewBBG.Adornee = NPC.Head
end

-- Update CreateClientNPC to handle current position properly
function NPCManager:CreateClientNPC(npcID, startTime, duration, currentPosition, NpcName: string)
	if ClientNPCs[npcID] then
	
		return
	end


	local newNPC = game.ReplicatedStorage.Assets.NPCs[NpcName or "DefaultNPC"]:Clone()
	newNPC.Parent = Config.NPC_Folder
	newNPC.Name = NpcName or "DefaultNPC"
	
	NPCManager.Create_BBG(newNPC)

	Promixity.new(newNPC.HumanoidRootPart, "Buy")

	for _, parts in pairs(newNPC:GetChildren()) do
		if parts:IsA("BasePart") or parts:IsA("WeldConstraint") then
			parts.CanCollide = false
			parts.CanTouch = false
			parts.CanQuery = false
			parts.CastShadow = false
			parts.Material = Enum.Material.SmoothPlastic
		end
	end

	local rawStartPos = Config.Start_Pos
	local rawEndPos = Config.End_Pos

	local startPos = Utils:GetGroundedPosition(rawStartPos)
	local endPos = Utils:GetGroundedPosition(rawEndPos)

	-- Use current position if provided (bulk sync), otherwise start position
	local initialPos = currentPosition and Utils:GetGroundedPosition(currentPosition) or startPos
	newNPC:PivotTo(CFrame.new(initialPos))
	newNPC:SetAttribute("NPCID", npcID)

	local humanoid = newNPC:FindFirstChildOfClass("Humanoid")
	if humanoid then
		local animator = humanoid:FindFirstChildOfClass("Animator")
		local animation = Config.Animations:FindFirstChild("Walk")
		if animator and animation then
			local walkAnim = animator:LoadAnimation(animation)
			walkAnim.Looped = true
			walkAnim:Play()
		end
	end

	ClientNPCs[npcID] = newNPC
	NPCMovementData[npcID] = {
		Start = startPos,
		Target = endPos,
		StartTime = startTime,
		Duration = duration,
		LastNetworkPos = initialPos,
		InterpolatedPos = initialPos,
		Finished = false,
		LastNetworkTime = require(script.Parent.TimeSync):GetSyncedTime(),
		IsRedirected = false,
		IsBulkSynced = currentPosition ~= nil, -- Track if this was from bulk sync
	}


end

function NPCManager:HandleRedirectEvent(redirectData)
	if redirectData then
		require(script.Parent.TimeSync):UpdateTimeSync(redirectData.ServerTime)

		-- Store redirect data along with the waypoints received from the server
		PendingRedirects[redirectData.ID] = {
			Waypoints = redirectData.Waypoints, -- list of waypoint Vector3 positions
			NewStart = Utils:GetGroundedPosition(redirectData.NewStart),
			NewTarget = Utils:GetGroundedPosition(redirectData.NewTarget),
			NewStartTime = redirectData.NewStartTime,
			NewDuration = redirectData.NewDuration,
		}
	end
end


function NPCManager:HandleBatchEvent(serializedData)
	local batchData = Sera.Deserialize(Schemas.NPCBatchSchema, serializedData)
	if batchData then
		local npcs, timestamp = self:UnpackNPCBatch(batchData)
		local currentTime = require(script.Parent.TimeSync):GetSyncedTime()

		for _, npcUpdate in ipairs(npcs) do
			local movementData = NPCMovementData[npcUpdate.ID]
			if movementData and not movementData.Finished then
				movementData.LastNetworkPos = npcUpdate.Position
				movementData.LastNetworkTime = currentTime
			end
		end
	end
end

function NPCManager:HandleDestroyEvent(serializedData)
	
	-- deserialize server to client data
	local destroyData = Sera.Deserialize(Schemas.NPCDestroySchema, serializedData)
	
	-- if data sent was correct proceed
	if destroyData then
		
		-- get the npc ids from the server
		local npcIDs = self:UnpackNPCDestroy(destroyData)

		for _, npcID in ipairs(npcIDs) do
			local npc = ClientNPCs[npcID]
			
			-- stop npc animations
			
			for _, v in pairs(npc.Humanoid.Animator:GetPlayingAnimationTracks()) do
				
				v:Stop()
				
			end
			
			local movementData = NPCMovementData[npcID]

			if npc then
				npc:Destroy()
				ClientNPCs[npcID] = nil
			end

			if movementData then
				NPCMovementData[npcID] = nil
			end
		end
	end
end

function NPCManager:HandleBulkSync(serializedData)
	local bulkData = Sera.Deserialize(Schemas.NPCBulkSyncSchema, serializedData)
	if bulkData then
		

		require(script.Parent.TimeSync):UpdateTimeSync(bulkData.ServerTime)

		local npcs, serverTime = self:UnpackNPCBulkSync(bulkData)
		

		for i, npcData in ipairs(npcs) do
			
			-- Include the NPC name when creating from bulk sync
			self:CreateClientNPC(npcData.ID, npcData.StartTime, npcData.Duration, npcData.CurrentPosition, npcData.NpcName)
		end

		require(script.Parent.EventBuffer):SetInitialSyncReceived(true)
	

		if require(script.Parent.EventBuffer):IsClientReady() then
			require(script.Parent.EventBuffer):ProcessBufferedEvents(self)
		end
		
	else
		
	end
end

function NPCManager:UnpackNPCBulkSync(bulkData)
	local npcs = {}
	local count = bulkData.Count

	for i = 1, count do
		local offset = (i - 1) * 22
		local id = buffer.readu16(bulkData.NPCData, offset)
		local startTime = buffer.readf32(bulkData.NPCData, offset + 2)
		local duration = buffer.readf32(bulkData.NPCData, offset + 6)
		local currentX = buffer.readf32(bulkData.NPCData, offset + 10)
		local currentY = buffer.readf32(bulkData.NPCData, offset + 14)
		local currentZ = buffer.readf32(bulkData.NPCData, offset + 18)

		
		table.insert(npcs, {
			ID = id,
			StartTime = startTime,
			Duration = duration,
			CurrentPosition = Vector3.new(currentX, currentY, currentZ),
			NpcName = "DefaultNPC", 
		})
	end

	return npcs, bulkData.ServerTime
end


function NPCManager:UnpackNPCBatch(batchData)
	local npcs = {}
	local count = batchData.Count

	for i = 1, count do
		local idOffset = (i - 1) * 2
		local posOffset = (i - 1) * 12

		local id = buffer.readu16(batchData.IDs, idOffset)
		local x = buffer.readf32(batchData.Positions, posOffset)
		local y = buffer.readf32(batchData.Positions, posOffset + 4)
		local z = buffer.readf32(batchData.Positions, posOffset + 8)

		table.insert(npcs, {
			ID = id,
			Position = Vector3.new(x, y, z),
		})
	end

	return npcs, batchData.Timestamp
end

function NPCManager:UnpackNPCDestroy(destroyData)
	local npcIDs = {}
	local count = destroyData.Count

	for i = 1, count do
		local idOffset = (i - 1) * 2
		local id = buffer.readu16(destroyData.IDs, idOffset)
		table.insert(npcIDs, id)
	end

	return npcIDs
end

local RedirectSpeed = 25

-- In UpdateNPCs, update the redirected branch as follows:
function NPCManager:UpdateNPCs(dt, syncedTime)
	for npcID, data in pairs(NPCMovementData) do
		local npc = ClientNPCs[npcID]
		if npc and npc:IsDescendantOf(workspace) and not data.Finished then
			local pendingRedirect = PendingRedirects[npcID]

			if pendingRedirect and not data.IsRedirected then
				
				local npcCurrentPos = npc:GetPivot().Position

				-- Handle waypoints from server pathfinding
				if pendingRedirect.Waypoints and #pendingRedirect.Waypoints > 0 then
					data.Waypoints = {}
					for i, waypoint in ipairs(pendingRedirect.Waypoints) do
						local pos = typeof(waypoint) == "Vector3" and waypoint or Vector3.new(waypoint.X, waypoint.Y, waypoint.Z)
						pos = Utils:GetGroundedPosition(pos)
						table.insert(data.Waypoints, pos)
					end
					data.CurrentWaypointIndex = 1
					
				else
					data.Waypoints = {Utils:GetGroundedPosition(pendingRedirect.NewTarget)}
					data.CurrentWaypointIndex = 1
				end

				
				data.Start = Utils:GetGroundedPosition(npcCurrentPos)
				data.Target = data.Waypoints[1]
				data.StartTime = syncedTime

				
				local dist = (data.Target - data.Start).Magnitude
				data.Duration = math.max(0.1, dist / RedirectSpeed) 

				data.LastNetworkTime = syncedTime
				data.IsRedirected = true
				data.InterpolatedPos = data.Start
				data.LastNetworkPos = data.Start

				PendingRedirects[npcID] = nil
				
			end

			
			local timeSinceLastUpdate = syncedTime - data.LastNetworkTime
			local blendFactor = math.min(0.2, 0.05 + timeSinceLastUpdate * 0.05)

			if data.IsRedirected and data.Waypoints and #data.Waypoints > 0 then
				
				local currentTarget = data.Target

				
				local t = math.clamp((syncedTime - data.StartTime) / data.Duration, 0, 1)
				local predictedPos = data.Start:Lerp(currentTarget, t)
				predictedPos = Utils:GetGroundedPosition(predictedPos)

			
				local finalPos = predictedPos:Lerp(data.LastNetworkPos, blendFactor)
				finalPos = Utils:GetGroundedPosition(finalPos)

				
				local lerpSpeed = 10
				data.InterpolatedPos = data.InterpolatedPos:Lerp(finalPos, dt * lerpSpeed)
				data.InterpolatedPos = Utils:GetGroundedPosition(data.InterpolatedPos)

				
				local direction = (currentTarget - data.InterpolatedPos)
				if direction.Magnitude > 0.1 then
					direction = direction.Unit
					local lookDirection = Vector3.new(direction.X, 0, direction.Z).Unit
					local currentCFrame = npc:GetPivot()
					local targetCFrame = CFrame.lookAt(data.InterpolatedPos, data.InterpolatedPos + lookDirection)
					local smoothCFrame = currentCFrame:Lerp(targetCFrame, dt * 10)
					npc:PivotTo(smoothCFrame)
				else
					npc:PivotTo(CFrame.new(data.InterpolatedPos))
				end

				
				local hrp = npc:FindFirstChild("HumanoidRootPart")
				if hrp then
					hrp.AssemblyLinearVelocity = Vector3.zero
				end

				-- Check waypoint completion (same as non-redirected completion)
				if t >= 1 then
					

					-- Remove current waypoint
					table.remove(data.Waypoints, 1)
					data.CurrentWaypointIndex = data.CurrentWaypointIndex + 1

					if #data.Waypoints > 0 then
						-- Move to next waypoint - same setup as non-redirected
						data.Start = Utils:GetGroundedPosition(currentTarget)
						data.Target = data.Waypoints[1]
						data.StartTime = syncedTime

						local dist = (data.Target - data.Start).Magnitude
						data.Duration = math.max(0.1, dist / RedirectSpeed)

						
					else
						-- All waypoints completed - switch back to normal mode
						data.IsRedirected = false
						data.Finished = true
						data.Waypoints = nil
					
						npc:PivotTo(CFrame.new(data.Target))
						
						local humanoid = npc:FindFirstChildOfClass("Humanoid")
						if humanoid then
							
							local animator :Animator = humanoid:FindFirstChildOfClass("Animator")
							local animation = Config.Animations:FindFirstChild("Walk")
							
							if animator and animation then
								
								for _, v in pairs(animator:GetPlayingAnimationTracks()) do
									v:Stop()
								end
								
							end
						end
					end
				end

			else
				-- Original non-redirected movement logic (unchanged)
				local t = math.clamp((syncedTime - data.StartTime) / data.Duration, 0, 1)
				local predictedPos = data.Start:Lerp(data.Target, t)
				predictedPos = Utils:GetGroundedPosition(predictedPos)

				local finalPos = predictedPos:Lerp(data.LastNetworkPos, blendFactor)
				finalPos = Utils:GetGroundedPosition(finalPos)

				local lerpSpeed = 10
				data.InterpolatedPos = data.InterpolatedPos:Lerp(finalPos, dt * lerpSpeed)
				data.InterpolatedPos = Utils:GetGroundedPosition(data.InterpolatedPos)

				local direction = (data.Target - data.InterpolatedPos).Unit
				local lookDirection = Vector3.new(direction.X, 0, direction.Z).Unit
				local currentCFrame = npc:GetPivot()
				local targetCFrame = CFrame.lookAt(data.InterpolatedPos, data.InterpolatedPos + lookDirection)
				local smoothCFrame = currentCFrame:Lerp(targetCFrame, dt * 10)
				npc:PivotTo(smoothCFrame)

				local hrp = npc:FindFirstChild("HumanoidRootPart")
				if hrp then
					hrp.AssemblyLinearVelocity = Vector3.zero
				end

				if t >= 1 then
					data.Finished = true
					
					npc:PivotTo(CFrame.new(data.Target))
					
					if hrp then
						hrp.AssemblyLinearVelocity = Vector3.zero
					end
				end
			end

			-- Sync position and time (same for both modes)
			data.LastNetworkPos = data.InterpolatedPos
			data.LastNetworkTime = syncedTime
		end
	end
end
return NPCManager