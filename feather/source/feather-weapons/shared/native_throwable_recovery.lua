-- Pure recovery evidence/planning. No independent exports, routes or writes.
-- A durable ammo decrease is NOT proof of projectile origin: it might be a
-- native reset rather than a throw. Exact-origin binding and the separately
-- named original-style bounded native-pool policy remain distinct. No SQL here.
WeaponNativeThrowableRecovery={}
local equal
local function copy(v)
    if type(v)~='table' then return v end
    local r={}; for k,x in pairs(v) do r[k]=copy(x) end; return r
end
local function integer(v,min) return type(v)=='number' and v>=min and v<math.huge and v%1==0 end
local function bounded(v) return type(v)=='string' and #v>0 and #v<=128 and not v:find('%c') end
-- Alternative to exact-world-projectile recovery: the original bounded native
-- pool policy. This is a SERVER transaction planner, not an RPC validator or
-- proof of which world object was picked up. `credit` must be read/locked from
-- durable server records; never construct it from a client recovery request.
-- The separate server reservation and default-off gate control admission.
function WeaponNativeThrowableRecovery.NativePickupPlan(credit,current,snapshot,report,catalog,limits)
    if type(credit)~='table' or credit.policy~='same_session_native_spend_credit_v1'
        or credit.phase~='committed_unclaimed' or not bounded(credit.receiptId) then
        return nil,'native_pickup_committed_credit_required'
    end
    local spend,why=WeaponNativeThrowableRecovery.SpendCandidate(credit.before,credit.after,
        credit.snapshot,catalog,limits)
    if not spend then return nil,why end
    if type(current)~='table' or current.phase~='active' or not integer(current.revision,0)
        or current.revision<credit.after.revision or type(report)~='table'
        or report.phase~='active' or report.revision~=current.revision then
        return nil,'native_pickup_current_revision_required'
    end
    for _,name in ipairs({'characterId','sessionId','epoch'}) do
        if current[name]~=spend.identity[name] or report[name]~=current[name] then
            return nil,'native_pickup_same_epoch_required'
        end
    end
    local assigned; assigned,why=WeaponNativeThrowableItem.Assigned(snapshot,catalog,spend.identity,limits)
    if not assigned then return nil,why end
    if assigned.row.id~=spend.itemId or assigned.row.revision~=spend.itemRevision
        or assigned.row.metadata.serialNumber~=spend.serialNumber
        or snapshot.revision~=current.revision or not equal(snapshot.pools,current.pools) then
        return nil,'native_pickup_carrier_or_snapshot_changed'
    end
    local pools=WeaponCharacterAmmunition.Validate(current.pools,limits)
    local observed=WeaponCharacterAmmunition.Validate(report.pools,limits)
    if not pools or not observed or pools.ammo_tomahawk_regular~=0
        or observed.ammo_tomahawk_regular~=1 then return nil,'native_pickup_one_unit_increase_required' end
    for id in pairs(limits) do
        if current.pools[id]==nil or report.pools[id]==nil then return nil,'native_pickup_full_pools_required' end
        if id~='ammo_tomahawk_regular' and pools[id]~=observed[id] then
            return nil,'native_pickup_other_pool_changed'
        end
    end
    pools.ammo_tomahawk_regular=1
    return {version=1,kind='native_pickup_ledger_plan',policy=credit.policy,
        spendReceiptId=credit.receiptId,spendKey=copy(spend.key),identity=copy(spend.identity),
        itemId=spend.itemId,itemRevision=spend.itemRevision,serialNumber=spend.serialNumber,
        expectedRevision=current.revision,revision=current.revision+1,pools=pools,units=1,
        requiresAtomicSpendClaim=true,requiresLedgerCAS=true,looseInventoryDelta=0,
        nativeAmmoDelta=0,originConfirmed=false,pickupCredits=false}
