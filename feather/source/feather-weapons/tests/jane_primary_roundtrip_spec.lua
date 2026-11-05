-- Run saved-loadout variants in the ordinary suite, not only ad-hoc invocations.
local priorRoundtrip,priorLoad,priorUnload=JANE_PRIMARY_ROUNDTRIP,JANE_ECONOMIC_REVOKE,JANE_ECONOMIC_REVOKE_UNLOAD
JANE_PRIMARY_ROUNDTRIP=true
JANE_ECONOMIC_REVOKE=nil; JANE_ECONOMIC_REVOKE_UNLOAD=nil
dofile('tests/jane_economic_spec.lua')
dofile('tests/jane_economic_client_spec.lua')
JANE_ECONOMIC_REVOKE=true
dofile('tests/jane_economic_spec.lua')
JANE_ECONOMIC_REVOKE=nil; JANE_ECONOMIC_REVOKE_UNLOAD=true
dofile('tests/jane_economic_spec.lua')
JANE_PRIMARY_ROUNDTRIP,JANE_ECONOMIC_REVOKE,JANE_ECONOMIC_REVOKE_UNLOAD=priorRoundtrip,priorLoad,priorUnload
print('Saved-primary roundtrip standard-suite variants PASS (success/client/load-loss/unload-loss)')
