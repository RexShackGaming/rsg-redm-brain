# Feather Settings

Version: **0.1.8**.

Owns the player settings menu and its PGUP input. It consumes the framework-agnostic `feather-menu-v2` Contract 1 API. Locale persistence remains a minimal Core account primitive, while PVP state is provided by `feather-pvp`.

## Installation and owner configuration

Start Core, Menu v2, PVP, and Character before Settings; these are its declared
dependencies. Install their prerequisites as described in their own READMEs.

```cfg
ensure feather-core
ensure feather-menu-v2
ensure feather-pvp
ensure feather-character
ensure feather-settings
```

This is a Settings dependency sequence, not a complete framework server config.
Keep the resource name `feather-settings`. After manifest changes run `refresh`
before restarting Settings. Stopping a hard dependency can stop Settings and other
consumers; coordinate shared dependency restarts rather than treating them as an
isolated Settings operation.

All owner settings are in `config.lua`:

| Field | Default | Purpose |
| --- | --- | --- |
| `Hotkey` | `0x446258B6` (PGUP) | Open/close Settings when another interface does not capture input. |
| `DefaultLocale` | `en_us` | Fallback language when no saved locale is available. |
| `Languages` | English, Spanish, French, Romanian | Codes and labels offered by the language page; locale translations must also be available. |

Preferences apply immediately through their owning resource; there is no
Settings-wide Save button. General and Session remain on the main page, while
provider controls open in group submenus. Session actions save Character position
and return to selection or disconnect through Character's commands. The PVP
toggle controls PVP's client-local preference; it is not a server combat-policy
or mutual-consent control. Settings itself stores no arbitrary preference values.

## Provider API

Feature resources can add bounded choice controls without moving preference
ownership into Settings:

```lua
exports['feather-settings']:RegisterChoice({
    id = 'my-resource:display-mode',
    ownerResource = GetCurrentResourceName(),
    label = 'Display Mode',
    control = 'arrows',
    options = {
        { value='Temporary', label='Temporary' },
        { value='Always', label='Always' },
    },
    initialValue = GetDisplayMode(),
    setEvent = 'MyResource:Settings:SetDisplayMode',
})
```

Provider IDs are resource-owned and unique. Providers are removed automatically
when their resource stops and may re-register after either resource restarts.
Settings renders the control; the provider validates and persists its value.
Pass `ownerResource = GetCurrentResourceName()` because some CFX client export
paths do not preserve `GetInvokingResource()`. Call
`UnregisterChoice(id, GetCurrentResourceName())` for explicit removal.
For cross-resource controls, a scalar `initialValue` plus a local `setEvent` is
preferred: the owner validates, persists, and applies the event value without
depending on CFX callback or dynamic-export serialization.
Supported controls are `dropdown`, `arrows`, and `slider`. Sliders use numeric
`min`, `max`, and `step` fields; arrows use the same bounded option documents as
dropdowns.

## Grouping and ordering

Registrations and removal still return booleans. Existing registrations need no
migration: omitted group metadata places controls under the owner resource name.
Optional metadata:

```lua
group = { key = 'display', label = 'Display', order = 10 },
order = 20,
```

General and Character Session actions stay on the main page. Each provider group
has one button opening its own submenu, with immediate-change guidance and a
localized Back action. Back returns focus to the group's main-page button.
Existing consumers require no changes. Without metadata, each owner gets one
submenu labeled with its resource name; optional groups create separate submenus.
The main page grows by group count rather than by individual control count.

Group keys accept 1–64 identifier bytes (letters, digits, underscore, dot, colon,
hyphen); labels accept 1–100 bytes. Orders are finite integers from -1000 to 1000,
defaulting to zero. Groups belong to their actual registered owner; identical keys
from different owners remain separate. Groups sort by order then owner/key;
controls sort by order then choice ID. The lowest current choice ID supplies
conflicting group label/order metadata. General appears first and Session last.
Provider labels remain owner-supplied; re-register to change translations.
Registration copies presentation metadata/options, so later caller mutations do
not change the registered control. Malformed supplied metadata is rejected.

Settings validates option membership, disabled controls/options, and finite slider
range/step alignment before dispatch. Providers must still validate and authorize
writes themselves. Callback/export rejection (`false` or a thrown error) refreshes
the displayed owner value. Event success means dispatch only; it cannot establish
acceptance or persistence. No acknowledgement protocol is required.

Preferences apply immediately; each owner controls persistence. Session actions
invoke the existing Character `logout` and `savequit` commands. Core owns account
locale and PVP owns its preference.

Menu initialization tries readiness three times (3 seconds per attempt, 500ms
between attempts), then logs failure. PGUP retries a bounded initialization cycle.
Menu v2 start recreates at most one menu while initialization is in progress.
Settings stop destroys its menu. Regular refreshes preserve element identities;
layout or registration changes replace controls only in affected group pages.
Main-page group buttons are reordered only when the group list/order changes.
Group pages, built-ins, and the open menu are retained. Removing the active group
returns to the main page; stale navigation/control callbacks are ignored. Menu v2
remembers page focus/scroll where supported; behavior during structural changes
still requires live validation.

## Validation

Run `lua5.4 tests/behavior.lua` from this resource root. CI also syntax-checks Lua.
`SettingsClientSmokeTest` checks live dependency contracts in F8.
Current evidence and coordinated live acceptance are maintained in
[Settings delivery evidence](../feather-framework-docs/feather-settings/SCOPED_DELIVERY_EVIDENCE.md).
Do not restart shared dependencies without coordinating with their owners.
