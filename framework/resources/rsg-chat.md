# rsg-chat

Version 3.0.1. rsg-chat

A chat resource for **RedM** servers running **RSG-Core**. It replaces the default chat. Every message shows the sender's in-character name, and the server checks each message before sending it to players. - **Character names:** messages show the sender's character first and last name, falling back to their account name. - **Server-side checks:** the server works out who sent each message and trim

Source: https://github.com/Rexshack-RedM/rsg-chat

**Dependencies:** `rsg-core`, `ox_lib`

Has NUI (`ui_page`).

## Net events registered

**server:** `__cfx_internal:commandFallback`, `_chat:messageEntered`, `chat:server:ServerPSA`

**client:** `__cfx_internal:serverPrint`, `chat:addMessage`, `chat:addSuggestion`, `chat:addSuggestions`, `chat:addTemplate`, `chat:clear`, `chat:removeSuggestion`, `chatMessage`

## Event handlers

**client:** `__cfx_internal:serverPrint`, `chat:addMessage`, `chat:addSuggestion`, `chat:addSuggestions`, `chat:addTemplate`, `chat:clear`, `chat:removeSuggestion`, `chatMessage`

## Commands (RegisterCommand)

**server:** `/clearchat`, `/ooc`

## Server events it triggers in other resources

**client:** `_chat:messageEntered`
