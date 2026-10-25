# rsg-doorlock

Version 3.1.0. rsg-doorlock

A database-driven door lock system for **RedM** using the **RSG Framework**. Doors are created, edited and deleted in game through an admin editor, synced to every player in real time, and logged to Discord. - 🔒 Lock and unlock doors with a hold prompt and a key animation - 🗄️ All doors are stored in the database (`rsg_doorlocks`), with no config editing needed

Source: https://github.com/Rexshack-RedM/rsg-doorlock

**Dependencies:** `rsg-core`, `ox_lib`, `oxmysql`

Has NUI (`ui_page`).

## Net events registered

**server:** `rsg-doorlock:server:admin:teleported`, `rsg-doorlock:server:requestToggle`

**client:** `rsg-doorlock:client:openEditor`, `rsg-doorlock:client:playKeyAnim`, `rsg-doorlock:client:setState`, `rsg-doorlock:client:syncAll`, `rsg-doorlock:client:syncDoor`

## Event handlers

**client:** `rsg-doorlock:client:editorRefresh`

## Callbacks (lib.callback)

**server:** `rsg-doorlock:server:admin:check`, `rsg-doorlock:server:admin:delete`, `rsg-doorlock:server:admin:save`, `rsg-doorlock:server:getDoors`

## Public (table) functions

**server/webhooks.lua:** `Webhook.PlayerField(src)`, `Webhook.DoorField(door, id)`, `Webhook.Send(logType, data)`, `Webhook.DoorUsed(src, door, locked)`, `Webhook.Denied(src, door, reason, distance)`, `Webhook.Security(src, what, detail)`, `Webhook.AdminSaved(src, door, old)`, `Webhook.AdminDeleted(src, door)`, `Webhook.AdminTeleport(src, door)`, `Webhook.System(title, description)`

## Database tables

`rsg_doorlocks`
