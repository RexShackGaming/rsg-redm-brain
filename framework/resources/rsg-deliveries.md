# rsg-deliveries

Version 3.0.0. Wagon delivery system RSG Framework

A wagon delivery system for RedM using the RSG Framework. Players pick up goods from NPC foremen at various towns and deliver them by wagon to destinations across the map for cash and item rewards. Talking to a foreman opens a NUI contract board listing every destination from that hub. Selecting a route shows its distance, time limit, wagon, difficulty rating, a route-length bar, and the cash and 

Source: https://github.com/Rexshack-RedM/rsg-deliveries

**Dependencies:** `rsg-core`, `ox_lib`, `ox_target`, `rsg-inventory`

Has NUI (`ui_page`).

## Net events registered

**server:** `rsg-deliveries:server:canceldelivery`, `rsg-deliveries:server:completedelivery`, `rsg-deliveries:server:faildelivery`, `rsg-deliveries:server:setwagon`

## Callbacks (lib.callback)

**server:** `rsg-deliveries:server:startdelivery`

## Commands (RegisterCommand)

**client:** `/canceldelivery`
