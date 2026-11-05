> Historical pre-cutover documentation only. Not installation or runtime guidance.

# Feather Weapons

Feather Weapons is the database-backed weapon system for the Feather Framework.
Weapons are unique inventory item instances with persistent identity and condition;
equipped state is stored per character. The existing default runtime uses item
ammunition metadata. The separately gated native alpha uses character-owned shared
ammunition pools instead, without per-weapon ammunition quantities.

The shared-pool native path is **disabled by default and development-scoped**, not
a general production cutover. See [native alpha integration](docs/native-alpha-integration.md)
for prerequisites, accepted tests and remaining limitations. When enabled it
quarantines legacy gameplay instead of running both ownership models together.

The 0.17.0 alpha checkpoint covers maintenance, attachment transactions, lifecycle
recovery and scoped evidence integration. See [checkpoint PR/deployment notes](docs/PR_PREPARATION_0.17.0.md).
It requires companion Inventory0.6.0 support and does not enable the native host
or claim production readiness.

Server operation, recovery, integration, and trust boundaries are documented in
[`docs/operations.md`](docs/operations.md).

> **[ WARNING ]**
> This alpha release supports four persistent weapon positions: primary and
> offhand sidearms plus shoulder and back long guns. Sidearms may dual-wield
> with distinct ammunition families; compatible native ammo pools are tracked
> without requiring every equipped weapon to use the same ammunition.

> **[ IMPORTANT ]**
> This is a native-first implementation. RedM owns live draw, fire, reload, and
> contextual controls. Feather owns authorization, Inventory-backed ammunition
> budgets, condition, persistence, and reconciliation.

## Current features

- Equip a weapon by using its item in Feather Inventory.
- Equip a second supported sidearm and use RedM's native dual-wield controls.
- Reject matching-hash equipped pairs; RedM cannot reliably preserve two copies
  through wheel, holster, and character-restoration transitions.
- Support different-model shoulder and back weapons that share a native
  ammunition type while preserving independent item escrow and clips.
- Unequip it by using the same item again.
- Restore the equipped weapon after reconnects and resource or server restarts.
- Finish reconnect and resource-start restoration with equipped guns holstered.
- Reload with the player-remappable `R` key.
- Atomically escrow compatible ammunition into single or dual weapon loadouts.
- Return ammunition from either equipped slot without unequipping the pair.
- Persist loaded ammunition after firing.
- Persist RedM native degradation, permanent degradation, damage, dirt, and soot per weapon instance.
- Select and repair either equipped weapon by using gun oil in Inventory.
- Atomically consume the gun oil and update weapon condition.
- Prevent equipped weapon instances from being moved or destroyed.
- Reject stale, concurrent, invalid, or unauthorized mutations.
- Validate attachment definitions, slots, conflicts, prerequisites, and per-weapon compatibility at startup.
- Resolve active characters through Feather Core Contract 1 sessions.
- Preserve canonical UUID character IDs through issuance, equipment, and Inventory calls.

The configured weapons are the Cattleman and Schofield revolvers using standard
revolver ammunition.

Weapon definition and Inventory item IDs follow `<family>_<model>`; for
example, `revolver_cattleman` and `revolver_schofield`.

## Requirements

- RedM server
- `oxmysql`
- `feather-core` Contract 1 with the session capability
- Current `feather-character` with logout checkpoint support
- Current `feather-inventory` Contract 4 with transactions, item instances,
  named equipment slots, atomic metadata, equipment promotion, guards, and
  canonical character-ID capabilities
- `feather-menu-v2` for weapon modification and repair selection screens

Recommended start order:

```cfg
ensure oxmysql
ensure feather-core
ensure feather-character
ensure feather-inventory
ensure feather-menu-v2
ensure feather-weapons
```

`feather-weapons` now requires the production Feather Inventory provider. The abandoned in-memory fallback has been removed.

Weapons and Inventory require canonical UUID character IDs. Numeric legacy
character IDs are rejected and are not part of the release contract.

## Installation

