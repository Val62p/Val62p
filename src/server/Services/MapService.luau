-- Construit la carte au démarrage du serveur, uniquement avec des Parts et la palette de la
-- configuration : place centrale, chemins, biomes décorés, bases et kiosques.
-- Le Workspace ne contient aucune logique de progression : seulement des repères et des
-- attributs publics lus par le client (propriétaire de base, arrivages, protections).
local CollectionService = game:GetService("CollectionService")
local Lighting = game:GetService("Lighting")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Config = require(ReplicatedStorage.Shared.Config)
local MapLayout = require(ReplicatedStorage.Shared.MapLayout)
local SeededRandom = require(ReplicatedStorage.Shared.SeededRandom)
local Icons = require(ReplicatedStorage.Shared.Icons)
local Tags = require(ReplicatedStorage.Shared.Tags)

local MapCfg = Config.Map
local BaseCfg = MapCfg.Base
local KioskCfg = MapCfg.Kiosk

local VERTICAL = CFrame.Angles(0, 0, math.pi / 2) -- axe des cylindres Roblox (X) → vertical
local WHITE = Color3.fromRGB(255, 255, 255)
local INK = Color3.fromRGB(34, 28, 48)

local MapService = {}
MapService.__index = MapService

---------------------------------------------------------------------------
-- Primitives
---------------------------------------------------------------------------

local function newPart(className: string, props: { [string]: any }, parent: Instance): BasePart
	local part = Instance.new(className) :: any
	part.Anchored = true
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth
	part.Material = Enum.Material.SmoothPlastic
	for key, value in props do
		part[key] = value
	end
	part.Parent = parent
	return part
end

local function block(name: string, size: Vector3, cframe: CFrame, color: Color3, parent: Instance, extra: { [string]: any }?)
	local props: { [string]: any } = { Name = name, Size = size, CFrame = cframe, Color = color }
	if extra then
		for key, value in extra do
			props[key] = value
		end
	end
	return newPart("Part", props, parent)
end

local function cylinder(
	name: string,
	diameter: number,
	height: number,
	center: CFrame,
	color: Color3,
	parent: Instance,
	extra: { [string]: any }?
)
	local props: { [string]: any } = {
		Name = name,
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(height, diameter, diameter),
		CFrame = center * VERTICAL,
		Color = color,
	}
	if extra then
		for key, value in extra do
			props[key] = value
		end
	end
	return newPart("Part", props, parent)
end

-- Disque horizontal dont le dessus est à `topCenter`.
local function disc(
	name: string,
	topCenter: Vector3,
	radius: number,
	thickness: number,
	color: Color3,
	parent: Instance,
	extra: { [string]: any }?
)
	return cylinder(name, radius * 2, thickness, CFrame.new(topCenter - Vector3.new(0, thickness / 2, 0)), color, parent, extra)
end

local function ball(name: string, diameter: number, position: Vector3, color: Color3, parent: Instance, extra: { [string]: any }?)
	local props: { [string]: any } = {
		Name = name,
		Shape = Enum.PartType.Ball,
		Size = Vector3.new(diameter, diameter, diameter),
		CFrame = CFrame.new(position),
		Color = color,
	}
	if extra then
		for key, value in extra do
			props[key] = value
		end
	end
	return newPart("Part", props, parent)
end

local function ellipsoid(name: string, size: Vector3, cframe: CFrame, color: Color3, parent: Instance, extra: { [string]: any }?)
	local part = block(name, size, cframe, color, parent, extra)
	local mesh = Instance.new("SpecialMesh")
	mesh.MeshType = Enum.MeshType.Sphere
	mesh.Parent = part
	return part
end

local function decorative(): { [string]: any }
	return { CanCollide = false, CanQuery = false, CanTouch = false, CastShadow = false }
end

local function merge(a: { [string]: any }, b: { [string]: any }): { [string]: any }
	local out = table.clone(a)
	for key, value in b do
		out[key] = value
	end
	return out
end

local function newText(parent: Instance, props: { [string]: any }): TextLabel
	local label = Instance.new("TextLabel") :: any
	label.BackgroundTransparency = 1
	label.TextScaled = true
	label.Font = Enum.Font.FredokaOne
	label.TextColor3 = WHITE
	label.TextStrokeTransparency = 0.6
	label.TextStrokeColor3 = INK
	for key, value in props do
		label[key] = value
	end
	label.Parent = parent
	return label
end

