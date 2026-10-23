--!strict
-- Règles du vol d'opportunité, sans dépendance au moteur : le service fournit un contexte
-- (mesuré côté serveur) et reçoit une décision. L'ordre des vérifications donne le message
-- le plus utile au joueur.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Net = require(ReplicatedStorage.Shared.Net)

local Codes = Net.Codes

local TheftRules = {}

export type StartContext = {
	now: number,
	isOwnBase: boolean,
	victimPresent: boolean,
	slotHasMeme: boolean,
	memeBusy: boolean,
	thiefBusy: boolean,
	thiefZen: boolean,
	thiefCooldownUntil: number,
	distance: number,
	maxDistance: number,
	victimZen: boolean,
	victimProtectedUntil: number,
	pairCooldownUntil: number,
	baseBusy: boolean,
	victimInBase: boolean,
	victimPlacedCount: number,
	minPlaced: number,
	thiefHasRoom: boolean,
}

function TheftRules.canStart(c: StartContext): (boolean, string)
	if c.isOwnBase then
		return false, Codes.OwnBase
	end
	if not c.victimPresent then
		return false, Codes.NoTarget
	end
	if not c.slotHasMeme then
		return false, Codes.SlotEmpty
	end
	if c.thiefBusy then
		return false, Codes.AlreadyCarrying
	end
	if c.thiefZen then
		return false, Codes.SelfZen
	end
	if c.now < c.thiefCooldownUntil then
		return false, Codes.ThiefCooldown
	end
	if c.distance > c.maxDistance then
		return false, Codes.TooFar
	end
	if c.victimZen then
		return false, Codes.TargetZen
	end
	if c.now < c.victimProtectedUntil then
		return false, Codes.TargetProtected
	end
	if c.now < c.pairCooldownUntil then
		return false, Codes.PairCooldown
	end
	if c.baseBusy or c.memeBusy then
		return false, Codes.BaseBusy
	end
	if c.victimInBase then
		return false, Codes.OwnerWatching
	end
	if c.victimPlacedCount < c.minPlaced then
		return false, Codes.LastMeme
	end
	if not c.thiefHasRoom then
		return false, Codes.NoRoom
	end
	return true, Codes.Ok
end

-- Issues possibles d'une étape de vol.
TheftRules.Outcome = table.freeze({
	Continue = "Continue",
	Lifted = "Lifted", -- crochetage réussi : passage au transport
	Delivered = "Delivered", -- arrivé dans sa base : vol réussi
	ThiefGone = "ThiefGone", -- voleur parti, mort ou sans personnage
	VictimGone = "VictimGone", -- victime partie
	LeftPad = "LeftPad", -- voleur trop loin du socle pendant le crochetage
	OwnerReturned = "OwnerReturned", -- propriétaire revenu dans sa base pendant le crochetage
	Caught = "Caught", -- propriétaire a touché le voleur
	Detected = "Detected", -- entrée dans la zone surveillée
	Timeout = "Timeout",
	Suspicious = "Suspicious", -- déplacement impossible (téléportation)
})

export type LockpickContext = {
	now: number,
	endsAt: number,
	thiefAlive: boolean,
	victimPresent: boolean,
	distanceToPad: number,
	maxDistance: number,
	victimInBase: boolean,
}

function TheftRules.evaluateLockpick(c: LockpickContext): string
	local Outcome = TheftRules.Outcome
	if not c.thiefAlive then
		return Outcome.ThiefGone
	end
	if not c.victimPresent then
		return Outcome.VictimGone
	end
	if c.distanceToPad > c.maxDistance then
		return Outcome.LeftPad
	end
	if c.victimInBase then
		return Outcome.OwnerReturned
	end
	if c.now >= c.endsAt then
		return Outcome.Lifted
	end
	return Outcome.Continue
end

export type CarryContext = {
	now: number,
	deadline: number,
	thiefAlive: boolean,
	victimPresent: boolean,
	speed: number,
	maxSpeed: number,
	victimDistance: number?, -- nil si la victime n'a pas de personnage
	catchRadius: number,
	thiefInSafeZone: boolean,
	thiefInOwnBase: boolean,
}

function TheftRules.evaluateCarry(c: CarryContext): string
	local Outcome = TheftRules.Outcome
	if not c.thiefAlive then
		return Outcome.ThiefGone
	end
	if not c.victimPresent then
		return Outcome.VictimGone
	end
	if c.speed > c.maxSpeed then
		return Outcome.Suspicious
	end
	if c.victimDistance and c.victimDistance <= c.catchRadius then
		return Outcome.Caught
	end
	if c.thiefInSafeZone then
		return Outcome.Detected
	end
	if c.thiefInOwnBase then
		return Outcome.Delivered
	end
	if c.now >= c.deadline then
		return Outcome.Timeout
	end
	return Outcome.Continue
end

return TheftRules
