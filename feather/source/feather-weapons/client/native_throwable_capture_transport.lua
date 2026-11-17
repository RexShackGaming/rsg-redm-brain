-- Server-challenged diagnostic report delivery only. Never retries a native,
-- equipment or economic operation. Captured client facts remain untrusted.
local active
local used,order={},{}
local function text(v) return type(v)=='string' and #v>0 and #v<=96 and not v:find('%c') end
RegisterNetEvent('feather-weapons:client:throwable-capture-ack',function(ticket,sequence)
    if source==65535 and active and active.ticket==ticket and active.pending==sequence then active.ack=sequence end
end)
RegisterNetEvent('feather-weapons:client:throwable-capture-cancel',function(ticket)
    if source==65535 and active and active.ticket==ticket then WeaponNativeThrowableEventProbe.Stop() end
end)
RegisterNetEvent('feather-weapons:client:throwable-capture-start',function(ticket,bound)
    if source~=65535 or active or not text(ticket) or used[ticket] or type(bound)~='table' then return end
    used[ticket]=true;order[#order+1]=ticket
    if #order>8 then used[table.remove(order,1)]=nil end
    local state={ticket=ticket,bound=bound};active=state
    local function deliver(report)
        state.report=report
        CreateThread(function()
            local ok,reason=pcall(function()
                local packets={}
                for first=1,#report.records,4 do
                    local rows={};for index=first,math.min(first+3,#report.records) do rows[#rows+1]=report.records[index] end
                    packets[#packets+1]={kind='rows',first=first,rows=rows}
                end
                packets[#packets+1]={kind='complete',count=#report.records,build=report.build,
                    reason=report.reason,frames=report.frames,readFailures=report.readFailures,truncated=report.truncated}
                for index,packet in ipairs(packets) do
                    local raw=json.encode(packet)
                    assert(type(raw)=='string' and #raw<=6000,'capture_report_packet_too_large')
                    state.pending=index
                    for attempt=1,3 do
                        TriggerServerEvent('feather-weapons:server:throwable-capture-report',ticket,index,raw)
                        local started=GetGameTimer()
                        while active==state and state.ack~=index and (GetGameTimer()-started)%4294967296<1000 do Wait(25) end
                        if state.ack==index then break end
                    end
                    assert(state.ack==index,'capture_report_delivery_unconfirmed')
                end
            end)
            if not ok then print('[WeaponNativeThrowableEvents] Report retained locally: '..tostring(reason)) end
            -- Local diagnostic remains available through the probe status.
            if active==state then active=nil end
        end)
    end
    local ok,started=pcall(WeaponNativeThrowableEventProbe.Start,bound,deliver)
    if not ok or not started then
        if not state.report then
            deliver({records={},build=0,reason='client_capture_preflight_refused',frames=0,readFailures=0,truncated=false})
        end
    end
end)
