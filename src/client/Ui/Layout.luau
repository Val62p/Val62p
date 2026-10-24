--!strict
-- Mise en page responsive, en fonctions pures (testées pour petits écrans tactiles).
-- `screen` = taille utile de l'écran (ScreenGui.AbsoluteSize, barre Roblox déjà exclue).
local Layout = {}

Layout.HudButtonCount = 4

function Layout.isCompact(screen: Vector2): boolean
	return screen.Y < 560 or screen.X < 900
end

-- Zone réservée aux commandes tactiles (joystick à gauche, saut à droite) en bas d'écran.
function Layout.thumbZone(screen: Vector2): number
	return math.min(screen.X * 0.22, 190)
end

export type Bar = { size: number, buttonWidth: number, gap: number, width: number, bottom: number }

-- Barre d'actions du HUD, centrée en bas, entre les zones des pouces.
-- Boutons un peu plus larges que hauts pour loger un libellé lisible sous l'icône.
function Layout.bottomBar(screen: Vector2, count: number?): Bar
	local n = count or Layout.HudButtonCount
	local compact = Layout.isCompact(screen)
	local size = if compact then 56 else 68
	local gap = if compact then 8 else 12
	local available = screen.X - 2 * Layout.thumbZone(screen)
	local function total(height: number): number
		return n * (height + 16) + (n - 1) * gap
	end
	-- Rétrécit si nécessaire, sans descendre sous 44 px (cible tactile minimale).
	while total(size) > available and size > 44 do
		size -= 2
	end
	return {
		size = size,
		buttonWidth = size + 16,
		gap = gap,
		width = total(size),
		bottom = if compact then 10 else 18,
	}
end

-- Hauteur occupée en haut par le solde et la puce d'état.
function Layout.topReserve(screen: Vector2): number
	return if Layout.isCompact(screen) then 64 else 96
end

export type PanelFrame = { width: number, height: number, centerY: number }

function Layout.panel(screen: Vector2): PanelFrame
	local compact = Layout.isCompact(screen)
	local top = if compact then 8 else Layout.topReserve(screen)
	local bottomReserve = if compact then 8 else 24
	local width = math.clamp(screen.X - 24, 280, 760)
	local height = math.clamp(screen.Y - top - bottomReserve, 220, 600)
	local centerY = top + height / 2
	-- Toujours entièrement visible, même si l'écran est plus petit que les minimums.
	width = math.min(width, screen.X - 8)
	height = math.min(height, screen.Y - 8)
	centerY = math.clamp(centerY, height / 2 + 4, screen.Y - height / 2 - 4)
	return { width = width, height = height, centerY = centerY }
end

function Layout.gridColumns(width: number): number
	if width >= 660 then
		return 3
	elseif width >= 420 then
		return 2
	end
	return 1
end

function Layout.cardHeight(screen: Vector2): number
	return if Layout.isCompact(screen) then 168 else 188
end

-- Taille de texte adaptée (jamais sous 14 px).
function Layout.textSize(screen: Vector2, base: number): number
	if Layout.isCompact(screen) then
		return math.max(14, base - 2)
	end
	return base
end

return Layout
