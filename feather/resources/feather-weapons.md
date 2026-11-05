# feather-weapons

Version 0.19.0. The official weapon system for Feather framework.

Current version: **0.19.0**. Feather's native-only, Inventory-backed firearm system. Weapons are unique item instances; equipped assignments and maintenance persist per character.

Source: https://github.com/FeatherFramework/feather-weapons

**Dependencies:** `feather-mysql`, `feather-core`, `feather-character`, `feather-medical`, `feather-inventory`, `feather-menu-v2`

## Exports (call as exports['feather-weapons']:Name)

**server:** `ApplyInventoryMoveDelivery(id,raw)`, `AuditInventoryMoveDelivery(id,raw)`, `DestroyWeapon(request, context)`, `HoldWeaponEvidence(request, context)`, `InspectWeaponHistory(request, context)`, `IssueWeapon(request, context)`, `ReadNativeEvidenceStatus(target,itemId)`, `ReadNativeMaintenanceAuditSpec(target,itemId)`, `ReadNativeRepairAuditSpec(target,itemId)`, `ReleaseWeaponEvidence(request, context)`, `ValidateCharacterAmmoRuntimeOperation(context,operation,spec)`, `ValidateNativeEquipmentCommit(context,spec)`, `ValidateNativeEvidenceCommit(context,spec)`, `ValidateNativeIssuance(context,spec)`, `initiate()`

**client:** `ChangeNativeAttachment(itemId,action,scope,attachmentId)`, `ChangeNativeEquipment(itemId,action,slot,scope)`, `CheckpointBeforeLogout()`, `CheckpointCharacterAmmunitionBeforeLogout(context)`, `CheckpointJanePrimaryLogout(context)`, `GetNativeAmmunitionControls(itemName)`, `GetNativeEquipmentControls(itemId)`, `RepairNativeEquipment(itemId,scope)`, `TransferNativeAmmunition(id,quantity,direction,scope)`, `initiate()`

## Net events registered

**server:** `feather-weapons:jane-economic:ack`, `feather-weapons:jane-economic:auto-ready`, `feather-weapons:jane-zero:ack`, `feather-weapons:jane-zero:login-ready`, `feather-weapons:jane-zero:startup-ready`, `feather-weapons:server:acceptance-report`, `feather-weapons:server:character-ammo`, `feather-weapons:server:character-ammo-ready`, `feather-weapons:server:client-ready`, `feather-weapons:server:native-equipment-released`, `feather-weapons:server:native-equipment-restored`, `feather-weapons:server:native-equipment-ui`, `feather-weapons:server:native-logout-wear`, `feather-weapons:server:native-maintenance-report`

**client:** `feather-weapons:client:acceptance-read`, `feather-weapons:client:attachmentResult`, `feather-weapons:client:character-ammo`, `feather-weapons:client:character-ammo-loadout`, `feather-weapons:client:character-ammo-ready`, `feather-weapons:client:clear`, `feather-weapons:client:clearAuthorization`, `feather-weapons:client:forceReconcile`, `feather-weapons:client:inventoryAmmoResult`, `feather-weapons:client:inventoryRepairResult`, `feather-weapons:client:native-equipment-release`, `feather-weapons:client:native-equipment-result`, `feather-weapons:client:native-logout-wear-result`, `feather-weapons:client:native-maintenance-read`, `feather-weapons:client:reconcile`, `feather-weapons:client:repairSlotRequested`, `feather-weapons:client:runtime-ready`, `feather-weapons:client:useInventoryWeapon`, `feather-weapons:jane-economic:failed`, `feather-weapons:jane-economic:released`, `feather-weapons:jane-economic:reply`, `feather-weapons:jane-zero:begin`, `feather-weapons:jane-zero:login-arm`

## Event handlers

**server:** `Feather:Inventory:ItemMoved`, `core.session.leaving.v1`, `core.session.left.v1`, `core.session.ready.v1`, `entityCreated`, `entityRemoved`, `startProjectileEvent`

**client:** `Feather:Character:Logout`, `Feather:Character:Spawned`, `feather-character:client:runtime-ready.v1`, `feather-medical:client:condition-changed.v1`

## Commands (RegisterCommand)

**server:** `/WeaponJaneAmmoRead`, `/WeaponJaneEconomic`, `/WeaponJanePrimaryAutoLogin`, `/WeaponJanePrimaryAutoRecover`, `/WeaponJanePrimaryLogin`, `/WeaponJanePrimaryLogout`, `/WeaponJanePrimaryNative`, `/WeaponJanePrimaryRecover`, `/WeaponJanePrimaryRoundtrip`, `/WeaponJaneSession`, `/WeaponJaneZero`, `/WeaponNativeAcceptance`, `/WeaponNativeArmAttachmentDisconnect`, `/WeaponNativeAttachmentChange`, `/WeaponNativeAttachmentStatus`, `/WeaponNativeEquipmentChange`, `/WeaponNativeEquipmentDryRun`, `/WeaponNativeEvidenceChange`, `/WeaponNativeEvidenceStatus`, `/WeaponNativeIssuanceStatus`, `/WeaponNativeIssue`, `/WeaponNativeKnifeStatus`, `/WeaponNativeMaintenanceCheckpoint`, `/WeaponNativeOverlapProbe`, `/WeaponNativePeriodicWearStatus`, `/WeaponNativePrepareStop`, `/WeaponNativePrepareStopAll`, `/WeaponNativeProjectileProbe`, `/WeaponNativeRecoveryStatus`, `/WeaponNativeRepair`, `/WeaponNativeRepairStatus`, `/WeaponNativeShutdownStatus`, `/WeaponNativeThrowableFunding`, `/WeaponNativeThrowableStatus`, `/WeaponNativeUtilityStatus`, `/WeaponProvenanceInspect`, `/WeaponRestartAcceptance`

