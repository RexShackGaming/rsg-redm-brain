# LOCALIZATION natives (4)
Source: VORPCORE/RDR3natives `rdr3natives.json`. Grep by NAME or hash.

## GET_CURRENT_LANGUAGE
`0xDB917DA5C6835FCC` | `int GET_CURRENT_LANGUAGE()` | build 1207
0 = american (en-US)
1 = french (fr-FR)
2 = german (de-DE)
3 = italian (it-IT)
4 = spanish (es-ES)
5 = brazilian (pt-BR)
6 = polish (pl-PL)
7 = russian (ru-RU)
8 = korean (ko-KR)
9 = chinesetrad (zh-TW)
10 = japanese (ja-JP)
11 = mexican (es-MX)
12 = chinesesimp (zh-CN)

## LOCALIZATION_GET_SYSTEM_DATE_TYPE
`0x76E30B799EBEEA0F` | `int LOCALIZATION_GET_SYSTEM_DATE_TYPE()` | build 1207
0 = DATE_FORMAT_DMY
1 = DATE_FORMAT_MDY
2 = DATE_FORMAT_YMD

Old name: _LOCALIZATION_GET_SYSTEM_DATE_FORMAT

## LOCALIZATION_GET_SYSTEM_LANGUAGE
`0x3C1A05F86AE6ACB5` | `int LOCALIZATION_GET_SYSTEM_LANGUAGE()` | build 1207
Same return values as GET_CURRENT_LANGUAGE

## _DOES_CURRENT_LANGUAGE_SUPPORT_CONDENSED_STYLE
`0x45D50415E4D885FF` | `BOOL _DOES_CURRENT_LANGUAGE_SUPPORT_CONDENSED_STYLE()` | build 1207
Returns true if the current language is american, french, german, italian, spanish, brazilian or mexican.
_DOES_*
