--!strict

local ProductManager = {}

local MKS = game:GetService("MarketplaceService")

local PlayerManager = require(game.ServerStorage.Modules.Data.PlayerManager)
local RandomNpcs = require(script.Parent.Random_NPC)

ProductManager.productIds = {}


ProductManager.productIds[3308764466] = function(Player : Player, Receipt)
	PlayerManager.AddMoney(Player, 2500)
end

ProductManager.productIds[3308764680] = function(Player : Player, receipt)
	PlayerManager.AddMoney(Player, 25000)
end

ProductManager.productIds[3308764814] = function(Player : Player, receipt)
	PlayerManager.AddMoney(Player, 80000)
end

ProductManager.productIds[3308764973] = function(Player : Player, receipt)
	PlayerManager.AddMoney(Player, 225000)
end

ProductManager.productIds[3308765104] = function(Player : Player, receipt)
	print("adding")
	PlayerManager.AddMoney(Player, 2500000)
end

ProductManager.productIds[3308822693] = function(Player : Player, receipt)
	RandomNpcs:AddBoostTime(900)
end


local function ProcessGamepass(Player : Player, GamepassId : number, WasPurchased : boolean)
	if not WasPurchased then return end
	
	local ShopUI = Player.PlayerGui.MainUI.UI.RobuxShop.Content.ScrollingFrame.BottomMiddle.Passes
	
	if GamepassId == 1262704501 then
		ShopUI.VIP.BuyPass.Price.Text = "Purchased"
	elseif GamepassId == 1262544659 then
		ShopUI.DoubleCash.BuyPass.Price.Text = "Purchased"
	elseif GamepassId == 1262192080 then
		ShopUI.HDAdmin.BuyPass.Price.Text = "Purchased"
	end
end

local function ProcessReceipt(receipt)
	local player = game.Players:GetPlayerByUserId(receipt.PlayerId)
	local productId = receipt.ProductId
	
	print(receipt.ProductId)
	
	print("T")

	if not player:IsDescendantOf(game.Players) then
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end

	if ProductManager.productIds[productId] then
		ProductManager.productIds[productId](player, receipt)
		return Enum.ProductPurchaseDecision.PurchaseGranted
	else
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end
end



MKS.ProcessReceipt = ProcessReceipt

MKS.PromptGamePassPurchaseFinished:Connect(function(Player : Player, GamepassId : number, WasPurchased : boolean)
	ProcessGamepass(Player, GamepassId, WasPurchased)
end)



return ProductManager
