local RunService = game:GetService("RunService")

local UpdateLoop = {}

function UpdateLoop:Initialize(NPCManager, TimeSync)
	self.NPCManager = NPCManager
	self.TimeSync = TimeSync
	self:StartUpdateLoop()
end

function UpdateLoop:StartUpdateLoop()
	RunService.RenderStepped:Connect(function(dt)
		local now = self.TimeSync:GetSyncedTime()
		self.NPCManager:UpdateNPCs(dt, now)
	end)
end

return UpdateLoop