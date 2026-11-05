# Feather Menu v2 — Contract 1

Contract 1 remains an alpha release until the [release checklist](RELEASE_CHECKLIST.md) is satisfied. The [README](../README.md) is the normative beginner-facing catalog of every accepted field, default, export, and callback. This reference describes implementation rules that consumers and maintainers must preserve.

## Public boundary

- Named client exports only; no Core dependency, mutable public registry, `initiate()` object, server scripts, notification system, or outbound version checker.
- Success: `{ ok = true, value = ... }`. Failure: `{ ok = false, code, message, details? }`.
- Owner identity is derived from `GetInvokingResource()`. Handles returned by the provider belong to that resource and should never be constructed by a consumer.
- Caller keys are 1–128 safe characters. Navigation/open handles accept the longer returned IDs (up to 1024 characters). Keys cannot be renamed through updates.
- Definitions are copied. Unknown fields return `invalid_input`. Functions belong only in callback arguments; normal Lua functions and callable Cfx references are accepted.
- Every consumer must rebuild definitions after provider restart; owner stop removes definitions/callbacks and releases focus.

## Validation and bounds

Payloads allow tables, strings, finite numbers, booleans, and nil; cyclic tables, non-finite numbers, functions, unsupported key types, oversized field names, and prototype-related reserved keys are rejected.

| Limit | Value |
| --- | ---: |
| Nested table depth | 6 |
| Fields per definition/payload | 4096 |
| Ordinary string length | 4096 UTF-8 bytes |
| Encoded definition/callback | 64 KiB |
| Encoded atomic batch | 256 KiB |
| Menu snapshot, including reserved envelope overhead | 1 MiB |
| Registered menus globally | 64 |
| Pages per menu | 64 |
| Elements per page | 512 |
| Atomic operations | 256 |
| Choice options | 500 |
| Image children | 100 |

Smaller per-field bounds are in the README. UTF-8 bytes are used by Lua's string-length operator, not Unicode character counts. Bounds may combine: a 500-option list must still fit its encoded and field limits.

Menu size/position tokens use bounded px/rem/%/vw/vh values. Themes allow local documented font stacks and bounded color formats. Frontend sound identifiers are bounded names. Image paths are relative or Cfx NUI resource URLs only. Arbitrary CSS, HTML, remote fonts/assets, and data URLs are not part of this contract.

## Updates

Objects merge; `options`, `items`, and navigation `pages` replace their arrays. This is identical in Lua validation, Lua mutation, and the NUI reducer. Nil is absence, not a delete instruction. Element keys/types are stable; recreate an element to change its type.

`ApplyPatch` accepts only `updateElement` operations. Each target may appear once. The provider validates the full resulting definition and total budget before applying any operation. A failing operation leaves all targets unchanged.

Configure navigation only with registered pages. Updates retain its callback. Removing a page removes its navigation entry; removing the final entry clears navigation. Deleting an active page requires a registered fallback distinct from the deleted page.

## Transport and acknowledgement

Lua is authoritative. A successful export means the mutation was accepted in Lua, not that the UI has painted it. Mutations increment the menu revision and send `menu:patch`. NUI applies only the next revision. A `menu:sync` snapshot may recover gaps; older snapshots cannot roll a newer menu backward.

NUI posts `ack { menuId, revision }` only after applying a patch or snapshot. Lua rejects future/non-integer revisions and records the highest acknowledged revision. Full sync starts a new acknowledgement wait. An open menu with a pending acknowledgement gets a full snapshot after two seconds, at most three times until a current acknowledgement clears recovery. Health reports the number of open menus with pending acknowledgements.

Rejected patches request one `desync` per menu until an accepted full sync clears that request. Closing/destroying a menu does not leave an unbounded retry loop. `SyncMenu` explicitly requests a new recovery snapshot.

## Input/callback semantics

- The active menu/page, element disabled state, event action, and value are checked before invoking a callback, even when `persist = false`.
- `change` values are stored only when persistence is enabled. Activation/page-arrow/image-child intents do not rewrite element definitions.
- Default persistence occurs before the consumer callback; an exception does not roll it back. Callback failures return `callback_failed` to NUI and are logged. Cleanup/close remain available.
- Controlled (`persist = false`) input is reconciled with the authoritative value returned after the callback, including a service rejection that leaves the old value unchanged.
- Button/image activation values and image-child metadata come from the registered definition. Client-supplied metadata is not trusted.
- If a callback message supplies a revision, a mismatched revision is rejected with `conflict` and a sync. Ordinary renderer callbacks omit it to allow consecutive live edits without waiting for a render round trip.
- Tabs navigate automatically unless controlled. Steppers always emit intents; workflow validation remains in the consumer. Disabled/hidden targets and invalid step boundaries cannot be bypassed by a NUI intent.
- Pointer grids commit once on release; cancellation does not commit. Range sliders emit while adjusted. Text/number controls commit on change; numbers clamp to bounds and reject empty/non-finite commits.
- Keyboard ownership, standard browser-gamepad mappings, focus defaults, and shortcuts are documented in the README. Browser support does not establish live Cfx device support.
- An owning consumer may use `SetMenuFocus` to release and restore modal input while keeping its active menu rendered; released menus do not suppress gameplay control groups.

## Stable-release evidence still required

Hosted Node 22/Lua test execution, real Cfx funcref/transport recovery, provider/consumer restart and focus matrices, supported RedM controller/resolution runs, Settings integration, Character/Admin migration, Legacy coexistence, dependency/license review, measured latency/throughput budgets, and packaged Linux/soak testing remain gates. Dropdown design acceptance is complete.

Same-page unrelated label patches preserve drafts. A menu-scoped page cache restores drafts, focused controls and scroll on page return while the menu remains open. An authoritative value change invalidates that element's cached draft; removal invalidates the removed IDs. Close/destruction releases temporary UI caches while committed Lua values follow the menu definition lifecycle. The full live structural-update matrix still needs verification.
