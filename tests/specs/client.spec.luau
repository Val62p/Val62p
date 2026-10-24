--!nocheck
-- Intégration : le vrai client piloté comme un joueur, connecté au vrai serveur de test.
local World = require("../lib/World")
local ClientHarness = require("../lib/ClientHarness")

return function(T, Loader)
	local roblox = Loader.roblox
	local Vector3 = roblox.Vector3

	local world = World.new(Loader)
	local Config = world.Config
	local MapLayout = world.MapLayout
	local alice = world.join("Alice")
	local client = ClientHarness.start(Loader, world, alice)
	local ClientState = client.ClientState
	local Panels = client.Panels
	local hud = client.screen("SAM_Hud")
	local panels = client.screen("SAM_Panels")

	T.test("démarrage : synchronisation et HUD minimal", function()
		T.truthy(hud and panels, "écrans créés")
		T.truthy(ClientState.view.ready, "vue reçue du serveur")
		T.eq(ClientState.view.baseIndex, world.ctx.bases:getBaseIndex(alice))
		T.truthy(client.findText(hud, "150"), "solde affiché")
		for _, label in { "Boutique", "Mèmes", "Ma base", "Aide" } do
			T.truthy(client.findButton(hud, label) or client.findText(hud, label), "bouton " .. label)
		end
		T.truthy(client.findText(hud, "Protection de départ"), "état de protection visible")
	end)

	T.test("tutoriel : première étape guidée", function()
		T.truthy(client.findText(hud, "Bienvenue"), "étape 1")
		T.truthy(client.findText(hud, "Prairie Pop"))
	end)

	T.test("boutique : arrivages découverts, biomes verrouillés, achat", function()
		client.press("SAM_Shop")
		T.eq(Panels.current(), "Shop")
		T.truthy(client.findText(panels, "Explore Plage Soda"), "biome non découvert verrouillé")
		local button = client.findButton(panels, "Acheter")
		T.truthy(button, "bouton d'achat")
		client.click(button)
		if client.findButton(panels, "Confirmer") then
			client.click(client.findButton(panels, "Confirmer"))
		end
		local _, _, total = Loader.require("ServerScriptService.Domain.Inventory").counts(world.profile(alice))
		T.eq(total, 1, "mème acheté côté serveur")
		T.truthy(ClientState.view.coins < 150, "solde mis à jour côté client")
		T.truthy(client.findText(hud, "rejoint ta réserve") or client.findText(hud, "posé"), "message de succès")
		local invocation = client.invocations[#client.invocations]
		T.eq(invocation.action, "BuyOffer")
		T.eq(invocation.args.n, 3, "biome, piédestal et version seulement (jamais de prix)")
	end)

	T.test("onglets améliorations et cosmétiques : prix et effets affichés", function()
		local tabs = panels:FindFirstChild("Tabs", true)
		T.truthy(tabs)
		client.click(tabs:FindFirstChild("Tab_Upgrades"))
		T.truthy(client.findText(panels, "Socles en plus"))
		T.truthy(client.findText(panels, "4 → 5 socles"), "effet avant achat")
		T.truthy(client.findButton(panels, "Il manque"), "achat impossible signalé")
		client.click(tabs:FindFirstChild("Tab_Cosmetics"))
		T.truthy(client.findButton(panels, "Équipé"), "thème actuel")
		Panels.close()
		T.eq(Panels.current(), nil)
	end)

	T.test("collection : poser le mème depuis la réserve", function()
		client.press("SAM_Collection")
		T.eq(Panels.current(), "Collection")
		local tabs = panels:FindFirstChild("Backdrop_Mes mèmes"):FindFirstChild("Tabs", true)
		client.click(tabs:FindFirstChild("Tab_Storage"))
		local place = client.findButton(panels, "Poser")
		T.truthy(place, "bouton Poser")
		client.click(place)
		local placed = 0
		for _, entry in world.profile(alice).memes do
			if entry.slot then
				placed += 1
			end
		end
		T.eq(placed, 1, "posé côté serveur")
		client.click(tabs:FindFirstChild("Tab_Base"))
		T.truthy(client.findText(panels, "Socle 1"))
		client.click(tabs:FindFirstChild("Tab_Album"))
		T.truthy(client.findText(panels, "1 / " .. #Config.Memes.Order), "compteur d'album")
		T.truthy(client.findText(panels, "???"), "mèmes inconnus masqués")
		Panels.close()
	end)

	T.test("revenus : solde et « +N » mis à jour", function()
		local before = ClientState.view.coins
		world.ctx.income:tick()
		T.truthy(ClientState.view.coins > before)
		T.truthy(client.findText(hud, "+"), "petit +N")
	end)

	T.test("tutoriel : étapes suivantes puis fin enregistrée par le serveur", function()
		T.truthy(client.findText(hud, "Et voilà les pièces"), "étape 3 après la pose")
		local tutorial = hud:FindFirstChild("Tutorial")
		client.click(client.findButton(tutorial, "Suivant"))
		T.truthy(client.findText(hud, "Explore les biomes"))
		client.click(client.findButton(tutorial, "Suivant"))
		T.truthy(client.findText(hud, "vol d'opportunité"))
		client.click(client.findButton(tutorial, "Compris"))
		T.eq(tutorial.Visible, false)
		T.truthy(world.profile(alice).settings.tutorialDone, "fin du tutoriel sauvegardée")
	end)

	T.test("aide : règles issues de la configuration et mode Zen", function()
		client.press("SAM_Help")
		T.truthy(client.findText(panels, Config.Theft.CarrySeconds .. " s"), "règles chiffrées")
		local zen = client.findButton(panels, "Activer le mode Zen")
		T.truthy(zen)
		client.click(zen)
		T.truthy(world.ctx.protection:isZen(alice.UserId), "Zen activé côté serveur")
		T.truthy(client.findText(hud, "Mode Zen actif"))
		world.advance(Config.Theft.ZenToggleCooldownSeconds + 1)
		client.pump(1)
		client.click(client.findButton(panels, "Désactiver le mode Zen"))
		T.falsy(world.ctx.protection:isZen(alice.UserId))
		Panels.close()
	end)

	T.test("invites de proximité : socles de sa base", function()
		local index = ClientState.view.baseIndex
		local pad = client.Fake.wrap(world.ctx.map.bases[index].pads[2])
		local prompt = pad:FindFirstChild("OwnerPrompt", true)
		T.truthy(prompt, "invite créée localement")
		T.eq(prompt.Enabled, true)
		T.eq(prompt.ActionText, "Poser un mème")
		local steal = pad:FindFirstChild("StealPrompt", true)
		T.eq(steal.Enabled, false, "jamais de vol dans sa propre base")
		client.Fake.fire(prompt, "Triggered")
		T.truthy(client.findText(hud, "réserve est vide"), "explication claire")
	end)

	T.test("vol depuis le client : invite, bandeau, annulation", function()
		local bob = world.join("Bob")
		world.give(bob, 0, { "Pataplouf", "PinceMoi", "ChampiChill" })
		world.expireShields()
		local bobBase = world.ctx.bases:getBaseIndex(bob)
		world.moveTo(bob, Vector3.new(0, 3, 0))
		world.moveTo(alice, MapLayout.slotCFrame(bobBase, 1).Position + Vector3.new(0, 3, -4))
		client.pump(1.1) -- rafraîchissement périodique des invites
		local pad = client.Fake.wrap(world.ctx.map.bases[bobBase].pads[1])
		local steal = pad:FindFirstChild("StealPrompt", true)
		T.truthy(steal)
		T.eq(steal.Enabled, true, "base sans surveillance")
		T.eq(pad:FindFirstChild("OwnerPrompt", true).Enabled, false)
		client.Fake.fire(steal, "Triggered")
		T.truthy(world.ctx.theft:isThief(alice), "vol lancé côté serveur")
		client.heartbeat:Fire(0.1)
		T.truthy(client.findText(hud, "Crochetage"), "bandeau du voleur")
		client.click(client.findButton(hud, "Annuler"))
		T.falsy(world.ctx.theft:isThief(alice))
		client.heartbeat:Fire(0.1)
		T.falsy(client.findText(hud, "Crochetage") and client.findText(hud, "Crochetage").Parent.Visible, "bandeau masqué")
	end)

	T.test("petit écran tactile : rien d'essentiel hors écran", function()
		local Layout = Loader.require("StarterPlayer.StarterPlayerScripts.Client.Ui.Layout")
		local small = roblox.Vector2.new(568, 320)
		client.resize(small)
		local bar = hud:FindFirstChild("ActionBar")
		local spec = Layout.bottomBar(small)
		T.eq(bar.Size.X.Offset, spec.width)
		T.truthy(spec.width <= small.X - 2 * Layout.thumbZone(small), "barre entre les pouces")
		client.press("SAM_Shop")
		local frame = panels:FindFirstChild("Backdrop_Boutique"):FindFirstChild("Panel")
		T.truthy(frame.Size.X.Offset <= small.X and frame.Size.Y.Offset <= small.Y, "panneau dans l'écran")
		Panels.close()
		client.resize(roblox.Vector2.new(1280, 720))
	end)
end
