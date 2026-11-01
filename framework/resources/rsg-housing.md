# rsg-housing

Version 3.0.1. rsg-housing

Monthly house rentals for the RSG Framework (RedM). Players rent a house directly at the property, pay rent every calendar month and are evicted if they don't pay. Everything is managed from an NUI panel at the house. - **Rent at the property.** Walk up to a house, press **[J]**, and rent it. The first month is paid up front in cash. - **Calendar-month rent.** Rent is due on the same day each mont

Source: https://github.com/Rexshack-RedM/rsg-housing

**Dependencies:** `rsg-core`, `ox_lib`, `oxmysql`, `rsg-inventory`

Has NUI (`ui_page`).

## Net events registered

**server:** `rsg-housing:server:openStorage`

**client:** `RSGCore:Client:OnPlayerLoaded`, `rsg-housing:client:SetDoorState`, `rsg-housing:client:SyncDoors`, `rsg-housing:client:SyncOwnedHouses`, `rsg-housing:client:openAdmin`

## Callbacks (lib.callback)

**server:** `rsg-housing:server:addGuest`, `rsg-housing:server:admin`, `rsg-housing:server:endTenancy`, `rsg-housing:server:getHouseStatus`, `rsg-housing:server:getState`, `rsg-housing:server:mailbox`, `rsg-housing:server:outfits`, `rsg-housing:server:payRent`, `rsg-housing:server:removeGuest`, `rsg-housing:server:renameHouse`, `rsg-housing:server:rentHouse`, `rsg-housing:server:searchPlayers`, `rsg-housing:server:setGuestPermission`, `rsg-housing:server:setHome`, `rsg-housing:server:toggleDoor`, `rsg-housing:server:upgradeStorage`

## Commands (RSGCore.Commands.Add)

**server:** `/houseadmin`

## Database tables

`rsg_housekeys`, `rsg_housing`
