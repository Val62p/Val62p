-- Aperçu 3D d'un mème dans l'interface (ViewportFrame). `silhouette` masque les mèmes
-- pas encore collectionnés dans l'album.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local MemeAppearance = require(ReplicatedStorage.Shared.MemeAppearance)

local MemePreview = {}

local SILHOUETTE = Color3.fromRGB(70, 62, 98)

function MemePreview.create(parent: Instance, memeId: string, silhouette: boolean?): ViewportFrame
	local viewport = Instance.new("ViewportFrame")
	viewport.Name = "Preview"
	viewport.BackgroundTransparency = 1
	viewport.Size = UDim2.fromScale(1, 1)
	viewport.Ambient = Color3.fromRGB(190, 186, 210)
	viewport.LightColor = Color3.fromRGB(255, 255, 255)
	viewport.LightDirection = Vector3.new(-0.6, -1, 0.8)

	local model = MemeAppearance.build(memeId, CFrame.new())
	if silhouette then
		for _, part in model:GetDescendants() do
			if part:IsA("BasePart") then
				part.Color = SILHOUETTE
				part.Material = Enum.Material.SmoothPlastic
				part.Transparency = 0
			end
		end
	end
	model.Parent = viewport

	local height = model:GetAttribute("Height") or 3
	local target = Vector3.new(0, height * 0.5, 0)
	local distance = height * 2.1 + 1.5
	local camera = Instance.new("Camera")
	camera.FieldOfView = 40
	camera.CFrame = CFrame.lookAt(target + Vector3.new(distance * 0.35, distance * 0.2, -distance), target)
	camera.Parent = viewport
	viewport.CurrentCamera = camera
	viewport.Parent = parent
	return viewport
end

return MemePreview
