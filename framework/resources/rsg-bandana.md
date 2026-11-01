# rsg-bandana

Version 3.0.3. rsg-bandana - raise / lower your bandana (male & female)

Raise and lower your bandana on RSG Framework (RedM). Works for male and female characters, on foot or mounted, using the same wearable-state system as RDR2 story mode. - `/bandana` pulls the bandana over your face or drops it back round your neck - RDR2 hand-to-face animation (right hand on foot, left hand when mounted)

Source: https://github.com/Rexshack-RedM/rsg-bandana

**Dependencies:** `rsg-core`

## Exports (call as exports['rsg-bandana']:Name)

**client:** `IsWearingBandana()`

## Net events registered

**client:** `RSGCore:Client:OnPlayerLoaded`, `RSGCore:Client:OnPlayerUnload`, `rsg-bandana:client:toggle`
