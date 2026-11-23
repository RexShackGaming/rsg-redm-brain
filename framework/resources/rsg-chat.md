# rsg-chat

Version 3.4.0. rsg-chat

**Version 3.4.0** A chat resource for **RedM** servers running **RSG-Core**. It replaces the default chat with channels that admins manage in-game, and a chat window each player can move, resize and style to suit themselves. Every message shows the sender's in-character name, and the server checks each message before sending it to players. - **Admin panel:** `/chatadmin` opens a channel manager. A

Source: https://github.com/Rexshack-RedM/rsg-chat

**Dependencies:** `rsg-core`, `oxmysql`

Has NUI (`ui_page`).

## Exports (call as exports['rsg-chat']:Name)

**server:** `GetChannels()`, `SendChannelMessage(channelId, author, text)`

## Net events registered

**server:** `__cfx_internal:commandFallback`, `_chat:messageEntered`, `chat:server:ServerPSA`, `rsg-chat:server:requestChannels`, `rsg-chat:server:send`

**client:** `RSGCore:Client:OnGangUpdate`, `RSGCore:Client:OnJobUpdate`, `RSGCore:Client:OnPlayerLoaded`, `__cfx_internal:serverPrint`, `chat:addMessage`, `chat:addSuggestion`, `chat:addSuggestions`, `chat:addTemplate`, `chat:clear`, `chat:removeSuggestion`, `chatMessage`, `rsg-chat:client:channelMessage`, `rsg-chat:client:openAdmin`, `rsg-chat:client:syncChannels`

## Event handlers

**server:** `RSGCore:Server:OnGangUpdate`, `RSGCore:Server:OnJobUpdate`, `RSGCore:Server:PlayerLoaded`

**client:** `__cfx_internal:serverPrint`, `chat:addMessage`, `chat:addSuggestion`, `chat:addSuggestions`, `chat:addTemplate`, `chat:clear`, `chat:removeSuggestion`, `chatMessage`

## Callbacks (RSGCore.Functions.CreateCallback)

**server:** `rsg-chat:server:`, `rsg-chat:server:adminGetChannels`

## Commands (RSGCore.Commands.Add)

**server:** `/chatadmin`, `/chatlog`, `/chatmute`, `/chatunmute`

## Commands (RegisterCommand)

**client:** `/channel`, `/chatsettings`, `/clearchat`, `/togglechat`

## Public (table) functions

**server/extras.lua:** `C.CheckMute(src)`, `C.Filter(message, src)`, `C.FindMentions(message, recipients, src)`, `C.Log(src, channel, name, message)`

## Database tables

`rsg_chat_channels`, `rsg_chat_logs`, `rsg_chat_mutes`