1. Install compatible versions of Feather Core and Feather Inventory.
2. For an existing alpha database, run
   [`sql/rename_weapon_ids.sql`](sql/rename_weapon_ids.sql) once.
3. Run [`sql/install_items.sql`](sql/install_items.sql) after the Feather Inventory schema and migrations.
4. Confirm `weapon_revolver_cattleman` exists as a unique, usable inventory definition.

Weapon catalog IDs remain `revolver_cattleman` and `revolver_schofield` for
metadata and grant commands. Their Inventory item names are
`weapon_revolver_cattleman` and `weapon_revolver_schofield`.

For existing installations, stop Inventory and Weapons and run
`sql/rename_weapon_item_names.sql` before `sql/install_items.sql`.
The rename preserves numeric item IDs and owned instances; it rejects conflicting rows.

Identical-hash dual wield is intentionally unsupported. A second weapon with
the same native model remains in Inventory but cannot occupy the offhand slot.
Different native models remain fully supported as a dual-wield pair.

5. Ensure the resources in the order shown above.
6. Restart the server; do not use a resource refresh for database migrations.

The installation SQL adds the ammunition catalog, gun oil, and the Cattleman Long Barrel; marks only the weapons, ammunition, and gun oil usable; and enforces unique/stack modes. It is idempotent and can be rerun. Startup fails closed if a required definition is missing, duplicated, or has incompatible usable, type, or instance-mode values.

> [!NOTE]
> Weapon instances are created through the inventory transaction service with unique serials and complete metadata. When `DevMode = true`, authorized staff can issue the configured Cattleman with `/grantweapon revolver_cattleman` in chat, or `grantweapon revolver_cattleman [targetServerId]` from the server console.

Cross-resource issuance is restricted to `Config.Issuance.trustedResources` and
an explicit purpose (`purchase`, `crafting`, `job_issue`, `admin_issue`, or
`recovery`; development grants remain development-only). Optional Core action
`weapons.issuance.issue` can apply future license, job, or shop policy. Callers
cannot authenticate themselves by supplying a resource name.

All non-development issuance requests must also provide a stable `requestId`.
Weapons stores the trusted resource plus request ID in a durable registry. A
committed retry returns the original item and serial with `replayed = true`;
concurrent retries fail closed while the first request is pending. Callers must
reuse the same request ID after timeouts rather than generating a new one.
Each key is permanently bound to its original target character, weapon
definition, and purpose; reusing it with a different payload fails closed.
Request IDs must be 1-128 characters, start with a letter or number, and use
only letters, numbers, dots, underscores, colons, or hyphens. Invalid IDs are
rejected instead of truncated.

If a request is interrupted after Inventory creates the weapon but before its
issuance reservation commits, retrying the same request reconciles the pending
record against the target character's canonical weapon metadata. Recovery only
commits when exactly one matching item exists; missing or ambiguous outcomes
remain fail-closed for operator review.

## Configuration

```lua
Config = {
    DevMode = false,
    RequiredCoreContract = 1,
    RequiredCharacterContract = 1,
    CharacterReadyTimeoutMs = 30000,
    Inventory = {
        requiredContract = 4,
        equipmentSlot = "weapon",
        equipmentSlots = {
            primary = "weapon",
            offhand = "weapon_offhand"
        }
    },
    Runtime = {
        authorizationTtlMs = 5000,
        authoritativeNativeAmmo = true,
        observationIntervalMs = 50,
        checkpointDebounceMs = 250,
        characterRestoreFallbackMs = 6000,
        characterRestoreRetryMs = 2000,
        characterRestoreMaxAttempts = 3
    },
    Escrow = {
        maxTotal = 200,
        refillAmount = 50
    },
    Offhand = {
        enabled = true,
        allowedFamilies = { revolver = true },
        allowedWeaponSlots = { sidearm = true },
        provisionNativeEntitlement = true,
        nativeEntitlements = {
            mp_male = {
                { itemName = "CLOTHING_ITEM_M_OFFHAND_000_TINT_004", slotId = 0xF20B6B4A },
                { itemName = "UPGRADE_OFFHAND_HOLSTER", slotId = 0x39E57B01 }
            },
            mp_female = {
                { itemName = "CLOTHING_ITEM_F_OFFHAND_000_TINT_004", slotId = 0xF20B6B4A },
                { itemName = "UPGRADE_OFFHAND_HOLSTER", slotId = 0x39E57B01 }
            }
        },
        primaryAttachPoint = 2,
        offhandAttachPoint = 3
    },
    Attachments = {
        requireStation = true,
        interactionDistance = 2.0,
        serverTolerance = 3.0,
        stations = {
            valentine = {
                label = "Valentine Gunsmith Bench",
                coords = vector3(-277.455, 779.197, 119.504)
            }
        }
    },
    Controls = {
        unload = {
            enabled = true,
            defaultKey = "U",
            command = "feather_weapon_unload"
        },
        modify = {
            enabled = true,
            defaultKey = "F6",
            command = "weaponmods"
        },
        ammunition = {
            enabled = true,
            defaultKey = "F7",
            command = "weaponammo"
        }
    }
}
```

