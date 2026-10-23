-- Vol d'opportunité, entièrement décidé par le serveur.
--
-- 1. Crochetage (quelques secondes) : le voleur reste près du socle ; la victime est alertée.
--    Le retour du propriétaire dans sa base l'interrompt.
-- 2. Transport visible (mème au-dessus de la tête, marche ralentie, délai limité) jusqu'à la
--    base du voleur. Interrompu si le propriétaire touche le voleur, si le voleur entre dans la
--    zone surveillée de la place, annule, meurt, quitte, dépasse le délai ou se téléporte.
-- 3. Issue claire : le mème change de propriétaire UNIQUEMENT à la livraison (opération
--    atomique en mémoire, puis sauvegarde rapprochée des deux profils). Dans tous les autres
--    cas il n'a jamais quitté le profil de la victime : aucune perte, aucun doublon.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local Config = require(ReplicatedStorage.Shared.Config)
local Catalog = require(ReplicatedStorage.Shared.Catalog)
local MapLayout = require(ReplicatedStorage.Shared.MapLayout)
local Net = require(ReplicatedStorage.Shared.Net)
local Economy = require(ServerScriptService.Domain.Economy)
local Inventory = require(ServerScriptService.Domain.Inventory)
local Progression = require(ServerScriptService.Domain.Progression)
local TheftRules = require(ServerScriptService.Domain.TheftRules)
local Validate = require(ServerScriptService.Domain.Validate)
local Router = require(ServerScriptService.Services.Router)

local Codes = Net.Codes
local Notify = Net.Notify
local Outcome = TheftRules.Outcome
local TheftCfg = Config.Theft

-- Fenêtre minimale pour mesurer la vitesse (lisse la gigue réseau).
local SPEED_WINDOW = 0.5

local TheftService = {}
TheftService.__index = TheftService

export type Theft = {
	id: number,
	thief: Player,
	victim: Player,
	thiefId: number,
	victimId: number,
	baseIndex: number,
	slot: number,
	uid: string,
	memeId: string,
	phase: string, -- "Lockpick" | "Carry"
	startedAt: number,
	endsAt: number,
	lastPosition: Vector3?,
	lastCheckAt: number,
	visuals: any,
}

function TheftService.new(ctx: any)
	return setmetatable({
		ctx = ctx,
		byThief = {} :: { [number]: Theft },
		byVictim = {} :: { [number]: Theft },
		byBase = {} :: { [number]: Theft },
		locked = {} :: { [string]: boolean },
		thiefCooldownUntil = {} :: { [number]: number },
		pairCooldownUntil = {} :: { [string]: number },
		nextId = 0,
		looping = false,
	}, TheftService)
end

local function lockKey(victimId: number, uid: string): string
	return tostring(victimId) .. ":" .. uid
end

local function pairKey(thiefId: number, victimId: number): string
	return tostring(thiefId) .. ">" .. tostring(victimId)
end

function TheftService:isLocked(victimId: number, uid: string): boolean
	return self.locked[lockKey(victimId, uid)] == true
end

function TheftService:isThief(player: Player): boolean
	return self.byThief[player.UserId] ~= nil
end

function TheftService:isInvolved(player: Player): boolean
	return self.byThief[player.UserId] ~= nil or self.byVictim[player.UserId] ~= nil
end

local function view(theft: Theft, other: Player)
	local def = Catalog.meme(theft.memeId)
	return {
		phase = theft.phase,
		memeId = theft.memeId,
		memeName = def and def.name or "",
		startedAt = theft.startedAt,
		endsAt = theft.endsAt,
		otherUserId = other.UserId,
		otherName = other.DisplayName,
		baseIndex = theft.baseIndex,
		slot = theft.slot,
	}
end

function TheftService:viewAsThief(player: Player)
	local theft = self.byThief[player.UserId]
	return theft and view(theft, theft.victim)
end

function TheftService:viewAsVictim(player: Player)
	local theft = self.byVictim[player.UserId]
	return theft and view(theft, theft.thief)
end

---------------------------------------------------------------------------
-- Démarrage
---------------------------------------------------------------------------

