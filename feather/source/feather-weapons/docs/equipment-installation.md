# Equipment startup and update scope

The current native host admits every authenticated character. Shipped Weapons
runtime, character ammunition and transport settings are enabled; Inventory's
character ammunition setting must also be enabled. Keep development mode off.
Updating an existing server must preserve its configuration and saved reports.
No item conversion, database wipe, manual SQL or automatic grants are required.

Normal wear persistence requires `NativeAlphaLifecycleWearEnabled=true` in the
Weapons config (now the shipped default). Older preserved configs may still have
`false`: native shot wear then appears until a rebuild restores the older saved
metadata. Update that single setting for lifecycle persistence. Periodic wear
sampling remains optional. This does not recover wear already lost
during a prior rebuild or rewrite item metadata to repair the test fixture.

The 0.21.1 patch enables this default. Existing installations that preserve their
config must set this field to `true` explicitly. The live Cattleman pair passed
individual and dual-wield firing, independent wear saving across swaps,
reconnect preservation, and ammunition load/unload conservation with the setting
enabled. No Inventory update or schema migration is required for this patch.

## GUID ownership

Exact GUID ownership now defaults to enabled on both server and client. A normal
installation needs no `feather_native_guid_ownership` console command or startup
entry. All firearms use GUID inventory insertion and point activation. An explicit
replicated `0` refuses firearm creation; remove the old override for normal operation. A configured
`1` remains compatible. Do not set `0` to test the default: remove the startup
entry and start a fresh server process with clients disconnected.

## Attachment and cleaning defaults

Saved attachment reconstruction and attachment transactions now default on with
missing convars. The recorded sight/barrel mappings are admitted without representative/catalog
startup flags or development mode. LeMat mode switching, separate pool spending
and independent wear passed focused live tests; unified production creation acceptance passed all 1,800 cases with confirmed cleanup, full report delivery, original-loadout restoration and final visual pass. Unknown or
changed model/component/slot/item combinations are refused.

No manual `setr feather_native_saved_attachments 1` or
`setr feather_native_attachment_transactions 1` startup command is needed.
Explicit replicated `0` values remain server-owner disables and override the
defaults; remove old overrides for normal operation. A transaction-only disable
preserves saved-component reconstruction. Disabling saved reconstruction refuses
customized loadouts rather than stripping components. An existing repair setting
of `false` is also preserved: change it to `true` only to enable cleaning.
Development mode, fixture grants and fault injection remain off.

Current live evidence includes the complete 1,800-case production GUID run,
confirmed reconstruction/cleanup/restoration and final visual pass. Earlier
attachment, death/recovery, storage and cleaning acceptance is retained. See
`guid-creation-validation.md` for the exact scope and historical transport failure.

## Accepted equipment behavior

- The compact panel shows actions relevant to the selected item, with a busy
  spinner and automatic close after success.
- Swap hands atomically exchanges two equipped sidearms.
- Primary — Unequip removes that gun and promotes the existing Offhand to
  Primary. The panel explains the move. Offhand can be unequipped independently.
- Identity, session, full equipment snapshot and item revisions are revalidated;
  no automatic mutation retries occur on uncertain outcomes.
- Player-selected locale text uses the existing Inventory/Core settings bundle
  with English fallback. There is no resource-specific locale selector.

Jane's unequal-wear Cattleman pair passed equip/draw, both carry roles,
reconnect, distinct attachments and independent removal/returns, Swap hands,
and Primary removal/Offhand promotion. The fresh-start default change has passed
local policy/native-adapter tests and the live fresh-server restart check. The
user confirmed both Cattlemans draw without a GUID console command or startup
entry, with preserved item revisions/wear and ammunition ledger.
Other customized models, customized-pair death and concurrency are separate
acceptance boundaries.

## Diagnostic cleanup

The temporary pair-options probe now lives only under `tests/support`, where
regressions can load it explicitly. It is absent from the runtime manifest and
client source folder. Do not deploy test support. An old server copy of
`client/native_pair_options_probe.lua` is harmless once the new manifest loads;
it is no longer downloaded or registered. Historical probe guides are evidence,
not current installation instructions.

## Combined update

Deploy matching Weapons creation/loadout/maintenance adapters, server equipment
transition, materialization and attachment definitions with its root manifest.
Deploy matching Inventory conditional equipment/commit services, Inventory
controller, English dictionary and built `ui` folder in the same stopped-server
window. Do not copy repository metadata, tests or development dependencies.

Prepare the active host with `WeaponNativePrepareStopAll`, wait for aggregate
PASS and `WeaponNativeShutdownStatus` phase ready, disconnect clients and stop
the server before copying. Preserve configs, receipts, provenance and reports.
The manifest changed to remove a client script: run server-console `refresh`
before `ensure feather-weapons`, with clients still disconnected. One fresh
server process verifies the missing-convar default; this is not a full crash
acceptance test. Reconnect and inspect native/maintenance status and drawing.


See [GUID creation validation](guid-creation-validation.md) for the production factory consolidation and its automated engine acceptance gate. Singles, mixed firearms and matching pairs share the same mechanism; a pair only requires an extra native inventory-slot separation.
