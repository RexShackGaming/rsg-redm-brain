Config={DevMode=true,NativeAlphaRuntime=true,NativeAlphaCharacterId='Jane',CharacterAmmunitionEnabled=true,CharacterAmmoTransportEnabled=true}
for _,file in ipairs({'shared/constants.lua','shared/definitions/ammunition.lua','shared/definitions/attachments.lua',
    'shared/definitions/weapons.lua','shared/character_ammunition_materialization.lua',
    'client/character_maintenance_native.lua','client/character_ammunition_creation_native.lua','client/character_ammunition_loadout.lua'}) do dofile(file) end
local originalRep,originalUnpack=string.rep,string.unpack
local buffers,sequence={},0
string.rep=function(s,n)
    if s=='\0' and n==104 then
        sequence=sequence+1; local raw=originalRep('\0',96)..string.format('%08d',sequence)
        buffers[raw]={}; return raw
    end
    return originalRep(s,n)
end
string.unpack=function(format,raw,pos)
    if buffers[raw] and format=='<I4' then return buffers[raw][math.floor(((pos or 1)-1)/8)+1] or 0,(pos or 1)+4 end
    return originalUnpack(format,raw,pos)
end
local hashes,nextHash={},100
joaat=function(name) if not hashes[name] then nextHash=nextHash+1; hashes[name]=nextHash end; return hashes[name] end
local function guid(n) return {0x80000000,0,17,n} end
local function key(words) return string.format('%08x%08x%08x%08x',words[1],words[2],words[3],words[4]) end
local function write(raw,words,hash,flag)
    buffers[raw]={words[1],words[2],words[3],words[4],hash or 0,0,0,0,0,0,flag or 0}
end
WeaponCharacterAmmoCreationNative.DecodeDiagnosticGuid=function(raw)
    local words=buffers[raw]; if not words or not words[1] then return nil end
    return {scriptSlotWords={words[1],words[2],words[3],words[4]},raw32=key(words)}
end
local savedFlag,epoch=1,'e1'
GetConvarInt=function(name) return name=='feather_native_guid_ownership' and 1 or name=='feather_native_saved_attachments' and savedFlag
    or name=='feather_native_representative_attachments' and epoch:match('^schofield') and 1
    or name=='feather_native_catalog_attachments' and epoch:match('^catalog:') and 1 or 0 end
PlayerPedId=function() return 42 end
WeaponCharacterAmmoWorldContext={Read=function() return {ok=true,value={characterId='Jane',sessionId='s',ped=42}} end}
local entity,parent,children,issued=0,nil,{},500
local wideHash=joaat('COMPONENT_REPEATER_CARBINE_SIGHT_WIDE')
local stockHash=joaat('COMPONENT_REPEATER_CARBINE_SIGHT_NARROW')
local weaponHash=joaat('WEAPON_REPEATER_CARBINE')
local currentPoint,currentSlot=10,468034421
DoesEntityExist=function(id) return id==42 or entity>0 and id==entity end
IsEntityDead=function() return false end
GetCurrentPedWeapon=function(_,_,point) return entity>0 and point==currentPoint,entity>0 and point==currentPoint and weaponHash or 0 end
GetCurrentPedWeaponEntityIndex=function(_,point) return entity>0 and point==currentPoint and entity or 0 end
HasPedGotWeapon=function() return entity>0 end
GiveWeaponToPed=function(_,hash,ammo)
    assert(hash==weaponHash and ammo==0 and entity==0)
    issued=issued+10; parent=guid(issued); entity=issued+1000
    children={[stockHash]={words=guid(issued+1),flag=1}}
end
RemoveWeaponFromPed=function()
    assert(children[wideHash]==nil and children[stockHash].flag==1,'children cleaned before weapon')
    entity=0; children={}
end
GetGameTimer=function() return 1 end
Wait=function() error('unexpected native factory yield') end
SetCurrentPedWeapon=function() end
GetObjectIndexFromEntityIndex=function(id) return id end
for _,name in ipairs({'GetWeaponDegradation','GetWeaponPermanentDegradation','GetWeaponDamage','GetWeaponDirt','GetWeaponSoot'}) do _G[name]=function() return 0 end end
for _,name in ipairs({'SetWeaponDegradation','SetWeaponDamage','SetWeaponDirt','SetWeaponSoot'}) do _G[name]=function() end end
Citizen={ResultAsInteger=function() return 'integer' end,InvokeNative=function(hash,a,b,c,d,e,f)
    if hash==0x6929E22158E52265 then assert(b==currentPoint); write(c,parent); return 1 end
    if hash==0x886DFD3E185C8A89 then
        assert(key(buffers[b])==key(parent) and d==currentSlot)
        local child=children[c]; if not child then return false end; write(e,child.words); return true
    end
    if hash==0x033EE4B89F3AC545 then local n=0; for _ in pairs(children) do n=n+1 end; return n end
    if hash==0xBE012571B25F5ACA then local stock=children[stockHash]; write(e,stock.words,stockHash,stock.flag); return 1 end
    if hash==0x9700E8EFC4AB9089 then
        for item,child in pairs(children) do if key(child.words)==key(buffers[b]) then write(c,child.words,item,child.flag); return true end end
        return false
    end
    if hash==0xCB5D11F9508A928D then
        assert(d==wideHash and e==currentSlot and f==1 and not children[wideHash])
        children[wideHash]={words=guid(issued+2),flag=0}; write(b,children[wideHash].words); return true
    end
    if hash==0x734311E2852760D0 then
        for _,child in pairs(children) do child.flag=key(child.words)==key(buffers[b]) and 1 or 0 end
        return true
    end
    if hash==0x3E4E811480B3AE79 then
        assert(children[wideHash] and key(buffers[b])==key(children[wideHash].words) and children[stockHash].flag==1)
        children[wideHash]=nil; return true
    end
    error('unexpected native '..string.format('%x',hash))
end}
local item={slot='shoulder',point=10,itemInstanceId=901,itemRevision=1,definitionId='repeater_carbine',
    serialNumber='ORDINARY-CARBINE-901',nativeWeaponName='WEAPON_REPEATER_CARBINE',
    attachments={{definitionId='carbine_wide_sight',slot='sight'}},cosmetics={},preferredAmmoType='regular',
    maintenance={degradation=0,permanentDegradation=0,damage=0,dirt=0,soot=0},copyKey='shoulder:901:1',creation='native_zero_ammo_grant'}
