# PART 4 – AI Processing Instructions

When given a script + this rules file, the AI must:

### Step 1 – Security Audit
- List every money/item add/remove location
- Rate each as CRITICAL / HIGH / MEDIUM / LOW
- Provide exact fixed code for every CRITICAL & HIGH issue

### Step 2 – Notification Conversion
- List every old notification call found
- Show the exact replacement using `lib.notify` / `ox_lib:notify`
- Ensure the text is moved to a locale key

### Step 3 – Locale Conversion
- Extract all player-facing strings
- Generate a clean, valid `locales/en.json` (and optionally other languages)
- Convert any existing Lua locale files to JSON
- Update fxmanifest (`files { 'locales/*.json' }`) and add `lib.locale()`
- Show the updated code using `locale('key')`

### Step 4 – Final Summary
Provide:
- Overall security risk (Critical / High / Medium / Low / Secure)
- Number of notifications converted
- Number of strings moved to locales
- List of files that need changes
- Ready-to-paste code blocks for the most important fixes

---

# Quick Reference – Preferred Modern Style (Secure + ox_lib + Locales)

```lua
-- Server event (secure + ox_lib + locales)
RegisterNetEvent('myresource:server:buyItem', function(itemName, amount)
    local src = source
    local Player = RSGCore.Functions.GetPlayer(src)
    if not Player then return end

    amount = tonumber(amount)
    if not amount or amount < 1 or amount > 50 then return end
    if not RSGCore.Shared.Items[itemName] then return end

    local price = Config.Items[itemName] and Config.Items[itemName].price
    if not price then return end

    local total = price * amount
    if Player.Functions.GetMoney('cash') < total then
        TriggerClientEvent('ox_lib:notify', src, {
            title = locale('shop_title'),
            description = locale('not_enough_money'),
            type = 'error',
            duration = 5000
        })
        return
    end

    if not exports['rsg-inventory']:CanAddItem(src, itemName, amount) then
        TriggerClientEvent('ox_lib:notify', src, {
            title = locale('shop_title'),
            description = locale('inventory_full'),
            type = 'error',
            duration = 5000
        })
        return
    end

    if Player.Functions.RemoveMoney('cash', total, 'shop-purchase') then
        exports['rsg-inventory']:AddItem(src, itemName, amount, nil, nil, 'shop-purchase')
        TriggerClientEvent('ox_lib:notify', src, {
            title = locale('shop_title'),
            description = locale('bought_success', amount, RSGCore.Shared.Items[itemName].label, total),
            type = 'success',
            duration = 5000
        })
    end
end)
```

---

