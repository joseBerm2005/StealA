local RunService = game:GetService("RunService")

local Config = require(script.Config)
local NPCManager = require(script.NPCManager)
local NetworkManager = require(script.NetworkManager)
local TimeSync = require(script.TimeSync)
local EventBuffer = require(script.EventBuffer)
local UpdateLoop = require(script.UpdateLoop)


NetworkManager:Initialize(NPCManager, TimeSync, EventBuffer)
UpdateLoop:Initialize(NPCManager, TimeSync)


task.spawn(function()
	task.wait(1)

	print("Client ready, signaling server...")
	EventBuffer:SetClientReady(true)
	Config.Events.ClientReady:FireServer()

	EventBuffer:ProcessBufferedEvents(NPCManager)

	task.wait(5)
	if not EventBuffer:HasReceivedInitialSync() then
		print("Backup sync request...")
		Config.Events.NPCSyncRequest:FireServer()
	end
end)