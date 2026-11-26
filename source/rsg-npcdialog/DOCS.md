# rsg-npcdialog 3.1.1 — Documentation

## Contents
1. Architecture
2. Dialog format
3. Exports
4. Events and callbacks
5. Actions and custom conditions
6. Saving
7. Security model
8. Database schema
9. Server owner how-tos
10. Troubleshooting
11. Quests
12. Time, weather and schedules
13. Quest markers, pins and GPS
14. Configuration reference
15. Commands, keys and the editor
16. Integration examples

## 1. Architecture
| File | Purpose |
|---|---|
| `shared/config.lua` | Settings and named actions |
| `shared/npcs.lua` | File-defined NPCs |
| `server/world.lua` | In-game clock, weather, daily and weekly periods |
| `server/validate.lua` | Cleans and checks every NPC definition |
| `server/database.lua` | Tables, editor NPCs and quests, progress caches |
| `server/engine.lua` | Requirements, costs, rewards |
| `shared/quests.lua` | File-defined quests |
| `server/quests.lua` | Quest registry, progress, rewards, kill checks |
| `client/quests.lua` | Journal, tracker, pins, GPS route, objective blips, kill watching |
| `server/main.lua` | NPC registry, schedules, conversation sessions, quest markers, exports |
| `server/admin.lua` | Editor command, save and delete |
| `server/versionchecker.lua` | Optional version check (`Config.VersionCheck`) |
| `client/main.lua` | Peds, blips, markers, targeting |
| `client/dialog.lua` | Camera, conversation UI, NUI focus |
| `client/admin.lua` | Editor bridge and rsg-gizmo placement |
| `html/` | Conversation, journal, tracker, editor and preview UI |

NPCs come from three sources: `config` (files), `export` (other resources) and `db` (editor). IDs are unique across all three. Clients only receive an NPC's ID, name, model, current position, scenario, blip and talk distance. Dialog lines are sent one at a time.

**Load order matters** (see `fxmanifest.lua`): `world`, `validate`, `database`, `engine`, `quests`, `main`, `admin`. The server files share the globals `World`, `Validate`, `DB`, `Engine`, `Quests` and `NPCs`; they are not exports.

**Conversation flow**
1. The target option calls the `open` callback with the NPC ID.
2. The server checks distance, dead or cuffed state, the NPC's `requires`, picks the opening line, stores a session and returns only that line and the replies this player may see.
3. A reply sends the session number and reply position to `choose`. The server re-checks everything, applies cost and reward, saves flags and records, updates quests, and returns the next line or closes.
4. Any `action` runs last, after NUI focus has been released.

**Server timers:** quest tick every `Config.Quests.TickMs` (only players with active quests), schedule check every `Config.ScheduleCheckMs`, marker refresh every `Config.Markers.RefreshMs`.

**Client timers:** NPC spawn check every 0.5 to 1 s, tracker visibility every 0.5 s, kill watch every 0.8 s while a kill objective is open (2 s otherwise), conversation safety check every 0.2 s while talking, and a per-frame control block only while a UI is open.

## 2. Dialog format
Text starting with `@` is a locale key from `locales/*.json`. Anything else is shown as written. IDs, node names, flags and condition names use letters, numbers, `_` and `-` (max 50).

### Complete example
```lua
{
    id = 'val_blacksmith', name = 'Amos', title = 'Blacksmith',
    model = 'u_m_m_valgenstoreowner_01',
    coords = vector4(0.0, 0.0, 0.0, 180.0),      -- replace with real coords
    scenario = 'WORLD_HUMAN_SMOKE', distance = 2.5,
    blip = { enabled = true, sprite = 'blip_ambient_npc' },
    start = 'hello',
    starts = { { node = 'welcome_back', requires = { flags = { 'met_amos' } } } },
    nodes = {
        hello = { text = 'Not seen you before.', choices = {
            { id = 'intro', label = 'Just passing.', next = 'welcome_back', setFlags = { 'met_amos' } },
            { id = 'bye', label = 'Goodbye.' },
        } },
        welcome_back = { text = 'What do you need?', choices = {
            { id = 'gift', label = 'Anything spare?', once = true,
              reward = { items = { { name = 'bread', amount = 1 } } } },
            { id = 'buy', label = 'Sell me water. ($1)', repeatable = true,
              cost = { money = { { type = 'cash', amount = 1 } } },
              reward = { items = { { name = 'water', amount = 1 } } } },
            { id = 'tip', label = 'Heard any news?', cooldown = 600, lock = 'show',
              requires = { time = { from = 18, to = 23 } } },
            { id = 'bye', label = 'Nothing, thanks.' },
        } },
    },
}
```
Put it in `Config.NPCs` or pass it to `RegisterNPC`. The editor stores the same shape as JSON.

### Limits
Text lengths are in bytes, so accented and non-Latin text fits fewer characters.

