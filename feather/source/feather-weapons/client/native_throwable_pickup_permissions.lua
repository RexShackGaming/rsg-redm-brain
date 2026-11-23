-- Feather-owned model pickup policy, not a native permission getter. Constructor
-- requires the caller's explicit prior policy so teardown never guesses it.
-- Inactive until the normal recovery lifecycle installs and owns this policy.
WeaponNativeThrowablePickupPermissions={}
function WeaponNativeThrowablePickupPermissions.New(setPermission,prior,modelList)
 local callable=type(setPermission)=='function' or type(setPermission)=='table' and type(rawget(setPermission,'__cfx_functionReference'))=='string'
 assert(callable and type(prior)=='table','Explicit prior model pickup policy required')
 local models=modelList or {'w_melee_tomahawk01','w_melee_tomahawk02'}
 assert(type(models)=='table' and #models>0 and #models<=8,'Bounded pickup models required')
 for _,name in ipairs(models) do assert(type(prior[name])=='boolean','Unknown prior pickup policy: '..name) end
 local original={};for _,name in ipairs(models) do original[name]=prior[name] end
 local changed,active,allowed={},false,false
 local P={}
 function P.Restore()
  local complete=true
  for _,name in ipairs(models) do if changed[name] then
   local ok,result=pcall(setPermission,name,original[name])
   if ok and result~=false then changed[name]=nil else complete=false end
  end end
  if complete then active=false;allowed=false end
  return complete
 end
 function P.Suppress()
  if active and not allowed then return true end
  -- Reserve restoration BEFORE invoking a possibly throwing native wrapper.
  for _,name in ipairs(models) do
   changed[name]=true
   local ok,result=pcall(setPermission,name,false)
   if not ok or result==false then P.Restore();return false end
  end
  active=true;allowed=false;return true
 end
 function P.Allow()
  if active and allowed then return true end
  allowed=true -- reserve suppression compensation before a partial allow can fail
  for _,name in ipairs(models) do
   changed[name]=true
   local ok,result=pcall(setPermission,name,true)
   if not ok or result==false then P.Suppress();return false end
  end
  active=true;allowed=true;return true
 end
 function P.Status()
  local pending=false;for _ in pairs(changed) do pending=true end
  return {active=active,restorationPending=pending}
 end
 return P
end
