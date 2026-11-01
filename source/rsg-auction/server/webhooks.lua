local RSGCore = exports['rsg-core']:GetCoreObject()
local Locale = locale

-- Discord Webhook System
-- Handles HTTP POST to Discord webhooks with retry logic and formatted embeds

-- Settings live in server/sv_config.lua (server-only, so URLs are never sent to clients).
-- Runtime changes from the admin commands below are kept in memory until restart.
local WebhookConfig = SvConfig.Webhooks
WebhookConfig.urls = WebhookConfig.urls or {}
WebhookConfig.enabled = WebhookConfig.enabled or {}
WebhookConfig.highValueThreshold = WebhookConfig.highValueThreshold or 1000
WebhookConfig.maxRetries = WebhookConfig.maxRetries or 3
WebhookConfig.retryDelay = WebhookConfig.retryDelay or 1000
WebhookConfig.botName = WebhookConfig.botName or 'Auction House'

-- ============================================
-- UTILITY FUNCTIONS
-- ============================================

local function getWebhookUrl(eventType)
    -- Check event-specific URL first
    if WebhookConfig.urls[eventType] then
        return WebhookConfig.urls[eventType]
    end
    -- Fall back to default URL
    return WebhookConfig.defaultUrl
end

-- Validate webhook URL to prevent SSRF
local function isValidWebhookUrl(url)
    if not url or type(url) ~= "string" then
        return false, Locale('error_url_must_be_string')
    end
    
    -- Must be HTTPS
    if not url:match("^https://") then
        return false, Locale('error_url_must_be_https')
    end
    
    -- Must be discord.com domain
    if not url:match("^https://discord%.com/api/webhooks/") then
        return false, Locale('error_url_must_be_discord')
    end
    
    -- Length check
    if #url > 500 then
        return false, Locale('error_url_too_long')
    end
    
    return true
end

local function isWebhookEnabled(eventType)
    return WebhookConfig.enabled[eventType] == true and getWebhookUrl(eventType) ~= nil
end

-- Format timestamp for Discord
local function formatTimestamp(timestamp)
    return os.date('!%Y-%m-%dT%H:%M:%S.000Z', timestamp or os.time())
end

-- Format currency (accepts cents, returns formatted string like "$1,234.56")
local function formatMoney(cents)
    return Money.formatWithCommas(cents or 0)
end

-- ============================================
-- EMBED BUILDERS
-- ============================================

local EmbedBuilders = {}

function EmbedBuilders.auctionCreated(data)
    return {
        title = 'New Auction Created',
        color = 3447003,
        fields = {
            { name = 'Item', value = string.format('%s x%d', data.itemLabel or data.itemName, data.count or 1), inline = true },
            { name = 'Starting Bid', value = formatMoney(data.startingBidCents), inline = true },
            { name = 'Seller', value = data.sellerName or 'Unknown', inline = true },
            { name = 'Duration', value = string.format('%d minutes', math.floor((data.duration or 3600) / 60)), inline = true },
            { name = 'Auction ID', value = data.auctionId or 'N/A', inline = true },
        },
        footer = { text = 'Auction House', icon_url = WebhookConfig.botAvatar },
        timestamp = formatTimestamp(),
    }
end

function EmbedBuilders.bidPlaced(data)
    return {
        title = 'Bid Placed',
        color = 16776960,
        fields = {
            { name = 'Item', value = data.itemLabel or 'Unknown Item', inline = true },
            { name = 'Bid Amount', value = formatMoney(data.bidAmountCents), inline = true },
            { name = 'Bidder', value = data.bidderName or 'Unknown', inline = true },
            { name = 'Previous Bid', value = data.previousBidCents and formatMoney(data.previousBidCents) or 'N/A', inline = true },
            { name = 'Total Bids', value = tostring(data.totalBids or 1), inline = true },
        },
        footer = { text = 'Auction House', icon_url = WebhookConfig.botAvatar },
        timestamp = formatTimestamp(),
    }
end

