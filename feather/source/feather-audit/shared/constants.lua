FeatherAuditConstants = {
    resourceName = 'feather-audit',
    contractVersion = 1,
    results = {
        accepted = 'accepted',
        duplicate = 'duplicate',
        retryableRejection = 'retryable_rejection',
        quarantined = 'quarantined'
    },
    sensitivityClasses = {
        public = true,
        internal = true,
        restricted = true,
        sealed = true
    },
    retentionClasses = {
        operational = true,
        administrative = true,
        security = true,
        financial = true,
        legal = true
    },
    eventResults = {
        success = true,
        failed = true,
        denied = true,
        cancelled = true
    },
    limits = {
        eventBytes = 32 * 1024,
        contextBytes = 16 * 1024,
        summaryBytes = 256,
        keyBytes = 128,
        displayNameBytes = 128,
        identifierBytes = 128,
        targets = 16,
        references = 16,
        contextKeys = 64,
        contextDepth = 4,
        contextArrayItems = 32,
        futureWarningSeconds = 5 * 60,
        futureHardLimitSeconds = 24 * 60 * 60
    },
    lifecycle = {
        scaffold = 'scaffold',
        starting = 'starting',
        ready = 'ready',
        degraded = 'degraded',
        unavailable = 'unavailable'
    }
}
