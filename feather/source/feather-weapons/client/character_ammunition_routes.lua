-- Transport only. No threads/native state writes or automatic Begin.
WeaponCharacterAmmoClientTransport=WeaponCharacterAmmoTransport.Client({
    register=function(handler)
        RegisterNetEvent('feather-weapons:client:character-ammo',function(...)
            if source~=65535 or Config.CharacterAmmunitionEnabled~=true
                or Config.CharacterAmmoTransportEnabled~=true then return end
            handler(...)
        end)
    end,
    send=function(kind,id,report)
        assert(Config.CharacterAmmunitionEnabled==true and Config.CharacterAmmoTransportEnabled==true,
            'character_ammunition_disabled')
        TriggerServerEvent('feather-weapons:server:character-ammo',kind,id,report)
    end,
    timeout=function(callback) SetTimeout(10000,callback) end
})
-- Explicit bootstrap hook only; never install a loadout receiver automatically.
-- Server-origin ingress cannot enroll, choose a baseline or grant independently
-- of the canonical runtime's creation/restore/ack checks.
WeaponCharacterAmmoClientIngress={}
local installed=false
local ingressRuntime,stopped=nil,false
function WeaponCharacterAmmoClientIngress.Install(runtime)
    if stopped then return nil,'loadout_ingress_stopped' end
    if Config.CharacterAmmunitionEnabled~=true or Config.CharacterAmmoTransportEnabled~=true then
        return nil,'character_ammunition_disabled'
    end
    if installed then return nil,'loadout_ingress_already_installed' end
    if type(runtime)~='table' or type(runtime.Receive)~='function' or type(runtime.Suspend)~='function' then
        return nil,'invalid_loadout_runtime'
    end
    installed=true
    ingressRuntime=runtime
    RegisterNetEvent('feather-weapons:client:character-ammo-loadout',function(bundle)
        if stopped or source~=65535 or Config.CharacterAmmunitionEnabled~=true
            or Config.CharacterAmmoTransportEnabled~=true then return end
        local ok,accepted,reason=pcall(runtime.Receive,bundle,true)
        if not ok then pcall(runtime.Suspend,'loadout_ingress_failed') end
        if not ok or not accepted then
            print('[feather-weapons] native loadout refused: '..tostring(ok and reason or 'loadout_ingress_failed'))
        end
        if ok and accepted and type(bundle.equipmentTransition)=='table' then
            CreateThread(function()
                local started=GetGameTimer()
                while (GetGameTimer()-started)%4294967296<10000 do
                    local state=runtime.Status()
                    local baseline=state.session and state.session.ammo and state.session.ammo.baseline
                    if state.phase=='active' and baseline and baseline.epoch==bundle.runtime.epoch then
                        TriggerServerEvent('feather-weapons:server:native-equipment-restored',bundle.equipmentTransition.ticket,
                            {characterId=baseline.characterId,sessionId=baseline.sessionId,epoch=baseline.epoch})
                        return
                    end
                    if stopped or state.phase=='frozen' or state.phase=='suspended' then return end
                    Wait(50)
                end
            end)
        end
    end)
    RegisterNetEvent('feather-weapons:client:native-equipment-release',function(request)
        if stopped or source~=65535 or Config.CharacterAmmunitionEnabled~=true
            or Config.CharacterAmmoTransportEnabled~=true or type(request)~='table' then return end
        local called,released,why,wear=pcall(runtime.ReleaseEquipment,request.identity,request.ticket,request.collectWear==true)
        TriggerServerEvent('feather-weapons:server:native-equipment-released',request.ticket,request.identity,called and released==true,wear)
        if not called or not released then print('[feather-weapons] equipment release refused: '..tostring(why)) end
    end)
    return true
end
-- Concrete registration adapters, still factory-only. The future owner supplies
-- input enforcement; this does not construct/start a runtime or enroll a player.
WeaponCharacterAmmoClientBindings={}
-- Native I/O composition only. Creation/owned-copy tracking remain explicitly
-- supplied by the lifecycle owner; there is no default grant or dual entitlement.
function WeaponCharacterAmmoClientBindings.NativeAdapters(creation,owned)
    return WeaponCharacterAmmoNativeAdapters.New(creation,owned,
        function(...) return WeaponCharacterAmmoClientTransport.Send(...) end)
