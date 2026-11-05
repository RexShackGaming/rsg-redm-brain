# Inventory

Feather Inventory provides server-authoritative item storage, custom containers, usable items, unique instances, metadata, transactions, equipment slots, and access control.

This page documents API contract version 2. Every server method returns a result envelope.

## Start here

**Signature**

```lua
exports['feather-inventory'].initiate() -> InventoryAPI
```

**Example**

```lua
local Inventory = exports['feather-inventory'].initiate()
```

On the client, the same export exposes only `Action.Open` and `Action.Close`. Inventory contents must never be changed from the client.

### Result envelopes

```lua
-- Success
{ ok = true, value = result, correlationId = 'optional-id' }

-- Failure
{
  ok = false,
  error = {
    code = 'stable_code',
    message = 'Developer-facing explanation',
    details = {}
  },
  correlationId = 'optional-id'
}
```

Always test `result.ok == true`. A failure envelope is still a Lua table, so `if result then` incorrectly treats failures as successes.

```lua
local result = Inventory.Items.GetItem(123)
if result.ok ~= true then
  print(result.error.code, result.error.message)
  return
end

print(result.value.name)
```

General error codes are `invalid_input`, `not_found`, `denied`, `conflict`, `unsupported`, `limit_exceeded`, `dependency_missing`, and `internal`. Methods may also return documented domain-specific codes.

### Check the contract version

**Signature**

```lua
Inventory.GetCapabilities() -> Result<Capabilities>
```

**Example**

```lua
local capabilities = Inventory.GetCapabilities()
if capabilities.ok ~= true or capabilities.value.contractVersion < 2 then
  error('feather-inventory contract 2 or newer is required')
end
```

Checking only whether a function exists is not enough because its return shape may have changed.

## API overview

| Surface | Purpose |
|---|---|
| `Inventory.Inventory` | Containers, capacity, opening, access, and lifecycle |
| `Inventory.Items` | Definitions, grants, removal, use, drops, and condition |
| `Inventory.Instances` | Exact item identity, metadata, and definition lifecycle |
| `Inventory.Transaction` | Atomic multi-item work |
| `Inventory.MutateItem` | Change one exact item with revision protection |
| `Inventory.CreateInstance` | Issue a unique item with metadata |
| `Inventory.DestroyInstances` | Destroy an exact, validated set of instances |
| `Inventory.UseItemAction` | Atomically consume or update the clicked item |
| `Inventory.Guards` | Veto movement/destruction and observe committed changes |
| `Inventory.Equipment` | Persistent Character equipment slots |
| `Inventory.Diagnostics` | Metrics and read-only integrity checks |
| `Inventory.Categories` | Inventory category definitions |

## Custom inventories

A custom inventory belongs to a row in another resource, such as a wagon, property, or stable. Register its foreign-key column once at startup, then register a container for each owner row.

### Register a foreign key

<Badge type="tip" text="Server only" />

**Signature**

```lua
Inventory.Inventory.RegisterForeignKey(tableName, foreignKeyType, primaryKeyName) -> Result
```

**Example**

```lua
AddEventHandler('onResourceStart', function(resourceName)
  if resourceName ~= GetCurrentResourceName() then return end

  local result = Inventory.Inventory.RegisterForeignKey(
    'wagons',          -- your table
    'BIGINT UNSIGNED', -- its primary-key type
    'id'               -- its primary-key column
  )

  if result.ok ~= true then
    print(result.error.code, result.error.message)
  end
end)
```

The owning table must already exist. Table and column names must be valid SQL identifiers.

### Register a container

**Signature**

```lua
Inventory.Inventory.RegisterInventory(
  tableName,
  id,
  displayName?,
  ignoreItemLimits?,
  maxWeight?,
  restrictedItems?,
  ownerCharacterId?,
  isPublic?,
  maxSlots?
) -> Result<{ uuid, id }>
```

**Example**

```lua
local registered = Inventory.Inventory.RegisterInventory(
  'wagons',                   -- registered owner table
  wagon.id,                   -- owner row id
  'Wagon Bed',                -- ledger name
  false,                      -- ignore per-item limits
  400.0,                      -- maximum weight in pounds
  { 'consumable_moonshine' }, -- blocked item names
  wagon.ownerCharacterId,     -- UUID Character owner
  false,                      -- public access
  60                          -- compartments
)

if registered.ok ~= true then
  print(registered.error.code, registered.error.message)
  return
end

local inventoryUuid = registered.value.uuid
local inventoryId = registered.value.id
```

