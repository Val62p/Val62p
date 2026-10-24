-- HUD permanent et minimal : solde, état de protection, et 4 boutons (boutique, mèmes,
-- ma base, aide). Les interactions contextuelles passent par les invites de proximité.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")

local Format = require(ReplicatedStorage.Shared.Format)
local Client = script.Parent.Parent
local Theme = require(Client.Ui.Theme)
local Ui = require(Client.Ui.Ui)
local Layout = require(Client.Ui.Layout)
local ClientState = require(script.Parent.ClientState)

local Colors = Theme.Colors

local Hud = {}

export type Actions = {
	shop: () -> (),
	collection: () -> (),
	home: () -> (),
	help: () -> (),
}

local coinsLabel: TextLabel
local bumpLabel: TextLabel
local statusChip: Frame
local statusLabel: TextLabel
local statusIcons: { [string]: Frame } = {}
local bar: Frame
local buttons: { TextButton } = {}

local function makeHudButton(parent: Instance, order: number, icon: string, label: string, key: string?, color: Color3, onClick: () -> ())
	local button = Ui.new("TextButton", {
		Name = "Hud_" .. icon,
		Text = "",
		AutoButtonColor = true,
		BackgroundColor3 = color,
		BorderSizePixel = 0,
		LayoutOrder = order,
		Parent = parent,
	})
	button:SetAttribute("Enabled", true)
	Ui.corner(button, 14)
	Ui.stroke(button, Colors.White, 2)
	local iconHolder = Ui.icon(button, icon, 30, Colors.White, {
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 6),
		Size = UDim2.new(0.5, 0, 0.5, 0),
		SizeConstraint = Enum.SizeConstraint.RelativeYY,
	})
	iconHolder.Name = "IconHolder"
	Ui.text(button, {
		Name = "Label",
		Text = label,
		Font = Theme.Fonts.Bold,
		TextSize = Theme.TextSize.Small,
		TextColor3 = Colors.White,
		TextXAlignment = Enum.TextXAlignment.Center,
		TextWrapped = false,
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -4),
		Size = UDim2.new(1, -4, 0, 18),
	})
	-- Raccourci clavier affiché uniquement quand un clavier est utilisé.
	if key and UserInputService.KeyboardEnabled and not UserInputService.TouchEnabled then
		local cap = Ui.new("Frame", {
			Name = "KeyCap",
			AnchorPoint = Vector2.new(1, 0),
			Position = UDim2.new(1, -3, 0, 3),
			Size = UDim2.fromOffset(0, 18),
			AutomaticSize = Enum.AutomaticSize.X,
			BackgroundColor3 = Colors.White,
			BorderSizePixel = 0,
			Parent = button,
		})
		Ui.corner(cap, 5)
		Ui.padding(cap, 0, 4)
		Ui.text(cap, {
			Text = key,
			Font = Theme.Fonts.Bold,
			TextSize = 12,
			TextXAlignment = Enum.TextXAlignment.Center,
			AutomaticSize = Enum.AutomaticSize.X,
			Size = UDim2.new(0, 0, 1, 0),
			TextWrapped = false,
		})
	end
	Ui.onClick(button, onClick)
	table.insert(buttons, button)
	return button
end

