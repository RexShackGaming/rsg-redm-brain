-- Isolated native gate driver; native adapter separately regression-tested.
local jane='6a2fd060-c46f-11f1-9ae2-e0d55eaa2deb'
local function scenario(nonzero,foreign,removeFails)
    Config={DevMode=true,CharacterAmmunitionEnabled=false,CharacterAmmoTransportEnabled=false}
    local begin
    RegisterNetEvent=function(name,fn) if name=='feather-weapons:jane-zero:begin' then begin=fn end end
    RegisterCommand=function() end
    AddEventHandler=function() end
    local time,created,removed=0,0,0
    GetGameTimer=function() return time end
    Wait=function() time=time+60000 end
    joaat=function(v) return v end
    GetPedAmmoByType=function() return nonzero and 1 or 0 end
    local phases={}
    TriggerServerEvent=function(_,_,phase) phases[#phases+1]=phase end
    WeaponCharacterAmmoPolicy={Build=function() return {names={a='AMMO_REVOLVER'},weapons={}} end}
    WeaponDefinitionCatalog={}
    WeaponCharacterAmmoMaterialization={Validate=function() return true end}
    WeaponCharacterAmmoWorldContext={Read=function() return {ok=true,value={ped=1,characterId=foreign and 'original' or jane,sessionId='s'}} end}
    WeaponCharacterAmmoCreationNative={New=function(_,current)
        return {createSingle=function(item,amount,identity)
            assert(amount==0 and current(identity) and item.itemInstanceId==112)
            created=created+1; return {entity=2}
        end,finish=function() return true end,remove=function()
            removed=removed+1; return not removeFails
        end}
    end}
    dofile('tests/archive/client/jane_ammunition_zero.lua')
    local plan={identity={characterId=jane,sessionId='s',epoch='e'},items={{itemInstanceId=112,itemRevision=1,
        definitionId='revolver_cattleman',point=2}}}
    source=1; begin(plan); assert(created==0,'client-origin begin forbidden')
    source=65535; begin(plan)
    if nonzero or foreign then
        assert(created==0 and phases[#phases]=='cleaned','preflight refusal cannot create/reset ammo')
    elseif removeFails then
        assert(created==1 and removed==1 and phases[#phases]=='created','failed cleanup cannot acknowledge release')
    else
        assert(created==1 and removed==1 and phases[1]=='created' and phases[2]=='cleaned')
    end
    begin(plan); assert(created<=1,'one attempt per start')
end
scenario(false,false,false); scenario(true,false,false); scenario(false,true,false); scenario(false,false,true)
print('Jane zero native client gate PASS (server origin, zero-only creation, nonzero/foreign refusal, automatic cleanup, failed cleanup retains hold; native mocks)')
