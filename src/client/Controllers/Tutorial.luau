-- Aide contextuelle au premier lancement : quelques étapes guidées par l'état réel du joueur,
-- un repère dans le monde, et un bouton « Passer ». Les règles restent dans le panneau Aide.
local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Config = require(ReplicatedStorage.Shared.Config)
local Tags = require(ReplicatedStorage.Shared.Tags)
local Client = script.Parent.Parent
local Theme = require(Client.Ui.Theme)
local Ui = require(Client.Ui.Ui)
local Layout = require(Client.Ui.Layout)
local ClientState = require(script.Parent.ClientState)

local Colors = Theme.Colors

local Tutorial = {}

type Step = { title: string, text: string, manual: boolean?, target: (() -> BasePart?)? }

local card: Frame
local titleLabel: TextLabel
local bodyLabel: TextLabel
local nextButton: TextButton
local skipButton: TextButton
local beacon: BillboardGui?
local beaconTarget: BasePart? = nil
local replaying = false
local manualStage: number? = nil

local function kioskSign(biomeId: string): BasePart?
	for _, model in CollectionService:GetTagged(Tags.Kiosk) do
		if model:GetAttribute("BiomeId") == biomeId then
			return model:FindFirstChild("KioskSign") :: BasePart?
		end
	end
	return nil
end

local function ownBaseSign(): BasePart?
	local index = ClientState.view.baseIndex
	for _, model in CollectionService:GetTagged(Tags.Base) do
		if model:GetAttribute("BaseIndex") == index then
			return model:FindFirstChild("Sign") :: BasePart?
		end
	end
	return nil
end

local STEPS: { Step } = {
	{
		title = "Bienvenue dans Steal a Meme !",
		text = "Va au kiosque de la Prairie Pop (suis le chemin jaune) et achète ton premier mème.",
		target = function()
			return kioskSign("PrairiePop")
		end,
	},
	{
		title = "Installe ton mème",
		text = "Approche-toi d'un socle de ta base, ou ouvre « Mèmes » puis « Poser ».",
		target = ownBaseSign,
	},
	{
		title = "Et voilà les pièces !",
		text = "Tes mèmes posés rapportent des pièces toutes les "
			.. Config.Economy.IncomeTickSeconds
			.. " s. Plus il y en a, plus ça rapporte.",
		manual = true,
	},
	{
		title = "Explore les biomes",
		text = "Plage Soda et Forêt Néon ont leurs propres mèmes. Les découvrir débloque leurs arrivages dans la boutique.",
		manual = true,
	},
	{
		title = "Le vol d'opportunité",
		text = "Tu peux tenter d'emporter un mème d'une base sans surveillance… mais si son propriétaire te touche, il revient ! Règles et mode Zen : bouton Aide.",
		manual = true,
	},
}

local function setBeacon(target: BasePart?)
	if target == beaconTarget then
		return
	end
	beaconTarget = target
	if beacon then
		beacon:Destroy()
		beacon = nil
	end
	if not target then
		return
	end
	local gui = Instance.new("BillboardGui")
	gui.Name = "TutorialBeacon"
	gui.AlwaysOnTop = true
	gui.Size = UDim2.fromOffset(110, 70)
	gui.StudsOffsetWorldSpace = Vector3.new(0, 6, 0)
	gui.MaxDistance = 2000
	gui.LightInfluence = 0
	gui.Adornee = target
	local label = Ui.new("Frame", {
		BackgroundColor3 = Colors.Primary,
		BorderSizePixel = 0,
		Size = UDim2.new(1, 0, 0, 40),
		Parent = gui,
	})
	Ui.corner(label, 12)
	Ui.text(label, {
		Text = "Ici !",
		Font = Theme.Fonts.Title,
		TextSize = 24,
		TextColor3 = Colors.White,
		TextXAlignment = Enum.TextXAlignment.Center,
		Size = UDim2.fromScale(1, 1),
	})
	Ui.new("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.new(0.5, 0, 0, 44),
		Size = UDim2.fromOffset(20, 20),
		Rotation = 45,
		BackgroundColor3 = Colors.Primary,
		BorderSizePixel = 0,
		Parent = gui,
	})
	gui.Parent = target
	beacon = gui
	TweenService:Create(
		gui,
		TweenInfo.new(0.8, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true),
		{ StudsOffsetWorldSpace = Vector3.new(0, 8, 0) }
	):Play()
