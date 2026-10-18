--!strict
--[[
	RateLimiter
	Per-player "N calls per time window" limits for remotes.

	local limiter = RateLimiter.new(10, 1) -- 10 calls per second
	if not limiter:check(player) then return end

	Entries are cleared when the player leaves.
]]

local Players = game:GetService("Players")

export type RateLimiter = {
	check: (self: RateLimiter, player: Player) -> boolean,
}

type Bucket = { windowStart: number, count: number }

local RateLimiter = {}

function RateLimiter.new(maxCalls: number, windowSeconds: number): RateLimiter
	local buckets: { [Player]: Bucket } = {}

	Players.PlayerRemoving:Connect(function(player)
		buckets[player] = nil
	end)

	local limiter = {} :: any

	-- Returns true if the call is allowed (and counts it), false if over the limit.
	function limiter:check(player: Player): boolean
		local now = os.clock()
		local bucket = buckets[player]
		if bucket == nil or now - bucket.windowStart >= windowSeconds then
			buckets[player] = { windowStart = now, count = 1 }
			return true
		end
		if bucket.count >= maxCalls then
			return false
		end
		bucket.count += 1
		return true
	end

	return limiter :: RateLimiter
end

-- Builds a limiter from a GameConfig.RateLimits entry.
function RateLimiter.fromConfig(config: { Calls: number, WindowSeconds: number }): RateLimiter
	return RateLimiter.new(config.Calls, config.WindowSeconds)
end

return RateLimiter
