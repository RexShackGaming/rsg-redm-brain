# rsg-fortuneteller – Docs (v3.0.1)

## Contents
1. Files
2. How it works
3. Configuration
4. Events and commands
5. Security
6. Server owner how-tos
7. Troubleshooting

## 1. Files
| File | Purpose |
|---|---|
| `fxmanifest.lua` | Manifest; depends on `rsg-core`, `rsg-target` |
| `shared/config.lua` | Price, cooldowns, interaction, timing, voices, machines |
| `shared/lines.lua` | The 72 fortune lines |
| `shared/utils.lua` | Shared helpers |
| `client/main.lua` | Machines, animation, speech, interaction |
| `client/dataview.lua` | Buffer helper |
| `server/main.lua` | Payment, cooldowns, machine locks |
| `server/versionchecker.lua` | GitHub version check |
| `ui/` | Optional custom `.ogg` sound files (`ui/sounds/`) |
| `locales/*.json` | en, de, el, es, fr, ja, nl, pl, pt-br, ro |

## 2. How it works
- Pay at a coin-operated machine, hand over cash, and the machine reads a random fortune using RDR2 `FTELL` voice lines. Nearby players within `HearingDistance` hear it.
- Configured machines stream in and out by distance (`StreamDistance`); map-placed machines work too (`AutoDetectExistingProps`).
- 72 game fortune lines, optional intro lines and custom `.ogg` files.
- The player is charged only after the voice and animations are loaded, so failures never take money.
- Hand-over animation with a pouch prop, machine glow and prop animation.
- Interaction through rsg-target, falling back to the native `G` prompt.
- Per-machine busy lock and an optional post-reading cooldown.

## 3. Configuration
`shared/config.lua`:
| Option | Default | Meaning |
|---|---|---|
| `Debug` | `false` | Diagnostics and `/fortunetest`, `/fortunespeech` |
| `Price` | `1.00` | Cash per reading (0 = free) |
| `CooldownSeconds` | `0` | Per-machine cooldown after a reading |
| `RequestCooldown` | `2` | Per-player anti-spam seconds |
| `Interaction` | `'auto'` | `auto`, `target` or `prompt` |
| `InteractionDistance` | `2.0` | Range |
| `TargetIcon`, `PromptKey` | moon icon, `G` | Interaction look |
| `Approach` | table | `distance`, `lookHeight` |
| `PrepareTimeoutSeconds`, `MaxReadingSeconds`, `StartDelayMs`, `PauseBetweenLines`, `SpeechPaddingSeconds` | | Timing |
| `HearingDistance` | `25.0` | Who hears the reading |
| `Volume`, `SpeechParam`, `Voices` | | Audio |
| `Model`, `StreamDistance` | `s_fortuneteller01x`, `80.0` | Machine model and streaming |
| `UseConfiguredMachines`, `AutoDetectExistingProps` | `true` | Which machines work |
| `MachineAnim`, `Handover`, `Light` | tables | Effects |
| `CoordinatesCommand` | `'fortunecoords'` | Prints your vector4 for `Config.Machines` |
| `IntroLines`, `CustomLines` | | Extra lines (`.ogg` in `ui/sounds/`) |
| `Machines` | list | Configured machine positions |

## 4. Events and commands
Events are named `rsg-fortuneteller:<side>:<name>`.
| Name | Side | Notes |
|---|---|---|
| `rsg-fortuneteller:server:request` | server event | `(clientKey, x, y, z)` start a reading |
| `rsg-fortuneteller:server:ready` / `failed` | server events | `(id)` client finished preparing / failed |
| `rsg-fortuneteller:client:begin` | client event | `(id, coords, sequence)` |
| `rsg-fortuneteller:client:play` | client event | `(id, coords, sequence, starter)` for nearby players |
| `rsg-fortuneteller:client:stop` | client event | `(id)` |
| `rsg-fortuneteller:client:deny` | client event | `(msgKey, arg)` |

| Command | Who | What |
|---|---|---|
| `/fortunecoords` | everyone | Print your position as a vector4 |
| `/fortunetest <lineId>` | debug only | Play one line |
| `/fortunespeech` | debug only | Speech test |

## 5. Security
Server-authoritative: machine key, distance, price and cooldowns are all checked on the server, with a per-machine busy lock and a per-player anti-spam delay.

## 6. How-tos
- Add a machine: stand at it, run `/fortunecoords`, paste the vector4 into `Config.Machines`.
- Free readings: `Price = 0`.
- Custom voice: add `.ogg` files to `ui/sounds/` and list them in `CustomLines`.

## 7. Troubleshooting
| Problem | Fix |
|---|---|
| No interaction | Check `Interaction` and that rsg-target is running |
| No sound | Speech failed to load (no charge); try again; check `Voices` |
| "Busy" | Another player is using that machine |
| Map machine ignored | `AutoDetectExistingProps = true` |

Support the Project : https://rexshack.tebex.store/
