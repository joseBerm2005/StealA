--!strict
local Bases = {
	pendingMoneyTbl = {}
}

local Plots_Folder = workspace.Plots

local PlotTbl = {} :: {[number]: Player | string} -- index: player, if string "" then can be claimed

local LockThreads = {} :: {[Player]: thread}

local DebounceTable = {} :: {[Player]: number}

local Profiles = require(script.Parent.Parent.Data.DataLoader)
local PlayerManager = require(game.ServerStorage.Modules.Data.PlayerManager)

local NPCLoadCallback = true

function Bases.SetNPCLoadCallback(callback)
	NPCLoadCallback = callback
end

function Bases.Plots_Init()
	for i = 1, #Plots_Folder:GetChildren() do
		PlotTbl[i] = ""
	end
end

Bases.Plots_Init()

local Players = game:GetService("Players")

local function GetPlayerFromPart(part: BasePart): Player?
	local character = part:FindFirstAncestorWhichIsA("Model")
	if not character then return nil end

	return Players:GetPlayerFromCharacter(character)
end


local function SetModelVisibility(model: Model, visible: boolean)
	for _, descendant in ipairs(model:GetDescendants()) do
		if descendant:IsA("BasePart") then
			descendant.Transparency = visible and 0 or 1
			descendant.CanCollide = visible
		elseif descendant:IsA("Decal") then
			descendant.Transparency = visible and 0 or 1
		end
	end
end

Profiles.LblSignal:Connect(function(Params : Player)
	print("Signal got")
	task.wait(0.1)
	PlayerManager.CalculateTotalBoost(Params)
end)




--[[
	Helper function, will return the players base index

]]
function Bases.GetIndex(Player : Player): number
	for Index, value in PlotTbl do
		if PlotTbl[Index] ~= Player then continue end
		return Index
	end
	return 0;
end

function Bases.IsBaseLocked(Player : Player) : boolean
	
	if LockThreads[Player] then return true end
	
	return false
end

function Bases.Plot_Lock(Player : Player, State : boolean)
	local Player_Plot = Bases.Get_Player_Plot(Player)
	if not Player_Plot then return end

	local InvisWall = Player_Plot.Floor1.Interactables:FindFirstChild("InvisWall") :: Part
	local InvisWall2 = Player_Plot.Floor2.Interactables:FindFirstChild("InvisWall") :: Part

	local Laser1 = Player_Plot.Floor1.Interactables:FindFirstChild("Lasers") :: Model
	local Laser2 = Player_Plot.Floor2.Interactables:FindFirstChild("Lasers") :: Model

	InvisWall.CanCollide = State
	InvisWall2.CanCollide = State

	SetModelVisibility(Laser1, State)
	SetModelVisibility(Laser2, State)
end

function Bases.Get_Player_Plot(Player : Player): typeof(Plots_Folder.Plot1)
	local PlotIndex = Bases.GetIndex(Player)
	
	local Player_Plot = Plots_Folder:FindFirstChild("Plot"..tostring(PlotIndex))
	
	return Player_Plot or nil
end

function Bases.Plots_Change_Boost_Lbl(Player : Player)
	local Plot = Bases.Get_Player_Plot(Player)
	local BBG : BillboardGui = Plot.Floor1.Interactables.CollectZone:FindFirstChild("BillboardGui", true)
	local TextLabel : TextLabel? = BBG:FindFirstChildOfClass("TextLabel")
	if not TextLabel then return end
	TextLabel.Text = "CASH MULTI: <br/> <font color='#ffbf00'> x"..PlayerManager.CalculateTotalBoost(Player) .. "</font>"
end



function Bases.Lock_Timer(Player: Player)
	local profile = Profiles.GetReplica(Player)
	print(profile)
	local lockTime = profile.Data.Lock_Timer

	local playerPlot = Bases.Get_Player_Plot(Player)
	if not playerPlot then return end

	local billboardLabel = playerPlot.Floor1.Interactables.Lock.BillboardGui.TextLabel
	local Billboardlabel2 = playerPlot.Floor2.Interactables.Lock.BillboardGui.TextLabel

	if LockThreads[Player] then
		task.cancel(LockThreads[Player])
		LockThreads[Player] = nil
	end

	local thread = task.spawn(function()
		local start = tick()
		while true do
			local elapsed = tick() - start
			local remaining = math.max(0, math.ceil(lockTime - elapsed))
			if not Player:GetAttribute("Locked") then
				if billboardLabel then
					billboardLabel.Text = "Lock Your Base!"
				end
				if Billboardlabel2 then
					Billboardlabel2.Text = "Lock Your Base!"
				end
				break
			end

			if billboardLabel then
				billboardLabel.Text = `Unlocking in {remaining}s`
			end
			
			if Billboardlabel2 then
				Billboardlabel2.Text = `Unlocking in {remaining}s`
			end

			if remaining <= 0 then
				Bases.Plot_Lock(Player, false)
				Player:SetAttribute("Locked", false)

				if billboardLabel then
					billboardLabel.Text = "Lock Your Base!"
				end

				if Billboardlabel2 then
					Billboardlabel2.Text = "Lock Your Base!"
				end
				break
			end

			task.wait(1)
		end

		LockThreads[Player] = nil
	end)

	LockThreads[Player] = thread
