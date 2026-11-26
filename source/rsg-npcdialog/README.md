# rsg-npcdialog

NPC dialog and quest system for the RSG Framework (RedM). Version **3.1.1**.

Branching conversations with a cinematic camera, written in config files, registered by other scripts, or built in-game by admins. Full developer and server owner documentation is in [DOCS.md](DOCS.md).

**Dependencies:** rsg-core, rsg-inventory, rsg-target, rsg-gizmo, oxmysql
**Optional:** rsg-skills and rsg-reputation (only for dialogs that use them), rsg-weather (time and weather rules, NPC schedules)

## Features
- Cinematic conversation view: camera on the NPC, typewriter speech, numbered replies (keys 1-9)
- Branching lines with up to 9 replies each, plus different opening lines for returning players
- **Quests:** deliver items, visit places, talk to NPCs, hunt or kill, or progress reported by your own scripts; one-time or repeatable; journal, on-screen tracker and map blips
- **Daily and weekly quests** that reset at a set time, with random pools that change each day or week
- **Quest markers:** coloured blips and a talk-prompt note on NPCs with a quest to give or take back
- **Pinned quests and GPS:** choose what the tracker shows and set a route from the journal
- **NPC schedules:** opening hours, with an optional different spot and scenario for each time slot
- **Requirements:** time of day, weather, quest state, any held job, job or gang grade, on duty, items, money, flags, skill level, honor, regional standing, custom conditions
- **Costs and rewards:** money, items, skill XP, honor, regional standing
- **Saved progress** per character: one-time replies, cooldowns and flags shared between NPCs
- **Actions:** replies can run events or functions from other scripts
- **In-game editor** (`/npcdialog`): create, edit, copy and delete NPCs and quests, place NPCs with rsg-gizmo, searchable name lists, and a preview of unsaved dialog
- Server-authoritative: the server tracks the current line and re-checks every reply
- NPCs are local peds that only exist when a player is nearby
- Push-to-talk keeps working while the UI is open

## Installation
1. Put `rsg-npcdialog` in your resources folder.
2. In `server.cfg`, start it after its dependencies:
   ```
   ensure rsg-core
   ensure rsg-inventory
   ensure rsg-target
   ensure rsg-gizmo
   ensure rsg-weather      # optional: time / weather rules and schedules
   ensure rsg-npcdialog
   ```
3. Database tables are created automatically on first start. To install manually, set `Config.AutoDatabase = false` and import `install.sql`.
4. The example NPC in `shared/npcs.lua` uses **placeholder coords** and gives `bread` and `water`. Move it, or set `enabled = false`. Check those items exist on your server. The example quest in `shared/quests.lua` also uses placeholder coords.

There are no new items or images to add.

