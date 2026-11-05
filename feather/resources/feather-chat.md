# feather-chat

Version 0.1.0. Feather official chat resource for RedM. This resource is a part of the Feather Framework.

Feather Chat is the official server-authoritative text communication resource for Feather Framework. The current `0.1.0` release contains the Contract 1 lifecycle, validated operator configuration, health/capability

Source: https://github.com/FeatherFramework/feather-chat

**Dependencies:** `feather-mysql`, `feather-core`

Has NUI (`ui_page`).

## Exports (call as exports['feather-chat']:Name)

**server:** `AwaitReady(timeoutMs)`, `GetCapabilities()`, `GetHealth()`, `GetModerationDiagnostics(request)`, `GetMuteSnapshot(request)`, `IssueMute(request)`, `PrepareStaffCaseText(source, conversationId, text)`, `RegisterChannel(definition)`, `RegisterChannelAccessProvider(name, implementation)`, `RegisterModerationProvider(name, implementation, options)`, `RegisterSuggestion(definition)`, `RegisterTheme(definition)`, `RemoveSuggestion(key)`, `RevokeMute(request)`, `UnregisterChannel(channelKey)`, `UnregisterChannelAccessProvider(name)`, `UnregisterModerationProvider(name)`, `UnregisterTheme(themeKey)`, `UpdateChannel(channelKey, patch, expectedRevision)`, `UpdateTheme(themeKey, definition, expectedRevision)`

**client:** `CloseChat()`, `GetChatState()`, `GetPresentation()`, `OpenChat()`, `SetChatVisible(visible)`, `SetPresentationPreference(key, value)`

## Net events registered

**client:** `Feather:Character:Spawned`, `feather-chat:directory:v1`, `feather-chat:message:v1`, `feather-chat:notice:v1`, `feather-chat:themes:v1`

## Event handlers

**client:** `feather-chat:conversation:panel-result`, `feather-chat:conversation:reset`, `feather-chat:conversation:updated`, `feather-core:locale:changed`

## Commands (RegisterCommand)

**server:** `/ChatChannelRegistrySmokeTest`, `/ChatFoundationSmokeTest`, `/ChatLocaleSmokeTest`, `/ChatMessageConcurrencySmokeTest`, `/ChatMessageContractSmokeTest`, `/ChatModerationProviderSmokeTest`, `/ChatModerationSmokeTest`, `/ChatRateLimitSmokeTest`, `/ChatSuggestionContractSmokeTest`, `/ChatThemeContractSmokeTest`

**client:** `/ChatClientFoundationSmokeTest`, `/ChatPresentationSmokeTest`

## Public (table) functions

**client/presentation.lua:** `ChatPresentation.RefreshThemes()`, `ChatPresentation.GetState()`, `ChatPresentation.Apply()`

**server/channels.lua:** `ChatChannels.Start()`, `ChatChannels.RegisterRoutes()`, `ChatChannels.Get(key)`, `ChatChannels.ResolveAlias(alias)`, `ChatChannels.CanSend(channel, actor)`, `ChatChannels.ResolveAudience(channel, sender, connected)`, `ChatChannels.List(actor)`, `ChatChannels.SuggestionSmoke()`, `ChatChannels.Smoke()`

**server/messaging.lua:** `ChatMessaging.Start()`, `ChatMessaging.IsReady()`, `ChatMessaging.NormalizeText(text)`, `ChatMessaging.ConcurrencySmoke()`, `ChatMessaging.RateLimitSmoke()`

**server/moderation.lua:** `ChatModeration.Start()`, `ChatModeration.CanSend(actor, channel)`, `ChatModeration.RegisterProvider(name, implementation, options)`, `ChatModeration.UnregisterProvider(name)`, `ChatModeration.EvaluateMessage(actor, channel, text)`, `ChatModeration.FilterRecipients(actor, recipients, channel)`, `ChatModeration.RecordDelivery(target, message, actor)`, `ChatModeration.ToggleIgnore(payload, source, context)`, `ChatModeration.ListIgnores(_, _, context)`, `ChatModeration.RemoveIgnore(payload, _, context)`, `ChatModeration.RegisterRoutes()`, `ChatModeration.IssueMute(request)`, `ChatModeration.RevokeMute(request)`, `ChatModeration.GetMuteSnapshot(request)`, `ChatModeration.GetDiagnostics(request)`, `ChatModeration.Smoke()`, `ChatModeration.ProviderSmoke()`

**server/themes.lua:** `ChatThemes.Start()`, `ChatThemes.RegisterRoutes()`, `ChatThemes.Smoke()`

**shared/contract.lua:** `ChatContract.ValidateTheme(theme)`, `ChatContract.ValidateConfig(config)`, `ChatContract.ValidateSubmission(payload, limits)`, `ChatContract.ValidateIgnoreRequest(payload)`, `ChatContract.ValidateIgnoreRemove(payload)`

**shared/locale.lua:** `ChatLocale.Resolve(base, override)`, `ChatLocale.Render(dictionary, key, variables)`, `ChatLocale.T(key, variables, source)`, `ChatLocale.Dictionary()`, `ChatLocale.MessageKey(message)`, `ChatLocale.LocalizeResult(result)`, `ChatLocale.Smoke()`, `ChatLocale.Format(key, ...)`

**shared/results.lua:** `ChatResults.Ok(value, meta)`, `ChatResults.Err(code, message, details)`
