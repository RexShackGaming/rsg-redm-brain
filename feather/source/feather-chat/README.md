# Feather Chat

Feather Chat is the official server-authoritative text communication resource
for Feather Framework. The current `0.1.0` release contains the
Contract 1 lifecycle, validated operator configuration, health/capability
exports, focus recovery, a themed Vue NUI, and server-authoritative local chat.

## Server-owner setup

Start Chat after Feather MySQL and Core:

```cfg
ensure feather-mysql
ensure feather-core
ensure feather-chat
```

`feather-mysql` and `feather-core` are hard dependencies. Chat does not require
BCC Chat, VORP, Discord, or Feather Menu. C6 stores administrative mutes and
player ignore preferences in Chat-owned tables so they survive resource and
server restarts.

### Configuration

Most servers should retain the safe defaults in `config.lua`.

### Player language and translation contributions

Chat uses the standard Feather Core `RegisterLocale` / `TranslateLocale` system,
not a separate server-wide Chat language setting. Players choose their account
language in Feather Settings. Chat sends the resulting translated dictionary to
its NUI and refreshes labels when Core emits `feather-core:locale:changed`, and
whenever Chat opens. Chat presentation controls re-register after language changes.

Contribute translations in `translations/<language>.lua`, using the same
`Feather.Locale.register('<language>', { ... })` adapter as Inventory and the
`feather_chat_` keys in `translations/en_us.lua`. Preserve `{name}`, `{count}`, `{channel}`
and `{code}` placeholders. Missing Chat keys fall back to English. Initial Spanish
UI coverage is included; other languages and remaining Admin/operator text still
need translation coverage. `translations/` is the single catalog for Lua and NUI:
Lua resolves Core's player language and English fallback, then sends a plain
key-to-string bundle to the NUI. There is no separate JavaScript/JSON catalog.

Error results retain stable `code` fields and may include `messageKey` so the
receiving client translates server validation messages in its own language.
Production operator messages also use locale keys, resolved using Core's default
server language, while codes/resource identifiers and smoke-test markers remain
stable. Operator format templates are never sent to the NUI label bundle.
Chat never translates player message bodies or third-party channel names.

Run `ChatLocaleSmokeTest` in the **server console**, with no connected player
required and no database writes. In game, an active player can select Spanish in
Settings, verify Chat tabs/settings/Staff labels change, return to English, and
verify the choice persists on reconnect. Admin rank is not needed for language
testing. Languages without complete catalogs should show readable English fallback.
The Core language-change event requires its updated code to load at the next
normal server startup; do not restart Core or Character during live Chat testing.

Install the published `feather-chat.zip` runtime package, not the web source tree.
The recipe downloads the latest stable release and starts Chat before its
Character/Inventory/Admin integrations. Do not also ensure CFX/BCC/VORP chat.
Existing installations may have legacy chat copied locally; remove it from their
start configuration before enabling Chat. The recipe removes the unused bundled
CFX chat example theme; the currently downloaded CFX tree contains no chat resource.

| Section | Purpose |
| --- | --- |
| `Input` | Open command, default key, and eventual submit-focus behavior. |
| `Channels` | OOC availability and local proximity radii. |
| `Limits` | Message, line, client-buffer, input-history, and callback bounds. |
| `RateLimit` | Per-player local message window and accepted-message ceiling. |
| `Moderation` | Persistent mute policy, configurable account/character ignore targets, official-context bypass boundaries, and audit privacy. |
| `Layout` | Anchor, size, density, fade, timestamps, font scale, and reduced motion. |
| `Theme` | Default and approved built-in theme keys. |
| `Preferences` | Which bounded presentation controls players may change through `feather-settings`. |
| `Features` | Explicitly disabled deferred features such as history and staff cases. |

`feather-settings` is optional. When it is running, Chat registers controls for
the approved theme, density, timestamps, reduced motion, text scale, and faded
feed opacity according to `Config.Preferences`. Chat validates, stores, and
applies those local presentation preferences; Settings only renders the
controls. Restarting either resource safely re-registers them.

### Local chat

Press `T` or run `/chat`, choose a local mode, and press Enter to submit.
Shift+Enter inserts a new line. Built-in command aliases are also available:

```text
/say message
/whisper message
/shout message
/me action
/do scene description
```

These slash commands work both as registered game commands and when typed
directly into the `T` composer.

Other slash-prefixed composer input uses the normal client command system with
the same authority it has in F8. For example, `/logout` invokes Feather
Character's registered client command; Chat does not reimplement or authorize
that command.

The server derives the character name from the active Core session, uses
server-side ped coordinates and routing buckets for recipients, accepts plain
text only, and applies the configured message and rate limits.
Rejected composer submissions release input focus automatically and leave the
safe error message visible in the temporary feed.

