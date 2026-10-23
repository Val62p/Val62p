--!strict
-- Requêtes en lecture sur la configuration (index précalculés, aucune donnée en double).
local Config = require(script.Parent.Config)

local Catalog = {}

local memesByBiome: { [string]: { string } } = {}
for _, memeId in Config.Memes.Order do
	local def = Config.Memes.Defs[memeId]
	local list = memesByBiome[def.biome]
	if not list then
		list = {}
		memesByBiome[def.biome] = list
	end
	table.insert(list, memeId)
end

function Catalog.meme(memeId: any)
	if type(memeId) ~= "string" then
		return nil
	end
	return Config.Memes.Defs[memeId]
end

function Catalog.isMeme(memeId: any): boolean
	return Catalog.meme(memeId) ~= nil
end

function Catalog.memeIds(): { string }
	return Config.Memes.Order
end

function Catalog.memesInBiome(biomeId: string): { string }
	return memesByBiome[biomeId] or {}
end

function Catalog.rarity(rarityId: string)
	return Config.Rarities.Defs[rarityId]
end

function Catalog.memeRarity(memeId: string)
	local def = Catalog.meme(memeId)
	return def and Config.Rarities.Defs[def.rarity]
end

function Catalog.biome(biomeId: any)
	if type(biomeId) ~= "string" then
		return nil
	end
	return Config.Biomes.Defs[biomeId]
end

function Catalog.upgrade(upgradeId: any)
	if type(upgradeId) ~= "string" then
		return nil
	end
	return Config.Upgrades.Defs[upgradeId]
end

function Catalog.cosmetic(cosmeticId: any)
	if type(cosmeticId) ~= "string" then
		return nil
	end
	return Config.Cosmetics.Defs[cosmeticId]
end

function Catalog.sellPrice(memeId: string): number
	local def = Catalog.meme(memeId)
	if not def then
		return 0
	end
	return math.floor(def.price * Config.Economy.SellRefundRatio)
end

return Catalog
