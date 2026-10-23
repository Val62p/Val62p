--!nocheck
-- Persistance : verrou de session, erreurs DataStore, reconnexion, versions.
local Fakes = require("../lib/Fakes")
local World = require("../lib/World")

return function(T, Loader)
	local function service(store, jobId, clock)
		Fakes.installServices(Loader, clock)
		local ProfileService = Loader.require("ServerScriptService.Services.ProfileService")
		local logs = {}
		local delayed = {}
		local svc = ProfileService.new({
			store = store,
			jobId = jobId,
			wallClock = clock.get,
			wait = function(seconds)
				clock.advance(seconds)
			end,
			delay = function(_, fn)
				table.insert(delayed, fn)
			end,
			log = function(...)
				table.insert(logs, table.concat({ ... }, " "))
			end,
			isInGame = function(player)
				return player.Parent ~= nil
			end,
		})
		return svc, logs, delayed
	end

	T.test("nouveau joueur : profil créé, sauvegardé au départ, rechargé à la reconnexion", function()
		local clock = Fakes.clock()
		local store = Fakes.dataStore()
		local svc = service(store, "A", clock)
		local player = Fakes.player()
		local record = svc:loadAsync(player)
		T.eq(record.status, "New")
		T.truthy(record.canSave)
		record.profile.coins = 4242
		svc:markDirty(player)
		svc:saveAndReleaseAsync(player)
		local saved = store.data["player_" .. player.UserId]
		T.eq(saved.data.coins, 4242)
		T.eq(saved.lock, nil, "verrou libéré au départ")
		T.eq(svc:get(player), nil, "profil déchargé")

		local again = svc:loadAsync(player)
		T.eq(again.status, "Ok")
		T.eq(again.profile.coins, 4242, "progression retrouvée")
	end)

	T.test("erreur DataStore temporaire : nouvel essai réussi", function()
		local clock = Fakes.clock()
		local store = Fakes.dataStore()
		store.data.player_1 = { data = { version = 1, coins = 900 } }
		local svc, logs = service(store, "A", clock)
		local player = Fakes.player()
		player.UserId = 1
		store.failNext = 2
		local record = svc:loadAsync(player)
		T.eq(record.profile.coins, 900)
		T.truthy(record.canSave)
		T.truthy(#logs >= 2, "erreurs journalisées")
	end)

	T.test("DataStore en panne : profil temporaire, le vrai profil n'est jamais écrasé", function()
		local clock = Fakes.clock()
		local store = Fakes.dataStore()
		store.data.player_2 = { data = { version = 1, coins = 5000 } }
		local svc = service(store, "A", clock)
		local player = Fakes.player()
		player.UserId = 2
		store.failNext = 100
		local record = svc:loadAsync(player)
		T.eq(record.status, "Unavailable")
		T.falsy(record.canSave)
		T.eq(record.profile.coins, 150, "profil de dépannage")
		store.failNext = 0
		record.profile.coins = 1
		svc:markDirty(player)
		svc:autosave()
		svc:saveAndReleaseAsync(player)
		T.eq(store.data.player_2.data.coins, 5000, "données réelles intactes")
	end)

	T.test("pas de DataStore (Studio sans accès API) : jeu possible, rien n'est écrit", function()
		local clock = Fakes.clock()
		local svc = service(nil, "A", clock)
		local player = Fakes.player()
		local record = svc:loadAsync(player)
		T.eq(record.status, "Unavailable")
		T.falsy(svc:saveAsync(record, true))
	end)

	T.test("profil verrouillé par un autre serveur : attente puis reprise du verrou", function()
		local clock = Fakes.clock()
		local store = Fakes.dataStore()
		local svcA = service(store, "A", clock)
		local svcB = service(store, "B", clock)
		local player = Fakes.player()
		local recordA = svcA:loadAsync(player)
		recordA.profile.coins = 777
		svcA:markDirty(player)
		svcA:saveAsync(recordA, false) -- A garde le verrou (serveur figé, par exemple)

		local recordB = svcB:loadAsync(player)
		T.eq(recordB.profile.coins, 777, "B lit la dernière sauvegarde")
		T.eq(store.data["player_" .. player.UserId].lock.job, "B", "B a repris le verrou")

		-- A ne peut plus écraser les données de B.
		recordA.profile.coins = 1
		svcA:markDirty(player)
		T.falsy(svcA:saveAsync(recordA, false), "sauvegarde de A refusée")
		T.falsy(recordA.canSave)
		T.eq(store.data["player_" .. player.UserId].data.coins, 777)
	end)

	T.test("verrou libéré par l'autre serveur pendant l'attente", function()
		local clock = Fakes.clock()
		local store = Fakes.dataStore()
		local player = Fakes.player()
		store.data["player_" .. player.UserId] = { data = { version = 1, coins = 10 }, lock = { job = "Z", at = clock.get() } }
		local releaseAfter = 2
		local original = store.UpdateAsync
		function store:UpdateAsync(key, transform)
			releaseAfter -= 1
			if releaseAfter <= 0 and self.data[key].lock and self.data[key].lock.job == "Z" then
				self.data[key].lock = nil
			end
			return original(self, key, transform)
		end
		local svc = service(store, "A", clock)
		local record = svc:loadAsync(player)
		T.eq(record.profile.coins, 10)
		T.eq(store.data["player_" .. player.UserId].lock.job, "A")
	end)

	T.test("ancienne version migrée puis réécrite au format courant", function()
		local clock = Fakes.clock()
		local store = Fakes.dataStore()
		local player = Fakes.player()
		store.data["player_" .. player.UserId] = { Coins = 64, Memes = { "Pataplouf" } } -- prototype sans enveloppe
		local svc = service(store, "A", clock)
		local record = svc:loadAsync(player)
		T.eq(record.status, "Migrated")
		T.eq(record.profile.coins, 64)
		T.eq(record.profile.memes.m1.id, "Pataplouf")
		T.truthy(svc:isDirty(record), "à réécrire")
		svc:autosave()
		local saved = store.data["player_" .. player.UserId]
		T.eq(saved.data.version, 1)
		T.eq(saved.data.memes.m1.id, "Pataplouf")
	end)

	T.test("données d'une version future : lecture seule", function()
		local clock = Fakes.clock()
		local store = Fakes.dataStore()
		local player = Fakes.player()
		store.data["player_" .. player.UserId] = { data = { version = 99, coins = 123, futureField = true } }
		local svc = service(store, "A", clock)
		local record = svc:loadAsync(player)
		T.eq(record.status, "FromFuture")
		T.falsy(record.canSave)
		record.profile.coins = 0
		svc:markDirty(player)
		svc:saveAndReleaseAsync(player)
		local saved = store.data["player_" .. player.UserId]
		T.eq(saved.data.coins, 123, "données futures intactes")
		T.truthy(saved.data.futureField)
		T.eq(saved.lock, nil, "verrou libéré quand même")
	end)

	T.test("profil invalide réparé et réécrit", function()
		local clock = Fakes.clock()
		local store = Fakes.dataStore()
		local player = Fakes.player()
		store.data["player_" .. player.UserId] = { data = { version = 1, coins = "beaucoup", memes = { m1 = { id = "Pataplouf", slot = 42 } } } }
		local svc = service(store, "A", clock)
		local record = svc:loadAsync(player)
		T.eq(record.status, "Repaired")
		T.eq(record.profile.memes.m1.slot, nil)
		svc:autosave()
		T.eq(store.data["player_" .. player.UserId].data.memes.m1.slot, nil)
	end)

	T.test("départ pendant le chargement : verrou rendu, rien d'écrit", function()
		local clock = Fakes.clock()
		local store = Fakes.dataStore()
		local player = Fakes.player()
		store.data["player_" .. player.UserId] = { data = { version = 1, coins = 50 }, lock = { job = "Z", at = clock.get() } }
		local svc = service(store, "A", clock)
		local calls = 0
		local original = store.UpdateAsync
		function store:UpdateAsync(key, transform)
			calls += 1
			if calls == 2 then
				player.Parent = nil -- le joueur quitte pendant l'attente du verrou
			end
			return original(self, key, transform)
		end
		T.eq(svc:loadAsync(player), nil)
		T.eq(store.data["player_" .. player.UserId].lock.job, "Z", "verrou d'autrui non volé")
		T.eq(store.data["player_" .. player.UserId].data.coins, 50)
	end)

	T.test("sauvegarde périodique : uniquement si modifié (ou rafraîchissement du verrou)", function()
		local clock = Fakes.clock()
		local store = Fakes.dataStore()
		local svc = service(store, "A", clock)
		local player = Fakes.player()
		local record = svc:loadAsync(player)
		svc:autosave() -- profil neuf : écrit une fois
		local writes = store.writes
		svc:autosave()
		T.eq(store.writes, writes, "rien à écrire")
		svc:markDirty(player)
		svc:autosave()
		T.eq(store.writes, writes + 1)
		clock.advance(1000)
		svc:autosave()
		T.eq(store.writes, writes + 2, "verrou rafraîchi")
		T.truthy(record.canSave)
	end)

	T.test("revenus : pas de sauvegarde à chaque tick", function()
		Loader.reset()
		local world = World.new(Loader)
		local player = world.join("Alice")
		world.give(player, 0, { "Pataplouf" })
		world.ctx.profiles:autosave()
		local writes = world.store.writes
		for _ = 1, 20 do
			world.ctx.income:tick()
		end
		T.eq(world.store.writes, writes, "aucune écriture pendant les revenus")
		world.ctx.profiles:autosave()
		T.eq(world.store.writes, writes + 1, "une seule écriture groupée")
	end)
end
