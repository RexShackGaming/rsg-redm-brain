local LIB <const> = Import 'class' --[[@as CLASS]]

local customInventory <const> = LIB.Class:Create({
    constructor = function(self, data)
        data = data or {}
        self.id = data.id
        self.name = data.name
        self.limit = data.limit or 10
        self.acceptWeapons = data.acceptWeapons or false
        self.shared = data.shared or false
        self.ignoreItemStackLimit = data.ignoreItemStackLimit or false
        self.limitedItems = {}
        self.whitelistItems = data.whitelistItems or false
        self.PermissionTakeFrom = {}
        self.PermissionMoveTo = {}
        self.CharIdPermissionTakeFrom = {}
        self.CharIdPermissionMoveTo = {}
        self.UsePermissions = data.UsePermissions or false
        self.UseBlackList = data.UseBlackList or false
        self.BlackListItems = {}
        self.whitelistWeapons = data.whitelistWeapons or false
        self.limitedWeapons = {}
        self.useweight = data.useWeight or false
        self.weight = data.weight or 0.0
        self.webhook = data.webhook or false
        self.inUse = false
    end,

    get = {
        getLimit = function(self)
            return self.limit
        end,

        getName = function(self)
            return self.name
        end,

        isShared = function(self)
            return self.shared
        end,

        isInUse = function(self)
            return self.inUse
        end,

        isPermEnabled = function(self)
            return self.UsePermissions
        end,

        getIgnoreItemStack = function(self)
            return self.ignoreItemStackLimit
        end,

        ---@param name string
        isWeaponInList = function(self, name)
            if self.limitedWeapons[name:lower()] then
                return true
            end
            return false
        end,

        ---@param name string
        isItemInList = function(self, name)
            if self.limitedItems[name:lower()] then
                return true
            end
            return false
        end,

        ---@param name string
        isItemInBlackList = function(self, name)
            if self.BlackListItems[name:lower()] then
                return true
            end
            return false
        end,

        ---@param name string
        getWeaponLimit = function(self, name)
            return self.limitedWeapons[name:lower()]
        end,

        ---@param name string
        getItemLimit = function(self, name)
            return self.limitedItems[name:lower()]
        end,

        iswhitelistWeaponsEnabled = function(self)
            return self.whitelistWeapons
        end,

        iswhitelistItemsEnabled = function(self)
            return self.whitelistItems
        end,

        isBlackListEnabled = function(self)
            return self.UseBlackList
        end,

        getBlackList = function(self)
            return self.BlackListItems
        end,

        getPermissionMoveTo = function(self)
            return self.PermissionMoveTo, self.CharIdPermissionMoveTo
        end,

        getPermissionTakeFrom = function(self)
            return self.PermissionTakeFrom, self.CharIdPermissionTakeFrom
        end,

        doesAcceptWeapons = function(self)
            return self.acceptWeapons
        end,

        getAllCustomInvData = function(self)
            return self
        end,

        getWebhook = function(self)
            return self.webhook
        end,

        getWeight = function(self)
            return self.weight
        end,

        useWeight = function(self)
            return self.useweight
        end,

        getCustomInvData = function(self)
            return self
        end,
    },

    set = {

        removeCustomInventory = function(self)
            CUSTOM_INVENTORIES[self.id] = nil
            USERS_ITEMS[self.id] = nil
            USERS_WEAPONS[self.id] = nil
        end,

        blackListItems = function(self, data)
            self.BlackListItems[data.name] = data.name
        end,

        addPermissionMoveTo = function(self, data)
            self.PermissionMoveTo[data.name] = data.grade
        end,

        addPermissionTakeFrom = function(self, data)
            self.PermissionTakeFrom[data.name] = data.grade
        end,

        addCharIdPermissionTakeFrom = function(self, charid, state)
            if self.CharIdPermissionTakeFrom[charid] then
                self.CharIdPermissionTakeFrom[charid] = state
            else
                if state == nil then state = true end
                self.CharIdPermissionTakeFrom[charid] = state
            end
        end,

        addCharIdPermissionMoveTo = function(self, charid, state)
            state = state ~= nil and state or true
            self.CharIdPermissionMoveTo[charid] = state
        end,

        setCustomInventoryLimit = function(self, limit)
            self.limit = limit
        end,

        setInUse = function(self, state)
            self.inUse = state
        end,

        setWeight = function(self, value)
            if self.useweight then
                self.weight = value
            end
        end,

        setCustomItemLimit = function(self, data)
            self.limitedItems[data.name] = data.limit
        end,

        setCustomWeaponLimit = function(self, data)
            self.limitedWeapons[data.name] = data.limit
        end,

        updateCustomInvData = function(self, data)
            self.name = data.name or self.name
            self.limit = data.limit or self.limit
            self.acceptWeapons = data.acceptWeapons or self.acceptWeapons
            self.shared = data.shared or self.shared
            self.ignoreItemStackLimit = data.ignoreItemStackLimit or self.ignoreItemStackLimit
            self.limitedItems = data.limitedItems or self.limitedItems
            self.whitelistItems = data.whitelistItems or self.whitelistItems
            self.PermissionTakeFrom = data.PermissionTakeFrom or self.PermissionTakeFrom
            self.PermissionMoveTo = data.PermissionMoveTo or self.PermissionMoveTo
            self.CharIdPermissionTakeFrom = data.CharIdPermissionTakeFrom or self.CharIdPermissionTakeFrom
            self.CharIdPermissionMoveTo = data.CharIdPermissionMoveTo or self.CharIdPermissionMoveTo
            self.UsePermissions = data.UsePermissions or self.UsePermissions
            self.UseBlackList = data.UseBlackList or self.UseBlackList
            self.BlackListItems = data.BlackListItems or self.BlackListItems
            self.whitelistWeapons = data.whitelistWeapons or self.whitelistWeapons
            self.limitedWeapons = data.limitedWeapons or self.limitedWeapons
            self.webhook = data.webhook or self.webhook
        end,
    },
}, "CUSTOM_INVENTORY")

---@class CUSTOM_INVENTORY_SERVER
---@field public New fun(self: CUSTOM_INVENTORY_SERVER, data: table): CUSTOM_INVENTORY_SERVER
---@field public Register fun(self: CUSTOM_INVENTORY_SERVER, data: table): CUSTOM_INVENTORY_SERVER
SECONDARY_INVENTORY = customInventory

--- Same pattern as `WEAPON:Register` / `ITEM:Register`: `New` then wire into runtime tables.
function SECONDARY_INVENTORY:Register(data)
    local inst <const> = SECONDARY_INVENTORY:New(data)
    CUSTOM_INVENTORIES[data.id] = inst
    USERS_ITEMS[data.id] = {}
    if not USERS_WEAPONS[data.id] then
        USERS_WEAPONS[data.id] = {}
    end
    return inst
end
