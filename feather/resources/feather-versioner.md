# feather-versioner

Version 0.1.8. Optional, operator-owned GitHub release notification service for Feather Framework

Version: **0.1.7**. Feather Versioner is an optional, server-only release notification service. It compares installed resource manifest versions with operator-selected GitHub release policies and prints concise console reports. It never downloads releases or overwrites, starts, stops, restarts, or migrates checked resources. GitHub availability never controls framework readiness, and Versioner doe

Source: https://github.com/FeatherFramework/feather-versioner

## Commands (RegisterCommand)

**server:** `/VersionerCacheAcceptanceSmokeTest`, `/VersionerContractSmokeTest`, `/VersionerFixtureSmokeTest`, `/VersionerSemverSmokeTest`, `/feather`

## Public (table) functions

**server/cache.lua:** `VersionerCache.Load()`, `VersionerCache.Save()`, `VersionerCache.Get(key)`, `VersionerCache.IsFresh(entry, now)`, `VersionerCache.Put(key, value)`

**server/config.lua:** `VersionerConfig.Validate()`

**server/github.lua:** `VersionerGithub.Fetch(repositoryRecord, generation, callback)`, `VersionerGithub.Select(cache, policy)`

**server/registry.lua:** `VersionerRegistry.Build()`, `VersionerRegistry.Get(name)`

**server/reporter.lua:** `VersionerReporter.Evaluate(entry, cache, stale)`, `VersionerReporter.Error(entry, failure, staleCache)`, `VersionerReporter.PrintOne(entry)`, `VersionerReporter.Print(entries, requestedName)`

**server/sanitize.lua:** `VersionerSanitize.Text(value, maximum)`, `VersionerSanitize.Repository(value)`, `VersionerSanitize.ReleaseUrl(value, repository)`

**server/scheduler.lua:** `VersionerScheduler.Run(reason, callback)`, `VersionerScheduler.Manual(callback)`, `VersionerScheduler.Start()`, `VersionerScheduler.Stop()`

**server/semver.lua:** `VersionerSemver.Parse(value)`, `VersionerSemver.Compare(left, right)`

**shared/results.lua:** `VersionerResults.Ok(value)`, `VersionerResults.Err(code, message, details)`

**tests/harness.lua:** `Harness.new(codec)`, `h:load(path)`, `h:advance(ms)`, `h:respond(index, status, body, headers)`, `h:release(version)`, `h:entry(version)`, `h:snapshot(entry)`, `h:body(version)`