-- Panneau texte sur la face avant d'une Part.
local function surfaceSign(part: BasePart, title: string, subtitle: string?, titleColor: Color3?, background: Color3?)
	local gui = Instance.new("SurfaceGui")
	gui.Face = Enum.NormalId.Front
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = 40
	gui.LightInfluence = 0
	gui.MaxDistance = 250
	gui.Parent = part
	local frame = Instance.new("Frame")
	frame.Size = UDim2.fromScale(1, 1)
	frame.BackgroundColor3 = background or WHITE
	frame.BackgroundTransparency = if background then 0 else 1
	frame.BorderSizePixel = 0
	frame.Parent = gui
	local titleLabel = newText(frame, {
		Name = "Title",
		Text = title,
		TextColor3 = titleColor or INK,
		TextStrokeTransparency = 1,
		Size = UDim2.fromScale(0.94, if subtitle then 0.62 else 0.86),
		Position = UDim2.fromScale(0.03, 0.07),
	})
	local subtitleLabel = nil
	if subtitle then
		subtitleLabel = newText(frame, {
			Name = "Subtitle",
			Text = subtitle,
			Font = Enum.Font.GothamBold,
			TextColor3 = titleColor or INK,
			TextStrokeTransparency = 1,
			Size = UDim2.fromScale(0.94, 0.26),
			Position = UDim2.fromScale(0.03, 0.68),
		})
	end
	return titleLabel, subtitleLabel
end

local function billboard(adornee: BasePart, size: UDim2, offset: Vector3, maxDistance: number): BillboardGui
	local gui = Instance.new("BillboardGui")
	gui.Adornee = adornee
	gui.Size = size
	gui.StudsOffsetWorldSpace = offset
	gui.MaxDistance = maxDistance
	gui.LightInfluence = 0
	gui.AlwaysOnTop = false
	gui.Parent = adornee
	return gui
end

---------------------------------------------------------------------------
-- Décor
---------------------------------------------------------------------------

type Placed = { position: Vector3, radius: number }

-- Place jusqu'à `count` éléments de rayon `radius` à des emplacements libres du biome.
local function scatter(
	biomeId: string,
	rng: any,
	occupied: { Placed },
	count: number,
	radius: number,
	build: (position: Vector3, index: number) -> ()
)
	local center = MapLayout.biomeFrame(biomeId).Position
	local placed = 0
	local attempts = 0
	while placed < count and attempts < count * 40 do
		attempts += 1
		local angle = rng:nextNumber(0, math.pi * 2)
		local distance = rng:nextNumber(12, MapCfg.BiomeRadius)
		local position = Vector3.new(center.X + math.cos(angle) * distance, MapCfg.BiomeTopY, center.Z + math.sin(angle) * distance)
		local free = MapLayout.isDecorSpotFree(biomeId, position, radius)
		if free then
			for _, other in occupied do
				if MapLayout.flatDistance(position, other.position) < radius + other.radius + 1.5 then
					free = false
					break
				end
			end
		end
		if free then
			placed += 1
			table.insert(occupied, { position = position, radius = radius })
			build(position, placed)
		end
	end
end

local decorBuilders: { [string]: (biomeId: string, palette: any, folder: Instance, rng: any) -> () } = {}

decorBuilders.Prairie = function(biomeId, palette, folder, rng)
	local occupied: { Placed } = {}
	-- Collines douces (calottes de sphères à demi enterrées).
	scatter(biomeId, rng, occupied, 6, 9, function(position, index)
		local diameter = rng:nextNumber(18, 26)
		local color = if index % 2 == 0 then palette.detail else palette.detail:Lerp(WHITE, 0.25)
		ball("Hill", diameter, position - Vector3.new(0, diameter * 0.3, 0), color, folder)
	end)
	-- Fleurs géométriques.
	scatter(biomeId, rng, occupied, 26, 2, function(position, index)
		local height = rng:nextNumber(3, 5.5)
		local yaw = rng:nextNumber(0, math.pi * 2)
		cylinder("Stem", 0.5, height, CFrame.new(position + Vector3.new(0, height / 2, 0)), palette.detail, folder, decorative())
		local head = position + Vector3.new(0, height + 0.6, 0)
		local petalColor = ({ palette.accentB, palette.accentC, WHITE })[index % 3 + 1]
		for i = 1, 6 do
			local angle = (i - 1) * (math.pi / 3)
			ellipsoid(
				"Petal",
				Vector3.new(1.7, 0.6, 0.3),
				CFrame.new(head) * CFrame.Angles(0, yaw, 0) * CFrame.Angles(0, 0, angle) * CFrame.new(1.05, 0, 0),
				petalColor,
				folder,
				decorative()
			)
		end
		ball("FlowerHeart", 1.3, head, palette.accentA, folder, decorative())
		ellipsoid(
			"Leaf",
			Vector3.new(1.4, 0.2, 0.6),
			CFrame.new(position + Vector3.new(0, height * 0.45, 0)) * CFrame.Angles(0, yaw, math.rad(25)) * CFrame.new(0.6, 0, 0),
			palette.detail,
			folder,
			decorative()
		)
	end)
	-- Petits cubes « pop » empilés, repères colorés.
	scatter(biomeId, rng, occupied, 5, 2.5, function(position, index)
		local colors = { palette.accentA, palette.accentB, palette.accentC }
		local y = position.Y
		for level = 1, 3 do
			local size = 3.2 - level * 0.7
			block(
				"PopCube",
				Vector3.new(size, size, size),
				CFrame.new(position.X, y + size / 2, position.Z) * CFrame.Angles(0, math.rad(level * 25 + index * 10), 0),
				colors[(level + index) % 3 + 1],
				folder
			)
			y += size
		end
	end)
