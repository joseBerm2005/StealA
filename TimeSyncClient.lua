local TimeSync = {}

local CLIENT_START_TIME = tick()
local TIME_OFFSET = 0
local NETWORK_LATENCY = 0.05
local TIME_SYNC_SAMPLES = {}
local MAX_SAMPLES = 5


function TimeSync:UpdateTimeSync(serverTime)
	local clientTime = tick() - CLIENT_START_TIME
	local rawOffset = serverTime - clientTime

	
	table.insert(TIME_SYNC_SAMPLES, {
		offset = rawOffset,
		timestamp = clientTime
	})

	
	if #TIME_SYNC_SAMPLES > MAX_SAMPLES then
		table.remove(TIME_SYNC_SAMPLES, 1)
	end


	local totalOffset = 0
	for _, sample in ipairs(TIME_SYNC_SAMPLES) do
		totalOffset = totalOffset + sample.offset
	end

	TIME_OFFSET = totalOffset / #TIME_SYNC_SAMPLES
	NETWORK_LATENCY = math.abs(TIME_OFFSET) / 2

end

function TimeSync:GetSyncedTime()
	return (tick() - CLIENT_START_TIME) + TIME_OFFSET
end

return TimeSync