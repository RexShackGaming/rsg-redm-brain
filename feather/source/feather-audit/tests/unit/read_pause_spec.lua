local Assert = _G.TestAssert
local commands, waits = {}, 0
local exported = {}
local oldPrint = print
print = function() end
RegisterCommand = function(name, callback) commands[name] = callback end
Wait = function(milliseconds)
    Assert.equal(45000, milliseconds)
    waits = waits + 1
    Assert.truthy(exported.IsDevelopmentReadPaused(1, 'original-session'))
    Assert.falsy(exported.IsDevelopmentReadPaused(1, 'different-session'))
end
exports = { ['feather-core'] = { GetSessionContext = function()
    return { ok = true, value = { sessionId = 'original-session' } }
end } }
setmetatable(exports, { __call = function(_, name, fn) exported[name] = fn end })
GetInvokingResource = function() return 'feather-admin' end
Config.Development.smokeCommands = true
dofile('server/services/read_pause.lua')
commands.AuditArmReadPause(0, { '1' })
Assert.truthy(FeatherAuditReadPause.Await(1, 'original-session'))
Assert.equal(1, waits)
Assert.falsy(exported.IsDevelopmentReadPaused(1, 'original-session'))
Assert.falsy(FeatherAuditReadPause.Await(1, 'original-session'))
Assert.equal(1, waits, 'pause is one-shot')
commands.AuditArmReadPause(0, { '1' })
Assert.falsy(FeatherAuditReadPause.Await(1, 'different-session'))
Assert.equal(1, waits, 'new session cannot inherit an armed pause')
commands.AuditArmReadPause(0, { '1' })
Config.Development.smokeCommands = false
Assert.falsy(FeatherAuditReadPause.Await(1, 'original-session'))
Assert.equal(1, waits, 'production mode must never pause reads')
Config.Development.smokeCommands = true
print = oldPrint
