# Feather Weather

World time, weather, and climate synchronization for RedM. Version `0.1.0` (unreleased), Contract 1.

A standalone service with no mandatory Core, database, Menu, or UI dependency. The initial baseline and Character integration have recorded user-reported live acceptance. Regional presentation is enabled by default following representative gameplay acceptance; custom policies and other server builds still require validation.

## Installation

1. Install as `feather-weather` and configure `config.lua`.
2. Select one weather/clock provider. Stop `weathersync` before starting this resource. Weather refuses authority while a configured conflicting resource is starting/running. This cannot detect arbitrary scripts writing weather natives.
3. Add `ensure feather-weather` before consumers that need scene overrides. Refresh/restart the resource after manifest changes.

This resource does not modify your recipe, server configuration, or other resources. Restart resets all domains to configuration; there is no persistence or legacy `weathersync` API alias.

## Configuration

| Setting | Meaning |
| --- | --- |
| `clock.mode` | `simulated` or `wall`. Wall mode uses UTC plus `offsetSeconds`, without host-local timezone/DST behavior. |
| `clock.seconds` | Initial seconds of week, Sunday `0` through `<604800`; `21600` is Sunday 06:00. |
| `clock.rate` | Simulated seconds per real second, `0..120`. Zero pauses simulation; it does not select wall mode. Wall mode runs at 1x. |
| `clock.frozen` | Freeze the displayed clock independently of weather scheduling. |
| `clock.offsetSeconds` | Integer UTC offset, `-86400..86400`, used in wall mode. |
| `weather.name` | A lowercase RedM weather name from the allowlist in `shared/contract.lua`. |
| `weather.frozen` | Pause automatic weather progression. |
| `weather.transitionSeconds` | Native transition duration, `0..300` real seconds. |
| `weather.snow` | Request forced snow coverage mode 3 when true, primary coverage mode 0 when false. This is not a guarantee that all natural regional snow disappears. |
| `weatherIntervalSeconds` | Simulation seconds between weather steps, `60..604800`. Clock freeze does not pause this schedule; zero simulated rate does. |
| `pattern` | Closed graph of ordered `{ name, weight }` rows, each totaling 100. All destinations must have rows. |
| `forecastCount` | Queued future weather states, `1..48`. |
| `wind` | Constant base direction `0..<360` and speed `0..30`; visual orientation/strength require supported-build acceptance. |
| `regions` | Optional named-zone presentation policy; enabled by default. See regional presentation below. Missing section preserves the 0.1.x global-only behavior. |
| `syncIntervalMs` | Periodic coherent correction, `1000..60000` ms; defaults to 5000. Changes also broadcast immediately. |
| `tickIntervalMs` / `clientIntervalMs` | Bounded server timing and client application cadence; defaults to 250 ms each. No per-frame loop. |
| `maxCatchUpSteps` | Bounded automatic transitions after a delayed tick, `1..128`. Longer stalls hold current weather, reset the interval, rebuild forecast, and increment `catchUpResets`. |
| `trustedResources` | Server mutation allowlist, keyed by actual invoking resource name with value `true`. Empty by default. |
| `overrideOwners` | Client scene allowlist, keyed by invoking resource, with `{ maxPriority=0..100 }`. Defaults to `feather-character` at maximum priority 10; test resources are not enabled. |
| `maxOverrides` / `maxOverrideSeconds` | Local handle count and maximum renewable lifetime; defaults 16 / 1800 seconds. |
| `conflictResources` | Known competing providers. Defaults to `{ 'weathersync' }`. |

Defaults provide a 30x clock, enabled seasonal weather patterns, gradual automatic wind and regional presentation. There is no temperature-driven climate, altitude wind, FiveM support or bundled NUI. Operator controls use optional Feather Admin; Weather still works independently.

## Wind progression and seasons

`windProgression` defines initial enabled/frozen controls, a real-time target interval (60 seconds by default), speed/direction slew limits and per-weather speed ranges. Targets change when shared weather changes or the interval expires. Current wind approaches its target gradually; clients project the same movement between snapshots. Wind freeze is independent of clock/weather/calendar freezes. `SetWind` applies manual values and disables automatic progression until resumed through `SetWindControl({automatic=true})`, Admin or `fwwindauto on`. Reset restores all configured defaults. Missing `windProgression` keeps older configs manual.

