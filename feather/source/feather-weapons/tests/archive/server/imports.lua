FeatherCore = {}
FeatherCore.RPC = {
    Register = function(name, callback, options)
        return exports["feather-core"]:RegisterRPC(name, function(params,respond,source,context)
            if Config.CharacterAmmunitionEnabled==true or Config.CharacterAmmoTransportEnabled==true then
                respond({ok=false,error={code='hybrid_runtime_disabled',message='Native cutover is not active.'}})
                return
            end
            return callback(params,respond,source,context)
        end, options)
    end
}
