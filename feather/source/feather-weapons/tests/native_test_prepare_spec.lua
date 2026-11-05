local commands={}
RegisterCommand=function(name,fn) commands[name]=fn end
dofile('server/services/commands.lua')
assert(commands.WeaponProvenanceInspect)
assert(commands.WeaponNativeTestPrepare==nil and commands.grantweapon==nil
 and commands.WeaponReconcile==nil and commands.WeaponIssuanceRecoveryTest==nil)
print('Native-only commands PASS (obsolete fixture/grant/reconcile/recovery commands retired)')
