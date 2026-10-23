-- Revenus passifs : une boucle serveur à intervalle fixe (pas de calcul par frame).
-- Seuls les joueurs connectés, avec une base, touchent les revenus de leurs mèmes posés.
-- Les pièces sont marquées « à sauvegarder » mais écrites par la sauvegarde périodique.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local Config = require(ReplicatedStorage.Shared.Config)
local Net = require(ReplicatedStorage.Shared.Net)
local Economy = require(ServerScriptService.Domain.Economy)
local Income = require(ServerScriptService.Domain.Income)

local IncomeService = {}
IncomeService.__index = IncomeService

function IncomeService.new(ctx: any)
	return setmetatable({ ctx = ctx }, IncomeService)
end

function IncomeService:tick()
	local ctx = self.ctx
	for _, player in ctx.getPlayers() do
		local record = ctx.profiles:get(player)
		if record and ctx.bases:getBaseIndex(player) then
			local userId = player.UserId
			local amount = Income.perTick(record.profile, function(uid)
				return ctx.theft:isLocked(userId, uid)
			end)
			if amount > 0 then
				local granted = Economy.grant(record.profile, amount)
				if granted > 0 then
					ctx.profiles:markDirty(player)
					ctx.state:push(player)
					ctx.notifier:send(player, Net.Notify.Income, "", { amount = granted })
				end
			end
		end
	end
end

function IncomeService:start()
	self.ctx.scheduler.spawn(function()
		while true do
			self.ctx.scheduler.wait(Config.Economy.IncomeTickSeconds)
			self:tick()
		end
	end)
end

return IncomeService
