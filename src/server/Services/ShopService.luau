-- Boutique en monnaie du jeu : mèmes des kiosques, améliorations et cosmétiques.
-- Le prix vient toujours de la configuration serveur ; le client ne cite qu'un identifiant.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local Config = require(ReplicatedStorage.Shared.Config)
local Catalog = require(ReplicatedStorage.Shared.Catalog)
local Net = require(ReplicatedStorage.Shared.Net)
local Economy = require(ServerScriptService.Domain.Economy)
local Inventory = require(ServerScriptService.Domain.Inventory)
local Progression = require(ServerScriptService.Domain.Progression)
local Validate = require(ServerScriptService.Domain.Validate)
local Router = require(ServerScriptService.Services.Router)

local Codes = Net.Codes
local Actions = Net.Actions

local ShopService = {}
ShopService.__index = ShopService

function ShopService.new(ctx: any)
	return setmetatable({ ctx = ctx }, ShopService)
end

function ShopService:_changed(player: Player, refreshBase: boolean)
	self.ctx.profiles:markDirty(player)
	if refreshBase then
		self.ctx.bases:refresh(player)
	end
	self.ctx.state:push(player)
end

function ShopService:buyOffer(player: Player, biomeId: string, pedestal: number, version: number)
	local profile = self.ctx.profiles:get(player).profile
	local offer = self.ctx.kiosks:getOffer(biomeId, pedestal)
	if not offer then
		return Router.fail(Codes.UnknownItem)
	end
	if offer.version ~= version then
		return Router.fail(Codes.OfferChanged, { memeId = offer.memeId })
	end

	-- À portée du piédestal, ou biome déjà découvert pour un achat depuis la boutique.
	local position = self.ctx.characters:getRootPosition(player)
	local near = position ~= nil
		and (position - self.ctx.kiosks:pedestalPosition(biomeId, pedestal)).Magnitude <= Config.Map.Kiosk.BuyRange
	if not profile.discovered[biomeId] and not near then
		return Router.fail(Codes.BiomeLocked)
	end

	local def = Catalog.meme(offer.memeId)
	if not Inventory.hasRoom(profile) then
		return Router.fail(Codes.InventoryFull)
	end
	if not Economy.spend(profile, def.price) then
		return Router.fail(Codes.NotEnoughCoins, { missing = Economy.missing(profile, def.price) })
	end
	local ok, code, uid, slot = Inventory.add(profile, offer.memeId, false)
	if not ok then
		Economy.grant(profile, def.price)
		return Router.fail(code)
	end
	profile.discovered[biomeId] = true
	profile.stats.bought += 1
	self:_changed(player, slot ~= nil)
	return Router.ok({ memeId = offer.memeId, uid = uid, slot = slot or 0, name = def.name })
end

function ShopService:buyUpgrade(player: Player, upgradeId: string)
	local profile = self.ctx.profiles:get(player).profile
	local nextLevel, levelIndex = Progression.nextLevel(profile, upgradeId)
	if not nextLevel then
		return Router.fail(Codes.MaxLevel)
	end
	if not Economy.spend(profile, nextLevel.price) then
		return Router.fail(Codes.NotEnoughCoins, { missing = Economy.missing(profile, nextLevel.price) })
	end
	profile.upgrades[upgradeId] = levelIndex
	self:applyUpgradeEffects(player, upgradeId)
	return Router.ok({ upgradeId = upgradeId, level = levelIndex })
end

-- Conséquences visibles d'un nouveau niveau (achat en pièces ou en Robux).
function ShopService:applyUpgradeEffects(player: Player, upgradeId: string)
	if upgradeId == "Treadmill" then
		self.ctx.characters:applySpeed(player)
	end
	self:_changed(player, upgradeId == "Slots" or upgradeId == "Treadmill")
end

function ShopService:buyCosmetic(player: Player, cosmeticId: string)
	local profile = self.ctx.profiles:get(player).profile
	local def = Catalog.cosmetic(cosmeticId)
	if profile.cosmetics.owned[cosmeticId] then
		return Router.fail(Codes.AlreadyOwned)
	end
	if not Economy.spend(profile, def.price) then
		return Router.fail(Codes.NotEnoughCoins, { missing = Economy.missing(profile, def.price) })
	end
	profile.cosmetics.owned[cosmeticId] = true
	profile.cosmetics.equipped = cosmeticId
	self:_applyTheme(player, cosmeticId)
	self:_changed(player, false)
	return Router.ok({ cosmeticId = cosmeticId })
end

function ShopService:equipCosmetic(player: Player, cosmeticId: string)
	local profile = self.ctx.profiles:get(player).profile
	if not profile.cosmetics.owned[cosmeticId] then
		return Router.fail(Codes.NotOwned)
	end
	profile.cosmetics.equipped = cosmeticId
	self:_applyTheme(player, cosmeticId)
	self:_changed(player, false)
	return Router.ok({ cosmeticId = cosmeticId })
end

function ShopService:_applyTheme(player: Player, cosmeticId: string)
	local index = self.ctx.bases:getBaseIndex(player)
	if index then
		self.ctx.bases:applyTheme(index, cosmeticId)
	end
end

function ShopService:registerActions(router: any)
	router:register(Actions.BuyOffer, {
		maxArgs = 3,
		validate = function(biomeId, pedestal, version)
			return Validate.isKeyOf(biomeId, Config.Biomes.Defs)
				and Validate.isInteger(pedestal, 1, Config.Map.Kiosk.Pedestals)
				and Validate.isInteger(version, 0, 2 ^ 31)
		end,
		handler = function(player, biomeId, pedestal, version)
			return self:buyOffer(player, biomeId, pedestal, version)
		end,
	})
	router:register(Actions.BuyUpgrade, {
		maxArgs = 1,
		validate = function(upgradeId)
			return Validate.isKeyOf(upgradeId, Config.Upgrades.Defs)
		end,
		handler = function(player, upgradeId)
			return self:buyUpgrade(player, upgradeId)
		end,
	})
	router:register(Actions.BuyCosmetic, {
		maxArgs = 1,
		validate = function(cosmeticId)
			return Validate.isKeyOf(cosmeticId, Config.Cosmetics.Defs)
		end,
		handler = function(player, cosmeticId)
			return self:buyCosmetic(player, cosmeticId)
		end,
	})
	router:register(Actions.EquipCosmetic, {
		maxArgs = 1,
		validate = function(cosmeticId)
			return Validate.isKeyOf(cosmeticId, Config.Cosmetics.Defs)
		end,
		handler = function(player, cosmeticId)
			return self:equipCosmetic(player, cosmeticId)
		end,
	})
end

return ShopService
