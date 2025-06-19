local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = {}


Config.NPC_Folder = workspace:WaitForChild("NPCS")
Config.Assets = ReplicatedStorage.Assets
Config.NPC_Template = Config.Assets.NPCs.Rig

Config.Start_Pos = workspace:WaitForChild("StartPos").Position
Config.End_Pos = workspace:WaitForChild("EndGoal"):WaitForChild("End_Pos").Position

Config.RAYCAST_DISTANCE = 50

Config.Animations = ReplicatedStorage.Animations

-- Events
Config.Events = {
	NPCBatchEvent = ReplicatedStorage.Events:WaitForChild("NPCBatchEvent"),
	NPCSpawnEvent = ReplicatedStorage.Events:WaitForChild("NPCSpawnEvent"),
	NPCDestroyEvent = ReplicatedStorage.Events:WaitForChild("NPCDestroyEvent"),
	TimeSync = ReplicatedStorage.Events:WaitForChild("TimeSync"),
	NPCSyncRequest = ReplicatedStorage.Events:WaitForChild("NPCSyncRequest"),
	ClientReady = ReplicatedStorage.Events:WaitForChild("ClientReady"),
	NPCRedirectEvent = ReplicatedStorage.Events:WaitForChild("NPCRedirectEvent"),
	StealNPC = ReplicatedStorage.Events:WaitForChild("StealNPC"),
	PlaceNPC = ReplicatedStorage.Events:WaitForChild("NPCPlacement"),
	UpdateProxs = ReplicatedStorage.Events:WaitForChild("UpdatePromiximities"),
	LoadNPCData = ReplicatedStorage.Events:WaitForChild("LoadNPCData")
}

return Config