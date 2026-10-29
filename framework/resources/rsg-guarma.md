# rsg-guarma

Version 3.0.0. rsg-guarma

Boat travel between **Saint Denis** and **Guarma** for the RSG Framework (RedM). Players buy boat tickets from a port worker, then sail to the other port. The script swaps the world horizon, water and minimap automatically when you enter or leave Guarma, including when you log in there or an admin teleports you. - Port worker NPCs (ox_target) at both ports, which fade in and out with distance

Source: https://github.com/Rexshack-RedM/rsg-guarma

**Dependencies:** `rsg-core`, `rsg-inventory`, `ox_lib`, `ox_target`

Has NUI (`ui_page`).

## Net events registered

**server:** `rsg-guarma:server:requestTravel`

**client:** `rsg-guarma:client:performTravel`

## Event handlers

**client:** `rsg-guarma:client:guarmaChanged`

## Callbacks (lib.callback)

**server:** `rsg-guarma:server:buyTicket`
