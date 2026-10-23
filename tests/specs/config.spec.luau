--!nocheck
-- Cohérence de la configuration (source unique de vérité).
local Fakes = require("../lib/Fakes")

return function(T, Loader)
	local clock = Fakes.clock()
	Fakes.installServices(Loader, clock)
	local Config = Loader.require("ReplicatedStorage.Shared.Config")
	local Catalog = Loader.require("ReplicatedStorage.Shared.Catalog")
	local MapLayout = Loader.require("ReplicatedStorage.Shared.MapLayout")

	T.test("la configuration est gelée", function()
		T.truthy(table.isfrozen(Config), "Config")
		T.truthy(table.isfrozen(Config.Memes.Defs.Pataplouf), "définition de mème")
		T.falsy(pcall(function()
			Config.Economy.StartingCoins = 1e9
		end), "écriture refusée")
	end)

	T.test("chaque mème a un biome, une rareté, un prix et un revenu valides", function()
		local seen = {}
		for _, memeId in Config.Memes.Order do
			T.falsy(seen[memeId], "doublon " .. memeId)
			seen[memeId] = true
			local def = Config.Memes.Defs[memeId]
			T.truthy(def, "définition " .. memeId)
			T.truthy(Config.Biomes.Defs[def.biome], "biome de " .. memeId)
			T.truthy(Config.Rarities.Defs[def.rarity], "rareté de " .. memeId)
			T.truthy(def.price > 0 and def.price % 1 == 0, "prix entier de " .. memeId)
			T.truthy(def.income > 0 and def.income % 1 == 0, "revenu entier de " .. memeId)
			T.truthy(#def.name > 0 and #def.tagline > 0, "textes de " .. memeId)
		end
		for memeId in Config.Memes.Defs do
			T.truthy(seen[memeId], memeId .. " absent de l'ordre")
		end
	end)

	T.test("chaque biome propose au moins un mème commun abordable au départ", function()
		for _, biomeId in Config.Biomes.Order do
			local cheapest = math.huge
			local hasCommon = false
			for _, memeId in Catalog.memesInBiome(biomeId) do
				local def = Config.Memes.Defs[memeId]
				cheapest = math.min(cheapest, def.price)
				hasCommon = hasCommon or def.rarity == "Common"
			end
			T.truthy(hasCommon, "commun dans " .. biomeId)
			T.truthy(cheapest <= Config.Economy.StartingCoins, "abordable dans " .. biomeId)
		end
	end)

	T.test("les raretés supérieures rapportent plus par pièce dépensée… mais coûtent plus", function()
		local order = {}
		for index, rarityId in Config.Rarities.Order do
			order[rarityId] = index
		end
		for _, a in Config.Memes.Order do
			for _, b in Config.Memes.Order do
				local da, db = Config.Memes.Defs[a], Config.Memes.Defs[b]
				if order[da.rarity] < order[db.rarity] then
					T.truthy(da.price < db.price, a .. " moins cher que " .. b)
					T.truthy(da.income < db.income, a .. " rapporte moins que " .. b)
				end
			end
		end
	end)

	T.test("améliorations : niveaux croissants, niveau 1 gratuit", function()
		for _, upgradeId in Config.Upgrades.Order do
			local levels = Config.Upgrades.Defs[upgradeId].levels
			T.eq(levels[1].price, 0, upgradeId .. " niveau 1")
			for i = 2, #levels do
				T.truthy(levels[i].price > levels[i - 1].price, upgradeId .. " prix croissant")
				T.truthy(levels[i].value > levels[i - 1].value, upgradeId .. " effet croissant")
			end
		end
		local maxSlots = Config.Upgrades.Defs.Slots.levels
		T.truthy(maxSlots[#maxSlots].value <= MapLayout.maxSlots(), "socles physiques suffisants")
	end)

	T.test("cosmétiques : le défaut est gratuit et existe", function()
		T.eq(Config.Cosmetics.Defs[Config.Cosmetics.Default].price, 0)
	end)

	T.test("monétisation Robux désactivée, aucun produit inventé", function()
		T.eq(Config.Monetization.Enabled, false)
		T.eq(next(Config.Monetization.DeveloperProducts), nil)
		T.eq(next(Config.Monetization.GamePasses), nil)
	end)

	T.test("chaque action réseau a une limite de débit et chaque code un message", function()
		local Net = Loader.require("ReplicatedStorage.Shared.Net")
		for action in Net.Actions do
			T.truthy(Config.RateLimits.Actions[action], "limite pour " .. action)
		end
		for code in Net.Codes do
			T.truthy(Net.Messages[code], "message pour " .. code)
		end
		T.eq(Net.message("NotEnoughCoins", { missing = 40 }), "Il te manque 40 pièces.")
	end)
end