**client:** `/WeaponDualEntitlementRemove`, `/WeaponJaneZeroCleanup`, `/WeaponNativeProbeClear`, `/WeaponNativeProbeCompare`, `/WeaponNativeProbeDualAllow`, `/WeaponNativeProbeDualEntitle`, `/WeaponNativeProbeDualPrepare`, `/WeaponNativeProbeDualStatus`, `/WeaponNativeProbeDualWatch`, `/WeaponNativeProbeHolsterPrepare`, `/WeaponNativeProbeHolsterStatus`, `/WeaponNativeProbeMark`, `/WeaponNativeProbePrepare`, `/WeaponNativeProbeSpecial`, `/WeaponNativeProbeStatus`, `/WeaponNativeProbeWatch`, `/weaponNativeChildComponentProbe`, `/weaponNativeComponentSlotStatus`, `/weaponNativeEntityStatus`, `/weaponNativeGuidComponentProbe`, `/weaponNativeMaintenanceStatus`, `/weaponNativeProjectileSnapshot`, `/weaponNativeStatus`, `/weapondeathaftershots`, `/weaponmaintenance`, `/weaponruntime`, `/weaponstate`, `/weaponthrowablecapacity`, `/weaponthrowablepoolfailure`, `/weaponthrowableselection`

## Public (table) functions

**.luals/cfx-runtime.lua:** `Citizen.InvokeNative(hash, ...)`, `Citizen.CreateThread(cb)`, `Citizen.CreateThreadNow(cb)`, `Citizen.Wait(ms)`, `Citizen.Trace(msg)`, `Citizen.Await(value)`, `promise.new()`, `json.encode(value)`, `json.decode(str)`

**client/character_ammunition_actions.lua:** `WeaponCharacterAmmoActions.New(api)`, `T.Options(itemName)`, `T.Transfer(id,quantity,direction,scope)`

**client/character_ammunition_checkpoint.lua:** `WeaponCharacterAmmoCheckpoint.Lifecycle(api)`, `T.Reply(id,scope,result,serverOrigin)`, `T.Run(context)`, `WeaponCharacterAmmoCheckpoint.New(receiver,api)`, `T.Run(context)`

**client/character_ammunition_client_runtime.lua:** `WeaponCharacterAmmoNativeAdapters.New(creation,owned,send)`, `WeaponCharacterAmmoClientRuntime.New(api)`, `T.Receive(bundle,origin)`, `T.Step()`, `T.Transfer(...)`, `T.Checkpoint(context)`, `T.ReleaseEquipment(identity,ticket,collectWear)`, `T.Suspend(reason)`, `T.ReadDeathObservation()`, `T.Status()`, `WeaponCharacterAmmoClientBootstrap.New(adapters,bindings)`, `T.Frame()`, `T.Start()`, `T.Status()`, `T.Transfer(...)`

**client/character_ammunition_context.lua:** `WeaponCharacterAmmoContext.New(api)`, `T.Identity()`, `T.Read()`, `T.ReadDeath()`, `T.Ready()`

**client/character_ammunition_controller.lua:** `WeaponCharacterAmmoController.New(api,pickupAck)`, `T.Begin(value,names,limits)`, `T.Tick()`, `T.Finalize()`, `T.Transfer(ammunitionId,amount,operationId)`, `T.FinalizeDeath()`, `T.Close()`, `T.AllowDeathCleanup()`, `T.ConfirmCleanup()`, `T.Status()`

**client/character_ammunition_creation_native.lua:** `WeaponCharacterAmmoCreationNative.SelectEquippedChild(stock,wide)`, `WeaponCharacterAmmoCreationNative.DecodeEquippedChild(raw,result)`, `WeaponCharacterAmmoCreationNative.DecodeChildEquippedFlag(raw,result)`, `WeaponCharacterAmmoCreationNative.DecodeDiagnosticGuid(raw)`, `WeaponCharacterAmmoCreationNative.New(ped,current,prepareDual,applyMaintenance,guidIdentity,savedAttachments)`, `WeaponCharacterAmmoCreationNative.Scoped(ped,identity,prepareDual,cleanupDual)`

**client/character_ammunition_driver.lua:** `WeaponCharacterAmmoDriver.New(host,api)`, `T.Receive(bundle,origin)`, `T.Step()`, `T.Status()`

**client/character_ammunition_dual_native.lua:** `WeaponCharacterAmmoDualNative.New(ped,current)`, `T.Cleanup()`, `T.Ensure()`, `T.Status()`

**client/character_ammunition_host.lua:** `WeaponCharacterAmmoHost.New(adapters)`, `T.ReadDeathObservation()`, `T.Receive(bundle,serverOrigin)`, `T.Tick()`, `T.Checkpoint(value)`, `T.Finalize()`, `T.Transfer(id,amount,operationId)`, `T.FinalizeDeath()`, `T.Cleanup()`, `T.RecoverDeath()`, `T.Quiesce()`, `T.PrepareEquipmentRelease(...)`, `T.Suspend(reason)`, `T.Status()`

**client/character_ammunition_lifecycle.lua:** `WeaponCharacterAmmoLifecycle.New(host,api)`, `T.Step()`, `T.Status()`

**client/character_ammunition_loadout.lua:** `WeaponCharacterAmmoLoadout.New(api)`

