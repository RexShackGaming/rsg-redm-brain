# feather-inventory

Version 0.14.2. The Inventory API for the Feather Framework

Pull requests and pushes to main run the full Lua regression runner and runtime syntax checks, Python collection/equipment tests, UI contract tests, lint/build, and install archive verification. Tests use Lupa 2.8 (Lua 5.4), Node 22 and pnpm

Source: https://github.com/FeatherFramework/feather-inventory

**Dependencies:** `feather-mysql`

Has NUI (`ui_page`).

## Exports (call as exports['feather-inventory']:Name)

**server:** `AwaitReady(timeoutMs)`, `BeginNativeAmmoFixture(identity,baseline,limits,validator,economy)`, `CancelCharacterItemGrant(request)`, `CancelCharacterUniqueItemGrant(request)`, `CheckoutShopOrder(orderId,source,permitId)`, `CommitNativeAttachmentTransition(context,spec)`, `CommitNativeEquipmentTransition(context,spec)`, `CommitNativeEvidenceTransition(context,spec)`, `CommitNativeRepairTransition(context,spec)`, `CommitNativeThrowableFunding(context,spec)`, `CommitNativeUtilityEquipment(context,spec)`, `GetCharacterAmmunitionSnapshot(context, limits)`, `GetCharacterFirearmRuntimeSnapshot(context, limits)`, `GetCharacterInventory(characterId)`, `GetConsumptionContract()`, `GetHealth()`, `GetNativeIssuanceContract()`, `GetShopCheckoutContract()`, `GetShopCheckoutDefinition(itemName)`, `GrantCharacterItem(characterId, itemName, quantity, reason)`, `GrantCharacterItemOnce(request)`, `GrantCharacterUniqueItemOnce(request)`, `InventoryDelegationFixture(request)`, `IssueNativeFirearmOnce(context,spec)`, `MutateCharacterAmmunition(context, spec)`, `ObserveCharacterAmmunition(context, spec)`, `ObserveNativeAmmoFixture(context,spec)`, `PrepareRestartRecovery(mode)`, `ReadNativeAcceptanceAudit(actors)`, `ReadNativeAttachmentMaterial(context,itemName)`, `ReadNativeEquipmentTransition(context,itemId,limits)`, `ReadNativeRepairMaterial(context,itemName)`, `ReadNativeUtilityEquipment(context)`, `ReadRestartRecovery(verify)`, `ReconcileNativeThrowablePickup(context,spec)`, `ReleaseNativeAmmoFixture()`, `RemoveCharacterInventoryInstance(characterId, instanceId, reason)`, `ResolveShopCheckout(orderId)`, `RunInstanceChangeGuardCFXSmokeTest(target,provider)`, `StablesCareProofFixture(action)`, `TransferNativeAmmoFixture(context,spec)`, `initiate()`

**client:** `GetHotbarOpacity()`, `GetHotbarPolicy()`, `GetHotbarVisibility()`, `SetHotbarOpacity(value)`, `SetHotbarVisibility(value)`, `initiate()`

## Net events registered

**client:** `Feather:Character:Spawned`, `Feather:Inventory:CloseInventory`, `Feather:Inventory:HotbarRefresh`, `Feather:Inventory:OpenInventory`, `Feather:Inventory:RefreshInventory`, `Feather:Inventory:UpdateGroundLocations`

## Event handlers

**server:** `Feather:Inventory:DefinitionMigrated`, `Feather:Inventory:Empty`, `Feather:Inventory:ItemCreated`, `Feather:Inventory:ItemDestroyed`, `Feather:Inventory:ItemMoved`, `Feather:Server:Character:Spawned`, `chat.ready.v1`, `core.session.ready.v1`

**client:** `Feather:Character:Logout`, `Feather:Inventory:HotbarRefreshAfterInventory`, `Feather:Inventory:HotbarVisibilityChanged`, `feather-core:locale:changed`, `feather-medical:client:condition-changed.v1`

## Commands (RegisterCommand)

