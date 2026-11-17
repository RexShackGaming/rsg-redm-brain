-- Same real client/native adapter/server protocol composition, with the paid
-- receipt held until 3.25 seconds after the locally observed throw.
THROWABLE_DELAYED_CHALLENGE=true
dofile('tests/native_throwable_transition_composition_spec.lua')
THROWABLE_DELAYED_CHALLENGE=nil
print('PASS delayed paid receipt: original projectile removed before challenge, early continuity retained without server requests or economic writes')