end

decorBuilders.Plage = function(biomeId, palette, folder, rng)
	local occupied: { Placed } = {}
	local frame = MapLayout.biomeFrame(biomeId)
	local top = MapCfg.BiomeTopY
	-- Deux lagons pétillants aux angles extérieurs.
	for _, side in { -1, 1 } do
		local center = frame.Position + frame.LookVector * 48 + frame.RightVector * side * 44
		center = Vector3.new(center.X, top, center.Z)
		table.insert(occupied, { position = center, radius = 17 })
		disc("Foam", center + Vector3.new(0, 0.03, 0), 17, 0.2, WHITE, folder)
		disc("Lagoon", center + Vector3.new(0, 0.06, 0), 15.5, 0.2, palette.detail, folder, { Transparency = 0.05 })
		for i = 1, 3 do
			local offset = Vector3.new(rng:nextNumber(-7, 7), 0.1, rng:nextNumber(-7, 7))
			ellipsoid(
				"Wave",
				Vector3.new(7, 0.25, 1.1),
				CFrame.new(center + offset) * CFrame.Angles(0, rng:nextNumber(0, math.pi), 0),
				WHITE,
				folder,
				decorative()
			)
			ball("Bubble", 0.8 + i * 0.3, center + offset + Vector3.new(1.5, 0.6, 0.5), WHITE, folder, merge(decorative(), { Transparency = 0.3 }))
		end
	end
	-- Parasols.
	scatter(biomeId, rng, occupied, 7, 4.5, function(position, index)
		cylinder("Pole", 0.5, 7, CFrame.new(position + Vector3.new(0, 3.5, 0)), WHITE, folder)
		local canopy = if index % 2 == 0 then palette.accentA else palette.accentB
		disc("Canopy", position + Vector3.new(0, 7.4, 0), 4.2, 0.5, canopy, folder, decorative())
		disc("CanopyTop", position + Vector3.new(0, 7.8, 0), 1.6, 0.4, WHITE, folder, decorative())
	end)
	-- Ballons de plage.
	scatter(biomeId, rng, occupied, 6, 1.6, function(position, index)
		local colors = { palette.accentA, palette.accentB, WHITE }
		ball("BeachBall", 2.6, position + Vector3.new(0, 1.3, 0), colors[index % 3 + 1], folder)
	end)
	-- Canettes géantes de soda fictif.
	scatter(biomeId, rng, occupied, 3, 3.5, function(position, index)
		local color = if index % 2 == 0 then palette.accentB else palette.accentA
		cylinder("SodaCan", 5, 9, CFrame.new(position + Vector3.new(0, 4.5, 0)), color, folder)
		cylinder("SodaBand", 5.2, 1.6, CFrame.new(position + Vector3.new(0, 4.5, 0)), palette.ground, folder, decorative())
		cylinder("SodaLid", 4.6, 0.3, CFrame.new(position + Vector3.new(0, 9.1, 0)), Color3.fromRGB(220, 228, 240), folder)
		cylinder(
			"SodaStraw",
			0.6,
			5,
			CFrame.new(position + Vector3.new(0.8, 10.8, 0)) * CFrame.Angles(0, 0, math.rad(-15)),
			WHITE,
			folder,
			decorative()
		)
	end)
end

