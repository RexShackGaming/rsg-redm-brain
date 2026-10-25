-- MLO / custom door hashes that are not in shared/doorhashes.lua
-- Paste entries in the usual door-hash format:
--   [doorHash] = { doorHash, modelHash, "modelName", x, y, z },
-- They are added to the /doorlock editor and locked with the game's door system.
CustomDoorHashes = {
    --[1651863461] = { 1651863461, -667091646, "p_door58x", -5528.4658203125, -2953.718994140625, -1.69699990749359 },
}

-- merge into the editor list (format: { doorHash, modelName, x, y, z })
local known = {}
for _, d in ipairs(DoorHashes) do known[d[1]] = true end
for hash, d in pairs(CustomDoorHashes) do
    if not known[hash] then
        DoorHashes[#DoorHashes + 1] = { hash, d[3], d[4], d[5], d[6] }
        known[hash] = true
    end
end
