--!strict
-- Envoie au client une vue de son état (lecture seule, aucune donnée d'autrui sensible).
-- Les envois sont regroupés : plusieurs changements dans la même frame = un seul message.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local Config = require(ReplicatedStorage.Shared.Config)
local Inventory = require(ServerScriptService.Domain.Inventory)
local Income = require(ServerScriptService.Domain.Income)
local Progression = require(ServerScriptService.Domain.Progression)

local StateSync = {}
StateSync.__index = StateSync

function StateSync.new(ctx: any, remote: any)
	return setmetatable({ ctx = ctx, remote = remote, pending = {} :: { [Player]: boolean } }, StateSync)
end

function StateSync:push(player: Player)
	if self.pending[player] then
		return
	end
	self.pending[player] = true
	self.ctx.scheduler.defer(function()
		self.pending[player] = nil
		if player.Parent ~= nil then
			self.remote:FireClient(player, self:buildView(player))
		end
	end)
end

function StateSync:buildView(player: Player): { [string]: any }
	local ctx = self.ctx
	local record = ctx.profiles:get(player)
	if not record then
		return { ready = false }
	end
	local profile = record.profile
	local userId = player.UserId
	local function isLocked(uid: string): boolean
		return ctx.theft:isLocked(userId, uid)
	end

	local memes = {}
	for _, uid in Inventory.sortedUids(profile) do
		local entry = profile.memes[uid]
		table.insert(memes, { uid = uid, id = entry.id, slot = entry.slot or 0, busy = isLocked(uid) })
	end

	local owned = {}
	for _, cosmeticId in Config.Cosmetics.Order do
		if profile.cosmetics.owned[cosmeticId] then
			table.insert(owned, cosmeticId)
		end
	end
	local discovered = {}
	for _, biomeId in Config.Biomes.Order do
		if profile.discovered[biomeId] then
			table.insert(discovered, biomeId)
		end
	end
	local album = {}
	for _, memeId in Config.Memes.Order do
		if profile.album[memeId] then
			table.insert(album, memeId)
		end
	end

	local protection = ctx.protection:view(userId)
	return {
		ready = true,
		coins = profile.coins,
		baseIndex = ctx.bases:getBaseIndex(player) or 0,
		capacity = {
			slots = Progression.slotCapacity(profile),
			storage = Progression.storageCapacity(profile),
		},
		memes = memes,
		upgrades = table.clone(profile.upgrades),
		cosmetics = { owned = owned, equipped = profile.cosmetics.equipped },
		discovered = discovered,
		album = album,
		tutorialDone = profile.settings.tutorialDone,
		zen = protection.zen,
		zenCooldownUntil = protection.zenCooldownUntil,
		protectedUntil = protection.protectedUntil,
		protectionReason = protection.reason,
		saveEnabled = record.canSave,
		incomePerTick = Income.perTick(profile, isLocked),
		carrying = ctx.theft:viewAsThief(player),
		robbery = ctx.theft:viewAsVictim(player),
		stats = table.clone(profile.stats),
	}
end

return StateSync