When enabled, a player can open Chat with `T`, right-click a received player
message, and choose **Ignore <name>**. The client submits only the opaque message
ID; the server verifies that the active session received that message and
resolves its authoritative author. Right-clicking an earlier message from the
same author allows the player to unignore them. Ignore preferences belong to
the ignoring account and target either the other account (default) or active
character according to `Config.Moderation.playerControls.ignoreSubjectScope`.
Server, account, and character identifiers are never player-facing inputs.
The **Ignored** control in the Chat channel bar lists persisted preferences by
their stored display-name snapshot and lets players remove them after reconnects
or restarts using an opaque ignore ID.

Administrative mutes always target accounts. Permanent mutes are disabled by
default and temporary mutes are capped at seven days. Server owners can change
those bounds in `Config.Moderation`; a new character never bypasses a mute.

Security-sensitive configuration is validated during startup. Invalid values
leave Chat unavailable instead of silently applying unsafe fallbacks.

### Current validation

Server console:

```text
ChatFoundationSmokeTest
```

Client F8:

```text
ChatClientFoundationSmokeTest
```

Press `T` or run `/chat` to inspect the chat shell. It must open, focus, close
with Escape, release focus when the pause menu or fade appears, and release
focus when the resource stops.

Phase C2 contract validation is available from the server console:

```text
ChatMessageContractSmokeTest
ChatMessageConcurrencySmokeTest
ChatThemeContractSmokeTest
ChatModerationSmokeTest
ChatModerationProviderSmokeTest
ChatRateLimitSmokeTest
```

Client F8 presentation validation:

```text
ChatPresentationSmokeTest
```

The concurrency smoke test is deterministic and does not require connected
players. It verifies that overlapping and completed retries with the same
submission ID produce one delivery, and that a character-session change during
submission processing rejects before delivery.

## Developer API reference

### Server exports

```lua
exports['feather-chat']:GetCapabilities()
exports['feather-chat']:GetHealth()
exports['feather-chat']:AwaitReady(timeoutMs)
exports['feather-chat']:RegisterChannel(definition)
exports['feather-chat']:UpdateChannel(channelKey, patch, expectedRevision)
exports['feather-chat']:UnregisterChannel(channelKey)
exports['feather-chat']:RegisterChannelAccessProvider(name, implementation)
exports['feather-chat']:UnregisterChannelAccessProvider(name)
exports['feather-chat']:RegisterSuggestion(definition)
exports['feather-chat']:RemoveSuggestion(key)
exports['feather-chat']:RegisterTheme(definition)
exports['feather-chat']:UpdateTheme(themeKey, definition, expectedRevision)
exports['feather-chat']:UnregisterTheme(themeKey)
exports['feather-chat']:IssueMute(request)
exports['feather-chat']:RevokeMute(request)
exports['feather-chat']:GetMuteSnapshot(request)
exports['feather-chat']:GetModerationDiagnostics(request)
exports['feather-chat']:RegisterModerationProvider(name, implementation, options)
exports['feather-chat']:UnregisterModerationProvider(name)
```

All exports return the Feather result envelope:

```lua
{ ok = true, value = value, meta = optionalMeta }
{ ok = false, code = 'stable_code', message = 'Safe summary', details = optionalDetails }
```

The resource advertises Contract `feather.chat` version `1`. Built-in local
messaging, proximity routing, registered channels/suggestions, access providers,
validated themes, presentation preferences, persistent account mutes, and
recipient-side ignores are available. General history, staff cases, and
player-to-player private messages are unavailable; player private messaging is
intentionally outside Chat's scope.

The moderation exports require a connected staff `source` in the request and
authorize `chat.mute.issue`, `chat.mute.revoke`, `chat.mute.inspect`, or
`chat.diagnostics` through Core. The active policy provider must map and grant
those named actions. Ordinary
player chat never receives a staff bypass; future official system, moderation,
staff-channel, and staff-case contexts may use only the explicitly configured
bypass categories.
Calls are accepted only from resources explicitly listed in
`Config.Moderation.trustedCallers`; the default trusts `feather-admin` only.

Moderation providers are owner-scoped server registrations. `Evaluate` receives
only authoritative account/character identity, channel key, and bounded plain
text. It returns `{ ok=true, value={ allowed=true, text=optionalPlainText } }`
or an allowed-false decision with an optional safe `reasonCode`. Providers
cannot choose recipients or return presentation markup. A required provider or
globally required provider policy fails closed when unavailable; optional
provider failures do not block otherwise valid chat.

### Client exports

```lua
exports['feather-chat']:OpenChat()
exports['feather-chat']:CloseChat()
exports['feather-chat']:SetChatVisible(visible)
exports['feather-chat']:GetChatState()
exports['feather-chat']:GetPresentation()
exports['feather-chat']:SetPresentationPreference(key, value)
```

