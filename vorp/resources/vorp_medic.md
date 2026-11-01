# vorp_medic

Version 0.3. A medical scrpt for vorp core framework

This is a medic system for RedM using the VORP framework. It integrates various doctor-related functionalities, such as an on-duty system, shared/private storages, job management, and more. The script is designed for small to large servers and offers customization options to suit different server needs. 1. Download or clone the repository to your server's resources folder. 2. Add `ensure vorp_medi

Source: https://github.com/VORPCORE/vorp_medic

## Exports (call as exports['vorp_medic']:Name)

**server:** `getDoctorFromCall(source)`, `isOnDuty(source)`

## Net events registered

**server:** `vorp_medic:Server:OpenStorage`, `vorp_medic:server:firePlayer`, `vorp_medic:server:hirePlayer`

**client:** `vorp_medic:Client:AlertDoctor`, `vorp_medic:Client:HealAnim`, `vorp_medic:Client:HealPlayer`, `vorp_medic:Client:JobUpdate`, `vorp_medic:Client:OpenMedicMenu`, `vorp_medic:Client:RemoveBlip`, `vorp_medic:Client:ReviveAnim`

## Event handlers

**server:** `vorp:SelectedCharacter`, `vorp:playerJobChange`

## Callbacks (VORP Core.Callback.Register)

**server:** `vorp_medic:server:checkDuty`