**client/character_ammunition_native.lua:** `WeaponCharacterAmmoNative.New(names,limits,api)`, `N.Read(ped,ready)`, `N.Restore(value,ped,ready)`

**client/character_ammunition_native_owner.lua:** `WeaponCharacterAmmoNativeOwner.New(dependencies)`, `T.ProbeGuidComponent(action)`, `T.InspectTrackedEntities()`, `T.MaintenanceStatus(allowReserved)`, `T.FinalWear(identity)`, `T.DeathWear(context)`, `T.StopZeroAmmo()`, `T.Start()`, `T.Status()`, `T.Readiness()`, `T.BindReadiness()`, `T.Transfer(id,amount,operationId,scope)`, `T.Recovery()`

**client/character_ammunition_owner.lua:** `WeaponCharacterAmmoOwner.New(api,registry)`, `T.Receive(bundle)`, `T.Tick()`, `T.Finalize()`, `T.Transfer(id,amount,operationId)`, `T.FinalizeDeath()`, `T.Cleanup()`, `T.RecoverDeath()`, `T.Status()`

**client/character_ammunition_receiver.lua:** `WeaponCharacterAmmoReceiver.New(api,registry)`, `T.Quiesce()`, `T.Suspend(reason)`, `T.Receive(bundle,serverOrigin)`, `T.Tick()`, `T.Finalize()`, `T.Transfer(id,amount,operationId)`, `T.PrepareEquipmentRelease(identity,ticket)`, `T.FinalizeDeath()`, `T.Cleanup()`, `T.RecoverDeath()`, `T.Status()`

**client/character_ammunition_release.lua:** `WeaponCharacterAmmoRelease.New(receiver,api)`, `T.Request(timeoutMs)`, `T.Step()`, `T.Status()`

**client/character_ammunition_routes.lua:** `WeaponCharacterAmmoClientIngress.Install(runtime)`, `WeaponCharacterAmmoClientBindings.NativeAdapters(creation,owned)`, `WeaponCharacterAmmoClientBindings.New(enforceInput)`, `WeaponCharacterAmmoClientBindings.Bootstrap(creation,owned,knife,melee,throwable,utility)`, `WeaponCharacterAmmoClientBindings.Readiness(owner)`

**client/character_ammunition_session.lua:** `WeaponCharacterAmmoSession.New(api,registry)`, `T.Begin(bundle)`, `T.Tick()`, `T.Finalize()`, `T.Transfer(id,amount,operationId)`, `T.FinalizeDeath()`, `T.Cleanup()`, `T.RecoverDeath()`, `T.Status()`

**client/character_maintenance_native.lua:** `WeaponNativeAttachmentReconstruction.New(api)`, `T.Apply(record,plan)`, `T.Cleanup(record)`, `T.Pending(record)`, `T.AnyPending()`, `WeaponNativeAttachmentReconstruction.Bind(base,project,manager)`, `WeaponNativeAttachmentChild.New(api)`, `WeaponNativeAttachmentSlots.Catalog(catalog,read)`, `WeaponNativeAttachmentSlots.Read(api)`, `WeaponNativeGuidIdentity.New(api,observationPoints)`, `T.Capture(record,identity)`, `T.Resolve(record,identity,exclusive)`, `T.Has(record)`, `T.MatchesCaptured(record,identity,guid)`, `WeaponCharacterMaintenanceNative.New(api)`, `T.Read(record,identity)`, `T.Apply(record,identity,maintenance)`, `WeaponCharacterMaintenanceNative.Scoped(ped,current,resolveOwned)`, `WeaponCharacterMaintenanceNative.DeathReadOnly(ped,identity,readContext)`

**client/native_knife_owner.lua:** `WeaponNativeKnifeOwner.New(api,definition,identity)`, `T.Status()`, `T.Create(row)`, `T.Release(deathRecovery)`, `WeaponNativeKnifeOwner.Scoped(ped,identity,current,definition)`

**client/native_melee_owner.lua:** `WeaponNativeMeleeOwner.New(approval,catalog,identity,factory,current)`, `T.Status()`, `T.Create()`, `T.Release(deathRecovery)`

**client/native_throwable_adapter.lua:** `WeaponNativeThrowableAdapter.Scoped(ped,identity,current,sealed,catalog,registry)`

**client/native_throwable_owner.lua:** `WeaponNativeThrowableOwner.New(api,catalog,identity,limits)`, `T.Status()`, `T.Create(snapshot)`, `T.Observe(baseline)`, `T.AcceptNativePickup(baseline)`, `T.Release()`

**client/native_utility_adapter.lua:** `WeaponNativeUtilityAdapter.Scoped(ped,identity,current,sealed,def)`

**client/native_utility_collection.lua:** `WeaponNativeUtilityCollection.New(factory,ped,bound,sealed)`, `T.Create(approval)`, `T.Release()`, `T.Status()`

**client/native_utility_owner.lua:** `WeaponNativeUtilityOwner.New(api,def,identity)`, `T.Status()`, `T.Create(candidate)`, `T.Release()`

**server/adapters/character_ammunition_inventory.lua:** `WeaponCharacterAmmoInventory.New(getInventory,isBound,administrativePolicy,canUninstall)`, `T.Install()`, `T.Status()`, `T.Uninstall()`, `WeaponNativeOwnershipInventory.New(getInventory)`, `T.Install()`, `T.ResolveWeaponDefinitionId(id)`, `T.GetInstance(context,id)`, `T.GetCharacterInventory(context,characterId)`, `T.IsReady()`

**server/adapters/core.lua:** `CoreAdapter.NormalizeCharacterId(value)`, `CoreAdapter.CheckCapabilities()`, `CoreAdapter.CheckCharacterCapabilities()`, `CoreAdapter.ResolveSession(source)`, `CoreAdapter.IsSessionCurrent(source, sessionId, characterId)`

