---
title: Feather HUD
---

# Feather HUD

Feather HUD displays the active Character’s cash, gold, tokens, XP, and derived rank in an always-on resource strip. It owns presentation only and stores no economy data.

## Installation

```cfg
ensure feather-core
ensure feather-hud
```

## Settings

`Config.XPPerLevel` controls display-only level calculation. `Config.ResourceStrip` controls the anchor, edge padding, top padding, scale, and optional scrim. Choose an anchor from `HudPosition.TopLeft` through `HudPosition.BottomRight`; invalid values fall back safely.

HUD currently has no public exports. It reacts to Character compatibility events and should not be used as an economy authority.
