# WATER natives (17)
Source: VORPCORE/RDR3natives `rdr3natives.json`. Grep by NAME or hash.

## DISABLE_WATER_LOOKUP
`0x754616EC6965D1FB` | `void DISABLE_WATER_LOOKUP()` | build 1207
Must be called every frame to take full effect.

## ENABLE_WATER_LOOKUP
`0x754616EC6965D1BF` | `void ENABLE_WATER_LOOKUP()` | build 1207

## GET_WATER_HEIGHT
`0xFCA8B23F28813F69` | `BOOL GET_WATER_HEIGHT(float x, float y, float z, float* height)` | build 1207
Checks against a global variable that is set by _SET_WORLD_WATER_TYPE. If that is set to one it will fail. Likely not the only issue but part of it.

## GET_WATER_HEIGHT_NO_WAVES
`0xDCF3690AA262C03F` | `BOOL GET_WATER_HEIGHT_NO_WAVES(float x, float y, float z, float* height)` | build 1207

## REMOVE_EXTRA_CALMING_QUAD
`0x4BEF8DD75AF6C71C` | `void REMOVE_EXTRA_CALMING_QUAD(int index)` | build 1207
Only used in rcm_crackpot1 R* Script: p0 = 0

## TEST_PROBE_AGAINST_ALL_WATER
`0x8974647ED222EA5F` | `int TEST_PROBE_AGAINST_ALL_WATER(float x1, float y1, float z1, float x2, float y2, float z2, int flags, Vector3* intersectionPos)` | build 1207
enum eScriptWaterTestResult
{
	SCRIPT_WATER_TEST_RESULT_NONE,
	SCRIPT_WATER_TEST_RESULT_WATER,
	SCRIPT_WATER_TEST_RESULT_BLOCKED,
};

## TEST_VERTICAL_PROBE_AGAINST_ALL_WATER
`0x2B3451FA1E3142E2` | `int TEST_VERTICAL_PROBE_AGAINST_ALL_WATER(float x, float y, float z, int flags, float* waterHeight)` | build 1207
Checks against a global variable that is set by _SET_WORLD_WATER_TYPE. If it's set to 1 (Guarma) it will fail.

See TEST_PROBE_AGAINST_ALL_WATER.

## _0x09A1C7DFDCE54FBC
`0x09A1C7DFDCE54FBC` | `void _0x09A1C7DFDCE54FBC(int p0)` | build 1207
Called together with REMOVE_EXTRA_CALMING_QUAD in rcm_crackpot1 R* Script: p0 = 0
_REMOVE_*

## _0x0DCEC6A92E497E17
`0x0DCEC6A92E497E17` | `void _0x0DCEC6A92E497E17(Entity entity, int p1)` | build 1207
Only used in native_son1 R* Script: p1 = 1

## _0xA33F5069B0CB89B8
`0xA33F5069B0CB89B8` | `void _0xA33F5069B0CB89B8()` | build 1207
Only used in fishing_core R* Script

## _0xB34A6009A0DB80B8
`0xB34A6009A0DB80B8` | `void _0xB34A6009A0DB80B8(Entity entity)` | build 1207
Used in bounty1, fanale3, sean1 R* Scripts

## _0xE8126623008372AA
`0xE8126623008372AA` | `void _0xE8126623008372AA()` | build 1207
Only used in fussar1 / train_robbery2 R* Script

## _0xF0FBF193F1F5C0EA
`0xF0FBF193F1F5C0EA` | `void _0xF0FBF193F1F5C0EA(Ped ped)` | build 1207
Only used in fishing_core R* Script

## _GET_WORLD_WATER_TYPE
`0x189739A7631C1867` | `int _GET_WORLD_WATER_TYPE()` | build 1207

## _RESET_GUARMA_WATER_STATE
`0xC63540AEF8384769` | `void _RESET_GUARMA_WATER_STATE()` | build 1207
Only used in guama1 / guama3 R* Script
_REQUEST_* or _RESET_*

## _SET_OCEAN_GUARMA_WATER_QUADRANT
`0xC63540AEF8384732` | `void _SET_OCEAN_GUARMA_WATER_QUADRANT(float wavesHeight, float p1, int waveDirection, float p3, float waveAmmount, float p5, float waveSpeed, float wavesStrength, int ignoreHeight)` | build 1207
Only used in R* Script guama1 this native allows to modify the ocean water in the guarma island. wave direction accepts 0, 1 and 2 values.

## _SET_WORLD_WATER_TYPE
`0xE8770EE02AEE45C2` | `void _SET_WORLD_WATER_TYPE(int waterType)` | build 1207
0 = World
1 = Guarma