function TheftService:tryStart(thief: Player, baseIndex: number, slot: number)
	local ctx = self.ctx
	local now = ctx.now()
	local thiefRecord = ctx.profiles:get(thief)
	local thiefBase = ctx.bases:getBaseIndex(thief)
	if not thiefBase then
		return Router.fail(Codes.NoBase)
	end
	local victim = ctx.bases:getOwner(baseIndex)
	local victimRecord = victim and ctx.profiles:get(victim)
	local uid = victimRecord and Inventory.uidAtSlot(victimRecord.profile, slot)
	local thiefPosition = ctx.characters:getRootPosition(thief)
	local distance = if thiefPosition then (thiefPosition - ctx.bases:padPosition(baseIndex, slot)).Magnitude else math.huge
	local victimPosition = victim and ctx.characters:getRootPosition(victim)
	local placed = if victimRecord then (Inventory.counts(victimRecord.profile)) else 0

	local ok, code = TheftRules.canStart({
		now = now,
		isOwnBase = baseIndex == thiefBase,
		victimPresent = victimRecord ~= nil,
		slotHasMeme = uid ~= nil,
		memeBusy = victim ~= nil and uid ~= nil and self:isLocked(victim.UserId, uid),
		thiefBusy = self.byThief[thief.UserId] ~= nil,
		thiefZen = ctx.protection:isZen(thief.UserId),
		thiefCooldownUntil = self.thiefCooldownUntil[thief.UserId] or 0,
		distance = distance,
		maxDistance = TheftCfg.StartRange,
		victimZen = victim ~= nil and ctx.protection:isZen(victim.UserId),
		victimProtectedUntil = if victim then ctx.protection:protectedUntil(victim.UserId) else 0,
		pairCooldownUntil = if victim then self.pairCooldownUntil[pairKey(thief.UserId, victim.UserId)] or 0 else 0,
		baseBusy = self.byBase[baseIndex] ~= nil,
		victimInBase = victimPosition ~= nil and MapLayout.isInsideBase(baseIndex, victimPosition),
		victimPlacedCount = placed,
		minPlaced = TheftCfg.MinPlacedToSteal,
		thiefHasRoom = thiefRecord ~= nil and Inventory.hasRoom(thiefRecord.profile),
	})
	if not ok then
		return Router.fail(code)
	end
	assert(victim and victimRecord and uid)

	self.nextId += 1
	local memeId = victimRecord.profile.memes[uid].id
	local theft: Theft = {
		id = self.nextId,
		thief = thief,
		victim = victim,
		thiefId = thief.UserId,
		victimId = victim.UserId,
		baseIndex = baseIndex,
		slot = slot,
		uid = uid,
		memeId = memeId,
		phase = "Lockpick",
		startedAt = now,
		endsAt = now + TheftCfg.LockpickSeconds + Progression.lockpickBonus(victimRecord.profile),
		lastPosition = thiefPosition,
		lastCheckAt = now,
		visuals = nil,
	}
	self.byThief[theft.thiefId] = theft
	self.byVictim[theft.victimId] = theft
	self.byBase[baseIndex] = theft
	self.locked[lockKey(theft.victimId, uid)] = true

	ctx.protection:consumeJoinShield(thief)
	ctx.bases:setUnderTheft(baseIndex, true)
	local memeName = Catalog.meme(memeId).name
	ctx.notifier:send(
		victim,
		Notify.Alert,
		thief.DisplayName .. " essaie d'emporter " .. memeName .. " ! Reviens dans ta base pour l'en empêcher.",
		{ theft = true }
	)
	ctx.notifier:send(thief, Notify.Info, "Crochetage en cours… reste près du socle.")
	ctx.state:push(thief)
	ctx.state:push(victim)
	self:_ensureLoop()
	return Router.ok({ memeId = memeId, endsAt = theft.endsAt })
end

---------------------------------------------------------------------------
-- Boucle
---------------------------------------------------------------------------

function TheftService:_ensureLoop()
	if self.looping or not self.ctx.runLoops then
		return
	end
	self.looping = true
	self.ctx.scheduler.spawn(function()
		while next(self.byThief) ~= nil do
			self.ctx.scheduler.wait(TheftCfg.CheckInterval)
			self:step(self.ctx.now())
		end
		self.looping = false
	end)
