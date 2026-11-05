FeatherCore = {}
FeatherCore.RPC = {
    Call = function(name, params, callback, source, timeoutMs)
        return exports["feather-core"]:CallRPC(name, params, callback, source, timeoutMs)
    end
}
