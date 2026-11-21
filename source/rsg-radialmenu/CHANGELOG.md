# Changelog

All notable changes to rsg-radialmenu. Newest first.

## 3.3.0

### Added
- **Rebindable key in tap mode:** with `Config.HoldToOpen = false` the menu key is registered through rsg-core `RegisterKey`, so players can rebind it in the game's key settings. New `Config.UseKeyMapping` and locale key `key_open` in all 11 languages. Hold mode is unchanged and still polls `Config.Keybind`, because the NUI detects the key release by name.

### Changed
- Requires rsg-core 3.5.0 or newer for the rebindable key.

## 3.2.1

### Documentation
- `DOCS.md`: added a generated technical reference (dependencies, database, configuration, exports, callbacks, events, commands, items, locales) with code examples, read straight from the source.