`seasons` defines enabled/frozen state, starting season/day, days per season and four validated weighted weather graphs. Defaults cycle spring → summer → autumn → winter, seven simulation days each. Calendar time follows simulated rate (or elapsed real seconds in wall mode) independently of clock freeze; rate zero pauses it. Calendar freeze does not stop weather progression. Seasons reset on resource restart; no database persistence, host timezone or real-world calendar dependency is introduced. Winter increases snowy forecast choices but does not force ground coverage; regional desert/tropical translations still apply.

`SetSeason({name='winter',day=1,enabled=true,frozen=false})` selects the calendar and rebuilds the future forecast, without replacing current weather or overriding a manual weather freeze. The next automatic weather interval uses the selected graph; unfreeze weather to resume progression. Day is bounded by configured `daysPerSeason`. Forecasts stop before the next unfrozen season boundary rather than claiming queued choices from the next graph. A custom `SetPattern` lasts until the next seasonal graph change, season-setting change or reset. Disabling seasons restores the base graph. Missing `seasons` keeps older configurations on the base graph.

`GetState()` snapshots add `season`, `windControl` and `windMotion`. Existing consumers can continue reading clock/weather/wind; client scene wind overrides still take precedence over the projected shared wind. Server capabilities advertise seasons/automaticWind support separately from their live control state.

Feather Admin is trusted by exact resource name in the default server mutation allowlist. Its Weather and seasons page uses server-enforced Authority capabilities and an audited, rate-limited RPC bridge. Removing its trust entry makes mutations fail closed; neither resource gains a mandatory dependency on the other.

If manual weather has no graph row, automatic progression resumes through the configured default row, or the alphabetically first graph row when the default is absent. Setting a pattern can therefore replace the entire graph safely.

## Regional presentation

Regional rules are enabled by default. Set `regions.enabled=false` for global-only presentation; check zone observations and climate rules when customizing policies or using another supported build. Restart Weather to reload configuration; its normal reset-to-config semantics still apply. There is no remote regional toggle or client-supplied region authority.

Included policy candidates use named zones from the map-zone catalogue, not bounding-box coordinate guesses:

| Policy | Membership | Example translation |
| --- | --- | --- |
| `grizzlies_snow` | District `GrizzliesWest` (type 10) | Rain → snow, drizzle/shower → snowlight, thunderstorm → blizzard. Preserve natural mountain ground coverage; no automatic forced coating (`autoSnow=false`). |
| `new_austin_dry` | Districts `GaptoothRidge`, `ChollaSprings`, `RioBravo`, `HennigansStead` (type 10) | Rain/shower → drizzle; snow → overcast; exceptional hurricane → sandstorm. This reduces precipitation rather than banning desert rain. |
| `guarma_tropical` | District `GuarmaD` (type 10) | Snow → rain, snowlight/sleet → drizzle, blizzard → thunderstorm. |

These are configurable design policies, not accepted climate boundaries or guarantees about every subarea. Western Grizzlies is deliberately a named district; whether its whole footprint should receive snow needs live review. Unmapped weather and ordinary/unknown zones retain shared weather. No native temperature read affects translation, avoiding local temperature/weather feedback loops.

The regional selector samples state/district at `sampleIntervalMs` (default 1000, bounds 250..10000), requiring stable candidate membership for `settleMs` (default 2000, bounds 0..30000). A boundary bounce cancels a pending switch. Higher priority wins overlaps; earlier configured rule wins ties. At most 16 rules, each with 1..16 named zones, are admitted. `transitionSeconds` controls the boundary blend (default 10, bounds 0..300). No independent regional clock, RNG, weather schedule, or forecast queue is created.

Each mapping is applied once to the current authoritative weather; translated output is never fed back as the next input. Automatic regional snow coverage is requested only by a matching `autoSnow=true` rule and a snowy translated weather. Leaving that policy restores shared coverage intent. An explicit global `weather.snow=true` remains authoritative even in desert/tropical rules. Primary coverage (`false`) does not promise removal of the engine's natural mountain snow.