decorBuilders.Foret = function(biomeId, palette, folder, rng)
	local occupied: { Placed } = {}
	local lights = 0
	-- Champignons géants lumineux.
	scatter(biomeId, rng, occupied, 8, 7, function(position, index)
		local stemHeight = rng:nextNumber(9, 16)
		local stemDiameter = rng:nextNumber(3, 4.5)
		local capWidth = rng:nextNumber(12, 18)
		local capColor = if index % 2 == 0 then palette.accentA else palette.accentB
		cylinder("MushroomStem", stemDiameter, stemHeight, CFrame.new(position + Vector3.new(0, stemHeight / 2, 0)), palette.detail, folder)
		local capCenter = position + Vector3.new(0, stemHeight + 1.4, 0)
		local cap = ellipsoid(
			"MushroomCap",
			Vector3.new(capWidth, rng:nextNumber(5, 7), capWidth),
			CFrame.new(capCenter),
			capColor,
			folder,
			merge(decorative(), { Material = Enum.Material.Neon })
		)
		disc("CapUnder", capCenter + Vector3.new(0, -0.6, 0), capWidth * 0.42, 0.4, palette.accentC, folder, decorative())
		for i = 1, 3 do
			local angle = i * 2.1
			ball(
				"CapDot",
				1.2,
				capCenter + Vector3.new(math.cos(angle) * capWidth * 0.22, 2.4, math.sin(angle) * capWidth * 0.22),
				WHITE,
				folder,
				decorative()
			)
		end
		if lights < 4 then
			lights += 1
			local light = Instance.new("PointLight")
			light.Color = capColor
			light.Range = 22
			light.Brightness = 1.2
			light.Shadows = false
			light.Parent = cap
		end
	end)
	-- Plantes fluo.
	scatter(biomeId, rng, occupied, 14, 1.5, function(position)
		for i = 1, 3 do
			local height = rng:nextNumber(2, 4)
			local tilt = math.rad(rng:nextNumber(-18, 18))
			cylinder(
				"GlowPlant",
				0.35,
				height,
				CFrame.new(position + Vector3.new((i - 2) * 0.5, height / 2, 0)) * CFrame.Angles(tilt, 0, tilt),
				palette.accentB,
				folder,
				merge(decorative(), { Material = Enum.Material.Neon })
			)
		end
	end)
	-- Cristaux.
	scatter(biomeId, rng, occupied, 6, 2, function(position, index)
		for i = 1, 2 do
			local height = 2.5 + i * 1.2
			block(
				"Crystal",
				Vector3.new(1.4, height, 1.4),
				CFrame.new(position + Vector3.new(i * 0.9 - 1.3, height / 2, 0)) * CFrame.Angles(0, math.rad(index * 37), math.rad(i * 12 - 18)),
				palette.accentA,
				folder,
				{ Material = Enum.Material.Neon, CanCollide = false, CastShadow = false }
			)
		end
	end)
	-- Mousse lumineuse au sol.
	scatter(biomeId, rng, occupied, 12, 2.5, function(position)
		disc(
			"Moss",
			position + Vector3.new(0, 0.05, 0),
			rng:nextNumber(1, 2.4),
			0.1,
			palette.accentB,
			folder,
			merge(decorative(), { Material = Enum.Material.Neon, Transparency = 0.35 })
		)
	end)
end

-- Décor générique pour un biome ajouté sans style dédié.
decorBuilders.Generic = function(biomeId, palette, folder, rng)
	local occupied: { Placed } = {}
	scatter(biomeId, rng, occupied, 14, 2.5, function(position, index)
		local colors = { palette.accentA, palette.accentB, palette.accentC }
		local size = rng:nextNumber(2, 4)
		block(
			"Block",
			Vector3.new(size, size, size),
			CFrame.new(position + Vector3.new(0, size / 2, 0)) * CFrame.Angles(0, rng:nextNumber(0, math.pi), 0),
			colors[index % 3 + 1],
			folder
		)
	end)
end

---------------------------------------------------------------------------
-- Construction
---------------------------------------------------------------------------

function MapService.new()
	return setmetatable({ root = nil, bases = {}, kiosks = {} }, MapService)
end

function MapService:_lighting()
	Lighting.ClockTime = 14.5
	Lighting.Brightness = 2.2
	Lighting.Ambient = Color3.fromRGB(140, 130, 162)
	Lighting.OutdoorAmbient = Color3.fromRGB(168, 162, 194)
	Lighting.EnvironmentDiffuseScale = 0.5
	Lighting.EnvironmentSpecularScale = 0.3
	Lighting.GlobalShadows = true
	if not Lighting:FindFirstChildOfClass("Atmosphere") then
		local atmosphere = Instance.new("Atmosphere")
		atmosphere.Density = 0.26
		atmosphere.Offset = 0.1
		atmosphere.Color = Color3.fromRGB(206, 214, 255)
		atmosphere.Decay = Color3.fromRGB(190, 160, 230)
		atmosphere.Glare = 0
		atmosphere.Haze = 0.8
		atmosphere.Parent = Lighting
	end
	if not Lighting:FindFirstChildOfClass("BloomEffect") then
		local bloom = Instance.new("BloomEffect")
		bloom.Intensity = 0.5
		bloom.Size = 24
		bloom.Threshold = 1.4
		bloom.Parent = Lighting
	end
end

function MapService:_ground(root: Instance)
	local folder = Instance.new("Folder")
	folder.Name = "Ground"
	folder.Parent = root
	disc("Ground", Vector3.new(0, MapCfg.GroundTopY, 0), MapCfg.GroundRadius, 4, MapCfg.GroundColor, folder)
	disc(
		"GroundRim",
		Vector3.new(0, MapCfg.GroundTopY - 0.05, 0),
		MapCfg.GroundRadius + 4,
		4,
		MapCfg.GroundColor:Lerp(INK, 0.15),
		folder
	)
	-- Murs invisibles au bord de la carte : personne ne tombe dans le vide.
	local segments = 36
	local radius = MapCfg.GroundRadius + 1
	local length = 2 * math.pi * radius / segments + 2
	for i = 1, segments do
		local angle = (i - 0.5) * (2 * math.pi / segments)
		local position = Vector3.new(math.cos(angle) * radius, 20, math.sin(angle) * radius)
		block(
			"Boundary",
			Vector3.new(length, 40, 2),
			CFrame.lookAt(position, Vector3.new(0, 20, 0)),
			WHITE,
			folder,
			{ Transparency = 1, CastShadow = false, CanQuery = false }
		)
	end
