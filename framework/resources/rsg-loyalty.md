# rsg-loyalty

Version 3.0.0. Loyalty script for RSG Framework

A comprehensive loyalty points system for RedM/RSG Framework servers. Players earn loyalty points through gameplay and redeem them for cash or items at NPC loyalty store locations. - **Automatic Point Earning**: Players earn points passively (configurable per-minute rate) after minimum playtime - **Session Caps & Cooldowns**: Prevents farming with per-session limits and earn cooldowns

Source: https://github.com/Rexshack-RedM/rsg-loyalty

**Dependencies:** `rsg-core`, `ox_lib`, `ox_target`, `rsg-inventory`, `oxmysql`

Has NUI (`ui_page`).

## Exports (call as exports['rsg-loyalty']:Name)

**server:** `addLoyaltyPoints(citizenid, points)`, `getLifetimeLoyaltyPoints(citizenid)`, `getLoyaltyPoints(citizenid)`, `removeLoyaltyPoints(citizenid, points)`

## Net events registered

**server:** `rsg-loyalty:server:adminAwardPoints`, `rsg-loyalty:server:earnPoints`, `rsg-loyalty:server:getLeaderboard`, `rsg-loyalty:server:getLoyaltyData`, `rsg-loyalty:server:playerLoaded`, `rsg-loyalty:server:redeem`

**client:** `RSGCore:Client:OnPlayerLoaded`, `RSGCore:Client:OnPlayerUnload`, `rsg-loyalty:client:leaderboardData`, `rsg-loyalty:client:openloyaltyUI`, `rsg-loyalty:client:updateLoyaltyData`

## Event handlers

**server:** `RSGCore:Server:OnPlayerUnload`

## Commands (RegisterCommand)

**server:** `/awardloyalty`, `/checkloyalty`, `/postleaderboard`, `/removeloyalty`

## Database tables

`rsg_loyalty`
