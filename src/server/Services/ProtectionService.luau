-- Protections contre le vol : protection de départ, protection après un vol subi, mode Zen.
-- Le mode Zen est l'option de protection accessible à tous : personne ne peut emprunter tes
-- mèmes, et tu ne peux pas en emprunter. Changement limité par un délai.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local Config = require(ReplicatedStorage.Shared.Config)
local Net = require(ReplicatedStorage.Shared.Net)
local Router = require(ServerScriptService.Services.Router)

local Codes = Net.Codes
local TheftCfg = Config.Theft

local ProtectionService = {}
ProtectionService.__index = ProtectionService

type State = {
	joinShieldUntil: number,
	shieldUntil: number,
	zen: boolean,
	zenCooldownUntil: number,
}

function ProtectionService.new(ctx: any)
	return setmetatable({ ctx = ctx, states = {} :: { [number]: State } }, ProtectionService)
end

local EMPTY: State = table.freeze({ joinShieldUntil = 0, shieldUntil = 0, zen = false, zenCooldownUntil = 0 })

function ProtectionService:_state(userId: number): State
	return self.states[userId] or EMPTY
end

function ProtectionService:onPlayerReady(player: Player, record: any)
	self.states[player.UserId] = {
		joinShieldUntil = self.ctx.now() + TheftCfg.JoinShieldSeconds,
		shieldUntil = 0,
		zen = record.profile.settings.zen == true,
		zenCooldownUntil = 0,
	}
	self:_changed(player)
end

function ProtectionService:onPlayerRemoving(player: Player)
	self.states[player.UserId] = nil
end

function ProtectionService:isZen(userId: number): boolean
	return self:_state(userId).zen
end

function ProtectionService:protectedUntil(userId: number): number
	local state = self:_state(userId)
	return math.max(state.joinShieldUntil, state.shieldUntil)
end

function ProtectionService:view(userId: number)
	local state = self:_state(userId)
	local now = self.ctx.now()
	local reason = ""
	if state.shieldUntil > now then
		reason = "Shield"
	elseif state.joinShieldUntil > now then
		reason = "Join"
	end
	return {
		zen = state.zen,
		zenCooldownUntil = state.zenCooldownUntil,
		protectedUntil = self:protectedUntil(userId),
		reason = reason,
	}
end

-- Lancer un vol met fin à sa propre protection de départ.
function ProtectionService:consumeJoinShield(player: Player)
	local state = self.states[player.UserId]
	if state and state.joinShieldUntil > 0 then
		state.joinShieldUntil = 0
		self:_changed(player)
	end
end

function ProtectionService:grantShield(player: Player, seconds: number)
	local state = self.states[player.UserId]
	if state then
		state.shieldUntil = math.max(state.shieldUntil, self.ctx.now() + seconds)
		self:_changed(player)
	end
end

-- Outil de test Studio : met fin aux protections du joueur.
function ProtectionService:clearShields(player: Player)
	local state = self.states[player.UserId]
	if state then
		state.joinShieldUntil = 0
		state.shieldUntil = 0
		self:_changed(player)
	end
end

function ProtectionService:toggleZen(player: Player)
	local state = self.states[player.UserId]
	if not state then
		return Router.fail(Codes.NotReady)
	end
	local now = self.ctx.now()
	if now < state.zenCooldownUntil then
		return Router.fail(Codes.ZenCooldown, { seconds = math.ceil(state.zenCooldownUntil - now) })
	end
	if self.ctx.theft:isInvolved(player) then
		return Router.fail(Codes.InTheft)
	end
	state.zen = not state.zen
	state.zenCooldownUntil = now + TheftCfg.ZenToggleCooldownSeconds
	local record = self.ctx.profiles:get(player)
	if record then
		record.profile.settings.zen = state.zen
		self.ctx.profiles:markDirty(player)
	end
	self:_changed(player)
	return Router.ok({ zen = state.zen })
end

function ProtectionService:_changed(player: Player)
	self.ctx.bases:updateProtection(player)
	self.ctx.state:push(player)
end

function ProtectionService:registerActions(router: any)
	router:register(Net.Actions.ToggleZen, {
		maxArgs = 0,
		handler = function(player)
			return self:toggleZen(player)
		end,
	})
end

return ProtectionService