`Offhand.enabled` controls native sidearm dual wield. The two allowlists use weapon
definition `family` and `slot` values; only entries set to `true` are accepted.
Keep automatic entitlement provisioning enabled unless another resource owns
RedM's offhand holster unlock. Testing confirmed that the upgrade entitlement
alone is insufficient: RedM also requires an offhand clothing entitlement.
Testing the available tint variants produced no visible cosmetic difference,
so Feather treats this item as a native inventory marker rather than character
styling. `nativeEntitlements` is keyed by the supported multiplayer character
model so male and female characters receive their matching wardrobe component.
It remains server-owned. Replace a clothing item only after testing the
alternative in game. Attach-point values should only be changed for a tested
setup.

`data/weapon_holsters.meta` applies RedM's required short-arm holster-depth
override for the M1899 pistol. This native metadata correction controls how that
model sits in equipped holsters; it does not change Feather's logical loadout
slots. Other pistols remain on their native defaults unless live testing proves
that a model-specific correction is required.

Startup always fails closed when required dependencies, definitions, or contracts are unavailable. Weapons verifies that Feather Character is ready and exposes the required profile, activation, and spawn capabilities before registering its runtime. `Inventory.requiredContract` must match the contract feather-inventory reports from `GetCapabilities().value.contractVersion` -- it is checked before any definition, usable callback or guard is registered, and a version below it aborts installation rather than degrading to an empty index.

The normal Character runtime-ready signal restores equipped weapons. A bounded,
idempotent fallback retries restoration when that one-time signal is missed.
Weapons-only restarts open the same fallback window and retry the client-ready
handshake after server listeners finish loading. The fallback is cancelled on
logout and never applies a completed loadout twice.

`DevMode` enables diagnostic output and development-only weapon grants; disable it on production servers. Keep `authoritativeNativeAmmo = true` when Feather Weapons owns all weapons and ammunition. At weapon boundaries, this clears the player's native ammo—including ammo granted by other resources—before restoring the equipped inventory item's saved rounds.

Trusted server resources issue unique weapons through the stable named export:

```lua
local result = exports['feather-weapons']:IssueWeapon(request, context)
```

## Recovery commands

The following commands are server-console only:

- `WeaponMetadataInspect [serverId]` validates both named Inventory weapon slots
  and reports each serial, ammunition state, condition, attachments, generation,
  and runtime match.
- `WeaponReconcile [serverId]` discards unaccepted native state and restores the
  character's accepted primary/offhand/shoulder/back Inventory snapshots with new lease
  generations.

Run the inspection command first. Reconciliation is an explicit recovery action,
not routine gameplay synchronization.

Players can change Feather's registered bindings in their Cfx key-binding settings. Unload defaults to `U`, weapon modifications to `F6`, and ammunition management to `F7`. Reload remains the native RedM `R` action and is not registered or intercepted by Feather. The menus can also be opened with `/weaponmods` and `/weaponammo`.

## Gameplay

### Equip and unequip