| What | Limit |
|---|---|
| NPC / quest name, title | 100 |
| Line text | 2000 |
| Reply label | 300 |
| Quest description | 1000 |
| Objective label | 200 |
| Custom condition `arg` | 100 |
| Cooldown | 1 to 31536000 seconds |
| Money, item, XP, reputation values | `Config.Limits` |
| Editor save | 200000 bytes |

### NPC
| Field | Required | Notes |
|---|---|---|
| `id`, `name`, `model`, `coords`, `start`, `nodes` | yes | `coords` is `vector4(x, y, z, heading)` using a character's standing position (the ped spawns 1.0 lower) |
| `title` | no | Subtitle under the name |
| `scenario` | no | e.g. `WORLD_HUMAN_SMOKE` |
| `distance` | no | Talk distance, 1.0 to 10.0 |
| `enabled` | no | `false` hides the NPC |
| `blip` | no | `{ enabled = true, sprite = 'blip_ambient_npc' }` |
| `schedule` | no | Up to 8 time slots, see section 12 |
| `requires` | no | Needed to talk at all |
| `starts` | no | `{ { node = 'x', requires = {...} } }`, first match replaces `start` |

Up to 100 nodes. Each node is `{ text = '...', choices = {...} }` with up to 9 choices. Other lists hold up to 30 entries.

### Choice
| Field | Notes |
|---|---|
| `label` | Required |
| `id` | Required with `once` or `cooldown`. Keep it stable: saved progress uses `npc:node:id` |
| `next` | Next node. Leave out to end the conversation |
| `requires` | See below |
| `lock` | `'hide'` (default) or `'show'` (greyed out with the reason) |
| `once` | Disappears after use, per character |
| `cooldown` | Seconds, per character, survives restarts |
| `repeatable` | Allows a reward with no `once` or `cooldown` |
| `cost` | `{ money = { { type, amount } }, items = { { name, amount } } }` |
| `reward` | `money`, `items`, `skillXP = { { skill, amount } }`, `honor = n`, `standing = { { region, amount } }` |
| `setFlags`, `clearFlags` | Lists of flag names (clear runs before set) |
| `action` | Name from `Config.Actions` or `RegisterAction` |
| `startQuest` | Quest ID. The reply is only available when the quest can be taken |
| `turnInQuest` | Quest ID. The reply is only available when the quest is ready. Can't be combined with `startQuest`; its own reward needs no `once` or `cooldown` |

Money types: `cash`, `bank`, `gold`, `bloodmoney`. `bank` is the legacy rsg-core account type.

### Requirements (all must pass)
```lua
requires = {
    job = { vallaw = 2 },              -- current job : minimum grade (any one listed)
    anyJob = { doctor = 0 },           -- any held job : minimum grade (any one listed)
    quests = { { id = 'my_fishing', state = 'completed' } },
    gang = { odriscoll = 0 },
    onduty = true,
    items = { { name = 'bread', amount = 1 } },  -- checked, not taken
    money = { { type = 'cash', amount = 5 } },   -- checked, not taken
    flags = { 'met_sheriff' },
    notFlags = { 'banned' },
    skills = { { skill = 'hunting', level = 5 } },
    honor = { min = 0, max = 100 },
    standing = { { region = 'valentine', min = 10 } },
    custom = { { name = 'owns_horse', arg = 'any' } },
    time = { from = 21, to = 5 },      -- in-game hours (rsg-weather)
    weather = { 'rain', 'thunderstorm' }, -- any one listed (rsg-weather)
}
```
`job` checks the player's **current** job. `anyJob` checks every job they hold through rsg-core `HasPlayerJob`. Skill keys come from rsg-skills and region keys from rsg-reputation.

Quest states: `available` (can be taken now, ignoring the active limit), `active` (includes ready), `ready`, `completed` (at least once, including repeatable quests), `notcompleted`. If quest progress can't be loaded, these fail.

On save, the editor checks item, job, gang, skill, region, quest, NPC, line and reply names. A list that is unavailable (for example, rsg-skills not running) isn't checked. File and export definitions are checked for shape only.

## 3. Exports
### Server
| Export | Returns | Notes |
|---|---|---|
| `RegisterNPC(def)` | `true, id` or `false, error` | Owned by the calling resource; calling again replaces it. Removed when that resource stops |
| `RemoveNPC(id)` | boolean | Only your own NPCs |
| `OpenDialog(src, npcId, node?)` | boolean | Skips the NPC position check; the player must then stay within 5m of where they were. `requires` still applies |
| `CloseDialog(src)` | – | |
| `RegisterAction(name, function(src, npcId))` | boolean | |
| `RegisterCondition(name, function(src, arg, npcId))` | boolean | Return `true`, or `false, 'reason'` |
| `HasFlag(src, flag)` | boolean | |
| `SetFlag(src, flag)` / `ClearFlag(src, flag)` | boolean | Online players |
| `ResetProgress(citizenid, npcId?)` | boolean | With `npcId`: clears that NPC's once and cooldown records. Without: clears everything, including flags and quest progress |
| `RegisterQuest(def)` | `true, id` or `false, error` | Owned by the caller; removed when it stops |
| `RemoveQuest(id)` | boolean | Only your own quests. Saved progress is kept |
| `StartQuest(src, id)` | `ok, reason` | Applies requirements, cooldown and active limit |
| `AbandonQuest(src, id)` | boolean | |
| `CompleteQuest(src, id)` | `ok, reason` | The quest must be active and ready. Takes delivery items and gives rewards |
| `AddQuestProgress(src, questId, objectiveId, amount?)` | boolean | `custom` objectives only |
| `GetQuestState(src, id)` | string or nil | `available`, `active`, `ready`, `completed`, `cooldown`, `locked` |

