--!strict
-- Biomes : zones de découverte compactes autour de la place centrale.
-- Ajouter un biome = ajouter une entrée ici (angle libre), des mèmes qui y sont rattachés
-- et, si besoin, un style de décor dans Services/MapService (sinon décor générique).
-- `angleDeg` : direction depuis la place (90 = nord / -Z).

local rgb = Color3.fromRGB

return {
	Order = { "PrairiePop", "PlageSoda", "ForetNeon" },
	Defs = {
		PrairiePop = {
			displayName = "Prairie Pop",
			description = "Collines douces et fleurs géométriques : parfait pour débuter.",
			angleDeg = 90,
			discoveredByDefault = true,
			decor = "Prairie",
			seed = 11,
			palette = {
				ground = rgb(150, 228, 186),
				rim = rgb(255, 214, 72),
				path = rgb(255, 244, 206),
				accentA = rgb(255, 210, 60),
				accentB = rgb(255, 136, 178),
				accentC = rgb(120, 196, 255),
				detail = rgb(104, 200, 140),
			},
			ambience = { tint = rgb(255, 252, 236), brightness = 0.02, saturation = 0.1, contrast = 0 },
		},
		PlageSoda = {
			displayName = "Plage Soda",
			description = "Sable propre, vagues pétillantes et parasols géants.",
			angleDeg = 210,
			discoveredByDefault = false,
			decor = "Plage",
			seed = 23,
			palette = {
				ground = rgb(255, 236, 200),
				rim = rgb(255, 126, 108),
				path = rgb(255, 250, 240),
				accentA = rgb(255, 120, 100),
				accentB = rgb(52, 206, 210),
				accentC = rgb(255, 255, 255),
				detail = rgb(64, 214, 214),
			},
			ambience = { tint = rgb(236, 255, 252), brightness = 0.03, saturation = 0.12, contrast = 0 },
		},
		ForetNeon = {
			displayName = "Forêt Néon",
			description = "Champignons lumineux et plantes fluo sous un ciel violet.",
			angleDeg = 330,
			discoveredByDefault = false,
			decor = "Foret",
			seed = 37,
			palette = {
				ground = rgb(64, 46, 118),
				rim = rgb(40, 228, 255),
				path = rgb(126, 106, 206),
				accentA = rgb(176, 96, 255),
				accentB = rgb(40, 228, 255),
				accentC = rgb(30, 40, 112),
				detail = rgb(226, 216, 255),
			},
			ambience = { tint = rgb(226, 220, 255), brightness = -0.05, saturation = 0.18, contrast = 0.05 },
		},
	},
}
