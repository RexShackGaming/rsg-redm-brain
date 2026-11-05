# feather-admin

Version 0.15.8. The official Admin menu for the Feather Framework

Current version: **0.15.8** authorizes Stables horse ownership transfers through the Assets broker, with direct and forged broker requests refused. 0.15.7 adds scoped service policy for the isolated Doors Property-binding fixture. 0.15.6 adds audited cash/gold additions and removals, scoped service grants and catalog diagnostics.

Source: https://github.com/FeatherFramework/feather-admin

**Dependencies:** `feather-mysql`, `feather-core`, `feather-authority`, `feather-toolkit`, `feather-inventory`, `feather-chat`, `feather-menu-v2`

Has NUI (`ui_page`).

## Exports (call as exports['feather-admin']:Name)

**server:** `CanMedicalRevive(actor, target)`, `checkConnectionBan(src, playerName)`

## Net events registered

**client:** `feather-admin:access:permissions`, `feather-admin:access:result`, `feather-admin:active-bans:result`, `feather-admin:announcement:broadcast`, `feather-admin:announcement:result`, `feather-admin:booster:apply`, `feather-admin:booster:death:check`, `feather-admin:booster:result`, `feather-admin:booster:revive`, `feather-admin:booster:toggle:result`, `feather-admin:cases:action:result`, `feather-admin:cases:detail:result`, `feather-admin:cases:list:result`, `feather-admin:character:restore`, `feather-admin:chat-moderation:notice`, `feather-admin:chat-moderation:result`, `feather-admin:conversation:reset`, `feather-admin:conversation:result`, `feather-admin:conversation:updated`, `feather-admin:economy:adjusted`, `feather-admin:economy:result`, `feather-admin:economy:summary`, `feather-admin:framework-audit:result`, `feather-admin:inventory:catalog:result`, `feather-admin:inventory:evidence:result`, `feather-admin:inventory:inspect:result`, `feather-admin:inventory:received`, `feather-admin:inventory:remove:result`, `feather-admin:inventory:result`, `feather-admin:moderation:history:result`, `feather-admin:moderation:result`, `feather-admin:moderation:search:result`, `feather-admin:notes:action:result`, `feather-admin:notes:history:result`, `feather-admin:notes:list:result`, `feather-admin:ped:apply`, `feather-admin:player:info`, `feather-admin:player:spectate`, `feather-admin:player:teleport`, `feather-admin:players:sync`, `feather-admin:reports:action:result`, `feather-admin:reports:list:result`, `feather-admin:reports:new`, `feather-admin:reports:player:update`, `feather-admin:reports:submission:result`, `feather-admin:server:overview`, `feather-admin:staff:list:result`, `feather-admin:staff:role:result`, `feather-admin:staff:role:updated`, `feather-admin:staff:search:result`, `feather-admin:troll:apply`, `feather-admin:troll:toggle:result`, `feather-admin:wallet:error`, `feather-admin:wallet:issued`, `feather-admin:weapons:catalog:result`, `feather-admin:weapons:result`, `feather-admin:weather:result`

## Event handlers

**server:** `Feather:Character:Logout`, `Feather:Server:Character:Spawned`, `chat.ready.v1`, `core.session.leaving.v1`, `core.session.ready.v1`, `playerJoining`

**client:** `Feather:Character:Logout`, `Feather:Character:Spawned`, `feather-admin:conversation:panel-request`

## Commands (RegisterCommand)

