# Standard Bolas candidate

Accepted: user confirmed all manual checks; native capacity3, consumption3->2,
restart, exact unload and no duplicate return passed. Lease5/5, release9/9 at
33/37/38. Binding and pickup recovery remain unverified.

Next candidate: Hawkmoth Bolas, separate WEAPON_THROWN_BOLAS_HAWKMOTH and
AMMO_BOLAS_HAWKMOTH pools, cap3 pending live verification. Use
sql/add_hawkmoth_bolas.sql, grantweapon throwable_bolas_hawkmoth 1 and
/AddItems ammo_bolas_hawkmoth 5. Replace standard Bolas in its existing slot
and repeat the same no-pickup lifecycle below. Counts34/38/38. No extra slot.

Cleanup regression passed at32/36/38 with eight active slots, lease5/5,
release9/9 and manual Regular/Poison checks. Improved remains deferred.

Next single-family slice: throwable_bolas / ammo_bolas_regular,
WEAPON_THROWN_BOLAS / AMMO_BOLAS. Existing three throwable positions are reused;
unequip one carrier before equipping Bolas. No fourth position or custom combat
controls are introduced. The existing single-type verification and bounded
same-runtime recovery path applies; cross-player recovery remains deferred.
The configured three-item ceiling is a candidate, not target-build acceptance.
Reference weapon list: https://github.com/femga/rdr3_discoveries/blob/master/weapons/weapons.lua
Reference ammo ceiling: https://github.com/Rexshack-RedM/rsg-ammo/blob/main/config.lua

Run sql/add_bolas.sql on an existing install. Restart Inventory before Weapons
so Inventory refreshes item definitions. NativeProbe must stay disabled.
Server console: `grantweapon throwable_bolas 1`.
Player chat: `/AddItems ammo_bolas_regular 5`.

1. Unequip Ancient Tomahawk to free its position; equip Bolas and load three.
   Confirm two remain in Inventory, wheel shows Bolas, other pools unchanged.
2. Run `weaponthrowablecapacity throwable_tertiary` and `weaponruntime` in F8.
   If Bolas occupied a different position, use that actual slot for capacity.
3. Throw one safely without picking it up. Inspect metadata: total two expected.
4. Restart Weapons, inspect restored pool, then unload. Exactly two should return
   (Inventory total four), and a repeated unload must not return anything.
5. Run metadata inspect, lease and release smokes. Expected counts33/37/38.

Stop and report zero/native mismatch or a ceiling other than three. Don't grant
additional ammo to compensate for a failed native application. Recovery/binding
behavior is not signed off by this initial no-pickup consumption test.
Static ammunition cases cover cap, excess retention, foreign-type rejection and
exact unloading, but no local Lua runner was available to execute them.
