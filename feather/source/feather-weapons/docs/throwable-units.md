# Purchased throwable units

Status: backend commerce, custody, equipment and observation composition is
implemented behind unshipped admission; player controls are implemented and live acceptance is pending.

The player buys actual throwable quantities. One Tomahawk purchase gives one
Tomahawk, without a separate pouch, carrier purchase, or ammunition purchase.
Equip and Unequip should be direct Inventory actions. Internal native GUIDs and
the character ledger must not appear as additional saleable items or quantities.
Existing item keys and image names remain unchanged.

## Quantity contract

For this first slice, each funded unit is in exactly one state: Inventory,
carried, or spent. Purchase increases Inventory only after the shared payment,
delivery and receipt transaction commits. Equipping transfers Inventory units to
carried quantity; unequipping reverses that transfer. Throwing decreases carried
quantity. Cleanup, native creation, reconnect and death restoration never create
units. Idle observations do not write or advance revisions.

Every mutation needs a durable operation receipt and expected revision. Replaying
a committed receipt returns its outcome without repeating payment or quantity
changes. Unknown transaction outcomes require readback, never blind mutation
replay. Tests model a three-unit capacity; the current controlled runtime remains
at its one-unit ceiling until its transaction and native paths are updated.

## Existing proof is not the production item model

The controlled Tomahawk code requires a persistent unique carrier item and funds
it from `ammo_tomahawk_regular`. Simply selling that carrier or enabling its
development switches would not implement the agreed purchase semantics.

The existing native pickup receipt establishes a bounded spend allowance, not
independent proof of the exact world projectile's origin. The projectile observer
also marks origin unconfirmed. Neither a pool increase, nearby object, matching
model nor a client-provided identity is enough to create a recovered unit.
Production recovery needs an authoritative eligibility contract; cross-player
pickup and disconnect/crash recovery remain unresolved. Do not enable the old
pickup gate as a substitute for that work.

## Implementation gates

1. Inventory owns the physical quantity and atomic transfers. Choose storage that
   does not leave a visible, transferable empty carrier representing a paid unit.
   Preserve established item keys; do not repurpose existing instances silently.
2. Wire normal paid issuance through the existing Shops transaction. Remove the
   separate Tomahawk ammunition offer when the actual-unit flow is enabled so
   players cannot buy two different representations of the same unit.
3. Bind native ownership to that quantity and fenced session identity. Empty
   quantity, partial materialization and uncertain cleanup must not grant units.
4. Add direct translated Equip/Unequip actions using each player's Settings
   language. Keep internal ledger, carrier and receipt details out of the menu.
5. Test rollback, lost reply, replay, capacity, last throw, empty reconnect,
   death/selection/logout, and verified recovery before exposing the catalog.

`tests/models/throwable_units.lua` is an executable conservation model, not a
runtime module. Its tests cover quantity transfers, depletion, stale revisions,
receipt conflicts/replays and refusal of unverified or twice-claimed recovery.
The model's `originVerified` field is a test precondition, not an implemented
server observer or a client permission flag.

## Staged Inventory storage component

Inventory's `server/services/native_throwable_unit_storage.lua` now implements
transaction-local carry, return and spend of actual unique Tomahawk instances.
It performs no startup writes. The released equipment export and reserved
ammunition observation now compose this component; it has no direct client route.
It uses the existing private character-collection schema and ammunition operation
receipt table; no additional schema is introduced. The existing one-unit carrier
runtime is unchanged and cannot be mixed into this three-unit storage contract.

Carried units move into a private three-slot collection. A spend moves the same
item into a separate private spent collection, preserving its identity pending a
reviewed recovery/retirement policy. Neither operation creates an extra carrier
or item. Return checks ordinary inventory acceptance and vacant slots before
moving the same item back. Item movement, carried ledger CAS and operation receipt
share the caller's transaction. Failed results must roll back the whole transaction.

The component validates source ownership, exact metadata and row revisions,
distinct serials, no existing equipment binding, collection identity, capacity,
current authority and post-move row state. An exact committed receipt can be read
back after the ledger advances without repeating a movement. Spent units cannot
be returned using the normal unload action. Receipt input conflicts refuse.

