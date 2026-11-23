# Changelog

All notable changes to rsg-crafting. Newest first.

## 3.3.0

### New
- Book: search box, favourite recipes, Max quantity button, category icons and translated category names
- Craft queue: line up several crafts that run back to back (`Config.Queue`)
- Failure chance with partial refunds (`Config.Failure`, recipe `failchance`)
- Crafted item quality that rises with crafting XP (`Config.Quality`, recipe `quality`)
- Blueprints: recipes hidden until a blueprint item is used (recipe `blueprint`, new `rsg_crafting_recipes` table)
- Crafting stations: recipes that need a forge, workbench, ... nearby (recipe `station`, `Config.Stations`, new `rsg_crafting_stations` table)
- Shared crafting: nearby players can help, shortening the craft and earning XP (`Config.Assist`)
- Admin commands `/craftingxp`, `/craftingrecipe`, `/craftstation`, `/removecraftstation`
- rsg-skills `speed_bonus` perk shortens crafts (`Config.Skills.SpeedBonus`)
- Exports `LearnRecipe`, `ForgetRecipe`, `HasLearnedRecipe`, `IsNearStation`

### Changed
- Push-to-talk keeps working while the book is open (`Config.AllowPushToTalkWhileOpen`)
- Database tables are created on start (`Config.AutoDatabase`); `install.sql` added for manual installs
- Dependencies: added `oxmysql`, `rsg-target`, `rsg-gizmo`
- Closing the book while a craft request is in flight no longer cancels the craft
- New locale keys in all 11 languages

## 3.2.1

### Fixes and cleanup
- Server: a NaN batch quantity from a modified client could skip the ingredient and craft-time checks; it is now rejected
- Server: recipe validation also checks `crafttime`, `requiredxp` and `xpreward`, and ingredient, tool and output amounts must be whole numbers (bad recipes are reported on start)
- Server: recipe list function defined before the callback that uses it; duplicated rsg-skills checks merged
- Client: the book can't be opened while dead, and closes (and cancels any craft) when the character unloads
- Client: crafting stops only its own animation instead of clearing every ped task

## 3.2.0

### Documentation
- `DOCS.md`: added a generated technical reference (dependencies, database, configuration, exports, callbacks, events, commands, items, locales) with code examples, read straight from the source.
