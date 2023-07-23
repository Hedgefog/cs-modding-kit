#if defined _api_player_model_included
  #endinput
#endif
#define _api_player_model_included

#pragma reqlib api_player_model

native PlayerModel_Get(pPlayer, szOut[], iLen);
native PlayerModel_Set(pPlayer, const szModel[]);
native PlayerModel_Update(pPlayer);
native PlayerModel_Reset(pPlayer);
native PlayerModel_PrecacheAnimation(const szAnimation[]);
native PlayerModel_SetSequence(pPlayer, const szSequence[]);
