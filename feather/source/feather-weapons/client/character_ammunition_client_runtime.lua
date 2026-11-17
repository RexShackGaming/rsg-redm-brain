-- Factory only. No instance, thread, event, export or automatic native grants.
-- One local runtime serializes ingress, frame work, transfers and checkpoints.
WeaponCharacterAmmoClientRuntime={}
-- Concrete native/transport I/O factory. No native calls at construction, no
-- creation defaults, and no independent ammo or entitlement authority.
WeaponCharacterAmmoNativeAdapters={}
function WeaponCharacterAmmoNativeAdapters.New(creation,owned,send)
    if type(creation)~='function' or type(owned)~='function' or type(send)~='function' then
        return nil,'missing_creation_ownership_transport'
    end
    local blocked=true
    local api={ped=PlayerPedId,hash=joaat,read=GetPedAmmoByType,write=SetPedAmmoByType,
        now=GetGameTimer,wait=Wait,caller=GetInvokingResource,
        creation=creation,owned=owned,send=send,
        block=function(value) blocked=value~=false end,
        remove=function(ped,hash,count)
            Citizen.InvokeNative(0xB6CFEC32E3742779,ped,hash,count,0xA07362E6)
        end,
        life=function()
            local dead=IsEntityDead(PlayerPedId())
            return (dead==true or dead==1) and 'dead' or 'alive'
        end,
    }
    api.collectionEnabled=function() return WeaponNativeThrowableCollectionClientHost and WeaponNativeThrowableCollectionClientHost.Ready()==true end
    api.readCollectionEscrow=function(ticket) return WeaponNativeThrowableCollectionClientHost.ReadEscrow(ticket) end
    api.beforeCollectionSample=function(runtime)
        if WeaponNativeThrowableCollectionClientHost and WeaponNativeThrowableCollectionClientHost.Enabled() then
            return WeaponNativeThrowableCollectionClientHost.BeforeStep(runtime)
        end
        return true
    end
    return api,function()
        local allowed=false
        if WeaponGuidAcceptanceClient and type(WeaponGuidAcceptanceClient.AllowTemporaryFiring)=='function' then
            local ok,value=pcall(WeaponGuidAcceptanceClient.AllowTemporaryFiring)
            allowed=ok and value==true
        end
        -- This predicate admits only a live server-challenged, released-owner
        -- one-throw fixture. Normal firing still requires the pickup host.
        if allowed then return end
        if WeaponNativeThrowablePolicy and WeaponNativeThrowablePolicy.UnitsEnabled and WeaponNativeThrowablePolicy.UnitsEnabled() then
            local checked,ready=pcall(function()
                if WeaponNativeThrowableCollectionClientHost and WeaponNativeThrowableCollectionClientHost.Enabled() then return WeaponNativeThrowableCollectionClientHost.Ready() end
                return WeaponNativeThrowablePickupClient and WeaponNativeThrowablePickupClient.Ready()
            end)
            if not checked or ready~=true then DisablePlayerFiring(PlayerId(),true);return end
        end
        if blocked and not allowed then DisablePlayerFiring(PlayerId(),true) end
    end
