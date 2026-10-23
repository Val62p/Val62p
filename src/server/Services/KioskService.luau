-- Kiosques de biome : arrivages renouvelés à intervalle régulier, affichés sur des piédestaux.
-- Chaque offre porte une version : le client doit citer la version vue, ce qui empêche
-- d'acheter par erreur un mème différent de celui affiché.
local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local Config = require(ReplicatedStorage.Shared.Config)
local Catalog = require(ReplicatedStorage.Shared.Catalog)
local Format = require(ReplicatedStorage.Shared.Format)
local MapLayout = require(ReplicatedStorage.Shared.MapLayout)
local MemeAppearance = require(ReplicatedStorage.Shared.MemeAppearance)
local Tags = require(ReplicatedStorage.Shared.Tags)
local KioskRotation = require(ServerScriptService.Domain.KioskRotation)

local KioskCfg = Config.Map.Kiosk

local KioskService = {}
KioskService.__index = KioskService

export type Offer = { memeId: string, version: number }

function KioskService.new(ctx: any, random: () -> number)
	return setmetatable({
		ctx = ctx,
		random = random,
		offers = {} :: { [string]: { [number]: Offer } },
		version = 0,
		nextRotationAt = 0,
	}, KioskService)
end

function KioskService:getOffer(biomeId: string, pedestal: number): Offer?
	local list = self.offers[biomeId]
	return list and list[pedestal]
end

function KioskService:pedestalPosition(biomeId: string, pedestal: number): Vector3
	return MapLayout.pedestalCFrame(biomeId, pedestal).Position
end

function KioskService:_display(biomeId: string, pedestal: number, memeId: string)
	local kiosk = self.ctx.map and self.ctx.map.kiosks[biomeId]
	if not kiosk then
		return
	end
	local ref = kiosk.pedestals[pedestal]
	local def = Catalog.meme(memeId)
	local rarity = Catalog.memeRarity(memeId)
	ref.display:ClearAllChildren()
	local model = MemeAppearance.build(memeId, ref.topCFrame, { ring = true })
	CollectionService:AddTag(model, Tags.MemeVisual)
	model.Parent = ref.display
	ref.nameLabel.Text = def.name
	ref.rarityLabel.Text = rarity.displayName
	ref.rarityLabel.TextColor3 = rarity.color:Lerp(Color3.new(0, 0, 0), 0.25)
	ref.stroke.Color = rarity.color
	ref.priceLabel.Text = Format.coins(def.price)
	ref.incomeLabel.Text = string.format("+%d / %d s", def.income, Config.Economy.IncomeTickSeconds)
	ref.part:SetAttribute("MemeId", memeId)
	ref.part:SetAttribute("Price", def.price)
	ref.part:SetAttribute("OfferVersion", self.offers[biomeId][pedestal].version)
end

function KioskService:rotate(biomeId: string)
	local picks = KioskRotation.pick(biomeId, KioskCfg.Pedestals, self.random)
	local list = {}
	self.offers[biomeId] = list
	for index, memeId in picks do
		self.version += 1
		list[index] = { memeId = memeId, version = self.version }
		self:_display(biomeId, index, memeId)
	end
end

function KioskService:rotateAll()
	self.nextRotationAt = self.ctx.now() + KioskCfg.RotationSeconds
	for _, biomeId in Config.Biomes.Order do
		self:rotate(biomeId)
		local kiosk = self.ctx.map and self.ctx.map.kiosks[biomeId]
		if kiosk then
			kiosk.model:SetAttribute("NextRotationAt", self.nextRotationAt)
		end
	end
end

function KioskService:start()
	self:rotateAll()
	self.ctx.scheduler.spawn(function()
		while true do
			self.ctx.scheduler.wait(KioskCfg.RotationSeconds)
			self:rotateAll()
		end
	end)
end

return KioskService
