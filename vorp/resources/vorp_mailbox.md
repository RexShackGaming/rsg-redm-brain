# vorp_mailbox

Version 1.0. A mailbox script for vorp core framework

Telegram script for VORP Core. With this script you can send a mail to a specific player or you can send a broadcast to all players. - Add `ensure vorp_mailbox` to your `server.cfg`/ `Resources.cfg` file - Run the `SQL` provided for database

Source: https://github.com/VORPCORE/vorp_mailbox

Has NUI (`ui_page`).

## Net events registered

**client:** `mailbox:receiveBroadcast`, `mailbox:receiveMessage`, `mailbox:setMessages`, `mailbox:setUsers`

## Event handlers

**server:** `mailbox:broadcastMessage`, `mailbox:getMessages`, `mailbox:getUsers`, `mailbox:sendMessage`, `mailbox:updateMessages`

**client:** `mailbox:receiveBroadcast`, `mailbox:receiveMessage`, `mailbox:setMessages`, `mailbox:setUsers`

## Server events it triggers in other resources

**client:** `mailbox:broadcastMessage`, `mailbox:getMessages`, `mailbox:getUsers`, `mailbox:sendMessage`, `mailbox:updateMessages`

## Public (table) functions

**client/client.lua:** `table.find(f, l)`

**client/json.lua:** `json.encode(val)`, `json.decode(str)`

## Database tables

`mailbox_mails`
