#if defined _api_player_effects_included
  #endinput
#endif
#define _api_player_effects_included

#pragma reqlib api_player_effects

#include <api_player_effects_const>

native PlayerEffect_Register(const szId[], const szInvokeFunction[], const szRevokeFunction[], const szIcon[] = "", const irgIconColor[3] = {255, 255, 255});
native PlayerEffect_Set(pPlayer, const szId[], bool:bValue, Float:flDuration = -1.0, bool:bExtend = true);
native bool:PlayerEffect_Get(pPlayer, const szId[]);
native Float:PlayerEffect_GetEndtime(pPlayer, const szId[]);
native Float:PlayerEffect_GetDuration(pPlayer, const szId[]);