end
function WeaponCharacterAmmoClientRuntime.New(api)
    if type(api)~='table' or type(api.life)~='function' then return nil,'missing_runtime_life' end
    local host,why=WeaponCharacterAmmoHost.New(api)
    if not host then return nil,why end
    local driver
    driver,why=WeaponCharacterAmmoDriver.New(host,{ped=api.ped,now=api.now,block=api.block,
        life=api.life,identity=WeaponCharacterAmmoWorldContext.Identity})
    if not driver then return nil,why end
    local busy=false
    local collectionHold
    local collectionTickets,collectionCount={},0
    local T={}
    local function same(a,b)
        return type(a)=='table' and type(b)=='table' and a.characterId==b.characterId
            and a.sessionId==b.sessionId and a.epoch==b.epoch
    end
    local function holdFailure(why)
        if collectionHold then collectionHold.phase='review_required';collectionHold.reason=why end
        pcall(api.block,true);pcall(host.Suspend,why)
        return nil,why
    end
    local function holdCurrent()
        local state=host.Status()
        local ammo=state.session and state.session.ammo
        local identity=WeaponCharacterAmmoWorldContext.Identity()
        local elapsed=(api.now()-collectionHold.started)%4294967296
        local pools=ammo and ammo.baseline and ammo.baseline.pools
        if type(pools)~='table' then return false end
        for key,value in pairs(collectionHold.pools) do if pools[key]~=value then return false end end
        for key in pairs(pools) do if collectionHold.pools[key]==nil then return false end end
        return state.phase=='active' and ammo and ammo.phase=='active' and not ammo.pending
            and not ammo.closing and not ammo.deathClosing and same(ammo.baseline,collectionHold.identity)
            and ammo.baseline.revision==collectionHold.revision
            and type(identity)=='table' and identity.characterId==collectionHold.identity.characterId
            and identity.sessionId==collectionHold.identity.sessionId and api.ped()==collectionHold.ped
            and api.life()=='alive' and elapsed<=10000
    end
    local function checkedHold()
        pcall(api.block,true)
        if collectionHold.phase=='review_required' then return nil,collectionHold.reason end
        local ok,current=pcall(holdCurrent)
        if not ok or not current then return holdFailure('native_collection_hold_scope_changed') end
        return true
    end
    local function reserved(fn,...)
        if collectionHold then pcall(api.block,true);return nil,'native_collection_hold_pending' end
        if busy or driver.Status().stepping or driver.Status().receiving then return nil,'runtime_busy' end
        busy=true
        local called,result,reason,extra=pcall(fn,...)
        busy=false
        if not called then
            pcall(api.block,true); pcall(host.Suspend,'runtime_operation_failed')
            return nil,'runtime_operation_failed'
        end
        return result,reason,extra
    end
    function T.Receive(bundle,origin) return reserved(driver.Receive,bundle,origin) end
    function T.Step()
        if busy or driver.Status().stepping or driver.Status().receiving then pcall(api.block,true); return nil,'runtime_busy' end
        if type(api.beforeCollectionSample)=='function' then
            local ok,ready=pcall(api.beforeCollectionSample,T)
            if not ok or ready~=true then return holdFailure('native_collection_pre_sample_failed') end
        end
        if collectionHold then
            local live,why=checkedHold()
            if not live then return nil,why end
            return true,'native_collection_hold_pending'
        end
        return driver.Step()
    end
    T.Tick=T.Step
    function T.Transfer(...) return reserved(host.Transfer,...) end
    function T.Checkpoint(context)
        local result,reason=reserved(host.Checkpoint,context)
        return result or {ok=false,error={code=reason},code=reason}
    end
    function T.ReleaseEquipment(identity,ticket,collectWear)
        return reserved(function()
            local wear
            if collectWear==true then
                local owner=WeaponCharacterAmmoActiveOwner
                local called,result=pcall(function() return owner and owner.FinalWear(identity) end)
                if not called or not result then return nil,'final_wear_readback_unavailable' end
                wear=result -- captured before seal/removal under the release reservation
            end
            local prepared,why=host.PrepareEquipmentRelease(identity,ticket)
            if not prepared then return nil,why end
            local release=WeaponCharacterAmmoRelease.New(host,api)
            local requested,reason=release.Request(10000)
            if not requested then return nil,reason end
            while true do
                local context=WeaponCharacterAmmoWorldContext.Identity()
                if type(context)~='table' or context.characterId~=identity.characterId or context.sessionId~=identity.sessionId then
                    host.Suspend('equipment_release_context_changed'); return nil,'equipment_release_context_changed'
                end
                local done,failure=release.Step()
                if done then return true,nil,wear end
                if release.Status().phase=='failed' then return nil,failure end
                api.wait(0)
            end
        end)
    end
    -- Orderly release helpers retain existing server seal/cleanup barriers.
    for _,name in ipairs({'Finalize','Cleanup','RecoverDeath','FinalizeDeath','Quiesce'}) do
        local method=host[name]
        T[name]=function(...) return reserved(method,...) end
    end
    -- Host-only opt-in. Concrete production adapters deliberately do not expose
    -- these ports until trusted ticket transport and exact escrow are composed.
    function T.BeginNativeCollectionHold(ticket,identity)
        return reserved(function()
            if type(api.collectionEnabled)~='function' or api.collectionEnabled()~=true
                or type(api.readCollectionEscrow)~='function' then return nil,'native_collection_hold_disabled' end
            if type(ticket)~='string' or #ticket<1 or #ticket>128 or ticket:find('%c')
                or collectionTickets[ticket] or collectionCount>=64
                or type(identity)~='table' or type(identity.epoch)~='string' or #identity.epoch==0 then
                return nil,'native_collection_hold_invalid'
            end
            local state=host.Status()
            local ammo=state.session and state.session.ammo
            local baseline=ammo and ammo.baseline
            if state.phase~='active' or not same(baseline,identity) or not baseline.pools
                or baseline.pools.ammo_tomahawk_regular~=0 or not state.session
                or state.session.throwable~=nil then return nil,'native_collection_empty_carry_required' end
            collectionTickets[ticket]=true;collectionCount=collectionCount+1
            local pools={};for key,value in pairs(baseline.pools) do pools[key]=value end
            collectionHold={phase='holding',ticket=ticket,identity={characterId=identity.characterId,
                sessionId=identity.sessionId,epoch=identity.epoch},revision=baseline.revision,
                pools=pools,ped=api.ped(),started=api.now()}
            return checkedHold()
        end)
    end
    function T.EndNativeCollectionHold(ticket)
        if not collectionHold or collectionHold.ticket~=ticket then return nil,'native_collection_hold_ticket_required' end
        if busy then return nil,'runtime_busy' end
        busy=true
        local ok,value,why=pcall(function()
            local current,failure=checkedHold();if not current then return nil,failure end
            local receipt=api.readCollectionEscrow(ticket)
            if not checkedHold() then return nil,collectionHold.reason end
            if type(receipt)~='table' or receipt.phase~='cleaned' or receipt.ticket~=ticket
                or not same(receipt.identity,collectionHold.identity) or receipt.quantityBefore~=1
                or receipt.quantityAfter~=0 or receipt.guidCaptured~=true or receipt.guidReleased~=true
                or receipt.otherPoolsUnchanged~=true then
                return holdFailure('native_collection_escrow_cleanup_unconfirmed')
            end
            collectionHold=nil -- normal observation/release resumes at unchanged saved baseline
            return true
        end)
        busy=false
        if not ok then return holdFailure('native_collection_hold_adapter_failed') end
        return value,why
    end
    function T.Suspend(reason)
        if collectionHold then return holdFailure(reason or 'native_collection_hold_suspended') end
        pcall(api.block,true); return host.Suspend(reason)
    end
    function T.ReadDeathObservation() return host.ReadDeathObservation() end
    function T.Status()
        local state=host.Status()
        state.fault=driver.Status().fault; state.runtimeBusy=busy
        state.deathRecovery=driver.Status().deathRecovery
        if collectionHold then state.collectionHold={phase=collectionHold.phase,reason=collectionHold.reason,
            ticket=collectionHold.ticket,revision=collectionHold.revision} end
        return state
    end
    return T
