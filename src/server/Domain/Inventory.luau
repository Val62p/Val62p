--!strict
-- Inventaire d'un profil : mèmes posés sur des socles ou rangés en réserve.
-- Un mème possédé = profile.memes[uid] = { id = memeId, slot = number? }.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Config = require(ReplicatedStorage.Shared.Config)
local Catalog = require(ReplicatedStorage.Shared.Catalog)
local Net = require(ReplicatedStorage.Shared.Net)
local Progression = require(script.Parent.Progression)

local Codes = Net.Codes

local Inventory = {}

function Inventory.uidNumber(uid: string): number
	return tonumber(string.sub(uid, 2)) or 0
end

-- Identifiants triés (ordre stable, utile pour l'affichage et la réparation des données).
function Inventory.sortedUids(profile: any): { string }
	local uids = {}
	for uid in profile.memes do
		table.insert(uids, uid)
	end
	table.sort(uids, function(a, b)
		return Inventory.uidNumber(a) < Inventory.uidNumber(b)
	end)
	return uids
end

function Inventory.placedBySlot(profile: any): { [number]: string }
	local bySlot = {}
	for uid, entry in profile.memes do
		if entry.slot then
			bySlot[entry.slot] = uid
		end
	end
	return bySlot
end

function Inventory.uidAtSlot(profile: any, slot: number): string?
	for uid, entry in profile.memes do
		if entry.slot == slot then
			return uid
		end
	end
	return nil
end

function Inventory.counts(profile: any): (number, number, number)
	local placed, stored = 0, 0
	for _, entry in profile.memes do
		if entry.slot then
			placed += 1
		else
			stored += 1
		end
	end
	return placed, stored, placed + stored
end

function Inventory.firstFreeSlot(profile: any): number?
	local bySlot = Inventory.placedBySlot(profile)
	for slot = 1, Progression.slotCapacity(profile) do
		if not bySlot[slot] then
			return slot
		end
	end
	return nil
end

-- Peut-on recevoir un nouveau mème (achat ou vol) ?
function Inventory.hasRoom(profile: any): boolean
	local _, stored, total = Inventory.counts(profile)
	if total >= Config.Economy.MaxMemesHardCap then
		return false
	end
	return Inventory.firstFreeSlot(profile) ~= nil or stored < Progression.storageCapacity(profile)
end

-- Ajoute un mème neuf. `preferSlot` : le poser directement si un socle est libre.
-- Sinon il va en réserve, ou sur un socle libre si la réserve est pleine.
function Inventory.add(profile: any, memeId: string, preferSlot: boolean): (boolean, string, string?, number?)
	if not Catalog.isMeme(memeId) then
		return false, Codes.UnknownItem
	end
	if not Inventory.hasRoom(profile) then
		return false, Codes.InventoryFull
	end
	local _, stored = Inventory.counts(profile)
	local freeSlot = Inventory.firstFreeSlot(profile)
	local slot: number? = nil
	if freeSlot and (preferSlot or stored >= Progression.storageCapacity(profile)) then
		slot = freeSlot
	end
	local uid = "m" .. tostring(profile.nextUid)
	profile.nextUid += 1
	profile.memes[uid] = { id = memeId, slot = slot }
	profile.album[memeId] = true
	return true, Codes.Ok, uid, slot
end

-- Pose un mème de la réserve sur `slot` (ou le premier socle libre si `slot` est nil).
function Inventory.place(profile: any, uid: string, slot: number?): (boolean, string, number?)
	local entry = profile.memes[uid]
	if not entry then
		return false, Codes.MemeNotFound
	end
	if entry.slot then
		return false, Codes.AlreadyPlaced
	end
	local target = slot
	if target == nil then
		target = Inventory.firstFreeSlot(profile)
		if not target then
			return false, Codes.NoFreeSlot
		end
	else
		if target > Progression.slotCapacity(profile) then
			return false, Codes.SlotLocked
		end
		if Inventory.uidAtSlot(profile, target) then
			return false, Codes.SlotOccupied
		end
	end
	entry.slot = target
	return true, Codes.Ok, target
end

-- Range en réserve le mème posé sur `slot`.
function Inventory.store(profile: any, slot: number): (boolean, string, string?)
	local uid = Inventory.uidAtSlot(profile, slot)
	if not uid then
		return false, Codes.SlotEmpty
	end
	local _, stored = Inventory.counts(profile)
	if stored >= Progression.storageCapacity(profile) then
		return false, Codes.StorageFull
	end
	profile.memes[uid].slot = nil
	return true, Codes.Ok, uid
end

function Inventory.remove(profile: any, uid: string): any?
	local entry = profile.memes[uid]
	profile.memes[uid] = nil
	return entry
end

return Inventory
