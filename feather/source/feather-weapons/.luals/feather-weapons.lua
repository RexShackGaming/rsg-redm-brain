---@meta

---@class FeatherWeaponsDiagnosticState
---@field equipped boolean
---@field itemInstanceId? integer|string
---@field definitionId? string
---@field nativeWeaponName? string
---@field nativeAmmoName? string
---@field generation? integer
---@field sessionId? string
---@field offhand? table

---@class FeatherWeaponsClientApi
---@field GetDiagnosticState fun(): FeatherWeaponsDiagnosticState

---@type FeatherWeaponsClientApi
FeatherWeaponsClient = {}

-- CFX exposes these RedM underscore natives through their normalized Lua
-- aliases. The generated native database retains the underscore-prefixed
-- names, so declare the runtime aliases used by the maintenance adapter here.
---@param weaponObject number
---@return number
function GetWeaponDamage(weaponObject) end

---@param weaponObject number
---@return number
function GetWeaponDirt(weaponObject) end

---@param weaponObject number
---@return number
function GetWeaponSoot(weaponObject) end

---@param weaponObject number
---@param level number
function SetWeaponDegradation(weaponObject, level) end

---@param weaponObject number
---@param level number
---@param p2 boolean
function SetWeaponDamage(weaponObject, level, p2) end

---@param weaponObject number
---@param level number
---@param p2 boolean
function SetWeaponDirt(weaponObject, level, p2) end

---@param weaponObject number
---@param level number
---@param p2 boolean
function SetWeaponSoot(weaponObject, level, p2) end
