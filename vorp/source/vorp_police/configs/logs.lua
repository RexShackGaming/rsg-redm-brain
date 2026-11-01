local Logs = {
    Webhook       = "",       -- add webhook for all other Police logs URL here
    StorageWebook = "",       -- add Storage webhook URL here
    DutyWebhook   = "",       -- add Duty webhook URL here
    JailWebhook   = "",       -- add Jail webhook URL here
    Namelogs      = "Police logs",
    color         = 16711680, -- color for webhook embeds, defaults to VORP core config if not set
    logo          = "",       -- logo URL for webhook embeds, defaults to VORP core config
    footerLogo    = "",       -- footer logo URL for webhook embeds, defaults to VORP core config
    Avatar        = "",       -- avatar URL for webhook embeds, defaults to VORP core config
    Lang          = {
        Steam          = "Steam: ",
        Identifier     = "Identifier: ",
        PlayerID       = "Player ID: ",
        Job            = "Job",
        PlayerName     = "Player Name: ",
        Jobfired       = "Officer Fired: ",
        JobHired       = "Officer Hired: ",
        JobOnDuty      = "Officer On Duty: ",
        JobOffDuty     = "Officer Off Duty: ",
        FiredPlayer    = "Fired Player: ",
        HiredPlayer    = "Hired Player: ",
        FiredBy        = "Fired By: ",
        HiredBy        = "Hired By: ",
        JailledEvent   = "Jailed: ",
        UnjailEvent    = "Unjailed: ",
        Adjusted       = "Jail Time Adjusted",
        FromJob        = "From Job: ",
        JailedPlayer   = "Jailed Player: ",
        JailedBy       = "Jailed By: ",
        JailTime       = "Jail Time (minutes): ",
        UnjailedPlayer = "Unjailed Player: ",
        JailTimeChange = "Time Change (minutes): ",
        NewTimeLeft    = "New Time Left (minutes): ",
        JailCompleted  = "Jail Sentence Completed: ",
        ReleasedPlayer = "Released Player: ",
        ReleasedByTime = "Released Automatically after Time Served",
    },
}

return {
    Logs = Logs
}
