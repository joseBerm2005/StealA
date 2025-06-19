local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = {}

-- Positions
Config.Start_Pos = workspace:WaitForChild("StartPos").Position
Config.End_Pos = workspace:WaitForChild("EndGoal").End_Pos.Position

-- Movement settings
Config.MOVE_SPEED = 12

Config.RedirectSpeed = 25

-- Update settings
Config.BATCH_SIZE = 20
Config.UPDATE_RATE = 1/40
Config.NPC_SPAWN_INTERVAL = 3
Config.TIME_SYNC_INTERVAL = 2
Config.PLAYER_SYNC_TIMEOUT = 10
Config.SYNC_DELAY = 0.1
Config.DESTROY_DELAY = 0.5

-- Server timing
Config.SERVER_START_TIME = tick()

-- Events
Config.Events = {
	NPCBatchEvent = ReplicatedStorage.Events.NPCBatchEvent,
	NPCSpawnEvent = ReplicatedStorage.Events.NPCSpawnEvent,
	NPCDestroyEvent = ReplicatedStorage.Events.NPCDestroyEvent,
	TimeSync = ReplicatedStorage.Events.TimeSync,
	NPCSyncRequest = ReplicatedStorage.Events.NPCSyncRequest,
	ClientReady = ReplicatedStorage.Events.ClientReady,
	NPCRedirectEvent = ReplicatedStorage.Events.NPCRedirectEvent,
	UpdateProxs = ReplicatedStorage.Events.UpdatePromiximities,
	NpcLoadEvent = ReplicatedStorage.Events.LoadNPCData
}

return Config