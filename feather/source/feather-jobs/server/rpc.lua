JobRoutes = {}
local Ok, Err = Jobs.Ok, Jobs.Err

-- Client-callable routes are read-only. Every mutation stays a trusted server
-- export; the character is always derived from the caller's Core session.
local routes = {
    {
        name = 'jobs.snapshot.get.v1',
        handler = function(_, source)
            if not Jobs.IsReady() then return Err('not_ready', 'Jobs is not ready.') end
            local session = exports['feather-core']:GetSessionContext(source)
            if type(session) ~= 'table' or not session.ok or type(session.value) ~= 'table'
                or not Jobs.Uuid(session.value.characterId) then
                return Err('character_required', 'An active character is required.')
            end
            local snapshot = JobEffective.Build(session.value.characterId)
            if not snapshot.ok then return snapshot end
            -- Players see their own job facts, not owner or provenance internals.
            local function Public(assignment)
                return {
                    assignmentId = assignment.assignmentId,
                    jobKey = assignment.jobKey,
                    jobLabel = assignment.jobLabel,
                    gradeKey = assignment.gradeKey,
                    gradeLabel = assignment.gradeLabel,
                    gradeOrdinal = assignment.gradeOrdinal,
                    employerType = assignment.employerType,
                    employerId = assignment.employerId,
                    dutyState = assignment.dutyState
                }
            end
            local assignments = {}
            for _, assignment in ipairs(snapshot.value.assignments) do
                assignments[#assignments + 1] = Public(assignment)
            end
            return Ok({
                activeAssignmentId = snapshot.value.activeAssignmentId,
                assignments = assignments
            })
        end,
        options = {
            contract = 1,
            direction = 'client_to_server',
            requireCharacter = true,
            windowMs = 5000,
            maxCalls = 5,
            maxPayloadBytes = 64,
            maxDepth = 2,
            maxNodes = 4,
            validatePayload = function(payload)
                return type(payload) == 'table' and next(payload) == nil,
                    'jobs.snapshot.get.v1 does not accept payload fields.'
            end
        }
    }
}

function JobRoutes.Register()
    for _, route in ipairs(routes) do
        local result = exports['feather-core']:RegisterRpc(route.name, route.handler, route.options)
        if type(result) ~= 'table' or not result.ok then
            return Err('dependency_unavailable', 'Could not register jobs RPC route.', {
                route = route.name,
                code = type(result) == 'table' and result.code or 'invalid_result'
            })
        end
    end
    return Ok(#routes)
end
