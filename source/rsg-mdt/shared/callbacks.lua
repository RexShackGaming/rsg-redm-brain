-- rsg-core callback bridge (replaces ox_lib lib.callback.register).
-- Handlers keep the ox_lib style of returning values; the bridge passes them to cb().
local RSGCore = exports['rsg-core']:GetCoreObject()

if IsDuplicityVersion() then
    function RegisterCallback(name, handler)
        RSGCore.Functions.CreateCallback(name, function(source, cb, ...)
            cb(handler(source, ...))
        end)
    end
else
    function RegisterClientCallback(name, handler)
        RSGCore.Functions.CreateClientCallback(name, function(cb, ...)
            cb(handler(...))
        end)
    end
end
