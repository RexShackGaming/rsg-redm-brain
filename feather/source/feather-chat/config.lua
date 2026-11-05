Config = {
    DevMode = false,
    Input = {
        command = 'chat',
        defaultKey = 'T',
        closeOnSubmit = true
    },
    Channels = {
        oocEnabled = false,
        proximity = { whisper=3.0, say=15.0, roleplay=15.0, shout=35.0 }
    },
    Limits = {
        maxMessageBytes = 500,
        maxMessageLines = 4,
        maxClientBuffer = 100,
        maxInputHistory = 20,
        callbackTimeoutMs = 5000
    },
    RateLimit = {
        windowMs = 10000,
        maxMessages = 5,
        repeatedWindowMs = 15000,
        maxRepeatedMessages = 2,
        channelProfiles = {
            ['local.whisper'] = { windowMs=10000, maxMessages=6 },
            ['local.say'] = { windowMs=10000, maxMessages=5 },
            ['local.shout'] = { windowMs=15000, maxMessages=3 },
            ['roleplay.me'] = { windowMs=10000, maxMessages=5 },
            ['roleplay.do'] = { windowMs=10000, maxMessages=5 }
        }
    },
    Moderation = {
        mutes = {
            enabled = true,
            allowedScopes = { 'all', 'channel', 'ooc' },
            permanentAllowed = false,
            maximumDurationMinutes = 10080,
            persistenceRequired = true
        },
        playerControls = {
            ignoreEnabled = true,
            ignoreSubjectScope = 'account',
            maximumIgnoredSubjects = 100
        },
        staffBypass = {
            system = true,
            moderation = true,
            staffChannel = true,
            staffCase = true,
            ordinaryPlayerChat = false
        },
        providers = { enabled=false, required=false, maximumRegistered=8 },
        trustedCallers = { ['feather-admin']=true },
        audit = { enabled=true, includeMessageBody=false }
    },
    Layout = {
        anchor = 'top-left',
        widthVw = 38,
        maxHeightVh = 28,
        density = 'comfortable',
        fadeDelayMs = 7000,
        idleOpacity = 0.75,
        timestamps = true,
        fontScale = 1.0,
        reducedMotion = false
    },
    Theme = {
        default = 'feather.default',
        approved = { 'feather.default', 'feather.high_contrast' }
    },
    Preferences = {
        theme = true,
        density = true,
        timestamps = true,
        reducedMotion = true,
        fontScale = { enabled=true, minimum=0.75, maximum=1.5, step=0.05 },
        idleOpacity = { enabled=true, minimum=0.2, maximum=1.0, step=0.05 }
    },
    Features = { history=false, privateMessages=false, emojiPicker=false }
}
