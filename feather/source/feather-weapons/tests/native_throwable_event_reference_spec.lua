dofile('shared/native_throwable_event_reference.lua')
local R=WeaponNativeThrowableEventReference
local function buffer(slots)
 local bytes={};for _,value in ipairs(slots) do bytes[#bytes+1]=string.pack('<i4i4',value,0) end;return table.concat(bytes)
end
local profiles=assert(R.Profiles(1491));assert(#profiles==2)
profiles[1].slots=999;assert(R.Profiles(1491)[1].slots==8,'reference profiles are copied')
local network=buffer({42,0,-123,77,-456,2,1,0})
local decoded=assert(R.Decode(1491,1,-454144443,network))
assert(decoded.pickupHandle==42 and decoded.collectorPlayerIndex==0 and decoded.pickupType==(-123 & 0xffffffff)
 and decoded.model==(-456 & 0xffffffff) and decoded.rawSlots[4]==77 and decoded.rawSlots[6]==2)
assert(decoded.originConfirmed==false and decoded.pickupCredits==false and decoded.clientDiagnosticOnly)
local opaque=string.pack('<I4I4',0xffffffff,0xabcdef01)..network:sub(9)
local full=assert(R.Decode(1491,1,-454144443,opaque))
assert(full.rawSlotHex[1]=='abcdef01ffffffff' and full.rawSlots[1]==-1,
 'opaque upper event words survive JSON as exact hex, without assigning them authority')
assert(R.Decode(1491,1,(-454144443 & 0xffffffff),network),'signed and unsigned hash refer to same event')
local ai=assert(R.Decode(1491,0,-178091376,buffer({10,1,2,3,4,5,6,7})))
assert(ai.pickupType==10 and ai.inventoryItemHash==7 and ai.model==3 and ai.collectorPlayerIndex==2 and ai.pickupHandle==nil,
 'AI item event uses its own reference-verified collector/model offsets')
local live=assert(R.Decode(1491,0,-178091376,buffer({-897823490,1,16,-936393949,0,363259472,1,-1511427369})))
assert(live.model==3358573347 and live.collectorPlayerIndex==16 and live.inventoryItemHash==2783539927
 and live.networkId==nil and live.pickupHandle==nil and live.originConfirmed==false,
 'live capture: matching player index16 and world network ID16 must never become an ownership link')
for _,build in ipairs({0,1311,1355,1436,1492}) do assert(not R.Decode(build,1,-454144443,network)) end
assert(not R.Decode(1491,0,-454144443,network))
assert(not R.Decode(1491,1,-178091376,network))
assert(not R.Decode(1491,1,-454144443,network:sub(1,63)))
assert(not R.Decode(1491,1,-454144443,network..'\0'))
assert(not R.Decode(1491,1,-454144443,{}))
print('Throwable event reference PASS:1491 eight-slot layouts, separate AI/network fields, hash normalization, unsupported build/queue/size refusal; no authority')
