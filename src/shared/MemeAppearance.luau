--!strict
-- Apparence des mèmes : figurines originales construites uniquement avec des Parts.
-- `specs` décrit les pièces (testable sans moteur) ; `build` crée le Model.
-- Repère du mème : origine au centre du dessous, face avant tournée vers -Z (LookVector).

local Config = require(script.Parent.Config)

local MemeAppearance = {}

export type PartKind = "Ball" | "Block" | "Ellipsoid" | "VCylinder"

export type PartSpec = {
	name: string,
	kind: PartKind,
	size: Vector3, -- Ball : diamètre en X ; VCylinder : (diamètre, hauteur, diamètre)
	offset: CFrame,
	color: Color3,
	material: string,
	transparency: number,
	isBody: boolean,
}

export type BuildOptions = {
	anchored: boolean?,
	ring: boolean?,
	transparency: number?,
}

local INK = Color3.fromRGB(34, 28, 48)
local WHITE = Color3.fromRGB(255, 255, 255)
local CHEEK = Color3.fromRGB(255, 150, 170)
local ORANGE = Color3.fromRGB(255, 168, 60)
local LEMON = Color3.fromRGB(255, 232, 92)

type Body = {
	W: number,
	H: number,
	D: number,
	cy: number,
	top: number,
	headCenter: Vector3,
	surfaceZ: (x: number, y: number) -> number,
}

local function ellipsoidSurface(center: Vector3, W: number, H: number, D: number)
	return function(x: number, y: number): number
		local nx = (x - center.X) / (W / 2)
		local ny = (y - center.Y) / (H / 2)
		return center.Z - (D / 2) * math.sqrt(math.max(0.05, 1 - nx * nx - ny * ny))
	end
end

local function makeBuilder()
	local list: { PartSpec } = {}
	local function add(
		name: string,
		kind: PartKind,
		size: Vector3,
		offset: CFrame,
		color: Color3,
		material: string?,
		transparency: number?,
		isBody: boolean?
	)
		table.insert(list, {
			name = name,
			kind = kind,
			size = size,
			offset = offset,
			color = color,
			material = material or "SmoothPlastic",
			transparency = transparency or 0,
			isBody = isBody == true,
		})
	end
	return list, add
end

local function buildBody(look: any, s: number, add): Body
	local color = look.color
	local material = if look.translucent then "Glass" else "SmoothPlastic"
	local transparency = if look.translucent then 0.3 else 0
	local lift = if look.accessory == "Tentacles" then 0.35 * s else 0
	local kind = look.body

	if kind == "Bean" then
		local W, H, D = 0.9 * s, 1.2 * s, 0.9 * s
		local center = Vector3.new(0, H / 2 + lift, 0)
		add("Body", "Ellipsoid", Vector3.new(W, H, D), CFrame.new(center), color, material, transparency, true)
		return {
			W = W,
			H = H,
			D = D,
			cy = center.Y,
			top = center.Y + H / 2,
			headCenter = center,
			surfaceZ = ellipsoidSurface(center, W, H, D),
		}
	elseif kind == "Block" then
		local center = Vector3.new(0, s / 2 + lift, 0)
		add("Body", "Block", Vector3.new(s, s, s), CFrame.new(center), color, material, transparency, true)
		return {
			W = s,
			H = s,
			D = s,
			cy = center.Y,
			top = center.Y + s / 2,
			headCenter = center,
			surfaceZ = function()
				return -s / 2
			end,
		}
	elseif kind == "Cylinder" then
		local d, h = 0.85 * s, 1.1 * s
		local center = Vector3.new(0, h / 2 + lift, 0)
		add("Body", "VCylinder", Vector3.new(d, h, d), CFrame.new(center), color, material, transparency, true)
		return {
			W = d,
			H = h,
			D = d,
			cy = center.Y,
			top = center.Y + h / 2,
			headCenter = center,
			surfaceZ = function(x: number)
				local r = d / 2
				return -math.sqrt(math.max(0.05 * r * r, r * r - x * x))
			end,
		}
	elseif kind == "Long" then
		local W, H, D = 0.8 * s, 0.62 * s, 1.6 * s
		local center = Vector3.new(0, H / 2 + lift, 0)
		add("Body", "Ellipsoid", Vector3.new(W, H, D), CFrame.new(center), color, material, transparency, true)
		-- Tête légèrement relevée à l'avant.
		local headCenter = Vector3.new(0, H * 0.75, -D * 0.32)
		local headW, headH, headD = W * 0.9, H * 0.95, D * 0.42
		add("Head", "Ellipsoid", Vector3.new(headW, headH, headD), CFrame.new(headCenter), color, material, transparency)
		return {
			W = headW,
			H = headH,
			D = headD,
			cy = headCenter.Y,
			top = headCenter.Y + headH / 2,
			headCenter = headCenter,
			surfaceZ = ellipsoidSurface(headCenter, headW, headH, headD),
		}
	elseif kind == "Flower" then
		local stemHeight = 0.75 * s
		add(
			"Stem",
			"VCylinder",
			Vector3.new(0.14 * s, stemHeight, 0.14 * s),
			CFrame.new(0, stemHeight / 2, 0),
			Color3.fromRGB(96, 186, 96)
		)
		local d = 0.75 * s
		local center = Vector3.new(0, stemHeight + d * 0.4, 0)
		add("Body", "Ball", Vector3.new(d, d, d), CFrame.new(center), color, material, transparency, true)
		return {
			W = d,
			H = d,
			D = d,
			cy = center.Y,
			top = center.Y + d / 2,
			headCenter = center,
			surfaceZ = ellipsoidSurface(center, d, d, d),
		}
	end

	-- "Ball" par défaut.
	local center = Vector3.new(0, s / 2 + lift, 0)
	add("Body", "Ball", Vector3.new(s, s, s), CFrame.new(center), color, material, transparency, true)
	return {
		W = s,
		H = s,
		D = s,
		cy = center.Y,
		top = center.Y + s / 2,
		headCenter = center,
		surfaceZ = ellipsoidSurface(center, s, s, s),
	}
