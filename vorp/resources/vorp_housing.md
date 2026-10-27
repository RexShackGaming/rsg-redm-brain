# vorp_housing

Version 0.2. A housing script for vorp

`vorp_housing` is a lightweight housing access system for RedM servers running VORP. This version is not a real estate market script. It does not let players buy or sell houses in-game. Instead, houses are defined directly in [config.lua](./config.lua), and access is granted to specific characters through their `charIdentifier`. If what you want is a clean way to:

Source: https://github.com/VORPCORE/vorp_housing

## Net events registered

**client:** `vorp_housing:Client:RegisterHouse`, `vorp_housing:Client:ShowHouses`

## Event handlers

**server:** `vorp:SelectedCharacter`
