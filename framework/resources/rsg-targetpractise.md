# rsg-targetpractise

Version 3.0.0. Placeable archery and throwing-knife practice targets for RSG Framework

Placeable archery and throwing-knife practice targets for **RSG-Core** on RedM. Players place a target from their inventory, shoot it with a bow or throwing knives, and compete on a live session leaderboard. All placement, pickup and scoring is checked on the server. - **Placeable targets:** use the `target` item to place a frame and face anywhere on the ground. You get a ghost preview you can rot

Source: https://github.com/Rexshack-RedM/rsg-targetpractise

**Dependencies:** `rsg-core`, `rsg-inventory`, `ox_lib`, `ox_target`, `/onesync`

Has NUI (`ui_page`).

## Net events registered

**server:** `rsg-targetpractise:server:cancel`, `rsg-targetpractise:server:diagnostic`, `rsg-targetpractise:server:hit`, `rsg-targetpractise:server:leaderboard`, `rsg-targetpractise:server:place`, `rsg-targetpractise:server:remove`, `rsg-targetpractise:server:shot`, `rsg-targetpractise:server:sync`

**client:** `RSGCore:Client:OnPlayerLoaded`, `RSGCore:Client:OnPlayerUnload`, `rsg-targetpractise:client:debug`, `rsg-targetpractise:client:diagnosticServer`, `rsg-targetpractise:client:leaderboard`, `rsg-targetpractise:client:openLeaderboard`, `rsg-targetpractise:client:place`, `rsg-targetpractise:client:scoreRejected`, `rsg-targetpractise:client:scored`, `rsg-targetpractise:client:sync`

## Commands (RSGCore.Commands.Add)

**server:** `/admintarget`, `/targetdebug`, `/targetscore`

## Commands (RegisterCommand)

**client:** `/targetboard`, `/targetdiag`, `/targetremove`

## Public (table) functions

**client/diagnostics.lua:** `D.count(key)`, `D.tick(stage)`, `D.recordError(name, message)`, `D.report()`, `D.show()`

**client/projectiles.lua:** `P.release(previousWeapon, previousAmmo, weapon, ammo, previousAmmoNow, shooting, wasShooting, allowed)`, `P.capture(seen, entity, position, origin, speed, attached)`, `P.segment(track, position)`, `P.modelKey(model)`, `P.probeSurface(from, to, impact, ignored, cast, modelOf, models, tolerance)`

**server/leaderboard.lua:** `TargetPractiseLeaderboard.name(charinfo)`, `TargetPractiseLeaderboard.build(totals, online, viewer)`

**shared/geometry.lua:** `G.finite(n)`, `G.point(p)`, `G.add(a, b)`, `G.sub(a, b)`, `G.distance(a, b)`, `G.multiply(a, b)`, `G.inverse(q)`, `G.rotate(q, p)`, `G.yaw(degrees)`, `G.pose(target)`, `G.faceLocal(target, world)`, `G.faceWorld(target, offset)`, `G.score(localPoint)`, `G.hitMode()`, `G.signedHash(value)`, `G.hitInBounds(target, world)`

**shared/locale.lua:** `TargetPractiseLocale.ui()`
