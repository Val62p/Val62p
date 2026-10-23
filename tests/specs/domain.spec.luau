--!nocheck
-- Règles pures : validation, débit, économie, inventaire, revenus, kiosques.
local Fakes = require("../lib/Fakes")

return function(T, Loader)
	local clock = Fakes.clock()
	Fakes.installServices(Loader, clock)
	local Validate = Loader.require("ServerScriptService.Domain.Validate")
	local RateLimiter = Loader.require("ServerScriptService.Domain.RateLimiter")
	local Economy = Loader.require("ServerScriptService.Domain.Economy")
	local Inventory = Loader.require("ServerScriptService.Domain.Inventory")
	local Income = Loader.require("ServerScriptService.Domain.Income")
	local Progression = Loader.require("ServerScriptService.Domain.Progression")
	local ProfileSchema = Loader.require("ServerScriptService.Domain.ProfileSchema")
	local KioskRotation = Loader.require("ServerScriptService.Domain.KioskRotation")
	local SeededRandom = Loader.require("ReplicatedStorage.Shared.SeededRandom")
	local Config = Loader.require("ReplicatedStorage.Shared.Config")
	local Format = Loader.require("ReplicatedStorage.Shared.Format")

	T.test("Validate refuse les valeurs falsifiées", function()
		T.truthy(Validate.isInteger(3, 1, 8))
		T.falsy(Validate.isInteger(3.5, 1, 8), "décimal")
		T.falsy(Validate.isInteger(0 / 0, 1, 8), "NaN")
		T.falsy(Validate.isInteger(math.huge, 1, math.huge), "infini")
		T.falsy(Validate.isInteger("3", 1, 8), "chaîne")
		T.falsy(Validate.isInteger(9, 1, 8), "hors bornes")
		T.truthy(Validate.isId("PrairiePop"))
		T.falsy(Validate.isId("Prairie Pop"), "espace")
		T.falsy(Validate.isId(string.rep("a", 100)), "trop long")
		T.falsy(Validate.isId({}), "table")
		T.truthy(Validate.isKeyOf("Slots", Config.Upgrades.Defs))
		T.falsy(Validate.isKeyOf("__index", Config.Upgrades.Defs), "clé spéciale")
		T.truthy(Validate.isMemeUid("m12"))
		T.falsy(Validate.isMemeUid("m12; drop"), "injection")
		T.falsy(Validate.isMemeUid(12), "nombre")
	end)

	T.test("RateLimiter bloque le spam puis se recharge", function()
		local limiter = RateLimiter.new(clock.get)
		local allowed = 0
		for _ = 1, 10 do
			if limiter:allow(1, "Buy", 3, 1) then
				allowed += 1
			end
		end
		T.eq(allowed, 3, "rafale")
		clock.advance(1)
		T.truthy(limiter:allow(1, "Buy", 3, 1), "recharge")
		T.falsy(limiter:allow(1, "Buy", 3, 1), "un seul jeton rechargé")
		T.truthy(limiter:allow(2, "Buy", 3, 1), "autre joueur indépendant")
	end)

	T.test("Economy : jamais négatif, entiers, plafond", function()
		local profile = ProfileSchema.default(0)
		profile.coins = 100
		T.falsy(Economy.spend(profile, 150), "fonds insuffisants")
		T.eq(profile.coins, 100)
		T.eq(Economy.missing(profile, 150), 50)
		T.truthy(Economy.spend(profile, 60))
		T.eq(profile.coins, 40)
		T.eq(Economy.grant(profile, 0 / 0), 0, "NaN ignoré")
		T.eq(Economy.grant(profile, -50), 0, "négatif ignoré")
		profile.coins = Config.Economy.MaxCoins - 1
		T.eq(Economy.grant(profile, 10), 1, "plafond")
	end)

	T.test("Inventory : ajout en réserve, placement, socles occupés et verrouillés", function()
		local profile = ProfileSchema.default(0)
		local ok, code, uid = Inventory.add(profile, "Pataplouf", false)
		T.truthy(ok, code)
		T.eq(profile.memes[uid].slot, nil, "en réserve")
		T.truthy(profile.album.Pataplouf, "album")
		local placed, _, slot = Inventory.place(profile, uid, nil)
		T.truthy(placed)
		T.eq(slot, 1)
		local again, againCode = Inventory.place(profile, uid, 2)
		T.falsy(again)
		T.eq(againCode, "AlreadyPlaced")
		local _, _, uid2 = Inventory.add(profile, "PinceMoi", false)
		local okOccupied, occupiedCode = Inventory.place(profile, uid2, 1)
		T.falsy(okOccupied)
		T.eq(occupiedCode, "SlotOccupied")
		local okLocked, lockedCode = Inventory.place(profile, uid2, 7)
		T.falsy(okLocked)
		T.eq(lockedCode, "SlotLocked")
		local okUnknown, unknownCode = Inventory.place(profile, "m999", 2)
		T.falsy(okUnknown)
		T.eq(unknownCode, "MemeNotFound")
		local okStore, _, storedUid = Inventory.store(profile, 1)
		T.truthy(okStore)
		T.eq(storedUid, uid)
		local okEmpty, emptyCode = Inventory.store(profile, 1)
		T.falsy(okEmpty)
		T.eq(emptyCode, "SlotEmpty")
	end)

	T.test("Inventory : capacité pleine = refus, jamais de perte", function()
		local profile = ProfileSchema.default(0)
		local slots = Progression.slotCapacity(profile)
		local storage = Progression.storageCapacity(profile)
		for _ = 1, slots + storage do
			local ok = Inventory.add(profile, "Pataplouf", true)
			T.truthy(ok)
		end
		local placed, stored = Inventory.counts(profile)
		T.eq(placed, slots)
		T.eq(stored, storage)
		local ok, code = Inventory.add(profile, "Pataplouf", true)
		T.falsy(ok)
		T.eq(code, "InventoryFull")
		local okStore, storeCode = Inventory.store(profile, 1)
		T.falsy(okStore, "réserve pleine")
		T.eq(storeCode, "StorageFull")
		local okPlace, placeCode = Inventory.place(profile, Inventory.sortedUids(profile)[#Inventory.sortedUids(profile)], nil)
		T.falsy(okPlace)
		T.eq(placeCode, "NoFreeSlot")
	end)

	T.test("Inventory : réserve pleine ⇒ achat posé sur un socle libre", function()
		local profile = ProfileSchema.default(0)
		for _ = 1, Progression.storageCapacity(profile) do
			Inventory.add(profile, "Pataplouf", false)
		end
		local ok, _, _, slot = Inventory.add(profile, "Pataplouf", false)
		T.truthy(ok)
		T.eq(slot, 1)
	end)

	T.test("Income : seuls les mèmes posés et non verrouillés rapportent", function()
		local profile = ProfileSchema.default(0)
		local _, _, a = Inventory.add(profile, "Pataplouf", true) -- 3
		local _, _, b = Inventory.add(profile, "MoutonNuage", true) -- 4
		Inventory.add(profile, "PinceMoi", false) -- en réserve
		T.eq(Income.perTick(profile), 7)
		T.eq(Income.perTick(profile, function(uid)
			return uid == b
		end), 3, "mème en cours de vol")
		profile.upgrades.Income = 4 -- ×1,5
		T.eq(Income.perTick(profile), 10, "multiplicateur arrondi à l'entier inférieur")
		T.truthy(a)
	end)

	T.test("KioskRotation : un commun d'abord, sans doublon, déterministe", function()
		for _, biomeId in Config.Biomes.Order do
			local rng = SeededRandom.new(42)
			for _ = 1, 200 do
				local offers = KioskRotation.pick(biomeId, Config.Map.Kiosk.Pedestals, function()
					return rng:nextNumber()
				end)
				T.eq(#offers, Config.Map.Kiosk.Pedestals, "nombre d'offres")
				T.eq(Config.Memes.Defs[offers[1]].rarity, "Common", "premier piédestal commun")
				local seen = {}
				for _, memeId in offers do
					T.falsy(seen[memeId], "doublon")
					seen[memeId] = true
					T.eq(Config.Memes.Defs[memeId].biome, biomeId)
				end
			end
		end
		local function run(seed)
			local rng = SeededRandom.new(seed)
			return table.concat(KioskRotation.pick("PlageSoda", 3, function()
				return rng:nextNumber()
			end), ",")
		end
		T.eq(run(7), run(7), "même graine, même résultat")
	end)

	T.test("SeededRandom reste dans ses bornes", function()
		local rng = SeededRandom.new(1)
		for _ = 1, 1000 do
			local n = rng:nextNumber(2, 5)
			T.truthy(n >= 2 and n < 5)
			local i = rng:nextInteger(1, 3)
			T.truthy(i >= 1 and i <= 3 and i % 1 == 0)
		end
	end)

	T.test("Format", function()
		T.eq(Format.coins(1234567), "1,2 M")
		T.eq(Format.coins(12345), "12\u{202F}345")
		T.eq(Format.coins(-5), "0")
		T.eq(Format.duration(125), "2:05")
		T.eq(Format.multiplier(1.25), "×1,25")
		T.eq(Format.multiplier(1.5), "×1,5")
		T.eq(Format.multiplier(1), "×1")
	end)
end
