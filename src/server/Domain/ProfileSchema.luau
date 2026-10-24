--!strict
-- Schéma du profil sauvegardé : valeurs par défaut, migrations et réparation des données chargées.
-- Règle d'or : une donnée invalide est corrigée ou ignorée, jamais propagée ;
-- un mème possédé n'est jamais supprimé pour cause de capacité (il part en réserve).
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Config = require(ReplicatedStorage.Shared.Config)
local Catalog = require(ReplicatedStorage.Shared.Catalog)
local MapLayout = require(ReplicatedStorage.Shared.MapLayout)
local Validate = require(script.Parent.Validate)
local Progression = require(script.Parent.Progression)

local ProfileSchema = {}

ProfileSchema.CURRENT_VERSION = 1

-- Statuts de chargement.
ProfileSchema.Status = table.freeze({
	New = "New", -- aucune donnée : profil neuf
	Ok = "Ok", -- données valides, version courante
	Migrated = "Migrated", -- ancienne version convertie
	Repaired = "Repaired", -- champs invalides corrigés
	FromFuture = "FromFuture", -- version plus récente que ce serveur : lecture seule
})

local STAT_KEYS = { "bought", "sold", "stolen", "lost", "defended" }

function ProfileSchema.default(now: number?)
	local discovered = {}
	for _, biomeId in Config.Biomes.Order do
		if Config.Biomes.Defs[biomeId].discoveredByDefault then
			discovered[biomeId] = true
		end
	end
	local upgrades = {}
	for _, upgradeId in Config.Upgrades.Order do
		upgrades[upgradeId] = 1
	end
	local stats = {}
	for _, key in STAT_KEYS do
		stats[key] = 0
	end
	return {
		version = ProfileSchema.CURRENT_VERSION,
		coins = Config.Economy.StartingCoins,
		memes = {},
		nextUid = 1,
		upgrades = upgrades,
		cosmetics = { owned = { [Config.Cosmetics.Default] = true }, equipped = Config.Cosmetics.Default },
		discovered = discovered,
		album = {},
		settings = { tutorialDone = false, zen = false },
		stats = stats,
		-- Identifiants des derniers achats Robux accordés (anti-doublon de ProcessReceipt).
		receipts = {},
		createdAt = now or 0,
	}
end

-- Migrations : MIGRATIONS[v] convertit une donnée de version v en version v + 1.
-- Version 0 = données sans champ `version` (prototype) : champs en majuscules et liste simple de mèmes.
local MIGRATIONS: { [number]: (any) -> any } = {
	[0] = function(raw: any)
		local out: any = { version = 1 }
		out.coins = if raw.coins ~= nil then raw.coins else raw.Coins
		if type(raw.memes) == "table" then
			out.memes = raw.memes
		elseif type(raw.Memes) == "table" then
			out.memes = {}
			local n = 0
			for _, memeId in ipairs(raw.Memes) do
				n += 1
				out.memes["m" .. n] = { id = memeId }
			end
			out.nextUid = n + 1
		end
		for _, key in { "nextUid", "upgrades", "cosmetics", "discovered", "album", "settings", "stats", "receipts", "createdAt" } do
			if raw[key] ~= nil and out[key] == nil then
				out[key] = raw[key]
			end
		end
		return out
	end,
}

local function isTable(value: any): boolean
	return type(value) == "table"
end

