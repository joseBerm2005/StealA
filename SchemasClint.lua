local Sera = require(game:GetService("ReplicatedStorage").Modules.Replication.Sera)

local Schemas = {}

-- NPC Spawn Schema
Schemas.NPCSpawnSchema = Sera.Schema({
	ID = Sera.Uint16,
	StartTime = Sera.Float32,
	Duration = Sera.Float32,
	ServerTime = Sera.Float32,
	NpcName = Sera.String8, -- Max 255 characters
	CurrentPosition = Sera.Vector3, -- Remove Optional wrapper since Sera doesn't have it
})

-- NPC Batch Schema
Schemas.NPCBatchSchema = Sera.Schema({
	Timestamp = Sera.Float32,
	Count = Sera.Uint16,
	IDs = Sera.Buffer16, -- Max 65,535 bytes
	Positions = Sera.Buffer16, -- Max 65,535 bytes
})

-- NPC Destroy Schema
Schemas.NPCDestroySchema = Sera.Schema({
	Count = Sera.Uint16,
	IDs = Sera.Buffer16,
})

-- NPC Bulk Sync Schema
Schemas.NPCBulkSyncSchema = Sera.Schema({
	ServerTime = Sera.Float32,
	Count = Sera.Uint16,
	NPCData = Sera.Buffer16, -- Contains packed NPC data
})

-- NPC Redirect Schema
Schemas.NPCRedirectSchema = Sera.Schema({
	ID = Sera.Uint16,
	NewStart = Sera.Vector3,
	NewTarget = Sera.Vector3,
	NewStartTime = Sera.Float32,
	NewDuration = Sera.Float32,
	ServerTime = Sera.Float32,
})

-- Time Sync Schema
Schemas.TimeSyncSchema = Sera.Schema({
	ServerTime = Sera.Float32,
})

return Schemas