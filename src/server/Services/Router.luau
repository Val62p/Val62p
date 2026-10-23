--!strict
-- Point d'entrée réseau unique : RemoteFunction `Action`.
-- Chaque action déclare un nombre maximal d'arguments, un validateur et un gestionnaire.
-- Ordre : nom d'action → débit global → débit de l'action → profil prêt → arguments → gestionnaire.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local Config = require(ReplicatedStorage.Shared.Config)
local Net = require(ReplicatedStorage.Shared.Net)
local RateLimiter = require(ServerScriptService.Domain.RateLimiter)

local Codes = Net.Codes

local Router = {}
Router.__index = Router

export type Result = { ok: boolean, code: string, data: { [string]: any }? }

export type ActionSpec = {
	maxArgs: number,
	validate: ((...any) -> boolean)?,
	handler: (player: Player, ...any) -> Result,
	requiresProfile: boolean?,
}

function Router.ok(data: { [string]: any }?): Result
	return { ok = true, code = Codes.Ok, data = data }
end

function Router.fail(code: string, data: { [string]: any }?): Result
	return { ok = false, code = code, data = data }
end

function Router.new(ctx: any)
	local self = setmetatable({
		ctx = ctx,
		specs = {} :: { [string]: ActionSpec },
		limiter = RateLimiter.new(ctx.clock or os.clock),
	}, Router)
	return self
end

function Router:register(action: string, spec: ActionSpec)
	assert(Net.Actions[action] == action, "Action non déclarée dans Net.Actions : " .. action)
	assert(Config.RateLimits.Actions[action], "Action sans limite de débit : " .. action)
	self.specs[action] = spec
end

function Router:dispatch(player: Player, action: any, ...: any): Result
	if type(action) ~= "string" or #action > 32 then
		return Router.fail(Codes.BadRequest)
	end
	local spec = rawget(self.specs, action)
	if not spec then
		return Router.fail(Codes.UnknownAction)
	end

	local global = Config.RateLimits.Global
	if not self.limiter:allow(player.UserId, "*", global.capacity, global.refillPerSecond) then
		return Router.fail(Codes.RateLimited)
	end
	local limit = Config.RateLimits.Actions[action]
	if not self.limiter:allow(player.UserId, action, limit.capacity, limit.refillPerSecond) then
		return Router.fail(Codes.RateLimited)
	end

	if spec.requiresProfile ~= false and not self.ctx.profiles:get(player) then
		return Router.fail(Codes.NotReady)
	end
	if select("#", ...) > spec.maxArgs then
		return Router.fail(Codes.BadRequest)
	end
	if spec.validate and not spec.validate(...) then
		return Router.fail(Codes.BadRequest)
	end

	local ok, result = pcall(spec.handler, player, ...)
	if not ok then
		self.ctx.log("[Router] erreur dans " .. action .. " : " .. tostring(result))
		return Router.fail(Codes.ServerError)
	end
	if type(result) ~= "table" or type(result.code) ~= "string" then
		return Router.fail(Codes.ServerError)
	end
	return result
end

function Router:bind(remote: RemoteFunction)
	remote.OnServerInvoke = function(player: Player, action: any, ...: any)
		return self:dispatch(player, action, ...)
	end
end

function Router:onPlayerRemoving(player: Player)
	self.limiter:forget(player.UserId)
end

return Router
