-- One character-level native carrier, independent of Inventory item identities.
-- The parent controller alone restores/persists ammunition quantities.
WeaponThrowableQuantityOwner={}
local permissionOwners={}
local active
local activeTypes={}
if type(RegisterCommand)=='function' then RegisterCommand('weaponQuantityStatus',function()
    local ok,value=pcall(function() return active and active.Status() or {phase='idle',quantityMode=false} end)
    print('[WeaponQuantityStatus] '..json.encode(ok and value or {phase='unreadable'}))
end,false) end
if type(AddEventHandler)=='function' then AddEventHandler('onResourceStop',function(resource)
    if resource~=GetCurrentResourceName() then return end
    for owner,restore in pairs(permissionOwners) do pcall(restore);permissionOwners[owner]=nil end
end) end
function WeaponThrowableQuantityOwner.New(api,catalog,identity,limits,definitionId)
    local profile,why=WeaponNativeThrowablePolicy.QuantityProfile(catalog,definitionId)
    if not profile then return nil,why end
    local ammoId,capacity=profile.ammunition.id,profile.ammunition.maxTotal
    local phase,handle,baseline,reason='idle',nil,nil,nil
    local pickupAllowed
    local Q={}
    local function count() local n=api.quantity();return type(n)=='number' and n%1==0 and n>=0 and n<=capacity and n or nil end
    local function extra()
        if not api.extraQuantity then return 0 end
        local n=api.extraQuantity();return type(n)=='number' and n%1==0 and n>=0 and n<=8 and n or nil
    end
    local function funded(value)
        return value.pools[ammoId]+(api.extraQuantity and value.pools.ammo_throwing_knives_poison or 0)
    end
    local function fail(why) phase='retained';reason=why;return nil,why end
    local function pickupPermission(n)
        if type(n)~='number' or n%1~=0 or n<0 or n>capacity then return false end
        local allowed=n<capacity
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
        local assigned,why=WeaponNativeThrowableItem.AssignedQuantity(snapshot,catalog,identity,limits,definitionId)
        if not assigned then return nil,why end
        phase='creating';baseline=snapshot;activeTypes[ammoId]=Q
        if ammoId=='ammo_tomahawk_regular' then active=Q end
        if not api.current() or count()~=0 or extra()~=0 or api.find()~=false then return fail('quantity_preexisting_native_state') end
        if funded(snapshot)>0 and not ensure() then return fail('quantity_carrier_creation_failed') end
        permissionOwners[Q]=api.restorePermissions
        if not pickupPermission(assigned.fundedQuantity) then return fail('quantity_pickup_permission_failed') end
        phase='active';return true
    end
    function Q.PrepareRestore(value)
        if phase~='active' or not api.current() then return nil end
        if funded(value)>0 and not ensure() then return fail('quantity_carrier_restore_failed') end
        if not pickupPermission(value.pools[ammoId]) then return fail('quantity_pickup_permission_failed') end
        baseline=value;return true
    end
    function Q.AcceptNativePickup(value)
        if phase~='active' or not api.current() or count()==nil then return nil end
        if extra()==nil then return fail('quantity_native_count_unreadable') end
        if count()+extra()>0 and not ensure() then return fail('quantity_collected_carrier_failed') end
        if not pickupPermission(count()) then return fail('quantity_pickup_permission_failed') end
        baseline=value;return true
    end
    function Q.Observe(value)
        if phase~='active' or not api.current() then return nil end
        local n=count();if not n or extra()==nil then return fail('quantity_native_count_unreadable') end
        if not pickupPermission(n) then return fail('quantity_pickup_permission_failed') end
        -- An increase is provisional until the server consumes an allowance.
        if n>value.pools[ammoId] then return {pickupCandidate=true,quantity=n} end
        local found=api.find()
        if found==nil then return fail('quantity_guid_unreadable') end
        if n==0 and extra()==0 and found==false then handle=nil
        elseif handle and (not found or found.guid~=handle.guid) then return fail('quantity_carrier_changed')
        elseif n+extra()>0 and not ensure() then return fail('quantity_carrier_absent') end
        baseline=value;return {quantity=n}
    end
    function Q.Release()
        if phase=='released' then return true end
        local sealed=api.sealed()
        if not sealed or not api.current() or count()~=sealed.pools[ammoId]
            or api.extraQuantity and extra()~=sealed.pools.ammo_throwing_knives_poison then return fail('quantity_seal_required') end
        phase='releasing'
        if not api.remove(handle) or count()~=0 or extra()~=0 or api.find()~=false or not api.restorePermissions() then
            return fail('quantity_cleanup_unconfirmed')
        end
        permissionOwners[Q]=nil;handle=nil;pickupAllowed=nil;phase='released';return true
    end
    function Q.Status()
        return {phase=phase,reason=reason,ammunitionId=ammoId,quantityMode=true,guidCaptured=handle~=nil,revision=baseline and baseline.revision,
            fundedQuantity=baseline and baseline.pools[ammoId],observedQuantity=count(),pickupAllowed=pickupAllowed,
            poison=api.extraQuantity and {fundedQuantity=baseline and baseline.pools.ammo_throwing_knives_poison,observedQuantity=extra()} or nil}
    end
    return Q
end

if type(RegisterCommand)=='function' then RegisterCommand('weaponKnifeQuantityStatus',function()
    local owner=activeTypes.ammo_throwing_knives_regular
    print('[WeaponKnifeQuantityStatus] '..json.encode(owner and owner.Status() or {phase='idle',quantityMode=false}))
end,false) end
