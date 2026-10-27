-- Plays the "Idle" animation on every critter tagged AnimatedCritter (wild, carried, in bases).
-- Prototype: the KeyframeSequence inside the model is registered locally (works in Studio).
-- Before launch, upload each Idle and set the model attribute IdleAnimationId instead.

local CollectionService = game:GetService("CollectionService")
local KeyframeSequenceProvider = game:GetService("KeyframeSequenceProvider")

local registered: { [string]: string } = {} -- species -> animation id

local function animationId(model: Model): string?
	local published = model:GetAttribute("IdleAnimationId")
	if typeof(published) == "string" and published ~= "" then
		return published
	end
	local species = model:GetAttribute("Species") or model.Name
	if registered[species] then
		return registered[species]
	end
	local ks = model:FindFirstChild("Idle")
	if not ks or not ks:IsA("KeyframeSequence") then
		return nil
	end
	local ok, id = pcall(function()
		return KeyframeSequenceProvider:RegisterKeyframeSequence(ks)
	end)
	if ok then
		registered[species] = id
		return id
	end
	return nil
end

local function play(model: Instance)
	if not model:IsA("Model") then
		return
	end
	task.wait() -- children may still be streaming in
	local id = animationId(model)
	local ctrl = model:FindFirstChildOfClass("AnimationController")
	if not id or not ctrl then
		return
	end
	local animator = ctrl:FindFirstChildOfClass("Animator") or Instance.new("Animator", ctrl)
	local anim = Instance.new("Animation")
	anim.AnimationId = id
	local ok, track = pcall(function()
		return (animator :: Animator):LoadAnimation(anim)
	end)
	if ok and track then
		track.Looped = true
		-- random start so a group of critters doesn't move in lockstep
		track:Play(0.2)
		track.TimePosition = math.random() * math.max(track.Length, 0.1)
	end
end

CollectionService:GetInstanceAddedSignal("AnimatedCritter"):Connect(play)
for _, m in ipairs(CollectionService:GetTagged("AnimatedCritter")) do
	task.spawn(play, m)
end
