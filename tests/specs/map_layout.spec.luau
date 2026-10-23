--!nocheck
-- Géométrie de la carte : bases, socles, kiosques, zones.
local Fakes = require("../lib/Fakes")

return function(T, Loader)
	local clock = Fakes.clock()
	Fakes.installServices(Loader, clock)
	local MapLayout = Loader.require("ReplicatedStorage.Shared.MapLayout")
	local Config = Loader.require("ReplicatedStorage.Shared.Config")
	local Vector3 = Loader.roblox.Vector3

	local half = Config.Map.Base.Size / 2

	T.test("une base par paire de joueurs attendus, chacune dans son biome", function()
		T.eq(MapLayout.baseCount(), #Config.Biomes.Order * Config.Map.BasesPerBiome)
		for _, base in MapLayout.bases() do
			T.eq(MapLayout.biomeAt(base.cframe.Position), base.biomeId, "base " .. base.index)
			-- Les 4 coins restent sur le disque du biome.
			for _, corner in { { -1, -1 }, { -1, 1 }, { 1, -1 }, { 1, 1 } } do
				local p = (base.cframe * Loader.roblox.CFrame.new(corner[1] * half, 0, corner[2] * half)).Position
				local center = MapLayout.biomeFrame(base.biomeId).Position
				T.truthy(MapLayout.flatDistance(p, center) < Config.Map.BiomeRadius, "coin dans le biome")
				T.falsy(MapLayout.isOnPlaza(p), "coin hors de la place")
			end
		end
	end)

	T.test("les bases ne se chevauchent pas", function()
		local bases = MapLayout.bases()
		for i = 1, #bases do
			for j = i + 1, #bases do
				local d = MapLayout.flatDistance(bases[i].cframe.Position, bases[j].cframe.Position)
				T.truthy(d > Config.Map.Base.Size * 1.5, "écart entre bases " .. i .. " et " .. j)
			end
		end
	end)

	T.test("chaque socle est dans sa base et l'entrée regarde le chemin", function()
		for _, base in MapLayout.bases() do
			for slot = 1, MapLayout.maxSlots() do
				local cf = MapLayout.slotCFrame(base.index, slot)
				T.truthy(MapLayout.isInsideBase(base.index, cf.Position), "socle " .. slot)
				for other = 1, MapLayout.baseCount() do
					if other ~= base.index then
						T.falsy(MapLayout.isInsideBase(other, cf.Position), "socle hors des autres bases")
					end
				end
			end
			local axis = MapLayout.biomeFrame(base.biomeId)
			local front = base.cframe.Position + base.cframe.LookVector * half
			local localFront = axis:PointToObjectSpace(front)
			local localCenter = axis:PointToObjectSpace(base.cframe.Position)
			T.truthy(math.abs(localFront.X) < math.abs(localCenter.X), "entrée tournée vers le chemin")
			T.truthy(MapLayout.isInsideBase(base.index, MapLayout.homeCFrame(base.index).Position), "point de retour")
		end
	end)

	T.test("kiosques et piédestaux dans leur biome, hors des bases", function()
		for _, biomeId in Config.Biomes.Order do
			for pedestal = 1, Config.Map.Kiosk.Pedestals do
				local p = MapLayout.pedestalCFrame(biomeId, pedestal).Position
				T.eq(MapLayout.biomeAt(p), biomeId)
				for _, base in MapLayout.bases() do
					T.falsy(MapLayout.isInsideBase(base.index, p), "piédestal hors base")
				end
			end
		end
	end)

	T.test("zone surveillée au centre, hors des biomes", function()
		T.truthy(MapLayout.isInSafeZone(Vector3.new(0, 3, 0)))
		T.truthy(MapLayout.isInSafeZone(Vector3.new(20, 3, 10)))
		T.falsy(MapLayout.isInSafeZone(Vector3.new(0, 3, -60)))
		T.eq(MapLayout.biomeAt(Vector3.new(0, 3, 0)), nil)
		for _, spawn in MapLayout.spawnCFrames() do
			T.truthy(MapLayout.isOnPlaza(spawn.Position), "spawn sur la place")
		end
	end)

	T.test("le trajet direct entre deux bases évite la zone surveillée", function()
		-- Garantit qu'un voleur peut toujours rentrer sans traverser la place surveillée.
		local bases = MapLayout.bases()
		for i = 1, #bases do
			for j = 1, #bases do
				if i ~= j then
					local a, b = bases[i].cframe.Position, bases[j].cframe.Position
					local clear = true
					for step = 0, 50 do
						local p = a:Lerp(b, step / 50)
						if MapLayout.isInSafeZone(p) then
							clear = false
						end
					end
					T.truthy(clear, "trajet " .. i .. " → " .. j)
				end
			end
		end
	end)

	T.test("isDecorSpotFree évite chemin, bases et kiosque", function()
		for _, biomeId in Config.Biomes.Order do
			local frame = MapLayout.biomeFrame(biomeId)
			T.falsy(MapLayout.isDecorSpotFree(biomeId, frame.Position, 2), "centre (chemin)")
			T.falsy(MapLayout.isDecorSpotFree(biomeId, MapLayout.kioskFrame(biomeId).Position, 2), "kiosque")
			for _, base in MapLayout.bases() do
				if base.biomeId == biomeId then
					T.falsy(MapLayout.isDecorSpotFree(biomeId, base.cframe.Position, 2), "base")
				end
			end
		end
	end)
end