**server/services/api.lua:** `WeaponAPI.GetCapabilities()`, `WeaponAPI.GetDefinition(kind, id)`, `WeaponAPI.ListDefinitions(kind)`, `WeaponAPI.ListCompatibleAttachments(weaponId)`, `WeaponAPI.IssueWeapon(request, context, invokingResource)`, `WeaponAPI.DestroyWeapon(request, context, invokingResource)`, `WeaponAPI.InspectWeaponHistory(request, context, invokingResource)`, `WeaponAPI.HoldEvidence(request, context, resource)`, `WeaponAPI.ReleaseEvidence(request, context, resource)`

**server/services/attachments.lua:** `AttachmentService.AuthorizeNativeModification(source,context,operation,weapon,attachment)`

**server/services/character_ammunition_dispatch.lua:** `WeaponCharacterAmmoDispatcher.Start(source)`

**server/services/character_ammunition_repository.lua:** `R.Lock(query, characterId)`, `R.Create(query, characterId, pools)`, `R.Write(query, record, expectedRevision)`, `R.Receipt(query, characterId, operationId)`, `R.RecordReceipt(query, characterId, operationId, result)`

**server/services/character_ammunition_runtime.lua:** `S.Open(source,limits)`, `S.ConfirmRestore(source,report)`, `S.OpenLoadout(source,catalog,policy)`, `S.ReadRecoveryStatus(source)`, `S.ReconcileSession(source,identity)`, `S.ValidateLoadout(source)`, `S.IsNativeItemBound(itemId)`, `S.CanReleaseInventoryGuards()`, `S.ReadBoundMaintenanceItems(source)`, `S.IsDeathWearWriteAuthorized(itemId,context)`, `S.IsDeathEquipmentWriteAuthorized(itemId,context)`, `S.FreezeLoadout(source,identity)`, `S.Observe(source,report)`, `S.NativePickup(source,report)`, `S.Transfer(source,report,id,amount,operationId)`, `S.CheckpointAndSeal(source,report)`, `S.ConfirmCleanup(source,report)`, `S.Revoke(source,sessionId,reason)`

**server/services/definition_registry.lua:** `DefinitionRegistry.Start()`, `DefinitionRegistry.ValidateAttachmentSet(weaponId, installed)`, `DefinitionRegistry.IsAttachmentCompatible(weaponId, attachmentId)`, `DefinitionRegistry.ListCompatibleAttachments(weaponId)`, `DefinitionRegistry.IsReady()`, `DefinitionRegistry.Get(kind, id)`, `DefinitionRegistry.List(kind)`, `DefinitionRegistry.Counts()`

**server/services/evidence.lua:** `WeaponEvidenceService.SetHold(context, request, invokingResource, held)`, `WeaponEvidenceService.NativeAvailable()`, `WeaponEvidenceService.ValidateNativeCommit(context,spec)`, `WeaponEvidenceService.NativeChange(context,request,resource,held)`, `WeaponEvidenceService.NativeStatus(target,itemId)`, `WeaponEvidenceService.Hold(context, request, resource)`, `WeaponEvidenceService.Release(context, request, resource)`, `WeaponEvidenceService.CheckContract()`

**server/services/issuance.lua:** `IssuanceService.NativeAvailable()`, `IssuanceService.Issue(context, request, invokingResource)`, `IssuanceService.CheckContract()`

**server/services/metadata.lua:** `WeaponMetadata.Build(definition, options)`, `WeaponMetadata.Validate(metadata,definition,correlationId)`

**server/services/move_delivery.lua:** `D.Facts(id,raw)`, `D.Apply(id,raw)`, `D.Start()`, `D.Audit(id,raw)`

**server/services/native_acceptance_suite.lua:** `S.New(api)`, `T.Status()`, `T.Run(again)`, `T.Visual(value)`

**server/services/native_equipment_transition.lua:** `WeaponNativeShutdownDrain.New(api)`, `T.IsLatched()`, `T.Status()`, `T.Begin()`, `WeaponNativePeriodicWear.New(api)`, `T.Step(target)`, `T.Complete(target,scope,outcome)`, `T.Forget(target,sessionId)`, `T.Status(target)`, `WeaponNativeEquipmentTransition.ProbeOverlap(coordinator,target,bound)`, `WeaponNativeEquipmentBindings.AcceptanceTransition(target,overlap)`, `WeaponNativeEquipmentBindings.AcceptanceStatus(target)`, `WeaponNativeEquipmentBindings.Attach(source,bundle)`, `WeaponNativeEquipmentBindings.IsStopping(source)`, `WeaponNativeEquipmentBindings.RetireSession(target,sessionId)`, `WeaponNativeEquipmentBindings.ReconcileSession(target,context)`, `WeaponNativeEquipmentTransition.New(api)`, `T.Begin(source,intent)`, `T.Released(source,ticket,hint,wear)`, `T.CanCommit(context,spec)`, `T.Restored(source,ticket,hint)`, `T.Cancel(source,sessionId)`, `T.Status(source)`, `T.Retire(source,sessionId)`

**server/services/native_throwable_projectile_observer.lua:** `WeaponNativeThrowableProjectileObserver.New(api)`, `O.ProjectileHint(source,data)`, `O.Created(handle)`, `O.Removed(handle)`, `O.Read(handle)`

**server/services/native_throwable_recovery_coordinator.lua:** `WeaponNativeThrowableRecoveryCoordinator.New(api)`, `O.Begin(context,plan)`, `O.Status(spendId)`

