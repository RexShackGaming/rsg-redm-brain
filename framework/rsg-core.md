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
- Notify (rsg-core's own NUI, no ox_lib): `RSGCore.Functions.Notify({ title, description, type, duration, icon, position, id })` or `(title, text, type, duration, icon)` or legacy `(text, type, duration)`. Types: `success`, `error`, `warning`, `inform`/`primary`. Icon = Font Awesome class. Never use `lib.notify` in new code.
- Server notify: `RSGCore.Functions.Notify(src, data|text, type, duration)` or `TriggerClientEvent('RSGCore:Client:Notify', src, {...})`. Never `ox_lib:notify` in new code.
- Helpers: `HasItem`, `GetCoords`, `GetClosestPlayer/Ped/Vehicle/Object(coords)`, `GetPlayersFromCoords`, `SpawnVehicle(model, cb, coords, networked, teleportInto)`, `DeleteVehicle`, `PlayAnim(dict, name, upperOnly, dur)`, `LookAtEntity`, `AttachProp`, `DrawText3D(x,y,z,text)`, `StartParticleAtCoord/OnEntity`, `GetGroundZCoord`, `GetGroundHash`, `GetCardinalDirection`, `GetCurrentTime`, `SpawnClear`.

## Callbacks
**Always use the rsg-core callback system. Do not use `lib.callback` (ox_lib is being phased out).**
```lua
-- server: register
RSGCore.Functions.CreateCallback('res:server:getThing', function(source, cb, arg)
    cb(result)                                   -- answer with cb(...), not return
end)

-- client: async
RSGCore.Functions.TriggerCallback('res:server:getThing', function(result) end, arg)

-- client: await (replaces lib.callback.await). Inside a thread/event handler.
-- AwaitCallback(name, timeout?, ...)  timeout ms, default 10000, false/0 = wait forever; nil on timeout
local result = RSGCore.Functions.AwaitCallback('res:server:getThing', 5000, arg)
```
Server asking a client:
```lua
-- client: register
RSGCore.Functions.CreateClientCallback('res:client:getThing', function(cb, arg) cb(value) end)
-- server: async
RSGCore.Functions.TriggerClientCallback('res:client:getThing', src, function(value) end, arg)
-- server: await. AwaitClientCallback(name, source, timeout?, ...)
local value = RSGCore.Functions.AwaitClientCallback('res:client:getThing', src, 5000, arg)
```
Converting from ox_lib:
| ox_lib | rsg-core |
|---|---|
| `lib.callback.register(name, function(source, ...) return x end)` | `RSGCore.Functions.CreateCallback(name, function(source, cb, ...) cb(x) end)` |
| `lib.callback.await(name, false, ...)` (client) | `RSGCore.Functions.AwaitCallback(name, nil, ...)` |
| `lib.callback(name, false, cb, ...)` (client) | `RSGCore.Functions.TriggerCallback(name, cb, ...)` |
| `lib.callback.await(name, src, ...)` (server) | `RSGCore.Functions.AwaitClientCallback(name, src, nil, ...)` |
| client `lib.callback.register` | `RSGCore.Functions.CreateClientCallback(name, function(cb, ...) end)` |

## Multi-job (built into rsg-core; rsg-multijob is removed)
Job definitions live in the `multijob_jobs` table (manage in-game with `/jobadmin`); players hold several jobs in `player_jobs` (`/myjobs`). Settings: `RSGConfig.MultiJob`.
Server (`RSGCore.Functions.*` or `exports['rsg-core']:*`, `id` = server id or citizenid):
`AddPlayerJob(id, job, grade, bypassMax)` → ok, reason; `RemovePlayerJob(id, job)`; `GetPlayerJobs(id)` → `{ job, salary, jobLabel, gradeLabel, grade, icon }[]`; `HasPlayerJob(id, job)` → held, grade; `CanTakePlayerJob(id, job, bypassMax)`; `GetPlayerJobCount(id)` → count, max; `GetJobDefinition(name)`; `GetJobDefinitions()`.
Note: `AddJob/RemoveJob/UpdateJob` on rsg-core are job *definition* functions, not player jobs. Old `exports['rsg-multijob']:*` calls still work via `provide`, but use the rsg-core names in new code.
Events kept: `rsg-multijob:client:openmenu`, `rsg-multijob:server:jobsLoaded`.

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
- Targeting: `rsg-target` (github.com/Rexshack-RedM/rsg-target) replaces ox_target and `provide`s it, so ox_target must not be installed. New code uses `exports['rsg-target']` and lists `rsg-target` in dependencies; old `exports.ox_target` calls still work.

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
