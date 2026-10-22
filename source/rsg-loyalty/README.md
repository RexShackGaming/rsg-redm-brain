# rsg-loyalty

A comprehensive loyalty points system for RedM/RSG Framework servers. Players earn loyalty points through gameplay and redeem them for cash or items at NPC loyalty store locations.

## Features

- **Automatic Point Earning**: Players earn points passively (configurable per-minute rate) after minimum playtime
- **Session Caps & Cooldowns**: Prevents farming with per-session limits and earn cooldowns
- **NPC Store Locations**: Redeem points at configurable NPC vendors across the map
- **Cash & Item Rewards**: Configurable reward catalog with images and pricing
- **Leaderboard**: NUI-based top players leaderboard (current & lifetime points)
- **Admin Tools**: Award/remove/check points with rate limiting and player notifications
- **Export API**: Other resources can read/write loyalty points via secure exports
- **Discord Logging**: Webhook-based logging for all loyalty events (configurable per event)
- **Security**: Atomic SQL point operations, inventory re-checks on redemption, export allowlist, rate-limited events
- **Localization**: Full locale support via ox_lib (English included)

## Installation

### Prerequisites
- RSG Framework (rsg-core)
- ox_lib
- ox_mysql
- rsg-inventory (for item images)

### Setup Steps

1. **Extract to Resources**
   ```
   Extract rsg-loyalty folder to your resources directory
   ```

2. **Start Resource**
   Add to your server.cfg:
   ```
   ensure rsg-loyalty
   ```
   The script automatically creates the `rsg_loyalty` table on first start via oxmysql — no manual SQL import is required. The SQL file in `installation/rsg_loyalty.sql` is kept only as a reference/fallback if you prefer to run it manually.

4. **Configure Discord Webhook** (Optional)
   Set your webhook URL in `server/config.lua`:
   ```lua
   Config.Discord.WebhookURL = 'YOUR_WEBHOOK_URL'
   ```

## Configuration

Settings are in `shared/config.lua`. Sensitive values (Discord webhook URL) go in `server/config.lua` (never sent to clients).

### Enable / Disable
```lua
Config.Enabled = true              -- master switch for the whole resource
Config.Loyalty.EnableEarning = true -- passive playtime points only
Config.Loyalty.RequireMovement = true -- anti-AFK: must move between ticks
Config.Loyalty.MinMoveDistance = 5.0  -- metres per ~1 minute tick
```
With `Config.Enabled = false` nothing runs (no NPCs, blips, store, earning, commands, webhooks; mutation exports return false). Saved points are kept. Restart the resource after changing.

### Loyalty Points Settings
```lua
Config.Loyalty = {
    PointsPerMinute = 1,              -- Points earned per minute
    MaxPointsPerSession = 500,        -- Max points per session
    MinPlaytimeBeforeEarning = 60,    -- Seconds before earning starts
    MaxAdminAwardPoints = 10000,      -- Max points per admin award
}
```

### Reward Configuration

#### Cash Rewards
```lua
Config.CashRewards = {
    {
        label = 'Reward Name',
        points = 500,                 -- Points required
        amount = 50,                  -- Cash amount given
        image = 'dollar.png'
    },
}
```

#### Item Rewards
```lua
Config.ItemRewards = {
    {
        label = 'Item Name',
        points = 1000,                -- Points required
        item = 'item_name',           -- Item identifier
        amount = 1,                   -- Quantity given
        image = 'item_name.png'
    },
}
```

### UI Settings
```lua
Config.UI = {
    OpenCommand = 'loyalty',          -- Command to open menu
    EnableCommand = false,            -- Enable/disable command
    NotificationDuration = 5000,      -- Notification duration (ms)
}
```

### Export Security
```lua
Config.Exports = {
    AllowedResources = {},            -- Resources allowed to use mutation exports
    AllowAllResources = false,        -- Set to true to allow all (INSECURE)
}
```

### Discord Integration
```lua
Config.Discord.EnableWebhooks = true  -- Enable Discord logging
Config.Discord.LogEvents = {
    PointsEarned = false,             -- Log points earned
    RedemptionSuccess = true,         -- Log successful redemptions
    RedemptionFailed = true,          -- Log failed redemptions
    AdminPointAward = true,           -- Log admin awards/removals
}
```

### NPC Locations
Configure NPC vendors in `Config.LoyaltyLocations` (coords, model, blip, scenario per location).

## Commands

### Player Commands
- `/loyalty` - Open the loyalty menu (configurable in `Config.UI.OpenCommand`)

### Admin Commands
- `/awardloyalty [playerid] [amount]` - Award points to a player
- `/removeloyalty [playerid] [amount]` - Remove points from a player
- `/checkloyalty [playerid]` - Check a player's points

## Exports (for other resources)

```lua
local points = exports['rsg-loyalty']:getLoyaltyPoints(citizenid)
local lifetime = exports['rsg-loyalty']:getLifetimeLoyaltyPoints(citizenid)
local success = exports['rsg-loyalty']:addLoyaltyPoints(citizenid, points)    -- restricted
local success = exports['rsg-loyalty']:removeLoyaltyPoints(citizenid, points) -- restricted
```

Mutation exports (`addLoyaltyPoints`, `removeLoyaltyPoints`) are restricted via `Config.Exports.AllowedResources`.

## Database Schema

```sql
CREATE TABLE IF NOT EXISTS `rsg_loyalty` (
    `id` INT NOT NULL AUTO_INCREMENT,
    `citizenid` VARCHAR(50) NOT NULL UNIQUE,
    `charname` VARCHAR(50) NOT NULL,
    `loyalty_points` INT NOT NULL DEFAULT 0,
    `lifetime_points` INT NOT NULL DEFAULT 0,
    `last_update` TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    PRIMARY KEY (`id`),
    KEY `citizenid_idx` (`citizenid`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
```

## Troubleshooting

### Discord Events Not Sending
- Verify `Config.Discord.EnableWebhooks` is `true` and the specific event is enabled in `Config.Discord.LogEvents`
- Confirm the webhook URL is set in `server/config.lua` and is valid
- Check server console for error messages

### Points Not Earning
- Verify `MinPlaytimeBeforeEarning` has passed
- Check the player hasn't hit `MaxPointsPerSession`
- Verify player is actively in-game

### Redemption Failures
- Ensure player has sufficient points and inventory space (for items)
- Verify reward is properly configured and rsg-inventory is running
