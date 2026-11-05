JANE_PRIMARY_LOGOUT=true
dofile('tests/jane_economic_spec.lua')
dofile('tests/jane_economic_client_spec.lua')
JANE_RETAINED_NATIVE=true
dofile('tests/jane_economic_client_spec.lua')
JANE_RETAINED_INVALID=true
dofile('tests/jane_economic_client_spec.lua')
JANE_RETAINED_INVALID=nil
JANE_RETAINED_NATIVE=nil
JANE_PRIMARY_LOGOUT=nil
print('Jane saved-primary logout/login variants PASS')
