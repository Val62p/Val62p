-- Retours visuels d'un vol en cours (côté serveur, visibles par tous) :
-- mème porté au-dessus de la tête du voleur, contour coloré et étiquette.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Catalog = require(ReplicatedStorage.Shared.Catalog)
local MemeAppearance = require(ReplicatedStorage.Shared.MemeAppearance)

local TheftVisuals = {}

export type Handle = { instances: { Instance } }

function TheftVisuals.attach(thief: Player, victim: Player, memeId: string): Handle
	local handle: Handle = { instances = {} }
	local character = thief.Character
	local head = character and character:FindFirstChild("Head")
	if not character or not head or not head:IsA("BasePart") then
		return handle
	end

	local model = MemeAppearance.build(memeId, head.CFrame * CFrame.new(0, head.Size.Y / 2 + 0.6, 0), { anchored = false })
	model.Name = "CarriedMeme"
	local weld = Instance.new("WeldConstraint")
	weld.Part0 = head
	weld.Part1 = model.PrimaryPart
	weld.Parent = model
	model.Parent = character
	table.insert(handle.instances, model)

	local highlight = Instance.new("Highlight")
	highlight.Name = "CarryHighlight"
	highlight.FillColor = Color3.fromRGB(255, 150, 40)
	highlight.FillTransparency = 0.8
	highlight.OutlineColor = Color3.fromRGB(255, 255, 255)
	highlight.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
	highlight.Parent = character
	table.insert(handle.instances, highlight)

	local gui = Instance.new("BillboardGui")
	gui.Name = "CarryLabel"
	gui.Adornee = head
	gui.Size = UDim2.fromOffset(200, 30)
	gui.StudsOffsetWorldSpace = Vector3.new(0, 7, 0)
	gui.MaxDistance = 150
	gui.LightInfluence = 0
	local label = Instance.new("TextLabel")
	label.BackgroundTransparency = 1
	label.Size = UDim2.fromScale(1, 1)
	label.Font = Enum.Font.GothamBold
	label.TextScaled = true
	label.TextColor3 = Color3.fromRGB(255, 255, 255)
	label.TextStrokeTransparency = 0.2
	label.Text = "Emporte " .. Catalog.meme(memeId).name .. " de " .. victim.DisplayName
	label.Parent = gui
	gui.Parent = character
	table.insert(handle.instances, gui)
	return handle
end

function TheftVisuals.detach(handle: Handle?)
	if not handle then
		return
	end
	for _, instance in handle.instances do
		instance:Destroy()
	end
	table.clear(handle.instances)
end

return TheftVisuals
