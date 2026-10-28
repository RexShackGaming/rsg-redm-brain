# rsg-fortuneteller

Version 3.0.0. Fortune teller machines for RSG-Core

Coin-operated fortune teller machines for **RSG-Core** (RedM). Pay at the machine, hand over your cash, and the machine reads you a random fortune using RDR2's own `FTELL` voice lines. Players nearby hear the reading too. - Configured machines spawn and stream in/out by distance. Machines already on the map can be used too (optional). - 72 game fortune lines, plus optional intro lines and your own

Source: https://github.com/Rexshack-RedM/rsg-fortuneteller

**Dependencies:** `rsg-core`, `ox_lib`

Has NUI (`ui_page`).

## Commands (RegisterCommand)

**client:** `/fortunespeech`, `/fortunetest`

## Public (table) functions

**client/dataview.lua:** `DataView.ArrayBuffer(length)`, `DataView.Wrap(blob)`, `DataView:Buffer()`, `DataView:ByteLength()`, `DataView:ByteOffset()`, `DataView:SubView(offset, length)`

**shared/utils.lua:** `Fortune.TotalSeconds(sequence)`, `Fortune.WorldKey(x, y, z)`
