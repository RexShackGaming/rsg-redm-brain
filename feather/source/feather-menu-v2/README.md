# Feather Menu v2
[![UI and Lua CI](https://github.com/FeatherFramework/feather-menu-v2/actions/workflows/ci.yml/badge.svg?branch=main&event=push)](https://github.com/FeatherFramework/feather-menu-v2/actions/workflows/ci.yml)
[![Latest version](https://img.shields.io/github/v/release/DavFount/feather-menu-v2?include_prereleases&label=latest)](https://github.com/FeatherFramework/feather-menu-v2/releases)

Build RedM menus from your resource's client-side Lua. Feather Menu v2 draws the menu, manages input and focus, and tells your code when the player changes something. Your resource decides what those changes mean.

**Status:** Contract 1 alpha, with the required element set and accepted dropdown design implemented. See [release verification](docs/RELEASE_CHECKLIST.md) for the remaining live and release gates. Do not interpret browser tests as proof of RedM controller compatibility.

## Contents

- [Install and choose the right menu](#install-and-choose-the-right-menu)
- [Your first working menu](#your-first-working-menu)
- [Understand menus, pages, elements, and results](#understand-menus-pages-elements-and-results)
- [Menu configuration](#menu-configuration)
- [Element configuration](#element-configuration)
- [Every available element](#every-available-element)
- [Pages, tabs, and steppers](#pages-tabs-and-steppers)
- [Update an open menu](#update-an-open-menu)
- [Callbacks and lifecycle](#callbacks-and-lifecycle)
- [Keyboard and controller input](#keyboard-and-controller-input)
- [All exports](#all-exports)
- [Troubleshooting](#troubleshooting)
- [Maintainer build and tests](#maintainer-build-and-tests)

## Install and choose the right menu

> **Choose the correct menu generation:** `feather-menu-v2` is the official Feather Framework menu system for new development. `feather-menu` is Legacy, retained for existing RedM resources that depend on its API. Keep Legacy until those resources have been migrated. V2 is not a drop-in replacement, and some existing Feather resources still require v1. Official direction does not change the alpha status noted above.

| Your resource uses | Install |
| --- | --- |
| `exports['feather-menu'].initiate()` | **Feather Menu Legacy**, folder `feather-menu` |
| `exports['feather-menu-v2']:CreateMenu(...)` | **Feather Menu v2**, folder `feather-menu-v2` |

Both resources can be installed together. Do not rename either folder or replace Legacy with v2. V2 does not implement the Legacy object API.

1. Download the prepared `feather-menu-v2.zip` release asset, rather than GitHub's source-code archive.
2. Create a folder named `feather-menu-v2` inside your server's resources directory and extract the ZIP contents into it. The ZIP contains `fxmanifest.lua`, `client/`, and `ui/` directly, with no enclosing folder.
3. Make sure `feather-menu-v2/fxmanifest.lua` and `feather-menu-v2/ui/index.html` exist.
4. Start the menu before resources that use it:

```cfg
ensure feather-menu-v2
ensure my-feather-resource

# Only needed for resources that still use Legacy:
ensure feather-menu
```

Server operators do not need Node.js or a frontend build. V2 has no dependency on `feather-core`. If your own resource uses Core, Notify, or other Feather services, declare and start those dependencies too. Notifications belong to `feather-notify`; gameplay, permissions, saving, and server validation belong to your resource.

The install ZIP contains only runtime files:

```text
feather-menu-v2/
  fxmanifest.lua
  client/
    results.lua
    validation.lua
    main.lua
  ui/
    index.html
    assets/  (compiled JavaScript and CSS referenced by index.html)
```

The README, documentation, source, tests, build scripts, repository metadata, and `.artifacts` output directory stay in the repository. The checksum is provided beside the install ZIP, not inside the resource. Local and GitHub packaging use the same explicit file allowlist; verification fails if any additional file or directory appears in the archive.

## Your first working menu

Create a folder named `my-feather-resource`. Put these two files inside it.

**`fxmanifest.lua`**

```lua
fx_version 'cerulean'
game 'rdr3'
rdr3_warning 'I acknowledge that this is a prerelease build of RedM, and I am aware my resources *will* become incompatible once RedM ships.'

dependency 'feather-menu-v2'
client_script 'client.lua'
```

**`client.lua`**

```lua
local Menu = exports['feather-menu-v2']
local menuId
local opening = false

-- Every export gives us a result. Stop this operation if it failed.
local function Require(result)
    if not result.ok then
        error(('%s: %s'):format(result.code, result.message), 0)
    end
    return result.value
end

local function BuildMenu()
    menuId = Require(Menu:CreateMenu({
        key = 'example',
        draggable = true,
        closable = true,
        size = { width = '32rem', maxHeight = '85vh' },
        theme = { preset = 'redemption', accent = '#a73732' },
    })).menuId

    local pageId = Require(Menu:CreatePage(menuId, { key = 'main' })).pageId

    -- The examples below use this same short helper.
    local function Add(elementType, settings, callback)
        return Require(Menu:AddElement(menuId, pageId, elementType, settings, callback)).elementId
    end

    Add('header', { key = 'title', value = 'My Feather Menu', slot = 'header' })
    Add('textdisplay', { key = 'help', value = 'Change a setting, then press Done.' })
    Add('toggle', { key = 'music', label = 'Enable music', value = true }, function(event)
        print('Music enabled:', event.value)
        -- Call your resource's own music/settings code here.
    end)
    Add('button', { key = 'done', label = 'Done', slot = 'footer' }, function()
        Require(Menu:CloseMenu(menuId))
    end)
end

RegisterCommand('feathermenu', function()
    if opening then return end
    opening = true
    CreateThread(function()
        local success, problem = pcall(function()
            Require(Menu:AwaitReady(5000))
            if not menuId then BuildMenu() end
            Require(Menu:OpenMenu(menuId))
        end)
        if not success then
            print('[my-feather-resource] ' .. tostring(problem))
            if menuId then Menu:DestroyMenu(menuId) end
            menuId = nil
        end
        opening = false
    end)
end, false)

-- A provider restart deletes its menus. Rebuild on the next command.
AddEventHandler('onClientResourceStop', function(resource)
    if resource == 'feather-menu-v2' then menuId = nil end
end)
```

Start both resources, join the server, and enter `/feathermenu`. It opens one menu and reuses that menu on later commands. Add the catalog examples below **inside `BuildMenu`, after the `Add` helper**, using a different `key` for each element. You do not need to copy all of them.

## Understand menus, pages, elements, and results

| Term | Meaning |
| --- | --- |
| Menu | The window: position, size, theme, focus, and pages. |
| Page | One screen inside a menu. Only one page is visible at a time. |
| Element | One heading, button, field, selector, image, or other row. |
| Slot | Where an element appears: `header`, scrolling `content`, or `footer`. |
| Key | Your stable name for an item, such as `main` or `save-button`. |
| ID | The handle returned by the export. Save it and pass it back; do not construct IDs yourself. |
| Callback | A Lua function called when the player interacts with an element. |

Keys are required when creating menus, pages, and elements. Use 1–128 ASCII letters, numbers, `.`, `_`, `:`, `-`, or `/`. A menu key is unique within your resource; page keys within a menu; element keys within a page. Keys cannot be changed by update exports.

All public exports return one of these shapes:

```lua
{ ok = true, value = { ... } }
{ ok = false, code = 'invalid_input', message = 'Explanation', details = { ... } }
```

The `Require` helper above is convenient inside a protected `pcall`. You can also handle an expected error directly:

```lua
local result = Menu:OpenMenu(menuId, { replace = false })
if not result.ok then
    print(result.code, result.message)
    return
end
```

Menu definitions are copied. Editing your original Lua table does not update a menu: use the update exports. Your resource owns its menu IDs; another resource cannot update or close them through those exports. Owner-stop cleanup removes its menus and callbacks automatically.

## Menu configuration

Pass these fields to `CreateMenu`. Use `UpdateMenu(menuId, changes)` to change mutable presentation settings later. Unknown fields return `invalid_input`, which helps catch spelling mistakes.

| Field | Default | Meaning |
| --- | --- | --- |
| `key` | Required | Stable menu name; immutable after creation. |
| `draggable` | `true` | Allow dragging the top header region. |
| `resizable` | `false` | Show the resize grip only when explicitly `true`. |
| `closable` | `true` | Show Close and allow player Escape/Back. Your Lua code can always call `CloseMenu`. |
| `persistPosition` | `true` | Remember dragged position locally across closes. |
| `persistSize` | `true` | Remember resized dimensions across closes when resizing is enabled. |
| `controller` | `true` | Enable standard browser-gamepad routing when available. |
| `position` | `{ x = '50%', y = '50%' }` | Initial position for any resource; `x`/`y` use the selected `anchor`. |
| `position.anchor` | `'center'` | Use `'top-left'` to interpret `x`/`y` as top/left edges, e.g. `{ x = '3%', y = '3%', anchor = 'top-left' }`. The edge stays fixed when content height changes. |
| `size` | See below | Window dimensions and responsive widths. |
| `theme` | Redemption colors | The documented local theme tokens below. |
| `focus` | `{ keyboard = true, cursor = true }` | Defaults for the next `OpenMenu` call. |

Remembered position/size is browser-local presentation state, not database persistence. Explicit menu destruction and owner-stop cleanup clear the stored values when NUI receives the destroy message. Turning a persistence flag off stops reuse; it does not erase previously stored values. It is not intended as a cross-session user-settings store.

### Size and position

Any resource can set an edge anchor when initializing its menu:

```lua
exports['feather-menu-v2']:CreateMenu({
    key = 'my-menu',
    position = { x = '3%', y = '3%', anchor = 'top-left' },
    persistPosition = false, -- Always reopen at the configured location.
})
```

Omit `anchor` (or use `'center'`) to retain centered positioning. Use
`persistPosition = true` to let a saved drag position override the configured
initial location. Top-left anchoring prevents content expansion from shifting
the menu's top edge; dragging remains separately controlled by `draggable`.

Lengths are strings with units: `'420px'`, `'32rem'`, `'80%'`, `'90vw'`, or `'85vh'`. `rem` follows the UI font size; `vw` and `vh` are percentages of viewport width and height. Numbers must be non-negative, up to 8192px, 512rem, or 100 for %, vw, and vh. Raw CSS expressions such as `calc(...)` are excluded.

| `size` field | Default | Meaning |
| --- | --- | --- |
| `width` | `'32rem'` | Base width. |
| `height` | `'auto'` | Grow with content until capped; `auto` is allowed. |
| `minWidth` | `'18rem'` | Smallest width. |
| `maxWidth` | `'90vw'` | Largest width. |
| `minHeight` | `'auto'` | Smallest height; `auto` is allowed. |
| `maxHeight` | `'85vh'` | Cap height so content scrolls. |
| `breakpoints` | Omitted | Table of string keys `'720'`, `'1080'`, `'1440'`, `'2160'`, each containing a width. |

When `breakpoints` is present, it enables responsive widths. Missing entries use `size.width` when provided, otherwise 28/32/36/40rem respectively. A remembered manual resize takes precedence while resizing is enabled. Keep minimum dimensions below maximum dimensions; CSS resolves the actual viewport layout.

```lua
Require(Menu:UpdateMenu(menuId, {
    resizable = true,
    position = { x = '50%', y = '50%' },
    size = {
        minWidth = '22rem', maxWidth = '90vw', maxHeight = '85vh',
        breakpoints = {
            ['720'] = '25rem', ['1080'] = '30rem',
            ['1440'] = '34rem', ['2160'] = '40rem',
        },
    },
}))
```

### Theme

| `theme` field | Default | Meaning |
| --- | --- | --- |
| `preset` | `'redemption'` | The one supported preset. |
| `accent` | `'#a73732'` | Accent and selected-control color. |
| `background` | `'rgba(22, 17, 14, .96)'` | Menu background; dropdown defaults to a more opaque variant when omitted. |
| `panel` | `'rgba(255, 255, 255, .055)'` | Control panels. |
| `text` | `'#f6eee3'` | Primary text. |
| `muted` | `'#c8b9a5'` | Secondary text. |
| `radius` | `'8px'` | Corner radius using the bounded length format. |
| `fontFamily` | `'rdr'` (RDRLino) | System override: `'Georgia, serif'`. System stacks: `'Arial, sans-serif'`, `'monospace'`. Bundled fonts: `'rdr'` (alias for `'RDRLino'`), `'RDRLino'`, `'RDRGothica'`, `'RDRCatalogueBold'`, `'HapnaSlabSerif'`, `'Redemption'`, `'WWI'`, `'Cherolina'`, `'AncientAd'`. |

Choose a font per menu through `theme = { fontFamily = 'rdr' }` in CreateMenu or UpdateMenu. The default is RDRLino, matching legacy Feather Menu. All eight bundled font files come unchanged from legacy Feather Menu (including their embedded notices); they load locally without remote requests. RDRLino uses its WOFF2 file to avoid packaging duplicate formats. Ordinary action buttons receive consistent vertical spacing in content, sections, rows and footers; resources do not need spacer elements between them. The release verifier limits compiled JS/CSS to 256 KiB and the eight fonts to 2 MiB separately.

Colors accept hex (`#abc`, `#abcd`, `#aabbcc`, `#aabbccdd`), `rgb(r, g, b)`, `rgba(r, g, b, a)`, `transparent`, `black`, or `white`. RGB channels are integers 0–255; alpha is 0–1. Remote fonts, arbitrary stylesheets, and CSS URLs are excluded.

### Open and close options

```lua
Require(Menu:OpenMenu(menuId, {
    pageId = pageId, -- Optional: previous active page, then first registered page.
    keyboard = true,
    cursor = true,
    replace = true,
    -- sound = { action = 'YOUR_SOUND', soundset = 'YOUR_SOUNDSET' },
}))
Require(Menu:CloseMenu(menuId))
```

`keyboard` and `cursor` override `menu.focus` for that open. `replace` defaults to `true`: opening a different menu closes the previous v2 menu. Use `false` to receive `focus_unavailable` instead. Only one v2 menu owns interactive focus. This does not arbitrate focus with unrelated NUI resources or Legacy.

`OpenMenu` and `CloseMenu` accept optional `sound = { action, soundset }`. Supply known RedM frontend sound identifiers, each 1–128 letters/numbers/underscores/hyphens. The resource validates identifiers but cannot guarantee that an identifier exists in your game build. There is no arbitrary sound URL or public NUI sound command.

## Element configuration

All elements use this call:

```lua
local elementId = Require(Menu:AddElement(menuId, pageId, 'button', {
    key = 'save', label = 'Save',
}, function(event)
    print(event.action)
end)).elementId
```

| Common field | Default | Meaning |
| --- | --- | --- |
| `key` | Required | Unique key within this page. |
| `slot` | `'content'` | `'header'`, `'content'`, or `'footer'`. |
| `row` | Omitted | Give consecutive elements the same safe row key to place them side by side at equal widths. Rows stack vertically on narrow menus. |
| `section` | Omitted | Place a content element inside an existing `accordion` on the same page by its key. Add the accordion first. |
| `label` | Omitted | Visible label on elements that display one; at most 256 UTF-8 bytes. |
| `disabled` | `false` | Prevent interaction. Display-only elements have no interaction to disable. |
| `persist` | `true` | For `change` events, store the validated value in Lua menu state. With `false`, your callback must accept/reject the proposed value and call `SetElementValue` or `UpdateElement`. |

`persist` does not save to a database. Text/range controls may show a local draft before your callback updates the authoritative value. Activation buttons, image children, and page arrows do not overwrite their definitions from clicks.

Use rows for compact groups such as a date or related actions:

```lua
Menu:AddElement(menuId, pageId, 'dropdown', { key = 'month', row = 'birthday', label = 'Month', value = 1, options = months })
Menu:AddElement(menuId, pageId, 'dropdown', { key = 'day', row = 'birthday', label = 'Day', value = 1, options = days })
Menu:AddElement(menuId, pageId, 'dropdown', { key = 'year', row = 'birthday', label = 'Year', value = 1874, options = years })
```

Use an accordion to tuck optional controls away without resetting their values. `value = false` starts collapsed; opening and closing is local UI state by default. Set `notify = true` to send the normal `change` callback with a boolean open value (persisted unless `persist = false`). Optional `labelAlign = 'center'` centers the label with its arrow at the right; the default is `'left'`.

```lua
Menu:AddElement(menuId, pageId, 'accordion', { key = 'fine-tune', label = 'Fine tune', value = false })
Menu:AddElement(menuId, pageId, 'slider', {
    key = 'depth', section = 'fine-tune', label = 'Depth', value = 0, min = -1, max = 1, step = 0.05
}, function(event)
    print('Depth:', event.value)
end)
```

Interactive buttons, toggles, checkboxes, choice controls, grids, image controls, and page arrows also accept optional `sound = { action, soundset }`. Input, textarea, number, slider, and display elements do not accept that field. Sound is played by Lua after an accepted interaction and a successful callback.

Definitions are limited to six nested table levels, 4096 fields, and 64 KiB of encoded JSON. Ordinary strings are at most 4096 UTF-8 bytes; smaller field limits are listed below. Values must be serializable Lua tables, strings, finite numbers, booleans, or nil. Put callbacks in the callback argument, not inside the definition.

### Shared choice options

`arrows`, `dropdown`, `radio`, and `colorpicker` require `value` and a sequential `options` array of 1–500 entries. Values must be unique strings, finite numbers, or booleans. The selected value must exactly match an option, including its type: `1` and `'1'` are different.

```lua
options = {
    { value = 'valentine', label = 'Valentine' },
    { value = 'rhodes', label = 'Rhodes' },
    { value = 'locked', label = 'Unavailable', disabled = true },
}
```

Each option accepts `value`, optional `label`, optional `text` (fallback label), and optional `disabled`. String values and labels are capped at 256 UTF-8 bytes. You can also use scalar entries, such as `options = { 'Small', 'Medium', 'Large' }`; each scalar becomes its own label and value. Color options additionally accept `color` for the displayed swatch.

Empty choice arrays are rejected. While loading options, show a text display or a disabled placeholder option, then update both `options` and `value` together.

## Every available element

These snippets use the `Add` helper inside the starter's `BuildMenu` function. The per-element fields listed here are in addition to the common fields above. Callbacks are optional unless your resource needs to act on the interaction.

### 1. `header` — large heading

Field: `value` (text, default empty, up to 512 UTF-8 bytes). No callback.

```lua
Add('header', { key = 'heading', value = 'Character Settings', slot = 'header' })
```

### 2. `subheader` — smaller heading

Field: `value` (text, default empty, up to 512 bytes). No callback.

```lua
Add('subheader', { key = 'appearance-title', value = 'Appearance' })
```

### 3. `line` — horizontal separator

No extra fields or callback.

```lua
Add('line', { key = 'separator' })
```

### 4. `bottomline` — footer separator

No extra fields or callback. Set `slot = 'footer'` explicitly to place it there.

```lua
Add('bottomline', { key = 'footer-line', slot = 'footer' })
```

### 5. `textdisplay` — read-only text

Field: `value` (text, default empty, up to 4096 bytes). Text is escaped, not interpreted as HTML. No callback.

```lua
Add('textdisplay', { key = 'instructions', value = 'Choose your preferred settings below.' })
```

### 6. `button` — perform an action

Fields: `value` (optional serializable payload), `sound` (optional). Displays `label`. Callback: `activate`; `event.value` is the configured value, not a client-supplied replacement.

```lua
Add('button', { key = 'save-profile', label = 'Save Profile', value = 'profile' }, function(event)
    print('Save requested for:', event.value)
end)
```

### 7. `input` — one line of text

Fields: `value` (default empty, max 512 bytes), `placeholder` (max 256 bytes), `maxLength` (integer 1–512). Callback: `change` with a string when the browser commits the edit, usually on leaving the field. Typing is a local draft.

```lua
Add('input', { key = 'first-name', label = 'First name', value = '', placeholder = 'Arthur', maxLength = 40 }, function(event)
    print('Name:', event.value)
end)
```

### 8. `textarea` — multiple lines of text

Fields: `value` (default empty, max 4096 bytes), `placeholder` (max 256 bytes), `maxLength` (integer 1–4096), `rows` (integer 1–20, default 4). Callback: `change` with a string on commit.

```lua
Add('textarea', { key = 'biography', label = 'Biography', value = '', rows = 5, maxLength = 1000 }, function(event)
    print('Biography:', event.value)
end)
```

The browser's text-length counter and Lua's UTF-8 byte limits differ for accented/non-Latin text. A value exceeding the Lua byte limit is rejected even if the browser allowed it to be typed.

### 9. `number` — numeric entry

Fields: `value` (default `min`), `min` (default 0), `max` (default 100), `step` (positive number, default 1), `placeholder` (max 256 bytes). Callback: `change` with a number. On commit, input is clamped to min/max; empty or non-finite input restores the previous value. Typed values are not rounded to a multiple of `step`; step controls increment/decrement behavior.

```lua
Add('number', { key = 'age', label = 'Age', value = 30, min = 18, max = 99, step = 1 }, function(event)
    print('Age:', event.value)
end)
```

### 10. `slider` — one-axis range

Fields: `value` (default `min`), `min` (0), `max` (100), `step` (positive, default 1). Callback: `change` with a number as the player adjusts the range. Unlike gridslider, this control sends changes during dragging.

```lua
Add('slider', { key = 'volume', label = 'Volume', value = 50, min = 0, max = 100, step = 5 }, function(event)
    print('Volume:', event.value)
end)
```

### 11. `arrows` — cycle through options

Fields: required `value`, required `options`, optional `sound`. Wraps at both ends and skips disabled options. Callback: `change` with the selected option value.

```lua
Add('arrows', { key = 'weather', label = 'Weather', value = 'Sunny', options = { 'Sunny', 'Cloudy', 'Rain' } }, function(event)
    print('Weather choice:', event.value)
end)
```

### 12. `toggle` — on/off switch

Fields: `value` (boolean, default false), `onLabel` (`'On'`), `offLabel` (`'Off'`), optional `sound`. Labels are capped at 64 bytes. Callback: `change` with true/false.

```lua
Add('toggle', { key = 'show-hud', label = 'Show HUD', value = true, onLabel = 'Visible', offLabel = 'Hidden' }, function(event)
    print('HUD:', event.value)
end)
```

### 13. `checkbox` — boolean selection

Same fields and callback as toggle; exposes checkbox semantics to assistive tools.

```lua
Add('checkbox', { key = 'remember', label = 'Remember my choice', value = false, onLabel = 'Yes', offLabel = 'No' })
```

### 14. `dropdown` — accepted overlay selector

Fields: required `value`/`options`, `placeholder` (max 256 bytes), `emptyText` (max 256 bytes), `maxVisibleOptions` (integer 3–10, default 6), optional `sound`. Extra rows scroll within an overlay without expanding the menu. Callback: `change` with the selected value. Because the contract requires a matching selection and nonempty options, placeholder/empty text are presentation fallbacks, not a supported empty-selection state.

```lua
Add('dropdown', {
    key = 'town', label = 'Home town', value = 'valentine', maxVisibleOptions = 6,
    options = { { value = 'valentine', label = 'Valentine' }, { value = 'rhodes', label = 'Rhodes' } },
}, function(event)
    print('Town:', event.value)
end)
```

### 15. `radio` — choose one visible option

Fields: required `value`/`options`, optional `sound`. Callback: `change` with the selected value. Disabled options remain visible but cannot be selected.

```lua
Add('radio', {
    key = 'camp-style', label = 'Camp style', value = 'quiet',
    options = { { value = 'quiet', label = 'Quiet' }, { value = 'social', label = 'Social' } },
})
```

### 16. `colorpicker` — palette of color swatches

Fields: required `value`/`options`, optional `sound`. An option can be a color string or `{ value, label, color, disabled }`. If `color` is omitted, `value` must itself be a valid theme-format color. Callback: `change` with the option value. This is a fixed palette, not a free-form color dialog.

```lua
Add('colorpicker', {
    key = 'accent', label = 'Accent color', value = 'red',
    options = { { value = 'red', label = 'Red', color = '#a73732' }, { value = 'blue', label = 'Blue', color = '#315b85' } },
}, function(event)
    print('Color identifier:', event.value)
end)
```

### 17. `gridslider` — two-axis control

Fields: required `value = { x, y }`, `maxx`/`maxy` (positive numbers, default 1), `step` (optional shared keyboard increment), `stepx`/`stepy` (optional per-axis overrides), optional `sound`. Coordinates must be between zero and their axis maximum. Default keyboard increments are one hundredth of each maximum.

Pointer movement is smooth and local. Release sends **one** `change` callback with `{ x, y }`; cancellation restores the authoritative value without committing. Keyboard/controller direction changes commit each step. Larger y values move downward.

```lua
Add('gridslider', { key = 'face-shape', label = 'Face shape', value = { x = 0.5, y = 0.5 }, maxx = 1, maxy = 1, step = 0.05 }, function(event)
    print('X:', event.value.x, 'Y:', event.value.y)
end)
```

### 18. `pagearrows` — previous/next counter

Fields: required integer `current` and `total` with `1 <= current <= total`, optional `sound`. Callback: `previous` with value -1, or `next` with value 1. The control does not navigate menu pages or change its counter automatically. Your resource owns that decision.

```lua
local current = 1
local counterId
counterId = Add('pagearrows', { key = 'catalog-page', current = current, total = 5 }, function(event)
    current = current + event.value
    Require(Menu:UpdateElement(menuId, pageId, counterId, { current = current }))
    -- Load your catalog data for current here.
end)
```

### 19. `imagebox` — clickable image

Fields: required `image` (or supported alias `img`), optional `alt` (max 256 bytes), optional `value`, optional `sound`, and the image presentation fields below. `label` appears beneath the image. Callback: `activate` with the configured value.

| Field | Default | Meaning |
| --- | --- | --- |
| `width` | Existing responsive width | Bounded `px`, `rem`, `%`, `vw`, or `vh` length, or `auto`. |
| `height` | Existing maximum of `5rem` | Bounded length using the same units, or `auto`. |
| `aspectRatio` | Natural image ratio | A positive ratio such as `'16/9'`, with each side no greater than 100. |
| `objectFit` | Browser default | `'cover'`, `'contain'`, `'fill'`, `'none'`, or `'scale-down'`. |

`width` and `height` resize the image inside its clickable box. The box continues to provide its border, background, label, focus state, and click target. When either dimension or `aspectRatio` is supplied, the original `5rem` image-height limit is removed. The menu still limits the image to the available horizontal space.

Use `objectFit = 'cover'` for equally sized thumbnails that may crop at the edges. Use `contain` when the entire image must remain visible. `aspectRatio` is most useful with one dimension—for example, `width = '100%'` and `aspectRatio = '16/9'`. When both `width` and `height` are supplied, those dimensions determine the displayed area.

```lua
Add('imagebox', {
    key = 'horse', label = 'View horse', alt = 'Brown horse', value = 'horse-1',
    image = 'https://cfx-nui-my-feather-resource/images/horse.png',
    width = '16rem', height = '10rem', aspectRatio = '8/5', objectFit = 'cover',
}, function(event)
    print('Selected:', event.value)
end)
```

Place that image in **your own resource** and add `files { 'images/*.png' }` to its manifest. Use its actual folder name in the `cfx-nui-` URL. Relative paths are also accepted, but resolve relative to Menu v2's UI and must be included by its manifest. Prefer your own resource's Cfx asset URL.

Only relative paths and `https://cfx-nui-RESOURCE/path` are accepted; no remote, `data:`, traversal, query-string, or arbitrary HTML URLs. Paths may use letters, digits, underscores, hyphens, dots, and slashes, up to 2048 bytes. Avoid spaces in image filenames.

### 20. `imageboxcontainer` — clickable image grid

Fields: required `items` (sequential array of 1–100 children), optional `sound`. Each child accepts optional `key`, required unique scalar `value`, optional `label`, required `image` (or `img`), optional `alt`, optional `disabled`, and the same `width`, `height`, `aspectRatio`, and `objectFit` image presentation fields as `imagebox`. Images use the same asset rules as imagebox. A disabled container disables every child.

Callback: `child` with the child's value and `event.meta.child`, a defensive copy of the registered child definition.

```lua
Add('imageboxcontainer', {
    key = 'horses', items = {
        {
            key = 'brown', value = 'brown', label = 'Brown',
            image = 'https://cfx-nui-my-feather-resource/images/brown.png',
            width = '100%', height = '7rem', objectFit = 'cover',
        },
        {
            key = 'white', value = 'white', label = 'White',
            image = 'https://cfx-nui-my-feather-resource/images/white.png',
            width = '100%', height = '7rem', objectFit = 'contain',
        },
    },
}, function(event)
    print('Horse:', event.value, event.meta.child.label)
end)
```

Sizing is configured per child, so a container can mix presentation when needed. For a uniform gallery, give every child the same dimensions and `objectFit`. Omit all four presentation fields to retain the original responsive image-grid appearance.

### 21. `progress` — read-only progress bar

Fields: `value` (default `min`), `min` (0), `max` (100), optional positive `step` (accepted numeric metadata, no interactive effect), `text` (optional display override, max 256 bytes). Default text is a percentage. No callback. Update its value from your own work loop or service.

```lua
local progressId = Add('progress', { key = 'loading', label = 'Loading', value = 25, min = 0, max = 100, text = 'Preparing character...' })
Require(Menu:SetElementValue(menuId, pageId, progressId, 75))
```

### 22. `spacer` — empty vertical space

Field: `size = 'small'`, `'medium'` (default), or `'large'`. No callback.

```lua
Add('spacer', { key = 'gap', size = 'small' })
```

`html` is intentionally excluded. `datepicker` was disabled in released Legacy and is not claimed as supported. Notifications and version checking belong to separate resources.

## Pages, tabs, and steppers

Create pages before referencing their IDs. Page configuration currently supports only `key`; headings and slot contents are elements, not page fields. `NavigateToPage` changes the active page without reconstructing the menu. Committed values are kept in Lua. While the menu stays open, v2 also remembers page drafts, the last focused element/control, and content scroll position.

### Tabs

```lua
local appearanceId = Require(Menu:CreatePage(menuId, { key = 'appearance' })).pageId
Require(Menu:ConfigureNavigation(menuId, {
    type = 'tabs',
    pages = { { pageId = pageId, label = 'General' }, { pageId = appearanceId, label = 'Appearance' } },
}))
```

Tabs navigate automatically by default. Set `controlled = true` and provide a callback if your resource must approve the change; call `NavigateToPage` after approval.

### Stepper

```lua
local reviewId = Require(Menu:CreatePage(menuId, { key = 'review' })).pageId
Require(Menu:ConfigureNavigation(menuId, {
    type = 'stepper', allowDirectStep = false,
    backLabel = 'Back', nextLabel = 'Continue', finishLabel = 'Finish',
    pages = { { pageId = pageId, label = 'Details' }, { pageId = reviewId, label = 'Review' } },
}, function(event)
    if event.action == 'finish' then
        -- Validate and save through your resource's own services here.
        Require(Menu:CloseMenu(menuId))
    elseif event.toPageId then
        -- Reject invalid form data here by returning without navigating.
        Require(Menu:NavigateToPage(menuId, event.toPageId))
    end
end))
```

Steppers always emit intents: your callback decides whether to move. They do not save forms or enforce business validation. An intent is a request, not proof that the user completed a step.

| Navigation field | Default | Meaning |
| --- | --- | --- |
| `type` | Required | `'tabs'` or `'stepper'`. |
| `pages` | Required | Sequential array of 1–64 registered, unique page IDs. |
| `controlled` | `false` | Tabs require explicit Lua navigation when true. Steppers are always controlled. |
| `allowDirectStep` | `true` | Allow clicking a step heading; only relevant to steppers. Set false for sequential workflows. |
| `backLabel` | `'Back'` | Stepper back button, max 128 bytes. |
| `nextLabel` | `'Next'` | Stepper forward button, max 128 bytes. |
| `finishLabel` | `'Finish'` | Final step button, max 128 bytes. |

Each navigation page accepts `pageId` (required), `label` (max 128 bytes), and booleans `disabled`, `hidden`, `complete`, and `invalid` (all default false). `complete` and `invalid` are visual status; validation stays in your resource. Earlier steps also receive completed styling. Hidden pages are omitted from navigation; disabled targets cannot be selected by NUI. Your owning resource can still explicitly navigate to a registered page.

Navigation callbacks receive `{ menuId, mode, fromPageId, toPageId, action, index }`. Actions are `select` for tabs; `step`, `back`, `next`, or `finish` for steppers. `finish` has no target page. `index` is zero-based: the selected heading for `select`/`step`, or the current step for Back/Next/Finish. Use `pageId` for application logic instead of assuming an index never changes.

`UpdateNavigation(menuId, changes)` updates labels or rules without reopening. If you provide `pages`, provide the **entire replacement array**. Destroying a page removes its navigation entry; destroying the final navigation entry clears navigation.

## Update an open menu

```lua
Require(Menu:UpdateElement(menuId, pageId, elementId, { label = 'Updated label', disabled = false }))
Require(Menu:SetElementValue(menuId, pageId, elementId, 'new-value'))
```

Use the right value type for that element. `SetElementValue` is shorthand for updating `value`; pagearrows instead uses `UpdateElement(..., { current = ... })`.

Nested configuration objects merge. Arrays (`options`, `items`, navigation `pages`) **replace** the old array completely, including when the new array is shorter. A nil Lua table field is absent; it does not remove a setting. Reset using an explicit documented value, or remove and recreate the element.

To change a choice list, send its replacement list and valid selection together:

```lua
Require(Menu:UpdateElement(menuId, pageId, townId, {
    options = { { value = 'rhodes', label = 'Rhodes' } }, value = 'rhodes',
}))
```

For changes that must succeed or fail together, use `ApplyPatch`:

```lua
Require(Menu:ApplyPatch(menuId, {
    { op = 'updateElement', pageId = pageId, elementId = titleId, changes = { value = 'Settings' } },
    { op = 'updateElement', pageId = pageId, elementId = saveId, changes = { label = 'Save' } },
}))
```

Contract 1 batches accept 1–256 `updateElement` operations, with each element appearing once. Every operation is validated before any applies. This is useful when changing translated labels: obtain translations in your Feather resource, then send the resulting strings. Menu v2 does not load language packs itself.

Updates work on active and inactive pages. Existing elements keep their IDs and callbacks; ordinary same-page label updates preserve local field drafts and focus. A changed authoritative `value` replaces the local draft. Returning to a page restores its draft only if its authoritative value has not changed while away, along with its content scroll and last enabled focused control. Removing an element/page discards its cached UI state. Closing/destroying the menu releases these temporary caches; commit edits to your own service before closing if they must survive.

Export success means **Lua accepted the change**, not that a frame has been drawn. NUI acknowledges applied revisions; rejected revisions request a full snapshot. Missing acknowledgements trigger at most three retries, two seconds apart. `GetHealth().value.pendingAcknowledgements` reports open menus still waiting. `SyncMenu(menuId)` requests a fresh snapshot when diagnosing recovery; do not poll it every frame.

## Callbacks and lifecycle

Element callbacks receive:

```lua
{
    menuId = 'returned-menu-id',
    pageId = 'returned-page-id',
    elementId = 'returned-element-id',
    action = 'change', -- See the element catalog.
    value = true,     -- Element-specific type; may be nil for activation.
    -- meta = { child = ... } -- Image-container child only.
}
```

V2 checks the active menu/page, disabled state, allowed action, and proposed value before calling your callback, including when `persist = false`. Callback return values do not accept/reject edits automatically. For service-owned settings, use `persist = false`, perform your operation, and explicitly update the control from the service's actual value, including after rejection.

```lua
local settingId
settingId = Add('toggle', { key = 'service-setting', label = 'Enabled', value = false, persist = false }, function(event)
    local accepted = event.value -- Replace with your service's validation/write.
    Require(Menu:SetElementValue(menuId, pageId, settingId, accepted))
end)
```

Callbacks can be normal Lua functions or Cfx callable function references. Failures are caught and logged; they do not bypass cleanup or prevent a later Close. Default-persisted state is stored before the callback, so a thrown error does not roll it back. Avoid long blocking work in callbacks, and validate gameplay actions on your server.

```lua
Require(Menu:RegisterMenuLifecycle(menuId, function(event)
    print(event.event, event.pageId, event.reason)
end))
```

Lifecycle events are `opened`, `closed`, `pageChanged`, `suspended`, and `resumed`. Fields include `menuId`, current `pageId`, optional `fromPageId`, optional `reason`, and `replacedByMenuId` when replaced. Close reasons include `api`, `user`, and `replaced`; pause events use `pauseMenu`. Owner/provider stop is cleanup, not a guaranteed final callback into a stopping resource. Pass nil to unregister the lifecycle callback.

Pause suspends the open menu and releases focus. Resume restores it when no other v2 menu took focus. Explicitly closing or destroying a suspended menu prevents it from reopening afterward.

## Keyboard and controller input

| Input | Behavior |
| --- | --- |
| Tab / Shift+Tab | Move among enabled controls within the menu. |
| Up / Down | Move among ordinary buttons; editable fields and selectors own their editing keys. |
| Enter / Space | Activate buttons using native browser behavior. |
| Escape | Close an open dropdown first; otherwise request menu close. |
| Dropdown arrows, Home, End | Move the active option, skipping disabled choices. Enter/Space selects. |
| Grid arrow keys | Move x/y by the configured step. |
| Standard controller A / south face | Activate/select focused control. |
| Standard controller B / east face | Back/Escape. |
| Controller shoulders | Previous/next control; useful for leaving a slider or grid. |
| D-pad / left stick | Directional editing or navigation. |

Gamepads require the host browser to expose a `standard` mapping through the [Gamepad API](https://developer.mozilla.org/en-US/docs/Web/API/Gamepad_API/Using_the_Gamepad_API). Unknown mappings are ignored. Text entry still requires a keyboard; this resource does not provide a virtual keyboard. Live RedM device validation remains a release gate. Set `controller = false` to disable browser-gamepad polling for a menu.

While any Menu v2 menu is open, Menu v2 releases gameplay passthrough and suppresses RedM control groups every frame. This is designed to prevent movement, sprint, inventory, and other gameplay actions from firing underneath a modal NUI while Chromium continues to receive menu-controller input. First-party Admin, Settings, and Inventory hotkeys also query `IsInputCaptured()` before opening a competing interface. Both halves require live RedM/controller verification.

Register a custom ordinary-button shortcut with:

```lua
Require(Menu:RegisterKeyAction(menuId, 'F2', function(event)
    print('Shortcut for:', event.menuId)
end))
Require(Menu:RemoveKeyAction(menuId, 'F2'))
```

Keys use browser `KeyboardEvent.key` names, 1–32 characters. Escape/Tab and control-owned keys take precedence. Shortcuts do not intercept typing in input/textarea fields. Callback payload is `{ menuId, key }`. Use `FocusElement(menuId, pageId, elementId)` to focus a control on the active page after opening.

## All exports

Every row returns the standard result envelope. IDs must belong to the calling resource.

| Export | Success `value` / purpose |
| --- | --- |
| `GetCapabilities()` | Resource/version/contract, readiness state, supported feature contract numbers. |
| `GetHealth()` | Readiness, `uiReady`, menu count, active ID, pending acknowledgement count. |
| `IsInputCaptured()` | `true` while any Menu v2 menu owns modal input; this owner-neutral query returns a boolean directly. |
| `AwaitReady(timeoutMs)` | Wait up to 0–30000ms; returns health or `not_ready`/`timeout`. Call from a yieldable thread. |
| `CreateMenu(spec)` | `{ menuId }`. |
| `UpdateMenu(menuId, changes)` | `{ revision }`. Updates mutable configuration. |
| `GetMenuState(menuId)` | Defensive snapshot: config, pages/elements, revision, open state, active page, navigation and keys. |
| `OpenMenu(menuId, options?)` | `{ menuId, pageId }`. |
| `SetMenuFocus(menuId, options)` | `{ keyboard, cursor }`; changes input ownership without hiding the active menu. |
| `CloseMenu(menuId, options?)` | `{ menuId }`. Safe to repeat for an existing closed menu. |
| `DestroyMenu(menuId)` | `{ destroyed = true }`; removes definition, callbacks, UI state and focus. A later call returns `not_found`. |
| `DestroyOwnedMenus()` | `{ removed }`; removes all menus belonging to your resource. |
| `CreatePage(menuId, spec)` | `{ pageId }`. |
| `UpdatePage(menuId, pageId, changes)` | `{ revision }`; only `key` is currently defined and it is immutable, so use elements to change page content. |
| `DestroyPage(menuId, pageId, fallbackPageId?)` | `{ destroyed = true, revision }`; deleting the active page requires another existing fallback page. |
| `NavigateToPage(menuId, pageId)` | `{ pageId, revision }`. |
| `AddElement(menuId, pageId, type, spec, callback?)` | `{ elementId }`. |
| `UpdateElement(menuId, pageId, elementId, changes)` | `{ revision }`. |
| `SetElementValue(menuId, pageId, elementId, value)` | `{ revision }`. |
| `RemoveElement(menuId, pageId, elementId)` | `{ removed }`; false when already absent. |
| `FocusElement(menuId, pageId, elementId)` | `{ elementId }`; page must be open and active. |
| `ConfigureNavigation(menuId, spec, callback?)` | `{ revision }`; replaces navigation and its callback. |
| `UpdateNavigation(menuId, changes)` | `{ revision }`; retains callback. |
| `RegisterMenuLifecycle(menuId, callback?)` | `{ registered }`; nil removes callback. |
| `RegisterKeyAction(menuId, key, callback)` | `{ key }`. |
| `RemoveKeyAction(menuId, key)` | `{ key }`. |
| `ApplyPatch(menuId, operations)` | `{ revision, applied }`. Atomic element updates. |
| `SyncMenu(menuId)` | `{ revision }`; sends authoritative state when NUI is ready. |

Resource limits: 64 menus globally, 64 pages per menu, 512 elements per page, 256 patch operations, 500 choices, and 100 image children. Encoded definitions/callbacks are bounded to 64 KiB, batches to 256 KiB, and menu snapshots to 1 MiB with reserved envelope space. These are ceilings, not recommended menu sizes.

## Troubleshooting

| Symptom/code | What to check |
| --- | --- |
| `not_ready`, `timeout`, or blank NUI | Start v2 first; use `AwaitReady`; verify `ui/index.html` and referenced compiled assets. Check the client F8 console. |
| No such export / Legacy method missing | Resource name and API generation. V2 uses named exports, not `initiate()`. |
| `invalid_input` | Read `message`/`details.path`. Check spelling, field allowlists, types, bounds, and matching choice value. |
| `unsupported_element` | Use a type from the 22-element catalog; HTML/datepicker are excluded. |
| `conflict` | Duplicate key, repeated target in a batch, stale intent, or active page deletion without fallback. |
| `not_found` after restart | Provider restart discarded IDs. Rebuild pages/elements before reopening. |
| `forbidden` | Another resource owns the ID. Create and operate menus from the same resource. |
| `unauthenticated` | The export needs a calling resource; use it from your client resource. |
| `invalid_state` | Open the correct page first, or configure navigation before updating it. |
| `focus_unavailable` | Another v2 menu is open and you chose `replace = false`. |
| `limit_exceeded` | Reduce definitions/pages/options or split the menu. |
| `callback_failed` in NUI | Inspect your callback error in F8. Callback errors are caught but your operation still needs fixing. |
| `transport_unavailable` in NUI | The browser could not reach the resource callback, often during restart. This is a browser transport result. |
| Values change visually but are not saved | Menu state is not database state. Implement saving in your Feather service. |
| Dropdown update rejected | Supply a nonempty replacement list and a matching `value` in the same update. |
| Image missing | Correct `cfx-nui-` resource name, safe filename, existing file, and consuming resource `files` entry. |
| Cursor remains after menu closes | Check another NUI resource's focus ownership and the live coexistence matrix. V2 only controls its own focus paths. |

For migration, replace Legacy menu/page objects with saved IDs and named exports. Move notification calls to `feather-notify`. Settings already uses this pattern; Character and Admin migrations remain separately tracked in the framework master plan.

## Maintainer build and tests

Use **Node 22** (`.node-version`) and **pnpm 9.15.0** (`web/package.json`). The Vue/Vite project is under `web`; it builds into the manifest's runtime-only `ui` directory.

```text
cd web
pnpm install --frozen-lockfile
pnpm check
pnpm dev
```

`pnpm check` runs lint, component/unit tests, and a production build. The development fixture is at `http://localhost:5174`; `?view=stepper` selects the stepper fixture. It renders without RedM, but browser-only callbacks do not execute Lua gameplay code. The fixture is excluded from production.

From the repository root with Lua 5.4 installed:

```text
lua tests/lua/validation_spec.lua .
lua tests/lua/runtime_spec.lua .
```

The runtime suite stubs Cfx to test ownership, validation, atomic batches, callable callbacks, failure handling, acknowledgements, focus, pause cancellation, and cleanup. It does not replace live RedM tests.

Pushes to `main` validate the resource, build a downloadable install artifact, and automatically publish the version declared in `web/package.json`; contributors do not create or push release tags manually. Alpha and other hyphenated versions are published as prereleases. The workflow verifies that the package and manifest versions match before publishing. The ZIP contains runtime files directly at its root, including compiled assets; its SHA-256 checksum is provided separately. Extract it into a folder named `feather-menu-v2`. Verify the actual archive with `python scripts/verify_release.py feather-menu-v2.zip`.

To make the same runtime-only ZIP locally after building, run `python scripts/package_release.py` from the repository root. It writes `.artifacts/feather-menu-v2.zip` and its checksum; then run `python scripts/verify_release.py .artifacts/feather-menu-v2.zip`.

See [Contract 1](docs/CONTRACT_1.md), [feature parity](docs/FEATURE_PARITY.md), and [release verification](docs/RELEASE_CHECKLIST.md) for maintainer details. No sibling test resource is assumed to be present in this checkout.

## Action feedback, field errors and confirmations

Ordinary buttons use the native held-down pressed state and return directly to
their hover/focus state on release; no delayed click flash is applied. They reject repeat activation while their NUI acknowledgement is outstanding.
A shared spinner beside the close X appears only after 250 ms of continuous busy
work, avoiding flashes on normal clicks. Without a close X it uses the same corner. For longer resource work, use UpdateElement with
`busy = true`, then clear it or replace the page when the operation completes.
`busyLabel` is optional localized text such as "Saving..."; otherwise the normal
label remains. Busy buttons also reject activation at the Lua boundary. Expandable section headers and arrow
selectors/page arrows have hover and pressed feedback without using game-font glyphs.
Reduced-motion preferences disable movement/spinner animation.

Text inputs, textareas and number fields accept `error = 'localized message'`
(up to 512 UTF-8 bytes). The message appears below the field with `role=alert`,
`aria-invalid` and an associated description. Clear with `error = ''`. Consumers
own validation and localization through the player's settings language.

Buttons can request a confirmation before their normal callback runs:

```lua
Add('button', {
    key = 'sell', label = translatedSell,
    confirm = {
        title = translatedTitle, message = translatedMessage,
        confirmLabel = translatedConfirm, cancelLabel = translatedCancel,
    },
}, onSell)
```

Each confirmation string is required (1-512 UTF-8 bytes). Text is rendered as text,
not HTML. Cancel has initial focus; keyboard/controller navigation stays in the
dialog. Escape, page exit and menu destruction cancel without invoking the action.
The underlying menu is inert while confirming. Confirmation is UI intent only;
consumers still enforce permissions, revisions and transaction rules on the server.
No destructive behavior is attached automatically to existing resource buttons.

Accordion `selected = true` adds separate muted-color `< >` markers around the plain text label and sets `aria-current`. It does not expand the section or allow HTML in labels. Marker color follows `theme.muted`, matching subheadings.
