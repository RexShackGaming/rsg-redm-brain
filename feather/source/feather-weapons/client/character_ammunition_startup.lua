-- Native-only scoped host. Disabled or incomplete configuration never selects another runtime.
CreateThread(function()
    if Config.CharacterAmmunitionEnabled~=true or Config.CharacterAmmoTransportEnabled~=true then return end
    if Config.NativeAlphaRuntime~=true
        or not WeaponNativeEnrollment.Validate(Config) then
        print('[feather-weapons] native alpha startup refused: explicit scoped configuration required')
        return
    end
    -- Character selection/loading can outlast 30s on a fresh connection.
    -- Keep waiting without creating an owner or requesting a loadout early.
    local waitingNoticeAt=GetGameTimer()+30000
    local waitingNotified=false
    while true do
        if Config.CharacterAmmunitionEnabled~=true or Config.CharacterAmmoTransportEnabled~=true
            or Config.NativeAlphaRuntime~=true then return end
        local result=WeaponCharacterAmmoWorldContext.Read()
        if result.ok==true and WeaponNativeEnrollment.Allows(Config,result.value.characterId) then
            local owner,reason=WeaponCharacterAmmoNativeOwner.New()
            if not owner then print('[feather-weapons] native alpha owner refused: '..tostring(reason)); return end
            WeaponCharacterAmmoActiveOwner=owner
            local started,why=owner.Start()
            if not started then print('[feather-weapons] native alpha startup failed: '..tostring(why)); return end
            local bound,failure=owner.BindReadiness()
            if not bound then print('[feather-weapons] native alpha readiness failed: '..tostring(failure)); return end
            print('[feather-weapons] scoped native alpha client started; awaiting authoritative loadout')
            return
        end
        if not waitingNotified and GetGameTimer()>=waitingNoticeAt then
            waitingNotified=true
            print('[feather-weapons] native alpha waiting for configured character readiness; no loadout requested')
        end
        Wait(250)
    end
end)

RegisterCommand('weaponNativeMaintenanceStatus',function()
    local owner=WeaponCharacterAmmoActiveOwner
    if Config.NativeAlphaRuntime~=true or not owner or type(owner.MaintenanceStatus)~='function' then return end
    local called,value,reason=pcall(owner.MaintenanceStatus)
    if called and value then print('[feather-weapons] native maintenance '..json.encode(value))
    else print('[feather-weapons] native maintenance unavailable: '..tostring(reason or value)) end
end,false)
RegisterCommand('weaponNativeEntityStatus',function()
    local owner=WeaponCharacterAmmoActiveOwner
    if Config.DevMode~=true or not owner or type(owner.InspectTrackedEntities)~='function' then return end
    local ok,value,why=pcall(owner.InspectTrackedEntities)
    print('[WeaponNativeEntityStatus] '..(ok and value and json.encode(value) or ('REFUSED '..tostring(why or value))))
end,false)
RegisterCommand('weaponNativeGuidComponentProbe',function()
    local owner=WeaponCharacterAmmoActiveOwner
    if not owner or type(owner.ProbeGuidComponent)~='function' then return print('[WeaponNativeGuidComponentProbe] REFUSED owner unavailable') end
    local ok,value,why=pcall(owner.ProbeGuidComponent)
    print('[WeaponNativeGuidComponentProbe] '..(ok and value and ('OBSERVED '..json.encode(value)) or ('REFUSED '..tostring(why or value))))
end,false)
RegisterCommand('weaponNativeComponentSlotStatus',function(_,args)
    if Config.DevMode~=true or Config.NativeAlphaRuntime~=true then return print('[WeaponNativeComponentSlotStatus] REFUSED native development scope required') end
    local function yes(value) return value==true or value==1 end
    local function read(weaponName,componentName)
    return WeaponNativeAttachmentSlots.Read({
        current=function() return Config.DevMode==true and Config.NativeAlphaRuntime==true end,
        category=function()
            local raw=string.rep('\0',104)
            if not yes(Citizen.InvokeNative(0xFE90ABBCBFDC13B2,joaat(weaponName),raw)) then return nil end
            return string.unpack('<I4',raw,9) -- game script outData.f_1, 8-byte script slots
        end,
        count=function(category) return Citizen.InvokeNative(0x44915068579D7710,category,Citizen.ResultAsInteger()) end,
        slot=function(category,index)
            local found,slot=Citizen.InvokeNative(0x8A9BD0DB7E8376CF,category,index,Citizen.PointerValueInt(),
                Citizen.ReturnResultAnyway(),Citizen.ResultAsInteger())
            return yes(found) and slot or nil
        end,
        compatible=function(category,slot)
            return yes(Citizen.InvokeNative(0x856FF92C57742AE5,joaat(componentName),category,slot))
        end,
    })
    end
    if args and #args>0 and (#args~=1 or args[1]~='catalog') then
        return print('[WeaponNativeComponentSlotStatus] REFUSED use no arguments or catalog')
    end
    local ok,value,why
    if args and args[1]=='catalog' then
        ok,value,why=pcall(WeaponNativeAttachmentSlots.Catalog,WeaponDefinitionCatalog,read)
    else ok,value,why=pcall(read,'WEAPON_REPEATER_CARBINE','COMPONENT_REPEATER_CARBINE_SIGHT_WIDE') end
    print('[WeaponNativeComponentSlotStatus] '..(ok and value and json.encode(value) or ('REFUSED '..tostring(why or value))))
end,false)
RegisterCommand('weaponNativeChildComponentProbe',function(_,args)
    local action=args and args[1]
    if action~='install' and action~='status' and action~='remove' then
        return print('[WeaponNativeChildComponentProbe] REFUSED use install/status/remove')
    end
    local owner=WeaponCharacterAmmoActiveOwner
    if not owner then return print('[WeaponNativeChildComponentProbe] REFUSED owner unavailable') end
    local ok,value,why=pcall(owner.ProbeGuidComponent,action)
    print('[WeaponNativeChildComponentProbe] '..(ok and value and ('OBSERVED '..json.encode(value)) or ('REFUSED '..tostring(why or value))))
end,false)
RegisterCommand('weaponNativeStatus',function()
    if Config.NativeAlphaRuntime~=true then
        print('[feather-weapons] native alpha is disabled'); return
    end
    local owner=WeaponCharacterAmmoActiveOwner
    if not owner then print('[feather-weapons] native alpha NOT READY: owner not started'); return end
    local status=owner.Status()
    local runtime=status.bootstrap and status.bootstrap.runtime
    local active=status.phase=='started' and runtime and runtime.phase=='active'
        and not runtime.fault and not runtime.runtimeBusy
    print('[feather-weapons] native alpha '..(active and 'ACTIVE' or 'NOT ACTIVE')..': '..json.encode(status))
end,false)
