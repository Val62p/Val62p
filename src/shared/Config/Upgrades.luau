--!strict
-- Améliorations de base achetées en pièces. Le niveau 1 est le niveau de départ (gratuit).
-- Chaque niveau porte une `value` (effet principal) et un `price` (coût pour l'atteindre).
return {
	Order = { "Slots", "Storage", "Income", "Alarm" },
	Defs = {
		Slots = {
			displayName = "Socles en plus",
			description = "Plus de socles, plus de mèmes qui rapportent.",
			valueFormat = "Count",
			unit = "socles",
			levels = {
				{ value = 4, price = 0 },
				{ value = 5, price = 250 },
				{ value = 6, price = 900 },
				{ value = 7, price = 2600 },
				{ value = 8, price = 6500 },
			},
		},
		Storage = {
			displayName = "Grande réserve",
			description = "Range davantage de mèmes en attente.",
			valueFormat = "Count",
			unit = "places",
			levels = {
				{ value = 6, price = 0 },
				{ value = 9, price = 300 },
				{ value = 12, price = 1200 },
				{ value = 16, price = 4000 },
			},
		},
		Income = {
			displayName = "Néons de production",
			description = "Tous tes mèmes posés rapportent davantage.",
			valueFormat = "Multiplier",
			unit = "",
			levels = {
				{ value = 1, price = 0 },
				{ value = 1.1, price = 600 },
				{ value = 1.25, price = 3000 },
				{ value = 1.5, price = 12000 },
			},
		},
		Alarm = {
			displayName = "Alarme de base",
			description = "Tu rattrapes les voleurs de plus loin et ils crochètent plus lentement.",
			valueFormat = "Radius",
			unit = "studs",
			-- value = rayon d'interception ; lockpickBonus = secondes de crochetage ajoutées.
			levels = {
				{ value = 8, lockpickBonus = 0, price = 0 },
				{ value = 10, lockpickBonus = 0.75, price = 400 },
				{ value = 12, lockpickBonus = 1.5, price = 1500 },
				{ value = 14, lockpickBonus = 2.25, price = 4500 },
			},
		},
	},
}
