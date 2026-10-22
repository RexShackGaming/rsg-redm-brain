# RSGCore API (rsg-core 3.0.3)

Built from the server's own resources/[framework]. Prefer these signatures to QBCore habits. If unsure, read the source in [framework]/rsg-core rather than guessing.

> On this server, job definitions live in the DB via rsg-multijob, not `RSGCore.Shared.Jobs`. Item notifications use `rsg-inventory:client:ItemBox` (not the old `inventory:client:ItemBox`), and items go through `exports['rsg-inventory']`, not `Player.Functions.AddItem`.

## Getting the core
```lua
local RSGCore = exports['rsg-core']:GetCoreObject()
```
Shared tables: `RSGCore.Shared.Items`, `.Jobs`, `.Gangs`, `.Vehicles`, `.Weapons`. Config: `RSGCore.Config` (`RSGConfig`).

## Player object (server)
`local Player = RSGCore.Functions.GetPlayer(src)` — always nil-check.
Lookups: `GetPlayerByCitizenId(cid)`, `GetOfflinePlayerByCitizenId(cid)`, `GetPlayerByLicense`, `GetPlayerByAccount`, `GetPlayerByCharInfo(prop, val)`, `GetPlayers()`, `GetRSGPlayers()`, `GetPlayersOnDuty(job)`, `GetDutyCount(job)`, `GetIdentifier(src, 'license')`, `GetSource(identifier)`.

`Player.PlayerData`: `source, citizenid, cid, license, name, money{cash,gold,bank,bloodmoney}, charinfo{firstname,lastname,birthdate,gender,nationality,account}, job{name,label,payment,type,onduty,isboss,grade{name,level}}, gang{...}, metadata{health,hunger,thirst,cleanliness,stress,isdead,armor,ishandcuffed,injail,jailitems,status,rep,callsign,bloodtype,fingerprint,walletid,criminalrecord}, position, items, weight(35000), slots(25)`.

`Player.Functions`:
- Money: `AddMoney(type, amt, reason)`, `RemoveMoney(type, amt, reason)` (returns false if insufficient), `SetMoney`, `GetMoney(type)`. Money types: `cash`, `gold`, `bank`, `bloodmoney`. Amounts must be finite and >= 0.
- Job/gang: `SetJob(name, grade)`, `SetGang(name, grade)`, `SetJobDuty(bool)`.
- Data: `SetPlayerData(key, val)`, `SetMetaData(key, val)`, `GetMetaData(key)`, `UpdatePlayerData()`, `Save()`, `Logout()`.
- Rep: `AddRep(name, amt)`, `RemoveRep`, `GetRep`.
- `HasItem(items, amount)`; extend with `AddMethod`, `AddField` or global `RSGCore.Functions.AddPlayerMethod(ids, name, fn)` / `AddPlayerField`.

### Money gotchas
- `EnableMoneyItems = true`: cash and bloodmoney are inventory items (`dollar`/`cent`, `blood_dollar`/`blood_cent`). Always go through `AddMoney/RemoveMoney`; never add those items directly.
- `bank` is legacy: rsg-banking v3 forwards it to the player's home branch. For new code use rsg-banking exports. Society accounts (`PayCheckSociety`) are NOT supported.
- `DontAllowMinus` covers all four types.

## Client core
- `RSGCore.Functions.GetPlayerData()` (or `(cb)`); refresh on `RSGCore:Client:OnPlayerLoaded` and `RSGCore:Player:SetPlayerData`.
- `RSGCore.Functions.Notify(title, text, type, duration, icon)` wraps `lib.notify`; also accepts a table, or legacy `(text, type, duration)`. Types: `success`, `error`, `inform`/`primary`. Prefer `lib.notify({...})` directly in new code.
- Server notify: `RSGCore.Functions.Notify(src, text, type, duration)` or `TriggerClientEvent('ox_lib:notify', src, {...})`.
- Helpers: `HasItem`, `GetCoords`, `GetClosestPlayer/Ped/Vehicle/Object(coords)`, `GetPlayersFromCoords`, `SpawnVehicle(model, cb, coords, networked, teleportInto)`, `DeleteVehicle`, `PlayAnim(dict, name, upperOnly, dur)`, `LookAtEntity`, `AttachProp`, `DrawText3D(x,y,z,text)`, `StartParticleAtCoord/OnEntity`, `GetGroundZCoord`, `GetGroundHash`, `GetCardinalDirection`, `GetCurrentTime`, `SpawnClear`.

