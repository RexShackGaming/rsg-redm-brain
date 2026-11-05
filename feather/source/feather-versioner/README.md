# Feather Versioner

Version: **0.1.7**.

Feather Versioner is an optional, server-only release notification service. It compares installed resource manifest versions with operator-selected GitHub release policies and prints concise console reports.

It never downloads releases or overwrites, starts, stops, restarts, or migrates checked resources. GitHub availability never controls framework readiness, and Versioner does not replace runtime contract negotiation.

## Installation

Place `feather-versioner` in the server resources directory, configure explicit repository mappings in `config.lua`, and add:

```cfg
ensure feather-versioner
```

It may start before or after checked resources. Missing resources or invalid/missing manifest version metadata produce `unknown`. Stopped resources with valid metadata can still be compared. Checked resources are never modified.

## Configuration

The shipped `config.lua` enables checks and includes first-party Feather mappings. Review that list before starting Versioner; remove unwanted mappings or set their `enabled = false`. Set `Enabled = false` to block all new outbound checks, including console/manual checks. Status and help remain available. Configuration files are read on Versioner startup; file edits take effect on Versioner restart, with no hot reload.

Example operator policy (add `MyServer` to `AllowedOwners` for this fork):

```lua
Config.Resources = {
    ['feather-core'] = {
        repository = 'FeatherFramework/feather-core',
        channel = 'stable'
    },
    ['my-fork'] = {
        repository = 'MyServer/my-fork',
        channel = 'prerelease',
        pin = '1.4.2',
        ignore = { '1.5.0' },
        label = 'My Fork'
    }
}
```

`AllowedOwners` is an outbound GitHub owner allowlist. Repository identities are validated and converted internally into GitHub API URLs; arbitrary URLs are never accepted. Manifest discovery is reserved for a later release and remains disabled.

Stable checks exclude drafts and prereleases. The prerelease channel includes both stable and prerelease releases and selects the newest valid SemVer. Ignored versions are removed from target selection. A pin becomes the operator target: an exact match is `pinned`, a lower installation is `outdated`, and a higher installation is `ahead`.

`ReportNewerThanPin = true` adds separately labeled upstream information when the newest channel-eligible release exceeds the pin, including ignored releases. It never changes the pin target, status, or summary counts. Stale upstream information is labeled stale. The default `false` produces no extra pin information and requires no extra request.

Global fields and shipped defaults:

| Field | Default | Meaning |
| --- | --- | --- |
| `Enabled` | `true` | Permit outbound checks; manual checks also obey this switch |
| `CheckOnStart` | `true` | Schedule an initial check |
| `StartupDelaySeconds` | `15` | Initial delay, 0–3600 |
| `IntervalMinutes` | `720` | Periodic interval, 5–10080 |
| `ResponseDeadlineSeconds` | `15` | Ignore responses after this deadline, 1–120; does not cancel the underlying HTTP request |
| `CacheTtlMinutes` | `120` | Freshness after a successful fetch/304, 1–10080 |
| `ManualRefreshCooldownSeconds` | `60` | Manual refresh cooldown, 0–3600 |
| `MaxBackoffMinutes` | `240` | Maximum retry/rate-reset delay, 1–10080 |
| `JitterPercent` | `10` | Interval jitter, 0–50 |
| `MaxConcurrentRequests` | `2` | Concurrent upstream requests, 1–8 |
| `MaxResponseBytes` | `1048576` | HTTP body and each cache-file byte limit, 1024–4194304 |
| `MaxReleases` | `50` | Releases processed per upstream, 1–100 |
| `MaxReleaseTitleBytes` | `160` | Title byte limit, 1–512 |
| `ReportCurrent` | `false` | Show current entries; actionable stale warnings always show |
| `ReportSummary` | `true` | Print status counts |
| `ConsoleColors` | `true` | Use Cfx console colors |
| `IncludeReleaseTitle` | `true` | Print sanitized release titles |
| `ReportNewerThanPin` | `false` | Optional upstream information for pins |
| `AllowManifestDiscovery` | `false` | Reserved; `true` is rejected |
| `AllowedOwners` | `{ 'FeatherFramework' }` | Allowed GitHub owners; an empty table permits any validated owner |
| `CacheFile` | `'versioner-cache.json'` | Resource-local filename, at most 80 bytes, starts with a letter, digit, or underscore |
| `Resources` | First-party mappings | Operator-selected policies |

