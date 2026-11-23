local RSGCore = exports['rsg-core']:GetCoreObject()
------------------------------------------
-- hunting journal: per player and species, how many were skinned,
-- how many were perfect, how many sold and the best butcher payout
------------------------------------------
HuntingJournal = {}

local function enabled()
    return Config.Journal and Config.Journal.Enabled and HuntingDB.ready
end
HuntingJournal.Enabled = enabled

-- species name: butcher list first (proper names), then the skinning list
local AnimalName, speciesCount = {}, 0
for _, a in ipairs(Config.Animal) do AnimalName[a.model] = a.name end
for _, a in ipairs(Config.Animals) do
    if a.skinable then speciesCount = speciesCount + 1 end
    AnimalName[a.modelhash] = AnimalName[a.modelhash] or a.name
end

function HuntingJournal.Name(model)
    return AnimalName[model] or locale('hunting_unknown')
end

local function citizenId(src)
    local Player = RSGCore.Functions.GetPlayer(src)
    return Player and Player.PlayerData.citizenid
end

function HuntingJournal.RecordSkin(src, model, quality)
    if not enabled() then return end
    local cid = citizenId(src)
    if not cid then return end
    MySQL.insert('INSERT INTO hunting_journal (citizenid, model, skinned, perfect) VALUES (?, ?, 1, ?) ON DUPLICATE KEY UPDATE skinned = skinned + 1, perfect = perfect + VALUES(perfect)',
        { cid, model, quality == 'perfect' and 1 or 0 })
end

function HuntingJournal.RecordSale(src, model, cash)
    if not enabled() then return end
    local cid = citizenId(src)
    if not cid then return end
    MySQL.insert('INSERT INTO hunting_journal (citizenid, model, sold, best_sale) VALUES (?, ?, 1, ?) ON DUPLICATE KEY UPDATE sold = sold + 1, best_sale = GREATEST(best_sale, VALUES(best_sale))',
        { cid, model, cash })
end

-- rows for the journal tab: { top = {...}, sub = 'text', rankText = 'text' }
function HuntingJournal.Board(src, maxRows)
    local cid = citizenId(src)
    if not cid then return nil end
    local rows = MySQL.query.await('SELECT model, skinned, perfect, sold, best_sale FROM hunting_journal WHERE citizenid = ? ORDER BY skinned DESC, sold DESC', { cid }) or {}
    local top, skinned = {}, 0
    for i, r in ipairs(rows) do
        skinned = skinned + (tonumber(r.skinned) or 0)
        if i <= maxRows then
            local best = tonumber(r.best_sale) or 0
            top[#top + 1] = {
                rank = i,
                name = HuntingJournal.Name(tonumber(r.model)),
                sub = best > 0 and locale('journal_best', ('%.2f'):format(best)) or nil,
                right = locale('journal_row', r.skinned or 0, r.perfect or 0),
            }
        end
    end
    return {
        top = top,
        total = #rows,
        sub = locale('journal_sub', #rows, speciesCount, skinned),
        rankText = ('%s/%s'):format(#rows, speciesCount),
    }
end
