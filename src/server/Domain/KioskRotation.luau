--!strict
-- Choix des arrivages d'un kiosque : le premier piédestal propose toujours un mème commun
-- (accessible à tous), les suivants sont tirés selon le poids de rareté, sans doublon.
-- Consulter les kiosques est gratuit : ce n'est pas un tirage payant.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Config = require(ReplicatedStorage.Shared.Config)
local Catalog = require(ReplicatedStorage.Shared.Catalog)

local KioskRotation = {}

local function weightOf(memeId: string): number
	local def = Config.Memes.Defs[memeId]
	return Config.Rarities.Defs[def.rarity].kioskWeight
end

local function pickWeighted(pool: { string }, random: () -> number): number
	local total = 0
	for _, memeId in pool do
		total += weightOf(memeId)
	end
	local roll = random() * total
	for index, memeId in pool do
		roll -= weightOf(memeId)
		if roll < 0 then
			return index
		end
	end
	return #pool
end

-- `random()` doit renvoyer un réel dans [0, 1).
function KioskRotation.pick(biomeId: string, count: number, random: () -> number): { string }
	local pool = table.clone(Catalog.memesInBiome(biomeId))
	local offers = {}
	if #pool == 0 then
		return offers
	end

	local commons = {}
	for index, memeId in pool do
		if Config.Memes.Defs[memeId].rarity == "Common" then
			table.insert(commons, index)
		end
	end
	if #commons > 0 then
		local chosen = commons[math.floor(random() * #commons) + 1] or commons[1]
		table.insert(offers, table.remove(pool, chosen) :: string)
	end

	while #offers < count and #pool > 0 do
		table.insert(offers, table.remove(pool, pickWeighted(pool, random)) :: string)
	end
	return offers
end

return KioskRotation
