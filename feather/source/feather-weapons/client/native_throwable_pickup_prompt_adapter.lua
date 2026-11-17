-- No automatic activation. The recovery route supplies world/claim/readClaim.
-- Core resolves feather-settings' account language and locale change events.
WeaponNativeThrowablePickupPromptAdapter={}
function WeaponNativeThrowablePickupPromptAdapter.New(ports)
 local callable=function(v) return type(v)=='function' or type(v)=='table' and type(rawget(v,'__cfx_functionReference'))=='string' end
 assert(type(ports)=='table' and callable(ports.entity),'Owned pickup visual resolver required')
 local core,toolkit=exports['feather-core'],exports['feather-toolkit']
 local english={pickup='Pick up Tomahawk',tomahawk='Tomahawk'}
 local entries={};for k,v in pairs(english) do entries['ui_weapons_throwable_'..k]=v end
 local registered=core:RegisterLocale('en',entries)
 assert(registered and registered.ok,'Pickup locale registration failed')
 local labels={}
 local function label(key)
  if labels[key] then return labels[key] end
  local ok,result=pcall(function() return core:TranslateLocale(0,'ui_weapons_throwable_'..key) end)
  if ok and type(result)=='table' and result.ok and type(result.value)=='string'
   and not result.value:match('^Translation %[') and not result.value:match('^Locale %[') then labels[key]=result.value;return result.value end
  labels[key]=english[key];return labels[key]
 end
 local function requireValue(result)
  assert(type(result)=='table' and result.ok,'Pickup prompt provider failed')
  return result.value
 end
 local group=joaat('feather-weapons:tomahawk-pickup')
 local controller=WeaponNativeThrowablePickupPrompt.New({world=ports.world,claim=ports.claim,readClaim=ports.readClaim,label=label,
  create=function(value)
   local control=requireValue(toolkit:ResolveControl('G'))
   return requireValue(toolkit:CreatePrompt({control=control,label=value,groupId=group,mode='hold',enabled=false,visible=false})).id
  end,
  remove=function(id) requireValue(toolkit:RemovePrompt(id)) end,
  enable=function(id,value) requireValue(toolkit:SetPromptEnabled(id,value)) end,
  show=function(value,row)
   local entity=ports.entity(row.id)
   if not entity or entity==0 or not DoesEntityExist(entity) then return false end
   -- Entity ambient groups coexist with surrounding interactions. See saved
   -- umaruru reference and HUD native signature; never force an active group.
   Citizen.InvokeNative(0x315C81D760609108,entity,2.0,2,1,group,CreateVarString(10,'LITERAL_STRING',value),2)
   return true
  end,
  completed=function(id) return requireValue(toolkit:IsPromptCompleted(id)).completed==true end})
 local changed=controller.LanguageChanged
 controller.LanguageChanged=function() labels={};changed() end
 return controller
end
