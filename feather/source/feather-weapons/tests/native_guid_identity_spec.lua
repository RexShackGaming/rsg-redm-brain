dofile('client/character_maintenance_native.lua')
local identity={characterId='c',sessionId='s',epoch='e'}
local active=true
local points={[10]={entity=50,hash='carbine',guid=string.rep('a',32)}}
local exists={[50]=true}
local function copy(v) if not v then return end; local r={}; for k,x in pairs(v) do r[k]=x end; return r end
local api={current=function() return active end,hash=function(v) return v end,
 point=function(p) return copy(points[p]) end,exists=function(h) return exists[h]==true end}
local resolver=WeaponNativeGuidIdentity.New(api)
local record={entity=50,name='carbine',point=10,itemInstanceId=135,itemRevision=0,serialNumber='test'}
assert(resolver.Capture(record,identity))
assert(not resolver.Capture(nil,identity))
assert(not resolver.Capture({entity=50,name='carbine',point=10,itemInstanceId=136,itemRevision=0,serialNumber='other'},identity),'duplicate GUID binding refused')
assert(resolver.Resolve(record,identity)==50)
points[0]=points[10]; points[10]=nil
assert(resolver.Resolve(record,identity)==50,'normal draw preserves exact entity')
points[0]={entity=51,hash='carbine',guid=string.rep('b',32)}; exists[51]=true; exists[50]=false
assert(not resolver.Resolve(record,identity) and record.entity==50,'same model foreign GUID never adopted')
points[0].guid=string.rep('a',32); exists[50]=true
assert(not resolver.Resolve(record,identity) and record.entity==50,'old live entity blocks replacement')
exists[50]=false
assert(resolver.Resolve(record,identity)==51 and record.entity==51,'exact stable GUID authorizes destroyed representation change')
points[10]={entity=52,hash='carbine',guid=string.rep('a',32)}; exists[52]=true
assert(not resolver.Resolve(record,identity) and record.entity==51,'ambiguous same GUID entities refuse')
points[10].guid=string.rep('b',32)
assert(resolver.Resolve(record,identity)==51 and not resolver.Resolve(record,identity,true),'model-wide removal refuses foreign same-model copy')
points[10]=nil
assert(not resolver.Resolve(record,{characterId='c',sessionId='s',epoch='new'}))
record.itemRevision=1; assert(not resolver.Resolve(record,identity)); record.itemRevision=0
record.entity=999; assert(not resolver.Resolve(record,identity),'mutated record cannot redirect binding'); record.entity=51
local originalPoint=api.point; local samples=0
api.point=function(p)
 local value=originalPoint(p)
 if p==0 then samples=samples+1; if samples==2 then value.guid=string.rep('c',32) end end
 return value
end
assert(not resolver.Resolve(record,identity),'changing readback refuses')
api.point=originalPoint; active=false; assert(not resolver.Resolve(record,identity))
print('GUID identity PASS (capture/current scope, normal relocation, GUID-verified replacement, foreign/ambiguous/live-old/mutated/torn/epoch refusal, exclusive cleanup)')
