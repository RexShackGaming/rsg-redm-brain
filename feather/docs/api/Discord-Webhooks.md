---
title: REVIEW — Discord Webhooks
---


# Discord Webhooks

This API allows you to easily add [Discord webhooks](https://support.discord.com/hc/en-us/articles/228383668-Intro-to-Webhooks) messages to your scripts.

## Send One Time Message

```lua

-- (webhookurl, webhookname, webhookavatar, name, description, embeds)
FeatherCore.Discord.sendMessage('webhookurl', 'My Script', 'https://cdn2.iconfinder.com/data/icons/frosted-glass/256/Danger.png', 'user123', 'this user is awesome')
```

## Create Discord Re-usable instance

```lua
-- (webhookurl, webhookname, webhookavatar)
local discord = FeatherCore.Discord.setup('webhookurl', 'My Script', 'https://cdn2.iconfinder.com/data/icons/frosted-glass/256/Danger.png')

-- (name, description, embeds)
discord:sendMessage('user123', 'this user is awesome')

discord:sendMessage('user456', 'this user is ALSO awesome')

discord:sendMessage('user789', 'this user kinda really awesome', {
    {
        color = 11342935,
        title = 'Embed Item 1',
        description = 'Items awesome description?'
    },
    {
        color = 11342935,
        title = 'Embed Item 2',
        description = 'Item 2 awesome description!'
    },
})

```
