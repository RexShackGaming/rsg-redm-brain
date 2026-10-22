-- Discord webhook logging for rsg-weather
-- Usage from any server file:  RSGWeatherLog(category, title, description, fields, src)
local RSGCore = exports['rsg-core']:GetCoreObject()
local W = WebhookConfig
W.ServerName = W.ServerName or GetConvar('sv_projectName', GetConvar('sv_hostname', 'RedM'))

function YesNo(b) return b and L('yes', 'Yes') or L('no', 'No') end

local queues   = {}   -- [url] = { embeds... }
local blocked  = {}   -- [url] = GetGameTimer() until which we're rate-limited
local VALID_HOSTS = { ['discord.com'] = true, ['discordapp.com'] = true, ['ptb.discord.com'] = true, ['canary.discord.com'] = true }

local function validUrl(url)
    local host = url:match('^https://([%w%.%-]+)/api/webhooks/%d+/[%w%-_]+$')
    return host ~= nil and VALID_HOSTS[host] == true
end

local function trim(s, n)
    s = tostring(s or '')
    return #s > n and (s:sub(1, n - 3) .. '...') or s
end

local function webhookFor(category)
    local cat = W.Categories[category]
    local url = GetConvar('rsg_weather_webhook_' .. category, '')
    if url == '' and cat then url = cat.webhook or '' end
    if url == '' then url = GetConvar('rsg_weather_webhook', '') end
    if url == '' then url = W.DefaultWebhook or '' end
    if url == '' then return nil end
    if not validUrl(url) then
        print(('^1[rsg-weather] webhook for "%s" is not a valid Discord webhook url^7'):format(category))
        return nil
    end
    return url
end

