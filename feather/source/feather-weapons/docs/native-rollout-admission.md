# Weapons access for all players

Every current player character can use Weapons. There is no character allowlist,
configurable player cap, or admission-mode setting. NativeAlphaCharacterId,
NativeAlphaAdditionalCharacters and the proposed NativeEnrollment setting are
not consulted for access. Old server configuration fields can be removed when
applying the eventual combined update; their presence does not restrict players.

Access still uses the server's authoritative Core session and character identity.
Players can only equip or modify their own permitted items. Ownership, equipment,
lease/epoch, ammunition, recovery, shutdown and duplicate-readiness checks remain.
Client-supplied character IDs do not replace server identity. Capability
scopedCharacterOnly is false; productionReady remains false.

The existing readiness loop starts a character's native owner automatically,
including character selection taking longer than 30 seconds. No per-player
access command or list entry is needed.

Normal native startup, player equipment, supported utility/melee/throwable
policies and wear lifecycle paths now work with DevMode=false. Native runtime,
transport, lifecycle and per-feature switches still apply; shipped native host
switches remain opt-in. Test commands, fault probes, fixture issuance and
experimental wider attachment maps still require developer mode. Native pickup
credit remains a separately guarded development feature.

The paired Inventory update automatically creates a zero-ammunition ledger and
initialization receipt during trusted runtime startup for eligible fresh
characters. Ordinary starter items are allowed. Existing ledgers/balances are
never reset; equipment, weapon/ammunition items, migration metadata, or existing
operation history without a ledger refuse automatic setup. Both writes share the
snapshot transaction and roll back if session/gate validation or snapshot fails.
Ordinary read-only snapshots never initialize data. No items/ammunition are granted.
Developer fixture/issuance and evidence tooling remain outside this normal-startup
change. These changes still require wider live acceptance before a production release.

Local regressions cover more than two independent identities, stale/forged
activation hints, duplicate-start refusal, delayed startup, invalid identities
and unchanged runtime/data gates. Broader multiplayer engine acceptance is pending.

The paired test deployment passed existing Jane/John loadout/ammunition/wear
conservation and visual checks with developer mode disabled. A new third
character automatically became ACTIVE with revision-zero/all-zero ammunition,
then reconnected with unchanged balances while John's weapons still drew.
Inventory health reported no pending work. An independent SQL receipt count was
not supplied. Five simultaneous owners are covered by the aggregate-drain
regression, not by live multiplayer acceptance.

Preserve the existing test server/database. Test a clean install separately with
an empty database; do not wipe acceptance evidence to test fresh startup. No
repeat deployment or live test is required to submit the accepted batch for review.
