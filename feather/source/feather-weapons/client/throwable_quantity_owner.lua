-- One character-level native carrier, independent of Inventory item identities.
-- The parent controller alone restores/persists ammunition quantities.
WeaponThrowableQuantityOwner={}
local permissionOwners={}
local active
if type(RegisterCommand)=='function' then RegisterCommand('weaponQuantityStatus',function()
    local ok,value=pcall(function() return active and active.Status() or {phase='idle',quantityMode=false} end)
    print('[WeaponQuantityStatus] '..json.encode(ok and value or {phase='unreadable'}))
end,false) end
if type(AddEventHandler)=='function' then AddEventHandler('onResourceStop',function(resource)
    if resource~=GetCurrentResourceName() then return end
    for owner,restore in pairs(permissionOwners) do pcall(restore);permissionOwners[owner]=nil end
end) end
function WeaponThrowableQuantityOwner.New(api,catalog,identity,limits)
    local phase,handle,baseline,reason='idle',nil,nil,nil
    local pickupAllowed
    local Q={}
    local function count() local n=api.quantity();return type(n)=='number' and n%1==0 and n>=0 and n<=3 and n or nil end
    local function fail(why) phase='retained';reason=why;return nil,why end
    local function pickupPermission(n)
        if type(n)~='number' or n%1~=0 or n<0 or n>3 then return false end
        local allowed=n<3
        if pickupAllowed==allowed then return true end
        local changed
        if allowed then changed=api.allow() else changed=api.suppress() end
        if changed~=true then return false end
        pickupAllowed=allowed;return true
    end
    local function ensure()
        if not api.current() then return false end
        local found=api.find()
        if found==nil then return false end
        -- A canonical quantity acknowledgement may materialize/rebind the one
        -- unique model carrier. This GUID is lifecycle cleanup, not item identity.
        if found==false then found=api.materialize() end
        if not found or type(found.guid)~='string' or not api.current() then return false end
        handle=found;return true
    end
    function Q.Create(snapshot)
        if phase~='idle' then return nil,'quantity_creation_already_attempted' end
        local assigned,why=WeaponNativeThrowableItem.AssignedQuantity(snapshot,catalog,identity,limits)
        if not assigned then return nil,why end
        phase='creating';baseline=snapshot;active=Q
        if not api.current() or count()~=0 or api.find()~=false then return fail('quantity_preexisting_native_state') end
        if assigned.fundedQuantity>0 and not ensure() then return fail('quantity_carrier_creation_failed') end
        permissionOwners[Q]=api.restorePermissions
        if not pickupPermission(assigned.fundedQuantity) then return fail('quantity_pickup_permission_failed') end
        phase='active';return true
    end
    function Q.PrepareRestore(value)
        if phase~='active' or not api.current() then return nil end
        if value.pools.ammo_tomahawk_regular>0 and not ensure() then return fail('quantity_carrier_restore_failed') end
        if not pickupPermission(value.pools.ammo_tomahawk_regular) then return fail('quantity_pickup_permission_failed') end
        baseline=value;return true
    end
    function Q.AcceptNativePickup(value)
        if phase~='active' or not api.current() or count()==nil then return nil end
        if count()>0 and not ensure() then return fail('quantity_collected_carrier_failed') end
        if not pickupPermission(count()) then return fail('quantity_pickup_permission_failed') end
        baseline=value;return true
    end
    function Q.Observe(value)
        if phase~='active' or not api.current() then return nil end
        local n=count();if not n then return fail('quantity_native_count_unreadable') end
        if not pickupPermission(n) then return fail('quantity_pickup_permission_failed') end
        -- An increase is provisional until the server consumes an allowance.
        if n>value.pools.ammo_tomahawk_regular then return {pickupCandidate=true,quantity=n} end
        local found=api.find()
        if found==nil then return fail('quantity_guid_unreadable') end
        if n==0 and found==false then handle=nil
        elseif handle and (not found or found.guid~=handle.guid) then return fail('quantity_carrier_changed')
        elseif n>0 and not ensure() then return fail('quantity_carrier_absent') end
        baseline=value;return {quantity=n}
    end
    function Q.Release()
        if phase=='released' then return true end
        local sealed=api.sealed()
        if not sealed or not api.current() or count()~=sealed.pools.ammo_tomahawk_regular then return fail('quantity_seal_required') end
        phase='releasing'
        if not api.remove(handle) or count()~=0 or api.find()~=false or not api.restorePermissions() then
            return fail('quantity_cleanup_unconfirmed')
        end
        permissionOwners[Q]=nil;handle=nil;pickupAllowed=nil;phase='released';return true
    end
    function Q.Status()
        return {phase=phase,reason=reason,quantityMode=true,guidCaptured=handle~=nil,revision=baseline and baseline.revision,
            fundedQuantity=baseline and baseline.pools.ammo_tomahawk_regular,observedQuantity=count(),pickupAllowed=pickupAllowed}
    end
    return Q
end
