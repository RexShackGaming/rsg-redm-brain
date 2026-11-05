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
    return api,function() if blocked then DisablePlayerFiring(PlayerId(),true) end end
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
    local T={}
    local function reserved(fn,...)
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
        if busy then pcall(api.block,true); return nil,'runtime_busy' end
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
    function T.Suspend(reason) pcall(api.block,true); return host.Suspend(reason) end
    function T.ReadDeathObservation() return host.ReadDeathObservation() end
    function T.Status()
        local state=host.Status()
        state.fault=driver.Status().fault; state.runtimeBusy=busy
        state.deathRecovery=driver.Status().deathRecovery
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
