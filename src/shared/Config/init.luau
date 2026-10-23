--!strict
-- Point d'entrée unique de la configuration : prix, revenus, raretés, délais, limites.
-- Tout réglage d'équilibrage se fait ici (et nulle part ailleurs).

local function deepFreeze<T>(value: T): T
	if type(value) == "table" and not table.isfrozen(value :: any) then
		for _, child in value :: any do
			deepFreeze(child)
		end
		table.freeze(value :: any)
	end
	return value
end

local Config = {
	Economy = require(script.Economy),
	Rarities = require(script.Rarities),
	Memes = require(script.Memes),
	Biomes = require(script.Biomes),
	Upgrades = require(script.Upgrades),
	Cosmetics = require(script.Cosmetics),
	Theft = require(script.Theft),
	Map = require(script.Map),
	RateLimits = require(script.RateLimits),
	Monetization = require(script.Monetization),
}

return deepFreeze(Config)
