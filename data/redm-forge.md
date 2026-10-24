# RedM Forge (redm-forge.vercel.app)

Online reference: https://redm-forge.vercel.app/ — fan-made RDR2/RedM tools by DatMayo (unofficial, not affiliated with Rockstar/Take-Two). Data generated with rdr-convert.

Use it to **cross-check** model names, hashes and coordinates found locally. Local files stay the first stop; tell the user when a value came from RedM Forge.

| Section | What's there | Use for | Local equivalent |
|---|---|---|---|
| Models | Peds, animals, horses, props with preview images, model hash and 3D view | Confirming a model name/hash exists and picking the right model visually | `rdr3_discoveries/peds/`, `rdr3_discoveries/objects/` |
| World map | Zoomable map with coordinates and named places | Finding coords for spawn points, blips, zones | `rdr3_discoveries/zones/`, `server/environment.md` |
| Animation builder | Build/preview animations | Finding anim dict + clip combos | `rdr3_discoveries/animations/` |

## Hashes
Model hashes are JOAAT of the **lowercased** model name — same as `joaat('model_name')` / `GetHashKey` in Lua. Prefer `joaat('name')` in code over hard-coded numbers.

## Notes
- The site is JS-rendered; if a fetch returns little, ask the user to check the page or use the local data.
- Check the site's "known issues" page if a value looks wrong.