end

-- Explicit bootstrap factory. Owning code supplies registration/scheduler hooks;
-- nothing is installed and no runtime is constructed until Start is requested.
WeaponCharacterAmmoClientBootstrap={}
function WeaponCharacterAmmoClientBootstrap.New(adapters,bindings)
    if type(adapters)~='table' or type(bindings)~='table' then return nil,'invalid_bootstrap' end
    local function callable(value)
        return type(value)=='function' or type(value)=='table'
            and type(rawget(value,'__cfx_functionReference'))=='string'
    end
    for _,name in ipairs({'ingress','checkpoint','frame'}) do
        if not callable(bindings[name]) then return nil,'missing_bootstrap_'..name end
    end
    local runtime,phase,reason=nil,'dormant',nil
    local T={}
    local function enabled()
        return Config.CharacterAmmunitionEnabled==true and Config.CharacterAmmoTransportEnabled==true
    end
    local function fail(code)
        phase,reason='failed',code
        pcall(adapters.block,true)
        if runtime then pcall(runtime.Suspend,code) end
        return nil,code
    end
    function T.Frame()
        if phase=='failed' then pcall(adapters.block,true); return nil,reason end
        if phase~='started' then return nil,'bootstrap_not_started' end
        if not enabled() then return fail('bootstrap_disabled') end
        local ok,result,why=pcall(runtime.Step)
        if not ok then return fail('bootstrap_frame_failed') end
        return result,why
    end
    function T.Start()
        if phase~='dormant' then return nil,'bootstrap_already_started' end
        if not enabled() then return nil,'character_ammunition_disabled' end
        -- Reserve before any factory/registration hook can yield.
        phase='starting'
        local ok,result,why=pcall(WeaponCharacterAmmoClientRuntime.New,adapters)
        if not ok or not result then return fail(why or 'bootstrap_runtime_failed') end
        runtime=result
        for _,entry in ipairs({{bindings.ingress,runtime},{bindings.checkpoint,runtime.Checkpoint},{bindings.frame,T.Frame}}) do
            -- The runtime factory and registration hooks can yield. Never
            -- install the next hook after shutdown during the preceding wait.
            if not enabled() then return fail('bootstrap_disabled') end
            local called,accepted=pcall(entry[1],entry[2])
            if not called or accepted~=true then return fail('bootstrap_registration_failed') end
            if not enabled() then return fail('bootstrap_disabled') end
        end
        phase='started'; return true
    end
    function T.Status() return {phase=phase,reason=reason,runtime=runtime and runtime.Status()} end
    function T.Transfer(...)
        if phase~='started' or not enabled() or not runtime then return nil,'bootstrap_not_active' end
        return runtime.Transfer(...)
    end
    return T
end
