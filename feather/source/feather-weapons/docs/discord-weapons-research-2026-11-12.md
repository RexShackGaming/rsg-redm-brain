# Cfx Discord Weapons research — 2026-11-12

Read-only UI search of the user's authenticated Cfx Community Discord. Channels:
redm-research (643437867044962304), redm-scripting (643437814104457217).
No messages, reactions, uploads or account/settings changes were made.

This is a focused search pass, not an exhaustive channel export. Search terms
included tomahawk, projectile, weapon, pickup, GUID, network weapon, networked,
NetworkGetEntityFromNetworkId and GUID weapon. Reviewed relevant search results,
two pickup-result pages, and surrounding context for the server lookup and
clip-GUID discussions. Broad searches had unrelated matches (e.g. GUID/guide).
Community descriptions are research leads, not automatic gameplay authority.

## 1. Server lookup can fail despite client networking status

MrEaqz, redm-scripting, 2024-07-07: reports a cart with a correct client network
ID and networked status while server NetworkGetEntityFromNetworkId returns0;
the same approach works with peds. Replies advise waiting for entity existence
and NetworkGetEntityIsNetworked. No confirmed resolution was visible in the
surrounding conversation inspected.

- Report: https://discord.com/channels/192358910387159041/643437814104457217/1259471062341783625
- Existence advice: https://discord.com/channels/192358910387159041/643437814104457217/1259476244680933378
- Networking advice: https://discord.com/channels/192358910387159041/643437814104457217/1259476848207986800

Relevance: our last live client already double-checks existence/model/network
ID. This supports investigating readiness and replication, not assuming the
advice fixes our Tomahawk lookup or granting items from a client-only ID.

## 2. Shared dropped-weapon duplication warning

A 2020-09-20 turbomodus report describes dropped torch objects: the dropping
client could delete/re-grant its torch, but another player received a new torch
without deleting the original dropped object. The author suspects ownership.
Message ID757351832086511740, found in the two requested channels' pickup
search. Surrounding replies and exact channel mapping were not inspected;
do not treat the author's ownership explanation as a confirmed engine rule.

Relevance: preserve the no-grant-on-unconfirmed-world-removal/single-claim
requirements. Do not transplant a naive delete-and-regrant implementation.

## 3. Projectile readers and bullet-only functions

Research message by Sarbatore (2026) reports testing these as bullet-only,
with no effect for arrows/throwable projectiles:
0xDC416CA762BC4F43, 0x7A76104CC2CC69E8, 0x970339EFA4FDE518.
https://discord.com/channels/192358910387159041/643437867044962304/1491743182256345183

Kadir Aktas, 2025-11-09: projectile volume-reader example
0x74C8000FDD1BB111 (ignited explosive projectiles), references the general
0x74C8000FDD1BB222 projectile-in-volume reader. Ignited-only lookup is not
sufficient for an ordinary Tomahawk.
https://discord.com/channels/192358910387159041/643437867044962304/1437038763653075073

Related projectile effect-radius note references
GET_PROJECTILE_OF_PROJECTILE_TYPE_WITHIN_DISTANCE:
https://discord.com/channels/192358910387159041/643437867044962304/1437029153076543539

Relevance: cross-check signatures and decompiled usage before evaluating a
narrow client projectile lookup instead of generic CObject snapshots. These
are client diagnostic candidates and do not solve server visibility/ownership.

## 4. GUID-based ammo query

Two research examples identify0x4823F13A21F51964 as total ammo queried through
a weapon GUID, obtained either from inventory item GUID lookup or attach point
0x6929E22158E52265. One description notes a false-like result for zero ammo.

- Outsider, 2026-05-07:
https://discord.com/channels/192358910387159041/643437867044962304/1502036250436304986
- Sarbatore, 2025-07-22:
https://discord.com/channels/192358910387159041/643437867044962304/1397103387740471418

Relevance: potential readback/cross-check for individual native entries. Do not
assume this is independent ownership or clip storage: the descriptions say total
ammo and need verification against our shared-pool and same-model pair behavior.
Search previews were read; the full snippets were not executed or installed.

## 5. Zero ammo can hide, rather than remove, a weapon

Outsider, 2026-06-18: inventory enumeration example checks owned weapons for an
ammo type, including hidden zero-ammo thrown dynamite. Describes persistent
native weapon ownership even when the weapon wheel does not show the weapon.
https://discord.com/channels/192358910387159041/643437867044962304/1517293258915708988

Relevance: supports our existing exact GUID absence/cleanup checks. A zero ammo
count or missing wheel entry must not be treated as proof of complete cleanup.

## 6. Weapon locker UI example

Sarbatore, 2026-08-19: shares native WEAPON_LOCKER UIapp/databinding example,
with a157-line plaintext attachment and video preview. The existence/preview
was read; attachment contents were not fully opened or downloaded.
https://discord.com/channels/192358910387159041/643437867044962304/1539695811485638806

Relevance: future storage/management UX reference. No proposal to replace the
current simple Inventory equipment UI without a separate design decision.

## 7. Clip GUID remains an open question in inspected discussion

r4venw, redm-scripting, 2023-03-02: asks for a clip-ammo setter by GUID and
investigates _REFILL_AMMO_IN_CLIP. Later reports failure and suspects the second
parameter is a clip inventory-item GUID, rather than a weapon GUID. Read the
surrounding messages; no working setter solution appeared there.
https://discord.com/channels/192358910387159041/643437814104457217/1081044555073331232

Relevance: keep weapon/clip GUID semantics distinct. This is not a verified API
signature or a proven fix for dual-weapon reload distribution.

## 8. Throwable attack task is not recovery

Kadir Aktas, 2025-10-09 documents0x2416EC2F31F75266 for forcing throwable/bow
attacks while aiming. Description excludes lasso/bolas.
https://discord.com/channels/192358910387159041/643437867044962304/1425941624512577648

Relevance: possible later NPC/testing behavior. It supplies no projectile
lifetime, paid ownership, collector authentication or exactly-once recovery.

## Current conclusion and next work

No verified shared-Tomahawk recovery recipe or direct fix for our server lookup
was established by this pass. The useful immediate leads are readiness/replication
checks and precise client projectile queries, while maintaining all durable
claim and conservation requirements. Latest live result: native case1/1,
cleanup/restoration true; server unconfirmed, callbacks23created/72removed/
0projectile, one hint received but not resolved. Rejections: entity_missing1,
model_mismatch_0 five, entity_type_1 fifty-nine. Cfx server source classifies
ped/animal/horse as1 and objects/pickups/WorldProjectile as3, so type1 rejection
must not simply be relaxed to admit peds as throwable objects. Reference:
https://github.com/citizenfx/fivem/blob/master/code/components/citizen-server-impl/src/state/ServerGameState_Scripting.cpp

No runtime edits, deployable batch or new live test requested by this research
step. Keep read-only readiness retries distinct from economic mutation retries.
