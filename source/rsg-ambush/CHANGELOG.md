# Changelog

All notable changes to rsg-ambush. Newest first.

## 3.2.1

### Added
- Optional rsg-deliveries hook: `GetAmbushMultiplier` raises the trigger chance while the rider has a delivery contract.
- Local server events `rsg-ambush:server:ambushStarted` and `rsg-ambush:server:ambushWon` for other resources.

## 3.2.0

### Added
- **Safe spawn points:** every bandit is placed on ground that is not water, not too steep and not inside an interior (`Config.SpawnChecks`), with several tries before giving up. If no safe spot exists the ambush is cancelled and the player's cooldown is not used up.
- **Server-side roll:** the server now rolls the trigger chance, so a modified client can't skip it. Added a per-player request throttle (`Config.RequestThrottle`).
- **Reputation hook (rsg-reputation, optional):** honor changes the ambush chance (`Config.Hooks.Honor`); beating a gang gives honor and standing in the nearby town.
- **Skills hook (rsg-skills, optional):** a higher level in the configured skill brings bigger gangs (`Config.Hooks.Scaling`); beating a gang gives skill XP.
- **Areas (rsg-economy, optional):** the nearest town changes the chance and which gangs appear (`Config.Zones`).
- **Bounty:** cash for every killed bandit, paid by the server once the gang is beaten, multiplied for on-duty jobs such as lawmen (`Config.Bounty`).
- **Gang behaviour:** bandits flee or surrender when badly hurt (`fleeChance`, `surrenderChance`); fled bandits that get away are removed; surrendered bandits drop their weapons and put their hands up. Sparing bandits earns a little mercy honor.
- **Sniper:** a gang can place one bandit on high ground (`sniper`, used by the Lemoyne Raiders).
- **Reinforcements:** a second group can ride in from behind, after a delay or once the first group is nearly beaten (`reinforcements`). The server plans it and validates the second registration.
- **Gang loot tables:** `loot` per gang replaces the global cash/items.
- **Strongbox:** a rare extra cash/item reward carried by one random bandit; only the server knows which (`Config.Strongbox`).
- **Warning:** a sound and a notice a few seconds before the bandits appear (`Config.WarningSeconds`, `Config.WarningSound`).
- **Death delay:** when the player dies the gang rides off and the ambush is removed after `Config.DeathCleanupDelay` instead of vanishing at once.
- Locale keys `ambush_warning`, `ambush_reinforcements`, `bounty_title`, `bounty_paid`, `loot_strongbox`, `log_won_title`, `log_field_bounty`, `log_field_killed`, `log_field_spared`, `log_field_strongbox` in all 11 languages.

### Changed
- `rsg-ambush:server:requestAmbush` takes an optional `force` (debug only) and returns `{ id, gang, count, wave, region }`.
- `rsg-ambush:server:registerPeds` takes a fourth argument `batch` (1 = first group, 2 = reinforcements).
- `rsg-ambush:server:finish` takes a second argument `aborted`.
- New event `rsg-ambush:server:claimWin`: the client reports the gang beaten and the server checks the bodies before paying.
- The Lemoyne Raiders' sniper rifle moved from the normal weapon list to their `sniper` role.

## 3.1.0

### Fixed
- Client: the monitor thread could end an ambush while it was still spawning, which threw `attempt to index a nil value` in the spawn code and spawned a false "you fought them off" notice. Spawning is now flagged and skipped by the monitor.
- Client: `cleanup()` cleared its state only after deleting the entities (it can yield for network control), so a character unload or resource stop during that window could run it twice. State is now cleared first and entities are deleted from a snapshot.
- Client: a bandit horse whose rider failed to spawn was left standing riderless; it is now deleted.
- Client: a loot request the server rejected gave no feedback; the player now gets a notification (`loot_failed`).
- Server: bandit network ids that had not replicated yet were accepted without any check. Registration now waits for the entity, then requires a non-player ped of the gang's model that is owned by the registering player and near them, and that no other ambush has claimed.

### Added
- Server removes the bandits and horses it registered when the ambush ends, the player disconnects or crashes, the ambush expires, or the resource stops (previously they could be orphaned in the world).
- Bandit horses are registered and validated too.
- Server config validation at start (`LootCash`, `LootItems`, `Gangs`) with console warnings instead of runtime errors; unknown loot items are reported once.
- Players in jail are not ambushed; ambushes are also skipped during scripted control loss (`IsPlayerControlOn`).
- Each bandit's blip is removed when that bandit dies.
- The gang <-> player relationship is restored after the ambush instead of staying hostile for the rest of the session.
- Expired ambushes and finished cooldowns are swept every minute.
- Webhook queue is capped (100) so a Discord outage can't grow memory.
- Locale keys `loot_failed` and `sec_register_invalid` in all 11 languages.

### Changed
- Cleanup requests network control of every entity once and waits once, instead of up to a second per entity.
- Resource stop deletes entities without waiting.
- Spawning no longer waits for each ped to network before creating the next.

## 3.0.1

### Documentation
- `DOCS.md`: added a generated technical reference (dependencies, database, configuration, exports, callbacks, events, commands, items, locales) with code examples, read straight from the source.
