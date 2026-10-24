--!nocheck
-- Tapis de course (vitesse), achats Robux par ProcessReceipt, outils de test Studio.
local World = require("../lib/World")
local Fakes = require("../lib/Fakes")
local ClientHarness = require("../lib/ClientHarness")

return function(T, Loader)
	local roblox = Loader.roblox
	local Vector3 = roblox.Vector3
	local Decision = roblox.Enum.ProductPurchaseDecision
	local PRODUCT_ID = 123456

	local function robuxSettings(historySize)
		return {
			Enabled = true,
			DeveloperProducts = {
				TreadmillLevel = {
					productId = PRODUCT_ID,
					kind = "UpgradeLevel",
					upgradeId = "Treadmill",
					displayName = "Tapis de course : +1 niveau",
				},
			},
			MaxLevelFallbackCoins = 5000,
			ReceiptHistorySize = historySize or 50,
			GamePasses = {},
		}
	end

	local function setup(options)
		Loader.reset()
		local world = World.new(Loader, options)
		local player = world.join("Alice")
		return world, player, world.ctx
	end

	local function receipt(player, purchaseId, productId)
		return { PlayerId = player.UserId, ProductId = productId or PRODUCT_ID, PurchaseId = purchaseId, CurrencySpent = 25 }
	end

	T.test("tapis de course : vitesse du personnage, niveau affiché sur la base", function()
		local world, player, ctx = setup()
		local humanoid = player.Character.humanoid
		T.eq(humanoid.WalkSpeed, 16, "vitesse de départ")
		world.profile(player).coins = 100_000
		local result = world.call(player, "BuyUpgrade", "Treadmill")
		T.truthy(result.ok, result.code)
		T.eq(humanoid.WalkSpeed, 18, "vitesse du niveau 2")
		local treadmill = ctx.map.bases[ctx.bases:getBaseIndex(player)].treadmill
		T.eq(treadmill.model:GetAttribute("Level"), 2)
		T.truthy(string.find(treadmill.levelLabel.Text, "vitesse 18"), treadmill.levelLabel.Text)
		T.eq(world.lastView(player).walkSpeed, 18)
		T.truthy(world.MapLayout.isInsideBase(ctx.bases:getBaseIndex(player), world.MapLayout.treadmillCFrame(ctx.bases:getBaseIndex(player)).Position))
	end)

	T.test("tapis de course : vitesse fixe en portant un mème, rendue ensuite", function()
		local world, thief, ctx = setup()
		local victim = world.join("Lina")
		world.give(victim, 0, { "Pataplouf", "PinceMoi", "ChampiChill" })
		world.profile(thief).upgrades.Treadmill = 6
		ctx.characters:applySpeed(thief)
		T.eq(thief.Character.humanoid.WalkSpeed, 26)
		world.expireShields()
		local victimBase = ctx.bases:getBaseIndex(victim)
		world.moveTo(victim, Vector3.new(0, 3, 0))
		world.moveTo(thief, world.MapLayout.slotCFrame(victimBase, 1).Position + Vector3.new(0, 3, -4))
		T.truthy(world.call(thief, "StartTheft", victimBase, 1).ok)
		world.advance(world.Config.Theft.LockpickSeconds + 0.1)
		ctx.theft:step(ctx.now())
		T.eq(thief.Character.humanoid.WalkSpeed, world.Config.Theft.CarryWalkSpeed, "pas d'avantage pour fuir")
		T.truthy(world.call(thief, "CancelTheft").ok)
		T.eq(thief.Character.humanoid.WalkSpeed, 26, "vitesse du tapis rendue")
	end)

	T.test("Robux désactivé par défaut : aucun achat possible, ProcessReceipt non branché", function()
		local world, player = setup()
		T.eq(world.call(player, "BuyWithRobux", "TreadmillLevel").code, "RobuxUnavailable")
		T.eq(world.marketplace.ProcessReceipt, nil)
		T.eq(#world.marketplace.prompts, 0)
		T.eq(next(world.lastView(player).robuxProducts), nil)
		T.eq(world.call(player, "ProcessReceipt", PRODUCT_ID).code, "UnknownAction", "le client ne peut rien s'accorder")
	end)

	T.test("Robux configuré : fenêtre d'achat ouverte par le serveur", function()
		local world, player = setup({ monetization = robuxSettings() })
		T.eq(world.lastView(player).robuxProducts.TreadmillLevel, PRODUCT_ID)
		T.truthy(world.call(player, "BuyWithRobux", "TreadmillLevel").ok)
		T.eq(world.marketplace.prompts[1].productId, PRODUCT_ID)
		world.advance(3)
		T.eq(world.call(player, "BuyWithRobux", "SuperPouvoir").code, "RobuxUnavailable")
		world.advance(3)
		T.eq(world.call(player, "BuyWithRobux", 42).code, "BadRequest")
		T.eq(world.profile(player).upgrades.Treadmill, 1, "ouvrir la fenêtre n'accorde rien")
	end)

	T.test("ProcessReceipt : accordé une seule fois, sauvegardé avant confirmation", function()
		local world, player = setup({ monetization = robuxSettings() })
		local process = world.marketplace.ProcessReceipt
		T.truthy(process, "ProcessReceipt branché")
		T.eq(process(receipt(player, "achat-1")), Decision.PurchaseGranted)
		T.eq(world.profile(player).upgrades.Treadmill, 2)
		T.eq(player.Character.humanoid.WalkSpeed, 18)
		local saved = world.store.data["player_" .. player.UserId].data
		T.eq(saved.upgrades.Treadmill, 2, "sauvegardé")
		T.truthy(table.find(saved.receipts, "achat-1"), "reçu mémorisé")
		T.eq(process(receipt(player, "achat-1")), Decision.PurchaseGranted, "rejeu du même reçu")
		T.eq(world.profile(player).upgrades.Treadmill, 2, "jamais deux fois")
		T.truthy(string.find(world.lastNotify(player).text, "Merci"))
	end)

	T.test("ProcessReceipt : cas limites", function()
		local world, player = setup({ monetization = robuxSettings(3) })
		local process = world.marketplace.ProcessReceipt
		T.eq(process(receipt(player, "x", 999)), Decision.NotProcessedYet, "produit inconnu")
		local absent = Fakes.player("Absent")
		T.eq(process({ PlayerId = absent.UserId, ProductId = PRODUCT_ID, PurchaseId = "y" }), Decision.NotProcessedYet, "joueur absent")

		-- Panne de sauvegarde : pas de confirmation, puis la nouvelle tentative n'accorde pas deux fois.
		world.store.failNext = 3
		T.eq(process(receipt(player, "panne")), Decision.NotProcessedYet)
		T.eq(world.profile(player).upgrades.Treadmill, 2)
		T.eq(process(receipt(player, "panne")), Decision.PurchaseGranted)
		T.eq(world.profile(player).upgrades.Treadmill, 2, "toujours un seul niveau")

		for i = 1, 6 do
			process(receipt(player, "r" .. i))
		end
		T.eq(world.profile(player).upgrades.Treadmill, 6, "niveau maximum")
		T.eq(#world.profile(player).receipts, 3, "historique borné")
		world.advance(3)
		T.eq(world.call(player, "BuyWithRobux", "TreadmillLevel").code, "MaxLevel", "pas d'achat inutile")
		local coins = world.profile(player).coins
		T.eq(process(receipt(player, "tardif")), Decision.PurchaseGranted)
		T.eq(world.profile(player).coins, coins + 5000, "achat jamais perdu : pièces à la place")
	end)

	T.test("ProcessReceipt sans sauvegarde : refusé en jeu publié, accepté dans Studio", function()
		local world, player = setup({ monetization = robuxSettings(), noStore = true })
		T.eq(world.marketplace.ProcessReceipt(receipt(player, "a")), Decision.NotProcessedYet)
		T.eq(world.profile(player).upgrades.Treadmill, 1)
		local studio, studioPlayer = setup({ monetization = robuxSettings(), noStore = true, isStudio = true })
		T.eq(studio.marketplace.ProcessReceipt(receipt(studioPlayer, "a")), Decision.PurchaseGranted)
		T.eq(studio.profile(studioPlayer).upgrades.Treadmill, 2)
	end)

	T.test("outils Studio : absents du jeu publié", function()
		local world, player = setup()
		T.eq(world.call(player, "StudioTool", "Coins").code, "UnknownAction")
		T.eq(world.profile(player).coins, world.Config.Economy.StartingCoins)
		T.eq(world.lastView(player).studioTools, false)
	end)

	T.test("outils Studio : pièces, fin de protection, nouvel arrivage", function()
		local world, player, ctx = setup({ isStudio = true })
		T.eq(world.lastView(player).studioTools, true)
		T.truthy(world.call(player, "StudioTool", "Coins").ok)
		T.eq(world.profile(player).coins, world.Config.Economy.StartingCoins + 10000)
		T.truthy(ctx.protection:protectedUntil(player.UserId) > ctx.now())
		T.truthy(world.call(player, "StudioTool", "EndShield").ok)
		T.truthy(ctx.protection:protectedUntil(player.UserId) <= ctx.now())
		local version = ctx.kiosks:getOffer("PrairiePop", 1).version
		T.truthy(world.call(player, "StudioTool", "Restock").ok)
		T.truthy(ctx.kiosks:getOffer("PrairiePop", 1).version > version)
		T.eq(world.call(player, "StudioTool", "Robux").code, "BadRequest")
	end)

	T.test("client : invite du tapis, bouton Robux, outils Studio dans l'aide", function()
		local world, player = setup({ monetization = robuxSettings(), isStudio = true })
		local client = ClientHarness.start(Loader, world, player)
		local hud, panels = client.screen("SAM_Hud"), client.screen("SAM_Panels")

		-- Outils de test dans l'aide.
		client.press("SAM_Help")
		local coinsTool = client.findButton(panels, "+10 000 pièces")
		T.truthy(coinsTool, "outil visible dans Studio")
		client.click(coinsTool)
		T.eq(world.profile(player).coins, world.Config.Economy.StartingCoins + 10000)
		client.Panels.close()

		-- Invite sur son propre tapis de course.
		local index = world.ctx.bases:getBaseIndex(player)
		local console = client.Fake.wrap(world.ctx.map.bases[index].treadmill.console)
		local prompt = console:FindFirstChild("TreadmillPrompt")
		T.truthy(prompt and prompt.Enabled, "invite active sur sa base")
		T.truthy(string.find(prompt.ActionText, "300"), prompt.ActionText)
		client.Fake.fire(prompt, "Triggered")
		T.eq(world.profile(player).upgrades.Treadmill, 2, "amélioré en pièces")
		T.truthy(client.findText(hud, "vitesse 18"), "message de succès")
		local other = client.Fake.wrap(world.ctx.map.bases[(index % 6) + 1].treadmill.console)
		T.eq(other:FindFirstChild("TreadmillPrompt").Enabled, false, "pas sur les autres bases")

		-- Boutique : choix pièces ou Robux.
		client.press("SAM_Shop")
		client.click(panels:FindFirstChild("Tab_Upgrades", true))
		client.pump(0)
		client.click(panels:FindFirstChild("Tab_Cosmetics", true))
		client.click(panels:FindFirstChild("Tab_Upgrades", true))
		local robux = client.findButton(panels, "R$ 25")
		T.truthy(robux, "bouton Robux avec le prix lu auprès de Roblox")
		client.click(robux)
		T.eq(world.marketplace.prompts[#world.marketplace.prompts].productId, PRODUCT_ID)
		T.truthy(client.findButton(panels, "1 200 pièces") or client.findButton(panels, "pièces"), "alternative en pièces")
		client.Panels.close()
	end)
end
