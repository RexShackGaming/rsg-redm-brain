local resourceName = GetCurrentResourceName()

local function Owner()
    local owner = GetInvokingResource()
    if type(owner) ~= 'string' or owner == '' then
        return nil
    end

    return owner
end

local function Capabilities()
    return ToolkitResults.Ok({
        resource = resourceName,
        contract = 1,
        version = GetResourceMetadata(resourceName, 'version', 0) or '0.0.0',
        features = { models = 1, animations = 1, entities = 1, blips = 1, keys = 1, controls = 1, prompts = 1, render = 1, clipboard = 1, progress = 1 }
    })
end

exports('GetCapabilities', Capabilities)

exports('LoadModel', ToolkitModels.Load)

exports('LoadAnimDict', ToolkitAnimations.LoadDictionary)

exports('CreateObject', function(spec)
    local o = Owner()
    return o and ToolkitEntities.CreateObject(o, spec) or
        ToolkitResults.Err('unauthenticated', 'Calling resource is required.')
end)

exports('CreatePed', function(spec)
    local o = Owner()
    return o and ToolkitEntities.CreatePed(o, spec) or
        ToolkitResults.Err('unauthenticated', 'Calling resource is required.')
end)

exports('RemoveEntity', function(id)
    local o = Owner()
    return o and ToolkitEntities.Remove(o, id) or
        ToolkitResults.Err('unauthenticated', 'Calling resource is required.')
end)

exports('CreateBlip', function(spec)
    local o = Owner()
    return o and ToolkitBlips.Create(o, spec) or
        ToolkitResults.Err('unauthenticated', 'Calling resource is required.')
end)

exports('RemoveBlip', function(id)
    local o = Owner()
    return o and ToolkitBlips.Remove(o, id) or
        ToolkitResults.Err('unauthenticated', 'Calling resource is required.')
end)

exports('RegisterKeyListener', function(control, cb, mode)
    local o = Owner()
    return o and ToolkitKeys.Register(o, control, cb, mode) or
        ToolkitResults.Err('unauthenticated', 'Calling resource is required.')
end)

exports('RemoveKeyListener', function(id)
    local o = Owner()
    return o and ToolkitKeys.Remove(o, id) or
        ToolkitResults.Err('unauthenticated', 'Calling resource is required.')
end)

exports('ResolveControl', ToolkitControls.Resolve)

exports('CreatePrompt', function(spec)
    local o = Owner()
    return o and ToolkitPrompts.Create(o, spec) or
        ToolkitResults.Err('unauthenticated', 'Calling resource is required.')
end)

exports('IsPromptCompleted', function(id)
    local o = Owner()
    return o and ToolkitPrompts.Completed(o, id) or
        ToolkitResults.Err('unauthenticated', 'Calling resource is required.')
end)

exports('SetPromptEnabled', function(id, v)
    local o = Owner()
    return o and ToolkitPrompts.SetEnabled(o, id, v) or
        ToolkitResults.Err('unauthenticated', 'Calling resource is required.')
end)

exports('RemovePrompt', function(id)
    local o = Owner()
    return o and ToolkitPrompts.Remove(o, id) or
        ToolkitResults.Err('unauthenticated', 'Calling resource is required.')
end)

exports('DrawText2D', ToolkitRender.Text2D)

exports('DrawText3D', ToolkitRender.Text3D)

exports('CopyToClipboard', ToolkitClipboard.Copy)

exports('StartProgress', function(spec, callback)
    local o = Owner()
    return o and ToolkitProgress.Start(o, spec, callback) or
        ToolkitResults.Err('unauthenticated', 'Calling resource is required.')
end)

exports('GetProgress', function(id)
    local o = Owner()
    return o and ToolkitProgress.Get(o, id) or
        ToolkitResults.Err('unauthenticated', 'Calling resource is required.')
end)

exports('CancelProgress', function(id)
    local o = Owner()
    return o and ToolkitProgress.Cancel(o, id) or
        ToolkitResults.Err('unauthenticated', 'Calling resource is required.')
end)

AddEventHandler('onResourceStop', function(owner)
    if owner == resourceName then
        ToolkitEntities.CleanupAll(); ToolkitBlips.CleanupAll(); ToolkitKeys.CleanupAll(); ToolkitPrompts.CleanupAll(); ToolkitProgress.CleanupAll()
        return
    end

    ToolkitEntities.Cleanup(owner)
    ToolkitBlips.Cleanup(owner)
    ToolkitKeys.Cleanup(owner)
    ToolkitPrompts.Cleanup(owner)
    ToolkitProgress.Cleanup(owner)
end)