end
function WeaponCharacterAmmoClientBindings.New(enforceInput)
    if type(enforceInput)~='function' then return nil,'missing_input_enforcement' end
    local checkpointBound,frameBound=false,false
    local function enabled()
        return Config.CharacterAmmunitionEnabled==true and Config.CharacterAmmoTransportEnabled==true
    end
    return {
        ingress=WeaponCharacterAmmoClientIngress.Install,
        checkpoint=function(handler)
            if not enabled() or checkpointBound or type(handler)~='function' then return false end
            checkpointBound=true
            local lifecycle=WeaponCharacterAmmoCheckpoint.Lifecycle({
                caller=GetInvokingResource,identity=function() return WeaponCharacterAmmoWorldContext.Identity() end,
                now=GetGameTimer,wait=Wait,
                enabled=function() return not stopped and enabled() and Config.NativeAlphaLifecycleWearEnabled==true end,
                status=function() return ingressRuntime and ingressRuntime.Status() end,
                send=function(id,scope) TriggerServerEvent('feather-weapons:server:native-logout-wear',id,scope) end,
            })
            RegisterNetEvent('feather-weapons:client:native-logout-wear-result',function(id,scope,result)
                lifecycle.Reply(id,scope,result,source==65535)
            end)
            exports('CheckpointCharacterAmmunitionBeforeLogout',function(context)
                if GetInvokingResource()~='feather-character' then
                    return {ok=false,error={code='checkpoint_caller_denied'}}
                end
                if not enabled() then return {ok=false,error={code='character_ammunition_disabled'}} end
                if Config.NativeAlphaLifecycleWearEnabled==true then return lifecycle.Run(context) end
                return handler(context)
            end)
            local called,result=pcall(function()
                return exports['feather-character']:RegisterLogoutCheckpoint(
                    'feather-weapons:character-ammunition','CheckpointCharacterAmmunitionBeforeLogout')
            end)
            return called and type(result)=='table' and result.ok==true
        end,
        frame=function(handler)
            if not enabled() or frameBound or type(handler)~='function' then return false end
            frameBound=true
            CreateThread(function()
                local failed=false
                while true do
                    if not enabled() then failed=true end
                    if not failed then
                        local stepped=pcall(handler)
                        local enforced=pcall(enforceInput)
                        failed=not stepped or not enforced
                    end
                    if failed then DisablePlayerFiring(PlayerId(),true) end
                    Wait(0)
                end
            end)
            return true
        end,
    }
end
-- Assembles the concrete adapters, but still does not call Start. The caller
-- must provide owned creation and explicitly own the activation lifecycle.
function WeaponCharacterAmmoClientBindings.Bootstrap(creation,owned,knife,melee,throwable,utility)
    local api,enforce=WeaponCharacterAmmoClientBindings.NativeAdapters(creation,owned)
    if not api then return nil,enforce end
    api.knife=knife -- supplied only by the same concrete native owner
    api.melee=melee
    api.throwable=throwable
    api.utility=utility
    local bindings,reason=WeaponCharacterAmmoClientBindings.New(enforce)
    if not bindings then return nil,reason end
    return WeaponCharacterAmmoClientBootstrap.New(api,bindings)
end
local readinessInstalled=false
function WeaponCharacterAmmoClientBindings.Readiness(owner)
    if stopped or readinessInstalled then return nil,'readiness_already_installed_or_stopped' end
    if Config.CharacterAmmunitionEnabled~=true or Config.CharacterAmmoTransportEnabled~=true
        or type(owner)~='table' or type(owner.Readiness)~='function' then
        return nil,'readiness_disabled_or_invalid_owner'
    end
    readinessInstalled=true
    local handshake=WeaponCharacterAmmoReadiness.Client({
        enabled=function()
            return not stopped and Config.CharacterAmmunitionEnabled==true
                and Config.CharacterAmmoTransportEnabled==true
        end,
        now=GetGameTimer,owner=owner,
        send=function(id,identity)
            TriggerServerEvent('feather-weapons:server:character-ammo-ready',id,identity)
        end,
    })
    RegisterNetEvent('feather-weapons:client:character-ammo-ready',function(id,identity,ok,reason)
        handshake.Reply(id,identity,ok,reason,source==65535)
    end)
    CreateThread(function()
        while not stopped and Config.CharacterAmmunitionEnabled==true
            and Config.CharacterAmmoTransportEnabled==true do
            local called,_,reason=pcall(handshake.Step)
            if not called then
                print('[feather-weapons] native readiness failed; owner retained')
                break
            end
            if reason=='readiness_retry_exhausted' then
                print('[feather-weapons] native readiness retries exhausted; no loadout granted')
                break
            end
            Wait(500)
        end
    end)
    return true
end
local function stopNativeHost(resource)
    if resource~=GetCurrentResourceName() or stopped then return end
    -- No asynchronous seal/SQL can be completed reliably during destruction.
    -- Only an independently empty, settled owner may remove its exact copies.
    stopped=true
    local owner=WeaponCharacterAmmoActiveOwner
    local ownerStatus=owner and owner.Status and owner.Status()
    if ownerStatus and ownerStatus.cleanupComplete==true and ownerStatus.ownedCopies==0 then
        print('[feather-weapons] native stop cleanup PASS no tracked copies remain; no new SQL/release acknowledgement')
    elseif owner and type(owner.StopZeroAmmo)=='function' then
        local called,cleaned,why=pcall(owner.StopZeroAmmo)
        print('[feather-weapons] native stop cleanup '..(called and cleaned==true and 'PASS owned zero-ammo copies removed; no SQL/release acknowledgement'
            or 'REFUSED '..tostring(called and why or 'stop_cleanup_exception')..'; orderly release or operator recovery required'))
    end
    if ingressRuntime then pcall(ingressRuntime.Suspend,'resource_stopping') end
    WeaponCharacterAmmoClientTransport.Close()
end
AddEventHandler('onResourceStop',stopNativeHost)
AddEventHandler('onClientResourceStop',stopNativeHost)