**server/services/ownership.lua:** `WeaponOwnershipService.EvaluateAdministrativeHold(metadata)`, `WeaponOwnershipService.HandleCommittedMove(payload)`, `WeaponOwnershipService.GetDiagnostics()`, `WeaponOwnershipService.Destroy(context, request, invokingResource)`, `WeaponOwnershipService.CheckDestructionContract()`

**server/services/provenance.lua:** `WeaponProvenanceService.Start()`, `WeaponProvenanceService.Record(fact)`, `WeaponProvenanceService.Inspect(request, context, invokingResource)`, `WeaponProvenanceService.IsReady()`, `WeaponProvenanceService.FindIssuanceEvent(itemInstanceId, correlationId)`, `WeaponProvenanceService.CheckContract()`

**shared/ammunition_migration_preview.lua:** `WeaponAmmoMigrationPreview.Build(items, catalog, limits)`

**shared/ammunition_pools.lua:** `WeaponAmmunitionPools.Allocate(previous, observed, owners, shots)`

**shared/character_ammunition.lua:** `A.Validate(pools, limits)`, `A.Observe(record, report, limits)`, `A.Transfer(record, id, amount, limits)`

**shared/character_ammunition_activation.lua:** `WeaponCharacterAmmoActivation.New(api)`, `T.Ready(source,hint)`, `T.Cancel(source,sessionId)`

**shared/character_ammunition_catalog.lua:** `WeaponCharacterAmmoCatalog.Build(catalog,policy)`

**shared/character_ammunition_client.lua:** `WeaponCharacterAmmoClient.New()`, `C.Begin(value,caps,currentPed)`, `C.Prepare(currentPed,pools,worldReady)`, `C.PrepareFinal(currentPed,pools,worldReady)`, `C.PrepareNativePickup(currentPed,pools,worldReady)`, `C.PrepareTransfer(currentPed,pools,worldReady,ammunitionId,amount,operationId)`, `C.PrepareCleanup(currentPed)`, `C.Accept(id,result,currentPed)`, `C.Close()`, `C.Status()`

**shared/character_ammunition_dispatch.lua:** `WeaponCharacterAmmoDispatch.New(api)`, `T.Start(source,catalog,policy)`, `T.ConfirmRestore(source,report)`, `T.Observe(source,report)`, `T.NativePickup(source,report)`, `T.Transfer(source,report)`, `T.CheckpointAndSeal(source,report)`, `T.ConfirmCleanup(source,report)`, `T.Forget(source,sessionId)`, `T.Status(source)`

**shared/character_ammunition_item.lua:** `WeaponCharacterAmmoItem.Validate(metadata,definition)`, `WeaponCharacterAmmoItem.Loadout(rows,catalog,registry)`

**shared/character_ammunition_loadout_lease.lua:** `WeaponCharacterAmmoLoadoutLease.Guard(isBound)`, `WeaponCharacterAmmoLoadoutLease.New(plan,knifeApproval,meleeApproval,throwableSnapshot,limits,utilitySnapshot)`

**shared/character_ammunition_materialization.lua:** `WeaponNativeAttachmentProjection.Build(item,catalog,identity)`, `WeaponNativeAttachmentProjection.BuildCatalog(item,catalog,identity)`, `WeaponCharacterAmmoMaterialization.Validate(plan,registry,baseline)`, `WeaponCharacterAmmoMaterialization.Build(rows,catalog,registry,identity)`

**shared/character_ammunition_policy.lua:** `WeaponCharacterAmmoPolicy.Limits()`, `WeaponCharacterAmmoPolicy.Build(catalog)`

**shared/character_ammunition_readiness.lua:** `WeaponCharacterAmmoReadiness.Server(api)`, `T.Receive(source,id,hint)`, `T.Cancel(source,sessionId)`, `WeaponCharacterAmmoReadiness.Client(api)`, `T.Step()`, `T.Reply(id,hint,ok,reason,serverOrigin)`

**shared/character_ammunition_runtime.lua:** `WeaponCharacterAmmoRuntime.New(isCurrent)`, `R.Open(context,baseline,limits,epoch)`, `R.ConfirmRestore(source,report)`, `R.PrepareObservation(source,report)`, `R.PrepareFinalObservation(source,report,finalWear)`, `R.PrepareNativePickup(source,report,plan)`, `R.PrepareTransfer(source,report,id,amount,operationId)`, `R.IsOperationCurrent(context,operation,spec)`, `R.Complete(context,result)`, `R.Seal(source,sessionId,epoch)`, `R.Revoke(source,sessionId)`, `R.ConfirmCleanup(source,report)`, `R.Get(source)`

**shared/character_ammunition_transport.lua:** `WeaponCharacterAmmoTransport.Server(api)`, `WeaponCharacterAmmoTransport.Client(api)`, `T.Send(kind,id,report,callback)`, `T.Close()`

**shared/character_attachments.lua:** `WeaponCharacterAttachments.PlanCatalog(metadata,weapon,attachment,action)`, `WeaponCharacterAttachments.Plan(metadata,weapon,attachment,action)`

**shared/character_lifecycle_wear.lua:** `WeaponCharacterLifecycleWear.DeathReport(value)`, `WeaponCharacterLifecycleWear.BrokenEquipment(rows,catalog)`, `WeaponCharacterLifecycleWear.ProjectBroken(rows,detached)`, `WeaponCharacterLifecycleWear.Plan(rows,readback,catalog,epoch,allowBroken)`

**shared/character_maintenance.lua:** `WeaponCharacterMaintenance.Observe(metadata,definition,report)`, `WeaponCharacterMaintenance.Repair(metadata,definition)`

