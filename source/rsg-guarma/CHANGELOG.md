# Changelog

All notable changes to rsg-guarma. Newest first.

## 3.1.1

### Added
- The ticket office can be moved by dragging its title bar. The position is remembered per player; double-click the title bar to centre it.

### Fixed
- The "How many" line no longer wraps onto two lines. The "(max N)" text is gone (the **Max** and **+** buttons already show the limit), and long translations move the quantity buttons to their own line.

## 3.1.0

### Added
- Sailing schedule: boats leave both ports together, with a boarding window and on-screen countdown. The ticket is taken at departure.
- Crossing screen and arrival banner (`rsg-zonenotify`).
- Return pair: two tickets at a discount.
- Rescue passage home from Guarma for stranded players.
- Customs searches on arrival at Saint Denis, with seizure, fine and lawman alert.
- Island cargo: four Guarma-only goods to buy and sell, with daily limits and optional `rsg-economy` pricing.
- Fussar alert level with reinforcements and `rsg-reputation` changes.
- Port management: job discounts, ticket income to an `rsg-society` account, hurricane closures and `/guarmaport`.

### Changed
- Needs `oxmysql` (new table `rsg_guarma_players`) and four new items.
- Instant travel is now `Schedule.enabled = false`.
- The buy callback returns `true` on success; office data comes from `rsg-guarma:server:getOffice`.

## 3.0.2

### Fixed
- The game clock no longer freezes while on Guarma (pausing rsg-weather sync also stopped time updates).
- Island weather is re-applied if rsg-weather restarts.
- Leaving Guarma or stopping the resource no longer removes the shipwreck IPL when another resource (for example rsg-mapping) loaded it.
- Stopping the resource now restores the horizon, water and minimap, and no longer changes ambience or IPLs for players on the mainland.
- Port workers respawn if deleted, and are no longer left behind if the resource stops during their fade-in.
- A travel ticket is not taken if the port's destination is misconfigured.
- The travel fade can no longer loop forever.
- A late purchase reply can no longer overwrite a reopened ticket office.
- A weather interval of 0 can no longer lock up the server.

### Security
- Travel is blocked while in last stand (server), and the ticket office and travel are blocked while hogtied or lassoed (client).
- Inventory is locked during the crossing.

### Added
- Push-to-talk works while the ticket office is open (`AllowPushToTalkWhileOpen`, `PushToTalkControls`).
- "Max" quantity button; the quantity stops at what you can afford.
- Cooldown messages show the seconds left.
- Killed patrols are replaced after `Soldiers.respawnTime`, even if players stay in the area.

### Changed
- The buy callback now returns `{ cash, owned }` on success (was `true`).
- Players in other routing buckets no longer cause soldiers to spawn.
- Removed an unneeded item check, a fixed UI sync delay and unused CSS.

## 3.0.1

### Documentation
- `DOCS.md`: added a generated technical reference (dependencies, database, configuration, exports, callbacks, events, commands, items, locales) with code examples, read straight from the source.
