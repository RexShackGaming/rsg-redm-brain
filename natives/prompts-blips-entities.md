# Prompts, blips, entities

## Prompts pattern

```lua
local prompt
do
    PromptRegisterBegin()
    PromptSetControlAction(0, `INPUT_CONTEXT`)
    PromptSetText(0, CreateVarString(10, "LITERAL_STRING", "Open Shop"))
    PromptSetStandardMode(0, true)   -- or PromptSetHoldMode(0, true) + PromptSetHoldTime(0, 1500)
    PromptSetEnabled(0, false); PromptSetVisible(0, false)
    prompt = PromptRegisterEnd()
end
-- In a distance-gated loop: PromptSetEnabled/Visible(prompt, near),
-- then IsControlJustReleased(0, `INPUT_CONTEXT`) or PromptHasHoldModeCompleted(prompt).
-- Grouped prompts: PromptSetGroup(0, groupId) at register; call UiPromptSetActiveGroupThisFrame each tick.
AddEventHandler("onResourceStop", function(r)
    if r == GetCurrentResourceName() then PromptDelete(prompt) end
end)
```

Every `PromptRegisterBegin` needs exactly one `PromptRegisterEnd`. Register once, not per frame.

## Entity and blip hygiene

- Request the model (`RequestModel` then wait for `HasModelLoaded`), spawn it, then `SetModelAsNoLongerNeeded`. Track every handle in a table and delete them all on resource stop.
- Blips: `BlipAddForCoords(styleHash, x, y, z)` (0x554D9D53F696D002), `SetBlipSprite`, `BlipAddModifier` for colour, `RemoveBlip` on stop. Look up style and modifier hashes in `useful_info_from_rpfs/`.
- Spawn networked entities on the server where possible, and share them via netId and state bags.

rsg-core also has prompt helpers (createPrompt etc.). See framework/rsg-core.md.
