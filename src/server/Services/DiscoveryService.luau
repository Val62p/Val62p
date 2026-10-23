-- Découverte des biomes : entrer dans un biome (position mesurée côté serveur) débloque
-- ses arrivages dans la boutique.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local MapLayout = require(ReplicatedStorage.Shared.MapLayout)
local Net = require(ReplicatedStorage.Shared.Net)

local DiscoveryService = {}
DiscoveryService.__index = DiscoveryService

DiscoveryService.IntervalSeconds = 1

function DiscoveryService.new(ctx: any)
	return setmetatable({ ctx = ctx }, DiscoveryService)
end

function DiscoveryService:check(player: Player)
	local ctx = self.ctx
	local record = ctx.profiles:get(player)
	local position = ctx.characters:getRootPosition(player)
	if not record or not position then
		return
	end
	local biomeId = MapLayout.biomeAt(position)
	if biomeId and not record.profile.discovered[biomeId] then
		record.profile.discovered[biomeId] = true
		ctx.profiles:markDirty(player)
		ctx.state:push(player)
		local name = Config.Biomes.Defs[biomeId].displayName
		ctx.notifier:send(
			player,
			Net.Notify.Discovery,
			"Nouveau biome découvert : " .. name .. " ! Ses arrivages apparaissent dans la boutique.",
			{ biomeId = biomeId }
		)
	end
end

function DiscoveryService:start()
	self.ctx.scheduler.spawn(function()
		while true do
			self.ctx.scheduler.wait(DiscoveryService.IntervalSeconds)
			for _, player in self.ctx.getPlayers() do
				self:check(player)
			end
		end
	end)
end

return DiscoveryService
