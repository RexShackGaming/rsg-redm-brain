-- Replies only with actual exact-owned readback. No native mutation or SQL.
RegisterNetEvent('feather-weapons:client:native-maintenance-read',function(ticket,identity,itemId)
    if Config.NativeAlphaRuntime~=true or Config.NativeAlphaMaintenanceEnabled~=true
        or type(ticket)~='string' or #ticket<1 or #ticket>128 or type(identity)~='table'
        or type(itemId)~='number' or itemId<1 or itemId%1~=0 or itemId==math.huge then return end
    local owner=WeaponCharacterAmmoActiveOwner
    if not owner or type(owner.MaintenanceStatus)~='function' then return end
    local status=owner.Status()
    local runtime=status and status.bootstrap and status.bootstrap.runtime
    local baseline=runtime and runtime.session and runtime.session.ammo and runtime.session.ammo.baseline
    if not baseline or baseline.characterId~=identity.characterId or baseline.sessionId~=identity.sessionId
        or baseline.epoch~=identity.epoch then return end
    local called,read=pcall(owner.MaintenanceStatus)
    if not called or not read or read.epoch~=identity.epoch then return end
    for _,item in ipairs(read.items) do
        if item.itemInstanceId==itemId then
            TriggerServerEvent('feather-weapons:server:native-maintenance-report',ticket,read.epoch,itemId,item.itemRevision,item.maintenance)
            return
        end
    end
end)
