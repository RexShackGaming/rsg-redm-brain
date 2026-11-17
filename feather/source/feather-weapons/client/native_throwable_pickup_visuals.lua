-- Local props represent server-issued offers only. They have no native pickup
-- or economic value. No game-pool scans and no deletion of thrown projectiles.
WeaponNativeThrowablePickupVisuals={}
local function copy(v) if type(v)~='table' then return v end;local r={};for k,x in pairs(v) do r[k]=copy(x) end;return r end
local function finite(v) return type(v)=='number' and v==v and v>-math.huge and v<math.huge end
local function int(v,min) return finite(v) and v>=min and v%1==0 end
local function text(v) return type(v)=='string' and #v>0 and #v<=96 and not v:find('%c') end
local function pos(v) return type(v)=='table' and finite(v.x) and finite(v.y) and finite(v.z) end
local function same(a,b) return a and b and a.characterId==b.characterId and a.sessionId==b.sessionId and a.epoch==b.epoch end
local function distance(a,b) return (a.x-b.x)^2+(a.y-b.y)^2+(a.z-b.z)^2 end
local function callable(v) return type(v)=='function' or type(v)=='table' and type(rawget(v,'__cfx_functionReference'))=='string' end
function WeaponNativeThrowablePickupVisuals.New(api)
 for _,key in ipairs({'world','create','remove','entity'}) do assert(type(api)=='table' and callable(api[key]),'Visual port required: '..key) end
 local rows,owned,bound,sequence,stopped={}, {},nil,-1,false
 local function retire(id)
  local object=owned[id];if not object then return true end
  if api.remove(object)==true then owned[id]=nil;return true end
  return false -- retain exact cleanup handle; never search for a replacement
 end
 local function clear()
  local ok=true;for id in pairs(owned) do if not retire(id) then ok=false end end;return ok
 end
 local P={}
 function P.Replace(identity,serial,offers)
  if stopped or not identity or not same(identity,api.world()) or not int(serial,0)
   or type(offers)~='table' or #offers>64 then return false end
  if bound and same(bound,identity) and serial<=sequence then return false end
  if bound and not same(bound,identity) and not clear() then return false end
  local nextRows={}
  for _,row in ipairs(offers) do
   if type(row)~='table' or not text(row.id) or nextRows[row.id] or row.kind~='tomahawk'
    or not int(row.revision,0) or not int(row.bucket,0) or not pos(row.position) then return false end
   local prior=rows[row.id]
   if prior and same(bound,identity) and (row.revision<prior.revision or row.revision==prior.revision
    and (row.bucket~=prior.bucket or distance(row.position,prior.position)~=0)) then return false end
   nextRows[row.id]={id=row.id,kind='tomahawk',revision=row.revision,bucket=row.bucket,position=copy(row.position)}
  end
  for id,row in pairs(rows) do if not nextRows[id] or nextRows[id].revision~=row.revision then if not retire(id) then return false end end end
  rows,bound,sequence=nextRows,copy(identity),serial;return true
 end
 function P.Tick()
  if stopped then return false end
  local world=api.world()
  if not same(world,bound) or not world or world.alive~=true or not pos(world.position) then return clear() end
  local nearby={}
  for id,row in pairs(rows) do
   local d=distance(world.position,row.position)
   if row.bucket==world.bucket and d<=1024 then nearby[#nearby+1]={id=id,distance=d} end
  end
  table.sort(nearby,function(a,b) return a.distance<b.distance or a.distance==b.distance and a.id<b.id end)
  local wanted={};for i=1,math.min(#nearby,8) do wanted[nearby[i].id]=true end
  for id in pairs(owned) do if not wanted[id] and not retire(id) then return false end end
  for _,candidate in ipairs(nearby) do
   local id=candidate.id
   if wanted[id] and not owned[id] then
    local row=copy(rows[id]);local scope=copy(bound)
    local created=api.create(row)
    if created then
     owned[id]=created
     local checked,entity=pcall(api.entity,created)
     if not checked or not entity then
      if not retire(id) then return false end
      return false
     end
     -- Model loading may yield while the session or offer changes.
     local after=api.world()
     if stopped or not same(after,scope) or after.alive~=true or after.bucket~=row.bucket or not pos(after.position)
      or distance(after.position,row.position)>1024 or not rows[id] or rows[id].revision~=row.revision then
      if not retire(id) then return false end
      return true
     end
    end
   end
  end
  return true
 end
 function P.Entity(id) return owned[id] and api.entity(owned[id]) or nil end
 function P.Stop() stopped=true;rows={};return clear() end
 return P
end