Explicit scene weather bypasses regional weather translation; explicit scene snow overrides regional coverage. Channels remain independent: overriding weather alone does not implicitly claim the snow channel. Character's existing four-channel scene therefore remains noon/sunny/calm/primary coverage in every region. Sampling continues beneath scenes so final release uses the current location and latest shared state.

Enabled policy probes at most two zone natives per eligible sample, with no per-frame region loop. Disabled/absent policy performs no automatic zone probes. State and district observations are independent: a missing state does not discard a valid district, and vice versa. Missing types remain absent in diagnostics; they are not guessed or inferred. Total lookup failure or malformed observations fall back to shared presentation with a regional diagnostic error; stable observations can recover. A feature flag of `regions=1` means implementation support; `GetCapabilities().value.regionPolicy.enabled` reports actual startup enablement.

Client **F8** commands:

```text
fwregion probe
fwregion
```

`probe` performs an explicit read-only state/district observation even with policy disabled; it neither applies climate nor mutates authority. `fwregion` reports configured enablement, current/pending rule, observed zone hashes, sample age/error, and requested base/effective weather/snow. It is diagnostic output, not proof that the region or visuals are correct. Server `fwstate` reports support and enablement; it does not know a player's effective native zone.

`GetLocalState().value.effective` adds `region` diagnostics and `authoritativeWeather`; its existing `weather`/`snow` fields remain effective requested presentation. Server `GetState()` and `GetForecast()` are unchanged/global. Never treat these local observations as authoritative gameplay eligibility, damage, or persistence input.

## Result convention

All exports return `{ ok=true, value=... }` or `{ ok=false, code='...', message='...' }`, matching Feather Routing's convention. State and forecast results are detached copies. Never assume `ok=true` proves an in-game visual result.

Common failures: `invalid_config`, `invalid_input`, `denied`, `unavailable`, `limit`, and `not_found`.

## Server exports

| Export | Behavior |
| --- | --- |
| `GetCapabilities()` | Version, Contract 1, readiness/conflict, supported features and limits, bounded request rejection count. Available even when authority is blocked. |
| `GetState()` | Epoch/revision, clock, weather, wind, transition identity/remaining time, schedule generation, and long-stall recovery count. |
| `GetForecast({ count=... })` | Bounded future weather entries with relative simulation seconds and, when progressing, estimated real seconds. No absolute clock-time guarantee. |
| `SetClock(patch)` | Scalar patch of `mode`, `seconds`, `rate`, `frozen`, `offsetSeconds`; immediately reanchors UTC wall mode. Retains schedule choices/progress and retimes forecast estimates. |
| `SetWeather(patch)` | Scalar patch of `name`, `frozen`, `transitionSeconds`, `snow`; resets interval and rebuilds forecast even for a freeze-only patch. |
| `SetWind(patch)` | Scalar patch of `direction` / `speed`; switches to manual wind. |
| `SetWindControl(patch)` | Scalar `automatic` / `frozen` booleans; resumes or holds configured wind progression. |
| `SetSeason(patch)` | Scalar `name`, `day`, `enabled`, `frozen`; rebuilds forecast while retaining current weather. |
| `SetPattern(pattern)` | Atomically validate/copy a complete graph, reset weather interval, rebuild forecast. |
| `ResetEnvironment()` | Reset all domains immediately to config and rebuild forecast. No partial-reset options in this version. |

Mutation exports require an entry in `WeatherConfig.trustedResources`. Ownership comes from `GetInvokingResource()`, not a supplied owner field. There are no inbound network mutation events. The sole inbound network request bootstraps read-only state with a per-player cooldown.

Example from an explicitly admitted **server resource**:

```lua
local result = exports['feather-weather']:SetWeather({ name='rain', frozen=true, transitionSeconds=10 })
if not result.ok then print(result.code, result.message) end
```

`feather-weather:changed` is a server-local notification after an accepted explicit mutation, carrying `{ action, owner, state }`. It is not emitted for every automatic step or clock minute and is not a durable gameplay scheduler.

## Client scene exports

`GetLocalState()` returns the authoritative epoch/revision plus effective requested presentation, winning override channels, handle count, snapshot age, and `evidence='application_attempt_only'`. It returns `unavailable` while waiting, conflicted, degraded, or reporting a native error. Temperature is not exposed in this version.