RegisterCommand('ToolkitContractSmokeTest', function()
    local caps = Capabilities()
    local invalid = ToolkitModels.Load(nil)
    local namedControl = ToolkitControls.Resolve('PGDN')
    local owned = ToolkitKeys.Register('smoke-owner', 0x760A9C6F, function() end)
    local cross = owned.ok and ToolkitKeys.Remove('other-owner', owned.value.id) or nil
    local cleaned = ToolkitKeys.Cleanup('smoke-owner')
    local invalidDictionary = ToolkitAnimations.LoadDictionary('')
    local invalidProgress = ToolkitProgress.Validate({ message = '', durationMs = 0 })
    local prompt = ToolkitPrompts.Create('smoke-owner', {
        control = 0x760A9C6F,
        label = 'Toolkit smoke prompt',
        enabled = false,
        visible = false
    })
    local promptDisabled = prompt.ok and ToolkitPrompts.SetEnabled(
        'smoke-owner', prompt.value.id, false) or nil
    local promptRemoved = prompt.ok and ToolkitPrompts.Remove(
        'smoke-owner', prompt.value.id) or nil
    local tests = {
        { 'capabilities', caps.ok and caps.value.contract == 1 },
        { 'feature surface', caps.ok and caps.value.features.prompts == 1 and caps.value.features.clipboard == 1 and
            caps.value.features.controls == 1 and caps.value.features.animations == 1 and caps.value.features.progress == 1 },
        { 'named control resolved', namedControl.ok and type(namedControl.value) == 'number' },
        { 'invalid model rejected', not invalid.ok and invalid.code == 'invalid_input' },
        { 'invalid anim rejected', not invalidDictionary.ok and invalidDictionary.code == 'invalid_input' },
        { 'invalid progress rejected', not invalidProgress.ok and invalidProgress.code == 'invalid_input' },
        { 'prompt created', prompt.ok },
        { 'prompt disabled', promptDisabled and promptDisabled.ok and promptDisabled.value.enabled == false },
        { 'prompt removed', promptRemoved and promptRemoved.ok },
        { 'cross owner denied', cross and not cross.ok and cross.code == 'forbidden' },
        { 'owner cleanup', cleaned == 1 } }
    local passed = 0
    for _, t in ipairs(tests) do
        if t[2] then
            passed = passed + 1
        end
        print(('[ToolkitContractSmokeTest] %-24s %s'):format(t[1], t[2] and 'PASS' or 'FAIL'))
    end

    print(('[ToolkitContractSmokeTest] done %d/%d passed'):format(passed, #tests))
end, false)

RegisterCommand('ToolkitProgressSmokeTest', function()
    local first = ToolkitProgress.Start('toolkit-smoke', {
        message = 'Toolkit progress one', durationMs = 1200, theme = 'linear'
    }, function(result)
        print(('[ToolkitProgressSmokeTest] first outcome=%s'):format(
            tostring(result.ok and result.value.outcome or result.code)))
    end)

    local second = ToolkitProgress.Start('toolkit-smoke', {
        message = 'Toolkit progress two', durationMs = 1200, theme = 'innercircle', color = '#b68a52'
    }, function(result)
        print(('[ToolkitProgressSmokeTest] second outcome=%s'):format(
            tostring(result.ok and result.value.outcome or result.code)))
    end)

    print(('[ToolkitProgressSmokeTest] dispatch %s first=%s second=%s queued=%s'):format(
        first.ok and second.ok and 'PASS' or 'FAIL',
        tostring(first.ok and first.value.id or first.code),
        tostring(second.ok and second.value.id or second.code),
        tostring(second.ok and second.value.state == 'queued')))
end, false)

RegisterCommand('ToolkitClipboardSmokeTest', function(_, args)
    local value = table.concat(args, ' ')
    if value == '' then
        value = 'Feather Toolkit clipboard test'
    end

    local result = ToolkitClipboard.Copy(value)
    print(('[ToolkitClipboardSmokeTest] dispatch %s -- copy and paste to verify'):format(result.ok and 'PASS' or 'FAIL'))
end, false)