local registry={weapons={repeater_carbine={nativeWeaponName=item.nativeWeaponName,family='repeater',compatible={regular=true}}}}
local previousWide
local resolveMapping=WeaponNativeAttachmentMappings.Resolve
WeaponNativeAttachmentMappings.Resolve=function(...)
    local mapping,why=resolveMapping(...)
    if mapping and epoch=='dynamic-stock' then mapping.stockComponentName=nil end
    return mapping,why
end
local cases={'e1','e2','dynamic-stock','schofield-sight','schofield-barrel'}
local catalogCases={}
for _,weapon in pairs(WeaponDefinitionCatalog.weapons) do
 if weapon.id~='revolver_lemat' then
  for _,ids in pairs(weapon.attachmentSlots or {}) do
   for _,id in ipairs(ids) do
    local case='catalog:'..id; cases[#cases+1]=case; catalogCases[case]={weapon=weapon,attachment=WeaponDefinitionCatalog.attachments[id]}
   end
  end
 end
end
for _,freshEpoch in ipairs(cases) do
    epoch=freshEpoch
    if epoch:match('^schofield') then
        local barrel=epoch=='schofield-barrel'
        item.slot='primary'; item.point=2; item.definitionId='revolver_schofield'
        item.nativeWeaponName='WEAPON_REVOLVER_SCHOFIELD'
        item.attachments={{definitionId=barrel and 'schofield_short_barrel' or 'schofield_wide_sight',slot=barrel and 'barrel' or 'sight'}}
        item.copyKey='primary:901:1'
        weaponHash=joaat(item.nativeWeaponName); currentPoint=2; currentSlot=barrel and 1985390213 or 1880805647
        wideHash=joaat(barrel and 'COMPONENT_REVOLVER_SCHOFIELD_BARREL_SHORT' or 'COMPONENT_REVOLVER_SCHOFIELD_SIGHT_WIDE')
        stockHash=joaat('MOCK_DISTINCT_STOCK_'..epoch) -- engine resolves exact child, no guessed stock name
        registry={weapons={revolver_schofield={nativeWeaponName=item.nativeWeaponName,family='revolver',compatible={regular=true}}}}
    end
    if catalogCases[epoch] then
        local selected=catalogCases[epoch]; local weapon,attachment=selected.weapon,selected.attachment
        item.slot=weapon.slot=='sidearm' and 'primary' or 'shoulder'; item.point=weapon.slot=='sidearm' and 2 or 10
        item.definitionId=weapon.id; item.nativeWeaponName=weapon.nativeWeaponName
        item.attachments={{definitionId=attachment.id,slot=attachment.slot}}; item.copyKey=item.slot..':901:1'
        local mapping=assert(WeaponNativeAttachmentMappings.Resolve(weapon,attachment,true))
        weaponHash=joaat(item.nativeWeaponName); currentPoint=item.point; currentSlot=mapping.nativeSlot
        wideHash=joaat(attachment.nativeComponentName)
        stockHash=joaat(mapping.stockComponentName or ('MOCK_STOCK_'..epoch))
        registry={weapons={[weapon.id]={nativeWeaponName=item.nativeWeaponName,family=weapon.family,compatible={regular=true}}}}
    end
    local identity={characterId='Jane',sessionId='s',epoch=epoch}
    local plan={identity=identity,dual=false,sameModel=false,items={item}}
    local valid,why=WeaponCharacterAmmoMaterialization.Validate(plan,registry,identity)
    assert(valid,epoch..': '..tostring(why))
    savedFlag=0; assert(not WeaponCharacterAmmoMaterialization.Validate(plan,registry,identity)); savedFlag=1
    local adapter=assert(WeaponCharacterAmmoCreationNative.Scoped(42,identity,function() return true end,function() return true end))
    local result=assert(WeaponCharacterAmmoLoadout.New(adapter).Create(plan))
    assert(children[wideHash].flag==1 and children[stockHash].flag==0)
    local newWide=key(children[wideHash].words)
    assert(newWide~=previousWide,'fresh runtime reconstructs a fresh native child, never adopts old GUID')
    previousWide=newWide
    assert(adapter.readMaintenance(result.handles[1],identity))
    assert(adapter.remove(result.handles[1]) and adapter.cleanupSetup() and entity==0)
    assert(item.itemRevision==1 and #item.attachments==1,'rebuild has no metadata write')
end
WeaponNativeAttachmentMappings.Resolve=resolveMapping
string.rep,string.unpack=originalRep,originalUnpack
print('saved native factory PASS (actual Scoped/projection/materialization/loadout/native child flags, exact cleanup, fresh epoch reconstruction, disabled veto)')