end

function MapService:_plaza(root: Instance)
	local folder = Instance.new("Folder")
	folder.Name = "Plaza"
	folder.Parent = root
	local colors = MapCfg.PlazaColors
	local top = MapCfg.PlazaTopY
	disc("PlazaOuter", Vector3.new(0, top, 0), MapCfg.PlazaRadius, top + 1, colors.outer, folder)
	disc("PlazaInner", Vector3.new(0, top + 0.02, 0), MapCfg.PlazaRadius - 8, 0.2, colors.inner, folder)

	-- Anneau de la zone surveillée (pointillés lumineux).
	local dashes = 32
	for i = 1, dashes do
		local angle = (i - 1) * (2 * math.pi / dashes)
		local position = Vector3.new(math.cos(angle), 0, math.sin(angle)) * MapCfg.SafeZoneRadius + Vector3.new(0, top + 0.06, 0)
		block(
			"SafeRing",
			Vector3.new(0.8, 0.1, 3),
			CFrame.lookAt(position, Vector3.new(0, position.Y, 0)) * CFrame.Angles(0, math.pi / 2, 0),
			colors.safeRing,
			folder,
			merge(decorative(), { Material = Enum.Material.Neon })
		)
	end
	-- Bornes « caméras » qui expliquent la détection.
	for i, angle in { 30, 150, 270 } do
		local direction = Vector3.new(math.cos(math.rad(angle)), 0, -math.sin(math.rad(angle)))
		local base = direction * (MapCfg.SafeZoneRadius + 2) + Vector3.new(0, top, 0)
		cylinder("Watcher", 1, 6, CFrame.new(base + Vector3.new(0, 3, 0)), WHITE, folder)
		local eye = ball("WatcherEye", 1.8, base + Vector3.new(0, 6.6, 0), colors.safeRing, folder, { Material = Enum.Material.Neon })
		local gui = billboard(eye, UDim2.fromOffset(170, 34), Vector3.new(0, 2.2, 0), 70)
		newText(gui, { Text = "Zone surveillée", Size = UDim2.fromScale(1, 1), Name = "Label" .. i })
	end

	-- Fontaine centrale.
	cylinder("FountainBase", 12, 2, CFrame.new(0, top + 1, 0), colors.fountain, folder)
	disc("FountainWater", Vector3.new(0, top + 2.05, 0), 5, 0.2, colors.water, folder, { Material = Enum.Material.Neon, Transparency = 0.2 })
	cylinder("FountainColumn", 1.6, 5, CFrame.new(0, top + 4.5, 0), colors.fountain, folder)
	cylinder("FountainBowl", 6, 0.8, CFrame.new(0, top + 7.2, 0), colors.fountain, folder)
	ball("FountainSplash", 2.4, Vector3.new(0, top + 8.2, 0), colors.water, folder, merge(decorative(), { Material = Enum.Material.Neon, Transparency = 0.25 }))

	-- Points d'apparition.
	for i, cframe in MapLayout.spawnCFrames() do
		local spawn = Instance.new("SpawnLocation")
		spawn.Name = "Spawn" .. i
		spawn.Anchored = true
		spawn.Size = Vector3.new(6, 0.4, 6)
		spawn.CFrame = cframe * CFrame.new(0, 0.2, 0)
		spawn.Color = Color3.fromRGB(255, 214, 102)
		spawn.Material = Enum.Material.SmoothPlastic
		spawn.TopSurface = Enum.SurfaceType.Smooth
		spawn.Neutral = true
		spawn.Duration = 0
		spawn.Parent = folder
	end

	-- Panneau d'accueil (au sud, entre deux chemins).
	local welcomePosition = Vector3.new(0, top + 6, MapCfg.PlazaRadius - 4)
	local welcome = block("WelcomeSign", Vector3.new(26, 8, 1), CFrame.lookAt(welcomePosition, Vector3.new(0, welcomePosition.Y, 0)), WHITE, folder)
	surfaceSign(welcome, "STEAL A MEME", "Collectionne, installe, emprunte… avec le sourire !", Color3.fromRGB(214, 51, 108), WHITE)
	for _, side in { -1, 1 } do
		cylinder("WelcomePost", 0.8, 6, CFrame.new(welcomePosition + Vector3.new(side * 12, -4.5, 0.6)), WHITE, folder)
	end

	-- Panneaux directionnels vers chaque biome.
	for _, biomeId in Config.Biomes.Order do
		local def = Config.Biomes.Defs[biomeId]
		local frame = MapLayout.biomeFrame(biomeId)
		local position = frame.LookVector * (MapCfg.PlazaRadius - 6) + frame.RightVector * (MapCfg.PathWidth / 2 + 3)
		position = Vector3.new(position.X, top, position.Z)
		cylinder("SignPost", 0.6, 7, CFrame.new(position + Vector3.new(0, 3.5, 0)), WHITE, folder)
		local board = block(
			"BiomeSign",
			Vector3.new(9, 2.6, 0.4),
			CFrame.lookAt(position + Vector3.new(0, 6, 0), Vector3.new(0, top + 6, 0)),
			def.palette.rim,
			folder
		)
		surfaceSign(board, def.displayName, "par ici", INK, def.palette.rim)
	end
