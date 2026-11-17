-- Explicit bounded read-only diagnostic, never a pickup authority or gameplay
-- route. No pickup permission switches, projectile listeners, grants or deletion.
local capture,completion,engineEvent
WeaponNativeThrowableEventProbe={}
local P=WeaponNativeThrowableEventProbe
local function copy(v) if type(v)~='table' then return v end;local r={};for k,x in pairs(v) do r[k]=copy(x) end;return r end
local function integer(v,min) return type(v)=='number' and v>=min and v<math.huge and v%1==0 end
local function yes(v) return v==true or v==1 end
local function emit(v) print('[WeaponNativeThrowableEvents] '..json.encode(v)) end
local function enabled() return GetConvarInt('feather_native_throwable_event_probe',0)==1 end
local function world()
    if not WeaponCharacterAmmoActiveOwner then return nil end
    local status=WeaponCharacterAmmoActiveOwner.Status()
    local runtime=status and status.bootstrap and status.bootstrap.runtime
    local baseline=runtime and runtime.session and runtime.session.ammo and runtime.session.ammo.baseline
    local ped=PlayerPedId()
    if not baseline or not integer(ped,1) or not yes(DoesEntityExist(ped)) or yes(IsEntityDead(ped)) then return nil end
    for _,key in ipairs({'characterId','sessionId'}) do if type(baseline[key])~='string' then return nil end end
    if type(runtime.epoch)~='string' then return nil end
    return {characterId=baseline.characterId,sessionId=baseline.sessionId,epoch=runtime.epoch,ped=ped}
end
local function stop(state,reason)
    state.phase='complete';state.reason=reason;engineEvent=nil
    emit(copy(state))
    if completion and completion.state==state then
        local callback=completion.fn;completion=nil
        pcall(callback,copy(state))
    end
end
local function matches(row,hashes)
    return row.model and hashes.models[row.model]==true or hashes.pickups[row.pickupType]==true
        or row.inventoryItemHash==hashes.weapon
