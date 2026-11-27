# rsg-guarma

Version 3.1.1. Boat travel between Saint Denis and Guarma for the RSG Framework

Boat travel between **Saint Denis** and **Guarma** for the RSG Framework (RedM). Version **3.1.1**. See [DOCS.md](DOCS.md) for architecture, events, security and troubleshooting. Players buy boat tickets from a port worker, then sail to the other port. The script swaps the world horizon, water and minimap automatically when you enter or leave Guarma, including when you log in there or an admin tel

Source: https://github.com/Rexshack-RedM/rsg-guarma

**Dependencies:** `rsg-core`, `rsg-inventory`, `rsg-target`, `oxmysql`

Has NUI (`ui_page`).

## Net events registered

**server:** `rsg-guarma:server:cancelBoarding`, `rsg-guarma:server:requestRescue`, `rsg-guarma:server:requestTravel`

**client:** `RSGCore:Client:OnPlayerUnload`, `rsg-guarma:client:boarded`, `rsg-guarma:client:boardingEnded`, `rsg-guarma:client:performTravel`

## Event handlers

**client:** `rsg-guarma:client:guarmaChanged`

## Callbacks (RSGCore.Functions.CreateCallback)

**server:** `rsg-guarma:server:buyTicket`, `rsg-guarma:server:getOffice`, `rsg-guarma:server:trade`

## Public (table) functions

**server/customs.lua:** `Guarma.CustomsSearch(src, destId)`

**server/database.lua:** `Guarma.GetRecord(citizenid)`, `Guarma.SaveRecord(citizenid)`

**server/management.lua:** `Guarma.ClosedReason(portId)`, `Guarma.Discount(Player)`, `Guarma.Price(Player, base)`, `Guarma.PayPortIncome(portId, amount)`

**server/soldiers.lua:** `Guarma.AlertLevel()`

**server/trade.lua:** `Guarma.CargoCount(src)`, `Guarma.CargoList(src, portId)`

**server/utils.lua:** `Guarma.Notify(src, title, nType, description)`, `Guarma.Round(amount)`, `Guarma.IsRunning(resource)`, `Guarma.GetNearPort(src, portId, radius)`, `Guarma.CanAct(Player)`, `Guarma.ItemCount(src, item)`, `Guarma.ItemLabel(item)`

## Database tables

`rsg_guarma_players`