end

function MapService:_paths(root: Instance)
	local folder = Instance.new("Folder")
	folder.Name = "Paths"
	folder.Parent = root
	for _, biomeId in Config.Biomes.Order do
		local palette = Config.Biomes.Defs[biomeId].palette
		local cframe, length = MapLayout.pathSegment(biomeId)
		local thickness = MapCfg.PathTopY - MapCfg.GroundTopY + 0.1
		block("Path", Vector3.new(MapCfg.PathWidth, thickness, length), cframe * CFrame.new(0, -thickness / 2, 0), palette.path, folder)
		for _, side in { -1, 1 } do
			block(
				"PathEdge",
				Vector3.new(1, thickness + 0.04, length),
				cframe * CFrame.new(side * (MapCfg.PathWidth / 2 + 0.5), -thickness / 2 + 0.02, 0),
				palette.rim,
				folder
			)
		end
	end
end

function MapService:_biome(root: Instance, biomeId: string)
	local def = Config.Biomes.Defs[biomeId]
	local palette = def.palette
	local folder = Instance.new("Folder")
	folder.Name = "Biome_" .. biomeId
	folder:SetAttribute("BiomeId", biomeId)
	folder.Parent = root
	local center = MapLayout.biomeFrame(biomeId).Position
	disc("BiomeRim", Vector3.new(center.X, MapCfg.BiomeTopY - 0.05, center.Z), MapCfg.BiomeRadius + 2.5, 1.2, palette.rim, folder)
	disc("BiomeGround", Vector3.new(center.X, MapCfg.BiomeTopY, center.Z), MapCfg.BiomeRadius, 1.2, palette.ground, folder)
	local decor = Instance.new("Folder")
	decor.Name = "Decor"
	decor.Parent = folder
	local builder = decorBuilders[def.decor] or decorBuilders.Generic
	builder(biomeId, palette, decor, SeededRandom.new(def.seed or 1))
end