**server:** `/AdminAccessServicePolicySmokeTest`, `/AdminAuditContentLiveTest`, `/AdminAuditDowngradeTestOwner`, `/AdminAuditOutboxStatus`, `/AdminAuditPausedReadLiveTest`, `/AdminAuditProducerSmokeTest`, `/AdminAuditProducerVerifySmokeTest`, `/AdminAuditPublish`, `/AdminAuditQueryLiveTest`, `/AdminAuditReadLiveTest`, `/AdminAuditRestoreTestRole`, `/AdminAuditRevokeTestRole`, `/AdminAuditVisibilityLiveTest`, `/AdminAuthorityCapabilityLiveTest`, `/AdminAuthorityContractSmokeTest`, `/AdminAuthorityHierarchyContractSmokeTest`, `/AdminAuthorityInspect`, `/AdminAuthorityRoleCatalogLiveTest`, `/AdminAuthorityRoleParitySmokeTest`, `/AdminAuthorityStaffAssignmentContractSmokeTest`, `/AdminAuthorityStaffAssignmentState`, `/AdminBanInspect`, `/AdminBootstrapAdministrator`, `/AdminBootstrapOwner`, `/AdminCasesContractSmokeTest`, `/AdminCasesPersistenceSmokeTest`, `/AdminCharacterIsolationHierarchyLiveTest`, `/AdminChatCaseAdapterSmokeTest`, `/AdminChatCaseConcurrencySmokeTest`, `/AdminChatCaseContractSmokeTest`, `/AdminChatCaseDatabaseConcurrencySmokeTest`, `/AdminChatCaseFailureSmokeTest`, `/AdminChatCaseNotificationSmokeTest`, `/AdminChatCaseRetentionSmokeTest`, `/AdminChatCaseStoreSmokeTest`, `/AdminChatDiagnostics`, `/AdminChatTranslationContractSmokeTest`, `/AdminIdentitySmokeTest`, `/AdminInventoryInspectionContractSmokeTest`, `/AdminModerationContractSmokeTest`, `/AdminModerationPersistenceSmokeTest`, `/AdminPlayerNotesAccessInspect`, `/AdminPlayerNotesContractSmokeTest`, `/AdminPlayerNotesPersistenceSmokeTest`, `/AdminPolicySmokeTest`, `/AdminReleaseContractSmokeTest`, `/AdminReportsContractSmokeTest`, `/AdminReportsPersistenceSmokeTest`, `/AdminServicePolicySmokeTest`, `/AdminWalletIssue`, `/AdminWeaponInspect`, `/AdminWeaponReconcile`, `/AdminWeaponsContractSmokeTest`, `/ShopBusinessLifecycleControl`, `/ShopOrganizationLifecycleLiveTest`

**client:** `/AdminChatTranslationSmokeTest`, `/AdminDevKillSelf`, `/AdminToolkitContractSmokeTest`

## Public (table) functions

**.luals/cfx-runtime.lua:** `Citizen.InvokeNative(hash, ...)`, `Citizen.CreateThread(cb)`, `Citizen.CreateThreadNow(cb)`, `Citizen.Wait(ms)`, `Citizen.Trace(msg)`, `json.encode(value)`, `json.decode(str)`

**client/core/teleport.lua:** `Feather.Teleport:IsBusy()`, `Feather.Teleport:FindSurface(x, y, fallbackZ, options)`, `Feather.Teleport:ToCoords(coords, options)`, `Feather.Teleport:ToWaypoint(options)`

**client/services/active_bans.lua:** `AdminActiveBans.Request(page)`, `AdminActiveBans.Search(query)`, `AdminActiveBans.ClearSearch()`

**client/services/announcements.lua:** `AdminAnnouncements.Validate(title, message)`, `AdminAnnouncements.Send(title, message)`

**client/services/boosters.lua:** `AdminBoosters.Request(action, targetPlayer, requestId)`, `AdminBoosters.ToggleNoClip(enabled)`, `AdminBoosters.RefreshPlayerState()`

**client/services/cases.lua:** `AdminCases.PriorityLabel(value)`, `AdminCases.Request(page)`, `AdminCases.RequestDetail(caseId)`, `AdminCases.CreateFromReport(reportId, title, summary, priority)`, `AdminCases.Claim(caseId)`, `AdminCases.Release(caseId)`, `AdminCases.Link(caseId, kind, recordId)`, `AdminCases.Close(caseId, resolution)`

**client/services/character_administration.lua:** `AdminCharacter.ParseAmount(value)`, `AdminCharacter.AdjustEconomy(target, field, operation, amount)`, `AdminCharacter.RequestEconomySummary(target)`, `AdminCharacter.RestoreAppearance(target)`

