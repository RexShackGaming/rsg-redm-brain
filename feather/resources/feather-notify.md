# feather-notify

Version 0.2.0. Default notification presentation provider for the Feather Framework

Feather Notify is the optional default notification display resource for the Feather Framework. It provides the native RedM presentations used by Feather resources while Feather Core handles server-side validation and routing.

Source: https://github.com/FeatherFramework/feather-notify

## Exports (call as exports['feather-notify']:Name)

**server:** `GetCapabilities()`

**client:** `ShowNotification(request)`

## Net events registered

**client:** `feather-notify:show.v1`

## Commands (RegisterCommand)

**server:** `/NotifyContractSmokeTest`

**client:** `/NotifyClientLimitSmokeTest`, `/NotifyClientSmokeTest`, `/NotifyStyleSmokeTest`

## Public (table) functions

**shared/contract.lua:** `NotifyContract.Limits()`, `NotifyContract.Validate(request)`

**shared/results.lua:** `NotifyResults.Ok(value)`, `NotifyResults.Err(code, message, details)`