Use the UUID with common container and item methods. Use numeric `inventory.id` with instance, transaction, equipment, and access methods.

- `maxWeight = nil` uses the configured default.
- `maxWeight = 0` means unlimited weight.
- `maxSlots = nil` uses the configured default.
- Omitted settings are not reset when a container is registered again.

## Find inventories and contents

**Signatures**

```lua
Inventory.Inventory.GetInventory(inventoryUuidOrId) -> Result<Inventory>
Inventory.Inventory.GetCustomInventory(tableName, ownerId) -> Result<Inventory>
Inventory.GetCharacterInventory(characterUuid) -> Result<Inventory>
Inventory.Inventory.GetInventoryItems(inventoryId) -> Result<Item[]>

exports['feather-inventory']:GetCharacterInventory(characterUuid) -> Result<Inventory>
exports['feather-inventory']:RemoveCharacterInventoryInstance(characterUuid, instanceId, reason?) -> Result
exports['feather-inventory']:GrantCharacterItem(characterUuid, itemName, quantity, reason?) -> Result
```

**Example**

```lua
local found = Inventory.Inventory.GetInventory(inventoryUuid)
local custom = Inventory.Inventory.GetCustomInventory('wagons', wagon.id)
local character = Inventory.GetCharacterInventory(characterUuid)
local contents = Inventory.Inventory.GetInventoryItems(inventoryId)

if contents.ok then
  for _, item in ipairs(contents.value) do
    print(item.id, item.name, item.quantity, item.slot_index)
  end
end
```

Character lookup also has a direct server export:

```lua
local result = exports['feather-inventory']:GetCharacterInventory(characterUuid)
```

## Capacity checks

**Signatures**

```lua
Inventory.Inventory.InventoryCanHold(items, playerSourceOrInventoryUuid) -> Result<Acceptance>
Inventory.Inventory.InventoryCanHoldById(items, inventoryId) -> Result<Acceptance>
Inventory.Inventory.EvaluateSlotMove(fromInventoryId, fromSlot, toInventoryId, toSlot) -> Result<Acceptance>
```

**Example**

```lua
local check = Inventory.Inventory.InventoryCanHold({
  { item = 'consumable_apple', quantity = 5 },
  { item = 'matches', quantity = 10 }
}, inventoryUuid)

if check.ok ~= true then
  print(check.error.code, check.error.message)
  return
end

if check.value.accepted ~= true then
  print(check.value.code, check.value.message)
  return
end
```

A refusal is a successful evaluation: `ok = true`, `accepted = false`. `ok = false` means the evaluation itself failed.

Use `InventoryCanHoldById(items, inventoryId)` for a numeric database id. A number passed to `InventoryCanHold` is interpreted as a player server ID. `EvaluateSlotMove(fromId, fromSlot, toId, toSlot)` checks both sides of a move or swap.

## Open and close the ledger

**Server signatures**

```lua
Inventory.Inventory.OpenInventory(source, otherInventoryUuid?, target?) -> Result
Inventory.Inventory.CloseInventory(source) -> Result
```

**Server example**

```lua
Inventory.Inventory.OpenInventory(source)
Inventory.Inventory.OpenInventory(source, wagonUuid, 'storage')
Inventory.Inventory.CloseInventory(source)
```

**Client signatures**

```lua
Inventory.Action.Open(otherInventoryUuid?, target?)
Inventory.Action.Close()
```

**Client example**

```lua
local Inventory = exports['feather-inventory'].initiate()
Inventory.Action.Open()
Inventory.Action.Open(wagonUuid, 'storage')
Inventory.Action.Close()
```

The client API controls presentation only.

## Item definitions and counts

**Signatures**

```lua
Inventory.Items.GetDefinitions() -> Result<Definition[]>
Inventory.Items.ItemExists(itemName) -> Result<boolean>
Inventory.Items.GetItem(instanceId) -> Result<Item>
Inventory.Items.GetItemCount(itemName, playerSourceOrInventoryUuid) -> Result<number>
Inventory.Items.InventoryHasItems(items, playerSourceOrInventoryUuid) -> Result<boolean>
```

**Example**

```lua
local definitions = Inventory.Items.GetDefinitions()
local exists = Inventory.Items.ItemExists('consumable_apple')
local item = Inventory.Items.GetItem(instanceId)
local count = Inventory.Items.GetItemCount('consumable_apple', inventoryUuid)

local hasItems = Inventory.Items.InventoryHasItems({
  { name = 'consumable_apple', quantity = 2 },
  { name = 'matches', quantity = 1 }
}, inventoryUuid)
```

