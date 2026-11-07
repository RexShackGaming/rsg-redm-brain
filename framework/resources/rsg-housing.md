# rsg-housing

Version 3.0.2. rsg-housing

Monthly house rentals for the RSG Framework (RedM). Players rent a house directly at the property, pay rent every calendar month and are evicted if they don't pay. Everything is managed from an NUI panel at the house. - **Rent at the property.** Walk up to a house, press **[J]**, and rent it. The first month is paid up front in cash. - **Calendar-month rent.** Rent is due on the same day each mont

Source: https://github.com/Rexshack-RedM/rsg-housing

**Dependencies:** `rsg-core`, `oxmysql`, `rsg-inventory`

Has NUI (`ui_page`).

## Net events registered

**server:** `rsg-housing:server:openStorage`

**client:** `RSGCore:Client:OnPlayerLoaded`, `rsg-housing:client:SetDoorState`, `rsg-housing:client:SyncDoors`, `rsg-housing:client:SyncOwnedHouses`, `rsg-housing:client:openAdmin`

## Commands (RSGCore.Commands.Add)

**server:** `/houseadmin`

## Database tables

`rsg_housekeys`, `rsg_housing`
