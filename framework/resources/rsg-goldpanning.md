# rsg-goldpanning

Version 3.0.0. Gold panning system for RSG Framework

Gold panning for the RSG Framework (RedM). Stand in a river, use a gold pan, and sift for nuggets. - Use the `tool_goldpan` item while standing in one of the configured rivers/creeks - ox_lib progress bar (cancellable) with scoop and shake animations

Source: https://github.com/Rexshack-RedM/rsg-goldpanning

**Dependencies:** `rsg-core`, `rsg-inventory`, `ox_lib`

## Net events registered

**server:** `rsg-goldpanning:server:cancelPan`, `rsg-goldpanning:server:claimPan`, `rsg-goldpanning:server:startPan`

**client:** `rsg-goldpanning:client:beginPan`, `rsg-goldpanning:client:tryPan`
