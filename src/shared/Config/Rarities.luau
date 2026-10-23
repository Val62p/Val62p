--!strict
-- Les raretés sont des catégories de collection : elles influencent l'apparence,
-- la taille et la fréquence d'apparition dans les kiosques (gratuits à consulter).
-- Aucun tirage aléatoire payant n'existe dans le jeu.
return {
	Order = { "Common", "Rare", "Epic", "Legendary" },
	Defs = {
		Common = {
			displayName = "Commun",
			color = Color3.fromRGB(94, 186, 120),
			scale = 1,
			kioskWeight = 60,
		},
		Rare = {
			displayName = "Rare",
			color = Color3.fromRGB(52, 148, 240),
			scale = 1.15,
			kioskWeight = 28,
		},
		Epic = {
			displayName = "Épique",
			color = Color3.fromRGB(160, 86, 240),
			scale = 1.3,
			kioskWeight = 10,
		},
		Legendary = {
			displayName = "Légendaire",
			color = Color3.fromRGB(240, 170, 20),
			scale = 1.5,
			kioskWeight = 3,
		},
	},
}
