# Feather Medical

Weapons integration: server `ReadNativeWeaponCondition(source, context)` is a
read-only, Weapons-only current-session condition snapshot for the scoped native
death-wear seal. It performs no initialization, recovery or lifecycle mutation.

Feather Medical lets players wait for help after dying or choose to respawn at
the nearest hospital after a timer ends. Staff can also revive players through
Feather Admin. The timer does not automatically respawn anyone.

Version: **0.1.1**.

## Before you install

You need a working Feather server with these resources installed:

- feather-mysql — the database resource Medical uses.
- feather-core
- feather-toolkit
- feather-character — use the updated version with Medical support.
- feather-admin — use the updated version with Medical support for staff revive.

Keep the other resources your Character system already needs. Older Character
or Admin versions may not work with this Medical version.

Back up your database before installing or updating. If someone manages your
server for you, ask them to make the backup and install the resources together.

## Install

1. Stop the server while installing or updating Character and Admin.
2. Copy the complete `feather-medical` folder into your server's resources folder.
   Keep its name exactly `feather-medical`; avoid an extra folder inside it.
3. Open your server's `server.cfg` file in a text editor.
4. Add `ensure feather-medical` after the start lines for feather-mysql,
   feather-core and feather-toolkit, and before feather-character. Do not remove
   or rearrange unrelated resources that your server already needs.
5. Open `feather-medical/config.lua` if you want to change the defaults. Medical
   is enabled by default; no Medical `setr` lines are needed in server.cfg.
6. Save your changes, then start the server.

Medical creates its database tables automatically. **There is no SQL file to
import.** Medical uses feather-mysql.

Look for this message in the server console:

```text
[feather-medical] storage ready; gameplay staging enabled (live acceptance pending)
```

That message means Medical is enabled and ready. Its wording does not indicate
an error. If you see `gameplay integration disabled`, check `enabled` in config.lua.

## Change the settings

Open **feather-medical/config.lua** in a text editor. Change the values inside
`Config.medical`. Keep commas, quotes and braces as they appear in the file.
Use lowercase `true` or `false`; numbers do not need quotes.

| Setting | Default | What it does |
|---|---|---|
| `enabled` | `true` | Turns Medical gameplay on. False deliberately restores the normal Character/Admin behavior. |
| `persistentDeath` | `true` | Keeps players dead after logging out and returning. **False lets players revive by logging out and back in.** |
| `doctorDelaySeconds` | `120` | Seconds before players may choose hospital respawn. |
| `respawnKey` | `'E'` | The key players press after the timer ends. Use a supported Feather Toolkit key name. |
| `lethalMode` | `'dead'` | Normal death screen. `'incapacitated'` adds a bleed-out period but currently still shows a dead body. |
| `bleedOutSeconds` | `60` | Bleed-out period, only used with incapacitated mode. |
| `temporarySpawnEnabled` | `true` | Allows the old Character spawn if every hospital is disabled. |
| `temporarySpawnPoint` | `'valentine'` | Character spawn used when that fallback is needed. |

For a one-minute wait, change the existing line to:

```lua
doctorDelaySeconds = 60,
```

Use whole seconds. The respawn wait can be zero; bleed-out must be at least one
second. Maximum delay is 604800 seconds (seven days). E is the tested default key.
Save the file, then restart Medical using the commands below. Editing the file
alone does not change the running server. If upgrading from the earlier test
build, remove its `setr feather_medical_*` lines from server.cfg; they are no longer used.

Character and Admin check Medical automatically. If it is not installed, they
keep their normal behavior. If installed but stopped or unavailable, character
activation and staff revival are blocked until it is ready. To deliberately stop
using Medical, set `enabled = false` and restart Medical first; stopping the
resource alone is not the same as disabling it.

## Hospitals

Six hospitals are included and enabled:

- Valentine
- Saint Denis
- Rhodes
- Strawberry
- Blackwater
- Armadillo

