# SHAPETEST natives (8)
Source: VORPCORE/RDR3natives `rdr3natives.json`. Grep by NAME or hash.

## GET_SHAPE_TEST_RESULT
`0xEDE8AC7C5108FB1D` | `int GET_SHAPE_TEST_RESULT(ScrHandle shapeTestHandle, BOOL* hit, Vector3* endCoords, Vector3* surfaceNormal, Entity* entityHit)` | build 1207
Returns the result of a shape test: 0 if the handle is invalid, 1 if the shape test is still pending, or 2 if the shape test has completed, and the handle should be invalidated.

When used with an asynchronous shape test, this native should be looped until returning 0 or 2, after which the handle is invalidated.

enum eShapeTestStatus
{
	SHAPETEST_STATUS_NONEXISTENT,
	SHAPETEST_STATUS_RESULTS_NOTREADY,
	SHAPETEST_STATUS_RESULTS_READY
};

## START_EXPENSIVE_SYNCHRONOUS_SHAPE_TEST_LOS_PROBE
`0x377906D8A31E5586` | `ScrHandle START_EXPENSIVE_SYNCHRONOUS_SHAPE_TEST_LOS_PROBE(float x1, float y1, float z1, float x2, float y2, float z2, int flags, Entity entityToIgnore, int p8)` | build 1207
Does the same as 0x7EE9F5D83DD4F90E, except blocking until the shape test completes.

## START_SHAPE_TEST_BOX
`0xFE466162C4401D18` | `ScrHandle START_SHAPE_TEST_BOX(float posX, float posY, float posZ, float dimensionsX, float dimensionsY, float dimensionsZ, float rotX, float rotY, float rotZ, int rotationOrder, int flags, Entity entityToIgnore, int options)` | build 1207

## START_SHAPE_TEST_CAPSULE
`0x28579D1B8F8AAC80` | `ScrHandle START_SHAPE_TEST_CAPSULE(float x1, float y1, float z1, float x2, float y2, float z2, float radius, int flags, Entity entityToIgnore, int p9)` | build 1207

## START_SHAPE_TEST_LOS_PROBE
`0x7EE9F5D83DD4F90E` | `ScrHandle START_SHAPE_TEST_LOS_PROBE(float x1, float y1, float z1, float x2, float y2, float z2, int flags, Entity entity, int p8)` | build 1207
Asynchronously starts a line-of-sight (raycast) world probe shape test.

Use the handle with 0x3D87450E15D98694 or 0x65287525D951F6BE until it returns 0 or 2.

p8 is a bit mask with bits 1, 2 and/or 4, relating to collider types; 4 should usually be used. flags used are mostly 83 and 3167

## START_SHAPE_TEST_MOUSE_CURSOR_LOS_PROBE
`0x9839013D8B6014F1` | `ScrHandle START_SHAPE_TEST_MOUSE_CURSOR_LOS_PROBE(Vector3* pVec1, Vector3* pVec2, int flag, Entity entity, int flag2)` | build 1207
Old name: _START_SHAPE_TEST_SURROUNDING_COORDS

## START_SHAPE_TEST_SWEPT_SPHERE
`0xAA5B7C8309F73230` | `ScrHandle START_SHAPE_TEST_SWEPT_SPHERE(float x1, float y1, float z1, float x2, float y2, float z2, float radius, int flags, Entity entity, Any p9)` | build 1207

## _0x04AA59CA40571C2E
`0x04AA59CA40571C2E` | `Any _0x04AA59CA40571C2E(Any p0, Any p1)` | build 1207
