dofile('shared/native_guid_acceptance.lua')
local documents={}
local function encode(v)
 local t=type(v)
 if t=='string' then return string.format('%q',v) end
 if t=='number' or t=='boolean' then return tostring(v) end
 assert(t=='table')
 local out={}
 if v[1] then for _,item in ipairs(v) do out[#out+1]=encode(item) end;return '['..table.concat(out,',')..']' end
 local keys={};for k in pairs(v) do keys[#keys+1]=k end;table.sort(keys)
 for _,k in ipairs(keys) do out[#out+1]=encode(k)..':'..encode(v[k]) end
 return '{'..table.concat(out,',')..'}'
end
local function remember(v) local raw=encode(v);documents[raw]=v;return raw end
local report={phase='complete',passed=1800,total=1800,cleanupComplete=true,cases={}}
for i=1,1800 do
 local row={id='case:'..i,phase='passed',cleanupComplete=true,observations={}}
 for n=1,4 do row.observations[n]={guid=string.rep('a',32),entity=i*4+n,point=n,
  item='weapon-model',wear={degradation=.125,permanentDegradation=.1,damage=.1,dirt=.25,soot=.5},
  activation={expectedGuid=string.rep('a',32),outputGuid=string.rep('a',32),nativeReturn='1',callCompleted=true}} end
 report.cases[i]=row
end
assert(#encode(report)>1000000,'exercise the former oversized-result failure shape')
local packets,summary=WeaponGuidAcceptance.Packets(report,remember)
assert(#packets>100 and #summary<1000)
local count=0
for _,raw in ipairs(packets) do
 assert(type(raw)=='string' and #raw<=6000)
 local value=documents[raw];assert(value.first==count+1 and #value.rows<=50)
 for _,row in ipairs(value.rows) do count=count+1;assert(row.id==report.cases[count].id) end
end
assert(count==1800 and documents[summary].caseCount==1800 and not documents[summary].cases)
local ok=pcall(WeaponGuidAcceptance.Packets,{cases={{id=string.rep('x',7000)}}},remember)
assert(not ok,'one oversized case is refused, never sent as a giant event')
print(('GUID report packets PASS (1800 detailed cases >1MB, %s bounded packets, compact summary, order/conservation/oversize checks)'):format(#packets))
