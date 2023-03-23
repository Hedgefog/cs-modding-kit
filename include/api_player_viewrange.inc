// This is a beta version, some functions may be unstable. Use at your own risk.

#if defined _api_player_viewrange_included
  #endinput
#endif
#define _api_player_viewrange_included

#pragma reqlib api_player_viewrange

native Float:PlayerViewRange_Get(pPlayer);
native PlayerViewRange_Set(pPlayer, Float:flValue);
native PlayerViewRange_Update(pPlayer);
native PlayerViewRange_Reset(pPlayer);
