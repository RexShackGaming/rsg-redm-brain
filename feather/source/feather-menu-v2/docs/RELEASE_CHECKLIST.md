# Contract 1 release verification

## Recorded completion

### 2.0.0-alpha.9 preparation - 2026-10-26

- Manifest/package versions agree at 2.0.0-alpha.9. Added reusable top-left anchor,
  legacy bundled fonts/default RDRLino, consistent button spacing and feedback,
  delayed corner busy indicator, inline field errors, opt-in localized confirmation,
  and accordion alignment/toggle/selection marker options.
- Navigation symbols use a separate system font to avoid game-font remapping.
  Arrow/accordion hover and subdued held-down feedback were confirmed live by
  the maintainer in Stables and other consumers. Stables tabs, checkout dialog,
  previews and input restoration were exercised in the consumer workflow.
- Current offline evidence: 75 browser tests, Lua validation/runtime 74/41
  assertions, lint with zero errors, production build and exact runtime ZIP
  verification. Bundled fonts are included by CSS references; JS/CSS retain the
  256 KiB budget and the eight fonts have a separate 2 MiB budget.
- Lua tests use Lupa Lua 5.4/Cfx simulations. Hosted Node 22 CI, full controller/
  resolution matrix and fault/restart gates below remain pending; consumer live
  acceptance does not certify every release gate. Generated ui/.artifacts stay
  ignored; the eight source font files must be included in the PR.

- Dropdown design/acceptance is **complete**, confirmed by the maintainer on 2026-09-03. Do not reopen it as unfinished feature work.
- Required renderer parity, tabs, stepper, and the initial RedM fixture were completed on the maintainer's main PC. Commit `131a775` is the work-PC starting point.
- Work-PC hardening adds exact field allowlists, bounded style/assets/sounds, encoded budgets, callback and navigation validation, replacement arrays, acknowledgements with three bounded retries, pause-close cancellation, and standard browser-gamepad routing.
- The README is the complete beginner-facing element/configuration/API reference. It includes a runnable starter, callback examples, migration guidance, and restart rebuilding.
- Packaging checks an actual flat install ZIP, referenced assets, absence of frontend source, the 256 KiB raw UI budget, and exclusion of the development fixture. Pushes to `main` build, verify, and automatically publish the package version without requiring contributors to create Git tags.
- Local and GitHub packaging share one runtime file allowlist: `fxmanifest.lua`, the three manifest-loaded client Lua files, `ui/index.html`, and its referenced compiled JS/CSS/font assets. Documentation/README, tests, scripts, repository metadata and `.artifacts` are excluded. Verification rejects any extra file or directory, including stale/unreferenced assets. Checksums remain beside the ZIP.

## Automated commands

### Work-PC execution record — 2026-09-03

- `pnpm check`: **58 UI tests passed**, production build passed; lint returned no errors and 67 formatting warnings. Local execution used Node 26.5.0 and pnpm 9.15.0; the supported Node 22 run remains a hosted CI gate.
- Browser fixture: loaded without logged warnings/errors; 720p menu and 1080p stepper inspected; dropdown Escape/Tab ownership, tab navigation with retained values, and stepper Next exercised. Browser callbacks simulate UI state only, not Cfx/Lua services.
- Local install ZIP: generated with `scripts/package_release.py`; actual extraction/layout/assets/bundle inspection passed. The checksum is distributed beside the ZIP.
- Lua suites: added/expanded and wired into CI/release, **not executed on this PC**. The optional Lua-runtime installation was declined.
- Website documentation: Menu v2 beginner/API reference, Legacy v1 warnings, version chooser, sidebar/overview links, and current consumer dependencies updated. VitePress production build passed in 71.17 seconds. Changes remain local; GitHub Pages publication and public-page verification are pending.

```text
cd web
pnpm install --frozen-lockfile
pnpm check
cd ..
lua tests/lua/validation_spec.lua .
lua tests/lua/runtime_spec.lua .
python scripts/package_release.py
python scripts/verify_release.py .artifacts/feather-menu-v2.zip
```

Use Node 22, pnpm 9.15.0, Lua 5.4, and Python 3. Runtime tests use simulated Cfx APIs and callable tables, not real Cfx function-reference serialization. CI and release jobs execute both Lua suites.

The work PC's available Node is newer than the pinned CI version. The optional installation of a local Lua test runtime was declined; do not claim Lua execution on this PC without a separate passing record. Do not change these gates to passed merely because tests were added.

## Required live record before stable

Record the commit, ZIP SHA-256, FXServer/RedM build, OS, resolution, controller, command, result, and any F8 errors for each run.

| Gate | Procedure | Status |
| --- | --- | --- |
| Hosted automated run | Clean Node 22/pnpm install; both Lua suites; UI tests/build; actual ZIP inspection | Pending hosted evidence for work-PC changes |
| Basic install | Extract ZIP into a folder named `feather-menu-v2`; ensure v2 then the README starter; open, edit, close, reopen | Pending new artifact run |
| Owner restart | Open starter, restart consumer; verify focus release and fresh menu construction | Pending |
| Provider restart | Open Settings, restart v2; reopen Settings and starter without stale IDs | Pending |
| Pause cancellation | Open, pause, close through Lua while suspended, unpause; it must remain closed | Pending |
| Callback failure | Throw inside a test callback; observe error; close/reopen still works | Pending Cfx funcref run |
| Recovery | Drop a patch/ack in a diagnostic fixture; verify bounded full-sync recovery and pending health count | Pending Cfx transport run |
| Controller | Standard device: D-pad, shoulders, accept/back, slider/radio/grid; no held-button reopen activation | Pending RedM host/device evidence |
| Keyboard/accessibility | Tab loop, disabled fieldsets, text editing, selector keys, Escape ownership, accessible labels | Component coverage; full browser/live review pending |
| Settings integration | Toggle PVP, provider choices, locale switch while open, restart/rebuild, rejected provider write | Pending live |
| Legacy coexistence | Run a third-party Legacy fixture beside v2; test transitions and focus release | Pending |
| Resolutions | 720p, 1080p, 1440p, 4K, ultrawide; long translated labels, resize, scroll, drag | New changes pending |
| Soak/performance | 30 minutes of open/close, updates, page changes, pause and restarts; record resmon and console | Pending |
| Linux server | Install exact ZIP on Linux FXServer and exercise the RedM client | Pending |
| Consumer adoption | Character/Admin migrate to Contract 1 and Notify; representative flows verified | Separate integration work pending |
| Release governance | Maintainer-approved license/contribution policy, dependency audit, supported runtime matrix, checksum and release notes | Pending |

The new controller route depends on browser `navigator.getGamepads()` support. If RedM's CEF build does not expose a standard device, a tested Cfx-native bridge will be needed; do not call controller support live-verified from JS tests alone.

## Scope and limits

Hard limits are enforced: 64 KiB definition/callback JSON, 256 KiB batch JSON, 1 MiB menu snapshot including reserved space, 256 KiB raw compiled UI. Open latency, update throughput, and large-list frame-time budgets still require measurements on the supported RedM baseline. The accepted dropdown should receive regression coverage as part of those runs, not another design-acceptance cycle.

Menu-scoped caches now preserve page drafts, focused control and content scroll across page navigation while open. Authoritative value changes invalidate stale drafts, removed IDs are purged, and close/destruction releases the temporary cache. Component tests cover page return; the full live structural-update matrix remains a verification gate.

No release was published as part of this work-PC implementation pass. Keep `2.0.0-alpha.1` until the maintainer chooses the next RC version after these gates.
