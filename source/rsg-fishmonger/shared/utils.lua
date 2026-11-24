-- shared helpers (client + server)

-- item given when processing this fish (per-fish override, else Config.FilletItem)
function FishmongerFillet(item)
    local f = Config.Fish[item]
    return f and f.fillet or Config.FilletItem
end