**server:** `/AddApples`, `/AddItems`, `/AddStorageItems`, `/CreateStorage`, `/CreateStorageKey`, `/InvBulkMutationSmokeTest`, `/InvCharacterAmmoEnrollmentReplayTest`, `/InvCharacterAmmoEnrollmentSmokeTest`, `/InvCharacterAmmoMigrationPreview`, `/InvCharacterAmmoNativePlanPreview`, `/InvCharacterAmmoObservationSmokeTest`, `/InvCharacterAmmoReplaySmokeTest`, `/InvCharacterAmmoRuntimeCFXSmokeTest`, `/InvCharacterAmmoRuntimeSmokeTest`, `/InvCharacterAmmoTxSmokeTest`, `/InvCharacterUuidSmokeTest`, `/InvConcurrencySmokeTest`, `/InvConditionalEquipmentSmokeTest`, `/InvConsumptionItemProof`, `/InvConsumptionProof`, `/InvInstanceChangeGuardSmokeTest`, `/InvIntegrityCheck`, `/InvJaneAmmoBudget`, `/InvJaneAmmoEconomicVerify`, `/InvJaneAmmoEnroll`, `/InvJaneAmmoVerify`, `/InvJanePreviewBudget`, `/InvJanePrimary`, `/InvJaneRepairFixture`, `/InvJaneSavedAttachmentFixture`, `/InvLifecycleSmokeTest`, `/InvMoveDeliveryAcceptance`, `/InvMoveHealth`, `/InvMoveMaintenanceAcceptance`, `/InvMoveRecoveryAcceptance`, `/InvNativeAmmoFixture`, `/InvNativeEmptyAmmoEnroll`, `/InvNativeMoveAckLossProbe`, `/InvNativeMoveContentionProbe`, `/InvNativeRecoveryBatch`, `/InvNativeRepairAudit`, `/InvNativeThrowableBudget`, `/InvNativeThrowableDeathBudget`, `/InvNativeThrowablePickupBudget`, `/InvNotificationSmokeTest`, `/InvServerCoreCutoverSmokeTest`, `/InvTxSmokeTest`, `/InventoryAccessMigrate`, `/InventoryAccessRollback`, `/InventoryAccessStatus`, `/InventoryFulfillmentContractSmokeTest`, `/InventoryUniqueFulfillmentContractSmokeTest`

**client:** `/close_inventory`, `/open_inventory`, `/open_storage`, `/toggle_hotbar`

## Server events it triggers in other resources

**client:** `Feather:Inventory:GetGroundLocations`

## Public (table) functions

**.luals/cfx-runtime.lua:** `Citizen.InvokeNative(hash, ...)`, `Citizen.CreateThread(cb)`, `Citizen.CreateThreadNow(cb)`, `Citizen.Wait(ms)`, `Citizen.Trace(msg)`, `json.encode(value)`, `json.decode(str)`

**client/helpers/runtime.lua:** `Feather.Keys:RegisterListener(keyName, callback)`, `Feather.Object:Create(modelName, x, y, z, heading, networked)`, `Feather.Prompt:SetupPromptGroup(groupId)`, `group:ShowGroup(text)`, `group:RegisterPrompt(title, button, enabled, visible, pulsing, mode, options)`

**server/controllers/categories.lua:** `CategoryControllers.GetCategories()`

**server/controllers/ground.lua:** `GroundControllers.GetGroundById(id, query)`, `GroundControllers.GetAllGroundLocations()`, `GroundControllers.GetGroundCleanupRows()`, `GroundControllers.GetClosestGroundByCoords(x, y, z, radius)`, `GroundControllers.CreateGround(x, y, z)`, `GroundControllers.DeleteGroundIfEmpty(id)`, `GroundControllers.DeleteEmptyGround()`, `GroundControllers.GetGroundID(id, query)`

