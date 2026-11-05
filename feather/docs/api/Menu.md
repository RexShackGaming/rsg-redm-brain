---
title: Choose your Feather Menu version
---

# Choose your Feather Menu version

This address previously documented `feather-menu`. Its API reference now lives at [Legacy: Menu v1](/api/resources/Menuv1).

::: warning Existing integrations still need their original dependency
**Feather Menu v1 (`feather-menu`) is Legacy. Feather Menu v2 (`feather-menu-v2`) is the official Feather Framework menu system for new development.** V2 has a different API and does not automatically replace v1 in existing RedM resources.
:::

| What your resource calls | Documentation and dependency |
| --- | --- |
| `exports['feather-menu']:initiate()` | [Legacy: Menu v1](/api/resources/Menuv1); keep `feather-menu`. |
| `exports['feather-menu-v2']:CreateMenu(...)` | [Menu v2](/api/resources/Menuv2); use `feather-menu-v2`. |

Both can be installed together. Keep their original folder names, start each before its consumers, and migrate each consuming resource before removing Legacy. Menu v2 currently has Contract 1 alpha status; consult its guide for release readiness.
