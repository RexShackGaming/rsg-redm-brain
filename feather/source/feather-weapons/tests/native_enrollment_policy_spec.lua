dofile('shared/constants.lua')
local E=WeaponNativeEnrollment
local config={NativeAlphaCharacterId='Jane',NativeAlphaAdditionalCharacters={invalid=false}}
for _,id in ipairs({'Jane','John','aaaaaaaa-bbbb-cccc-dddd-eeeeeeeeeeee','third-player'}) do
 assert(E.Allows(config,id),'old test allowlists cannot restrict player access')
end
assert(E.Validate({}) and E.Allows({},'another-character'))
for _,bad in ipairs({'','*',' ',string.rep('a',129),false,1}) do assert(not E.Allows(config,bad)) end
assert(not E.Allows(config,nil) and not E.Validate(false))
print('All-player admission PASS (no allowlist, valid identity required, old test settings ignored)')
