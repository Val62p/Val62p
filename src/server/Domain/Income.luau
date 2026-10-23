--!strict
-- Revenu d'un tick : somme des mèmes posés (hors mèmes en cours de vol) × multiplicateur.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Catalog = require(ReplicatedStorage.Shared.Catalog)
local Progression = require(script.Parent.Progression)

local Income = {}

-- `isLocked(uid)` : vrai si le mème est en cours de crochetage/transport (il ne rapporte rien).
function Income.perTick(profile: any, isLocked: ((uid: string) -> boolean)?): number
	local sum = 0
	for uid, entry in profile.memes do
		if entry.slot and not (isLocked and isLocked(uid)) then
			local def = Catalog.meme(entry.id)
			if def then
				sum += def.income
			end
		end
	end
	return math.floor(sum * Progression.incomeMultiplier(profile))
end

return Income
