DoorsContract = {}
local C=DoorsContract
C.MaxRevision=9007199254740990
function C.Err(code) return {ok=false,code=code,message=code} end
function C.Ok(value) return {ok=true,value=value} end
function C.Int(n,min,max) return type(n)=='number' and n==n and n%1==0 and n>=min and n<=max end
function C.Token(s,max) return type(s)=='string' and #s>0 and #s<=max and s:match('^[%w][%w_.:%-]*$')~=nil end
function C.Uuid(s)
    return type(s)=='string' and #s==36 and s:match('^%x%x%x%x%x%x%x%x%-%x%x%x%x%-%x%x%x%x%-%x%x%x%x%-%x%x%x%x%x%x%x%x%x%x%x%x$')~=nil
end
function C.Fields(t,allowed)
    if type(t)~='table' or getmetatable(t)~=nil then return false end
    for key in pairs(t) do if not allowed[key] then return false end end
    return true
end
function C.Canonical(value)
    if type(value)~='table' then return json.encode(value) end
    local keys,parts={},{}
    for key in pairs(value) do keys[#keys+1]=key end
    table.sort(keys,function(a,b) return tostring(a)<tostring(b) end)
    for _,key in ipairs(keys) do parts[#parts+1]=json.encode(tostring(key))..':'..C.Canonical(value[key]) end
    return '{'..table.concat(parts,',')..'}'
end
local common={requestId=true,reasonCode=true}
local policies={preserve=true,force_locked=true,force_unlocked=true}
function C.Validate(kind,request)
    local fields={}
    for k in pairs(common) do fields[k]=true end
    local extra=kind=='create' and {'key','label','locked','startupPolicy','leaves'}
        or kind=='update' and {'doorId','expectedRevision','label','status','startupPolicy'}
        or kind=='state' and {'doorId','expectedRevision','locked'}
        or kind=='control' and {'key','expectedRevision','locked'}
        or kind=='binding' and {'doorId','expectedRevision','mode'}
        or kind=='authority' and {'doorId','expectedRevision'}
        or kind=='retire' and {'doorId','expectedRevision'} or nil
    if not extra then return nil end
    for _,k in ipairs(extra) do fields[k]=true end
    if not C.Fields(request,fields) or not C.Token(request.requestId,128) or not C.Token(request.reasonCode,64) then return nil end
    local out={requestId=request.requestId,reasonCode=request.reasonCode}
    for _,key in ipairs(extra) do out[key]=request[key] end
    if kind=='control' then
        if not C.Token(out.key,100) or not C.Int(out.expectedRevision,1,C.MaxRevision) then return nil end
    elseif kind~='create' then
        if not C.Uuid(out.doorId) or not C.Int(out.expectedRevision,1,C.MaxRevision) then return nil end
        out.doorId=out.doorId:lower()
    end
    if kind=='create' then
        if not C.Token(out.key,100) or type(out.locked)~='boolean' then return nil end
        if out.startupPolicy==nil then out.startupPolicy='preserve' end
        if type(out.leaves)~='table' or getmetatable(out.leaves) then return nil end
        local count=0
        for k in pairs(out.leaves) do if not C.Int(k,1,2) then return nil end; count=count+1 end
        if count<1 or count~=#out.leaves then return nil end
        local leaves,seen={},{}
        for i,leaf in ipairs(out.leaves) do
            if not C.Fields(leaf,{hash=true,model=true,x=true,y=true,z=true})
                or not C.Int(leaf.hash,1,4294967295) or not C.Int(leaf.model,1,4294967295) or seen[leaf.hash] then return nil end
            for _,axis in ipairs({'x','y','z'}) do
                local n=leaf[axis]
                if type(n)~='number' or n~=n or math.abs(n)> (axis=='z' and 5000 or 20000)
                    or (axis=='z' and n < -2000) then return nil end
            end
            seen[leaf.hash]=true
            leaves[i]={hash=leaf.hash,model=leaf.model,x=leaf.x,y=leaf.y,z=leaf.z}
        end
        out.leaves=leaves
    end
    if kind=='create' or out.label~=nil then
        if type(out.label)~='string' or #out.label<1 or #out.label>128 or out.label:find('%c')
            or not out.label:find('%S') or not utf8.len(out.label) then return nil end
    end
    if out.startupPolicy~=nil and not policies[out.startupPolicy] then return nil end
    if out.status~=nil and out.status~='active' and out.status~='suspended' then return nil end
    if kind=='update' and out.label==nil and out.status==nil and out.startupPolicy==nil then return nil end
    if kind=='binding' and out.mode~='standalone' and out.mode~='property' then return nil end
    if (kind=='state' or kind=='control') and type(out.locked)~='boolean' then return nil end
    return out
end
