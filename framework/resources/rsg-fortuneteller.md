# rsg-fortuneteller

Version 3.0.1. Fortune teller machines for RSG-Core

Coin-operated fortune teller machines for **RSG Framework** (RedM). Pay at the machine, hand over cash, and the machine reads a random fortune using RDR2 `FTELL` voice lines. Nearby players hear the reading too. - Configured machines stream in/out by distance; map-placed machines can also be used - 72 game fortune lines, optional intro lines, and custom `.ogg` files

Source: https://github.com/Rexshack-RedM/rsg-fortuneteller

**Dependencies:** `rsg-core`, `rsg-target`

Has NUI (`ui_page`).

## Commands (RegisterCommand)

**client:** `/fortunespeech`, `/fortunetest`

## Public (table) functions

**client/dataview.lua:** `DataView.ArrayBuffer(length)`, `DataView.Wrap(blob)`, `DataView:Buffer()`, `DataView:ByteLength()`, `DataView:ByteOffset()`, `DataView:SubView(offset, length)`

**shared/utils.lua:** `Fortune.TotalSeconds(sequence)`, `Fortune.WorldKey(x, y, z)`
