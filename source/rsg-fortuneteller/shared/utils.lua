lib.locale()

Fortune = {}

--- Total length of a reading in seconds. Server and client use the same timeline.
function Fortune.TotalSeconds(sequence)
    local t = Config.StartDelayMs / 1000.0
    if Config.Handover.enabled then t = t + Config.Handover.durationMs / 1000.0 end
    for i, line in ipairs(sequence) do
        t = t + line.duration + Config.SpeechPaddingSeconds
        if i < #sequence then t = t + Config.PauseBetweenLines end
    end
    return t
end

--- Stable key for an unconfigured world prop, built from its rounded position.
function Fortune.WorldKey(x, y, z)
    return ('world:%d:%d:%d'):format(math.floor(x + 0.5), math.floor(y + 0.5), math.floor(z + 0.5))
end
