# rsg-samples

Version 2.1.0. rsg-samples

Animal sample collector for RedM (best version) with leaderboard, certificate, and milestone rewards. - Sedate wild animals and hold a prompt to collect their sample - 75 animal species across 6 categories (Predator, Bird, Reptile, Ungulate, Small Game, Exotic)

Source: https://github.com/Rexshack-RedM/rsg-samples

**Dependencies:** `/onesync`, `oxmysql`, `ox_lib`, `ox_target`, `rsg-core`

Has NUI (`ui_page`).

## Net events registered

**server:** `rsg-samples:server:requestMenu`, `rsg-samples:server:sampleAnimal`

**client:** `rsg-samples:client:openSamplesMenu`

## Event handlers

**client:** `rsg-samples:ReviveData`

## Commands (RSGCore.Commands.Add)

**server:** `/samplecert`, `/samplesmenu`, `/setfeatured`

## Database tables

`player_samples`