## Callbacks
```lua
-- server
RSGCore.Functions.CreateCallback('res:server:getThing', function(source, cb, arg) cb(result) end)
-- client
RSGCore.Functions.TriggerCallback('res:server:getThing', function(result) end, arg)
```
Also client callbacks: `CreateClientCallback` / server `TriggerClientCallback(name, src, cb, ...)`. `lib.callback` from ox_lib is equally fine.

## Usable items, commands, permissions
```lua
RSGCore.Functions.CreateUseableItem('canteen100', function(source, item)
    local Player = RSGCore.Functions.GetPlayer(source); if not Player then return end
    TriggerClientEvent('res:client:use', source, item)
end)
RSGCore.Commands.Add('name', 'help', {{name='id', help='Player ID'}}, true, function(source, args) end, 'admin')
```
Permission levels: `god, developer, headadmin, admin, mod, helper`, `user` = unrestricted. Check with `RSGCore.Functions.HasPermission(src, 'admin')`.

## Runtime shared-data registration (server exports)
`AddItem/AddItems/UpdateItem/RemoveItem`, `AddJob/AddJobs/UpdateJob/RemoveJob`, `AddGang/...` on `exports['rsg-core']` and `RSGCore.Functions`. Changes sync to clients via `RSGCore:Client:OnSharedUpdate(Multiple)`.
Item shape: `{ name, label, weight, type='item', image='x.png', unique, useable, shouldClose, category, description }`.
Job shape: `{ name, label, type='leo', defaultDuty, offDutyPay, grades = { ['0'] = { name, payment, isboss? } } }` (grade keys are strings).

## Prompts & draw text (client exports on rsg-core)
- `createPrompt(name, coords, key, text, { type='client'|'server', event='...', args={} })`, `deletePrompt(name)`, `createPromptGroup(group, label, coords, prompts)`, `deletePromptGroup`. Trigger distance `RSGConfig.PromptDistance` (1.5). Clean up on `onResourceStop`.
- `DrawText(text, pos)`, `ChangeText`, `HideText`, `KeyPressed`.
- Targeting: `ox_target` is installed; some older scripts reference `rsg-target`.

## Core events
Client: `RSGCore:Client:OnPlayerLoaded`, `RSGCore:Client:OnPlayerUnload`, `RSGCore:Client:OnJobUpdate(job)`, `RSGCore:Client:OnGangUpdate`, `RSGCore:Client:OnMoneyChange`, `RSGCore:Client:SetDuty`, `RSGCore:Player:SetPlayerData(data)`.
Server: `RSGCore:Server:PlayerLoaded(Player)`, `RSGCore:Server:OnPlayerLoaded`, `RSGCore:Server:OnPlayerUnload`, `RSGCore:Server:PlayerDropped`, `RSGCore:Server:OnJobUpdate`, `RSGCore:Server:OnGangUpdate`, `RSGCore:Server:OnMoneyChange`.
Logging: `TriggerEvent('rsg-log:server:CreateLog', 'channel', 'Title', 'color', 'message')`.

## Security rules (enforced by core, follow in new code)
- `RSGCore:Server:SetMetaData` from clients only accepts keys in `RSGConfig.ClientWritableMetadata` (hunger, thirst, cleanliness, stress, health, armor). Set everything else server-side.
- Never trust client-sent amounts, prices, items or coords: compute on the server from config, check distance with `GetEntityCoords(GetPlayerPed(src))`.
- Exploit attempts: `exports['rsg-core']:ExploitBan(src, 'reason')`. Core ships a CSRF token (`GenerateCSRFToken`) for sensitive net events.
- Validate `Player` exists, `CanAddItem` before `AddItem`, `RemoveMoney` return value before granting goods.
- DB: `MySQL.query/insert/update/scalar(.await)` from oxmysql with `?` params. Never concatenate SQL.

## Naming conventions
Events: `<resource>:client:<action>` / `<resource>:server:<action>`. Callbacks: `<resource>:server:<name>`. Config in `Config = {}` in `shared/config.lua`.=================== rsg-redm
