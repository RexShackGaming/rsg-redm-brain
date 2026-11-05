-- Development-only acceptance test. MUTATES DATA: it registers a uniquely
-- provenanced smoke asset for the first character, races two transfers to the
-- second, revises metadata, transfers it back, holds it and retires it. Never
-- enable DevMode in production. Run it once per asset type: the same steps must
-- pass for horses, wagons and boats (master plan A4).
--   Usage (server console):
--   AssetsLifecycleSmokeTest <serverId|characterUuid> <otherServerId|otherCharacterUuid> [assetType]

-- Two game models per type, only to fill modelKey; the service never reads them.
local smokeModels = {
    horse = { 'A_C_Horse_Arabian_White', 'A_C_Horse_Morgan_Bay' },
    wagon = { 'wagon02x', 'cart01' },
    boat = { 'canoe', 'rowboat' }
}

local function Target(argument)
    if Assets.Uuid(argument) then
        return argument:lower()
    end
    local source = tonumber(argument)
    if not source then
        return nil
    end
    local session = exports['feather-core']:GetSessionContext(source)
    return type(session) == 'table' and session.ok and session.value.characterId or nil
end

-- Runs both transfers at once; the asset row lock must let exactly one win.
local function Race(first, second)
    local results, done = {}, 0
    for index, request in ipairs({ first, second }) do
        CreateThread(function()
            results[index] = AssetInterests.Transfer(request, GetCurrentResourceName())
            done = done + 1
        end)
    end
    while done < 2 do
        Wait(0)
    end
    return results[1], results[2]
end

