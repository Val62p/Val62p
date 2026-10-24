-- Boutique : mèmes des kiosques découverts, améliorations, cosmétiques.
-- Prix et effet affichés avant achat, état d'achat, confirmation courte pour les achats
-- importants, retours d'erreur traduits. Bouton Robux seulement pour les produits réellement
-- configurés par le serveur (l'achat est accordé par le serveur, jamais par ce client).
local CollectionService = game:GetService("CollectionService")
local MarketplaceService = game:GetService("MarketplaceService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Format = require(ReplicatedStorage.Shared.Format)
local MapLayout = require(ReplicatedStorage.Shared.MapLayout)
local Tags = require(ReplicatedStorage.Shared.Tags)
local Client = script.Parent.Parent
local Theme = require(Client.Ui.Theme)
local Ui = require(Client.Ui.Ui)
local Layout = require(Client.Ui.Layout)
local MemePreview = require(Client.Ui.MemePreview)
local ClientState = require(script.Parent.ClientState)
local Notifications = require(script.Parent.Notifications)
local Panels = require(script.Parent.Panels)

local Colors = Theme.Colors

local ShopPanel = {}

local CONFIRM_THRESHOLD = 500
local CONFIRM_SECONDS = 3

local screenGui: ScreenGui
local panel: any
local tabs: any
local content: ScrollingFrame
local updaters: { () -> () } = {}
local timers: { { label: TextLabel, biomeId: string } } = {}
local pedestals: { [string]: { [number]: BasePart } } = {}
local robuxPrices: { [number]: number | false } = {}

local function grid(parent: Instance, order: number): Frame
	local screen = screenGui.AbsoluteSize
	local width = Layout.panel(screen).width - 40
	local columns = Layout.gridColumns(width)
	local frame = Ui.frame(parent, {
		Name = "Grid",
		Size = UDim2.new(1, 0, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		LayoutOrder = order,
	})
	Ui.new("UIGridLayout", {
		CellSize = UDim2.new(1 / columns, -10 * (columns - 1) / columns, 0, Layout.cardHeight(screen)),
		CellPadding = UDim2.fromOffset(10, 10),
		SortOrder = Enum.SortOrder.LayoutOrder,
		Parent = frame,
	})
	return frame
end

local function card(parent: Instance, order: number): Frame
	local frame = Ui.new("Frame", {
		Name = "Card",
		BackgroundColor3 = Colors.PanelAlt,
		BorderSizePixel = 0,
		LayoutOrder = order,
		Parent = parent,
	})
	Ui.corner(frame, 14)
	Ui.padding(frame, 10)
	return frame
end

local function sectionTitle(parent: Instance, text: string, order: number): TextLabel
	return Ui.text(parent, {
		Name = "Section",
		Text = text,
		Font = Theme.Fonts.Title,
		TextSize = Theme.TextSize.Large,
		Size = UDim2.new(1, 0, 0, 28),
		LayoutOrder = order,
	})
end

local function priceRow(parent: Instance, price: number)
	local row = Ui.frame(parent, {
		Name = "Price",
		AnchorPoint = Vector2.new(0, 1),
		Position = UDim2.new(0, 0, 1, -10),
		Size = UDim2.new(0.45, 0, 0, 26),
	})
	Ui.icon(row, "coin", 24, nil, { Position = UDim2.fromOffset(0, 1) })
	Ui.text(row, {
		Text = Format.coins(price),
		Font = Theme.Fonts.Bold,
		TextSize = Theme.TextSize.Large,
		Size = UDim2.new(1, -30, 1, 0),
		Position = UDim2.fromOffset(30, 0),
		TextWrapped = false,
	})
end

local function actionButton(parent: Instance, text: string, color: Color3): TextButton
	return Ui.button(parent, {
		text = text,
		color = color,
		size = UDim2.new(0.52, 0, 0, 44),
		name = "Action",
	}) :: any
end

-- Bouton d'achat avec confirmation courte pour les montants importants.
local function purchaseButton(
	parent: Instance,
	price: number,
	key: string,
	baseText: string,
	baseColor: Color3,
	blocked: () -> string?,
	perform: () -> ()
)
	local button = actionButton(parent, baseText, baseColor)
	button.AnchorPoint = Vector2.new(1, 1)
	button.Position = UDim2.fromScale(1, 1)
	local armed = false
	local function update()
		local view = ClientState.view
		if not view.ready or ClientState.isPending(key) then
			Ui.setButton(button, { text = "…", enabled = false })
			return
		end
		local reason = blocked()
		if reason then
			Ui.setButton(button, { text = reason, enabled = false })
		elseif view.coins < price then
			Ui.setButton(button, { text = "Il manque " .. Format.coins(price - view.coins), enabled = false })
		elseif armed then
			Ui.setButton(button, { text = "Confirmer ?", enabled = true, color = Colors.Warning })
		else
			Ui.setButton(button, { text = baseText, enabled = true, color = baseColor })
		end
	end
	Ui.onClick(button, function()
		local view = ClientState.view
		local needsConfirm = price >= CONFIRM_THRESHOLD or price >= view.coins * 0.5
		if needsConfirm and not armed then
			armed = true
			update()
			task.delay(CONFIRM_SECONDS, function()
				armed = false
				if button.Parent then
					update()
				end
			end)
			return
		end
		armed = false
		task.spawn(function()
			perform()
			if button.Parent then
				update()
			end
		end)
		task.defer(update)
	end)
	table.insert(updaters, update)
	update()
	return button
end

---------------------------------------------------------------------------
-- Onglet Mèmes
---------------------------------------------------------------------------

local function memeCard(parent: Instance, order: number, biomeId: string, index: number, pedestal: BasePart)
	local memeId = pedestal:GetAttribute("MemeId")
	local version = pedestal:GetAttribute("OfferVersion")
	local def = Config.Memes.Defs[memeId]
	if not def then
		return
	end
	local rarity = Config.Rarities.Defs[def.rarity]
	local frame = card(parent, order)
	local previewHolder = Ui.new("Frame", {
		Name = "PreviewHolder",
		BackgroundColor3 = Colors.White,
		BorderSizePixel = 0,
		Size = UDim2.fromOffset(84, 84),
		Parent = frame,
	})
	Ui.corner(previewHolder, 12)
	Ui.stroke(previewHolder, rarity.color, 3)
	MemePreview.create(previewHolder, memeId)
	Ui.text(frame, {
		Text = def.name,
		Font = Theme.Fonts.Title,
		TextSize = Theme.TextSize.Large,
		Position = UDim2.fromOffset(94, 0),
		Size = UDim2.new(1, -94, 0, 26),
		TextWrapped = false,
		TextTruncate = Enum.TextTruncate.AtEnd,
	})
	Ui.chip(frame, rarity.displayName, rarity.color, { Position = UDim2.fromOffset(94, 30) })
	Ui.text(frame, {
		Text = string.format("+%d pièces / %d s", def.income, Config.Economy.IncomeTickSeconds),
		Font = Theme.Fonts.Bold,
		TextSize = Theme.TextSize.Small,
		TextColor3 = Colors.Success,
		Position = UDim2.fromOffset(94, 58),
		Size = UDim2.new(1, -94, 0, 20),
	})
	priceRow(frame, def.price)
	purchaseButton(frame, def.price, "buy:" .. biomeId .. index, "Acheter", Colors.Primary, function()
		if not ClientState.hasRoom() then
			return "Plein"
		end
		return nil
	end, function()
		local result = ClientState.requestOnce("buy:" .. biomeId .. index, "BuyOffer", biomeId, index, version)
		if result and result.ok then
			local placed = result.data and result.data.slot and result.data.slot > 0
			Notifications.show(
				"Success",
				def.name .. (if placed then " est posé dans ta base !" else " rejoint ta réserve : pose-le depuis « Mèmes ».")
			)
		else
			Notifications.result(result)
		end
	end)
end

local function buildMemes()
	local order = 0
	for _, biomeId in Config.Biomes.Order do
		local biome = Config.Biomes.Defs[biomeId]
		order += 1
		local header = Ui.frame(content, { Name = "Header", Size = UDim2.new(1, 0, 0, 28), LayoutOrder = order })
		sectionTitle(header, biome.displayName, 0).Size = UDim2.new(0.5, 0, 1, 0)
		local timer = Ui.text(header, {
			Name = "Timer",
			Text = "",
			Font = Theme.Fonts.Body,
			TextSize = Theme.TextSize.Small,
			TextColor3 = Colors.InkSoft,
			TextXAlignment = Enum.TextXAlignment.Right,
			Size = UDim2.new(0.5, 0, 1, 0),
			Position = UDim2.fromScale(0.5, 0),
		})
		order += 1
		local section = grid(content, order)
		if ClientState.isDiscovered(biomeId) then
			table.insert(timers, { label = timer, biomeId = biomeId })
			for index = 1, Config.Map.Kiosk.Pedestals do
				local pedestal = pedestals[biomeId] and pedestals[biomeId][index]
				if pedestal then
					memeCard(section, index, biomeId, index, pedestal)
				end
			end
		else
			local locked = card(section, 1)
			Ui.icon(locked, "lock", 40, Colors.InkSoft, { Position = UDim2.fromOffset(0, 4) })
			Ui.text(locked, {
				Text = "Explore " .. biome.displayName .. " pour découvrir ses arrivages.",
				Font = Theme.Fonts.Bold,
				Position = UDim2.fromOffset(50, 0),
				Size = UDim2.new(1, -50, 0, 48),
			})
			Ui.text(locked, {
				Text = biome.description,
				TextSize = Theme.TextSize.Small,
				TextColor3 = Colors.InkSoft,
				Position = UDim2.fromOffset(0, 56),
				Size = UDim2.new(1, 0, 0, 60),
				TextYAlignment = Enum.TextYAlignment.Top,
			})
		end
	end
end

---------------------------------------------------------------------------
-- Onglets Améliorations et Cosmétiques
---------------------------------------------------------------------------

local function effectText(def: any, from: any, to: any?): string
	local function value(level: any): string
		if def.valueFormat == "Multiplier" then
			return Format.multiplier(level.value)
		end
		return tostring(level.value)
	end
	local unit = if def.valueFormat == "Radius" then " (rayon d'interception)" elseif def.unit ~= "" then " " .. def.unit else ""
	if not to then
		return value(from) .. unit .. " · niveau maximum"
	end
	return value(from) .. " → " .. value(to) .. unit
end

-- Produit Robux configuré qui avance d'un niveau l'amélioration `upgradeId`.
local function robuxProductFor(upgradeId: string): (string?, number?)
	local available = ClientState.view.robuxProducts or {}
	for key, def in Config.Monetization.DeveloperProducts do
		if def.kind == "UpgradeLevel" and def.upgradeId == upgradeId and available[key] then
			return key, available[key]
		end
	end
	return nil, nil
end

-- Prix en Robux lu auprès de Roblox (mis en cache) ; le bouton affiche « Robux » en attendant.
local function robuxPrice(productId: number): number?
	local cached = robuxPrices[productId]
	if cached == nil then
		robuxPrices[productId] = false
		task.spawn(function()
			local ok, info = pcall(function()
				return MarketplaceService:GetProductInfo(productId, Enum.InfoType.Product)
			end)
			if ok and type(info) == "table" and type(info.PriceInRobux) == "number" then
				robuxPrices[productId] = info.PriceInRobux
				-- Reconstruction différée : jamais au milieu d'une construction en cours.
				task.defer(function()
					if Panels.current() == "Shop" and tabs.selected() == "Upgrades" then
						ShopPanel.build("Upgrades")
					end
				end)
			end
		end)
		return nil
	end
	return if cached then cached else nil
end

local function robuxButton(parent: Instance, productKey: string, productId: number)
	local price = robuxPrice(productId)
	local button = actionButton(parent, if price then "R$ " .. price else "Robux", Colors.Success)
	button.AnchorPoint = Vector2.new(1, 1)
	button.Position = UDim2.fromScale(1, 1)
	button.Size = UDim2.new(0.48, 0, 0, 44)
	Ui.onClick(button, function()
		task.spawn(function()
			-- Le serveur vérifie puis ouvre la fenêtre d'achat officielle de Roblox.
			local result = ClientState.requestOnce("robux:" .. productKey, "BuyWithRobux", productKey)
			if result and not result.ok then
				Notifications.result(result)
			end
		end)
	end)
	return button
end

local function buildUpgrades()
	local section = grid(content, 1)
	for order, upgradeId in Config.Upgrades.Order do
		local def = Config.Upgrades.Defs[upgradeId]
		local frame = card(section, order)
		local level = (ClientState.view.upgrades or {})[upgradeId] or 1
		local current, nextLevel = def.levels[level], def.levels[level + 1]
		Ui.text(frame, {
			Text = def.displayName,
			Font = Theme.Fonts.Title,
			TextSize = Theme.TextSize.Large,
			Size = UDim2.new(1, 0, 0, 26),
		})
		Ui.text(frame, {
			Text = string.format("Niveau %d / %d · %s", level, #def.levels, effectText(def, current, nextLevel)),
			Font = Theme.Fonts.Bold,
			TextSize = Theme.TextSize.Small,
			TextColor3 = Colors.Secondary,
			Position = UDim2.fromOffset(0, 28),
			Size = UDim2.new(1, 0, 0, 32),
			TextYAlignment = Enum.TextYAlignment.Top,
		})
		Ui.text(frame, {
			Text = def.description,
			TextSize = Theme.TextSize.Small,
			TextColor3 = Colors.InkSoft,
			Position = UDim2.fromOffset(0, 62),
			Size = UDim2.new(1, 0, 0, 38),
			TextYAlignment = Enum.TextYAlignment.Top,
		})
		if nextLevel then
			local productKey, productId = robuxProductFor(upgradeId)
			local coinsButton = purchaseButton(
				frame,
				nextLevel.price,
				"upgrade:" .. upgradeId,
				if productKey then Format.coins(nextLevel.price) .. " pièces" else "Améliorer",
				Colors.Secondary,
				function()
					return nil
				end,
				function()
					local result = ClientState.requestOnce("upgrade:" .. upgradeId, "BuyUpgrade", upgradeId)
					Notifications.result(result, def.displayName .. " : niveau " .. tostring(level + 1) .. " !")
					if result and result.ok then
						task.defer(ShopPanel.build, "Upgrades")
					end
				end
			)
			if productKey and productId then
				-- Deux choix côte à côte : pièces (gratuit) ou Robux (raccourci d'un niveau).
				coinsButton.AnchorPoint = Vector2.new(0, 1)
				coinsButton.Position = UDim2.fromScale(0, 1)
				coinsButton.Size = UDim2.new(0.48, 0, 0, 44)
				robuxButton(frame, productKey, productId)
			else
				priceRow(frame, nextLevel.price)
			end
		else
			local done = actionButton(frame, "Maximum", Colors.Success)
			done.AnchorPoint = Vector2.new(1, 1)
			done.Position = UDim2.fromScale(1, 1)
			Ui.setButton(done, { enabled = false })
		end
	end
end

local function buildCosmetics()
	local section = grid(content, 1)
	local view = ClientState.view
	local baseLayout = view.ready and view.baseIndex > 0 and MapLayout.base(view.baseIndex)
	for order, cosmeticId in Config.Cosmetics.Order do
		local def = Config.Cosmetics.Defs[cosmeticId]
		local frame = card(section, order)
		local baseColor = if baseLayout then baseLayout.color else Colors.Secondary
		local swatch = Ui.new("Frame", {
			Name = "Swatch",
			BackgroundColor3 = def.floor or baseColor:Lerp(Colors.White, 0.72),
			BorderSizePixel = 0,
			Size = UDim2.fromOffset(64, 64),
			Parent = frame,
		})
		Ui.corner(swatch, 12)
		Ui.stroke(swatch, def.trim or baseColor, 6)
		Ui.text(frame, {
			Text = def.displayName,
			Font = Theme.Fonts.Title,
			TextSize = Theme.TextSize.Large,
			Position = UDim2.fromOffset(76, 0),
			Size = UDim2.new(1, -76, 0, 26),
		})
		Ui.text(frame, {
			Text = def.description,
			TextSize = Theme.TextSize.Small,
			TextColor3 = Colors.InkSoft,
			Position = UDim2.fromOffset(76, 28),
			Size = UDim2.new(1, -76, 0, 44),
			TextYAlignment = Enum.TextYAlignment.Top,
		})
		local owned = ClientState.ownsCosmetic(cosmeticId)
		local equipped = view.ready and view.cosmetics.equipped == cosmeticId
		if equipped then
			local button = actionButton(frame, "Équipé", Colors.Success)
			button.AnchorPoint = Vector2.new(1, 1)
			button.Position = UDim2.fromScale(1, 1)
			Ui.setButton(button, { enabled = false })
		elseif owned then
			local button = actionButton(frame, "Équiper", Colors.Secondary)
			button.AnchorPoint = Vector2.new(1, 1)
			button.Position = UDim2.fromScale(1, 1)
			Ui.onClick(button, function()
				Ui.setButton(button, { text = "…", enabled = false })
				task.spawn(function()
					local result = ClientState.requestOnce("equip:" .. cosmeticId, "EquipCosmetic", cosmeticId)
					Notifications.result(result, "Thème « " .. def.displayName .. " » appliqué à ta base.")
					ShopPanel.build("Cosmetics")
				end)
			end)
		else
			priceRow(frame, def.price)
			purchaseButton(frame, def.price, "cosmetic:" .. cosmeticId, "Acheter", Colors.Primary, function()
				return nil
			end, function()
				local result = ClientState.requestOnce("cosmetic:" .. cosmeticId, "BuyCosmetic", cosmeticId)
				Notifications.result(result, "Thème « " .. def.displayName .. " » débloqué et appliqué !")
				if result and result.ok then
					task.defer(ShopPanel.build, "Cosmetics")
				end
			end)
		end
	end
end

---------------------------------------------------------------------------

local function updateTimers()
	for _, timer in timers do
		local kiosk = nil
		for _, model in CollectionService:GetTagged(Tags.Kiosk) do
			if model:GetAttribute("BiomeId") == timer.biomeId then
				kiosk = model
				break
			end
		end
		local nextAt = kiosk and kiosk:GetAttribute("NextRotationAt") or 0
		local remaining = nextAt - ClientState.serverNow()
		timer.label.Text = if remaining > 0 then "Nouvel arrivage dans " .. Format.duration(remaining) else "Arrivage en cours…"
	end
end

function ShopPanel.build(tab: string)
	if not content then
		return
	end
	Ui.clear(content)
	table.clear(updaters)
	table.clear(timers)
	if tab == "Upgrades" then
		buildUpgrades()
	elseif tab == "Cosmetics" then
		buildCosmetics()
	else
		buildMemes()
		updateTimers()
	end
	content.CanvasPosition = Vector2.zero
end

local function trackPedestal(part: Instance)
	if not part:IsA("BasePart") then
		return
	end
	local biomeId = part:GetAttribute("BiomeId")
	local index = part:GetAttribute("Pedestal")
	if type(biomeId) ~= "string" or type(index) ~= "number" then
		return
	end
	pedestals[biomeId] = pedestals[biomeId] or {}
	pedestals[biomeId][index] = part
	part:GetAttributeChangedSignal("OfferVersion"):Connect(function()
		if Panels.current() == "Shop" and tabs.selected() == "Memes" then
			ShopPanel.build("Memes")
		end
	end)
end

function ShopPanel.init(root: ScreenGui)
	screenGui = root
	panel = Ui.panel(root, "Boutique", "basket", Panels.close)
	tabs = Ui.tabs(panel.body, {
		{ id = "Memes", label = "Mèmes" },
		{ id = "Upgrades", label = "Améliorations" },
		{ id = "Cosmetics", label = "Cosmétiques" },
	}, function(id)
		ShopPanel.build(id)
	end)
	content = Ui.scroll(panel.body, { Size = UDim2.new(1, 0, 1, -52), Position = UDim2.fromOffset(0, 52) })
	Ui.list(content, { Padding = UDim.new(0, 10) })
	Ui.padding(content, 2, 12, 8, 2)

	for _, part in CollectionService:GetTagged(Tags.Pedestal) do
		trackPedestal(part)
	end
	CollectionService:GetInstanceAddedSignal(Tags.Pedestal):Connect(trackPedestal)

	local lastDiscovered = 0
	ClientState.changed:Connect(function(view)
		if Panels.current() ~= "Shop" then
			return
		end
		local discovered = #(view.discovered or {})
		if discovered ~= lastDiscovered and tabs.selected() == "Memes" then
			lastDiscovered = discovered
			ShopPanel.build("Memes")
			return
		end
		for _, update in updaters do
			update()
		end
	end)

	Panels.register("Shop", {
		panel = panel,
		onOpen = function(args)
			lastDiscovered = #(ClientState.view.discovered or {})
			if args and args.tab then
				tabs.select(args.tab)
			else
				ShopPanel.build(tabs.selected())
			end
		end,
		onClose = function()
			Ui.clear(content)
			table.clear(updaters)
			table.clear(timers)
		end,
	})

	task.spawn(function()
		while true do
			task.wait(1)
			if Panels.current() == "Shop" then
				updateTimers()
			end
		end
	end)
end

return ShopPanel
