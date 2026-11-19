# rsg-housing

Monthly house rentals for the RSG Framework (RedM). Players rent a house directly at the property, pay rent every calendar month and are evicted if they don't pay. Everything is managed from an NUI panel at the house.

## Features

- **Rent at the property.** Walk up to a house, press **[J]**, and rent it. The first month is paid up front in cash.
- **Calendar-month rent.** Rent is due on the same day each month. Tenants pay at the house and can be at most one month ahead.
- **Reminders and eviction.** A telegram (and on-screen alert if online) goes out a few days before rent is due. If rent isn't paid within the grace period the tenant is evicted, all keys are removed and the house goes back on the market.
- **Viewings.** Doors of vacant houses stay unlocked so players can look around before renting. Renting locks them; ending a tenancy unlocks them again.
- **Doors.** Tenants and guests lock/unlock with a hold prompt. The player turns to face the door and plays a key animation.
- **Guests with per-guest access.** Search players by name and give them a key, then choose what each guest can use: **Doors**, **Storage**, **Wardrobe** and **Mailbox**. Each is a simple on/off toggle in the guest list and is enforced on the server.
- **Storage with upgrades.** Small storage is included; Medium and Large are paid upgrades that last for the tenancy. Storage is emptied when a tenancy ends; belongings can be collected for a few days (see below).
- **Wardrobe.** Change into any outfit saved with rsg-character.
- **Mailbox.** Read and delete your rsg-telegram inbox at home (sending stays at the post office).
- **Rename the house.** The custom name shows on the panel, map blip and door prompt.
- **At Home status.** Tenants can mark themselves home; the house blip changes colour for everyone. It switches back to Away automatically if the tenant leaves or logs off.
- **Decorating.** Tenants place furniture with rsg-gizmo (chairs, tables, cabinets and more from `Config.DecorProps`). Aim at a placed item to move it or remove it for a partial refund. Furniture is saved per house and removed when the tenancy ends.
- **Time-limited keys.** Pick how long a guest key lasts (until removed, 24 hours, 7 days by default). Expired keys are cleaned up automatically.
- **Knock on the door.** Visitors without a key knock instead of getting an error; the tenant is told if they are online.
- **Rent reminders at login.** Tenants are told when rent is due soon or overdue as soon as they log in.
- **Belongings kept after eviction.** Evicted (or departed, if configured) tenants can collect their storage for a few days with `/housebelongings` at the house.
- **Early-exit refund.** Optionally refund part of the unused rent when a tenant ends the tenancy early.
- **/myhouse** draws a GPS route to your house (run it again to clear).
- **Map blips** for vacant, rented, your own and "home" houses (all configurable).
- **Movable panel.** Drag the header to move it (position is remembered); double-click the header to reset.

## Dependencies

