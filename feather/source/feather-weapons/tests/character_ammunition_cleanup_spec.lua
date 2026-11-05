dofile('shared/character_ammunition.lua'); dofile('shared/character_ammunition_runtime.lua')
local runtime=WeaponCharacterAmmoRuntime.New(function() return true end)
local value=assert(runtime.Open({source=1,characterId='c',sessionId='s'},
    {characterId='c',revision=0,pools={regular=8}},{regular=200},'e'))
local report={characterId='c',sessionId='s',epoch='e',revision=0,pools={regular=8},cleanupComplete=true,remainingCopies=0}
assert(not runtime.ConfirmCleanup(1,report),'restoring cannot release')
assert(runtime.ConfirmRestore(1,report)); assert(not runtime.ConfirmCleanup(1,report),'active cannot release')
assert(runtime.PrepareFinalObservation(1,report).value.phase=='sealed')
report.remainingCopies=1; assert(not runtime.ConfirmCleanup(1,report)); report.remainingCopies=0
report.pools.regular=7; assert(not runtime.ConfirmCleanup(1,report)); report.pools.regular=8
report.epoch='old'; assert(not runtime.ConfirmCleanup(1,report)); report.epoch='e'
assert(runtime.ConfirmCleanup(1,report).phase=='released')
assert(runtime.ConfirmCleanup(1,report).phase=='released','duplicate exact cleanup is harmless')
assert(not runtime.PrepareObservation(1,report))
assert(runtime.Open({source=1,characterId='c',sessionId='s'},
    {characterId='c',revision=0,pools={regular=8}},{regular=200},'next'))
assert(not runtime.ConfirmCleanup(1,report),'old release ack cannot close new epoch')
print('character_ammunition_cleanup_spec PASS (seal, zero copies, exact belt, stale epoch, idempotent release)')
