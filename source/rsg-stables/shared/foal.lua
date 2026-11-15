-- rsg-stables: foal growth rules (shared by client and server)
-- A foal is a horse born at a stable (rsg_stables_horses.born = 1) that is younger than the adult age.
-- Its size grows from Config.FoalGrowth.startScale to adultScale over that time, and it can't be ridden.

local function flag(v) return v == true or v == 1 end

--- seconds a foal takes to grow up (defaults to the end of the Young stage in Config.HorseAging)
function FoalAdultSeconds()
    local G = Config.FoalGrowth or {}
    local days = tonumber(G.adultAfterDays) or tonumber(Config.HorseAging and Config.HorseAging.youngUntilDays) or 7
    return math.max(1, days * 86400)
end

--- @param row table horse row; needs `born` and `age_seconds` (see AGE_SQL in server/server.lua)
--- @return boolean isFoal, number scale, number secondsLeft
function GetFoalState(row)
    local G = Config.FoalGrowth
    if not (G and G.enabled) or type(row) ~= 'table' then return false, 1.0, 0 end
    if not G.applyToPurchased and not flag(row.born) then return false, 1.0, 0 end
    local total = FoalAdultSeconds()
    local age = math.max(0, tonumber(row.age_seconds) or 0)
    if age >= total then return false, (G.adultScale or 1.0), 0 end
    local startScale, adultScale = G.startScale or 0.5, G.adultScale or 1.0
    local scale
    if type(G.scaleByDay) == 'table' then
        -- like rsg-ranch: one size per day of age; the highest day entry at or below the foal's age wins
        local day = math.floor(age / 86400)
        scale = startScale
        local best = -1
        for d, v in pairs(G.scaleByDay) do
            if type(d) == 'number' and d <= day and d > best then best, scale = d, v end
        end
    else
        scale = startScale + (adultScale - startScale) * (age / total) -- smooth linear growth
    end
    scale = math.min(math.max(tonumber(scale) or 1.0, 0.1), 2.0) -- same clamp as rsg-ranch
    return true, scale, total - age
end
