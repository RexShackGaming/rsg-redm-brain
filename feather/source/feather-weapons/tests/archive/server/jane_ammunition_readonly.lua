-- No native handlers, SQL, grants, runtime epochs, or gameplay startup.
local approved='6a2fd060-c46f-11f1-9ae2-e0d55eaa2deb'
local function enabled()
    return Config.DevMode==true and Config.CharacterAmmunitionEnabled~=true
        and Config.CharacterAmmoTransportEnabled~=true
        and GetConvar('feather_jane_ammo_readonly','0')=='1'
        and GetResourceState('feather-weapons-native-proof')=='stopped'
end
RegisterCommand('WeaponJaneAmmoRead',function(source,args)
    if source~=0 then return end
    local prefix='[WeaponJaneAmmoRead] '
    local target=tonumber(args and args[1])
    if not enabled() or not target or target<1 or target%1~=0 or args[2]~=approved then
        print(prefix..'BLOCKED: read-only test scope, stopped proof and exact Jane UUID required'); return
    end
    local ok,result=pcall(function()
        local session=exports['feather-core']:GetSessionContext(target)
        assert(type(session)=='table' and session.ok==true and type(session.value)=='table'
            and session.value.characterId==approved,'Jane session required')
        local identity=session.value
        local function current()
            return enabled() and exports['feather-core']:IsSessionCurrent(target,identity.sessionId,approved)==true
        end
        assert(current(),'current Jane required')
        local registry=assert(WeaponCharacterAmmoPolicy.Build(WeaponDefinitionCatalog))
        local health=exports['feather-inventory']:GetHealth()
        assert(type(health)=='table' and health.ok==true and health.value.state=='ready','Inventory ready required')
        for _,method in ipairs({'GetCharacterAmmunitionSnapshot','GetCharacterFirearmRuntimeSnapshot'}) do
            local read=exports['feather-inventory'][method](exports['feather-inventory'],
                {actorSource=target,characterId=approved,sessionId=identity.sessionId},registry.limits)
            assert(current(),'context changed during read')
            assert(type(read)=='table' and read.ok==true and type(read.value)=='table','snapshot refused: '..method)
            local value=read.value
            assert(value.characterId==approved and value.revision==0 and type(value.pools)=='table','baseline mismatch')
            local count=0
            for id in pairs(registry.limits) do assert(value.pools[id]==0,'pool mismatch'); count=count+1 end
            for id in pairs(value.pools) do assert(registry.limits[id]~=nil,'unknown pool') end
            assert(count==27,'canonical policy mismatch')
            if method=='GetCharacterFirearmRuntimeSnapshot' then
                assert(type(value.equipment)=='table' and next(value.equipment)==nil,'Jane must remain unequipped')
            end
        end
        for _,method in ipairs({'ObserveCharacterAmmunition','MutateCharacterAmmunition'}) do
            assert(current(),'context changed before denial probe')
            -- Deliberately empty: no transfer amount, receipt ID, or runtime ticket.
            local refused=exports['feather-inventory'][method](exports['feather-inventory'],
                {actorSource=target,characterId=approved,sessionId=identity.sessionId},{})
            assert(current(),'context changed during denial probe')
            assert(type(refused)=='table' and refused.ok==false and type(refused.error)=='table'
                and refused.error.code=='denied','write gate did not deny: '..method)
        end
        return true
    end)
    if not ok or result~=true then print(prefix..'FAIL '..tostring(result)); return end
    print(prefix..'PASS snapshots=2 writeDenials=2 pools=27 revision0 ammo0 characterId='..approved
        ..'; actual trusted Weapons exports, scoped read-only; no native/SQL writes; NOT mutation/gameplay authorization')
end,true)
