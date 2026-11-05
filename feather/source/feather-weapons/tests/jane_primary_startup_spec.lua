-- Actual resource-start scheduler, read-only world mocks.
local jane='6a2fd060-c46f-11f1-9ae2-e0d55eaa2deb'
local function scenario(mode)
    Config={DevMode=true,CharacterAmmunitionEnabled=false,CharacterAmmoTransportEnabled=false}
    local worker,time,sends=nil,0,{}
    local identity={characterId=jane,sessionId='session'}
    local ready=false
    CreateThread=function(fn) worker=coroutine.create(fn) end
    GetGameTimer=function() return time end
    Wait=function() time=time+100; coroutine.yield() end
    TriggerServerEvent=function(...) sends[#sends+1]={...} end
    WeaponCharacterAmmoWorldContext={Identity=function() return identity end,
        Read=function() return {ok=ready,value={characterId=jane,sessionId='session',ped=1}} end}
    if mode=='foreign' then identity.characterId='original' end
    if mode=='disabled' then Config.CharacterAmmoTransportEnabled=true end
    dofile('tests/archive/client/jane_ammunition_startup.lua')
    assert(coroutine.resume(worker) and #sends==0)
    if mode=='foreign' or mode=='disabled' then assert(coroutine.status(worker)=='dead'); return end
    if mode=='changed' then identity.sessionId='other' elseif mode=='lost' then identity=nil
    elseif mode=='timeout' then time=30000 else ready=true end
    assert(coroutine.resume(worker) and coroutine.status(worker)=='dead')
    if mode=='success' then
        assert(#sends==1 and sends[1][1]=='feather-weapons:jane-zero:startup-ready'
            and sends[1][2]==jane and sends[1][3]=='session')
    else assert(#sends==0) end
end
for _,mode in ipairs({'success','foreign','disabled','changed','lost','timeout'}) do scenario(mode) end
-- All manifest paths exist; normal production manifest does not load the gate.
local file=assert(io.open('tests/archive/fxmanifest.jane-startup.lua')); local manifest=file:read('*a'); file:close()
for path in manifest:gmatch("'([^']+%.lua)'") do local entry=assert(io.open(path)); entry:close() end
file=assert(io.open('fxmanifest.lua')); local normal=file:read('*a'); file:close()
assert(not normal:find('jane_ammunition_startup.lua',1,true))
print('Jane resource-start client PASS (one read-only hint, alive settlement, foreign/disabled/identity loss/timeout refusal; isolated manifest paths verified)')
