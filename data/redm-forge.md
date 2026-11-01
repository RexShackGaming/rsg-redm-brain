# RedM Forge (redm-forge.vercel.app)

Online reference: https://redm-forge.vercel.app/ — fan-made RDR2/RedM tools by DatMayo (unofficial, not affiliated with Rockstar/Take-Two). Data generated with rdr-convert. Known issues: https://redm-forge.vercel.app/known-issues/

**Role in the brain:** a *visual cross-check* for models, coordinates and animations. Local data (`rdr3_discoveries/`, `natives/db/`, `server/environment.md`) is always the first stop. RedM Forge is the second opinion, and the place to send the user when a choice needs eyes (which ped looks right, where exactly on the map).

| Section | What's there | Use for | Local equivalent |
|---|---|---|---|
| Models | Peds, animals, horses, props with preview images, model hash and 3D view | Confirming a model name/hash exists; picking a model visually | `rdr3_discoveries/peds/`, `rdr3_discoveries/objects/` |
| World map | Zoomable map with coordinates and named places | Coords for spawn points, NPCs, blips, zones | `rdr3_discoveries/zones/`, `server/environment.md` |
| Animation builder | Build/preview animations | Anim dict + clip combos | `rdr3_discoveries/animations/` |

---

## How an AI model should use it

### 1. What the AI can and can't do with the site
- The site is a **JS-rendered app**. Fetch tools (WebFetch, curl, plain HTTP) usually get only the shell page: no model list, no hashes, no map data.
- There is **no public API or JSON endpoint**. Don't invent URLs like `/models/<name>` or `?search=`; they aren't documented.
- What works:
  - **With a browser tool** (Claude in Chrome, the built-in browser, Playwright): open the site, use its search/filters, read the hash or coords off the page.
  - **Without a browser:** use the local data, then ask the user to check the value on RedM Forge and paste the result back.

### 2. Lookup workflow (models / props / animals / horses)
1. Search locally first: `rdr3_discoveries/MAP.md` → `peds/peds_list.lua` or `objects/` (grep, never read the whole file).
2. Found locally → use it. Use RedM Forge only if the user wants to see the model or the name looks doubtful.
3. Not found locally → open RedM Forge Models in a browser tool and search the name. Otherwise ask the user to look it up.
4. Record the confirmed value in `data/README.md` → "Local additions" table (name / hash / notes, source: RedM Forge).
5. Tell the user where the value came from, e.g. "`a_c_horse_arabian_white` (from peds_list.lua, confirmed on RedM Forge)".

### 3. Coordinates workflow (world map)
1. Check `server/environment.md` and `rdr3_discoveries/zones/` for known town/area names.
2. For a specific spot, ask the user to pick it on the RedM Forge map, or better, to stand there in game and run `/coords` (or the admin menu equivalent). In-game coords include Z and heading; map coords usually don't.
3. Treat map coords as approximate: always mark them `-- TODO: verify in game` in config.
4. Store coords as `vector3(x, y, z)` / `vector4(x, y, z, h)` in `config.lua`, never hard-coded in client logic.

### 4. Animation workflow
1. Search `rdr3_discoveries/animations/` (ingameanims, megadictanims, scenarios) for the dict/clip.
2. Use the RedM Forge animation builder to preview the combo, or ask the user to, before writing it into a script.
3. Always `RequestAnimDict` + wait for `HasAnimDictLoaded` (with a timeout) before `TaskPlayAnim`, and `RemoveAnimDict` afterwards.

### 5. Hashes in code
Model hashes are JOAAT of the **lowercased** model name, so they're the same as `joaat('model_name')` / `GetHashKey('model_name')`.
- Prefer the readable name in code and config: `model = 'p_chair05x'`, then `joaat(Config.Model)` at runtime.
- If you only have a numeric hash (e.g. from a native's output), RedM Forge or `natives/db/` can map it back to a name. Write the name in a comment next to the number.
- Always check the model loads: `IsModelValid` → `RequestModel` → wait for `HasModelLoaded` (with a timeout) → `SetModelAsNoLongerNeeded` after spawning.

### 6. Rules
- **Never present a RedM Forge value you didn't actually see.** If the page couldn't be read, say so; don't guess "it's probably…".
- If RedM Forge and local data disagree, flag it to the user and test in game. The local copy may be out of date or the site may have a known issue.
- Cite the source for every value: local file path, or "RedM Forge (models/map/animation builder)".

---

## Prompt snippets (copy into a chat with any AI model)

**Model check**
> Using the RedM brain, find the ped model for a female saloon worker. Search `data/rdr3_discoveries/peds/` first. Give me the model name and `joaat` usage, and say which ones I should preview on https://redm-forge.vercel.app/ before picking.

**Prop for a script**
> I need a safe prop for rsg-bankrobbery. List candidate prop names from `rdr3_discoveries/objects/`, and I'll confirm them on RedM Forge's 3D viewer. Don't guess names that aren't in the local files.

**Coordinates**
> Give me a config block of NPC locations for Valentine, Rhodes and Saint Denis. Mark every coordinate as needing in-game verification, and tell me which ones to check on the RedM Forge map.

**Hash to name**
> This native returned hash `-1234567890`. Find the model name in `natives/db/` or `rdr3_discoveries/`. If it's not there, tell me to look it up on RedM Forge rather than guessing.
