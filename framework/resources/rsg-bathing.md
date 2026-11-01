# rsg-bathing

Version 3.0.0. rsg-bathing

Interactive bathhouse system for RedM servers running the RSG Framework. Players pay for a bath, scrub themselves clean using the original RDR2 bathing animations, and can upgrade to an NPC-assisted deluxe bath. - Bathhouses in Saint Denis, Valentine, Annesburg, Strawberry, Blackwater, Van Horn, Rhodes and Tumbleweed (Tumbleweed uses its own `Pbl_Regular_Outro`) - Tub steam and per-body-part soap 

Source: https://github.com/Rexshack-RedM/rsg-bathing

**Dependencies:** `rsg-core`, `rsg-wardrobe`

## Exports (call as exports['rsg-bathing']:Name)

**client:** `IsBathingActive()`

## Net events registered

**server:** `rsg-bathing:server:canEnterBath`, `rsg-bathing:server:canEnterDeluxeBath`, `rsg-bathing:server:dressPlayer`, `rsg-bathing:server:setBathAsFree`, `rsg-bathing:server:undressPlayer`

**client:** `rsg-bathing:client:HideDeluxePrompt`, `rsg-bathing:client:RestorePrompts`, `rsg-bathing:client:StartBath`, `rsg-bathing:client:StartDeluxeBath`, `rsg-bathing:client:ToggleInvincibility`
