---
title: Feather Notify
---

# Feather Notify

Feather Notify is the optional default RedM presentation provider for Core
notifications. Server resources dispatch through Core; client resources can use
Notify directly for local-only presentation.

## Installation and settings

```cfg
ensure feather-core
ensure feather-notify
```

If an update changes `fxmanifest.lua` or its file list, perform a full server
restart or run `refresh` before restarting `feather-notify`. Restarting the
resource alone can continue using the previously loaded manifest.

`config.lua` limits message, title, location-label, and native-identifier byte
lengths; duration; and the signed 32-bit `quality` value. It also supplies the
default duration, bounded provider-registration retry timing, local presentation
rate, and timed-handle limit. Notify advertises these capabilities for Core to
enforce. Supported styles are `tooltip`,
`advanced`, `location`, `right`, `left`, `top_banner`, `advanced_right`, `top`,
`center`, `standard`, `bottom_right`, `mission_failed`, `dead_player`, and
`warning`.

## API reference

### Server exports

```lua
exports['feather-notify']:GetCapabilities() -> Result
exports['feather-core']:SendNotification(request[, providerName]) -> Result
```

```lua
exports['feather-core']:SendNotification({
  source = source,
  style = 'right',
  message = 'Saved successfully.',
  duration = 3000
})
```

A successful server result contains `value.dispatched = true`. This means the
provider accepted the request and emitted it to the target client; it does not
claim that the player saw the presentation.

`GetCapabilities()` returns the resource and Contract versions, provider state,
supported styles, and active limits.

### Client exports

```lua
exports['feather-notify']:ShowNotification(request) -> Result
```

A successful direct client result contains `value.displayed = true` after the
request is validated and its renderer is invoked.

Because Notify is optional, direct client calls should be protected with
`pcall` or a resource-state check. A failed notification must not change the
result of the gameplay operation that requested it.

## Request fields

| Field | Type | Required | Notes |
| --- | --- | --- | --- |
| `source` | positive integer | Server only | Must identify a connected player. |
| `style` | string | No | Defaults to `right`. |
| `message` | string | Yes | Non-empty and byte-bounded. |
| `duration` | integer | No | Milliseconds; defaults to 3000. |
| `title` | string | By style | Required for title-bearing styles. |
| `location` | string | No | Location presentation label. |
| `dictionary` | string | No | Texture dictionary identifier. |
| `icon` | string | No | Icon identifier. |
| `color` | string | No | Presentation color identifier. |
| `quality` | integer | No | Signed 32-bit native value. |
| `audioSource` | string | No | Audio source identifier. |
| `audioName` | string | No | Audio name identifier. |

Unknown fields are rejected.

### Result envelope

Success:

```lua
{ ok = true, value = { --[[ operation-specific fields ]] } }
```

Failure:

```lua
{
  ok = false,
  code = 'invalid_input',
  message = 'Notification message is invalid.',
  details = { --[[ optional bounded metadata ]] }
}
```

| Code | Meaning |
| --- | --- |
| `invalid_input` | Invalid request, target, style, field type, or bound. |
| `provider_unavailable` | No compatible provider can accept the request. |
| `presentation_failed` | Client renderer/native invocation failed. |
| `rate_limited` | A dispatch or local presentation limit was exceeded. |

Core applies a configurable per-player dispatch-rate limit. Notify separately
bounds local client presentation rate and simultaneous timed presentation
handles. Excess requests return `rate_limited` and should not be retried in a
tight loop.

Providers advertise supported styles and request limits. Core checks these
capabilities before dispatch so a more restrictive provider does not silently
discard a request Core accepted.

Styles `top_banner`, `advanced`, `mission_failed`, and `warning` require a
non-empty title. Advanced presentations may also use `dictionary`, `icon`,
`color`, `quality`, and audio fields.

Notify is optional. Removing `ensure feather-notify` leaves Core and gameplay
operational; server notification requests return `provider_unavailable`. A
replacement Contract 1 provider can register its styles and limits through Core.

## Verification

Automated Contract 1 validation runs from
`tests/contract_validation.lua` in the Notify repository. Runtime verification
commands are `CoreNotificationSmokeTest <source>`,
`CoreNotificationAvailabilityTest <source> <available|unavailable>`,
`CoreNotificationRateRecoveryTest <source>`,
`NotifyContractSmokeTest <source>`, `NotifyClientSmokeTest`,
`NotifyClientLimitSmokeTest`, and `NotifyStyleSmokeTest`.
