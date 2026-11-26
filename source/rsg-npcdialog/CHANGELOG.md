# Changelog

## 3.1.1
- Security: journal data requests are rate limited, so the new quest marker checks can't be spammed.
- Security: talk objectives now always count once, because higher counts could be farmed by repeating a conversation.
- Fixed: with rsg-core gold items on, gold rewards could be lost with a full inventory.
- Fixed: the journal's quest badge style changed the badges in the editor list.
- UX: scheduled NPCs no longer end conversations when the next time slot has the same spot and scenario; markers update as soon as an NPC appears; the journal says when it can't load; the editor hides fields that have no effect.
- Performance: marker refreshes are grouped, spread over several frames, and no longer delay replies or quest updates.

## 3.1.0
- New: **quest markers**. NPCs with a quest to give or take back get a coloured blip (yellow to offer, green to hand in) and a note on the talk prompt.
- New: **pinned quests** and **GPS routes** from the journal.
- New: **daily and weekly quests** with a set reset time, and **random pools** that offer a different pick each day or week.
- New: **time of day and weather requirements** (rsg-weather).
- New: **NPC opening hours and schedules**, with an optional different spot and scenario for each time slot.
- The editor has fields for all of the above. Long cooldowns now show hours and minutes.
- New file `server/world.lua`, new config options, and new text in all 11 locales. No database changes.

## 3.0.1
- Security: quest payouts are locked while running; opening conversations is rate limited.
- Fixed: cash rewards could be lost with a full inventory (money items); a failed money reward now undoes the whole reply.
- Fixed: errors from other resources could leave a conversation request unanswered or a reply half saved.
- Fixed: quest requirement checks could show "locked" when several were running at once.
- Fixed: horse trampling kills were rejected; reused entity handles could stop later kills counting.
- Fixed: editor saves could fail for long player names; a quest requirement matching a line ID skipped the typo check; the placement preview ped could be left behind on restart.
- Cached progress is now freed when a player leaves.
- UX: long lines scroll while typing, number keys skip typing, the journal keeps its scroll position, and errors are now shown instead of failing silently.
- Performance: the control-blocking thread only runs while a UI is open; players with no active quests are skipped by the quest tick.
- Removed unused `Config.Debug`, three unused locale keys and dead code.

## 3.0.0
- First release.
- Branching NPC conversations with a cinematic camera and a fixed-size box with replies side by side.
- Dialogs from config files, other scripts (exports) or the in-game editor.
- Requirements, costs, rewards, saved progress and named actions, with rsg-skills and rsg-reputation support.
- Quests: deliver, visit, talk, kill and custom objectives, with a journal, on-screen tracker and map blips.
- Editor for NPCs and quests, with searchable name lists, name checks on save and dialog preview.