Players respawn at the nearest enabled hospital, measured in a straight line
from their position. All six locations and their surrounding areas passed our
reported in-game respawn and ground-placement tests.

Hospital locations are in `feather-medical/config.lua`. You do not need to edit
this file to use the included hospitals. To turn one off, find its entry and
change `enabled = true` to `enabled = false`. Leave the other values unchanged.
Save the file, then restart Medical as described below.

To add a hospital, copy an existing hospital entry and give it a unique `id`,
a readable `label`, and the new location's `x`, `y`, `z` and `heading` values.
`heading` is the direction the player faces. Keep the same commas and braces as
the existing entries; ask your server developer for help if unsure. Test the new
location in game before opening it to players.

If every hospital is disabled, Medical uses the fallback only when its setting
allows it. With no hospital and no fallback, hospital respawn is unavailable;
staff can still revive in place.

A respawn already requested keeps the location selected when it was requested.
Changing hospitals does not move an existing request to another location.

## Update or restart Medical

For Medical-only updates, copy the **whole resource folder**, including its
client, server and web folders. Then enter these commands in the **server console**:

```text
refresh
restart feather-medical
```

The server console is your server's command window or txAdmin Live Console.
It is different from the F8 console inside the game. Restarting Medical reloads
its code and death screen. It does not require restarting Core or Character.

If the update also changes Character or Admin, stop the server and update the
matching resources together, then start it again. Players should be disconnected
while Character is being updated.

With persistent death enabled, restarting Medical or reconnecting does not clear
a player's death. Waiting past zero also leaves the player dead until they choose
respawn or receive a staff revive.

## Check that it works

One player is enough for these checks:

1. Load a character and die near a town.
2. Confirm the countdown appears at the bottom of the screen.
3. Wait until it ends. You should remain dead until you press E.
4. Close any open menus and the F8 console, then press E.
5. Confirm you appear at the nearest hospital, on the ground, with your character's appearance.
6. Test a normal revive through Feather Admin using an authorized staff account.
7. With persistent death enabled, die again, log out and return. You should still be dead.

The death screen does not take control of the mouse. Close other menus before
pressing the respawn key.

## If something goes wrong

| Problem | What to do |
|---|---|
| No death screen | Confirm `enabled = true` in Medical config.lua and restart Medical. Check the startup message. |
| E does nothing | Wait for the timer to end, close menus and F8, then try again. |
| Cannot load a character | Check Medical's server startup output. Medical must be ready before Character can restore the player. |
| Player floats or appears in an unsafe place | Check the hospital coordinates. Disable that hospital for new requests until the location is corrected. |
| Staff revive fails | Check staff permissions and that Medical is running. Use the updated Admin resource. |
| Database or startup error | Save the full error and contact your server developer or Feather support. Do not delete Medical database records to fix it. |

To collect information for support:

- Enter `MedicalHealth` in the **server console** and copy the output.
- With a character loaded, press **F8**, enter `MedicalStatus`, and copy the output.
- Include the startup errors and explain what you did before the problem occurred.

Staff can also enter `MedicalRevive 1` in the **server console** to revive player
server ID 1. Replace `1` with the correct player's server ID.

## What this version includes

This version handles death, the respawn timer, hospital respawn, saved death and
staff revive. Looting, restraints, living unconscious animations, and injury or
ailment treatments are not included. Medical manages life state; Feather Status
manages metabolism.

Death detection comes from the player's game. Medical controls the saved state,
timer and recovery permission on the server, but cannot guarantee that a modified
game client reports physical death honestly.

Normal respawn, ground placement at all six hospitals, staff revive, saved death
and Medical restarts while dead have passed reported live testing. Database retry
and pending-recovery restart tests also passed. Advanced crash, interrupted physical
recovery and multiplayer tests remain separate checks.

Developers can find integration details and diagnostic test instructions in
[the development notes](docs/DEVELOPMENT.md).
