local INTERIORS = assert(WorldInteriorDefinitions, 'interior definitions were not loaded')
local IMAP_STATES = assert(WorldImapStates, 'IMAP states were not loaded')

local interiorConfig = Config.InteriorFix
local started = false
local interiorsById = {}

InteriorsActive = false
IMapsActive = false
InteriorDefinitionCount = 0
InteriorEntitySetCount = 0
InteriorInvalidCount = 0
InteriorMetadataCount = 0
IMapOperationCount = 0
IMapDescriptionCount = 0

for _, definition in ipairs(INTERIORS) do
    interiorsById[definition.id] = definition
    if definition.coords and definition.type and definition.type.hash and definition.type.name and definition.type.rpf then
        InteriorMetadataCount = InteriorMetadataCount + 1
    end
end

local function ActivateInteriorDefinition(definition)
    InteriorDefinitionCount = InteriorDefinitionCount + 1
    if not IsValidInterior(definition.id) then
        InteriorInvalidCount = InteriorInvalidCount + 1
        DebugLog('[Interiors]', ('invalid interior id=%d name=%s'):format(definition.id, definition.name))
        return
    end

    for _, entitySet in ipairs(definition.sets) do
        if not IsInteriorEntitySetActive(definition.id, entitySet) then
            ActivateInteriorEntitySet(definition.id, entitySet, 0)
        end
        InteriorEntitySetCount = InteriorEntitySetCount + 1
    end
end

local function ApplyImapStates()
    for _, imap in ipairs(IMAP_STATES) do
        if imap.enabled then
            RequestImap(imap.hash)
        else
            RemoveImap(imap.hash)
        end
        IMapOperationCount = IMapOperationCount + 1
        if imap.description then IMapDescriptionCount = IMapDescriptionCount + 1 end
    end
    IMapsActive = true
end

if Config.DevMode then
    RegisterCommand('WorldInteriorInspect', function(_, args)
        local interiorId = tonumber(args[1])
        local definition = interiorId and interiorsById[interiorId] or nil
        if not definition then
            print('[WorldInteriorInspect] usage: WorldInteriorInspect <interiorId>')
            return
        end

        print(('[WorldInteriorInspect] id=%d name=%s coords=(%.2f, %.2f, %.2f) typeHash=%d typeName=%s rpf=%s sets=%d valid=%s')
            :format(definition.id, definition.name, definition.coords.x, definition.coords.y, definition.coords.z,
                definition.type.hash, definition.type.name, definition.type.rpf, #definition.sets,
                tostring(IsValidInterior(definition.id))))
    end, false)
end

function StartInteriorsFix()
    if started then return end
    started = true

    ApplyImapStates()

    CreateThread(function()
        Wait(interiorConfig.startupDelayMs)
        for _, definition in ipairs(INTERIORS) do
            ActivateInteriorDefinition(definition)
        end
        InteriorsActive = true
        DebugLog('[Interiors]',
            ('activation complete interiors=%d metadata=%d sets=%d invalid=%d imapStates=%d described=%d')
            :format(InteriorDefinitionCount, InteriorMetadataCount, InteriorEntitySetCount, InteriorInvalidCount,
                IMapOperationCount, IMapDescriptionCount))
    end)
end
