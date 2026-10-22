# rsg-telegram

Version 3.0.0. rsg-telegram

Source: https://github.com/Rexshack-RedM/rsg-telegram

**Dependencies:** `rsg-core`, `ox_lib`, `oxmysql`

Has NUI (`ui_page`).

## Net events registered

**server:** `rsg-telegram:server:markRead`

**client:** `rsg-telegram:client:newTelegram`

## Event handlers

**server:** `RSGCore:Server:PlayerLoaded`

## Callbacks (lib.callback)

**server:** `rsg-telegram:server:addContact`, `rsg-telegram:server:delete`, `rsg-telegram:server:getContacts`, `rsg-telegram:server:getInbox`, `rsg-telegram:server:removeContact`, `rsg-telegram:server:searchRecipients`, `rsg-telegram:server:send`

## Database tables

`rsg_telegram_contacts`, `rsg_telegrams`
