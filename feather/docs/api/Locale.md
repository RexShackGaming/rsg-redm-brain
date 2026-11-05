---
title: Locale (Core)
---

# Locale

Locale registration and translation are provided by Feather Core.

```lua
exports['feather-core']:RegisterLocale(locale, translations) -> Result
exports['feather-core']:TranslateLocale(key, variables?, locale?) -> Result
exports['feather-core']:SetClientLocale(locale) -> Result
```

See the [Core resource reference](/api/resources/Core) for the shared result contract and configuration.
