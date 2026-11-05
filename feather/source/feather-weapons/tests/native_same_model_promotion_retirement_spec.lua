for _,path in ipairs({'client/character_ammunition_native_owner.lua','client/character_ammunition_startup.lua'}) do
 local file=assert(io.open(path,'r')); local source=file:read('*a'); file:close()
 assert(not source:find('SameModelPromotionFixture',1,true),'temporary native setter fixture must not ship')
 assert(not source:find('feather_native_same_model_promotion_fixture',1,true),'temporary fixture flag must not ship')
end
print('same-model promotion temporary fixture retirement PASS')
