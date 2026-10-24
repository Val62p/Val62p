-- Bandes lumineuses des tapis de course qui défilent, plus vite à chaque niveau (client seulement).
local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local MapLayout = require(ReplicatedStorage.Shared.MapLayout)
local Tags = require(ReplicatedStorage.Shared.Tags)

local TreadmillAnimator = {}

local BELT_LENGTH = 8
local MAX_DISTANCE = 90
local UPDATE_INTERVAL = 1 / 30

type Stripe = { part: BasePart, z0: number }
type Entry = { model: Model, frame: CFrame, stripes: { Stripe } }

local entries: { [Model]: Entry } = {}

local function track(instance: Instance)
	if not instance:IsA("Model") or entries[instance] then
		return
	end
	local baseIndex = instance:GetAttribute("BaseIndex")
	if type(baseIndex) ~= "number" or not MapLayout.base(baseIndex) then
		return
	end
	local stripes = {}
	for _, child in instance:GetChildren() do
		if child:IsA("BasePart") and child.Name == "Stripe" then
			table.insert(stripes, { part = child, z0 = child:GetAttribute("Z0") or 0 })
		end
	end
	entries[instance] = { model = instance, frame = MapLayout.treadmillCFrame(baseIndex), stripes = stripes }
end

-- Position d'une bande : elle recule sous les pieds du coureur et revient au début.
function TreadmillAnimator.stripeZ(z0: number, travelled: number): number
	local half = BELT_LENGTH / 2
	return ((z0 + half - travelled) % BELT_LENGTH) - half
end

function TreadmillAnimator.init()
	for _, model in CollectionService:GetTagged(Tags.Treadmill) do
		track(model)
	end
	CollectionService:GetInstanceAddedSignal(Tags.Treadmill):Connect(track)

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
		local t = os.clock()
		for model, entry in entries do
			if model.Parent and (entry.frame.Position - camera.CFrame.Position).Magnitude <= MAX_DISTANCE then
				local speed = model:GetAttribute("Speed") or 16
				local travelled = t * speed * 0.25
				for _, stripe in entry.stripes do
					stripe.part.CFrame = entry.frame * CFrame.new(0, 0.6, TreadmillAnimator.stripeZ(stripe.z0, travelled))
				end
			end
		end
	end)
end

return TreadmillAnimator
