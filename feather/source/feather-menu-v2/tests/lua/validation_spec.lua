local root = arg[1] or '.'
dofile(root .. '/client/results.lua')
dofile(root .. '/client/validation.lua')

local passed = 0
local function Pass(condition, label)
    if not condition then error('FAIL ' .. label, 0) end
    passed = passed + 1
end
local function Valid(result, label) Pass(result == nil, label) end
local function Invalid(result, code, label)
    Pass(type(result) == 'table' and result.ok == false and result.code == code, label)
end

Valid(MenuValidation.Menu({ key = 'settings', draggable = true, resizable = false }, 'spec', true), 'valid menu')
Valid(MenuValidation.Menu({key='anchored',position={x='3%',y='3%',anchor='top-left'}},'spec',true),'top-left placement')
Valid(MenuValidation.Menu({key='centered',position={anchor='center'}},'spec',true),'explicit centered placement')
Invalid(MenuValidation.Menu({key='bad-anchor',position={anchor='bottom-right'}},'spec',true),'invalid_input','unsupported anchor')
Invalid(MenuValidation.Menu({ key = 'bad key' }, 'spec', true), 'invalid_input', 'unsafe menu key')
Invalid(MenuValidation.Menu({ key = 'menu', draggable = 'yes' }, 'spec', true), 'invalid_input', 'menu boolean')
Invalid(MenuValidation.Payload({ callback = function() end }, 'spec'), 'invalid_input', 'function payload')
Invalid(MenuValidation.Payload({ value = 0 / 0 }, 'spec'), 'invalid_input', 'NaN payload')
local cyclic = {}; cyclic.self = cyclic
Invalid(MenuValidation.Payload(cyclic, 'spec'), 'invalid_input', 'cyclic payload')

Valid(MenuValidation.Element('button', { key = 'save', label = 'Save' }), 'button')
Valid(MenuValidation.Element('button', { key = 'save', label = 'Save', row = 'actions' }), 'button row')
Invalid(MenuValidation.Element('button', { key = 'save', row = 'not valid' }), 'invalid_input', 'invalid row key')
Invalid(MenuValidation.Element('unknown', { key = 'bad' }), 'unsupported_element', 'unknown element')
Valid(MenuValidation.Element('toggle', { key = 'pvp', value = true }), 'toggle')
Valid(MenuValidation.Element('accordion', { key = 'fine-tune', label = 'Fine tune', value = false }), 'accordion')
Valid(MenuValidation.Element('slider', { key = 'depth', section = 'fine-tune', value = 0, min = -1, max = 1 }), 'accordion child')
Invalid(MenuValidation.Element('accordion', { key = 'fine-tune', label = 'Fine tune', value = 1 }), 'invalid_input', 'accordion open state is boolean')
Invalid(MenuValidation.Element('accordion', { key = 'fine-tune' }), 'invalid_input', 'accordion label required')
Invalid(MenuValidation.Element('slider', { key = 'depth', section = 'bad section' }), 'invalid_input', 'section key validated')
Invalid(MenuValidation.Element('toggle', { key = 'pvp', value = 'true' }), 'invalid_input', 'toggle value')
Valid(MenuValidation.Element('number', { key = 'age', value = 36, min = 18, max = 99, step = 1 }), 'number')
Invalid(MenuValidation.Element('number', { key = 'age', value = 100, min = 18, max = 99 }), 'invalid_input', 'numeric bounds')
Valid(MenuValidation.Element('dropdown', { key = 'town', value = 'valentine', options = {
    { value = 'valentine', label = 'Valentine' }, { value = 'blackwater', label = 'Blackwater' },
} }), 'dropdown')
Invalid(MenuValidation.Element('dropdown', { key = 'town', value = 'missing', options = {
    { value = 'valentine', label = 'Valentine' },
} }), 'invalid_input', 'selected option')
Invalid(MenuValidation.Element('dropdown', { key = 'town', value = 'one', maxVisibleOptions = 11, options = {
    { value = 'one', label = 'One' },
} }), 'invalid_input', 'dropdown row limit')
Valid(MenuValidation.Element('gridslider', { key = 'face', value = { x = 0.5, y = 0.5 }, maxx = 1, maxy = 1, step = 0.1 }), 'grid')
Invalid(MenuValidation.Element('gridslider', { key = 'face', value = { x = 2, y = 0.5 }, maxx = 1, maxy = 1 }), 'invalid_input', 'grid bounds')
Invalid(MenuValidation.Element('gridslider', { key = 'face', value = { x = 0.5, y = 0.5 }, step = 0 }), 'invalid_input', 'grid step')
Valid(MenuValidation.ElementChanges('toggle', { key = 'pvp', value = false }, { value = true }, 'changes'), 'valid merged update')
Invalid(MenuValidation.ElementChanges('toggle', { key = 'pvp', value = false }, { value = 'yes' }, 'changes'), 'invalid_input', 'invalid merged update')
Valid(MenuValidation.Navigation({ type = 'tabs', pages = {
    { pageId = 'menu/main', label = 'Main' }, { pageId = 'menu/language', label = 'Language' },
} }), 'tabs')
Invalid(MenuValidation.Navigation({ type = 'tabs', pages = {
    { pageId = 'menu/main' }, { pageId = 'menu/main' },
} }), 'invalid_input', 'duplicate navigation page')

Invalid(MenuValidation.Menu({ key = 'menu', dragable = true }, 'spec', true), 'invalid_input', 'unknown menu field')
Invalid(MenuValidation.Menu({ key = 'menu', theme = { background = 'url(https://example.com)' } }, 'spec', true), 'invalid_input', 'CSS asset injection')
for _,font in ipairs({'rdr','RDRLino','RDRGothica','RDRCatalogueBold','HapnaSlabSerif','Redemption','WWI','Cherolina','AncientAd'}) do
    Valid(MenuValidation.Menu({key='font-menu',theme={fontFamily=font}},'spec',true),'bundled font '..font)
