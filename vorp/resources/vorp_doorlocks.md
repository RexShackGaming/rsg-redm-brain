# vorp_doorlocks

Version 0.5. Door System for RedM vorp core

Door locks for your server to control any doors based on jobs, with alert probability and lock pick systems - Place `vorp_doorlocks` into your `resources` folder - Add `ensure vorp_doorlocks` to your `server.cfg` / `resources.cfg` file

Source: https://github.com/VORPCORE/vorp_doorlocks

## Exports (call as exports['vorp_doorlocks']:Name)

**server:** `updateDoorPermission(source, door, allow)`

**client:** `getDoorIdByDistance(dist)`, `getDoorIdByDoorCoords(x, y, z)`, `getDoorIdByName(name)`, `getDoorState(door)`, `setDoorState(door, state)`

## Net events registered

**server:** `vorp_doorlocks:Server:AlertPolice`, `vorp_doorlocks:Server:UpdateDoorState`

**client:** `vorp_doorlocks:Client:Sync`, `vorp_doorlocks:Client:UpdateDoorState`, `vorp_doorlocks:Client:UpdatePerms`

## Event handlers

**server:** `vorp:SelectedCharacter`, `vorp:playerJobChange`

## Callbacks (VORP Core.Callback.Register)

**server:** `vorp_doorlocks:Server:CheckDoorState`

**client:** `vorp_doorlocks:Client:lockpickdoor`