Export functions that touch progress may wait for the database, so call them from an event or thread. If rsg-npcdialog restarts, other resources must register their NPCs, actions and conditions again.

### Server examples
```lua
local npc = exports['rsg-npcdialog']

-- NPCs
local ok, err = npc:RegisterNPC(definition)      -- true, id  or  false, error
if not ok then print(err) end
npc:RemoveNPC('my_stablehand')                   -- only from the resource that registered it

-- conversations
npc:OpenDialog(src, 'my_stablehand')             -- opening line
npc:OpenDialog(src, 'my_stablehand', 'offer')    -- a named line
npc:CloseDialog(src)

-- flags
if not npc:HasFlag(src, 'met_amos') then npc:SetFlag(src, 'met_amos') end
npc:ClearFlag(src, 'met_amos')

-- reset
npc:ResetProgress(citizenid, 'val_blacksmith')   -- that NPC's once / cooldown records
npc:ResetProgress(citizenid)                     -- everything, including quests

-- quests
npc:RegisterQuest(questDefinition)
npc:RemoveQuest('my_fishing')
local started, reason = npc:StartQuest(src, 'my_fishing')
local added = npc:AddQuestProgress(src, 'my_fishing', 'catch', 1) -- false if nothing counted
local state = npc:GetQuestState(src, 'my_fishing')
if state == 'ready' then
    local done, why = npc:CompleteQuest(src, 'my_fishing')
end
npc:AbandonQuest(src, 'my_fishing')
```

### Client
| Export | Notes |
|---|---|
| `Open(npcId)` | Normal distance checks apply. Call from a thread |
| `IsOpen()` | boolean |
| `Close()` | |
| `OpenJournal()` | Opens the quest journal |

`Open` returns `false` if a UI is already open, the player is dead or mounted, or the server refuses.
```lua
CreateThread(function()
    if not exports['rsg-npcdialog']:IsOpen() then
        local opened = exports['rsg-npcdialog']:Open('val_blacksmith')
    end
end)
exports['rsg-npcdialog']:Close()
exports['rsg-npcdialog']:OpenJournal()
```

## 4. Events and callbacks
### Public events (safe to listen to)
| Event | Side | Arguments |
|---|---|---|
| `rsg-npcdialog:server:opened` | server | `src, npcId` |
| `rsg-npcdialog:server:choice` | server | `src, npcId, nodeId, choiceId` after a reply is accepted |
| `rsg-npcdialog:server:questStarted` | server | `src, questId` |
| `rsg-npcdialog:server:questCompleted` | server | `src, questId` |
| `rsg-npcdialog:server:questAbandoned` | server | `src, questId` |
| `rsg-npcdialog:client:opened` | client | `npcId` |
| `rsg-npcdialog:client:closed` | client | `npcId` |

These are local events: use `AddEventHandler`. Never add `RegisterNetEvent` for the server ones, or clients could fake them.
```lua
-- server
AddEventHandler('rsg-npcdialog:server:questCompleted', function(src, questId)
    print(('player %s finished %s'):format(src, questId))
end)
-- client
AddEventHandler('rsg-npcdialog:client:opened', function(npcId) end)
```

### Internal network events
Listed for debugging. Don't trigger them from other resources.

| Event | Direction | Data |
|---|---|---|
| `rsg-npcdialog:client:sync` | server to client | List of visible NPCs |
| `rsg-npcdialog:client:markers` | server to client | `{ [npcId] = 'offer' or 'turnin' }` |
| `rsg-npcdialog:client:quests` | server to client | Journal view: `active`, `completed` |
| `rsg-npcdialog:client:show` | server to client | `npcId, view` (from `OpenDialog`) |
| `rsg-npcdialog:client:close` | server to client | none |
| `rsg-npcdialog:client:openEditor` | server to client | none |
| `rsg-npcdialog:server:closed` | client to server | `sessionId` |
| `rsg-npcdialog:server:questKill` | client to server | `netId`, checked as described in section 11 |

### Internal rsg-core callbacks
All are prefixed `rsg-npcdialog:server:`.

| Callback | Arguments | Protection |
|---|---|---|
| `getNPCs` | none | Public data only |
| `open` | `npcId` | Position, state and requirements; once per 750 ms |
| `choose` | `sessionId, index` | Session match, full re-check, `ChoiceCooldownMs`, one at a time |
| `getQuests` | none | Own data only; once per 500 ms |
| `abandonQuest` | `questId` | Own active quest only |
| `canEdit` | none | Returns the permission check |
| `editorData` | none | Permission |
| `save` | `kind, json, isNew` | Permission, size, validation, name checks |
| `delete` | `kind, id` | Permission; editor entries only |

