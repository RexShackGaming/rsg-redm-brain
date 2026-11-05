dofile('shared/ammunition_pools.lua')
local allocate = WeaponAmmunitionPools.Allocate
local owners = { primary = { regular = 20, express = 10 },
    offhand = { regular = 15, express = 5 } }
local result = assert(allocate({ regular = 35, express = 15 },
    { regular = 34, express = 15 }, owners, { primary = { regular = 1 } }))
assert(result.primary.regular == 19 and result.offhand.regular == 15)
assert(result.primary.express == 10 and result.offhand.express == 5)
assert(owners.primary.regular == 20, 'Allocation must not mutate authoritative input')
assert(not allocate({ regular = 35 }, { regular = 34 }, owners, {}))
assert(not allocate({ regular = 35 }, { regular = 34 }, owners,
    { primary = { regular = 1 }, offhand = { regular = 1 } }))
result = assert(allocate({ regular = 35 }, { regular = 40 }, owners, {}))
assert(result.primary.regular == 20 and result.offhand.regular == 15, 'Pickup cannot mint ownership')
assert(not allocate({ regular = 35 }, { regular = 34 }, owners, { primary = { regular = -1 } }))
print('Shared pool attribution checks passed')
local mixed = assert(allocate({ revolver_regular = 5, repeater_regular = 20 },
    { revolver_regular = 5, repeater_regular = 19 },
    { primary = { revolver_regular = 5 }, shoulder = { repeater_regular = 10 },
        back = { repeater_regular = 10 } }, { shoulder = { repeater_regular = 1 } }))
assert(mixed.primary.revolver_regular == 5 and mixed.shoulder.repeater_regular == 9)
assert(mixed.primary.repeater_regular == nil and mixed.shoulder.revolver_regular == nil
    and mixed.back.revolver_regular == nil, 'Mixed families must not receive foreign zero keys')
assert(not allocate({ revolver_regular = 5, repeater_regular = 20 },
    { revolver_regular = 4, repeater_regular = 20 },
    { shoulder = { repeater_regular = 10 } }, { shoulder = { revolver_regular = 1 } }),
    'A foreign positive attribution must still be rejected')
print('Mixed-family pool key isolation checks passed')
