# Metal Detector and Fishing Rod native-only batch

2026-10-31 COMPLETE scoped live gate: complete final John maintenance capture
confirms155rev4 wear unchanged and158rev5 pristine unchanged in fresh session
2f284025-d5a8-11f1-99a9-e0d55eaa2deb. All individual and shared lifecycle/observer
checks below accepted. This closes the truncated-capture limitation below;
broader production/crash/transfer acceptance remains pending.

2026-10-31 scoped eight-utility lifecycle manually confirmed. Gate baselines,
issuance/replay (Metal Detector227 rev0/provenance30, Fishing Rod228 rev0/
provenance31), isolated removal/menu restore/Utility7-8 indicators, shared restart,
death seal medical33/doctor alive34 and fresh session
2f284025-d5a8-11f1-99a9-e0d55eaa2deb all pass. All8 select/draw/GUID-captured;
John ledger16/Tomahawk1; Jane ledger35/repeater1 and complete wear unchanged.
John155rev4 complete wear matches baseline. Final158 wear output truncated:
only complete final second-firearm comparison remains pending, not lifecycle retest.
Deployment and subsequent checkpoint instructions below are the historical runbook.

## Boundaries

- Metal Detector: utility_metal_detector / weapon_kit_metal_detector /
  WEAPON_KIT_METAL_DETECTOR; weapon_utility_septenary (Utility 7).
- Fishing Rod: utility_fishing_rod / weapon_fishingrod / WEAPON_FISHINGROD;
  weapon_utility_octonary (Utility 8).
- Independent default-off replicated feather_native_metal_detector and
  feather_native_fishing_rod gates; each requires Improved Binoculars and earlier
  collection gates, exact enrollment and native/ammo/transport/lifecycle settings.
  Neither new gate requires the other. Disabled saved assignments refuse, not omit.
- Eight distinct owned identities use the existing lease, full sibling revision /
  metadata CAS, native GUID ownership and final-seal/release barriers. Uncertain
  child factory/removal retains parent ownership; no adoption or model-wide purge.
- Existing selected-language numbered labels cover Utility 7/8 with English fallback.
- Original metal-detector-live-gate.md and fishing-rod-live-gate.md are historical
  gameplay evidence. Their old grant commands are not this native-only protocol.
  No detecting rewards, bait/fishing gameplay, or ammo/material grants added.

## Automated evidence

212 Weapons Lua specs and runtime syntax; full Inventory Lua suite and 81-file
syntax; 7 Weapons Node tests and 3 UI Node tests; changed helper ESLint and UI
production build pass. Cases exercise strict profiles, eight-owner session/parent,
seventh/eighth uncertain cleanup/factory, independent gate loss, isolated removal,
full sibling CAS, disabled persisted slots, exact native identity and localized UI.

## Runtime deployment (server resources root unknown)

Destinations below are relative to the server resources root. Preserve both
config.lua files and server enrollment/accepted gates. No tests, docs, .git or
node_modules need copying. No database migration, reset or full server restart.

| Absolute local source | Relative destination |
| --- | --- |
| C:/coding/feather-scripts/feather-weapons/client/ | feather-weapons/client/ |
| C:/coding/feather-scripts/feather-weapons/server/ | feather-weapons/server/ |
| C:/coding/feather-scripts/feather-weapons/shared/ | feather-weapons/shared/ |
| C:/coding/feather-scripts/feather-weapons/fxmanifest.lua | feather-weapons/fxmanifest.lua |
| C:/coding/feather-scripts/feather-inventory/server/internal/ | feather-inventory/server/internal/ |
| C:/coding/feather-scripts/feather-inventory/ui/index.html | feather-inventory/ui/index.html |
| C:/coding/feather-scripts/feather-inventory/ui/assets/ | feather-inventory/ui/assets/ |

Server console, BEFORE copying or restarting:

```text
WeaponNativePrepareStopAll
WeaponNativeShutdownStatus
```

Wait for aggregate PASS then ready/completed=total. Any refusal/failure stops this
handoff; do not retry an uncertain drain or force restart. Fully quit BOTH clients
manually after successful drain (drain does not disconnect them). Copy runtime
paths, then server console:

```text
setr feather_native_metal_detector 0
setr feather_native_fishing_rod 0
refresh
restart feather-inventory
restart feather-weapons
```

Refresh is required for the two new manifest scripts and rebuilt UI assets.
Reconnect both clients through normal character selection. Record fresh player IDs.
Both players F8: weaponNativeStatus. Server: WeaponNativeUtilityStatus.
Expect both new profiles Loaded=true, Convar=0, Enabled=false; all existing six
John utilities active and ammo/wear baselines preserved. No issuance/equip yet.

## Subsequent combined live checkpoints (after baseline review)

Prepared Weapons-only restart enables both new gates1 together; clients may remain
connected only after aggregate PASS and ready. Obtain current IDs before commands.
Inspect existing ownership before any new issuance; never reuse original item139.
If absent use one fixed request per definition, replay exact request once and
disable issuance afterward. Suggested receipts native-metal-detector-alpha-v1 and
native-fishing-rod-alpha-v1. Do not infer item IDs before returned issuance.
Individually equip/remove each exact slot, verify sibling preservation, then restore
both via normal Equipment menu and verify Utility7/8 selected indicators and all8
select/draw. Run ONE shared prepared Weapons restart, ONE death/final-seal/doctor
recovery and ONE normal character logout/login with all8. Capture observer Jane
ammo/wear unchanged. Broader production/crash/transfer/storage acceptance pending.

Baseline before this batch: John CID4560a489-ca6c-11f1-9ad4-e0d55eaa2deb,
ledger16/Tomahawk1, utilities172/173/174/175/225/226 rev0,
firearm155rev4 degradation0.00778666650876 dirt0.6680000424385 soot0.00499999988824,
firearm158rev5 pristine. Jane ledger35/repeater1, firearm112rev2
degradation0.00871666707098 dirt1.0, firearm134rev8 pristine. Other pools and
permanentDegradation/damage zero. Six-utility live gate already accepted.
