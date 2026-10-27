# vorp_metabolism

Version 1.2. A Metabolism Script With HUD For VORP Core Framework

This script integrates a metabolism system into your RedM server, allowing players to manage their **thirst**, **hunger**, and **metabolism**. Additionally, it allows players to consume items that affect these stats, such as food and beverages. The script also provides support for visual effects (like being drunk) when consuming certain items. __Hud redesigned by Z-eus__ - **Metabolism System**: M

Source: https://github.com/VORPCORE/vorp_metabolism

Has NUI (`ui_page`).

## Net events registered

**server:** `vorpmetabolism:GetStatus`, `vorpmetabolism:SaveLastStatus`

**client:** `vorp:PlayerForceRespawn`, `vorp:SelectedCharacter`, `vorpmetabolism:StartFunctions`, `vorpmetabolism:changeValue`, `vorpmetabolism:getValue`, `vorpmetabolism:setHud`, `vorpmetabolism:setValue`, `vorpmetabolism:useItem`

## Event handlers

**client:** `vorp_core:Client:OnPlayerSpawned`

## Server events it triggers in other resources

**client:** `vorpmetabolism:GetStatus`, `vorpmetabolism:SaveLastStatus`