## Configuration (`shared/config.lua`)
| Option | Default | Description |
|---|---|---|
| `Config.VersionCheck` | `false` | Check GitHub for a newer version |
| `Config.AutoDatabase` | `true` | Create database tables on start |
| `Config.AllowPushToTalkWhileOpen` | `true` | Keep push-to-talk working in the UI |
| `Config.PushToTalkControls` | push-to-talk | Controls left enabled while the UI is open |
| `Config.SpawnDistance` | `60.0` | Distance at which NPCs spawn |
| `Config.InteractDistance` | `2.5` | Default talk distance |
| `Config.ServerLeeway` | `2.0` | Extra distance allowed by the server |
| `Config.ChoiceCooldownMs` | `400` | Minimum time between replies |
| `Config.ScheduleCheckMs` | `5000` | How often NPC schedules are checked |
| `Config.Markers` | see file | `Enabled`, `RefreshMs` (10000), `ShowBlip` (temporary blip for NPCs without one), `OfferColour`, `TurnInColour` |
| `Config.Quests.GpsColour` | `'COLOR_YELLOW'` | Journal GPS route colour |
| `Config.Quests.Reset` | 06:00 UTC, Monday | `Hour`, `WeekDay` (1 = Monday), `UtcOffset` for daily and weekly quests |
| `Config.Quests.Pools` | empty | Quests offered per day or week from each pool (unlisted pools offer 1) |
| `Config.Camera` | see file | `enabled`, `offset`, `lookAt`, `fov`, `easeMs`, `hidePlayer` |
| `Config.TypeSpeed` | `35` | Milliseconds per letter (0 = instant) |
| `Config.HideRadar` | `true` | Hide the radar during conversations |
| `Config.AdminCommand` | `'npcdialog'` | Editor command |
| `Config.AdminPermission` | `'admin'` | Permission needed for the editor |
| `Config.PlaceDistance` | `10.0` | Placement range |
| `Config.Limits` | money 10000, items 100, xp 1000, rep 100 | Largest values any dialog may use |
| `Config.Quests.MaxActive` | `10` | Active quests per character |
| `Config.Quests.TickMs` | `2000` | How often the server checks visits and carried items |
| `Config.Quests.MinRepeatCooldown` | `60` | Shortest repeat cooldown (seconds) |
| `Config.Quests.KillRange` | `150.0` | Furthest a counted body may be |
| `Config.Quests.CheckKiller` | `true` | Reject bodies someone else killed |
| `Config.Quests.JournalCommand` | `'quests'` | Journal command |
| `Config.Quests.JournalKey` | `''` | Default journal key (rebindable in the game's key settings) |
| `Config.Quests.TrackerCommand` | `'questhud'` | Show or hide the tracker |
| `Config.Quests.TrackerMax` | `3` | Quests on the tracker |
| `Config.Quests.TrackerPosition` | `'right'` | `'right'` or `'left'` |
| `Config.Actions` | empty | Named events that replies can run |

## How to use
**Players:** aim at an NPC with rsg-target and choose *Talk to ...*. Click a reply or press 1-9. Space, a click on the text or a number key skips the typing. Replies run side by side, three to a row. The conversation box stays the same size; scroll if a long line or more than six replies don't fit. Esc, Backspace or *Leave* ends the conversation. Walking away, taking damage or dying also ends it. You can't start one while mounted.

**Quests:** take them and hand them in by talking to NPCs. `/quests` opens the journal, where you can also abandon a quest. **Pin** makes the tracker show only your pinned quests (up to `TrackerMax`). **Route** draws a GPS route to the next talk or marked visit objective, or to the hand-in NPC; it is greyed out when there is no single place to go. Pins are saved per character on your PC; the route is not saved. `/questhud` shows or hides the tracker. A journal key can be bound in the game's key settings. Delivery items are taken when you hand the quest in.

**Admins:** `/npcdialog` (permission: `admin`).
1. **New NPC**, then enter an ID, name and ped model.
2. **Place NPC** (rsg-gizmo) or **Use my position**.
3. On the **Dialog** tab add lines and replies. "Goes to" picks the next line; "End conversation" closes it.
4. Add requirements, costs and rewards where needed, then **Save**. Changes apply immediately.

**Opening hours:** on the NPC tab, **Add time slot** and set the in-game hours (from is included, to is not; `21` to `5` runs overnight). The NPC only appears during its slots. Tick **Different spot** to move it for a slot. The first matching slot wins.

**Daily or weekly quest:** on the quest, choose **Reset**. To offer a random pick, give several daily (or weekly) quests the same **Random pool** name and set the number in `Config.Quests.Pools`. Everyone gets the same pick.

NPCs from `shared/npcs.lua` or other scripts are read-only in the editor. Use **Copy NPC** to make an editable copy, then disable the original in its file so you don't have two in the same spot.

**Making a quest:** switch to **Quests** at the top left, add objectives and rewards, then **Save**. Next, on an NPC's replies, set **Starts quest** on one and **Hands in quest** on another (not needed to hand in if the quest completes automatically). Give those replies a **Quest state** requirement only if you want extra rules: start replies already show only when the quest can be taken, and hand-in replies only when it is ready (or greyed out if set to *Show as locked*).

**Preview** plays the NPC you are editing, including unsaved changes. Nothing is given, taken or saved. Only flags are simulated. Use *Pretend fail* to see what happens when a requirement is not met.

Name fields (item, job, gang, skill, region, quest, NPC) have searchable lists. Saving checks the names. If a list is empty because the resource that provides it isn't running, that name type isn't checked.

A reply with a reward must be **once per character**, have a **cooldown**, or be marked **reward repeatable**. This stops accidental infinite rewards.

## Developer example
```lua
-- server side of another resource (add 'rsg-npcdialog' to its dependencies)
exports['rsg-npcdialog']:RegisterAction('stable_open', function(src, npcId)
    TriggerClientEvent('my-stables:client:open', src)
end)

local ok, err = exports['rsg-npcdialog']:RegisterNPC({
    id = 'my_stablehand', name = 'Stablehand', model = 'u_m_m_valgenstoreowner_01',
    coords = vector4(0.0, 0.0, 0.0, 0.0), start = 'hi',
    nodes = {
        hi = { text = 'Need a horse?', choices = {
            { id = 'yes', label = 'Show me.', action = 'stable_open' },
            { id = 'no', label = 'No thanks.' },
        } },
    },
})
if not ok then print(err) end
```

## Quest example
```lua
-- server side of another resource
exports['rsg-npcdialog']:RegisterQuest({
    id = 'my_fishing', name = 'Fresh Catch',
    objectives = { { id = 'catch', type = 'custom', label = 'Catch fish', count = 3 } },
    reward = { money = { { type = 'cash', amount = 4 } } },
})
-- when your script sees a catch
exports['rsg-npcdialog']:AddQuestProgress(src, 'my_fishing', 'catch', 1)
```

## Locales
en, de, el, es, fr, ja, nl, pl, pt-br, ro, ru. Set the language with `setr rsg:locale de`. Editor validation errors for badly formed dialogs are in English.

Support: https://rexshack.tebex.store
