--!strict
-- Validation des arguments réseau : type, taille et contenu. Toute valeur venant du client
-- est hostile tant qu'elle n'est pas passée par ici.
local Validate = {}

function Validate.isFiniteNumber(value: any): boolean
	return type(value) == "number" and value == value and value ~= math.huge and value ~= -math.huge
end

function Validate.isInteger(value: any, min: number, max: number): boolean
	return Validate.isFiniteNumber(value) and value % 1 == 0 and value >= min and value <= max
end

-- Identifiant court : lettres, chiffres, souligné uniquement.
function Validate.isId(value: any, maxLength: number?): boolean
	if type(value) ~= "string" then
		return false
	end
	local length = #value
	return length > 0 and length <= (maxLength or 32) and string.match(value, "^[%w_]+$") ~= nil
end

-- Clé présente dans un dictionnaire de configuration.
function Validate.isKeyOf(value: any, dict: { [string]: any }): boolean
	return Validate.isId(value, 48) and rawget(dict, value) ~= nil
end

-- Identifiant d'instance de mème possédé (« m » + nombre).
function Validate.isMemeUid(value: any): boolean
	return type(value) == "string" and #value <= 12 and string.match(value, "^m%d+$") ~= nil
end

return Validate