end
-- Data-only join of TWO independently obtained server records. `observed` must
-- be issued by a trusted projectile observer with a server lifetime ID and an
-- authenticated originating throw; these fields are NOT client attestations.
-- No such live observer is wired yet. A model/net ID/proximity alone never
-- authorizes this plan, and this plan itself is NOT a claim or credit receipt.
function WeaponNativeThrowableRecovery.BindingPlan(candidate,durable,observed)
    if type(candidate)~='table' or candidate.version~=1 or candidate.kind~='unbound_spend_candidate'
        or candidate.units~=1 or candidate.pickupCredits~=false or candidate.requiresProjectileBinding~=true
        or candidate.requiresDurableSingleClaim~=true or candidate.definitionId~='throwable_tomahawk'
        or not integer(candidate.itemId,1) or not integer(candidate.itemRevision,0) or not bounded(candidate.serialNumber)
        or type(candidate.identity)~='table' or type(candidate.key)~='table' then return nil,'invalid_throwable_spend_candidate' end
    local identity,key=candidate.identity,candidate.key
    for _,name in ipairs({'characterId','sessionId','epoch'}) do
        if not bounded(identity[name]) or key[name]~=identity[name] then return nil,'throwable_binding_identity_required' end
    end
    if key.ammunitionId~='ammo_tomahawk_regular' or not integer(key.revisionBefore,0)
        or key.revisionAfter~=key.revisionBefore+1 then return nil,'throwable_binding_spend_key_required' end
    if type(durable)~='table' or durable.phase~='committed_unclaimed' or not bounded(durable.receiptId)
        or not equal(durable.candidate,candidate) or not integer(durable.windowStartMs,0)
        or not integer(durable.windowEndMs,0) or durable.windowEndMs<durable.windowStartMs
        or durable.windowEndMs-durable.windowStartMs>10000 then return nil,'throwable_durable_spend_required' end
    if type(observed)~='table' or observed.phase~='observed_unclaimed' or not bounded(observed.instanceId)
        or not bounded(observed.originEventId) or not integer(observed.networkId,1)
        or observed.model~='WEAPON_THROWN_TOMAHAWK' or not integer(observed.spawnedAtMs,0)
        or observed.spawnedAtMs<durable.windowStartMs or observed.spawnedAtMs>durable.windowEndMs
        or type(observed.origin)~='table' then return nil,'throwable_projectile_origin_required' end
    local origin=observed.origin
    if not equal(origin.identity,identity) or origin.itemId~=candidate.itemId
        or origin.itemRevision~=candidate.itemRevision or origin.serialNumber~=candidate.serialNumber
        or origin.ammunitionId~='ammo_tomahawk_regular' or origin.units~=1 then
        return nil,'throwable_projectile_origin_mismatch'
    end
    return {version=1,kind='projectile_binding_plan',spendKey=copy(key),spendReceiptId=durable.receiptId,
        projectileInstanceId=observed.instanceId,originEventId=observed.originEventId,
        networkId=observed.networkId,identity=copy(identity),itemId=candidate.itemId,
        itemRevision=candidate.itemRevision,serialNumber=candidate.serialNumber,units=1,
        pickupCredits=false,requiresAtomicSingleClaim=true,requiresCurrentProjectile=true,
        requiresPickupProximity=true}
end
equal=function(a,b)
    if type(a)~=type(b) then return false end
    if type(a)~='table' then return a==b end
    for k,v in pairs(a) do if not equal(v,b[k]) then return false end end
    for k in pairs(b) do if a[k]==nil then return false end end; return true
end
-- Inputs must come from the server's confirmed observation commit and its
-- pre-commit lease approval, never from a client-supplied pickup report.
function WeaponNativeThrowableRecovery.SpendCandidate(before,after,snapshot,catalog,limits)
    if type(before)~='table' or type(after)~='table' or before.phase~='active' or after.phase~='active'
        or type(before.pools)~='table' or type(after.pools)~='table' or type(limits)~='table'
        or limits.ammo_tomahawk_regular~=1 then return nil,'throwable_spend_active_observation_required' end
    local identity={characterId=before.characterId,sessionId=before.sessionId,epoch=before.epoch}
    for _,key in ipairs({'characterId','sessionId','epoch'}) do
        if type(identity[key])~='string' or #identity[key]<1 or #identity[key]>128
            or identity[key]:find('%c') or after[key]~=identity[key] then return nil,'throwable_spend_identity_changed' end
    end
    for id in pairs(limits) do
        if before.pools[id]==nil or after.pools[id]==nil then return nil,'throwable_spend_full_pools_required' end
    end
    local assigned,why=WeaponNativeThrowableItem.Assigned(snapshot,catalog,identity,limits)
    if not assigned then return nil,why or 'throwable_spend_carrier_required' end
    if assigned.ledgerRevision~=before.revision or not equal(snapshot.pools,before.pools)
        or before.pools.ammo_tomahawk_regular~=1 or after.pools.ammo_tomahawk_regular~=0 then
        return nil,'throwable_spend_funded_decrease_required'
    end
    local report=copy(after); report.revision=before.revision
    local expected=WeaponCharacterAmmunition.Observe(before,report,limits)
    if not expected or expected.revision~=after.revision or not equal(expected.pools,after.pools) then
        return nil,'throwable_spend_unconfirmed_revision'
    end
    -- Structured unique key must eventually be constrained durably by the
    -- recovery transaction. Never use caller-selected request IDs for deduping
    -- the same spent unit, nor treat this ephemeral candidate as a receipt.
    return {version=1,kind='unbound_spend_candidate',identity=copy(identity),
        key={characterId=identity.characterId,sessionId=identity.sessionId,epoch=identity.epoch,
            revisionBefore=before.revision,revisionAfter=after.revision,ammunitionId='ammo_tomahawk_regular'},
        itemId=assigned.row.id,itemRevision=assigned.row.revision,serialNumber=assigned.row.metadata.serialNumber,
        definitionId='throwable_tomahawk',units=1,pickupCredits=false,requiresProjectileBinding=true,
        requiresDurableSingleClaim=true}
end
