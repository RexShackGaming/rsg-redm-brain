local count = 0
local function check(label, good) assert(good, label); count = count + 1; print('PASS ' .. label) end
local target = {sessionId = 'target-session', characterId = string.rep('t', 36)}
local actor = {sessionId = 'actor-session', characterId = string.rep('a', 36)}
local ready, allow, policyFails = true, true, false
local callbacks = {}
exports = setmetatable({
    ['feather-core'] = {
        IsSessionCurrent = function(_, source, session, character)
            local expected = source == 1 and target or source == 2 and actor
            return expected and expected.sessionId == session and expected.characterId == character or false
        end,
        GetSessionContext = function(_, source)
            local value = source == 1 and target or source == 2 and actor
            return value and {ok = true, value = value} or {ok = false}
        end,
        Authorize = function() if policyFails then error('policy unavailable') end; return {ok = true, value = {allowed = allow}} end
    },
    ['feather-character'] = {
        GetMedicalReadySession = function() return {ok = ready, value = target} end,
        GetMedicalRecoveryDestination = function() return {ok = true, value = {id = 'valentine', x = 1, y = 2, z = 3}} end
    },
    ['feather-admin'] = {CanMedicalRevive = function() return true end}
}, {__call = function(_, name, fn) callbacks[name] = fn end})
AddEventHandler = function() end
RegisterCommand = function() end
local caller = 'foreign-resource'
GetInvokingResource = function() return caller end
local ids = 0
DB = {value = function() ids = ids + 1; return ('%036d'):format(ids) end}
Config = {medical = {enabled = true, persistentDeath = false, temporarySpawnEnabled = true}, hospitals = {}}
local resets, initialized, completions, begun = 0, 0, 0, 0
local record = {characterId = target.characterId, lifeState = 'dead', episodeId = 'episode', revision = 1}
local history, missing = false, false
local hasPending = true
local lastDestination
MedicalRepository = {
    Get = function() return not missing and record or nil end,
    HasHistory = function() return history end,
    Initialize = function() initialized = initialized + 1; missing = false; return record end,
    Advance = function() return record end,
    ResetOnActivation = function() resets = resets + 1; return record end,
    BeginStaffRecovery = function(_, _, _, _, guard) assert(guard()); begun = begun + 1; return {ok = true, value = {operationId = 'op'}} end,
    BeginRecovery = function(_, _, _, _, guard, kind, destination)
        assert(guard() and kind == 'doctor'); lastDestination = destination
        return {ok = true, value = {operationId = 'op'}}
    end,
    PendingRecovery = function() if hasPending then return {operation_id = 'op', episode_id = 'episode', recovery_kind = 'staff'} end end,
    CompleteStaffRecovery = function(_, _, _, _, guard)
        assert(guard()); completions = completions + 1; return {ok = true, value = record}
    end
}
dofile('server/hospitals.lua')
dofile('server/gameplay.lua')
local G = MedicalGameplay
G.Ready = function() return true end
check('default nonpersistent activation requests explicit reset', G.Prepare(target.characterId).ok and resets == 1)
Config.medical.persistentDeath = true
check('persistent activation preserves episode', G.Prepare(target.characterId).ok and resets == 1)
missing, history = true, true
check('missing condition with history never provisions alive', G.Prepare(target.characterId).code == 'condition_missing' and initialized == 0)
history = false
check('first enrollment provisions through owning repository', G.Prepare(target.characterId).ok and initialized == 1)
check('foreign provisioning export denied', callbacks.PrepareCharacter(target.characterId).code == 'forbidden')
check('foreign staff recovery export denied', callbacks.RequestStaffRecovery(2, 1).code == 'forbidden')
caller = 'feather-character'
check('Cfx numeric string source can provision', callbacks.PrepareCharacter(target.characterId, '1', target.sessionId).ok)
check('fractional source is rejected', callbacks.PrepareCharacter(target.characterId, '1.5', target.sessionId).code == 'session_required')
caller = 'foreign-resource'
ready = false
check('world readiness required for mutation', G.RequestStaff(2, 1).code == 'target_not_ready')
ready, allow = true, false
check('policy denial creates no operation', G.RequestStaff(2, 1).code == 'forbidden' and begun == 0)
allow, policyFails = true, true
check('policy provider failure cannot create recovery', not pcall(G.RequestStaff, 2, 1) and begun == 0)
policyFails = false
check('staff permission accepted', G.RequestStaff(2, 1).ok and begun == 1)
check('Cfx numeric string staff source is normalized', G.RequestStaff('2', '1').ok and begun == 2)
check('ack requires current-session delivery', G.Acknowledge(1, target, 'op').code == 'stale_delivery' and completions == 0)
local firstDelivery = G.Pending(1, target).value
check('pending operation rebinds delivery to current session', firstDelivery.operationId == 'op')
check('same session retains delivery token', G.Pending(1, target).value.deliveryToken == firstDelivery.deliveryToken)
check('different operation ack denied', G.Acknowledge(1, target, 'other').code == 'stale_delivery')
check('incorrect delivery token cannot complete', G.Acknowledge(1, target, 'op', 'forged').code == 'stale_delivery')
check('delivered operation may be acknowledged', G.Acknowledge(1, target, 'op', firstDelivery.deliveryToken).ok and completions == 1)
local old = {sessionId = target.sessionId, characterId = target.characterId}
target = {sessionId = 'new-session', characterId = target.characterId}
check('old session acknowledgement denied', G.Acknowledge(1, old, 'op').code == 'stale_delivery' and completions == 1)
check('new session cannot ack old delivery before redelivery', G.Acknowledge(1, target, 'op', firstDelivery.deliveryToken).code == 'stale_delivery')
local redelivery = G.Pending(1, target).value
check('new session gets a different delivery token', redelivery.deliveryToken ~= firstDelivery.deliveryToken)
check('old token rejected after redelivery', G.Acknowledge(1, target, 'op', firstDelivery.deliveryToken).code == 'stale_delivery')
hasPending = false
check('doctor destination comes from Character', G.RequestDoctor(1, target).ok and lastDestination.id == 'valentine')
Config.medical.temporarySpawnEnabled = false
check('empty hospitals with fallback disabled fail closed', G.RequestDoctor(1, target).code == 'hospital_unavailable')
hasPending = true
check('existing operation resumes even after destination config changes', G.RequestDoctor(1, target).value.operationId == 'op')
hasPending = false
Config.hospitals = {
    {id = 'near', label = 'Near', x = 9, y = 0, z = 0, heading = 0},
    {id = 'far', label = 'Far', x = 100, y = 0, z = 0, heading = 0}
}
GetPlayerPed = function(source) assert(source == 1); return 42 end
DoesEntityExist = function() return 1 end
GetEntityCoords = function() return {x = 10, y = 0, z = 0} end
check('nearest hospital uses server ped position', G.RequestDoctor(1, target).ok and lastDestination.id == 'near')
GetPlayerPed = function() return 0 end
check('missing server ped cannot select a hospital', G.RequestDoctor(1, target).code == 'position_unavailable')
caller='foreign-resource'
check('weapon condition reader rejects foreign caller',callbacks.ReadNativeWeaponCondition(1,target).code=='forbidden')
caller='feather-weapons'; ready=true; missing=false
local beforeReads={initialized,resets,completions,begun}
local condition=callbacks.ReadNativeWeaponCondition(1,target)
check('weapon condition reader returns current stored condition',condition.ok and condition.value.revision==record.revision
    and condition.value.lifeState==record.lifeState and condition.value.sessionId==target.sessionId)
