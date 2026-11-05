# Native-only runtime cutover — 2026-10-17

Implemented and automated; live post-deployment loadout restoration accepted:
Jane epoch14643723:1/112rev2+134rev8/ledger35/repeater1 and John epoch14654949:2/
158rev3/ledger3/all ammo0, expected wear preserved and both ACTIVE idle.
Existing158 provenance readback accepted: currenttrue/destroyedfalse, original
serial, issuance14 and both transfers15/16 intact. Live restoration/history gate
complete in observed scope; startup/refresh logs not supplied, disabled-flags
no-fallback behavior covered by automated tests, not a destructive live test.
Human requires one new system, no old-version compatibility or data migration.
Keep the present native test database only to verify this cutover. No schema
deletion, item cleanup, reset, conversion or compatibility bridge is performed.

## What changed

- Manifest no longer loads the old server Inventory provider, per-item ammo/
  equip/maintenance/repair/runtime/reconciliation modules or RPC registration shim.
  Old client main, per-item pool/coordinator/GUID/maintenance/probe/shot-death
  scripts and import shim are no longer loaded either.
- Main startup only installs the native definitions/ownership reader/provenance/
  guards. Missing/disabled/inconsistent native settings fail startup; there is
  no alternative gameplay mode selected by turning flags off.
- Issuance has one native receipt-backed path. Old reserve/commit/cancel/recover
  issuance methods and old issuance table creation/migration are removed.
  Existing native inventory_grant_receipts and feather_weapon_events stay in use.
  Old tables, if present, are left unused; they are not read or migrated.
- Public metadata Build/Validate creates/accepts character-owned ammo documents
  only. Old loaded/reserve/chambered documents refuse without conversion.
  Native item validation's private zero-quantity structural view is validation
  only; it is not a compatibility import or stored ammunition projection.
- Attachment service retains only native station/authorization policy. Evidence,
  movement observation and provenance use native ownership only, never the old
  Inventory adapter or reconciler. Native destruction remains unsupported.
- Provider installation, old runtime getters and old inspect/reconcile API
  surfaces are removed. The old Admin console inspect/reconcile contract tools
  will need native-aware replacements; they are not supported compatibility
  endpoints. Admin evidence/issuance named exports remain; permissions unchanged.
- Commands file now retains WeaponProvenanceInspect only. Supported native
  issuance/equipment/shutdown/evidence commands are registered by their owners.
  Old grantweapon, WeaponNativeTestPrepare and legacy smoke/recovery/reconcile
  commands are retired. No more old-issuer grant route remains in this runtime.

Repository cleanup is complete:27 retired source/temporary-manifest files now
live only under tests/archive, with historical test reads updated. Original
runtime paths and alternate root manifests are gone. The old README is archived
there too; root README is current/native-only. An archive-boundary regression
asserts originals stay absent and test paths stay out of the runtime manifest.
136 Lua specs plus runtime/archive syntax and7 Node checks pass. Archive-only
cleanup adds no runtime deployment delta, refresh, restart or gameplay retest.
Do not deploy tests/archive. Exact optional orphaned-server-file removal list is
tests/archive/README.md; no server removal was automated. Historical static
tests do not establish native non-firearm parity. Unused-config cleanup remains
separate and must not reintroduce a fallback.

## Boundaries

Native-only does NOT mean global/production-ready: existing DevMode, NativeAlphaRuntime,
both character-ammo flags, explicit maximum-two enrollment and feature gates
remain. Default-disabled flags now fail server startup instead of starting the
old host. Preserve the already-deployed customized config; no config replacement
is needed for Jane and John. Native non-firearms, destruction, customized pairs,
automatic shutdown and actual in-flight SQL/crash handling remain separate work.

The earlier cross-mode request-ID issue is removed from the supported runtime
by eliminating the second issuer, not by supporting cross-mode replay. Existing
old-format items and old receipt history are unsupported. No new shared ledger,
mode fence, migration or conversion is added. Native request IDs and receipts,
including native-issue-alpha-v1 ->158/event14, remain authoritative.

## Deployment — Weapons ONLY

Copy these exact existing files; no Inventory/Admin runtime changes:

```text
fxmanifest.lua
client/character_ammunition_startup.lua
server/main.lua
server/services/api.lua
server/services/attachments.lua
server/services/commands.lua
server/services/evidence.lua
server/services/issuance.lua
server/services/metadata.lua
server/services/ownership.lua
server/services/provenance.lua
```

1. Keep both players connected, alive and idle. Use current server IDs, last
   known Jane1/John3. Run WeaponNativePrepareStopAll on the currently deployed
   version and wait for aggregate PASS/ready. On refusal, do not stop or retry.
2. Stop feather-weapons, copy the files above, then run server-console `refresh`
   BEFORE `ensure feather-weapons` because the manifest changed.
3. Expect scoped native-only firearms host ready; no legacy fallback. Keep
   issuance0 and all temporary fixture/probe flags0; do not change existing
   native/enrollment settings or wipe the database.
4. From both desks capture weaponNativeStatus and weaponNativeMaintenanceStatus.
   Expected last known state: Jane112rev2 +134rev8/ledger35/repeater1; John158rev3/
   ledger3/all ammo0. Preserve known wear (Jane112 dirt1/degradation0.00871666707098;
   John158 soot0.00499999988824/degradation0.00333333341404; other known fields0).
5. Run `WeaponProvenanceInspect 158 5`. The
   existing serial/history must remain readable. Stop for readback review.
   Do not issue another firearm or deliberately disable flags on the live test.

Later receipt replay can reuse the existing exact key, never a new grant key.
No need to repeat firing, transfers, death, repairs or attachment catalog tests
for this initial cutover gate. No automatic database wipe is authorized.

## Automated coverage

135 Lua specs + all runtime Lua syntax, 7 Node checks PASS. Real manifest server
and client graphs load without obsolete globals; server disabled-gate startup
refuses; metadata old-format import is rejected; issuance flags-off does not
fall back; obsolete fixture/old command/provider/ledger routes are absent.
Native ownership/evidence/issuance and all preceding regressions pass. Inventory
full Lua suite passes unchanged. Native/SQL boundaries remain mocked; no live
cutover claim until the deployment outputs above are supplied.
