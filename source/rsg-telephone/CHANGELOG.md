# Changelog

All notable changes to rsg-telephone. Newest first.

## 3.1.1

### Added
- Calls now tell rsg-voice 3.2.0+ that a call is running (`SetCallActive`), so radio and party voice cannot cut in or take over the voice target during a call (`Config.Priority.Call` in rsg-voice). Older rsg-voice versions ignore it.

## 3.1.0

### Documentation
- `DOCS.md`: added a generated technical reference (dependencies, database, configuration, exports, callbacks, events, commands, items, locales) with code examples, read straight from the source.