A definition describes an item type. An instance is an owned row in an inventory. Every call above returns a result envelope.

## Grant and remove items

**Signatures**

```lua
Inventory.Items.GrantItem(itemName, quantity, playerSourceOrInventoryUuid) -> Result
Inventory.Items.AddItem(itemName, quantity, metadata?, playerSourceOrInventoryUuid) -> Result
Inventory.Items.RemoveItemByName(itemName, quantity, playerSourceOrInventoryUuid?) -> Result
Inventory.Items.RemoveItemById(instanceId) -> Result

exports['feather-inventory']:GrantCharacterItem(characterUuid, itemName, quantity, reason?) -> Result
exports['feather-inventory']:RemoveCharacterInventoryInstance(characterUuid, instanceId, reason?) -> Result
```

**Example**

```lua
local granted = Inventory.Items.GrantItem('consumable_apple', 5, inventoryUuid)
```

`GrantItem` atomically validates the definition, quantity, weight, item limit, blacklist, and compartments. It rejects `unique` definitions; issue unique property through `CreateInstance` from the resource that owns it.

`Items.AddItem(itemName, quantity, metadata, inventory)` remains available for stackable items that need metadata.

Trusted resources may grant a stackable item to an online or offline UUID Character:

```lua
local result = exports['feather-inventory']:GrantCharacterItem(
  characterUuid, 'consumable_apple', 5, 'daily_reward'
)
```

Remove by definition or exact instance:

```lua
local byName = Inventory.Items.RemoveItemByName('consumable_apple', 2, inventoryUuid)
local exact = Inventory.Items.RemoveItemById(instanceId)
```

For a selected Character-owned instance, use the ownership-scoped export:

```lua
local result = exports['feather-inventory']:RemoveCharacterInventoryInstance(
  characterUuid, instanceId, 'admin_remove'
)
```

It locks the row, verifies current ownership, and runs destruction guards.

## Usable items

Callback registration does not consume the item automatically:

**Signatures**

```lua
Inventory.Items.RegisterUsableItem(itemName, callback, ownerResource?) -> Result
Inventory.Items.RegisterUsableAction(itemName, action, afterCommit?, ownerResource?) -> Result
Inventory.Items.UseItem(instanceId, source, context?) -> Result
```

**Callback example**

```lua
Inventory.Items.RegisterUsableItem('consumable_coffee', function(item, source)
  -- Apply the gameplay effect.
end)
```

Prefer a declarative action when use should atomically consume or update the clicked row:

**Atomic-action example**

```lua
Inventory.Items.RegisterUsableAction('consumable_coffee', {
  consume = true,
  quantity = 1
}, function(item, source, committed)
  -- Runs after commit. Apply the gameplay effect here.
end)
```

Declarative actions protect the instance from competing use, move, and destroy requests. If post-commit code fails, do not consume the item again.

## Condition and metadata

**Signatures**

```lua
Inventory.Items.GetCondition(instanceId) -> Result<number|nil>
Inventory.Items.SetCondition(instanceId, value) -> Result
Inventory.Items.AdjustCondition(instanceId, delta) -> Result

Inventory.Instances.GetInstance(instanceId) -> Result<Instance>
Inventory.Instances.ReadMetadata(instanceId) -> Result<{ document, revision }>
Inventory.Instances.WriteMetadata(instanceId, document, expectedRevision?, correlationId?) -> Result
Inventory.Instances.MergeMetadata(instanceId, patch, correlationId?) -> Result
Inventory.Instances.IsUniqueDefinition(definitionId) -> boolean
Inventory.Instances.SetInstanceMode(definitionId, mode) -> Result
Inventory.Instances.SetDefinitionArchived(definitionId, archived, reason?) -> Result
Inventory.Instances.GetDefinitionMigrationPreflight(sourceDefinitionId, targetDefinitionId) -> Result
Inventory.Instances.MigrateDefinitionInstances(sourceDefinitionId, targetDefinitionId, reason) -> Result
```

**Example**

```lua
local condition = Inventory.Items.GetCondition(instanceId)
local set = Inventory.Items.SetCondition(instanceId, 75)
local adjusted = Inventory.Items.AdjustCondition(instanceId, -1)

local instance = Inventory.Instances.GetInstance(instanceId)
local metadata = Inventory.Instances.ReadMetadata(instanceId)
```

