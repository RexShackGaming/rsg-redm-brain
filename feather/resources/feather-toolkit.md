# feather-toolkit

Version 0.3.0. Owned, reusable client utility contracts for Feather Framework

Reusable, client-side utility contracts for future Feather resources. Toolkit uses named exports, result envelopes, bounded model loading, per-resource ownership, and automatic cleanup. Contract 1 includes models, bounded animation-dictionary loading, objects, peds, blips, named control resolution, key listeners, prompts, 2D/3D text, clipboard access, and queued progress UI. Teleport, horses, and 

Source: https://github.com/FeatherFramework/feather-toolkit

Has NUI (`ui_page`).

## Exports (call as exports['feather-toolkit']:Name)

**server:** `GetCapabilities()`

**client:** `CancelProgress(id)`, `CopyToClipboard(text)`, `CreateBlip(spec)`, `CreateObject(spec)`, `CreatePed(spec)`, `CreatePrompt(spec)`, `DrawText2D(spec)`, `DrawText3D(spec)`, `GetCapabilities()`, `GetProgress(id)`, `IsPromptCompleted(id)`, `LoadAnimDict(dictionary, timeoutMs)`, `LoadModel(model, timeoutMs)`, `RegisterKeyListener(control, cb, mode)`, `RemoveBlip(id)`, `RemoveEntity(id)`, `RemoveKeyListener(id)`, `RemovePrompt(id)`, `ResolveControl(control)`, `SetPromptEnabled(id, v)`, `ShowPromptGroup(groupId, label)`, `StartProgress(spec, callback)`

## Commands (RegisterCommand)

**server:** `/ToolkitServerContractSmokeTest`

**client:** `/ToolkitClipboardSmokeTest`, `/ToolkitContractSmokeTest`, `/ToolkitProgressSmokeTest`

## Public (table) functions

**client/services/animations.lua:** `ToolkitAnimations.LoadDictionary(dictionary, timeoutMs)`

**client/services/blips.lua:** `ToolkitBlips.Create(owner, spec)`, `ToolkitBlips.Remove(owner, id)`, `ToolkitBlips.Cleanup(owner)`, `ToolkitBlips.CleanupAll()`

**client/services/clipboard.lua:** `ToolkitClipboard.Copy(text)`

**client/services/controls.lua:** `ToolkitControls.Resolve(control)`

**client/services/entities.lua:** `ToolkitEntities.CreateObject(owner, spec)`, `ToolkitEntities.CreatePed(owner, spec)`, `ToolkitEntities.Remove(owner, id)`, `ToolkitEntities.Cleanup(owner)`, `ToolkitEntities.CleanupAll()`

**client/services/keys.lua:** `ToolkitKeys.Register(owner, control, callback, mode)`, `ToolkitKeys.Remove(owner, id)`, `ToolkitKeys.Cleanup(owner)`, `ToolkitKeys.CleanupAll()`

**client/services/models.lua:** `ToolkitModels.Load(model, timeoutMs)`

**client/services/progress.lua:** `ToolkitProgress.Start(owner, spec, callback)`, `ToolkitProgress.Get(owner, id)`, `ToolkitProgress.Cancel(owner, id)`, `ToolkitProgress.Cleanup(owner)`, `ToolkitProgress.CleanupAll()`, `ToolkitProgress.Validate(spec, callback)`

**client/services/prompts.lua:** `ToolkitPrompts.Create(owner, spec)`, `ToolkitPrompts.Completed(owner, id)`, `ToolkitPrompts.SetEnabled(owner, id, enabled)`, `ToolkitPrompts.Remove(owner, id)`, `ToolkitPrompts.Cleanup(owner)`, `ToolkitPrompts.CleanupAll()`

**client/services/render.lua:** `ToolkitRender.Text2D(spec)`, `ToolkitRender.Text3D(spec)`

**shared/results.lua:** `ToolkitResults.Ok(value)`, `ToolkitResults.Err(code, message, details)`
