-- shared helpers used by both client (UI preview) and server (authoritative payout)

---@return number distance in metres from the hub's cart spawn to the drop-off
function GetRouteDistance(location, destination)
    return #(location.cartSpawn.xyz - destination.deliveryLoc)
end

---Calculates the cash reward for a route. Server value is authoritative; client only uses it for display.
---@return integer cash, boolean capped
function CalculateCashReward(location, destination)
    local reward = destination.reward or {}
    local distance = GetRouteDistance(location, destination)
    local cash = 0

    if reward.priceByDistance and reward.priceByDistance.activation then
        cash = cash + Config.BaseReward + (distance * Config.RewardPerDistance * (reward.priceByDistance.multiplier or 1.0))
    end
    if reward.priceByConfig and reward.priceByConfig.activation then
        cash = cash + (reward.priceByConfig.price or 0)
    end

    cash = math.max(0, math.floor(cash + 0.5))
    if cash > Config.MaxRewardAmount then
        return Config.MaxRewardAmount, true
    end
    return cash, false
end

---Route of a hub that is 'hot' today (rotates at midnight UTC). Client uses it for the badge, the server for the bonus.
---@return integer|nil index into location.deliveries
function GetHotRouteIndex(hubIndex, count)
    if not count or count < 1 then return nil end
    local now = IsDuplicityVersion() and os.time() or GetCloudTimeAsInt()
    return ((now // 86400) + hubIndex) % count + 1
end
