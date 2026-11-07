# rsg-guarma

Version 3.0.1. Boat travel between Saint Denis and Guarma for the RSG Framework

Boat travel between **Saint Denis** and **Guarma** for the RSG Framework (RedM). Version **3.0.1**. See [DOCS.md](DOCS.md) for architecture, events, security and troubleshooting. Players buy boat tickets from a port worker, then sail to the other port. The script swaps the world horizon, water and minimap automatically when you enter or leave Guarma, including when you log in there or an admin tel

Source: https://github.com/Rexshack-RedM/rsg-guarma

**Dependencies:** `rsg-core`, `rsg-inventory`, `rsg-target`

Has NUI (`ui_page`).

## Net events registered

**server:** `rsg-guarma:server:requestTravel`

**client:** `rsg-guarma:client:performTravel`

## Event handlers

**client:** `rsg-guarma:client:guarmaChanged`

## Callbacks (RSGCore.Functions.CreateCallback)

**server:** `rsg-guarma:server:buyTicket`