**shared/constants.lua:** `WeaponNativeEnrollment.Validate(config)`, `WeaponNativeEnrollment.Allows(config,characterId)`

**shared/definitions/attachments.lua:** `WeaponNativeAttachmentMappings.CaptureModel(name)`, `WeaponNativeAttachmentMappings.Resolve(weapon,attachment,requireReconstruction)`, `WeaponNativeAttachmentMappings.ValidateSet(weapon,saved,requireReconstruction)`

**shared/errors.lua:** `WeaponResult.Ok(value, correlationId)`, `WeaponResult.Error(code, message, details, correlationId)`

**shared/native_acceptance_view.lua:** `V.Equal(a,b)`, `V.Normalize(v)`, `V.Read(owner,bound)`, `V.MatchesDurable(view,durable,limits)`

**shared/native_advanced_camera_policy.lua:** `WeaponNativeAdvancedCameraPolicy.Resolve(def)`

**shared/native_binoculars_policy.lua:** `WeaponNativeBinocularsPolicy.Resolve(def)`

**shared/native_camera_policy.lua:** `WeaponNativeCameraPolicy.Resolve(def)`

**shared/native_davy_lantern_policy.lua:** `WeaponNativeDavyLanternPolicy.Resolve(def)`

**shared/native_fishing_rod_policy.lua:** `WeaponNativeFishingRodPolicy.Resolve(def)`

**shared/native_improved_binoculars_policy.lua:** `WeaponNativeImprovedBinocularsPolicy.Resolve(def)`

**shared/native_knife.lua:** `WeaponNativeKnife.Enabled()`, `WeaponNativeKnife.Validate(metadata,def)`, `WeaponNativeKnife.Build(def,options)`, `WeaponNativeKnife.Project(row,def,identity)`, `WeaponNativeKnife.Assigned(snapshot,def,identity)`, `WeaponNativeKnife.ValidateApproval(approval,def,identity)`, `WeaponNativeKnife.Prepare(snapshot,def,identity,intent)`

**shared/native_lasso_policy.lua:** `P.Resolve(def)`, `P.ValidateAssignments(equipment,catalog)`

**shared/native_melee_catalog.lua:** `WeaponNativeMeleeCatalog.Enabled()`, `WeaponNativeMeleeCatalog.Resolve(def)`, `WeaponNativeMeleeCatalog.Slots()`, `WeaponNativeMeleeCatalog.Project(snapshot,catalog,identity)`, `WeaponNativeMeleeCatalog.ValidateApproval(approval,catalog,identity)`, `WeaponNativeMeleeCatalog.Prepare(snapshot,catalog,identity,intent)`

**shared/native_metal_detector_policy.lua:** `WeaponNativeMetalDetectorPolicy.Resolve(def)`

**shared/native_restart_acceptance.lua:** `R.Conserved(a,b,equal)`, `R.Compare(a,b)`, `R.New(api)`, `T.Status()`, `T.Busy()`, `T.Prepare(mode)`, `T.RetryPreflight()`, `T.Verify()`, `T.Inspect()`, `T.Visual(value)`

**shared/native_throwable_item.lua:** `WeaponNativeThrowableItem.Prepare(snapshot,catalog,identity,intent)`, `WeaponNativeThrowableItem.Validate(metadata,catalog)`, `WeaponNativeThrowableItem.Build(catalog,options)`, `WeaponNativeThrowableItem.Assigned(snapshot,catalog,identity,limits)`

**shared/native_throwable_policy.lua:** `WeaponNativeThrowablePolicy.Enabled()`, `WeaponNativeThrowablePolicy.Resolve(catalog)`, `WeaponNativeThrowablePolicy.Preview(catalog,firearmRegistry)`, `WeaponNativeThrowablePolicy.RegistryFromLimits(catalog,limits)`

**shared/native_throwable_recovery.lua:** `WeaponNativeThrowableRecovery.NativePickupPlan(credit,current,snapshot,report,catalog,limits)`, `WeaponNativeThrowableRecovery.BindingPlan(candidate,durable,observed)`, `WeaponNativeThrowableRecovery.SpendCandidate(before,after,snapshot,catalog,limits)`

**shared/native_utility_catalog.lua:** `WeaponNativeUtilityCatalog.Enabled()`, `WeaponNativeUtilityCatalog.Resolve(def)`, `WeaponNativeUtilityCatalog.ReinforcedEnabled()`, `WeaponNativeUtilityCatalog.Slots()`, `WeaponNativeUtilityCatalog.ImprovedBinocularsEnabled()`, `WeaponNativeUtilityCatalog.AdvancedCameraEnabled()`, `WeaponNativeUtilityCatalog.CameraEnabled()`, `WeaponNativeUtilityCatalog.BinocularsEnabled()`, `WeaponNativeUtilityCatalog.DavyEnabled()`, `WeaponNativeUtilityCatalog.MetalDetectorEnabled()`, `WeaponNativeUtilityCatalog.FishingRodEnabled()`

**shared/native_utility_collection.lua:** `U.Entries(approval)`, `U.ValidateCollection(approval,catalog,bound)`, `U.AssignedSnapshot(snapshot,catalog,bound)`, `U.Prepare(snapshot,def,bound,intent)`

**shared/native_utility_item.lua:** `U.Validate(metadata,def)`, `U.Build(def,options)`, `U.Project(row,def,bound)`, `U.Assigned(snapshot,def,bound)`, `U.ValidateApproval(approval,def,bound)`, `U.LassoAssigned(snapshot,catalog,bound)`, `U.ValidateLassoApproval(approval,catalog,bound)`, `U.AssignedSnapshot(snapshot,catalog,bound)`, `U.Prepare(snapshot,def,bound,intent)`

