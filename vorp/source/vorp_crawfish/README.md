# VORP-Crawfish
RedM resource allowing players to search Crawfish Holes to obtain live Crawfish and then harvest them from their inventory.

# Requirements
- VORP Core: [vorp-core-lua](https://github.com/VORPCORE/vorp-core-lua) (lua, recommended) OR [VORP-Core](https://github.com/VORPCORE/VORP-Core) (c#)
- VORP Inventory: [vorp_inventory-lua](https://github.com/VORPCORE/vorp_inventory-lua) (lua, recommended) OR [VORP-Inventory](https://github.com/VORPCORE/VORP-Inventory) (c#)
- Progress Bar: [vorp_progressbar](https://github.com/VORPCORE/vorp_progressbar) (recommended) OR [progressBars](https://github.com/outsider31000/VORP-Premade-server/tree/main/server-data/resources/%5Bothers%5D/progressBars)

# Installation
- Extract .zip contents and place the `vorp_crawfish` folder in your server's `resources/` folder (or `resources/[VORP]/` if preferred).
- Copy/Cut & Paste the icons found in the `vorp_crawfish/items/` folder into the `vorp_inventory/html/img/items/` folder.
- Run the queries found in `vorp_crawfish/items/items.sql` if your deployment of VORP has not already added them to your items database table.
- Read over `vorp_crawfish/config.lua` and configure the resource to suit your needs.
- Add `ensure vorp_crawfish` to your server.cfg file *after* `ensure vorp_core` and `ensure vorp_inventory` and (`ensure vorp_progressbar` or `ensure progressBars`).

# Notes
- You may encounter some Crawfish Hole locations which aren't yet included in the config; if you do, please feel free to submit them to github for addition so that everyone can enjoy the benefits.
- Crawfish Hole locations are not marked on the map or minimap, nor highlighted visually; they may be difficult to find if you don't know what you're looking for... also, be wary of alligators when searching!

## Original Author
adamdrakon
- https://github.com/adamdrakon

***Permission has been granted for VORPCORE to adopt this as an official resource with full control of its future development and distribution.***
