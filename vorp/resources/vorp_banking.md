# vorp_banking

Version 1.9. Bank system VORP

Bank Script made for VORP Core. - Place `vorp_banking` into your `resources` folder - Add `ensure vorp_banking` to your `server.cfg` / `resources.cfg` file

Source: https://github.com/VORPCORE/vorp_banking

## Callbacks (VORP Core.Callback.Register)

**server:** `vorp_bank:getinfo`

## Server events it triggers in other resources

**client:** `vorp_bank:UpgradeSafeBox`, `vorp_bank:depositcash`, `vorp_bank:depositgold`, `vorp_bank:transfer`, `vorp_bank:withcash`, `vorp_bank:withgold`

## Database tables

`bank_users`
