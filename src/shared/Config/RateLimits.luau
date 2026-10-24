--!strict
-- Limitation de débit côté serveur (seau à jetons) : capacité + recharge par seconde.
return {
	Global = { capacity = 20, refillPerSecond = 8 },
	Actions = {
		RequestSync = { capacity = 3, refillPerSecond = 0.5 },
		BuyOffer = { capacity = 4, refillPerSecond = 2 },
		BuyUpgrade = { capacity = 4, refillPerSecond = 2 },
		BuyCosmetic = { capacity = 4, refillPerSecond = 2 },
		EquipCosmetic = { capacity = 6, refillPerSecond = 3 },
		PlaceMeme = { capacity = 8, refillPerSecond = 4 },
		StoreMeme = { capacity = 8, refillPerSecond = 4 },
		SellMeme = { capacity = 4, refillPerSecond = 2 },
		StartTheft = { capacity = 3, refillPerSecond = 1 },
		CancelTheft = { capacity = 3, refillPerSecond = 1 },
		ToggleZen = { capacity = 2, refillPerSecond = 0.5 },
		TeleportHome = { capacity = 2, refillPerSecond = 0.5 },
		CompleteTutorial = { capacity = 2, refillPerSecond = 0.2 },
		BuyWithRobux = { capacity = 2, refillPerSecond = 0.5 },
		StudioTool = { capacity = 5, refillPerSecond = 2 },
	},
}
