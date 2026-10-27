# VORP Core (reference only)

VORP (github.com/VORPCORE) is the other major RedM framework. **This server runs RSG, not VORP.** Use this folder to:
- port or convert a VORP script to RSG,
- study how VORP solved a feature before building the RSG version,
- write a script that supports both frameworks (bridge).

Never call VORP APIs in an RSG script unless the user explicitly asks for VORP or bridge support. Precedence is unchanged: `server/environment.md` > RSG `source/` > `framework/` > `vorp/`.

| Path | What it holds |
|---|---|
| `vorp/README.md` | This guide: core API summary and the RSG ⇄ VORP conversion map |
| `vorp/docs/` | Official VORP API docs (`core`, `inventory`, `characters`, `lib`, `menu`, `inputs`, `progressbar`, `metabolism`, `animations`, best practices) |
| `vorp/resources/` | **Generated** API reference for ~40 VORP resources (exports, net events, callbacks, usable items, commands, DB tables) |
| `vorp/source/` | Code-only mirror of the VORPCORE Lua repos (from the VORP_txAdmin recipe) |

Refresh with `tools/refresh.sh` (same run as the RSG refresh).

## Core basics
```lua
local Core = exports.vorp_core:GetCore()          -- shared (client and server)

-- server: user -> character
local user = Core.getUser(source)                 -- nil-check
if not user then return end
local character = user.getUsedCharacter
-- getters: identifier, charIdentifier, group, job, jobGrade, jobLabel, money, gold, rol, xp,
--          firstname, lastname, age, gender, nickname, invCapacity, skills, multiJobs, isdead, coords
character.addCurrency(0, 10.0)     -- 0 = money (cash), 1 = gold, 2 = rol
character.removeCurrency(0, 10.0)  -- check character.money first
character.setJob('sheriff', true); character.setJobGrade(1, true); character.setJobLabel('Sheriff')
character.setGroup('admin', false); character.addXp(100)
Core.getUserByCharId(charid)
Core.Player.Heal(src) / Core.Player.Revive(src) / Core.Player.Respawn(src)
Core.RegisterJobs(jobsData, GetCurrentResourceName())   -- server-registered jobs (config/jobs.lua)
```
Client: `LocalPlayer.state.IsInSession`, `LocalPlayer.state.Character.{FirstName,LastName,Job,JobLabel,Grade,Group,Age,Gender,NickName}`.

### Callbacks
```lua
-- server
Core.Callback.Register('res:getThing', function(source, cb, ...) cb(result) end)
-- client
local result = Core.Callback.TriggerAwait('res:getThing', ...)
Core.Callback.TriggerAsync('res:getThing', function(result) end, ...)
```

### Notifications (native RDR style, not ox_lib)
Client `Core.NotifyTip(text, ms)`, `NotifyLeft(title, sub, dict, icon, ms, color)`, `NotifyRightTip`, `NotifyObjective`, `NotifyTop`, `NotifyAvanced`, `NotifyFail`, `NotifyDead`, `NotifyUpdate`, `NotifyWarning`… Server versions take `source` first: `Core.NotifyRightTip(src, text, ms)`. Full list in `docs/core.mdx`.

### Events
- Character selected: server `vorp:SelectedCharacter (source, character)`, client `vorp:SelectedCharacter (charid)`; spawn: client `vorp_core:Client:OnPlayerSpawned`.
- `vorp:playerJobChange (src, new, old)`, `vorp:playerJobGradeChange`, `vorp:playerGroupChange`.
- `vorp_core:Server/Client:OnPlayerDeath | OnPlayerRevive | OnPlayerRespawn | OnPlayerHeal | OnPlayerLevelUp`.

### Inventory (`vorp_inventory`, server)
Most exports take a trailing `callback`; omit it to get the return value synchronously in current versions (check `docs/inventory.mdx`).
```lua
exports.vorp_inventory:canCarryItem(src, 'water', 1)
exports.vorp_inventory:addItem(src, 'water', 1, metadata)
exports.vorp_inventory:subItem(src, 'water', 1, metadata)
exports.vorp_inventory:getItemCount(src, nil, 'water', metadata)
exports.vorp_inventory:registerUsableItem('water', function(data) --[[data.source, data.item]] end, GetCurrentResourceName())
exports.vorp_inventory:registerInventory({ id = 'stash_1', name = 'Stash', limit = 50, ... })
exports.vorp_inventory:openInventory(src, 'stash_1')
exports.vorp_inventory:createWeapon(src, 'WEAPON_REVOLVER_CATTLEMAN', ammo, components)
```
Items live in the `items` DB table (not a shared Lua table).

