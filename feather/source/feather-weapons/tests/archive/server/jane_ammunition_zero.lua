-- No persistence writes, general gameplay startup, or positive ammo authority.
local jane='6a2fd060-c46f-11f1-9ae2-e0d55eaa2deb'
local active,api,sequence=nil,nil,0
local loginArm=nil
local startupBusy,startupUsed=false,false
local guardName='feather-weapons-jane-zero'
local function enabled()
    return Config.DevMode==true and Config.CharacterAmmunitionEnabled~=true
        and Config.CharacterAmmoTransportEnabled~=true
        and GetConvar('feather_jane_ammo_readonly','0')=='1'
        and GetResourceState('feather-weapons-native-proof')=='stopped'
end
local function current(owner)
    return enabled() and exports['feather-core']:IsSessionCurrent(owner.source,owner.sessionId,jane)==true
end
local function guard(item)
    return not active or tonumber(item.id)~=112, 'Jane zero-ammo native test holds item112'
end
local function release()
    for _,name in ipairs({'UnregisterMoveGuard','UnregisterDestroyGuard','UnregisterInstanceChangeGuard'}) do
        api.Guards[name](guardName) -- unregister contract returns no value
    end
    active=nil
end
local function begin(source,args,savedPrimary,expectedSession)
    if source~=0 then return end
    local target=tonumber(args and args[1])
    if active or not enabled() or not target or target<1 or target%1~=0 or args[2]~=jane then
        print('[WeaponJaneZero] BLOCKED: exact Jane, opt-in, stopped proof, and no active attempt required'); return
    end
    -- Reserve/hold before any Inventory read may yield.
    local owner={source=target,savedPrimary=savedPrimary~=false,login=savedPrimary=='login',startup=savedPrimary=='startup'}; active=owner
    owner.label=owner.startup and '[WeaponJanePrimaryStartup] ' or owner.login and '[WeaponJanePrimaryLogin] ' or owner.savedPrimary and '[WeaponJanePrimaryNative] ' or '[WeaponJaneZero] '
    local sent=false
    local ok,reason=pcall(function()
        local session=exports['feather-core']:GetSessionContext(target)
        assert(session and session.ok and session.value.characterId==jane,'Jane session required')
        owner.sessionId=session.value.sessionId
        assert(not expectedSession or owner.sessionId==expectedSession,'login session changed')
        if owner.login then assert(GetConvar('feather_jane_primary_login','0')=='1','login scope disabled') end
        if owner.startup then assert(GetConvar('feather_jane_primary_startup','0')=='1','startup scope disabled') end
        assert(current(owner),'current Jane required')
        api=exports['feather-inventory']:initiate()
        for _,name in ipairs({'RegisterMoveGuard','RegisterDestroyGuard','RegisterInstanceChangeGuard'}) do
            local result=api.Guards[name](guardName,guard)
            assert(result and result.ok==true,'guard registration failed: '..name)
        end
        local registry=assert(WeaponCharacterAmmoPolicy.Build(WeaponDefinitionCatalog))
        local context={actorSource=target,sessionId=owner.sessionId,characterId=jane}
        local baseline=exports['feather-inventory']:GetCharacterFirearmRuntimeSnapshot(context,registry.limits)
        assert(current(owner) and baseline and baseline.ok,'snapshot refused')
        assert(baseline.value.characterId==jane and type(baseline.value.equipment)=='table','equipment snapshot required')
        local saved=baseline.value.equipment
        if savedPrimary then
            local expectedRevision=owner.startup and 9 or owner.login and 7 or 3
            assert(baseline.value.revision==expectedRevision and saved.primary and saved.primary.id==112
                and saved.primary.revision==1 and saved.primary.itemName=='weapon_revolver_cattleman',
                'saved primary item112 revision1 at expected ledger required')
            for slot in pairs(saved) do assert(slot=='primary','only saved primary permitted') end
        else
            assert(baseline.value.revision==0 and next(saved)==nil,'zero unequipped baseline required')
        end
        local count=0
        for id in pairs(registry.limits) do assert(baseline.value.pools[id]==0,'nonzero belt'); count=count+1 end
        assert(count==27,'canonical policy required')
        for id in pairs(baseline.value.pools) do assert(registry.limits[id]~=nil,'unknown belt pool') end
        local row
        if savedPrimary then
            -- Use the identity/metadata returned by the locked saved-equipment reader,
            -- never manufacture a slot assignment from a standalone inventory item.
            row={id=saved.primary.id,revision=saved.primary.revision,
                definition={name=saved.primary.itemName},metadata=saved.primary.metadata}
        else
            local item=api.GetItemForCharacter(jane,112)
            assert(current(owner) and item and item.ok,'item ownership required')
            row=item.value
        end
        assert(row.id==112 and row.revision==1 and row.definition.name=='weapon_revolver_cattleman','exact item112 revision1 required')
        assert(row.metadata.serialNumber=='FW-REVO-6AC9DCDE-FDEBF3-0001','serial mismatch')
        sequence=sequence+1
        owner.epoch=('jane-zero:%s:%s:%s'):format(owner.sessionId,GetGameTimer(),sequence)
        local identity={characterId=jane,sessionId=owner.sessionId,epoch=owner.epoch}
        local equipment=savedPrimary and saved or {primary={id=112,revision=1,itemName=row.definition.name,metadata=row.metadata}}
        local plan=assert(WeaponCharacterAmmoMaterialization.Build(equipment,WeaponDefinitionCatalog,registry,identity))
        assert(#plan.items==1 and plan.items[1].definitionId=='revolver_cattleman','one Cattleman required')
        assert(current(owner),'context changed before dispatch')
        if owner.login then assert(GetConvar('feather_jane_primary_login','0')=='1','login scope disabled') end
        if owner.startup then assert(GetConvar('feather_jane_primary_startup','0')=='1','startup scope disabled') end
        sent=true
        TriggerClientEvent('feather-weapons:jane-zero:begin',target,plan)
        print(owner.startup and '[WeaponJanePrimaryStartup] SENT resource-start saved primary item112 revision1 ledger9; zero ammo; auto cleanup after60s'
            or owner.login and '[WeaponJanePrimaryLogin] SENT automatic saved primary item112 revision1 ledger7; zero ammo; auto cleanup after60s'
            or savedPrimary and '[WeaponJanePrimaryNative] SENT saved primary item112 revision1 ledger3; zero ammo; saved assignment retained; auto cleanup after60s'
            or '[WeaponJaneZero] SENT item112 revision1; temporary primary copy only, no persisted equip/ammo; auto cleanup after60s')
    end)
    if not ok then
        if not sent and api then pcall(release) end
        if not sent and not api then active=nil end
        print(owner.label..'FAIL '..tostring(reason)..'; do not restart Inventory while native copy may remain')
    end
end
RegisterCommand('WeaponJaneZero',function(source,args) begin(source,args,false) end,true)
RegisterCommand('WeaponJanePrimaryNative',function(source,args) begin(source,args,true) end,true)
RegisterNetEvent('feather-weapons:jane-zero:startup-ready',function(characterId,sessionId)
    local target=source
    if startupBusy or startupUsed or active or not enabled()
        or GetConvar('feather_jane_primary_startup','0')~='1' or characterId~=jane
        or type(target)~='number' or target<1 or target%1~=0
        or type(sessionId)~='string' or sessionId=='' or #sessionId>128 then return end
    startupBusy=true -- reserve before independent Core validation may yield
    local called,valid=pcall(function() return exports['feather-core']:IsSessionCurrent(target,sessionId,jane) end)
    startupBusy=false
    if not called or valid~=true or active or startupUsed or not enabled()
        or GetConvar('feather_jane_primary_startup','0')~='1' then return end
    startupUsed=true -- one native attempt per resource instance, no silent retry
    begin(0,{tostring(target),jane},'startup',sessionId)
end)
-- Explicit one-use login gate, not production startup. The readiness hint can
-- only consume a console arm for a new, independently verified Core session.
RegisterCommand('WeaponJanePrimaryLogin',function(caller,args)
    if caller~=0 or active or loginArm or not enabled()
        or GetConvar('feather_jane_primary_login','0')~='1' then return end
    local target=tonumber(args and args[1])
    if not target or target<1 or target%1~=0 or args[2]~=jane then return end
    local arm={source=target}; loginArm=arm -- reserve before Core may yield
    local called,result=pcall(function() return exports['feather-core']:GetSessionContext(target) end)
    local value=called and type(result)=='table' and result.ok and result.value
    if not enabled() or GetConvar('feather_jane_primary_login','0')~='1'
        or type(value)~='table' or value.characterId~=jane or type(value.sessionId)~='string'
        or value.sessionId=='' or not exports['feather-core']:IsSessionCurrent(target,value.sessionId,jane) then
        loginArm=nil; print('[WeaponJanePrimaryLogin] BLOCKED: current Jane session required'); return
    end
    arm.sessionId=value.sessionId
    TriggerClientEvent('feather-weapons:jane-zero:login-arm',target,arm.sessionId)
    print('[WeaponJanePrimaryLogin] ARMED: logout then login Jane; automatic zero-ammo saved primary; one attempt')
end,true)
RegisterNetEvent('feather-weapons:jane-zero:login-ready',function(characterId,sessionId)
    local target=source -- CFX source must be captured before exports may yield
    local arm=loginArm
    if not arm or arm.used or arm.busy or active or target~=arm.source or not enabled()
        or GetConvar('feather_jane_primary_login','0')~='1' or characterId~=jane
        or type(sessionId)~='string' or sessionId==arm.sessionId then return end
    arm.busy=true
    local checked,currentSession=pcall(function()
        return exports['feather-core']:IsSessionCurrent(target,sessionId,jane)
    end)
    arm.busy=nil
    if not checked or currentSession~=true or active or arm.used or not enabled()
        or GetConvar('feather_jane_primary_login','0')~='1' then return end
    arm.used=true -- prevent overlapping readiness hints across Inventory waits
    begin(0,{tostring(target),jane},'login',sessionId)
end)
RegisterNetEvent('feather-weapons:jane-zero:ack',function(epoch,phase)
    local owner=active
    if not owner or source~=owner.source or epoch~=owner.epoch then return end
    if phase=='created' then
        if current(owner) then print(owner.label
            ..'CREATED: check holster/wheel/single draw; zero ammo; cleanup within60s') end
    elseif phase=='cleaned' then
        local ok,reason=pcall(release)
        print(owner.label
            ..(ok and 'CLEANUP PASS owned copy removed; holds released; saved equipment unchanged; no SQL writes' or 'FAIL '..tostring(reason)))
    end
end)
