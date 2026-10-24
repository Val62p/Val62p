--!nocheck
-- Monde de test : les VRAIS services du serveur, branchés sur des doublures
-- (horloge, DataStore en mémoire, distants, joueurs et personnages simulés).
-- La carte est réellement construite avec les instances de @lune/roblox, ce qui valide
-- les noms et types de propriétés Roblox utilisés.
local Fakes = require("./Fakes")

local World = {}

local function fakeRemote()
	local remote = { events = {} }
	function remote:FireClient(player, payload)
		table.insert(self.events, { player = player, payload = payload })
	end
	return remote
end

function World.new(Loader, options)
	options = options or {}
	local roblox = Loader.roblox
	local clock = Fakes.clock(10_000)

	local dataModel = roblox.Instance.new("DataModel")
	local tagged = {}
	Loader.services.Workspace = dataModel:GetService("Workspace")
	Loader.services.Lighting = dataModel:GetService("Lighting")
	Loader.services.RunService = {
		IsStudio = function()
			return false
		end,
	}
	Loader.services.CollectionService = {
		AddTag = function(_, instance, tag)
			tagged[tag] = tagged[tag] or {}
			table.insert(tagged[tag], instance)
		end,
		RemoveTag = function() end,
		GetTagged = function(_, tag)
			return tagged[tag] or {}
		end,
	}

	local Services = "ServerScriptService.Services."
	local delayed = {}
	local players = {}

	local ctx
	ctx = {
		now = clock.get,
		clock = clock.get,
		logs = {},
		runLoops = false,
		scheduler = {
			spawn = function(fn, ...)
				fn(...)
			end,
			defer = function(fn, ...)
				fn(...)
			end,
			delay = function(seconds, fn)
				table.insert(delayed, { at = clock.now + seconds, fn = fn })
			end,
			wait = function(seconds)
				clock.advance(seconds or 0)
			end,
		},
		getPlayers = function()
			return players
		end,
		isInGame = function(player)
			return player.Parent ~= nil
		end,
		getPlayerByUserId = function(userId)
			for _, player in players do
				if player.UserId == userId then
					return player
				end
			end
			return nil
		end,
		isStudio = options.isStudio == true,
		visuals = {
			attach = function()
				return { attached = true }
			end,
			detach = function() end,
		},
	}
	ctx.log = function(...)
		table.insert(ctx.logs, table.concat({ ... }, " "))
	end

	local notifyRemote, stateRemote = fakeRemote(), fakeRemote()
	ctx.notifier = Loader.require(Services .. "Notifier").new(notifyRemote)
	ctx.state = Loader.require(Services .. "StateSync").new(ctx, stateRemote)
	local store = options.store or Fakes.dataStore()
	ctx.profiles = Loader.require(Services .. "ProfileService").new({
		store = if options.noStore then nil else store,
		jobId = options.jobId or "job-A",
		wallClock = clock.get,
		wait = function(seconds)
			clock.advance(seconds)
		end,
		delay = ctx.scheduler.delay,
		log = ctx.log,
		isInGame = ctx.isInGame,
	})
	ctx.map = Loader.require(Services .. "MapService").new()
	ctx.protection = Loader.require(Services .. "ProtectionService").new(ctx)
	ctx.bases = Loader.require(Services .. "BaseService").new(ctx)
	local SeededRandom = Loader.require("ReplicatedStorage.Shared.SeededRandom")
	local rng = SeededRandom.new(options.seed or 3)
	ctx.kiosks = Loader.require(Services .. "KioskService").new(ctx, function()
		return rng:nextNumber()
	end)
	ctx.shop = Loader.require(Services .. "ShopService").new(ctx)
	ctx.inventory = Loader.require(Services .. "InventoryService").new(ctx)
	ctx.income = Loader.require(Services .. "IncomeService").new(ctx)
	ctx.discovery = Loader.require(Services .. "DiscoveryService").new(ctx)
	ctx.characters = Loader.require(Services .. "CharacterService").new(ctx)
	ctx.theft = Loader.require(Services .. "TheftService").new(ctx)
	-- Doublure de MarketplaceService : enregistre les fenêtres d'achat ouvertes.
	local marketplace = { prompts = {}, ProcessReceipt = nil }
	function marketplace:PromptProductPurchase(player, productId)
		table.insert(self.prompts, { player = player, productId = productId })
	end
	ctx.monetization = Loader.require(Services .. "MonetizationService").new(ctx, marketplace, options.monetization)
	ctx.studioTools = Loader.require(Services .. "StudioTools").new(ctx)
	ctx.router = Loader.require(Services .. "Router").new(ctx)

	ctx.map:build()
	for _, service in { ctx.shop, ctx.inventory, ctx.theft, ctx.protection, ctx.characters, ctx.monetization, ctx.studioTools } do
		service:registerActions(ctx.router)
	end
	ctx.monetization:bind()
	ctx.kiosks:rotateAll()

	local world = {
		ctx = ctx,
		clock = clock,
		store = store,
		tagged = tagged,
		marketplace = marketplace,
		notify = notifyRemote,
		stateRemote = stateRemote,
		players = players,
		dataModel = dataModel,
		MapLayout = Loader.require("ReplicatedStorage.Shared.MapLayout"),
		Config = Loader.require("ReplicatedStorage.Shared.Config"),
	}

	-- Joueur connecté avec un personnage (HumanoidRootPart et Humanoid réels).
	function world.join(name)
		local player = Fakes.player(name)
		local root = roblox.Instance.new("Part")
		root.Name = "HumanoidRootPart"
		local head = roblox.Instance.new("Part")
		head.Name = "Head"
		local humanoid = roblox.Instance.new("Humanoid")
		humanoid.Health = 100 -- Lune n'a pas les valeurs par défaut de toutes les propriétés
		humanoid.WalkSpeed = 16
		local character = {
			root = root,
			humanoid = humanoid,
		}
		function character:FindFirstChild(childName)
			if childName == "HumanoidRootPart" then
				return root
			elseif childName == "Head" then
				return head
			end
			return nil
		end
		function character:FindFirstChildOfClass(className)
			if className == "Humanoid" then
				return humanoid
			end
			return nil
		end
		function character:PivotTo(cframe)
			root.CFrame = cframe
		end
		player.Character = character
		table.insert(players, player)
		local record = ctx.profiles:loadAsync(player)
		if record then
			ctx.protection:onPlayerReady(player, record)
			ctx.bases:assign(player)
			ctx.characters:applySpeed(player)
		end
		return player
	end

	function world.leave(player)
		ctx.theft:onPlayerRemoving(player)
		ctx.bases:release(player)
		ctx.protection:onPlayerRemoving(player)
		ctx.characters:onPlayerRemoving(player)
		ctx.router:onPlayerRemoving(player)
		player.Parent = nil
		ctx.profiles:saveAndReleaseAsync(player)
		local index = table.find(players, player)
		if index then
			table.remove(players, index)
		end
	end

	function world.moveTo(player, position)
		player.Character.root.CFrame = roblox.CFrame.new(position)
	end

	function world.profile(player)
		local record = ctx.profiles:get(player)
		return record and record.profile
	end

	function world.call(player, action, ...)
		return ctx.router:dispatch(player, action, ...)
	end

	-- Fait passer le temps (déclenche les sauvegardes différées échues).
	function world.advance(seconds)
		clock.advance(seconds)
		local due = {}
		for i = #delayed, 1, -1 do
			if delayed[i].at <= clock.now then
				table.insert(due, table.remove(delayed, i))
			end
		end
		for _, item in due do
			item.fn()
		end
	end

	function world.lastNotify(player)
		for i = #notifyRemote.events, 1, -1 do
			local event = notifyRemote.events[i]
			if event.player == player and event.payload.kind ~= "Income" then
				return event.payload
			end
		end
		return nil
	end

	function world.lastView(player)
		for i = #stateRemote.events, 1, -1 do
			if stateRemote.events[i].player == player then
				return stateRemote.events[i].payload
			end
		end
		return nil
	end

	-- Donne des pièces et des mèmes posés à un joueur (préparation de scénario).
	function world.give(player, coins, memes)
		local profile = world.profile(player)
		profile.coins = coins or profile.coins
		local Inventory = Loader.require("ServerScriptService.Domain.Inventory")
		for _, memeId in memes or {} do
			Inventory.add(profile, memeId, true)
		end
		ctx.bases:refresh(player)
	end

	-- Fin de la protection de départ de tout le monde.
	function world.expireShields()
		clock.advance(world.Config.Theft.JoinShieldSeconds + 1)
	end

	return world
end

return World
