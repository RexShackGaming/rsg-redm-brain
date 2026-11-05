local count = 0
for _, path in ipairs({'../feather-character/server/activation.lua','../feather-admin/server/services/boosters.lua','../feather-admin/client/services/boosters.lua'}) do
 local f=assert(io.open(path)); local source=f:read('*a'); f:close()
 local helper=assert(source:match('^(.-)\n\n'))
 local policy=assert((loadstring or load)(helper..'\nreturn medicalEnabled'))()
 local state, health, throws='missing', {}, false
 GetResourceState=function() return state end
 exports={['feather-medical']={GetHealth=function() if throws then error('unavailable') end return health end}}
 local function check(expected) assert(policy()==expected,path);count=count+1 end
 check(false);state='stopped';check(nil);state='starting';check(nil)
 state='started';check(nil);throws=true;check(nil);throws=false
 health={enabled=false,state='ready'};check(false)
 health={enabled=true,state='starting'};check(nil)
 health={enabled=true,state='ready'};check(true)
end
print(('PASS %d cross-resource Medical policy checks'):format(count))
