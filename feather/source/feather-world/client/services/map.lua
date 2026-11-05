MapAPI = {}
WorldMapRouteActive = false

local function ResultError(code, message)
    return { ok = false, error = { code = code, message = message } }
end

local function IsCoordinate(value)
    local valueType = type(value)
    if valueType ~= 'table' and valueType ~= 'vector3' then return false end
    return tonumber(value.x) ~= nil and tonumber(value.y) ~= nil and tonumber(value.z) ~= nil
end

function MapAPI.SetFogOfWar(hidden)
    SetMinimapHideFow(hidden == true)
    return { ok = true }
end

function MapAPI.DisplayRadar(visible)
    DisplayRadar(visible == true)
    return { ok = true }
end

function MapAPI.StartGps(startCoords, finishCoords)
    if not IsCoordinate(startCoords) or not IsCoordinate(finishCoords) then
        return ResultError('invalid_coordinates', 'Start and finish coordinates are required.')
    end

    ClearGpsMultiRoute()
    StartGpsMultiRoute(Config.Map.gpsRouteColor, true, true)
    AddPointToGpsMultiRoute(startCoords.x, startCoords.y, startCoords.z)
    AddPointToGpsMultiRoute(finishCoords.x, finishCoords.y, finishCoords.z)
    SetGpsMultiRouteRender(true)
    WorldMapRouteActive = true
    return { ok = true }
end

function MapAPI.StopGps()
    ClearGpsMultiRoute()
    WorldMapRouteActive = false
    return { ok = true }
end
