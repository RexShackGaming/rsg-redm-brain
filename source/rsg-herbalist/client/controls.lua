----------------------------------------------------------------------------
-- Shared "pick up" control-binding helpers
--
-- Used by both client/client.lua (herb nodes) and client/mysterybox.lua
-- (mystery box) to detect the RDR3 "pick up" input (keyboard + gamepad
-- variants). Previously duplicated identically in both files; kept here
-- once so the two interaction systems can't drift out of sync.
----------------------------------------------------------------------------

function IsPickupControlPressed()
    local list = Config.PickupControls
    for i = 1, #list do
        if IsDisabledControlJustPressed(0, list[i]) then
            if Config.Debug then
                print(('[rsg-herbalist] pickup control fired: 0x%X (Config.PickupControls entry %d)'):format(list[i], i))
            end
            return true
        end
    end
    return false
end