Replace a complete document or merge a patch, optionally checking the expected row revision:

```lua
local written = Inventory.Instances.WriteMetadata(
  instanceId,
  { condition = 80, serial = 'ABC-123' },
  expectedRevision
)

local merged = Inventory.Instances.MergeMetadata(
  instanceId,
  { condition = 79 },
  correlationId
)
```

A stale revision returns `conflict` and changes nothing. Stackable rows merge only when their complete decoded metadata documents are equal.

Definitions use `stack` or `unique` mode. Lifecycle methods include `SetInstanceMode`, `SetDefinitionArchived`, `GetDefinitionMigrationPreflight`, and `MigrateDefinitionInstances`. Always run migration preflight first.

## Transactions

Use a transaction when several changes must all succeed or all fail:

**Signatures**

```lua
Inventory.Transaction(context, transactionBody) -> Result
Inventory.MutateItem(context, spec) -> Result
Inventory.CreateInstance(context, spec) -> Result
Inventory.DestroyInstances(context, spec) -> Result
Inventory.UseItemAction(context, spec) -> Result
```

**Transaction-handle signatures**

```lua
tx:GetItemForUpdate(instanceId) -> Result<Instance>
tx:GetQuantity(inventoryId, definitionId) -> Result<number>
tx:RemoveQuantity(inventoryId, definitionId, quantity) -> Result
tx:RemoveInstances(inventoryId, definitionId, instanceIds) -> Result
tx:AddQuantity(inventoryId, definitionId, quantity, metadata?) -> Result
tx:CreateInstance(inventoryId, definitionId, metadata) -> Result
tx:SetMetadata(instanceId, document, expectedRevision?) -> Result
tx:MoveInstance(instanceId, toInventoryId, toSlot) -> Result
tx:AssertAccess(source, inventoryId, action) -> Result
```

**Example**

```lua
local result = Inventory.Transaction({
  actorSource = source,
  resource = GetCurrentResourceName(),
  reason = 'craft_bandage',
  correlationId = requestId,
  idempotencyKey = requestId
}, function(tx)
  local removed = tx:RemoveQuantity(characterInventoryId, clothDefinitionId, 2)
  if removed.ok ~= true then return removed end

  local added = tx:AddQuantity(characterInventoryId, bandageDefinitionId, 1)
  if added.ok ~= true then return added end

  return { crafted = 1 }
end)
```

Transaction handle methods include `GetItemForUpdate`, `GetQuantity`, `RemoveQuantity`, `RemoveInstances`, `AddQuantity`, `CreateInstance`, `SetMetadata`, `MoveInstance`, and `AssertAccess`.

Use a stable `idempotencyKey` when a request may be retried. For common single-purpose work, use `MutateItem`, `CreateInstance`, `DestroyInstances`, or `UseItemAction`.

## Access control

Access modes are `READ`, `INSERT`, `REMOVE`, and `MANAGE`:

**Signatures**

```lua
Inventory.Inventory.CanAccessInventory(source, inventoryId, action, context?) -> Result
Inventory.Inventory.GrantInventoryAccess(source, inventoryId, characterUuid) -> Result
Inventory.Inventory.RevokeInventoryAccess(source, inventoryId, characterUuid) -> Result
Inventory.Inventory.SetInventoryPublic(source, inventoryId, isPublic) -> Result
Inventory.Inventory.ListInventoryAccess(source, inventoryId) -> Result
Inventory.Inventory.GrantTemporaryAccess(source, inventoryId, ttlSeconds?) -> Result
Inventory.Inventory.RevokeTemporaryAccess(source, inventoryId) -> Result
Inventory.Inventory.HasTemporaryAccess(source, inventoryId) -> Result<boolean>
```

**Example**

```lua
local modes = Inventory.Inventory.AccessModes
local decision = Inventory.Inventory.CanAccessInventory(
  source, inventoryId, modes.REMOVE, { reason = 'take_from_wagon' }
)
```

Shared and temporary access:

```lua
Inventory.Inventory.GrantInventoryAccess(source, inventoryId, otherCharacterUuid)
Inventory.Inventory.RevokeInventoryAccess(source, inventoryId, otherCharacterUuid)
Inventory.Inventory.SetInventoryPublic(source, inventoryId, true)
local grants = Inventory.Inventory.ListInventoryAccess(source, inventoryId)

Inventory.Inventory.GrantTemporaryAccess(source, inventoryId, 60)
Inventory.Inventory.RevokeTemporaryAccess(source, inventoryId)
```

