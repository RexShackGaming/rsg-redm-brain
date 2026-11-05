-- Opt-in, self-only native timing test. Never flushes/checkpoints or grants ammo.
if not Config.DevMode then return end
if Config.CharacterAmmunitionEnabled==true or Config.CharacterAmmoTransportEnabled==true then return end
local sequence = 0
RegisterCommand('weapondeathaftershots', function(_, args)
    sequence = sequence + 1 -- also cancels a previous armed test
    if args[1] == 'cancel' then
        print('[feather-weapons] shot-death test cancelled')
        return
    end
    local target = tonumber(args[1] or '2')
    local mode = args[2] or 'sidearms'
    if not target or target % 1 ~= 0 or target < 1 or target > 4
        or (mode ~= 'sidearms' and mode ~= 'longguns') then
        print('[feather-weapons] usage: weapondeathaftershots [1-4|cancel] [sidearms|longguns]')
        return
    end
    local initial = FeatherWeaponsClient.GetShotDeathContext(mode)
    local ped = PlayerPedId()
    if not initial then
        print('[feather-weapons] shot-death rejected: alive same-ammo pair required; longguns mode requires a drawn longgun')
        return
    end
    local before = tonumber(GetPedAmmoByType(ped, initial.ammoHash))
    if not before or before ~= initial.expected or before < target then
        print('[feather-weapons] shot-death rejected: native/saved pool mismatch or insufficient ammo')
        return
    end
    local token, deadline = sequence, GetGameTimer() + 30000
    print(('[feather-weapons] shot-death ARMED target=%d baseline=%d timeout=30s'):format(target, before))
    CreateThread(function()
        local previous, consumed = before, 0
        while token == sequence do
            Wait(0)
            if token ~= sequence then return end
            local current = FeatherWeaponsClient.GetShotDeathContext(mode)
            local stable = current and PlayerPedId() == ped
            for _, key in ipairs({'primary', 'offhand', 'primaryGeneration', 'offhandGeneration',
                'epoch', 'restoreGeneration', 'ammoHash', 'selectedHash'}) do
                if not current or current[key] ~= initial[key] then stable = false end
            end
            if not stable or GetGameTimer() >= deadline then
                print('[feather-weapons] shot-death cancelled: context changed, death or timeout')
                return
            end
            local total = tonumber(GetPedAmmoByType(ped, initial.ammoHash))
            if not total or total > previous then
                print('[feather-weapons] shot-death cancelled: ammo pool increased/unavailable')
                return
            end
            consumed = consumed + previous - total
            previous = total
            if consumed >= target then
                -- Deliberately do NOT flush ammunition before killing.
                SetEntityHealth(ped, 0)
                print(('[feather-weapons] shot-death TRIGGERED target=%d observed=%d before=%d after=%d'):format(
                    target, consumed, before, total))
                return
            end
        end
    end)
end, false)
