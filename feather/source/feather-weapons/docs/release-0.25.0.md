# Weapons0.25.0 release notes

Regular arrows now use the current native GUID-owned Bow and character ammunition
ledger. Enable with `setr feather_regular_arrows 1` before resource startup, paired
with Inventory0.17.0 and Shops0.5.0. The option defaults off. Preserve this startup
setting while using the saved arrow pool; disabling it is not a data migration.

- Own the Bow as a normal serialized weapon, with Regular arrows conserved as a
  character quantity up to40. Native pickup never issues a bow or extra native ammo.
- Recover funded arrows through separate, once-only, same-bucket allowances
  within180seconds and50metres, including bounded shared recovery by other bow owners.
- Use correct Bow carry points: Shoulder8 and Back7. Firearm mappings stay unchanged.
- Buy the configurable $5 Bow and unchanged $0.50 five-arrow packs through the
  normal authoritative Shops checkout, with a localized Bows category.
- Preserve existing item names, historical serialized items and receipts. No
  automatic conversions, grants, refunds or SQL schema migration are included.

Local verification:309 Weapons Lua suites/syntax,7 JavaScript checks, full paired
Inventory Lua suite/version verification and44 Shops composition scenarios pass.
Live acceptance covers own/batched/shared Regular-arrow recovery, recipient
reselection/draw, exact unload/reload, loaded death/revive/resource restoration,
both carry positions, 40-arrow capacity controls and nearby headroom recovery.
Latest Jane state:40arrows/3Tomahawks/100revolver rounds, shared ledger81.

Limits: specialty arrows remain outside admission; simultaneous increases of
arrow and Tomahawk pools fail closed. Native events are observations, not exact
projectile ownership proof. A modified client may consume an available nearby
funded allowance, but saved recovery cannot exceed those allowances. Live
competing-collector contention and arrow-specific rejection scenarios remain
modeled rather than live accepted. Literal crashes/in-flight SQL interruption
are not covered by the orderly lifecycle results.

Release preparation: Inventory v0.17.0, Shops v0.5.0, then Weapons v0.25.0.
Weapons and Inventory PRs must cross-link the paired changes. The user pushed
Weapons implementation e3d60a0 and Inventory implementation ec9c5a9; both PRs are
open for review with green checks on those heads. Local CI pin follow-ups now
select these exact paired implementations, pending user commit/push and new CI.
The user handles all commits, pushes, PR ready/merge actions, tags and releases.
No GitHub release or CI result for the unpushed pin follow-ups is claimed here.