end


local function bindTouch(part: BasePart, floorName: string, plot: Model)
	if not part then return end

	local laserModel = plot[floorName] and plot[floorName].Interactables:FindFirstChild("Lasers") :: Model

	part.Touched:Connect(function(hit)
		local player = GetPlayerFromPart(hit)
		if not player then return end

		local now = tick()
		if DebounceTable[player] and now - DebounceTable[player] < 2 then
			return
		end
		DebounceTable[player] = now

		local ownedPlot = Bases.Get_Player_Plot(player)
		if not ownedPlot or ownedPlot ~= plot then return end

		print(player.Name .. " touched their own locked part on " .. floorName)
		
		player:SetAttribute("Locked", not player:GetAttribute("Locked"))

		Bases.Plot_Lock(player, player:GetAttribute("Locked"))
		
		local Plot = Bases.Get_Player_Plot(player)
		
		game.ReplicatedStorage.Events.Group:FireClient(player, Plot)

		Bases.Lock_Timer(player)
	end)
end


function Bases.Setup_Lock_Touch_Listeners()
	for _, plot in Plots_Folder:GetChildren() do
		local floor1Lock = plot:FindFirstChild("Floor1") and plot.Floor1.Interactables:FindFirstChild("Lock")
		local floor2Lock = plot:FindFirstChild("Floor2") and plot.Floor2.Interactables:FindFirstChild("Lock")

		bindTouch(floor1Lock, "Floor1", plot)
		bindTouch(floor2Lock, "Floor2", plot)
	end
end

Bases.Setup_Lock_Touch_Listeners()





function Bases.Plot_Position_Player(Player: Player)
	local Player_Plot = Bases.Get_Player_Plot(Player)
	if not Player_Plot then return end

	local PlrChar = Player.Character or Player.CharacterAdded:Wait()
	local targetPos = Player_Plot.Floor1.Interactables.CollectZone.Part.Position + Vector3.new(0, 5, 0)

	PlrChar:PivotTo(CFrame.new(targetPos))
end

function Bases.Plot_Load_Data(Player : Player)
	local Player_Plot = Bases.Get_Player_Plot(Player)
	
	local TextLabel = Player_Plot.Floor1.Interactables.Sign:FindFirstChild("TextLabel", true) :: TextLabel
		
	TextLabel.Text = Player.Name .. "s Plot"
	
	Bases.Plot_Position_Player(Player)
	Bases.Plot_Lock(Player, false)
end

function Bases.Plot_Assign(Player: Player)
	local availableIndices = {}

	for index, value in PlotTbl do
		if value == "" then
			table.insert(availableIndices, index)
		end
	end

	if #availableIndices == 0 then
		warn("No available plots to assign.")
		return
	end

	local randomIndex = availableIndices[math.random(1, #availableIndices)]
	PlotTbl[randomIndex] = Player
	
	local PlayerReplica = Profiles.GetReplica(Player)
	
	for _, child in PlayerReplica.Data.NPCS do
		child.Base = "Plot"..tostring(Bases.GetIndex(Player))
	end
	
	
end

function Bases.Plot_Reset_Billboards(Player : Player)
	local Player_Plot = Bases.Get_Player_Plot(Player)
	
	Player_Plot.Floor1.Interactables.Sign.Main.SurfaceGui.TextLabel.Text = "Someones Plot"
	Player_Plot.Floor1.Interactables.Lock.BillboardGui.TextLabel.Text = "Lock your base!"
	Player_Plot.Floor2.Interactables.Lock.BillboardGui.TextLabel.Text = "Lock your base!"
end


function Bases.Plot_Remove(Player : Player)
	if LockThreads[Player] then
		task.cancel(LockThreads[Player])
	end
	Bases.Plot_Reset_Billboards(Player)
	Bases.Plot_Lock(Player, true)
	for index, value in PlotTbl do
		if value ~= Player then continue end
		PlotTbl[index] = ""
		break
	end
end

game.Players.PlayerAdded:Connect(function(Player : Player)
	Player:SetAttribute("Locked", false)
	Bases.Plot_Assign(Player)
	print(PlotTbl)
	Bases.Plot_Load_Data(Player)
end)

game.Players.PlayerRemoving:Connect(function(Player : Player)
	Bases.Plot_Remove(Player)
	print(PlotTbl)
end)


return Bases
