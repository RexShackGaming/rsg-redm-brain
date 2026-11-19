# rsg-housing

Version 3.3.0. rsg-housing

Monthly house rentals for the RSG Framework (RedM). Players rent a house directly at the property, pay rent every calendar month and are evicted if they don't pay. Everything is managed from an NUI panel at the house. - **Rent at the property.** Walk up to a house, press **[J]**, and rent it. The first month is paid up front in cash. - **Calendar-month rent.** Rent is due on the same day each mont

Source: https://github.com/Rexshack-RedM/rsg-housing

**Dependencies:** `rsg-core`, `oxmysql`, `rsg-inventory`, `rsg-target`, `rsg-gizmo`

Has NUI (`ui_page`).

## Exports (call as exports['rsg-housing']:Name)

**server:** `AddGuest(houseid, citizenid, opts)`, `EvictTenant(houseid, opts)`, `GetDoorState(doorid)`, `GetHouse(houseid)`, `GetHouseAccess(citizenid, houseid)`, `GetHouseAt(coords, radius)`, `GetHouseByDoor(doorid)`, `GetHouseGuests(houseid)`, `GetHouseProps(houseid)`, `GetHouses()`, `GetPlayerHouses(citizenid)`, `GetTenant(houseid)`, `HasHouseAccess(citizenid, houseid, perm)`, `IsHouseRented(houseid)`, `OpenHouseStorage(src, houseid)`, `RemoveGuest(houseid, citizenid)`, `SetHouseDoors(houseid, locked)`, `SetHouseRent(houseid, rent)`

**client:** `GetHouseName(houseid)`, `GetMyHouses()`, `GetNearestHouse(coords, maxDist)`, `IsHouseMenuOpen()`, `IsHouseRented(houseid)`, `IsMyHouse(houseid)`, `OpenHouseMenu(houseid)`

## Net events registered

**server:** `rsg-housing:server:loginCheck`, `rsg-housing:server:openStorage`

**client:** `RSGCore:Client:OnPlayerLoaded`, `RSGCore:Client:OnPlayerUnload`, `rsg-housing:client:SetDoorState`, `rsg-housing:client:SyncDoors`, `rsg-housing:client:SyncOwnedHouses`, `rsg-housing:client:openAdmin`, `rsg-housing:client:placeProp`, `rsg-housing:client:propAdded`, `rsg-housing:client:propMoved`, `rsg-housing:client:propRemoved`, `rsg-housing:client:propsCleared`

## Commands (RSGCore.Commands.Add)

**server:** `/houseadmin`, `/housebelongings`

## Commands (RegisterCommand)

**client:** `/myhouse`

## Database tables

`rsg_housekeys`, `rsg_housing`, `rsg_housing_props`, `rsg_housing_retrieval`
