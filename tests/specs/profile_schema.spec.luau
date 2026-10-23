--!nocheck
-- Chargement, migration et réparation des profils.
local Fakes = require("../lib/Fakes")

return function(T, Loader)
	local clock = Fakes.clock()
	Fakes.installServices(Loader, clock)
	local ProfileSchema = Loader.require("ServerScriptService.Domain.ProfileSchema")
	local Config = Loader.require("ReplicatedStorage.Shared.Config")
	local Status = ProfileSchema.Status

	T.test("nouveau joueur : profil par défaut", function()
		local profile, status = ProfileSchema.load(nil, 5)
		T.eq(status, Status.New)
		T.eq(profile.coins, Config.Economy.StartingCoins)
		T.eq(profile.version, ProfileSchema.CURRENT_VERSION)
		T.truthy(profile.discovered.PrairiePop)
		T.falsy(profile.discovered.PlageSoda)
		T.eq(profile.cosmetics.equipped, "Classic")
	end)

	T.test("profil valide rechargé à l'identique", function()
		local profile = ProfileSchema.default(1)
		profile.coins = 999
		profile.memes.m1 = { id = "Pataplouf", slot = 2 }
		profile.memes.m2 = { id = "HibouWifi" }
		profile.nextUid = 3
		profile.upgrades.Slots = 3
		profile.settings.tutorialDone = true
		local saved = ProfileSchema.serialize(profile)
		local loaded, status, issues = ProfileSchema.load(saved, 2)
		T.eq(status, Status.Ok, table.concat(issues, ","))
		T.eq(loaded.coins, 999)
		T.eq(loaded.memes.m1.slot, 2)
		T.eq(loaded.memes.m2.slot, nil)
		T.eq(loaded.nextUid, 3)
		T.eq(loaded.upgrades.Slots, 3)
		T.truthy(loaded.settings.tutorialDone)
	end)

	T.test("serialize produit une copie indépendante", function()
		local profile = ProfileSchema.default(1)
		local copy = ProfileSchema.serialize(profile)
		copy.coins = 1
		copy.memes.m1 = { id = "Pataplouf" }
		T.eq(profile.coins, Config.Economy.StartingCoins)
		T.eq(profile.memes.m1, nil)
	end)

	T.test("profil invalide : valeurs corrigées, aucun mème valide perdu", function()
		local raw = {
			version = 1,
			coins = -50,
			memes = {
				m1 = { id = "Pataplouf", slot = 1 },
				m2 = { id = "MoutonNuage", slot = 1 }, -- socle en double
				m3 = { id = "MemeInconnu" },
				m4 = { id = "PinceMoi", slot = 99 }, -- socle impossible
				["bad key"] = { id = "ChampiChill" }, -- identifiant illisible
				m5 = "pas une table",
			},
			nextUid = -3,
			upgrades = { Slots = 99, Storage = 2.5, Income = 2 },
			cosmetics = { owned = { Bonbon = true, Inexistant = true }, equipped = "Inexistant" },
			discovered = { PlageSoda = true, Atlantide = true },
			settings = { tutorialDone = "oui" },
			stats = { bought = -1, stolen = 4 },
		}
		local profile, status, issues = ProfileSchema.load(raw, 0)
		T.eq(status, Status.Repaired)
		T.truthy(#issues > 0)
		T.eq(profile.coins, 0, "pièces bornées")
		T.eq(profile.upgrades.Slots, 1, "niveau impossible ignoré")
		T.eq(profile.upgrades.Storage, 1)
		T.eq(profile.upgrades.Income, 2)
		T.eq(profile.memes.m1.slot, 1)
		T.eq(profile.memes.m2.slot, nil, "doublon renvoyé en réserve")
		T.eq(profile.memes.m4.slot, nil, "socle impossible renvoyé en réserve")
		T.eq(profile.memes.m3, nil, "mème inconnu retiré")
		local champi = 0
		for _, entry in profile.memes do
			if entry.id == "ChampiChill" then
				champi += 1
			end
		end
		T.eq(champi, 1, "mème à identifiant illisible conservé")
		T.truthy(profile.nextUid > 5, "nextUid au-delà des identifiants existants")
		T.truthy(profile.cosmetics.owned.Bonbon)
		T.eq(profile.cosmetics.owned.Inexistant, nil)
		T.eq(profile.cosmetics.equipped, "Classic")
		T.truthy(profile.discovered.PlageSoda)
		T.eq(profile.discovered.Atlantide, nil)
		T.eq(profile.settings.tutorialDone, false)
		T.eq(profile.stats.bought, 0)
		T.eq(profile.stats.stolen, 4)
	end)

	T.test("racine illisible : profil neuf marqué réparé", function()
		local profile, status, issues = ProfileSchema.load("garbage", 0)
		T.eq(status, Status.Repaired)
		T.eq(profile.coins, Config.Economy.StartingCoins)
		T.truthy(string.find(issues[1], "invalid_root"))
	end)

	T.test("ancienne version (sans champ version) migrée", function()
		local raw = { Coins = 321, Memes = { "Pataplouf", "Inconnu", "HibouWifi" } }
		local profile, status = ProfileSchema.load(raw, 0)
		T.eq(status, Status.Migrated)
		T.eq(profile.version, ProfileSchema.CURRENT_VERSION)
		T.eq(profile.coins, 321)
		T.eq(profile.memes.m1.id, "Pataplouf")
		T.eq(profile.memes.m3.id, "HibouWifi")
		T.eq(profile.memes.m2, nil)
		T.eq(profile.nextUid, 4)
	end)

	T.test("version future : lecture seule", function()
		local raw = ProfileSchema.serialize(ProfileSchema.default(0))
		raw.version = ProfileSchema.CURRENT_VERSION + 1
		raw.coins = 77
		local profile, status = ProfileSchema.load(raw, 0)
		T.eq(status, Status.FromFuture)
		T.eq(profile.coins, 77)
	end)
end
