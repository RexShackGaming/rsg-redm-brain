---
title: Feather Versioner
---

# Feather Versioner

Feather Versioner is an optional server-only GitHub release notification service. It reports available releases but never downloads, overwrites, starts, stops, restarts, or migrates resources.

## Configuration

Add explicit repository mappings to `Config.Resources`. Each entry selects `stable` or `prerelease`, and may specify a pin, ignored versions, and display label. `AllowedOwners` limits outbound GitHub repository owners. Arbitrary URLs and automatic manifest discovery are not accepted.

```lua
Config.Resources['feather-core'] = {
  repository = 'FeatherFramework/feather-core',
  channel = 'stable'
}
```

## Commands

```text
feather versions
feather versions check
feather versions <resource>
feather versions help
```

Versioner has no public gameplay exports. GitHub outages use bounded retries and stale cache without affecting framework readiness.
