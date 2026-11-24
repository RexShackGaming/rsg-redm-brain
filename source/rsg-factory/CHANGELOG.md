# Changelog

All notable changes to rsg-factory. Newest first.

## 3.2.0

### Added
- **Activity log and report:** the owner tab lists the last runs (player, line, batches, fee) and the top users of the last 7 days (new `rsg_factory_log` table, pruned after `Config.Log.KeepDays`).
- **Worker wages** (`Config.Wages`): owners set a wage per batch for trusted workers, paid from the society account.
- **Fee discounts** (`Config.Fees.TrustedDiscount`, `Config.Fees.JobDiscounts`): trusted workers run free by default; jobs can get a % off.
- **Repeat last run** button on the production tab.
- **Supply stash** (`Config.Stash`): an rsg-inventory stash per factory whose wood, coal and buckets refill fuel and water automatically.
- **Ready blip:** factories with finished products for you get their own blip colour and a "(ready)" label.
- **Sell-back of upgrades** (`Config.SellbackUpgradePercent`).
- New texts in all 11 languages.

### Changed
- Selling pays a share of the price the owner **paid** (new `paid` column) instead of the current price, plus the upgrade share. The next owner starts with no upgrades, no wage and a clean log; selling is refused while the supply stash holds items.
- Deleting a factory hands queued products to online players first and warns once about anything still lost (delete again within 60 s to confirm).
- The trusted-worker and transfer pickers list only online players at the factory. The database search of every character is gone, and trusted workers must be present to be added.
- A request sent while another one is still running now shows a notice.

## 3.1.1

### Fixed
- Adding water no longer eats the filled bucket when the player has no room for the empty bucket: the supply is refused with an inventory-full message before anything is taken.
- Deleting a factory is refused while its owner is offline and its earnings account holds money, so the balance can no longer be destroyed (new `delete_owner_offline` text in all 11 languages).
- The panel closes by itself if the player dies while it is open.

### Changed
- New `idx_finish` index on `rsg_factory_queue` for the 30 second finished-production check. Added automatically (and in `install.sql`).

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