Tests execute the actual storage, collection resolver, ledger reader and
MoveInstance bodies against mocked transactional SQL/access ports. They cover
carry/return/spend rollback at movement, authority, ledger and receipt boundaries,
full or refused return, stale/foreign/bound/archived items, duplicate operation
readback, three-unit capacity and CFX callable-table authority. This is not live
database contention or native engine validation.

Still required before enabling gameplay: authoritative pickup eligibility; bounded spent retirement
and recovery across lifecycle boundaries; live lifecycle acceptance. Spent storage currently
refuses beyond 500 retained units. That staging bound is not a production solution
for ongoing throwables and must be resolved before enabling native throws.

## Carried accounting and native ownership components

Inventory now has a read-only contract-2 custody snapshot, bound to the current
character/session/epoch and exact ledger quantity. Reads do not create missing
collections. The shared Weapons projection accepts only that explicit physical
unit shape with a three-unit limit; the old one-unit carrier shape remains
separate. Empty custody produces no carrier approval.

Native ownership and the server lease bind all carried item IDs, revisions and
metadata, including secondary units. The concrete native adapter can restore the
approved quantity up to three, observe partial depletion, and clean up only its
captured GUID and remaining Tomahawk pool. The old carrier pickup allowance is
always disabled for physical-unit approvals. These are component changes, not
enabled normal runtime admission: `NativeThrowableUnitsEnabled` must explicitly
be true for the new mode. That field is not enabled in shipped configuration.

Carried collection weight now participates in Inventory's total display weight,
transactional add/checkout capacity and ordinary/greedy transfer and swap budgets.
The private rows contribute quantity caps without occupying public compartments.
Returning exact verified carried IDs discounts those units before testing their
arrival, preventing double-counting weight or quantity. Spent and unrelated private
collections are excluded. Accounting does not depend on a gameplay toggle, so
disabling admission cannot make retained carried weight disappear. It uses an
indexed character/purpose lookup when a budget is needed, without a new polling
loop or a mutable weight cache. Corrupt private policy refuses capacity reads.

Validation: full Inventory Lua suite and 242 Weapons isolated Lua specs pass.
New tests cover read-only custody, display/admission accounting, return neutrality,
definition caps, planner/swap budgets, secondary ownership changes and aliases,
native three-unit creation, partial/complete depletion, retained-pool cleanup,
and refusal of the old pickup credit. SQL and native boundaries are mocked;
live engine/MariaDB and end-to-end paid throwable gameplay remain pending.

## Connected backend flow

Physical-unit admission selects a three-unit policy independently of the old
developer carrier convar. Runtime snapshots carry the authoritative epoch into
Inventory's custody reader. Normal paid issuance prepares one pristine unique
Tomahawk instance with purchase provenance; it never funds an extra ledger unit.
The catalog adapter supports a physical `throwables` offer and suppresses the
separate Tomahawk ammunition offer in that mode. The shipped Tomahawk price stays
false; no new offer is exposed yet.

Equip/Unequip use the existing reservation, final seal, native cleanup and fresh
same-session restoration coordinator. Preparation identifies the exact public or
carried row. After release it rechecks equipment and refreshes the ledger revision
before committing final wear, the same physical instance movement, ledger CAS and
receipt in one Inventory transaction. A last throw can make an unequip selection
unavailable; that selection refuses instead of manufacturing a returned item.

Observed depletion now moves the highest stable IDs from carried to spent custody
and applies all reported ammunition decreases in one revision/transaction. A
short-lived server observation ticket permits only those selected private item
moves. Movement does not inherit metadata/equipment-write exceptions, and the
spend permission cannot authorize destruction. Provider failure freezes while
retaining the original ownership holds. Confirmed results rebind the lease to
the remaining unit prefix; idle reports do not write and stale reports cannot
spend twice. Private custody moves do not emit generic ItemMoved ownership facts;
their durable operation receipt records the actual state change.

