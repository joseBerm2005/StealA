local Config = require(script.Parent.Config)
local NetworkManager = require(script.Parent.NetworkManager)
local Random_NPC = require(script.Parent.Parent.Random_NPC)
local Bases = require(script.Parent.Parent.Bases)
local NpcInfo = require(game.ReplicatedStorage.Modules.Shared.NPC_INFO)
local DataManager = require(script.Parent.Parent.Parent.Data.DataLoader)

local NPCManager = {}

NPCManager.NPCStates = {}

NPCManager.StolenNPCsOutOfPlots = {}

NPCManager.NPCsInPlots = {}

NPCManager.NextNPCID = 1

function NPCManager:FilterWaypoints(waypoints, maxWaypoints)
	if not waypoints or #waypoints <= maxWaypoints then
		return waypoints
	end

	local filteredWaypoints = {}
	local totalWaypoints = #waypoints

	-- Always keep the first waypoint
	table.insert(filteredWaypoints, waypoints[1])

	-- Calculate step size to get evenly distributed waypoints
	local step = math.max(2, math.floor(totalWaypoints / (maxWaypoints - 1)))

	-- Add intermediate waypoints
	for i = step, totalWaypoints - step, step do
		table.insert(filteredWaypoints, waypoints[i])
	end

	-- Always keep the last waypoint
	if filteredWaypoints[#filteredWaypoints] ~= waypoints[totalWaypoints] then
		table.insert(filteredWaypoints, waypoints[totalWaypoints])
	end

	
	return filteredWaypoints
end

-- Simple spawn function (for npcs in the line only)
function NPCManager:SpawnNPC()
	local currentTime = tick()
	local relativeTime = currentTime - Config.SERVER_START_TIME
	local npcID = NPCManager.NextNPCID
	NPCManager.NextNPCID += 1

	local startPos = Config.Start_Pos
	local endPos = Config.End_Pos

	local NPCName = Random_NPC:GetRandomNPCName()

	local totalDist = (endPos - startPos).Magnitude
	local duration = totalDist / Config.MOVE_SPEED

	NPCManager.NPCStates[npcID] = {
		Start = startPos,
		Target = endPos,
		StartTime = relativeTime,
		Duration = duration,
		Finished = false,
		CurrentPosition = startPos,
		NpcName = NPCName,
		SwitchToBase = false,
		Owner = nil,
		RedirectRequested = false,
		RedirectData = nil,
	}

	local spawnData = {
		ID = npcID,
		StartTime = relativeTime,
		Duration = duration,
		ServerTime = relativeTime,
		NpcName = NPCName,
		CurrentPosition = startPos, -- Always send current position
	}

	
	NetworkManager:SendNPCSpawn(spawnData)
end

-- Request redirect (called from NetworkManager)
function NPCManager:RequestNPCRedirect(npcID, player)
	local state = NPCManager.NPCStates[npcID]
	
	local ActiveNps = NPCManager:GetActiveNPCs()
	local NPC_NAME = nil
	for _, child in ActiveNps do
		if child.ID == npcID then
			NPC_NAME = child.NpcName
			break
		end
	end

	if NPC_NAME == nil then return end
	
	local Cost = NpcInfo.NPCS[NPC_NAME].Price
	
	local CachedReplica = require(game.ServerScriptService.Modules.Data.DataLoader).GetReplica(player)
	
	local CurrentCash = CachedReplica.Data.Cash

	if CurrentCash < Cost then return end
	
	
	
	-- might remove this later idk
	if not state or state.Finished or state.SwitchToBase then
		return false
	end

	local playerBase = Bases.Get_Player_Plot(player)
	if not playerBase then
		return false
	end

	-- Time to finally code this bad boy fr
	-- check first floor first then second floor
	local Pads = playerBase.Floor1.Interactables.Pads
	
	local RandomPad = Pads:GetChildren()[math.random(1, #Pads:GetChildren())]
	if not RandomPad then
		return false
	end
	local basePosition = RandomPad.Main.Position
	
	RandomPad:SetAttribute("NPC", NPC_NAME)
	

	
	CachedReplica:SetValue("Cash", CurrentCash - Cost)

	
	
	
	CachedReplica:SetValue({"Index", NPC_NAME}, true)

	
	state.RedirectRequested = true
	state.RedirectData = {
		player = player,
		basePosition = basePosition
	}

	return true
end

function NPCManager:GetCurrentNPCPosition(npcID, state, currentTime)
	if state.Finished then
		return state.Target
	end

	local t = math.clamp((currentTime - state.StartTime) / state.Duration, 0, 1)
	if t >= 1 then
		return state.Target
	else
		return state.Start:Lerp(state.Target, t)
	end
end

function NPCManager:GetActiveNPCs()
	local currentTime = tick()
	local relativeTime = currentTime - Config.SERVER_START_TIME
	local activeNPCs = {}

	for npcID, state in pairs(NPCManager.NPCStates) do
		if not state.Finished then
			local currentPos = self:GetCurrentNPCPosition(npcID, state, relativeTime)
			table.insert(activeNPCs, {
				ID = npcID,
				StartTime = state.StartTime,
				Duration = state.Duration,
				CurrentPosition = currentPos,
				NpcName = state.NpcName,
			})
		end
	end

	return activeNPCs, relativeTime
end

function NPCManager:UpdateNPCs()
	local currentTime = tick()
	local relativeTime = currentTime - Config.SERVER_START_TIME

	local npcBatch = {}
	local toDestroy = {}
	local redirectBatch = {}

	for npcID, state in pairs(NPCManager.NPCStates) do
		if not state.Finished then
			-- Handle redirect: if a redirect was requested for this NPC
			if state.RedirectRequested and not state.SwitchToBase then
				print("=== SERVER REDIRECT FOR NPC", npcID, "===")
				local currentPos = self:GetCurrentNPCPosition(npcID, state, relativeTime)

				-- Use Roblox's PathfindingService to compute the navigation path
				local pathfinder = game:GetService("PathfindingService")
				local path = pathfinder:CreatePath({
					AgentRadius = 2,
					AgentHeight = 5,
					AgentCanJump = false, -- Disable jumping to prevent hopping
					WaypointSpacing = 10, -- Increase spacing between waypoints
				})

				path:ComputeAsync(currentPos, state.RedirectData.basePosition)
				local waypoints = {}

				if path.Status == Enum.PathStatus.Success then
					local rawWaypoints = path:GetWaypoints()
					

					-- Convert waypoints to positions and filter out Jump waypoints
					for _, waypoint in ipairs(rawWaypoints) do
						if waypoint.Action ~= Enum.PathWaypointAction.Jump then
							table.insert(waypoints, waypoint.Position)
						end
					end

					-- Filter to maximum 5-6 waypoints for smooth movement
					waypoints = self:FilterWaypoints(waypoints, 10)
				
				else
					-- if pathfinding fails, fall back to a direct path
				
					table.insert(waypoints, state.RedirectData.basePosition)
				end

				-- Calculate new duration based on total path distance
				local totalDistance = 0
				local lastPos = currentPos
				for _, waypoint in ipairs(waypoints) do
					totalDistance = totalDistance + (waypoint - lastPos).Magnitude
					lastPos = waypoint
				end
				local newDuration = totalDistance / Config.RedirectSpeed

				-- Update the NPC state for the redirection
				state.Start = currentPos
				state.Target = state.RedirectData.basePosition
				state.StartTime = relativeTime
				state.Duration = newDuration
				state.SwitchToBase = true
				state.Owner = state.RedirectData.player
				state.CurrentPosition = currentPos
				state.RedirectRequested = false

				table.insert(redirectBatch, {
					ID = npcID,
					NewStart = currentPos,
					NewTarget = state.RedirectData.basePosition,
					NewStartTime = relativeTime,
					NewDuration = newDuration,
					Waypoints = waypoints, -- Now properly filtered waypoints
				})

				
			end

			-- Normal movement handling (remains unchanged)
			local t = math.clamp((relativeTime - state.StartTime) / state.Duration, 0, 1)
			if t >= 1 then
				state.Finished = true
				state.CurrentPosition = state.Target
				table.insert(npcBatch, {
					ID = npcID,
					Position = state.Target,
				})

				if state.SwitchToBase then
					local GetPlayerBase = Bases.Get_Player_Plot(state.Owner)
					if GetPlayerBase then
						print("inserted")
						
						print(GetPlayerBase)
						
						local spotkey
						
						for _, spots in pairs(GetPlayerBase:GetDescendants()) do
							if spots.Parent.Name == "Pads" then
								print("found the pads")
								if spots:GetAttribute("NPC") then
									print("has attribute")
									if spots:GetAttribute("NPC") == state.NpcName then
										spotkey = spots
									end
								end
							end
						end
						
						NPCManager.NPCsInPlots[npcID] = {
							player = state.Owner,
							Base = GetPlayerBase,
							spot = spotkey,
							npcName = state.NpcName
						}
						NPCManager.NPCStates[npcID] = nil
						
						task.wait(0.2)
						
						NetworkManager.UpdatePromixities()
					end
				else
					table.insert(toDestroy, npcID)
				end
			else
				local lerpedPos = state.Start:Lerp(state.Target, t)
				state.CurrentPosition = lerpedPos
				table.insert(npcBatch, {
					ID = npcID,
					Position = lerpedPos,
				})
			end
		end
	end

	-- Send updates
	if #npcBatch > 0 then
		NetworkManager:SendNPCBatch(npcBatch, relativeTime)
	end

	if #redirectBatch > 0 then
		NetworkManager:SendNPCRedirectBatch(redirectBatch, relativeTime)
	end

	-- Clean up
	if #toDestroy > 0 then
		task.wait(Config.DESTROY_DELAY)
		NetworkManager:SendNPCDestroy(toDestroy)

		for _, npcID in ipairs(toDestroy) do
			NPCManager.NPCStates[npcID] = nil
		end
	end
end

function NPCManager:LoadPlayerNPCs(player, npcData)
	local playerBase = require(script.Parent.Parent.Bases).Get_Player_Plot(player)
	if not playerBase then
		warn("No player base found for", player.Name)
		return
	end

	for npcid, data in pairs(npcData) do
		local targetPad = nil
		for _, floor in pairs({"Floor1", "Floor2"}) do
			local pads = playerBase[floor].Interactables.Pads
			targetPad = pads:FindFirstChild(data.padName)
			if targetPad then break end
		end

		if targetPad then
			targetPad:SetAttribute("NPC", data.npcName)

			NPCManager.NPCsInPlots[npcid] = {
				player = player.Name,
				Base = playerBase,
				spot = targetPad,
				npcName = data.npcName
			}

			local Bases = require(script.Parent.Parent.Bases)
			Bases.pendingMoneyTbl[npcid] = {
				player = player.Name,
				spot = targetPad,
				money = data.money or 0,
				Base = playerBase
			}

			print("Loaded NPC:", data.npcName, "on", data.padName, "with", data.money, "pending money")
		else
			warn("Could not find pad", data.padName, "for player", player.Name)
		end
	end
end

game.Players.PlayerAdded:Connect(function(Player : Player)
	task.wait(2)

	local Replica = DataManager.GetReplica(Player)
	if Replica and Replica.Data.NPCS then
		NPCManager:LoadPlayerNPCs(Player, Replica.Data.NPCS)
	end
end)


return NPCManager