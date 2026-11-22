# Changelog

## 3.5.0

### Changed
- **rsg-society is now required** (3.1.0 or newer) and owns gang identity, members, ranks, permissions and the bank. rsg-gangs reads them from it and no longer keeps its own copy, so the two menus can no longer disagree.
- Invite, kick, promote, demote, leadership transfer, deposit, withdraw, rename, colour and tag in the gang menu and the staff panel now call rsg-society. Creating or disbanding a gang there creates or disbands the rsg-society gang.
- Permission checks use the rank's rsg-society permissions. `Config.Ranks` is only the staff panel's rank choices, and `Config.DefaultLeaderRank` / `Config.DefaultJoinRank` were removed.
- Gang money paid in or out by territory income, upkeep, claims, bounties and stash upgrades goes through rsg-society's account and shows in its ledger.
- Changes made in rsg-society's own menu (members, ranks, money, name, colour, tag, disband) show up here immediately.
- `GetPlayerGang` now also returns `level`; `rank` is the rank name from rsg-society.

### Upgrading
- Start rsg-society before rsg-gangs. On first start rsg-society imports the old `rsg_gangs`, `rsg_gang_members` and `rsg_gang_logs` data (nothing is deleted). Gangs that rsg-society could not import stay inactive and are listed in the console.
- `rsg_gang_members` and the `bank`, `label`, `color` and `owner` columns of `rsg_gangs` are no longer used.