**server/controllers/inventory.lua:** `InventoryControllers.GetInventoryById(inventoryId, type)`, `InventoryControllers.GetInventoryLocationById(id, query)`, `InventoryControllers.GetInventoryCapacity(inventory)`, `InventoryControllers.GetInventoryWeightLimit(inventory)`, `InventoryControllers.GetCustomInventoryById(key, id)`, `InventoryControllers.GetInventoryByCharacter(character, query)`, `InventoryControllers.InventoryItemCount(inventory, itemId)`, `InventoryControllers.GetInventoryItemById(id)`, `InventoryControllers.GetInventoryTotalWeight(inventory)`, `InventoryControllers.GetInventoryItems(inventory)`, `InventoryControllers.GetInventoryItemsPair(sourceInventory, targetInventory)`, `InventoryControllers.InventoryItemCounts(inventory)`, `InventoryControllers.GetInventoryTotalItemCounts(inventory)`, `InventoryControllers.GetOccupiedSlotSet(inventory)`, `InventoryControllers.GetFreeSlot(inventory, capacity)`, `InventoryControllers.GetSplitPreflight(inventory, sourceSlot)`, `InventoryControllers.GetItemsInSlot(inventory, slot)`, `InventoryControllers.AreSlotsStackCompatible(fromInventory, fromSlot, toInventory, toSlot)`, `InventoryControllers.GetItemStackCounts(inventory, itemId)`, `InventoryControllers.GetSlotItemBreakdown(inventory, slot)`, `InventoryControllers.MoveSlotItemsPartial(fromInventory, fromSlot, toInventory, toSlot, quantity, context)`, `InventoryControllers.GetOccupiedSlotCount(inventory)`, `InventoryControllers.MoveSlotItems(fromInventory, fromSlot, toInventory, toSlot, context)`, `InventoryControllers.SplitSlotItems(inventory, fromSlot, toSlot, quantity, context)`, `InventoryControllers.IsItemRestricted(inventory, itemId)`, `InventoryControllers.UpdateRestrictedItems(inventory, items)`, `InventoryControllers.AcceptanceInTransaction(query, inventory, checkItems)`, `InventoryControllers.NormalizeMoveItemIds(items)`, `InventoryControllers.MoveInventoryItems(sourceInventory, targetInventory, items, context)`

**server/controllers/item.lua:** `ItemControllers.GetItemByName(itemName)`, `ItemControllers.GetItemDefinitionByName(itemName)`, `ItemControllers.GetItemDefinitions()`

**server/helpers/character_identity.lua:** `InventoryIdentity.NormalizeCharacterId(value)`, `InventoryIdentity.IsUuid(value)`, `InventoryIdentity.GetSession(src)`, `InventoryIdentity.GetCharacter(src)`, `InventoryIdentity.GetPosition(src)`

**server/helpers/integrity_diagnostics.lua:** `report:add(code, severity, details)`, `DiagnosticsAPI.RunIntegrityDiagnostics(options)`

**server/helpers/metadata_compatibility.lua:** `InventoryMetadata.Decode(value)`, `InventoryMetadata.DocumentsEqual(left, right)`, `InventoryMetadata.RowsCompatible(rows)`

**server/helpers/move_planner.lua:** `InventoryMovePlanner.ValidateArrivals(policy, targetRows, arriving, restricted)`, `InventoryMovePlanner.Plan(policy, targetRows, candidates, restricted, greedy)`

**server/helpers/mutation_metrics.lua:** `InventoryMutationMetrics.Elapsed(started)`, `InventoryMutationMetrics.Begin(operation, traceId)`, `InventoryMutationMetrics.Measure(metrics, key, callback, ...)`, `InventoryMutationMetrics.Finish(metrics, response)`

**server/helpers/result.lua:** `Result.Ok(value, correlationId)`, `Result.Err(code, message, details, correlationId)`, `Result.IsOk(result)`

**server/internal/move_recovery.lua:** `InventoryMoveRecoveryEngine.New(api)`, `T.Run(body,metrics,context,scope)`, `T.Sweep()`

**server/internal/native_equipment_snapshot.lua:** `NativeEquipmentSnapshot.With(tx,characterId,authority,headerLocked,body)`

**server/internal/native_move_contention_probe.lua:** `NativeMoveContentionProbe.RunAckLoss(api,before,itemId,sourceInventory,targetInventory)`, `NativeMoveContentionProbe.Run(api,before,itemId,sourceInventory,targetInventory)`

**server/internal/native_recovery_batch.lua:** `NativeRecoveryBatch.New(api)`, `T.Guard(item,context)`, `T.Status()`, `T.Run(mode,expected)`, `T.Verify()`, `T.Clear()`

