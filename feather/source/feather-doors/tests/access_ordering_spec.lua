-- Execute actual Access control flow with deterministic yield interleavings.
-- This proves why an advisory preflight is not an atomic transfer/use permit.
local passed=0
local function check(ok,label) assert(ok,label);passed=passed+1 end
local epoch,stored,changeAtCommit,changeAtUse=1,nil,false,false
local G={}
Access={Grants=G,Copy=function(t) local o={};for k,v in pairs(t) do o[k]=v end;return o end,
 OnlyFields=function() return true end,Key=function(v) return type(v)=='string' end,
 Uuid=function(v) return type(v)=='string' end,Integer=function(v,a,b) return type(v)=='number' and v>=a and v<=b end,
 Ok=function(v) return {ok=true,value=v} end,Err=function(code) return {ok=false,code=code} end,Providers={}}
Config={Grants={MaxValidityMs=100000,CheckTimeoutMs=5000}}
G.Token=function() return true end
G.Begin=function() return Access.Ok({system=true,resource='feather-doors'}) end
G.Fingerprint=function() return 'fp' end;G.Replay=function() end
G.Context=function() return Access.Ok({targetType='doors.group',targetId='door',epoch=epoch,status='active',
 capabilities={'door.unlock'},provider={generation=1}}) end
G.Capability=function() return true end
G.Current=function() return Access.Ok(true) end
G.Character=function() return Access.Ok(true) end
Access.Providers.Authorize=function() return Access.Ok(true) end
G.Clock=function() return {grant_id='grant',event_id='event',now_ms=1000} end
G.Snapshot=function(row) return row end;G.Record=function() end
json={encode=function() return '{}' end}
GetGameTimer=function() return 0 end
local tx={exec=function(_,...) local p={...};stored={grant_id=p[1],target_epoch=p[4],grantee_type=p[5],valid_until=p[10]} end,
 one=function() return stored end}
G.Mutate=function(_,_,_,_,_,body) if changeAtCommit then epoch=2 end;return body(tx) end
DB={query=function(_,_,_,requestedEpoch) return stored and stored.target_epoch==requestedEpoch and {stored} or {} end,
 one=function() if changeAtUse then epoch=2 end;return {grant_id='grant',valid_until=2000,now_ms=1000} end}
dofile('../feather-access/server/grants.lua')
local r={requestId='request',reasonCode='test',targetType='doors.group',targetId='door',expectedEpoch=1,
 granteeType='character',granteeId='character',capability='door.unlock',validFrom=1000,validUntil=2000,
 provenanceType='doors.delegation',provenanceId='door'}
changeAtCommit=true
check(G.Grant(r,'feather-doors').ok,'Access can commit after final target check')
check(epoch==2 and stored.target_epoch==1,'late grant retains old target epoch')
local denied=G.Check({targetType='doors.group',targetId='door',capability='door.unlock',characterId='character'},'feather-doors')
check(denied.ok and denied.value.allowed==false,'new target lookup does not match old epoch grant')
epoch=1;changeAtUse=true
local advisory=G.Check({targetType='doors.group',targetId='door',capability='door.unlock',characterId='character'},'feather-doors')
check(advisory.ok and advisory.value.allowed==true and epoch==2,'transfer after final context check demonstrates advisory boundary')
print(('PASS %d Access ordering boundary checks'):format(passed))