function EmbedBuilders.auctionWon(data)
    return {
        title = 'Auction Won!',
        color = 3066993,
        fields = {
            { name = 'Item', value = string.format('%s x%d', data.itemLabel or data.itemName, data.count or 1), inline = true },
            { name = 'Final Price', value = formatMoney(data.finalPriceCents), inline = true },
            { name = 'Winner', value = data.winnerName or 'Unknown', inline = true },
            { name = 'Seller', value = data.sellerName or 'Unknown', inline = true },
            { name = 'Total Bids', value = tostring(data.totalBids or 0), inline = true },
        },
        footer = { text = 'Auction House', icon_url = WebhookConfig.botAvatar },
        timestamp = formatTimestamp(),
    }
end

function EmbedBuilders.auctionBuyout(data)
    return {
        title = 'Item Purchased via Buyout!',
        color = 5763719,
        fields = {
            { name = 'Item', value = string.format('%s x%d', data.itemLabel or data.itemName, data.count or 1), inline = true },
            { name = 'Buyout Price', value = formatMoney(data.buyoutPriceCents), inline = true },
            { name = 'Buyer', value = data.buyerName or 'Unknown', inline = true },
            { name = 'Seller', value = data.sellerName or 'Unknown', inline = true },
            { name = 'Auction ID', value = data.auctionId or 'N/A', inline = true },
        },
        footer = { text = 'Auction House - Buyout', icon_url = WebhookConfig.botAvatar },
        timestamp = formatTimestamp(),
    }
end

function EmbedBuilders.auctionExpired(data)
    return {
        title = 'Auction Expired',
        color = 15158332,
        fields = {
            { name = 'Item', value = string.format('%s x%d', data.itemLabel or data.itemName, data.count or 1), inline = true },
            { name = 'Starting Bid', value = formatMoney(data.startingBidCents), inline = true },
            { name = 'Seller', value = data.sellerName or 'Unknown', inline = true },
            { name = 'Reason', value = 'No bids placed', inline = false },
        },
        footer = { text = 'Auction House', icon_url = WebhookConfig.botAvatar },
        timestamp = formatTimestamp(),
    }
end

function EmbedBuilders.auctionCancelled(data)
    return {
        title = 'Auction Cancelled',
        color = 10038562,
        fields = {
            { name = 'Item', value = string.format('%s x%d', data.itemLabel or data.itemName, data.count or 1), inline = true },
            { name = 'Starting Bid', value = formatMoney(data.startingBidCents), inline = true },
            { name = 'Seller', value = data.sellerName or 'Unknown', inline = true },
            { name = 'Reason', value = data.reason or 'Cancelled by seller', inline = false },
        },
        footer = { text = 'Auction House', icon_url = WebhookConfig.botAvatar },
        timestamp = formatTimestamp(),
    }
end

function EmbedBuilders.highValueSale(data)
    return {
        title = 'High Value Sale!',
        color = 15844367,
        fields = {
            { name = 'Item', value = string.format('%s x%d', data.itemLabel or data.itemName, data.count or 1), inline = true },
            { name = 'Final Price', value = formatMoney(data.finalPriceCents or data.buyoutPriceCents), inline = true },
            { name = 'Winner', value = data.winnerName or data.buyerName or 'Unknown', inline = true },
            { name = 'Seller', value = data.sellerName or 'Unknown', inline = true },
        },
        footer = { text = 'Auction House - High Value Alert', icon_url = WebhookConfig.botAvatar },
        timestamp = formatTimestamp(),
    }
end

-- ============================================
-- HTTP REQUEST
-- ============================================

local function sendWebhookRequest(url, payload, retryCount)
    retryCount = retryCount or 0
    
    PerformHttpRequest(url, function(errorCode, resultData, resultHeaders)
        if errorCode >= 200 and errorCode < 300 then
            if Config and Config.Debug then
                print('[Webhook] Successfully sent webhook')
            end
        else
            local errorMsg = string.format('HTTP %d: %s', errorCode, resultData or 'Unknown error')
            print('[Webhook] Failed to send: ' .. errorMsg)
            
            -- Retry logic
            if retryCount < WebhookConfig.maxRetries then
                print(string.format('[Webhook] Retrying (%d/%d)...', retryCount + 1, WebhookConfig.maxRetries))
                SetTimeout(WebhookConfig.retryDelay, function()
                    sendWebhookRequest(url, payload, retryCount + 1)
                end)
            else
                print('[Webhook] Max retries reached, giving up')
                -- Log to file for later review
                -- Append (SaveResourceFile overwrites, so the log previously only ever held the last error)
                local resource = GetCurrentResourceName()
                local existing = LoadResourceFile(resource, 'webhook_errors.log') or ''
                local logEntry = string.format('[%s] FAILED WEBHOOK: %s\n', os.date('%Y-%m-%d %H:%M:%S'), errorMsg)
                SaveResourceFile(resource, 'webhook_errors.log', existing:sub(-50000) .. logEntry, -1)
            end
        end
    end, 'POST', json.encode(payload), {
        ['Content-Type'] = 'application/json'
    })
