# rsg-theatre

Theatre Raleur (Saint Denis) stage shows for RSG Framework, rebuilt from Rockstar's `show_nbx_*` scripts.

## Features
- Ticket seller NPC at the theatre ticket fence (ox_target) with a playbill NUI
- Server-scheduled shows (rotation or random) every `Config.ShowInterval` minutes
- Ticket holders near the stage when the show starts get the full performance: curtain opens, performers play the original anim scene, curtain closes
- 14 shows: Can-Can I & II, Big Band I & II, Fire Performer, Fire Dancer, Fire Breather, Snake Dancer I & II, Sword Dancer, Feats of Strength, Escape Artist, Escape from the Noose, Odd Fellows
- NPC audience fills the theatre seats during a show (Rockstar's seat list and Saint Denis population set), configurable with `Config.Audience`
- Multi-part acts play their playlists in sequence, switching as each part ends, like Rockstar's scripts
- Persistent stage curtain while you're near the theatre, opening and closing the way Rockstar's script does
- Audience volunteers and hanging props (Odd Fellows participant, the noose rope) recreated from the original scripts
- `/theatre [showId]` admin command to start a show now (stops a running show first)
- Theatre door locks added to rsg-doorlock automatically on first start (main doors open, side doors locked)

## Languages
All player-facing text (notifications, playbill UI, blip, show names and descriptions) is in `locales/`: en, de, el, es, fr, ja, nl, pl, pt-br, ro. Set the language with ox_lib's `ox:locale` convar, e.g. `setr ox:locale "de"`.

## Install
1. Drop `rsg-theatre` into your resources and `ensure rsg-theatre` after rsg-core, ox_lib, ox_target, oxmysql and rsg-doorlock.
2. No items needed. Tickets are held server-side (per character) until the holder watches a show.
3. On first start the four theatre door locks are inserted into `rsg_doorlocks` (skipped if a door with the same name already exists). Restart rsg-doorlock once afterwards to load them. `doors.sql` is the same data if you prefer to run it by hand.

## Config
- `Config.TicketPrice`, `Config.TicketCooldown`, `Config.TicketSeller.buyDistance`
- `Config.ShowInterval`, `Config.FirstShowDelay`, `Config.ShowOrder`, `Config.MaxShowLength`
- `Config.Stage`, `Config.AudienceRadius` – ticket holders must be inside this radius when the curtain rises
- `Config.Backstage` – where performers and props are created before the scene walks them on
- `Config.CurtainRange`, `Config.CurtainOpenDelay`, `Config.CurtainCloseDelay`
- `Config.Audience` – `enabled`, `fill` (share of the 53 seats used), population set and fallback models
- `Config.Shows` – each show's scene, playlist, optional `sequence`, `origin`, `flags`, `volunteer` and `rope`
- `Config.AdminCommand`, `Config.AdminPermission`

## Notes
- If an admin forces a show, the next scheduled show waits until it has finished instead of being skipped.
- Performers, props and the NPC audience are spawned locally on each viewer's client, so nothing is networked.
- Only the first Can-Can sets its scene origin in the decompiled scripts; every other act uses the origin baked into its scene. If an act stands off-mark, set its `origin = nil`.
- Bullet Catcher and Flex Fight aren't included: both need a volunteer from the crowd interacting with the performer.

Support: https://buymeacoffee.com/rexshack
