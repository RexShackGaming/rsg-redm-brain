-- Pure authority model: no Cfx globals, native calls, IO, or remote handlers.
WeatherEngine = {}
local E, W = WeatherEngine, Weather
E.__index = E

function E.New(config, epoch, random)
    if not W.Config(config) then return W.Err('invalid_config', 'Invalid Weather configuration; check clock, weather, pattern, limits and owner policies.') end
    local self = setmetatable({ config=W.Copy(config), epoch=epoch, revision=1,
        clock=W.Copy(config.clock), weather=W.Copy(config.weather), wind=W.Copy(config.wind),
        pattern=W.Copy(config.pattern), progress=0, transitionId=1, transitionRemaining=0,
        generation=0, catchUpResets=0, random=random or math.random }, E)
    self:ResetClimate()
    self:Rebuild()
    return W.Ok(self)
end

function E:ResetClimate()
    local season,wind=self.config.seasons,self.config.windProgression
    self.season={enabled=season and season.enabled or false,frozen=season and season.frozen or false,
        name=season and season.start or 'spring',day=season and season.day or 1,seconds=0,
        daysPerSeason=season and season.daysPerSeason or 7,cycle=0}
    self.windControl={automatic=wind and wind.enabled or false,frozen=wind and wind.frozen or false}
    self.windTarget=W.Copy(self.wind)
    self.windElapsed=0
    if self.season.enabled then self.pattern=W.Copy(season.patterns[self.season.name]) end
    if self.windControl.automatic then self:ChooseWind() end
end

function E:ChooseWind()
    local cfg=self.config.windProgression
    if not cfg or not self.windControl.automatic then return end
    local range=cfg.profiles[self.weather.name] or cfg.default
    local roll=math.max(1,math.min(100,self.random(1,100)))
    self.windTarget={speed=range.min+(range.max-range.min)*(roll-1)/99,
        direction=(self.wind.direction+(self.random(1,100)-50)*0.9)%360}
    self.windElapsed=0
end

function E:AdvanceCalendar(simulationSeconds)
    local s=self.season
    if not s.enabled or s.frozen then return false end
    local seasonSeconds=s.daysPerSeason*86400
    local position=(s.day-1)*86400+s.seconds+simulationSeconds
    local steps=math.floor(position/seasonSeconds)
    position=position%seasonSeconds
    s.day,s.seconds=math.floor(position/86400)+1,position%86400
    if steps==0 then return false end
    local index=W.SeasonIndex(s.name)-1+steps
    s.name=W.seasonNames[index%4+1]
    s.cycle=s.cycle+math.floor(index/4)
    self.pattern=W.Copy(self.config.seasons.patterns[s.name])
    self.progress=0
    self:Rebuild()
    return true
end

