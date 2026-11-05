dofile('client/character_maintenance_native.lua')
local function fixture()
    local s={current=true,child=nil,writes=0,equip=true,remove=true}
    local p=WeaponNativeAttachmentChild.New({current=function() return s.current end,
        count=function() return s.child and 1 or 0 end,
        find=function() return s.child end,
        add=function() s.writes=s.writes+1; s.child='new'; return s.child end,
        equip=function() return s.equip end,
        remove=function() s.writes=s.writes+1; if s.remove then s.child=nil end; return s.remove end})
    return s,p
end
local s,p=fixture()
assert(p.Run('install').owned and p.Pending())
assert(not p.Run('install') and s.writes==1)
assert(p.Run('status').child=='new')
assert(p.Run('status').slotCount==1 and p.Run('status').slotCountType=='number' and p.Run('status').noNativeWrites)
assert(not p.Run('remove').owned and not p.Pending() and s.writes==2)
s,p=fixture(); s.child='foreign'; assert(not p.Run('install') and s.writes==0)
assert(p.Run('status').slotCount==1 and not p.Pending() and s.writes==0,'refused existing slot remains read-only and unowned')
s,p=fixture(); s.equip=false; assert(not p.Run('install') and p.Pending()); assert(p.Run('remove'))
s,p=fixture(); assert(p.Run('install')); s.child='foreign'; assert(not p.Run('remove') and s.writes==1 and p.Pending())
s,p=fixture(); assert(p.Run('install')); s.current=false; assert(not p.Run('remove') and p.Pending())
s,p=fixture(); assert(p.Run('install')); s.remove=false; assert(not p.Run('remove') and p.Pending())
local writes=0
p=WeaponNativeAttachmentChild.New({current=function() return true end,find=function() end,count=function() return 0 end,
    add=function() writes=writes+1; return nil end})
assert(not p.Run('install') and p.Pending()); assert(not p.Run('install') and writes==1)
print('native_attachment_child_spec: PASS')
