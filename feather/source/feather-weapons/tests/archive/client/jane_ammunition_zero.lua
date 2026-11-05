local jane='6a2fd060-c46f-11f1-9ae2-e0d55eaa2deb'
local active,attempted=nil,false
local loginArm,loginRequested=nil,false
local function yes(v) return v==true or v==1 end
local function empty(ped,registry)
    for _,name in pairs(registry.names) do
        if GetPedAmmoByType(ped,joaat(name))~=0 then return false end
    end
    return true
end
local function cleanup()
    local owner=active
    if not owner then return end
    if owner.record then
        local ok,removed=pcall(owner.native.remove,owner.record)
        if not ok or removed~=true then print('[WeaponJaneZero] CLEANUP FAIL: owned entity not verified; retain server holds'); return end
    end
    active=nil
    TriggerServerEvent('feather-weapons:jane-zero:ack',owner.identity.epoch,'cleaned')
end
RegisterNetEvent('feather-weapons:jane-zero:begin',function(plan)
    if source~=65535 or active or attempted or Config.DevMode~=true
        or Config.CharacterAmmunitionEnabled==true or Config.CharacterAmmoTransportEnabled==true then return end
    if type(plan)~='table' or type(plan.identity)~='table' or plan.identity.characterId~=jane then return end
    attempted=true -- includes yields; one attempt per resource start
    local registry=assert(WeaponCharacterAmmoPolicy.Build(WeaponDefinitionCatalog))
    local identity=plan.identity
    local owner={identity=identity}; active=owner
    local ok,reason=pcall(function()
        assert(WeaponCharacterAmmoMaterialization.Validate(plan,registry,identity),'invalid plan')
        assert(#plan.items==1 and plan.items[1].itemInstanceId==112 and plan.items[1].itemRevision==1
            and plan.items[1].definitionId=='revolver_cattleman' and plan.items[1].point==2,'exact Jane Cattleman required')
        local world=WeaponCharacterAmmoWorldContext.Read()
        assert(world.ok and world.value.characterId==jane and world.value.sessionId==identity.sessionId,'Jane alive context required')
        local ped=world.value.ped
        local function current(check)
            local read=WeaponCharacterAmmoWorldContext.Read()
            return check==identity and read.ok and read.value.ped==ped
                and read.value.characterId==jane and read.value.sessionId==identity.sessionId
        end
        assert(empty(ped,registry),'all native ammo pools must already be empty; no reset authorized')
        owner.native=WeaponCharacterAmmoCreationNative.New(ped,current,function() return false end)
        owner.record=assert(owner.native.createSingle(plan.items[1],0,identity))
        assert(owner.native.finish({owner.record},identity) and empty(ped,registry),'post-creation holster/zero-ammo verification failed')
        TriggerServerEvent('feather-weapons:jane-zero:ack',identity.epoch,'created')
        local deadline=GetGameTimer()+60000
        while active==owner and GetGameTimer()<deadline and current(identity) and empty(ped,registry) do Wait(100) end
    end)
    if not ok then print('[WeaponJaneZero] FAIL '..tostring(reason)) end
    cleanup()
end)
RegisterCommand('WeaponJaneZeroCleanup',cleanup,false)
RegisterNetEvent('feather-weapons:jane-zero:login-arm',function(sessionId)
    if source~=65535 or active or attempted or loginArm or Config.DevMode~=true
        or Config.CharacterAmmunitionEnabled==true or Config.CharacterAmmoTransportEnabled==true
        or type(sessionId)~='string' or sessionId=='' then return end
    local read=WeaponCharacterAmmoWorldContext.Read()
    if not read.ok or read.value.characterId~=jane or read.value.sessionId~=sessionId then return end
    loginArm=sessionId
    print('[WeaponJanePrimaryLogin] ARMED: logout then login Jane; do not fire or switch characters')
end)
AddEventHandler('feather-character:client:runtime-ready.v1',function(lifecycle)
    if not loginArm or loginRequested or active or attempted or Config.DevMode~=true
        or Config.CharacterAmmunitionEnabled==true or Config.CharacterAmmoTransportEnabled==true
        or type(lifecycle)~='table' or lifecycle.characterId~=jane then return end
    local identity=WeaponCharacterAmmoWorldContext.Identity()
    if not identity or identity.characterId~=jane or identity.sessionId==loginArm then return end
    local expectedSession=identity.sessionId
    loginRequested=true -- reserve before readiness polling yields
    CreateThread(function()
        local deadline=GetGameTimer()+30000
        while GetGameTimer()<deadline do
            local currentIdentity=WeaponCharacterAmmoWorldContext.Identity()
            if Config.DevMode~=true or Config.CharacterAmmunitionEnabled==true
                or Config.CharacterAmmoTransportEnabled==true or not currentIdentity
                or currentIdentity.characterId~=jane or currentIdentity.sessionId~=expectedSession then
                print('[WeaponJanePrimaryLogin] CANCELLED: login context changed; no native writes requested'); return
            end
            local read=WeaponCharacterAmmoWorldContext.Read()
            if read.ok and read.value.characterId==jane and read.value.sessionId==expectedSession then
                TriggerServerEvent('feather-weapons:jane-zero:login-ready',jane,read.value.sessionId)
                return
            end
            Wait(100)
        end
        print('[WeaponJanePrimaryLogin] NOT READY: no new alive Jane session; no native writes requested')
    end)
end)
AddEventHandler('onResourceStop',function(name) if name==GetCurrentResourceName() then cleanup() end end)
