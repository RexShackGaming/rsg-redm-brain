Config={}
for _,file in ipairs({'shared/constants.lua','shared/definitions/ammunition.lua','shared/definitions/attachments.lua',
    'shared/definitions/weapons.lua','shared/character_ammunition_materialization.lua',
    'client/character_maintenance_native.lua','client/character_ammunition_loadout.lua'}) do dofile(file) end
local function fixture(failCleanup)
    local s={current=true,count=1,equipped='stock',stock='stock',created=0,removed=0}
    local identity={characterId='c',sessionId='s',epoch='e'}
    local item={itemInstanceId=135,itemRevision=1,serialNumber='serial',definitionId='repeater_carbine',
        nativeWeaponName='WEAPON_REPEATER_CARBINE',attachments={{definitionId='carbine_wide_sight',slot='sight'}},cosmetics={},
        creation='native_zero_ammo_grant',copyKey='shoulder:135:1',point=10}
    local base={current=function() return s.current end,prepareDual=function() return true end,
        createPair=function() error('unproved customized pairs forbidden upstream') end,
        createSingle=function(private,ammo)
            assert(next(private.attachments)==nil and ammo==0)
            assert(item.attachments[1].definitionId=='carbine_wide_sight','saved metadata must not be cleared')
            s.created=s.created+1
            return {entity=101,name=item.nativeWeaponName,itemInstanceId=135,itemRevision=1,serialNumber='serial'}
        end,
        finish=function() return true end,
        remove=function() assert(not s.wide and s.equipped=='stock'); s.removed=s.removed+1; return true end,
        cleanupSetup=function() return true end}
    local manager=WeaponNativeAttachmentReconstruction.New({current=function(b) return s.current and b.epoch=='e' end,
        probe=function()
            return WeaponNativeAttachmentChild.New({current=function() return s.current end,
                count=function() return s.count end,find=function() return s.wide end,
                stock=function() return s.stock end,equipped=function() return s.equipped end,
                add=function() s.wide='new'; s.count=2; return s.wide end,
                equip=function(id)
                    if failCleanup then return false end
                    s.equipped=id; return true
                end,
                remove=function(id) assert(id=='new'); s.wide=nil; s.count=1; return true end})
        end})
    local adapter=WeaponNativeAttachmentReconstruction.Bind(base,function(value,check)
        return WeaponNativeAttachmentProjection.Build(value,WeaponDefinitionCatalog,check)
    end,manager)
    return s,adapter,{identity=identity,dual=false,items={item}}
end
local s,adapter,plan=fixture(false)
local result=assert(WeaponCharacterAmmoLoadout.New(adapter).Create(plan))
assert(s.created==1 and s.wide=='new' and s.equipped=='new' and s.removed==0)
assert(not adapter.cleanupSetup(),'setup cannot acknowledge outstanding child resources')
assert(adapter.remove(result.handles[1]) and s.removed==1 and s.equipped=='stock' and adapter.cleanupSetup())
s,adapter,plan=fixture(true)
local created,why,partial=WeaponCharacterAmmoLoadout.New(adapter).Create(plan)
assert(not created and why=='holster_verification_failed' and #partial.handles==1 and not partial.cleanupComplete)
assert(s.wide=='new' and s.removed==0 and not adapter.cleanupSetup(),'failed child compensation retains weapon and vetoes cleanup')
s,adapter,plan=fixture(false)
plan.items[1].attachments[1].nativeComponentName='injected'
assert(not WeaponCharacterAmmoLoadout.New(adapter).Create(plan) and s.created==0,'preflight rejects native instructions before weapon creation')
print('attachment creation binding PASS (canonical projection before grant, apply after handle tracking, child-first cleanup, partial retention, no metadata mutation)')
