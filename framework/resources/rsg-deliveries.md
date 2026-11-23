# rsg-deliveries

Version 3.3.0. Wagon delivery system RSG Framework

A wagon delivery system for RedM using the RSG Framework. Players pick up goods from NPC foremen at various towns and deliver them by wagon to destinations across the map for cash and item rewards. Talking to a foreman opens a NUI contract board listing every destination from that hub. Selecting a route shows its distance, time limit, wagon, difficulty rating, a route-length bar, and the cash and 

Source: https://github.com/Rexshack-RedM/rsg-deliveries

**Dependencies:** `rsg-core`, `rsg-target`, `rsg-inventory`, `oxmysql`

Has NUI (`ui_page`).

## Exports (call as exports['rsg-deliveries']:Name)

**server:** `GetAmbushMultiplier(src)`

## Net events registered

**server:** `rsg-deliveries:server:canceldelivery`, `rsg-deliveries:server:completedelivery`, `rsg-deliveries:server:declinereturn`, `rsg-deliveries:server:faildelivery`, `rsg-deliveries:server:setwagon`

**client:** `rsg-deliveries:client:finished`

## Event handlers

**server:** `rsg-ambush:server:ambushStarted`, `rsg-ambush:server:ambushWon`, `rsg-skills:server:ready`

## Callbacks (RSGCore.Functions.CreateCallback)

**server:** `rsg-deliveries:server:acceptreturn`, `rsg-deliveries:server:getleaderboard`, `rsg-deliveries:server:startdelivery`

## Commands (RegisterCommand)

**client:** `/canceldelivery`

## Public (table) functions

**server/stats.lua:** `Stats.Get(citizenid)`, `Stats.NextStreak(citizenid, now)`, `Stats.Record(citizenid, name, distance, earned, streak, now)`

## Database tables

`rsg_deliveries_stats`
