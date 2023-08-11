#if defined _api_player_cosmetic_included
  #endinput
#endif
#define _api_player_cosmetic_included

#pragma reqlib api_player_cosmetic

native PlayerCosmetic_Equip(pPlayer, iModelIndex);
native bool:PlayerCosmetic_Unequip(pPlayer, iModelIndex);
native bool:PlayerCosmetic_IsEquiped(pPlayer, iModelIndex);
native PlayerCosmetic_GetEntity(pPlayer, iModelIndex);
