---
title: Toolkit Overview
---

# Feather Toolkit

Feather Toolkit is the developer kit for reusable client utilities that were previously mixed into Core. It uses named exports, result envelopes, resource ownership, bounded model loading, and automatic cleanup.

```cfg
ensure feather-toolkit
```

`Config.ModelTimeoutMs` limits model loading and `Config.MaxKeyListeners` bounds registered listeners. Toolkit has no `initiate()` object: call named exports directly and check every result.

```lua
local capabilities = exports['feather-toolkit']:GetCapabilities()
if not capabilities.ok or capabilities.value.contract < 1 then
  error('Feather Toolkit contract 1 is required')
end
```

Toolkit owns models, generic objects and peds, blips, controls, key listeners, prompts, text rendering, and clipboard access. Teleport, persistent horses, and wagons remain domain-owned.

Run `ToolkitServerContractSmokeTest` in the server console and `ToolkitContractSmokeTest` in F8.
