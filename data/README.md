# Data lookup index

**First stop: `rdr3_discoveries/MAP.md`.** It's a local copy of femga/rdr3_discoveries, refreshed by `tools/refresh.sh`. Search the local files there before fetching anything below.

Data tables are too big to keep here, so fetch the exact file when you need it. **Never guess values.**

Condensed from Forza-Studios/RedM-AI-Knowledge-Brain (much of the `ai/` data originates from femga/rdr3_discoveries). Use alongside `rsg-redm` for framework code; this skill covers game natives and data.
Raw base: `https://raw.githubusercontent.com/Forza-Studios/RedM-AI-Knowledge-Brain/main/`

| Need | Path |
|---|---|
| Ped config flags (full, with player defaults) | `ai/CPED_CONFIG_FLAGS/README.md` |
| Ped reset flags (set every frame) | `ai/CPED_RESET_FLAGS/README.md`, `ai/PLAYER_RESET_FLAGS/README.md` |
| Combat styles, blackboards | `ai/COMBAT_STYLES/README.md`, `ai/BLACKBOARDS/README.md` |
| Combat action disable, ragdoll blocking | `ai/COMBAT_ACTION_DISABLE_FLAGS/README.md`, `ai/RAGDOLL_BLOCKING_FLAGS/README.md` |
| Animal tuning params | `ai/ANIMAL_TUNING_BOOL_PARAMS/README.md`, `ai/ANIMAL_TUNING_FLOAT_PARAMS/README.md` |
| Carrying, looting, lasso/hogtie, transport flags | `ai/CARRYING_FLAGS/`, `ai/LOOTING_FLAGS/`, `ai/LASSO_HOGTIE_FLAG/`, `ai/TRANSPORT_CONFIG_FLAGS/` (README.md) |
| Relationship groups per ped model | `ai/RELATIONSHIP/README.md` |
| All events + data sizes | `ai/EVENTS/README.md`, `ai/EVENTS/events.lua`, DataView helper `ai/EVENTS/dataview_by_Gottfriedleibniz.lua` |
| Peds / MP peds | `peds/peds_list.lua`, `peds/MP_male.csv`, `peds/MP_female.csv` |
| Outfits, decals, wearable states | `peds_customization/*.lua`; clothes in `clothes/` |
| Objects, pickups, composites | `objects/`, `objects/pickup_list.lua`, `objects/composites/composites_list.lua` |
| Interiors | `interiors/interiors_coords_and_hashes.lua`, `interiors/interior_sets/` |
| Doors | `doorHashes/` |
| Weapons / ammo / components | `weapons/weapons.lua`, `weapons/ammo_types.lua`, `weapons/weapon_components.lua` |
| Vehicles, trains | `vehicles/vehicles_list.lua`, `vehicles/trains/` |
| Animations, scenarios, emotes | `animations/{ingameanims,megadictanims,scenarios,kit_emotes_list,anim_events}/` |
| Audio | `audio/{soundsets,frontend_soundsets,music_events,audio_banks}/` |
| PTFX, markers, animpostfx, timecycles | `graphics/` |
| Blip styles/modifiers, colours, textures | `useful_info_from_rpfs/` |
| Controls, stats, zones, weather, bones, IMAPs | `Controls/`, `Stats/`, `zones/`, `weather/`, `boneNames/`, `imaps/` |
| Tasks (animal, horse, item interaction) | `tasks/` |
| UI databindings | `databindings/` |
| JSON datasets | `datasets/{peds,horses,weapons,items,blips,prompts,hashes}.json` |
| Native API docs + examples | `docs/natives/{prompts,blips,peds,entities,tasks,streaming}/{api,examples}.md` |
| Framework notes | `docs/frameworks/{rsg,vorp,redem}/`, `docs/frameworks/ns-lib.md` |

If a path 404s, list the folder with the GitHub API: `https://api.github.com/repos/Forza-Studios/RedM-AI-Knowledge-Brain/contents/<folder>`.

## Local additions
- `../natives/db/` — full natives database (same data as redm.info/natives).
- `redm-info.md` — redm.info lookup guide.
- `redm-forge.md` — RedM Forge (models with hashes + 3D view, world map coords, animation builder).
Add verified values here as you use them (model name / hash / notes):

| Type | Name | Hash | Notes |
|---|---|---|---|
