# rsg-barbers

Version 3.0.0. rsg-barbers

**Barbershops for RedM (RSG Framework): hair, beard and makeup with a live preview.** - Barber NPCs that spawn and fade in near each shop, with map blips. - Sit in the barber chair with a scripted camera and studio lighting.

Source: https://github.com/Rexshack-RedM/rsg-barbers

**Dependencies:** `rsg-core`, `rsg-character`, `rsg-target`, `oxmysql`

Has NUI (`ui_page`).

## Net events registered

**client:** `rsg-barbers:client:open`

## Event handlers

**client:** `rsg-barber:client:menu`

## Callbacks (RSGCore.Functions.CreateCallback)

**server:** `rsg-barbers:server:purchase`

## Public (table) functions

**shared/functions.lua:** `Barber.GetLocation(barberid)`, `Barber.GetPrice(loc)`, `Barber.ResolveHash(gender, category, model, texture)`, `Barber.FindModel(gender, category, hash)`, `Barber.StoredHash(gender, category, value)`
