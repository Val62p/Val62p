-- Messages courts (toasts) en haut de l'écran : succès, info, avertissement, alerte.
-- Animations brèves, jamais bloquantes ; trois messages au plus à la fois.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Net = require(ReplicatedStorage.Shared.Net)
local Client = script.Parent.Parent
local Theme = require(Client.Ui.Theme)
local Ui = require(Client.Ui.Ui)
local Layout = require(Client.Ui.Layout)

local Colors = Theme.Colors

local Notifications = {}

local STYLE = {
	Success = { color = Colors.Success, icon = "check" },
	Info = { color = Colors.Secondary, icon = "help" },
	Discovery = { color = Colors.Primary, icon = "cards" },
	Warning = { color = Colors.InkSoft, icon = "alert" },
	Alert = { color = Colors.Danger, icon = "alert" },
}

local MAX_VISIBLE = 3
local DURATION = 4

local container: Frame
local screenGui: ScreenGui
local counter = 0

-- `stack` : colonne partagée en haut de l'écran (sous le solde), `root` : l'écran.
function Notifications.init(root: ScreenGui, stack: Frame)
	screenGui = root
	container = Ui.frame(stack, {
		Name = "Toasts",
		Size = UDim2.new(1, 0, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		LayoutOrder = 2,
	})
	Ui.list(container, { HorizontalAlignment = Enum.HorizontalAlignment.Center, Padding = UDim.new(0, 6) })
end

function Notifications.show(kind: string, text: string)
	if not container or text == "" then
		return
	end
	local style = STYLE[kind] or STYLE.Info
	local toasts = {}
	for _, child in container:GetChildren() do
		if child:IsA("Frame") then
			table.insert(toasts, child)
		end
	end
	table.sort(toasts, function(a, b)
		return a.LayoutOrder < b.LayoutOrder
	end)
	while #toasts >= MAX_VISIBLE do
		table.remove(toasts, 1):Destroy()
	end

	counter += 1
	local toast = Ui.new("Frame", {
		Name = "Toast",
		BackgroundColor3 = style.color,
		BorderSizePixel = 0,
		Size = UDim2.new(1, 0, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		LayoutOrder = counter,
		Parent = container,
	})
	Ui.corner(toast, 12)
	Ui.padding(toast, 8, 12)
	Ui.icon(toast, style.icon, 24, Colors.White, { Position = UDim2.fromOffset(0, 0) })
	local label = Ui.text(toast, {
		Text = text,
		Font = Theme.Fonts.Bold,
		TextSize = Layout.textSize(screenGui.AbsoluteSize, Theme.TextSize.Body),
		TextColor3 = Colors.White,
		Size = UDim2.new(1, -34, 0, 0),
		Position = UDim2.fromOffset(34, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
	})
	local scale = Ui.new("UIScale", { Scale = 0.85, Parent = toast })
	TweenService:Create(scale, TweenInfo.new(0.15, Enum.EasingStyle.Back), { Scale = 1 }):Play()
	task.delay(DURATION, function()
		if toast.Parent then
			local fade = TweenService:Create(toast, TweenInfo.new(0.25), { BackgroundTransparency = 1 })
			TweenService:Create(label, TweenInfo.new(0.25), { TextTransparency = 1 }):Play()
			fade:Play()
			fade.Completed:Wait()
			toast:Destroy()
		end
	end)
end

-- Affiche le résultat d'une requête : message d'erreur traduit, ou texte de succès.
function Notifications.result(result: { ok: boolean, code: string, data: any }?, successText: string?)
	if not result then
		return
	end
	if result.ok then
		if successText then
			Notifications.show("Success", successText)
		end
	else
		Notifications.show("Warning", Net.message(result.code, result.data))
	end
end

return Notifications