### UI libs
`vorp_menu` (MenuData, native-style menus), `vorp_inputs` (text input), `vorp_progressbar`, `vorp_lib` (Prompts, Blips, Points, Entities, Commands, DataView… see `docs/lib.mdx`).

## RSG ⇄ VORP conversion map
| Task | RSG (this server) | VORP |
|---|---|---|
| Core object | `exports['rsg-core']:GetCoreObject()` | `exports.vorp_core:GetCore()` |
| Player (server) | `RSGCore.Functions.GetPlayer(src)` | `Core.getUser(src).getUsedCharacter` |
| Character id | `Player.PlayerData.citizenid` | `character.charIdentifier` (number) |
| License / identifier | `Player.PlayerData.license` | `character.identifier` |
| Name | `PlayerData.charinfo.firstname/lastname` | `character.firstname/lastname` |
| Cash | `Player.Functions.AddMoney('cash', n)` / `RemoveMoney` | `character.addCurrency(0, n)` / `removeCurrency(0, n)` |
| Gold | `AddMoney('gold', n)` | `addCurrency(1, n)` |
| Bank | rsg-banking exports | `vorp_banking` (per-town `bank_users`) |
| Job | `PlayerData.job.name`, `.grade.level`, `.onduty` | `character.job`, `character.jobGrade` (no built-in duty) |
| Set job | `Player.Functions.SetJob(name, grade)` (jobs in DB via rsg-multijob) | `character.setJob(name)` + `setJobGrade(g)` |
| Admin check | `RSGCore.Functions.HasPermission(src, 'admin')` | `user.getGroup == 'admin'` / `character.group` |
| Add item | `exports['rsg-inventory']:AddItem(src, item, n, info, slot, reason)` | `exports.vorp_inventory:addItem(src, item, n, metadata)` |
| Remove item | `exports['rsg-inventory']:RemoveItem(...)` | `exports.vorp_inventory:subItem(src, item, n, metadata)` |
| Can carry | `exports['rsg-inventory']:CanAddItem(src, item, n)` | `exports.vorp_inventory:canCarryItem(src, item, n)` |
| Item count | `HasItem` / `GetItemCount` | `getItemCount(src, nil, item)` |
| Usable item | `RSGCore.Functions.CreateUseableItem(name, fn(src, item))` | `exports.vorp_inventory:registerUsableItem(name, fn(data))` |
| Item metadata | `info` | `metadata` |
| Item list | `RSGCore.Shared.Items` | `items` DB table / `getServerItem` |
| Stash | `exports['rsg-inventory']:OpenInventory(src, id, data)` | `registerInventory` + `openInventory(src, id)` |
| Callback | `RSGCore.Functions.CreateCallback` / `lib.callback` | `Core.Callback.Register` / `TriggerAwait` |
| Notify | `lib.notify` (house rule) | `Core.NotifyRightTip` etc. → convert to `lib.notify` |
| Player loaded (client) | `RSGCore:Client:OnPlayerLoaded` | `vorp:SelectedCharacter` / `vorp_core:Client:OnPlayerSpawned` |
| Player data (client) | `RSGCore.Functions.GetPlayerData()` | `LocalPlayer.state.Character` |
| Job change | `RSGCore:Client:OnJobUpdate` | `vorp:playerJobChange` (server) |
| Menus | ox_lib context / NUI house style | `vorp_menu` MenuData → convert to ox_lib or NUI |
| Input | `lib.inputDialog` | `vorp_inputs` |
| Progress | `lib.progressBar` / `progressCircle` | `vorp_progressbar` |
| Commands | `RSGCore.Commands.Add` / `lib.addCommand` | `RegisterCommand` + group check |
| Revive/heal | rsg-medic events | `Core.Player.Revive(src)` / `Heal(src)` |

### Porting checklist (VORP → RSG)
1. Replace every row above; drop VORP notification calls for `lib.notify` + locales.
2. Rewrite `vorp_menu` / `vorp_inputs` UIs as ox_lib or NUI in the house style (`ui/design-standard.md`).
3. Item names must match `server/environment.md`; VORP item rows from SQL become `rsg-core/shared/items.lua` entries.
4. Re-check every server event against `conventions/security.md` (many VORP scripts trust the client).
5. Audit with `audit/audit-checklist.md`.