`AcquireOverride(spec)` returns `{ handle, ttlSeconds }`; `UpdateOverride(handle, spec)` replaces the complete spec and renews lifetime. Renewing an unchanged presentation keeps its token stable, so weather transitions are not restarted by TTL renewal. `ReleaseOverride(handle)` is idempotent for an absent handle and denies release of another owner's live handle.

Scene spec fields:

- `priority`: integer up to that owner's configured `maxPriority`.
- `ttlSeconds`: positive renewable lifetime, at least 1 second and no greater than `maxOverrideSeconds`.
- Optional channels: `clock` (fixed seconds of week), `weather={name, transitionSeconds}`, `wind={direction,speed}`, `snow` (boolean). At least one channel is required.

Highest priority wins independently for each channel; oldest handle wins ties. Lifetime expiry or the invoking client resource stopping releases its handles. Global snapshots continue updating during a scene. The next application tick after final release projects the newest global clock and restores latest global weather/wind/snow policy.

Example integration from a **client resource**, after the operator adds its actual resource name to `overrideOwners`:

```lua
local opened = exports['feather-weather']:AcquireOverride({
    clock=12 * 3600,
    weather={ name='sunny', transitionSeconds=1 },
    wind={ direction=0, speed=0 },
    snow=false,
    priority=10,
    ttlSeconds=300
})
if opened.ok then
    local handle = opened.value.handle
    -- Retain the handle, renew before expiry if needed, and release on scene close.
    -- exports['feather-weather']:ReleaseOverride(handle)
end
```

Character `0.7.3` uses this API for selection/creation without changing global conditions; its optional adapter/config lives in Character. Existing installations must merge the owner entry into their Weather config. Stable horse previews can use the same API after separately admitting their actual resource name; no stables integration is installed. A bucket change alone does not acquire/release an override. Client owner checks support lifecycle coordination; they do not make a modified client authoritative or trustworthy.

## Operator commands

Console can run these directly. In-game operators need the corresponding `command.<name>` ACE and read results in F8; there is no Chat dependency.

| Command | Action |
| --- | --- |
| `fwstate` | Readiness/capabilities/diagnostics. |
| `fwforecast` | Queued global forecast. |
| `fwweather rain` | Set manual frozen weather; existing transition and snow settings are retained. |
| `fwclock 12 30` | Set frozen simulated time to 12:30, day Sunday. |
| `fwwind 90 2` | Set constant base wind. |
| `fwwindauto on` | Resume automatic wind; `off` holds the current values. |
| `fwseason winter 1` | Select winter day 1 and enable seasonal patterns. Does not unfreeze manual weather. |
| `fwreset` | Reset all clock/weather/wind/snow settings to configured defaults. |

Example scoped ACE: `add_ace group.admin command.fwweather allow`. Existing `group.admin command allow` also applies. This resource adds no ACE grants or player-facing sync bypass automatically.

## Synchronization and stop behavior

Snapshots carry a startup epoch and increasing revision. A new epoch requires a matched bootstrap response; older revisions are discarded. The client estimates one-way delay from half the bootstrap round trip, capped at one second, and projects from receipt time using its own elapsed timer. It never compares unrelated client/server timer origins. Bootstrap retries are bounded to one outstanding request with a 10-second timeout/retry interval.

Weather transitions apply on identity changes rather than restarting on every correction. Stale snapshots retain projected presentation with explicit `degraded` status while bootstrap retries continue. Override acquisitions/updates are blocked until healthy; release still works. Native dispatch failures are reported as `native_error` and retried on later application ticks.

On stop, Weather releases its documented native clock override and resets its snow coverage request to primary mode. Weather/wind may persist in the engine: no complete pre-start restoration is promised. A coordinated replacement provider or reconnect/server restart may be needed for full visual reset. Do not switch providers simultaneously or expect bucket isolation to stop another script's native writes.

## Validation

From this resource directory, run `lua54 tests/run.lua` (or your Lua 5.4 executable). Tests exercise the pure engine, validation, real server/client entry points under a mocked Cfx scheduler, override ownership/expiry, and native dispatch cadence. They do not start FXServer or prove visuals, multiplayer synchronization, performance, or release readiness.

License: GPL-3.0; see [LICENSE](LICENSE).
