--!nocheck
-- Boucle économique de bout en bout + requêtes client falsifiées.
local World = require("../lib/World")

return function(T, Loader)
	local Vector3 = Loader.roblox.Vector3

	local function setup()
		Loader.reset()
		local world = World.new(Loader)
		local player = world.join("Alice")
		return world, player, world.ctx
	end

	local function atPedestal(world, player, biomeId, pedestal)
		world.moveTo(player, world.MapLayout.pedestalCFrame(biomeId, pedestal).Position + Vector3.new(0, 0, -5))
	end

	T.test("rejoindre → acheter → poser → gagner des pièces", function()
		local world, player, ctx = setup()
		local Config = world.Config
		local profile = world.profile(player)
		T.eq(profile.coins, Config.Economy.StartingCoins)
		T.truthy(ctx.bases:getBaseIndex(player), "base reçue")

		atPedestal(world, player, "PrairiePop", 1)
		local offer = ctx.kiosks:getOffer("PrairiePop", 1)
		local price = Config.Memes.Defs[offer.memeId].price
		local result = world.call(player, "BuyOffer", "PrairiePop", 1, offer.version)
		T.truthy(result.ok, result.code)
		T.eq(profile.coins, Config.Economy.StartingCoins - price, "prix serveur débité")
		T.eq(result.data.slot, 0, "en réserve")

		local placed = world.call(player, "PlaceMeme", result.data.uid)
		T.truthy(placed.ok, placed.code)
		local index = ctx.bases:getBaseIndex(player)
		local pad = ctx.map.bases[index].pads[placed.data.slot]
		T.eq(pad:GetAttribute("HasMeme"), true)
		T.eq(pad:GetAttribute("MemeId"), offer.memeId)
		T.truthy(ctx.map.bases[index].memes:FindFirstChild("Slot" .. placed.data.slot), "mème affiché sur le socle")

		local before = profile.coins
		ctx.income:tick()
		T.eq(profile.coins, before + Config.Memes.Defs[offer.memeId].income, "revenu serveur")
		local view = world.lastView(player)
		T.eq(view.coins, profile.coins, "vue client synchronisée")
		T.eq(view.incomePerTick, Config.Memes.Defs[offer.memeId].income)
	end)

	T.test("fonds insuffisants, offre changée, objet inconnu", function()
		local world, player, ctx = setup()
		local profile = world.profile(player)
		atPedestal(world, player, "PrairiePop", 1)
		local offer = ctx.kiosks:getOffer("PrairiePop", 1)
		profile.coins = 1
		local poor = world.call(player, "BuyOffer", "PrairiePop", 1, offer.version)
		T.eq(poor.code, "NotEnoughCoins")
		T.truthy(poor.data.missing > 0)
		T.eq(profile.coins, 1, "rien débité")
		profile.coins = 10_000
		T.eq(world.call(player, "BuyOffer", "PrairiePop", 1, offer.version + 1).code, "OfferChanged")
		T.eq(world.call(player, "BuyOffer", "Atlantide", 1, offer.version).code, "BadRequest")
		T.eq(world.call(player, "BuyOffer", "PrairiePop", 99, offer.version).code, "BadRequest")
		T.eq(world.call(player, "BuyUpgrade", "SuperMoteur").code, "BadRequest")
		T.eq(world.call(player, "BuyCosmetic", "Diamant").code, "BadRequest")
		T.eq(profile.coins, 10_000, "aucune transaction")
	end)

	T.test("arguments falsifiés : types, NaN, surplus, action inconnue", function()
		local world, player, ctx = setup()
		local profile = world.profile(player)
		local offer = ctx.kiosks:getOffer("PrairiePop", 1)
		local cases = {
			{ "BuyOffer", "PrairiePop", 1, 0 / 0 },
			{ "BuyOffer", "PrairiePop", 1.5, offer.version },
			{ "BuyOffer", { biome = "PrairiePop" }, 1, offer.version },
			{ "BuyOffer", "PrairiePop", 1, offer.version, "prix=0" },
			{ "PlaceMeme", "m1", 0 },
			{ "PlaceMeme", "m1", 1, 3 },
			{ "PlaceMeme", 1 },
			{ "StoreMeme", "1" },
			{ "SellMeme", "m1' or 1=1" },
			{ "StartTheft", 0, 1 },
			{ "StartTheft", 1, 9 },
		}
		for _, case in cases do
			local result = world.call(player, table.unpack(case))
			T.eq(result.code, "BadRequest", case[1] .. " falsifié")
		end
		T.eq(world.call(player, "GiveCoins", 1e9).code, "UnknownAction")
		T.eq(world.call(player, 42).code, "BadRequest")
		T.eq(world.call(player, string.rep("x", 100)).code, "BadRequest")
		T.eq(profile.coins, world.Config.Economy.StartingCoins, "solde intact")
	end)

	T.test("biome non découvert : achat à distance refusé, sur place accepté", function()
		local world, player, ctx = setup()
		local profile = world.profile(player)
		profile.coins = 10_000
		local offer = ctx.kiosks:getOffer("PlageSoda", 1)
		world.moveTo(player, Vector3.new(0, 3, 0))
		T.eq(world.call(player, "BuyOffer", "PlageSoda", 1, offer.version).code, "BiomeLocked")
		atPedestal(world, player, "PlageSoda", 1)
		local result = world.call(player, "BuyOffer", "PlageSoda", 1, offer.version)
		T.truthy(result.ok, result.code)
		T.truthy(profile.discovered.PlageSoda, "biome découvert par l'achat sur place")
	end)

	T.test("découverte d'un biome en y entrant", function()
		local world, player, ctx = setup()
		local profile = world.profile(player)
		T.falsy(profile.discovered.ForetNeon)
		world.moveTo(player, world.MapLayout.biomeFrame("ForetNeon").Position + Vector3.new(0, 3, 0))
		ctx.discovery:check(player)
		T.truthy(profile.discovered.ForetNeon)
		T.eq(world.lastNotify(player).kind, "Discovery")
	end)

	T.test("double clic et spam : limités côté serveur", function()
		local world, player, ctx = setup()
		local profile = world.profile(player)
		profile.coins = 1_000_000
		atPedestal(world, player, "PrairiePop", 1)
		local offer = ctx.kiosks:getOffer("PrairiePop", 1)
		local ok, limited = 0, 0
		for _ = 1, 30 do
			local result = world.call(player, "BuyOffer", "PrairiePop", 1, offer.version)
			if result.ok then
				ok += 1
			elseif result.code == "RateLimited" then
				limited += 1
			end
		end
		T.eq(ok, world.Config.RateLimits.Actions.BuyOffer.capacity, "rafale bornée")
		T.truthy(limited > 0)
		local _, _, total = Loader.require("ServerScriptService.Domain.Inventory").counts(profile)
		T.eq(total, ok, "un mème par achat accepté")
	end)

	T.test("socles : occupé, verrouillé, réserve vide, inventaire plein", function()
		local world, player, ctx = setup()
		local profile = world.profile(player)
		world.give(player, 0, { "Pataplouf" })
		local uid = Loader.require("ServerScriptService.Domain.Inventory").uidAtSlot(profile, 1)
		T.truthy(uid)
		T.eq(world.call(player, "StoreMeme", 2).code, "SlotEmpty")
		local stored = world.call(player, "StoreMeme", 1)
		T.truthy(stored.ok)
		T.eq(world.call(player, "PlaceMeme", uid, 6).code, "SlotLocked")
		T.eq(world.call(player, "PlaceMeme", "m999").code, "MemeNotFound")
		T.truthy(world.call(player, "PlaceMeme", uid, 2).ok)
		T.eq(world.call(player, "PlaceMeme", uid, 3).code, "AlreadyPlaced")

		-- Remplir socles + réserve puis tenter un achat.
		local Progression = Loader.require("ServerScriptService.Domain.Progression")
		local fill = Progression.slotCapacity(profile) + Progression.storageCapacity(profile) - 1
		local list = {}
		for _ = 1, fill do
			table.insert(list, "Pataplouf")
		end
		world.give(player, 1_000_000, list)
		atPedestal(world, player, "PrairiePop", 1)
		local offer = ctx.kiosks:getOffer("PrairiePop", 1)
		local full = world.call(player, "BuyOffer", "PrairiePop", 1, offer.version)
		T.eq(full.code, "InventoryFull")
		T.eq(profile.coins, 1_000_000, "rien débité quand c'est plein")
	end)

	T.test("revente : remboursement partiel, mème retiré", function()
		local world, player = setup()
		local profile = world.profile(player)
		world.give(player, 0, { "HibouWifi" })
		local uid = next(profile.memes)
		local result = world.call(player, "SellMeme", uid)
		T.truthy(result.ok)
		T.eq(profile.coins, math.floor(world.Config.Memes.Defs.HibouWifi.price * world.Config.Economy.SellRefundRatio))
		T.eq(profile.memes[uid], nil)
		T.eq(world.call(player, "SellMeme", uid).code, "MemeNotFound", "pas de double revente")
	end)

	T.test("améliorations et cosmétiques", function()
		local world, player, ctx = setup()
		local profile = world.profile(player)
		profile.coins = 1_000_000
		for _ = 1, 4 do
			T.truthy(world.call(player, "BuyUpgrade", "Slots").ok)
			world.advance(1)
		end
		T.eq(profile.upgrades.Slots, 5)
		T.eq(world.call(player, "BuyUpgrade", "Slots").code, "MaxLevel")
		local index = ctx.bases:getBaseIndex(player)
		T.eq(ctx.map.bases[index].pads[8]:GetAttribute("Locked"), false, "8e socle déverrouillé")

		T.eq(world.call(player, "EquipCosmetic", "Minuit").code, "NotOwned")
		T.truthy(world.call(player, "BuyCosmetic", "Minuit").ok)
		T.eq(profile.cosmetics.equipped, "Minuit")
		T.eq(ctx.map.bases[index].floor.Color, world.Config.Cosmetics.Defs.Minuit.floor, "thème appliqué")
		T.eq(world.call(player, "BuyCosmetic", "Minuit").code, "AlreadyOwned")
		T.truthy(world.call(player, "EquipCosmetic", "Classic").ok)
	end)

	T.test("le revenu n'est versé qu'aux joueurs prêts et avec base", function()
		local world, player, ctx = setup()
		world.give(player, 0, { "Pataplouf" })
		world.leave(player)
		ctx.income:tick()
		T.eq(world.profile(player), nil, "profil déchargé, aucun revenu hors ligne")
	end)
end