---------------------------------
-- actor info (who did it)
---------------------------------
local function actorField(src)
    src = tonumber(src)
    if not src or src <= 0 then return { name = L('wh_actor', 'Actor'), value = L('wh_console', 'Console / System'), inline = true } end

    local lines = { ('**%s** (ID %d)'):format(trim(GetPlayerName(src) or '?', 64), src) }
    local Player = RSGCore.Functions.GetPlayer(src)
    if Player then
        local ci = Player.PlayerData.charinfo or {}
        lines[#lines + 1] = L('wh_character', 'Character: %s %s', ci.firstname or '?', ci.lastname or '?')
        lines[#lines + 1] = ('CitizenID: `%s`'):format(Player.PlayerData.citizenid or '?')
    end
    if W.ShowDiscordMention then
        local discord = GetPlayerIdentifierByType(src, 'discord')
        if discord then lines[#lines + 1] = ('Discord: <@%s>'):format((discord:gsub('discord:', ''))) end
    end
    if W.ShowLicense then
        local lic = GetPlayerIdentifierByType(src, 'license')
        if lic then lines[#lines + 1] = ('License: `%s`'):format(lic) end
    end
    return { name = L('wh_actor', 'Actor'), value = table.concat(lines, '\n'), inline = false }
end

---------------------------------
-- public logger
---------------------------------
function RSGWeatherLog(category, title, description, fields, src)
    if not W.Enabled then return end
    local cat = W.Categories[category]
    if not cat or not cat.enabled then return end
    local url = webhookFor(category)
    if not url then return end

    local embedFields = {}
    if src ~= false then embedFields[1] = actorField(src) end
    for _, f in ipairs(fields or {}) do
        if #embedFields >= 25 then break end
        embedFields[#embedFields + 1] = {
            name = trim(f.name or f[1], 256),
            value = trim((f.value or f[2]) ~= nil and tostring(f.value or f[2]) or '-', 1024),
            inline = (f.inline == nil) and true or f.inline,
        }
    end

    local embed = {
        title = trim(title, 256),
        description = description and trim(description, 4000) or nil,
        color = cat.color or 9807270,
        fields = embedFields,
        footer = { text = ('%s • rsg-weather • %s'):format(W.ServerName or 'RedM', category) },
        timestamp = os.date('!%Y-%m-%dT%H:%M:%SZ'),
    }

    queues[url] = queues[url] or { embeds = {}, ping = {} }
    local q = queues[url]
    q.embeds[#q.embeds + 1] = embed
    if cat.ping and cat.ping ~= '' then q.ping[cat.ping] = true end
end

---------------------------------
-- sender: batches up to 10 embeds per message, respects Discord rate limits
---------------------------------
local function allowedMentions(content)
    local am = { parse = {}, roles = {}, users = {} }
    if content then
        for id in content:gmatch('<@&(%d+)>') do am.roles[#am.roles + 1] = id end
        for id in content:gmatch('<@!?(%d+)>') do am.users[#am.users + 1] = id end
        if content:find('@everyone') or content:find('@here') then am.parse = { 'everyone' } end
    end
    return am
end

-- rough size of an embed as Discord counts it (title, description, fields, footer)
local function embedSize(e)
    local n = #(e.title or '') + #(e.description or '') + #((e.footer and e.footer.text) or '')
    for _, f in ipairs(e.fields or {}) do n = n + #(f.name or '') + #(f.value or '') end
    return n
end

local function send(url, embeds, content)
    PerformHttpRequest(url, function(status, _, headers, err)
        if status == 429 then
            local retry = tonumber(headers and (headers['Retry-After'] or headers['retry-after'])) or 5
            blocked[url] = GetGameTimer() + math.ceil(retry * 1000)
            -- put the embeds back at the front of the queue
            queues[url] = queues[url] or { embeds = {}, ping = {} }
            for i = #embeds, 1, -1 do table.insert(queues[url].embeds, 1, embeds[i]) end
            print(('^3[rsg-weather] discord rate limited, retrying in %ss^7'):format(retry))
        elseif status < 200 or status >= 300 then
            print(('^1[rsg-weather] discord webhook failed (HTTP %s) %s^7'):format(status, tostring(err or '')))
        end
    end, 'POST', json.encode({
        username = W.BotName,
        avatar_url = (W.AvatarUrl ~= '' and W.AvatarUrl) or nil,
        content = content,
        embeds = embeds,
        -- only the configured ping (role/user) may notify anyone; actor mentions in embeds never ping
        allowed_mentions = allowedMentions(content),
    }), { ['Content-Type'] = 'application/json' })
end

CreateThread(function()
    while true do
        Wait(2000)
        local now = GetGameTimer()
        for url, q in pairs(queues) do
            if #q.embeds > 0 and (not blocked[url] or now >= blocked[url]) then
                -- Discord limits: 10 embeds and 6000 characters per message
                local batch, size = {}, 0
                while #q.embeds > 0 and #batch < 10 do
                    local s = embedSize(q.embeds[1])
                    if #batch > 0 and size + s > 5800 then break end
                    batch[#batch + 1] = table.remove(q.embeds, 1)
                    size = size + s
                end
                local pings = {}
                for p in pairs(q.ping) do pings[#pings + 1] = p end
                q.ping = {}
                send(url, batch, #pings > 0 and table.concat(pings, ' ') or nil)
                blocked[url] = now + 2100 -- max ~30 msgs/min per webhook
            end
        end
    end
end)

---------------------------------
-- forecast bulletin
---------------------------------

function RSGWeatherPostForecast()
    local f = RSGWeather.getForecast()
    local hours = math.min(W.Forecast.Hours or 12, #f)
    local lines = {}
    for i = 1, hours do
        local e = f[i]
        lines[#lines + 1] = L('wh_forecast_line', '`%s %02d:%02d` %s  *(wind %s)*', GetDayOfWeek(e.day), e.hour, e.minute, WeatherLabel(e.weather), GetCardinalDirection(e.wind))
    end
    local season = RSGWeatherSeason and RSGWeatherSeason.get().current
    local s = RSGWeather.getState()
    RSGWeatherLog('forecast', L('wh_bulletin', '📰 Weather Bulletin'), table.concat(lines, '\n'), {
        { name = L('wh_now', 'Now'), value = WeatherLabel(s.weather) },
        { name = L('wh_wind', 'Wind'), value = ('%d° %s'):format(math.floor(s.windDirection), GetCardinalDirection(s.windDirection)) },
        { name = L('wh_season', 'Season'), value = SeasonLabel(season) },
    }, false)
end

CreateThread(function()
    Wait(10000)
    if W.Forecast.PostOnStart then RSGWeatherPostForecast() end
    local mins = tonumber(W.Forecast.IntervalMinutes) or 0
    if mins <= 0 then return end
    while true do
        Wait(mins * 60000)
        RSGWeatherPostForecast()
    end
end)

---------------------------------
-- system logs
---------------------------------
CreateThread(function()
    Wait(3000)
    RSGWeatherLog('system', L('wh_started', '✅ rsg-weather started'), nil, {
        { name = L('wh_version', 'Version'), value = GetResourceMetadata(GetCurrentResourceName(), 'version', 0) or '?' },
        { name = L('wh_weather', 'Weather'), value = WeatherLabel(RSGWeather.getWeather()) },
    }, false)
end)

AddEventHandler('onResourceStop', function(res)
    if res ~= GetCurrentResourceName() then return end
    -- flush synchronously-ish: one last post with whatever is queued (best effort)
    local url = webhookFor('system')
    if url and W.Enabled and W.Categories.system.enabled then
        send(url, { { title = L('wh_stopped', '⛔ rsg-weather stopped'), color = W.Categories.system.color,
            footer = { text = (W.ServerName or 'RedM') .. ' • rsg-weather • system' }, timestamp = os.date('!%Y-%m-%dT%H:%M:%SZ') } })
    end
end)
