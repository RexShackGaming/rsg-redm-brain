# Feather Weapons

Current version: **0.19.0**.

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
historical replay after transfer, and an uncustomized same-model Cattleman pair.

Limits remain: full non-firearm catalog/interaction parity, destruction, customized same-model
pairs, wider enrollment, automatic shutdown interception, simultaneous SQL
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

Use only the root `fxmanifest.lua`. Keep existing explicit native and feature
configuration; shipped defaults remain disabled. Required native host gates are
DevMode, NativeAlphaRuntime, CharacterAmmunitionEnabled,
CharacterAmmoTransportEnabled and valid explicit enrollment. Missing gates
refuse startup. Do not replace a customized config wholesale.

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
