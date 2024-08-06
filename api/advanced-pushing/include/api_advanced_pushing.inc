#if defined _api_advanced_pushing_included
  #endinput
#endif
#define _api_advanced_pushing_included

#pragma reqlib api_advanced_pushing

enum APS_Flags (<<=1) {
  APS_Flag_None,
  APS_Flag_AddForce = 1,
  APS_Flag_AddForceInfluenceMode,
  APS_Flag_OverlapMode
};

/**
 * Pushes the entity using the given force vector.
 *
 * @param pEntity The entity to push.
 * @param vecForce The force vector to apply.
 * @param iFlags The flags for the push operation.
 *
 * @noreturn
 */
native APS_Push(pEntity, const Float:vecForce[3], APS_Flags:iFlags = APS_Flag_None);

/**
 * Pushes the entity from a specified origin with a force magnitude.
 *
 * @param pEntity The entity to push.
 * @param flForce The force magnitude to apply.
 * @param vecOrigin The origin point of the push.
 * @param iFlags The flags for the push operation.
 *
 * @noreturn
 */
native APS_PushFromOrigin(pEntity, Float:flForce, Float:vecOrigin[3], APS_Flags:iFlags = APS_Flag_None);

/**
 * Pushes the entity using a bounding box as the toucher.
 *
 * @param pEntity The entity to push.
 * @param flForce The force magnitude to apply.
 * @param vecAbsMin The absolute minimum point of the bounding box.
 * @param vecAbsMax The absolute maximum point of the bounding box.
 * @param flMinDepthRatio The minimum depth ratio for depth influence.
 * @param flMaxDepthRatio The maximum depth ratio for depth influence.
 * @param flDepthInfluenceMin The minimum depth influence.
 * @param flDepthInfluenceMax The maximum depth influence.
 * @param iFlags The flags for the push operation.
 *
 * @noreturn
 */
native APS_PushFromBBox(
  pEntity,
  Float:flForce,
  const Float:vecAbsMin[3],
  const Float:vecAbsMax[3],
  Float:flMinDepthRatio = 0.0,
  Float:flMaxDepthRatio = 1.0,
  Float:flDepthInfluenceMin = 0.0,
  Float:flDepthInfluenceMax = 1.0,
  APS_Flags:iFlags = APS_Flag_None
);

forward APS_Fw_Push(pEntity, const Float:vecForce[3], APS_Flags:iFlags);
