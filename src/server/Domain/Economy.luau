--!strict
-- Opérations sur le solde : toujours des entiers, bornés entre 0 et MaxCoins.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Config = require(ReplicatedStorage.Shared.Config)

local Economy = {}

local function sanitizeAmount(amount: number): number
	if amount ~= amount or amount == math.huge or amount == -math.huge then
		return 0
	end
	return math.max(0, math.floor(amount))
end

function Economy.canAfford(profile: any, price: number): boolean
	return profile.coins >= sanitizeAmount(price)
end

function Economy.missing(profile: any, price: number): number
	return math.max(0, sanitizeAmount(price) - profile.coins)
end

-- Retire `price` si le solde le permet. Retourne true si le paiement a eu lieu.
function Economy.spend(profile: any, price: number): boolean
	local amount = sanitizeAmount(price)
	if profile.coins < amount then
		return false
	end
	profile.coins -= amount
	return true
end

-- Ajoute des pièces (plafonné). Retourne le montant réellement crédité.
function Economy.grant(profile: any, amount: number): number
	local value = sanitizeAmount(amount)
	local before = profile.coins
	profile.coins = math.min(Config.Economy.MaxCoins, before + value)
	return profile.coins - before
end

return Economy
