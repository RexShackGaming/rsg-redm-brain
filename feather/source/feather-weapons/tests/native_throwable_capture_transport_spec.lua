local events,packets,documents={},{},{}
local time,sequence,starts,mode=0,0,0,'normal'
RegisterNetEvent=function(name,fn) events[name]=fn end
CreateThread=function(fn) fn() end
Wait=function(ms) time=time+ms end
GetGameTimer=function() return time end
local bound={characterId='john',sessionId='s',epoch='e'}
json={encode=function(v)
 sequence=sequence+1;documents[tostring(sequence)]=v
 return mode=='oversize' and string.rep('x',6001) or tostring(sequence)
end}
WeaponNativeThrowableEventProbe={Start=function(b,callback)
 starts=starts+1;assert(b==bound)
 if mode=='refused' then return false end
 local rows={};for id=1,5 do rows[id]={id=id} end
 callback({records=rows,build=1491,reason='window_complete',frames=10,readFailures=0,truncated=false})
 return true
end,Stop=function() end}
TriggerServerEvent=function(name,ticket,index,raw)
 assert(name=='feather-weapons:server:throwable-capture-report')
 packets[#packets+1]={ticket=ticket,index=index,value=documents[raw]}
 if mode=='lost-ack' or mode=='wrong-ack' then
  source=mode=='wrong-ack' and 8 or 65535
  if mode=='wrong-ack' then events['feather-weapons:client:throwable-capture-ack'](ticket,index) end
 else
  source=65535;events['feather-weapons:client:throwable-capture-ack'](ticket,index)
 end
end
for _,name in ipairs({'GiveWeaponToPed','SetPedAmmoByType','DeleteEntity','ExecuteCommand'}) do
 _G[name]=function() error('report transport cannot call '..name) end
end
local oldPrint=print;print=function() end
dofile('client/native_throwable_capture_transport.lua')
local start=events['feather-weapons:client:throwable-capture-start']
source=9;start('ticket',bound);assert(starts==0)
source=65535;start('ticket',bound)
assert(starts==1 and #packets==3 and #packets[1].value.rows==4 and #packets[2].value.rows==1
 and packets[3].value.kind=='complete' and packets[3].value.count==5)
source=65535;start('ticket',bound);assert(starts==1,'duplicate challenge never starts a second observation window')
for _,failure in ipairs({'lost-ack','wrong-ack'}) do
 mode=failure;local count=#packets;source=65535;start('ticket-'..failure,bound)
 assert(starts==(failure=='lost-ack' and 2 or 3) and #packets==count+3,'only diagnostic packet retries, bounded to3')
end
mode='oversize';local count=#packets;source=65535;start('oversize',bound);assert(#packets==count)
mode='refused';source=65535;start('refused',bound)
assert(packets[#packets].value.reason=='client_capture_preflight_refused' and packets[#packets].value.count==0)
print=oldPrint
print('Capture transport PASS: server challenge/ack gates, four-row bounded packets, safe report-only retries, duplicate challenge refusal, preflight/oversize retention')
