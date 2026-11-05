local function help()
    print('[Feather Versions] feather versions | feather versions check | feather versions <resource> | feather versions help')
end

RegisterCommand('feather', function(source, args)
    if source ~= 0 then return end
    if args[1] ~= 'versions' then return end
    local action = args[2]
    if not action then VersionerReporter.Print(VersionerRegistry.entries); return end
    if action == 'help' then help(); return end
    if action == 'check' then
        local started = VersionerScheduler.Manual(function() VersionerReporter.Print(VersionerRegistry.entries) end)
        if not started.ok then print(('[Feather Versions] refresh rejected: %s (%s)'):format(started.message, started.code)) end
        return
    end
    VersionerReporter.Print(VersionerRegistry.entries, action)
end, true)