These exports control local presentation only. They never authorize message
delivery or channel access.

Theme registration is server-only and owner-scoped. Documents use schema
version `1` and accept only bounded typography, surface, text, semantic channel,
shape, and motion tokens. Raw CSS, HTML, JavaScript, URLs, and arbitrary font
names are rejected. A registered theme is offered to players only when its key
is present in `Config.Theme.approved`; removing or invalidating the selected
theme falls back to the configured default and publishes a live revision.

Channel and suggestion registrations are server-only and owned by the invoking
resource. Duplicate keys and aliases are rejected, foreign updates/removals are
forbidden, revisions protect updates, and registrations are removed when their
owner stops. Protected channels use a named Core-backed access provider instead
of copying membership into Chat.

A resource that owns a client command may advertise it in Chat from its server
script:

```lua
exports['feather-chat']:RegisterSuggestion({
    key = 'feather-character.logout',
    trigger = '/logout',
    description = 'Return to character selection'
})
```

Chat removes that suggestion automatically when its owning resource stops.

Suggestions must be registered from the owning resource's **server** script,
both at startup (once `GetHealth().value.state == 'ready'`) and on the local
`chat.ready.v1` event. Clear any registration guard on `onResourceStop` for
`feather-chat`; Chat's registry is rebuilt on every restart. Startup registration
handles consumers started after Chat, while the readiness event handles the
opposite order and Chat-only restarts. Do not use legacy `chat:addSuggestion`.
Triggers preserve command casing; autocomplete matches case-insensitively.
Suggestions may include `descriptionKey`, a standard Core locale key registered
by their owner on clients. Chat resolves it in each player's language; missing
keys retain the provided `description` fallback.

An optional `accessProvider` names an access provider registered by the same
resource through `RegisterChannelAccessProvider`. Its `CanView` receives
`{ actor=actor, suggestionKey=key }`; denial or provider failure hides the
suggestion. This controls discovery only, never command authorization.

### First-party command suggestion audit

The Feather-only audit excludes `feather-weapons`. Admin advertises its configured
menu command only to authorized staff, and its enabled report command to players.
Character advertises `/logout` and `/savequit`; Inventory advertises
`/open_inventory` and `/close_inventory`. Chat already advertises its channel
aliases. The development mock provider restores `/mock` and its channel on Chat
readiness. Other Feather registrations are diagnostics, smoke tests, console-only
or developer-only commands and are intentionally not advertised.

Run `ChatSuggestionContractSmokeTest` in the **server console**; no connected
player is required. It temporarily registers/removes synthetic suggestions and
performs no database writes. Live restart acceptance requires an active character:
check suggestions, run `restart feather-chat` in the server console, then reopen
Chat and verify they return without restarting their owners. Check the Admin menu
suggestion with both an authorized staff character and a nonstaff character;
the latter must not see it. Actual commands retain their own authorization.
Load updated consumer code first; Character's integration must wait for a normal
server startup—do not restart `feather-character` during live testing. No manifest
changes are needed for this integration.

## Staff conversations (C7 preview)

With `feather-admin` installed, open Chat and select **Staff** to view authorized
staff-to-player conversations. Staff initiates from Admin's selected-player
workflow; players cannot initiate conversations or close them. There are no
player-to-player DMs. Admin's Your Conversations entry reopens staff management
for replies, close/archive and internal-case links. `/staffchat` is removed;
players use Chat -> Staff, which does not open the Admin menu.

Messages persist in Admin-owned database tables. Closed/archived conversations
remain read-only and readable. Open Staff views update after committed-message
notifications; Refresh is a recovery control, not required for normal replies.
Use Next messages
for subsequent history pages; history pages currently start at the earliest
message. Notifications never steal focus. Account-scoped participation survives
character changes, but each request requires a current character session; staff
permissions remain attached to the active character. Internal staff notes,
account IDs and moderation case summaries are excluded from player history.

Archive policy is configured in Admin's `Config.chatConversations`; archiving
does not delete messages. C7's two-player authorization, message exchange,
privacy, persistence/restart and navigation acceptance passed. Final presentation
polish and release localization remain planned work.

## UI development

The source is in `web/`; production output is generated into `ui/`.

```text
cd web
pnpm install
pnpm check
```

The NUI has no runtime CDN dependencies and does not render caller-provided
HTML. Commit or package the built `ui/` output with releases.

## Releases

Pushes to `main` validate and package the resource, then create or update the
GitHub release for the version shared by `fxmanifest.lua` and
`web/package.json`. The workflow manages the matching `v<version>` release tag;
contributors do not create or push tags manually.

Versions with a SemVer suffix such as `-alpha.1`, `-beta.1`, or `-rc.1` are
published as GitHub prereleases. Unsuffixed versions are published as stable
releases.
