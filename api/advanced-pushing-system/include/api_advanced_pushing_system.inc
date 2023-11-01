#if defined _api_advanced_pushing_system_included
  #endinput
#endif
#define _api_advanced_pushing_system_included

#pragma reqlib api_advanced_pushing_system

enum APS_Flags (<<=1) {
  APS_Flag_None,
  APS_Flag_AddForce = 1,
  APS_Flag_AddForceInfluenceMode,
  APS_Flag_OverlapMode
};

native APS_Push(pEntity, const Float:vecForce[3], APS_Flags:iFlags = APS_Flag_None);
native APS_PushFromOrigin(pEntity, Float:flForce, Float:vecOrigin[3], APS_Flags:iFlags = APS_Flag_None);
native APS_PushFromBBox(
  pEntity,
  Float:flForce,
  const Float:vecAbsMin[3],
  const Float:vecToucherAbsMax[3],
  Float:flMinDepthRatio = 0.0,
  Float:flMaxDepthRatio = 1.0,
  Float:flDepthInfluenceMin = 0.0,
  Float:flDepthInfluenceMax = 1.0,
  APS_Flags:iFlags = APS_Flag_None
);