end

function TheftService:_victimPresent(theft: Theft): boolean
	return self.ctx.isInGame(theft.victim)
		and self.ctx.bases:getOwner(theft.baseIndex) == theft.victim
		and self.ctx.profiles:get(theft.victim) ~= nil
end

function TheftService:step(now: number)
	local ctx = self.ctx
	local active = {}
	for _, theft in self.byThief do
		table.insert(active, theft)
	end
	table.sort(active, function(a, b)
		return a.id < b.id
	end)

	for _, theft in active do
		if self.byThief[theft.thiefId] ~= theft then
			continue
		end
		local thiefAlive = ctx.isInGame(theft.thief) and ctx.characters:isAlive(theft.thief)
		local victimPresent = self:_victimPresent(theft)
		local position = ctx.characters:getRootPosition(theft.thief)
		local victimPosition = ctx.characters:getRootPosition(theft.victim)

		if theft.phase == "Lockpick" then
			local outcome = TheftRules.evaluateLockpick({
				now = now,
				endsAt = theft.endsAt,
				thiefAlive = thiefAlive,
				victimPresent = victimPresent,
				distanceToPad = if position
					then (position - ctx.bases:padPosition(theft.baseIndex, theft.slot)).Magnitude
					else math.huge,
				maxDistance = TheftCfg.LockpickRange,
				victimInBase = victimPosition ~= nil and MapLayout.isInsideBase(theft.baseIndex, victimPosition),
			})
			if outcome == Outcome.Lifted then
				self:_lift(theft, now, position)
			elseif outcome ~= Outcome.Continue then
				self:_fail(theft, outcome)
			end
		else
			local speed = 0
			local elapsed = now - theft.lastCheckAt
			if position and theft.lastPosition and elapsed >= SPEED_WINDOW then
				speed = MapLayout.flatDistance(position, theft.lastPosition) / elapsed
			end
			local victimRecord = ctx.profiles:get(theft.victim)
			local thiefBase = ctx.bases:getBaseIndex(theft.thief)
			local outcome = TheftRules.evaluateCarry({
				now = now,
				deadline = theft.endsAt,
				thiefAlive = thiefAlive,
				victimPresent = victimPresent,
				speed = speed,
				maxSpeed = TheftCfg.MaxCarrySpeed,
				victimDistance = if position and victimPosition then (position - victimPosition).Magnitude else nil,
				catchRadius = if victimRecord then Progression.catchRadius(victimRecord.profile) else 0,
				thiefInSafeZone = position ~= nil and MapLayout.isInSafeZone(position),
				thiefInOwnBase = position ~= nil and thiefBase ~= nil and MapLayout.isInsideBase(thiefBase, position),
			})
			if elapsed >= SPEED_WINDOW or not theft.lastPosition then
				theft.lastPosition = position
				theft.lastCheckAt = now
			end
			if outcome == Outcome.Delivered then
				self:_complete(theft, now)
			elseif outcome ~= Outcome.Continue then
				self:_fail(theft, outcome)
			end
		end
	end
end

function TheftService:_lift(theft: Theft, now: number, position: Vector3?)
	local ctx = self.ctx
	theft.phase = "Carry"
	theft.endsAt = now + TheftCfg.CarrySeconds
	theft.lastPosition = position
	theft.lastCheckAt = now
	ctx.bases:setTransit(theft.baseIndex, theft.slot, true)
	theft.visuals = ctx.visuals.attach(theft.thief, theft.victim, theft.memeId)
	ctx.characters:setWalkSpeed(theft.thief, TheftCfg.CarryWalkSpeed)
	local memeName = Catalog.meme(theft.memeId).name
	ctx.notifier:send(
		theft.victim,
		Notify.Alert,
		theft.thief.DisplayName .. " emporte " .. memeName .. " ! Touche-le avant qu'il n'atteigne sa base.",
		{ theft = true }
	)
	ctx.notifier:send(
		theft.thief,
		Notify.Info,
		"Ramène " .. memeName .. " dans ta base en moins de " .. TheftCfg.CarrySeconds .. " s. Évite la place surveillée !"
	)
	ctx.state:push(theft.thief)
	ctx.state:push(theft.victim)