Validation now includes full Inventory Lua and 243 Weapons Lua specs, plus 44
four-resource checkout composition scenarios. New coverage includes normal
DevMode=false physical equip/return through actual coordinator bindings, forged
released-ticket refusal, private candidate reads, combined firearm/throwable
depletion rollback, service ticket retirement/rebinding, paid Tomahawk replay and
insufficient-funds rollback. SQL/native/CFX boundaries remain modeled. No server
deployment or live feature enablement has been performed.


## 2026-11-12 player controls

Inventory now presents the requesting character's carried Tomahawks as a compact
row under item details: a translated equipped count and an Unequip one button.
The existing grid remains available for ordinary inventory units, which get a
direct Equip context action. Generic Use and Ammunition are hidden for Tomahawks.
The carried row uses no public compartment and includes its weight in the carrying
line. Pairing a storage/robbery book never exposes the other character's private
collection or identifiers. The payload contains only the player's unit IDs and
carried weight, without private inventory IDs or metadata.

Unequip one chooses the highest stable carried ID, reads fresh authoritative
options, and submits the existing scoped equipment action once. Duplicate clicks,
late replies, changed selection and lifecycle invalidation cannot reuse an action.
Success closes the panel automatically; uncertain results retain the existing
uncertainty presentation. There is no optimistic count decrement or item return.
Only a confirmed physical-unit restore reply requests an Inventory refresh, which
preserves the paired book and completes before acknowledging the NUI. Other
weapon actions do not gain an unnecessary inventory refresh.

New strings use the existing Core locale provider fed by feather-settings and
its locale-changed event, with English frontend fallback. Shops has a translated
Throwables category. Inventory's definition-only startup policy now covers30
native definitions, including Tomahawk, and changes only the old exact default
carrier description to a physical Tomahawk description. Custom descriptions are
preserved. Recipe seed agrees; do not reimport seed over an existing database.

Validation: full Inventory Lua,243 Weapons Lua specs,44 checkout composition
scenarios, four targeted UI contract files, UI lint/build, and six Recipe contracts
pass. The built production UI was rendered with an isolated local fixture;
three equipped units and their combined carrying weight fit the page. This is
layout review, not RedM engine acceptance. Preview artifact:
C:/coding/review-snapshots/throwables-ui-20261112/inventory.png.

No feature gate or shop price was enabled and no server deployment occurred.
Pickup recovery, spent retirement, uncertain-outcome/lifecycle acceptance and a
combined PowerShell test installer remain before live rollout.


## 2026-11-12 shared throwable recovery scope and spend evidence

The user selected recovery of other players' thrown Tomahawks as well as their
own. An own-session spend-credit increase alone is therefore insufficient for
the requested gameplay. Shared recovery must transfer a previously paid physical
instance, claim its world binding once, and update the collector's custody and
ammunition atomically. Never create a replacement unit from an unbound native
pool increase. The existing server observer remains diagnostic, not origin proof.

Implemented a pure physical spend-evidence builder for the confirmed Inventory
commit result. It conserves the same highest-ID unit selection as storage, checks
the full pre-spend custody snapshot, same session/epoch, consecutive ledger
revision, post-move item revisions and unchanged metadata. Multiple spent units
have separate item-specific keys. The existing projectile binding planner now
requires that physical key to match its item. Neither planner grants pickup
authority, performs SQL/native writes, or is wired to a new gameplay route.

Validation:244 isolated Weapons Lua specs pass, including partial/full/multiple
spends, combined ammunition decreases, stale/foreign identity, duplicate or sparse
unit lists, metadata/revision changes and mismatched projectile/unit bindings.
These are automated modeled-boundary checks, not RedM shared-pickup acceptance.

Remaining: server world-object correlation and lifecycle, durable shared claim
storage and atomic ownership transfer, collector native rebind, bounded spent
retirement, uncertainty/lifecycle tests, and the combined PowerShell installer.
The physical-unit feature and its shop offer remain disabled. No server files
were changed and no deployment or client restart is required for this work.


## 2026-11-12 durable shared pickup transaction groundwork

