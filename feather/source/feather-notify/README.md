# Feather Notify

Feather Notify is the optional default notification display resource for the
Feather Framework. It provides the native RedM presentations used by Feather
resources while Feather Core handles server-side validation and routing.

A notification is presentation only. If Notify is disabled or temporarily
unavailable, gameplay actions continue with their original result.

## Server-owner guide

### Installation

Start Notify after Core:

```cfg
ensure feather-core
ensure feather-notify
```

Notify is optional. Without it, Core and gameplay resources continue running,
but server notification requests return `provider_unavailable`.

If an update changes `fxmanifest.lua` or its file list, restart the server or
run `refresh` before restarting `feather-notify`. Restarting only the resource
can leave the old manifest file list loaded.

### Configuration

Most servers should keep the defaults in `config.lua`.

| Setting | Default | Purpose |
| --- | ---: | --- |
| `maxMessageLength` | `512` | Maximum message length in bytes. |
| `maxTitleLength` | `256` | Maximum title length in bytes. |
| `maxLocationLength` | `256` | Maximum location-label length in bytes. |
| `maxIdentifierLength` | `128` | Maximum icon, dictionary, color, and audio identifier length. |
| `maxDurationMs` | `15000` | Longest allowed presentation in milliseconds. |
| `defaultDurationMs` | `3000` | Duration used when a resource omits one. |
| `minQuality` / `maxQuality` | signed 32-bit range | Bounds the native quality value. |
| `providerRegistrationAttempts` | `5` | Registration attempts while Core becomes available. |
| `providerRegistrationBaseDelayMs` | `500` | Initial registration retry delay. |
| `providerRegistrationMaxDelayMs` | `5000` | Maximum registration retry delay. |
| `clientRateWindowMs` | `1000` | Local presentation-rate window. |
| `clientMaxCallsPerWindow` | `20` | Presentations accepted during one window. |
| `maxTimedPresentations` | `8` | Simultaneous retained timed presentations. |

Core separately controls server dispatch limits. Notify advertises its actual
styles and limits so Core can reject unsupported requests before dispatch.

### Included presentations

Notify includes `tooltip`, `advanced`, `location`, `right`, `left`,
`top_banner`, `advanced_right`, `top`, `center`, `standard`, `bottom_right`,
`mission_failed`, `dead_player`, and `warning`.

### Disabling or replacing Notify

Remove `ensure feather-notify` to disable the default presentation provider.
Do not remove `feather-core`; it remains the framework service boundary.

A compatible replacement can register as the default Contract 1 notification
provider and advertise its supported styles and limits. Gameplay resources that
use Core do not need to be edited when the replacement supports their requests.

### Verification

Run these from the server console:

```text
CoreNotificationSmokeTest <source>
CoreNotificationAvailabilityTest <source> <available|unavailable>
CoreNotificationRateRecoveryTest <source>
NotifyContractSmokeTest <source>
```

Run these from the client F8 console:

```text
NotifyClientSmokeTest
NotifyClientLimitSmokeTest
NotifyStyleSmokeTest
```

The smoke tests validate contracts, request limits, provider lifecycle, and rate
recovery. `NotifyStyleSmokeTest` still requires a person to visually confirm
each presentation. Automated Contract 1 validation also runs in CI from
`tests/contract_validation.lua`.

Developers with Lua 5.4 installed can run the same suite from the resource root:

```text
lua5.4 tests/contract_validation.lua
```

## Developer API reference

### Server dispatch

Server resources send notifications through Core:

```lua
local result = exports['feather-core']:SendNotification({
    source = source,
    style = 'right',
    message = 'Saved successfully.',
    duration = 3000
})
```

An optional provider name can be supplied as the second argument:

```lua
exports['feather-core']:SendNotification(request, 'my-notify-provider')
```

Success returns:

```lua
{ ok = true, value = { dispatched = true, style = 'right' } }
```

`dispatched` means the provider accepted the request and emitted it to the
client. It does not confirm that the player saw it.

### Client presentation

Client resources can request a local presentation directly:

```lua
local result = exports['feather-notify']:ShowNotification({
    style = 'top_banner',
    title = 'Feather',
    message = 'Welcome to the server.',
    duration = 3000
})
```

Success returns `value.displayed = true` after validation and renderer
invocation. Because Notify is optional, wrap direct exports in `pcall` or check
the resource state before calling them.

### Capabilities

Server code can inspect the running provider:

```lua
local result = exports['feather-notify']:GetCapabilities()
```

The successful value includes the resource version, Contract version, state,
supported styles, and active request limits.

### Request fields

| Field | Type | Required | Notes |
| --- | --- | --- | --- |
| `source` | positive integer | Server only | Must identify a connected player. |
| `style` | string | No | Defaults to `right`. |
| `message` | string | Yes | Must be non-empty and within the configured limit. |
| `duration` | integer | No | Milliseconds; defaults to `defaultDurationMs`. |
| `title` | string | By style | Required by `advanced`, `top_banner`, `mission_failed`, and `warning`. |
| `location` | string | No | Location presentation label. |
| `dictionary` | string | No | Texture dictionary identifier. |
| `icon` | string | No | Icon identifier. |
| `color` | string | No | Presentation color identifier. |
| `quality` | integer | No | Bounded native quality value. |
| `audioSource` | string | No | Audio source identifier. |
| `audioName` | string | No | Audio name identifier. |

Unknown fields are rejected.

### Style fields

| Style | Required fields | Common optional fields |
| --- | --- | --- |
| `tooltip` | `message` | `duration` |
| `advanced` | `title`, `message` | `dictionary`, `icon`, `color`, `duration` |
| `location` | `message` | `location`, `duration` |
| `right`, `left`, `top`, `center`, `standard`, `bottom_right` | `message` | `color`, `duration` where supported |
| `top_banner`, `mission_failed` | `title`, `message` | `duration` |
| `advanced_right` | `message` | `dictionary`, `icon`, `color`, `quality`, `duration` |
| `dead_player` | `message` | `audioSource`, `audioName`, `duration` |
| `warning` | `title`, `message` | `audioSource`, `audioName`, `duration` |

### Result and error handling

All APIs return a result envelope. Check `result.ok` before reading
`result.value`.

| Code | Meaning |
| --- | --- |
| `invalid_input` | Invalid request, target, style, field type, or bound. |
| `provider_unavailable` | No compatible server provider accepted the request. |
| `presentation_failed` | A client renderer or native invocation failed. |
| `rate_limited` | A server dispatch or local presentation limit was exceeded. |

Notification failure must not reverse or redefine successful gameplay work.
Do not retry `rate_limited` or `provider_unavailable` in a tight loop.
