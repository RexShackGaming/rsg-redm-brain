-- Concrete bounded READ-ONLY RedM diagnostic. No public net event, grants,
-- deletion, world consumption, ammo mutation or recovery authority.
local run
local function integer(v,min) return type(v)=='number' and v>=min and v<math.huge and v%1==0 end
local function enabled()
    return Config.DevMode==true and WeaponNativeThrowablePolicy and WeaponNativeThrowablePolicy.Enabled()
        and GetConvarInt('feather_native_throwable_projectile_probe',0)==1
end
local function emit(value) print('[WeaponNativeProjectileProbe] '..json.encode(value)) end
local function finish(why)
    if not run then return end
    local old=run; run=nil
    emit({phase='stopped',reason=why,source=old.source,projectileEvents=old.projectileEvents or 0,
        entityEvents=old.entityEvents or 0,nativeReadFailures=old.nativeReadFailures or 0,
        entityReadAttempts=old.entityReadAttempts or 0,
        readFailureReasons=old.readFailureReasons or {},modelZeroReads=old.modelZeroReads or 0,
        ownerMismatchReads=old.ownerMismatchReads or 0,nonObjectReads=old.nonObjectReads or 0,
        noWrites=true,originConfirmed=false,pickupCredits=false})
end
local function active()
    if not run or run.phase~='armed' then return nil end
    if not enabled() then finish('probe_disabled'); return nil end
    if (GetGameTimer()-run.started)%4294967296>=60000 then finish('expired'); return nil end
    local state=WeaponCharacterAmmoDispatcher.Status(run.source)
    if not state or state.phase~='active' or not state.identity
        or state.identity.characterId~=run.identity.characterId or state.identity.sessionId~=run.identity.sessionId
        or state.identity.epoch~=run.identity.epoch
        or not CoreAdapter.IsSessionCurrent(run.source,run.identity.sessionId,run.identity.characterId) then
        finish('owner_changed'); return nil
    end
    return run
end
local function entity(handle)
    local function read(fn,stage)
        if type(fn)~='function' then return nil,stage..'_unavailable' end
        local ok,value=pcall(fn,handle)
        if not ok then return nil,stage..'_exception' end
        if value==nil then return nil,stage..'_nil' end
        return value
    end
    local exists,why=read(DoesEntityExist,'exists')
    if exists==nil then return nil,why end
    if exists==false or exists==0 then return nil,'entity_absent' end
    if exists~=true and exists~=1 then return nil,'exists_invalid' end
    local out={}
    for _,field in ipairs({{'networkId',NetworkGetNetworkIdFromEntity},{'ownerSource',NetworkGetEntityOwner},
        {'model',GetEntityModel},{'entityType',GetEntityType}}) do
        local value; value,why=read(field[2],field[1])
        if value==nil then return nil,why end
        if field[1]=='model' then
            if not integer(value,-2147483648) or value>4294967295 then return nil,'model_invalid' end
            out.modelRaw=value
            value=value & 0xffffffff
        end
        if not integer(value,field[1]=='ownerSource' and -1 or 0) then return nil,field[1]..'_invalid' end
        out[field[1]]=value
    end
    exists,why=read(DoesEntityExist,'exists_after')
    if exists==nil then return nil,why end
    if exists~=true and exists~=1 then return nil,'entity_disappeared_during_read' end
    return out
end
local function sample(state,handle,kind,expected)
    if state.entityEvents>=32 or state.nativeReadFailures>=64 or state.entityReadAttempts>=128 then return end
    state.entityReadAttempts=state.entityReadAttempts+1
    local value,why=entity(handle)
    if active()~=state then return end
    if not value then
        state.nativeReadFailures=state.nativeReadFailures+1
        state.readFailureReasons[why]=(state.readFailureReasons[why] or 0)+1
        if state.failureLogs<8 then
            state.failureLogs=state.failureLogs+1
            emit({phase='observation',kind='entity_read_failure',readKind=kind,reason=why,handle=handle,
                noWrites=true,originConfirmed=false,pickupCredits=false})
        end
        return
    end
    if value.ownerSource~=state.source then state.ownerMismatchReads=state.ownerMismatchReads+1; return end
    if value.entityType~=3 then state.nonObjectReads=state.nonObjectReads+1; return end
    if value.model==0 then state.modelZeroReads=state.modelZeroReads+1 end
    if expected and (state.entities[handle]~=expected or value.networkId~=expected.networkId) then return end
    state.entityEvents=state.entityEvents+1
    emit({phase='observation',kind=kind,source=state.source,handle=handle,networkId=value.networkId,
        model=value.model,modelRaw=value.modelRaw,modelSettled=value.model~=0,entityType=value.entityType,
        noWrites=true,originConfirmed=false,pickupCredits=false})
    if not expected then state.entities[handle]={networkId=value.networkId} end
    return true
