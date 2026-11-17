dofile('client/native_throwable_pickup_visuals.lua')
local function copy(v) if type(v)~='table' then return v end;local r={};for k,x in pairs(v) do r[k]=copy(x) end;return r end
local function fixture()
 local world={characterId='jane',sessionId='sid',epoch='epoch',alive=true,bucket=1,position={x=0,y=0,z=0}}
 local created,removed={},{};local fail=false
 local api={world=function() return world end,
 create=function(row) created[#created+1]=copy(row);return {id=row.id,handle=#created} end,
 remove=function(object) if fail then return false end;removed[#removed+1]=object;return true end,
 entity=function(object) return object.handle end}
 local p=WeaponNativeThrowablePickupVisuals.New(api)
 return p,world,api,created,removed,function(v) fail=v end
end
local function offer(id,x) return {id=id,kind='tomahawk',revision=0,bucket=1,position={x=x,y=0,z=0}} end
local p,w,api,created,removed,fail=fixture()
local rows={};for i=1,12 do rows[i]=offer(tostring(i),i) end
assert(p.Replace(w,1,rows));p.Tick();assert(#created==8 and p.Entity('1'))
assert(not p.Replace(w,1,rows),'stale snapshots ignored')
local altered=copy(rows);altered[1].position.x=2
assert(not p.Replace(w,2,altered),'same revision cannot move a pickup')
w.position.x=100;p.Tick();assert(#removed==8)
w.position.x=0;p.Tick();assert(#created==16)
fail(true);assert(not p.Replace(w,2,{}) and #removed==8,'retain failed exact cleanup')
fail(false);assert(p.Replace(w,2,{}) and #removed==16)
assert(not p.Replace(w,3,{offer('bad',0/0)}))
local p,w,api,created,removed=fixture()
api.create=function(row) created[#created+1]=row;w.epoch='new';return {id=row.id,handle=1} end
assert(p.Replace(w,1,{offer('a',1),offer('b',2)}));p.Tick()
assert(#created==1 and #removed==1 and not p.Entity('a'),'model-load yield cannot leak an old-session prop')
local p,w,api,created,removed=fixture()
assert(p.Replace(w,1,{offer('a',1)}));p.Tick();w.alive=false;p.Tick();assert(#removed==1)
assert(p.Stop() and not p.Replace(w,2,{}) and not p.Tick())
print('PASS pickup visuals: bounded nearest props, immutable offers, stale snapshots, exact cleanup and session/death fencing')
