local commands={}
RegisterCommand=function(name,callback) commands[name]=callback end
dofile('tests/support/native_pair_options_probe.lua')
local P=WeaponNativePairOptionsProbe
local function guid(n) return string.pack('<I4I4I4I4I4I4I4I4',n,0,2,0,3,0,4,0)..string.rep('\0',72) end
local raw=guid(1)
local packed=assert(P.Pack(raw,0x89abcdef,3,752097756))
assert(#packed==104 and packed:sub(1,32)==raw:sub(1,32))
assert(string.unpack('<I4',packed,33)==0x89abcdef)
assert(string.unpack('<I4',packed,41)==0,'no ammunition requested')
assert(string.unpack('<I4',packed,49)==3)
assert(string.unpack('<I4',packed,57)==752097756)
assert(string.unpack('<f',packed,65)==0.5 and string.unpack('<f',packed,73)==1.0)
assert(string.unpack('<I4',packed,81)==0 and string.unpack('<I4',packed,89)==0,'unknown fields stay zero')
assert(string.unpack('<I4',packed,97)==1)
assert(not P.Pack(string.rep('\0',104),1,2,1) and not P.Pack(raw,1,99,1))
assert(P.GuidKey(raw)~=P.GuidKey(guid(2)))
local full=raw:sub(1,32)..string.pack('<I4I4',0x89abcdef,0)..string.rep('\0',128)..string.pack('<I4I4',0,0)
local enabled,prior=P.EnableInventoryRecord(full,raw,0x89abcdef)
assert(enabled and prior==0 and #enabled==176 and enabled:sub(1,168)==full:sub(1,168))
assert(string.unpack('<I4',enabled,169)==1)
assert(select(2,P.EnableInventoryRecord(enabled,raw,0x89abcdef))==1)
assert(not P.EnableInventoryRecord(full,guid(2),0x89abcdef))
assert(not P.EnableInventoryRecord(full,raw,100))
local worn=assert(P.SetTemporaryPermanent(full,raw,0x89abcdef,0.1))
assert(#worn==176 and worn:sub(1,136)==full:sub(1,136) and worn:sub(141)==full:sub(141),
 'only the candidate permanent float changes; padding and other fields stay exact')
assert(math.abs(P.WearFields(worn,raw,0x89abcdef).field17-0.1)<0.000001)
assert(not P.SetTemporaryPermanent(full,guid(2),0x89abcdef,0.1))
for _,bad in ipairs({-0.1,1.1,math.huge,'0.1',false}) do assert(not P.SetTemporaryPermanent(full,raw,0x89abcdef,bad)) end
local function fixture(failure)
    local removed,activated={},{}
    local primaryActivated=false
    local current=true
    local api={current=function() return current end,preflight=function() return true end,
     prepare=function() return true end,cleanupSetup=function() return failure~='setup-cleanup' end,
     verifyCleanup=function() return failure~='ammo' end,
     insert=function(record)
        if failure=='unknown-insert' and record.point==3 then return false end
        record.guid=guid(record.point); return true
     end,
     move=function() return true end,
     activate=function(record)
        assert(record.point~=3 or primaryActivated,'offhand options requires a pre-existing primary entity')
        activated[#activated+1]=record.point
        if record.point==2 then primaryActivated=true end
        if failure=='lifecycle' then current=false end
        if failure=='false-with-guid' or failure=='false-wrong-guid' then
            return false,{callCompleted=true,guid=P.GuidKey(record.guid),
                outputGuid=failure=='false-with-guid' and P.GuidKey(record.guid) or 'wrong-guid'}
        end
        return failure~='activation'
     end,
     verify=function(records)
        assert(records[1].point==2 and records[2].point==3)
        if failure=='guid' then return nil,'wrong_copy' end
        return {{guid=P.GuidKey(records[1].guid),permanentDegradation=failure=='wear-mismatch' and 0 or 0.1},
            {guid=P.GuidKey(records[2].guid),permanentDegradation=0.25}}
     end,
     remove=function(record)
        if record.pending or failure=='remove' then return false end
        removed[#removed+1]=record.point; return true
     end}
    if failure=='wear' or failure=='wear-mismatch' then api.expectedWear={0.1,0.25} end
    return P.New(api),removed,activated
end
local probe,removed,activated=fixture()
local result=assert(probe.Run())
assert(result.phase=='passed_guid_activation' and result.cleanupComplete and #removed==2)
assert(activated[1]==2 and activated[2]==3,'options creates the primary before requesting an offhand')
assert(not probe.Run(),'diagnostic never retries mutations automatically')
probe,removed=fixture('wear')
result=assert(probe.Run())
assert(result.phase=='passed_permanent_pair' and result.cleanupComplete and #removed==2)
assert(result.expectedPermanent[1]==0.1 and result.expectedPermanent[2]==0.25)
probe,removed=fixture('wear-mismatch')
result=assert(probe.Run())
assert(result.phase=='review_required' and result.reason:find('probe_per_copy_permanent_mismatch',1,true))
assert(result.observed and result.cleanupComplete and #removed==2,'wrong native wear retained as evidence, never a pass')
probe,removed,activated=fixture('false-with-guid')
result=assert(probe.Run())
assert(result.phase=='review_required' and result.activation=='verified_readback_return_mismatch')
assert(result.allNativeAccepted==false and result.observed and result.cleanupComplete and #activated==2)
assert(activated[1]==2 and activated[2]==3 and not probe.Run(),'one observation per independent copy, no repeat of refused native')
probe,removed,activated=fixture('false-wrong-guid')
result=assert(probe.Run())
assert(result.activation=='failed' and #activated==1 and result.cleanupComplete)
for _,failure in ipairs({'activation','guid','remove','unknown-insert','lifecycle','setup-cleanup','ammo'}) do
 probe,removed=fixture(failure)
 result=assert(probe.Run())
 assert(result.phase=='review_required')
 if failure=='remove' or failure=='unknown-insert' or failure=='lifecycle' or failure=='setup-cleanup' or failure=='ammo' then
    assert(not result.cleanupComplete,'uncertain cleanup is retained: '..failure)
 else assert(result.cleanupComplete and #removed==2) end
 assert(not probe.Run())
end
print('Pair options probe PASS (script-slot layout, zero ammo/unknown fields, ordered GUID activation, cleanup/identity/unknown retention, no retries; native boundary mocked)')