### NUI callbacks
`dialogChoose`, `dialogClose`, `journalClose`, `journalAbandon`, `journalPin`, `journalRoute`, `editorClose`, `editorSave`, `editorDelete`, `editorHere`, `editorTeleport`, `editorPlace`. All text is written to the page with `textContent`, never as HTML.

## 5. Actions and custom conditions
```lua
-- shared/config.lua
Config.Actions = {
    open_shop = { side = 'client', event = 'my-shop:client:open', args = { shop = 'valentine' } },
    start_job = { side = 'server', event = 'my-job:server:start' },
}
```
- `client` receives `(npcId, args)`.
- `server` receives `(src, npcId, args)`. Use `AddEventHandler`, **not** `RegisterNetEvent`, or players could trigger it themselves.

Handlers for the two configured actions above:
```lua
-- client side of my-shop
RegisterNetEvent('my-shop:client:open', function(npcId, args) end) -- sent over the network by the server

-- server side of my-job (no RegisterNetEvent)
AddEventHandler('my-job:server:start', function(src, npcId, args) end)
```
An action added with `RegisterAction` runs its function directly on the server. A registered name takes priority over the same name in `Config.Actions`. Actions and conditions are removed when their resource stops.

```lua
exports['rsg-npcdialog']:RegisterCondition('has_clean_record', function(src, arg)
    local ok = exports['my-records']:IsClean(src) -- your own check
    return ok == true, 'Come back when your name is clean.'
end)
```
The editor lists actions and registered custom conditions. A choice whose action is not registered is unavailable.

An action runs after costs and rewards. If it opens another UI, put it on a choice with no `next`.

## 6. Saving
- Editor NPCs are stored as JSON in `rsg_npcdialog_npcs` and apply to everyone immediately. Saving an NPC ends conversations with it.
- Flags, one-time replies and cooldowns are saved per `citizenid` as they happen.
- If progress cannot be loaded, conversations are refused rather than treated as empty.
- Editor quests are stored as JSON in `rsg_npcdialog_quests`.
- Quest progress is one JSON row per character and quest:
  ```json
  { "active": true, "progress": { "look": 1 }, "started": 1795690000, "times": 0, "completedAt": 0 }
  ```
  `deliver` objectives are not stored; they are counted from the inventory.