**client/services/chat_cases.lua:** `AdminChatCases.RequestList(offset)`, `AdminChatCases.RequestHistory(afterSequence)`, `AdminUI.OpenChatConversation()`, `AdminUI.OpenChatConversationCreate()`

**client/services/developer_tools.lua:** `AdminDeveloperTools.ToggleDevGun()`, `AdminDeveloperTools.ToggleBoneDisplay()`, `AdminDeveloperTools.CopyCoordinates(format)`

**client/services/framework_audit.lua:** `state.Reset()`, `state.Read(mode, query, page)`, `state.Search()`, `state.Page(number)`, `state.Detail(row)`, `state.Correlation(row)`

**client/services/inventory.lua:** `AdminInventory.SetOnlineTarget(serverId)`, `AdminInventory.SetTarget(target)`, `AdminInventory.RequestInspection()`, `AdminInventory.RemoveInstance(instanceId)`, `AdminInventory.RequestCatalog()`, `AdminInventory.Give(itemName, quantity)`, `AdminInventory.RequestEvidence()`, `AdminInventory.ChangeEvidence()`

**client/services/moderation.lua:** `AdminModeration.ValidateReason(reason)`, `AdminModeration.SelectOnline(serverId)`, `AdminModeration.SelectOffline(target)`, `AdminModeration.ValidateBan(reason, duration)`, `AdminModeration.Ban(reason, duration)`, `AdminModeration.Warn(reason)`, `AdminModeration.Kick(reason)`, `AdminModeration.RequestHistory()`, `AdminModeration.Search(query)`, `AdminModeration.SearchPlayers(query)`, `AdminModeration.Unban(banId, origin)`, `AdminModeration.Mute(reason, duration, scope)`, `AdminModeration.RequestMutes()`, `AdminModeration.RevokeMute(muteId)`

**client/services/ped_changer.lua:** `AdminPedChanger.Request(targetPlayer, modelName)`

**client/services/player_management.lua:** `AdminPlayerManagement.RequestInfo(target)`, `AdminPlayerManagement.GoTo(target)`, `AdminPlayerManagement.ReturnToPreviousLocation()`, `AdminPlayerManagement.Bring(target)`, `AdminPlayerManagement.SendBack(target)`, `AdminPlayerManagement.Spectate(target, enabled)`, `AdminPlayerManagement.IsSpectating(target)`, `AdminPlayerManagement.StopSpectating()`

**client/services/player_notes.lua:** `AdminPlayerNotes.OpenTarget(target)`, `AdminPlayerNotes.OpenOnline(serverId)`, `AdminPlayerNotes.Request(page)`, `AdminPlayerNotes.Create(body)`, `AdminPlayerNotes.Edit(noteId, revision, body)`, `AdminPlayerNotes.Archive(noteId)`, `AdminPlayerNotes.RequestHistory(noteId)`

**client/services/reports.lua:** `AdminReports.CategoryLabel(value)`, `AdminReports.Request(page)`, `AdminReports.Claim(reportId)`, `AdminReports.Release(reportId)`, `AdminReports.Close(reportId, resolution)`

**client/services/server_overview.lua:** `AdminServerOverview.Request()`

**client/services/staff_management.lua:** `AdminStaff.Request(playerId)`, `AdminStaff.OpenCharacter(target)`, `AdminStaff.Search(query, page)`, `AdminStaff.Assign(characterId, roleKey, reason, expectedRevision)`, `AdminStaff.RequestHistory(characterId, page)`

**client/services/teleports.lua:** `AdminTeleports.ToWaypoint()`, `AdminTeleports.ParseCoordinates(value)`, `AdminTeleports.ToCoordinates(x, y, z, heading)`, `AdminTeleports.ToggleAutoWaypoint()`

**client/services/trolls.lua:** `AdminTrolls.Request(action, targetPlayer, requestId)`, `AdminTrolls.RefreshPlayerState()`

