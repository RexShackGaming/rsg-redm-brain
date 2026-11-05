# Advanced Camera scoped equipment gate

2026-10-31 native equipment checkpoint COMPLETE: issued225rev0/replay, serial
FW-CAME-6AE67E6A-4E6482-0001/provenance28, five-utility/paired-camera coexistence,
isolated fifth cleanup, normal menu re-equip/English occupancy layout, prepared
2/2 shutdown/guard teardown/restart, death seal/doctor and normal new-session
restoration passed. User confirms five selectable/drawable in final John session
2311bec4-d58b-11f1-99a9-e0d55eaa2deb; ledger16/Tomahawk1 and155rev4/158rev5 wear
preserved; Jane ledger35/repeater1 and112rev2/134rev8 wear unchanged.
Separate UI live language-change/fallback check remains pending (automated tests pass).
Runbook below retained as reference, not a request to repeat native tests/grants.

2026-10-31: implemented and automatically tested; new-port live acceptance pending.
Original paired-camera wheel evidence in advanced-camera-live-gate.md is reused.
Equipment ownership and persistence only, no photography controls or photo saving.

## Invariants

- Preserve utility_camera_advanced / weapon_kit_camera_advanced /
  WEAPON_KIT_CAMERA_ADVANCED in weapon_utility_quinary (Utility5).
- Replicated feather_native_camera_advanced defaults0; requires admitted Standard
  Camera/Binoculars/Davy collection and existing exact-enrollment native gates.
- Canonical family stays camera. Trusted distinct camera_advanced ownership group
  allows both cameras without weakening duplicate-item or one-lasso restrictions.
- Fifth exact GUID cleanup must succeed before parent release. Factory/create/
  cleanup uncertainty or gate loss retains owner; no adoption/retry/model purge.
- Full Inventory assignment/metadata/revision CAS/final wear and independent
  released-owner reservation checks remain in force. Disabled fifth refuses.
- Selected-language Equipment UI follows feather-settings through Core's locale
  cache/TranslateLocale and feather-core:locale:changed. Missing keys fall back
  to English. UI translates machine slot/action fields, not shared server labels.
  Locale refresh changes text only; no scope mutation or equipment request.

## Required runtime deployment (source to destination)

Destination paths below are relative to the operator's server resources directory,
whose absolute location is unknown. Preserve config.lua in both resources.

| Absolute local source | Relative server destination |
| --- | --- |
| C:/coding/feather-scripts/feather-weapons/client/ | feather-weapons/client/ |
| C:/coding/feather-scripts/feather-weapons/server/ | feather-weapons/server/ |
| C:/coding/feather-scripts/feather-weapons/shared/ | feather-weapons/shared/ |
| C:/coding/feather-scripts/feather-weapons/fxmanifest.lua | feather-weapons/fxmanifest.lua |
| C:/coding/feather-scripts/feather-inventory/server/internal/ | feather-inventory/server/internal/ |
| C:/coding/feather-scripts/feather-inventory/client/controllers/inventory.lua | feather-inventory/client/controllers/inventory.lua |
| C:/coding/feather-scripts/feather-inventory/translations/en_us.lua | feather-inventory/translations/en_us.lua |
| C:/coding/feather-scripts/feather-inventory/ui/index.html | feather-inventory/ui/index.html |
| C:/coding/feather-scripts/feather-inventory/ui/assets/ | feather-inventory/ui/assets/ |

Already built locally. Do not copy web/node_modules, .git, tests, fixtures or docs.
Documentation/tests are optional reference only, not runtime deployment.

## First checkpoint: gate-off deployment only

1. Server console WeaponNativePrepareStopAll, wait aggregate PASS. Then
   WeaponNativeShutdownStatus: require ready and completed==total. If either
   fails or startup is still failing, stop and report; do not force owner release.
2. Manually fully quit BOTH RedM clients. Drain never disconnects them.
3. Copy required runtime paths above, preserving server config/enrollment.
4. Server console in this order:

       setr feather_native_camera_advanced 0
       refresh
       restart feather-inventory
       restart feather-weapons

   refresh is required for the added manifest policy and rebuilt UI assets.
   No database migration/reset, full server restart or other flag changes.
5. Reconnect both characters via normal selection. Report current IDs. Each
   player's F8 console: weaponNativeStatus. Server console:
   WeaponNativeUtilityStatus. Expect advancedCameraLoadedtrue/convar0/enabledfalse.
   Do not assume old IDs/UUIDs or item identities survived a database rebuild.

No Advanced Camera issuance/equip at this checkpoint. Later prepared gate1 restart
and owned-item inspection precede any explicit idempotent issuance decision.
Original historical Advanced item134 is NOT current John ownership.

After stable gate-on baseline, test fifth coexistence, isolated cleanup, normal
menu re-equip and genuinely new five-child lifecycle boundaries. Also inspect
Equipment text after feather-settings language changes with panel open: each
recipient follows their selected dictionary; missing entries use English. No
equipment request or stale-language key should be produced by language refresh.

Pre-rebuild observed baseline reference only: John ledger16/Tomahawk1;
155rev4 dirt0.6680000424385/degradation0.00778666650876/soot0.00499999988824,
158rev5 pristine; utilities172/173/174/175rev0. Jane ledger35/repeater1,
112rev2 dirt1/degradation0.00871666707098,134rev8 pristine. Verify fresh state.

Automated:201 Weapons Lua specs/runtime syntax+7 Node tests; full Inventory Lua
suite/runtime syntax81 files+3 web tests; touched UI ESLint/Vite build PASS.
Tests simulate five children/native/SQL, separate client language bundles and
actual locale bridge. Live engine/layout/localization acceptance remains pending.
No production enrollment, photography, true crash or unknown SQL outcome claim.