**shared/validation.lua:** `WeaponValidation.AcceptsAmmunition(definition, ammunitionType)`, `WeaponValidation.EscrowMaximum(definition, ammunitionType)`, `WeaponValidation.Definition(definition, expectedKind)`, `WeaponValidation.Metadata(metadata, definition)`

**tests/ammunition.lua:** `TestInventoryAdapter.GetItemForCharacter(_, id)`, `TestInventoryAdapter.MutateWeaponMetadataBatch(_, mutations)`, `TestInventoryAdapter.Transaction(_, callback)`, `tx:GetItemForUpdate(id)`, `tx:GetQuantity(name)`, `tx:RemoveQuantity(name, amount)`, `tx:AddQuantity(name, amount)`, `tx:SetMetadata(id, metadata, revision)`

**tests/archive/client/firearm_pools.lua:** `FeatherFirearmPools.Reset()`, `FeatherFirearmPools.UpdateLonggunWindow(ped, selectedWeapon, catalog)`, `FeatherFirearmPools.Restore(ped, slots, catalog)`, `FeatherFirearmPools.Capture(ped, catalog)`, `FeatherFirearmPools.Accept(capture)`

**tests/archive/client/guid_weapons.lua:** `FeatherGuidWeapons.NewBuffer(length)`, `FeatherGuidWeapons.ResolveGuid(inventoryId, parentGuid, category, slotId)`, `FeatherGuidWeapons.ResolveExisting(weaponName)`, `FeatherGuidWeapons.SelectExistingAmmo(ped, weaponName, ammoName)`, `FeatherGuidWeapons.HasSelectedAmmo(ped, record, ammoName)`, `FeatherGuidWeapons.SetSelectedAmmo(ped, record, ammoName)`, `FeatherGuidWeapons.Activate(ped, pair)`, `FeatherGuidWeapons.CreateMatchingPair(ped, weaponName)`, `FeatherGuidWeapons.AwaitInventoryReady(timeoutMs)`, `FeatherGuidWeapons.ReadClip(ped, record)`, `FeatherGuidWeapons.ReadTotal(ped, record)`, `FeatherGuidWeapons.Destroy(pair)`

**tests/archive/client/main.lua:** `FeatherWeaponsClient.Checkpoint(callback, skipExtras)`, `FeatherWeaponsClient.Reconcile(callback, options)`, `FeatherWeaponsClient.Equip(itemInstanceId, callback, slot)`, `FeatherWeaponsClient.Unequip(callback, slot)`, `FeatherWeaponsClient.GetDiagnosticState()`, `FeatherWeaponsClient.Unload(amount, callback)`, `FeatherWeaponsClient.Repair(slot, callback)`, `FeatherWeaponsClient.GetShotDeathContext(mode)`

**tests/archive/client/native_maintenance.lua:** `FeatherNativeMaintenance.ResolveObject(ped, slot, nativeWeaponName)`, `FeatherNativeMaintenance.Read(ped, slot, state)`, `FeatherNativeMaintenance.Apply(ped, slot, state)`

**tests/archive/client/native_weapon_coordinator.lua:** `FeatherNativeWeaponCoordinator.GetStatus()`, `FeatherNativeWeaponCoordinator.Release(reason)`, `FeatherNativeWeaponCoordinator.PrepareCharacterRestore(ped, timeoutMs)`, `FeatherNativeWeaponCoordinator.ClearUnfundedPools(ped, slots, catalog)`, `FeatherNativeWeaponCoordinator.BuildPoolTotals(slots, catalog)`, `FeatherNativeWeaponCoordinator.RestorePoolTotals(ped, slots, catalog)`, `FeatherNativeWeaponCoordinator.TrackAmmoWindows(ped, slots)`, `FeatherNativeWeaponCoordinator.ReplenishAmmoWindows(ped, slots)`

**tests/archive/server/adapters/feather_inventory.lua:** `FeatherInventoryProvider.GetCapabilities()`, `FeatherInventoryProvider.GetItemForCharacter(context, itemInstanceId)`, `FeatherInventoryProvider.GetInstance(context, itemInstanceId)`, `FeatherInventoryProvider.GetCharacterInventory(context, characterId)`, `FeatherInventoryProvider.DestroyInstance(context, item)`, `FeatherInventoryProvider.ResolveWeaponDefinitionId(inventoryDefinitionId)`, `FeatherInventoryProvider.GetEquippedForCharacter(context)`, `FeatherInventoryProvider.SetEquippedForCharacter(context, itemInstanceId)`, `FeatherInventoryProvider.GetEquippedSlotsForCharacter(context)`, `FeatherInventoryProvider.ListWeaponsForCharacter(context)`, `FeatherInventoryProvider.SetEquippedSlotForCharacter(context, slot, itemInstanceId)`, `FeatherInventoryProvider.PromoteOffhandToPrimary(context)`, `FeatherInventoryProvider.CreateWeapon(context, definition, metadata)`, `FeatherInventoryProvider.Transaction(context, callback)`, `tx:GetItemForUpdate(itemInstanceId)`, `tx:GetQuantity(definitionName)`, `tx:RemoveQuantity(definitionName, quantity)`, `tx:AddQuantity(definitionName, quantity, metadata)`, `tx:SetMetadata(itemInstanceId, metadata, revision)`, `FeatherInventoryProvider.MutateWeaponMetadataBatch(context, mutations)`

