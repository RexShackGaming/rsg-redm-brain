# Feather Menu v2 feature-parity ledger

This ledger is a release gate, not a claim that browser-only work proves live RedM behavior. “Implemented” means source exists and local static/browser checks can exercise it. “Live pending” means packaged Cfx/RedM evidence is still required.

## Reconciled status — 2026-09-03

Dropdown acceptance is **complete**, explicitly confirmed by the maintainer. The main-PC build at `131a775` records required v1 parity confirmation. Older “live pending” entries below describe the original ledger and do not undo recorded main-PC tests. New work-PC changes need regression runs, not another dropdown design-acceptance cycle.

Exact schemas, array replacement, callback validation, bounded acknowledgements/recovery, pause-close cancellation, standard browser-gamepad routing, keyboard ownership and accessible names are now implemented. The [README](../README.md) documents every element/configuration/export. Use the [release checklist](RELEASE_CHECKLIST.md) for current outstanding evidence, including real RedM controller support and consumer migrations.

## Menu-level capabilities

| Capability | v1 behavior | v2 contract | Current evidence |
| --- | --- | --- | --- |
| Draggable | Header/element drag with localStorage position | Opt-out dragging, viewport clamping, caller/menu-namespaced persisted position | Implemented; browser drag verified; live pending |
| Sizable | Breakpoint widths plus runtime height updates | Explicit `resizable = true` gate, persistent reactive dimensions, width/height bounds, and 720/1080/1440/2160 breakpoint widths | Implemented; browser resize verified; persistence live retest pending |
| Themable | Raw menu/slot/element styles and custom fonts | Presets plus bounded theme tokens for colors, radius, font family, sizing and layout; no remote CSS injection | Initial token contract implemented; complete schema validation/presets pending |
| Header/content/footer slots | Per-page slots | Stable slots updated reactively | Implemented; live pending |
| Closable | Close button/Escape may be disabled | `closable`, idempotent close, focus release | Implemented; live pending |
| Focus/cursor | Open options | Explicit keyboard/cursor options and single focus owner | Implemented; live pending |
| Active-menu replacement | Open may replace/block | Replace by default; `replace=false` returns `focus_unavailable` | Implemented; live pending |
| Key callbacks | Menu key map | Caller-owned `RegisterKeyAction`/`RemoveKeyAction` | Implemented; live pending |
| Sounds | Open/close/element frontend sounds | Validated explicit frontend sounds | Implemented; live pending |
| Scrolling | Content vertical scrolling | Bounded content scroll with stable header/footer | Implemented; browser verified; live pending |
| Reactive updates | Active-page values only; structure requires reroute/reopen | Revisioned active/inactive-page value and structure mutations, atomic label batches, desync recovery | Implemented foundation and store tests; Cfx recovery pending |
| Lifecycle/pause screen | Open/close/page callbacks; close and rebuild around pause screen | Standard lifecycle callback; suspend/resume without reconstructing state | Implemented; live pending |
| Multiple definitions | Many registered; one active focus owner | Many caller-owned definitions; one interactive menu in Contract 1 | Implemented |
| Cleanup | Partial/manual | Automatic owner-stop cleanup of menus, callbacks and focus | Implemented; live pending |

## Element surface

Implemented renderer types:

- v1 parity: `header`, `subheader`, `line`, `bottomline`, `button`, `input`, `textarea`, `slider`, `arrows`, `toggle`, `checkbox`, `dropdown`, `gridslider`, `imagebox`, `imageboxcontainer`, `pagearrows`, and `textdisplay`;
- v2 additions: `radio`, `number`, `progress`, `spacer`, and palette-first `colorpicker`;
- primary navigation modes: `tabs` and `stepper`.

Not claimed as supported:

- `html`: intentionally excluded until a bounded rich-text contract replaces arbitrary `v-html`;
- `datepicker`: v1 source existed but was disabled and therefore is not counted as released v1 parity;
- notifications and version checking: intentionally owned elsewhere.

Every type still requires its full component, mouse, keyboard, controller, reactive update, cleanup, visual, packaged Cfx, and live RedM acceptance row before stable `2.0.0`.

`gridslider` tracks pointer movement locally for smooth dragging and commits one Lua `change` callback on pointer release. This intentionally avoids cross-resource callback traffic for every pointer-move frame.

`dropdown` displays at most six option rows by default and then scrolls inside its teleported overlay. Consumers may set bounded `maxVisibleOptions` from 3 through 10; menu content and dropdown overflow use themed scrollbars rather than browser-default chrome.

## Compatibility note

Feature parity does not mean API compatibility. Existing resources continue using Legacy `feather-menu`. V2 uses named exports, result envelopes, opaque caller-owned IDs, and no `initiate()` object.