end

local function line(add, name: string, body: Body, x: number, y: number, length: number, thickness: number, angle: number)
	local z = body.surfaceZ(x, y) - 0.02
	add(name, "Block", Vector3.new(length, thickness, 0.08), CFrame.new(x, y, z) * CFrame.Angles(0, 0, angle), INK)
end

local function buildFace(look: any, body: Body, add)
	local face = look.face
	local W = body.W
	local e = W * (if face == "Round" then 0.34 else 0.26)
	local ex = W * 0.21
	local faceY = body.cy + body.H * 0.08
	local mouthY = faceY - e * 1.1
	local lt = math.max(0.07, e * 0.16)

	local function eye(side: number, eyeColor: Color3?, material: string?, withPupil: boolean)
		local x = side * ex
		local z = body.surfaceZ(x, faceY)
		add("Eye", "Ball", Vector3.new(e, e, e), CFrame.new(x, faceY, z + e * 0.2), eyeColor or WHITE, material)
		if withPupil then
			local p = e * 0.55
			add("Pupil", "Ball", Vector3.new(p, p, p), CFrame.new(x, faceY - e * 0.05, z - e * 0.18), INK)
		end
	end

	local function smile(frown: boolean)
		local sign = if frown then -1 else 1
		line(add, "Mouth", body, 0, mouthY, e * 0.7, lt, 0)
		for _, side in { -1, 1 } do
			line(add, "Mouth", body, side * e * 0.48, mouthY + sign * e * 0.12, e * 0.45, lt, side * sign * math.rad(28))
		end
	end

	local function cheeks()
		for _, side in { -1, 1 } do
			local x = side * (ex + e * 0.55)
			local y = mouthY + e * 0.35
			add("Cheek", "Ellipsoid", Vector3.new(e * 0.5, e * 0.3, 0.1), CFrame.new(x, y, body.surfaceZ(x, y) - 0.01), CHEEK)
		end
	end

	if face == "Sleepy" then
		for _, side in { -1, 1 } do
			line(add, "EyeClosed", body, side * ex, faceY, e * 0.8, lt, 0)
		end
		add(
			"Mouth",
			"Ellipsoid",
			Vector3.new(e * 0.35, e * 0.3, 0.12),
			CFrame.new(0, mouthY, body.surfaceZ(0, mouthY) - 0.02),
			INK
		)
	elseif face == "Grumpy" then
		eye(-1, nil, nil, true)
		eye(1, nil, nil, true)
		for _, side in { -1, 1 } do
			line(add, "Brow", body, side * ex, faceY + e * 0.75, e * 1.05, lt * 1.2, side * math.rad(22))
		end
		smile(true)
	elseif face == "Cool" then
		local z = body.surfaceZ(0, faceY) - 0.06
		add("Glasses", "Block", Vector3.new(math.min(W * 0.8, ex * 2 + e * 1.4), e * 0.85, 0.14), CFrame.new(0, faceY, z), INK)
		add("Shine", "Block", Vector3.new(e * 0.35, e * 0.12, 0.05), CFrame.new(ex + e * 0.1, faceY + e * 0.18, z - 0.08), WHITE)
		smile(false)
	elseif face == "Star" then
		eye(-1, LEMON, "Neon", false)
		eye(1, LEMON, "Neon", false)
		add(
			"Mouth",
			"Ellipsoid",
			Vector3.new(e * 0.6, e * 0.5, 0.14),
			CFrame.new(0, mouthY, body.surfaceZ(0, mouthY) - 0.02),
			INK
		)
	elseif face == "Proud" then
		for _, side in { -1, 1 } do
			local x = side * ex
			line(add, "EyeHappy", body, x - e * 0.18, faceY, e * 0.5, lt, math.rad(35))
			line(add, "EyeHappy", body, x + e * 0.18, faceY, e * 0.5, lt, -math.rad(35))
		end
		smile(false)
		cheeks()
	elseif face == "Round" then
		eye(-1, nil, nil, true)
		eye(1, nil, nil, true)
		add(
			"Beak",
			"Ellipsoid",
			Vector3.new(e * 0.45, e * 0.4, e * 0.55),
			CFrame.new(0, mouthY + e * 0.25, body.surfaceZ(0, mouthY + e * 0.25) - e * 0.1),
			ORANGE
		)
	elseif face == "Serious" then
		eye(-1, nil, nil, true)
		eye(1, nil, nil, true)
		line(add, "Mouth", body, 0, mouthY, e * 0.8, lt, 0)
	else -- Happy
		eye(-1, nil, nil, true)
		eye(1, nil, nil, true)
		smile(false)
		cheeks()
	end
