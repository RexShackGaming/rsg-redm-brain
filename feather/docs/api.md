---
layout: doc
title: Documentation
description: Resource references and developer APIs for Feather Framework.
---

# Build on Feather

Use these references to configure Feather resources and integrate your own gameplay systems. Each resource owns a focused responsibility; shared development utilities live in Toolkit.

<div class="feather-doc-grid">
  <a class="feather-doc-card feather-doc-card--wide" href="/api/resources/Core">
    <span class="feather-doc-card__label">Start here</span>
    <strong>Framework resources</strong>
    <p>Core contracts, Character sessions, Roles, Routing, World, Settings, HUD, Admin, and more.</p>
    <span class="feather-doc-card__arrow">Explore resources →</span>
  </a>
  <a class="feather-doc-card" href="/api/toolkit/Overview">
    <span class="feather-doc-card__label">Developer kit</span>
    <strong>Toolkit</strong>
    <p>Owned entities, blips, controls, prompts, rendering, and clipboard utilities.</p>
    <span class="feather-doc-card__arrow">Open Toolkit →</span>
  </a>
  <a class="feather-doc-card" href="/api/Inventory">
    <span class="feather-doc-card__label">Gameplay system</span>
    <strong>Inventory</strong>
    <p>Server-authoritative instances, ledgers, access, transactions, equipment, and item-owner hooks.</p>
    <span class="feather-doc-card__arrow">Read Inventory →</span>
  </a>
  <a class="feather-doc-card" href="/api/resources/Menuv2">
    <span class="feather-doc-card__label">Interface</span>
    <strong>Menu v2</strong>
    <p>The official Feather menu system: build NUI menus, pages, tabs, and controls from Lua.</p>
    <span class="feather-doc-card__arrow">Read Menu v2 →</span>
  </a>
</div>

Existing resources using `feather-menu` still need [Legacy: Menu v1](/api/resources/Menuv1). [Menu v2](/api/resources/Menuv2) is the official system for new Feather development and uses a different API. Keep Legacy until the resources that depend on it have migrated.

## API conventions

Most current Feather contracts use named exports and return a structured result:

```lua
{ ok = true, value = value, meta = optionalMeta }
{ ok = false, code = 'stable_code', message = 'Safe summary', details = optionalDetails }
```

Always check `result.ok == true` before reading `result.value`. Calls that mutate gameplay state belong on the server unless a resource reference explicitly marks an export as client-side.

## Finding the right owner

- Use **Core** for accounts, sessions, providers, RPC, locale, guards, policy, events, and notification dispatch.
- Use **Toolkit** for reusable client utilities that do not own a gameplay domain.
- Use the named gameplay resource for domain state such as Character, Inventory, Roles, Routing, or World.
- Pages labeled **REVIEW** describe an older surface that does not currently map to a cloned resource. Treat them as migration context, not a current contract.
