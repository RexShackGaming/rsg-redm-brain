# vorp_lootnpcs

Version 1.4. A npc looting script for vorp core framework

The **VORP_LootNPCs** allows players to have a chance to loot NPCs during the game. Make sure you have the following dependencies installed before using **VORP_LootNPCs**: - [VORP_Core](https://github.com/VORPCORE/vorp-core-lua)

Source: https://github.com/VORPCORE/vorp_lootnpcs

## Net events registered

**client:** `npcloot:looted`, `vorp:SelectedCharacter`, `vorp_core:Client:OnPlayerRevive`

## Event handlers

**client:** `vorp_core:Client:OnPlayerDeath`

## Server events it triggers in other resources

**client:** `npcloot:give_reward`
