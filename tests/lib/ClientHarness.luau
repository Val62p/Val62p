--!nocheck
-- Exécute le VRAI client (Main.client.luau et ses contrôleurs) branché sur un monde serveur
-- de test : les requêtes du client passent par le routeur du serveur, et les vues/notifications
-- du serveur sont livrées au client. Les instances du client sont des FakeRoblox (propriétés
-- validées par la réflexion Roblox, événements simulés).
local Fakes = require("./Fakes")
local FakeRoblox = require("./FakeRoblox")

local ClientHarness = {}

function ClientHarness.start(Loader, world, serverPlayer, options)
	options = options or {}
	local roblox = Loader.roblox
	local Fake = FakeRoblox

	-- Cache neuf : les modules partagés sont rechargés avec les instances simulées.
	Loader.reset()
	Loader.globals.Instance = Fake.Instance
	Loader.globals.task = Fake.task

	local stateSignal, notifySignal = Fake.signal(), Fake.signal()
	local invocations = {}
	local remotes = {
		Action = {
			InvokeServer = function(_, action, ...)
				table.insert(invocations, { action = action, args = table.pack(...) })
				-- Copie profonde : le client ne partage jamais de tables avec le serveur.
				return Fakes.deepCopy(world.call(serverPlayer, action, ...))
			end,
		},
		State = { OnClientEvent = stateSignal },
		Notify = { OnClientEvent = notifySignal },
	}
	Loader.overrides["ReplicatedStorage.Remotes"] = {
		WaitForChild = function(_, name)
			return remotes[name]
		end,
	}

	-- Livraison serveur → client (comme la réplication des RemoteEvent).
	local stateRemote, notifyRemote = world.stateRemote, world.notify
	local originalState, originalNotify = stateRemote.FireClient, notifyRemote.FireClient
	stateRemote.FireClient = function(self, player, payload)
		originalState(self, player, payload)
		if player == serverPlayer then
			stateSignal:Fire(Fakes.deepCopy(payload))
		end
	end
	notifyRemote.FireClient = function(self, player, payload)
		originalNotify(self, player, payload)
		if player == serverPlayer then
			notifySignal:Fire(Fakes.deepCopy(payload))
		end
	end

	local playerGui = Fake.Instance.new("Folder")
	playerGui.Name = "PlayerGui"
	local localPlayer = {
		UserId = serverPlayer.UserId,
		Name = serverPlayer.Name,
		DisplayName = serverPlayer.DisplayName,
		Character = nil,
	}
	function localPlayer:WaitForChild(name)
		assert(name == "PlayerGui", "enfant inattendu : " .. tostring(name))
		return playerGui
	end

	local function wrapList(list)
		local out = {}
		for _, instance in list or {} do
			table.insert(out, Fake.wrap(instance))
		end
		return out
	end
	local bound = {}
	local clientModel = roblox.Instance.new("DataModel")
	Loader.services.Players = {
		LocalPlayer = localPlayer,
		GetPlayerByUserId = function()
			return nil
		end,
	}
	Loader.services.CollectionService = {
		GetTagged = function(_, tag)
			return wrapList(world.tagged[tag])
		end,
		GetInstanceAddedSignal = function()
			return Fake.signal()
		end,
		GetInstanceRemovedSignal = function()
			return Fake.signal()
		end,
	}
	Loader.services.TweenService = {
		Create = function(_, instance, _info, goals)
			local tween = { Completed = Fake.signal() }
			function tween:Play()
				for key, value in goals do
					instance[key] = value
				end
				Fake.task.delay(0, function()
					tween.Completed:Fire()
				end)
			end
			function tween:Cancel() end
			return tween
		end,
	}
	local heartbeat, renderStepped = Fake.signal(), Fake.signal()
	Loader.services.RunService = {
		Heartbeat = heartbeat,
		RenderStepped = renderStepped,
		IsStudio = function()
			return true
		end,
	}
	Loader.services.ContextActionService = {
		BindAction = function(_, name, handler, _createTouchButton, ...)
			bound[name] = { handler = handler, keys = { ... } }
		end,
		UnbindAction = function(_, name)
			bound[name] = nil
		end,
	}
	Loader.services.GuiService = { SelectedObject = nil }
	Loader.services.MarketplaceService = {
		GetProductInfo = function(_, productId)
			return { ProductId = productId, PriceInRobux = 25 }
		end,
	}
	Loader.services.UserInputService = {
		KeyboardEnabled = options.keyboard ~= false,
		TouchEnabled = options.touch == true,
		GamepadEnabled = options.gamepad == true,
	}
	Loader.services.StarterGui = { SetCoreGuiEnabled = function() end }
	Loader.services.Lighting = Fake.wrap(clientModel:GetService("Lighting"))
	Loader.services.Workspace = {
		CurrentCamera = { CFrame = roblox.CFrame.new(0, 20, 0) },
		GetServerTimeNow = function()
			return world.clock.get()
		end,
	}

	Loader.require("StarterPlayer.StarterPlayerScripts.Client.Main")

	local client = {
		playerGui = playerGui,
		invocations = invocations,
		bound = bound,
		heartbeat = heartbeat,
		renderStepped = renderStepped,
		Fake = Fake,
		ClientState = Loader.require("StarterPlayer.StarterPlayerScripts.Client.Controllers.ClientState"),
		Panels = Loader.require("StarterPlayer.StarterPlayerScripts.Client.Controllers.Panels"),
	}

	function client.screen(name)
		return playerGui:FindFirstChild(name)
	end

	-- Texte visible quelque part dans l'interface (TextLabel contenant `pattern`).
	function client.findText(root, pattern)
		for _, descendant in root:GetDescendants() do
			if descendant:IsA("TextLabel") and string.find(descendant.Text, pattern, 1, true) then
				return descendant
			end
		end
		return nil
	end

	function client.findButton(root, labelPattern)
		for _, descendant in root:GetDescendants() do
			if descendant:IsA("GuiButton") then
				local label = descendant:FindFirstChild("Label")
				if label and string.find(label.Text, labelPattern, 1, true) then
					return descendant
				end
			end
		end
		return nil
	end

	function client.click(button)
		assert(button, "bouton introuvable")
		Fake.fire(button, "Activated")
		Fake.pump(0) -- exécute les tâches différées (task.defer)
	end

	function client.press(actionName)
		local entry = bound[actionName]
		assert(entry, "action non liée : " .. actionName)
		entry.handler(actionName, roblox.Enum.UserInputState.Begin, {})
	end

	function client.pump(seconds)
		Fake.pump(seconds or 0)
	end

	function client.resize(size)
		FakeRoblox.defaults.AbsoluteSize = size
		for _, gui in playerGui:GetChildren() do
			gui:GetPropertyChangedSignal("AbsoluteSize"):Fire()
		end
	end

	return client
end

return ClientHarness
