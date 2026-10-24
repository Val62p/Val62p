-- Invites de proximité créées localement (souris, tactile, manette gérés par Roblox).
-- Elles ne sont que des raccourcis d'interface : chaque action est revalidée par le serveur.
--  * Socle de sa base : « Poser un mème » / « Ranger »
--  * Socle d'une autre base : « Tenter un vol » (masqué si la base est protégée)
--  * Piédestal de kiosque : « Acheter »
local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Format = require(ReplicatedStorage.Shared.Format)
local Tags = require(ReplicatedStorage.Shared.Tags)
local ClientState = require(script.Parent.ClientState)
local Notifications = require(script.Parent.Notifications)

local localPlayer = Players.LocalPlayer

local Prompts = {}

type PadEntry = { pad: BasePart, owner: ProximityPrompt, steal: ProximityPrompt }
type PedestalEntry = { part: BasePart, prompt: ProximityPrompt }

local padEntries: { [BasePart]: PadEntry } = {}
local watchedBases: { [Instance]: boolean } = {}
local pedestalEntries: { [BasePart]: PedestalEntry } = {}
local openPicker: (slot: number) -> () = function(_slot: number) end

local function anchor(part: BasePart, height: number): Attachment
	local attachment = Instance.new("Attachment")
	attachment.Name = "PromptAnchor"
	attachment.Parent = part
	attachment.WorldPosition = part.Position + Vector3.new(0, height, 0)
	return attachment
end

local function newPrompt(parent: Instance, actionText: string, hold: number, distance: number): ProximityPrompt
	local prompt = Instance.new("ProximityPrompt")
	prompt.ActionText = actionText
	prompt.HoldDuration = hold
	prompt.MaxActivationDistance = distance
	prompt.RequiresLineOfSight = false
	prompt.Enabled = false
	prompt.Parent = parent
	return prompt
end

local function memeName(memeId: any): string
	local def = Config.Memes.Defs[memeId]
	return if def then def.name else ""
end

local function updatePad(entry: PadEntry)
	local pad = entry.pad
	local base = pad.Parent
	if not base then
		return
	end
	local view = ClientState.view
	local owner = base:GetAttribute("OwnerUserId") or 0
	local mine = view.ready and owner == localPlayer.UserId
	local hasMeme = pad:GetAttribute("HasMeme") == true
	local locked = pad:GetAttribute("Locked") == true
	local inTransit = pad:GetAttribute("InTransit") == true
	local slot = pad:GetAttribute("Slot")

	entry.owner.Enabled = mine and not locked and not inTransit
	entry.owner.ActionText = if hasMeme then "Ranger" else "Poser un mème"
	entry.owner.ObjectText = (if hasMeme then memeName(pad:GetAttribute("MemeId")) .. " · " else "") .. "Socle " .. tostring(slot)

	local now = ClientState.serverNow()
	local protected = (base:GetAttribute("ShieldUntil") or 0) > now or base:GetAttribute("Zen") == true
	entry.steal.Enabled = view.ready
		and owner ~= 0
		and not mine
		and hasMeme
		and not inTransit
		and not protected
		and not view.carrying
		and base:GetAttribute("UnderTheft") ~= true
	entry.steal.ObjectText = memeName(pad:GetAttribute("MemeId"))
end

local function updatePedestal(entry: PedestalEntry)
	local part = entry.part
	local price = part:GetAttribute("Price") or 0
	local view = ClientState.view
	entry.prompt.Enabled = view.ready and part:GetAttribute("MemeId") ~= ""
	entry.prompt.ObjectText = memeName(part:GetAttribute("MemeId")) .. " · " .. Format.coins(price) .. " pièces"
	if view.ready and view.coins < price then
		entry.prompt.ActionText = "Il manque " .. Format.coins(price - view.coins)
	else
		entry.prompt.ActionText = "Acheter"
	end
	-- Achat important : maintien plus long, pour éviter les achats accidentels.
	entry.prompt.HoldDuration = if price >= 500 then 0.8 else 0.25
end

local function updateAll()
	for _, entry in padEntries do
		updatePad(entry)
	end
	for _, entry in pedestalEntries do
		updatePedestal(entry)
	end
end

