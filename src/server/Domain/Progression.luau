--!strict
-- Lecture des effets d'améliorations d'un profil (niveaux bornés par la configuration).
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Config = require(ReplicatedStorage.Shared.Config)

local Progression = {}

function Progression.level(profile: any, upgradeId: string): number
	local def = Config.Upgrades.Defs[upgradeId]
	local level = profile.upgrades[upgradeId] or 1
	return math.clamp(level, 1, #def.levels)
end

function Progression.current(profile: any, upgradeId: string)
	local def = Config.Upgrades.Defs[upgradeId]
	return def.levels[Progression.level(profile, upgradeId)]
end

-- Niveau suivant (nil si niveau maximum atteint).
function Progression.nextLevel(profile: any, upgradeId: string): (any?, number)
	local def = Config.Upgrades.Defs[upgradeId]
	local nextIndex = Progression.level(profile, upgradeId) + 1
	return def.levels[nextIndex], nextIndex
end

function Progression.slotCapacity(profile: any): number
	return Progression.current(profile, "Slots").value
end

function Progression.storageCapacity(profile: any): number
	return Progression.current(profile, "Storage").value
end

function Progression.incomeMultiplier(profile: any): number
	return Progression.current(profile, "Income").value
end

function Progression.catchRadius(profile: any): number
	return Progression.current(profile, "Alarm").value
end

function Progression.lockpickBonus(profile: any): number
	return Progression.current(profile, "Alarm").lockpickBonus or 0
end

return Progression
