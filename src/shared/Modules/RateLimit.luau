--!strict
-- Per-player, per-key cooldown for remote handlers. Call from the server only.
local Players = game:GetService("Players")

local RateLimit = {}

local last: { [Player]: { [string]: number } } = {}

-- Rejections since the server started, per key (read by MetricsService).
RateLimit.rejected = {} :: { [string]: number }

-- Returns true if the call is allowed. A rejected call does not reset the timer.
function RateLimit.check(player: Player, key: string, interval: number): boolean
	local mine = last[player]
	if not mine then
		mine = {}
		last[player] = mine
	end
	local now = os.clock()
	if now - (mine[key] or -math.huge) < interval then
		RateLimit.rejected[key] = (RateLimit.rejected[key] or 0) + 1
		return false
	end
	mine[key] = now
	return true
end

Players.PlayerRemoving:Connect(function(p)
	last[p] = nil
end)

return RateLimit
