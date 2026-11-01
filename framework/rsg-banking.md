# rsg-banking v3 exports
`HasAccount(cid)`, `GetBranchBalance(cid, bankId)`, `GetTotalBalance(cid)`, `AddBranchMoney(cid, bankId, amt, note)`, `RemoveBranchMoney(cid, bankId, amt, note)`, `GetHomeBranch(cid)`, `AddHomeMoney(cid, amt, note)`, `GetLoans(cid)`, `HasActiveLoan(cid)`, `GetLockboxItems(cid, bankId)`.

`bank` money type is legacy: it forwards to the player's home branch. Use these exports in new code. Society accounts are NOT supported.
