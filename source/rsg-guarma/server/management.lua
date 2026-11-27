-------------------------------------
-- port management: closures, job discounts, ticket income
-------------------------------------
local RSGCore = exports['rsg-core']:GetCoreObject()
local manualClosed = {} -- [portId] = true (reset on restart)

-- nil = open, otherwise 'weather' or 'manual'
function Guarma.ClosedReason(portId)
    if manualClosed[portId] then return 'manual' end
    if Config.Management.hurricaneClosure and Config.Weather.enabled and GlobalState.guarmaWeather == 'hurricane' then
        return 'weather'
    end
    return nil
end

function Guarma.Discount(Player)
    local job = Player.PlayerData.job
    local discount = job and tonumber(Config.Management.discounts[job.name]) or 0
    return math.max(0, math.min(1, discount))
end

function Guarma.Price(Player, base)
    return Guarma.Round(base * (1 - Guarma.Discount(Player)))
end

function Guarma.PayPortIncome(portId, amount)
    local society = Config.Ports[portId].society
    if not society or not Guarma.IsRunning('rsg-society') then return end
    local share = Guarma.Round(amount * math.max(0, math.min(1, Config.Management.incomeShare)))
    if share <= 0 then return end
    if not exports['rsg-society']:AddMoney(society, share, 'Guarma boat tickets') then
        print(('^3[rsg-guarma] could not pay $%s to society "%s" (check the name)^7'):format(share, society))
    end
end

local function MayManage(src, portId)
    if src == 0 or RSGCore.Functions.HasPermission(src, Config.Management.adminPermission) then return true end
    local society = Config.Ports[portId].society
    return society ~= nil and Guarma.IsRunning('rsg-society') and exports['rsg-society']:IsBoss(src, society)
end

if Config.Management.command ~= '' then
    RSGCore.Commands.Add(Config.Management.command, locale('cmd_port_help'), {
        { name = 'port', help = locale('cmd_port_arg') },
        { name = 'state', help = 'open / close' },
    }, true, function(src, args)
        local portId, state = args[1], args[2]
        if not Config.Ports[portId] or (state ~= 'open' and state ~= 'close') then
            return Guarma.Notify(src, locale('cmd_port_usage', Config.Management.command), 'error')
        end
        if not MayManage(src, portId) then
            return Guarma.Notify(src, locale('no_permission'), 'error')
        end
        manualClosed[portId] = state == 'close' or nil
        Guarma.Notify(src, locale(state == 'close' and 'port_now_closed' or 'port_now_open', locale(Config.Ports[portId].label)), 'success')
        print(('[rsg-guarma] port %s set to %s by %s'):format(portId, state, src == 0 and 'console' or GetPlayerName(src)))
    end, 'user')
end
