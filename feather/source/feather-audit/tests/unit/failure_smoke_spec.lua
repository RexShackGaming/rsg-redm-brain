local Assert = _G.TestAssert
local commands, output = {}, {}
local savedPrint, savedConfig = print, Config
dofile('config.lua')
Config.Development.smokeCommands = true
dofile('server/ingestion/rate_limit.lua')
RegisterCommand = function(name, callback) commands[name] = callback end
GetGameTimer = function() return 12345 end
print = function(line) output[#output + 1] = line end
dofile('server/services/smoke.lua')
local originalInstance = Config.SourceInstance
commands.AuditFailureBoundarySmokeTest(0)
Assert.equal('[AuditFailureBoundarySmokeTest] done 5/5 passed', output[#output])
Assert.equal(originalInstance, Config.SourceInstance)
local count = #output
commands.AuditFailureBoundarySmokeTest(1)
Assert.equal(count, #output, 'player invocation must not execute failure checks')
print, Config = savedPrint, savedConfig
