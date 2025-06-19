local RunService = game:GetService("RunService")

local Config = require(script.Parent.Config)

local UpdateLoop = {}

local lastUpdateTime = 0

function UpdateLoop:Initialize(NPCManager, NetworkManager)
	self.NPCManager = NPCManager
	self.NetworkManager = NetworkManager
	self:StartUpdateLoop()
end

function UpdateLoop:StartUpdateLoop()
	RunService.Heartbeat:Connect(function(dt)
		local currentTime = tick()
		local relativeTime = currentTime - Config.SERVER_START_TIME

		if relativeTime - lastUpdateTime < Config.UPDATE_RATE then
			return
		end
		lastUpdateTime = relativeTime

		self.NPCManager:UpdateNPCs()
	end)
end

return UpdateLoop