Opening a ledger is not permanent permission. Inventory checks live access again when a mutation occurs.

## Container lifecycle

Before deleting an entity that owns a container, let Inventory safely handle its contents.

**Signatures**

```lua
Inventory.Inventory.GetContainerLifecycle(inventoryId) -> Result
Inventory.Inventory.DeleteContainerIfEmpty(inventoryId, expectedLocation, reason) -> Result
Inventory.Inventory.RecoverContainerContents(inventoryId, targetInventoryId, expectedLocation, reason) -> Result
```

**Example**

```lua
local deleted = Inventory.Inventory.DeleteContainerIfEmpty(
  inventoryId, 'wagons', 'wagon permanently deleted'
)

local recovered = Inventory.Inventory.RecoverContainerContents(
  wagonInventoryId,
  characterInventoryId,
  'wagons',
  'wagon permanently deleted'
)
```

Do not delete the owning entity until the Inventory call succeeds. A database cascade is cleanup machinery, not permission to destroy player property.

## Guards, equipment, and diagnostics

Guards synchronously veto movement or destruction before commit:

**Guard signatures**

```lua
Inventory.Guards.RegisterMoveGuard(name, callback) -> Result
Inventory.Guards.RegisterDestroyGuard(name, callback) -> Result
Inventory.Guards.UnregisterMoveGuard(name)
Inventory.Guards.UnregisterDestroyGuard(name)
Inventory.Guards.CanMoveInstance(instanceId, context?) -> boolean, reason?
Inventory.Guards.CanDestroyInstance(instanceId, context?) -> boolean, reason?
```

**Guard example**

```lua
Inventory.Guards.RegisterMoveGuard('my-resource:equipped', function(item, context)
  if item.id == equippedInstanceId then
    return false, 'Unequip this item first.'
  end
  return true
end)
```

Guard callbacks must be fast and must not yield. Unregister them when your resource stops. Structured post-commit events report created, moved, metadata-changed, destroyed, and transaction-committed facts.

Equipment is persistent generic state:

**Equipment signatures**

```lua
Inventory.Equipment.GetEquippedForCharacter(characterUuid, slot?) -> Result
Inventory.Equipment.SetEquippedForCharacter(characterUuid, slot, instanceId?) -> Result
Inventory.Equipment.ClearEquippedInstance(instanceId) -> Result
Inventory.Equipment.IsInstanceEquipped(instanceId) -> Result<boolean>
```

**Equipment example**

```lua
local equipped = Inventory.Equipment.GetEquippedForCharacter(characterUuid)
local set = Inventory.Equipment.SetEquippedForCharacter(characterUuid, 'primary', instanceId)
local cleared = Inventory.Equipment.ClearEquippedInstance(instanceId)
```

Diagnostics are read-only:

**Diagnostic and category signatures**

```lua
Inventory.Diagnostics.GetTransactionMetrics() -> TransactionMetrics
Inventory.Diagnostics.RunIntegrityDiagnostics(options?) -> Result<IntegrityReport>
Inventory.Categories.GetCategories() -> Result<Category[]>
```

**Example**

```lua
local metrics = Inventory.Diagnostics.GetTransactionMetrics()
local report = Inventory.Diagnostics.RunIntegrityDiagnostics({ sampleLimit = 500 })
local categories = Inventory.Categories.GetCategories()
```

## Contract 2 migration notes

| Legacy API | Contract 2 replacement |
|---|---|
| `{ status, reason }` or `{ error = boolean }` | `{ ok, value }` or `{ ok, error }` |
| Positional multi-returns | Named fields inside `.value` |
| `Items.SetMetadata` | `Instances.MergeMetadata` or `Instances.WriteMetadata` |
| `metadataRevision` | `revision` |
| `item_metadata` in ledger rows | `metadata` |
| Generic grants for unique definitions | `CreateInstance` through the owner resource |
| Client-side mutations | Server API methods |

When migrating older code, update return checks first. `if result then` is unsafe with result envelopes.

## Client hotbar preferences

The client exposes read-only policy information and player presentation preferences. Item owners still own cooldowns, animation, weapon equip behavior, and consumable policy.

```lua
exports['feather-inventory']:GetHotbarPolicy() -> table
exports['feather-inventory']:GetHotbarVisibility() -> boolean
exports['feather-inventory']:SetHotbarVisibility(visible) -> boolean
exports['feather-inventory']:GetHotbarOpacity() -> number
exports['feather-inventory']:SetHotbarOpacity(opacity) -> number
```
