-- Repères dans le monde, côté client : « Ta base », bulles d'état des bases (protégée,
-- Zen, alerte), comptes à rebours des kiosques et « +N » au-dessus de ses mèmes.
local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Config = require(ReplicatedStorage.Shared.Config)
local Format = require(ReplicatedStorage.Shared.Format)
local MapLayout = require(ReplicatedStorage.Shared.MapLayout)
local Tags = require(ReplicatedStorage.Shared.Tags)
local Client = script.Parent.Parent
local Theme = require(Client.Ui.Theme)
local Ui = require(Client.Ui.Ui)
local ClientState = require(script.Parent.ClientState)

local Colors = Theme.Colors
local localPlayer = Players.LocalPlayer

local WorldLabels = {}

local marker: BillboardGui? = nil
local markerBase = 0

local function baseModel(index: number): Model?
	for _, model in CollectionService:GetTagged(Tags.Base) do
		if model:GetAttribute("BaseIndex") == index then
			return model
		end
	end
	return nil
end

local function rootPosition(): Vector3?
	local character = localPlayer.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	return if root and root:IsA("BasePart") then root.Position else nil
end

local function updateMarker()
	local view = ClientState.view
	local index = if view.ready then view.baseIndex else 0
	if index ~= markerBase or (index > 0 and not marker) then
		markerBase = index
		if marker then
			marker:Destroy()
			marker = nil
		end
		local model = index > 0 and baseModel(index)
		local sign = model and model:FindFirstChild("Sign")
		if sign and sign:IsA("BasePart") then
			local gui = Instance.new("BillboardGui")
			gui.Name = "OwnBaseMarker"
			gui.AlwaysOnTop = true
			gui.MaxDistance = 2000
			gui.LightInfluence = 0
			gui.Size = UDim2.fromOffset(130, 40)
			gui.StudsOffsetWorldSpace = Vector3.new(0, 9, 0)
			gui.Adornee = sign
			local frame = Ui.new("Frame", {
				BackgroundColor3 = Colors.Success,
				BorderSizePixel = 0,
				Size = UDim2.fromScale(1, 1),
				Parent = gui,
			})
			Ui.round(frame)
			Ui.icon(frame, "house", 28, Colors.White, { Position = UDim2.new(0, 8, 0.5, -14) })
			Ui.text(frame, {
				Text = "Ta base",
				Font = Theme.Fonts.Title,
				TextSize = 20,
				TextColor3 = Colors.White,
				Position = UDim2.fromOffset(40, 0),
				Size = UDim2.new(1, -44, 1, 0),
			})
			gui.Parent = sign
			marker = gui
		end
	end
	if marker then
		local position = rootPosition()
		marker.Enabled = not (position and MapLayout.isInsideBase(markerBase, position))
	end
end

local function updateBaseStatus(model: Instance, now: number)
	local gui = model:FindFirstChild("Sign") and model.Sign:FindFirstChild("StatusGui")
	if not gui then
		return
	end
	local frame = gui:FindFirstChild("Frame")
	local label = frame and frame:FindFirstChild("Label")
	if not label then
		return
	end
	local owner = model:GetAttribute("OwnerUserId") or 0
	local text, color = nil, Colors.Success
	if owner ~= 0 then
		if model:GetAttribute("UnderTheft") then
			text, color = "Alerte !", Colors.Warning
		elseif model:GetAttribute("Zen") then
			text, color = "Mode Zen", Colors.Zen
		elseif (model:GetAttribute("ShieldUntil") or 0) > now then
			text = "Protégée " .. Format.duration(model:GetAttribute("ShieldUntil") - now)
		end
	end
	gui.Enabled = text ~= nil
	if text then
		label.Text = text
		label.TextColor3 = Theme.readableOn(color)
		frame.BackgroundColor3 = color
	end
end

local function updateKiosk(model: Instance, now: number)
	local sign = model:FindFirstChild("KioskSign")
	local surface = sign and sign:FindFirstChildOfClass("SurfaceGui")
	local timer = surface and surface:FindFirstChild("Timer", true)
	if timer and timer:IsA("TextLabel") then
		local remaining = (model:GetAttribute("NextRotationAt") or 0) - now
		timer.Text = if remaining > 0 then "Nouvel arrivage dans " .. Format.duration(remaining) else "Arrivage en cours…"
	end
end

-- « +N » flottant au-dessus de chacun de ses mèmes posés (si on est près de sa base).
local function incomePopups()
	local view = ClientState.view
	if not view.ready or view.baseIndex == 0 then
		return
	end
	local position = rootPosition()
	local home = MapLayout.base(view.baseIndex)
	if not position or not home or (position - home.cframe.Position).Magnitude > 120 then
		return
	end
	local model = baseModel(view.baseIndex)
	if not model then
		return
	end
	for _, meme in ClientState.placedMemes() do
		local def = Config.Memes.Defs[meme.id]
		local pad = model:FindFirstChild("Pad" .. meme.slot)
		if def and pad and pad:IsA("BasePart") and not meme.busy then
			local gui = Instance.new("BillboardGui")
			gui.Name = "IncomePopup"
			gui.Size = UDim2.fromOffset(90, 30)
			gui.StudsOffsetWorldSpace = Vector3.new(0, 4.5, 0)
			gui.LightInfluence = 0
			gui.MaxDistance = 120
			gui.Adornee = pad
			local label = Ui.text(gui, {
				Text = "+" .. def.income,
				Font = Theme.Fonts.Title,
				TextSize = 22,
				TextColor3 = Colors.Coin,
				TextStrokeTransparency = 0.2,
				TextStrokeColor3 = Colors.Ink,
				TextXAlignment = Enum.TextXAlignment.Center,
				Size = UDim2.fromScale(1, 1),
			})
			gui.Parent = pad
			TweenService:Create(gui, TweenInfo.new(1.1), { StudsOffsetWorldSpace = Vector3.new(0, 7, 0) }):Play()
			TweenService:Create(label, TweenInfo.new(1.1), { TextTransparency = 1, TextStrokeTransparency = 1 }):Play()
			task.delay(1.2, function()
				gui:Destroy()
			end)
		end
	end
end

function WorldLabels.init()
	ClientState.changed:Connect(updateMarker)
	ClientState.notified:Connect(function(payload)
		if payload.kind == "Income" then
			incomePopups()
		end
	end)
	task.spawn(function()
		while true do
			local now = ClientState.serverNow()
			updateMarker()
			for _, model in CollectionService:GetTagged(Tags.Base) do
				updateBaseStatus(model, now)
			end
			for _, model in CollectionService:GetTagged(Tags.Kiosk) do
				updateKiosk(model, now)
			end
			task.wait(0.5)
		end
	end)
end

return WorldLabels