end
local function command(_,args,challenge,completed,releasedWorld,observed,durationMs)
    local readWorld=releasedWorld or world
    args=args or {}
    if #args~=1 or (args[1]~='start' and args[1]~='status' and args[1]~='stop') then
        return emit({phase='refused',reason='use_start_status_or_stop',noWrites=true})
    end
    if args[1]=='status' then return emit(capture and copy(capture) or {phase='idle',noWrites=true}) end
    if args[1]=='stop' then
        if capture and capture.phase=='capturing' then stop(capture,'operator_stop') end
        return
    end
    if (not challenge and not enabled()) or capture and capture.phase=='capturing' then
        return emit({phase='refused',reason='explicit_probe_gate_and_idle_required',noWrites=true})
    end
    local ok,bound=pcall(readWorld)
    local built,build=pcall(GetGameBuildNumber)
    local profiles,why=WeaponNativeThrowableEventReference.Profiles(built and build or 0)
    if not ok or not bound or not profiles then
        return emit({phase='refused',reason=why or 'current_alive_native_owner_required',noWrites=true})
    end
    if challenge then
        for _,key in ipairs({'characterId','sessionId','epoch'}) do
            if type(challenge)~='table' or challenge[key]~=bound[key] then
                return emit({phase='refused',reason='capture_challenge_identity_changed',noWrites=true})
            end
        end
    end
    local hashes={models={},pickups={},weapon=joaat('WEAPON_THROWN_TOMAHAWK') & 0xffffffff}
    for _,name in ipairs({'w_melee_tomahawk01','w_melee_tomahawk02'}) do hashes.models[joaat(name) & 0xffffffff]=true end
    for _,name in ipairs({'pickup_weapon_thrown_tomahawk_mp','pickup_weapon_thrown_tomahawk'}) do hashes.pickups[joaat(name) & 0xffffffff]=true end
    capture={phase='capturing',captureVersion=4,build=build,identity=bound,startedAt=GetGameTimer(),durationMs=releasedWorld and (durationMs or 90000) or 30000,
        records={},frames=0,readFailures=0,objectScans=0,projectileReads=0,projectileReadFailures=0,projectileReaderAvailable=type(GetProjectileOfProjectileTypeWithinDistance)=='function',objectScanFailures=0,objectPoolPartial=false,truncated=false,noWrites=true,originConfirmed=false,
        pickupCredits=false,clientDiagnosticOnly=true}
    local state=capture
    local seenTargets,lastTarget,lastObjects,lastProjectile={},nil,nil,nil
    local landingOrigin,watched,previousSamples,lastCandidates=nil,{},{},nil
    local function objectEvidence(entity)
        if not integer(entity,1) or not yes(DoesEntityExist(entity)) or type(GetEntityModel)~='function' then return nil end
        local model=GetEntityModel(entity) & 0xffffffff
        if not hashes.models[model] then return nil end
        local networked=type(NetworkGetEntityIsNetworked)=='function' and yes(NetworkGetEntityIsNetworked(entity)) or false
        local net=networked and NetworkGetNetworkIdFromEntity(entity) or nil
        if networked and not integer(net,1) then return nil end
        if not yes(DoesEntityExist(entity)) or (GetEntityModel(entity) & 0xffffffff)~=model then return nil end
        if networked and (not yes(NetworkGetEntityIsNetworked(entity)) or NetworkGetNetworkIdFromEntity(entity)~=net) then return nil end
        return {entity=entity,model=model,networked=networked,networkId=net}
    end
    local function record(kind,fields)
        if #state.records>=24 then state.truncated=true;return end -- reserve event capacity
        local row=fields or {};row.kind=kind;row.elapsedMs=(GetGameTimer()-state.startedAt)%4294967296
        row.noWrites=true;row.originConfirmed=false;row.pickupCredits=false;row.clientDiagnosticOnly=true
        state.records[#state.records+1]=row
    end
    if releasedWorld then
        engineEvent=function(name,args)
            if capture~=state or state.phase~='capturing' or type(name)~='string' or #name>96 or #state.records>=32 then return end
            local lower=name:lower()
            if not lower:find('pickup',1,true) and not lower:find('projectile',1,true) and not lower:find('collect',1,true) then return end
            local after=readWorld()
            if not after or after.ped~=bound.ped or after.epoch~=bound.epoch or after.sessionId~=bound.sessionId
                or after.characterId~=bound.characterId then return end
            local values={}
            if type(args)=='table' then for i=1,math.min(#args,8) do
                local v=args[i]
                if type(v)=='number' and v==v and v>-math.huge and v<math.huge then values[i]=v
                elseif type(v)=='boolean' then values[i]=v and 1 or 0 else values[i]=0 end
            end end
            state.records[#state.records+1]={kind='game_event',name=name,rawSlots=values,
                elapsedMs=(GetGameTimer()-state.startedAt)%4294967296,
                noWrites=true,originConfirmed=false,pickupCredits=false,clientDiagnosticOnly=true}
        end
    end
    emit(copy(state))
    completion=completed and {state=state,fn=completed} or nil
    CreateThread(function()
        while capture==state and state.phase=='capturing' do
            local ok,reason=pcall(function()
                local time=GetGameTimer()
                if not challenge and not enabled() then return 'probe_disabled' end
                if (time-state.startedAt)%4294967296>=state.durationMs or state.frames>=state.durationMs*0.12 then return 'window_complete' end
                local current=readWorld()
                if not current or current.ped~=bound.ped or current.characterId~=bound.characterId
                    or current.sessionId~=bound.sessionId or current.epoch~=bound.epoch then return 'owner_changed' end
                state.frames=state.frames+1
                -- Native DB typed signature: bool,Vector3,Object. Diagnostic
                -- only: the ownership argument is not durable origin proof.
                if releasedWorld and state.loanStage=='awaiting_pickup' and state.projectileReaderAvailable
                    and (not lastProjectile or (time-lastProjectile)%4294967296>=100) then
                    lastProjectile=time
                    for _,ownedOnly in ipairs({true,false}) do
                        state.projectileReads=state.projectileReads+1
                        local ok,found,_,entity=pcall(GetProjectileOfProjectileTypeWithinDistance,bound.ped,hashes.weapon,50.0,false,ownedOnly)
                        if not ok then state.projectileReadFailures=state.projectileReadFailures+1
                        elseif yes(found) then
                            local checked,object=pcall(objectEvidence,entity)
                            if not checked then state.projectileReadFailures=state.projectileReadFailures+1
                            elseif object then
                                if ownedOnly and type(GetEntityCoords)=='function' then
                                    local pos=GetEntityCoords(entity)
                                    landingOrigin={x=pos.x,y=pos.y,z=pos.z}
                                end
                                local key='projectile:'..object.entity..':'..tostring(object.networkId)..':'..object.model
                                if not seenTargets[key] and #state.records<24 then
                                    seenTargets[key]=true
                                    state.records[#state.records+1]={kind='tomahawk_projectile_snapshot',object=object,
                                        requestedOwnedOnly=ownedOnly,elapsedMs=(time-state.startedAt)%4294967296,
                                        noWrites=true,originConfirmed=false,pickupCredits=false,clientDiagnosticOnly=true}
                                end
                                -- A generic pool/unowned observation must not consume
                                -- the later owned-projectile notification. Snapshot
                                -- deduplication and typed notification are independent.
                                local fingerprint=object.entity..':'..tostring(object.networkId)..':'..object.model
                                local hint=(ownedOnly and 'owned-hint:' or 'hint:')..fingerprint
                                if observed and object.networked and seenTargets[key] and not seenTargets[hint] then
                                    seenTargets[hint]=true
                                    if ownedOnly then seenTargets['hint:'..fingerprint]=true end
                                    pcall(observed,copy(object),ownedOnly and 'owned_projectile' or nil)
                                end
                            end
                        end
                    end
                end
                -- The engine replaces the flying projectile with a pickup object.
                -- A closest-model result is only a candidate, never continuity or
                -- paid ownership proof. Retain each bounded fingerprint so its
                -- disappearance can be compared with the collection event.
                if releasedWorld and landingOrigin and type(GetClosestObjectOfType)=='function'
                    and (state.loanStage=='awaiting_pickup' or state.loanStage=='settling_events')
                    and (not lastCandidates or (time-lastCandidates)%4294967296>=100) then
                    lastCandidates=time
                    for model in pairs(hashes.models) do
                        local entity=GetClosestObjectOfType(landingOrigin.x,landingOrigin.y,landingOrigin.z,2.0,model,false,false,false)
                        local object=objectEvidence(entity)
                        if object and not watched[entity] then
                            local size=0;for _ in pairs(watched) do size=size+1 end
                            if size<6 then
                                watched[entity]=object
                                record('native_collection_candidate',{object=copy(object),candidateOnly=true})
                                if observed and object.networked then
                                    local proposal=copy(object);local p=GetEntityCoords(entity)
                                    proposal.position={x=p.x,y=p.y,z=p.z}
                                    pcall(observed,proposal,'collection_candidate')
                                end
                            end
                        end
                    end
                    for entity,object in pairs(watched) do
                        local current=objectEvidence(entity)
                        local intact=current and current.model==object.model and current.networkId==object.networkId
                        local sample=intact and 'present' or 'missing_or_changed'
                        if previousSamples[entity]~=sample then
                            previousSamples[entity]=sample
                            record('native_collection_candidate_state',{object=copy(object),state=sample,candidateOnly=true})
                        end
                    end
                end
                -- Isolated-loan fallback only: two bounded, read-only model
                -- snapshots per second while its one unit is out in the world.
                if releasedWorld and state.loanStage=='awaiting_pickup' and type(GetGamePool)=='function'
                    and (not lastObjects or (time-lastObjects)%4294967296>=500) then
                    lastObjects=time;state.objectScans=state.objectScans+1
                    local scanned,objects=pcall(function()
                        local pool=GetGamePool('CObject');assert(type(pool)=='table','object_pool_unreadable')
                        state.objectPoolPartial=state.objectPoolPartial or #pool>512
                        local origin=GetEntityCoords(bound.ped);local rows={}
                        -- Recent handles are useful diagnostic candidates, not ownership proof.
                        for index=#pool,math.max(1,#pool-511),-1 do
                            local entity=pool[index]
                            local object=objectEvidence(entity)
                            if object and not yes(IsEntityAttached(entity)) then
                                local pos=GetEntityCoords(entity)
                                local distance=(pos.x-origin.x)^2+(pos.y-origin.y)^2+(pos.z-origin.z)^2
                                if distance<=2500 then
                                    object.position={x=pos.x,y=pos.y,z=pos.z}
                                    rows[#rows+1]=object;if #rows==6 then break end
                                end
                            end
                        end
                        return rows
                    end)
                    if not scanned then state.objectScanFailures=state.objectScanFailures+1
                    else for _,object in ipairs(objects) do
                        local key='world:'..object.entity..':'..tostring(object.networkId)..':'..object.model
                        if not seenTargets[key] and #state.records<24 then
                            seenTargets[key]=true
                            state.records[#state.records+1]={kind='tomahawk_object_snapshot',object=object,
                                elapsedMs=(time-state.startedAt)%4294967296,noWrites=true,
                                originConfirmed=false,pickupCredits=false,clientDiagnosticOnly=true}
                            local hint='hint:'..object.entity..':'..tostring(object.networkId)..':'..object.model
                            if observed and object.networked and not seenTargets[hint] then seenTargets[hint]=true;pcall(observed,copy(object)) end
                        end
                    end end
                end
                -- Targeted read from the game's own pickup/looting interaction;
                -- no scan of every prop or request for control of a world object.
                if type(GetLootingPickupTargetEntity)=='function'
                    and (not lastTarget or (time-lastTarget)%4294967296>=100) then
                    lastTarget=time
                    local ok,target=pcall(function() return objectEvidence(GetLootingPickupTargetEntity(bound.ped)) end)
                    if ok and target then
                        local after=readWorld()
                        if not after or after.ped~=bound.ped or after.epoch~=bound.epoch or after.sessionId~=bound.sessionId
                            or after.characterId~=bound.characterId then return 'owner_changed' end
                        local key=target.entity..':'..tostring(target.networkId)..':'..target.model
                        if not seenTargets[key] then
                            seenTargets[key]=true
                            state.records[#state.records+1]={kind='pickup_target_snapshot',referenceBuild=build,
                                object=target,elapsedMs=(time-state.startedAt)%4294967296,
                                noWrites=true,originConfirmed=false,pickupCredits=false,clientDiagnosticOnly=true}
                            if #state.records>=32 then state.truncated=true;return 'record_limit' end
                        end
                    end
                end
                -- At most64 events per queue per frame; no broad object scans.
                for _,profile in ipairs(profiles) do
                    local count=GetNumberOfEvents(profile.queue)
                    if not integer(count,0) then error('event_count_unreadable') end
                    if count>64 then state.truncated=true end
                    for index=0,math.min(count,64)-1 do
                        local hash=GetEventAtIndex(profile.queue,index)
                        if integer(hash,-2147483648) and (hash & 0xffffffff)==(profile.eventHash & 0xffffffff) then
                            local buffer=string.rep('\0',profile.slots*8)
                            local read=Citizen.InvokeNative(0x57EC5FA4D4D6AFCA,profile.queue,index,buffer,profile.slots)
                            if yes(read) then
                                local row=WeaponNativeThrowableEventReference.Decode(build,profile.queue,hash,buffer)
                                if row and matches(row,hashes) then
                                    if type(PlayerId)=='function' then
                                        row.localPlayerIndex=PlayerId()
                                        row.collectorIsLocal=row.collectorPlayerIndex==row.localPlayerIndex
                                    end
                                    if type(GetPedAmmoByType)=='function' then
                                        local readCount,count=pcall(GetPedAmmoByType,bound.ped,joaat('AMMO_TOMAHAWK'))
                                        if readCount and integer(count,0) then row.nativeTomahawkQuantity=count end
                                    end
                                    if row.kind=='network_pickup' and integer(row.pickupHandle,1)
                                        and type(DoesPickupExist)=='function' and type(GetPickupObject)=='function' then
                                        local ok,object=pcall(function()
                                            return yes(DoesPickupExist(row.pickupHandle)) and objectEvidence(GetPickupObject(row.pickupHandle)) or nil
                                        end)
                                        row.pickupObject=ok and object or nil
                                        row.pickupObjectReadConfirmed=ok
                                        if type(HasPickupBeenCollected)=='function' then
                                            local readCollected,collected=pcall(HasPickupBeenCollected,row.pickupHandle)
                                            row.collectedReadConfirmed=readCollected
                                            if readCollected then row.nativeCollected=yes(collected) end
                                        end
                                    end
                                    local after=readWorld()
                                    if not after or after.epoch~=bound.epoch or after.ped~=bound.ped
                                        or after.sessionId~=bound.sessionId or after.characterId~=bound.characterId then return 'owner_changed' end
                                    row.elapsedMs=(time-state.startedAt)%4294967296
                                    state.records[#state.records+1]=row
                                    if releasedWorld and observed and row.kind=='ai_pickup' then pcall(observed,copy(row),'collection_event') end
                                    if #state.records>=32 then state.truncated=true;return 'record_limit' end
                                end
                            else
                                state.readFailures=state.readFailures+1
                                if state.readFailures>=16 then return 'read_failure_limit' end
                            end
                        end
                    end
                end
            end)
            if not ok then stop(state,'event_read_exception');return end
            if reason then stop(state,reason);return end
            Wait(0)
        end
    end)
end
function P.Start(bound,completed)
    if type(bound)~='table' or type(completed)~='function' then return false end
    local previous=capture
    command(0,{'start'},bound,completed)
    return capture~=previous and capture.phase=='capturing'
end
function P.Stop() command(0,{'stop'}) end
RegisterCommand('weaponNativeThrowableEvents',function(source,args) command(source,args) end,false)

-- Local trusted fixture port; no network event or public export admits this.
function P.StartReleased(bound,current,completed,observed,durationMs)
    if type(bound)~='table' or type(current)~='function' or type(completed)~='function' then return false end
    if durationMs~=nil and durationMs~=90000 and durationMs~=180000 then return false end
    local previous=capture
    command(0,{'start'},bound,completed,current,observed,durationMs)
    return capture~=previous and capture.phase=='capturing'
end
function P.Records() return capture and copy(capture.records) or {} end

function P.LoanStage(stage) if capture and capture.phase=='capturing' then capture.loanStage=stage end end
if type(AddEventHandler)=='function' then
    AddEventHandler('gameEventTriggered',function(name,args) if engineEvent then engineEvent(name,args) end end)
end
