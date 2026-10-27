-- Assigns one base plot per player, shows the owner on the gate sign, and spawns the player in it.

local CollectionService = game:GetService("CollectionService")

local PlotService = {}

local plots: { Model } = {}
local owner: { [Model]: Player } = {}
local plotOf: { [Player]: Model } = {}

function PlotService.init()
	for _, m in ipairs(CollectionService:GetTagged("BasePlot")) do
		table.insert(plots, m)
	end
	table.sort(plots, function(a, b)
		return (a:GetAttribute("PlotId") or 0) < (b:GetAttribute("PlotId") or 0)
	end)
end

local function setSign(plot: Model, text: string)
	local label = plot:FindFirstChild("OwnerName", true)
	if label and label:IsA("TextLabel") then
		label.Text = text
	end
end

function PlotService.assign(player: Player): Model?
	for _, plot in ipairs(plots) do
		if not owner[plot] then
			owner[plot] = player
			plotOf[player] = plot
			plot:SetAttribute("OwnerUserId", player.UserId)
			player:SetAttribute("PlotId", plot:GetAttribute("PlotId"))
			setSign(plot, player.DisplayName .. "'s Base")
			return plot
		end
	end
	warn("[PlotService] no free plot for " .. player.Name)
	return nil
end

function PlotService.release(player: Player)
	local plot = plotOf[player]
	if not plot then
		return
	end
	owner[plot] = nil
	plotOf[player] = nil
	plot:SetAttribute("OwnerUserId", nil)
	setSign(plot, "Empty Base")
end

function PlotService.getPlot(player: Player): Model?
	return plotOf[player]
end

function PlotService.getOwner(plot: Model): Player?
	return owner[plot]
end

-- Spawn point: inside the plot in front of the pedestals, facing the gate / avenue.
function PlotService.spawnCFrame(plot: Model): CFrame
	local floor = plot:FindFirstChild("Floor") :: BasePart
	return floor.CFrame * CFrame.new(0, 4, -13)
end

-- Is a world position inside this plot's fence?
function PlotService.isInside(plot: Model, position: Vector3): boolean
	local floor = plot:FindFirstChild("Floor") :: BasePart
	local p = floor.CFrame:PointToObjectSpace(position)
	return math.abs(p.X) < 24 and math.abs(p.Z) < 24 and p.Y > -3 and p.Y < 25
end

function PlotService.slot(plot: Model, index: number): BasePart?
	local slots = plot:FindFirstChild("Slots")
	return slots and slots:FindFirstChild("Slot" .. index) :: BasePart?
end

function PlotService.spawnCharacter(player: Player, character: Model)
	local plot = plotOf[player]
	if not plot then
		return
	end
	local hrp = character:WaitForChild("HumanoidRootPart", 10)
	if not hrp then
		return
	end
	task.wait() -- let the default spawn finish first
	character:PivotTo(PlotService.spawnCFrame(plot))
end

return PlotService