-- Construit un profil valide à partir de données de version courante (potentiellement corrompues).
local function sanitize(raw: any, now: number): (any, { string })
	local issues: { string } = {}
	local profile = ProfileSchema.default(now)
	local function issue(text: string)
		table.insert(issues, text)
	end

	-- Pièces
	if Validate.isFiniteNumber(raw.coins) then
		profile.coins = math.clamp(math.floor(raw.coins), 0, Config.Economy.MaxCoins)
		if profile.coins ~= raw.coins then
			issue("coins_clamped")
		end
	elseif raw.coins ~= nil then
		issue("coins_invalid")
	end

	-- Améliorations
	if isTable(raw.upgrades) then
		for _, upgradeId in Config.Upgrades.Order do
			local level = raw.upgrades[upgradeId]
			local maxLevel = #Config.Upgrades.Defs[upgradeId].levels
			if Validate.isInteger(level, 1, maxLevel) then
				profile.upgrades[upgradeId] = level
			elseif level ~= nil then
				issue("upgrade_invalid:" .. upgradeId)
			end
		end
	end

	-- Mèmes (triés par identifiant pour une réparation déterministe)
	local maxUid = 0
	if isTable(raw.memes) then
		local uids = {}
		local rekeyed = {}
		for uid, entry in raw.memes do
			if isTable(entry) and Catalog.isMeme(entry.id) then
				if Validate.isMemeUid(uid) then
					table.insert(uids, uid)
				else
					-- Mème valide mais identifiant illisible : on le garde sous un nouvel identifiant.
					table.insert(rekeyed, entry)
				end
			else
				issue("meme_dropped")
			end
		end
		if #rekeyed > 0 then
			issue("meme_rekeyed")
			local highest = 0
			for _, uid in uids do
				highest = math.max(highest, tonumber(string.sub(uid, 2)) or 0)
			end
			local source = table.clone(raw.memes)
			for _, entry in rekeyed do
				highest += 1
				local uid = "m" .. highest
				source[uid] = { id = entry.id }
				table.insert(uids, uid)
			end
			raw = table.clone(raw)
			raw.memes = source
		end
		table.sort(uids, function(a, b)
			return (tonumber(string.sub(a, 2)) or 0) < (tonumber(string.sub(b, 2)) or 0)
		end)
		local slotCapacity = Progression.slotCapacity(profile)
		local usedSlots = {}
		for index, uid in uids do
			if index > Config.Economy.MaxMemesHardCap then
				issue("meme_over_hard_cap")
				break
			end
			local entry = raw.memes[uid]
			local slot = entry.slot
			if slot ~= nil then
				if
					not Validate.isInteger(slot, 1, math.min(slotCapacity, MapLayout.maxSlots()))
					or usedSlots[slot]
				then
					issue("slot_reset:" .. uid)
					slot = nil
				else
					usedSlots[slot] = true
				end
			end
			profile.memes[uid] = { id = entry.id, slot = slot }
			profile.album[entry.id] = true
			maxUid = math.max(maxUid, tonumber(string.sub(uid, 2)) or 0)
		end
	end
	profile.nextUid = maxUid + 1
	if Validate.isInteger(raw.nextUid, 1, 1e9) and raw.nextUid > maxUid then
		profile.nextUid = raw.nextUid
	end

	-- Cosmétiques
	if isTable(raw.cosmetics) then
		if isTable(raw.cosmetics.owned) then
			for cosmeticId, owned in raw.cosmetics.owned do
				if owned == true and Catalog.cosmetic(cosmeticId) then
					profile.cosmetics.owned[cosmeticId] = true
				end
			end
		end
		local equipped = raw.cosmetics.equipped
		if type(equipped) == "string" and profile.cosmetics.owned[equipped] then
			profile.cosmetics.equipped = equipped
		elseif equipped ~= nil then
			issue("cosmetic_equipped_reset")
		end
	end

	-- Découvertes et album
	if isTable(raw.discovered) then
		for biomeId, value in raw.discovered do
			if value == true and Catalog.biome(biomeId) then
				profile.discovered[biomeId] = true
			end
		end
	end
	if isTable(raw.album) then
		for memeId, value in raw.album do
			if value == true and Catalog.isMeme(memeId) then
				profile.album[memeId] = true
			end
		end
	end

	-- Paramètres
	if isTable(raw.settings) then
		if type(raw.settings.tutorialDone) == "boolean" then
			profile.settings.tutorialDone = raw.settings.tutorialDone
		end
		if type(raw.settings.zen) == "boolean" then
			profile.settings.zen = raw.settings.zen
		end
	end

	-- Statistiques
	if isTable(raw.stats) then
		for _, key in STAT_KEYS do
			local value = raw.stats[key]
			if Validate.isInteger(value, 0, 1e12) then
				profile.stats[key] = value
			end
		end
	end

	-- Reçus d'achats Robux : chaînes courtes, historique borné (les plus récents).
	if isTable(raw.receipts) then
		local limit = Config.Monetization.ReceiptHistorySize
		for _, receipt in ipairs(raw.receipts) do
			if type(receipt) == "string" and #receipt > 0 and #receipt <= 64 then
				table.insert(profile.receipts, receipt)
			end
		end
		while #profile.receipts > limit do
			table.remove(profile.receipts, 1)
		end
	end

	if Validate.isFiniteNumber(raw.createdAt) then
		profile.createdAt = raw.createdAt
	end

	return profile, issues
end

-- Charge des données brutes du DataStore. Retourne (profil valide, statut, problèmes).
function ProfileSchema.load(raw: any, now: number): (any, string, { string })
	if raw == nil then
		return ProfileSchema.default(now), ProfileSchema.Status.New, {}
	end
	if type(raw) ~= "table" then
		-- Racine illisible : rien à récupérer. Le profil neuf conserve une trace pour le support.
		local profile = ProfileSchema.default(now)
		return profile, ProfileSchema.Status.Repaired, { "invalid_root:" .. type(raw) }
	end

	local version = raw.version
	if version == nil then
		version = 0
	end
	if not Validate.isInteger(version, 0, 1e6) then
		local profile, issues = sanitize(raw, now)
		table.insert(issues, 1, "invalid_version")
		return profile, ProfileSchema.Status.Repaired, issues
	end

	if version > ProfileSchema.CURRENT_VERSION then
		-- Données écrites par une version plus récente du jeu : on joue avec une lecture
		-- au mieux, mais le serveur ne doit jamais les écraser.
		local profile, issues = sanitize(raw, now)
		return profile, ProfileSchema.Status.FromFuture, issues
	end

	local data = raw
	local migrated = false
	while data.version == nil or data.version < ProfileSchema.CURRENT_VERSION do
		local from = data.version or 0
		local step = MIGRATIONS[from]
		if not step then
			break
		end
		data = step(data)
		migrated = true
	end

	local profile, issues = sanitize(data, now)
	local status = ProfileSchema.Status.Ok
	if migrated then
		status = ProfileSchema.Status.Migrated
	elseif #issues > 0 then
		status = ProfileSchema.Status.Repaired
	end
	return profile, status, issues
end

-- Copie profonde prête à être sauvegardée (aucune référence partagée avec l'état en jeu).
function ProfileSchema.serialize(profile: any): any
	local function copy(value: any): any
		if type(value) ~= "table" then
			return value
		end
		local out = {}
		for key, child in value do
			out[key] = copy(child)
		end
		return out
	end
	return copy(profile)
end

return ProfileSchema
