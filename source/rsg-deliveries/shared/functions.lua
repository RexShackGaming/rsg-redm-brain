-- shared helpers used by both client (UI preview) and server (authoritative payout)

---Calculates the cash reward for a route. Server value is authoritative; client only uses it for display.
---@return integer cash, boolean capped
function CalculateCashReward(location, destination)
    local reward = destination.reward or {}
    local distance = #(location.cartSpawn.xyz - destination.deliveryLoc)
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

---@return number distance in metres from the hub's cart spawn to the drop-off
function GetRouteDistance(location, destination)
    return #(location.cartSpawn.xyz - destination.deliveryLoc)
end
