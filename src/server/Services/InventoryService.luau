-- Actions sur la collection : poser, ranger, revendre. Toujours dans SA base (le client ne
-- choisit qu'un socle de sa propre base ; aucun argument ne désigne une autre base).
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local Catalog = require(ReplicatedStorage.Shared.Catalog)
local MapLayout = require(ReplicatedStorage.Shared.MapLayout)
local Net = require(ReplicatedStorage.Shared.Net)
local Economy = require(ServerScriptService.Domain.Economy)
local Inventory = require(ServerScriptService.Domain.Inventory)
local Validate = require(ServerScriptService.Domain.Validate)
local Router = require(ServerScriptService.Services.Router)

local Codes = Net.Codes
local Actions = Net.Actions

local InventoryService = {}
InventoryService.__index = InventoryService

function InventoryService.new(ctx: any)
	return setmetatable({ ctx = ctx }, InventoryService)
end

function InventoryService:_changed(player: Player, refreshBase: boolean)
	self.ctx.profiles:markDirty(player)
	if refreshBase then
		self.ctx.bases:refresh(player)
	end
	self.ctx.state:push(player)
end

function InventoryService:place(player: Player, uid: string, slot: number?)
	if not self.ctx.bases:getBaseIndex(player) then
		return Router.fail(Codes.NoBase)
	end
	local profile = self.ctx.profiles:get(player).profile
	local ok, code, placedSlot = Inventory.place(profile, uid, slot)
	if not ok then
		return Router.fail(code)
	end
	self:_changed(player, true)
	return Router.ok({ slot = placedSlot, memeId = profile.memes[uid].id })
end

function InventoryService:store(player: Player, slot: number)
	if not self.ctx.bases:getBaseIndex(player) then
		return Router.fail(Codes.NoBase)
	end
	local profile = self.ctx.profiles:get(player).profile
	local uid = Inventory.uidAtSlot(profile, slot)
	if uid and self.ctx.theft:isLocked(player.UserId, uid) then
		return Router.fail(Codes.MemeBusy)
	end
	local ok, code, storedUid = Inventory.store(profile, slot)
	if not ok then
		return Router.fail(code)
	end
	self:_changed(player, true)
	return Router.ok({ uid = storedUid, memeId = profile.memes[storedUid].id })
end

function InventoryService:sell(player: Player, uid: string)
	local profile = self.ctx.profiles:get(player).profile
	local entry = profile.memes[uid]
	if not entry then
		return Router.fail(Codes.MemeNotFound)
	end
	if self.ctx.theft:isLocked(player.UserId, uid) then
		return Router.fail(Codes.MemeBusy)
	end
	local wasPlaced = entry.slot ~= nil
	Inventory.remove(profile, uid)
	local amount = Economy.grant(profile, Catalog.sellPrice(entry.id))
	profile.stats.sold += 1
	self:_changed(player, wasPlaced)
	return Router.ok({ amount = amount, memeId = entry.id, name = Catalog.meme(entry.id).name })
end

function InventoryService:registerActions(router: any)
	local maxSlots = MapLayout.maxSlots()
	router:register(Actions.PlaceMeme, {
		maxArgs = 2,
		validate = function(uid, slot)
			return Validate.isMemeUid(uid) and (slot == nil or Validate.isInteger(slot, 1, maxSlots))
		end,
		handler = function(player, uid, slot)
			return self:place(player, uid, slot)
		end,
	})
	router:register(Actions.StoreMeme, {
		maxArgs = 1,
		validate = function(slot)
			return Validate.isInteger(slot, 1, maxSlots)
		end,
		handler = function(player, slot)
			return self:store(player, slot)
		end,
	})
	router:register(Actions.SellMeme, {
		maxArgs = 1,
		validate = function(uid)
			return Validate.isMemeUid(uid)
		end,
		handler = function(player, uid)
			return self:sell(player, uid)
		end,
	})
end

return InventoryService
