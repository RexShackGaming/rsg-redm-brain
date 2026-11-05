dofile('shared/character_ammunition_readiness.lua')
local enabled,now,opens=true,0,0
local hint={characterId='Jane',sessionId='current'}
local replies={}
local server
server=WeaponCharacterAmmoReadiness.Server({enabled=function() return enabled end,now=function() return now end,
    owner={Ready=function(_,value)
        opens=opens+1; assert(value.pools==nil)
        assert(not server.Receive(2,2,hint),'yielded duplicate reserved')
        return {ok=true,value={pools={regular=999}}}
    end},reply=function(_,id,value,ok) replies[#replies+1]={id,value,ok} end})
assert(not server.Receive(2,1,{characterId='Jane',sessionId='current',pools={regular=999}}))
assert(not server.Receive(2,0,hint)); assert(server.Receive(2,1,hint) and opens==1)
assert(replies[1][2].pools==nil and replies[1][3])
assert(not server.Receive(2,2,hint)); now=1000
local original=server
local cancelling
cancelling=WeaponCharacterAmmoReadiness.Server({enabled=function() return enabled end,now=function() return now end,
    owner={Ready=function() cancelling.Cancel(2); return {ok=true} end},reply=function() error('cancelled reply') end})
assert(not cancelling.Receive(2,3,hint))
local late,lateReplies=nil,0
late=WeaponCharacterAmmoReadiness.Server({enabled=function() return enabled end,now=function() return now end,
    owner={Ready=function()
        assert(not late.Cancel(2,'old'),'late old-session leave cannot cancel current activation')
        assert(not late.Receive(2,4,hint),'reservation remains held')
        return {ok=true}
    end},reply=function() lateReplies=lateReplies+1 end})
assert(late.Receive(2,3,hint) and lateReplies==1)
assert(not late.Cancel(2,'old') and not late.Receive(2,4,hint),'old leave preserves current throttle')
assert(late.Cancel(2,'current'),'matching leave clears current throttle')
local sends={}
local ready=hint
local client=WeaponCharacterAmmoReadiness.Client({enabled=function() return enabled end,now=function() return now end,
    owner={Readiness=function() return ready end},send=function(id,value) sends[#sends+1]={id,value} end})
client.Step(); assert(#sends==1); client.Step(); assert(#sends==1)
assert(not client.Reply(1,hint,true,nil,false))
assert(client.Reply(1,hint,true,nil,true)); client.Step(); assert(#sends==1)
ready=nil; client.Step(); ready=hint; client.Step(); assert(#sends==1,'logout cleanup must not reopen old identity')
ready={characterId='Jane',sessionId='new'}
assert(not client.Reply(1,hint,true,nil,true)); client.Step(); assert(#sends==2)
enabled=false; assert(not client.Reply(2,ready,true,nil,true)); client.Step(); enabled=true
client.Step(); assert(#sends==3)
for _=1,7 do now=now+12000; client.Step(); now=now+1000; client.Step() end
assert(#sends==8,'six total attempts in a readiness cycle')
print('character_ammunition_readiness_spec PASS (identity-only handshake, source reserve, origin/retry/lifecycle barriers)')
