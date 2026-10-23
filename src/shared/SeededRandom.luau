--!strict
-- Générateur pseudo-aléatoire déterministe (xorshift32) : décor reproductible et tests stables.
local SeededRandom = {}
SeededRandom.__index = SeededRandom

export type SeededRandom = typeof(setmetatable({} :: { state: number }, SeededRandom))

function SeededRandom.new(seed: number): SeededRandom
	local state = bit32.band(math.floor(seed), 0xFFFFFFFF)
	if state == 0 then
		state = 0x9E3779B9
	end
	return setmetatable({ state = state }, SeededRandom)
end

function SeededRandom.nextU32(self: SeededRandom): number
	local x = self.state
	x = bit32.bxor(x, bit32.lshift(x, 13))
	x = bit32.bxor(x, bit32.rshift(x, 17))
	x = bit32.bxor(x, bit32.lshift(x, 5))
	self.state = x
	return x
end

-- Nombre réel dans [min, max).
function SeededRandom.nextNumber(self: SeededRandom, min: number?, max: number?): number
	local lo, hi = min or 0, max or 1
	return lo + (self:nextU32() / 4294967296) * (hi - lo)
end

-- Entier dans [min, max].
function SeededRandom.nextInteger(self: SeededRandom, min: number, max: number): number
	return min + self:nextU32() % (max - min + 1)
end

return SeededRandom
