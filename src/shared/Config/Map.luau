--!strict
-- Dimensions de la carte compacte (en studs). Toutes les positions dérivent de ces valeurs
-- via Shared/MapLayout.
local rgb = Color3.fromRGB

return {
	GroundRadius = 270,
	GroundColor = rgb(204, 208, 238),
	GroundTopY = 0,

	PlazaRadius = 44,
	PlazaTopY = 0.8,
	-- Zone surveillée (détection) au cœur de la place.
	SafeZoneRadius = 24,
	PlazaColors = {
		outer = rgb(255, 250, 240),
		inner = rgb(255, 236, 214),
		safeRing = rgb(255, 196, 40),
		fountain = rgb(255, 255, 255),
		water = rgb(84, 210, 255),
	},

	BiomeDistance = 155,
	BiomeRadius = 85,
	BiomeTopY = 0.6,
	PathWidth = 16,
	PathTopY = 0.7,

	BasesPerBiome = 2,
	Base = {
		Size = 36,
		FloorThickness = 0.8,
		CurbHeight = 1.6,
		RadialOffset = -22, -- vers la place
		TangentOffset = 44, -- de part et d'autre du chemin
		SlotColumns = 4,
		SlotRows = 2,
		SlotSpacing = 8,
		RowZ = { 1, 10 }, -- profondeur des rangées (local, l'entrée est en -Z)
		PadDiameter = 6,
		PadHeight = 0.4,
	},
	-- Couleur « Classique » de chaque base (dans l'ordre des bases).
	BaseColors = {
		rgb(255, 120, 120),
		rgb(255, 176, 64),
		rgb(84, 176, 255),
		rgb(44, 200, 190),
		rgb(176, 120, 255),
		rgb(255, 120, 200),
	},

	Kiosk = {
		RadialOffset = 38,
		Pedestals = 3,
		PedestalSpacing = 10,
		PedestalHeight = 3,
		RotationSeconds = 120,
		BuyRange = 16,
	},

	SpawnRadius = 16,
	SpawnCount = 4,
}
