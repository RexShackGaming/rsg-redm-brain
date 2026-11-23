# Changelog

All notable changes to rsg-economy. Newest first.

## 3.2.0

### Added
- **Player elections:** each town can elect a mayor (candidacy, voting, result phases; one vote per licence; candidate fee; term length). The sitting mayor is an official of the town. New `Elections` tab, `Config.Elections`, admin commands `/startelection`, `/endelection`, `/cancelelection`, `/setmayor`, `/clearmayor`, exports `GetMayor`, `StartElection`, `SetMayor`, `ClearMayor` and event `rsg-economy:server:mayorChanged`.
- **Admin panel (Admin tab):** staff add, edit and remove towns, set their law job and officials, and use their own position as the town centre. Saved in the database and merged with `Config.Regions`.
- **Limits and alerts:** per-official daily withdrawal limit (`Treasury.Withdraw.PlayerDailyLimit`) and alerts to other online officials for large withdrawals (`AlertAbove`).
- **Key:** `F7` (rebindable in the game's key settings) opens the panel; `Config.UseKeyMapping`, `Config.Key`.
- **Treasury interest:** optional daily interest on treasuries (`Treasury.Interest`), ledger kind `interest`.
- **Weekly report:** a telegram summary to the mayor and online officials through `rsg-telegram` (optional dependency; `Config.Report`).
- **Project effects:** projects can now have an `effect`: `wage` (law workers on duty are paid from the treasury), `tradeBonus` (better sell prices) and `taxHoliday` (no tax). 
- **Import duty:** new `duty` tax category on items brought in from another town (`origin` in `Quote`, or `Config.Duties.Origins`).
- Client export `HasProject(region, id)` and `GlobalState['rsg-economy:projects']`.
- 75 new locale keys in all 11 languages.

### Upgrade notes
- Six new tables are created automatically (`rsg_economy_meta`, `_region`, `_mayor`, `_election`, `_candidate`, `_vote`). Manual installs: import `install.sql` again (it is safe to re-run).
- The default `government` official entry still applies to every town; with elections on, consider giving it a higher `minGrade`.

## 3.1.1

### Security
- Donations: added `Treasury.MinDeposit`, `DepositCooldown`, `DonationRepMin` and `DonationRepCooldown`. Before, a 1-cent donation every 0.4 s gave unlimited rsg-reputation honor and standing and flooded the ledger.
- Funding a project is claimed before it is paid, so two officials funding the same project at once can no longer both be charged.
- Citizen ids in ledger actors are now hidden from non-officials.
- Calls made before the saved data loaded (start-up) wait for it instead of being overwritten by the load.
- Balances are capped at the database limit; admin commands reject huge values; a deposit that cannot be stored is refunded.
- Reputation price modifier is limited by the new `Config.ReputationLimit`.
- Admin commands record who ran them in the ledger.

### Fixes and cleanup
- Opening the panel and then the ledger within 0.7 s no longer returns nothing (separate throttles).
- Saves run in one transaction and a failed save is retried (before, background saves were not retried).
- Ledger is read in index order and pruned with a new `idx_created` index (added to existing tables automatically). Ledger keeps at least 2 days so the daily limit stays correct.
- Removed duplicated helper functions, the duplicate `uiFocus` flag and the copy of the official check.

### UI
- Panel opens on the town you are in (else a town you run).
- Shows how much you can still withdraw today; thousands separators on amounts.
- A refused tax change, deposit or withdrawal keeps what you typed.
- The panel will not open before a character is loaded.

### Locales
- New keys `msg_min_deposit` and `ui_remaining` in all 11 languages.

### Upgrade
- Nothing to do with `AutoDatabase = true`. For a manual install run: `ALTER TABLE rsg_economy_ledger ADD KEY idx_created (created);`

## 3.1.0

### Documentation
- `DOCS.md`: added a generated technical reference (dependencies, database, configuration, exports, callbacks, events, commands, items, locales) with code examples, read straight from the source.
