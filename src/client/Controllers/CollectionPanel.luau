-- Collection : mèmes posés dans la base, réserve, et album de tous les mèmes.
-- « Poser » depuis un socle ouvre ce panneau en mode choix pour ce socle.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Format = require(ReplicatedStorage.Shared.Format)
local Client = script.Parent.Parent
local Theme = require(Client.Ui.Theme)
local Ui = require(Client.Ui.Ui)
local Layout = require(Client.Ui.Layout)
local MemePreview = require(Client.Ui.MemePreview)
local ClientState = require(script.Parent.ClientState)
local Notifications = require(script.Parent.Notifications)
local Panels = require(script.Parent.Panels)

local Colors = Theme.Colors

local CollectionPanel = {}

local screenGui: ScreenGui
local panel: any
local tabs: any
local summary: TextLabel
local content: ScrollingFrame
local pickSlot: number? = nil
local lastSignature = ""

local function grid(order: number): Frame
	local screen = screenGui.AbsoluteSize
	local columns = Layout.gridColumns(Layout.panel(screen).width - 40)
	local frame = Ui.frame(content, {
		Name = "Grid",
		Size = UDim2.new(1, 0, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		LayoutOrder = order,
	})
	Ui.new("UIGridLayout", {
		CellSize = UDim2.new(1 / columns, -10 * (columns - 1) / columns, 0, Layout.cardHeight(screen) - 20),
		CellPadding = UDim2.fromOffset(10, 10),
		SortOrder = Enum.SortOrder.LayoutOrder,
		Parent = frame,
	})
	return frame
end

local function memeCard(parent: Instance, order: number, memeId: string, silhouette: boolean?): Frame
	local def = Config.Memes.Defs[memeId]
	local rarity = Config.Rarities.Defs[def.rarity]
	local frame = Ui.new("Frame", {
		Name = "Card",
		BackgroundColor3 = Colors.PanelAlt,
		BorderSizePixel = 0,
		LayoutOrder = order,
		Parent = parent,
	})
	Ui.corner(frame, 14)
	Ui.padding(frame, 10)
	local holder = Ui.new("Frame", {
		Name = "PreviewHolder",
		BackgroundColor3 = Colors.White,
		BorderSizePixel = 0,
		Size = UDim2.fromOffset(72, 72),
		Parent = frame,
	})
	Ui.corner(holder, 12)
	Ui.stroke(holder, if silhouette then Colors.Line else rarity.color, 3)
	MemePreview.create(holder, memeId, silhouette)
	Ui.text(frame, {
		Name = "MemeName",
		Text = if silhouette then "???" else def.name,
		Font = Theme.Fonts.Title,
		TextSize = Theme.TextSize.Large,
		Position = UDim2.fromOffset(82, 0),
		Size = UDim2.new(1, -82, 0, 26),
		TextWrapped = false,
		TextTruncate = Enum.TextTruncate.AtEnd,
	})
	if silhouette then
		Ui.text(frame, {
			Text = "À trouver : " .. Config.Biomes.Defs[def.biome].displayName,
			TextSize = Theme.TextSize.Small,
			TextColor3 = Colors.InkSoft,
			Position = UDim2.fromOffset(82, 28),
			Size = UDim2.new(1, -82, 0, 36),
			TextYAlignment = Enum.TextYAlignment.Top,
		})
	else
		Ui.chip(frame, rarity.displayName, rarity.color, { Position = UDim2.fromOffset(82, 28) })
		Ui.text(frame, {
			Text = string.format("+%d / %d s", def.income, Config.Economy.IncomeTickSeconds),
			Font = Theme.Fonts.Bold,
			TextSize = Theme.TextSize.Small,
			TextColor3 = Colors.Success,
			Position = UDim2.fromOffset(82, 54),
			Size = UDim2.new(1, -82, 0, 20),
		})
	end
	return frame
end

local function bottomButton(frame: Frame, text: string, color: Color3, side: string): TextButton
	local button = Ui.button(frame, {
		text = text,
		color = color,
		size = UDim2.new(0.48, 0, 0, 44),
		name = side,
		textSize = Theme.TextSize.Small,
	})
	button.AnchorPoint = if side == "Left" then Vector2.new(0, 1) else Vector2.new(1, 1)
	button.Position = if side == "Left" then UDim2.fromScale(0, 1) else UDim2.fromScale(1, 1)
	return button
end

local function emptyState(text: string, buttonText: string?, onClick: (() -> ())?)
	local frame = Ui.frame(content, { Size = UDim2.new(1, 0, 0, 120), LayoutOrder = 1 })
	Ui.text(frame, {
		Text = text,
		Font = Theme.Fonts.Bold,
		TextXAlignment = Enum.TextXAlignment.Center,
		Size = UDim2.new(1, 0, 0, 56),
	})
	if buttonText and onClick then
		local button = Ui.button(frame, { text = buttonText, color = Colors.Primary, size = UDim2.fromOffset(220, 44) })
		button.AnchorPoint = Vector2.new(0.5, 0)
		button.Position = UDim2.new(0.5, 0, 0, 64)
		Ui.onClick(button, onClick)
	end
end

local function request(key: string, action: string, ...: any)
	local args = table.pack(...)
	task.spawn(function()
		local result = ClientState.requestOnce(key, action, table.unpack(args, 1, args.n))
		if result and not result.ok then
			Notifications.result(result)
		elseif result and result.ok and action == "SellMeme" then
			Notifications.show("Success", result.data.name .. " revendu : +" .. Format.coins(result.data.amount) .. " pièces.")
		end
	end)
end

local function buildBase()
	local view = ClientState.view
	local placed = ClientState.placedMemes()
	if #placed == 0 then
		emptyState("Aucun mème posé. Pose un mème de ta réserve pour gagner des pièces !", "Voir la réserve", function()
			tabs.select("Storage")
		end)
		return
	end
	local section = grid(1)
	local storageFull = #ClientState.storedMemes() >= view.capacity.storage
	for order, meme in placed do
		local frame = memeCard(section, order, meme.id)
		Ui.text(frame, {
			Text = "Socle " .. meme.slot,
			TextSize = Theme.TextSize.Small,
			TextColor3 = Colors.InkSoft,
			AnchorPoint = Vector2.new(0, 1),
			Position = UDim2.new(0, 0, 1, -12),
			Size = UDim2.new(0.5, 0, 0, 20),
		})
		local button = bottomButton(frame, "Ranger", Colors.Secondary, "Right")
		if meme.busy then
			Ui.setButton(button, { text = "Emporté !", enabled = false })
		elseif storageFull then
			Ui.setButton(button, { text = "Réserve pleine", enabled = false })
		end
		Ui.onClick(button, function()
			Ui.setButton(button, { text = "…", enabled = false })
			request("store:" .. meme.uid, "StoreMeme", meme.slot)
		end)
	end
end

local function buildStorage()
	local stored = ClientState.storedMemes()
	if pickSlot then
		Ui.text(content, {
			Text = "Choisis un mème pour le socle " .. pickSlot .. ".",
			Font = Theme.Fonts.Bold,
			TextColor3 = Colors.Secondary,
			Size = UDim2.new(1, 0, 0, 24),
			LayoutOrder = 0,
		})
	end
	if #stored == 0 then
		emptyState("Ta réserve est vide. Achète des mèmes dans les kiosques des biomes !", "Ouvrir la boutique", function()
			Panels.open("Shop")
		end)
		return
	end
	local section = grid(1)
	local freeSlots = ClientState.freeSlots()
	for order, meme in stored do
		local def = Config.Memes.Defs[meme.id]
		local frame = memeCard(section, order, meme.id)
		local place = bottomButton(frame, "Poser", Colors.Success, "Left")
		if freeSlots == 0 then
			Ui.setButton(place, { text = "Socles pleins", enabled = false })
		end
		Ui.onClick(place, function()
			Ui.setButton(place, { text = "…", enabled = false })
			local slot = pickSlot
			pickSlot = nil
			request("place:" .. meme.uid, "PlaceMeme", meme.uid, slot)
		end)
		local refund = math.floor(def.price * Config.Economy.SellRefundRatio)
		local sell = bottomButton(frame, "Vendre +" .. Format.coins(refund), Colors.InkSoft, "Right")
		local armed = false
		Ui.onClick(sell, function()
			if not armed then
				armed = true
				Ui.setButton(sell, { text = "Confirmer ?", color = Colors.Warning })
				task.delay(3, function()
					armed = false
					if sell.Parent then
						Ui.setButton(sell, { text = "Vendre +" .. Format.coins(refund), color = Colors.InkSoft })
					end
				end)
				return
			end
			Ui.setButton(sell, { text = "…", enabled = false })
			request("sell:" .. meme.uid, "SellMeme", meme.uid)
		end)
	end
end

local function buildAlbum()
	local album = ClientState.view.album or {}
	Ui.text(content, {
		Text = string.format("%d / %d mèmes collectionnés", #album, #Config.Memes.Order),
		Font = Theme.Fonts.Bold,
		Size = UDim2.new(1, 0, 0, 24),
		LayoutOrder = 0,
	})
	local section = grid(1)
	for order, memeId in Config.Memes.Order do
		local owned = table.find(album, memeId) ~= nil
		local frame = memeCard(section, order, memeId, not owned)
		if owned then
			Ui.text(frame, {
				Text = Config.Memes.Defs[memeId].tagline,
				TextSize = Theme.TextSize.Small,
				TextColor3 = Colors.InkSoft,
				AnchorPoint = Vector2.new(0, 1),
				Position = UDim2.fromScale(0, 1),
				Size = UDim2.new(1, 0, 0, 40),
				TextYAlignment = Enum.TextYAlignment.Bottom,
			})
		end
	end
end

local function updateSummary()
	local view = ClientState.view
	if not view.ready then
		summary.Text = "Chargement…"
		return
	end
	summary.Text = string.format(
		"Socles %d/%d · Réserve %d/%d · +%s pièces / %d s",
		#ClientState.placedMemes(),
		view.capacity.slots,
		#ClientState.storedMemes(),
		view.capacity.storage,
		Format.coins(view.incomePerTick),
		Config.Economy.IncomeTickSeconds
	)
end

function CollectionPanel.build(tab: string)
	Ui.clear(content)
	updateSummary()
	if tab == "Storage" then
		buildStorage()
	elseif tab == "Album" then
		buildAlbum()
	else
		buildBase()
	end
end

-- Signature de ce qui change l'affichage (hors solde), pour ne reconstruire qu'au besoin.
local function signature(view: any): string
	if not view.ready then
		return "loading"
	end
	local parts = { tostring(view.capacity.slots), tostring(view.capacity.storage), tostring(#(view.album or {})) }
	for _, meme in view.memes do
		table.insert(parts, meme.uid .. ":" .. meme.slot .. ":" .. tostring(meme.busy))
	end
	return table.concat(parts, "|")
end

function CollectionPanel.init(root: ScreenGui)
	screenGui = root
	panel = Ui.panel(root, "Mes mèmes", "cards", Panels.close)
	tabs = Ui.tabs(panel.body, {
		{ id = "Base", label = "Ma base" },
		{ id = "Storage", label = "Réserve" },
		{ id = "Album", label = "Album" },
	}, function(id)
		if id ~= "Storage" then
			pickSlot = nil
		end
		CollectionPanel.build(id)
	end)
	summary = Ui.text(panel.body, {
		Name = "Summary",
		Font = Theme.Fonts.Bold,
		TextSize = Theme.TextSize.Small,
		TextColor3 = Colors.InkSoft,
		Position = UDim2.fromOffset(0, 50),
		Size = UDim2.new(1, 0, 0, 22),
	})
	content = Ui.scroll(panel.body, { Size = UDim2.new(1, 0, 1, -78), Position = UDim2.fromOffset(0, 78) })
	Ui.list(content, { Padding = UDim.new(0, 10) })
	Ui.padding(content, 2, 12, 8, 2)

	ClientState.changed:Connect(function(view)
		if Panels.current() ~= "Collection" then
			return
		end
		local current = signature(view)
		if current ~= lastSignature then
			lastSignature = current
			CollectionPanel.build(tabs.selected())
		else
			updateSummary()
		end
	end)

	Panels.register("Collection", {
		panel = panel,
		onOpen = function(args)
			lastSignature = signature(ClientState.view)
			pickSlot = args and args.pickSlot or nil
			if pickSlot then
				tabs.select("Storage")
			elseif args and args.tab then
				tabs.select(args.tab)
			else
				CollectionPanel.build(tabs.selected())
			end
		end,
		onClose = function()
			pickSlot = nil
			Ui.clear(content)
		end,
	})
end

return CollectionPanel
