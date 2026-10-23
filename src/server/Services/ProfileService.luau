--!strict
-- Profils joueurs persistés dans un DataStore, avec verrou de session.
--
-- Valeur stockée : { data = profil, lock = { job = JobId, at = os.time() }?, savedAt = number }
-- * Chargement (UpdateAsync) : prend le verrou s'il est libre, périmé ou détenu par ce serveur ;
--   sinon réessaie puis le reprend de force (l'ancien serveur ne pourra plus sauvegarder).
-- * Sauvegarde (UpdateAsync) : écrit seulement si ce serveur détient toujours le verrou.
-- * Échec de chargement : profil temporaire NON sauvegardable (le vrai profil n'est jamais écrasé).
-- * Version de données plus récente : lecture seule.
local ServerScriptService = game:GetService("ServerScriptService")
local ProfileSchema = require(ServerScriptService.Domain.ProfileSchema)

local ProfileService = {}
ProfileService.__index = ProfileService

ProfileService.LockTtlSeconds = 600
ProfileService.LockRefreshSeconds = 240
ProfileService.LockRetryAttempts = 5
ProfileService.LockRetryDelay = 4
ProfileService.ErrorRetryAttempts = 3
ProfileService.SaveDebounceSeconds = 3

export type Record = {
	player: Player,
	userId: number,
	key: string,
	profile: any,
	status: string,
	issues: { string },
	loaded: boolean,
	canSave: boolean,
	ownsLock: boolean,
	saving: boolean,
	revision: number,
	savedRevision: number,
	lastSaveAt: number,
	releaseRequested: boolean,
	saveScheduled: boolean,
}

export type Options = {
	store: any?, -- GlobalDataStore (ou doublure de test) ; nil = persistance indisponible
	jobId: string,
	wallClock: () -> number,
	wait: (number) -> (),
	delay: (number, () -> ()) -> (),
	log: (...any) -> (),
	isInGame: (player: Player) -> boolean,
}

function ProfileService.new(options: Options)
	return setmetatable({
		store = options.store,
		jobId = options.jobId,
		wallClock = options.wallClock,
		wait = options.wait,
		delay = options.delay,
		log = options.log,
		isInGame = options.isInGame,
		records = {} :: { [number]: Record },
	}, ProfileService)
end

function ProfileService:get(player: Player): Record?
	local record = self.records[player.UserId]
	if record and record.loaded then
		return record
	end
	return nil
end

function ProfileService:markDirty(player: Player)
	local record = self:get(player)
	if record then
		record.revision += 1
	end
end

function ProfileService:isDirty(record: Record): boolean
	return record.revision ~= record.savedRevision
end

-- Tente de prendre le verrou. Retourne "ok" + données brutes, "locked", ou "error" + message.
function ProfileService:_acquire(key: string, force: boolean): (string, any)
	local jobId = self.jobId
	local now = self.wallClock()
	local ttl = ProfileService.LockTtlSeconds
	local lockedByOther = false
	local raw: any = nil
	local ok, err = pcall(function()
		self.store:UpdateAsync(key, function(old: any)
			lockedByOther = false
			raw = nil
			local envelope: any = nil
			if type(old) == "table" and (old.data ~= nil or old.lock ~= nil or old.savedAt ~= nil) then
				envelope = old
				raw = old.data
			else
				raw = old -- donnée héritée sans enveloppe (ou nil)
			end
			local lock = envelope and envelope.lock
			if
				not force
				and type(lock) == "table"
				and lock.job ~= jobId
				and type(lock.at) == "number"
				and now - lock.at < ttl
			then
				lockedByOther = true
				return nil
			end
			return { data = raw, lock = { job = jobId, at = now }, savedAt = envelope and envelope.savedAt or nil }
		end)
	end)
	if not ok then
		return "error", err
	end
	if lockedByOther then
		return "locked", nil
	end
	return "ok", raw
end

function ProfileService:_releaseLock(key: string)
	local jobId = self.jobId
	local ok, err = pcall(function()
		self.store:UpdateAsync(key, function(old: any)
			if type(old) == "table" and type(old.lock) == "table" and old.lock.job == jobId then
				local copy = table.clone(old)
				copy.lock = nil
				return copy
			end
			return nil
		end)
	end)
	if not ok then
		self.log("[Profiles] libération du verrou impossible", key, err)
	end
end

function ProfileService:_finish(record: Record, raw: any, available: boolean): Record
	local now = self.wallClock()
	if not available then
		record.profile = ProfileSchema.default(now)
		record.status = "Unavailable"
		record.issues = {}
		record.canSave = false
		record.ownsLock = false
	else
		local profile, status, issues = ProfileSchema.load(raw, now)
		record.profile = profile
		record.status = status
		record.issues = issues
		record.ownsLock = true
		record.canSave = status ~= ProfileSchema.Status.FromFuture
		if status ~= ProfileSchema.Status.Ok then
			-- Profil neuf, migré ou réparé : à écrire au prochain cycle.
			record.revision += 1
		end
		if #issues > 0 then
			self.log("[Profiles] profil réparé", record.userId, table.concat(issues, ", "))
		end
	end
	record.loaded = true
	record.lastSaveAt = now
	return record
end

-- Charge le profil d'un joueur (bloquant). Retourne nil si le joueur est parti entre-temps.
function ProfileService:loadAsync(player: Player): Record?
	local userId = player.UserId
	local existing = self.records[userId]
	if existing then
		return if existing.loaded then existing else nil
	end
	local record: Record = {
		player = player,
		userId = userId,
		key = "player_" .. tostring(userId),
		profile = nil,
		status = "Loading",
		issues = {},
		loaded = false,
		canSave = false,
		ownsLock = false,
		saving = false,
		revision = 0,
		savedRevision = 0,
		lastSaveAt = 0,
		releaseRequested = false,
		saveScheduled = false,
	}
	self.records[userId] = record

	if not self.store then
		return self:_finish(record, nil, false)
	end

	local lockAttempts, errors = 0, 0
	local status, raw
	while true do
		status, raw = self:_acquire(record.key, lockAttempts >= ProfileService.LockRetryAttempts)
		if status == "ok" then
			break
		elseif status == "locked" then
			lockAttempts += 1
			self.log("[Profiles] profil verrouillé par un autre serveur, tentative", userId, lockAttempts)
			self.wait(ProfileService.LockRetryDelay)
		else
			errors += 1
			self.log("[Profiles] erreur DataStore au chargement", userId, raw)
			if errors >= ProfileService.ErrorRetryAttempts then
				break
			end
			self.wait(2 ^ (errors - 1))
		end
		if not self.isInGame(player) or record.releaseRequested then
			self.records[userId] = nil
			return nil
		end
	end

	if status ~= "ok" then
		return self:_finish(record, nil, false)
	end
	if not self.isInGame(player) or record.releaseRequested then
		self:_releaseLock(record.key)
		self.records[userId] = nil
		return nil
	end
	return self:_finish(record, raw, true)
end

-- Sauvegarde (bloquante). `release` libère le verrou (départ du joueur, fermeture).
function ProfileService:saveAsync(record: Record, release: boolean?): boolean
	if not record.loaded then
		return false
	end
	while record.saving do
		self.wait(0.1)
	end
	if not record.canSave then
		if release and record.ownsLock then
			record.ownsLock = false
			self:_releaseLock(record.key)
		end
		return false
	end

	record.saving = true
	local revision = record.revision
	local data = ProfileSchema.serialize(record.profile)
	local jobId = self.jobId
	local now = self.wallClock()
	local lostLock = false
	local success = false
	for attempt = 1, ProfileService.ErrorRetryAttempts do
		local ok, err = pcall(function()
			self.store:UpdateAsync(record.key, function(old: any)
				lostLock = false
				if type(old) == "table" and type(old.lock) == "table" and old.lock.job ~= jobId then
					lostLock = true
					return nil
				end
				return {
					data = data,
					lock = if release then nil else { job = jobId, at = now },
					savedAt = now,
				}
			end)
		end)
		if ok then
			success = true
			break
		end
		self.log("[Profiles] erreur DataStore à la sauvegarde", record.userId, err)
		if attempt < ProfileService.ErrorRetryAttempts then
			self.wait(2 ^ (attempt - 1))
		end
	end
	record.saving = false

	if lostLock then
		record.canSave = false
		record.ownsLock = false
		self.log("[Profiles] verrou repris par un autre serveur : sauvegardes arrêtées", record.userId)
		return false
	end
	if success then
		record.savedRevision = revision
		record.lastSaveAt = now
		if release then
			record.ownsLock = false
		end
	end
	return success
end

-- Sauvegarde rapprochée (ex. après un vol), regroupée sur quelques secondes.
function ProfileService:scheduleSave(player: Player)
	local record = self:get(player)
	if not record or record.saveScheduled or not record.canSave then
		return
	end
	record.saveScheduled = true
	self.delay(ProfileService.SaveDebounceSeconds, function()
		record.saveScheduled = false
		if self.records[record.userId] == record then
			self:saveAsync(record, false)
		end
	end)
end

-- Départ du joueur : sauvegarde finale + libération du verrou.
function ProfileService:saveAndReleaseAsync(player: Player)
	local record = self.records[player.UserId]
	if not record then
		return
	end
	if not record.loaded then
		record.releaseRequested = true
		return
	end
	self:saveAsync(record, true)
	if self.records[player.UserId] == record then
		self.records[player.UserId] = nil
	end
end

-- Sauvegarde périodique des profils modifiés (et rafraîchissement du verrou).
function ProfileService:autosave()
	local now = self.wallClock()
	for _, record in table.clone(self.records) do
		if
			record.loaded
			and record.canSave
			and (self:isDirty(record) or now - record.lastSaveAt >= ProfileService.LockRefreshSeconds)
		then
			self:saveAsync(record, false)
		end
	end
end

-- Fermeture du serveur : sauvegarde tout en parallèle, dans la limite de `timeout` secondes.
function ProfileService:saveAllAsync(spawn: (() -> ()) -> (), timeout: number)
	local pending = 0
	for _, record in table.clone(self.records) do
		pending += 1
		spawn(function()
			self:saveAndReleaseAsync(record.player)
			pending -= 1
		end)
	end
	local waited = 0
	while pending > 0 and waited < timeout do
		self.wait(0.25)
		waited += 0.25
	end
end

return ProfileService
