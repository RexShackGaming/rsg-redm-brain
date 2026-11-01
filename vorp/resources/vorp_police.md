# vorp_police

Version 0.6. A police job for vorp core framework

This is a comprehensive police system for RedM using the VORP framework. It integrates various police-related functionalities, such as an on-duty system, shared/private storages, job management, and more. The script is designed for small to large servers and offers customization options to suit different server needs. 1. Download or clone the repository to your server's resources folder. 2. Add `e

Source: https://github.com/VORPCORE/vorp_police

## Exports (call as exports['vorp_police']:Name)

**server:** `getPoliceFromCall(source)`, `isOnDuty(source)`

## Net events registered

**server:** `vorp_core:Server:OnPlayerDeath`, `vorp_police:Server:OpenStorage`, `vorp_police:server:firePlayer`, `vorp_police:server:hirePlayer`

**client:** `vorp_police:Client:AlertPolice`, `vorp_police:Client:JailFinished`, `vorp_police:Client:JailPlayer`, `vorp_police:Client:JobUpdate`, `vorp_police:Client:OpenPoliceMenu`, `vorp_police:Client:PlayerCuff`, `vorp_police:Client:RemoveBlip`, `vorp_police:Client:dragPlayer`

## Event handlers

**server:** `vorp:SelectedCharacter`, `vorp:playerJobChange`

**client:** `vorp_core:Client:OnPlayerDeath`

## Callbacks (VORP Core.Callback.Register)

**server:** `vorp_police:server:checkDuty`

**client:** `vorp_police:server:isPlayerCuffed`
