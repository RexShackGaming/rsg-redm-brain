# rsg-banking

Version 3.1.0. rsg-banking - individual branch banks across the frontier

Branch banking for RSG-Core (RedM). Every town bank is its own institution: money deposited in Valentine can only be withdrawn in Valentine, unless it is wired to another branch for a fee. - Six branches: Valentine, Rhodes, Saint Denis, Blackwater, Armadillo, Strawberry (configurable) - Players open an account at each branch before using it (optional cash fee)

Source: https://github.com/Rexshack-RedM/rsg-banking

**Dependencies:** `rsg-core`, `rsg-inventory`, `oxmysql`

Has NUI (`ui_page`).

## Exports (call as exports['rsg-banking']:Name)

**server:** `AddBranchMoney(citizenid, bankId, amount, note)`, `AddHomeMoney(cid, amount, note, txType)`, `GetBranchBalance(citizenid, bankId)`, `GetCreditScore(citizenid)`, `GetHomeBranch(cid)`, `GetLoans(citizenid)`, `GetLockboxItems(citizenid, bankId)`, `GetTotalBalance(citizenid)`, `HasAccount(citizenid, bankId)`, `HasActiveLoan(citizenid)`, `IsBranchLocked(bankId)`, `LockBranch(bankId, seconds, reason)`, `RemoveBranchMoney(citizenid, bankId, amount, note)`, `SweepCoreBank(src)`, `UnlockBranch(bankId)`

## Net events registered

**client:** `RSGCore:Client:OnPlayerUnload`, `rsg-banking:client:branchLock`, `rsg-banking:client:open`

## Event handlers

**server:** `RSGCore:Server:OnMoneyChange`, `RSGCore:Server:PlayerLoaded`, `rsg-banking:server:lockBranch`, `rsg-banking:server:unlockBranch`

## Commands (RegisterCommand)

**server:** `/bankinterestnow`, `/bankwebhooktest`

## Database tables

`rsg_bank_accounts`, `rsg_bank_business_members`, `rsg_bank_credit`, `rsg_bank_home`, `rsg_bank_loans`, `rsg_bank_lockbox_items`, `rsg_bank_lockboxes`, `rsg_bank_meta`, `rsg_bank_transactions`
