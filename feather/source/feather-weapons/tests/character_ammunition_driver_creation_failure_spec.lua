dofile('client/character_ammunition_driver.lua')
local state={phase='closed'}
local blocked=false
local host={Status=function() return state end,
    Receive=function() state={phase='frozen',reason='creation_changed_native_pool'}; return nil,state.reason end,
    Suspend=function(why) state.reason=why end,Tick=function() error('unexpected tick') end,
    FinalizeDeath=function() end,RecoverDeath=function() end}
local driver=assert(WeaponCharacterAmmoDriver.New(host,{
    ped=function() return 1 end,identity=function() return {characterId='c',sessionId='s'} end,
    life=function() return 'alive' end,now=function() return 0 end,block=function(value) blocked=value end,
}))
local accepted,why=driver.Receive({runtime={characterId='c',sessionId='s',epoch='e'}},true)
assert(not accepted and why=='creation_changed_native_pool')
accepted,why=driver.Step()
assert(not accepted and why=='creation_changed_native_pool' and blocked)
assert(driver.Status().fault=='creation_changed_native_pool' and state.reason=='creation_changed_native_pool')
print('native driver creation failure preservation PASS')
