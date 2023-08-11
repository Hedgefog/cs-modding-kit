#if defined _api_player_dizziness_included
  #endinput
#endif
#define _api_player_dizziness_included

#pragma reqlib api_player_dizziness

native PlayerDizziness_Set(pPlayer, Float:flStrength);
native Float:PlayerDizziness_Get(pPlayer);
