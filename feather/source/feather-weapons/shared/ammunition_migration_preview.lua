-- Pure read-only calculation: NEVER repairs metadata or sums clip projections
-- on top of authoritative pools. Enrollment must revalidate under locks later.
WeaponAmmoMigrationPreview = {}
local families = { pistol=true, revolver=true, repeater=true, rifle=true, shotgun=true }
local function count(value)
    return type(value)=='number' and value==value and value>=0
        and value%1==0 and value<math.huge
end
function WeaponAmmoMigrationPreview.Build(items, catalog, limits)
    local plan={items={},pools={},nativePools={},loose={},excluded={},issues={},overflow={},
        firearmCount=0,revisionChecks={},readOnly=true}
    local byName={}
    for _,definition in pairs(catalog.weapons or {}) do byName[definition.itemName]=definition end
    local seen={}
    local function issue(item, reason)
        plan.issues[#plan.issues+1]={itemId=item.id,itemName=item.name,reason=reason}
    end
    for _,item in ipairs(items or {}) do
        local definition=byName[item.name]
        local id=tonumber(item.id)
        if not id or id<1 or id%1~=0 or seen[id] then
            issue(item,'invalid_or_duplicate_item_id')
        else
            seen[id]=true
            if item.type=='item_ammo' then
                local ammo=catalog.ammunition[item.name]
                if ammo then plan.loose[item.name]=(plan.loose[item.name] or 0)+1 end
            elseif definition and families[definition.family] and definition.usesAmmunition~=false then
                plan.firearmCount=plan.firearmCount+1
                local metadata=item.metadata
                local ammo=type(metadata)=='table' and metadata.ammo
                local valid=true
                local function reject(reason) valid=false; issue(item,reason) end
                if item.type~='item_weapon' then reject('firearm_item_type_mismatch') end
                if type(metadata)~='table' or metadata.weaponDefinitionId~=definition.id then reject('weapon_metadata_identity_mismatch') end
                if type(ammo)~='table' then reject('missing_ammo_metadata') end
                if not count(item.revision) then reject('invalid_item_revision') end
                local accepted,selected,mode={},nil,'pools'
                local compatible={}
                for _,ammoId in ipairs(definition.ammunitionTypes or {}) do compatible[ammoId]=true end
                if type(ammo)=='table' then
                    selected=ammo.type or definition.ammunitionType
                    if ammo.ownership=='character' then reject('already_character_owned_item') end
                    if not compatible[selected] then reject('incompatible_selected_type') end
                    if not count(ammo.loaded) or not count(ammo.reserve) or ammo.loaded>definition.capacity then
                        reject('invalid_loaded_or_reserve')
                    end
                    if ammo.pools~=nil then
                        mode='pools'
                        if type(ammo.pools)~='table' then reject('invalid_pool_table')
                        else
                            for ammoId,amount in pairs(ammo.pools) do
                                if not compatible[ammoId] or not catalog.ammunition[ammoId] or not count(amount) then
                                    reject('incompatible_or_invalid_pool')
                                else accepted[ammoId]=amount end
                            end
                            if count(ammo.loaded) and count(ammo.reserve)
                                and (accepted[selected] or 0)~=ammo.loaded+ammo.reserve then
                                reject('selected_projection_mismatch')
                            end
                        end
                    else
                        reject('missing_authoritative_pools')
                    end
                    if ammo.clips~=nil then
                        if type(ammo.clips)~='table' or mode~='pools' then reject('invalid_clip_table')
                        else
                            for ammoId,amount in pairs(ammo.clips) do
                                if not compatible[ammoId] or not count(amount) or amount>definition.capacity
                                    or amount>(accepted[ammoId] or 0) then reject('invalid_clip_projection') end
                            end
                            if ammo.clips[selected]~=ammo.loaded then reject('selected_clip_mismatch') end
                        end
                    end
                end
                for ammoId in pairs(accepted) do
                    local ammunition=catalog.ammunition[ammoId]
                    if not count(limits[ammoId]) or type(ammunition.nativeAmmoName)~='string' then
                        reject('missing_pool_limit_or_native_type')
                    end
                end
                if valid then
                    plan.items[#plan.items+1]={itemId=id,itemName=item.name,definitionId=definition.id,
                        revision=item.revision,mode=mode,selected=selected,pools=accepted,
                        specialModePending=definition.nativeWeaponName=='WEAPON_REVOLVER_LEMAT'}
                    plan.revisionChecks[tostring(id)]=item.revision
                    for ammoId,amount in pairs(accepted) do
                        plan.pools[ammoId]=(plan.pools[ammoId] or 0)+amount
                        local native=catalog.ammunition[ammoId].nativeAmmoName
                        local pool=plan.nativePools[native] or {total=0,limit=limits[ammoId],ammunitionIds={}}
                        pool.total=pool.total+amount
                        pool.limit=math.min(pool.limit,limits[ammoId])
                        pool.ammunitionIds[ammoId]=true
                        plan.nativePools[native]=pool
                    end
                end
            elseif item.type=='item_weapon' and not definition then
                issue(item,'unknown_weapon_definition')
            elseif definition then
                plan.excluded[#plan.excluded+1]={itemId=id,itemName=item.name,family=definition.family}
            end
        end
    end
    for native,pool in pairs(plan.nativePools) do
        if pool.total>pool.limit then
            plan.overflow[#plan.overflow+1]={nativeAmmoName=native,total=pool.total,
                provisionalLimit=pool.limit,excess=pool.total-pool.limit}
        end
    end
    plan.validationPassed=#plan.issues==0 and #plan.overflow==0
    plan.productionReady=false -- preview passes never authorize migration
    return plan
end