**server/internal/native_throwable_native_pickup_claim.lua:** `C.Apply(tx,context,plan,limits,current)`

**server/internal/native_throwable_recovery_claim.lua:** `C.Apply(tx,context,plan,current)`

**server/internal/native_utility_equipment.lua:** `U.Read(tx,characterId,authority,locked)`, `U.Apply(tx,spec,authority)`

**server/services/character_ammunition.lua:** `A.Apply(tx, context, spec)`, `A.ApplyThrowableFunding(tx,context,spec,authority)`, `A.ApplyObservation(tx,context,spec,authority)`, `A.Mutate(context,spec,invokingResource)`, `A.Observe(context,spec,invokingResource)`, `A.ReadRuntimeEquipment(tx,characterId,locked)`, `A.ReadSnapshot(tx,characterId,limits,withEquipment,initializeFresh)`, `A.PrepareFreshCharacter(tx,characterId,limits,isCurrent)`, `A.Snapshot(context,limits,invokingResource)`, `A.RuntimeSnapshot(context,limits,invokingResource)`

**server/services/character_ammunition_enrollment.lua:** `E.ApplyJaneTest(tx,catalog,planner,limits)`, `E.Apply(tx,characterId,catalog,planner,limits)`, `E.ApplyEmpty(tx,characterId,catalog,planner,limits,current)`, `E.ReadJaneBaseline(tx)`, `E.ReadJaneEconomic(tx,limits,allowPrimary,roundtrip)`

**server/services/character_ammunition_enrollment_test.lua:** `fixture.query(sql,params)`, `fixture:SetMetadata(id,document,revision)`

**server/services/character_ammunition_native_preview.lua:** `CharacterAmmoNativePreview.Load()`, `CharacterAmmoNativePreview.Build(rows,catalog,registry,itemContract,strict)`

**server/services/character_ammunition_preview.lua:** `CharacterAmmoCutoverPreview.LoadRuntime()`, `CharacterAmmoCutoverPreview.Load()`

**server/services/character_ammunition_replay_test.lua:** `fixture.query(sql, params)`, `fixture:RequireAccess()`, `fixture:RemoveQuantity(inventoryId, definitionId, amount)`, `fixture:AddQuantity(inventoryId, definitionId, amount)`

**server/services/character_collections.lua:** `C.Start()`, `C.Allowed(p,row)`, `C.Resolve(tx,p)`, `C.Get(request,resource)`, `C.Item(request,resource)`, `C.Batch(request,resource)`, `C.Retire(request,resource)`, `C.Transfer(request,resource)`

**server/services/collection_storage.lua:** `S.Start()`, `S.Register(p,resource)`, `S.IsManaged(id)`, `S.Access(src,id,mode,boundQuery)`, `S.Get(request,resource)`, `S.Open(request,resource)`, `S.RequireEmpty(tx,instanceId)`

**server/services/conditional_equipment.lua:** `ConditionalEquipment.Apply(tx,spec,current,guardContext)`

**server/services/consumption_once.lua:** `ConsumptionOnceAPI.Start()`, `ConsumptionOnceAPI.Contract()`, `ConsumptionOnceAPI.Consume(request,resource)`, `ConsumptionOnceAPI.Cancel(request,resource)`, `ConsumptionOnceAPI.Inspect(request,resource)`, `ConsumptionOnceAPI.Wear(request,resource)`, `ConsumptionOnceAPI.CancelWear(request,resource)`, `ConsumptionOnceAPI.InspectWear(request,resource)`

**server/services/consumption_proof.lua:** `tx:GetItemForUpdate(id)`, `tx:RemoveInstances(inventoryId,definitionId,ids)`

**server/services/equipment.lua:** `EquipmentAPI.GetEquippedForCharacter(characterId, slot)`, `EquipmentAPI.SetEquippedForCharacter(characterId, slot, instanceId)`, `EquipmentAPI.SetEquipmentBatchForCharacter(characterId,changes)`, `EquipmentAPI.SetCollectionEquipmentBatch(characterId,changes,collectionId,policy)`, `EquipmentAPI.PromoteEquippedSlot(characterId, fromSlot, toSlot)`, `EquipmentAPI.ClearEquippedInstance(instanceId)`, `EquipmentAPI.IsInstanceEquipped(instanceId)`

