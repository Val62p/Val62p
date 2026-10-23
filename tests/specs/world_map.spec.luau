--!nocheck
-- Construction réelle de la carte et attribution des bases.
local World = require("../lib/World")

return function(T, Loader)
	local world = World.new(Loader)
	local ctx = world.ctx
	local Config = world.Config
	local MapLayout = world.MapLayout

	T.test("la carte est construite dans Workspace.Map", function()
		local map = world.dataModel:GetService("Workspace"):FindFirstChild("Map")
		T.truthy(map, "dossier Map")
		local parts = 0
		for _, descendant in map:GetDescendants() do
			if descendant:IsA("BasePart") then
				parts += 1
			end
		end
		-- Garde-fou de performance : carte modeste (mèmes des kiosques compris).
		T.truthy(parts > 200, "assez de pièces pour 3 biomes décorés (" .. parts .. ")")
		T.truthy(parts < 2500, "carte modeste (" .. parts .. ")")
		local spawns = 0
		for _, descendant in map:GetDescendants() do
			if descendant:IsA("SpawnLocation") then
				spawns += 1
			end
		end
		T.eq(spawns, Config.Map.SpawnCount)
	end)

	T.test("socles et piédestaux tagués pour le client", function()
		T.eq(#(world.tagged.SAM_Pad or {}), MapLayout.baseCount() * MapLayout.maxSlots())
		T.eq(#(world.tagged.SAM_Pedestal or {}), #Config.Biomes.Order * Config.Map.Kiosk.Pedestals)
		T.eq(#(world.tagged.SAM_Base or {}), MapLayout.baseCount())
		T.eq(#(world.tagged.SAM_Kiosk or {}), #Config.Biomes.Order)
	end)

	T.test("chaque piédestal affiche une offre versionnée", function()
		for _, biomeId in Config.Biomes.Order do
			for pedestal = 1, Config.Map.Kiosk.Pedestals do
				local offer = ctx.kiosks:getOffer(biomeId, pedestal)
				T.truthy(offer, "offre " .. biomeId .. pedestal)
				local ref = ctx.map.kiosks[biomeId].pedestals[pedestal]
				T.eq(ref.part:GetAttribute("MemeId"), offer.memeId)
				T.eq(ref.part:GetAttribute("OfferVersion"), offer.version)
				T.eq(ref.part:GetAttribute("Price"), Config.Memes.Defs[offer.memeId].price)
				T.eq(#ref.display:GetChildren(), 1, "un seul modèle affiché")
			end
		end
		local before = ctx.kiosks:getOffer("PrairiePop", 1).version
		ctx.kiosks:rotateAll()
		T.truthy(ctx.kiosks:getOffer("PrairiePop", 1).version > before, "nouvelle version après rotation")
		T.eq(#ctx.map.kiosks.PrairiePop.pedestals[1].display:GetChildren(), 1, "ancien modèle retiré")
	end)

	T.test("un joueur reçoit une base libre, la rend en partant", function()
		local a = world.join("Alice")
		local b = world.join("Bob")
		local ia, ib = ctx.bases:getBaseIndex(a), ctx.bases:getBaseIndex(b)
		T.truthy(ia and ib and ia ~= ib, "bases distinctes")
		local model = ctx.map.bases[ia].model
		T.eq(model:GetAttribute("OwnerUserId"), a.UserId)
		T.eq(ctx.map.bases[ia].signTitle.Text, "Base de Alice")
		T.truthy(model:GetAttribute("ShieldUntil") > ctx.now(), "protection de départ visible")
		world.leave(a)
		T.eq(model:GetAttribute("OwnerUserId"), 0)
		T.eq(ctx.map.bases[ia].signTitle.Text, "Base libre")
		local c = world.join("Chloé")
		T.eq(ctx.bases:getBaseIndex(c), ia, "base réattribuée")
	end)

	T.test("serveur plein : pas de base, mais le joueur peut jouer", function()
		local extra = {}
		while #world.players < MapLayout.baseCount() do
			table.insert(extra, world.join())
		end
		local late = world.join("Tard")
		T.eq(ctx.bases:getBaseIndex(late), nil)
		T.truthy(string.find(world.lastNotify(late).text, "occupées"), "message clair")
		local result = world.call(late, "PlaceMeme", "m1")
		T.eq(result.code, "NoBase")
		ctx.income:tick() -- ne doit pas planter ni rapporter
		T.eq(world.profile(late).coins, Config.Economy.StartingCoins)
	end)
end
