-- Adds the theatre door locks to rsg_doorlocks the first time the resource starts.
-- Each door is only inserted if a row with the same name doesn't already exist.
local theatreDoors = {
    { name = 'Theatre Main Doors', locked = 0,
      doors = '[{"coords":{"x":2547.550048828125,"y":-1289.8310546875,"z":48.21599960327148},"hash":544106233},{"coords":{"x":2545.345947265625,"y":-1289.8310546875,"z":48.21599960327148},"hash":340151973}]',
      text  = '{"x":2546.447998046875,"y":-1289.8310546875,"z":49.21599960327148}' },
    { name = 'Theatre Side Door 1', locked = 1,
      doors = '[{"coords":{"x":2537.594970703125,"y":-1294.47802734375,"z":48.21599960327148},"hash":534819197},{"coords":{"x":2537.594970703125,"y":-1295.8360595703126,"z":48.21599960327148},"hash":836064614}]',
      text  = '{"x":2537.594970703125,"y":-1295.156982421875,"z":49.21599960327148}' },
    { name = 'Theatre Side Door 2', locked = 1,
      doors = '[{"coords":{"x":2537.594970703125,"y":-1299.5899658203126,"z":48.21599960327148},"hash":1449678065},{"coords":{"x":2537.594970703125,"y":-1298.2330322265626,"z":48.21599960327148},"hash":2053545201}]',
      text  = '{"x":2537.594970703125,"y":-1298.9114990234376,"z":49.21599960327148}' },
    { name = 'Theatre Side Door 3', locked = 1,
      doors = '[{"coords":{"x":2537.594970703125,"y":-1303.3360595703126,"z":48.21599960327148},"hash":627391959},{"coords":{"x":2537.594970703125,"y":-1301.97802734375,"z":48.21599960327148},"hash":3468071035}]',
      text  = '{"x":2537.594970703125,"y":-1302.656982421875,"z":49.21599960327148}' },
}

CreateThread(function()
    -- rsg-doorlock creates its table and imports its own seed doors in a thread on start,
    -- and skips that import if the table already has rows. Wait for it so we don't block it.
    local ok, count
    local timeout = GetGameTimer() + 15000
    repeat
        Wait(1000)
        ok, count = pcall(MySQL.scalar.await, 'SELECT COUNT(*) FROM rsg_doorlocks')
    until (ok and (count or 0) > 0) or GetGameTimer() > timeout
    if not ok then
        return print('^1[rsg-theatre]^7 rsg_doorlocks table not found, theatre door locks not added')
    end
    local added = 0
    for _, d in ipairs(theatreDoors) do
        local exists = MySQL.scalar.await('SELECT 1 FROM rsg_doorlocks WHERE name = ? LIMIT 1', { d.name })
        if not exists then
            MySQL.insert.await(
                'INSERT INTO rsg_doorlocks (name, doors, text_coords, jobs, distance, locked) VALUES (?, ?, ?, ?, ?, ?)',
                { d.name, d.doors, d.text, '[]', 1.25, d.locked }
            )
            added = added + 1
        end
    end
    if added > 0 then
        print(('^2[rsg-theatre]^7 added %d theatre door lock(s) to rsg_doorlocks - restart rsg-doorlock to load them'):format(added))
    end
end)
