-- Prices are owned by Weapons; money and delivery remain owned by Shops/Inventory.
WeaponGunStore = {}
local function Error(message) return {ok=false,code='invalid_config',message=message} end
local function Integer(n,lo,hi) return type(n)=='number' and n%1==0 and n>=lo and n<=hi end
local function Copy(v)
    if type(v)~='table' then return v end
    local out={};for k,x in pairs(v) do out[k]=Copy(x) end;return out
end
local function Price(n)
    if type(n)~='number' or n~=n or n<=0 or n>1000000 then return nil end
    local cents=math.floor(n*100+0.5)
    if math.abs(n*100-cents)>0.000001 then return nil end
    return cents
end
local function OfferId(shop,item)
    local parts={}
    for seed=1,4 do
        local hash=(2166136261 ~ seed)&0xffffffff
        for i=1,#(shop..':'..item) do hash=((hash ~ (shop..':'..item):byte(i))*16777619)&0xffffffff end
        parts[seed]=('%08x'):format(hash)
    end
    local h=table.concat(parts)
    return h:sub(1,8)..'-'..h:sub(9,12)..'-4'..h:sub(14,16)..'-8'..h:sub(18,20)..'-'..h:sub(21,32)
end
function WeaponGunStore.Build(config,definitions)
    if type(config)~='table' or type(config.enabled)~='boolean' then return Error('Gun store configuration required.') end
    if not config.enabled then return {ok=true,value={contract=1,stores={}}} end
    if config.currency~='dollars' or not Integer(config.maximumBoxes,1,100)
        or type(config.stores)~='table' or #config.stores>20 then return Error('Gun store currency, quantity or locations invalid.') end
    local entries={}
    for _,group in ipairs({'weapons','ammunition','attachments'}) do
        if type(config[group])~='table' then return Error('Missing gun store price group: '..group) end
        for key in pairs(config[group]) do
            if not definitions[group][key] then return Error('Unknown gun store price key: '..tostring(key)) end
        end
        for key,definition in pairs(definitions[group]) do
            local setting=config[group][key]
            if setting==nil then return Error('Missing gun store price: '..key) end
            if setting~=false and not (group=='ammunition' and type(setting)=='table' and setting.price==false) then
                local price,size,category
                if group=='ammunition' then
                    if type(setting)~='table' then return Error('Ammo requires price and rounds: '..key) end
                    price=Price(setting.price);size=setting.rounds;category='ammunition'
                else
                    price=Price(setting);size=1
                    category=group=='attachments' and 'attachments' or definition.family
                    local firearm={pistol=true,revolver=true,repeater=true,rifle=true,shotgun=true}
                    if group=='weapons' and (not firearm[definition.family]
                        or (definition.slot~='sidearm' and definition.slot~='longgun')) then
                        return Error('No canonical shop issuance for weapon: '..key)
                    end
                end
                if not price or not Integer(size,1,100) then return Error('Invalid gun store price or pack size: '..key) end
                if group=='ammunition' then
                    for field in pairs(setting) do
                        if field~='price' and field~='rounds' then return Error('Unknown ammunition offer field: '..tostring(field)) end
                    end
                end
                entries[#entries+1]={itemName=definition.itemName,label=definition.label,
                    category=category,unitPrice=price,packSize=size,
                    maximumQuantity=group=='ammunition' and math.min(config.maximumBoxes,math.floor(100/size))
                        or (group=='weapons' and 1 or 10)}
            end
        end
    end
    if config.gunOil~=false then
        local price=Price(config.gunOil)
        if not price then return Error('Invalid gun oil price.') end
        entries[#entries+1]={itemName='gun_oil',label='Gun Oil',category='maintenance',unitPrice=price,packSize=1,maximumQuantity=10}
    end
    table.sort(entries,function(a,b) return a.itemName<b.itemName end)
    local stores,seen={},{ }
    for _,location in ipairs(config.stores) do
        if type(location)~='table' or type(location.id)~='string' then return Error('Invalid gun store location.') end
        local store=Copy(location);store.offers={};store.catalogResource='feather-weapons'
        for _,entry in ipairs(entries) do
            local offer=Copy(entry);offer.id=OfferId(store.id,entry.itemName);offer.currency=config.currency
            if seen[offer.id] then return Error('Duplicate gun store offer identity.') end
            seen[offer.id]=true;store.offers[#store.offers+1]=offer
        end
        stores[#stores+1]=store
    end
    return {ok=true,value={contract=1,stores=stores}}
end
exports('GetGunStoreCatalog',function()
    if GetInvokingResource()~='feather-shops' then return {ok=false,code='authorization_denied'} end
    if not DefinitionRegistry.IsReady() or not IssuanceService.PurchaseAvailable() then
        return {ok=false,code='not_ready',message='Weapons catalog is not ready.'}
    end
    return WeaponGunStore.Build(WeaponStoreConfig,WeaponDefinitionCatalog)
end)
