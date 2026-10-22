# Ped AI, combat, relationships

## Combat attributes: `SetPedCombatAttributes(ped, id, bool)` (0x9F7794730795E019)

0 USE_COVER · 1 USE_VEHICLE · 2 DO_DRIVEBYS · 3 LEAVE_VEHICLES · 5 ALWAYS_FIGHT · 14 CAN_INVESTIGATE · 17 ALWAYS_FLEE · 21 CAN_CHASE_TARGET_ON_FOOT · 27 PERFECT_ACCURACY · 30 can shoot without LOS · 31 MAINTAIN_MIN_DISTANCE_TO_TARGET · 35 DISABLE_PINNED_DOWN · 38 DISABLE_BULLET_REACTIONS · 42 CAN_FLANK · 46 CAN_FIGHT_ARMED_PEDS_WHEN_NOT_ARMED · 50 CAN_CHARGE · 54 ALWAYS_EQUIP_BEST_WEAPON · 58 DISABLE_FLEE_FROM_COMBAT · 78 DISABLE_ALL_RANDOMS_FLEE · 81 FORCE_STRAFE · 93 PREFER_MELEE · 113 USE_INFINITE_CLIPS · 114 CAN_EXECUTE_TARGET · 116 PREFER_DUAL_WIELD · 117 WILL_CUT_FREE_HOGTIED_PEDS · 118 TRY_TO_FORCE_SURRENDER · 125 QUIT_WHEN_TARGET_FLEES_INTERACTION_FIGHT · 133 DISABLE_BLANK_SHOTS

## Combat floats: `SetCombatFloat(ped, id, value)` (0xFF41B4B141ED981C), get 0x52DFF8A10508090A

0 BlindFireChance · 1 BurstDurationInCover · 2 MaxShootingDistance · 3 TimeBetweenBurstsInCover · 4 TimeBetweenPeeks · 5 StrafeWhenMovingChance · 8 WalkWhenStrafingChance · 11 AttackWindowDistanceForCover · 12 TimeToInvalidateInjuredTarget · 13 MinimumDistanceToTarget · 14 BulletImpactDetectionRange · 16 AimTurnThreshold · 17 OptimalCoverDistance

## Flee attributes: `SetPedFleeAttributes(ped, bits, bool)` (0x70A2D1137C8ED7C9)

Bitmask. 65536 FA_FORCE_EXIT_VEHICLE · 1048576 FA_DISABLE_MOUNT_USAGE · 4194304 FA_DISABLE_ENTER_VEHICLES. Most other bits are undocumented.

## Entity proofs: `SetEntityProofs(entity, bits, 0)` (0xFAEE099C6F890BB8), get 0x6CF0DAD7FA1088EA

Bitmask, so sum the values: 1 bullet · 2 flame · 4 explosion · 8 collision · 16 melee · 32 steam · 64 smoke · 128 headshot · 256 projectile. Check a bit with `(mask & flag) ~= 0`.

## Ped config flags: `SetPedConfigFlag(ped, id, bool)` (0x1913FE4CBF41C463)

Set these once; unlike reset flags, they don't need setting every frame. Useful ones:

3 GetOutUndriveableVehicle · 6 DontInfluenceWantedLevel · 11 Knockedout · 16/17/18 DontActivateRagdollFromBullet/Explosions/Fire · 20 KeepWeaponHolsteredUnlessFired · 21 ForceControlledKnockout · 24 RunFromFiresAndExplosions · 26 DisableMelee · 43 DisableLadderClimbing · 130 DisableTalkTo · 136 CannotBeMounted · 178 AllowNonTempExceptionEvents · 254 full immunity to melee and ranged · 263 NoCriticalHits · 292 is using scenario · 297/301 Force/DisableInteractionLockonOnTargetPed · 312 DisableHorseGunshotFleeResponse · 456 ForcePedKnockOut · 560 EnableMountCoverForPedInMP

## Relationships

`SetRelationshipBetweenGroups(type, groupA, groupB)`. Types: 0 NONE · 1 RESPECT · 2 LIKE · 3 IGNORE · 4 DISLIKE · 5 WANTED · 6 HATE · 7 DEAD · 8 DISGUISE · 9 THIEF.

Common groups: `PLAYER`, `REL_CIVMALE`, `REL_CIVFEMALE`, `REL_COP`, `REL_PLAYER_ENEMY`, `REL_PLAYER_ALLY`, `REL_PLAYER_LIKE`, `REL_COMPANION_GROUP`, `REL_WILD_ANIMAL`, `REL_WILD_ANIMAL_PREDATOR`, `REL_DOMESTICATED_ANIMAL`, `REL_BOUNTY_HUNTER`, `REL_PINKERTONS`, `REL_CRIMINALS`, `REL_GANG_ODRISCOLL`, `REL_GANG_LEMOYNE_RAIDERS`, `REL_GANG_SKINNER_BROTHERS`, `REL_GANG_MURFREE_BROOD`, `REL_GUARD`, `REL_RANCHER`. Create your own with `AddRelationshipGroup` and assign with `SetPedRelationshipGroupHash`. For a scripted NPC to hold its behaviour, also call `SetBlockingOfNonTemporaryEvents(ped, true)`.