Use a weapon item to equip it. Use that same item again to unequip it. When the
configured offhand policy permits the weapon, using a second sidearm equips it
in the offhand slot. Long guns fill shoulder and back. Using the primary item promotes the offhand weapon; using
the offhand item removes only that slot.

### Reload

Use a compatible ammunition stack while a matching weapon is equipped to
transfer cartridges transactionally into bounded weapon escrow. With two
weapons equipped, the less-stocked slot is filled first; repeated uses can fill
both slots. Refilling an empty revolver loads its cylinder when RedM grants the
positive native pool. After firing, press native `R` to reload. Feather observes
and persists each loaded/reserve distribution without intercepting the key.

### Unload

Press `U` with one or two weapons equipped. The server checkpoints the active
loadout, returns the better-stocked slot's loaded and reserve cartridges to
Inventory, and updates its metadata in one transaction. Repeated uses drain the
other slot as well.

### Ammunition management

Press `F7` or use `/weaponammo` to select a specific equipped weapon. The menu
shows its ammunition type and exact loaded, reserve, and total ownership. Load
up to one 50-cartridge Inventory stack into that slot, unload up to 10
cartridges, or unload the slot completely. Every action shows the exact amount
that can move and the menu refreshes on the selected weapon after it completes.
An in-menu activity indicator remains visible while Inventory and native weapon
state are synchronized, preventing duplicate ammunition requests.
Load choices are limited to compatible ammunition the character currently
owns. Selecting a different owned type atomically returns the current load and
loads the chosen cartridges. Shared native ammo pools do not change per-weapon
Inventory ownership.

### Condition and repair

Weapon condition is derived from RedM's native maintenance state; ammunition
checkpoints never apply condition wear. Use `gun_oil` from Inventory to clean
soot and dirt and restore degradation up to the weapon's permanent wear floor.
Definitions do not declare deterministic per-shot wear because that would
double-count RedM's native degradation. When multiple weapons are equipped,
choose the primary, offhand, shoulder, or back weapon from the repair menu.
Full-condition, stale-slot, and invalid repairs do not consume a kit.

### Weapon modifications

Attachment installation and removal require proximity to a configured gunsmith bench. Equip the weapon at the Valentine bench, then press `F6` or use `/weaponmods` to install an owned compatible attachment or remove an installed one. The Long Barrel is not a usable item; the server verifies distance and ownership before starting the Inventory transaction.

`Attachments.authorization.enabled` can route every install and removal through
Feather Core's policy provider using the configured action (default
`weapons.attachments.modify`). The policy receives the operation, station,
weapon definition, and attachment ID, allowing an Authority-backed domain or jobs
resource to enforce gunsmith access. Authorization is unrestricted by default
and fails closed when enabled without an available policy decision.

Modification menus label definition-driven native defaults for empty component
slots. These labels describe the weapon's built-in baseline and never create or
return Inventory items.

## Current revolver settings

| Setting | Value |
| --- | --- |
| Capacity | 6 rounds |
| Escrow ceiling | 200 rounds per shared native ammunition pool |
| Managed load action | Up to 50 rounds |
| Ammunition | Standard revolver cartridges |
| Maximum condition | 100 |
| Wear | RedM native degradation (usage and environment) |
| Equip minimum | 1 condition |
| Repair cost | 1 gun oil |
| Repair result | Clean to the native permanent-degradation floor |

## Persistence

| Event | Result |
| --- | --- |
| Character reconnect | Equipped weapon, loaded ammo, and condition restore |
| `feather-weapons` restart | Equipped state restores from the database |
| Server restart | Equipped state and item metadata restore from the database |
| Failed transaction | Ammo, repair materials, and metadata remain unchanged |
| Concurrent stale mutation | Rejected by inventory revision checks |

## Development diagnostics

When `DevMode = true`, `/weaponstate` prints the authoritative equipped item ID, loaded ammunition, and condition to F8. Normal equip, reload, unload, and repair testing uses gameplay interactions rather than test commands.

