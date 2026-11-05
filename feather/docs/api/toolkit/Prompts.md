---
title: Prompts
---

# Toolkit Prompts

```lua
exports['feather-toolkit']:CreatePrompt(spec) -> Result<{ id, handle }>
exports['feather-toolkit']:ShowPromptGroup(groupId, label) -> Result
exports['feather-toolkit']:IsPromptCompleted(id) -> Result<{ completed }>
exports['feather-toolkit']:SetPromptEnabled(id, enabled) -> Result
exports['feather-toolkit']:RemovePrompt(id) -> Result
```

```lua
local prompt = exports['feather-toolkit']:CreatePrompt({
  control = 0x8CC9CD42,
  label = 'Open storage',
  groupId = joaat('wagon-storage'),
  mode = 'hold',
  enabled = true,
  visible = true
})
```

`control` and `groupId` must be numeric hashes. Use `ResolveControl` first when starting from a Toolkit control name.

Prompt handles belong to the creating resource and are cleaned up automatically when it stops.
