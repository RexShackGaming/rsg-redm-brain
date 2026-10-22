# Game events (event queue)

Poll with `GetNumberOfEvents(group)` / `GetEventAtIndex(group, i)`. Read data with GET_EVENT_DATA `Citizen.InvokeNative(0x57EC5FA4D4D6AFCA, group, i, buf, size)` using a DataView buffer of `8*size` bytes, where each field sits at an 8-byte offset. The size must be exact, or the call fails. Group 0 = SCRIPT_EVENT_QUEUE_AI, 1 = network.

| Event | Grp | Size | Key fields |
|---|---|---|---|
| EVENT_ENTITY_DAMAGED | 0 | 9 | 0 victim, 1 attacker, 2 weapon, 3 ammo, 4 dmg(f), 6-8 xyz(f) |
| EVENT_NETWORK_DAMAGE_ENTITY | 1 | 32 | 0 victim, 1 killer, 2 dmg, 3 destroyed, 5 weapon, 11 headshot, 17 hogtied |
| EVENT_LOOT_COMPLETE | 0 | 3 | 0 looter, 1 looted, 2 success |
| EVENT_CALCULATE_LOOT | 0 | 26 | 2 item hash, 23 looter, 24 looted |
| EVENT_LOOT_PLANT_START | 0 | 36 | 26 looter, 27 looted, 29 composite hash |
| EVENT_CARRIABLE_UPDATE_CARRY_STATE (1208357138) | 0 | 5 | 0 carriable, 1 perpetrator, 2 carrier, 3 onHorse, 4 onGround |
| EVENT_PLAYER_PROMPT_TRIGGERED | 0 | 10 | 0 prompt type, 2 target, 4-6 xyz |
| EVENT_PLAYER_COLLECTED_AMBIENT_PICKUP | 0 | 8 | 0 pickup hash, 3 model, 6 qty, 7 item hash |
| EVENT_HORSE_BROKEN | 0 | 3 | 0 rider, 1 horse, 2 type |
| EVENT_PED_CREATED | 0 | 1 | 0 ped |
| EVENT_PED_WHISTLE | 0 | 2 | 0 whistler, 1 whistle type |

Any other event: fetch `ai/EVENTS/README.md`, which lists them all.