Implemented inactive Inventory internal native_throwable_shared_claim.lua with a
durable binding writer and a physical shared-claim transaction body. No manifest
entry, export, client route, polling worker or feature admission was added.
RecordBinding requires a trusted server world-lifetime/origin reservation callback
and an existing exact committed paid spend. Three indexed receipt identities
(projectile lifetime, origin event, paid item/revision) refuse duplicate bindings.
The existing inventory_grant_receipts schema is reused; no new schema or seed
import is needed for this groundwork. This writer does not establish world origin
by itself; a real observer/provider is still a prerequisite.

Apply locks donor/collector inventory headers in deterministic character order,
then the collector ledger and durable binding. It verifies the original spend,
private spent custody, canonical item identity/revision/metadata, lack of equipment
binding, collector access and carrying capacity. It moves the existing unique row
into the collector's three-slot carried custody and increments only the collector
ledger, recording the claim in the same transaction. Donor ammunition is not
rewritten and donor need not remain logged in. Own pickup uses the same flow.
Historical readback does not move or credit again after subsequent gameplay.
Private-to-private moves suppress generic nil-owner ItemMoved facts; explicit
origin/collector identities are retained in the durable claim. Normal ownership
provenance delivery integration remains pending with the live coordinator.

Physical spend receipts now persist the server character/session/epoch identity;
spend receipt readback requires that same identity. Previously incomplete receipts
without that identity cannot authorize the new shared claim; no automatic repair
or reinterpretation was introduced. The feature has not been deployed/enabled.

Validation: full Inventory Lua suite and97-file Lua syntax check pass. New specs
execute the real binding/claim and MoveInstance bodies with modeled SQL, capacity,
custody-reader and world-authority boundaries. They cover own/shared pickup,
competing collectors after serialization, duplicate world bindings, one/two/three
existing carried units, unchanged foreign ammo, stale metadata/revisions,
replacement sessions, callable-table authority, historical reply recovery, and
rollback on an exception or authority loss at every SQL boundary. These tests do
not claim real MariaDB concurrency or RedM world-object acceptance.

Remaining before normal gameplay: server world correlation/lifetime authority,
collector runtime reservation/native rebind and lease adoption, explicit ownership
provenance delivery, bounded spent retirement, real interruption/lifecycle checks,
and a combined PowerShell deployment/test batch. Shipped gates/prices are unchanged.
No server files were moved; no deployment commands or client restart are needed.


## 2026-11-12 decompiled pickup references and collector adoption

Reviewed local1491.50 multiplayer decompilation. fm_deathmatch_controller
func_240 identifies collection switches for w_melee_tomahawk01/02, and its
weapon/pickup mapping uses pickup_weapon_thrown_tomahawk_mp. fm_race_controller
func_256 reads network pickup hash-454144443 as8 RAGE slots (pickup handle,
player index, pickup type, model). short_update func_83/377 reads a distinct
AI pickup hash-178091376 as8 slots. fme_archery func_532/790 supplies a separate
six-slot impact-event lead, not a demonstrated projectile network ID. Details,
local references, source fingerprints and interpretation limits are recorded in
feather-weapons/docs/throwable-world-research.md. No decompiled source copied
into runtime.

Implemented a build1491-only diagnostic decoder and explicit default-off bounded
client capture command. It filters Tomahawk-related pickup events, keeps AI and
network layouts separate, and interprets no unknown field as a projectile ID.
The probe reads at most64 events per queue/frame, retains at most32 records,
expires after30 seconds/3600 frames and stops after16 read failures. It performs
no networking, SQL, native grants, deletion or collection-permission switches.
It is manifest-listed, so the eventual combined installer/handoff must require
refresh before restart. No deployment has occurred; no commands are needed now.

Implemented shared physical claim-result validation and collector lease adoption.
Exactly one paid unit may be added to empty/partial custody; existing metadata,
identity and foreign pools remain exact, and companion item aliases refuse.
Confirmed historical replies can finish one pending adoption; repeating an
already-adopted snapshot refuses. The native owner/concrete adapter now support
read-only GUID recapture of an already collected Tomahawk, including empty
custody and a changed lowest-ID anchor. Native quantity/full-pool readback,
model/GUID and current owner are checked; no weapon/ammo grant is used. These
methods are not yet connected to a physical pickup route; default-off feature
and old carrier policy remain unchanged.

