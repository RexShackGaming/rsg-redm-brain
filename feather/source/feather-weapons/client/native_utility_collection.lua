-- Parent-facing composite. Every child still captures/removes its own exact GUID.
WeaponNativeUtilityCollection={}
function WeaponNativeUtilityCollection.New(factory,ped,bound,sealed)
    local phase,children,attempted='idle',{},false
    local T={}
    function T.Create(approval)
        if attempted then return nil,'utility_creation_already_attempted' end
        local checked,why=WeaponNativeUtilityItem.ValidateCollection(approval,WeaponDefinitionCatalog,bound)
        if not checked then return nil,why end
        attempted=true; phase='creating'
        for _,entry in ipairs(checked.items) do
            local def=WeaponDefinitionCatalog.weapons[entry.row.metadata.weaponDefinitionId]
            local ok,child=pcall(factory,ped,bound,sealed,def)
            if not ok or type(child)~='table' or type(child.Create)~='function'
                or type(child.Release)~='function' or type(child.Status)~='function' then
                phase='retained'; return nil,'utility_factory_unconfirmed'
            end
            children[#children+1]=child
            local made,result=pcall(child.Create,entry)
            if not made or result~=true then phase='retained'; return nil,'utility_creation_unconfirmed' end
        end
        phase='active'; return true
    end
    function T.Release()
        if phase=='released' then return true end
        if phase~='active' then return nil,'utility_cleanup_unconfirmed' end
        phase='releasing'
        for i=#children,1,-1 do
            local ok,result=pcall(children[i].Release)
            local read,status=pcall(children[i].Status)
            if not ok or result~=true or not read or type(status)~='table' or status.phase~='released' then
                phase='retained'; return nil,'utility_cleanup_unconfirmed'
            end
        end
        phase='released'; return true
    end
    function T.Status()
        local entries={}
        for _,child in ipairs(children) do
            local ok,status=pcall(child.Status)
            entries[#entries+1]=ok and status or {phase='unconfirmed'}
        end
        return {phase=phase,items=entries}
    end
    return T
end
