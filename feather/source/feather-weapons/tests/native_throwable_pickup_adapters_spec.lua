dofile('client/native_throwable_pickup_visuals.lua')
dofile('client/native_throwable_pickup_visual_adapter.lua')
dofile('client/native_throwable_pickup_prompt.lua')
dofile('client/native_throwable_pickup_prompt_adapter.lua')
local w={characterId='jane',sessionId='sid',epoch='epoch',alive=true,bucket=1,position={x=0,y=0,z=0}}
local exists,networked,enabled,press=true,false,false,false
local labels,ambient,removes,translations={},0,0,0
joaat=function(s) return s=='w_melee_tomahawk01' and 201 or 202 end
DoesEntityExist=function() return exists end
NetworkGetEntityIsNetworked=function() return networked end
GetEntityModel=function() return 201 end
SetEntityCollision=function(_,first,second) assert(first==false and second==false) end
CreateVarString=function(_,_,label) return label end
Citizen={InvokeNative=function(hash,entity,radius,p2,tabs,group,label,flags)
 assert(hash==0x315C81D760609108 and entity==50 and radius==2 and p2==2 and tabs==1 and flags==2)
 ambient=ambient+1;assert(label=='Tomahawk')
end}
exports={['feather-core']={
 RegisterLocale=function(_,language,entries) assert(language=='en' and entries.ui_weapons_throwable_pickup=='Pick up Tomahawk');return {ok=true} end,
 TranslateLocale=function() translations=translations+1;return {ok=true,value='Translation [ro][missing] does not exist'} end},
 ['feather-toolkit']={
 CreateObject=function(_,spec)
  assert(spec.networked==false and spec.scriptHost==false and spec.dynamic==false and spec.frozen==true
   and spec.placeOnGround==false and spec.model=='w_melee_tomahawk01')
  return {ok=true,value={id='owned-prop',entity=50}}
 end,
 RemoveEntity=function(_,id) assert(id=='owned-prop');removes=removes+1;exists=false;return {ok=true} end,
 ResolveControl=function(_,key) assert(key=='G');return {ok=true,value=10} end,
 CreatePrompt=function(_,spec) labels[#labels+1]=spec.label;assert(spec.mode=='hold' and not spec.enabled and not spec.visible);return {ok=true,value={id='prompt'}} end,
 RemovePrompt=function() return {ok=true} end,
 SetPromptEnabled=function(_,_,value) enabled=value;return {ok=true} end,
 IsPromptCompleted=function() return {ok=true,value={completed=press}} end}}
local visual=WeaponNativeThrowablePickupVisualAdapter.New(function() return w end)
local offer={id='pickup',kind='tomahawk',revision=1,bucket=1,position={x=1,y=0,z=0}}
assert(visual.Replace(w,1,{offer}));visual.Tick()
local prompt=WeaponNativeThrowablePickupPromptAdapter.New({world=function() return w end,
 entity=visual.Entity,claim=function() error('claim should not run') end,readClaim=function() end})
assert(prompt.Replace({offer}));prompt.Tick();prompt.Tick()
assert(ambient==2 and enabled and labels[1]=='Pick up Tomahawk' and translations==2,'English fallback cached by key')
prompt.LanguageChanged();prompt.Tick();assert(translations==4 and labels[2]=='Pick up Tomahawk')
networked=true;prompt.Tick();assert(not enabled,'do not attach a prompt to a replaced network entity')
assert(not visual.Stop() and removes==0,'owned handle mismatch must not delete another entity')
networked=false;assert(visual.Stop() and removes==1)
prompt.Stop()
print('PASS actual pickup adapters: Toolkit ownership, inert local props, ambient native arguments, locale fallback/cache and foreign-entity refusal')