**tests/archive/server/adapters/inventory.lua:** `InventoryAdapter.InstallProvider(candidate)`, `InventoryAdapter.IsReady()`, `InventoryAdapter.GetCapabilities()`, `InventoryAdapter.GetItemForCharacter(context, itemInstanceId)`, `InventoryAdapter.GetEquippedForCharacter(context)`, `InventoryAdapter.SetEquippedForCharacter(context, itemInstanceId)`, `InventoryAdapter.GetEquippedSlotsForCharacter(context)`, `InventoryAdapter.ListWeaponsForCharacter(context)`, `InventoryAdapter.SetEquippedSlotForCharacter(context, slot, itemInstanceId)`, `InventoryAdapter.MutateWeaponMetadataBatch(context, mutations)`, `InventoryAdapter.PromoteOffhandToPrimary(context)`, `InventoryAdapter.CreateWeapon(context, definition, metadata)`, `InventoryAdapter.GetInstance(context, itemInstanceId)`, `InventoryAdapter.GetCharacterInventory(context, characterId)`, `InventoryAdapter.DestroyInstance(context, item)`, `InventoryAdapter.ResolveWeaponDefinitionId(inventoryDefinitionId)`, `InventoryAdapter.Transaction(context, callback)`

**tests/archive/server/services/ammo.lua:** `AmmoService.NormalizeSharedPools(source, rpcContext)`, `AmmoService.Escrow(source, rpcContext, amount, ammunitionType)`, `AmmoService.LoadSlot(source, rpcContext, params)`, `AmmoService.SwitchSlot(source, rpcContext, params)`, `AmmoService.GetInventoryAvailability(source, rpcContext)`, `AmmoService.Unload(source, rpcContext, requested, requestedSlot, lease)`, `AmmoService.SyncPools(source, rpcContext, params)`, `AmmoService.SyncPoolBatch(source, rpcContext, params)`, `AmmoService.SyncConsumption(source, rpcContext, params)`, `AmmoService.SyncPair(source, rpcContext, params)`

**tests/archive/server/services/equip.lua:** `EquipService.ValidateOwnedItem(context, itemInstanceId)`, `EquipService.ValidateConfiguration()`, `EquipService.Request(source, rpcContext, itemInstanceId, slot)`, `EquipService.Acknowledge(source, rpcContext, token)`, `EquipService.Restore(source, session, itemInstanceId, correlationId, slot)`, `EquipService.Unequip(source, rpcContext, slot)`

**tests/archive/server/services/maintenance.lua:** `MaintenanceService.Sync(source, rpcContext, params)`

**tests/archive/server/services/reconciliation.lua:** `ReconciliationService.MarkStartupReady()`, `ReconciliationService.RehydrateSession(session)`, `ReconciliationService.Snapshot(source, sessionId, correlationId)`, `ReconciliationService.InspectMetadata(source)`, `ReconciliationService.Force(source)`, `ReconciliationService.BootstrapActiveSessions()`

**tests/archive/server/services/repair.lua:** `RepairService.Repair(source, rpcContext, request, allowOwned)`, `RepairService.BeginSelection(source, rpcContext, done)`, `RepairService.Select(source, rpcContext, request)`

**tests/archive/server/services/runtime.lua:** `WeaponRuntime.NormalizeSlot(slot)`, `WeaponRuntime.GetSlot(source, slot)`, `WeaponRuntime.Get(source)`, `WeaponRuntime.FindLeaseByItem(itemInstanceId)`, `WeaponRuntime.MatchesLease(source, sessionId, itemInstanceId, generation, slot)`, `WeaponRuntime.Begin(session)`, `WeaponRuntime.Clear(source)`, `WeaponRuntime.RestoreEquipped(source, sessionId, item, definition, correlationId, slot)`, `WeaponRuntime.BeginEquip(source, sessionId, item, definition, correlationId, slot)`, `WeaponRuntime.CompleteEquip(source, sessionId, token, correlationId)`, `WeaponRuntime.SetSlotAmmunitionType(source, sessionId, slot, ammunitionType)`, `WeaponRuntime.SetSlotAmmo(source, sessionId, slot, total, loaded, correlationId)`, `WeaponRuntime.SetSlotCondition(source, sessionId, slot, condition, correlationId)`, `WeaponRuntime.SetSlotMaintenance(source, sessionId, slot, maintenance, condition, correlationId)`, `WeaponRuntime.SetSlotAttachments(source, sessionId, slot, attachments, correlationId)`, `WeaponRuntime.ResetForReconcile(source, sessionId, correlationId)`, `WeaponRuntime.Unequip(source, sessionId, correlationId, slot)`, `WeaponRuntime.PromoteOffhand(source, sessionId, correlationId)`

**tests/firearm_pool_server.lua:** `TestInventoryAdapter.GetItemForCharacter(_, id)`, `TestInventoryAdapter.MutateWeaponMetadataBatch(_, mutations)`, `TestInventoryAdapter.Transaction(_, callback)`, `tx:GetItemForUpdate(id)`, `tx:GetQuantity(name)`, `tx:RemoveQuantity(name, amount)`, `tx:AddQuantity(name, amount)`, `tx:SetMetadata(id, metadata, revision)`

**tests/native_throwable_pickup_server_spec.lua:** `inventory:GetCharacterFirearmRuntimeSnapshot(context,limits)`, `inventory:ObserveCharacterAmmunition(context,spec)`, `inventory:ReconcileNativeThrowablePickup(context,spec)`, `inventory:ReconcileNativeThrowablePickup(context,spec)`

## Database tables

`feather_ammunition_operations`, `feather_character_ammunition`
