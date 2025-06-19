local Config = require(script.Parent.Config)
local Proximity = require(script.Parent.Proximity)
local NPCManager = require(script.Parent.NPCManager)

local player = game.Players.LocalPlayer


local NetworkManager = {}

local function findNPC(npcid : number)
	print(npcid)
	for _, npc in pairs(game.Workspace.NPCS:GetChildren()) do
		if npc:GetAttribute("NPCID") then
			print(npc:GetAttribute("NPCID") == tonumber(npcid))
		if npc:GetAttribute("NPCID") == tonumber(npcid) then
			return npc
			end
		end
	end
end

function NetworkManager:Initialize(NPCManager, TimeSync, EventBuffer)
	self.NPCManager = NPCManager
	self.TimeSync = TimeSync
	self.EventBuffer = EventBuffer
	self:SetupEventConnections()

	-- Request initial sync when client loads
	self:RequestInitialSync()
end

local function hideProximityPrompt(ProxPrompt)
	ProxPrompt.Enabled = false
end



function NetworkManager:RequestInitialSync()
	-- Wait a moment for everything to load, then request sync
	task.wait(2)
	print("Requesting initial NPC sync from server...")
	game.ReplicatedStorage.Events.NPCSyncRequest:FireServer()
end

function NetworkManager:SetupEventConnections()
	-- Remove the bulk sync handler since we're using spawn events
	-- Config.Events.NPCSyncRequest.OnClientEvent:Connect(function(serializedData)

	-- Handle time sync
	Config.Events.TimeSync.OnClientEvent:Connect(function(serializedData)
		local Sera = require(game:GetService("ReplicatedStorage").Modules.Replication.Sera)
		local Schemas = require(script.Parent.Schemas)

		local syncData = Sera.Deserialize(Schemas.TimeSyncSchema, serializedData)
		if syncData then
			self.TimeSync:UpdateTimeSync(syncData.ServerTime)
		else
			print("ERROR: Failed to deserialize time sync data")
		end
	end)
	
	Config.Events.UpdateProxs.OnClientEvent:Connect(function(npcBuyOrSteal, hideProxFrom)
		-- Validate input
		if type(npcBuyOrSteal) ~= "table" or type(hideProxFrom) ~= "table" then
			warn("Invalid proximity update data received")
			return
		end

		print("yes good data sent")

		-- Process each NPC with error handling
		for npcId, actionType in pairs(npcBuyOrSteal) do
			local npcModel = findNPC(npcId)
			print("Processing NPC ID:", npcId)

			if npcModel then
				print("Found model for NPC:", npcId)
				print(actionType)

				if npcModel.HumanoidRootPart:FindFirstChild(actionType) then continue end
				
				local proximityPrompt = Proximity.new(npcModel.HumanoidRootPart,actionType)
				print(actionType)

			else
				warn("NPC model not found for ID:", npcId)
			end

		end

		-- Process hide/show with error handling
		for npcID, shouldHide in pairs(hideProxFrom) do
			local success, errorMsg = pcall(function()
				local npcModel = findNPC(npcID)

				if npcModel then
					print("Found model for hide operation, NPC:", npcID)
					for _, prox in pairs(npcModel:GetDescendants()) do
						if prox:IsA("ProximityPrompt") then
							print("Processing hide operation for NPC:", npcID)
							if shouldHide then
								print("Hiding prompt for NPC:", npcID)
								hideProximityPrompt(prox)
							else
								print("Showing prompt for NPC:", npcID)
								prox.Enabled = true -- Make sure to show it
							end
						end
					end
				else
					warn("NPC model not found for hide operation, ID:", npcID)
				end
			end)

			if not success then
				warn("Error processing hide operation for NPC", npcID, ":", errorMsg)
			end
		end
	end)
	
	local activeNPCAnimations = {}
	local activeNPCAttachments = {}
	
	
	-- find npc from npc id in the npcs folder
	-- weld npc to player
	-- use motor6ds to have a holding animation
	-- modify ncps motor6ds to be laying down (also rotate npc to be laying down)
	Config.Events.StealNPC.OnClientEvent:Connect(function(player, NPCID)
		local StolenNPC = findNPC(NPCID)

		print("hi")

		if activeNPCAttachments[NPCID] then
			for i,v in pairs(activeNPCAttachments[NPCID]) do
				if typeof(v) == "Instance" then
					v:Destroy()
				end
			end
		end

		print("heyyyy")



		if StolenNPC and player.Character and player.Character:FindFirstChild("HumanoidRootPart") then

			print("Starting NPC attachment process...")

			if game.Workspace.NPCS:FindFirstChild(StolenNPC.Name.."NPC") then
				-- this is the npcs npc (not the food npc)
				if game.Workspace.NPCS[StolenNPC.Name.."NPC"]:GetAttribute("NPC_ID") == tonumber(NPCID) then
					game.Workspace.NPCS:FindFirstChild(StolenNPC.Name.."NPC"):Destroy()
				end
			end

			-- ANCHOR NPC PARTS to prevent falling
			for _, part in pairs(StolenNPC:GetDescendants()) do
				if part:IsA("BasePart") then
					part.CanCollide = false
					part.Massless = true
					part.Anchored = true
					part.TopSurface = Enum.SurfaceType.Smooth
					part.BottomSurface = Enum.SurfaceType.Smooth

					part.Size = part.Size * 2
				end
			end

			-- Remove ONLY external constraints, NOT internal Motor6Ds
			for _, obj in pairs(StolenNPC:GetDescendants()) do
				if obj:IsA("BodyPosition") or obj:IsA("BodyVelocity") or obj:IsA("BodyAngularVelocity") or obj:IsA("BodyThrust") then
					obj:Destroy()
				elseif obj:IsA("WeldConstraint") then
					-- Only remove WeldConstraints that connect to external objects
					local part0, part1 = obj.Part0, obj.Part1
					if part0 and part1 then
						local part0InNPC = part0:IsDescendantOf(StolenNPC)
						local part1InNPC = part1:IsDescendantOf(StolenNPC)
						-- If one part is outside the NPC, remove the constraint
						if not (part0InNPC and part1InNPC) then
							obj:Destroy()
						end
					end
				elseif obj:IsA("Motor6D") then
					-- Only remove Motor6Ds that connect to external objects
					local part0, part1 = obj.Part0, obj.Part1
					if part0 and part1 then
						local part0InNPC = part0:IsDescendantOf(StolenNPC)
						local part1InNPC = part1:IsDescendantOf(StolenNPC)
						-- If one part is outside the NPC, remove the constraint
						if not (part0InNPC and part1InNPC) then
							obj:Destroy()
						end
					end
				end
			end

			-- Position NPC behind player
			StolenNPC.PrimaryPart.CFrame = player.Character.HumanoidRootPart.CFrame * CFrame.new(0, 0, -2)

			-- CRITICAL: Ensure player humanoid is not affected
			local playerHumanoid = player.Character.Humanoid
			playerHumanoid.PlatformStand = false
			playerHumanoid.Sit = false

			-- Wait for physics to settle
			game:GetService("RunService").Heartbeat:Wait()

			-- UNANCHOR before creating Motor6D
			for _, part in pairs(StolenNPC:GetDescendants()) do
				if part:IsA("BasePart") then
					part.Anchored = false
				end
			end

			-- Create Motor6D for attachment
			local motor6D = Instance.new("Motor6D")
			motor6D.Name = "NPCAttachment"
			motor6D.Part0 = player.Character.UpperTorso
			motor6D.Part1 = StolenNPC.PrimaryPart
			motor6D.C0 = CFrame.new()
			motor6D.C1 = CFrame.new(0, 0, -1.5)
			motor6D.Parent = player.Character.UpperTorso

			if activeNPCAttachments[NPCID] then
				table.insert(activeNPCAttachments[NPCID], motor6D)
			else
				activeNPCAttachments[NPCID] = {
					[1] = motor6D
				}
			end

			-- Load and play animations AFTER attachment
			--local NPCAnim = StolenNPC.Humanoid.Animator:LoadAnimation(game.ReplicatedStorage.Animations.DummyRide)
			local playerAnim = player.Character.Humanoid.Animator:LoadAnimation(game.ReplicatedStorage.Animations.PlayerRide)

			--NPCAnim.Looped = true
			playerAnim.Looped = true

			--NPCAnim:Play()
			playerAnim:Play()

			-- Ensure player can move
			game:GetService("RunService").Heartbeat:Wait()
			playerHumanoid:ChangeState(Enum.HumanoidStateType.Running)

		end
	end)
	
	Config.Events.LoadNPCData.OnClientEvent:Connect(function(data)
		
		for i,v in pairs(data) do
			
		end
		
	end)
	
	-- Handle new NPC spawns (including bulk sync)
	Config.Events.NPCSpawnEvent.OnClientEvent:Connect(function(serializedData)
		if not self.EventBuffer:IsClientReady() then
			self.EventBuffer:BufferSpawnEvent(serializedData)
			return
		end

		self.NPCManager:HandleSpawnEvent(serializedData)
	end)

	-- Handle NPC batch updates
	Config.Events.NPCBatchEvent.OnClientEvent:Connect(function(serializedData)
		if not self.EventBuffer:IsClientReady() then
			self.EventBuffer:BufferBatchEvent(serializedData)
			return
		end

		self.NPCManager:HandleBatchEvent(serializedData)
	end)

	-- Handle NPC destruction
	Config.Events.NPCDestroyEvent.OnClientEvent:Connect(function(serializedData)
		if not self.EventBuffer:IsClientReady() then
			self.EventBuffer:BufferDestroyEvent(serializedData)
			return
		end

		self.NPCManager:HandleDestroyEvent(serializedData)
	end)

	-- Handle NPC redirects
	Config.Events.NPCRedirectEvent.OnClientEvent:Connect(function(serializedData)
		if not self.EventBuffer:IsClientReady() then
			self.EventBuffer:BufferRedirectEvent(serializedData)
			return
		end

		self.NPCManager:HandleRedirectEvent(serializedData)
	end)
end

return NetworkManager