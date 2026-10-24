-- Attribution des bases, affichage des mèmes posés, thèmes et attributs publics de protection.
-- Une base n'existe que pour un joueur connecté : au départ, elle est libérée et vidée
-- (les mèmes restent dans le profil sauvegardé, rien n'est perdu).
local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local Config = require(ReplicatedStorage.Shared.Config)
local Catalog = require(ReplicatedStorage.Shared.Catalog)
local MapLayout = require(ReplicatedStorage.Shared.MapLayout)
local MemeAppearance = require(ReplicatedStorage.Shared.MemeAppearance)
local Tags = require(ReplicatedStorage.Shared.Tags)
local Net = require(ReplicatedStorage.Shared.Net)
local Inventory = require(ServerScriptService.Domain.Inventory)
local Progression = require(ServerScriptService.Domain.Progression)

local WHITE = Color3.fromRGB(255, 255, 255)
local LOCKED = Color3.fromRGB(196, 192, 214)
local INK = Color3.fromRGB(34, 28, 48)

local BaseService = {}
BaseService.__index = BaseService

function BaseService.new(ctx: any)
	return setmetatable({
		ctx = ctx,
		owners = {} :: { [number]: Player },
		baseOf = {} :: { [number]: number },
		visuals = {} :: { [number]: { [number]: any } },
	}, BaseService)
end

function BaseService:getBaseIndex(player: Player): number?
	return self.baseOf[player.UserId]
end

function BaseService:getOwner(baseIndex: number): Player?
	return self.owners[baseIndex]
end

function BaseService:padPosition(baseIndex: number, slot: number): Vector3
	return MapLayout.slotCFrame(baseIndex, slot).Position
end

-- Le joueur se trouve-t-il dans sa propre base (position mesurée côté serveur) ?
function BaseService:isInOwnBase(player: Player): boolean
	local index = self.baseOf[player.UserId]
	local position = self.ctx.characters:getRootPosition(player)
	return index ~= nil and position ~= nil and MapLayout.isInsideBase(index, position)
end

function BaseService:assign(player: Player): number?
	local record = self.ctx.profiles:get(player)
	if not record or self.baseOf[player.UserId] then
		return self.baseOf[player.UserId]
	end
	local chosen = nil
	for index = 1, MapLayout.baseCount() do
		if not self.owners[index] then
			chosen = index
			break
		end
	end
	if not chosen then
		self.ctx.notifier:send(player, Net.Notify.Warning, "Toutes les bases sont occupées : explore et reviens plus tard !")
		return nil
	end
	self.owners[chosen] = player
	self.baseOf[player.UserId] = chosen
	self.visuals[chosen] = {}

	local ref = self.ctx.map.bases[chosen]
	ref.model:SetAttribute("OwnerUserId", player.UserId)
	ref.model:SetAttribute("OwnerName", player.DisplayName)
	ref.signTitle.Text = "Base de " .. player.DisplayName
	ref.signSubtitle.Text = Config.Biomes.Defs[ref.layout.biomeId].displayName
	self:applyTheme(chosen, record.profile.cosmetics.equipped)
	self:refresh(player)
	self:updateProtection(player)
	return chosen
end

function BaseService:release(player: Player)
	local index = self.baseOf[player.UserId]
	if not index then
		return
	end
	for _, visual in self.visuals[index] or {} do
		visual.model:Destroy()
	end
	self.visuals[index] = nil
	self.owners[index] = nil
	self.baseOf[player.UserId] = nil

	local ref = self.ctx.map.bases[index]
	ref.model:SetAttribute("OwnerUserId", 0)
	ref.model:SetAttribute("OwnerName", "")
	ref.model:SetAttribute("ShieldUntil", 0)
	ref.model:SetAttribute("Zen", false)
	ref.model:SetAttribute("UnderTheft", false)
	ref.signTitle.Text = "Base libre"
	ref.signSubtitle.Text = "Rejoins la partie pour l'occuper"
	for _, pad in ref.pads do
		pad:SetAttribute("HasMeme", false)
		pad:SetAttribute("MemeId", "")
		pad:SetAttribute("Locked", false)
		pad:SetAttribute("InTransit", false)
		pad.Color = WHITE
		pad.LockGui.Enabled = false
	end
	self:applyTheme(index, Config.Cosmetics.Default)
	ref.treadmill.model:SetAttribute("Level", 1)
	ref.treadmill.levelLabel.Text = "Base libre"
end

-- Niveau et vitesse du tapis de course, visibles par tous au-dessus de la console.
function BaseService:_refreshTreadmill(index: number, profile: any)
	local treadmill = self.ctx.map.bases[index].treadmill
	local level = Progression.level(profile, "Treadmill")
	local maxLevel = #Config.Upgrades.Defs.Treadmill.levels
	treadmill.model:SetAttribute("Level", level)
	treadmill.model:SetAttribute("Speed", Progression.walkSpeed(profile))
	treadmill.levelLabel.Text = string.format("Niv. %d/%d · vitesse %d", level, maxLevel, Progression.walkSpeed(profile))
end

function BaseService:_spawnMeme(index: number, slot: number, uid: string, memeId: string)
	local ref = self.ctx.map.bases[index]
	local def = Catalog.meme(memeId)
	local model = MemeAppearance.build(memeId, MapLayout.slotCFrame(index, slot), { ring = true })
	model.Name = "Slot" .. slot
	for _, part in model:GetDescendants() do
		if part:IsA("BasePart") then
			part:SetAttribute("BaseTransparency", part.Transparency)
		end
	end

	local height = model:GetAttribute("Height") or 3
	local gui = Instance.new("BillboardGui")
	gui.Name = "Label"
	gui.Adornee = model.PrimaryPart
	gui.Size = UDim2.fromOffset(150, 46)
	gui.StudsOffsetWorldSpace = Vector3.new(0, height + 1.4 - model.PrimaryPart.CFrame.Position.Y + MapLayout.slotCFrame(index, slot).Position.Y, 0)
	gui.MaxDistance = 60
	gui.LightInfluence = 0
	gui.Parent = model
	local nameLabel = Instance.new("TextLabel")
	nameLabel.Name = "MemeName"
	nameLabel.BackgroundTransparency = 1
	nameLabel.Size = UDim2.fromScale(1, 0.55)
	nameLabel.Font = Enum.Font.FredokaOne
	nameLabel.TextScaled = true
	nameLabel.TextColor3 = WHITE
	nameLabel.TextStrokeColor3 = INK
	nameLabel.TextStrokeTransparency = 0.2
	nameLabel.Text = def.name
	nameLabel.Parent = gui
	local incomeLabel = nameLabel:Clone()
	incomeLabel.Name = "Income"
	incomeLabel.Font = Enum.Font.GothamBold
	incomeLabel.Position = UDim2.fromScale(0, 0.55)
	incomeLabel.Size = UDim2.fromScale(1, 0.45)
	incomeLabel.TextColor3 = Color3.fromRGB(150, 255, 190)
	incomeLabel.Text = string.format("+%d / %d s", def.income, Config.Economy.IncomeTickSeconds)
	incomeLabel.Parent = gui

	CollectionService:AddTag(model, Tags.MemeVisual)
	model.Parent = ref.memes
	self.visuals[index][slot] = { uid = uid, memeId = memeId, model = model, label = gui }
end

-- Aligne l'affichage de la base sur le profil (après achat, placement, vol, amélioration…).
function BaseService:refresh(player: Player)
	local index = self.baseOf[player.UserId]
	local record = self.ctx.profiles:get(player)
	if not index or not record then
		return
	end
	local profile = record.profile
	local ref = self.ctx.map.bases[index]
	local visuals = self.visuals[index]
	self:_refreshTreadmill(index, profile)
	local capacity = Progression.slotCapacity(profile)
	local bySlot = Inventory.placedBySlot(profile)
	for slot = 1, MapLayout.maxSlots() do
		local pad = ref.pads[slot]
		local uid = bySlot[slot]
		local entry = uid and profile.memes[uid]
		local visual = visuals[slot]
		if visual and (visual.uid ~= uid or (entry and visual.memeId ~= entry.id)) then
			visual.model:Destroy()
			visuals[slot] = nil
			visual = nil
		end
		if uid and entry and not visual then
			self:_spawnMeme(index, slot, uid, entry.id)
		end
		local locked = slot > capacity
		pad:SetAttribute("HasMeme", uid ~= nil)
		pad:SetAttribute("MemeId", if entry then entry.id else "")
		pad:SetAttribute("Locked", locked)
		pad.Color = if locked then LOCKED else WHITE
		pad.LockGui.Enabled = locked
		local inTransit = uid ~= nil and self.ctx.theft:isLocked(player.UserId, uid)
		self:_setTransitVisual(index, slot, inTransit)
	end
end

function BaseService:_setTransitVisual(index: number, slot: number, inTransit: boolean)
	local ref = self.ctx.map.bases[index]
	ref.pads[slot]:SetAttribute("InTransit", inTransit)
	local visual = self.visuals[index] and self.visuals[index][slot]
	if not visual then
		return
	end
	for _, part in visual.model:GetDescendants() do
		if part:IsA("BasePart") then
			local baseTransparency = part:GetAttribute("BaseTransparency") or 0
			part.Transparency = if inTransit then math.max(baseTransparency, 0.82) else baseTransparency
		end
	end
	visual.label.MemeName.Text = if inTransit then "Emporté !" else Catalog.meme(visual.memeId).name
end

-- Fantôme sur le socle pendant le transport d'un mème (le mème reste au profil de la victime).
function BaseService:setTransit(baseIndex: number, slot: number, inTransit: boolean)
	if self.owners[baseIndex] then
		self:_setTransitVisual(baseIndex, slot, inTransit)
	end
end

function BaseService:setUnderTheft(baseIndex: number, value: boolean)
	local ref = self.ctx.map.bases[baseIndex]
	if ref then
		ref.model:SetAttribute("UnderTheft", value)
	end
end

function BaseService:applyTheme(baseIndex: number, cosmeticId: string)
	local ref = self.ctx.map.bases[baseIndex]
	local def = Catalog.cosmetic(cosmeticId) or Catalog.cosmetic(Config.Cosmetics.Default)
	local baseColor = ref.layout.color
	ref.floor.Color = def.floor or baseColor:Lerp(WHITE, 0.72)
	for _, part in ref.trims do
		part.Color = def.trim or baseColor
		part.Material = if def.neonTrim then Enum.Material.Neon else Enum.Material.SmoothPlastic
	end
end

-- Attributs publics lus par tous les clients (bulle d'état de la base).
function BaseService:updateProtection(player: Player)
	local index = self.baseOf[player.UserId]
	if not index then
		return
	end
	local ref = self.ctx.map.bases[index]
	local view = self.ctx.protection:view(player.UserId)
	ref.model:SetAttribute("ShieldUntil", view.protectedUntil)
	ref.model:SetAttribute("Zen", view.zen)
end

return BaseService
