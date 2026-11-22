# Changelog

All notable changes to rsg-lockpick. Newest first.

## 3.1.0

### Added
- Optional rsg-reputation integration (`Config.Reputation`): `StartAttempt` accepts `reputation = { action, region }` and applies that rsg-reputation action when the attempt succeeds. Only actions listed in `Config.Reputation.Actions` are accepted, and `DefaultAction` can apply one to every successful attempt. Existing callers are unchanged.

### Documentation
- README and DOCS describe the new option; the README version line is corrected.
