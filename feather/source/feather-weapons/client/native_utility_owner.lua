-- Inert injected owner. No native adapter, route, thread or automatic admission.
WeaponNativeUtilityOwner={}
local function copy(v) if type(v)~='table' then return v end; local r={}; for k,x in pairs(v) do r[k]=copy(x) end; return r end
local function guid(v) return type(v)=='string' and #v==32 and v:match('^[%da-fA-F]+$')~=nil end
function WeaponNativeUtilityOwner.New(api,def,identity)
    for _,k in ipairs({'current','present','create','capture','sealed','removeCaptured','absent'}) do
        assert(type(api)=='table' and type(api[k])=='function','Local utility adapter required: '..k)
    end
    local profile=WeaponNativeUtilityCatalog.Resolve(def)
    if not profile then return nil,'unsupported_native_utility_definition' end
    def,identity=copy(def),copy(identity)
    local phase,reason,approval,handle='idle',nil,nil,nil
    local function call(name,...)
        local ok,v=pcall(api[name],...); return ok and v or nil
    end
    local function live() return call('current',copy(identity))==true end
    local function retained(why) phase='retained'; reason=why; return nil,why end
    local T={}
    function T.Status()
        return {phase=phase,reason=reason,identity=copy(identity),itemId=approval and approval.row.id,
            itemRevision=approval and approval.row.revision,guidOwnershipCaptured=handle~=nil}
    end
    function T.Create(candidate)
        if phase~='idle' then return nil,'utility_creation_already_attempted' end
        local bound,why=WeaponNativeUtilityItem.ValidateApproval(candidate,def,identity)
        if not bound then return nil,why end
        if not live() then return nil,'utility_world_changed' end
        phase='preflight'; approval=bound
        -- pcall separately: false is positive absence, nil/throw is uncertainty.
        local ok,present=pcall(api.present,copy(profile),copy(identity))
        if not ok or present~=false or not live() then return retained('utility_preexisting_or_unconfirmed') end
        phase='creating'
        if call('create',copy(profile),copy(identity))~=true or not live() then return retained('utility_creation_unconfirmed') end
        local captured=call('capture',copy(profile),copy(approval))
        if type(captured)~='table' or not guid(captured.guid) or not live() then return retained('utility_guid_capture_unconfirmed') end
        handle=copy(captured); phase='active'; return true
    end
    function T.Release()
        if phase=='released' then return true end
        if phase~='active' or not handle then return nil,'utility_exact_cleanup_unavailable' end
        phase='releasing'
        if not live() or call('sealed',copy(approval))~=true or not live() then return retained('utility_cleanup_not_sealed') end
        -- Concrete adapter must resolve/remove only this captured inventory GUID.
        -- No model-wide fallback or speculative second removal after failure.
        if call('removeCaptured',copy(handle),copy(approval))~=true or not live() then
            return retained('utility_cleanup_unconfirmed')
        end
        if call('absent',copy(handle),copy(approval))~=true or not live() then return retained('utility_cleanup_absence_unconfirmed') end
        phase='released'; return true
    end
    return T
end
