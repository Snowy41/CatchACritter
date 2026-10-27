-- Custom nametags: outlined display name, "@username" below, optional role (icon + label) above
-- (Owner / Admin / Moderator / Tester from shared/Roles) and the equipped title (player attribute
-- "Title", shared/Titles) at the bottom. Replaces Roblox's default name display.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Roles = require(ReplicatedStorage.Shared.Roles)
local Titles = require(ReplicatedStorage.Shared.Titles)

local NametagService = {}
NametagService.Priority = 70

local INK = Color3.fromRGB(20, 14, 36)
local roleCache: { [Player]: Roles.Role? } = {}

local function stroke(parent: Instance, thickness: number, contextual: boolean?)
	local s = Instance.new("UIStroke")
	s.Thickness = thickness
	s.Color = INK
	s.LineJoinMode = Enum.LineJoinMode.Round
	s.ApplyStrokeMode = contextual and Enum.ApplyStrokeMode.Contextual or Enum.ApplyStrokeMode.Border
	s.Parent = parent
end

local function gradient(parent: Instance, top: Color3, bottom: Color3)
	local g = Instance.new("UIGradient")
	g.Rotation = 90
	g.Color = ColorSequence.new(top, bottom)
	g.Parent = parent
end

local function label(parent: Instance, text: string, font: Enum.Font, color: Color3, size: UDim2, pos: UDim2, strokeT: number): TextLabel
	local t = Instance.new("TextLabel")
	t.BackgroundTransparency = 1
	t.Font = font
	t.TextScaled = true
	t.Text = text
	t.TextColor3 = color
	t.Size = size
	t.Position = pos
	t.AnchorPoint = Vector2.new(0.5, 0.5)
	t.ZIndex = 3
	stroke(t, strokeT, true)
	t.Parent = parent
	return t
end

local function build(player: Player, root: BasePart, headHeight: number, role: Roles.Role?)
	local title = Titles[player:GetAttribute("Title") or ""]
	local extra = title and 22 or 0
	local old = root:FindFirstChild("Nametag")
	if old then
		old:Destroy()
	end
	-- Adorned to the HumanoidRootPart (not the Head): the root is never animated, so the tag only
	-- follows real movement and ignores walk bob / idle sway.
	local g = Instance.new("BillboardGui")
	g.Name = "Nametag"
	g.Size = UDim2.fromOffset(230, (role and 84 or 56) + extra)
	g.StudsOffsetWorldSpace = Vector3.new(0, headHeight + 2.3, 0)
	g.MaxDistance = 85
	g.LightInfluence = 0
	g.ResetOnSpawn = false
	g.ClipsDescendants = false
	g.Adornee = root

	-- no panel: outlined text only
	label(g, "@" .. player.Name, Enum.Font.FredokaOne, Color3.fromRGB(225, 218, 255), UDim2.new(1, 0, 0, 18), UDim2.new(0.5, 0, 1, -10 - extra), 2)
	label(g, player.DisplayName, Enum.Font.LuckiestGuy, Color3.new(1, 1, 1), UDim2.new(1, 0, 0, 30), UDim2.new(0.5, 0, 1, -34 - extra), 3)
	if title then
		label(g, title.text, Enum.Font.FredokaOne, title.color, UDim2.new(1, 0, 0, 19), UDim2.new(0.5, 0, 1, -11), 2.2)
	end

	-- role: icon + gradient-coloured outlined text above the name
	if role then
		local row = Instance.new("Frame")
		row.Name = "Role"
		row.BackgroundTransparency = 1
		row.AnchorPoint = Vector2.new(0.5, 0)
		row.Position = UDim2.new(0.5, 0, 0, 0)
		row.Size = UDim2.new(1, 0, 0, 26)
		row.Parent = g
		local layout = Instance.new("UIListLayout")
		layout.FillDirection = Enum.FillDirection.Horizontal
		layout.HorizontalAlignment = Enum.HorizontalAlignment.Center
		layout.VerticalAlignment = Enum.VerticalAlignment.Center
		layout.Padding = UDim.new(0, 3)
		layout.SortOrder = Enum.SortOrder.LayoutOrder
		layout.Parent = row
		if role.icon then
			local icon = Instance.new("ImageLabel")
			icon.BackgroundTransparency = 1
			icon.Image = role.icon
			icon.Size = UDim2.fromOffset(28, 28)
			icon.LayoutOrder = 1
			icon.Parent = row
		end
		local t = Instance.new("TextLabel")
		t.BackgroundTransparency = 1
		t.Font = Enum.Font.LuckiestGuy
		t.Text = role.label
		t.TextSize = 22
		t.AutomaticSize = Enum.AutomaticSize.X
		t.Size = UDim2.fromOffset(0, 22)
		t.TextColor3 = Color3.new(1, 1, 1)
		t.LayoutOrder = 2
		gradient(t, role.top, role.bottom)
		stroke(t, 2.5, true)
		t.Parent = row
	end
	g.Parent = root
end

local function onCharacter(player: Player, character: Model)
	local hum = character:WaitForChild("Humanoid", 10) :: Humanoid?
	local head = character:WaitForChild("Head", 10) :: BasePart?
	local root = character:WaitForChild("HumanoidRootPart", 10) :: BasePart?
	if not hum or not head or not root then
		return
	end
	hum.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
	hum.NameDisplayDistance = 0
	-- top of the head relative to the root, measured in the character's rest pose
	local headHeight = root.CFrame:PointToObjectSpace(head.Position).Y + head.Size.Y / 2
	build(player, root, headHeight, roleCache[player])
end

function NametagService.PlayerAdded(player: Player)
	task.spawn(function()
		roleCache[player] = Roles.of(player) -- may yield (group rank lookup)
		player:SetAttribute("Role", roleCache[player] and (roleCache[player] :: Roles.Role).name or nil)
		if player.Character then
			onCharacter(player, player.Character)
		end
	end)
	player.CharacterAdded:Connect(function(character)
		onCharacter(player, character)
	end)
	player:GetAttributeChangedSignal("Title"):Connect(function()
		if player.Character then
			onCharacter(player, player.Character)
		end
	end)
end

function NametagService.PlayerRemoving(player: Player)
	roleCache[player] = nil
end

return NametagService
