-- Lets existing scripts keep calling exports.ox_target:<fn>() while rsg-target is running.
-- Remove/stop the original ox_target resource when using rsg-target.
local api = require 'client.api'

for name, func in pairs(api) do
    if type(func) == 'function' then
        AddEventHandler(('__cfx_export_ox_target_%s'):format(name), function(setCB)
            setCB(func)
        end)
    end
end
