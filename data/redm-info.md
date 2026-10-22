# redm.info (RedM Index) — online lookup

https://redm.info/ is a searchable front-end over data that is mostly local already. Use local files first; use the site to cross-check or when local search finds nothing.

| redm.info section | Local equivalent | Site URL |
|---|---|---|
| Natives (~7.6k) | `natives/db/` (INDEX.tsv + per-namespace .md) | https://redm.info/natives , detail `/natives/<hash>` |
| Hashes (~82k joaat: peds, anims, props, weapons, vehicles, IMAPs) | `data/rdr3_discoveries/` (start at MAP.md) | https://redm.info/hashes |
| Clothes (~16k shop items, APPLY_SHOP_ITEM_TO_PED snippets) | `data/rdr3_discoveries/clothes/` | https://redm.info/clothes |
| Blips (~592 sprites) | `data/rdr3_discoveries/useful_info_from_rpfs/` | https://redm.info/blips |
| Props | `data/rdr3_discoveries/objects/` | https://redm.info/props |
| Item Tool | — | https://redm.info/item-tool |

Site sources (per its FAQ): rdr3natives.com, VORPCORE/RDR3natives, CitizenFX shared natives, femga/rdr3_discoveries.
No public API or download. Fetch single pages with WebFetch only; don't crawl it.
When a value comes from the site, tell the user the URL.
