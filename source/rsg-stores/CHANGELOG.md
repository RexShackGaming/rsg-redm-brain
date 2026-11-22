# Changelog

All notable changes to rsg-stores. Newest first.

## 3.6.0

- **Owner resale:** owners can put their store up for sale from Manage Store > Settings > Sell Store. Another player buys it at the owner's price; the owner is paid to their bank (online or offline) together with the till, stock stays with the store, staff are let go and the new owner starts with a clean ledger. Blocked while upkeep is owed. `Config.OwnedStores.AllowResale`.
- **Bank payment:** the buy window now has **Pay Cash** and **Pay From Bank** buttons. `Config.OwnedStores.BankPayment`.
- **For-sale map blip** on every store that is for sale (admin price or resale price). `Config.OwnedStores.ForSaleBlip`.
- **Purchase ledger and webhook detail:** store purchases write a `bought` ledger row for the new owner; the webhook shows the payment method and the previous owner for resales.
- **Admin Audit tab** in `/storeadmin`: store created / edited / deleted, owner evicted, store bought and every admin-panel change (till, upkeep, staff, transfer, close, settings, upkeep run), with who and when. New table `rsg_shops_audit`, trimmed to `Config.AdminPanel.AuditKeep` rows.
- **Upkeep eviction warning:** when one more missed period would repossess a store the owner gets a final warning, and owners with unpaid upkeep are told on login.
- **Bulk price edit:** Manage Store > Settings > Adjust All Prices raises or lowers every listing by a percentage.
- Admin Settings tab: new toggles for bank payment and resale. New column `rsg_shops_npcs.resale_price` (added automatically). 40 new locale strings in all 11 languages.

## 3.5.3

- Audit: reviewed all net events, callbacks and admin handlers (admin gating, throttles, server-side pricing, atomic stock and purchase paths) and found no exploits. Removed two unused locale keys (`cl_create_blip`, `cl_delete_npc`) from all 11 languages.

## 3.5.2

- Wording: "shop" is now "store" in English, German (Laden) and Japanese (店舗) texts, the README and DOCS, and the Store Sign item label (config definition and rsg-core `items.lua`). Item name `shopsign` is unchanged so existing signs keep working.

---

## 3.5.1

- Buying a store that is for sale now shows a Buy / Cancel confirmation window first. 4 new locale keys (`cl_buy_confirm_*`) in all 11 languages.

---

## 3.5.0

### New
- **Stores for sale.** Set a **Sale Price** on an unowned player store in `/storeadmin` and any player can buy it with cash at the counter. Evicted or repossessed stores go back on sale at the same price.
- New `sale_price` column on `rsg_shops_npcs` (added automatically and in `install/rsg-stores.sql`), `Config.OwnedStores.MaxSalePrice` and `MaxStoresPerPlayer`. 10 new locale keys in all 11 languages.

---

## 3.4.0

### New
- **Admin Overview tab.** Live totals, a searchable store list with status filters (open, overdue, closed, packed up), recent activity across all stores and a button to run upkeep now.
- **Per-store management.** Finance with till adjustments (reason required, logged to the ledger and the admin webhook), filterable ledger, upkeep tools, staff ranks, ownership transfer, evict and repossess.
- **Live Settings editor.** Common `config.lua` values editable in-game, validated on the server, saved in the new `rsg_shops_settings` table and pushed live to all players. Each value can be reset to its default.
- **The admin command is now `/storeadmin`** (was `/createshop`).
- New `Config.AdminPanel`. New ledger kind `admin`. 180 new locale keys in all 11 languages.

### Notes
- `rsg_shops_settings` is created automatically and added to `install/rsg-stores.sql`.
- Native `<select>` popups are not used: the panel's existing dropdowns are already custom HTML.

---

## 3.3.0

### New
- **The till is the society account.** With `Config.Society.SalesToSociety` (default `true`) every sale, buy-back, wholesale purchase, upkeep charge and till withdrawal of a store that has a society uses its rsg-society account instead of the `rsg_shops_npcs.balance` column. The owner sees the same money in the Manage Store panel and in the society menu.
- Money already in a store's database till is moved into its society account on the next start.
- Set `SalesToSociety = false` for a separate till. If rsg-society is stopped, stores fall back to the database till until it is back.
- Each sale shows as a `till [rsg-stores]` entry in the society ledger (cleaned up by rsg-society's `PruneDays`).

## 3.2.0

### New
- **rsg-society integration.** Every player-owned store now gets its own job (`store_<id>`) and a job society in rsg-society (treasury, members, ranks, storage, audit). The owner holds the boss grade; hired staff hold the first grade and are added and removed with the staff list. The job label follows the store name.
- Applies to stores opened with the shop sign, stores an admin creates or hands to a player, and (on the next start) stores that already exist.
- Closing a store (pack up, eviction, repossession, admin delete or clearing the owner) removes the society and job and pays the account balance to the owner when they are online. If the owner is offline the balance is forfeited and printed in the server console.
- New config `Config.Society` (`Enabled`, `JobPrefix`, `JobType`, `Grades`). Needs rsg-society 3.4.0 or newer; it is optional and a stopped rsg-society never blocks a store.
- New file `server/sv_society.lua`.

## 3.1.2

### Documentation
- `DOCS.md`: added a generated technical reference (dependencies, database, configuration, exports, callbacks, events, commands, items, locales) with code examples, read straight from the source.
