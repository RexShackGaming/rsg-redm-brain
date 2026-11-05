-- Execute actual Property link-context function without replacing a live owner.
dofile('server/contract.lua')
local C=DoorsContract
Property={CheckRead=function(resource) return resource=='feather-doors' and C.Ok(true) or C.Err('authorization_denied') end,
    Fields=function(request,fields) return C.Fields(request,fields) and C.Ok(true) or C.Err('invalid_input') end,
    Allowed=function() return {} end,Export=function() end,Uuid=C.Uuid,Integer=C.Int,MaxRevision=C.MaxRevision,
    Token=C.Token,Ok=C.Ok,Err=C.Err}
Config={LinkTypes={door={}}}
local row={link_id='22222222-2222-2222-2222-222222222222',property_id='33333333-3333-3333-3333-333333333333',status='active',delegation_epoch=1,expired_owner=0}
DB={one=function() return row end}
dofile('../feather-property/server/links.lua')
local passed=0
local function check(ok,label) assert(ok,label);passed=passed+1 end
local request={linkType='door',externalId='11111111-1111-1111-1111-111111111111'}
check(PropertyLinks.Context(request,'foreign').code=='authorization_denied','reader policy enforced')
check(PropertyLinks.Context({linkType='other',externalId=request.externalId},'feather-doors').code=='invalid_input','unknown type refused')
local result=PropertyLinks.Context(request,'feather-doors')
check(result.ok and result.value.linkId==row.link_id and result.value.epoch==1,'canonical identity and owner epoch exposed')
row.expired_owner=1
check(PropertyLinks.Context(request,'feather-doors').value.status=='unavailable','expired owner denied before cleanup')
row.expired_owner=0;row.status='suspended'
check(PropertyLinks.Context(request,'feather-doors').value.status=='suspended','suspension preserved')
row.status='active';row.delegation_epoch=0
check(PropertyLinks.Context(request,'feather-doors').code=='invalid_persistence','invalid owner epoch refused')
row=nil
check(PropertyLinks.Context(request,'feather-doors').code=='link_not_found','missing link explicit')
print(('PASS %d canonical Property link checks'):format(passed))
