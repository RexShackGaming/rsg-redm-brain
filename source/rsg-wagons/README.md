# rsg-wagons

**Version 3.0.0** · Wagon yards for RSG Framework (RedM).

Walk up to a yard keeper, open a full-screen catalogue, preview any wagon in 3D with an orbit camera (the same controls as rsg-stables), buy it, name it, take it out, use its storage and trade it back in.

Dependencies: `rsg-core`, `rsg-inventory`, `rsg-target`, `oxmysql`. No ox_lib.

Full developer and server-owner reference: [DOCS.md](DOCS.md)

## Features
- Shop keeper NPCs at Valentine, Saint Denis, Strawberry, Blackwater and Tumbleweed, opened through **rsg-target**
- Full NUI catalogue in the RSG leather & gold style: category tabs, search, capacity/slots/seats stat bars, price and class badges
- Live 3D preview of the selected wagon (with its draft horses) and orbit camera: hold the arrows or **A / D** to rotate, scroll or **+ / −** to zoom, slow idle spin
- **My Wagons** tab: take out, return, rename and sell owned wagons
- Wagon condition saved when stored; condition below 90% counts as *damaged* and lowers the trade-in value (taken from the RDR2 wagon fence script)
- Each owned wagon has its own rsg-inventory stash (`wagon_<id>`) sized by the wagon's capacity and slots
- One wagon out per player; it despawns and returns to the yard when the player leaves
- Database table created automatically
- 10 languages

## Installation
1. Put `rsg-wagons` in your resources folder (e.g. `resources/[framework]/rsg-wagons`).
2. Add `ensure rsg-wagons` to your `server.cfg` after `rsg-core`, `rsg-inventory` and `rsg-target`.
3. Database: the `player_wagons` table is created automatically on first start. To install it manually instead, set `Config.AutoDatabase = false` and import `install.sql`.
4. Restart the server.

> If you are replacing the older rsg-wagons, its `rsg_wagons` table is left untouched. This version uses a new `player_wagons` table, so wagons owned under the old script are not moved over.

## Configuration (`shared/config.lua`)

Liveries (`Config.Liveries`) and colour counts (`Config.Tints`) per model live in `shared/liveries.lua`; cargo (`Config.Propsets`) and lantern (`Config.Lanterns`) sets live in `shared/propsets.lua` — remove entries to hide them.

| Option | Default | Description |
|---|---|---|
| `Config.AutoDatabase` | `true` | Build the table on start. `false` = import `install.sql` yourself |
| `Config.MoneyType` | `'cash'` | Money type taken for purchases and paid for trade-ins |
| `Config.MaxWagons` | `5` | Max wagons a player can own |
| `Config.SellPercent` | `0.50` | Trade-in = price × this |
| `Config.DamagedThreshold` | `90` | Condition % below this counts as damaged |
| `Config.DamagedSellModifier` | `0.5` | Damaged wagons get this fraction of the trade-in |
| `Config.StoreDistance` | `15.0` | How close the player must be to the yard's preview spot to use the keeper menu / sell |
| `Config.CallKey` | `0xF3830D8E` (J) | Key to call your wagon to you (`false` = off) |
| `Config.CallCommand` / `Config.FleeCommand` | `'callwagon'` / `'fleewagon'` | Chat commands to call / send away your wagon (`false` = off) |
| `Config.CallNearDistance` | `25.0` | If the wagon is closer than this, calling just says it's nearby |
| `Config.CallRoadDistance` | `60.0` | A called wagon appears on a road within this distance, otherwise beside you |
| `Config.WagonBlip` | `enabled = true`, `style = 'BLIP_STYLE_PLAYER_COACH'`, `sprite = 'blip_player_coach'` | Map/radar blip on the wagon you have out |
| `Config.FieldRepair` | 35%, 3 x `resource_wood`, 8 s, `/repairwagon` | Temporary patch on the road (item or money) |
| `Config.YardRepair` | `$0.5` per missing % | Full repair to 100% at a yard (My Wagons → Repair) |
| `Config.HuntingCart` (`shared/huntingcart.lua`) | 20 carcasses, tarp, 12 butchers, rsg-hunting prices | Hunting cart (huntercart01): stow carcasses, sell the load at a butcher |
| `Config.StoreRadius` | `35.0` | Wagon and player must both be within this distance of a yard (keeper or preview spot) to store |
| `Config.StorePrompt` | `true` | Show a hold-to-store prompt when near a yard with your wagon out |
| `Config.StoreKey` | `0x760A9C6F` (G) | Key for the store prompt |
| `Config.StoreHoldTime` | `1000` | How long (ms) to hold the store key |
| `Config.UseDistance` | `4.0` | Distance to the wagon to open its storage |
| `Config.InteractDistance` | `3.0` | Target distance to the yard keeper |
| `Config.ActionCooldown` | `1500` | ms between shop actions per player |
| `Config.NameMaxLength` | `24` | Max wagon name length |
| `Config.Preview` | table | Camera radius/min/max, height, rotate speed, idle spin, show draft animals |
| `Config.Blip` | table | Enable, sprite (`blip_shop_coach_fencing`), scale |
| `Config.Stores` | 5 yards | `label`, `npcModel`, `npc` (vec4), `preview` (vec4: preview + spawn point), `showBlip` |
| `Config.Categories` | 5 | Category ids and Font Awesome icons for the tabs |
| `Config.Wagons` | 33 models | `label`, `category`, `price`, `weight` (kg), `slots`, `seats`, `tier` (1–4), `description`, optional `stores` |

