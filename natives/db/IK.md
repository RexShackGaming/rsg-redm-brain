# IK natives (5)
Source: VORPCORE/RDR3natives `rdr3natives.json`. Grep by NAME or hash.

## _0x873C792E07A32C8B
`0x873C792E07A32C8B` | `void _0x873C792E07A32C8B(Ped ped1, Ped ped2)` | build 1207

## _INVERSE_KINEMATICS_IS_ACTIVE
`0x6098139150DCC745` | `BOOL _INVERSE_KINEMATICS_IS_ACTIVE(Ped ped, int ik)` | build 1207
Get the ped ik activity state.

## _INVERSE_KINEMATICS_POINT_AT
`0x0B9F7A01EC50448D` | `void _INVERSE_KINEMATICS_POINT_AT(Ped ped, Any* parameters)` | build 1207
Make the ped point at with arms, must be called every frame.
```lua
struct parameters {
  bool isRightHand;
  Vector3 offset;
  Entity entity;
  int boneIndex;
  int flags; // (1 << 22) makes attach to point at
  int unk1; // 1-5
  int unk2; // 1-2
}
```

## _INVERSE_KINEMATICS_REQUEST_LOOK_AT
`0x66F9EB44342BB4C5` | `void _INVERSE_KINEMATICS_REQUEST_LOOK_AT(Ped ped, Any* args)` | build 1207

## _INVERSE_KINEMATICS_SET_DISABLED_FOR_PED
`0x0EABF182FBB63D72` | `void _INVERSE_KINEMATICS_SET_DISABLED_FOR_PED(Ped ped, int p1, BOOL p2)` | build 1207
Seems to disable IK on ped
