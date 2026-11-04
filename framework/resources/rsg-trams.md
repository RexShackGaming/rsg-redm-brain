# rsg-trams

Version 3.1.1. rsg-trams - Saint Denis trolley network (one trolley per track)

Saint Denis trolleys for RSG Framework, with **one trolley on the Saint Denis loop**. - One networked trolley on the Saint Denis loop (upper and inner tracks removed), with map blips - Only one trolley ever: if a trolley already exists anywhere, no new one is spawned (a lost one is re-adopted)

Source: https://github.com/Rexshack-RedM/rsg-trams

**Dependencies:** `rsg-core`

## Net events registered

**server:** `rsg-trams:server:registerTram`

**client:** `rsg-trams:client:deleteTrain`, `rsg-trams:client:spawnTrack`

## Commands (RSGCore.Commands.Add)

**server:** `/trams`

## Public (table) functions

**client/dataview.lua:** `DataView.ArrayBuffer(length)`, `DataView.Wrap(blob)`, `DataView:Buffer()`, `DataView:ByteLength()`, `DataView:ByteOffset()`, `DataView:SubView(offset)`