function MapService:_base(root: Instance, layout: MapLayout.BaseLayout)
	local half = BaseCfg.Size / 2
	local cf = layout.cframe
	local model = Instance.new("Model")
	model.Name = "Base" .. layout.index
	model:SetAttribute("BaseIndex", layout.index)
	model:SetAttribute("BiomeId", layout.biomeId)
	model:SetAttribute("OwnerUserId", 0)
	model:SetAttribute("OwnerName", "")
	model:SetAttribute("ShieldUntil", 0)
	model:SetAttribute("Zen", false)
	model:SetAttribute("UnderTheft", false)
	model.Parent = root

	local floor = block(
		"Floor",
		Vector3.new(BaseCfg.Size, BaseCfg.FloorThickness, BaseCfg.Size),
		cf * CFrame.new(0, -BaseCfg.FloorThickness / 2, 0),
		layout.color:Lerp(WHITE, 0.72),
		model
	)
	model.PrimaryPart = floor

	local trims = {}
	local h = BaseCfg.CurbHeight
	table.insert(trims, block("CurbBack", Vector3.new(BaseCfg.Size, h, 1), cf * CFrame.new(0, h / 2, half - 0.5), layout.color, model))
	for _, side in { -1, 1 } do
		table.insert(trims, block("CurbSide", Vector3.new(1, h, BaseCfg.Size), cf * CFrame.new(side * (half - 0.5), h / 2, 0), layout.color, model))
		table.insert(trims, block("ArchPost", Vector3.new(1.4, 9, 1.4), cf * CFrame.new(side * 9.5, 4.5, -half + 0.7), layout.color, model))
		-- Murets de chaque côté de l'entrée.
		table.insert(
			trims,
			block("CurbFront", Vector3.new(half - 10.2, h, 1), cf * CFrame.new(side * (half - (half - 10.2) / 2), h / 2, -half + 0.5), layout.color, model)
		)
	end
	local beam = block("ArchBeam", Vector3.new(20.4, 1.4, 1.4), cf * CFrame.new(0, 9.4, -half + 0.7), layout.color, model)
	table.insert(trims, beam)
	local signPart = block("Sign", Vector3.new(15, 3.2, 0.4), cf * CFrame.new(0, 11.8, -half + 0.7), WHITE, model)
	local signTitle, signSubtitle = surfaceSign(signPart, "Base libre", "Rejoins la partie pour l'occuper", INK, WHITE)

	-- Bulle d'état au-dessus de l'arche (protection, Zen, alerte) : texte mis à jour par le client.
	local statusGui = billboard(signPart, UDim2.fromOffset(220, 44), Vector3.new(0, 3.4, 0), 160)
	statusGui.Name = "StatusGui"
	statusGui.Enabled = false
	local statusFrame = Instance.new("Frame")
	statusFrame.Name = "Frame"
	statusFrame.Size = UDim2.fromScale(1, 1)
	statusFrame.BackgroundColor3 = WHITE
	statusFrame.BorderSizePixel = 0
	statusFrame.Parent = statusGui
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0.5, 0)
	corner.Parent = statusFrame
	local iconHolder = Instance.new("Frame")
	iconHolder.Name = "IconHolder"
	iconHolder.BackgroundTransparency = 1
	iconHolder.Size = UDim2.new(0, 34, 0, 34)
	iconHolder.Position = UDim2.new(0, 6, 0.5, -17)
	iconHolder.Parent = statusFrame
	Icons.create("shield").Parent = iconHolder
	newText(statusFrame, {
		Name = "Label",
		Text = "",
		Font = Enum.Font.GothamBold,
		TextColor3 = INK,
		TextStrokeTransparency = 1,
		Size = UDim2.new(1, -50, 0.7, 0),
		Position = UDim2.new(0, 44, 0.15, 0),
		TextXAlignment = Enum.TextXAlignment.Left,
	})

	local pads = {}
	local memes = Instance.new("Folder")
	memes.Name = "Memes"
	memes.Parent = model
	for slot = 1, MapLayout.maxSlots() do
		local slotCf = MapLayout.slotCFrame(layout.index, slot)
		local pad = cylinder(
			"Pad" .. slot,
			BaseCfg.PadDiameter,
			BaseCfg.PadHeight,
			CFrame.new(slotCf.Position - Vector3.new(0, BaseCfg.PadHeight / 2, 0)),
			WHITE,
			model
		)
		pad:SetAttribute("BaseIndex", layout.index)
		pad:SetAttribute("Slot", slot)
		pad:SetAttribute("HasMeme", false)
		pad:SetAttribute("MemeId", "")
		pad:SetAttribute("Locked", false)
		pad:SetAttribute("InTransit", false)
		CollectionService:AddTag(pad, Tags.Pad)
		-- Cadenas affiché sur les socles verrouillés.
		local lockGui = billboard(pad, UDim2.fromOffset(40, 40), Vector3.new(0, 1.6, 0), 70)
		lockGui.Name = "LockGui"
		lockGui.Enabled = false
		Icons.create("lock", Color3.fromRGB(120, 112, 150)).Parent = lockGui
		pads[slot] = pad
	end

	CollectionService:AddTag(model, Tags.Base)
	self.bases[layout.index] = {
		index = layout.index,
		layout = layout,
		model = model,
		floor = floor,
		trims = trims,
		pads = pads,
		memes = memes,
		signTitle = signTitle,
		signSubtitle = signSubtitle,
		statusGui = statusGui,
	}
end