end

local function finish()
	manualStage = nil
	card.Visible = false
	setBeacon(nil)
	if not replaying then
		task.spawn(ClientState.request, "CompleteTutorial")
	end
	replaying = false
end

local function currentStep(view: any): number?
	if not view.ready or (view.tutorialDone and not replaying) then
		return nil
	end
	if manualStage then
		return manualStage
	end
	if #view.memes == 0 and view.stats.bought == 0 then
		return 1
	end
	if #ClientState.placedMemes() == 0 then
		return 2
	end
	manualStage = 3
	return 3
end

function Tutorial.refresh()
	local index = currentStep(ClientState.view)
	if not index then
		card.Visible = false
		setBeacon(nil)
		return
	end
	local step = STEPS[index]
	card.Visible = true
	titleLabel.Text = string.format("%s  (%d/%d)", step.title, index, #STEPS)
	bodyLabel.Text = step.text
	nextButton.Visible = step.manual == true
	Ui.setButton(nextButton, { text = if index == #STEPS then "Compris !" else "Suivant" })
	setBeacon(if step.target then step.target() else nil)
end

function Tutorial.replay()
	replaying = true
	manualStage = nil
	Tutorial.refresh()
end

function Tutorial.init(root: ScreenGui)
	card = Ui.new("Frame", {
		Name = "Tutorial",
		AnchorPoint = Vector2.new(0.5, 1),
		BackgroundColor3 = Colors.White,
		BorderSizePixel = 0,
		Size = UDim2.fromOffset(460, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		Visible = false,
		Parent = root,
	})
	Ui.corner(card, 16)
	Ui.stroke(card, Colors.Primary, 3)
	Ui.padding(card, 12)
	Ui.list(card, { Padding = UDim.new(0, 6) })
	titleLabel = Ui.text(card, {
		Font = Theme.Fonts.Title,
		TextSize = Theme.TextSize.Large,
		TextColor3 = Colors.Primary,
		AutomaticSize = Enum.AutomaticSize.Y,
		LayoutOrder = 1,
	})
	bodyLabel = Ui.text(card, {
		AutomaticSize = Enum.AutomaticSize.Y,
		LayoutOrder = 2,
	})
	local row = Ui.frame(card, { Size = UDim2.new(1, 0, 0, 44), LayoutOrder = 3 })
	Ui.list(row, {
		FillDirection = Enum.FillDirection.Horizontal,
		HorizontalAlignment = Enum.HorizontalAlignment.Right,
		Padding = UDim.new(0, 8),
	})
	skipButton = Ui.button(row, { text = "Passer", color = Colors.InkSoft, size = UDim2.fromOffset(120, 44), layoutOrder = 1 })
	nextButton = Ui.button(row, { text = "Suivant", color = Colors.Primary, size = UDim2.fromOffset(140, 44), layoutOrder = 2 })
	Ui.onClick(skipButton, finish)
	Ui.onClick(nextButton, function()
		local index = currentStep(ClientState.view)
		if not index then
			return
		end
		if index >= #STEPS then
			finish()
		else
			manualStage = index + 1
			Tutorial.refresh()
		end
	end)

	local function relayout()
		local screen = root.AbsoluteSize
		local bar = Layout.bottomBar(screen)
		-- Entre les zones des pouces sur mobile (joystick à gauche, saut à droite).
		card.Size = UDim2.fromOffset(math.min(460, math.max(280, screen.X - 2 * Layout.thumbZone(screen))), 0)
		card.Position = UDim2.new(0.5, 0, 1, -(bar.bottom + bar.size + 12))
	end
	root:GetPropertyChangedSignal("AbsoluteSize"):Connect(relayout)
	relayout()
	ClientState.changed:Connect(Tutorial.refresh)
	Tutorial.refresh()
end

return Tutorial
