-- Animations des mèmes (rebond, flottement, dandinement, rotation), uniquement côté client.
-- Coût borné : seuls les mèmes proches de la caméra sont animés, à fréquence limitée.
local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Tags = require(ReplicatedStorage.Shared.Tags)

local MemeAnimator = {}

local MAX_ANIMATED = 24
local MAX_DISTANCE = 110
local UPDATE_INTERVAL = 1 / 30

type Entry = { model: Model, pivot: CFrame, anim: string, phase: number }

local entries: { [Model]: Entry } = {}

local function track(instance: Instance)
	if not instance:IsA("Model") or entries[instance] then
		return
	end
	entries[instance] = {
		model = instance,
		pivot = instance:GetPivot(),
		anim = instance:GetAttribute("Anim") or "Bounce",
		phase = math.random() * math.pi * 2,
	}
end

local function untrack(instance: Instance)
	entries[instance :: Model] = nil
end

local function offset(anim: string, t: number): CFrame
	if anim == "Spin" then
		return CFrame.Angles(0, t * 1.4, 0)
	elseif anim == "Wobble" then
		return CFrame.Angles(0, 0, math.sin(t * 3) * 0.14)
	elseif anim == "Float" then
		return CFrame.new(0, 0.25 + math.sin(t * 2) * 0.25, 0)
	end
	return CFrame.new(0, math.abs(math.sin(t * 3.5)) * 0.45, 0)
end

function MemeAnimator.init()
	for _, model in CollectionService:GetTagged(Tags.MemeVisual) do
		track(model)
	end
	CollectionService:GetInstanceAddedSignal(Tags.MemeVisual):Connect(track)
	CollectionService:GetInstanceRemovedSignal(Tags.MemeVisual):Connect(untrack)

	local accumulator = 0
	RunService.RenderStepped:Connect(function(dt)
		accumulator += dt
		if accumulator < UPDATE_INTERVAL then
			return
		end
		accumulator = 0
		local camera = Workspace.CurrentCamera
		if not camera then
			return
		end
		local origin = camera.CFrame.Position
		local candidates = {}
		for model, entry in entries do
			if model.Parent then
				local distance = (entry.pivot.Position - origin).Magnitude
				if distance <= MAX_DISTANCE then
					table.insert(candidates, { entry = entry, distance = distance })
				end
			end
		end
		table.sort(candidates, function(a, b)
			return a.distance < b.distance
		end)
		local t = os.clock()
		for i = 1, math.min(#candidates, MAX_ANIMATED) do
			local entry = candidates[i].entry
			entry.model:PivotTo(entry.pivot * offset(entry.anim, t + entry.phase))
		end
	end)
end

return MemeAnimator
