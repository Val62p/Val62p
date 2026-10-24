-- Bandeaux de vol : pour le voleur (crochetage, temps restant, annuler) et pour la victime
-- (alerte, distance du voleur, retour rapide à sa base). Textes neutres et bienveillants.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Format = require(ReplicatedStorage.Shared.Format)
local Client = script.Parent.Parent
local Theme = require(Client.Ui.Theme)
local Ui = require(Client.Ui.Ui)
local ClientState = require(script.Parent.ClientState)
local Notifications = require(script.Parent.Notifications)

local Colors = Theme.Colors
local localPlayer = Players.LocalPlayer

local TheftHud = {}

type Banner = {
	frame: Frame,
	title: TextLabel,
	subtitle: TextLabel,
	fill: Frame,
	button: TextButton,
}

local thiefBanner: Banner
local victimBanner: Banner
local heartbeat: RBXScriptConnection? = nil

local function makeBanner(parent: Instance, order: number, buttonText: string, onClick: () -> ()): Banner
	local frame = Ui.new("Frame", {
		Name = "TheftBanner",
		BackgroundColor3 = Colors.Danger,
		BorderSizePixel = 0,
		Size = UDim2.new(1, 0, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		LayoutOrder = order,
		Visible = false,
		Parent = parent,
	})
	Ui.corner(frame, 14)
	Ui.padding(frame, 10, 12)
	Ui.icon(frame, "alert", 34, nil, { Position = UDim2.fromOffset(0, 2) })
	local title = Ui.text(frame, {
		Font = Theme.Fonts.Bold,
		TextSize = Theme.TextSize.Body,
		TextColor3 = Colors.White,
		Position = UDim2.fromOffset(44, 0),
		Size = UDim2.new(1, -170, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
	})
	local subtitle = Ui.text(frame, {
		TextSize = Theme.TextSize.Small,
		TextColor3 = Colors.White,
		Position = UDim2.fromOffset(44, 24),
		Size = UDim2.new(1, -170, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
	})
	local track = Ui.new("Frame", {
		Name = "Progress",
		BackgroundColor3 = Colors.White,
		BackgroundTransparency = 0.6,
		BorderSizePixel = 0,
		Position = UDim2.fromOffset(44, 52),
		Size = UDim2.new(1, -170, 0, 8),
		Parent = frame,
	})
	Ui.round(track)
	local fill = Ui.new("Frame", {
		BackgroundColor3 = Colors.White,
		BorderSizePixel = 0,
		Size = UDim2.fromScale(0, 1),
		Parent = track,
	})
	Ui.round(fill)
	local button = Ui.button(frame, {
		text = buttonText,
		color = Colors.White,
		size = UDim2.fromOffset(112, 44),
	})
	button.AnchorPoint = Vector2.new(1, 0)
	button.Position = UDim2.new(1, 0, 0, 6)
	Ui.onClick(button, onClick)
	return { frame = frame, title = title, subtitle = subtitle, fill = fill, button = button }
end

local function otherDistance(userId: number): number?
	local other = Players:GetPlayerByUserId(userId)
	local mine = localPlayer.Character and localPlayer.Character:FindFirstChild("HumanoidRootPart")
	local theirs = other and other.Character and other.Character:FindFirstChild("HumanoidRootPart")
	if mine and theirs and mine:IsA("BasePart") and theirs:IsA("BasePart") then
		return (mine.Position - theirs.Position).Magnitude
	end
	return nil
end

local function progress(info: any, now: number): number
	local total = math.max(0.1, info.endsAt - info.startedAt)
	return math.clamp((now - info.startedAt) / total, 0, 1)
end

local function render()
	local view = ClientState.view
	local now = ClientState.serverNow()

	local carrying = view.ready and view.carrying
	thiefBanner.frame.Visible = carrying ~= nil and carrying ~= false
	if carrying then
		local remaining = math.max(0, carrying.endsAt - now)
		if carrying.phase == "Lockpick" then
			thiefBanner.frame.BackgroundColor3 = Colors.Secondary
			thiefBanner.title.Text = "Crochetage de " .. carrying.memeName .. "…"
			thiefBanner.subtitle.Text = "Reste près du socle (" .. Format.duration(remaining) .. ")"
			thiefBanner.fill.Size = UDim2.fromScale(progress(carrying, now), 1)
		else
			local total = math.max(0.1, carrying.endsAt - carrying.startedAt)
			thiefBanner.frame.BackgroundColor3 = Colors.Primary
			thiefBanner.title.Text = "Ramène " .. carrying.memeName .. " dans ta base !"
			thiefBanner.subtitle.Text = Format.duration(remaining) .. " · évite la place surveillée et " .. carrying.otherName
			thiefBanner.fill.Size = UDim2.fromScale(math.clamp(remaining / total, 0, 1), 1)
		end
	end

	local robbery = view.ready and view.robbery
	victimBanner.frame.Visible = robbery ~= nil and robbery ~= false
	if robbery then
		local distance = otherDistance(robbery.otherUserId)
		local distanceText = if distance then " · à " .. math.floor(distance) .. " m" else ""
		if robbery.phase == "Lockpick" then
			victimBanner.title.Text = "Alerte : " .. robbery.otherName .. " crochète " .. robbery.memeName .. " !"
			victimBanner.subtitle.Text = "Reviens dans ta base pour l'en empêcher" .. distanceText
			victimBanner.fill.Size = UDim2.fromScale(progress(robbery, now), 1)
		else
			local remaining = math.max(0, robbery.endsAt - now)
			local total = math.max(0.1, robbery.endsAt - robbery.startedAt)
			victimBanner.title.Text = "Alerte : " .. robbery.otherName .. " emporte " .. robbery.memeName .. " !"
			victimBanner.subtitle.Text = "Touche-le pour le récupérer" .. distanceText
			victimBanner.fill.Size = UDim2.fromScale(math.clamp(remaining / total, 0, 1), 1)
		end
	end

	local active = thiefBanner.frame.Visible or victimBanner.frame.Visible
	if not active and heartbeat then
		heartbeat:Disconnect()
		heartbeat = nil
	end
end

local function onChanged()
	render()
	local view = ClientState.view
	if (view.carrying or view.robbery) and not heartbeat then
		heartbeat = RunService.Heartbeat:Connect(render)
	end
end

function TheftHud.init(stack: Frame)
	local holder = Ui.frame(stack, {
		Name = "TheftBanners",
		Size = UDim2.new(1, 0, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		LayoutOrder = 1,
	})
	Ui.list(holder, { Padding = UDim.new(0, 6) })
	thiefBanner = makeBanner(holder, 1, "Annuler", function()
		task.spawn(function()
			Notifications.result(ClientState.requestOnce("cancelTheft", "CancelTheft"))
		end)
	end)
	victimBanner = makeBanner(holder, 2, "Ma base", function()
		task.spawn(function()
			Notifications.result(ClientState.requestOnce("home", "TeleportHome"))
		end)
	end)
	ClientState.changed:Connect(onChanged)
	onChanged()
end

return TheftHud
