-- shared helpers (client + server)

---@return boolean open, integer openHour, integer closeHour
function FishmongerIsOpen(loc, hour)
    local cfg = Config.OpeningHours
    local h = loc.hours or cfg
    if not cfg.enabled or hour == nil then return true, h.open, h.close end
    if h.open == h.close then return true, h.open, h.close end
    if h.open < h.close then return hour >= h.open and hour < h.close, h.open, h.close end
    return hour >= h.open or hour < h.close, h.open, h.close
end

function FishmongerFillet(item)
    local f = Config.Fish[item]
    return f and f.fillet or Config.FilletItem
end
