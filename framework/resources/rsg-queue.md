# rsg-queue

Version 3.0.1. rsg-queue - connect queue with VIP priority, reserved slots and crash grace

**Version 3.0.1** · A modern connect queue for RSG Framework RedM servers. Players wait in line on a styled Adaptive Card, and VIP members you manage get priority, reserved slots and tiers. Dependencies: `rsg-core`, `oxmysql` (no ox_lib). Optional: `rsg-log` for logging. Full developer and server owner documentation: [DOCS.md](DOCS.md)

Source: https://github.com/Rexshack-RedM/rsg-queue

**Dependencies:** `rsg-core`, `oxmysql`

Has NUI (`ui_page`).

## Exports (call as exports['rsg-queue']:Name)

**server:** `AddVip(identifier, tier, days, name)`, `GetQueue()`, `GetQueueSize()`, `IsMaintenance()`, `IsVip(identifier)`, `RemoveVip(identifier)`, `SetMaintenance(on)`

## Net events registered

**client:** `rsg-queue:client:openAdmin`

## Event handlers

**server:** `RSGCore:Server:PlayerLoaded`, `playerConnecting`, `playerJoining`

## Callbacks (RSGCore.Functions.CreateCallback)

**server:** `rsg-queue:server:adminAction`, `rsg-queue:server:getAdminData`

## Commands (RSGCore.Commands.Add)

**server:** `/queue`, `/queuemaint`, `/vipadd`, `/vipremove`

## Commands (RegisterCommand)

**server:** `/queuevip`

## Database tables

`rsg_queue_rewards`, `rsg_queue_vip`
