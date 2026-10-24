lib.locale()

-- Intentionally loads before the detector, so the report command survives a
-- detector initialization failure. No inventory, permissions, or scoring changes.
TargetPractiseDiagnostics = {
    codeVersion = GetResourceMetadata(GetCurrentResourceName(), 'version', 0), counts = {}, errors = {},
    stage = 'not-started', server = nil, captureId = 0
}
local D = TargetPractiseDiagnostics

local function translated(key)
    if type(locale) == 'function' then
        local ok, text = pcall(locale, key)
        if ok then return text end
    end
    return key -- A broken locale loader must not disable technical diagnostics.
end

function D.count(key)
    D.counts[key] = (D.counts[key] or 0) + 1
end

function D.tick(stage)
    D.stage, D.lastTick = stage, GetGameTimer()
    D.count('loop_ticks')
end

function D.recordError(name, message)
    D.errors[name] = tostring(message)
    print(('[rsg-targetpractise] %s ERROR: %s'):format(name, tostring(message)))
    if lib and type(lib.notify) == 'function' then
        lib.notify({
            title = translated('notify_title'), description = translated('diag_detector_error'),
            type = 'error', duration = 7000
        })
    end
end

function D.report()
    local lines = {
        'client_code=' .. D.codeVersion,
        'detector_code=' .. tostring(D.detectorVersion or 'not reported; check client.lua'),
        'mixed_client_files=' .. (D.detectorVersion and tostring(D.detectorVersion ~= D.codeVersion) or 'unknown'),
        'resource=' .. GetCurrentResourceName(),
        'resource_version=' .. tostring(GetResourceMetadata(GetCurrentResourceName(), 'version', 0)),
        'main_ready=' .. tostring(D.mainReady == true),
        'projectile_module=' .. tostring(type(TargetPractiseProjectiles) == 'table'),
        'stage=' .. D.stage,
        'last_tick_ms_ago=' .. (D.lastTick and tostring(GetGameTimer() - D.lastTick) or 'never'),
        'server=' .. (D.server and tostring(D.server.code) or 'no diagnostic response'),
    }
    if D.server then
        lines[#lines + 1] = 'server_score_mode=' .. tostring(D.server.mode or 'not reported')
        lines[#lines + 1] = ('server_version=%s active_targets=%s bucket=%s storage_ok=%s'):format(
            tostring(D.server.version), tostring(D.server.targets), tostring(D.server.bucket), tostring(D.server.storage))
    end
    if D.provider then
        local ok, result = pcall(D.provider)
        if ok then
            for _, line in ipairs(result) do lines[#lines + 1] = line end
        else
            lines[#lines + 1] = 'snapshot_error=' .. tostring(result)
        end
    end
    local known = {
        loop_ticks = true, idle_ticks = true, weapon_samples = true,
        release_events = true, owned_knives_found = true, knives_tracked = true,
        flight_collisions = true, hits_submitted = true, scores_accepted = true,
        confirmed_face_hits = true, frame_collisions = true, face_probe_misses = true,
        projectile_probe_skips = true, bullseyes = true,
        server_rejections = true
    }
    for key in pairs(D.counts) do known[key] = true end
    local keys = {}
    for key in pairs(known) do keys[#keys + 1] = key end
    table.sort(keys)
    for _, key in ipairs(keys) do lines[#lines + 1] = key .. '=' .. (D.counts[key] or 0) end
    lines[#lines + 1] = 'last_result=' .. tostring(D.lastResult or 'none')
    if D.lastProjectile then lines[#lines + 1] = 'projectile_native=' .. D.lastProjectile end
    lines[#lines + 1] = 'last_probe=' .. tostring(D.lastProbe or 'none')
    for name, message in pairs(D.errors) do
        lines[#lines + 1] = 'ERROR ' .. name .. '=' .. message:sub(1, 1400)
    end
    return table.concat(lines, '\n')
end

function D.show()
    local report = D.report()
    print('[rsg-targetpractise] DETECTION REPORT\n' .. report)
    if lib and type(lib.alertDialog) == 'function' then
        lib.alertDialog({
            header = translated('diag_title'),
            content = translated('diag_intro') .. '\n\n```\n' .. report:gsub('`', "'") .. '\n```',
            centered = true, size = 'lg', cancel = false,
            labels = { confirm = translated('diag_close') }
        })
    end
end

RegisterNetEvent('rsg-targetpractise:client:diagnosticServer', function(data)
    if type(data) == 'table' then D.server = data end
end)

RegisterCommand('targetdiag', function(_, args)
    args = args or {}
    if args[1] == 'report' then D.show() return end
    D.captureId = D.captureId + 1
    if args[1] == 'off' then
        if D.enable then D.enable(false) end
        if lib and type(lib.notify) == 'function' then
            lib.notify({ title = translated('notify_title'), description = translated('diag_stopped'), type = 'inform', duration = 5000 })
        end
        return
    end
    local capture = D.captureId
    D.counts, D.server = {}, nil
    D.lastResult, D.lastProjectile = nil, nil
    D.lastProbe = nil
    if D.enable then D.enable(true) end
    TriggerServerEvent('rsg-targetpractise:server:diagnostic')
    print('[rsg-targetpractise] Diagnostic capture started; client code ' .. D.codeVersion)
    if lib and type(lib.notify) == 'function' then
        lib.notify({ title = translated('notify_title'), description = translated('diag_started'), type = 'inform', duration = 7000 })
    end
    SetTimeout(10000, function() if D.captureId == capture then D.show() end end)
end, false)

print('[rsg-targetpractise] Client diagnostics loaded: code ' .. D.codeVersion .. ' (/targetdiag)')