- [rsg-core](https://github.com/Rexshack-RedM/rsg-core)
- rsg-target and rsg-gizmo (furniture placement and the move / remove options)
- [oxmysql](https://github.com/Rexshack-RedM/oxmysql)
- [rsg-inventory](https://github.com/Rexshack-RedM/rsg-inventory)

Optional (features switch off cleanly if they aren't running):

- [rsg-character](https://github.com/Rexshack-RedM/rsg-character) – saved outfits for the wardrobe
- [rsg-wardrobe](https://github.com/Rexshack-RedM/rsg-wardrobe) – cleanly changes the player into an outfit
- [rsg-telegram](https://github.com/Rexshack-RedM/rsg-telegram) – mailbox and rent telegrams
- rsg-bossmenu – only if `Config.EnableGovernor = true` (the old `EnableGovenor` name still works)
- rsg-log – eviction logs

## Installation

1. Put `rsg-housing` in your resources folder and add `ensure rsg-housing` to your server config, **after** the dependencies above.
2. Start the server. Tables are created automatically on first start. To install manually, set `Config.AutoDatabase = false` and import `installation/rsg-housing.sql`.
3. Adjust `shared/config.lua` (rent rules, storage tiers, blips) and set each house's rent in `/houseadmin` (see **Admin** below).

Houses you add to `Config.Houses` get a database row automatically when the entry has `region = '...'` (optional `rent = 50`); otherwise the console warns that the house cannot be rented until a row exists. The script also adds any new columns to existing `rsg_housing` / `rsg_housekeys` tables on start, so updates don't need manual SQL. Guests that existed before the permissions update keep full access.

## How it works for players

| Who | At the house menu [J] |
|---|---|
| Anyone (vacant house) | See the monthly rent and terms, rent the house |
| Tenant | Rent status and Pay Rent, At Home switch, Guests, Storage (open / upgrade), Wardrobe, Mailbox, Rename House, End Tenancy |
| Guest | Only what the tenant allowed: Storage (open), Wardrobe, Mailbox (and the doors) |
| Anyone else (rented house) | "This house is already rented" |

## Configuration (`shared/config.lua`)

| Setting | Default | Description |
|---|---|---|
| `MaxHousesPerPlayer` | `1` | Houses a player can rent at once |
| `GracePeriodDays` | `3` | Days after the due date before eviction |
| `ReminderDays` | `3` | Reminder telegram this many days before rent is due |
| `RentCheckCronJob` | `'0 * * * *'` | How often reminders/evictions are checked (hourly) |
| `MaxRent` | `1000000` | Highest rent an admin can set |
| `AutoDatabase` | `true` | Create/update tables on start. Set `false` to import `installation/rsg-housing.sql` manually |
| `MaxGuests` | `8` | Max guests (keys) a tenant can give out per house |
| `GuestSearchScope` | `'nearby'` | Guest search: `'nearby'` (online players close to you), `'online'`, or `'all'` characters |
| `GuestSearchDistance` | `25.0` | Range for the `'nearby'` search |
| `GuestDurations` | `{ 0, 24, 168 }` | Key lengths in hours the tenant can choose (0 = until removed) |
| `AllowKnock` / `KnockCooldown` | `true` / `20` | Knocking for visitors without a key, and seconds between knocks |
| `LoginRentReminder` | `true` | Remind tenants about due / overdue rent at login |
| `RetrievalDays` | `3` | Days belongings can be collected after eviction (0 = delete at once) |
| `PurgeStorageOnLeave` | `true` | `false` keeps a departing tenant's storage for `RetrievalDays` |
| `EndTenancyRefundPercent` | `0` | % of unused rent refunded when ending the tenancy early |
| `Decorating` | `true` | Allow tenants to place furniture |
| `MaxPropsPerHouse` | `25` | Furniture limit per house |
| `PropPlaceRadius` / `PropStreamDistance` | `40.0` / `80.0` | How far from the house furniture may be placed (server checked) / spawn range |
| `PropRefundPercent` | `50` | % refunded when a tenant removes furniture |
| `DecorProps` | 12 items | Furniture list: `key`, `label`, `model`, `price` |
| `AllowPushToTalkWhileOpen` | `true` | Keep push-to-talk working while the panel is open |
| `PushToTalkControls` | push-to-talk | Controls left enabled while the panel has focus |
| `AdminPermission` | `'admin'` | rsg-core permission needed for `/houseadmin` |
| `InteractDistance` | `5.0` | Server-checked distance from the house menu for renting, paying, storage etc. |
| `MenuPromptDistance` | `1.5` | Distance the [J] prompt appears at |
| `HouseNameMin` / `HouseNameMax` | `3` / `30` | Custom house name length |
| `GuestSearchMin` / `GuestSearchResults` | `2` / `6` | Guest search: letters before searching, results shown |
| `GuestDefaultPermissions` | all `true` | What a newly added guest can use (`doors`, `storage`, `wardrobe`, `mailbox`); the tenant can change each guest afterwards |
| `WardrobeResource` | `'rsg-wardrobe'` | Wardrobe resource name |
| `TelegramResource` / `MailboxMax` | `'rsg-telegram'` / `50` | Telegram resource name, telegrams shown in the mailbox |
| `HomeAutoAwayDistance` | `75.0` | Tenant is set to Away past this distance (0 = never) |
| `HomeCheckInterval` | `15` | Seconds between automatic Away checks |
| `Blips` | | Sprite and colour for `vacant`, `mine` (away), `rented` (someone else, away) and `home` |
| `StorageTiers` | Small / Medium / Large | Slots, weight (grams) and price of each storage size |
| `OwnedHouseBlips` | `false` | Only show the player's own house on the map |
| `PurgeStorageOnLeave` | `true` | Delete storage when a tenant moves out (evictions always delete it) |
| `EnableGovernor` / `GovernorJobs` | `false` | Pay rent and upgrades into a region's governor boss account |
| `Houses` | | Each house: `name`, `houseid`, `menucoords`, `blipcoords`, `showblip` |
| `HouseDoors` | | Each door: `houseid`, `name`, `doorid` (door hash), `doorcoords` |

Storage weights are in grams like rsg-inventory (1000 = 1 kg). rsg-inventory caps stashes at its own `Config.Stash.MaxSlots` / `MaxWeight`.

### Adding a house

1. Add an entry to `Config.Houses` and its doors to `Config.HouseDoors`.
2. Add a row to the `rsg_housing` table with the same `houseid`, its `region` and the monthly `rent`.

### Governor accounts

With `EnableGovernor = true` (the old `EnableGovenor` name still works), rent and storage upgrades are paid to the rsg-bossmenu job set for the house's region in `GovernorJobs` (`govenor1` – `govenor5` by default). Those jobs must exist in your job setup.

## Languages

All text (notifications, prompts, telegrams and the whole NUI) comes from `locales/`. Included: English (`en`), German (`de`), Greek (`el`), Spanish (`es`), French (`fr`), Japanese (`ja`), Dutch (`nl`), Polish (`pl`), Brazilian Portuguese (`pt-br`) and Romanian (`ro`).

The language follows rsg-core's locale setting (`rsg:locale` convar), for example in your server config:

```
setr rsg:locale de
```

To add a language, copy `locales/en.json` to `locales/<code>.json` and translate the values. Keep every `%s` in the same order, and keep `**bold**` markers and `~e~` / `~t6~` / `~q~` colour codes as they are.

## Admin

`/houseadmin` (needs the `Config.AdminPermission` permission, `admin` by default) opens the housing admin panel.

**All properties.** Every house with its tenant, rent and rent status. Click the Total / Rented / Vacant / Overdue counters to filter, or search by house, custom name, tenant, citizen ID or region. Overdue houses are marked in red.

**House details.** Click a house to:

- change the monthly rent (applies from the tenant's next payment)
- move the rent due date by a month either way, or set an exact date (today or later; a past date would evict the tenant on the next rent check)
- evict the tenant, keeping their belongings for retrieval or deleting them (the tenant gets a telegram)
- change the storage size (no charge; going smaller is refused while items sit in slots the smaller size doesn't have)
- lock or unlock the doors
- teleport to the house or open its storage
- reset a custom house name
- remove guests

Every admin change is sent to rsg-log (`rsghousing`). Rent can't be set above `Config.MaxRent`.

To change every house at once, run SQL such as:

```sql
UPDATE rsg_housing SET rent = 50;
```

## Commands

| Command | Who | What it does |
|---|---|---|
| `/myhouse` | everyone | GPS route to the house you rent (again to clear) |
| `/housebelongings` | former tenants | Open the belongings kept after your tenancy ended (stand at the old house) |
| `/houseadmin` | admins | Open the admin panel |

Adding houses: give the entry in `Config.Houses` a `region = '...'` (and optional `rent = 50`) and it gets its database row automatically.

## For developers

Other scripts can read and control houses through server and client exports and hook events (`houseRented`, `rentPaid`, `tenancyEnded`, `guestAdded`, `guestRemoved`). See **DOCS.md** for every export with examples. Version history is in **CHANGELOG.md**.

```lua
local ok = exports['rsg-housing']:HasHouseAccess(citizenid, 'house1', 'storage')
```

## Troubleshooting

- **"Table doesn't exist" on start:** the script creates its tables itself; check oxmysql is started before rsg-housing and the database user can `CREATE` and `ALTER` tables.
- **Mailbox or wardrobe says unavailable:** rsg-telegram / rsg-wardrobe isn't started (or `Config.TelegramResource` / `Config.WardrobeResource` don't match their folder names).
- **Blip colours look wrong:** change the `colour` modifiers in `Config.Blips`.
- **`/houseadmin` does nothing:** the player needs the `Config.AdminPermission` permission in rsg-core.

## Database

| Table | Purpose |
|---|---|
| `rsg_housing` | One row per house: region, tenant, rent, due date, custom name, storage tier |
| `rsg_housekeys` | Keys: the tenant (`guest = 0`) and their guests (`guest = 1`), with each guest's `perm_doors`, `perm_storage`, `perm_wardrobe`, `perm_mailbox` and optional `expires` |
| `rsg_housing_props` | Furniture placed in each house |
| `rsg_housing_retrieval` | Belongings waiting for a former tenant |

House storage is an rsg-inventory stash named `house_<houseid>`. The mailbox reads `rsg_telegrams` (rsg-telegram) and the wardrobe reads `playeroutfit` (rsg-character).

## Security

All money, keys, storage and doors are handled on the server. Prices come from the database/config, never from the client. Every action checks the player's key/tenancy, the guest's permission for that feature, and distance to the house, purchases are atomic (no double-renting or double-spending) and actions are rate limited. Every admin action is re-checked for permission on the server.

## Support

If you find this useful, you can support development here: https://buymeacoffee.com/rexshack

## rsg-economy integration

Optional. With `rsg-economy` started, rent and storage upgrade payments are also deposited into the treasury of the town nearest to the house (`Config.Economy`). With `ReplaceGovernor = true` the treasury is used instead of the governor boss account. Set `Config.Economy.Enabled = false` to turn it off.


Support: https://rexshack.tebex.store
