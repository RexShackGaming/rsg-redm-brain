local passed=0
local function check(ok,label) assert(ok,label);passed=passed+1 end
Config={};dofile('../feather-admin/configs/service_policy.lua')
local principal=Config.servicePolicy['feather-property']['feather-doors-property-tests']
check(principal['property.property.manage']==true and principal['property.interest.manage']==true,'exact Property fixture service actions')
check(Config.servicePolicy['feather-access']['feather-doors-property-tests']==nil,'no Access grant-service authority')
dofile('../feather-property/config.lua')
check(Config.Access.trustedReaders['feather-doors']==true and not Config.Access.trustedManagers['feather-doors'],'Doors receives Property reads only')
check(Config.Access.trustedManagers['feather-doors-property-tests']==true,'development fixture has own-property manager trust')
local file=assert(io.open('../feather-property/config.lua','r'));local source=file:read('*a');file:close()
source=source:gsub('DevMode = true','DevMode = false',1)
assert(load(source,'Property config production posture'))()
check(Config.Access.trustedManagers['feather-doors-property-tests']==nil,'fixture trust absent with Property DevMode off')
print(('PASS %d binding config boundary checks'):format(passed))