The read-only `WeaponRuntimeLeaseSmokeTest`, `WeaponDualSlotContractSmokeTest`,
`WeaponAttachmentContractSmokeTest`, `WeaponOwnershipTransitionSmokeTest`, and
`WeaponReleaseContractSmokeTest` commands remain available from the server
console with `DevMode` disabled. The attachment check validates active component
sets, native mappings, item/slot identity, runtime lease scope, and optional
authorization configuration without mutating weapons or Inventory.

`WeaponOwnershipTransitionSmokeTest [itemInstanceId]` validates the most recent
cross-container weapon move observed from Inventory's committed event. It checks
weapon definition and serial identity, origin/destination inventories, and that
no equipped lease bypassed the registered movement guard.
It also verifies that ordinary weapon metadata remains movable while evidence
and administratively disabled states are rejected by Weapons policy.
Committed facts label explicit `transfer`, `drop`, and `recovery` reasons and
use the actor's character inventory to distinguish `pickup` and `deposit`.
Ambiguous container movement remains labeled `inventory_move`.

`WeaponPlayerTransferSmokeTest [itemInstanceId]` validates Inventory's existing
give flow for an unequipped firearm. It requires both active character owners
to resolve, preserves the weapon serial, and rejects any transfer observation
that coincided with an active lease violation.

`WeaponDestructionContractSmokeTest` checks the trusted destruction surface,
authorization configuration, rejection behavior, and provider capability
without deleting an item.

In development mode, the server-console-only
`WeaponDestroyTest <source> <itemInstanceId> <serialNumber> DESTROY` command
permanently removes one exact, unequipped test weapon. The mandatory serial and
confirmation token make the destructive target explicit.
`WeaponDestructionAuditSmokeTest <itemInstanceId> <serialNumber>` then validates
the captured terminal ownership fact without performing another mutation.

Trusted server resources may permanently destroy an exact unequipped weapon
through `DestroyWeapon(request, context)`. The request must include the owning
character UUID, item instance ID, and expected serial. Calls fail closed for an
untrusted resource, stale serial, equipped weapon, evidence hold, disabled
weapon, invalid metadata, or denied optional Core authorization.

The ammunition and modification menus display each equipped firearm's persisted
serial number. The same serial is included in `weaponstate` diagnostics for
primary, offhand, shoulder, and back slots.
Development grants and native probes remain disabled.

Issuance, cross-inventory ownership transitions, and destruction are also
written to the append-only `feather_weapon_events` ledger. Trusted resources
may call `InspectWeaponHistory` with an `itemInstanceId` or `serialNumber` and
an optional bounded `limit` (maximum 100) to retrieve the current item, terminal
state, and newest-first audit history. Run `WeaponProvenanceContractSmokeTest`
from the server console to verify the read-only contract.

History is private to resources explicitly listed in
`Config.Ownership.trustedResources`. `Config.Provenance.maxInspectionEvents`
bounds each query. `retentionDays = 0` is the safe default and retains the
append-only audit indefinitely; Weapons does not silently purge ownership
history.

Trusted resources may place or release an exact unequipped character-owned
weapon under evidence hold through `HoldWeaponEvidence` and
`ReleaseWeaponEvidence`. Both require the canonical character UUID, item
instance ID, and expected serial. Held weapons fail closed for equip, ordinary
movement, and ordinary destruction; the canonical item is mutated in place and
each state change is appended to the provenance ledger. Optional Core actions
are configured as `weapons.evidence.hold` and `weapons.evidence.release`.

## Known limitations

- The Cattleman Long Barrel and Wide Sight and the Schofield Short Barrel and
  Wide Sight are live-validated functional attachment slices. Broader model
  compatibility remains unfinished. The LeMat Long Barrel and Wide Sight are
  also live-validated functional attachment slices. The Navy Long Barrel and
  Wide Sight are live validated as well. The Double-Action Long Barrel and Wide
  Sight are live validated as well. The M1899 Long Barrel and Wide Sight are
  live validated as well. The Volcanic Long Barrel and Wide Sight are live
  validated as well. The Semi-Automatic Long Barrel and Wide Sight are live
  validated as well. The Mauser Long Barrel and Wide Sight are live validated
  as well. The Carbine, Lancaster, and Litchfield Wide Sights are live
  validated as well. The Evans, Springfield, and Bolt Action Wide Sights are
  live validated as well. The Varmint Wide Sight is live validated as well. The
  Elephant Long Barrel and Wide Sight are live validated as well. The Rolling
  Block and Carcano Wide Sights are live validated as well. The Repeating
  Shotgun Long Barrel and Wide Sight are live validated as well. The Pump-Action
  Long Barrel and Wide Sight are live validated as well. The Semi-Auto Shotgun
  Long Barrel and Wide Sight are live validated as well. The Double-Barreled
  Shotgun Long Barrel and Wide Sight are live validated as well. The Sawed-Off
  Shotgun Wide Sight is live validated as well.
