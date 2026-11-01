# vorp_paycheck

Version 0.2. Paycheck System

An optimised secured system using classes and supporting statebags to allow jobs to be paid for their time worked. - add to your server/resources.cfg `ensure vorp_paycheck` - unique job names and multiple grades per job

Source: https://github.com/VORPCORE/vorp_paycheck

## Event handlers

**server:** `vorp:SelectedCharacter`, `vorp:playerGroupChange`, `vorp:playerJobChange`

## Public (table) functions

**server/main.lua:** `Paycheck:new(source, amount, isOnDuty, currency)`, `Paycheck:Pay()`, `Paycheck:Pause()`, `Paycheck:ChangeAmount(amount)`, `Paycheck:Resume()`, `Paycheck:Destroy()`, `Paycheck:HandlePaymentThread()`
