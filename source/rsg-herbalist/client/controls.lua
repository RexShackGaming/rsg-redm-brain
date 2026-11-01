----------------------------------------------------------------------------
-- Shared "pick up" control-binding helpers
--
-- Used by both client/client.lua (herb nodes) and client/mysterybox.lua
-- (mystery box) to detect the RDR3 "pick up" input (keyboard + gamepad
-- variants). Previously duplicated identically in both files; kept here
-- once so the two interaction systems can't drift out of sync.
----------------------------------------------------------------------------

PICKUP_CONTROL_HASHES = {
    0xCEFD9220, -- INPUT_PICKUP
    0xE30CD707, -- INPUT_PICKUP_ALT (gamepad)
    0xF6BB7378,
    0xEB2AC491,
    0xFF8109D8,
    0x27D1C284,
    0xBE8593AF,
    0x41AC83D1,
}

function IsPickupControlPressed()
    for _, hash in ipairs(PICKUP_CONTROL_HASHES) do
        if IsDisabledControlJustPressed(0, hash) then
            return true
        end
    end
    return false
end
