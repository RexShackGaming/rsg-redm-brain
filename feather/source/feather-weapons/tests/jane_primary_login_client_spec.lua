-- Actual login listener, mocked world and scheduler; no native creation here.
local jane='6a2fd060-c46f-11f1-9ae2-e0d55eaa2deb'
local function scenario(change,disable,timeout)
    Config={DevMode=true,CharacterAmmunitionEnabled=false,CharacterAmmoTransportEnabled=false}
    local events,handlers,threads,sends={},{},{},{}
    local session,ready,time='old',true,0
    RegisterNetEvent=function(name,fn) events[name]=fn end
    AddEventHandler=function(name,fn) handlers[name]=fn end
    RegisterCommand=function() end
    CreateThread=function(fn) threads[#threads+1]=coroutine.create(fn) end
    GetGameTimer=function() return time end
    Wait=function() time=time+100; coroutine.yield() end
    TriggerServerEvent=function(...) sends[#sends+1]={...} end
    WeaponCharacterAmmoWorldContext={
        Identity=function() return {characterId=jane,sessionId=session} end,
        Read=function() return {ok=ready,value={characterId=jane,sessionId=session,ped=1}} end,
    }
    dofile('tests/archive/client/jane_ammunition_zero.lua')
    local arm=events['feather-weapons:jane-zero:login-arm']
    local activate=handlers['feather-character:client:runtime-ready.v1']
    source=1; arm('old'); activate({characterId=jane}); assert(#threads==0)
    source=65535; arm('wrong'); activate({characterId=jane}); assert(#threads==0)
    arm('old'); activate({characterId=jane}); assert(#threads==0,'old session must not consume arm')
    session='new'; ready=false
    activate({characterId='original'}); assert(#threads==0)
    activate({characterId=jane}); activate({characterId=jane}); assert(#threads==1)
    assert(coroutine.resume(threads[1]) and #sends==0,'wait for independent alive readiness')
    if change then session='other' elseif disable then Config.CharacterAmmunitionEnabled=true
    elseif timeout then time=30000 else ready=true end
    assert(coroutine.resume(threads[1]))
    if change or disable or timeout then assert(#sends==0)
    else
        assert(#sends==1 and sends[1][1]=='feather-weapons:jane-zero:login-ready'
            and sends[1][2]==jane and sends[1][3]=='new')
    end
    activate({characterId=jane}); assert(#threads==1,'no automatic retry or replay')
end
scenario(false,false,false); scenario(true,false,false)
scenario(false,true,false); scenario(false,false,true)
print('Jane automatic login client PASS (server arm, actual lifecycle listener, new independent identity, alive readiness, cancellation, timeout, one-use; mocked CFX)')