local function onOwnerTriggered(entry: PadEntry)
	local pad = entry.pad
	local slot = pad:GetAttribute("Slot")
	if pad:GetAttribute("HasMeme") then
		task.spawn(function()
			local result = ClientState.requestOnce("store:" .. tostring(slot), "StoreMeme", slot)
			Notifications.result(result, if result and result.ok then memeName(result.data.memeId) .. " rangé dans ta réserve." else nil)
		end)
		return
	end
	local stored = ClientState.storedMemes()
	if #stored == 0 then
		Notifications.show("Info", "Ta réserve est vide : achète un mème dans un kiosque !")
	elseif #stored == 1 then
		task.spawn(function()
			local result = ClientState.requestOnce("place:" .. stored[1].uid, "PlaceMeme", stored[1].uid, slot)
			Notifications.result(result, if result and result.ok then memeName(stored[1].id) .. " est installé !" else nil)
		end)
	else
		openPicker(slot)
	end
end

local function onStealTriggered(entry: PadEntry)
	local pad = entry.pad
	local baseIndex = pad:GetAttribute("BaseIndex")
	local slot = pad:GetAttribute("Slot")
	task.spawn(function()
		local result = ClientState.requestOnce("steal", "StartTheft", baseIndex, slot)
		if result and not result.ok then
			Notifications.result(result)
		end
	end)
end

local function trackPad(instance: Instance)
	if not instance:IsA("BasePart") or padEntries[instance] then
		return
	end
	local attachment = anchor(instance, 2.5)
	local entry: PadEntry = {
		pad = instance,
		owner = newPrompt(attachment, "Poser un mème", 0, 9),
		steal = newPrompt(attachment, "Tenter un vol", 0.5, 10),
	}
	entry.owner.Name = "OwnerPrompt"
	entry.steal.Name = "StealPrompt"
	padEntries[instance] = entry
	entry.owner.Triggered:Connect(function()
		onOwnerTriggered(entry)
	end)
	entry.steal.Triggered:Connect(function()
		onStealTriggered(entry)
	end)
	instance.AttributeChanged:Connect(function()
		updatePad(entry)
	end)
	local base = instance.Parent
	if base and not watchedBases[base] then
		watchedBases[base] = true
		base.AttributeChanged:Connect(function()
			for _, other in padEntries do
				if other.pad.Parent == base then
					updatePad(other)
				end
			end
		end)
	end
	updatePad(entry)
end

local function trackPedestal(instance: Instance)
	if not instance:IsA("BasePart") or pedestalEntries[instance] then
		return
	end
	local attachment = anchor(instance, 3)
	local entry: PedestalEntry = { part = instance, prompt = newPrompt(attachment, "Acheter", 0.25, 12) }
	entry.prompt.Name = "BuyPrompt"
	pedestalEntries[instance] = entry
	entry.prompt.Triggered:Connect(function()
		local biomeId = instance:GetAttribute("BiomeId")
		local index = instance:GetAttribute("Pedestal")
		local version = instance:GetAttribute("OfferVersion")
		local name = memeName(instance:GetAttribute("MemeId"))
		task.spawn(function()
			local result = ClientState.requestOnce("buy:" .. tostring(biomeId) .. tostring(index), "BuyOffer", biomeId, index, version)
			if result and result.ok then
				local placed = result.data and result.data.slot and result.data.slot > 0
				Notifications.show("Success", name .. (if placed then " est posé dans ta base !" else " rejoint ta réserve : pose-le sur un socle !"))
			else
				Notifications.result(result)
			end
		end)
	end)
	instance.AttributeChanged:Connect(function()
		updatePedestal(entry)
	end)
	updatePedestal(entry)
end

function Prompts.init(onPick: (slot: number) -> ())
	openPicker = onPick
	for _, pad in CollectionService:GetTagged(Tags.Pad) do
		trackPad(pad)
	end
	CollectionService:GetInstanceAddedSignal(Tags.Pad):Connect(trackPad)
	for _, pedestal in CollectionService:GetTagged(Tags.Pedestal) do
		trackPedestal(pedestal)
	end
	CollectionService:GetInstanceAddedSignal(Tags.Pedestal):Connect(trackPedestal)
	ClientState.changed:Connect(updateAll)
	-- Fin des protections (compte à rebours) : rafraîchissement léger chaque seconde.
	task.spawn(function()
		while true do
			task.wait(1)
			updateAll()
		end
	end)
end

return Prompts