end

-- Retire le vol des index et nettoie les effets (sans décider de l'issue).
function TheftService:_clear(theft: Theft)
	local ctx = self.ctx
	self.byThief[theft.thiefId] = nil
	if self.byVictim[theft.victimId] == theft then
		self.byVictim[theft.victimId] = nil
	end
	if self.byBase[theft.baseIndex] == theft then
		self.byBase[theft.baseIndex] = nil
	end
	self.locked[lockKey(theft.victimId, theft.uid)] = nil
	ctx.visuals.detach(theft.visuals)
	theft.visuals = nil
	if ctx.bases:getOwner(theft.baseIndex) == theft.victim then
		ctx.bases:setTransit(theft.baseIndex, theft.slot, false)
	end
	ctx.bases:setUnderTheft(theft.baseIndex, false)
	if ctx.isInGame(theft.thief) then
		ctx.characters:setWalkSpeed(theft.thief, TheftCfg.NormalWalkSpeed)
	end
end

function TheftService:_complete(theft: Theft, now: number)
	local ctx = self.ctx
	local thiefRecord = ctx.profiles:get(theft.thief)
	local victimRecord = ctx.profiles:get(theft.victim)
	local entry = victimRecord and victimRecord.profile.memes[theft.uid]
	if not thiefRecord or not victimRecord or not entry or entry.id ~= theft.memeId then
		return self:_fail(theft, Outcome.VictimGone)
	end
	if not Inventory.hasRoom(thiefRecord.profile) then
		return self:_fail(theft, "NoRoom")
	end

	self:_clear(theft)
	-- Transfert : d'abord l'ajout chez le voleur, puis le retrait chez la victime.
	local added = Inventory.add(thiefRecord.profile, theft.memeId, true)
	if not added then
		return self:_notifyFailure(theft, "NoRoom")
	end
	Inventory.remove(victimRecord.profile, theft.uid)

	local def = Catalog.meme(theft.memeId)
	local insurance = Economy.grant(victimRecord.profile, math.floor(def.price * TheftCfg.InsuranceRatio))
	thiefRecord.profile.stats.stolen += 1
	victimRecord.profile.stats.lost += 1
	self.thiefCooldownUntil[theft.thiefId] = now + TheftCfg.ThiefCooldownSeconds
	self.pairCooldownUntil[pairKey(theft.thiefId, theft.victimId)] = now + TheftCfg.PairCooldownSuccessSeconds
	ctx.protection:grantShield(theft.victim, TheftCfg.VictimShieldSeconds)

	for _, player in { theft.thief, theft.victim } do
		ctx.profiles:markDirty(player)
		ctx.profiles:scheduleSave(player)
		ctx.bases:refresh(player)
		ctx.state:push(player)
	end
	ctx.notifier:send(theft.thief, Notify.Success, "Bien joué ! " .. def.name .. " a rejoint ta base.")
	ctx.notifier:send(
		theft.victim,
		Notify.Warning,
		string.format(
			"%s est reparti avec %s. Ton assurance te verse %d pièces et ta base est protégée %d min.",
			theft.thief.DisplayName,
			def.name,
			insurance,
			math.floor(TheftCfg.VictimShieldSeconds / 60)
		)
	)
end

local FAILURE_TEXT: { [string]: { thief: string?, victim: string?, victimKind: string? } } = {
	[Outcome.Caught] = {
		thief = "{victim} t'a rattrapé : {meme} retourne à sa place.",
		victim = "Bravo, tu as récupéré {meme} !",
		victimKind = Notify.Success,
	},
	[Outcome.OwnerReturned] = {
		thief = "{victim} est revenu surveiller sa base : tentative annulée.",
		victim = "Ta présence a fait fuir {thief} : {meme} est en sécurité.",
		victimKind = Notify.Success,
	},
	[Outcome.Detected] = {
		thief = "La place surveillée t'a repéré : {meme} retourne chez {victim}.",
		victim = "{meme} a été repéré sur la place et revient chez toi.",
	},
	[Outcome.Timeout] = {
		thief = "Trop tard ! {meme} retourne chez {victim}.",
		victim = "{meme} est revenu chez toi.",
	},
	[Outcome.LeftPad] = {
		thief = "Tu t'es éloigné du socle : tentative annulée.",
		victim = "Fausse alerte : {meme} est toujours là.",
	},
	[Outcome.Suspicious] = {
		thief = "Déplacement anormal détecté : tentative annulée.",
		victim = "{meme} est revenu chez toi.",
	},
	[Outcome.ThiefGone] = {
		victim = "{meme} est revenu chez toi.",
	},
	[Outcome.VictimGone] = {
		thief = "Le propriétaire est parti : tentative annulée.",
	},
	Cancelled = {
		thief = "Tentative annulée.",
		victim = "Fausse alerte : {meme} est revenu.",
	},
	NoRoom = {
		thief = "Ta base est pleine : {meme} retourne chez {victim}.",
		victim = "{meme} est revenu chez toi.",
	},
	ServerClosing = {},
}

function TheftService:_notifyFailure(theft: Theft, outcome: string)
	local ctx = self.ctx
	local texts = FAILURE_TEXT[outcome] or {}
	local values = {
		meme = Catalog.meme(theft.memeId).name,
		thief = theft.thief.DisplayName,
		victim = theft.victim.DisplayName,
	}
	if texts.thief then
		ctx.notifier:send(theft.thief, Notify.Warning, Net.format(texts.thief, values))
	end
	if texts.victim then
		ctx.notifier:send(theft.victim, texts.victimKind or Notify.Info, Net.format(texts.victim, values))
	end
	for _, player in { theft.thief, theft.victim } do
		if ctx.isInGame(player) then
			ctx.state:push(player)
		end
	end
end

function TheftService:_fail(theft: Theft, outcome: string)
	local ctx = self.ctx
	local now = ctx.now()
	self:_clear(theft)
	self.thiefCooldownUntil[theft.thiefId] = now + TheftCfg.ThiefCooldownSeconds
	local key = pairKey(theft.thiefId, theft.victimId)
	self.pairCooldownUntil[key] = math.max(self.pairCooldownUntil[key] or 0, now + TheftCfg.PairCooldownFailSeconds)
	if outcome == Outcome.Caught or outcome == Outcome.OwnerReturned then
		local victimRecord = ctx.profiles:get(theft.victim)
		if victimRecord then
			victimRecord.profile.stats.defended += 1
			ctx.profiles:markDirty(theft.victim)
		end
	end
	self:_notifyFailure(theft, outcome)
end

---------------------------------------------------------------------------
-- Événements externes
---------------------------------------------------------------------------

function TheftService:cancel(player: Player)
	local theft = self.byThief[player.UserId]
	if not theft then
		return Router.fail(Codes.NotCarrying)
	end
	self:_fail(theft, "Cancelled")
	return Router.ok()
end

function TheftService:onCharacterDied(player: Player)
	local theft = self.byThief[player.UserId]
	if theft then
		self:_fail(theft, Outcome.ThiefGone)
	end
end

-- À appeler AVANT la libération de la base et la sauvegarde du profil.
function TheftService:onPlayerRemoving(player: Player)
	local asThief = self.byThief[player.UserId]
	if asThief then
		self:_fail(asThief, Outcome.ThiefGone)
	end
	local asVictim = self.byVictim[player.UserId]
	if asVictim then
		self:_fail(asVictim, Outcome.VictimGone)
	end
end

function TheftService:cancelAll(reason: string)
	for _, theft in table.clone(self.byThief) do
		self:_fail(theft, reason)
	end
end

function TheftService:registerActions(router: any)
	local maxSlots = MapLayout.maxSlots()
	local baseCount = MapLayout.baseCount()
	router:register(Net.Actions.StartTheft, {
		maxArgs = 2,
		validate = function(baseIndex, slot)
			return Validate.isInteger(baseIndex, 1, baseCount) and Validate.isInteger(slot, 1, maxSlots)
		end,
		handler = function(player, baseIndex, slot)
			return self:tryStart(player, baseIndex, slot)
		end,
	})
	router:register(Net.Actions.CancelTheft, {
		maxArgs = 0,
		handler = function(player)
			return self:cancel(player)
		end,
	})
end

return TheftService
