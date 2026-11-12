ShopCatalogSources = {}
local owners={}
local invalidated=false
AddEventHandler('onResourceStop',function(resource) if owners[resource] then invalidated=true end end)
function ShopCatalogSources.IsCurrent() return not invalidated end
function ShopCatalogSources.Load()
    if not Config.WeaponStoresEnabled then return {ok=true} end
    local deadline=GetGameTimer()+Config.ReadinessTimeoutMs
    local result
    repeat
        local called,value=pcall(function() return exports['feather-weapons']:GetGunStoreCatalog() end)
        result=called and value or nil
        if type(result)=='table' and (result.ok or result.code~='not_ready') then break end
        Wait(100)
    until GetGameTimer()>=deadline
    if type(result)~='table' or not result.ok or type(result.value)~='table'
        or result.value.contract~=1 or type(result.value.stores)~='table' then
        return {ok=false,code='dependency_unavailable',message='Weapons gun-store catalog unavailable; check Weapons shop_config.lua.',
            details={reason=type(result)=='table' and result.message or 'Required Weapons catalog export did not respond.'}}
    end
    for _,store in ipairs(result.value.stores) do Config.Shops[#Config.Shops+1]=store end
    owners['feather-weapons']=true
    return {ok=true}
end
function ShopCatalogSources.Owns(resource) return owners[resource]==true end
