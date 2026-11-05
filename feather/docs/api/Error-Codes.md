---
title: Stable Error Codes
description: Machine-readable Feather Framework error codes grouped by owning resource.
---

# Stable error codes

Use error codes for program logic and localization. Messages are developer-facing summaries and may become clearer over time; do not compare or parse message text.

This page is the maintained registry for stable public error codes. Codes are grouped by the resource that owns and returns them.

## Reading an error

### Core

Core failures place the stable code directly on the result:

```lua
local result = exports['feather-core']:AwaitReady(10000)

if not result.ok then
  print(result.code, result.message)
end
```

```lua
{ ok = false, code = 'not_ready', message = 'Safe summary', details = {} }
```

### Inventory

Current Inventory contract failures nest the error document:

```lua
local result = Inventory.Instances.GetInstance(instanceId)

if not result.ok then
  print(result.error.code, result.error.message)
end
```

```lua
{
  ok = false,
  error = {
    code = 'not_found',
    message = 'Safe summary',
    details = {}
  },
  correlationId = correlationId
}
```

::: warning
A failure envelope is still a Lua table and therefore truthy. Check `result.ok == true` rather than `if result then`.
:::

## Core

### General contract

| Code | Meaning | Typical caller action |
|---|---|---|
| `invalid_input` | A required value is missing, malformed, or outside its allowed bounds. | Correct the request; do not retry unchanged. |
| `invalid_context` | The operation was called from the wrong client/server context. | Move the call to the documented context. |
| `invalid_state` | Core cannot perform the operation in its current lifecycle state. | Check health and readiness before retrying. |
| `not_ready` | The required Core capability has not finished starting. | Wait for readiness or fail the dependent resource safely. |
| `timeout` | A bounded wait or RPC call did not complete in time. | Retry only when the operation is safe to repeat. |
| `not_found` | The requested route, registration, account, or record does not exist. | Refresh the reference or stop the operation. |
| `conflict` | The request conflicts with current state or an existing registration. | Re-read current state and reconcile. |
| `forbidden` | The caller or route is not permitted to perform the operation. | Do not retry without an authority or ownership change. |
| `unauthenticated` | A connected account or trusted caller context is required. | Establish the required account/session context. |
| `limit_exceeded` | A configured registration or subscriber limit was reached. | Release unused registrations or review the configured bound. |
| `payload_too_large` | An event or RPC payload exceeded its bounded size. | Send a smaller plain-data document. |
| `internal_error` | Core encountered an unexpected or safely hidden failure. | Log the correlation/context and investigate server output. |

### Accounts, locale, and sessions

| Code | Meaning |
|---|---|
| `invalid_config` | A required Core configuration value is not valid. |
| `locale_invalid` | The requested locale is not registered. |
| `identifier_conflict` | Player identifiers resolve to conflicting accounts. |
| `identity_unavailable` | Core could not safely resolve or create account identity. |
| `account_unavailable` | The resolved Core account is not active or available. |
| `session_unavailable` | No usable Character session exists for the source. |
| `character_required` | The operation requires an active Character. |
| `session_stale` | The supplied session no longer matches the current session. |
| `character_session_expired` | An RPC response belongs to an expired Character session. |

### Providers, guards, RPC, and registration

| Code | Meaning |
|---|---|
| `provider_unavailable` | No healthy provider can satisfy the requested capability. |
| `unsupported_contract` | The provider does not support the required contract version. |
| `registration_failed` | A route or owned registration could not be installed. |
| `guard_failed` | A guard errored or could not produce a safe decision. |
| `rate_limited` | An RPC caller or route exceeded its bounded call rate. |
| `invalid_request` | The incoming RPC request is structurally invalid. |

### Migrations

| Code | Meaning |
|---|---|
| `invalid_migration` | A migration definition is malformed. |
| `invalid_migration_result` | A migration returned an unsupported result. |
| `duplicate_migration` | The migration identifier is already registered. |
| `migration_checksum_mismatch` | Applied migration content differs from the registered migration. |
| `migration_failed` | The migration could not complete safely. |

## Inventory

### General contract

| Code | Meaning | Typical caller action |
|---|---|---|
| `invalid_input` | A required ID, quantity, document, or mutation specification is invalid. | Correct the request; do not retry unchanged. |
| `not_found` | The requested definition, instance, Inventory, or equipment record does not exist. | Refresh state or stop the operation. |
| `denied` | Ownership, access, distance, archive, or a guard prevents the operation. | Explain the refusal; retry only after the condition changes. |
| `conflict` | State or revision changed during an optimistic mutation. | Re-read the ledger/instance and retry with current revisions. |
| `unsupported` | The request is valid but not supported by that item or entity. | Use a supported item mode or owner operation. |
| `limit_exceeded` | Capacity, weight, quantity, slots, metadata, or another bound was exceeded. | Reduce the request or free capacity. |
| `dependency_missing` | A required external capability is unavailable. | Restore or start the dependency before retrying. |
| `internal` | Inventory encountered an unexpected failure or rolled back. | Record the correlation ID and investigate server logs. |

### Inventory domain

| Code | Meaning |
|---|---|
| `invalid_inventory` | The Inventory does not exist or is not available. |
| `invalid_item` | The item name or reference is invalid, or its definition does not exist. |
| `invalid_quantity` | The supplied quantity or condition value is invalid. |
| `no_character` | The player does not have an active Character. |
| `no_access` | The Character does not currently have access to the Inventory. |
| `unique_requires_issuer` | A unique item must be created by its owning resource instead of a generic grant. |
| `condition_not_supported` | Condition cannot be applied to the requested stackable item. |

### Capacity decisions

Inventory capacity checks can succeed as calls while declining the proposed change. In this case `result.ok` is true and `result.value.accepted` is false.

| Decision code | Meaning |
|---|---|
| `invalid_inventory` | The target Inventory is unavailable. |
| `invalid_item` | The proposed item does not exist. |
| `item_restricted` | The Inventory does not accept that item. |
| `item_limit` | The item-specific quantity limit would be exceeded. |
| `inventory_full` | No Inventory slot is available. |
| `weight_limit` | The Inventory weight limit would be exceeded. |

```lua
local capacity = Inventory.Inventory.InventoryCanHold({
  { item = itemName, quantity = quantity }
}, inventoryId)

if capacity.ok and not capacity.value.accepted then
  print(('Inventory declined the item: %s'):format(capacity.value.code))
end
```

## Weapons

::: info Actively changing
`feather-weapons` is not present in the current workspace and its public contract is actively changing. Stable Weapons error codes will be added here after that contract is frozen. Until then, do not build integrations that branch on undocumented Weapons error strings.
:::

## Stability policy

- Existing stable codes keep their meaning throughout a compatible contract version.
- New codes may be added without changing existing meanings.
- A resource reference documents whether its code is at `result.code`, `result.error.code`, or inside a successful decision value.
- Messages and details provide context but are not compatibility identifiers.
- Codes removed or renamed in a future incompatible contract will be listed in that resource's migration notes.
