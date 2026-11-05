# Dedicated database recovery boundary runner

2026-11-01 LIVE standalone provider boundary acceptance confirmed from remote
PowerShell output, Node26.13, fixture feather_recovery_8d8bf1abc3689d78:
PASS real COMMIT reply loss (public caller unknown, independent row committed
once, no retry); PASS abrupt worker death (connection gone, independent row
unchanged, no retry); Fixture cleanup confirmed, prompt returned. Earlier failed
attempt remains historical harness-boundary error, not this result. Inventory
fixture229 was not involved. This accepts deterministic committed-but-reply-lost
and uncommitted worker termination at provider boundary; whole database/RedM
crash, arbitrary COMMIT interruption timing, and end-to-end durable inventory
reconciliation/production rollout remain separate pending scope.

2026-11-01 remote diagnostic SELECT passed with no leftover fixture tables.
Full attempt then failed at commit_reply_loss/ERR_ASSERTION; fixture cleanup
confirmed, worker-death test not reached. Inspection found a harness boundary
error: raw mysql2 transport errors need publicError classification, as in the
actual CFX bridge. Standalone runner assertion corrected; provider runtime
unchanged. All130 provider/proxy regressions pass. Corrected live test pending;
neither boundary gate is accepted from the failed attempt.

2026-11-01 live attempt on remote Windows/Node26.13: dependencies installed;
runner printed fixture feather_recovery_497e34d01dc4f274 then generic FAIL,
without either PASS line. Failure stage and table cleanup were not established;
do not count this as acceptance or blindly rerun. Runner now reports only a
safe stage/code and explicit cleanup confirmation. `node tests/recovery_boundary_windows.js --check`
uses SELECT-only connection/table inspection (same private environment setup),
with no fixture creation, worker or fault injection. Inspect leftovers before
any future full run. This diagnostic update has syntax checks only; real check pending.

Implemented and regression tested; the dedicated live boundary run above passed.
The commands below are an explicit developer rerun, not a routine installation step.
Run outside RedM using Node 20+ and the locked mysql2 dependency (`npm ci` in
the feather-mysql directory). No resource changes, client resets or restarts.
Use the dedicated test database account with CREATE/DROP TABLE and normal data
permissions. The runner creates a randomly named InnoDB table, never touches
inventory_items, and drops only that generated table in final cleanup. It prints
the table name for inspection if interrupted. Never blindly rerun after failure.

PowerShell, in the local feather-mysql directory:

```powershell
npm ci
$recoverySecret = Read-Host 'Dedicated test database connection string' -AsSecureString
$env:FEATHER_RECOVERY_URL = [System.Net.NetworkCredential]::new('', $recoverySecret).Password
$env:FEATHER_RECOVERY_DEDICATED = 'YES'
try {
    node tests/recovery_boundary_windows.js
} finally {
    Remove-Item Env:FEATHER_RECOVERY_URL -ErrorAction SilentlyContinue
    Remove-Item Env:FEATHER_RECOVERY_DEDICATED -ErrorAction SilentlyContinue
    $recoverySecret = $null
}
```

Enter the connection string privately in the prompt; never paste it into chat.
It supports the existing feather-mysql URI or semicolon syntax. TLS connections
are refused: do not weaken an existing TLS configuration to run this harness.
The loopback proxy needs local networking permission and the PC needs access to
the dedicated database host. The database service stays running throughout.

Expected two PASS lines:

1. Real COMMIT reply loss: actual provider Driver sends one COMMIT through the
   proxy; server response is consumed but withheld; provider must return unknown.
   Independent direct SQL sees value101, proving commit without a caller reply.
2. Abrupt worker death: child uses the actual Driver, updates value200 in an open
   transaction, reports its connection ID, then the parent kills that child.
   After PROCESSLIST confirms connection absence, independent SQL must still see
   value101, proving the uncommitted update did not survive. No retries.

Do not call this arbitrary in-flight COMMIT interruption, whole database crash,
RedM server crash, or end-to-end inventory journal recovery. The lost reply test
deliberately waits for the server response before cutting the connection, so it
exercises the committed-but-caller-unknown branch deterministically. Full service
crash durability remains a separate gate. None of these tests changes fixture229.
