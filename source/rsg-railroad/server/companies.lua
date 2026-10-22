local RSGCore = exports['rsg-core']:GetCoreObject()

---------------------------------------------------------------
-- ADD COMPANY XP AND HANDLE RANK-UP (+ one-off rank cash reward)
---------------------------------------------------------------
function AddCompanyXP(src, citizenid, companyId, xpAmount)
    if not companyId or not Config.Companies[companyId] then return end
    xpAmount = math.floor(tonumber(xpAmount) or 0)
    if xpAmount <= 0 then return end

    DB.EnsureCompanyMembership(citizenid, companyId)
    local membership = DB.GetCompanyMembership(citizenid, companyId)
    if not membership then return end

    DB.AddCompanyXP(citizenid, companyId, xpAmount)

    local newXP = (membership.xp or 0) + xpAmount
    local currentRank = membership.rank or 1
    local newRank = currentRank
    for rank = #Config.Ranks, 1, -1 do
        if newXP >= Config.Ranks[rank].xpRequired then
            newRank = rank
            break
        end
    end
    if newRank <= currentRank then return end

    DB.SetCompanyRank(citizenid, companyId, newRank)
    NotifyPlayer(src, locale('rank_up', Config.Ranks[newRank].label, CompanyLabel(companyId)), 'success', 8000)

    local reward = Config.CompanyRankRewards[newRank]
    if reward and reward.cashReward > 0 then
        local Player = RSGCore.Functions.GetPlayer(src)
        if Player then
            Player.Functions.AddMoney('cash', reward.cashReward, 'railroad-rank-reward')
            NotifyPlayer(src, locale('rank_reward', reward.cashReward), 'success')
        end
    end
end