Validation:247 isolated Weapons Lua specs pass and git diff whitespace checks
pass. New tests cover reference layout/build/queue/size isolation, bounded probe
capture and failure/epoch/overlap handling, exact claim receipts, empty/partial
collector leases, repeated/stale/alias refusal, actual native-adapter body with
modeled engine calls, read-only recapture and wrong-model refusal. No live RedM
pickup event or world-origin correlation is claimed. The next engine evidence
needed is whether native thrown-object collection emits these events and how its
pickup handle links to the server-observed world lifetime. Durable shared claim
wiring, ownership delivery, retirement and live lifecycle/uncertainty acceptance
remain pending.


## 2026-11-12 coordinated server world-capture reports

Added a console-only, default-off WeaponThrowableWorldCapture orchestration path
for the read-only client probe. It challenges one exact active native owner and
collects bounded client rows plus server projectile-start/entity-created samples
into native-throwable-world-capture.json. No Inventory provider, SQL operation,
weapon/ammunition grant, world deletion, released-owner transition or pickup
claim is performed. This is evidence capture, not a temporary-loan test or a
normal throwable acceptance pass. The proposed temporary-loan path remains
unconnected because an uncollected test projectile still needs an exact world
cleanup policy. No test Tomahawk is automatically lent by this implementation.

Report transport uses bounded four-row packets and at most three diagnostic
packet-delivery attempts. Acknowledgements follow server file write/readback;
file failures/exceptions cannot turn a retransmission into a false success.
Duplicate recent challenges cannot start a second client observation window.
Source, ticket, sequence, character session and native epoch are checked.
Unsupported/failed client preflight, operator cancellation, timeout and restart
leave diagnostic review evidence without automatic resumption or state repair.
Existing reports are archived before a new capture, including unreadable prior
raw evidence. The capture gate is reset on startup and completion/timeout.

The client now reads the game's looting pickup target at most once per100ms,
and resolves a collected network event's pickup handle where it still exists.
Only the known Tomahawk reference models are retained. Entity/model/network
readbacks are checked twice; non-networked objects never receive a network-ID
query. There are no broad prop scans or requests for entity control. Identity
changes across reads terminate the observation window. Optional unavailable
native readers do not invent data.

The server retains separate per-creation lifetime labels and removed events.
Client network/model references are joined to server samples as diagnostic
candidateMatches only. Reused network IDs which match multiple lifetimes are
explicitly ambiguous. Every candidate remains originConfirmed=false and no
record supplies an economic entitlement. The root result is captured or
review_required, not a shared-pickup approval. Server-native/sample and client
reference facts remain distinguishable in the saved report.

Validation:249 isolated Weapons Lua specs pass. Coverage includes current-owner
and console/opt-in gates, malformed/foreign/out-of-order reports, bounded capture
and packet counts, source-checked acknowledgement, file-before-ack ordering,
storage exceptions/failure, report-only retries, duplicate challenges, targeted
native-reference reads, owner changes, deterministic candidate joins and network
ID reuse ambiguity. Engine/file/network ports are modeled; no live RedM capture
has occurred. New server/client scripts are manifest-listed; the eventual
combined deployment requires refresh before restart. No server deployment or
normal feature/catalog activation occurred in this step.

Next: package an appropriate scoped live test once a funded/isolated throwable
is available, inspect its engine evidence, finish the actual shared-pickup
reservation/commit/native-ack route and ownership delivery, and complete spent
retirement/lifecycle/uncertainty checks. Do not advertise recovery as usable yet.


2026-11-12 remote dev inspection: viewed the existing authenticated HeidiSQL
session for feather_dev through Remote Desktop and ran a SELECT-only join of
inventory_items/items/inventory for weapon_thrown_tomahawk (limit10). Result:
zero rows. The existing Feather-Dev console showed zero connected players.
No item, currency, schema, configuration or server-resource change was made.
This confirms that a canonical funded fixture or a safely isolated native test
must be prepared before the first meaningful live throw/pickup capture. The
read-only report command deliberately does not manufacture that prerequisite.
