# BUILTIN natives (22)
Source: VORPCORE/RDR3natives `rdr3natives.json`. Grep by NAME or hash.

## CEIL
`0x11E019C8F43ACC8A` | `int CEIL(float value)` | build 1207
Rounds a float value up to the next whole number

## COS
`0xD0FFB162F40A139C` | `float COS(float value)` | build 1207

## FLOOR
`0xF34EE736CF047844` | `int FLOOR(float value)` | build 1207
Rounds a float value down to the next whole number

## LOG10
`0xE816E655DE37FE20` | `float LOG10(float value)` | build 1232
Old name: _LOG10

## POW
`0xE3621CC40F31FE2E` | `float POW(float base, float exponent)` | build 1207

## ROUND
`0xF2DB717A73826179` | `int ROUND(float value)` | build 1207

## SETTIMERA
`0xC1B1E9A034A63A62` | `void SETTIMERA(int value)` | build 1207

## SETTIMERB
`0x5AE11BC36633DE4E` | `void SETTIMERB(int value)` | build 1207

## SET_THIS_THREAD_PRIORITY
`0x42B65DEEF2EDF2A1` | `void SET_THIS_THREAD_PRIORITY(int priority)` | build 1207
THREAD_PRIO_HIGHEST = 0
THREAD_PRIO_NORMAL = 1
THREAD_PRIO_LOWEST = 2
THREAD_PRIO_MANUAL_UPDATE = 100

## SHIFT_LEFT
`0xEDD95A39E5544DE8` | `int SHIFT_LEFT(int value, int bitShift)` | build 1207

## SHIFT_RIGHT
`0x97EF1E5BCE9DC075` | `int SHIFT_RIGHT(int value, int bitShift)` | build 1207

## SIN
`0x0BADBFA3B172435F` | `float SIN(float value)` | build 1207

## SQRT
`0x71D93B57D07F9804` | `float SQRT(float value)` | build 1207

## TIMERA
`0x83666F9FB8FEBD4B` | `int TIMERA()` | build 1207
Counts up. Every 1000 is 1 real-time second. Use SETTIMERA(int value) to set the timer (e.g.: SETTIMERA(0)).

## TIMERB
`0xC9D9444186B5A374` | `int TIMERB()` | build 1207

## TIMESTEP
`0x0000000050597EE2` | `float TIMESTEP()` | build 1207
Gets the current frame time.

## TO_FLOAT
`0xBBDA792448DB5A89` | `float TO_FLOAT(int value)` | build 1207

## VDIST
`0x2A488C176D52CCA5` | `float VDIST(float x1, float y1, float z1, float x2, float y2, float z2)` | build 1207
Calculates distance between vectors.
The value returned will be in meters.

## VDIST2
`0xB7A628320EFF8E47` | `float VDIST2(float x1, float y1, float z1, float x2, float y2, float z2)` | build 1207
Calculates distance between vectors but does not perform Sqrt operations. (Its way faster)
The value returned will be in RAGE units.

## VMAG
`0x652D2EEEF1D3E62C` | `float VMAG(float x, float y, float z)` | build 1207
Calculates the magnitude of a vector.

## VMAG2
`0xA8CEACB4F35AE058` | `float VMAG2(float x, float y, float z)` | build 1207
Calculates the magnitude of a vector but does not perform Sqrt operations. (Its way faster)

## WAIT
`0x4EDE34FBADD967A6` | `void WAIT(int ms)` | build 1207
