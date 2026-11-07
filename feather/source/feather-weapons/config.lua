Config = {
    NativeAlphaRuntime = true, -- required native-only host; canonical ownership/session gates still apply
    NativeAlphaRepairEnabled = false, -- scoped console/Equipment-menu repair; canonical material, opt in only
    NativeAlphaMaintenanceEnabled = false, -- scoped wear checkpoint; no ammo/material economic writes
    NativeAlphaPeriodicWearEnabled = false, -- idle scoped sampler; changed wear uses sealed checkpoint
    NativeAlphaPeriodicWearIntervalMs = 60000, -- one equipped copy per interval; round-robin up to four
    NativeAlphaLifecycleWearEnabled = false, -- final wear on equipment/stop/logout/death; opt in
    -- All current player characters have access; no character allowlist is needed.
    CharacterAmmunitionEnabled = true, -- required canonical character ammunition integration
    CharacterAmmoTransportEnabled = true, -- required checkpoint transport; no automatic item/ammo grants
    DevMode = false, -- diagnostics, fixture issuance and fault tests only; gameplay does not require this
    RequiredCoreContract = 1,
    RequiredCharacterContract = 1,
    CharacterReadyTimeoutMs = 30000,
    Inventory = {
        requiredContract = 4,
        -- Stable Inventory equipment keys. Do not rename these after launch.
        equipmentSlot = "weapon", -- Legacy alias for the primary slot.
        equipmentSlots = {
            utility = "weapon_utility",
            utility_secondary = "weapon_utility_secondary",
            utility_tertiary = "weapon_utility_tertiary",
            utility_quaternary = "weapon_utility_quaternary",
            utility_quinary = "weapon_utility_quinary",
            utility_senary = "weapon_utility_senary",
            utility_septenary = "weapon_utility_septenary",
            utility_octonary = "weapon_utility_octonary",
            primary = "weapon",
            offhand = "weapon_offhand",
            shoulder = "weapon_shoulder",
            back = "weapon_back",
            melee = "weapon_melee",
            melee_secondary = "weapon_melee_secondary",
            melee_tertiary = "weapon_melee_tertiary",
            melee_quaternary = "weapon_melee_quaternary",
            melee_quinary = "weapon_melee_quinary",
            throwable = "weapon_throwable",
            throwable_secondary = "weapon_throwable_secondary",
            throwable_tertiary = "weapon_throwable_tertiary",
            throwable_quaternary = "weapon_throwable_quaternary",
            throwable_quinary = "weapon_throwable_quinary",
            throwable_senary = "weapon_throwable_senary",
            throwable_septenary = "weapon_throwable_septenary",
            throwable_octonary = "weapon_throwable_octonary",
            throwable_nonary = "weapon_throwable_nonary",
            throwable_denary = "weapon_throwable_denary"
        }
    },
    AmmunitionPools = {
        -- Experimental scoped gates; not broad catalog opt-in.
        enabled = true,
        weapons = { revolver_cattleman = true, revolver_schofield = true,
            repeater_carbine = true, repeater_lancaster = true,
            pistol_m1899 = true, pistol_volcanic = true,
            pistol_semiauto = true }
    },
    Runtime = {
        authorizationTtlMs = 5000,
        authoritativeNativeAmmo = true,
        observationIntervalMs = 50,
        checkpointDebounceMs = 250,
        maintenanceCheckpointMs = 5000,
        -- Character normally signals when the player ped is ready. This
        -- bounded fallback restores the loadout if that one-time signal is
        -- missed, without applying the same loadout twice.
        characterRestoreFallbackMs = 6000,
        characterRestoreRetryMs = 2000,
        characterRestoreMaxAttempts = 3
    },
    Escrow = {
        -- Maximum cartridges authorized across every equipped weapon sharing
        -- an ammunition type. Feather keeps reserve virtual when two different
        -- long-gun hashes share that type; RedM sees only their loaded clips.
        -- Ammunition definitions may impose a smaller native-pool maximum.
        maxTotal = 200,
        -- Cartridges moved by one Inventory ammunition use.
        -- Match one standard Inventory ammunition stack per load action.
        refillAmount = 50
    },
    Offhand = {
        -- Disable to run this server in primary-weapon-only mode.
        enabled = true,
        -- Only definition families/slots set to true may use the offhand.
        allowedFamilies = { revolver = true, pistol = true },
        allowedWeaponSlots = { sidearm = true },
        -- Automatically provide RedM's offhand holster entitlement when needed.
        provisionNativeEntitlement = true,
        -- RedM requires both an offhand clothing entitlement and its upgrade.
        -- Tested tint variants did not visibly restyle the equipped holster.
        nativeEntitlements = {
            mp_male = {
                { itemName = "CLOTHING_ITEM_M_OFFHAND_000_TINT_004", slotId = 0xF20B6B4A },
                { itemName = "UPGRADE_OFFHAND_HOLSTER", slotId = 0x39E57B01 }
            },
            mp_female = {
                { itemName = "CLOTHING_ITEM_F_OFFHAND_000_TINT_004", slotId = 0xF20B6B4A },
                { itemName = "UPGRADE_OFFHAND_HOLSTER", slotId = 0x39E57B01 }
            }
        },
        -- Native holster points; change only for a tested clothing setup.
        primaryAttachPoint = 2,
        offhandAttachPoint = 3
    },
    Loadout = {
        -- Four independent persistent positions: two sidearms and two long guns.
        -- Inventory uses these names when a weapon is equipped without an
        -- explicit slot; definitions marked sidearm fill primary/offhand and
        -- definitions marked longgun fill shoulder/back.
        utilitySlots = { "utility", "utility_secondary", "utility_tertiary", "utility_quaternary", "utility_quinary", "utility_senary","utility_septenary", "utility_octonary" },
        sidearmSlots = { "primary", "offhand" },
        longgunSlots = { "shoulder", "back" },
        meleeSlots = { "melee", "melee_secondary", "melee_tertiary", "melee_quaternary", "melee_quinary" },
        throwableSlots = { "throwable", "throwable_secondary", "throwable_tertiary", "throwable_quaternary", "throwable_quinary", "throwable_senary", "throwable_septenary", "throwable_octonary", "throwable_nonary", "throwable_denary" },
        -- RedM's two weapon-wheel long-gun positions. These are the native
        -- RIFLE and RIFLE_ALTERNATE attach points, not cosmetic body bones.
        -- In-game layout: point 10 is the shoulder carry and point 9 is the
        -- back carry. Keep the logical slot names aligned with that layout.
        shoulderAttachPoint = 10,
        backAttachPoint = 9
    },
    NativeProbe = {
        -- Isolated Phase 1 diagnostic. Enable only on a development server.
        enabled = false,
        weapon = "WEAPON_REVOLVER_CATTLEMAN",
        -- Second native used only by the Phase 7 offhand/dual-wield probe.
        offhandWeapon = "WEAPON_REVOLVER_SCHOFIELD",
        ammo = "AMMO_REVOLVER",
        capacity = 6,
        primaryAttachPoint = 2,
        offhandAttachPoint = 3,
        observationIntervalMs = 50
    },
    Attachments = {
        requireStation = true,
        interactionDistance = 2.0,
        serverTolerance = 3.0,
        authorization = {
            enabled = false,
            action = "weapons.attachments.modify"
        },
        stations = {
            valentine = {
                label = "Valentine Gunsmith Bench",
                coords = vector3(-277.455, 779.197, 119.504)
            }
        }
    },
    Ownership = {
        trustedResources = {
            ["feather-admin"] = true,
            ["feather-weapons"] = true
        },
        authorization = {
            enabled = false,
            destroyAction = "weapons.ownership.destroy",
            holdAction = "weapons.evidence.hold",
            releaseAction = "weapons.evidence.release"
        }
    },
    Provenance = {
        -- Zero retains audit events indefinitely. Any future purge workflow
        -- must be an explicit server-owner operation, never an automatic side effect.
        retentionDays = 0,
        maxInspectionEvents = 100
    },
    Issuance = {
        trustedResources = { ["feather-weapons"] = true, ["feather-admin"] = true },
        allowedPurposes = {
            development_grant = true, admin_issue = true, purchase = true,
            crafting = true, job_issue = true, recovery = true
        },
        authorization = { enabled = false, action = "weapons.issuance.issue" }
    },
    Controls = {
        unload = {
            enabled = true,
            defaultKey = "U",
            command = "feather_weapon_unload"
        },
        modify = {
            enabled = true,
            defaultKey = "F6",
            command = "weaponmods"
        },
        ammunition = {
            enabled = true,
            defaultKey = "F7",
            command = "weaponammo"
        }
    }
}
