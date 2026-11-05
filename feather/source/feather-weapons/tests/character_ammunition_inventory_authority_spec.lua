-- Actual Weapons service + actual Inventory API; only CFX/SQL are mocked.
local function copy(value)
    if type(value)~='table' then return value end
    local result={}; for key,item in pairs(value) do result[key]=copy(item) end; return result
end
local documents,sequence={},0
json={encode=function(value) sequence=sequence+1; documents[tostring(sequence)]=copy(value); return tostring(sequence) end,
    decode=function(value) return copy(assert(documents[value])) end}
Result={Codes={DENIED='denied',INVALID_INPUT='invalid',CONFLICT='conflict',NOT_FOUND='missing',LIMIT_EXCEEDED='limit'},
    Ok=function(value) return {ok=true,value=value} end,
    Err=function(code,message) return {ok=false,error={code=code,message=message}} end,
    IsOk=function(value) return value and value.ok==true end}
Config={CharacterAmmunitionEnabled=true}
InventoryIdentity={NormalizeCharacterId=function(value) return value=='c' and value or nil end}
InventoryAPI={AccessModes={REMOVE='remove',INSERT='insert'}}
local caller='feather-inventory'
local current=true
local inventory,registered={},{}
exports=setmetatable({['feather-inventory']=inventory,
    ['feather-core']={IsSessionCurrent=function(_,source,session,character)
        return current and source==1 and session=='s' and character=='c'
    end},['feather-weapons']={}},
    {__call=function(_,name,fn) registered[name]=fn end})
GetInvokingResource=function() return caller end
GetGameTimer=function() return 1 end
RegisterCommand=function() end
AddEventHandler=function() end
CoreAdapter={ResolveSession=function() return {ok=true,value={sessionId='s',characterId='c'}} end,
    IsSessionCurrent=function(source,session,character) return current and source==1 and session=='s' and character=='c' end}
local database={revision=0,pools=json.encode({ammo_pistol_regular=3}),loose=2,receipts={}}
local transactions=0
local revokeAtWrite=false
local tx={}
tx.query=function(sql,args)
    if sql:find('SELECT id FROM inventory',1,true) then return {{id=1}} end
    if sql:find('SELECT revision, pools',1,true) then return {{revision=database.revision,pools=database.pools}} end
    if sql:find('SELECT result FROM',1,true) then
        local receipt=database.receipts[args[2]]; return receipt and {{result=receipt}} or {}
    end
    if sql:find('SELECT id, type',1,true) then return {{id=1,type='item_ammo',instance_mode='stack'}} end
    if sql:find('UPDATE feather_character',1,true) then
        if database.revision~=args[4] then return {affectedRows=0} end
        database.revision,database.pools=args[2],args[1]
        if revokeAtWrite then WeaponCharacterAmmoService.Revoke(1,'s') end
        return {affectedRows=1}
    end
    if sql:find('INSERT INTO feather_ammunition',1,true) then
        database.receipts[args[2]]=args[3]; return {affectedRows=1}
    end
    error(sql)
end
tx.RequireAccess=function() return nil end
tx.RemoveQuantity=function(_,_,_,amount)
    if database.loose<amount then return Result.Err('limit','insufficient') end
    database.loose=database.loose-amount; return Result.Ok({})
end
tx.AddQuantity=function(_,_,_,amount) database.loose=database.loose+amount; return Result.Ok({}) end
TransactionAPI={Transaction=function(_,body)
    transactions=transactions+1
    local before=copy(database)
    local result=body(tx)
    if not result.ok then database=before end
    return result
end}
dofile('../feather-inventory/server/services/character_ammunition.lua')
inventory.GetCharacterAmmunitionSnapshot=function(_,context,limits)
    return CharacterAmmunitionAPI.Snapshot(context,limits,'feather-weapons')
end
inventory.ObserveCharacterAmmunition=function(_,context,spec)
    return CharacterAmmunitionAPI.Observe(context,spec,'feather-weapons')
end
inventory.MutateCharacterAmmunition=function(_,context,spec)
    return CharacterAmmunitionAPI.Mutate(context,spec,'feather-weapons')
end
dofile('shared/character_ammunition.lua')
dofile('shared/character_ammunition_runtime.lua')
dofile('server/services/character_ammunition_runtime.lua')
exports['feather-weapons'].ValidateCharacterAmmoRuntimeOperation=function(_,context,operation,spec)
    return registered.ValidateCharacterAmmoRuntimeOperation(context,operation,spec)
end
local service=WeaponCharacterAmmoService
local opened=assert(service.Open(1,{ammo_pistol_regular=100}).value)
assert(service.ConfirmRestore(1,opened).ok)
local before=transactions
local forged={actorSource=1,characterId='c',sessionId='s',runtimeEpoch=opened.epoch,runtimeTicket='forged'}
assert(not CharacterAmmunitionAPI.Observe(forged,
    {expectedRevision=0,pools={ammo_pistol_regular=0},limits={ammo_pistol_regular=100}},'feather-weapons').ok)
