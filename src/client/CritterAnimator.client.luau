-- Plays animations on every model tagged AnimatedCritter (wild/carried/base critters, guardians).
-- The model attribute "Anim" names the KeyframeSequence to play (default "Idle"); changing it
-- switches the animation (guardians: Sleep / Alert / Chase). "AnimSpeed" scales playback.
-- Prototype: KeyframeSequences are registered locally (works in Studio). Before launch, upload
-- them and set attributes like "IdleAnimationId" / "SleepAnimationId" instead.

local CollectionService = game:GetService("CollectionService")
local KeyframeSequenceProvider = game:GetService("KeyframeSequenceProvider")

local registered: { [string]: string } = {} -- "Species/AnimName" -> animation id

local function animationId(model: Model, animName: string): string?
	local published = model:GetAttribute(animName .. "AnimationId")
	if typeof(published) == "string" and published ~= "" then
		return published
	end
	local key = tostring(model:GetAttribute("Species") or model.Name) .. "/" .. animName
	if registered[key] then
		return registered[key]
	end
	local ks = model:FindFirstChild(animName)
	if not ks or not ks:IsA("KeyframeSequence") then
		return nil
	end
	local ok, id = pcall(function()
		return KeyframeSequenceProvider:RegisterKeyframeSequence(ks)
	end)
	if ok then
		registered[key] = id
		return id
	end
	return nil
end

local function setup(model: Instance)
	if not model:IsA("Model") then
		return
	end
	task.wait() -- children may still be streaming in
	local ctrl = model:FindFirstChildOfClass("AnimationController")
	if not ctrl then
		return
	end
	local animator = ctrl:FindFirstChildOfClass("Animator") or Instance.new("Animator", ctrl)
	local tracks: { [string]: AnimationTrack } = {}
	local current: AnimationTrack? = nil

	local function play()
		local name = model:GetAttribute("Anim") or "Idle"
		local track = tracks[name]
		if not track then
			local id = animationId(model, name)
			if not id then
				return
			end
			local anim = Instance.new("Animation")
			anim.AnimationId = id
			local ok, t = pcall(function()
				return (animator :: Animator):LoadAnimation(anim)
			end)
			if not ok or not t then
				return
			end
			track = t
			track.Looped = true
			tracks[name] = track
		end
		if current ~= track then
			if current then
				current:Stop(0.3)
			end
			track:Play(0.3)
			if name == "Idle" then
				-- random start so a group of critters doesn't move in lockstep
				track.TimePosition = math.random() * math.max(track.Length, 0.1)
			end
			current = track
		end
		track:AdjustSpeed(model:GetAttribute("AnimSpeed") or 1)
	end

	model:GetAttributeChangedSignal("Anim"):Connect(play)
	model:GetAttributeChangedSignal("AnimSpeed"):Connect(play)
	play()
end

CollectionService:GetInstanceAddedSignal("AnimatedCritter"):Connect(setup)
for _, m in ipairs(CollectionService:GetTagged("AnimatedCritter")) do
	task.spawn(setup, m)
end
