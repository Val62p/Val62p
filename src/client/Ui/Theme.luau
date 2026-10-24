--!strict
-- Thème de l'interface : couleurs à fort contraste, typographie lisible, tailles minimales.
local rgb = Color3.fromRGB

local Theme = {}

Theme.Colors = table.freeze({
	White = rgb(255, 255, 255),
	Ink = rgb(34, 28, 48),
	InkSoft = rgb(92, 84, 120),
	Panel = rgb(255, 255, 255),
	PanelAlt = rgb(245, 240, 255),
	Line = rgb(226, 220, 240),
	Backdrop = rgb(20, 16, 36),
	Primary = rgb(214, 51, 108),
	Secondary = rgb(28, 120, 200),
	Success = rgb(24, 135, 84),
	Danger = rgb(200, 40, 60),
	Warning = rgb(255, 184, 40),
	Zen = rgb(22, 128, 100),
	Disabled = rgb(200, 196, 214),
	Coin = rgb(255, 200, 40),
})

-- Paires texte / fond utilisées par l'interface : toutes doivent atteindre 4,5:1 (WCAG AA).
Theme.ContrastPairs = table.freeze({
	{ "Ink", "Panel" },
	{ "Ink", "PanelAlt" },
	{ "InkSoft", "Panel" },
	{ "InkSoft", "PanelAlt" },
	{ "White", "Primary" },
	{ "White", "Secondary" },
	{ "White", "Success" },
	{ "White", "Danger" },
	{ "White", "Zen" },
	{ "White", "InkSoft" },
	{ "Ink", "Warning" },
	{ "Ink", "Disabled" },
})

Theme.Fonts = table.freeze({
	Title = Enum.Font.FredokaOne,
	Body = Enum.Font.GothamMedium,
	Bold = Enum.Font.GothamBold,
})

-- Tailles de texte en pixels (jamais sous 14).
Theme.TextSize = table.freeze({
	Small = 14,
	Body = 16,
	Large = 20,
	Title = 26,
	Coins = 28,
})

Theme.Radius = 12

local function channel(value: number): number
	if value <= 0.03928 then
		return value / 12.92
	end
	return ((value + 0.055) / 1.055) ^ 2.4
end

function Theme.luminance(color: Color3): number
	return 0.2126 * channel(color.R) + 0.7152 * channel(color.G) + 0.0722 * channel(color.B)
end

function Theme.contrast(a: Color3, b: Color3): number
	local la, lb = Theme.luminance(a), Theme.luminance(b)
	local lighter, darker = math.max(la, lb), math.min(la, lb)
	return (lighter + 0.05) / (darker + 0.05)
end

-- Texte lisible (blanc ou encre) sur un fond donné, ex. couleur de rareté.
function Theme.readableOn(background: Color3): Color3
	if Theme.contrast(Theme.Colors.White, background) >= Theme.contrast(Theme.Colors.Ink, background) then
		return Theme.Colors.White
	end
	return Theme.Colors.Ink
end

return Theme
