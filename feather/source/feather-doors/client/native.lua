-- Internal Phase 0 adapter. Loading this file never changes a door.
-- This is not an authorization or synchronization API.
FeatherDoorsNative = {}

function FeatherDoorsNative.New(port)
    local leases = {}
    local api = {}
    local function finite(n) return type(n) == 'number' and n == n and math.abs(n) < math.huge end
    local function registered(hash)
        local value = port.registered(hash)
        if value == true or value == 1 then return true end
        if value == false or value == 0 then return false end
        error('invalid_registration_readback')
    end
    local function read(hash)
        return { hash=hash, registered=registered(hash), state=port.state(hash), ratio=port.ratio(hash) }
    end
    function api:Inspect()
        local result = {}
        for _, lease in ipairs(leases) do result[#result+1] = read(lease.hash) end
        return result
    end
    function api:Release()
        local failures = {}
        for index = #leases, 1, -1 do
            local lease = leases[index]
            local ok, err = pcall(function()
                if lease.existing then
                    if not registered(lease.hash) then error('registration_lost') end
                    port.setState(lease.hash, 0)
                    port.setRatio(lease.hash, lease.ratio)
                    port.setState(lease.hash, lease.state)
                    if port.state(lease.hash) ~= lease.state then error('restore_state_mismatch') end
                else
                    if registered(lease.hash) and not lease.removalRequested then
                        port.setState(lease.hash, 0)
                        port.remove(lease.hash)
                        -- Removal can still read registered during this frame.
                        -- Poll confirmation later rather than reissuing removal.
                        lease.removalRequested = true
                    end
                    if registered(lease.hash) then error('remove_pending') end
                end
            end)
            if ok then table.remove(leases, index)
            else failures[#failures+1] = { hash=lease.hash, error=tostring(err) } end
        end
        return #failures == 0, failures
    end
    function api:Acquire(hashes)
        if #leases > 0 then return false, 'already_acquired' end
        if type(hashes) ~= 'table' or getmetatable(hashes) ~= nil then return false, 'invalid_hashes' end
        local count = 0
        for k in pairs(hashes) do
            if type(k) ~= 'number' or k%1 ~= 0 or k<1 or k>2 then return false, 'invalid_hashes' end
            count = count+1
        end
        if count < 1 or count ~= #hashes then return false, 'invalid_hashes' end
        local seen, captured = {}, {}
        -- Validate and capture the whole group before modifying any leaf.
        for _, hash in ipairs(hashes) do
            if not finite(hash) or hash%1 ~= 0 or hash<1 or hash>4294967295 or seen[hash] then
                return false, 'invalid_hashes'
            end
            seen[hash] = true
            local state = read(hash)
            if state.registered and (not finite(state.state) or state.state%1~=0 or state.state<0
                or state.state>4 or not finite(state.ratio) or math.abs(state.ratio)>1) then
                return false, 'unsupported_baseline'
            end
            captured[#captured+1] = { hash=hash, existing=state.registered, state=state.state, ratio=state.ratio }
        end
        local ok, err = pcall(function()
            for _, lease in ipairs(captured) do
                leases[#leases+1] = lease
                if not lease.existing then port.add(lease.hash) end
                if not registered(lease.hash) then error('registration_failed') end
            end
        end)
        if not ok then
            local restored = self:Release()
            return false, restored and 'registration_failed' or 'cleanup_pending', tostring(err)
        end
        return true, self:Inspect()
    end
    function api:SetLocked(locked)
        if type(locked) ~= 'boolean' then return false, 'invalid_state' end
        if #leases == 0 then return false, 'not_acquired' end
        -- Do not silently re-register a leaf removed by another script.
        for _, lease in ipairs(leases) do
            if lease.removalRequested then return false, 'cleanup_pending' end
            if not registered(lease.hash) then return false, 'registration_lost' end
        end
        for _, lease in ipairs(leases) do
            if locked then port.setRatio(lease.hash, 0.0) end
            port.setState(lease.hash, locked and 1 or 0)
        end
        local snapshot = self:Inspect()
        for _, leaf in ipairs(snapshot) do
            if leaf.state ~= (locked and 1 or 0) then return false, 'state_readback_mismatch', snapshot end
        end
        return true, snapshot
    end
    return api
end

function FeatherDoorsNative.GamePort()
    return {
        registered = function(hash) return IsDoorRegisteredWithSystem(hash) end,
        state = function(hash) return DoorSystemGetDoorState(hash) end,
        ratio = function(hash) return DoorSystemGetOpenRatio(hash) end,
        add = function(hash) Citizen.InvokeNative(0xD99229FE93B46286, hash, true, true, false, 0, 0, false) end,
        remove = function(hash) RemoveDoorFromSystem(hash) end,
        setState = function(hash, state) DoorSystemSetDoorState(hash, state) end,
        setRatio = function(hash, ratio) DoorSystemSetOpenRatio(hash, ratio, true) end
    }
end
