# Changelog

All notable changes to rsg-factory. Newest first.

## 3.1.0

### Added
- **rsg-society integration** (`server/sv_society.lua`, `Config.Society`): a new factory gets its own job `factory_<id>` and a job society in rsg-society as soon as `/createfactory` runs. Existing factories get theirs on the next start.
- The owner holds the boss grade; trusted workers hold the first grade. Buying, transferring and selling a factory move the grades along (a sold or transferred factory starts clean for the next owner).
- Earnings (the fees other players pay) go into the society account when `Config.Society.EarningsToSociety = true`. The Earnings tab, selling and transferring use that account; earnings already in the factory move over on the next start.
- Renaming a factory renames its job and society. Deleting a factory closes the society, removes its job and pays the balance to the owner if online.
- Everything is optional and best effort: without rsg-society the factory works as before.

## 3.0.0

### Documentation
- `DOCS.md`: added a generated technical reference (dependencies, database, configuration, exports, callbacks, events, commands, items, locales) with code examples, read straight from the source.
