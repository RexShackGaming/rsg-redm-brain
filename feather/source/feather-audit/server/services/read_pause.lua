-- Development-only one-shot pause after the transaction has completed. No lock
-- is held while the operator logs out or changes the target character's role.
FeatherAuditReadPause = {}
local armed = {}
local paused = {}

exports('IsDevelopmentReadPaused', function(actorSource, sessionId)
    return GetInvokingResource() == 'feather-admin' and Config.Development.smokeCommands == true
        and paused[actorSource] == sessionId
end)

function FeatherAuditReadPause.Await(actorSource, sessionId)
    local pause = armed[actorSource]
    armed[actorSource] = nil
    if not Config.Development.smokeCommands or not pause or pause.expires < os.time()
        or pause.sessionId ~= sessionId then return false end
    print(('[AuditReadPause] PAUSED source=%d seconds=45; change this character session or its grants now.'):format(actorSource))
    paused[actorSource] = sessionId
    Wait(45000)
    paused[actorSource] = nil
    print(('[AuditReadPause] RESUMED source=%d; rechecking session and Authority.'):format(actorSource))
    return true
end

RegisterCommand('AuditArmReadPause', function(source, args)
    if source ~= 0 or not Config.Development.smokeCommands then return end
    local actorSource = tonumber(args[1])
    if not actorSource or actorSource < 1 or actorSource % 1 ~= 0 then
        return print('[AuditArmReadPause] Use <loaded staff server ID>')
    end
    local session = exports['feather-core']:GetSessionContext(actorSource)
    if type(session) ~= 'table' or not session.ok or type(session.value) ~= 'table' then
        return print('[AuditArmReadPause] FAIL no active session')
    end
    -- Bound the arm map by the connected player population; stale entries are
    -- pruned each time an arm is requested.
    for key, value in pairs(armed) do if value.expires < os.time() then armed[key] = nil end end
    armed[actorSource] = { sessionId = session.value.sessionId, expires = os.time() + 60 }
    print(('[AuditArmReadPause] ARMED source=%d for next successful read within 60 seconds.'):format(actorSource))
end, true)
