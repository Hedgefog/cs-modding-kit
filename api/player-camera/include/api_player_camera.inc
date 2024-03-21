#if defined _api_player_camera_included
  #endinput
#endif
#define _api_player_camera_included

#pragma reqlib api_player_camera

/**
 * Activates the player's camera.
 *
 * @param pPlayer The player entity.
 *
 * @noreturn
 */
native PlayerCamera_Activate(pPlayer);

/**
 * Deactivates the player's camera.
 *
 * @param pPlayer The player entity.
 *
 * @noreturn
 */
native PlayerCamera_Deactivate(pPlayer);

/**
 * Checks if the player's camera is active.
 *
 * @param pPlayer The player entity.
 *
 * @return True if the camera is active, false otherwise.
 */
native bool:PlayerCamera_IsActive(pPlayer);

/**
 * Sets the offset of the player's camera.
 *
 * @param pPlayer     The player entity.
 * @param vecOffset   The offset vector.
 *
 * @noreturn
 */
native PlayerCamera_SetOffset(pPlayer, const Float:vecOffset[3]);

/**
 * Sets the angles of the player's camera.
 *
 * @param pPlayer     The player entity.
 * @param vecAngles   The angles vector.
 *
 * @noreturn
 */
native PlayerCamera_SetAngles(pPlayer, const Float:vecAngles[3]);

/**
 * Sets the distance of the player's camera.
 *
 * @param pPlayer    The player entity.
 * @param flDistance The distance value.
 *
 * @noreturn
 */
native PlayerCamera_SetDistance(pPlayer, Float:flDistance);

/**
 * Sets the axis lock of the player's camera.
 *
 * @param pPlayer     The player entity.
 * @param bLockPitch  Lock Pitch axis.
 * @param bLockYaw    Lock Yaw axis.
 * @param bLockRoll   Lock Roll axis.
 *
 * @noreturn
 */
native PlayerCamera_SetAxisLock(pPlayer, bool:bLockPitch, bool:bLockYaw, bool:bLockRoll);

/**
 * Sets the target entity of the player's camera.
 *
 * @param pPlayer    The player entity.
 * @param pTarget    The target entity.
 *
 * @noreturn
 */
native PlayerCamera_SetTargetEntity(pPlayer, pTarget);

/**
 * Sets the thinking delay of the player's camera.
 *
 * @param pPlayer      The player entity.
 * @param flThinkDelay The thinking delay value.
 *
 * @noreturn
 */
native PlayerCamera_SetThinkDelay(pPlayer, Float:flThinkDelay);

/**
 * Function called when the player's camera is activated.
 *
 * @param pPlayer The player entity.
 *
 * @noreturn
 */
forward PlayerCamera_Fw_Activate(pPlayer);

/**
 * Function called when the player's camera is deactivated.
 *
 * @param pPlayer The player entity.
 *
 * @noreturn
 */
forward PlayerCamera_Fw_Deactivate(pPlayer);

/**
 * Function called when the player's camera is activated.
 *
 * @param pPlayer The player entity.
 *
 * @noreturn
 */
forward PlayerCamera_Fw_Activated(pPlayer);

/**
 * Function called when the player's camera is deactivated.
 *
 * @param pPlayer The player entity.
 *
 * @noreturn
 */
forward PlayerCamera_Fw_Deactivated(pPlayer);
