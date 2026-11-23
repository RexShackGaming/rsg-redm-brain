# Feather Weapons

Current version: **0.26.0**. See [release notes](docs/release-0.26.0.md).

Regular throwing knives and validated specialty ammunition use the character
ledger, paired with Inventory **0.18.0**. Regular/Poison knives share one native
carrier with independent eight-unit pools; Poison recovery becomes Regular.
Small Game, Poison, Fire and Dynamite arrows keep independent quantities.
These additions are opt-in; see the release notes for startup settings and
recovery limits. Specialty-arrow recovery and Improved variants remain disabled.

## Regular arrows

`setr feather_regular_arrows 1` opts the current native runtime into owned bows
and the 40-unit Regular-arrow character pool. Bows use their native Shoulder8 /
Back7 carry points. The default Bow offer is $5; Regular arrows retain their
$0.50 five-arrow pack. Native recovery consumes a separate, once-only funded
arrow allowance within180seconds/50metres in the same routing bucket; it never
issues a bow or an extra native ammunition grant. Deploy with the matching
Inventory recovery and Shops Bow-category changes. Persist the flag before
startup while using this pool; disabling it is not a saved-data migration.

Own/batched/cross-player recovery, recovered-arrow reselection, loaded death/
revive/restart, both carry positions and 40-unit capacity controls are live
accepted. Specialty arrows remain outside this admission; simultaneous increases
of arrow and Tomahawk pools fail closed. Live competing collectors remain untested.
See [the integration record](docs/regular-arrow-integration.md) for evidence.

## Gun-store configuration

`shop_config.lua` owns gun-store locations and all firearm, ammunition, attachment
and gun-oil prices. Shops imports this server-only catalog; checkout/payment and
recovery still use the existing Inventory-owned atomic transaction. Requires the
matching Shops package-order and Inventory package-delivery changes together.

Prices are dollar amounts (`12.00`, not `1200`). Ammunition prices apply to one
box: `ammo_revolver_regular = { price=0.80, rounds=50 }`. Set an entry to `false`
to hide it; an ammunition table may also use `price=false`. Box purchases deliver
the exact existing loose-round items, with no additional box item or unpack step.
Pistol/revolver and repeater defaults are 50 rounds, rifle 20, varmint 50 and
shotgun 25. Specialty quantities/prices are editable gameplay estimates. Defaults
are historical-based, not a claim of exact historical prices for every item.

The initial Valentine store has 24 firearms, 43 ammunition offers, 38 components
and gun oil. The other 25 weapon entries stay explicitly disabled until their
canonical shop issuance is supported. Adding a price cannot bypass that boundary.
One order delivers at most 100 items; the box selector is capped automatically.
Store position is configurable and still needs a live access check.

Use the existing framework safe-stop/deployment flow before changing running
resources. Restart Shops after a changed Weapons catalog is loaded; stopping the
catalog owner closes Shops admission until it is restarted. No automatic purchase
replay or catalog change rewrites historical orders. Each player's language is
resolved through feather-settings/Core, with English fallback. Store/item label
translation keys are `ui_shops_store_<store UUID>` and `ui_shops_item_<item name>`.

Current version: **0.24.0**. Adds melee commerce and opt-in quantity Tomahawk recovery; pair with Inventory **0.16.0** and Shops **0.4.1**.

Feather's native-only, Inventory-backed firearm system. Weapons are unique
item instances; equipped assignments and maintenance persist per character.
Ammunition belongs to the character's shared pools, not individual weapons.

There is no legacy gameplay fallback, old-item conversion or alternate test
manifest deployment. Disabling native flags refuses startup instead of selecting
a different host. Preserve existing native test data until cutover verification;
no old-item conversion or database wipe is performed. Owned schema tables and
compatible columns initialize automatically at startup.

## Current supported scope

Weapons access is available to all current player characters, with no character
allowlist. [All-player access and startup boundaries](docs/native-rollout-admission.md)
describes the current rollout stage. Normal startup/equipment/wear no longer
require DevMode; native runtime/feature switches and canonical Inventory
requirements still apply. The paired Inventory update initializes eligible fresh
characters with zero ammunition. Broader live acceptance remains pending. Supported native firearms
use primary/offhand/shoulder/back positions, character ammunition, maintenance,
repair, admitted saved attachments, guarded ownership movement/provenance,
scoped evidence and receipt-backed pristine issuance.

