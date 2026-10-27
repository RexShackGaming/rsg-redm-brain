# vorp_housing

`vorp_housing` is a lightweight housing access system for RedM servers running VORP.

This version is not a real estate market script. It does not let players buy or sell houses in-game. Instead, houses are defined directly in [config.lua](./config.lua), and access is granted to specific characters through their `charIdentifier`.

If what you want is a clean way to:

- assign houses to characters
- give selected characters door access
- give selected characters storage access
- show private house blips only to the right owners

then this resource is exactly that.

> [!NOTE]
> This repo is closer to a permission-based housing layer than a full economy housing system. Ownership is configured by hand in the config file.

## Installation

1. Place `vorp_housing` in your server resources folder.
2. Make sure all required dependencies are already started.
3. Add `ensure vorp_housing` to your server config.
4. Open [config.lua](./config.lua) and configure your houses.
5. Restart the resource.

## How Doors Work

Doors are not handled internally by a custom lock system in this script.

This resource delegates door permissions to `vorp_doorlocks`.

When a valid owner loads in, [server/server.lua](./server/server.lua) gives that player permission on every door ID listed under the house if `DOOR = true`.

Each house uses:

```lua
DOORS = {
    4070066247,
    3444471262
}
```

Those values must match valid door IDs already managed by `vorp_doorlocks`.

If the door does not exist in your doorlock setup, this script cannot magically manage it for you.

> [!WARNING]
> A wrong door ID will not give the player access to the correct door. Always verify your door IDs in `vorp_doorlocks` first.


## Configuration Guide

Most of the script is configured in [config.lua](./config.lua).

## Common Setup Mistakes

The most common issues are usually these:

- using the wrong `charIdentifier`
- forgetting to add the correct door IDs in `vorp_doorlocks`
- reusing a storage `ID`
- putting the wrong storage `LOCATION`
- expecting players to buy houses in-game when this version does not support that
- leaving `CONFIG.DEV_MODE = true` on production

> [!IMPORTANT]
> If a player can see the house but cannot open doors or storage, check the owner entry first. In most cases, the issue is either a wrong `charIdentifier` or a permission flag set to `false`.

## Support

If you run into an issue:

- if you know your way around the code, feel free to open a PR
- if not, open an issue on GitHub
- or join the VORP Discord: [discord.gg/DHGVAbCj7N](https://discord.gg/DHGVAbCj7N)