**client/services/weapons_admin.lua:** `AdminWeapons.SetOnlineTarget(serverId)`, `AdminWeapons.SetTarget(target)`, `AdminWeapons.RequestCatalog()`, `AdminWeapons.Issue(definitionId)`, `AdminWeapons.GrantAmmo(definitionId, quantity)`

**client/services/weather.lua:** `AdminWeather.Request(action,spec)`

**client/ui/menu.lua:** `handle:update(changes)`, `AdminUI.RegisterPage(key)`, `AdminUI.AddHeader(page, title, subtitle)`, `AdminUI.TargetLabel(selected)`, `AdminUI.AddTargetContext(page, selected)`, `AdminUI.BeginSection(page, label, expanded)`, `AdminUI.EndSection(page)`, `AdminUI.BeginRow(page)`, `AdminUI.EndRow(page)`, `AdminUI.AddImage(page, image, label, alt)`, `AdminUI.AddPagination(page, current, total, navigate)`, `AdminUI.AddCatalog(page, entries, state, reopen, itemLabel, choose)`, `AdminUI.ConfirmTargetAction(label, callback, back)`, `AdminUI.AddButton(page, label, callback)`, `AdminUI.AddInput(page, label, placeholder, callback, value)`, `AdminUI.AddDropdown(page, options, placeholder, callback)`, `AdminUI.AddText(page, value)`, `AdminUI.AddLine(page)`, `AdminUI.AddArrows(page, label, options, selectedIndex, callback)`, `AdminUI.AddFooter(page)`, `AdminUI.AddFooterButton(page, label, callback)`, `AdminUI.OpenPage(key)`, `AdminUI.SetTarget(playerId)`, `AdminUI.GetTarget()`, `AdminUI.CanUse(action)`, `AdminUI.NotifyActionDenied()`, `AdminUI.IsSelfTarget(target)`, `AdminUI.CanUseOnTarget(action, ...)`, `AdminUI.RequireUseOnTarget(action, ...)`, `AdminUI.CanUseAnyAction(actions)`, `AdminUI.RequireAnyUseOnTarget(actions, ...)`, `AdminUI.CanUseAny(prefix)`, `AdminUI.RunAction(label, callback)`, `AdminUI.GetToggleLabel(label, action)`, `AdminUI.SetToggleState(action, enabled, target)`, `AdminUI.RunToggleAction(label, action, element, callback)`, `AdminUI.RunServerToggleAction(label, action, element, callback)`, `AdminUI.ResolveServerToggle(requestId, succeeded)`, `AdminUI.Close()`, `AdminUI.OpenPedParent()`

**client/ui/navigation.lua:** `AdminUI.RegisterNavigationSection(key, labelKey, order)`, `AdminUI.RegisterNavigationItem(sectionKey, item)`, `AdminUI.HasNavigationItems(sectionKey)`, `AdminUI.OpenNavigationSection(sectionKey)`

**client/ui/pages/active_bans.lua:** `AdminUI.OpenActiveBanRevokeConfirmation()`, `AdminUI.OpenActiveBanDetails()`, `AdminUI.OpenActiveBans()`

**client/ui/pages/announcements.lua:** `AdminUI.OpenAnnouncementConfirmation(title, message)`, `AdminUI.OpenAnnouncements()`

**client/ui/pages/appearance.lua:** `AdminUI.OpenAppearance(parentPage, target)`

**client/ui/pages/boosters.lua:** `AdminUI.CanUsePlayerStatus(includeLocalActions)`, `AdminUI.OpenBoosters(includeLocalActions)`

**client/ui/pages/cases.lua:** `AdminUI.OpenCaseCreateFromReport()`, `AdminUI.OpenCaseCloseConfirmation()`, `AdminUI.OpenCaseDetails()`, `AdminUI.OpenCases()`

**client/ui/pages/character_administration.lua:** `AdminUI.OpenEconomyConfirmation(field, amount)`, `AdminUI.OpenCharacterAdministration()`

**client/ui/pages/developer_tools.lua:** `AdminUI.OpenDeveloperTools()`

