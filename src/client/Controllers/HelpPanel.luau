-- Aide et réglages : règles du jeu (générées depuis la configuration, donc toujours exactes),
-- mode Zen (protection accessible à tous), commandes, état de la sauvegarde, tutoriel.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Format = require(ReplicatedStorage.Shared.Format)
local Client = script.Parent.Parent
local Theme = require(Client.Ui.Theme)
local Ui = require(Client.Ui.Ui)
local ClientState = require(script.Parent.ClientState)
local Notifications = require(script.Parent.Notifications)
local Panels = require(script.Parent.Panels)

local Colors = Theme.Colors
local TheftCfg = Config.Theft

local HelpPanel = {}

local panel: any
local content: ScrollingFrame
local zenButton: TextButton
local zenText: TextLabel
local saveText: TextLabel
local onReplayTutorial: () -> () = function() end

local function minutes(seconds: number): string
	local m = seconds / 60
	if m >= 1 and m % 1 == 0 then
		return string.format("%d min", m)
	end
	return string.format("%d s", seconds)
end

local function rules(): { { title: string, lines: { string } } }
	return {
		{
			title = "Le but",
			lines = {
				"Collectionne des mèmes, installe-les sur les socles de ta base : ils rapportent des pièces toutes les "
					.. Config.Economy.IncomeTickSeconds
					.. " secondes.",
				"Les kiosques de chaque biome renouvellent leurs arrivages toutes les "
					.. minutes(Config.Map.Kiosk.RotationSeconds)
					.. ". Explore les biomes pour les débloquer dans la boutique.",
				"Les raretés (Commun, Rare, Épique, Légendaire) sont des catégories de collection : on les achète en pièces, jamais au hasard.",
			},
		},
		{
			title = "Le vol d'opportunité",
			lines = {
				"Dans une base sans surveillance, tu peux tenter d'emporter un mème : reste "
					.. TheftCfg.LockpickSeconds
					.. " s près du socle pendant le crochetage, puis ramène-le dans ta base en moins de "
					.. TheftCfg.CarrySeconds
					.. " s.",
				"Pendant le transport, tout le monde te voit et tu marches moins vite.",
				"Le mème revient chez son propriétaire si celui-ci te touche, si tu entres dans la zone surveillée de la place centrale, si tu annules, si le temps est écoulé ou si tu quittes la partie.",
				"Impossible de voler si le propriétaire est dans sa base, ni d'emporter le dernier mème d'une base.",
			},
		},
		{
			title = "Protections",
			lines = {
				"En arrivant, ta base est protégée " .. minutes(TheftCfg.JoinShieldSeconds) .. " (tenter un vol met fin à cette protection).",
				"Après un vol subi : protection de "
					.. minutes(TheftCfg.VictimShieldSeconds)
					.. " et une assurance de "
					.. math.floor(TheftCfg.InsuranceRatio * 100)
					.. " % du prix du mème.",
				"Un même joueur ne peut pas viser ta base en boucle : il doit attendre "
					.. minutes(TheftCfg.PairCooldownSuccessSeconds)
					.. " après un vol réussi.",
				"Mode Zen : personne ne peut emprunter tes mèmes et tu ne peux pas en emprunter. Tu peux le changer toutes les "
					.. minutes(TheftCfg.ZenToggleCooldownSeconds)
					.. ".",
			},
		},
		{
			title = "Commandes",
			lines = {
				"Approche-toi d'un socle ou d'un piédestal : l'action s'affiche (touche E, bouton X de la manette, ou toucher l'écran).",
				"Raccourcis clavier : B boutique, C mèmes, H aller à ta base, F1 aide. Manette : Y boutique, L1 mèmes, R1 aide, B pour fermer.",
			},
		},
	}
end

