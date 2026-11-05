local Assert = _G.TestAssert

local originalInstance, originalProducers = Config.SourceInstance, Config.Producers
Config.SourceInstance = 'test-1'
Config.Producers = {
    ['feather-economy'] = {
        enabled = true,
        eventPrefixes = { 'economy.' },
        versions = { [1] = true },
        maxPerMinute = 10
    }
}
local valid, problem = FeatherAuditConfig.Validate()
Assert.truthy(valid, problem)

Config.Producers['feather-economy'].eventPrefixes = { 'economy..' }
local invalid, invalidProblem = FeatherAuditConfig.Validate()
Assert.falsy(invalid)
Assert.truthy(invalidProblem:find('invalid_producer_prefix', 1, true))

Config.SourceInstance, Config.Producers = originalInstance, originalProducers
