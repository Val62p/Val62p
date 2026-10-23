--!nocheck
-- Vol d'opportunité : règles, interruptions, déconnexions, issues.
local World = require("../lib/World")

return function(T, Loader)
	local Vector3 = Loader.roblox.Vector3
	local Inventory = Loader.require("ServerScriptService.Domain.Inventory")

	-- Monde avec un voleur (Vic… non : Tom) et une victime (Lina) qui a 3 mèmes posés.
	local function setup(victimMemes)
		Loader.reset()
		local world = World.new(Loader)
		local thief = world.join("Tom")
		local victim = world.join("Lina")
		world.give(victim, 0, victimMemes or { "Pataplouf", "MoutonNuage", "PinceMoi" })
		world.expireShields()
		local ctx = world.ctx
		local victimBase = ctx.bases:getBaseIndex(victim)
		local thiefBase = ctx.bases:getBaseIndex(thief)
		world.moveTo(victim, Vector3.new(0, 3, 0)) -- sur la place, loin de sa base
		world.moveTo(thief, world.MapLayout.slotCFrame(victimBase, 1).Position + Vector3.new(0, 3, -4))
		return world, thief, victim, ctx, victimBase, thiefBase
	end

	local function step(world)
		world.ctx.theft:step(world.ctx.now())
	end

	-- Marche (vitesse de transport) vers `target` en appelant la boucle du vol.
	local function walk(world, player, target, speed)
		speed = speed or world.Config.Theft.CarryWalkSpeed
		for _ = 1, 400 do
			local position = player.Character.root.CFrame.Position
			local delta = target - position
			if delta.Magnitude < 0.5 then
				break
			end
			local stepLength = math.min(delta.Magnitude, speed * 0.5)
			world.moveTo(player, position + delta.Unit * stepLength)
			world.advance(0.5)
			step(world)
			if not world.ctx.theft:isThief(player) then
				break
			end
		end
	end

	local function lift(world)
		world.advance(world.Config.Theft.LockpickSeconds + 0.1)
		step(world)
	end

	T.test("vol réussi : crochetage, transport, livraison, assurance, protection", function()
		local world, thief, victim, ctx, victimBase, thiefBase = setup()
		local victimProfile, thiefProfile = world.profile(victim), world.profile(thief)
		local stolenUid = Inventory.uidAtSlot(victimProfile, 1)
		local memeId = victimProfile.memes[stolenUid].id

		local result = world.call(thief, "StartTheft", victimBase, 1)
		T.truthy(result.ok, result.code)
		T.eq(world.lastNotify(victim).kind, "Alert", "victime alertée")
		T.truthy(ctx.theft:isLocked(victim.UserId, stolenUid), "mème verrouillé")
		T.eq(world.lastView(victim).robbery.otherName, "Tom")
		step(world)
		T.eq(ctx.theft.byThief[thief.UserId].phase, "Lockpick")
		lift(world)
		T.eq(ctx.theft.byThief[thief.UserId].phase, "Carry")
		T.eq(ctx.map.bases[victimBase].pads[1]:GetAttribute("InTransit"), true, "fantôme sur le socle")
		T.eq(world.lastView(thief).carrying.memeId, memeId)

		-- Pendant le transport, le mème ne rapporte rien et ne peut être ni rangé ni revendu.
		local victimCoins = victimProfile.coins
		ctx.income:tick()
		local expected = 0
		for uid, entry in victimProfile.memes do
			if entry.slot and uid ~= stolenUid then
				expected += world.Config.Memes.Defs[entry.id].income
			end
		end
		T.eq(victimProfile.coins - victimCoins, expected, "aucun revenu pour le mème emporté")
		T.eq(world.call(victim, "StoreMeme", 1).code, "MemeBusy")
		T.eq(world.call(victim, "SellMeme", stolenUid).code, "MemeBusy")
		T.eq(world.call(thief, "TeleportHome").code, "TeleportBlocked")
		T.eq(world.call(thief, "ToggleZen").code, "InTheft")

		walk(world, thief, world.MapLayout.homeCFrame(thiefBase).Position)
		T.falsy(ctx.theft:isThief(thief), "vol terminé")
		T.eq(victimProfile.memes[stolenUid], nil, "retiré chez la victime")
		local found = false
		for _, entry in thiefProfile.memes do
			if entry.id == memeId then
				found = true
				T.truthy(entry.slot, "posé directement dans la base du voleur")
			end
		end
		T.truthy(found, "ajouté chez le voleur")
		T.eq(thiefProfile.stats.stolen, 1)
		T.eq(victimProfile.stats.lost, 1)
		local insurance = math.floor(world.Config.Memes.Defs[memeId].price * world.Config.Theft.InsuranceRatio)
		T.truthy(victimProfile.coins >= victimCoins + insurance, "assurance versée")
		T.truthy(ctx.protection:protectedUntil(victim.UserId) > ctx.now(), "victime protégée")
		T.eq(ctx.map.bases[victimBase].pads[1]:GetAttribute("HasMeme"), false)
		T.truthy(string.find(world.lastNotify(victim).text, "assurance"), "message clair et bienveillant")

		-- Sauvegarde rapprochée des deux profils.
		world.advance(5)
		local saved = world.store.data["player_" .. victim.UserId].data
		T.eq(saved.memes[stolenUid], nil, "victime sauvegardée")
		local savedThief = world.store.data["player_" .. thief.UserId].data
		local savedCount = 0
		for _, entry in savedThief.memes do
			if entry.id == memeId then
				savedCount += 1
			end
		end
		T.eq(savedCount, 1, "voleur sauvegardé, sans doublon")

		-- Protection après vol + anti-répétition.
		world.advance(world.Config.Theft.ThiefCooldownSeconds + 1)
		world.moveTo(thief, world.MapLayout.slotCFrame(victimBase, 2).Position + Vector3.new(0, 3, -4))
		T.eq(world.call(thief, "StartTheft", victimBase, 2).code, "TargetProtected")
		world.advance(world.Config.Theft.VictimShieldSeconds)
		T.eq(world.call(thief, "StartTheft", victimBase, 2).code, "PairCooldown")
	end)

	T.test("règles de démarrage", function()
		local world, thief, victim, ctx, victimBase, thiefBase = setup()
		-- Les appels sont espacés pour ne pas déclencher la limitation de débit.
		local function call(player, ...)
			world.advance(1.1)
			return world.call(player, ...)
		end
		T.eq(call(thief, "StartTheft", thiefBase, 1).code, "OwnBase")
		T.eq(call(thief, "StartTheft", victimBase, 4).code, "SlotEmpty")
		world.moveTo(thief, Vector3.new(0, 3, 0))
		T.eq(call(thief, "StartTheft", victimBase, 1).code, "TooFar", "hors de portée")
		world.moveTo(thief, world.MapLayout.slotCFrame(victimBase, 1).Position + Vector3.new(0, 3, -4))

		ctx.protection.states[victim.UserId].zen = true
		T.eq(call(thief, "StartTheft", victimBase, 1).code, "TargetZen")
		ctx.protection.states[victim.UserId].zen = false
		ctx.protection.states[thief.UserId].zen = true
		T.eq(call(thief, "StartTheft", victimBase, 1).code, "SelfZen")
		ctx.protection.states[thief.UserId].zen = false

		world.moveTo(victim, world.MapLayout.homeCFrame(victimBase).Position)
		T.eq(call(thief, "StartTheft", victimBase, 1).code, "OwnerWatching")
		world.moveTo(victim, Vector3.new(0, 3, 0))

		local other = world.join("Zoé")
		world.advance(1)
		ctx.protection.states[other.UserId].joinShieldUntil = 0
		world.moveTo(other, world.MapLayout.slotCFrame(victimBase, 2).Position + Vector3.new(0, 3, -4))
		T.truthy(call(thief, "StartTheft", victimBase, 1).ok)
		T.eq(call(other, "StartTheft", victimBase, 2).code, "BaseBusy", "un seul vol par base")
		T.eq(call(thief, "StartTheft", victimBase, 2).code, "AlreadyCarrying")
		T.truthy(call(thief, "CancelTheft").ok)
		T.eq(call(thief, "CancelTheft").code, "NotCarrying")
		T.eq(call(thief, "StartTheft", victimBase, 1).code, "ThiefCooldown")
	end)

	T.test("protection de départ et dernier mème", function()
		Loader.reset()
		local world = World.new(Loader)
		local thief = world.join("Tom")
		local victim = world.join("Lina")
		world.give(victim, 0, { "Pataplouf" })
		local ctx = world.ctx
		local victimBase = ctx.bases:getBaseIndex(victim)
		world.moveTo(victim, Vector3.new(0, 3, 0))
		world.moveTo(thief, world.MapLayout.slotCFrame(victimBase, 1).Position + Vector3.new(0, 3, -4))
		T.eq(world.call(thief, "StartTheft", victimBase, 1).code, "TargetProtected", "nouveau joueur protégé")
		world.expireShields()
		T.eq(world.call(thief, "StartTheft", victimBase, 1).code, "LastMeme", "dernier mème intouchable")
	end)

	T.test("lancer un vol met fin à sa propre protection de départ", function()
		Loader.reset()
		local world = World.new(Loader)
		local victim = world.join("Lina")
		world.give(victim, 0, { "Pataplouf", "PinceMoi" })
		world.expireShields()
		local thief = world.join("Tom") -- arrive plus tard : encore protégé
		local ctx = world.ctx
		local victimBase = ctx.bases:getBaseIndex(victim)
		world.moveTo(victim, Vector3.new(0, 3, 0))
		world.moveTo(thief, world.MapLayout.slotCFrame(victimBase, 1).Position + Vector3.new(0, 3, -4))
		T.truthy(ctx.protection:protectedUntil(thief.UserId) > ctx.now())
		T.truthy(world.call(thief, "StartTheft", victimBase, 1).ok)
		T.truthy(ctx.protection:protectedUntil(thief.UserId) <= ctx.now(), "protection consommée")
	end)

	T.test("le propriétaire revient pendant le crochetage", function()
		local world, thief, victim, ctx, victimBase = setup()
		local victimProfile = world.profile(victim)
		T.truthy(world.call(thief, "StartTheft", victimBase, 1).ok)
		world.moveTo(victim, world.MapLayout.homeCFrame(victimBase).Position)
		step(world)
		T.falsy(ctx.theft:isThief(thief))
		T.eq(victimProfile.stats.defended, 1)
		T.eq(world.lastNotify(victim).kind, "Success")
	end)

	T.test("le voleur s'éloigne pendant le crochetage", function()
		local world, thief, _, ctx, victimBase = setup()
		T.truthy(world.call(thief, "StartTheft", victimBase, 1).ok)
		world.moveTo(thief, Vector3.new(0, 3, 0))
		step(world)
		T.falsy(ctx.theft:isThief(thief))
		T.truthy(string.find(world.lastNotify(thief).text, "éloigné"))
	end)

	T.test("la victime rattrape le voleur", function()
		local world, thief, victim, ctx, victimBase = setup()
		local victimProfile = world.profile(victim)
		local uid = Inventory.uidAtSlot(victimProfile, 1)
		T.truthy(world.call(thief, "StartTheft", victimBase, 1).ok)
		lift(world)
		world.advance(1)
		local thiefPosition = thief.Character.root.CFrame.Position
		world.moveTo(victim, thiefPosition + Vector3.new(3, 0, 0))
		step(world)
		T.falsy(ctx.theft:isThief(thief))
		T.eq(victimProfile.memes[uid].slot, 1, "mème revenu sur son socle")
		T.eq(ctx.map.bases[victimBase].pads[1]:GetAttribute("InTransit"), false)
		T.falsy(ctx.theft:isLocked(victim.UserId, uid))
		T.eq(victimProfile.stats.defended, 1)
		T.truthy(string.find(world.lastNotify(victim).text, "récupéré"))
	end)

	T.test("zone surveillée de la place : détection", function()
		local world, thief, victim, ctx, victimBase = setup()
		world.moveTo(victim, world.MapLayout.biomeFrame("ForetNeon").Position + Vector3.new(0, 3, 0))
		local uid = Inventory.uidAtSlot(world.profile(victim), 1)
		T.truthy(world.call(thief, "StartTheft", victimBase, 1).ok)
		lift(world)
		walk(world, thief, Vector3.new(0, 3, 0))
		T.falsy(ctx.theft:isThief(thief))
		T.truthy(world.profile(victim).memes[uid], "mème toujours à la victime")
		T.truthy(string.find(world.lastNotify(thief).text, "surveillée"))
	end)

	T.test("délai dépassé", function()
		local world, thief, victim, ctx, victimBase = setup()
		local uid = Inventory.uidAtSlot(world.profile(victim), 1)
		T.truthy(world.call(thief, "StartTheft", victimBase, 1).ok)
		lift(world)
		world.advance(world.Config.Theft.CarrySeconds + 1)
		step(world)
		T.falsy(ctx.theft:isThief(thief))
		T.truthy(world.profile(victim).memes[uid])
		T.truthy(string.find(world.lastNotify(thief).text, "Trop tard"))
	end)

	T.test("téléportation détectée pendant le transport", function()
		local world, thief, victim, ctx, victimBase, thiefBase = setup()
		local uid = Inventory.uidAtSlot(world.profile(victim), 1)
		T.truthy(world.call(thief, "StartTheft", victimBase, 1).ok)
		lift(world)
		world.advance(0.6)
		world.moveTo(thief, world.MapLayout.homeCFrame(thiefBase).Position)
		step(world)
		T.falsy(ctx.theft:isThief(thief))
		T.truthy(world.profile(victim).memes[uid], "pas de livraison par téléportation")
		T.truthy(string.find(world.lastNotify(thief).text, "anormal"))
	end)

	T.test("le voleur meurt", function()
		local world, thief, victim, ctx, victimBase = setup()
		local uid = Inventory.uidAtSlot(world.profile(victim), 1)
		T.truthy(world.call(thief, "StartTheft", victimBase, 1).ok)
		lift(world)
		thief.Character.humanoid.Health = 0
		step(world)
		T.falsy(ctx.theft:isThief(thief))
		T.truthy(world.profile(victim).memes[uid])
	end)

	T.test("le voleur se déconnecte pendant le transport", function()
		local world, thief, victim, ctx, victimBase = setup()
		local uid = Inventory.uidAtSlot(world.profile(victim), 1)
		T.truthy(world.call(thief, "StartTheft", victimBase, 1).ok)
		lift(world)
		world.leave(thief)
		T.eq(next(ctx.theft.byThief), nil)
		T.eq(world.profile(victim).memes[uid].slot, 1, "mème rendu à son socle")
		local saved = world.store.data["player_" .. thief.UserId].data
		for _, entry in saved.memes do
			T.falsy(entry.id == "Pataplouf" and false, "rien d'inattendu")
		end
		T.eq(ctx.map.bases[victimBase].model:GetAttribute("UnderTheft"), false)
	end)

	T.test("la victime se déconnecte pendant le transport : son mème est sauvegardé chez elle", function()
		local world, thief, victim, ctx, victimBase = setup()
		local uid = Inventory.uidAtSlot(world.profile(victim), 1)
		local memeId = world.profile(victim).memes[uid].id
		T.truthy(world.call(thief, "StartTheft", victimBase, 1).ok)
		lift(world)
		world.leave(victim)
		T.falsy(ctx.theft:isThief(thief))
		local saved = world.store.data["player_" .. victim.UserId].data
		T.eq(saved.memes[uid].id, memeId, "mème sauvegardé chez la victime")
		for _, entry in world.profile(thief).memes do
			T.falsy(entry.id == memeId, "pas de copie chez le voleur")
		end
		T.truthy(string.find(world.lastNotify(thief).text, "parti"))
	end)

	T.test("base du voleur pleine à l'arrivée", function()
		local world, thief, victim, ctx, victimBase, thiefBase = setup()
		local uid = Inventory.uidAtSlot(world.profile(victim), 1)
		T.truthy(world.call(thief, "StartTheft", victimBase, 1).ok)
		lift(world)
		local Progression = Loader.require("ServerScriptService.Domain.Progression")
		local thiefProfile = world.profile(thief)
		for _ = 1, Progression.slotCapacity(thiefProfile) + Progression.storageCapacity(thiefProfile) do
			Inventory.add(thiefProfile, "ChampiChill", true)
		end
		walk(world, thief, world.MapLayout.homeCFrame(thiefBase).Position)
		T.falsy(ctx.theft:isThief(thief))
		T.truthy(world.profile(victim).memes[uid], "mème rendu")
		T.truthy(string.find(world.lastNotify(thief).text, "pleine"))
	end)

	T.test("fermeture du serveur pendant un vol", function()
		local world, thief, victim, ctx, victimBase = setup()
		local uid = Inventory.uidAtSlot(world.profile(victim), 1)
		T.truthy(world.call(thief, "StartTheft", victimBase, 1).ok)
		lift(world)
		ctx.theft:cancelAll("ServerClosing")
		ctx.profiles:saveAllAsync(function(fn)
			fn()
		end, 25)
		local saved = world.store.data["player_" .. victim.UserId]
		T.truthy(saved.data.memes[uid], "mème intact dans la sauvegarde")
		T.eq(saved.lock, nil, "verrou libéré")
	end)

	T.test("spam de tentatives limité", function()
		local world, thief, _, _, victimBase = setup()
		local limited = 0
		for _ = 1, 20 do
			if world.call(thief, "StartTheft", victimBase, 1).code == "RateLimited" then
				limited += 1
			end
		end
		T.truthy(limited > 0)
	end)
end
