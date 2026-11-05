---
title: Feather Admin
---

# Feather Admin

Feather Admin is the operator interface for moderation, reports, cases, player notes, staff roles, inventory administration, announcements, audit viewing, player management, and developer tools.

## Requirements and installation

Admin uses [Menu v2](/api/resources/Menuv2) and character-scoped roles from Feather Authority.

```cfg
ensure oxmysql
ensure feather-core
ensure feather-character
ensure feather-organizations
ensure feather-authority
ensure feather-toolkit
ensure feather-inventory
ensure feather-menu-v2
ensure feather-admin
```

Configure the menu command, reports, moderation limits, logging/webhook, hierarchy, and permission matrix in `configs/`. Grant the first character-scoped Owner from the server console with `AdminBootstrapOwner <connectedSource> <stableRequestId>` before using Admin for routine role management.

## Public API

Admin is primarily an operator UI, not a general gameplay API. Its supported server export is:

```lua
exports['feather-admin']:checkConnectionBan(primaryIdentifier)
```

Connection-gate integrations should use the current Core gate and Admin moderation contracts rather than calling Admin network events. The `feather-admin:*` events are internal UI transport and are not a supported external mutation API.

## Production guidance

- Keep permissions least-privileged.
- Configure Discord webhook delivery only for Admin audit reporting; Core does not provide generic Discord helpers.
- Use Admin’s Inventory and Authority integrations rather than editing those databases.
- Run the supplied contract and persistence smoke tests in staging after upgrades.
