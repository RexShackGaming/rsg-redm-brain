-- Internal durable-offer reload/projection. No net handlers or automatic scans.
-- Read one bounded page per Step, publish a replacement only after a full scan.
WeaponNativeThrowablePickupOfferFeed={}
local function copy(v) if type(v)~='table' then return v end;local r={};for k,x in pairs(v) do r[k]=copy(x) end;return r end
local function finite(v) return type(v)=='number' and v==v and v>-math.huge and v<math.huge end
local function int(v,min) return finite(v) and v>=min and v%1==0 end
local function text(v) return type(v)=='string' and #v>0 and #v<=96 and not v:find('%c') end
local function pos(v) return type(v)=='table' and finite(v.x) and finite(v.y) and finite(v.z) end
local function same(a,b) return a and b and a.characterId==b.characterId and a.sessionId==b.sessionId and a.epoch==b.epoch end
local function distance(a,b) return (a.x-b.x)^2+(a.y-b.y)^2+(a.z-b.z)^2 end
local function callable(v) return type(v)=='function' or type(v)=='table' and type(rawget(v,'__cfx_functionReference'))=='string' end
function WeaponNativeThrowablePickupOfferFeed.New(api)
 for _,k in ipairs({'page','actor','available','send'}) do assert(type(api)=='table' and callable(api[k]),'Offer feed port required: '..k) end
 local cache,working,cursor,pages,sequence,scanning={}, {},nil,0,0,false
 local revisions={}
 local P={}
 function P.Step()
  if scanning then return false,'scan_in_progress' end
  scanning=true
  local ok,page=pcall(api.page,cursor);scanning=false
  if not ok or type(page)~='table' or type(page.bindings)~='table' or #page.bindings>64
   or not int(page.scanned,0) or page.scanned>64 or type(page.hasMore)~='boolean'
   or page.hasMore and (not text(page.cursor) or page.cursor==cursor or page.scanned~=64) then
   working,cursor,pages={},nil,0;return false,'offer_page_unavailable'
  end
  pages=pages+1
  if pages>16 then working,cursor,pages={},nil,0;return false,'offer_scan_capacity' end
  for _,b in ipairs(page.bindings) do
   if type(b)~='table' or b.version~=3 or b.kind~='paid_tomahawk_pickup' or b.phase~='available'
    or b.presentation~=nil and b.presentation~='prompt'
    or not text(b.pickupId) or working[b.pickupId] or not int(b.pickupRevision,0)
    or not int(b.bucket,0) or not pos(b.position) then
    working,cursor,pages={},nil,0;return false,'offer_binding_invalid'
   end
   -- Client projection excludes serials, donor identity and item metadata.
   working[b.pickupId]={id=b.pickupId,kind='tomahawk',revision=b.pickupRevision,bucket=b.bucket,position=copy(b.position)}
  end
  if page.hasMore then cursor=page.cursor;return true,'scanning' end
  cache=working;working,cursor,pages={},nil,0;sequence=sequence+1
  return true,'complete'
 end
 function P.Send(source)
  if not int(source,1) or sequence==0 then return false end
  local a=api.actor(source)
  if type(a)~='table' or not text(a.characterId) or not text(a.sessionId) or not text(a.epoch)
   or not int(a.bucket,0) or not pos(a.position) or a.alive~=true then return false end
  a=copy(a) -- subsequent yielding reservation reads cannot mutate this snapshot
  local scope={characterId=a.characterId,sessionId=a.sessionId,epoch=a.epoch};local selected={}
  for id,row in pairs(cache) do
   local d=distance(a.position,row.position)
   if a.bucket==row.bucket and d<=2500 and api.available(id)==true then selected[#selected+1]={row=row,distance=d} end
  end
  table.sort(selected,function(x,y) return x.distance<y.distance or x.distance==y.distance and x.row.id<y.row.id end)
  local offers={};for i=1,math.min(#selected,64) do offers[i]=copy(selected[i].row) end
  local after=api.actor(source)
  if not same(scope,after) or after.alive~=true or after.bucket~=a.bucket then return false end
  local prior=revisions[source]
  local serial=prior and same(prior.identity,scope) and prior.sequence+1 or 1
  revisions[source]={identity=copy(scope),sequence=serial}
  api.send(source,{identity=scope,sequence=serial,bucket=a.bucket,pickups=offers})
  return true
 end
 function P.Forget(source) revisions[source]=nil end
 return P
end
