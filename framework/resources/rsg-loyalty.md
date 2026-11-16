# rsg-loyalty

Version 3.1.0. Loyalty script for RSG Framework

Loyalty points for RSG Framework (RedM). Players earn points for playing, climb loyalty tiers and spend points at NPC stores on cash, items and weekly specials. Full developer reference: [DOCS.md](DOCS.md). **Version:** 3.1.0 | **Dependencies:** rsg-core, rsg-target, rsg-inventory, oxmysql (no ox_lib) - Passive points per minute, awarded entirely on the server (anti-AFK movement check, session cap

Source: https://github.com/Rexshack-RedM/rsg-loyalty

**Dependencies:** `rsg-core`, `rsg-target`, `rsg-inventory`, `oxmysql`

Has NUI (`ui_page`).

## Exports (call as exports['rsg-loyalty']:Name)

**server:** `addLoyaltyPoints(citizenid, points)`, `awardActivity(src, activity)`, `getLifetimeLoyaltyPoints(citizenid)`, `getLoyaltyPoints(citizenid)`, `getLoyaltyTier(citizenid)`, `removeLoyaltyPoints(citizenid, points)`, `setLoyaltyBoost(multiplier, minutes)`

## Net events registered

**server:** `rsg-loyalty:server:adminAwardPoints`, `rsg-loyalty:server:getHistory`, `rsg-loyalty:server:getLeaderboard`, `rsg-loyalty:server:getStore`, `rsg-loyalty:server:playerLoaded`, `rsg-loyalty:server:redeem`

**client:** `RSGCore:Client:OnPlayerLoaded`, `RSGCore:Client:OnPlayerUnload`, `rsg-loyalty:client:historyData`, `rsg-loyalty:client:leaderboardData`, `rsg-loyalty:client:openloyaltyUI`, `rsg-loyalty:client:storeState`, `rsg-loyalty:client:updateLoyaltyData`

## Event handlers

**server:** `RSGCore:Server:OnPlayerUnload`

## Commands (RegisterCommand)

**server:** `/awardloyalty`, `/checkloyalty`, `/loyaltyboost`, `/postleaderboard`, `/removeloyalty`

## Database tables

`rsg_loyalty`, `rsg_loyalty_history`, `rsg_loyalty_redemptions`