Live controlled coverage includes two-player isolation, death/doctor recovery,
prepared resource/server restart, aggregate connected-owner drain, unequipped
give/return, equipped give refusal feedback, native issuance/replay/reconnect,
historical replay after transfer, and a same-model Cattleman pair with unequal
permanent wear and separate saved attachments. The pair passed reconnect,
independent attachment removal/returns, Swap hands, and Primary removal with
automatic Offhand promotion.

Limits remain: full non-firearm catalog/interaction parity, destruction, other
customized firearm pairs, larger multiplayer scale, automatic shutdown interception, simultaneous SQL
contention and abrupt/in-flight crash outcomes are not generally accepted.
Admin roles and permissions are not changed by this work.


The current alpha includes eight utility positions covering lasso variants,
Davy Lantern, standard/improved binoculars, standard/advanced cameras, Metal
Detector and Fishing Rod. Controlled acceptance covers equip/unequip isolation,
selection/draw, lifecycle restoration and two-player conservation; resource-specific
photography, collection and fishing reward systems are separate integrations.

Inventory moves now queue immutable ownership facts. Weapons stores each move's
provenance and deduplication receipt atomically, so a repeated delivery returns
the original event IDs. Matching Inventory and Weapons versions must be deployed
together while the host is prepared/stopped; do not combine an old observer with
the new producer. Arbitrary event subscribers remain best-effort.

Automated lifecycle checks, outcome/delivery recovery, retention/health checks
and prepared full-server/MariaDB restart scenarios have passed with the enrolled
test characters and recorded visual acceptance. Prepared restart success does
not certify power loss or arbitrary economic COMMIT interruption. Required
receiver receipts and provenance are retained; do not purge them as cleanup.

## Deployment and configuration

Use with Feather Inventory **0.14.0** for the new sidearm equipment controls;
deploy the matching updates together. Existing native data is preserved.

See [current equipment installation](docs/equipment-installation.md) for the
tested pair/controls update and configuration-preserving deployment scope.

Use only the root `fxmanifest.lua`. Shipped defaults enable the required
NativeAlphaRuntime, CharacterAmmunitionEnabled and CharacterAmmoTransportEnabled
settings. Inventory must also enable CharacterAmmunitionEnabled (its shipped
default). All current characters have access, subject to canonical item ownership
and session checks. No character allowlist or DevMode is required. Development
mode and experimental feature/test gates remain disabled. Preserve customized config
values when updating; explicitly disabled required runtime settings refuse startup.

Lifecycle wear saving also defaults on (`NativeAlphaLifecycleWearEnabled=true`).
It saves each firearm's observed wear before equipment changes, orderly shutdown,
character logout and supported death recovery. An existing config with this set
to `false` must be updated to retain newly acquired wear across those rebuilds.
Gun-oil cleaning also defaults on (`NativeAlphaRepairEnabled=true`). Periodic
sampling remains opt-in; development mode is not required for these gameplay paths.

Exact GUID ownership defaults on automatically on both server and client. Worn
same-model pairs need no `setr feather_native_guid_ownership 1` startup command.
An explicit `setr feather_native_guid_ownership 0` still overrides that default
and refuses firearm creation; remove that old override for normal operation. Existing
`1` entries are harmless. Saved attachment reconstruction and attachment
transactions also default on; manual startup commands are unnecessary. This
admits the recorded sight/barrel mappings across the tested firearm catalog.
LeMat mode switching, separate revolver/shotgun expenditure and per-copy wear passed focused live checks. The unified production GUID acceptance run passed all 1,800 cases, full report delivery, original-loadout restoration and the final visual check. Gunsmith location, configured
permissions, material costs, ownership and current-session checks still apply.

Server owners can explicitly disable attachment changes with replicated
`feather_native_attachment_transactions=0`, saved reconstruction with replicated
`feather_native_saved_attachments=0`, or cleaning with
`NativeAlphaRepairEnabled=false`. Disabling reconstruction while customized guns
are equipped refuses their restoration; it never silently strips components.
Existing `1` convar entries are harmless. Grants and fault injection remain off.

The temporary pair-options diagnostic is retained only in `tests/support`.
It is not loaded by the resource; do not deploy test support. After updating the
manifest, an old server copy of `client/native_pair_options_probe.lua` is unused.

See [native-only cutover](docs/native-only-runtime-cutover.md) for the runtime
file list, required manifest refresh, and accepted loadout/history gate.
Before stopping an active Weapons host, run `WeaponNativePrepareStopAll` and
wait for aggregate PASS/ready. Failure is not permission to stop or retry.

Native issuance remains separately default-off:
`set feather_native_issuance 0`. See the
[issuance contract](docs/native-issuance-alpha.md) for stable request IDs,
historical receipt semantics and no-replacement behavior after uncertainty.