end
Invalid(MenuValidation.Menu({key='font-menu',theme={fontFamily='url(https://example.com/font.ttf)'}},'spec',true),'invalid_input','remote font rejected')
Valid(MenuValidation.Menu({ key = 'menu', size = { width = '32rem', breakpoints = { ['720'] = '25rem' } }, theme = { background = 'rgba(22, 17, 14, .96)' } }, 'spec', true), 'bounded style tokens')
Invalid(MenuValidation.Element('imagebox', { key = 'image', image = 'https://example.com/image.png' }), 'invalid_input', 'remote image rejected')
Valid(MenuValidation.Element('imagebox', { key = 'image', image = 'https://cfx-nui-my-resource/images/icon.png' }), 'local Cfx image')
Valid(MenuValidation.Element('imagebox', { key = 'image-sized', image = 'images/icon.png', width = '12rem', height = '8rem', aspectRatio = '3/2', objectFit = 'cover' }), 'bounded image sizing')
Invalid(MenuValidation.Element('imagebox', { key = 'image-css', image = 'images/icon.png', width = 'calc(100% - 1rem)' }), 'invalid_input', 'arbitrary image sizing rejected')
Invalid(MenuValidation.Element('imagebox', { key = 'image-fit', image = 'images/icon.png', objectFit = 'initial' }), 'invalid_input', 'unknown image fit rejected')
Valid(MenuValidation.Element('imageboxcontainer', { key = 'image-grid', items = {
    { value = 'one', image = 'images/one.png', width = '96px', height = '72px', objectFit = 'contain' },
} }), 'image child sizing')
Valid(MenuValidation.Element('dropdown', { key = 'bool', value = false, options = { { value = false, label = 'No' }, { value = true, label = 'Yes' } } }), 'false option values')
Invalid(MenuValidation.Element('dropdown', { key = 'duplicates', value = 1, options = { 1, 1.0 } }), 'invalid_input', 'integer and float representations are the same choice')
Invalid(MenuValidation.Element('textarea', { key = 'bio', value = 'too long', maxLength = 3 }), 'invalid_input', 'text length enforced')
Invalid(MenuValidation.Element('textarea', { key = 'bio', rows = 0 }), 'invalid_input', 'textarea rows enforced')
local options = { key = 'choice', value = 'a', options = { 'a', 'b', 'c' } }
local replacement = MenuValidation.Copy(options)
MenuValidation.Merge(replacement, { options = { 'a' } })
Pass(#replacement.options == 1 and #options.options == 3, 'array replacement and defensive copy')
Invalid(MenuValidation.ElementAction({ type = 'toggle', data = { key = 'toggle', value = false, persist = false } }, { event = 'change', value = 'bad' }), 'invalid_input', 'non-persisted callback validation')
Invalid(MenuValidation.ElementAction({ type = 'dropdown', data = { key = 'choice', value = 'a', options = { 'a', { value = 'b', disabled = true } } } }, { event = 'change', value = 'b' }), 'invalid_input', 'disabled selection validation')
Invalid(MenuValidation.ElementAction({ type = 'pagearrows', data = { key = 'pages', current = 1, total = 2 } }, { event = 'previous', value = -1 }), 'invalid_input', 'page boundary validation')
Invalid(MenuValidation.OpenOptions({ keyboard = 'yes' }), 'invalid_input', 'focus flags are boolean')
Invalid(MenuValidation.FocusOptions({ keyboard = 'yes' }), 'invalid_input', 'runtime focus flags are boolean')
Invalid(MenuValidation.FocusOptions({ invented = true }), 'invalid_input', 'runtime focus rejects unknown fields')
Invalid(MenuValidation.Sound({ action = '', soundset = 'HUD' }, 'sound'), 'invalid_input', 'empty sound identifier')
Valid(MenuValidation.Element('accordion', { key='horse', label='Morgan', value=false, labelAlign='center', notify=true }), 'centered notifying section')
Invalid(MenuValidation.Element('accordion', { key='horse', label='Morgan', labelAlign='right' }), 'invalid_input', 'bounded alignment')
Invalid(MenuValidation.Element('accordion', { key='horse', label='Morgan', notify='yes' }), 'invalid_input', 'notify boolean')
Valid(MenuValidation.ElementAction({type='accordion',data={key='horse',label='Morgan',value=false,notify=true}}, {event='change',value=true}), 'accordion change callback')
Valid(MenuValidation.Element('button',{key='save',busy=true,busyLabel='Saving',confirm={title='Delete?',message='Cannot undo',confirmLabel='Delete',cancelLabel='Cancel'}}), 'busy and confirmation options')
Invalid(MenuValidation.Element('button',{key='save',busy='yes'}),'invalid_input','busy boolean')
Invalid(MenuValidation.Element('button',{key='save',confirm={title='Delete?'}}),'invalid_input','confirmation requires localized labels')
Valid(MenuValidation.Element('input',{key='name',value='',error='Enter a valid name.'}), 'inline error')
Valid(MenuValidation.Element('accordion',{key='horse',label='Jerry',selected=true}), 'selected markers')
Invalid(MenuValidation.Element('accordion',{key='horse',label='Jerry',selected='yes'}),'invalid_input','selection boolean')
-- The Cfx runtime supplies json.encode. This probe verifies the byte gate itself.
json = { encode = function() return string.rep('x', 65537) end }
Invalid(MenuValidation.Bytes({ key = 'oversized' }, 'payload'), 'invalid_input', 'encoded byte budget')
json = nil
print(('PASS validation suite %d assertions'):format(passed))
