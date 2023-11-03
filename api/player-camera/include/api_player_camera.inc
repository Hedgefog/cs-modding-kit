#if defined _api_player_camera_included
  #endinput
#endif
#define _api_player_camera_included

#pragma reqlib api_player_camera

native PlayerCamera_Activate(pPlayer);
native PlayerCamera_Deactivate(pPlayer);
native bool:PlayerCamera_IsActive(pPlayer);
native PlayerCamera_SetOffset(pPlayer, const Float:vecOffset[3]);
native PlayerCamera_SetAngles(pPlayer, const Float:vecAngles[3]);
native PlayerCamera_SetDistance(pPlayer, Float:flDistance);
native PlayerCamera_SetThinkDelay(pPlayer, Float:flThinkDelay);

forward PlayerCamera_Fw_Activate(pPlayer);
forward PlayerCamera_Fw_Deactivate(pPlayer);
forward PlayerCamera_Fw_Activated(pPlayer);
forward PlayerCamera_Fw_Deactivated(pPlayer);