**client/ui/pages/framework_audit.lua:** `AdminUI.OpenFrameworkAudit()`, `AdminUI.OpenFrameworkAuditDetail()`

**client/ui/pages/inventory.lua:** `AdminUI.OpenInventoryActions()`, `AdminUI.OpenInventoryCategories()`, `AdminUI.OpenInventoryInspection(pageNumber)`, `AdminUI.OpenInventoryInstanceDetails()`, `AdminUI.OpenInventoryRawMetadata(pageNumber)`, `AdminUI.OpenEvidenceConfirmation()`, `AdminUI.OpenInventoryRemovalConfirmation()`, `AdminUI.OpenInventoryItems(category, pageNumber)`, `AdminUI.OpenInventoryGrant()`, `AdminUI.OpenInventoryConfirmation(quantity)`

**client/ui/pages/main.lua:** `AdminUI.OpenMain()`

**client/ui/pages/moderation.lua:** `AdminUI.OpenModerationConfirmation(action, reason, duration, scope)`, `AdminUI.OpenModeration()`, `AdminUI.OpenModerationSearchResults()`, `AdminUI.OpenModerationHistory(history)`, `AdminUI.OpenChatMutes(mutes)`, `AdminUI.OpenModerationTarget()`

**client/ui/pages/ped_changer.lua:** `AdminUI.OpenPedCategories()`

**client/ui/pages/player_management.lua:** `AdminUI.OpenPlayerInfo(info)`, `AdminUI.OpenPlayerManagement()`

**client/ui/pages/player_notes.lua:** `AdminUI.OpenPlayerNotes()`, `AdminUI.OpenPlayerNoteDetails()`, `AdminUI.OpenPlayerNoteHistory()`, `AdminUI.OpenPlayerNoteArchiveConfirmation()`

**client/ui/pages/players.lua:** `AdminUI.OpenSelectedPlayer()`, `AdminUI.OpenPlayers(pageNumber)`, `AdminUI.OpenPlayerSearchResults()`, `AdminUI.OpenOfflinePlayer(target)`, `AdminUI.OpenCharacterManagement()`, `AdminUI.OpenSelectedPlayerTools()`

**client/ui/pages/reports.lua:** `AdminUI.OpenReportCloseConfirmation()`, `AdminUI.OpenReportDetails()`, `AdminUI.OpenReports()`

**client/ui/pages/self_tools.lua:** `AdminUI.OpenSelfTools()`

**client/ui/pages/server_overview.lua:** `AdminUI.OpenServerOverview()`

**client/ui/pages/staff_management.lua:** `AdminUI.OpenStaffManagement()`, `AdminUI.OpenStaffSearchResults()`, `AdminUI.OpenStaffRole()`, `AdminUI.OpenStaffRoleConfirmation()`

**client/ui/pages/teleports.lua:** `AdminUI.OpenTeleports()`

**client/ui/pages/trolls.lua:** `AdminUI.CanUseSpecialEffects()`, `AdminUI.OpenTrolls()`

**client/ui/pages/weapons_admin.lua:** `AdminUI.OpenWeaponAdmin()`, `AdminUI.OpenWeaponIssueCatalog()`, `AdminUI.OpenAmmoGrantCatalog()`, `AdminUI.OpenAmmoGrantQuantity()`, `AdminUI.OpenWeaponGrantConfirmation()`

**client/ui/pages/weather.lua:** `AdminUI.OpenWeather()`

