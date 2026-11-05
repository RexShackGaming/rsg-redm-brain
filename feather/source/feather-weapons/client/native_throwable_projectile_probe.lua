-- Explicit one-shot READ-ONLY client evidence, never server origin authority.
-- No threads, entity control requests, ammo setters, pickup or network messages.
local lastRead
local function finite(v) return type(v)=='number' and v==v and v>-math.huge and v<math.huge end
local function integer(v,min) return finite(v) and v>=min and v%1==0 end
local function yes(v) return v==true or v==1 end
local function emit(v) print('[WeaponNativeProjectileSnapshot] '..json.encode(v)) end
local function world()
    local owner=WeaponCharacterAmmoActiveOwner
    if not owner then return nil end
    local ok,status=pcall(owner.Status)
    local runtime=ok and status and status.bootstrap and status.bootstrap.runtime
    if not runtime or status.phase~='started' or runtime.phase~='active' or runtime.runtimeBusy
        or runtime.quiescing or runtime.receiving or runtime.fault then return nil end
    local session=runtime.session
    local baseline=session and session.ammo and session.ammo.baseline
    local ped=PlayerPedId()
    if not baseline or session.ammo.pending or session.ammo.closing or session.ammo.deathClosing
        or not integer(ped,1) or not yes(DoesEntityExist(ped)) or yes(IsEntityDead(ped)) then return nil end
    return {ped=ped,characterId=baseline.characterId,sessionId=baseline.sessionId,epoch=runtime.epoch,
        revision=baseline.revision}
end
local function position(entity)
    local p=GetEntityCoords(entity)
    if not p or not finite(p.x) or not finite(p.y) or not finite(p.z) then return nil end
    return {x=p.x,y=p.y,z=p.z}
end
RegisterCommand('weaponNativeProjectileSnapshot',function(_,args)
    if Config.DevMode~=true or not WeaponNativeThrowablePolicy or not WeaponNativeThrowablePolicy.Enabled()
        or GetConvarInt('feather_native_throwable_client_probe',0)~=1 or (args and #args~=0) then
        return emit({phase='refused',reason='explicit_client_probe_gate_required',noWrites=true})
    end
    local now=GetGameTimer()
    if lastRead and (now-lastRead)%4294967296<5000 then return emit({phase='refused',reason='probe_rate_limited',noWrites=true}) end
    lastRead=now -- reserve before local exports/read natives can yield
    local ok,bound=pcall(world)
    if not ok or not bound then return emit({phase='refused',reason='active_alive_owner_required',noWrites=true}) end
    local read,pool=pcall(function() return GetGamePool('CObject') end)
    if not read or type(pool)~='table' then return emit({phase='refused',reason='object_pool_unavailable',noWrites=true}) end
    local located,origin=pcall(position,bound.ped)
    if not located or not origin then return emit({phase='refused',reason='ped_position_unavailable',noWrites=true}) end
    local rows,failures,scanned={},0,0
    for index=1,math.min(#pool,512) do
        scanned=scanned+1
        local seen,row=pcall(function()
            local handle=pool[index]
            if not integer(handle,1) or not yes(DoesEntityExist(handle)) then return nil end
            local coords=position(handle)
            if not coords then error('position') end
            local distance=(coords.x-origin.x)^2+(coords.y-origin.y)^2+(coords.z-origin.z)^2
            if distance>2500 then return nil end -- bounded fifty-metre diagnostic, no pickup proximity authority
            local rawModel=GetEntityModel(handle)
            if not integer(rawModel,-2147483648) or rawModel>4294967295 then error('model') end
            local networkedOk,networked=pcall(NetworkGetEntityIsNetworked,handle)
            local netOk,net=false,nil
            -- Local map props/attachments do not have network objects. Avoid
            -- invoking a getter that emits engine warnings for those handles.
            if networkedOk and yes(networked) then netOk,net=pcall(NetworkGetNetworkIdFromEntity,handle) end
            local attachedOk,attached=pcall(IsEntityAttached,handle)
            return {handle=handle,model=rawModel & 0xffffffff,modelRaw=rawModel,position=coords,
                distanceSquared=distance,networkId=netOk and integer(net,0) and net or nil,
                networkReadConfirmed=netOk and integer(net,0) or false,
                networked=networkedOk and yes(networked) or false,networkedReadConfirmed=networkedOk,
                attached=attachedOk and yes(attached) or false,attachmentReadConfirmed=attachedOk}
        end)
        if not seen then failures=failures+1 elseif row then rows[#rows+1]=row end
    end
    table.sort(rows,function(a,b)
        if a.networked~=b.networked then return a.networked end
        if a.attached~=b.attached then return not a.attached end
        if a.distanceSquared~=b.distanceSquared then return a.distanceSquared<b.distanceSquared end
        return a.handle<b.handle
    end)
    local nearby=#rows
    while #rows>16 do table.remove(rows) end
    local checked,after=pcall(world)
    if not checked or not after or after.ped~=bound.ped or after.characterId~=bound.characterId
        or after.sessionId~=bound.sessionId or after.epoch~=bound.epoch then
        return emit({phase='refused',reason='owner_changed_during_probe',noWrites=true})
    end
    emit({phase='snapshot',epoch=bound.epoch,ledgerRevision=bound.revision,objects=rows,scanned=scanned,
        poolSize=#pool,nearbyObjects=nearby,partial=scanned<#pool or nearby>#rows,
        poolPartial=scanned<#pool,outputPartial=nearby>#rows,nativeReadFailures=failures,
        noWrites=true,originConfirmed=false,pickupCredits=false,clientDiagnosticOnly=true})
end,false)
