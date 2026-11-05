---
title: Feather Settings
---

# Feather Settings

Feather Settings owns the player settings menu and its default `PGUP` input. Feature resources retain ownership and persistence of their own preferences.

## Settings

`Config.Hotkey` selects the menu control. `Config.DefaultLocale` and `Config.Languages` configure the language selector. Settings depends on Core, [Menu v2](/api/resources/Menuv2) (`feather-menu-v2`), and PVP. Start those dependencies before Settings.

## Client provider API

```lua
exports['feather-settings']:RegisterChoice(spec) -> boolean, reason?
exports['feather-settings']:UnregisterChoice(id, ownerResource?) -> boolean
```

```lua
exports['feather-settings']:RegisterChoice({
  id = 'my-resource:display-mode',
  ownerResource = GetCurrentResourceName(),
  label = 'Display Mode',
  control = 'arrows',
  options = {
    { value = 'Temporary', label = 'Temporary' },
    { value = 'Always', label = 'Always' }
  },
  initialValue = GetDisplayMode(),
  setEvent = 'MyResource:Settings:SetDisplayMode'
})
```

Supported controls are `dropdown`, `arrows`, and `slider`. Sliders require numeric `min`, `max`, and `step` fields; dropdowns and arrows require between 2 and 20 string-valued options. Providers validate, apply, and persist their own values and are removed automatically when their resource stops.