**server/services/grants_once.lua:** `NativeFirearmIssuanceAPI.Apply(tx,context,spec,current)`, `NativeFirearmIssuanceAPI.Issue(context,spec,resource)`, `GrantOnceAPI.Start()`, `GrantOnceAPI.Grant(request, resource, privateKey, sessionCurrent)`, `GrantOnceAPI.Cancel(request, resource)`, `UniqueGrantOnceAPI.Validate(request, resource)`, `UniqueGrantOnceAPI.Grant(request, resource)`, `UniqueGrantOnceAPI.Cancel(request, resource)`

**server/services/guards.lua:** `GuardsAPI.PrepareMoveSnapshots(query, rows)`, `GuardsAPI.PrepareDestroySnapshots(query, rows)`, `GuardsAPI.GetLockedEquipmentState(instanceId)`, `GuardsAPI.RegisterMoveGuard(name, fn)`, `GuardsAPI.RegisterDestroyGuard(name, fn)`, `GuardsAPI.UnregisterMoveGuard(name)`, `GuardsAPI.RegisterInstanceChangeGuard(name, fn)`, `GuardsAPI.UnregisterInstanceChangeGuard(name)`, `GuardsAPI.UnregisterDestroyGuard(name)`, `GuardsAPI.HasRegisteredGuard(name)`, `GuardsAPI.CanMoveInstance(instanceId, context)`, `GuardsAPI.CanChangeInstance(instanceId, context)`, `GuardsAPI.CanMoveInstanceSnapshot(instance, context)`, `GuardsAPI.CanDestroyInstance(instanceId, context)`, `GuardsAPI.CanDestroyInstanceSnapshot(instance, context)`, `GuardsAPI.EmitItemCreated(instanceId, definitionId, inventoryId, context)`, `GuardsAPI.EmitItemMoved(instanceId, fromInventoryId, toInventoryId, context, extra)`, `GuardsAPI.EmitItemMetadataChanged(instanceId, revision, context, extra)`, `GuardsAPI.EmitItemDestroyed(instanceId, definitionId, inventoryId, context)`, `GuardsAPI.EmitTransactionCommitted(context, summary)`, `GuardsAPI.EmitDefinitionMigrated(sourceDefinitionId, targetDefinitionId, quantity, context)`

**server/services/hotbar.lua:** `HotbarAPI.GetBindings(src)`, `HotbarAPI.SetBinding(src, slot, itemId)`, `HotbarAPI.UseBinding(src, slot)`

**server/services/instances.lua:** `InstancesAPI.IsUniqueDefinition(itemId)`, `InstancesAPI.SetInstanceMode(itemId, mode)`, `InstancesAPI.SetDefinitionArchived(itemId, archived, reason)`, `InstancesAPI.GetDefinitionMigrationPreflight(sourceItemId, targetItemId)`, `InstancesAPI.MigrateDefinitionInstances(sourceItemId, targetItemId, reason)`, `InstancesAPI.ReadMetadata(instanceId)`, `InstancesAPI.WriteMetadata(instanceId, document, expectedRevision, correlationId)`, `InstancesAPI.MergeMetadata(instanceId, patch, correlationId)`, `InstancesAPI.GetInstance(instanceId)`, `InstancesAPI.FindInstances(inventoryId, definitionName)`, `InstancesAPI.GetItemForCharacter(characterId, instanceId)`, `InstancesAPI.GetCapabilities()`

**server/services/inventory.lua:** `InventoryAPI.GetContainerLifecycle(inventoryId)`, `InventoryAPI.DeleteContainerIfEmpty(inventoryId, expectedLocation, reason)`, `InventoryAPI.RecoverContainerContents(inventoryId, targetInventoryId, expectedLocation, reason)`

**server/services/inventory_delegation.lua:** `D.Query(query, sql, params)`, `D.Row(id, query, lock)`, `D.Access(operation, request)`, `D.Base(source, character, row)`, `D.Read(source, id, action)`, `D.Check(source, id, action, query)`, `D.Transaction(context, runner)`, `D.LockSnapshot(query, snapshot)`, `D.EndSnapshot(snapshot)`, `D.LegacyWrite(id)`, `D.LegacyMutation(id, fn)`

