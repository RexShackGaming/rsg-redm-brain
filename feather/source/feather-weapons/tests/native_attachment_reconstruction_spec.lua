dofile('client/character_maintenance_native.lua')
local function fixture()
    local s={current=true,stock='s',equipped='s',count=1}
    local plan={characterId='c',sessionId='sid',epoch='e',itemInstanceId=135,itemRevision=2,
        serialNumber='serial',nativeWeaponName='WEAPON_REPEATER_CARBINE',components={{definitionId='carbine_wide_sight',
        slot='sight',nativeSlot=468034421,nativeComponentName='COMPONENT_REPEATER_CARBINE_SIGHT_WIDE',
        stockComponentName='COMPONENT_REPEATER_CARBINE_SIGHT_NARROW'}}}
    local record={itemInstanceId=135,itemRevision=2,serialNumber='serial',name=plan.nativeWeaponName}
    local manager=WeaponNativeAttachmentReconstruction.New({current=function(b) return s.current and b.epoch=='e' end,
        probe=function()
            assert(s.manager.Pending(record),'factory reservation exists before native work')
            if s.factoryError then error('factory failed') end
            return WeaponNativeAttachmentChild.New({current=function() return s.current end,
                stock=function() return s.stock end,equipped=function() return s.equipped end,
                count=function() return s.count end,find=function() return s.wide end,
                add=function() s.wide='w'; s.count=2; return 'w' end,
                equip=function(id) if s.failEquip then return false end; s.equipped=id; return true end,
                remove=function(id) assert(id=='w' and s.equipped=='s'); s.wide=nil; s.count=1; return true end})
        end})
    s.manager=manager
    return s,manager,record,plan
end
local s,m,r,p=fixture()
assert(m.Apply(r,p) and m.Pending(r) and s.equipped=='w')
assert(not m.Apply(r,p))
p.epoch='mutated'; p.components[1].nativeSlot=0 -- manager retains private binding
assert(m.Cleanup(r) and not m.Pending(r) and s.stock=='s' and s.equipped=='s')
s,m,r,p=fixture(); s.failEquip=true
assert(not m.Apply(r,p) and m.Pending(r) and s.wide=='w')
assert(not m.Cleanup(r) and m.Pending(r),'failed compensation is retained')
s.failEquip=false; assert(m.Cleanup(r))
s,m,r,p=fixture(); assert(m.Apply(r,p)); r.itemRevision=3
assert(not m.Cleanup(r) and m.Pending(r),'revision mutation cannot authorize cleanup')
s,m,r,p=fixture(); s.factoryError=true
assert(not m.Apply(r,p) and m.Pending(r) and not m.Cleanup(r),'unknown factory outcome never falsely clears')
s,m,r,p=fixture(); s.current=false; assert(not m.Apply(r,p) and not m.Pending(r))
s,m,r,p=fixture(); p.components={}; assert(m.Apply(r,p) and not m.Pending(r))
print('attachment reconstruction PASS (pre-factory reservation, exact copy/revision/session, stock cleanup, partial/unknown retention)')
