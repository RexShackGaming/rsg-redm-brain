# Improved Binoculars scoped native gate

2026-10-31 scoped live acceptance confirmed: six utilities select/draw after
isolated sixth removal/menu re-equip, resource restart, death/doctor recovery,
and fresh character session. Item226 rev0 issuance replay returned the same serial
FW-BINO-6AE697BB-8FE714-0001 and provenance29. John ledger16/Tomahawk1 and
firearm155rev4/158rev5 maintenance stayed unchanged; Jane ledger35/repeater1 and
firearm112rev2/134rev8 maintenance stayed unchanged. Broader rollout remains pending.
Original combined viewing/wheel record in improved-binoculars-live-gate.md is reused.
Native wheel label was Refined Binoculars; item/native names remain unchanged.

## Scope

- Exact utility_binoculars_improved / weapon_kit_binoculars_improved /
  WEAPON_KIT_BINOCULARS_IMPROVED in weapon_utility_senary (Utility6).
- Default0 replicated feather_native_binoculars_improved requires existing Advanced
  Camera and earlier utility collection gates plus exact enrollment/native settings.
- Canonical binoculars family remains; trusted binoculars_improved carrier group
  permits coexistence with Standard. Neither carrier implicitly replaces another.
- Six separate item holds/GUID owners share sealed cleanup. Sixth factory/create/
  removal uncertainty or gate loss retains parent; no adoption/retry/model purge.
- Inventory full owned assignment/revision/metadata CAS, final wear and independent
  reserved commit checks remain. Disabled saved sixth refuses, never silently omits.
- Utility6 uses existing selected-language equipment label templates/English
  fallback and text-only locale updates. No new dictionary entries are needed.
- No custom viewing, zoom, ammo, unlock or photography implementation.

## Required runtime paths

Server destinations are relative to the operator's resources directory; its
absolute root is unknown. Preserve both deployed config.lua files and enrollment.

| Absolute local source | Relative server destination |
| --- | --- |
| C:/coding/feather-scripts/feather-weapons/client/ | feather-weapons/client/ |
| C:/coding/feather-scripts/feather-weapons/server/ | feather-weapons/server/ |
| C:/coding/feather-scripts/feather-weapons/shared/ | feather-weapons/shared/ |
| C:/coding/feather-scripts/feather-weapons/fxmanifest.lua | feather-weapons/fxmanifest.lua |
| C:/coding/feather-scripts/feather-inventory/server/internal/ | feather-inventory/server/internal/ |
| C:/coding/feather-scripts/feather-inventory/ui/index.html | feather-inventory/ui/index.html |
| C:/coding/feather-scripts/feather-inventory/ui/assets/ | feather-inventory/ui/assets/ |

UI already rebuilt. No new controller/dictionary changes relative to Advanced Camera
deployment. Docs/tests are optional reference only: do not copy fixtures/.git/
node_modules or tests for runtime.

## First checkpoint: gate-off baseline

1. Server console WeaponNativePrepareStopAll, wait aggregate PASS.
   Then WeaponNativeShutdownStatus; require ready and completed==total.
   Any failure means stop/report, not force/retry or hot restart.
2. Manually fully quit BOTH RedM clients.
3. Copy runtime paths above, preserving config files.
4. Server console in execution order:

       setr feather_native_binoculars_improved 0
       refresh
       restart feather-inventory
       restart feather-weapons

   refresh is required for new policy manifest entry and rebuilt UI assets.
   No full server restart, DB migration/reset, new grants or other flag changes.
5. Reconnect via normal character selection, report current IDs. Each F8 console:
   weaponNativeStatus. Server console: WeaponNativeUtilityStatus.
   Expect improvedBinocularsLoadedtrue/convar0/enabledfalse, existing five utilities
   intact, prior durable ammunition. Do not assume old IDs after reconnect.

Only after baseline review: prepared Weapons-only opt-in restart, current statuses,
then inspect already-owned Improved Binoculars before any explicit one-time
issuance/replay decision. Historical original item138 is NOT current John ownership.
No ammunition funding/budget needed. Live new-port tests target six-child native
coexistence, isolated sixth cleanup/menu equip, and genuinely new lifecycle boundary;
do not repeat the entire original native viewing matrix.

Current accepted baseline reference: John utilities172/175/225/173/174rev0,
melee160..164rev0, carrier165rev0, ledger16/Tomahawk1;155rev4 degradation
0.00778666650876/dirt0.6680000424385/soot0.00499999988824/damage0/permanent0,
158rev5 pristine. Jane ledger35/repeater1;112rev2 dirt1/degradation0.00871666707098/
other0,134rev8 pristine. Verify fresh statuses rather than restoring/granting guesses.

Automated205 Weapons Lua specs/runtime syntax+7 Node, Inventory full Lua suite/
runtime syntax81 files+3 web tests, changed UI ESLint/Vite build PASS. Tests include
sixth-child faults/current-gate loss, separate Binocular holds, CAS/sibling cleanup,
concrete mocked native GUID case, sixteen slots and localized Utility6.
Live engine/layout acceptance pending; no broader production/crash/transfer claim.