assert(transactions==before,'forged ticket denied before SQL')
opened.pools.ammo_pistol_regular=2
local saved=assert(service.Observe(1,opened).value)
assert(saved.revision==1 and database.revision==1 and json.decode(database.pools).ammo_pistol_regular==2)
local loaded=assert(service.Transfer(1,saved,'ammo_pistol_regular',1,'load').value)
assert(loaded.phase=='restoring' and database.loose==1 and database.revision==2)
assert(not service.Observe(1,loaded).ok,'economic restore barrier')
assert(service.ConfirmRestore(1,loaded).ok)
local unloaded=assert(service.Transfer(1,loaded,'ammo_pistol_regular',-1,'unload').value)
assert(database.loose==2 and database.revision==3 and json.decode(database.pools).ammo_pistol_regular==2)
assert(service.ConfirmRestore(1,unloaded).ok)
local durable=copy(database)
revokeAtWrite=true; unloaded.pools.ammo_pistol_regular=1
assert(not service.CheckpointAndSeal(1,unloaded).ok)
assert(database.revision==durable.revision and database.pools==durable.pools and database.loose==durable.loose,
    'actual Inventory post-write ticket check rolls back revoked Weapons operation')
assert(not service.Observe(1,unloaded).ok,'revoked runtime cannot revive after rollback')
print('combined trusted authority PASS (actual Weapons service + Inventory API, forged ticket denial, shot/transfer/restore, revoke rollback; mocked CFX/SQL)')

-- Dedicated-character starting shape: canonical empty belt, no economic budget.
revokeAtWrite=false
dofile('shared/definitions/ammunition.lua')
dofile('shared/definitions/weapons.lua')
dofile('shared/character_ammunition_catalog.lua')
dofile('shared/character_ammunition_policy.lua')
local registry=assert(WeaponCharacterAmmoPolicy.Build(WeaponDefinitionCatalog))
local zero,count={},0
for id in pairs(registry.limits) do zero[id]=0; count=count+1 end
assert(count==27)
database={revision=0,pools=json.encode(zero),loose=0,receipts={}}
local baseline=assert(service.Open(1,registry.limits).value)
local readTransactions=transactions
assert(not service.ConfirmCleanup(1,baseline).ok,'cleanup cannot precede seal')
assert(service.ConfirmRestore(1,baseline).ok)
for _=1,100 do assert(service.Observe(1,baseline).ok) end
assert(transactions==readTransactions,'empty idle belt must not call Inventory')
local increased=copy(baseline); increased.pools.ammo_revolver_regular=1
assert(not service.Observe(1,increased).ok,'zero baseline cannot credit native increase')
assert(transactions==readTransactions,'increase denied before SQL')
-- An increase freezes the epoch; reopen only from unchanged authoritative SQL.
service.Revoke(1,'s')
baseline=assert(service.Open(1,registry.limits).value)
assert(service.ConfirmRestore(1,baseline).ok)
readTransactions=transactions
local final=assert(service.CheckpointAndSeal(1,baseline).value)
assert(final.phase=='sealed' and transactions==readTransactions)
assert(not service.Observe(1,baseline).ok,'sealed empty belt rejects late observations')
local cleaned=copy(final); cleaned.cleanupComplete=true; cleaned.remainingCopies=0
assert(service.ConfirmCleanup(1,cleaned).ok)
assert(database.revision==0 and database.loose==0 and next(database.receipts)==nil)
for _,amount in pairs(json.decode(database.pools)) do assert(amount==0) end
assert(transactions==readTransactions,'seal/cleanup of empty belt does not write or reread SQL')
print('combined canonical zero-belt lifecycle PASS (27 pools, 100 idle samples, increase refusal, seal/cleanup, no SQL writes; mocked CFX/SQL)')

service.Revoke(1,'s')
baseline=assert(service.Open(1,registry.limits).value)
assert(service.ConfirmRestore(1,baseline).ok)
local economicBefore=copy(database)
local economicTransactions=transactions
assert(not service.Transfer(1,baseline,'ammo_revolver_regular',-1,'empty-unload').ok)
assert(transactions==economicTransactions,'empty belt unload refused before SQL')
local refused=service.Transfer(1,baseline,'ammo_revolver_regular',1,'empty-load')
assert(not refused.ok and transactions==economicTransactions+1,'empty inventory load reaches authorized transaction but fails')
assert(database.revision==economicBefore.revision and database.pools==economicBefore.pools
    and database.loose==0 and next(database.receipts)==nil,'failed load must not create belt ammo or receipt')
assert(not service.Transfer(1,baseline,'ammo_revolver_regular',1,'empty-load').ok
    and transactions==economicTransactions+1,'failed persistence freezes epoch before repeated SQL')
service.Revoke(1,'s')
baseline=assert(service.Open(1,registry.limits).value)
assert(service.ConfirmRestore(1,baseline).ok)
assert(baseline.revision==0 and baseline.pools.ammo_revolver_regular==0,'reopen sees original zero baseline')
service.Revoke(1,'s')
print('combined empty economy refusal PASS (no unload minting, insufficient loose load rollback, no receipts, frozen retry, unchanged reopen; mocked CFX/SQL)')