function E:Next(name)
    -- Manual exceptional weather may not have a graph row. Resume via configured default.
    local row = self.pattern[name] or self.pattern[self.config.weather.name]
    if not row then
        local keys = {}
        for key in pairs(self.pattern) do keys[#keys + 1] = key end
        table.sort(keys)
        row = self.pattern[keys[1]]
    end
    local roll, total = self.random(1, 100), 0
    for _, choice in ipairs(row) do
        total = total + choice.weight
        if roll <= total then return choice.name end
    end
    error('validated weighted graph produced no choice')
end

function E:Rebuild()
    self.queue = {}
    local name = self.weather.name
    for index = 1, self.config.forecastCount do
        name = self:Next(name)
        self.queue[index] = name
    end
    self.generation = self.generation + 1
end

function E:Step(elapsed, wallSeconds)
    if not W.Number(elapsed, 0, math.huge) or elapsed == math.huge then return false end
    if not self.clock.frozen then
        if self.clock.mode == 'wall' then
            self.clock.seconds = (wallSeconds + self.clock.offsetSeconds) % W.WEEK
        else
            self.clock.seconds = (self.clock.seconds + elapsed * self.clock.rate) % W.WEEK
        end
    end
    self.transitionRemaining = math.max(0, self.transitionRemaining - elapsed)
    local changed = false
    if not self.weather.frozen then
        local rate, interval = W.Rate(self.clock), self.config.weatherIntervalSeconds
        self.progress = self.progress + elapsed * rate
        local steps = math.floor(self.progress / interval)
        self.progress = self.progress % interval
        if steps > self.config.maxCatchUpSteps then
            -- Explicit long-stall policy: hold current weather, reset its interval,
            -- rebuild a new bounded forecast, and expose the discontinuity.
            self.progress = 0
            self.catchUpResets = self.catchUpResets + 1
            self:Rebuild()
            changed = true
        else
            for _ = 1, steps do
                self.weather.name = table.remove(self.queue, 1)
                self.queue[#self.queue + 1] = self:Next(self.queue[#self.queue] or self.weather.name)
                self.transitionId = self.transitionId + 1
                changed = true
            end
            if steps > 0 then
                local age = rate > 0 and self.progress / rate or 0
                self.transitionRemaining = math.max(0, self.weather.transitionSeconds - age)
            end
        end
    end
    if changed then self:ChooseWind() end
    if self.windControl.automatic and not self.windControl.frozen then
        local cfg=self.config.windProgression
        self.windElapsed=self.windElapsed+elapsed
        self.wind=W.ProjectWind(self.wind,self.windTarget,elapsed,cfg.degreesPerSecond,cfg.speedPerSecond)
        if self.windElapsed>=cfg.intervalSeconds then self:ChooseWind(); changed=true end
    end
    if self:AdvanceCalendar(elapsed*W.Rate(self.clock)) then changed=true end
    self.revision = self.revision + 1
    return changed
end

function E:Advance(elapsed,wallSeconds)
    if not W.Number(elapsed,0,math.huge) or elapsed==math.huge then return false end
    local changed,segments=false,0
    repeat
        local step=elapsed
        local s,rate=self.season,W.Rate(self.clock)
        if s.enabled and not s.frozen and rate>0 and segments<self.config.maxCatchUpSteps then
            step=math.min(step,((s.daysPerSeason-s.day+1)*86400-s.seconds)/rate)
        end
        changed=self:Step(step,wallSeconds) or changed
        elapsed=math.max(0,elapsed-step)
        segments=segments+1
    until elapsed<=0
    return changed
end

function E:Snapshot()
    return W.Copy({ epoch=self.epoch, revision=self.revision, clock=self.clock, weather=self.weather,
        wind=self.wind, transitionId=self.transitionId, transitionRemainingSeconds=self.transitionRemaining,
        scheduleGeneration=self.generation, catchUpResets=self.catchUpResets,season=self.season,
        windControl=self.windControl,windMotion={target=self.windTarget,
            degreesPerSecond=self.windControl.automatic and not self.windControl.frozen and self.config.windProgression.degreesPerSecond or 0,
            speedPerSecond=self.windControl.automatic and not self.windControl.frozen and self.config.windProgression.speedPerSecond or 0} })
end

function E:Forecast(options)
    options = options or {}
    if not W.Fields(options, { count=true }) then return W.Err('invalid_input', 'Expected forecast options with optional count.') end
    local count = options.count or self.config.forecastCount
    if not W.Number(count, 1, self.config.forecastCount, true) then return W.Err('invalid_input', 'Forecast count exceeds configured bounds.') end
    local result, rate = {}, W.Rate(self.clock)
    for index = 1, count do
        local due = self.config.weatherIntervalSeconds * index - self.progress
        local s=self.season
        if s.enabled and not s.frozen and due>=((s.daysPerSeason-s.day+1)*86400-s.seconds) then break end
        result[index] = { name=self.queue[index], dueSimulationSeconds=due }
        if not self.weather.frozen and rate > 0 then result[index].dueRealSeconds = due / rate end
    end
    return W.Ok({ epoch=self.epoch, revision=self.revision, generation=self.generation,
        paused=self.weather.frozen or rate == 0, basis='elapsed_simulation',season=self.season.name,
        horizon=self.season.enabled and not self.season.frozen and 'next_season_boundary' or 'configured_count',entries=result })
end

function E:Mutate(action, spec)
    if action == 'clock' then
        local nextValue = W.Merge(self.clock, spec, W.Clock)
        if not nextValue then return W.Err('invalid_input', 'Invalid clock patch.') end
        self.clock = nextValue
        -- Progress/queued weather are retained; forecast dueRealSeconds uses the new rate.
    elseif action == 'weather' then
        local nextValue = W.Merge(self.weather, spec, W.Weather)
        if not nextValue then return W.Err('invalid_input', 'Invalid weather patch.') end
        self.weather, self.progress = nextValue, 0
        self.transitionId = self.transitionId + 1
        self.transitionRemaining = nextValue.transitionSeconds
        self:Rebuild()
        self:ChooseWind()
    elseif action == 'wind' then
        local nextValue = W.Merge(self.wind, spec, W.Wind)
        if not nextValue then return W.Err('invalid_input', 'Invalid wind patch.') end
        self.wind = nextValue
        self.windControl.automatic=false
        self.windTarget=W.Copy(nextValue)
    elseif action == 'windControl' then
        local nextValue=W.Merge(self.windControl,spec,W.WindControl)
        if not nextValue or (nextValue.automatic and not self.config.windProgression) then
            return W.Err('invalid_input','Invalid wind control patch or no configured progression.')
        end
        self.windControl=nextValue
        if nextValue.automatic then self:ChooseWind() else self.windTarget=W.Copy(self.wind) end
    elseif action == 'season' then
        if not W.Fields(spec,{name=true,day=true,enabled=true,frozen=true}) then return W.Err('invalid_input','Invalid season patch.') end
        local nextValue=W.Copy(self.season)
        for k,v in pairs(spec) do nextValue[k]=v end
        if not W.SeasonState(nextValue) or (nextValue.enabled and not self.config.seasons) then
            return W.Err('invalid_input','Invalid season, day or calendar controls.')
        end
        if spec.name or spec.day then nextValue.seconds=0 end
        self.season=nextValue
        self.pattern=W.Copy(nextValue.enabled and self.config.seasons.patterns[nextValue.name] or self.config.pattern)
        self.progress=0
        self:Rebuild()
    elseif action == 'pattern' then
        if not W.Pattern(spec) then return W.Err('invalid_input', 'Pattern must be a closed ordered weighted graph; each row totals 100.') end
        self.pattern, self.progress = W.Copy(spec), 0
        self:Rebuild()
    elseif action == 'reset' then
        if spec ~= nil and not W.Fields(spec, {}) then return W.Err('invalid_input', 'Reset takes no options; all domains reset.') end
        self.clock, self.weather, self.wind = W.Copy(self.config.clock), W.Copy(self.config.weather), W.Copy(self.config.wind)
        self.pattern, self.progress = W.Copy(self.config.pattern), 0
        self:ResetClimate()
        self.transitionId = self.transitionId + 1
        self.transitionRemaining = self.weather.transitionSeconds
        self:Rebuild()
    else
        return W.Err('invalid_input', 'Unknown mutation.')
    end
    self.revision = self.revision + 1
    return W.Ok(self:Snapshot())
end
