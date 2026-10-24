--!strict
-- Géométrie de la carte, entièrement dérivée de Config.Map et Config.Biomes.
-- Utilisée par le serveur (construction de la carte, validations de distance et de zone)
-- et par le client (repères, ambiance). Aucune instance n'est créée ici.

local Config = require(script.Parent.Config)

local MapCfg = Config.Map
local BaseCfg = MapCfg.Base
local KioskCfg = MapCfg.Kiosk

local MapLayout = {}

export type BaseLayout = {
	index: number,
	biomeId: string,
	cframe: CFrame, -- centre du dessus du sol de la base ; LookVector = côté entrée
	color: Color3,
}

local function direction(angleDeg: number): Vector3
	local r = math.rad(angleDeg)
	return Vector3.new(math.cos(r), 0, -math.sin(r))
end

local function flatDistance(a: Vector3, b: Vector3): number
	local dx, dz = a.X - b.X, a.Z - b.Z
	return math.sqrt(dx * dx + dz * dz)
end
MapLayout.flatDistance = flatDistance

-- Repère d'un biome : origine au centre (dessus du sol), LookVector vers l'extérieur de la carte.
local biomeFrames: { [string]: CFrame } = {}
for _, biomeId in Config.Biomes.Order do
	local u = direction(Config.Biomes.Defs[biomeId].angleDeg)
	local center = u * MapCfg.BiomeDistance + Vector3.new(0, MapCfg.BiomeTopY, 0)
	biomeFrames[biomeId] = CFrame.lookAt(center, center + u)
end

function MapLayout.biomeFrame(biomeId: string): CFrame
	return biomeFrames[biomeId]
end