## Current guides

- [Controlled enrollment](docs/native-controlled-enrollment.md)
- [Aggregate shutdown preparation](docs/native-shutdown-drain-alpha.md)
- [Native issuance](docs/native-issuance-alpha.md)
- [Native-only cutover](docs/native-only-runtime-cutover.md)
- [Lifecycle acceptance automation](docs/native-acceptance-automation.md)
- [Ownership recovery evidence](docs/native-recovery-batch-alpha-gate.md)
- [Prepared restart acceptance](docs/native-restart-acceptance.md)

The authoritative implementation status and acceptance record live in the
companion feather-framework-docs repository, under feather-weapons/
FEATHER_WEAPONS_MASTER_PLAN_NEXT.md and NATIVE_CUTOVER_REMAINING_WORK.md.
Older dated guides are evidence history, not alternate supported runtime modes.

## Historical tests

Current pull requests and pushes to main run `python tests/run_lua.py` with
Lupa 2.8 (Lua 5.4), followed by `node --test tests/*.test.mjs` on Node 22.
The runner checks runtime syntax and discovers current `tests/*spec.lua` files,
running each in a fresh VM. It excludes the historical archive. This workflow
does not publish, connect to a live database or certify native engine behavior;
the recorded live acceptance gates remain separate.

Retired scripts and temporary Jane manifests are isolated under
[tests/archive](tests/archive/README.md). Do not deploy that directory or load it
from the active manifest. Historical tests reproduce old evidence with mocks;
they do not establish current native parity or backward compatibility.

The former README is retained there as historical documentation only.


Firearm creation uses the same GUID inventory insertion/activation and exact-copy cleanup for singles, mixed loadouts and matching pairs, including independently worn/customized copies. The opt-in [GUID acceptance suite](docs/guid-creation-validation.md) exercises this production implementation with a temporary native-only matrix; it does not issue Inventory weapons or repair saved data.

Fresh recipe installs do not require the retired feather-weapons-native-proof resource. Normal equipment, maintenance and voluntary logout accept that resource being missing or stopped; an active or uncertain proof state remains blocked.

Normal melee commerce supports Knife, Machete, Hammer, Cleaver and Hatchet with unique serials and purchase provenance. Prices live in shop_config.lua. The five-model native path defaults on (feather_native_melee may explicitly disable it); throwing/pickup and same-model equipped duplicates remain unsupported. Equipment offers one Equip or Unequip action and chooses an empty compatible slot without replacing another model. No ammunition is created by melee purchases.

## Opt-in Tomahawk quantities

Set replicated `feather_throwable_quantities=1` before Inventory, Weapons and
Shops start to use regular Tomahawk ammunition instead of serialized thrown
units. Capacity is three; Inventory's Ammunition panel loads/unloads the existing
`ammo_tomahawk_regular` stack item. Native walk-over collection consumes shared
server allowances created atomically with confirmed paid throws. Allowances
expire after 180 seconds and require the same routing bucket within 50 metres
of the server-recorded launch position. Each allowance can be consumed once.
This deliberately accepts nearby quantity claims rather than exact projectile
identity; a modified client can consume an available nearby allowance, but cannot
recover more saved quantity than funded throws supplied. Serial, condition and
provenance do not follow thrown quantities. Historical serialized items are not
converted, refunded or deleted. Store legacy carried units before opting in.

Disable the old paid-throwable, paid-collection and GUID-suite test switches for
this mode. Do not revert to physical-unit mode while quantities remain loaded.
This mode remains default-off. Own/shared/repeated recovery, three outstanding
throws, load/unload persistence, loaded reconnect, death/admin revive, prepared
resource stop/start and full server restart were confirmed live. Capacity pickup
suppression/re-enable, multi-unit pickup, and controlled expiry/distance/bucket
rejection also passed. A settled unprepared resource stop correctly refused
cleanup, then full client exit/rejoin restored the acknowledged balance. Actual
process crashes and interrupted-write durability remain untested. See the
[quantity acceptance summary](docs/quantity-recovery-acceptance.md) for scope.
The normal manifest excludes the retired prompt, exact-item handoff, capture and
loan hosts. Their source and historical regressions remain offline evidence;
see [the research boundary](tests/archive/throwable-research/README.md). Old
throwable gameplay switches are refused at startup. Quantity mode uses
`shared/throwable_mode.lua`, with regular ammunition price/pack size configured
in `shop_config.lua`; temporary paid-test overlays are no longer loaded. The
firearm GUID matrix remains available, while its retired throwable loan actions
refuse without dispatch. No archive/test files are needed for deployment.
