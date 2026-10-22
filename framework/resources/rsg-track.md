# rsg-track

Version 2.0.1. rsg-track

A custom horse race track builder and race manager for **RSG-Core** RedM servers. Players (or staff) lay out a checkpoint route in the open world with a couple of keybinds, save it to the database, invite riders, and run multi-lap races with automatic winner tracking, cash rewards, and optional Discord logging — all through a themed NUI menu. - **In-world track creation** — press `J` to drop the s

Source: https://github.com/Rexshack-RedM/rsg-track

**Dependencies:** `rsg-core`, `ox_lib`, `oxmysql`

Has NUI (`ui_page`).

## Net events registered

**client:** `rsg-track:finishRace`, `rsg-track:joinedRace`, `rsg-track:leftRace`, `rsg-track:raceStarted`, `rsg-track:resetRace`, `rsg-track:rewardReceived`, `rsg-track:showFinisherNotification`, `rsg-track:startRace`, `rsg-track:syncLaps`, `rsg-track:syncMaxMarkers`, `rsg-track:syncRaceResults`, `rsg-track:syncResults`, `rsg-track:syncTrack`, `rsg-track:syncTracks`, `rsg-track:toast`, `rsg-track:updatePlayers`

## Event handlers

**server:** `horse_race:countdownFinished`, `horse_race:finishRace`, `horse_race:trackCreated`, `playerConnecting`, `rsg-track:deleteTrack`, `rsg-track:joinRace`, `rsg-track:leaveRace`, `rsg-track:loadTrack`, `rsg-track:requestTracks`, `rsg-track:resetRace`, `rsg-track:setLaps`, `rsg-track:setMaxMarkers`, `rsg-track:startRace`

**client:** `rsg-track:finishRace`, `rsg-track:joinedRace`, `rsg-track:leftRace`, `rsg-track:raceStarted`, `rsg-track:resetRace`, `rsg-track:rewardReceived`, `rsg-track:showFinisherNotification`, `rsg-track:startRace`, `rsg-track:syncLaps`, `rsg-track:syncMaxMarkers`, `rsg-track:syncRaceResults`, `rsg-track:syncResults`, `rsg-track:syncTrack`, `rsg-track:syncTracks`, `rsg-track:updatePlayers`

## Commands (RegisterCommand)

**server:** `/racewebhooktest`

**client:** `/race`, `/racerace`

## Server events it triggers in other resources

**client:** `horse_race:countdownFinished`, `horse_race:finishRace`, `horse_race:trackCreated`