end

-- ============================================
-- PUBLIC API
-- ============================================

function SendWebhook(eventType, data)
    -- Check if webhook is enabled for this event type
    if not isWebhookEnabled(eventType) then
        if Config and Config.Debug then
            print(string.format('[Webhook] Event type "%s" is disabled or has no URL configured', eventType))
        end
        return false
    end
    
    -- Get webhook URL
    local url = getWebhookUrl(eventType)
    if not url then
        print('[Webhook] No URL configured for event type: ' .. eventType)
        return false
    end
    
    -- Build embed
    local builder = EmbedBuilders[eventType]
    if not builder then
        print('[Webhook] No embed builder for event type: ' .. eventType)
        return false
    end
    
    local embed = builder(data)
    if not embed then
        print('[Webhook] Failed to build embed for event type: ' .. eventType)
        return false
    end
    
    -- Construct payload
    local payload = {
        username = WebhookConfig.botName,
        avatar_url = WebhookConfig.botAvatar,
        embeds = { embed }
    }
    
    -- Send webhook
    sendWebhookRequest(url, payload)

    -- Check for high value sale (auctionWon or auctionBuyout)
    local finalPriceCents = nil
    if eventType == 'auctionWon' then
        finalPriceCents = data.finalPriceCents
    elseif eventType == 'auctionBuyout' then
        finalPriceCents = data.buyoutPriceCents
    end

    if finalPriceCents and finalPriceCents >= (WebhookConfig.highValueThreshold * 100) then
        if isWebhookEnabled('highValueSale') then
            local highValueUrl = getWebhookUrl('highValueSale')
            if highValueUrl then
                sendWebhookRequest(highValueUrl, {
                    username = WebhookConfig.botName,
                    avatar_url = WebhookConfig.botAvatar,
                    embeds = { EmbedBuilders.highValueSale(data) }
                })
            end
        end
    end
    
    return true
end

-- Configure webhook URL at runtime
local function SetWebhookUrl(eventType, url)
    -- Validate URL
    local valid, err = isValidWebhookUrl(url)
    if not valid then
        return false, err or Locale('error_invalid_webhook_url')
    end
    
    if eventType == 'default' then
        WebhookConfig.defaultUrl = url
    elseif WebhookConfig.enabled[eventType] ~= nil then
        WebhookConfig.urls[eventType] = url
    else
        return false, Locale('error_webhook_config_invalid')
    end
    return true
end

-- Get current webhook configuration
local function GetWebhookConfig()
    return {
        defaultUrl = WebhookConfig.defaultUrl,
        urls = WebhookConfig.urls,
        enabled = WebhookConfig.enabled,
        highValueThreshold = WebhookConfig.highValueThreshold,
    }
end

-- Toggle webhook for event type
local function ToggleWebhook(eventType, enabled)
    if WebhookConfig.enabled[eventType] ~= nil then
        WebhookConfig.enabled[eventType] = enabled
        return true
    end
    return false, Locale('error_webhook_config_invalid')
end

-- Drop any invalid URLs from the config at startup
for eventType, url in pairs(WebhookConfig.urls) do
    if not isValidWebhookUrl(url) then
        print(('[Webhook] ^3Ignoring invalid URL for %s^7'):format(eventType))
        WebhookConfig.urls[eventType] = nil
    end
end
if WebhookConfig.defaultUrl and not isValidWebhookUrl(WebhookConfig.defaultUrl) then
    print('[Webhook] ^3Ignoring invalid default URL^7')
    WebhookConfig.defaultUrl = nil
end

-- ============================================
-- ADMIN COMMANDS
-- ============================================

-- Console is always allowed; players need rsg-core 'admin' permission.
local function isAdmin(source)
    if source == 0 or RSGCore.Functions.HasPermission(source, 'admin') then return true end
    TriggerClientEvent('auction:client:webhookResult', source, {
        success = false,
        message = Locale('error_permission_denied')
    })
    return false
