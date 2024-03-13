#if defined _api_entity_selection_included
  #endinput
#endif
#define _api_entity_selection_included

#pragma reqlib api_entity_selection

native EntitySelection_Start(pPlayer, const szFilterCb[]);
native EntitySelection_End(pPlayer);
native EntitySelection_GetEntity(pPlayer, iIndex);
native EntitySelection_GetSize(pPlayer);
native EntitySelection_GetCursorPos(pPlayer, Float:vecOut[]);
native EntitySelection_GetStartPos(pPlayer, Float:vecOut[]);
native EntitySelection_GetEndPos(pPlayer, Float:vecOut[]);
