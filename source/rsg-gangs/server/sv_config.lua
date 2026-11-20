-- Server-only settings (this file is never sent to players, so the webhook URL stays private).
SvConfig = {}

-- Discord webhook for gang activity. Leave Url empty or Enabled = false to turn it off.
SvConfig.Webhook = {
    Enabled = false,
    Url = '',
    Name = 'rsg-gangs',
    -- Only these log actions are posted. Remove the table (set to nil) to post every action.
    Actions = {
        created = true, territory_claim = true, territory_abandon = true, raid_won = true, raid_lost = true,
        raid_defended = true, bounty_post = true, bounty_paid = true, upkeep_missed = true, rival_kill = true,
    },
}