- Alternate ammunition, expanded provenance, evidence, licenses, shops, and crafting remain planned.

## Validation status

The current release has passed Inventory Contract 4 startup gates, unique
issuance, both equip orders, alternating fire/reload, per-item condition,
slot-aware repair and attachments, movement guards, reconciliation, entitlement
recovery, reconnect/resource/server restart, Admin operations, and two-player
isolation. Matching-hash pairs are rejected by policy. Different-hash sidearm
pairs, all four logical slots, and primary-only behavior remain regression tested.
The female Cattleman/Schofield pair has also passed visible offhand entitlement
provisioning and cleanup, alternating fire, automatic holster reload,
logout/reselection, resource restart, and full server restart checks without
changing unrelated clothing.
The Sawed-Off passed its two-round capacity, regular/slug switching, unload
conservation, repair, and restart matrix. The LeMat passed its nine-round
cylinder and safely inert unsupported shotgun-barrel boundary. Varmint regular
and tranquilizer ammunition passed shoulder restoration and exact returns. The
Elephant Rifle passed its 20-round Nitro Express ceiling, back-slot isolation,
and dual-long-gun restart restoration. Weapons-only restarts now restore
long-gun-only loadouts after the server/client listener startup race.
The M1899 passed its model-specific holster placement, eight-round pistol
capacity, reload, restart, and unload checks. The Pump Shotgun passed its
five-shell cycling, native wear, reload, restart, and conservation checks. The
Rolling Block passed scoped aiming, one-round automatic reload, restart, and
unload checks. Different-model repeaters sharing `AMMO_REPEATER` passed
independent loading, firing, controlled reload, restart, and exact combined
unload conservation; shared-ammo long guns are supported.

## Attachment phase

The first attachment vertical slice uses a Cattleman Long Barrel inventory item
mapped to `COMPONENT_REVOLVER_CATTLEMAN_BARREL_LONG`. Open `/weaponmods` or press
`F6`, choose an equipped weapon slot, then install
or remove the component. Both operations validate the selected slot lease,
commit atomically, and rebuild the approved native pair without changing saved
ammunition or condition.

## Developer API

```lua
local Weapons = exports["feather-weapons"]:initiate()
local capabilities = Weapons.GetCapabilities()
```

Server capabilities expose definition reads, metadata validation, runtime state, and feature availability. Client methods expose equip, unequip, reload, repair, and reconciliation requests.

Operations return a consistent result envelope:

```lua
{ ok = true, value = value, correlationId = correlationId }
```

```lua
{
    ok = false,
    error = {
        code = "WEAPON_ERROR_CODE",
        message = "Human-readable message",
        details = {}
    },
    correlationId = correlationId
}
```

## Next milestones

1. Complete the per-model live matrix for the remaining firearm families.
2. Expand the weapon catalog one tested family at a time.
3. Add ammunition types and complete the modification catalog.
4. Add transfers, storage, evidence, destruction, and recovery flows.
5. Integrate shops, licenses, jobs, and crafting through public contracts.

See the centralized
[Weapons expansion master plan](https://github.com/DavFount/feather-framework-docs/blob/main/feather-weapons/FEATHER_WEAPONS_MASTER_PLAN_NEXT.md).
The completed native-first architecture and validation record remains in the
[Weapons master plan](https://github.com/DavFount/feather-framework-docs/blob/main/feather-weapons/FEATHER_WEAPONS_MASTER_PLAN.md).
