--!strict
-- Cosmétiques : thèmes de couleur de base (purement visuels).
-- `floor`/`trim` absents = couleur attribuée à la base.
local rgb = Color3.fromRGB

return {
	Default = "Classic",
	Order = { "Classic", "Bonbon", "Lagon", "Citron", "Minuit" },
	Defs = {
		Classic = {
			displayName = "Classique",
			description = "La couleur d'origine de ta base.",
			price = 0,
		},
		Bonbon = {
			displayName = "Bonbon",
			description = "Rose guimauve et bordures sucrées.",
			price = 400,
			floor = rgb(255, 228, 240),
			trim = rgb(255, 104, 170),
		},
		Lagon = {
			displayName = "Lagon",
			description = "Turquoise frais façon Plage Soda.",
			price = 900,
			floor = rgb(220, 250, 244),
			trim = rgb(28, 186, 186),
		},
		Citron = {
			displayName = "Citron",
			description = "Jaune pétillant, bordures citron vert.",
			price = 1600,
			floor = rgb(252, 255, 214),
			trim = rgb(176, 214, 30),
		},
		Minuit = {
			displayName = "Minuit",
			description = "Bleu nuit et bordures néon qui brillent.",
			price = 3200,
			floor = rgb(40, 40, 82),
			trim = rgb(108, 238, 255),
			neonTrim = true,
		},
	},
}
