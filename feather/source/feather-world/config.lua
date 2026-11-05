Config = {
    -- Enables diagnostic logging and development-only commands. Keep disabled on production servers.
    DevMode = false,

    PlayerRuntime = {
        -- Removes Rockstar challenge notifications that are not used by Feather gameplay.
        clearChallengeFeed = true,

        -- Prevents weapon-wheel and interaction controls known to leave the player in a stuck input state.
        disableWeaponSoftlockControls = true,

        -- Disables Rockstar HUD shortcuts that conflict with Feather-owned interfaces.
        disableFrameworkHudControls = true,

        -- Hides ambient corpse and saddlebag loot prompts. Inventory resources can still provide their own prompts.
        suppressRandomLootPrompts = true
    },

    Map = {
        -- RedM route color used by the StartGpsRoute client export.
        gpsRouteColor = 6
    },

    InteriorFix = {
        -- Applies Feather's curated interior entity sets and deterministic IMAP states.
        enabled = true,

        -- Small delay before entity-set activation. IMAP states are applied immediately.
        startupDelayMs = 1,

        -- Catalog integrity values. Server owners should not edit these unless the catalog itself changes.
        expectedInteriorDefinitions = 35,
        expectedInteriorMetadata = 35,
        expectedEntitySets = 494,
        expectedImapOperations = 400,
        expectedImapDescriptions = 217
    },

    WagonFix = {
        -- Removes ambient wagons whose body is stopped while a harness horse continues walking.
        enabled = true,

        -- Detection frequency. Higher values reduce scanning frequency.
        checkIntervalMs = 1000,

        -- Frequency for removing detached known wagon components.
        orphanCheckIntervalMs = 5000,

        -- Removes allowlisted wagon components that are no longer attached to or near a vehicle.
        removeOrphanedComponents = true,

        -- Maximum distance from a wagon for a known component to be considered associated with it.
        componentDistance = 3.0,

        -- Maximum distance used when locating NPC occupants attached to a stuck wagon.
        occupantDistance = 5.0,

        networkControl = {
            -- Bounded control requests prevent deletion attempts from waiting forever.
            maxAttempts = 50,
            waitMs = 10
        },

        -- Object models known to detach from affected wagons. Add only verified wagon components.
        components = {
            's_wagonprison_lock',
            's_coachlock02x',
            'p_wagonprison_lock01x',
            'p_wagonprison_chain01x'
        }
    },

    -- Density values are enforced every rendered frame. Use 0.0 to suppress a category and 1.0 for game defaults.
    DensityMultipliers = {
        ambientPeds = 1.0,
        scenarioPeds = 1.0,
        vehicles = 1.0,
        parkedVehicles = 1.0,
        randomVehicles = 1.0,
        ambientAnimals = 1.0,
        ambientHumans = 1.0,
        scenarioAnimals = 1.0,
        scenarioHumans = 1.0
    }
}
