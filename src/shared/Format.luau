--!strict
-- Mise en forme des nombres et durées (texte en français).
local Format = {}

local function group(digits: string): string
	-- Groupes de 3 chiffres séparés par une espace fine insécable.
	local out = digits
	while true do
		local replaced, count = string.gsub(out, "^(%d+)(%d%d%d)", "%1\u{202F}%2")
		out = replaced
		if count == 0 then
			break
		end
	end
	return out
end

function Format.coins(amount: number): string
	local n = math.floor(math.max(0, amount))
	if n >= 1e9 then
		return (string.gsub(string.format("%.1f", n / 1e9), "%.", ",")) .. " Md"
	elseif n >= 1e6 then
		return (string.gsub(string.format("%.1f", n / 1e6), "%.", ",")) .. " M"
	end
	return group(tostring(n))
end

function Format.duration(seconds: number): string
	local s = math.max(0, math.ceil(seconds))
	local minutes = s // 60
	local rest = s % 60
	return string.format("%d:%02d", minutes, rest)
end

function Format.multiplier(value: number): string
	local text = string.format("%.2f", value)
	text = string.gsub(text, "0+$", "")
	text = string.gsub(text, "%.$", "")
	text = string.gsub(text, "%.", ",")
	return "×" .. text
end

function Format.plural(count: number, singular: string, plural: string): string
	if math.abs(count) >= 2 then
		return plural
	end
	return singular
end

return Format
