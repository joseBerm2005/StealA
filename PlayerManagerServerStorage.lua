--!strict

local PlayerManager = {}
local ProfileLoader = require(game.ServerScriptService.Modules.Data.DataLoader)

function PlayerManager.CalculateTotalBoost(Player : Player): number
	local Profile = ProfileLoader.GetReplica(Player)
	local MoneyBoosts = Profile.Data.MoneyBoosts
	
	local Extra = 1
	
	local hasPass = game:GetService("MarketplaceService"):UserOwnsGamePassAsync(Player.UserId, 1262544659)
	
	if hasPass then Extra = 2 end
	
	return MoneyBoosts.FriendBoost * MoneyBoosts.RebirthBoost * Extra
end

function PlayerManager.AddMoney(Player : Player, Amount : number)
	local Replica = ProfileLoader.GetReplica(Player)
	print(PlayerManager.CalculateTotalBoost(Player))
	Replica:SetValue("Cash", Replica.Data.Cash + (Amount * PlayerManager.CalculateTotalBoost(Player)))
end

return PlayerManager
