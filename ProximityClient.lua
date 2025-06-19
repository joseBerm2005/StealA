local Proximity = {}
Proximity.__index = Proximity
local NPC_INFO = require(game.ReplicatedStorage.Modules.Shared.NPC_INFO)
local Replica_Listener = require(script.Parent.Parent.Parent.Client.Modules.Data.Replica_Listener)


local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Events = ReplicatedStorage:WaitForChild("Events")

type proximity = {
	Proximity: ProximityPrompt;
	NPC_Name: string;
	Triggered: (self : proximity) -> ()
}

-- // added name argument to be able to handle more than one in every npc
-- // should only be used on the buy bc ye (on npcs. refer to updateprox in server networkmanager on why) - catman
function Proximity.new(HRP : Part, Name): proximity
	local self = setmetatable({}, Proximity) :: proximity
	
	for _, v in pairs(HRP:GetChildren()) do
		if v:IsA("ProximityPrompt") then
			v:Destroy()
		end
	end
	
	task.wait()

	self.Proximity = Instance.new("ProximityPrompt")
	self.Proximity.MaxActivationDistance = 16
	self.Proximity.ActionText = Name.." " .. HRP.Parent.Name
	self.Proximity.RequiresLineOfSight = false
	self.Proximity.Parent = HRP
	self.Proximity.Name = Name

	self.NPC_Name = HRP.Parent.Name
	self.Proximity.Triggered:Connect(function(player)
		print("hi yo :3")
		Proximity.Triggered(self, player, HRP.Parent:GetAttribute("NPCID"), HRP)
	end)

	return self
end


function Proximity.Triggered(self : proximity, player, Attribute, HRP)
	local Data = Replica_Listener:GetData()
	--if Data.Cash < NPC_INFO.NPCS[self.NPC_Name].Price then return end -- doing this on the server too for security reasons // obviously -- yoda962 // shutup - CatMan
	
	
	if self.Proximity.Name == "Buy" then
		
		Events.BuyNPC:FireServer(Attribute)
		
		
		self.Proximity:Destroy()
	end
	
	if self.Proximity.Name == "Steal" then
		
		print("steal >:3")
		print(Attribute)
		
		Events.StealNPC:FireServer(Attribute)
		
		Events.UpdatePromiximities:FireServer()
		
	end
	
	if self.Proximity.Name == "Sell" then
		print("Sell :D")
	end
	
end


return Proximity