local function refresh()
	local view = ClientState.view
	if not zenButton then
		return
	end
	if not view.ready then
		Ui.setButton(zenButton, { text = "…", enabled = false })
		return
	end
	local now = ClientState.serverNow()
	local cooling = view.zenCooldownUntil > now
	if view.zen then
		zenText.Text = "Mode Zen activé : tes mèmes sont à l'abri, et tu ne peux pas en emprunter."
		Ui.setButton(zenButton, {
			text = if cooling then "Patiente " .. Format.duration(view.zenCooldownUntil - now) else "Désactiver le mode Zen",
			enabled = not cooling,
			color = Colors.InkSoft,
		})
	else
		zenText.Text = "Mode Zen désactivé : le vol d'opportunité est possible, dans les deux sens."
		Ui.setButton(zenButton, {
			text = if cooling then "Patiente " .. Format.duration(view.zenCooldownUntil - now) else "Activer le mode Zen",
			enabled = not cooling,
			color = Colors.Zen,
		})
	end
	saveText.Text = if view.saveEnabled
		then "Sauvegarde : active (automatique)."
		else "Sauvegarde : indisponible pour cette session (place non publiée ou service DataStore inaccessible)."
end

local function build()
	Ui.clear(content)
	local order = 0
	local function nextOrder(): number
		order += 1
		return order
	end

	-- Réglages en tête : protection accessible immédiatement.
	local zenCard = Ui.new("Frame", {
		Name = "Zen",
		BackgroundColor3 = Colors.PanelAlt,
		BorderSizePixel = 0,
		Size = UDim2.new(1, 0, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		LayoutOrder = nextOrder(),
		Parent = content,
	})
	Ui.corner(zenCard, 14)
	Ui.padding(zenCard, 10)
	Ui.list(zenCard, { Padding = UDim.new(0, 8) })
	Ui.text(zenCard, { Text = "Mode Zen", Font = Theme.Fonts.Title, TextSize = Theme.TextSize.Large, LayoutOrder = 1 })
	zenText = Ui.text(zenCard, {
		TextSize = Theme.TextSize.Small,
		TextColor3 = Colors.InkSoft,
		AutomaticSize = Enum.AutomaticSize.Y,
		LayoutOrder = 2,
	})
	zenButton = Ui.button(zenCard, { text = "…", color = Colors.Zen, layoutOrder = 3, size = UDim2.new(1, 0, 0, 44) })
	Ui.onClick(zenButton, function()
		Ui.setButton(zenButton, { text = "…", enabled = false })
		task.spawn(function()
			local result = ClientState.requestOnce("zen", "ToggleZen")
			if result and result.ok then
				Notifications.show("Success", if result.data.zen then "Mode Zen activé." else "Mode Zen désactivé.")
			else
				Notifications.result(result)
			end
			refresh()
		end)
	end)

	for _, section in rules() do
		Ui.text(content, {
			Text = section.title,
			Font = Theme.Fonts.Title,
			TextSize = Theme.TextSize.Large,
			Size = UDim2.new(1, 0, 0, 28),
			LayoutOrder = nextOrder(),
		})
		for _, line in section.lines do
			Ui.text(content, {
				Text = "•  " .. line,
				TextSize = Theme.TextSize.Body,
				Size = UDim2.new(1, 0, 0, 0),
				AutomaticSize = Enum.AutomaticSize.Y,
				TextYAlignment = Enum.TextYAlignment.Top,
				LayoutOrder = nextOrder(),
			})
		end
	end

	saveText = Ui.text(content, {
		TextSize = Theme.TextSize.Small,
		TextColor3 = Colors.InkSoft,
		Size = UDim2.new(1, 0, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		LayoutOrder = nextOrder(),
	})
	local replay = Ui.button(content, {
		text = "Revoir le tutoriel",
		color = Colors.Secondary,
		layoutOrder = nextOrder(),
		size = UDim2.new(1, 0, 0, 44),
	})
	Ui.onClick(replay, function()
		Panels.close()
		onReplayTutorial()
	end)
	refresh()
end

function HelpPanel.init(root: ScreenGui, replayTutorial: () -> ())
	onReplayTutorial = replayTutorial
	panel = Ui.panel(root, "Aide & réglages", "help", Panels.close)
	content = Ui.scroll(panel.body)
	Ui.list(content, { Padding = UDim.new(0, 8) })
	Ui.padding(content, 2, 12, 8, 2)
	ClientState.changed:Connect(function()
		if Panels.current() == "Help" then
			refresh()
		end
	end)
	Panels.register("Help", {
		panel = panel,
		onOpen = build,
	})
	task.spawn(function()
		while true do
			task.wait(1)
			if Panels.current() == "Help" then
				refresh()
			end
		end
	end)
end

return HelpPanel
