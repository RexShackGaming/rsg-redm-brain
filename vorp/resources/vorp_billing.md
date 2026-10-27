# vorp_billing

Version 0.2. Vorp billing system

The `vorp_billing` script is a customizable billing system for VORP Core. Allowing specific jobs to charge players in-game. It includes options for on duty checks, receipt issuance, and negative billing restrictions. Use the `/bill` command to initiate charges. - Add `receipt` item to database (You can add the desired item from `Billing.ReceiptItem`)

Source: https://github.com/VORPCORE/vorp_billing

## Net events registered

**server:** `vorp_billing:server:SendBill`

**client:** `vorp_billing:client:openMenu`

## Event handlers

**server:** `vorp:SelectedCharacter`
