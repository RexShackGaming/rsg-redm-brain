Config = {
    Contract = 1,
    RequiredCoreContract = 1,
    ReadinessTimeoutMs = 30000,
    DevMode = true,
    Outbox = { pollIntervalMs = 1000, retryDelaySeconds = 5, batchSize = 20 },

    -- J0 decisions (see README): multiple simultaneous assignments, optional
    -- single active assignment, duty as an explicit per-assignment enum.
    Assignments = {
        maxOpenPerCharacter = 8,
        -- When false, a resource may only assign jobs whose definition it owns.
        allowForeignJobs = false
    },
    ActiveAssignment = {
        enabled = true,
        -- A character's first open assignment becomes active automatically.
        autoSelectFirst = true
    },
    Limits = { maxGradesPerJob = 32, maxListLimit = 50 },

    -- Employer references link an assignment to an entity Jobs does not own.
    -- validator = 'organizations' checks the UUID through feather-organizations;
    -- validator = false trusts the owning resource (its own society/business IDs).
    EmployerTypes = {
        organization = { validator = 'organizations' },
        society = { validator = false }
    },

    -- Service-level policy actions, evaluated through Core. Grants live in the
    -- default policy provider (feather-admin configs/service_policy.lua).
    Authorization = {
        enabled = true,
        definitionAction = 'jobs.definition.manage',
        assignmentAction = 'jobs.assignment.manage'
    },

    Access = {
        trustedReaders = { ['feather-jobs'] = true, ['feather-admin'] = true, ['feather-access'] = true, ['bcc-society'] = true,
            ['bcc-stables'] = true, ['bcc-doorlocks'] = true,
            ['bcc-craft'] = true, ['bcc-banks'] = true, ['bcc-housing'] = true },
        -- May register job definitions/grades they will own.
        trustedRegistrars = { ['feather-jobs'] = true, ['feather-admin'] = true, ['bcc-society'] = true },
        -- May change definitions owned by another resource.
        privilegedRegistrars = { ['feather-admin'] = true },
        -- May create assignments they will own and mutate them.
        trustedAssigners = { ['feather-jobs'] = true, ['feather-admin'] = true, ['bcc-society'] = true },
        -- May mutate assignments owned by another resource.
        privilegedAssigners = { ['feather-admin'] = true },
        trustedAuditors = { ['feather-jobs'] = true, ['feather-admin'] = true, ['bcc-society'] = true },
        privilegedAuditors = { ['feather-admin'] = true }
    }
}

-- Optional acceptance fixture only. Never start it or grant it trust in production.
if Config.DevMode then
    Config.Access.trustedReaders['feather-jobs-tests'] = true
    Config.Access.trustedRegistrars['feather-jobs-tests'] = true
    Config.Access.trustedAssigners['feather-jobs-tests'] = true
    Config.Access.trustedAuditors['feather-jobs-tests'] = true
end
