# vorp_billing
---

The `vorp_billing` script is a customizable billing system for VORP Core. Allowing specific jobs to charge players in-game. It includes options for on duty checks, receipt issuance, and negative billing restrictions.

Use the `/bill` command to initiate charges.

## Installation
- Add `receipt` item to database (You can add the desired item from `Billing.ReceiptItem`)
- `ensure vorp_billing` in your `server.cfg`

## Features

**Flexible Billing Options;** 
- Control where billed money goes: either to the billing job/player or nowhere
- Job and grade restrictions on charge/billing
- Option to allow or restrict billing players who lack sufficient funds
- Specify the maximum billable amount (`Billing.MaxBillAmount`)

**Receipt System;** 
- Issue a receipt item (`Billing.ReceiptItem`) for each transaction, configured in your database

**On-Duty Requirement;** 
- Allows specific jobs to bill only when on duty, with a built-in check compatible with [vorp_police](https://github.com/VORPCORE/vorp_police) and [vorp_medic](https://github.com/VORPCORE/vorp_medic) (Check `Billing.GetIsOnduty` Function)

---
[VORP Core Discord](https://discord.gg/JjNYMnDKMf)