function MapService:_kiosk(root: Instance, biomeId: string)
	local def = Config.Biomes.Defs[biomeId]
	local palette = def.palette
	local kf = MapLayout.kioskFrame(biomeId)
	local width = KioskCfg.Pedestals * KioskCfg.PedestalSpacing + 8
	local model = Instance.new("Model")
	model.Name = "Kiosk_" .. biomeId
	model:SetAttribute("BiomeId", biomeId)
	model:SetAttribute("NextRotationAt", 0)
	model.Parent = root

	block("KioskFloor", Vector3.new(width, 0.4, 14), kf * CFrame.new(0, 0.2, 1), palette.path, model)
	block("KioskBack", Vector3.new(width, 10, 1.2), kf * CFrame.new(0, 5, 7), palette.rim, model)
	block("KioskRoof", Vector3.new(width + 2, 1, 15), kf * CFrame.new(0, 11, 0.5), palette.accentA, model)
	block("KioskValance", Vector3.new(width + 2, 1.4, 0.6), kf * CFrame.new(0, 10.2, -7), palette.accentB, model)
	for _, side in { -1, 1 } do
		cylinder("KioskPost", 1.2, 10.5, kf * CFrame.new(side * (width / 2), 5.25, -6.5), WHITE, model)
	end
	local signPart = block("KioskSign", Vector3.new(22, 3.6, 0.5), kf * CFrame.new(0, 13.4, -6.6), WHITE, model)
	local title, subtitle = surfaceSign(signPart, "Kiosque " .. def.displayName, "Nouvel arrivage bientôt", INK, WHITE)
	subtitle.Name = "Timer"

	local pedestals = {}
	for index = 1, KioskCfg.Pedestals do
		local topCf = MapLayout.pedestalCFrame(biomeId, index)
		local pedestal = cylinder(
			"Pedestal" .. index,
			4.6,
			KioskCfg.PedestalHeight,
			CFrame.new(topCf.Position - Vector3.new(0, KioskCfg.PedestalHeight / 2, 0)),
			WHITE,
			model
		)
		pedestal:SetAttribute("BiomeId", biomeId)
		pedestal:SetAttribute("Pedestal", index)
		pedestal:SetAttribute("MemeId", "")
		pedestal:SetAttribute("OfferVersion", 0)
		pedestal:SetAttribute("Price", 0)
		CollectionService:AddTag(pedestal, Tags.Pedestal)

		local gui = billboard(pedestal, UDim2.fromOffset(190, 92), Vector3.new(0, KioskCfg.PedestalHeight / 2 + 8, 0), 90)
		gui.Name = "OfferGui"
		local frame = Instance.new("Frame")
		frame.Size = UDim2.fromScale(1, 1)
		frame.BackgroundColor3 = WHITE
		frame.BackgroundTransparency = 0.08
		frame.BorderSizePixel = 0
		frame.Parent = gui
		local corner = Instance.new("UICorner")
		corner.CornerRadius = UDim.new(0, 14)
		corner.Parent = frame
		local stroke = Instance.new("UIStroke")
		stroke.Name = "RarityStroke"
		stroke.Thickness = 3
		stroke.Color = WHITE
		stroke.Parent = frame
		local nameLabel = newText(frame, {
			Name = "MemeName",
			Text = "",
			TextColor3 = INK,
			TextStrokeTransparency = 1,
			Size = UDim2.new(1, -12, 0.36, 0),
			Position = UDim2.new(0, 6, 0.04, 0),
		})
		local rarityLabel = newText(frame, {
			Name = "Rarity",
			Text = "",
			Font = Enum.Font.GothamBold,
			TextStrokeTransparency = 1,
			Size = UDim2.new(1, -12, 0.22, 0),
			Position = UDim2.new(0, 6, 0.4, 0),
		})
		local coinHolder = Instance.new("Frame")
		coinHolder.BackgroundTransparency = 1
		coinHolder.Size = UDim2.new(0, 26, 0, 26)
		coinHolder.Position = UDim2.new(0, 10, 0.64, 2)
		coinHolder.Parent = frame
		Icons.create("coin").Parent = coinHolder
		local priceLabel = newText(frame, {
			Name = "Price",
			Text = "",
			Font = Enum.Font.GothamBold,
			TextColor3 = INK,
			TextStrokeTransparency = 1,
			TextXAlignment = Enum.TextXAlignment.Left,
			Size = UDim2.new(0.5, -40, 0.3, 0),
			Position = UDim2.new(0, 40, 0.64, 0),
		})
		local incomeLabel = newText(frame, {
			Name = "Income",
			Text = "",
			Font = Enum.Font.GothamBold,
			TextColor3 = Color3.fromRGB(24, 135, 84),
			TextStrokeTransparency = 1,
			TextXAlignment = Enum.TextXAlignment.Right,
			Size = UDim2.new(0.5, -10, 0.3, 0),
			Position = UDim2.new(0.5, 0, 0.64, 0),
		})

		local display = Instance.new("Folder")
		display.Name = "Display"
		display.Parent = pedestal
		pedestals[index] = {
			part = pedestal,
			topCFrame = topCf,
			display = display,
			stroke = stroke,
			nameLabel = nameLabel,
			rarityLabel = rarityLabel,
			priceLabel = priceLabel,
			incomeLabel = incomeLabel,
		}
	end

	CollectionService:AddTag(model, Tags.Kiosk)
	self.kiosks[biomeId] = { model = model, pedestals = pedestals, title = title, timer = subtitle }
end

function MapService:build(): Instance
	local existing = Workspace:FindFirstChild("Map")
	if existing then
		existing:Destroy()
	end
	local root = Instance.new("Folder")
	root.Name = "Map"
	self.root = root

	self:_lighting()
	self:_ground(root)
	self:_plaza(root)
	self:_paths(root)
	for _, biomeId in Config.Biomes.Order do
		self:_biome(root, biomeId)
	end
	local basesFolder = Instance.new("Folder")
	basesFolder.Name = "Bases"
	basesFolder.Parent = root
	for _, layout in MapLayout.bases() do
		self:_base(basesFolder, layout)
	end
	local kiosksFolder = Instance.new("Folder")
	kiosksFolder.Name = "Kiosks"
	kiosksFolder.Parent = root
	for _, biomeId in Config.Biomes.Order do
		self:_kiosk(kiosksFolder, biomeId)
	end

	root.Parent = Workspace
	return root
end

return MapService