**server/services/inventory_delegation_cutover.lua:** `D.Migrate(uuid, validUntil)`, `D.Rollback(uuid)`

**server/services/items.lua:** `ItemsAPI.RegisterInternalUseGuard()`, `ItemsAPI.GetDefinitions()`, `ItemsAPI.GrantItem(itemName, quantity, inventoryId)`

**server/services/move_maintenance.lua:** `M.PruneLocked(query,candidate)`, `M.Cleanup()`, `M.Health()`, `M.Start()`

**server/services/move_outbox.lua:** `O.Headers(query,a,b)`, `O.Build(id,result,context,scope)`, `O.Append(query,id,result,context,scope)`, `O.Sweep()`, `O.Start()`

**server/services/move_recovery.lua:** `R.Run(body,metrics,context,scope)`, `R.Start()`, `R.Status()`

**server/services/native_attachment_commit.lua:** `NativeAttachmentCommit.Apply(tx,spec,current)`

**server/services/native_evidence_commit.lua:** `NativeEvidenceCommit.Apply(tx,spec,current)`

**server/services/native_knife_equipment.lua:** `NativeKnifeEquipment.Read(tx,characterId,itemId,authority,locked)`, `NativeKnifeEquipment.Apply(tx,spec,authority)`, `NativeMeleeEquipment.Read(tx,characterId,itemId,authority,locked)`, `NativeMeleeEquipment.Apply(tx,spec,authority)`, `NativeThrowableEquipment.Read(tx,characterId,itemId,authority,locked)`, `NativeThrowableEquipment.Apply(tx,spec,authority)`

**server/services/native_lifecycle_wear.lua:** `NativeLifecycleWear.DetachBroken(tx,spec,current,guardContext)`, `NativeLifecycleWear.Apply(tx,spec,current,guardContext)`

**server/services/native_repair_audit.lua:** `NativeRepairAudit.New(api)`, `A.Run(target,characterId,itemId,mode,label)`

**server/services/native_repair_commit.lua:** `NativeRepairCommit.Apply(tx,spec,current)`

**server/services/native_repair_fixture.lua:** `NativeRepairFixture.Apply(tx,current,limits,itemContract,definition)`, `NativeSavedAttachmentFixture.Apply(tx,current,mode,itemContract,definition)`

**server/services/native_repair_verify.lua:** `NativeRepairVerify.Read(tx,characterId)`, `NativeRepairVerify.Compare(before,after,spec)`, `NativeRepairVerify.Diagnose(before,after,spec)`, `NativeRepairVerify.CompareWear(before,after,spec)`, `NativeRepairVerify.ComparePromotionWear(before,after,spec)`

**server/services/native_throwable_native_pickup_credits.lua:** `C.Record(tx,context,before,after,limits,current)`

**server/services/restart_audit.lua:** `A.Paused(id)`

**server/services/shop_checkout.lua:** `ShopCheckoutAPI.Resolve(order)`, `ShopCheckoutAPI.Start()`, `ShopCheckoutAPI.Execute(context, order, participants)`

**server/services/stables_care_proof.lua:** `P.TryInspect(request,resource)`, `P.Step(action,resource)`

**server/services/transactions.lua:** `TransactionAPI.GetMetrics()`, `TransactionAPI.IsUnknownProviderFailure(value)`, `Tx:RequireAccess(inventoryId, action)`, `Tx:GetItemForUpdate(instanceId)`, `Tx:GetQuantity(inventoryId, definitionId)`, `Tx:RemoveQuantity(inventoryId, definitionId, quantity)`, `Tx:RemoveInstances(inventoryId, definitionId, instanceIds)`, `Tx:AddQuantity(inventoryId, definitionId, quantity, metadata, expectedDefinition)`, `Tx:CreateInstance(inventoryId, definitionId, metadata)`, `Tx:SetMetadata(instanceId, document, expectedRevision)`, `Tx:MoveInstance(instanceId, toInventoryId, toSlot)`, `Tx:AssertAccess(src, inventoryId, action)`, `TransactionAPI.Transaction(context, fn)`, `TransactionAPI.MutateItem(context, spec)`, `TransactionAPI.MutateItems(context, spec)`, `TransactionAPI.DestroyInstances(context, spec)`, `TransactionAPI.UseItemAction(context, spec)`, `TransactionAPI.CreateInstance(context, spec)`

