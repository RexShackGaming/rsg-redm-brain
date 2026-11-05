WeatherConfig = {
    -- Restart intentionally resets authority to these defaults. No persistence.
    clock = { mode = 'simulated', seconds = 21600, rate = 30, frozen = false, offsetSeconds = 0 },
    weather = { name = 'sunny', frozen = false, transitionSeconds = 15, snow = false },
    -- Weather interval is in simulation seconds, independent of clock freeze.
    weatherIntervalSeconds = 3600,
    forecastCount = 12,
    -- Ordered weighted choices; each row totals 100. Exceptional storms are opt-in.
    pattern = {
        sunny = { { name = 'sunny', weight = 60 }, { name = 'clouds', weight = 40 } },
        clouds = { { name = 'sunny', weight = 40 }, { name = 'clouds', weight = 30 }, { name = 'overcast', weight = 30 } },
        overcast = { { name = 'clouds', weight = 50 }, { name = 'rain', weight = 50 } },
        rain = { { name = 'overcast', weight = 60 }, { name = 'rain', weight = 40 } }
    },
    wind = { direction = 0, speed = 0 },
    windProgression = {
        enabled=true, frozen=false, intervalSeconds=60,
        degreesPerSecond=1.5, speedPerSecond=0.15,
        default={min=1,max=4},
        profiles={
            sunny={min=0,max=3}, highpressure={min=0,max=2}, clouds={min=1,max=5},
            rain={min=3,max=8}, thunderstorm={min=8,max=16}, hurricane={min=16,max=25},
            blizzard={min=8,max=16}, whiteout={min=12,max=22}, sandstorm={min=10,max=20}
        }
    },
    -- A simulation calendar, independent of the weekly clock anchor and clock freeze.
    -- Seven simulation days per season; restart resets to the configured season/day.
    seasons = {
        enabled=true, start='spring', day=1, daysPerSeason=7, frozen=false,
        patterns={
            spring={
                sunny={{name='clouds',weight=60},{name='sunny',weight=40}},
                clouds={{name='rain',weight=50},{name='overcast',weight=30},{name='sunny',weight=20}},
                overcast={{name='rain',weight=60},{name='clouds',weight=40}},
                rain={{name='clouds',weight=50},{name='rain',weight=50}}
            },
            summer={
                sunny={{name='sunny',weight=75},{name='clouds',weight=25}},
                clouds={{name='sunny',weight=65},{name='rain',weight=35}},
                rain={{name='clouds',weight=70},{name='rain',weight=30}}
            },
            autumn={
                sunny={{name='clouds',weight=70},{name='sunny',weight=30}},
                clouds={{name='overcast',weight=60},{name='rain',weight=40}},
                overcast={{name='rain',weight=50},{name='clouds',weight=50}},
                rain={{name='rain',weight=60},{name='clouds',weight=40}}
            },
            winter={
                clouds={{name='snowlight',weight=60},{name='overcast',weight=40}},
                overcast={{name='snow',weight=60},{name='clouds',weight=40}},
                snowlight={{name='snow',weight=40},{name='clouds',weight=60}},
                snow={{name='snowlight',weight=60},{name='overcast',weight=40}}
            }
        }
    },
    -- Regional presentation enabled by default after representative gameplay acceptance.
    -- Set enabled=false for global-only presentation.
    regions = {
        enabled = true,
        sampleIntervalMs = 1000,
        settleMs = 2000,
        transitionSeconds = 10,
        rules = {
            {
                id = 'grizzlies_snow', priority = 100, zoneType = 10,
                -- Preserve natural mountain coverage; only translate precipitation.
                zones = { 'GrizzliesWest' }, autoSnow = false,
                weather = { rain='snow', drizzle='snowlight', shower='snowlight',
                    thunderstorm='blizzard', hurricane='whiteout' }
            },
            {
                id = 'new_austin_dry', priority = 50, zoneType = 10,
                zones = { 'GaptoothRidge', 'ChollaSprings', 'RioBravo', 'HennigansStead' }, autoSnow = false,
                -- Preserve full desert thunderstorms; only soften ordinary rain.
                weather = { rain='drizzle', shower='drizzle',
                    hurricane='sandstorm', snow='overcast', snowlight='overcast',
                    blizzard='overcastdark', groundblizzard='overcastdark', whiteout='overcastdark', sleet='drizzle' }
            },
            {
                id = 'guarma_tropical', priority = 50, zoneType = 10,
                zones = { 'GuarmaD' }, autoSnow = false,
                weather = { snow='rain', snowlight='drizzle', blizzard='thunderstorm',
                    groundblizzard='rain', whiteout='thunderstorm', sleet='drizzle' }
            }
        }
    },
    syncIntervalMs = 5000,
    tickIntervalMs = 250,
    clientIntervalMs = 250,
    maxCatchUpSteps = 64,
    conflictResources = { 'weathersync' },
    -- Server exports may mutate only for explicitly allowed invoking resources.
    trustedResources = { ['feather-admin']=true },
    -- Character owns only local selection/creation presentation, never shared state.
    -- Admit other scene consumers explicitly; development test owners are not enabled here.
    overrideOwners = { ['feather-character'] = { maxPriority = 10 } },
    maxOverrides = 16,
    maxOverrideSeconds = 1800
}