end

local function ring(add, name: string, count: number, radius: number, center: Vector3, size: Vector3, color: Color3, z: number, material: string?)
	for i = 1, count do
		local angle = (i - 1) * (2 * math.pi / count)
		add(name, "Ellipsoid", size, CFrame.new(center) * CFrame.Angles(0, 0, angle) * CFrame.new(radius, 0, z), color, material)
	end
end

local function buildAccessory(look: any, body: Body, s: number, add)
	local accent = look.accent
	local accessory = look.accessory
	local top = body.top

	if accessory == "Sprout" then
		add("Stem", "VCylinder", Vector3.new(0.09 * s, 0.35 * s, 0.09 * s), CFrame.new(0, top + 0.12 * s, 0), accent)
		for _, side in { -1, 1 } do
			add(
				"Leaf",
				"Ellipsoid",
				Vector3.new(0.34 * s, 0.06 * s, 0.17 * s),
				CFrame.new(side * 0.16 * s, top + 0.28 * s, 0) * CFrame.Angles(0, 0, side * math.rad(25)),
				accent
			)
		end
	elseif accessory == "Cloud" then
		local puffs = {
			Vector3.new(0, 0.48, 0.05),
			Vector3.new(-0.34, 0.3, 0.12),
			Vector3.new(0.34, 0.3, 0.12),
			Vector3.new(-0.44, -0.05, 0.12),
			Vector3.new(0.44, -0.05, 0.12),
			Vector3.new(0, 0.2, 0.4),
		}
		for _, p in puffs do
			add("Puff", "Ball", Vector3.new(0.42 * s, 0.42 * s, 0.42 * s), CFrame.new(Vector3.new(p.X * s, body.cy + p.Y * s, p.Z * s)), look.color)
		end
		local patchY = body.cy - 0.02 * s
		add(
			"FacePatch",
			"Ellipsoid",
			Vector3.new(0.62 * s, 0.56 * s, 0.22 * s),
			CFrame.new(0, patchY, body.surfaceZ(0, patchY) + 0.04 * s),
			Color3.fromRGB(255, 222, 208)
		)
		for _, side in { -1, 1 } do
			add(
				"Ear",
				"Ellipsoid",
				Vector3.new(0.34 * s, 0.12 * s, 0.2 * s),
				CFrame.new(side * 0.5 * s, body.cy + 0.18 * s, -0.05 * s) * CFrame.Angles(0, 0, side * math.rad(-30)),
				accent
			)
		end
	elseif accessory == "Petals" then
		ring(
			add,
			"Petal",
			10,
			body.W / 2 + 0.12 * s,
			body.headCenter,
			Vector3.new(0.36 * s, 0.18 * s, 0.08 * s),
			accent,
			0.06 * s
		)
		for _, side in { -1, 1 } do
			add(
				"Leaf",
				"Ellipsoid",
				Vector3.new(0.32 * s, 0.06 * s, 0.15 * s),
				CFrame.new(side * 0.16 * s, 0.32 * s, 0) * CFrame.Angles(0, 0, side * math.rad(20)),
				Color3.fromRGB(96, 186, 96)
			)
		end
	elseif accessory == "Florets" then
		local florets = {
			Vector3.new(0, 0.06, 0),
			Vector3.new(-0.26, -0.06, 0.04),
			Vector3.new(0.26, -0.06, 0.04),
			Vector3.new(0, -0.04, 0.26),
			Vector3.new(-0.14, -0.02, -0.18),
			Vector3.new(0.14, -0.02, -0.18),
		}
		for _, p in florets do
			add("Floret", "Ball", Vector3.new(0.44 * s, 0.44 * s, 0.44 * s), CFrame.new(p.X * s, top + p.Y * s, p.Z * s), accent)
		end
		for _, side in { -1, 1 } do
			add(
				"Biceps",
				"Ellipsoid",
				Vector3.new(0.34 * s, 0.26 * s, 0.26 * s),
				CFrame.new(side * (body.W / 2 + 0.06 * s), body.cy, 0) * CFrame.Angles(0, 0, side * math.rad(-35)),
				look.color
			)
		end
	elseif accessory == "Claws" then
		for _, side in { -1, 1 } do
			local x = side * (body.W / 2 + 0.16 * s)
			local y = body.cy + 0.02 * s
			for _, jaw in { -1, 1 } do
				add(
					"Claw",
					"Ellipsoid",
					Vector3.new(0.34 * s, 0.15 * s, 0.24 * s),
					CFrame.new(x, y + jaw * 0.08 * s, -0.08 * s) * CFrame.Angles(0, 0, side * jaw * math.rad(18)),
					accent
				)
			end
		end
	elseif accessory == "Straw" then
		add(
			"Straw",
			"VCylinder",
			Vector3.new(0.12 * s, 0.75 * s, 0.12 * s),
			CFrame.new(0.15 * s, top + 0.22 * s, 0.05 * s) * CFrame.Angles(0, 0, math.rad(-18)),
			accent
		)
		add(
			"Lemon",
			"VCylinder",
			Vector3.new(0.42 * s, 0.08 * s, 0.42 * s),
			CFrame.new(-0.32 * s, top - 0.04 * s, 0) * CFrame.Angles(math.rad(90), 0, math.rad(20)),
			LEMON
		)
	elseif accessory == "Tentacles" then
		for i = 1, 6 do
			local angle = (i - 1) * (math.pi / 3)
			local tilt = if i % 2 == 0 then math.rad(10) else math.rad(-10)
			add(
				"Tentacle",
				"VCylinder",
				Vector3.new(0.1 * s, 0.55 * s, 0.1 * s),
				CFrame.new(math.cos(angle) * 0.26 * s, 0.3 * s, math.sin(angle) * 0.26 * s) * CFrame.Angles(tilt, 0, -tilt),
				accent
			)
		end
		add("Glow", "Ball", Vector3.new(0.42 * s, 0.42 * s, 0.42 * s), CFrame.new(body.headCenter), accent, "Neon")
	elseif accessory == "ShellCrown" then
		for i = 1, 5 do
			local angle = (i - 1) * (2 * math.pi / 5)
			add(
				"Spike",
				"Ellipsoid",
				Vector3.new(0.16 * s, 0.36 * s, 0.16 * s),
				CFrame.new(math.cos(angle) * 0.22 * s, top + 0.08 * s, math.sin(angle) * 0.22 * s)
					* CFrame.Angles(math.sin(angle) * math.rad(15), 0, -math.cos(angle) * math.rad(15)),
				accent
			)
		end
		add("Pearl", "Ball", Vector3.new(0.16 * s, 0.16 * s, 0.16 * s), CFrame.new(0, top + 0.12 * s, 0), WHITE)
	elseif accessory == "MushroomCap" then
		local capY = top + 0.12 * s
		add("Cap", "Ellipsoid", Vector3.new(body.W * 1.55, 0.62 * s, body.W * 1.55), CFrame.new(0, capY, 0), accent, "Neon")
		local dots = { Vector3.new(0, 0.3, 0), Vector3.new(0.34, 0.2, 0.1), Vector3.new(-0.3, 0.2, 0.18), Vector3.new(0.1, 0.2, -0.34) }
		for _, p in dots do
			add("Dot", "Ball", Vector3.new(0.14 * s, 0.14 * s, 0.14 * s), CFrame.new(p.X * s, capY + p.Y * s, p.Z * s), WHITE)
		end
	elseif accessory == "Antenna" then
		add(
			"Antenna",
			"VCylinder",
			Vector3.new(0.05 * s, 0.45 * s, 0.05 * s),
			CFrame.new(0.14 * s, top + 0.18 * s, 0) * CFrame.Angles(0, 0, math.rad(-12)),
			INK
		)
		add("AntennaTip", "Ball", Vector3.new(0.16 * s, 0.16 * s, 0.16 * s), CFrame.new(0.19 * s, top + 0.42 * s, 0), accent, "Neon")
		for _, side in { -1, 1 } do
			add(
				"Tuft",
				"Ellipsoid",
				Vector3.new(0.14 * s, 0.32 * s, 0.12 * s),
				CFrame.new(side * 0.28 * s, top - 0.04 * s, 0) * CFrame.Angles(0, 0, side * math.rad(-22)),
				look.color
			)
		end
		local bellyY = body.cy - 0.25 * s
		add(
			"Belly",
			"Ellipsoid",
			Vector3.new(0.5 * s, 0.5 * s, 0.2 * s),
			CFrame.new(0, bellyY, body.surfaceZ(0, bellyY) + 0.05 * s),
			Color3.fromRGB(214, 204, 255)
		)
	elseif accessory == "EyeStalks" then
		for _, side in { -1, 1 } do
			local base = Vector3.new(side * 0.14 * s, top - 0.02 * s, body.headCenter.Z)
			add(
				"Stalk",
				"VCylinder",
				Vector3.new(0.07 * s, 0.45 * s, 0.07 * s),
				CFrame.new(base + Vector3.new(side * 0.04 * s, 0.2 * s, 0)) * CFrame.Angles(0, 0, side * math.rad(-14)),
				look.color
			)
			add(
				"StalkTip",
				"Ball",
				Vector3.new(0.17 * s, 0.17 * s, 0.17 * s),
				CFrame.new(base + Vector3.new(side * 0.1 * s, 0.44 * s, 0)),
				accent,
				"Neon"
			)
		end
		for i, z in { -0.05, 0.3, 0.62 } do
			local size = 0.2 - i * 0.03
			add("Spot", "Ball", Vector3.new(size * s, size * s, size * s), CFrame.new(0, 0.6 * s, z * s), accent, "Neon")
		end
	elseif accessory == "Mane" then
		ring(add, "Mane", 12, body.W / 2 + 0.02 * s, body.headCenter, Vector3.new(0.36 * s, 0.36 * s, 0.3 * s), accent, 0.08 * s)
		for _, side in { -1, 1 } do
			add(
				"Wing",
				"Ellipsoid",
				Vector3.new(0.72 * s, 0.06 * s, 0.38 * s),
				CFrame.new(side * 0.4 * s, body.cy + 0.28 * s, 0.42 * s) * CFrame.Angles(0, 0, side * math.rad(30)),
				Color3.fromRGB(255, 250, 206),
				"Neon",
				0.35
			)
		end
		add("Tail", "Ball", Vector3.new(0.3 * s, 0.3 * s, 0.3 * s), CFrame.new(0, body.cy - 0.2 * s, 0.62 * s), LEMON, "Neon")
	end
