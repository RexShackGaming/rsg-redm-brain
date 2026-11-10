-- Deterministic coverage and injected execution; never a gameplay creation policy.
WeaponGuidAcceptance={}
local S=WeaponGuidAcceptance
local order={'primary','offhand','shoulder','back'}
local function copy(v) if type(v)~='table' then return v end;local t={};for k,x in pairs(v) do t[k]=copy(x) end;return t end
function S.Matrix(catalog,registry)
 local side,long,models={},{},{}
 for id,w in pairs(catalog.weapons) do
  if registry.weapons[id] and ({pistol=true,revolver=true,repeater=true,rifle=true,shotgun=true})[w.family]
   and (w.slot=='sidearm' or w.slot=='longgun') and w.usesAmmunition~=false then
   if models[w.nativeWeaponName] then return nil,'duplicate_catalog_model' end
   models[w.nativeWeaponName]=true
   local list=w.slot=='sidearm' and side or long;list[#list+1]=id
  end
 end
 table.sort(side);table.sort(long)
 if #side<2 or #long<2 then return nil,'incomplete_firearm_catalog' end
 local matrix={}
 local function add(label,slots)
  for _,profile in ipairs({'clean','customized'}) do
   matrix[#matrix+1]={id=label..':'..profile,slots=copy(slots),profile=profile}
  end
 end
 for _,id in ipairs(side) do
  add('single-primary:'..id,{primary=id})
  add('single-offhand:'..id,{primary=side[1]==id and side[2] or side[1],offhand=id})
 end
 for _,id in ipairs(long) do add('single-shoulder:'..id,{shoulder=id});add('single-back:'..id,{back=id}) end
 for _,a in ipairs(side) do for _,b in ipairs(side) do add('hands:'..a..':'..b,{primary=a,offhand=b}) end end
 for _,a in ipairs(long) do for _,b in ipairs(long) do
  if a~=b then add('longguns:'..a..':'..b,{shoulder=a,back=b}) end
 end end
 for _,a in ipairs(side) do for _,b in ipairs(long) do
  add('primary-shoulder:'..a..':'..b,{primary=a,shoulder=b})
  add('primary-back:'..a..':'..b,{primary=a,back=b})
  add('offhand-shoulder:'..a..':'..b,{primary=side[1]==a and side[2] or side[1],offhand=a,shoulder=b})
  add('offhand-back:'..a..':'..b,{primary=side[1]==a and side[2] or side[1],offhand=a,back=b})
 end end
 for i,id in ipairs(side) do
  add('four-slot:'..id,{primary=id,offhand=side[i%#side+1],shoulder=long[1],back=long[2]})
 end
 if #matrix>5000 then return nil,'matrix_limit_exceeded' end
 return matrix
end
function S.Plan(case,catalog,registry,identity)
 local rows={}
 for index,slot in ipairs(order) do
  local id=case.slots[slot]
  if id then
   local w=catalog.weapons[id];local attachments={}
   local permanent=case.profile=='customized' and index*0.025 or 0
   local degradation=case.profile=='customized' and permanent+0.05 or 0
   local soot=case.profile=='customized' and index*0.025 or 0
   if case.profile=='customized' then
    for _,ids in pairs(w.attachmentSlots or {}) do
     if #ids>0 then local d=catalog.attachments[ids[1]];attachments[#attachments+1]={definitionId=d.id,slot=d.slot} end
    end
    table.sort(attachments,function(a,b) return a.slot<b.slot end)
   end
   rows[slot]={id=800000000+index,revision=0,itemName=w.itemName,metadata={schemaVersion=2,
    weaponDefinitionId=id,serialNumber='GUID-ACCEPTANCE-TEMP-'..index,quality=100,condition=100-math.ceil(degradation*100),
    maintenance={permanentDegradation=permanent,damage=permanent,degradation=degradation,dirt=soot,soot=soot},
    ammo={ownership='character',type=w.ammunitionType},attachments=attachments,cosmetics={},
    flags={disabled=false,evidence=false,stolen=false},provenance={}}}
  end
 end
 local plan,why=WeaponCharacterAmmoMaterialization.Build(rows,catalog,registry,identity)
 if not plan then return nil,why end
 local valid,reason=WeaponCharacterAmmoMaterialization.Validate(plan,registry,identity)
 if not valid then return nil,reason end
 return plan
end
function S.Run(api,cases)
 local report={phase='running',cases={},passed=0,total=#cases,automaticRetries=0,
  candidate='native_inventory_guid_v1',coverage='ordered pairwise plus representative four-slot',visual='pending'}
 for index,case in ipairs(cases) do
  local row={id=case.id,phase='running'};report.cases[index]=row
  local ok,result=pcall(api.case,case,index)
  if not ok or type(result)~='table' then result={ok=false,cleanupComplete=false,reason='case_exception_retained'} end
  row.phase=result.ok and 'passed' or 'failed';row.reason=result.reason;row.cleanupComplete=result.cleanupComplete
  row.observations=result.observations;row.retained=result.retained
  if not result.ok or result.cleanupComplete~=true then
   report.phase='review_required';report.reason=result.reason or 'case_cleanup_unconfirmed';report.failedCase=case.id
   report.cleanupComplete=result.cleanupComplete==true;return report
  end
  report.passed=index
  if api.progress then api.progress(index,#cases,case.id) end
 end
 report.phase='complete';report.cleanupComplete=true;return report
end
-- JSON strings keep CFX event serialization shallow and each packet bounded.
-- Report delivery may retry; native test cases and economic mutations never do.
function S.Packets(report,encode)
 local packets,batch,first={}, {},1
 local function flush()
  if #batch==0 then return end
  local raw=encode({first=first,rows=batch})
  assert(type(raw)=='string' and #raw<=6000,'guid_report_row_exceeds_packet_limit')
  packets[#packets+1]=raw;first=first+#batch;batch={}
 end
 for _,row in ipairs(report.cases or {}) do
  batch[#batch+1]=row
  local raw=encode({first=first,rows=batch})
  if #raw>6000 or #batch>50 then batch[#batch]=nil;flush();batch[1]=row end
 end
 flush()
 local summary={wireVersion=2,phase=report.phase,passed=report.passed,total=report.total,
  caseCount=#(report.cases or {}),cleanupComplete=report.cleanupComplete,reason=report.reason,
  failedCase=report.failedCase,automaticRetries=0,candidate=report.candidate,coverage=report.coverage,visual='pending'}
 local raw=encode(summary)
 assert(type(raw)=='string' and #raw<=6000,'guid_report_summary_exceeds_packet_limit')
 return packets,raw
end