Assets.RegisterDevCommand('AssetsLifecycleSmokeTest', function(source, args)
    if source ~= 0 then
        return
    end
    local called, reason = xpcall(function()
        local holderA, holderB = Target(args[1]), Target(args[2])
        local assetType = args[3] or 'horse'
        local models = smokeModels[assetType] or { 'smoke_model_a', 'smoke_model_b' }
        if not holderA or not holderB or holderA == holderB or not Config.AssetTypes[assetType] then
            print('[AssetsLifecycleSmokeTest] usage: AssetsLifecycleSmokeTest <serverId|characterUuid> <otherServerId|otherCharacterUuid> [assetType]')
            return
        end
        local owner, untrusted = GetCurrentResourceName(), 'untrusted-smoke-caller'
        local run = ('%d%04d'):format(os.time(), math.random(0, 9999))
        local reasonCode = 'assets.smoke_test'
        local function Id(step)
            return ('smoke:%s:%s'):format(run, step)
        end
        local function Register(requestId, modelKey, provenanceId, resource, metadata)
            return AssetRecords.Register({
                requestId = requestId,
                assetType = assetType,
                modelKey = modelKey,
                holderType = 'character',
                holderId = holderA,
                provenanceType = 'smoke_test',
                provenanceId = provenanceId,
                metadata = metadata,
                reasonCode = reasonCode
            }, resource)
        end

        local registered = Register(Id('register'), models[1], run, owner, { name = 'Smoke' })
        local replayed = Register(Id('register'), models[1], run, owner, { name = 'Smoke' })
        local conflicted = Register(Id('register'), models[2], run, owner, { name = 'Smoke' })
        local duplicate = Register(Id('register-again'), models[1], run, owner, { name = 'Smoke' })
        local denied = Register(Id('denied'), models[1], run .. 'x', untrusted)
        local tooDeep = Register(Id('deep'), models[1], run .. 'd', owner,
            { a = { b = { c = { d = { e = 1 } } } } })
        local assetId = registered.ok and registered.value.assetId or '00000000-0000-0000-0000-000000000000'

        local function Transfer(step, expectedRevision, extra)
            local request = {
                requestId = Id(step),
                assetId = assetId,
                expectedRevision = expectedRevision,
                toHolderType = 'character',
                toHolderId = holderB,
                reasonCode = reasonCode
            }
            for field, value in pairs(extra or {}) do
                request[field] = value
            end
            return request
        end

        local stale = AssetInterests.Transfer(Transfer('transfer-stale', 99), owner)
        local mismatch = AssetInterests.Transfer(Transfer('transfer-mismatch', 1, {
            fromHolderType = 'character',
            fromHolderId = holderB
        }), owner)
        local raceA, raceB = Race(Transfer('race-a', 1), Transfer('race-b', 1))
        local winners = (raceA.ok and 1 or 0) + (raceB.ok and 1 or 0)
        local winner, loser = raceA.ok and raceA or raceB, raceA.ok and raceB or raceA

        local checkB = AssetInterests.Check({ assetId = assetId, holderType = 'character', holderId = holderB }, owner)
        local checkA = AssetInterests.Check({ assetId = assetId, holderType = 'character', holderId = holderA }, owner)
        local listedB = AssetRecords.ListByHolder({ holderType = 'character', holderId = holderB,
            assetType = assetType }, owner)
        local listedHasAsset = false
        for _, item in ipairs(listedB.ok and listedB.value.items or {}) do
            if item.assetId == assetId then
                listedHasAsset = true
            end
        end

        local revised = AssetRecords.UpdateMetadata({ requestId = Id('metadata'), assetId = assetId,
            expectedRevision = 2, metadataVersion = 2, metadata = { name = 'Renamed', coat = 'white' },
            reasonCode = reasonCode }, owner)
        -- Back to the first owner: a new epoch, never the one the first owner had.
        local returned = AssetInterests.Transfer(Transfer('transfer-back', 3, {
            fromHolderType = 'character',
            fromHolderId = holderB,
            toHolderId = holderA
        }), owner)
        local held = AssetRecords.ChangeStatus({ requestId = Id('held'), assetId = assetId,
            expectedRevision = 4, status = 'held', reasonCode = reasonCode }, owner)
        local heldTransfer = AssetInterests.Transfer(Transfer('transfer-held', 5), owner)
        local foreign = AssetRecords.Retire({ requestId = Id('retire-foreign'), assetId = assetId,
            expectedRevision = 5, reasonCode = reasonCode }, untrusted)
        local retired = AssetRecords.Retire({ requestId = Id('retire'), assetId = assetId,
            expectedRevision = 5, reasonCode = reasonCode }, owner)
        local retiredAgain = AssetRecords.Retire({ requestId = Id('retire-again'), assetId = assetId,
            expectedRevision = 6, reasonCode = reasonCode }, owner)
        local checkAfter = AssetInterests.Check({ assetId = assetId, holderType = 'character',
            holderId = holderA }, owner)
        local lookup = Assets.FindOperation({ requestId = Id('register') }, owner)
        local history = AssetEvents.History({ assetId = assetId }, owner)

        local tests = {
            { 'register asset', registered.ok and registered.value.revision == 1
                and registered.value.assetType == assetType and registered.value.delegationEpoch == 1
                and registered.value.owner.holderId == holderA and registered.value.replayed == false },
            { 'idempotent replay', replayed.ok and replayed.value.replayed == true
                and replayed.value.assetId == assetId },
            { 'idempotency conflict', not conflicted.ok and conflicted.code == 'idempotency_conflict' },
            { 'duplicate provenance', not duplicate.ok and duplicate.code == 'asset_exists' },
            { 'untrusted manager denied', not denied.ok and denied.code == 'authorization_denied' },
            { 'metadata limits enforced', not tooDeep.ok and tooDeep.code == 'invalid_metadata' },
            { 'stale revision rejected', not stale.ok and stale.code == 'revision_conflict' },
            { 'holder mismatch rejected', not mismatch.ok and mismatch.code == 'holder_mismatch' },
            { 'concurrent sale one winner', winners == 1 and loser.code == 'revision_conflict' },
            { 'transfer advances epoch', winners == 1 and winner.value.delegationEpoch == 2 },
            { 'new owner holds interest', checkB.ok and checkB.value.matched == true
                and checkB.value.delegationEpoch == 2 },
            { 'previous owner released', checkA.ok and checkA.value.matched == false },
            { 'listed under new owner', listedHasAsset },
            { 'metadata revised', revised.ok and revised.value.metadataVersion == 2
                and revised.value.metadata.name == 'Renamed' and revised.value.revision == 3
                and revised.value.delegationEpoch == 2 },
            { 'return gets a new epoch', returned.ok and returned.value.owner.holderId == holderA
                and returned.value.revision == 4 and returned.value.delegationEpoch == 3 },
            { 'status keeps epoch', held.ok and held.value.status == 'held' and held.value.revision == 5
                and held.value.delegationEpoch == 3 },
            { 'held asset not transferable', not heldTransfer.ok and heldTransfer.code == 'asset_unavailable' },
            { 'foreign mutation denied', not foreign.ok and foreign.code == 'authorization_denied' },
            { 'asset retired', retired.ok and retired.value.status == 'retired' and retired.value.owner == nil
                and retired.value.delegationEpoch == 4 },
            { 'retire is terminal', not retiredAgain.ok and retiredAgain.code == 'asset_retired' },
            { 'retired interest ended', checkAfter.ok and checkAfter.value.matched == false
                and checkAfter.value.assetStatus == 'retired' },
            { 'operation lookup', lookup.ok and lookup.value.found == true
                and lookup.value.operation == 'asset.register' },
            { 'audit history', history.ok and #history.value.items == 6 }
        }
        local passed = 0
        for _, test in ipairs(tests) do
            if test[2] then
                passed = passed + 1
            end
            print(('[AssetsLifecycleSmokeTest] %-28s %s'):format(test[1], test[2] and 'PASS' or 'FAIL'))
        end
        print(('[AssetsLifecycleSmokeTest] done %d/%d passed (MUTATING: %s asset %s)'):format(
            passed, #tests, assetType, assetId))

        local function Explain(step, result)
            if result.ok then
                return
            end
            local details = type(result.details) == 'table' and result.details or {}
            print(('[AssetsLifecycleSmokeTest] %s failed code=%s policyCode=%s provider=%s reason=%s'):format(
                step, tostring(result.code), tostring(details.policyCode), tostring(details.provider),
                tostring(details.policyReason or result.message)))
        end
        Explain('register', registered)
        if winners == 0 then
            Explain('transfer', raceA)
        end
    end, debug.traceback)
    if not called then
        print('[AssetsLifecycleSmokeTest] FAIL ' .. tostring(reason))
    end
end, true)
