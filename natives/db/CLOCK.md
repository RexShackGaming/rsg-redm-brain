# CLOCK natives (19)
Source: VORPCORE/RDR3natives `rdr3natives.json`. Grep by NAME or hash.

## ADD_TO_CLOCK_TIME
`0xAB7C251C7701D336` | `void ADD_TO_CLOCK_TIME(int hours, int minutes, int seconds)` | build 1207

## ADVANCE_CLOCK_TIME_TO
`0x0184750AE88D0B1D` | `void ADVANCE_CLOCK_TIME_TO(int hour, int minute, int second)` | build 1207

## GET_CLOCK_DAY_OF_MONTH
`0xDF2FD796C54480A5` | `int GET_CLOCK_DAY_OF_MONTH()` | build 1207

## GET_CLOCK_DAY_OF_WEEK
`0x4DD02D4C7FB30076` | `int GET_CLOCK_DAY_OF_WEEK()` | build 1207
Gets the current day of the week.

0: Sunday
1: Monday
2: Tuesday
3: Wednesday
4: Thursday
5: Friday
6: Saturday

## GET_CLOCK_HOURS
`0xC82CF208C2B19199` | `int GET_CLOCK_HOURS()` | build 1207
Gets the current ingame hour, expressed without zeros. (09:34 will be represented as 9)

## GET_CLOCK_MINUTES
`0x4E162231B823DBBF` | `int GET_CLOCK_MINUTES()` | build 1207
Gets the current ingame clock minute.

## GET_CLOCK_MONTH
`0x2D44E8FC79EAB1AC` | `int GET_CLOCK_MONTH()` | build 1207

## GET_CLOCK_SECONDS
`0xB6101ABE62B5F080` | `int GET_CLOCK_SECONDS()` | build 1207
Gets the current ingame clock second. Note that ingame clock seconds change really fast since a day in RDR is only 48 minutes in real life.

## GET_CLOCK_YEAR
`0xE136DCA28C4A48BA` | `int GET_CLOCK_YEAR()` | build 1207

## GET_MILLISECONDS_PER_GAME_MINUTE
`0xE4CB8D126501EC52` | `int GET_MILLISECONDS_PER_GAME_MINUTE()` | build 1207

## GET_POSIX_TIME
`0x90338AD4A784E455` | `void GET_POSIX_TIME(int* year, int* month, int* day, int* hour, int* minute, int* second)` | build 1207

## PAUSE_CLOCK
`0x4D1A590C92BF377E` | `void PAUSE_CLOCK(BOOL toggle, Any unused)` | build 1207

## SET_CLOCK_DATE
`0x02AD3092562941E2` | `void SET_CLOCK_DATE(int day, int month, int year)` | build 1207

## SET_CLOCK_TIME
`0x3A52C59FFB2DEED8` | `void SET_CLOCK_TIME(int hour, int minute, int second)` | build 1207
SET_CLOCK_TIME(12, 34, 56);

## _ADD_TIME_TO_DATE_TIME
`0x28EEACE9B43D9597` | `void _ADD_TIME_TO_DATE_TIME(Any* inDateTime, Any* timeToAdd, Any* outDateTime)` | build 1207

## _GET_POSIX_TIME_STRUCT
`0x86A68E84E5884951` | `void _GET_POSIX_TIME_STRUCT(Any* outTime)` | build 1207
Same as GET_POSIX_TIME except that it takes a single pointer to a struct.

## _GET_SECONDS_SINCE_BASE_YEAR
`0x78FD8BE812E436B2` | `int _GET_SECONDS_SINCE_BASE_YEAR()` | build 1207
Base year is 1898.

## _PAUSE_CLOCK_THIS_FRAME
`0x568D998A9FF96774` | `void _PAUSE_CLOCK_THIS_FRAME(BOOL toggle)` | build 1207

## _SET_MILLISECONDS_PER_GAME_MINUTE
`0x04EEDB3848DACF68` | `void _SET_MILLISECONDS_PER_GAME_MINUTE(int ms)` | build 1207
