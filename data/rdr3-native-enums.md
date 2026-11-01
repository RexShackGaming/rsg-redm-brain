# RDR3 Native Flags and Enums

Repo: https://github.com/Halen84/RDR3-Native-Flags-And-Enums (by **Halen84**)
Local copy: `data/rdr3-native-enums/` (63 enums, one `<Enum>.md` each, plus `INDEX.tsv`). Rebuilt by `tools/refresh.sh` via `tools/build_enums.py`.

Each file lists the **natives that take the enum** (name + hash) and the full C++ enum with its integer values. Use it whenever a native takes a flag/enum int: never pass a bare magic number without looking it up here.

## How to search
```bash
# Which enum does a native take?
rg -i "SET_PED_CONFIG_FLAG" data/rdr3-native-enums/INDEX.tsv
# Find a specific flag/value by name
rg -n "PCF_DisableMelee|Knockedout" data/rdr3-native-enums/
# Open one enum (files are small)
cat data/rdr3-native-enums/ePedScriptConfigFlags.md
```

## Most useful for RSG scripts
| Enum | Used with |
|---|---|
| `ePedScriptConfigFlags` / `ePedScriptResetFlags` | `SetPedConfigFlag` / `SetPedResetFlag` |
| `Combat__Attribute__Enum`, `eCombatAttributeFloats`, `CCombatData__*` | Combat attributes, ability, movement, range |
| `eRelationType` | `SetRelationshipBetweenGroups` |
| `eFleeStyle`, `PedFilterFlags`, `CLawBehavior__Flags` | Flee tasks, law response |
| `eScriptedAnimFlags`, `eIkControlFlags`, `eAnimSceneFlag` | `TaskPlayAnim`, anim scenes |
| `ePromptType`, `ePromptPriority`, `eUIPromptAttribute` | UI prompts (`patterns/`, `natives/prompts-blips-entities.md`) |
| `eHudContext`, `eHudVisibilitySlotType`, `eUIFeedChannel` | HUD hiding, feeds |
| `eDoorId`, `DoorScriptState` | Door system (pairs with rsg-doorlock) |
| `eEnterExitVehicleFlags`, `eSetPlayerControlFlags`, `CCarryingFlags__Flags`, `CLassoHogtieFlags__Flags`, `CLootingFlags__Flags` | Vehicles/horses, control, carrying, lasso, looting |
| `eTaskType`, `eEventType`, `eExplosionTag`, `eMetaPedType` | Task checks, events, explosions, metaped |

Bit-flag enums (values like `1 << n`) are combined with `|` in Lua 5.4. Cross-check hashes with `natives/db/INDEX.tsv`; for AI flags also see `data/rdr3_discoveries/AI/`.
