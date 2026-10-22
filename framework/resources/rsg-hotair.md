# rsg-hotair

Version 2.0.1. rsg-hotair

Hireable hot air balloons for RedM servers running the **RSG-Core** framework. Players hire a balloon at a dock, pilot it (or ride along as a passenger), and store it again when they're done. Includes its own weight-limited storage stash per balloon, full ox_target integration, an ox_lib-driven multi-language NUI, and a live on-screen flight control HUD. - **Hire / store flow** — players hire a ba

Source: https://github.com/Rexshack-RedM/rsg-hotair

**Dependencies:** `rsg-core`, `ox_lib`, `ox_target`, `rsg-inventory`

Has NUI (`ui_page`).

## Net events registered

**server:** `rsg-hotair:server:cancelHire`, `rsg-hotair:server:disembarkAll`, `rsg-hotair:server:registerBalloon`, `rsg-hotair:server:storedBalloon`, `rsg-hotair:server:vacateSeat`

**client:** `rsg-hotair:client:forceDisembark`, `rsg-hotair:client:seatUpdate`

## Callbacks (RSGCore.Functions.CreateCallback)

**server:** `rsg-hotair:server:hireBalloon`, `rsg-hotair:server:openStorage`, `rsg-hotair:server:requestSeat`

## Commands (RegisterCommand)

**client:** `/hotair`
