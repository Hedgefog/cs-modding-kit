// This is a beta version, some functions may be unstable. Use at your own risk.

#if defined _api_player_model_included
  #endinput
#endif
#define _api_player_model_included

#pragma reqlib api_player_model

native PlayerModel_Get(pPlayer, szOut[]);
native PlayerModel_Set(pPlayer, const szModel[]);
native PlayerModel_Update(pPlayer);
native PlayerModel_Reset(pPlayer);
