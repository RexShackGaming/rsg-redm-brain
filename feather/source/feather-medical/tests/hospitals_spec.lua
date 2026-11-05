local H = dofile('server/hospitals.lua')
local points = {
    {id = 'west', label = 'West', x = -10, y = 0, z = 0, heading = 90},
    {id = 'east', label = 'East', x = 10, y = 0, z = 0, heading = 0},
    {id = 'disabled', label = 'Disabled', x = 9, y = 0, z = 0, heading = 0, enabled = false}
}
assert(H.Validate(points))
assert(H.Nearest(points, {x = 9, y = 0, z = 0}).id == 'east', 'nearest enabled hospital selected')
assert(H.Nearest(points, {x = 0, y = 0, z = 0}).id == 'east', 'ties use stable hospital id')
local chosen = H.Nearest(points, {x = 9, y = 0, z = 0}); points[2].x = 20
assert(chosen.x == 10, 'selected destination is a captured copy')
points[2].x = 0/0
assert(not H.Validate(points), 'NaN coordinates rejected')
points[2].x, points[2].id = 10, 'west'
assert(not H.Validate(points), 'duplicate id rejected')
assert(H.Nearest({}, {x = 0, y = 0, z = 0}) == nil, 'no hospital cannot invent destination')
assert(H.Nearest({}, {x = math.huge, y = 0, z = 0}) == nil, 'invalid player position rejected')
assert(not H.Validate({[2] = points[1]}), 'sparse config rejected')
print('PASS 9 hospital selection checks')