end

-- Liste des pièces d'un mème et sa hauteur approximative (pour placer les étiquettes).
function MemeAppearance.specs(memeId: string): ({ PartSpec }, number)
	local def = Config.Memes.Defs[memeId]
	assert(def, "Mème inconnu : " .. tostring(memeId))
	local look = def.look
	local scale = Config.Rarities.Defs[def.rarity].scale
	local s = look.size * scale
	local list, add = makeBuilder()
	local body = buildBody(look, s, add)
	buildFace(look, body, add)
	buildAccessory(look, body, s, add)

	local height = 0
	for _, spec in list do
		local h = spec.offset.Position.Y + math.max(spec.size.X, spec.size.Y, spec.size.Z) / 2
		height = math.max(height, h)
	end
	return list, height
end

local materials: { [string]: Enum.Material } = {
	SmoothPlastic = Enum.Material.SmoothPlastic,
	Neon = Enum.Material.Neon,
	Glass = Enum.Material.Glass,
}

local function makePart(spec: PartSpec): BasePart
	local part = Instance.new("Part")
	if spec.kind == "Ball" then
		part.Shape = Enum.PartType.Ball
		part.Size = Vector3.new(spec.size.X, spec.size.X, spec.size.X)
	elseif spec.kind == "VCylinder" then
		part.Shape = Enum.PartType.Cylinder
		part.Size = Vector3.new(spec.size.Y, spec.size.X, spec.size.Z)
	else
		part.Shape = Enum.PartType.Block
		part.Size = spec.size
		if spec.kind == "Ellipsoid" then
			local mesh = Instance.new("SpecialMesh")
			mesh.MeshType = Enum.MeshType.Sphere
			mesh.Parent = part
		end
	end
	part.Name = spec.name
	part.Color = spec.color
	part.Material = materials[spec.material] or Enum.Material.SmoothPlastic
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth
	part.CanCollide = false
	part.CanTouch = false
	part.CanQuery = false
	part.CastShadow = false
	part.Massless = true
	return part
