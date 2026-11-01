# rsg-cinema

Version 3.0.1. rsg-cinema - moving picture shows rebuilt from RDR2 show_movie_magic_lantern

Moving picture shows for the RSG Framework. Films are projected through each cinema's own projector light, exactly as in single player. - **Ticket seller** NPC (rsg-target) with NUI: next film, live countdown and price. The panel refreshes itself while open and closes if you walk away. Sellers only spawn when a player is nearby.

Source: https://github.com/Rexshack-RedM/rsg-cinema

**Dependencies:** `rsg-core`, `rsg-target`

Has NUI (`ui_page`).

## Net events registered

**server:** `rsg-cinema:server:adminSetDraw`, `rsg-cinema:server:filmEnded`, `rsg-cinema:server:sync`

**client:** `RSGCore:Client:OnPlayerLoaded`, `rsg-cinema:client:openAdmin`, `rsg-cinema:client:setDraw`, `rsg-cinema:client:startFilm`, `rsg-cinema:client:stopFilm`

## Callbacks (RSGCore.Functions.CreateCallback)

**server:** `rsg-cinema:server:adminAction`, `rsg-cinema:server:adminData`, `rsg-cinema:server:buyTicket`, `rsg-cinema:server:getDraws`, `rsg-cinema:server:getInfo`
