#if defined _api_entity_selection_included
  #endinput
#endif
#define _api_entity_selection_included

#pragma reqlib api_entity_selection

native Selection:EntitySelection_Create(pPlayer);
native EntitySelection_Destroy(&Selection:selection);
native EntitySelection_Start(const &Selection:selection);
native EntitySelection_SetFilter(const &Selection:selection, const szCallback[]);
native EntitySelection_SetColor(const &Selection:selection, const rgiColor[3]);
native EntitySelection_SetBrightness(const &Selection:selection, iBrightness);
native EntitySelection_End(const &Selection:selection);
native EntitySelection_GetEntity(const &Selection:selection, iIndex);
native EntitySelection_GetSize(const &Selection:selection);
native EntitySelection_GetPlayer(const &Selection:selection);
native EntitySelection_SetCursorEntity(const &Selection:selection, pCursor);
native EntitySelection_GetCursorEntity(const &Selection:selection);
native EntitySelection_GetCursorPos(const &Selection:selection, Float:vecOut[]);
native EntitySelection_GetStartPos(const &Selection:selection, Float:vecOut[]);
native EntitySelection_GetEndPos(const &Selection:selection, Float:vecOut[]);
