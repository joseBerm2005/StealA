local Players = game:GetService("Players")

local Config = require(script.Parent.Config)

local Utils = {}


function Utils:GetCharactersToExclude()
	local excludeList = {Config.NPC_Folder}

	for _, player in pairs(Players:GetPlayers()) do
		if player.Character and player.Character:FindFirstChild("HumanoidRootPart") then
			table.insert(excludeList, player.Character)
		end
	end

	return excludeList
end


function Utils:GetGroundedPosition(position)
	local raycastParams = RaycastParams.new()
	raycastParams.FilterType = Enum.RaycastFilterType.Exclude
	raycastParams.FilterDescendantsInstances = self:GetCharactersToExclude()

	local rayOrigin = Vector3.new(position.X, position.Y + 10, position.Z)
	local rayDirection = Vector3.new(0, -Config.RAYCAST_DISTANCE, 0)
	


	local raycastResult = workspace:Raycast(rayOrigin, rayDirection, raycastParams)

	if raycastResult then
		return Vector3.new(position.X, raycastResult.Position.Y + 3, position.Z)
	else
		return position
	end
end

return Utils