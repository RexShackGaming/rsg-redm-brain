# vorp inventory V2

A complete refactor from original vorp_inventory to be use with vorp_core for RedM


## Requirements
- vorp core
- oxmysql
- vorp lib

## How to install
- Download the lastest version
- Add and if needed rename the folder to `vorp_inventory` folder to `resources/[VORP]`
- Add `ensure vorp_inventory` to your `server.cfg` file
- To change Language verify/add yours, if exists in folder `languages`  to use it  go to config.lua and apply the name of the language there to be used.
- to update to v2 use the sql file `sql_v2_update.sql`


## Features
- Slots and Weight inventory based 

- Ammo 
  - Gunbelt to store all ammo
  - ammo is added to weapon from gunbelt and reduced when you shoot
  - manual reload allowing to remove ammo from gunbelt into weapon and saves it in the weapon
  - ammo register is done in vorp weapons

- Drop system
    - Props can be spawned for dropped items(weapon models are used for weapons)
	- Adanced prop placement using gizmo
	- Drop all for items
	- Quick Drop 
	- Drop amount for items
	- Drop items or weapons outside of the inventory on the container
	  - can use shift + drag to drop all
	  - can use alt + drag to drop half
	  - can drag to choose amount

- Give system
  - select players to give instead of ids or names
  - give quick (when item is 1 of count)
  - give amount when item has more than one
  - give all

- Items
  - rarity
  - groups `(dynamic)`
  - instructions 
  - dynamic weight 
  - limit
  - dynamic metadata `(reserved words for metadata see documentation)`
  - dynamic image
  - degradation when in main inventory

- Weapons
  - manual reload option
  - no reserved ammo ammo only stores in clip
  - each weapon has its own ammo
  - weight
  - custom descriptions api
  - custom label api
  - serial number or an custom serial number api
  - limit `(can hold more with a job)`
  - native degradation and condition (config)
  - adjustable reload speeds 


- Freedom item/weapons placement in inventory
  - replace items with other items
  - drag anywhere from secondary inventories

- Secondary Inventory
  - slot based
  - extensive api
  - controls to quick add items or take
  - item groups

- Hot bar for items and weapons

- Weapon components container to easly add components as items to weapons

- Handcraft items with recipe list instead og guessing what an item needs to be crafted


## DOCUMENTATION
Inventory API [Documentation](https://docs.vorp-core.com/api-reference/inventory)

## Credits
- To [Val3ro](https://github.com/Val3ro) for the initial work in lua
- To [Emolitt](https://github.com/RomainJolidon) for the conversion from C# to lua.

## Support
[Discord](https://discord.gg/JjNYMnDKMf)

