dofile('client/character_maintenance_native.lua')
local identity={characterId='c',sessionId='s',epoch='e'}
local original={{itemInstanceId=1,serialNumber='first',attachments={{definitionId='wide'}}},
 {itemInstanceId=2,serialNumber='second',attachments={{definitionId='long'}}}}
local applied,cleaned,removed={},{},{}
local failSecond=false
local base={current=function() return true end,
 createPair=function(items)
    assert(next(items[1].attachments)==nil and next(items[2].attachments)==nil)
    assert(original[1].attachments[1].definitionId=='wide' and original[2].attachments[1].definitionId=='long')
    return {{entity=101,itemInstanceId=1},{entity=102,itemInstanceId=2}}
 end,
 createSingle=function() error('unexpected single') end,
 finish=function() return true end,
 remove=function(record) assert(cleaned[record.itemInstanceId]); removed[record.itemInstanceId]=true; return true end}
local manager={Apply=function(record,plan)
 assert(plan.itemInstanceId==record.itemInstanceId)
 applied[record.itemInstanceId]=plan.component
 return not (failSecond and record.itemInstanceId==2)
end,Cleanup=function(record) cleaned[record.itemInstanceId]=true; return true end}
local adapter=WeaponNativeAttachmentReconstruction.Bind(base,function(item)
 return {itemInstanceId=item.itemInstanceId,component=item.attachments[1].definitionId}
end,manager)
local records=assert(adapter.createPair(original,identity))
assert(adapter.finish(records,identity))
assert(applied[1]=='wide' and applied[2]=='long','each copy receives its own component plan')
assert(adapter.remove(records[2]) and adapter.remove(records[1]) and removed[1] and removed[2])
failSecond=true; applied={}
records=assert(adapter.createPair(original,identity))
assert(not adapter.finish(records,identity),'second-copy failure cannot report pair success')
print('Pair attachment binding PASS (two independent plans, saved metadata unchanged, child-first cleanup, failed second-copy refusal)')