end

-- Set webhook URL command (admin only)
RegisterCommand('auctionwebhook', function(source, args, rawCommand)
    if not isAdmin(source) then return end
    
    if #args < 2 then
        local helpMsg = Locale('cmd_webhook_usage_title') .. '\n'
            .. Locale('cmd_webhook_usage_events') .. '\n'
            .. Locale('cmd_webhook_event_default') .. '\n'
            .. Locale('cmd_webhook_event_created') .. '\n'
            .. Locale('cmd_webhook_event_bid') .. '\n'
            .. Locale('cmd_webhook_event_won') .. '\n'
            .. Locale('cmd_webhook_event_expired') .. '\n'
            .. Locale('cmd_webhook_event_cancelled') .. '\n'
            .. Locale('cmd_webhook_event_highvalue') .. '\n'
            .. '\n'
            .. Locale('cmd_webhook_example')
        if source == 0 then
            print(helpMsg)
        else
            TriggerClientEvent('auction:client:webhookResult', source, {
                success = false,
                message = helpMsg
            })
        end
        return
    end
    
    local eventType = args[1]
    local url = args[2]
    
    local success, err = SetWebhookUrl(eventType, url)
    
    if success then
        local msg = Locale('cmd_webhook_set', eventType)
        if source == 0 then
            print('[Webhook] ' .. msg)
        else
            TriggerClientEvent('auction:client:webhookResult', source, {
                success = true,
                message = msg
            })
        end
    else
        err = err or Locale('cmd_webhook_unknown_error')
        if source == 0 then
            print('[Webhook] Error: ' .. err)
        else
            TriggerClientEvent('auction:client:webhookResult', source, {
                success = false,
                message = err
            })
        end
    end
end, false)

-- Toggle webhook command (admin only)
RegisterCommand('auctionwebhooktoggle', function(source, args, rawCommand)
    if not isAdmin(source) then return end
    
    if #args < 2 then
        local msg = Locale('cmd_webhook_usage_toggle')
        if source == 0 then
            print(msg)
        else
            TriggerClientEvent('auction:client:webhookResult', source, {
                success = false,
                message = msg
            })
        end
        return
    end
    
    local eventType = args[1]
    local enabled = args[2]:lower() == 'true'
    
    local success, err = ToggleWebhook(eventType, enabled)
    
    if success then
        local msg = enabled and Locale('cmd_webhook_enabled', eventType) or Locale('cmd_webhook_disabled_str', eventType)
        if source == 0 then
            print('[Webhook] ' .. msg)
        else
            TriggerClientEvent('auction:client:webhookResult', source, {
                success = true,
                message = msg
            })
        end
    else
        err = err or Locale('cmd_webhook_unknown_error')
        if source == 0 then
            print('[Webhook] Error: ' .. err)
        else
            TriggerClientEvent('auction:client:webhookResult', source, {
                success = false,
                message = err
            })
        end
    end
end, false)

-- View webhook status command
RegisterCommand('auctionwebhookstatus', function(source, args, rawCommand)
    if not isAdmin(source) then return end
    
    local config = GetWebhookConfig()
    local statusMsg = Locale('cmd_webhook_status_title') .. '\n'
    statusMsg = statusMsg .. Locale('cmd_webhook_status_default', config.defaultUrl or Locale('cmd_webhook_status_not_configured')) .. '\n'
    statusMsg = statusMsg .. Locale('cmd_webhook_status_threshold', formatMoney(config.highValueThreshold * 100)) .. '\n'
    statusMsg = statusMsg .. Locale('cmd_webhook_status_events') .. '\n'
    
    for eventType, enabled in pairs(config.enabled) do
        local url = config.urls[eventType] or config.defaultUrl
        local urlDisplay = url and Locale('cmd_webhook_status_configured') or Locale('cmd_webhook_status_not_configured')
        local state = enabled and Locale('cmd_webhook_status_on') or Locale('cmd_webhook_status_off')
        statusMsg = statusMsg .. string.format('  %s: %s (%s)\n', eventType, state, urlDisplay)
    end
    
    if source == 0 then
        print(statusMsg)
    else
        TriggerClientEvent('auction:client:webhookResult', source, {
            success = true,
            message = statusMsg
        })
    end
end, false)
