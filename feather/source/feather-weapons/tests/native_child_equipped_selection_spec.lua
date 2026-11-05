dofile('client/character_ammunition_creation_native.lua')
local select=WeaponCharacterAmmoCreationNative.SelectEquippedChild
local function item(id,equipped)
    return {guid=id,found=true,readConfirmed=true,equippedFlagReadable=true,equipped=equipped}
end
assert(select(item('stock',true),{found=false})=='stock')
assert(select(item('stock',false),item('wide',true))=='wide','live stock-off/wide-on selects wide regardless slot query')
assert(select(item('stock',true),item('wide',false))=='stock')
assert(not select(item('stock',true),item('wide',true)),'ambiguous both-on refuses')
assert(not select(item('stock',false),item('wide',false)),'neither-on refuses')
assert(not select(item('stock',false),{found=false}))
assert(not select(item('same',false),item('same',true)),'same GUID cannot identify two different children')
local bad=item('wide',true); bad.readConfirmed=false
assert(not select(item('stock',false),bad))
bad=item('wide',true); bad.equippedFlagReadable=false
assert(not select(item('stock',false),bad))
assert(not select(nil,{found=false}) and not select(item('stock',true),nil))
print('exact child equipped selection PASS (stock/wide live flags, failed/ambiguous/duplicate refusal)')
