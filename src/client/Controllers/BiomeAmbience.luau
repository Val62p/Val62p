-- Ambiance locale par biome (teinte douce) et titre du lieu quand on y entre.
local Lighting = game:GetService("Lighting")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Config = require(ReplicatedStorage.Shared.Config)
local MapLayout = require(ReplicatedStorage.Shared.MapLayout)
local Client = script.Parent.Parent
local Theme = require(Client.Ui.Theme)
local Ui = require(Client.Ui.Ui)

local localPlayer = Players.LocalPlayer

local BiomeAmbience = {}

local NEUTRAL = { tint = Color3.fromRGB(255, 255, 255), brightness = 0, saturation = 0.05, contrast = 0 }

function BiomeAmbience.init(root: ScreenGui)
	local correction = Instance.new("ColorCorrectionEffect")
	correction.Name = "SAM_BiomeAmbience"
	correction.Parent = Lighting

	local title = Ui.text(root, {
		Name = "PlaceTitle",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.32),
		Size = UDim2.fromOffset(500, 50),
		Font = Theme.Fonts.Title,
		TextSize = 40,
		TextColor3 = Theme.Colors.White,
		TextStrokeTransparency = 0.3,
		TextStrokeColor3 = Theme.Colors.Ink,
		TextXAlignment = Enum.TextXAlignment.Center,
		TextTransparency = 1,
	})

	local current: string? = "none"
	local function apply(biomeId: string?)
		local ambience = if biomeId then Config.Biomes.Defs[biomeId].ambience else NEUTRAL
		TweenService:Create(correction, TweenInfo.new(1.2), {
			TintColor = ambience.tint,
			Brightness = ambience.brightness,
			Saturation = ambience.saturation,
			Contrast = ambience.contrast,
		}):Play()
		local text = if biomeId then Config.Biomes.Defs[biomeId].displayName else "Place centrale"
		title.Text = text
		title.TextTransparency = 0
		title.TextStrokeTransparency = 0.3
		TweenService:Create(title, TweenInfo.new(2.5, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
			TextTransparency = 1,
			TextStrokeTransparency = 1,
		}):Play()
	end

	task.spawn(function()
		while true do
			task.wait(0.5)
			local character = localPlayer.Character
			local rootPart = character and character:FindFirstChild("HumanoidRootPart")
			if rootPart and rootPart:IsA("BasePart") then
				local biomeId = MapLayout.biomeAt(rootPart.Position)
				local place = biomeId or (if MapLayout.isOnPlaza(rootPart.Position) then "plaza" else current)
				if place ~= current then
					current = place
					apply(biomeId)
				end
			end
		end
	end)
end

return BiomeAmbience