end

-- Construit le Model d'un mème posé à `cframe` (dessous du mème).
function MemeAppearance.build(memeId: string, cframe: CFrame, options: BuildOptions?): Model
	local opts: BuildOptions = options or {}
	local anchored = opts.anchored ~= false
	local extraTransparency = opts.transparency or 0
	local def = Config.Memes.Defs[memeId]
	local list, height = MemeAppearance.specs(memeId)

	local model = Instance.new("Model")
	model.Name = memeId
	local primary: BasePart? = nil
	for _, spec in list do
		local part = makePart(spec)
		local offset = spec.offset
		if spec.kind == "VCylinder" then
			offset = offset * CFrame.Angles(0, 0, math.pi / 2)
		end
		part.CFrame = cframe * offset
		part.Transparency = math.max(spec.transparency, extraTransparency)
		part.Anchored = anchored
		part.Parent = model
		if spec.isBody then
			primary = part
		end
	end

	if opts.ring then
		local rarity = Config.Rarities.Defs[def.rarity]
		local ringPart = makePart({
			name = "RarityRing",
			kind = "VCylinder",
			size = Vector3.new(def.look.size * rarity.scale * 1.25, 0.12, def.look.size * rarity.scale * 1.25),
			offset = CFrame.new(0, 0.06, 0),
			color = rarity.color,
			material = "Neon",
			transparency = 0.15,
			isBody = false,
		})
		ringPart.CFrame = cframe * CFrame.new(0, 0.06, 0) * CFrame.Angles(0, 0, math.pi / 2)
		ringPart.Anchored = anchored
		ringPart.Parent = model
	end

	assert(primary, "Le mème doit avoir un corps")
	model.PrimaryPart = primary
	model.WorldPivot = cframe
	if not anchored then
		for _, child in model:GetChildren() do
			if child:IsA("BasePart") and child ~= primary then
				local weld = Instance.new("WeldConstraint")
				weld.Part0 = primary
				weld.Part1 = child
				weld.Parent = child
			end
		end
	end
	model:SetAttribute("MemeId", memeId)
	model:SetAttribute("Anim", def.look.anim)
	model:SetAttribute("Height", height)
	return model
end

return MemeAppearance
