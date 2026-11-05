FeatherCore = FeatherCore or {}
FeatherCore.RPC = {
    Call = function(name, params, callback, source, timeoutMs)
        return exports['feather-core']:CallRPC(name, params, callback, source, timeoutMs)
    end,
    CallAsync = function(name, params, source, timeoutMs)
        return exports['feather-core']:CallRPCAsync(name, params, source, timeoutMs)
    end
}