function Hud.init(root: ScreenGui, actions: Actions)
	-- Solde et état, en haut au centre.
	local top = Ui.frame(root, {
		Name = "Top",
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 8),
		Size = UDim2.fromOffset(0, 0),
		AutomaticSize = Enum.AutomaticSize.XY,
	})
	Ui.list(top, { HorizontalAlignment = Enum.HorizontalAlignment.Center, Padding = UDim.new(0, 6) })

	local pill = Ui.new("Frame", {
		Name = "Coins",
		BackgroundColor3 = Colors.White,
		BorderSizePixel = 0,
		AutomaticSize = Enum.AutomaticSize.X,
		Size = UDim2.new(0, 0, 0, 48),
		LayoutOrder = 1,
		Parent = top,
	})
	Ui.round(pill)
	Ui.stroke(pill, Colors.Line, 2)
	Ui.padding(pill, 6, 16, 6, 8)
	Ui.list(pill, {
		FillDirection = Enum.FillDirection.Horizontal,
		VerticalAlignment = Enum.VerticalAlignment.Center,
		Padding = UDim.new(0, 8),
	})
	Ui.icon(pill, "coin", 36, nil, { LayoutOrder = 1 })
	coinsLabel = Ui.text(pill, {
		Name = "Amount",
		Text = "Chargement…",
		Font = Theme.Fonts.Title,
		TextSize = Theme.TextSize.Coins,
		AutomaticSize = Enum.AutomaticSize.X,
		Size = UDim2.new(0, 0, 1, 0),
		TextWrapped = false,
		LayoutOrder = 2,
	})
	bumpLabel = Ui.text(pill, {
		Name = "Bump",
		Text = "",
		Font = Theme.Fonts.Bold,
		TextSize = Theme.TextSize.Body,
		TextColor3 = Colors.Success,
		AutomaticSize = Enum.AutomaticSize.X,
		Size = UDim2.new(0, 0, 1, 0),
		TextWrapped = false,
		LayoutOrder = 3,
		TextTransparency = 1,
	})

	statusChip = Ui.new("Frame", {
		Name = "Status",
		BackgroundColor3 = Colors.Success,
		BorderSizePixel = 0,
		AutomaticSize = Enum.AutomaticSize.X,
		Size = UDim2.new(0, 0, 0, 30),
		LayoutOrder = 2,
		Visible = false,
		Parent = top,
	})
	Ui.round(statusChip)
	Ui.padding(statusChip, 3, 12, 3, 6)
	Ui.list(statusChip, {
		FillDirection = Enum.FillDirection.Horizontal,
		VerticalAlignment = Enum.VerticalAlignment.Center,
		Padding = UDim.new(0, 6),
	})
	for _, name in { "shield", "leaf" } do
		statusIcons[name] = Ui.icon(statusChip, name, 22, Colors.White, { LayoutOrder = 1, Visible = false })
	end
	statusLabel = Ui.text(statusChip, {
		Text = "",
		Font = Theme.Fonts.Bold,
		TextSize = Theme.TextSize.Small,
		TextColor3 = Colors.White,
		AutomaticSize = Enum.AutomaticSize.X,
		Size = UDim2.new(0, 0, 1, 0),
		TextWrapped = false,
		LayoutOrder = 2,
	})

	-- Barre d'actions en bas au centre.
	bar = Ui.frame(root, { Name = "ActionBar", AnchorPoint = Vector2.new(0.5, 1) })
	Ui.list(bar, {
		FillDirection = Enum.FillDirection.Horizontal,
		HorizontalAlignment = Enum.HorizontalAlignment.Center,
		Padding = UDim.new(0, 8),
	})
	makeHudButton(bar, 1, "basket", "Boutique", "B", Colors.Primary, actions.shop)
	makeHudButton(bar, 2, "cards", "Mèmes", "C", Colors.Secondary, actions.collection)
	makeHudButton(bar, 3, "house", "Ma base", "H", Colors.Success, actions.home)
	makeHudButton(bar, 4, "help", "Aide", "F1", Colors.InkSoft, actions.help)

	local function relayout()
		local screen = root.AbsoluteSize
		local spec = Layout.bottomBar(screen, #buttons)
		bar.Size = UDim2.fromOffset(spec.width, spec.size)
		bar.Position = UDim2.new(0.5, 0, 1, -spec.bottom)
		local list = bar:FindFirstChildOfClass("UIListLayout")
		if list then
			list.Padding = UDim.new(0, spec.gap)
		end
		for _, button in buttons do
			button.Size = UDim2.fromOffset(spec.buttonWidth, spec.size)
		end
	end
	root:GetPropertyChangedSignal("AbsoluteSize"):Connect(relayout)
	relayout()

	ClientState.changed:Connect(Hud.update)
	task.spawn(function()
		while true do
			task.wait(1)
			Hud.updateStatus(ClientState.view)
		end
	end)
	Hud.update(ClientState.view)
end

function Hud.updateStatus(view: any)
	if not view.ready then
		statusChip.Visible = false
		return
	end
	local now = ClientState.serverNow()
	local text, color, icon = nil, Colors.Success, "shield"
	if view.zen then
		text, color, icon = "Mode Zen actif", Colors.Zen, "leaf"
	elseif view.protectedUntil > now then
		local label = if view.protectionReason == "Join" then "Protection de départ" else "Base protégée"
		text = label .. " · " .. Format.duration(view.protectedUntil - now)
	elseif not view.saveEnabled then
		text, color, icon = "Sauvegarde indisponible", Colors.InkSoft, "shield"
	end
	statusChip.Visible = text ~= nil
	if text then
		statusChip.BackgroundColor3 = color
		statusLabel.Text = text
		for name, holder in statusIcons do
			holder.Visible = name == icon
		end
	end
end

function Hud.update(view: any)
	if view.ready then
		coinsLabel.Text = Format.coins(view.coins)
	else
		coinsLabel.Text = "Chargement…"
	end
	Hud.updateStatus(view)
end

-- Petit « +N » à côté du solde à chaque revenu.
function Hud.bump(amount: number)
	if not bumpLabel then
		return
	end
	bumpLabel.Text = "+" .. Format.coins(amount)
	bumpLabel.TextTransparency = 0
	TweenService:Create(bumpLabel, TweenInfo.new(1.2, Enum.EasingStyle.Quad, Enum.EasingDirection.In), { TextTransparency = 1 })
		:Play()
end

return Hud
