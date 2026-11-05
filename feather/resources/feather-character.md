# feather-character

Version 0.7.4. Feather Character clean-room rewrite (first-playable development slice)

Feather Character provides character creation, selection, appearance, first-spawn placement, position saving, logout, and character deletion for a Feather Framework RedM server.

Source: https://github.com/FeatherFramework/feather-character

**Dependencies:** `feather-mysql`, `feather-core`, `feather-routing`, `feather-economy`, `feather-menu-v2`

## Exports (call as exports['feather-character']:Name)

**server:** `GetCapabilities()`, `GetHealth()`, `GetMedicalReadySession(source)`, `GetMedicalRecoveryDestination(key)`

**client:** `ApplyMedicalCondition(snapshot)`, `ApplyMedicalRecovery(plan)`, `GetMedicalContext()`, `HasActiveCharacter()`, `RegisterLogoutCheckpoint(name, exportName)`

## Net events registered

**client:** `feather-character:spawnExpired`

## Event handlers

**server:** `chat.ready.v1`

**client:** `onClientMapStart`, `playerSpawned`

## Commands (RegisterCommand)

**server:** `/CharacterV2Status`

**client:** `/characterSelectionRetry`, `/characterWeatherStatus`, `/logout`, `/savequit`

## Public (table) functions

**.luals/cfx-runtime.lua:** `Citizen.InvokeNative(hash, ...)`, `Citizen.CreateThread(cb)`, `Citizen.CreateThreadNow(cb)`, `Citizen.Wait(ms)`, `Citizen.Trace(msg)`, `json.encode(value)`, `json.decode(str)`

**client/appearance.lua:** `CharacterV2Appearance.CleanCreatorPed(ped)`, `CharacterV2Appearance.ResetCreatorPed(ped)`, `CharacterV2Appearance.InitializePed(ped, model)`, `CharacterV2Appearance.Apply(ped, document)`

**client/arrival.lua:** `CharacterV2Arrival.Cleanup()`, `CharacterV2Arrival.Play(townKey, playerPed, requestedType)`

**client/checkpoints.lua:** `CharacterV2Checkpoints.Run(context)`

**client/environment.lua:** `E.Enter(nextView)`, `E.Leave(reason)`, `E.State()`

**client/flow.lua:** `CharacterV2Flow.State()`, `CharacterV2Flow.Transition(nextPhase)`, `CharacterV2Flow.IsCurrent(ticket)`, `CharacterV2Flow.Reset()`

**client/locale.lua:** `CharacterV2Locale.Register(locale, translations)`, `CharacterV2Locale.Text(key)`

**client/medical.lua:** `CharacterV2Medical.ApplyCondition(snapshot)`

**client/overlay_menu.lua:** `CharacterV2OverlayMenu.Build(context)`

**client/preview.lua:** `CharacterV2Preview.Close(preserveCamera)`, `CharacterV2Preview.Open(viewName, model)`, `CharacterV2Preview.StashSelector(key)`, `CharacterV2Preview.ActivateSelector(key)`, `CharacterV2Preview.EvictSelector(key)`, `CharacterV2Preview.FadeOut()`, `CharacterV2Preview.Reveal()`, `CharacterV2Preview.PoseSelector()`, `CharacterV2Preview.SetCamera(viewKey, fov)`, `CharacterV2Preview.Rotate(amount)`, `CharacterV2Preview.Current()`

**client/spawn_ownership.lua:** `CharacterV2SpawnOwnership.Enforce()`

**server/activation.lua:** `CharacterV2Activation.EnterSelection(source)`, `CharacterV2Activation.LeaveSelection(source)`, `CharacterV2Activation.PrepareSpawn(source, context, payload)`, `CharacterV2Activation.PrepareReveal(source, context, payload)`, `CharacterV2Activation.Activate(source, accountId, characterId)`, `CharacterV2Activation.CompleteSpawn(source, context)`, `CharacterV2Activation.Abort(source, sessionId)`, `CharacterV2Activation.Logout(source, context, position, reason)`, `CharacterV2Activation.Quit(source, context, position)`

**server/migrate.lua:** `CharacterV2Migration.Run()`

**server/profiles.lua:** `CharacterV2Profiles.Create(accountId, requestKey, input)`, `CharacterV2Profiles.UpdatePosition(accountId, characterId, position)`, `CharacterV2Profiles.List(accountId)`, `CharacterV2Profiles.Delete(accountId, characterId)`, `CharacterV2Profiles.Get(accountId, characterId)`, `CharacterV2Profiles.GetAppearance(accountId, characterId)`, `CharacterV2Profiles.GetSpawnState(accountId, characterId)`, `CharacterV2Profiles.SearchProfiles(query, page, limit)`

**shared/catalog.lua:** `CharacterV2Catalog.Heritages(model)`, `CharacterV2Catalog.Values(model, category, heritageIndex)`, `CharacterV2Catalog.Albedo(model, heritageIndex)`, `CharacterV2Catalog.Contains(model, category, value)`

**shared/draft.lua:** `CharacterV2Draft.SanitizeAppearance(model, input)`, `CharacterV2Draft.Validate(input)`

**shared/hair_catalog.lua:** `CharacterV2HairCatalog.Groups(model, kind)`, `CharacterV2HairCatalog.Contains(model, kind, hash)`, `CharacterV2HairCatalog.StyleLabel(hash, index)`

**shared/overlay_catalog.lua:** `CharacterV2OverlayCatalog.Get(category)`

**shared/result.lua:** `CharacterV2Result.Ok(value)`, `CharacterV2Result.Err(code, message)`

**tests/environment_spec.lua:** `api:AcquireOverride(spec)`, `api:UpdateOverride(handle,spec)`, `api:ReleaseOverride(handle)`, `api:GetLocalState()`, `env:step(ms)`, `env:count()`
