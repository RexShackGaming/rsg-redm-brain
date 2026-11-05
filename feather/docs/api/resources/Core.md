---
title: Feather Core
---

# Feather Core

Feather Core is the minimal framework kernel. It owns accounts, active Character sessions, readiness, RPC transport, locale registration, policy and guard evaluation, provider discovery, event brokering, and server-side notification dispatch. Gameplay systems belong in their own resources.

## Installation and settings

Start Core after `oxmysql` and before other Feather resources:

```cfg
ensure oxmysql
ensure feather-core
```

In `config.lua`, server owners normally change only `Config.DevMode`, `Config.DefaultLang`, and the logging level. Event, provider, guard, notification, and RPC limits are safety limits and should remain unchanged unless a developer identifies a measured requirement.

## Result contract

```lua
{ ok = true, value = value, meta = optionalMeta }
{ ok = false, code = 'stable_code', message = 'Safe summary', details = optionalDetails }
```

Always check `result.ok == true`.

## Foundation

**Signatures**

```lua
exports['feather-core']:GetCapabilities()
exports['feather-core']:GetHealth()
exports['feather-core']:AwaitReady(timeoutMs?)
```

**Example**

```lua
local ready = exports['feather-core']:AwaitReady(10000)
if not ready.ok then error(ready.message) end
```

## Accounts and sessions

```lua
exports['feather-core']:GetPrimaryIdentifier(source)
exports['feather-core']:GetAccountContext(source)
exports['feather-core']:GetAccountSettings(source)
exports['feather-core']:GetSessionContext(source)
exports['feather-core']:RequireSession(source)
exports['feather-core']:IsSessionCurrent(source, sessionId, characterId?)
exports['feather-core']:ActivateSession(source, characterId)
exports['feather-core']:BeginSessionLeaving(source, reason?)
exports['feather-core']:CompleteSessionLeaving(source, sessionId)
```

Session mutations (`ActivateSession`, `BeginSessionLeaving`, and `CompleteSessionLeaving`) are trusted server lifecycle operations. Gameplay resources should usually read or require a session rather than change it.

## Public service contracts

```lua
exports['feather-core']:RegisterLocale(locale, translations)
exports['feather-core']:TranslateLocale(source, key, ...)
exports['feather-core']:SetClientLocale(locale) -- client only

exports['feather-core']:RegisterRPC(name, callback, options?)
exports['feather-core']:RegisterContractRPC(name, callback, options?)
exports['feather-core']:GetRPCRoutes()
exports['feather-core']:NotifyRPC(name, payload?, target?)
exports['feather-core']:CallRPC(name, payload?, callback, target?, timeoutMs?)
exports['feather-core']:CallRPCAsync(name, payload?, target?, timeoutMs?)

exports['feather-core']:RegisterProvider(kind, name, implementation, options?)
exports['feather-core']:UnregisterProvider(kind, name)
exports['feather-core']:GetProvider(kind, name?, minimumContract?)
exports['feather-core']:GetProviderHealth(kind, name?)
exports['feather-core']:GetProviders()

exports['feather-core']:RegisterPolicyProvider(name, implementation, options?)
exports['feather-core']:Authorize(action, request)

exports['feather-core']:RegisterGuard(action, name, callback, options?)
exports['feather-core']:UnregisterGuard(action, name)
exports['feather-core']:EvaluateGuards(action, context)
exports['feather-core']:GetGuards()

exports['feather-core']:DeclareEvent(name, options?)
exports['feather-core']:SubscribeEvent(name, callback)
exports['feather-core']:UnsubscribeEvent(token)
exports['feather-core']:PublishEvent(name, payload)
exports['feather-core']:GetEvents()

exports['feather-core']:RegisterNotificationProvider(name, implementation, options?)
exports['feather-core']:SendNotification(request, providerName?)

exports['feather-core']:RegisterConnectionGate(name, callback, options?)
exports['feather-core']:GetConnectionGates()
```

Registrations are resource-owned and cleaned up when their owner stops. Authorization and guards fail closed when their providers cannot decide safely.

## Verification

Run `CoreContractSmokeTest` from the server console. More focused smoke tests exist for accounts, sessions, RPC, providers, policy, guards, events, notifications, and migrations.
