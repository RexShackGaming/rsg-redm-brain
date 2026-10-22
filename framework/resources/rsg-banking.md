# rsg-banking

Version 3.0.2. rsg-banking - individual branch banks across the frontier

Branch banking for RSG-Core (RedM). Every town bank is its own institution: money deposited in Valentine can only be withdrawn in Valentine, unless it is wired to another branch for a fee. - Six branches: Valentine, Rhodes, Saint Denis, Blackwater, Armadillo, Strawberry (configurable) - Players open an account at each branch before using it (optional cash fee)

Source: https://github.com/Rexshack-RedM/rsg-banking

**Dependencies:** `rsg-core`, `ox_lib`, `oxmysql`

Has NUI (`ui_page`).

## Exports (call as exports['rsg-banking']:Name)

**server:** `AddBranchMoney(citizenid, bankId, amount, note)`, `AddHomeMoney(cid, amount, note)`, `GetBranchBalance(citizenid, bankId)`, `GetHomeBranch(cid)`, `GetLoans(citizenid)`, `GetLockboxItems(citizenid, bankId)`, `GetTotalBalance(citizenid)`, `HasAccount(cid, bankId)`, `HasActiveLoan(citizenid)`, `RemoveBranchMoney(citizenid, bankId, amount, note)`, `SweepCoreBank(src)`

## Net events registered

**client:** `rsg-banking:client:open`

## Event handlers

**server:** `RSGCore:Server:OnMoneyChange`, `RSGCore:Server:PlayerLoaded`

## Callbacks (lib.callback)

**server:** `rsg-banking:server:buyLockbox`, `rsg-banking:server:deposit`, `rsg-banking:server:getData`, `rsg-banking:server:lockboxDeposit`, `rsg-banking:server:lockboxWithdraw`, `rsg-banking:server:openAccount`, `rsg-banking:server:repayLoan`, `rsg-banking:server:setHome`, `rsg-banking:server:takeLoan`, `rsg-banking:server:transfer`, `rsg-banking:server:upgradeLockbox`, `rsg-banking:server:withdraw`

## Commands (RegisterCommand)

**server:** `/bankwebhooktest`

## Database tables

`rsg_bank_accounts`, `rsg_bank_home`, `rsg_bank_loans`, `rsg_bank_lockbox_items`, `rsg_bank_lockboxes`, `rsg_bank_meta`, `rsg_bank_transactions`
