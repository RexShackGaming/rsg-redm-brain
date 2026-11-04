# rsg-trams documentation

## Tracks
`Config.Tracks` has a single entry, `loop`. The upper (Rockstar 11) and inner (12) tracks were removed; the code still supports extra tracks if you add entries back.

| Track | Rockstar index (medium_update.c, build 1491.50) | Train config |
|---|---|---|
| `loop`  | 8/9/10 `AMBIENT_NBX_TROLLEY`, `_1`, `_2` (Rockstar runs three on this loop; rsg-trams runs one) | `-1083616881` |

Fields: `enabled`, `order` (spawn priority), `config`, `coords` (func_1284), `direction` (func_1285), `callOutOnly` (conductor only uses `CALL_OUT_NEUTRAL`, as Rockstar's upper line does).


## Config
| Option | Default | Meaning |
|---|---|---|
| `TrolleyModels` | `{ 'trolley01x' }` | Models that count as a trolley; if one exists, no new trolley spawns |
| `AdminPermission` | `'admin'` | rsg-core permission for `/trams` |
| `CruiseSpeed` / `MaxSpeed` | 3.5 / 6.0 | func_775 / func_779 |
| `StopForStations` | true | func_1287 |
| `Passengers` / `Conductor` | true | Ambient passengers and driver |
| `Invincible` | true | Trolley and driver can't be wrecked |
| `Blip`, `BlipSprite`, `BlipModifier` | | Map blip per trolley |
| `Audio` | `trolley01x` | Car models whose audio game object is forced |
| `Announce`, `AnnounceRange` | true, 25.0 | Conductor announcements near the player |
| `Avoid` | | Braking look-ahead: `distance`, `width`, `interval`, `clearNpcAfter`, `maxWait`, `pushTime`, `stopGap`, `brake`, `accel` |
| `SpawnClearance` | 40.0 | Wait to spawn while any trolley is this close to the spawn point |
| `HostCheckInterval` | 10000 | ms between server checks |
| `DriverlessChecks` | 2 | Checks without a living driver before a trolley is replaced |
| `SpawnTimeout` | 60000 | ms before an unanswered spawn request is retried |

## How one-per-track is enforced
1. `GlobalState.rsgTrams[track] = leadNetId` is written only by the server.
2. The server asks the host to spawn a track only when that track has no live trolley and no spawn in flight, and only one spawn runs at a time.
3. The host checks GlobalState again before and after waiting for a valid spawn spot.
4. `registerTram` is rejected (and the train deleted by the host with `DELETE_MISSION_TRAIN`) if the sender isn't the host, the track is disabled, no spawn was requested, or the track already has a live trolley.
5. Every car is tagged with state bags `rsgTram = track` and `rsgTramId = leadNetId`. Each check, any tagged car whose `rsgTramId` doesn't match the registered trolley (or whose track is disabled) is deleted with its NPCs, unless a player is in it.

6. **Never a second trolley:** before asking for a spawn, the server scans every vehicle for a `Config.TrolleyModels` model. If a trolley it tagged is found, it is re-adopted instead of spawning a new one; if any other trolley exists (ambient or another script), nothing spawns. The host also checks its own vehicle pool for a trolley right before and after waiting for a spawn spot, and the server rejects a registration if another tagged trolley already exists.

## Events
| Event | Side | Purpose |
|---|---|---|
| `rsg-trams:client:spawnTrack (track)` | server → host | Create a track's trolley |
| `rsg-trams:server:registerTram (track, netId, cars)` | host → server | Register the new trolley |
| `rsg-trams:client:deleteTrain (netId)` | server → host | Delete a rejected trolley |

## State bags
- `GlobalState.rsgTrams` — `{ [track] = netId }`
- Entity: `rsgTram` (track id), `rsgTramId` (lead netId), `ownFare` (true; ticket systems skip it)

## Ownership and movement
Whichever client owns a trolley runs obstacle braking and keeps the driver protected. Other trolleys count as obstacles. When the road is clear, speed is handed back to the game so station stops work normally.

## Natives used
`_CREATE_MISSION_TRAIN 0xC239DBD9A57D2A71`, `_IS_SPAWN_POSITION_VALID_FOR_TRAIN 0xF05DFAF1ADFEF2CD`, `_SET_TRAIN_STOPS_FOR_STATIONS 0x4182C037AA1F0091`, `_SET_TRAIN_MAX_SPEED 0x9F29999DFDF2AEB8`, `SET_TRAIN_CRUISE_SPEED 0x01021EB2E96B793C`, `SET_TRAIN_SPEED 0xDFBA6BBFF7CCAFBB`, `IS_TRAIN_WAITING_AT_STATION 0xE887BD31D97793F6`, `GET_TRAIN_CARRIAGE 0xD0FB093A4CDB932C`, `GET_CURRENT_STATION_FOR_TRAIN 0x86FA6D8B48667D75`, `DELETE_MISSION_TRAIN 0x0D3630FB07E8B570`, `PLAY_PED_AMBIENT_SPEECH_NATIVE 0x8E04FEDD28D42462`, `SET_AMBIENT_VOICE_NAME 0x6C8065A3B780185B`, `FORCE_USE_AUDIO_GAME_OBJECT 0x4F0C413926060B38`.
