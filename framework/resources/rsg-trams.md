# rsg-trams

Version 3.0.1. rsg-trams - Saint Denis trolley network

Saint Denis trolleys for RSG Framework. - Networked Saint Denis trolleys that every player sees, with map blips - Speeds, spawn points and station stops taken from Rockstar's ambient trolley code

Source: https://github.com/Rexshack-RedM/rsg-trams

**Dependencies:** `rsg-core`, `ox_lib`

## Net events registered

**server:** `rsg-trams:server:registerTram`

**client:** `rsg-trams:client:deleteTrain`, `rsg-trams:client:spawnLine`

## Public (table) functions

**client/dataview.lua:** `DataView.ArrayBuffer(length)`, `DataView.Wrap(blob)`, `DataView:Buffer()`, `DataView:ByteLength()`, `DataView:ByteOffset()`, `DataView:SubView(offset)`
