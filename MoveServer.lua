--!native

local MoveServer = {}
local RunService = game:GetService("RunService")

-- Import modules
local Config = require(script.Config)
local NPCManager = require(script.NPCManager)
local NetworkManager = require(script.NetworkManager)
local PlayerManager = require(script.PlayerManager)
local UpdateLoop = require(script.UpdateLoop)

-- Initialize all managers
PlayerManager:Initialize()
UpdateLoop:Initialize(NPCManager, NetworkManager)

-- Start the spawning loop
task.spawn(function()
	while true do
		task.wait(Config.NPC_SPAWN_INTERVAL)
		NPCManager:SpawnNPC()
	end
end)

-- Start the time sync loop
task.spawn(function()
	while true do
		task.wait(Config.TIME_SYNC_INTERVAL)
		NetworkManager:SendTimeSync()
	end
end)

return MoveServer