**tests/lua/character_ammo_enrollment_spec.lua:** `tx.query(sql,p)`, `tx:SetMetadata(id,document,revision)`, `tx:GetItemForUpdate()`, `tx:RequireAccess()`, `tx:AddQuantity(_,_,amount)`, `tx:RemoveQuantity(_,_,amount)`, `tx:GetQuantity()`

**tests/lua/character_ammo_observation_spec.lua:** `tx.query(sql,p)`, `tx:SetMetadata(id,document,revision)`

**tests/lua/character_ammo_spec.lua:** `tx:RequireAccess()`, `tx:RemoveQuantity(_, _, amount)`, `tx:AddQuantity(_, _, amount)`, `tx:RemoveQuantity(...)`

**tests/lua/consumption_once_spec.lua:** `tx.query(sql,p)`, `tx:GetItemForUpdate(id)`, `tx:RemoveInstances(inv,def,ids)`, `tx:SetMetadata(id,metadata,revision)`

**tests/lua/fixtures/native_john_fixture_legacy.lua:** `NativeJohnMultiplayerFixture.Apply(tx,current,limits,itemContract,definition)`

**tests/lua/instance_change_guard_spec.lua:** `tx:SetMetadata(id,doc,revision)`

**tests/lua/native_attachment_commit_spec.lua:** `tx:GetItemForUpdate(id)`, `tx:RemoveQuantity(inv,id,count)`, `tx:AddQuantity(inv,id,count,metadata)`, `tx:SetMetadata(id,metadata,revision)`

**tests/lua/native_attachment_composition_spec.lua:** `tx:GetItemForUpdate(id)`, `tx:SetMetadata(id,metadata,revision)`, `tx:RemoveQuantity(inv,id,count)`, `tx:AddQuantity(inv,id,count)`

**tests/lua/native_attachment_material_spec.lua:** `tx:GetQuantity(inventory,id)`

**tests/lua/native_broken_equipment_spec.lua:** `tx.query(sql,p)`, `tx:GetItemForUpdate(id)`, `tx:SetMetadata(id,value,revision)`, `tx.query(sql,p)`

**tests/lua/native_evidence_commit_spec.lua:** `tx:GetItemForUpdate(id)`, `tx:SetMetadata(id,metadata,revision)`

**tests/lua/native_issuance_spec.lua:** `tx:CreateInstance(inv,id,metadata)`

**tests/lua/native_john_fixture_spec.lua:** `tx:CreateInstance(inv,id,metadata)`, `tx:AddQuantity(inv,id,amount)`

**tests/lua/native_repair_commit_spec.lua:** `tx.query(sql)`, `tx:GetItemForUpdate(id)`, `tx:RemoveQuantity(inventory,id,quantity)`, `tx:SetMetadata(id,metadata,revision)`

**tests/lua/native_repair_fixture_spec.lua:** `tx.query(sql,args)`, `tx:GetItemForUpdate(id)`, `tx:CreateInstance(inventory,id,value)`, `tx:AddQuantity(inventory,id,quantity)`

**tests/lua/native_repair_material_spec.lua:** `tx:GetQuantity(inventoryId,itemId)`

**tests/lua/native_saved_attachment_fixture_spec.lua:** `tx:GetItemForUpdate(id)`, `tx:SetMetadata(id,document,revision)`

**tests/lua/native_throwable_funding_atomic_spec.lua:** `tx.query(sql,p)`, `tx:RequireAccess()`, `tx:RemoveQuantity(_,id,n)`, `tx:AddQuantity(_,id,n)`

**tests/lua/native_throwable_recovery_claim_spec.lua:** `tx.query(sql,p)`, `tx:AddQuantity(inv,id,qty)`

**tests/lua/unique_grants_spec.lua:** `tx:CreateInstance(inv,id,metadata)`
