-- Read-only independent world identity. Never derives identity from a loadout.
WeaponCharacterAmmoContext={}
function WeaponCharacterAmmoContext.New(api)
    local T={}
    -- RedM BOOL readbacks can be numeric. Zero must not be Lua-truthy here.
    local function yes(value) return value==true or value==1 end
    local function context()
        if api.state('feather-core')~='started' or api.state('feather-character')~='started' then return nil end
        local ok,value=pcall(api.character)
        if not ok or type(value)~='table' then return nil end
        for _,key in ipairs({'characterId','sessionId'}) do
            if type(value[key])~='string' or #value[key]<1 or #value[key]>128 then return nil end
        end
        return {characterId=value.characterId,sessionId=value.sessionId}
    end
    function T.Identity() return context() end
    local function read(expectedLife)
        local expectDead=expectedLife=='dead'
        local identity=context()
        if not identity then return {ok=false,error={code='character_context_unavailable'}} end
        local ped=api.ped()
        local validPed=type(ped)=='number' and ped>0 and ped%1==0
        local network=api.network()
        local exists=validPed and api.exists(ped) or false
        local dead=validPed and api.dead(ped) or false
        if not yes(network) or not validPed or not yes(exists) or yes(dead)~=expectDead then
            return {ok=false,error={code='native_world_not_ready',detail={ped=ped,
                network=network,exists=exists,dead=dead}}}
        end
        if api.state('feather-medical')~='started' then return {ok=false,error={code='medical_unavailable'}} end
        local ok,condition=pcall(api.medical)
        local value=ok and type(condition)=='table' and condition.ok==true and condition.value
        if type(value)~='table' or value.characterId~=identity.characterId or value.sessionId~=identity.sessionId
            or value.lifeState~=expectedLife or type(value.revision)~='number' or value.revision<0
            or value.revision%1~=0 or value.revision==math.huge then
            return {ok=false,error={code='medical_not_alive_or_current'}}
        end
        local after=context()
        if not after or after.characterId~=identity.characterId or after.sessionId~=identity.sessionId
            or not yes(api.network()) or api.state('feather-medical')~='started'
            or api.ped()~=ped or not yes(api.exists(ped)) or yes(api.dead(ped))~=expectDead then
            return {ok=false,error={code='world_changed_during_context_read'}}
        end
        return {ok=true,value={characterId=identity.characterId,sessionId=identity.sessionId,ped=ped,
            medicalRevision=value.revision,lifeState=expectedLife,ready=not expectDead}}
    end
    function T.Read() return read('alive') end
    -- Diagnostic/persistence preflight only, never alive readiness or restore authority.
    function T.ReadDeath() return read('dead') end
    function T.Ready() return T.Read().ok==true end
    return T
end
