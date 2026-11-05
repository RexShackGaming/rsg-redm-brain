-- Staging guard only: not native activation or non-firearm parity coverage.
local registered,ran,response
exports={['feather-core']={RegisterRPC=function(_,name,fn) registered=fn; return true end}}
for _,flags in ipairs({{false,false},{true,false},{false,true},{true,true}}) do
    Config={CharacterAmmunitionEnabled=flags[1],CharacterAmmoTransportEnabled=flags[2]}
    dofile('tests/archive/server/imports.lua')
    ran=false; response=nil
    FeatherCore.RPC.Register('legacy',function() ran=true end,{})
    registered({},function(value) response=value end,1,{})
    if not flags[1] and not flags[2] then assert(ran)
    else assert(not ran and response.error.code=='hybrid_runtime_disabled')
        -- Early return must happen before any threads/routes/exports/natives.
        dofile('tests/archive/client/main.lua')
        dofile('tests/archive/client/dev_shot_death.lua')
        dofile('tests/archive/client/native_probe.lua')
    end
end
print('character_ammunition_exclusivity_spec PASS (flag matrix, legacy RPC veto, client early quarantine)')
