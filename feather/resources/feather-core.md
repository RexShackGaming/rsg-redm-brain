# feather-core

Version 0.5.2. The Core service for the Feather Framework

Feather Core is the required foundation for the Feather Framework. It manages player accounts, active character sessions, database migrations, framework communication, and the shared services used by other Feather resources.

Source: https://github.com/FeatherFramework/feather-core

**Dependencies:** `feather-mysql`

## Exports (call as exports['feather-core']:Name)

**server:** `ActivateSession(src, characterId)`, `Authorize(action, request)`, `AwaitReady(timeoutMs)`, `BeginSessionLeaving(src, reason)`, `CompleteSessionLeaving(src, sessionId)`, `DeclareEvent(name, options)`, `EvaluateGuards(action, context)`, `GetAccountContext(src)`, `GetAccountIdentity(accountId)`, `GetAccountSettings(source)`, `GetCapabilities()`, `GetConnectionGates()`, `GetEvents()`, `GetGuards()`, `GetHealth()`, `GetPrimaryIdentifier(src)`, `GetProvider(kind, name, minimumContract)`, `GetProviderHealth(kind, name)`, `GetProviders()`, `GetRpcRoutes()`, `GetSessionContext(src)`, `IsSessionCurrent(src, sessionId, characterId)`, `PublishEvent(name, payload)`, `RegisterConnectionGate(name, callback, options)`, `RegisterGuard(action, name, callback, options)`, `RegisterNotificationProvider(name, implementation, options)`, `RegisterPolicyProvider(name, implementation, options)`, `RegisterProvider(kind, name, implementation, options)`, `RegisterRpc(name, callback, options)`, `RequireSession(src)`, `SendNotification(request, providerName)`, `SubscribeEvent(name, callback)`, `UnregisterGuard(action, name)`, `UnregisterProvider(kind, name)`, `UnsubscribeEvent(token)`

**client:** `AwaitReady(timeoutMs)`

**shared:** `CallRPC(name, params, callback, source, timeoutMs)`, `CallRPCAsync(name, params, source, timeoutMs)`, `GetRPCRoutes()`, `NotifyRPC(name, params, source)`, `RegisterContractRPC(name, callback, options)`, `RegisterLocale(key, translations)`, `RegisterRPC(name, callback, options)`, `SetClientLocale(locale)`, `TranslateLocale(src, key, ...)`

## Net events registered

**shared:** `Feather:Call`, `Feather:Response`

## Event handlers

**server:** `core.connection.rejected.v1`, `playerConnecting`, `playerJoining`

**shared:** `Feather:Call`, `Feather:Response`, `playerSpawned`

## Commands (RegisterCommand)

**server:** `/CoreAccountIdentityContractSmokeTest`, `/CoreAccountSettingsSmokeTest`, `/CoreAccountSmokeTest`, `/CoreConnectionGates`, `/CoreContractSmokeTest`, `/CoreEventSmokeTest`, `/CoreGuardSmokeTest`, `/CoreMigrationSmokeTest`, `/CoreNotificationAvailabilityTest`, `/CoreNotificationRateRecoveryTest`, `/CoreNotificationSmokeTest`, `/CorePolicySmokeTest`, `/CoreProviderSmokeTest`, `/CoreRpcSmokeTest`, `/CoreSessionSmokeTest`, `/CoreSplitConnectedAccount`

**client:** `/CoreClientReadinessSmokeTest`

## Public (table) functions

**.luals/cfx-runtime.lua:** `Citizen.InvokeNative(hash, ...)`, `Citizen.CreateThread(cb)`, `Citizen.CreateThreadNow(cb)`, `Citizen.Wait(ms)`, `Citizen.Trace(msg)`, `Citizen.Await(value)`, `promise.new()`, `json.encode(value)`, `json.decode(str)`

**server/services/account_settings.lua:** `CoreAccountSettings.Get(accountId)`, `CoreAccountSettings.GetBySource(source)`, `CoreAccountSettings.Set(accountId, locale)`

**server/services/connection.lua:** `ConnectionAPI.RegisterGate(name, callback, options, registeredOwner)`, `ConnectionAPI.UnregisterGate(name)`, `ConnectionAPI.GetGates()`, `ConnectionAPI.RunGates(src, playerName, deferrals)`

**server/services/connection_accounts.lua:** `CoreAccounts.Resolve(src, displayName)`, `CoreAccounts.GetContext(src)`, `CoreAccounts.GetIdentity(accountId)`, `CoreAccounts.GetPrimaryIdentifier(src)`, `CoreAccounts.GetCounts()`

**server/services/event_broker.lua:** `CoreEventBroker.Declare(name, options)`, `CoreEventBroker.Subscribe(name, callback)`, `CoreEventBroker.Unsubscribe(token)`, `CoreEventBroker.Publish(name, payload)`, `CoreEventBroker.PublishInternal(name, payload)`, `CoreEventBroker.GetEvents()`

**server/services/foundation.lua:** `CoreFoundation.GetCapabilities()`, `CoreFoundation.GetHealth()`, `CoreFoundation.AwaitReady(timeoutMs)`, `CoreFoundation.BeginStartup()`, `CoreFoundation.MarkMigrationsComplete(details)`, `CoreFoundation.MarkReady()`, `CoreFoundation.MarkFailed(code, message, details)`

**server/services/guards.lua:** `CoreGuards.Register(action, name, callback, options)`, `CoreGuards.Unregister(action, name)`, `CoreGuards.Evaluate(action, context)`, `CoreGuards.GetGuards()`

**server/services/migrations.lua:** `CoreMigrationRunner.Run()`

**server/services/notification_registry.lua:** `CoreNotifications.RegisterProvider(name, implementation, options)`, `CoreNotifications.Send(request, providerName)`

**server/services/policy.lua:** `CorePolicy.RegisterProvider(name, implementation, options)`, `CorePolicy.Authorize(action, request)`

**server/services/providers.lua:** `CoreProviders.Register(kind, name, implementation, options)`, `CoreProviders.Unregister(kind, name)`, `CoreProviders.Get(kind, name, minimumContract)`, `CoreProviders.Health(kind, name)`, `CoreProviders.GetProviders()`

**server/services/sessions.lua:** `CoreSessions.Activate(src, characterId)`, `CoreSessions.Get(src)`, `CoreSessions.IsCurrent(src, sessionId, characterId)`, `CoreSessions.BeginLeaving(src, reason)`, `CoreSessions.CompleteLeaving(src, sessionId)`, `CoreSessions.Disconnect(src, reason)`, `CoreSessions.GetCounts()`

**shared/services/arpc.lua:** `RPCAPI.Register(name, callback, options)`, `RPCAPI.RegisterContract(name, callback, options)`, `RPCAPI.GetRoutes()`, `RPCAPI.Notify(name, params, source)`, `RPCAPI.Call(name, params, callback, source, timeoutMs)`, `RPCAPI.CallAsync(name, params, source, timeoutMs)`

**shared/services/locale.lua:** `LocalesAPI.SetClientLang(lang)`, `LocalesAPI.RefreshClientLang()`, `LocalesAPI.register(key, translation)`, `LocalesAPI.translate(src, str, ...)`

**shared/services/logging.lua:** `CoreLogging.Create(resourceName, subsystem)`, `logger.Debug(eventName, fields)`, `logger.Info(eventName, fields)`, `logger.Warn(eventName, fields)`, `logger.Error(eventName, fields)`

**shared/services/results.lua:** `CoreResults.Ok(value, meta)`, `CoreResults.Err(code, message, details)`, `CoreResults.Is(value)`