## How to use
1. Go to a wagon yard (wagon blip) and target the yard keeper → **Browse Wagons**.
2. Pick a category or search, click a wagon to preview it. The list swaps to the wagon's details; press **Back** (or **ESC**) to return to the list.
3. Rotate with **A / D**, arrow keys or the on-screen buttons (camera row in the details panel), zoom with the scroll wheel or **+ / −**.
4. Use the **Livery** and **Colour** arrows to pick a paint scheme and base colour (only at purchase; it's permanent and applied every time the wagon is taken out) (the preview updates live), then **Purchase** → name the wagon → it's added to **My Wagons**.
5. In **My Wagons** choose a wagon → **Take Out**. It appears at the yard's preview spot.
6. Target your wagon → **Open Wagon Storage**.
6b. Target your wagon → **Customise Wagon** to pick its **Cargo** and **Lanterns** (live preview, then **Save**). Saved per wagon and seen by everyone.
6e. **Hunting Cart**: carry a carcass (or have one on your horse) to your cart → target → **Stow Carcass** (up to 20; the tarp rises as it fills). Drive to any butcher → target the cart → **Sell Cart Load** for rsg-hunting's prices, items and hunting XP.
6d. Damaged or wrecked on the road? Target the wagon → **Patch Up Wagon**, or `/repairwagon` for a wreck. Costs 3 wood (configurable) and brings it to 35% only; get it fully repaired at a yard (My Wagons → **Repair**).
6c. Target your wagon → **Send Wagon Away** (or `/fleewagon`) to send it off; press **J** (or `/callwagon`) to call it back to the nearest road. It stays out until stored, even across server restarts and relogs: after logging in, just press **J**.
7. Bring it back to any yard and store it: hold **G** on the yard prompt, target the wagon → **Store Wagon**, or use **Return Wagon** at the keeper. **Sell** a stored wagon for its trade-in value.
8. **ESC** closes the shop (from the details panel it goes back to the list first).
9. Drag any window by its title bar to move it; positions are remembered. Double-click a title bar to reset it.

## Developer examples
```lua
-- server: what wagon does this player have out?
local active = exports['rsg-wagons']:GetActiveWagon(source) -- { id, netId, model } or nil

-- server: list a character's wagons
local wagons = exports['rsg-wagons']:GetPlayerWagons(Player.PlayerData.citizenid)
```

## Locales
`en`, `de`, `el`, `es`, `fr`, `ja`, `nl`, `pl`, `pt-br`, `ro`. Set the language with `setr rsg:locale de`.

Support: https://buymeacoffee.com/rexshack
