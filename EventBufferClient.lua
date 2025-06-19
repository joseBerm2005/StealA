local EventBuffer = {}


local CLIENT_READY = false
local INITIAL_SYNC_RECEIVED = false
local BUFFERED_BATCH_EVENTS = {}
local BUFFERED_SPAWN_EVENTS = {}
local BUFFERED_DESTROY_EVENTS = {}

function EventBuffer:SetClientReady(ready)
	CLIENT_READY = ready
end

function EventBuffer:IsClientReady()
	return CLIENT_READY
end

function EventBuffer:SetInitialSyncReceived(received)
	INITIAL_SYNC_RECEIVED = received
end

function EventBuffer:HasReceivedInitialSync()
	return INITIAL_SYNC_RECEIVED
end

function EventBuffer:BufferSpawnEvent(serializedData)
	table.insert(BUFFERED_SPAWN_EVENTS, serializedData)
end

function EventBuffer:BufferBatchEvent(serializedData)
	table.insert(BUFFERED_BATCH_EVENTS, serializedData)
end

function EventBuffer:BufferDestroyEvent(serializedData)
	table.insert(BUFFERED_DESTROY_EVENTS, serializedData)
end

function EventBuffer:ProcessBufferedEvents(NPCManager)


	for _, serializedData in ipairs(BUFFERED_SPAWN_EVENTS) do
		NPCManager:HandleSpawnEvent(serializedData)
	end


	for _, serializedData in ipairs(BUFFERED_BATCH_EVENTS) do
		NPCManager:HandleBatchEvent(serializedData)
	end

	
	for _, serializedData in ipairs(BUFFERED_DESTROY_EVENTS) do
		NPCManager:HandleDestroyEvent(serializedData)
	end

	
	BUFFERED_SPAWN_EVENTS = {}
	BUFFERED_BATCH_EVENTS = {}
	BUFFERED_DESTROY_EVENTS = {}
end

return EventBuffer