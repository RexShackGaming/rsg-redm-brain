dofile('client/character_maintenance_native.lua')
local function fixture()
    local s={current=true,stock='stock-guid',equipped='stock-guid',count=1,events={}}
    local p=WeaponNativeAttachmentChild.New({
        current=function() return s.current end,
        count=function() return s.count end,
        find=function() return s.wide end,
        stock=function() return s.stock end,
        equipped=function() return s.equipped end,
        add=function() s.events[#s.events+1]='add'; s.wide='new-guid'; s.count=2; return s.wide end,
        equip=function(id)
            s.events[#s.events+1]='equip:'..id
            if s.failEquip==id then return false end
            if not s.noEquipReadback then s.equipped=id end
            return true
        end,
        remove=function(id)
            assert(id=='new-guid','stock child must NEVER be removed')
            assert(s.equipped=='stock-guid','stock must be restored before removing new child')
            s.events[#s.events+1]='remove:'..id
            s.wide=nil; s.count=1; return true
        end,
    })
    return s,p
end
local s,p=fixture()
assert(p.Run('status').noNativeWrites and #s.events==0 and not p.Pending())
assert(p.Run('install').preservedStockGuid=='stock-guid' and s.equipped=='new-guid' and p.Pending())
assert(not p.Run('install') and #s.events==2,'no duplicate add')
local out=assert(p.Run('remove'))
assert(not out.owned and not p.Pending() and s.stock=='stock-guid' and s.equipped=='stock-guid')
assert(table.concat(s.events,',')=='add,equip:new-guid,equip:stock-guid,remove:new-guid')
for _,change in ipairs({function(x) x.stock=nil end,function(x) x.count=2 end,
    function(x) x.wide='foreign-wide' end,function(x) x.equipped='foreign-equipped' end}) do
    s,p=fixture(); change(s); assert(not p.Run('install') and #s.events==0 and not p.Pending())
end
s,p=fixture(); s.failEquip='new-guid'; assert(not p.Run('install') and p.Pending()); assert(p.Run('remove'))
s,p=fixture(); assert(p.Run('install')); s.failEquip='stock-guid'
assert(not p.Run('remove') and p.Pending() and s.wide=='new-guid','failed stock restore cannot remove wide')
s,p=fixture(); assert(p.Run('install')); s.stock='foreign-stock'
local n=#s.events; assert(not p.Run('remove') and #s.events==n and p.Pending())
s,p=fixture(); s.noEquipReadback=true
assert(not p.Run('install') and p.Pending(),'successful native equip alone is not readback acceptance')
s,p=fixture(); assert(p.Run('install')); s.current=false
assert(not p.Run('remove') and p.Pending() and #s.events==2)
print('native stock child PASS (exact preservation, equip readback, restore-before-remove, foreign/failure/context refusal)')
