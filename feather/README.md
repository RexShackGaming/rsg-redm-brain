# Feather Framework (reference only)

Feather (github.com/FeatherFramework) is an up-and-coming RedM framework, under heavy active development (most repos updated weekly in late 2026). **This server runs RSG, not Feather.** Use this folder to:
- port or convert a Feather script to RSG,
- study how Feather solved a feature before building the RSG version,
- write a script that supports several frameworks (bridge).

Never call Feather APIs in an RSG script unless the user explicitly asks for Feather or bridge support. Precedence is unchanged: `server/environment.md` > RSG `source/` > `framework/` > `vorp/` / `feather/`.

Because Feather changes fast, **always check `feather/docs/` and `feather/source/` for the current signature** before relying on anything below. `feather/source/LAST_REFRESH.txt` shows when the mirror was pulled.

| Path | What it holds |
|---|---|
| `feather/README.md` | This guide: architecture, core API summary, RSG ⇄ Feather conversion map |
| `feather/docs/` | Official docs (from `feather-website`): `api/resources/*.md` (Core, Character, Notify, HUD, Menu v1/v2, Admin, World, Routing, PVP, Settings, Versioner), `api/Inventory.md`, `api/toolkit/` (blips, prompts, entities, keys), `guide.md`, `roadmap.md` |
| `feather/resources/` | **Generated** API reference for ~33 Feather resources (exports, net events, callbacks, usable items, commands, DB tables) |
| `feather/source/` | Code-only mirror of the FeatherFramework Lua repos (each repo's README is the best per-resource contract doc) |

Refresh with `tools/refresh.sh` / `refresh.ps1` (same run as the RSG and VORP refresh).

## How Feather is different (read this first)
Feather is **contract-based and service-oriented**, very unlike RSGCore/VORP:
- **No core object.** The old `FeatherCore = exports['feather-core']:initiate()` is no longer the public contract. Resources call **named exports** directly.
- **Result envelopes everywhere.** Nearly every export returns `{ ok = true, value = ..., meta = ... }` or `{ ok = false, code = 'stable_code', message = '...', details = ... }`. Always check `result.ok == true`.
- **Readiness:** every service has `GetCapabilities()`, `GetHealth()`, `AwaitReady(timeoutMs)`. Await before use.
- **Split ownership.** Core only owns accounts, sessions, RPC, locale, policy/guards, providers, events and notification dispatch. Money is `feather-economy`, jobs `feather-jobs`, items `feather-inventory`, horses/wagons/boats `feather-assets`, houses `feather-property`, licences `feather-licenses`, legal records `feather-justice`, bills `feather-contracts`, groups `feather-organizations`.
- **Access groups.** Services check the *calling resource name* against `Config.Access` groups (e.g. `trustedTransactors`) in that service's config. A new resource must be added there or calls fail with `authorization_denied`.
- **Idempotency.** Mutations take a `requestId` / `idempotencyKey` plus a namespaced `reasonCode` (`shop.purchase`). Retrying the same key replays the result (`replayed = true`); a changed payload gives `idempotency_conflict`. Retry timeouts with the same key.
- **Character IDs, not sources**, for services: get `characterId` from the Core session, then pass it on.
- Uses oxmysql in Core (also ships its own `feather-mysql`); install via `feather-recipe` (txAdmin).

## Core basics (server)
```lua
local ready = exports['feather-core']:AwaitReady(10000)
if not ready.ok then error(ready.message) end

local s = exports['feather-core']:RequireSession(source)   -- fails if no active character
if not s.ok then return end
local characterId = s.value.characterId
-- session fields: sessionId, source, accountId, characterId, generation, state ('ready'), activatedAt
exports['feather-core']:GetPrimaryIdentifier(source)
exports['feather-core']:IsSessionCurrent(source, sessionId, characterId)   -- re-check after async work
```
Session events: `core.session.ready.v1` (character loaded, payload = session snapshot) and `core.session.left.v1`. Also via `exports['feather-core']:SubscribeEvent(name, cb)`.

### RPC (callbacks)
```lua
-- server
exports['feather-core']:RegisterRPC('myres:getThing', function(params, res, src) ... end)
-- client
local r = exports['feather-core']:CallRPCAsync('myres:getThing', { id = 1 })
exports['feather-core']:CallRPC('myres:getThing', params, function(result) end)
exports['feather-core']:NotifyRPC('myres:event', payload, target)   -- fire-and-forget
```
Check the exact handler signature in `feather/docs/api/resources/Core.md` and `feather/source/feather-core/`.

### Notifications
```lua
-- server (dispatched via provider, feather-notify by default)
exports['feather-core']:SendNotification({ source = src, style = 'right', message = 'Saved.', duration = 3000 })
-- client (feather-notify is optional; guard the call)
exports['feather-notify']:ShowNotification({ style = 'right', message = 'Saved.', duration = 3000 })
```

### Locale
`exports['feather-core']:RegisterLocale(locale, translations)`, `TranslateLocale(source, key, ...)`, client `SetClientLocale(locale)`.

### Money (`feather-economy`, server)
Double-entry ledger with wallets per currency (`dollars`, etc.). No `AddMoney`/`RemoveMoney`: you **transfer between accounts**.
```lua
local w = exports['feather-economy']:EnsureCharacterWallets({ characterId = characterId })
local paid = exports['feather-economy']:Transfer({
  fromAccountId = buyerWalletId, toAccountId = shopAccountId,
  currency = 'dollars', amount = 2500,          -- integer minor units (cents)
  reasonCode = 'shop.purchase', referenceType = 'shop_order', referenceId = orderId,
  idempotencyKey = requestId
}, { actorCharacterId = characterId, actorSource = source })
```
Reads: `GetAccount`, `FindAccountsByOwner({ ownerType, ownerId })`, `GetSystemAccount`. Creating money: `Issue` / `Destroy` (needs `trustedSuppliers` + policy grant). See `feather/source/feather-economy/README.md`.

### Inventory (`feather-inventory`, server)
```lua
local Inventory = exports['feather-inventory'].initiate()      -- API table (contract 2)
exports['feather-inventory']:GetCharacterInventory(characterUuid)
exports['feather-inventory']:GrantCharacterItem(characterUuid, 'consumable_coffee', 1, 'reason')
exports['feather-inventory']:RemoveCharacterInventoryInstance(characterUuid, instanceId, 'reason')
Inventory.Items.RegisterUsableItem('consumable_coffee', function(item, source) end)       -- does NOT consume
Inventory.Items.RegisterUsableAction('consumable_coffee', { consume = true, quantity = 1 },
  function(item, source, committed) end)                                                  -- atomic consume
```
Items are **instances** (each row has an `instanceId`, condition and metadata); capacity checks, transactions, custom containers and access control are in `feather/docs/api/Inventory.md`.

### Jobs (`feather-jobs`, server)
Jobs are definitions + grades + **assignments** (multiple per character, one active, with duty state).
```lua
local Jobs = exports['feather-jobs']
Jobs:CheckAssignment({ characterId = cid, jobKey = 'sheriff', minGradeOrdinal = 1, dutyState = 'on', activeOnly = true })
--> value.matched
Jobs:GetEffectiveJobSnapshot({ characterId = cid })
Jobs:CreateAssignment({ requestId = ..., characterId = cid, jobKey = 'blacksmith', gradeKey = 'apprentice',
  provenanceType = 'society_membership', provenanceId = id, reasonCode = 'society.hire', actorSource = source })
Jobs:SetDutyState({ assignmentId = id, expectedRevision = rev, dutyState = 'on' })
```
Writes use optimistic locking (`expectedRevision`; `revision_conflict` on mismatch).

### Other resources
| Resource | Purpose |
|---|---|
| `feather-character` | Character select/create, spawn, appearance, death state; `TeleportToCoords`, `RegisterLogoutCheckpoint` |
| `feather-menu` / `feather-menu-v2` | Menu API (NUI) |
| `feather-progressbar` | Progress bar API |
| `feather-toolkit` | Client helpers: blips, prompts, models/entities, keys, text rendering (`docs/api/toolkit/`) |
| `feather-hud`, `feather-chat`, `feather-loadscreen` | UI |
| `feather-admin` | Admin menu |
| `feather-weapons`, `feather-medical`, `feather-pvp`, `feather-doors`, `feather-shops`, `feather-weather`, `feather-world`, `feather-routing` (instances) | Gameplay services |
| `feather-assets`, `feather-property`, `feather-licenses`, `feather-justice`, `feather-contracts`, `feather-organizations`, `feather-access`, `feather-authority`, `feather-audit`, `feather-settings`, `feather-versioner` | Registries, policy, audit and settings |

## RSG ⇄ Feather conversion map
| RSG (this server) | Feather |
|---|---|
| `local RSGCore = exports['rsg-core']:GetCoreObject()` | No core object; named exports on each service, `AwaitReady` first |
| `RSGCore.Functions.GetPlayer(src)` | `exports['feather-core']:RequireSession(src)` → `value.characterId` |
| `Player.PlayerData.citizenid` | `session.characterId` (+ `accountId`) |
| `RSGCore:Server:OnPlayerLoaded` / `RSGCore:Client:OnPlayerLoaded` | `core.session.ready.v1` |
| `RSGCore:Server:OnPlayerUnload` / `playerDropped` | `core.session.left.v1` |
| `RSGCore.Functions.CreateCallback` / `TriggerCallback` (or `lib.callback`) | `RegisterRPC` / `CallRPCAsync` |
| `RSGCore.Functions.Notify(src, msg, type)` | `exports['feather-core']:SendNotification({ source, style, message, duration })` |
| `Player.Functions.AddMoney('cash', n)` / `RemoveMoney` | `feather-economy` `Transfer` between wallet/system accounts, integer cents, idempotency key |
| `Player.Functions.GetMoney('cash')` | `GetAccount({ accountId })` on the character wallet |
| `exports['rsg-inventory']:AddItem(src, item, n, nil, info)` | `GrantCharacterItem(characterUuid, item, n, reason)` |
| `exports['rsg-inventory']:RemoveItem(src, item, n)` | `RemoveCharacterInventoryInstance(characterUuid, instanceId, reason)` (instance-based) |
| `RSGCore.Functions.CreateUseableItem(name, fn)` | `Inventory.Items.RegisterUsableItem` / `RegisterUsableAction` (atomic consume) |
| `Player.PlayerData.job.name / grade.level / onduty` | `feather-jobs` `CheckAssignment` / `GetEffectiveJobSnapshot` (assignments, `ordinal`, `dutyState`) |
| rsg-core multi-job (DB jobs) | Assignments: several per character, one active |
| `Player.Functions.SetJob` | `CreateAssignment` + `SetActiveAssignment` (or `ChangeAssignmentGrade`) |
| `RSGCore.Functions.HasPermission(src, 'admin')` | `exports['feather-core']:Authorize(action, request)` (policy provider) |
| `locales/*.json` + `locale()` | `RegisterLocale` / `TranslateLocale` |
| rsg-target | No built-in target; Feather uses prompts (`feather-toolkit`) |

## Porting checklist (Feather → RSG)
1. Replace every `result.ok`/`result.value` unwrap with direct RSG returns (RSG functions return values, not envelopes).
2. Map `characterId` back to `Player.PlayerData.citizenid` / `source`.
3. Money: replace `Transfer` with `RemoveMoney` on the buyer (check balance first) and, if needed, `AddMoney`/society banking (`framework/rsg-banking`). Convert cents → dollars.
4. Items: instance IDs become slot/name-based rsg-inventory calls; map item names to this server's names (`server/environment.md`).
5. Jobs: assignment checks become `PlayerData.job` checks; register jobs in the DB (rsg-core multi-job).
6. Drop access-group config, idempotency keys and revision checks, but **keep server-side validation** (`conventions/security.md`).
7. Notifications → `RSGCore.Functions.Notify`; text → locales; prompts → rsg-target where the RSG pattern uses it; menus/progress bars → rsg-core/NUI house style.
8. Run `audit/audit-checklist.md`.