check('weapon condition reader has no lifecycle writes',initialized==beforeReads[1] and resets==beforeReads[2]
    and completions==beforeReads[3] and begun==beforeReads[4])
check('weapon condition reader rejects stale session',callbacks.ReadNativeWeaponCondition(1,old).code=='stale_session')
local get=MedicalRepository.Get
MedicalRepository.Get=function(...) local value=get(...); ready=false; return value end
check('weapon condition reader rechecks after storage yield',callbacks.ReadNativeWeaponCondition(1,target).code=='stale_session')
MedicalRepository.Get=get; ready=true
check('weapon condition reader rejects malformed context',callbacks.ReadNativeWeaponCondition(1,{}).code=='forbidden')
check('weapon condition reader rejects invalid source',callbacks.ReadNativeWeaponCondition(0,target).code=='forbidden')
missing=true
check('weapon condition reader never initializes missing condition',callbacks.ReadNativeWeaponCondition(1,target).code=='condition_missing'
    and initialized==beforeReads[1])
missing=false
MedicalRepository.Get=function() error('storage offline') end
check('weapon condition reader reports storage failure',callbacks.ReadNativeWeaponCondition(1,target).code=='storage_unavailable')
MedicalRepository.Get=get
Config.medical.enabled=false
check('weapon condition reader rejects disabled Medical',callbacks.ReadNativeWeaponCondition(1,target).code=='stale_session')
Config.medical.enabled=true
print(('PASS %d gameplay service harness checks'):format(count))
