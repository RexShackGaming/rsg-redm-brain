arg=arg or {};arg[2]='poison-fixture'
local f=dofile('tests/regular_knife_carriers_spec.lua');arg[2]=nil
local b=f.baseline
b.pools.ammo_throwing_knives_regular=0;b.pools.ammo_throwing_knives_poison=8
assert(f.root.Create(b),'Poison-only ownership must create the same zero-ammo carrier')
f.native.AMMO_TOMAHAWK=3;f.native.AMMO_THROWING_KNIVES_POISON=8
assert(f.root.Observe(b))
local s=f.root.Status().knives
assert(s.fundedQuantity==0 and s.poison.fundedQuantity==8 and s.poison.observedQuantity==8 and s.guidCaptured)
assert(f.permissions[10043]==true,'Regular recovery headroom is independent of Poison capacity')
local next=f.copy(b);next.revision=2;next.pools.ammo_throwing_knives_poison=7
f.native.AMMO_THROWING_KNIVES_POISON=7;assert(f.root.Observe(next))
next.revision=3;next.pools.ammo_throwing_knives_regular=1;f.native.AMMO_THROWING_KNIVES=1
assert(f.root.AcceptNativePickup(next))
local grants=f.counters();assert(grants==2,'conversion must reuse the shared knife GUID')
next.revision=4;next.pools.ammo_throwing_knives_regular=8
assert(f.root.PrepareRestore(next));f.native.AMMO_THROWING_KNIVES=8
assert(f.root.Observe(next) and f.permissions[10043]==false)
next.phase='sealed';f.seal(next)
assert(f.root.Release())
assert(f.native.AMMO_THROWING_KNIVES==0 and f.native.AMMO_THROWING_KNIVES_POISON==0 and f.native.AMMO_TOMAHAWK==0)
local _,removed,writes=f.counters();assert(removed==2 and writes==0,'one GUID removal per model, both knife pools cleaned')
print('PASS Poison-only/shared knife carrier: independent capacities, one GUID, Regular conversion rebind, exact sealed dual-pool cleanup')