Numeric settings require finite integers within these ranges (numeric strings are accepted). Switches require Lua booleans. Per-resource fields are `repository` (required), `channel` (`stable` or `prerelease`, default `stable`), optional `pin`, `ignore` (version list), `enabled` (default `true`), and `label` (sanitized, bounded display name). Invalid global/policy configuration prevents automatic startup checks.

Versions must use strict `major.minor.patch` SemVer. A leading `v` is accepted on release tags. Build metadata is retained for display but does not affect precedence.

## Commands

Server console only:

```text
feather versions
feather versions check
feather versions <resource>
feather versions help
```

Manual checks respect `Enabled`, `ManualRefreshCooldownSeconds`, active-cycle exclusion, and repository backoff. They bypass cache freshness to revalidate upstream. Periodic checks use jitter, bounded concurrency, ETags, response deadlines, retry backoff, and stale-cache fallback. Duplicate upstream mappings share one request per cycle.

Console reports use semantic Cfx colors by default: green for current or pinned, yellow for updates or ignored releases, blue for locally-ahead versions, and red for unknown or error states. Set `ConsoleColors = false` in `config.lua` for plain text output.

## Cache and outages

Versioner writes only `CacheFile` and `CacheFile .. '.bak'` inside its own resource. Schema 1, file bytes, up to 512 entries, repository identity, finite integer timestamps, dense bounded release lists, SemVer/tag agreement, URLs, titles, and ETags are validated before loaded data is used. Invalid entries are discarded with a bounded count diagnostic. A wholly invalid snapshot triggers backup recovery.

Missing, empty, oversized, unreadable, malformed, or unsupported-schema primary files all try the backup. If both candidates are unusable, Versioner continues empty with a warning; two absent files are a normal first run. Recovery/dropped-entry diagnostics identify backup use without printing cache contents.

Saving writes the previous validated snapshot to backup before the new primary; the first save seeds backup with the new validated snapshot. Corrupt on-disk primary bytes are never copied into backup. Successful writes are verified by reading back the exact bytes. Encoding, validation, native write failure, or read-back mismatch leave the cache dirty and report a bounded warning that identifies the failure stage. This is recoverable sequential persistence, not atomic replacement across two files; disk failure or interrupted writes still need operator recovery. Do not edit a deployed cache to test failures.

Network failures retain valid cached releases as stale and print the failure reason even for otherwise-current resources. Successful checks clear that warning. Stop invalidates outstanding callbacks before they can mutate cache or report results. No tokens or private-repository authentication are supported; outbound requests reveal configured repository identities to GitHub and never contain full release bodies in console output.

## Verification

From the resource directory, run the offline suite with Lua 5.4:

```sh
lua5.4 tests/run.lua
```

The PR/push workflow also checks Lua syntax. Tests isolate filesystem, HTTP, timers, metadata, console, and JSON decoding/encoding behind fixtures; they make no live requests or resource-file writes. They do not certify Cfx JSON/filesystem behavior, live GitHub, FXServer restarts, or hosted releases. Delivery evidence and remaining acceptance gates: [Versioner hardening validation](../feather-framework-docs/feather-versioner/HARDENING_VALIDATION.md).

Run these from the server console:

```text
VersionerContractSmokeTest
VersionerSemverSmokeTest
VersionerFixtureSmokeTest
VersionerCacheAcceptanceSmokeTest
```

`VersionerCacheAcceptanceSmokeTest` uses real Cfx JSON with an in-memory filesystem and fixed fixture policies. It checks 11 cache recovery/write-failure cases without touching deployed cache files, changing operator config, or making HTTP requests. Keep the `tests` files with the resource to use this optional console command.

After configuring at least one repository, run `feather versions check` to exercise the live GitHub path.

## Migration

Release deployment remains manual and operator-controlled. Remove legacy `github_version_check` manifest metadata only after a resource is mapped to a published Versioner release policy. Runtime consumers must continue using capability and contract negotiation rather than release versions.
