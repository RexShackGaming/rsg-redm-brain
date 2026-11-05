JANE_PRIMARY_LOGOUT=true; JANE_AUTO_LOGIN=true
dofile('tests/jane_economic_spec.lua')
dofile('tests/jane_economic_client_spec.lua')
JANE_RETAINED_NATIVE=true
dofile('tests/jane_economic_client_spec.lua')
JANE_RETAINED_INVALID=true
dofile('tests/jane_economic_client_spec.lua')
JANE_RETAINED_INVALID=nil; JANE_RETAINED_NATIVE=nil
JANE_ECONOMIC_REVOKE=true
dofile('tests/jane_economic_spec.lua')
JANE_ECONOMIC_REVOKE=nil; JANE_ECONOMIC_REVOKE_UNLOAD=true
dofile('tests/jane_economic_spec.lua')
JANE_ECONOMIC_REVOKE_UNLOAD=nil
JANE_PRIMARY_LOGOUT=nil; JANE_AUTO_LOGIN=nil
print('Jane loaded-round automatic login variants PASS (ledger7->8->9; mocked SQL/CFX/native)')
