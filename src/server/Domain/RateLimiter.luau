--!strict
-- Limitation de débit par joueur et par action (seau à jetons), horloge injectée.
local RateLimiter = {}
RateLimiter.__index = RateLimiter

type Bucket = { tokens: number, last: number }

export type RateLimiter = typeof(setmetatable(
	{} :: { clock: () -> number, buckets: { [number]: { [string]: Bucket } } },
	RateLimiter
))

function RateLimiter.new(clock: () -> number): RateLimiter
	return setmetatable({ clock = clock, buckets = {} }, RateLimiter)
end

-- Consomme un jeton si disponible. `key` distingue les actions d'un même joueur.
function RateLimiter.allow(self: RateLimiter, userId: number, key: string, capacity: number, refillPerSecond: number): boolean
	local now = self.clock()
	local perUser = self.buckets[userId]
	if not perUser then
		perUser = {}
		self.buckets[userId] = perUser
	end
	local bucket = perUser[key]
	if not bucket then
		bucket = { tokens = capacity, last = now }
		perUser[key] = bucket
	else
		local elapsed = math.max(0, now - bucket.last)
		bucket.tokens = math.min(capacity, bucket.tokens + elapsed * refillPerSecond)
		bucket.last = now
	end
	if bucket.tokens >= 1 then
		bucket.tokens -= 1
		return true
	end
	return false
end

function RateLimiter.forget(self: RateLimiter, userId: number)
	self.buckets[userId] = nil
end

return RateLimiter
