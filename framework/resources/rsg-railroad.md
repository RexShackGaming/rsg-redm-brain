# rsg-railroad

Version 3.1.3. rsg-railroad

Advanced train management system for RedM (rsg-core). Buy railroad companies, hire drivers, manage trains, run missions, and build a railroad empire. - **Buy a Railroad Company** — 4 companies available across the map ($50,000 each, configurable) - **Rename Your Company** — Custom company names shown on UI

Source: https://github.com/Rexshack-RedM/rsg-railroad

**Dependencies:** `rsg-core`, `ox_lib`, `ox_target`, `oxmysql`, `rsg-inventory`

Has NUI (`ui_page`).

## Net events registered

**server:** `rsg-railroad:addMiles`, `rsg-railroad:addSupply`, `rsg-railroad:ambientDespawned`, `rsg-railroad:applyAsDriver`, `rsg-railroad:approveDriver`, `rsg-railroad:buyCompany`, `rsg-railroad:buyTrain`, `rsg-railroad:completeMission`, `rsg-railroad:fireDriver`, `rsg-railroad:openTrainStorage`, `rsg-railroad:parkTrain`, `rsg-railroad:purchaseUpgrade`, `rsg-railroad:rejectDriver`, `rsg-railroad:renameCompany`, `rsg-railroad:robberyDefeated`, `rsg-railroad:robberyOccurred`, `rsg-railroad:sellCompany`, `rsg-railroad:sellTrain`, `rsg-railroad:setTrainSpawned`, `rsg-railroad:takeSupply`, `rsg-railroad:ticketRevenue`, `rsg-railroad:updateCondition`, `rsg-railroad:updateFuel`, `rsg-railroad:updateTrainState`, `rsg-railroad:updateWater`, `rsg-railroad:useMaintenanceItem`, `rsg-railroad:withdrawFunds`

**client:** `rsg-railroad:client:setjunction`, `rsg-railroad:client:trainpos`, `rsg-railroad:maintenanceResult`, `rsg-railroad:refreshStationData`, `rsg-railroad:setAmbientState`

## Callbacks (lib.callback)

**server:** `rsg-railroad:canSpawnTrain`, `rsg-railroad:getAllCompanyStats`, `rsg-railroad:getAllOwnedCompanies`, `rsg-railroad:getAmbientState`, `rsg-railroad:getCompanyOwnership`, `rsg-railroad:getCompanyStats`, `rsg-railroad:getCompanySupplies`, `rsg-railroad:getCompanyTrains`, `rsg-railroad:getCompanyUpgrades`, `rsg-railroad:getEmployees`, `rsg-railroad:getMyCompanyMembership`, `rsg-railroad:getMyEmployeeData`, `rsg-railroad:getMyEmployment`, `rsg-railroad:getOwnedTrains`, `rsg-railroad:getPendingApplications`, `rsg-railroad:getPlayerRole`, `rsg-railroad:getTrainById`, `rsg-railroad:getTrainModelUpgrade`, `rsg-railroad:getTrainStorageState`, `rsg-railroad:server:useTicket`, `rsg-railroad:shouldSpawnAmbient`

## Commands (RSGCore.Commands.Add)

**server:** `/setjunction`, `/trainpos`

## Commands (RegisterCommand)

**client:** `/trainrobbery`

## Public (table) functions

**server/db.lua:** `DB.GetOwnedTrains(citizenid)`, `DB.GetTrainById(trainId)`, `DB.InsertTrain(citizenid, companyId, model, label, fuel, water, condition)`, `DB.DeleteTrain(trainId, citizenid)`, `DB.UpdateTrainFuel(trainId, fuel)`, `DB.UpdateTrainWater(trainId, water)`, `DB.UpdateTrainCondition(trainId, condition)`, `DB.UpdateTrainState(trainId, fuel, water, condition)`, `DB.ParkTrain(trainId, stationId, fuel, water, condition)`, `DB.UnparkTrain(trainId)`, `DB.AddMiles(trainId, miles)`, `DB.CountTrains(citizenid)`, `DB.GetCompanyMembership(citizenid, companyId)`, `DB.JoinCompany(citizenid, companyId)`, `DB.EnsureCompanyMembership(citizenid, companyId)`, `DB.AddCompanyXP(citizenid, companyId, xp)`, `DB.SetCompanyRank(citizenid, companyId, rank)`, `DB.IncrementMissions(citizenid, companyId)`, `DB.AddEarnings(citizenid, companyId, amount)`, `DB.HasClaimedReward(citizenid, rewardId)`, `DB.ClaimReward(citizenid, rewardId)`, `DB.GetCompanyOwnership(companyId)`, `DB.GetAllOwnedCompanies()`, `DB.GetOwnedCompaniesByCitizen(citizenid)`, `DB.PurchaseCompany(companyId, citizenid, ownerName)`, `DB.SellCompany(companyId, citizenid)`, `DB.SetCompanyName(companyId, name)`, `DB.GetOwnedCompanyCount()`, `DB.GetCashRegister(companyId)`, `DB.AddToCashRegister(companyId, amount)`, `DB.WithdrawFromCashRegister(companyId, amount)`, `DB.GetCompanyTrains(companyId)`, `DB.GetCompanyUpgrades(companyId)`, `DB.GetCompanyTrainUpgrade(companyId, trainModel)`, `DB.UpsertCompanyUpgrade(companyId, trainModel, column, level)`, `DB.ApplyAsDriver(companyId, citizenid, firstname, lastname)`, `DB.GetEmployeesByCompany(companyId)`, `DB.GetEmployeeByIds(companyId, citizenid)`, `DB.GetPlayerEmployment(citizenid)`, `DB.GetPendingApplications(companyId)`, `DB.GetEmployeeById(companyId, employeeId)`, `DB.ApproveEmployee(companyId, employeeId)`, `DB.RejectEmployee(companyId, employeeId)`, `DB.FireEmployee(companyId, employeeId)`, `DB.IncrementEmployeeMissions(employeeId)`, `DB.AddEmployeeEarnings(employeeId, amount)`, `DB.DeleteEmployeesByCompany(companyId)`, `DB.GetCompanySupplies(companyId)`, `DB.GetSupplyItem(companyId, itemName)`, `DB.AddSupplyItem(companyId, itemName, quantity)`, `DB.TakeSupplyItem(companyId, itemName, quantity)`, `DB.DeleteSuppliesByCompany(companyId)`, `DB.EnsureTables()`

**server/storage.lua:** `TrainStorage.OnSpawn(src, model)`, `TrainStorage.OnPutAway(src, silent)`

**server/webhook.lua:** `Webhook.Send(category, data)`, `Webhook.SendFields(category, title, fieldPairs, wtype, description)`

## Database tables

`railroad_companies`, `railroad_companies_owned`, `railroad_company_supplies`, `railroad_company_upgrades`, `railroad_employees`, `railroad_rewards`, `railroad_trains`