**server/core/init.lua:** `FeatherAdmin.Notify(src, message, duration)`, `FeatherAdmin.Identity.Resolve(src)`, `FeatherAdmin.Identity.Invalidate(accountId)`, `FeatherAdmin.Identity.GetStaff(identity)`, `FeatherAdmin.Identity.GetStaffByAccountId(accountId)`, `FeatherAdmin.RegisterRPC(name, callback, options)`, `FeatherAdmin.GetRolePrecedence(src)`, `FeatherAdmin.IsActionEnabled(action)`, `FeatherAdmin.CanUse(src, action)`, `FeatherAdmin.GetPermissions(src)`, `FeatherAdmin.IsAuthorized(src)`, `FeatherAdmin.Deny(src)`, `FeatherAdmin.DenyAction(src)`, `FeatherAdmin.RequirePermission(src, action)`, `FeatherAdmin.ValidTarget(playerId)`, `FeatherAdmin.CanActOnLicense(src, targetLicense, action)`, `FeatherAdmin.CanActOnAccount(src, targetAccountId, action)`, `FeatherAdmin.CheckTargetAccountHierarchy(src, action, targetAccountId, targetId)`, `FeatherAdmin.RequireTarget(src, action, playerId)`, `FeatherAdmin.CheckTargetHierarchy(src, action, targetLicense, targetId)`

**server/database.lua:** `AdminDatabase.OnReady(callback)`

**server/services/audit_log.lua:** `AdminAudit.BuildEvent(eventId, actor, action, target, details)`, `AdminAudit.RecordTarget(source, action, target, details)`, `AdminAudit.Record(source, action, targetSource, details)`, `AdminAudit.PublishOnce()`

**server/services/authority_catalog.lua:** `FeatherAdmin.AuthorityCatalog.Definitions()`, `FeatherAdmin.AuthorityCatalog.State()`

**server/services/chat_case_adapter.lua:** `AdminChatCaseAdapter.SessionIdentity(source)`, `AdminChatCaseAdapter.Actor(source, targetAccountId, operation, injected)`, `AdminChatCaseAdapter.Reply(source, payload)`, `AdminChatCaseAdapter.Create(source, targetSource)`, `AdminChatCaseAdapter.List(source, offset)`, `AdminChatCaseAdapter.History(source, id, afterSequence, limit)`, `AdminChatCaseAdapter.Transition(source, id, operation)`, `AdminChatCaseAdapter.Link(source, id, caseId)`

**server/services/chat_case_concurrency_smoke.lua:** `tx.one(sql, ...)`, `tx.exec(sql, ...)`

**server/services/chat_case_contract.lua:** `AdminChatCaseContract.IsUUID(value)`, `AdminChatCaseContract.AuthorizeCreation(targetAccountId, actor)`, `AdminChatCaseContract.ValidateSubmission(payload, maximumBytes)`, `AdminChatCaseContract.Authorize(conversation, actor, operation)`, `AdminChatCaseContract.CheckReplay(stored, actorAccountId, conversationId, text)`, `AdminChatCaseContract.Smoke()`

**server/services/chat_case_database_concurrency_smoke.lua:** `wrapped.one(sql, ...)`

**server/services/chat_case_notifications.lua:** `AdminChatCaseNotifications.Dispatch(result, operation, id, deps)`, `AdminChatCaseNotifications.Notify(result, operation, id, initiatingSource)`

**server/services/chat_case_retention.lua:** `AdminChatCaseRetention.Settings(config)`, `AdminChatCaseRetention.SweepIn(tx, settings)`

**server/services/chat_case_store.lua:** `AdminChatCaseStore.CreateIn(tx, id, targetAccountId, actor, revalidate, targetName)`, `AdminChatCaseStore.HistoryIn(tx, id, actor, afterSequence, limit, revalidate)`, `AdminChatCaseStore.AppendIn(tx, payload, actor, messageId, revalidate)`, `AdminChatCaseStore.TransitionIn(tx, id, actor, operation, revalidate)`, `AdminChatCaseStore.RunTransaction(work, deps)`, `AdminChatCaseStore.Append(payload, actor, messageId, revalidate)`, `AdminChatCaseStore.Transition(id, actor, operation, revalidate)`, `AdminChatCaseStore.Create(id, targetAccountId, actor, revalidate, targetName)`, `AdminChatCaseStore.History(id, actor, afterSequence, limit, revalidate)`, `AdminChatCaseStore.LinkIn(tx, id, caseId, actor, revalidate)`, `AdminChatCaseStore.Link(id, caseId, actor, revalidate)`

**server/services/chat_case_store_smoke.lua:** `scoped.query(sql, ...)`
