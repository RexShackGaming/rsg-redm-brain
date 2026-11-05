-- Reuse observer scenarios with distinct shoulder/back repeaters. Only test
-- fixture identifiers are substituted; production observer code runs unchanged.
local file = assert(io.open('tests/firearm_dual_pools.lua', 'r'))
local source = file:read('*a') file:close()
source = source:gsub('cattleman', 'carbine'):gsub('schofield', 'lancaster')
    :gsub('primary', 'shoulder'):gsub('offhand', 'back')
    :gsub("slot = 'sidearm'", "slot = 'longgun'")
    :gsub("family = 'revolver', capacity = 6", "family = 'repeater', capacity = index == 1 and 7 or 14")
assert(load(source, 'shoulder/back observer fixture', 't', _G))()
print('Distinct shoulder/back repeater observer checks passed')