- Progress is cached in memory and written as it changes. The cache is freed when the player leaves. If you edit the tables by hand, do it while that character is offline.
- Client KVP (per player's PC): `tracker_off` (tracker hidden) and `pins_<citizenid>` (JSON list of pinned quest IDs). No server KVP is used.

## 7. Security model
**Checked by this resource**
- The server holds each player's current node. Clients send only a session number and a reply position.
- Every reply re-checks distance, dead or cuffed state, requirements, once and cooldown.
- Only one reply per player can be processed at a time, with a rate limit. Opening a conversation from the client is limited to once every 750 ms.
- A quest cannot be completed again while its payout is still running.
- Journal data requests are limited to one every 500 ms. Marker refreshes are grouped to at most one pending per player.
- All SQL uses `?` parameters.
- With rsg-core money items on, there must be room for `cash` / `bloodmoney` reward items or nothing is paid. The same applies to gold rewards with gold items on. Each item type is checked separately, so an almost full inventory that has room for only one of several money items may still lose one.
- A requirement check that errors counts as "not met". A failing skill or reputation reward is logged and doesn't stop the reply being saved.
- Costs and rewards come from the server's copy. Items are validated before anything is taken. If removing a cost or adding an item fails, earlier steps are undone. A refunded unique item does not keep its old metadata.
- Skill XP and reputation are awarded after that step.
- Editor callbacks check permission every time, validate the whole definition, cap values with `Config.Limits`, and log saves and deletes through rsg-log.
- Editor users can only choose registered actions.
- Missing optional resources or conditions count as "not met".

**Your responsibility**
- Anyone with `Config.AdminPermission` can create dialogs that give money and items, within `Config.Limits` per reply. Only grant it to trusted staff.
- Validate anything your actions do (job, ownership, limits).
- A `cost` plus `repeatable` reward is a trade: check it can't be turned into profit elsewhere.
- Skill XP or reputation rewards need `once`, `cooldown` or `repeatable` too.

## 8. Database schema
Created automatically when `Config.AutoDatabase = true`; otherwise import `install.sql`:
```sql
-- rsg-npcdialog: only needed when Config.AutoDatabase = false
CREATE TABLE IF NOT EXISTS `rsg_npcdialog_npcs` (
  `id` VARCHAR(50) NOT NULL,
  `data` LONGTEXT NOT NULL,
  `updated_by` VARCHAR(50) DEFAULT NULL,
  `updated_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`)
);
CREATE TABLE IF NOT EXISTS `rsg_npcdialog_progress` (
  `citizenid` VARCHAR(50) NOT NULL,
  `kind` VARCHAR(8) NOT NULL,
  `name` VARCHAR(160) NOT NULL,
  `value` BIGINT NOT NULL DEFAULT 0,
  PRIMARY KEY (`citizenid`, `kind`, `name`)
);
CREATE TABLE IF NOT EXISTS `rsg_npcdialog_quests` (
  `id` VARCHAR(50) NOT NULL,
  `data` LONGTEXT NOT NULL,
  `updated_by` VARCHAR(50) DEFAULT NULL,
  `updated_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`)
);
CREATE TABLE IF NOT EXISTS `rsg_npcdialog_quest_progress` (
  `citizenid` VARCHAR(50) NOT NULL,
  `quest_id` VARCHAR(50) NOT NULL,
  `data` TEXT NOT NULL,
  PRIMARY KEY (`citizenid`, `quest_id`)
);
```

| Table | Columns |
|---|---|
| `rsg_npcdialog_npcs` | `id` (PK), `data`, `updated_by`, `updated_at` |
| `rsg_npcdialog_progress` | `citizenid`, `kind` (`flag`, `once`, `cd`), `name`, `value` (cooldowns store the expiry time); PK is the first three |
| `rsg_npcdialog_quests` | `id` (PK), `data`, `updated_by`, `updated_at` |
| `rsg_npcdialog_quest_progress` | `citizenid`, `quest_id`, `data` (JSON); PK is the first two |

## 9. Server owner how-tos
- **Move the camera:** change `Config.Camera.offset` (right, forward, up) and `lookAt`.
- **Disable the example:** set `enabled = false` in `shared/npcs.lua`.
- **Reset a conversation:** call `ResetProgress(citizenid, npcId)`, and `ClearFlag` for its flags.
- **Add a translated NPC:** add keys to all 11 locale files and use `@key` text.
- **Change the language:** `setr rsg:locale de` in `server.cfg`.
- **Give a quest reward from another script:** use a `custom` objective with `autoComplete = true`, then call `AddQuestProgress`.
- **Clear one quest for one character** (while they are offline):
  `DELETE FROM rsg_npcdialog_quest_progress WHERE citizenid = ? AND quest_id = ?;`
- **Manual install:** set `Config.AutoDatabase = false` and import `install.sql`.

## 10. Troubleshooting
A reply with no `next` ends the conversation straight away, so put any final words on their own line with a goodbye reply. The conversation box has a fixed size (`.dlg` and `.dlg .speech` in `html/style.css`); longer text and reply lists scroll. Replies show three to a row, with two rows visible.

| Symptom | Check |
|---|---|
| NPC missing | `enabled`, coords, spawn distance, F8 for an invalid model, server console for a validation error |
| No target option | rsg-target is started; you are within the talk distance |
| "That did not work" | Database errors in the console; unknown item names |
| Reply always locked | Optional resource started; skill, region, action and condition names |
| Editor won't open | Your permission matches `Config.AdminPermission`; no conversation is open |
| Save rejected | The message names the node or field |
| Placement fails | rsg-gizmo is started; the model name is valid; stay within `Config.PlaceDistance` |
| NPC floats or sinks | Adjust `z`; coords are a standing position, not ground height |

## 11. Quests
Quests come from `shared/quests.lua`, `RegisterQuest` or the editor. File and export quests are read-only in the editor.

### Format
| Field | Notes |
|---|---|
| `id`, `name`, `objectives` | Required. 1 to 10 objectives |
| `description` | Shown in the journal |
| `enabled` | `false` hides the quest |
| `ordered` | Only the first unfinished objective can progress |
| `autoComplete` | Completes as soon as it is ready. Not allowed with `deliver` objectives |
| `repeatable`, `cooldown` | `cooldown` (seconds) is required when repeatable without `reset`, at least `MinRepeatCooldown` |
| `reset` | `'daily'` or `'weekly'`. Needs `repeatable = true`; replaces `cooldown` |
| `pool` | Name of a random pool. Needs `reset` |
| `requires` | Same format as dialog requirements |
| `reward` | Same format as dialog rewards |

Every objective has `id`, `type`, `label` and usually `count` (default 1).

| Type | Extra fields | How it counts |
|---|---|---|
| `deliver` | `item` | Counts what is carried. Taken when the quest is completed |
| `visit` | `coords`, `radius` (1-200, default 5), `blip` (default true) | Checked on the server every `TickMs`. Count is always 1 |
| `talk` | `npc`, `node?`, `choice?` | Opening the NPC; or reaching `node`; or picking reply `choice` of `node` (use the reply's `id`) |
| `kill` | `models` | Ped model names. One body counts once, for one objective |
| `custom` | none | Added with `AddQuestProgress` |

`visit` and `talk` objectives always have a count of 1, whatever is written. This stops a talk objective being farmed by repeating the conversation.

```lua
{
    id = 'amos_delivery', name = 'A Hand for Amos', description = 'Fetch and carry.',
    ordered = true, repeatable = true, reset = 'daily',
    requires = { flags = { 'met_amos' } },
    objectives = {
        { id = 'go',    type = 'visit',   label = 'Check the old shed', coords = vector3(0.0, 0.0, 0.0), radius = 4.0, blip = true },
        { id = 'hunt',  type = 'kill',    label = 'Clear out wolves', models = { 'a_c_wolf' }, count = 2 },
        { id = 'ask',   type = 'talk',    label = 'Speak to Amos', npc = 'val_blacksmith', node = 'welcome_back' },
        { id = 'help',  type = 'custom',  label = 'Help at the forge', count = 3 },
        { id = 'bread', type = 'deliver', label = 'Bring bread', item = 'bread', count = 2 },
    },
    reward = { money = { { type = 'cash', amount = 5 } } },
}
```

Replies that start and hand in that quest:
```lua
{ id = 'job',  label = 'Any work?',      startQuest  = 'amos_delivery' },
{ id = 'done', label = 'It is finished.', turnInQuest = 'amos_delivery', lock = 'show' },
```

Talk progress only counts after the quest is active, so a reply that starts a quest doesn't also complete its talk objective.

### Daily, weekly and pools
A quest with `reset` can be completed once per period. Periods change at `Config.Quests.Reset` in real time (a fixed UTC offset, so it does not follow summer time). The period is the one in which the quest was **completed**.
```lua
Config.Quests.Pools = { bounties = 2 } -- offer 2 of the quests in this pool each period

-- a quest in that pool (add one definition like this for each quest in the draw)
exports['rsg-npcdialog']:RegisterQuest({
    id = 'bounty_wolves', name = 'Wolf Bounty', repeatable = true, reset = 'daily', pool = 'bounties',
    objectives = { { id = 'hunt', type = 'kill', label = 'Hunt wolves', models = { 'a_c_wolf' }, count = 3 } },
})
```
Quests are in the same draw when they share a pool name **and** reset type, and are enabled. The pick is worked out from the pool name, period number and quest ID, so it is the same for everyone and survives restarts without saving anything. It is random, so a quest can come up several periods in a row. Adding, removing or disabling a pool quest can change the current pick. A quest that isn't picked reports `locked`; players who already have it active keep it and can hand it in.

### Turning in
A `turnInQuest` reply applies its own cost and reward together with the delivery items and quest reward in one step. If anything fails (for example, no inventory space) earlier steps are undone and the quest stays ready. Skill XP and reputation follow. Auto-complete quests that can't pay out tell the player once and keep trying.

### Abandoning and repeats
Abandoning loses objective progress but keeps completion history, so it can't skip a cooldown or reset. Removing or disabling a quest hides it but keeps saved progress. If you reuse a quest ID, old progress applies to it, so use new IDs for new quests. Changing objective IDs resets their progress.

### Journal, tracker and blips
The client receives only the character's active and completed quests. The tracker hides while other UI is open, and each player's on/off choice is saved with client KVP. Pins and routes are covered in section 13. Visit objectives with `blip` show a map blip while open.

### Security
- All progress and rewards are decided on the server.
- For kills, the client only sends a network ID. The server checks it is an existing, dead, non-player ped with a listed model, within `KillRange`, not counted before, with a per-player rate limit. With `CheckKiller`, a body is rejected when the server knows a different killer, unless that killer is a non-player ped within 2 m of the player (a mount trampling the target).
- Talk objectives count once only.
- **Limits:** the server can't always tell who killed a ped, so a cheater could claim another player's or a world kill nearby, or spawn and kill peds. Keep rewards for kill quests modest and give repeatable ones a sensible cooldown. Kills only count for networked peds.
- `visit` uses the server's view of the player's position. It can't detect a teleport cheat.
- `AddQuestProgress` and the other exports trust the calling resource. Validate before calling them.
- Editor users can create quests with rewards up to `Config.Limits`.

### Quest troubleshooting
| Symptom | Check |
|---|---|
| Start reply missing | Quest enabled, requirements, cooldown, one-time already done |
| "Too many active quests" | `Config.Quests.MaxActive` |
| Kill not counted | Model name; the ped is networked; objective is open (ordered quests); stay near the body |
| Visit not counted | Coords and radius; dead players don't count; wait one tick |
| No tracker | `/questhud`; another UI may be open |
| Hand-in greyed out or hidden | All objectives met and items carried |

## 12. Time, weather and schedules
Both use **rsg-weather** server exports `getTime()` (in-game hour) and `getWeather()`.

- `time = { from, to }`: `from` is included, `to` is not. It wraps past midnight. Equal values mean all day. `to = 24` is the same as `0`.
- `weather`: any one of `blizzard`, `clouds`, `drizzle`, `fog`, `groundblizzard`, `hail`, `highpressure`, `hurricane`, `misty`, `overcast`, `overcastdark`, `rain`, `sandstorm`, `shower`, `sleet`, `snow`, `snowlight`, `sunny`, `thunder`, `thunderstorm`, `whiteout`.
- This is the **server** weather. rsg-weather may show different weather in some regions on the client; that isn't checked.
- If rsg-weather isn't running, time and weather requirements **fail**, but scheduled NPCs **stay at their normal spot** all day. One console warning is printed.

```lua
schedule = {
    { from = 8, to = 18, scenario = 'WORLD_HUMAN_SMOKE' },        -- at the normal coords
    { from = 21, to = 2, coords = vector4(0.0, 0.0, 0.0, 90.0) }, -- somewhere else at night
}
```
With a `schedule`, the NPC only exists during a matching slot (first match wins). A slot without `coords` or `scenario` uses the NPC's own. It is checked every `Config.ScheduleCheckMs`. The NPC appears and disappears at once, with no walking between spots. Open conversations end when the NPC closes or its spot or scenario changes. `OpenDialog` from another resource still works while the NPC is closed. The blip is only shown while the NPC is present.

## 13. Quest markers, pins and GPS
**Markers.** The server marks an NPC for a player when one of its `startQuest` replies can be used (`offer`) or a `turnInQuest` reply is ready (`turnin`, which takes priority). It checks the NPC's `requires`, the reply's `requires`, `once`, `cooldown`, its action, and the quest's own rules and active limit. It does **not** check whether the player can reach that reply from the opening line, so a reply behind other gated replies can be marked early. Costs are not checked, so an offer can be marked even if the player cannot pay. Markers update after replies and quest changes, and every `Config.Markers.RefreshMs`. Custom conditions are therefore called regularly for online players: keep them quick and free of side effects. Set `Config.Markers.Enabled = false` to turn markers off.

**Pins.** If any quest is pinned, the tracker shows only pinned quests. Pins are stored in client KVP per character and removed when the quest is no longer active.

**GPS.** The route leads to the first open unfinished `talk` or visible `visit` objective, or, when the quest is ready, to the hand-in NPC. Visit objectives with `blip = false` are never revealed, and `deliver`, `kill` and `custom` objectives have no location. If several NPCs accept the hand-in, the first by ID is used, without checking its reply requirements. A closed NPC is routed to where it is now if present, otherwise to its first slot's spot. The route is cleared when the quest ends or you press **Stop route**. A GPS route set by another script may replace it, and clearing this one may clear theirs.

| Symptom | Check |
|---|---|
| NPC missing at some hours | Its `schedule`; the in-game hour |
| Time or weather reply always locked | rsg-weather is started; the weather names |
| No marker | `Config.Markers.Enabled`; the reply has `startQuest` or `turnInQuest` and its rules pass; wait `RefreshMs` |
| Route greyed out | The current objective has no location |
| Pool quest never offered | It isn't picked this period; `Config.Quests.Pools` |

## 14. Configuration reference
All in `shared/config.lua`, which both server and client read. Don't put secrets in it.

| Option | Default | Used by | Description |
|---|---|---|---|
| `Config.VersionCheck` | `false` | server | Compare with rsg-versioncheckers on GitHub |
| `Config.AutoDatabase` | `true` | server | Create tables on start |
| `Config.AllowPushToTalkWhileOpen` | `true` | client | Keep push-to-talk in the UI |
| `Config.PushToTalkControls` | `{ 0x4BC9DABB }` | client | Controls left enabled while a UI is open |
| `Config.SpawnDistance` | `60.0` | client | NPC spawn distance (removed 5 m further out) |
| `Config.InteractDistance` | `2.5` | both | Default talk distance |
| `Config.ServerLeeway` | `2.0` | server | Extra distance allowed |
| `Config.ChoiceCooldownMs` | `400` | server | Minimum time between replies |
| `Config.ScheduleCheckMs` | `5000` | server | Schedule check interval |
| `Config.Markers.Enabled` | `true` | server | Quest markers on or off |
| `Config.Markers.RefreshMs` | `10000` | server | Periodic marker refresh |
| `Config.Markers.ShowBlip` | `true` | client | Temporary blip for a marked NPC without one |
| `Config.Markers.OfferColour` | `'BLIP_MODIFIER_MP_COLOR_6'` | client | Blip modifier for offers |
| `Config.Markers.TurnInColour` | `'BLIP_MODIFIER_MP_COLOR_8'` | client | Blip modifier for hand-ins |
| `Config.Camera.enabled` | `true` | client | Conversation camera |
| `Config.Camera.offset` | `vector3(0.45, 1.45, 0.55)` | client | Right, forward, up from the NPC |
| `Config.Camera.lookAt` | `vector3(0.0, 0.0, 0.45)` | client | Point on the NPC |
| `Config.Camera.fov` | `40.0` | client | Field of view |
| `Config.Camera.easeMs` | `600` | client | Blend time |
| `Config.Camera.hidePlayer` | `true` | client | Hide your own character locally |
| `Config.TypeSpeed` | `35` | client | Milliseconds per letter, 0 = instant |
| `Config.HideRadar` | `true` | client | Hide radar while talking |
| `Config.Quests.MaxActive` | `10` | server | Active quests per character |
| `Config.Quests.TickMs` | `2000` | server | Visit and delivery check |
| `Config.Quests.MinRepeatCooldown` | `60` | server | Shortest repeat cooldown (seconds) |
| `Config.Quests.KillRange` | `150.0` | both | Furthest counted body |
| `Config.Quests.CheckKiller` | `true` | server | Reject other people's kills |
| `Config.Quests.JournalCommand` | `'quests'` | client | Journal command |
| `Config.Quests.JournalKey` | `''` | client | Default journal key |
| `Config.Quests.TrackerCommand` | `'questhud'` | client | Tracker on or off |
| `Config.Quests.TrackerMax` | `3` | client | Quests shown, including pinned ones |
| `Config.Quests.TrackerPosition` | `'right'` | client | `'right'` or `'left'` |
| `Config.Quests.GpsColour` | `'COLOR_YELLOW'` | client | GPS route colour |
| `Config.Quests.Reset.Hour` | `6` | server | Daily and weekly reset hour |
| `Config.Quests.Reset.WeekDay` | `1` | server | 1 = Monday to 7 = Sunday |
| `Config.Quests.Reset.UtcOffset` | `0` | server | Hours from UTC |
| `Config.Quests.Pools` | `{}` | server | `{ poolName = quests offered }`, default 1 |
| `Config.AdminCommand` | `'npcdialog'` | server | Editor command |
| `Config.AdminPermission` | `'admin'` | server | Editor permission |
| `Config.PlaceDistance` | `10.0` | client | rsg-gizmo placement range |
| `Config.Limits.money / items / xp / rep` | `10000 / 100 / 1000 / 100` | server | Largest values in any definition |
| `Config.Actions` | `{}` | server | Named events replies can run |

`Config.NPCs` is set in `shared/npcs.lua` and `Config.QuestList` in `shared/quests.lua`. Because these are shared files, players can read what is written in them. Editor and export definitions are only held on the server.

## 15. Commands, keys and the editor
| Command | Who | Does |
|---|---|---|
| `/npcdialog` (`AdminCommand`) | `AdminPermission` | Opens the editor |
| `/quests` (`JournalCommand`) | everyone | Opens the journal |
| `/questhud` (`TrackerCommand`) | everyone | Shows or hides the tracker |

The journal key is registered with rsg-core `RegisterKey` as `rsgnpcdialog_journal` (rsg-core 3.5.0+). It is unbound by default and can be rebound in the game's key settings. Talking uses rsg-target.

**In a conversation:** 1-9 replies, Space or click skips typing, Esc or Backspace leaves.

**Editor**
- *NPCs / Quests* switch at the top left, with search. The badge shows the source: `config` and `export` entries are read-only; copy them to edit.
- NPC tab: details, position, opening hours, talk requirements. Dialog tab: opening lines, nodes and replies.
- *Place NPC* moves a preview ped with rsg-gizmo (on the base position or one schedule slot). *Use my position* and *Teleport* work on the same position.
- *Preview* runs in the browser only.
- *Save* validates on the server, writes the database and applies at once.
- Saves and deletes are sent to rsg-log (`default` channel).

## 16. Integration examples
### A quest driven by another script
```lua
-- server.lua of my-fishing (fxmanifest: dependency 'rsg-npcdialog')
local function register()
    local ok, err = exports['rsg-npcdialog']:RegisterQuest({
        id = 'my_fishing', name = 'Fresh Catch', repeatable = true, reset = 'daily',
        objectives = { { id = 'catch', type = 'custom', label = 'Catch fish', count = 3 } },
        reward = { money = { { type = 'cash', amount = 4 } } },
    })
    if not ok then print(err) end
end

CreateThread(register)
-- register again if rsg-npcdialog restarts
AddEventHandler('onResourceStart', function(res)
    if res == 'rsg-npcdialog' then SetTimeout(500, register) end
end)

-- call from your own server-validated catch logic
local function onCatch(src)
    exports['rsg-npcdialog']:AddQuestProgress(src, 'my_fishing', 'catch', 1)
end
```

### A custom requirement
```lua
exports['rsg-npcdialog']:RegisterCondition('min_cash', function(src, arg)
    local Player = exports['rsg-core']:GetCoreObject().Functions.GetPlayer(src)
    if Player and Player.Functions.GetMoney('cash') >= (tonumber(arg) or 0) then return true end
    return false, 'You look short of money.'
end)
-- in a reply: requires = { custom = { { name = 'min_cash', arg = '20' } } }
```
Conditions also run during marker refreshes, so keep them quick and don't change anything inside them.

### Opening a conversation from your own event
```lua
-- server
RegisterNetEvent('my-resource:server:knock', function()
    local src = source
    -- check distance and anything else here first
    exports['rsg-npcdialog']:OpenDialog(src, 'val_blacksmith')
end)
```

Support: https://rexshack.tebex.store
