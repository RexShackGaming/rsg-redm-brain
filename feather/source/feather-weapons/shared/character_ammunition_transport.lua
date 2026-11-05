-- Factory only: owner chooses namespace and explicitly installs enabled routes.
-- No baseline/open endpoint. Transfers require an already active runtime.
WeaponCharacterAmmoTransport={}
local function valid(kind,id,report)
    if kind~='restore' and kind~='observe' and kind~='seal' and kind~='cleanup' and kind~='transfer' and kind~='pickup' then return false end
    if kind=='pickup' and type(report)=='table' and (report.transfer~=nil or report.nativePickupPlan~=nil) then return false end
    if type(report)=='table' and report.deathWear~=nil then
        if kind~='seal' or not WeaponCharacterLifecycleWear.DeathReport(report.deathWear) then return false end
    end
    if kind=='transfer' then
        local spec=type(report)=='table' and report.transfer
        if type(spec)~='table' or type(spec.ammunitionId)~='string' or #spec.ammunitionId<1 or #spec.ammunitionId>128
            or type(spec.operationId)~='string' or #spec.operationId<1 or #spec.operationId>64
            or type(spec.amount)~='number' or spec.amount==0 or spec.amount%1~=0 or math.abs(spec.amount)>1000 then return false end
    end
    if kind=='cleanup' and (type(report)~='table' or report.cleanupComplete~=true or report.remainingCopies~=0) then return false end
    if type(id)~='number' or id<1 or id%1~=0 or id>2147483647 or type(report)~='table' then return false end
    for _,field in ipairs({'characterId','sessionId','epoch'}) do
        if type(report[field])~='string' or #report[field]<1 or #report[field]>128 then return false end
    end
    if type(report.revision)~='number' or report.revision<0 or report.revision%1~=0 or report.revision==math.huge
        or type(report.pools)~='table' then return false end
    local count=0
    for ammo,amount in pairs(report.pools) do
        count=count+1
        if count>64 or type(ammo)~='string' or #ammo>128 or type(amount)~='number'
            or amount<0 or amount%1~=0 or amount==math.huge then return false end
    end
    return count>0
end
function WeaponCharacterAmmoTransport.Server(api)
    local methods={restore='ConfirmRestore',observe='Observe',seal='CheckpointAndSeal',cleanup='ConfirmCleanup',transfer='Transfer',pickup='NativePickup'}
    api.register(function(source,kind,id,report)
        if api.enabled()~=true or not valid(kind,id,report) then return end
        local epoch=report.epoch
        local ok,result=pcall(api.service[methods[kind]],source,report)
        if not ok or type(result)~='table' then result={ok=false,error={code='runtime_request_failed'}} end
        api.reply(source,id,epoch,result)
    end)
end
function WeaponCharacterAmmoTransport.Client(api)
    local pending={}; local closed=false; local T={}
    api.register(function(id,epoch,result)
        if type(epoch)~='string' or type(id)~='number' then return end
        local key=epoch..':'..id; local request=pending[key]
        if not request then return end
        pending[key]=nil; request.callback(result)
    end)
    function T.Send(kind,id,report,callback)
        -- Closure is terminal for this resource-owned transport instance. A
        -- yielded owner must not send a new mutation after lifecycle shutdown.
        if closed then
            callback({ok=false,error={code='transport_closed'}})
            return
        end
        assert(valid(kind,id,report),'invalid ammo transport report')
        local key=report.epoch..':'..id
        assert(not pending[key],'duplicate ammo transport request')
        local request={callback=callback}; pending[key]=request
        local ok=pcall(api.send,kind,id,report)
        if not ok then pending[key]=nil; callback({ok=false,error={code='transport_unavailable'}}); return end
        api.timeout(function()
            if pending[key]~=request then return end
            pending[key]=nil; callback({ok=false,error={code='runtime_request_timeout'}})
        end)
    end
    function T.Close() closed=true; pending={} end -- never replay a lost/ambiguous mutation
    return T
end