-- Bases : deux par biome, de part et d'autre du chemin, entrée tournée vers le chemin.
local bases: { BaseLayout } = {}
for _, biomeId in Config.Biomes.Order do
	local frame = biomeFrames[biomeId]
	local u, t = frame.LookVector, frame.RightVector
	for k = 1, MapCfg.BasesPerBiome do
		local side = if k % 2 == 1 then -1 else 1
		local spread = math.ceil(k / 2)
		local center = frame.Position + u * BaseCfg.RadialOffset + t * side * BaseCfg.TangentOffset * spread
		center = Vector3.new(center.X, MapCfg.BiomeTopY + BaseCfg.FloorThickness, center.Z)
		local index = #bases + 1
		table.insert(bases, {
			index = index,
			biomeId = biomeId,
			cframe = CFrame.lookAt(center, center - t * side),
			color = MapCfg.BaseColors[(index - 1) % #MapCfg.BaseColors + 1],
		})
	end
end

function MapLayout.baseCount(): number
	return #bases
end

function MapLayout.base(baseIndex: number): BaseLayout?
	return bases[baseIndex]
end

function MapLayout.bases(): { BaseLayout }
	return bases
end

function MapLayout.maxSlots(): number
	return BaseCfg.SlotColumns * BaseCfg.SlotRows
end

function MapLayout.slotLocal(slot: number): Vector3
	local col = (slot - 1) % BaseCfg.SlotColumns + 1
	local row = (slot - 1) // BaseCfg.SlotColumns + 1
	local x = (col - (BaseCfg.SlotColumns + 1) / 2) * BaseCfg.SlotSpacing
	return Vector3.new(x, 0, BaseCfg.RowZ[row])
end

-- Dessus du socle, orienté comme la base (le mème regarde l'entrée).
function MapLayout.slotCFrame(baseIndex: number, slot: number): CFrame
	local base = bases[baseIndex]
	return base.cframe * CFrame.new(MapLayout.slotLocal(slot) + Vector3.new(0, BaseCfg.PadHeight, 0))
end

-- Point d'arrivée de la téléportation « Ma base » (face aux socles).
function MapLayout.homeCFrame(baseIndex: number): CFrame
	local base = bases[baseIndex]
	return base.cframe * CFrame.new(0, 3, -12) * CFrame.Angles(0, math.pi, 0)
end

-- Tapis de course : dans le coin avant de la base, derrière le muret, loin des socles.
-- Repère : dessus du sol, axe de course en Z (la console est côté +Z, face aux socles).
MapLayout.TreadmillOffset = Vector3.new(-13.5, 0, -9.5)

function MapLayout.treadmillCFrame(baseIndex: number): CFrame
	return bases[baseIndex].cframe * CFrame.new(MapLayout.TreadmillOffset)
end

function MapLayout.isInsideBase(baseIndex: number, position: Vector3): boolean
	local base = bases[baseIndex]
	if not base then
		return false
	end
	local p = base.cframe:PointToObjectSpace(position)
	local half = BaseCfg.Size / 2 + 1
	return math.abs(p.X) <= half and math.abs(p.Z) <= half and p.Y >= -4 and p.Y <= 30
end

-- Kiosque : face au centre du biome (là où arrivent les joueurs).
local kioskFrames: { [string]: CFrame } = {}
for _, biomeId in Config.Biomes.Order do
	local frame = biomeFrames[biomeId]
	local position = frame.Position + frame.LookVector * KioskCfg.RadialOffset
	kioskFrames[biomeId] = CFrame.lookAt(position, position - frame.LookVector)
end

function MapLayout.kioskFrame(biomeId: string): CFrame
	return kioskFrames[biomeId]
end

-- Dessus d'un piédestal ; le n°1 est à gauche pour un joueur qui fait face au kiosque.
function MapLayout.pedestalCFrame(biomeId: string, pedestal: number): CFrame
	local offset = ((KioskCfg.Pedestals + 1) / 2 - pedestal) * KioskCfg.PedestalSpacing
	return kioskFrames[biomeId] * CFrame.new(offset, KioskCfg.PedestalHeight, 0)
end

function MapLayout.biomeAt(position: Vector3): string?
	for _, biomeId in Config.Biomes.Order do
		if flatDistance(position, biomeFrames[biomeId].Position) <= MapCfg.BiomeRadius then
			return biomeId
		end
	end
	return nil
end

function MapLayout.isInSafeZone(position: Vector3): boolean
	return flatDistance(position, Vector3.zero) <= MapCfg.SafeZoneRadius and position.Y < 40
end

function MapLayout.isOnPlaza(position: Vector3): boolean
	return flatDistance(position, Vector3.zero) <= MapCfg.PlazaRadius
end

function MapLayout.spawnCFrames(): { CFrame }
	local list = {}
	for i = 1, MapCfg.SpawnCount do
		local angle = math.rad(45 + (i - 1) * (360 / MapCfg.SpawnCount))
		local position = Vector3.new(math.cos(angle), 0, math.sin(angle)) * MapCfg.SpawnRadius
		table.insert(list, CFrame.lookAt(position + Vector3.new(0, MapCfg.PlazaTopY, 0), Vector3.new(0, MapCfg.PlazaTopY, 0)))
	end
	return list
end

-- Chemin d'un biome : de la place jusqu'au kiosque, le long de l'axe du biome.
function MapLayout.pathSegment(biomeId: string): (CFrame, number)
	local u = biomeFrames[biomeId].LookVector
	local fromRadius = MapCfg.PlazaRadius - 4
	local toRadius = MapCfg.BiomeDistance + KioskCfg.RadialOffset - 4
	local middle = u * ((fromRadius + toRadius) / 2) + Vector3.new(0, MapCfg.PathTopY, 0)
	return CFrame.lookAt(middle, middle + u), toRadius - fromRadius
end

-- Emplacement libre pour un élément de décor de rayon `radius` (évite chemin, bases, kiosque).
function MapLayout.isDecorSpotFree(biomeId: string, position: Vector3, radius: number): boolean
	local frame = biomeFrames[biomeId]
	if flatDistance(position, frame.Position) > MapCfg.BiomeRadius - radius - 2 then
		return false
	end
	local p = frame:PointToObjectSpace(position)
	if math.abs(p.X) < MapCfg.PathWidth / 2 + radius + 3 then
		return false
	end
	local margin = BaseCfg.Size / 2 + radius + 4
	for _, base in bases do
		if base.biomeId == biomeId then
			local b = base.cframe:PointToObjectSpace(position)
			if math.abs(b.X) < margin and math.abs(b.Z) < margin then
				return false
			end
		end
	end
	if flatDistance(position, kioskFrames[biomeId].Position) < 22 + radius then
		return false
	end
	return true
end

return MapLayout
