local definitionsByName = {}
local listeners = {}
local listenerCountsByGroup = {}
local buffers = {}
local nextListenerId = 0
local started = false

WorldEvents = {}
EventListenerCount = 0

for eventHash, definition in pairs(WorldNativeEventDefinitions) do
    definition.hash = eventHash
    definitionsByName[definition.name] = definition
    listenerCountsByGroup[definition.group] = 0
end

local function ReadEventData(definition, eventGroup, eventIndex)
    local buffer = buffers[definition.hash]
    if not buffer then
        buffer = WorldEventBuffer.Create(#definition.fields)
        buffers[definition.hash] = buffer
    end

    local available = Citizen.InvokeNative(0x57EC5FA4D4D6AFCA, eventGroup, eventIndex, buffer.Buffer(),
        #definition.fields)
    if not available then return nil end

    local values = {}
    for index, fieldType in ipairs(definition.fields) do
        local offset = index - 1
        values[index] = fieldType == 'float' and buffer:ReadFloat(offset) or buffer:ReadInt(offset)
    end
    return values
end

local function Dispatch(definition, values)
    local bucket = listeners[definition.hash]
    if not bucket then return end

    if Config.DevMode then
        DebugLog('[NativeEvents]', ('dispatch name=%s listeners=%d'):format(definition.name, bucket.count))
    end

    for _, callback in pairs(bucket.callbacks) do
        local ok, err = pcall(callback, values)
        if not ok then
            print(('[feather-world] native event listener failed name=%s error=%s')
                :format(definition.name, tostring(err)))
        end
    end
end

local function PollEventGroup(eventGroup)
    CreateThread(function()
        while true do
            if (listenerCountsByGroup[eventGroup] or 0) > 0 then
                local eventCount = GetNumberOfEvents(eventGroup)
                for eventIndex = 0, eventCount - 1 do
                    local definition = WorldNativeEventDefinitions[GetEventAtIndex(eventGroup, eventIndex)]
                    if definition and listeners[definition.hash] then
                        local values = ReadEventData(definition, eventGroup, eventIndex)
                        if values then Dispatch(definition, values) end
                    end
                end
            end
            Wait(0)
        end
    end)
end

function WorldEvents.Register(eventName, callback)
    if type(eventName) ~= 'string' or type(callback) ~= 'function' then return nil end

    local definition = definitionsByName[eventName]
    if not definition then return nil end

    local bucket = listeners[definition.hash]
    if not bucket then
        bucket = { count = 0, callbacks = {} }
        listeners[definition.hash] = bucket
    end

    nextListenerId = nextListenerId + 1
    bucket.callbacks[nextListenerId] = callback
    bucket.count = bucket.count + 1
    listenerCountsByGroup[definition.group] = listenerCountsByGroup[definition.group] + 1
    EventListenerCount = EventListenerCount + 1

    return { hash = definition.hash, id = nextListenerId, group = definition.group }
end

function WorldEvents.Remove(handle)
    if type(handle) ~= 'table' then return false end

    local bucket = listeners[handle.hash]
    if not bucket or not bucket.callbacks[handle.id] then return false end

    bucket.callbacks[handle.id] = nil
    bucket.count = bucket.count - 1
    listenerCountsByGroup[handle.group] = math.max(0, listenerCountsByGroup[handle.group] - 1)
    EventListenerCount = math.max(0, EventListenerCount - 1)
    if bucket.count == 0 then listeners[handle.hash] = nil end
    return true
end

function StartNativeEventRuntime()
    if started then return end
    started = true

    for eventGroup in pairs(listenerCountsByGroup) do
        PollEventGroup(eventGroup)
    end
end
