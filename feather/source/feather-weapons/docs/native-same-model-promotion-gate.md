# Controlled same-model broken-primary promotion gate

FINAL cleanup: maintenance at epoch19444822:4 reports155rev3 unchanged prior
wear and158rev5 pristine after requested offhand restoration. No independent
restoration entity/slot/ammo snapshot claimed. Temporary fixture method/command
removed locally; retirement regression requires hook/flag absent.137 Lua specs/
client syntax+7 Node PASS. Deploy Weapons ONLY client/character_ammunition_native_owner.lua
and client/character_ammunition_startup.lua after aggregate drain/PASS/stop and
ensure; no refresh/new runtime script/manifest/config change. Keep flag0.
Retained audit JSON and Inventory promotion-aware audit remain. No further
gameplay break test needed for retirement; deployment pending.

Repair cleanup accepted:158rev4/oil1/eligible ->WeaponNativeRepair PASS material
payment/CAS/fresh restore, TX:3934 COMMIT14queries/no ammo economic writes ->
158rev5 weapon_already_serviced.155 left primary. Optional158 offhand restore
and temporary fixture removal remain pending; no independent repair audit claim.

LIVE periodic same-model promotion gate COMPLETE: verify-promotion-wear against
retained same-model-promotion-v1 PASS revision4/changedtrue/promotionVerifiedtrue/
promotedItemId155/equipmentUnchangedfalse/ammoUnchangedtrue/materialConsumed0/
noEconomicWrites. Exact assignment and full baseline conservation accepted.
158 repair/optional offhand restoration and hook retirement are cleanup pending.
Fixture remains0; no repeat break. No death-time same-model/customized/crash claim.

Promotion-aware audit now implemented/automated in Inventory, live pending.
Deploy existing server/services/native_repair_verify.lua and native_repair_audit.lua
after aggregate Weapons drain/PASS/stop. Preserve private audit JSON in Inventory;
restart Inventory/dependents and Weapons. No manifest/refresh delta. Keep fixture0.
Then server console (use current John ID):
InvNativeRepairAudit 3 4560a489-ca6c-11f1-9ad4-e0d55eaa2deb 158 verify-promotion-wear same-model-promotion-v1
This SELECT-only mode checks exact expected assignments separately, then all
ordinary monotonic wear/identity/item/material/ledger/operation/grant checks.
Ordinary verify-wear is not relaxed. Expect promotionVerified=true,
promotedItemId=155, revision4, equipmentUnchanged=false, ammoUnchanged=true,
materialConsumed0. Do not claim acceptance or repair until actual output.

Latest live confirmation: SQL screenshot exactly one John assignment weapon155,
no offhand/158. Observed periodic same-model promotion accepted alongside durable
158rev4 broken and unchanged155rev3 native primary readback. Jane ACTIVE idle
2copies/ledger35/repeater1/others0 epoch18039985:1; expected observer status
preserved, no fresh pre-fixture observer baseline for exact epoch/wear invariance.
Full promotion-aware metadata/material/economic conservation audit pending;
ordinary verify-wear correctly refuses changed assignments. Keep baseline and
broken158 untouched until that audit; fixture flag0, no repeat fixture/grants.

Durable158 repair snapshot now confirms revision4/condition0/degradation1,
soot unchanged/other wear0, oil0. Ordinary verify-wear refused 'Wear changed
equipment.' CompareWear requires unchanged equipment by design and stops there;
it cannot prove intended promotion or remaining conservation checks. Retain
baseline; do not overwrite/relax generic verifier. Exact durable equipment and
promotion-aware audit plus Jane observer remain pending. No full audit accepted.

Live progress: fixture PASS158rev3 degradation1/other wear unchanged,155rev3
unchanged. Flag disabled0. Inventory TX:3729 COMMIT21queries and periodic wear/
checkpoint PASS. John new epoch18298823:3 ACTIVE idle1copy/ledger3/all ammo0;
155rev3 same wear, tracked entity9132290 primary point2/offhand3 absent. Native
promotion observed; durable158 repair/audit and Jane observer readback pending.
New reconstructed entity is not same-epoch GUID adoption.

2026-10-17 IMPLEMENTED/automatically tested; live break/promotion PENDING.
John3 durable capture-wear same-model-promotion-v1 PASS item158 revision3,
noEconomicWrites. Pair baseline158/155 revision3 has distinct tracked entities
at primary2/offhand3, both degradation0.00333333341404/soot0.00499999988824,
other wear0. Diagnostic GUIDs are not ownership/adoption authority.

Temporary F8 `weaponNativeSameModelPromotionFixture`, default-off replicated
`feather_native_same_model_promotion_fixture`, targets only John CID
4560a489-ca6c-11f1-9ad4-e0d55eaa2deb, exact158 issuance serial and155 fixture
serial, both rev3, plain holstered Cattlemen at points2/3. Requires idle live
owner, lifecycle wear enabled, ledger3/acknowledged and actual pools all0.
Only setter: primary tracked object degradation1.0. Independent five-field
readback requires sibling unchanged and primary other wear unchanged. One setter
attempt per owner, including exceptions/ineffective results; no retry on uncertain
outcome. No SQL/ammo/material calls or automatic checkpoint/repair/grant.
Normal periodic wear must establish the separate durable detach/promotion gate.
Native readbacks are not durable commit evidence.

137 Lua specs/runtime syntax and7 Node checks PASS. Refusal tests include disabled
flag, busy/fault, ledger/ammo mismatch, different identity/revision/serial/slot,
drawn layout, wear drift, ineffective setter and sibling corruption.

Deployment: Weapons ONLY, existing files client/character_ammunition_native_owner.lua
and client/character_ammunition_startup.lua. No manifest change/new runtime file;
no refresh required for this delta. Keep custom configs unchanged. Before stop:
setr feather_native_same_model_promotion_fixture 0; WeaponNativePrepareStopAll;
wait aggregate PASS/status ready; stop Weapons, copy both files, ensure Weapons.
Do not stop after refusal. Re-read John's current ID, status, maintenance/entity
pair and verify captured baseline remains applicable before enabling fixture.
No grant/funding/repair needed for setup. Runtime restart changes epoch/entities.

Only after baseline review: setr feather_native_same_model_promotion_fixture 1;
John invokes command once; immediately setr flag0; retain output. If refusal,
do not retry or overwrite audit baseline. Follow with periodic persistence log,
status/maintenance/entity readback, durable audit and repair snapshot for158.
Expected155 promoted primary unchanged,158 broken durable rev4/unequipped,
ammo all0/ledger3; verify rather than assume. Jane observer must stay isolated.
Remove temporary hook after acceptance. No crash/customized-pair/death gate claim.
