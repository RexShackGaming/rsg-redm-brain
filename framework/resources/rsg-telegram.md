# rsg-telegram

Version 3.2.0. rsg-telegram

Telegram system for RSG Framework (RedM). Send and receive telegrams at any post office, with an address book, a player directory search and an RDR2-styled NUI. - Post offices with blips and a `[J]` prompt (configurable) - Inbox with unread markers, read, reply, save sender and destroy, plus **Mark all read** and **Destroy read**

Source: https://github.com/Rexshack-RedM/rsg-telegram

**Dependencies:** `rsg-core`, `rsg-inventory`, `oxmysql`

Has NUI (`ui_page`).

## Exports (call as exports['rsg-telegram']:Name)

**server:** `AddContact(citizen, contact, nickname)`, `BlockCitizen(citizen, target)`, `DeleteReadTelegrams(citizen)`, `DeleteTelegram(citizen, id)`, `GetBlocked(citizen)`, `GetContacts(citizen)`, `GetSentTelegrams(citizen, limit)`, `GetTelegrams(citizen, opts)`, `GetUnreadCount(citizen)`, `IsBlocked(citizen, sender)`, `MarkRead(citizen, id)`, `OpenTelegrams(src, opts)`, `RemoveContact(citizen, contact)`, `SendTelegram(recipient, subject, message, opts)`, `UnblockCitizen(citizen, target)`

**client:** `Close()`, `IsOpen()`

## Net events registered

**server:** `rsg-telegram:server:closed`, `rsg-telegram:server:markRead`

**client:** `rsg-telegram:client:newTelegram`, `rsg-telegram:client:open`

## Event handlers

**server:** `RSGCore:Server:PlayerLoaded`

## Callbacks (RSGCore.Functions.CreateCallback)

**server:** `rsg-telegram:server:addContact`, `rsg-telegram:server:block`, `rsg-telegram:server:collect`, `rsg-telegram:server:delete`, `rsg-telegram:server:deleteRead`, `rsg-telegram:server:getAttachables`, `rsg-telegram:server:getBlocked`, `rsg-telegram:server:getContacts`, `rsg-telegram:server:getInbox`, `rsg-telegram:server:getSent`, `rsg-telegram:server:markAllRead`, `rsg-telegram:server:removeContact`, `rsg-telegram:server:searchRecipients`, `rsg-telegram:server:send`, `rsg-telegram:server:unblock`

## Database tables

`rsg_telegram_blocks`, `rsg_telegram_contacts`, `rsg_telegrams`
