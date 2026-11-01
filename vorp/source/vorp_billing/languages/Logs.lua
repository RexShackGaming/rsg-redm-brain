local Logs = {
    Webhook    = "",          -- add webhook for all other Police logs URL here
    Namelogs   = "Billing",
    color      = 16711680,    -- color for webhook embeds, defaults to VORP core config if not set
    logo       = "",          -- logo URL for webhook embeds, defaults to VORP core config
    footerlogo = "",          -- footer logo URL for webhook embeds, defaults to VORP core config
    avatar     = "",          -- avatar URL for webhook embeds, defaults to VORP core config

    Lang = {
        BillSent     = "Bill Sent: ",
        BilledPlayer = "Billed Player: ",
        BilledBy     = "Billed By: ",
        BillAmount   = "Amount: ",
        BillReason   = "Reason: ",
        OfficerSteam = "Officer Steam Name: ",
        OfficerID    = "Officer Identifier: ",
        TargetSteam  = "Billed Player Steam Name: ",
        TargetID     = "Billed Player Identifier: "

    }
}

return {
    Logs = Logs
}