end
local function watch(state,handle,kind)
    if not sample(state,handle,kind) then return end
    local token=state.entities[handle]
    for _,delay in ipairs({100,500,1500}) do
        SetTimeout(delay,function()
            if active()==state and state.entities[handle]==token then
                sample(state,handle,'entity_settled_'..delay,token)
            end
        end)
    end
end
RegisterCommand('WeaponNativeProjectileProbe',function(source,args)
    if source~=0 then return end
    if args and #args==1 and args[1]=='stop' then finish('console_stop'); return end
    if not enabled() or run or not args or (#args~=1 and #args~=2) or not integer(tonumber(args[1]),1)
        or (#args==2 and not integer(tonumber(args[2]),1)) then
        return emit({phase='refused',reason='explicit_probe_flag_idle_current_source_required',noWrites=true})
    end
    local target=tonumber(args[1]); run={phase='arming',source=target}
    local reserved=run
    local ok,state=pcall(WeaponCharacterAmmoDispatcher.Status,target)
    local identity=ok and state and state.identity
    if not enabled() or not identity or state.phase~='active'
        or not CoreAdapter.IsSessionCurrent(target,identity.sessionId,identity.characterId)
        or not WeaponNativeEnrollment.Allows(Config,identity.characterId) then return finish('current_native_owner_required') end
    if run~=reserved then return end
    run={phase='armed',source=target,identity={characterId=identity.characterId,sessionId=identity.sessionId,epoch=identity.epoch},
        started=GetGameTimer(),projectileEvents=0,entityEvents=0,nativeReadFailures=0,entityReadAttempts=0,entities={},
        failureLogs=0,readFailureReasons={},modelZeroReads=0,ownerMismatchReads=0,nonObjectReads=0}
    emit({phase='armed',source=target,durationMs=60000,noWrites=true,originConfirmed=false,pickupCredits=false})
    local owner=run
    SetTimeout(60000,function() if run==owner then finish('expired') end end)
    -- Console-only readback of an already observed handle, never ownership
    -- adoption. Owner/epoch/type/read budgets still apply; useful without a throw.
    if args[2] then watch(owner,tonumber(args[2]),'entity_console_readback') end
end,true)
AddEventHandler('startProjectileEvent',function(sender,data)
    local state=active()
    if not state or tonumber(sender)~=state.source or state.projectileEvents>=8 then return end
    state.projectileEvents=state.projectileEvents+1
    local selected={}
    if type(data)=='table' then
        for _,key in ipairs({'ownerId','weaponHash','projectileHash','throwTaskSequence','targetEntity'}) do
            local value=data[key]
            if type(value)=='number' and value==value and value>-math.huge and value<math.huge then selected[key]=value end
        end
    end
    local ok,pedNetworkId=pcall(function() return NetworkGetNetworkIdFromEntity(GetPlayerPed(state.source)) end)
    emit({phase='observation',kind='projectile_start_hint',source=state.source,dataType=type(data),fields=selected,
        expectedPedNetworkId=ok and pedNetworkId or nil,noWrites=true,originConfirmed=false,pickupCredits=false})
end)
AddEventHandler('entityCreated',function(handle)
    local state=active()
    if not state or not integer(handle,1) then return end
    watch(state,handle,'entity_created')
end)
AddEventHandler('entityRemoved',function(handle)
    local state=active()
    if not state or not state.entities[handle] then return end
    state.entities[handle]=nil
    emit({phase='observation',kind='entity_removed',source=state.source,handle=handle,
        noWrites=true,originConfirmed=false,pickupCredits=false})
end)
