-- Outils de test, actifs UNIQUEMENT dans Roblox Studio (RunService:IsStudio()).
-- Sur un vrai serveur Roblox, l'action n'est même pas enregistrée : elle répond « action inconnue ».
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local Net = require(ReplicatedStorage.Shared.Net)
local Economy = require(ServerScriptService.Domain.Economy)
local Router = require(ServerScriptService.Services.Router)

local StudioTools = {}
StudioTools.__index = StudioTools

StudioTools.CoinsGift = 10000

function StudioTools.new(ctx: any)
	return setmetatable({ ctx = ctx }, StudioTools)
end

local TOOLS: { [string]: (self: any, player: Player) -> string } = {
	-- +10 000 pièces pour essayer les achats et améliorations.
	Coins = function(self, player)
		local profile = self.ctx.profiles:get(player).profile
		local amount = Economy.grant(profile, StudioTools.CoinsGift)
		self.ctx.profiles:markDirty(player)
		self.ctx.state:push(player)
		return "+" .. amount .. " pièces (outil Studio)."
	end,
	-- Fin immédiate de ses protections, pour tester le vol sans attendre 3 minutes.
	EndShield = function(self, player)
		self.ctx.protection:clearShields(player)
		return "Protections terminées (outil Studio)."
	end,
	-- Nouvel arrivage dans tous les kiosques.
	Restock = function(self)
		self.ctx.kiosks:rotateAll()
		return "Nouvel arrivage dans tous les kiosques (outil Studio)."
	end,
}

function StudioTools:use(player: Player, tool: string)
	if not self.ctx.isStudio then
		return Router.fail(Net.Codes.UnknownAction)
	end
	local handler = TOOLS[tool]
	if not handler then
		return Router.fail(Net.Codes.BadRequest)
	end
	return Router.ok({ text = handler(self, player) })
end

-- N'enregistre l'action que dans Studio.
function StudioTools:registerActions(router: any)
	if not self.ctx.isStudio then
		return
	end
	router:register(Net.Actions.StudioTool, {
		maxArgs = 1,
		validate = function(tool)
			return type(tool) == "string" and rawget(TOOLS, tool) ~= nil
		end,
		handler = function(player, tool)
			return self:use(player, tool)
		end,
	})
end

return StudioTools
