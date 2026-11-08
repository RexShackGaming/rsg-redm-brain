# rsg-telegram

Version 3.1.1. rsg-telegram

Telegram system for RSG Framework (RedM). Send and receive telegrams at any post office, with an address book, a player directory search and an RDR2-styled NUI. - Post offices with blips and a `[J]` prompt (configurable) - Inbox with unread markers, read, reply, save sender and destroy

Source: https://github.com/Rexshack-RedM/rsg-telegram

**Dependencies:** `rsg-core`, `oxmysql`

Has NUI (`ui_page`).

## Net events registered

**server:** `rsg-telegram:server:markRead`

**client:** `rsg-telegram:client:newTelegram`

## Event handlers

**server:** `RSGCore:Server:PlayerLoaded`

## Callbacks (RSGCore.Functions.CreateCallback)

**server:** `rsg-telegram:server:addContact`, `rsg-telegram:server:delete`, `rsg-telegram:server:getContacts`, `rsg-telegram:server:getInbox`, `rsg-telegram:server:removeContact`, `rsg-telegram:server:searchRecipients`, `rsg-telegram:server:send`

## Database tables

`rsg_telegram_contacts`, `rsg_telegrams`
