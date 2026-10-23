--!strict
-- Icônes originales dessinées avec des primitives d'interface (Frame, UICorner, UIStroke).
-- Aucune image externe. Chaque icône remplit son parent (taille relative) et reste carrée.
-- Icônes : coin, basket, cards, lock, house, alert, help, leaf, close, check, shield.

local Icons = {}

local INK = Color3.fromRGB(34, 28, 48)

type Props = { [string]: any }

local function new(className: string, props: Props, parent: Instance?): any
	local instance = Instance.new(className)
	for key, value in props do
		(instance :: any)[key] = value
	end
	if parent then
		instance.Parent = parent
	end
	return instance
end

local function box(parent: Instance, x: number, y: number, w: number, h: number, color: Color3?, props: Props?): Frame
	local frame = new("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(x, y),
		Size = UDim2.fromScale(w, h),
		BackgroundColor3 = color or INK,
		BackgroundTransparency = if color then 0 else 1,
		BorderSizePixel = 0,
	}, parent)
	if props then
		for key, value in props do
			(frame :: any)[key] = value
		end
	end
	return frame
end

local function round(frame: Instance, scale: number)
	new("UICorner", { CornerRadius = UDim.new(scale, 0) }, frame)
end

local function stroke(frame: Instance, color: Color3, thickness: number)
	new("UIStroke", {
		Color = color,
		Thickness = thickness,
		ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
	}, frame)
end

local function glyph(parent: Instance, text: string, color: Color3, scale: number?)
	local size = scale or 0.7
	return new("TextLabel", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.52),
		Size = UDim2.fromScale(size, size),
		BackgroundTransparency = 1,
		Text = text,
		TextColor3 = color,
		TextScaled = true,
		Font = Enum.Font.FredokaOne,
	}, parent)
end

local function root(name: string): Frame
	local frame = new("Frame", {
		Name = "Icon_" .. name,
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
	})
	new("UIAspectRatioConstraint", { AspectRatio = 1 }, frame)
	return frame
end

local drawers: { [string]: (Frame, Color3?) -> () } = {}

drawers.coin = function(f)
	local outer = box(f, 0.5, 0.5, 0.9, 0.9, Color3.fromRGB(255, 200, 40))
	round(outer, 0.5)
	stroke(outer, Color3.fromRGB(190, 120, 0), 2)
	local inner = box(f, 0.5, 0.5, 0.62, 0.62)
	round(inner, 0.5)
	stroke(inner, Color3.fromRGB(226, 156, 0), 2)
	glyph(f, "M", Color3.fromRGB(150, 86, 0), 0.5)
end

drawers.basket = function(f, color)
	local c = color or Color3.fromRGB(255, 255, 255)
	local handle = box(f, 0.5, 0.38, 0.56, 0.52)
	round(handle, 0.5)
	stroke(handle, c, 3)
	local body = box(f, 0.5, 0.66, 0.86, 0.42, c)
	round(body, 0.2)
	for _, x in { 0.32, 0.5, 0.68 } do
		box(f, x, 0.67, 0.07, 0.24, Color3.fromRGB(80, 70, 110), { BackgroundTransparency = 0.45 })
	end
end

drawers.cards = function(f, color)
	local c = color or Color3.fromRGB(255, 255, 255)
	local back = box(f, 0.42, 0.5, 0.48, 0.68, c, { Rotation = -14, BackgroundTransparency = 0.35 })
	round(back, 0.16)
	local front = box(f, 0.58, 0.52, 0.48, 0.68, c, { Rotation = 8 })
	round(front, 0.16)
	stroke(front, Color3.fromRGB(80, 70, 110), 2)
	local faceDot = box(front, 0.5, 0.45, 0.5, 0.36, Color3.fromRGB(255, 200, 70))
	round(faceDot, 0.5)
	box(faceDot, 0.35, 0.45, 0.14, 0.2, INK)
	box(faceDot, 0.65, 0.45, 0.14, 0.2, INK)
end

drawers.lock = function(f, color)
	local c = color or Color3.fromRGB(255, 255, 255)
	local shackle = box(f, 0.5, 0.34, 0.46, 0.5)
	round(shackle, 0.5)
	stroke(shackle, c, 3)
	local body = box(f, 0.5, 0.66, 0.68, 0.48, c)
	round(body, 0.2)
	local hole = box(body, 0.5, 0.42, 0.2, 0.28, INK)
	round(hole, 0.5)
	box(body, 0.5, 0.64, 0.08, 0.26, INK)
end

drawers.house = function(f, color)
	local c = color or Color3.fromRGB(255, 255, 255)
	local roof = box(f, 0.5, 0.44, 0.58, 0.58, c, { Rotation = 45 })
	round(roof, 0.08)
	local body = box(f, 0.5, 0.7, 0.62, 0.44, c)
	round(body, 0.08)
	local door = box(f, 0.5, 0.79, 0.18, 0.26, Color3.fromRGB(80, 70, 110))
	round(door, 0.3)
end

drawers.alert = function(f)
	local diamond = box(f, 0.5, 0.5, 0.66, 0.66, Color3.fromRGB(255, 96, 70), { Rotation = 45 })
	round(diamond, 0.16)
	stroke(diamond, Color3.fromRGB(255, 255, 255), 2)
	glyph(f, "!", Color3.fromRGB(255, 255, 255), 0.55)
end

drawers.help = function(f, color)
	local c = color or Color3.fromRGB(255, 255, 255)
	local circle = box(f, 0.5, 0.5, 0.86, 0.86)
	round(circle, 0.5)
	stroke(circle, c, 3)
	glyph(f, "?", c, 0.6)
end

drawers.leaf = function(f, color)
	local c = color or Color3.fromRGB(80, 210, 150)
	local leaf = box(f, 0.5, 0.48, 0.46, 0.84, c, { Rotation = 40 })
	round(leaf, 0.5)
	box(f, 0.5, 0.5, 0.06, 0.62, Color3.fromRGB(255, 255, 255), { Rotation = 40, BackgroundTransparency = 0.25 })
end

drawers.close = function(f, color)
	local c = color or INK
	box(f, 0.5, 0.5, 0.14, 0.8, c, { Rotation = 45 })
	box(f, 0.5, 0.5, 0.14, 0.8, c, { Rotation = -45 })
end

drawers.check = function(f, color)
	local c = color or Color3.fromRGB(255, 255, 255)
	box(f, 0.33, 0.6, 0.14, 0.4, c, { Rotation = -45 })
	box(f, 0.6, 0.5, 0.14, 0.7, c, { Rotation = 38 })
end

drawers.shield = function(f, color)
	local c = color or Color3.fromRGB(80, 210, 150)
	local top = box(f, 0.5, 0.36, 0.76, 0.44, c)
	round(top, 0.18)
	local tip = box(f, 0.5, 0.58, 0.5, 0.5, c, { Rotation = 45 })
	round(tip, 0.12)
	local mark = box(f, 0.5, 0.46, 0.5, 0.5)
	drawers.check(mark, Color3.fromRGB(255, 255, 255))
end

Icons.names = { "coin", "basket", "cards", "lock", "house", "alert", "help", "leaf", "close", "check", "shield" }

-- Crée l'icône `name` (Frame transparent remplissant le parent).
function Icons.create(name: string, color: Color3?): Frame
	local drawer = drawers[name]
	assert(drawer, "Icône inconnue : " .. name)
	local frame = root(name)
	drawer(frame, color)
	return frame
end

return Icons
