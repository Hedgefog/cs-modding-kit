#pragma semicolon 1

#include <amxmodx>
#include <fakemeta>
#include <hamsandwich>
#include <xs>

#include <cellstruct>

#define IS_PLAYER(%1) (%1 >= 1 && %1 <= MaxClients)

#define MAX_SELECTIONS 256

#define NOT_VALID_SELECTION_ERR "Selection %d is not valid selection handle!"

const Float:SelectionGroundOffset = 1.0;

new const g_szTrailModel[] = "sprites/zbeam2.spr";

enum Callback {
  Callback_PluginId,
  Callback_FunctionId
}

enum Selection {
  Selection_Index,
  bool:Selection_Active,
  bool:Selection_Free,
  Selection_Player,
  Selection_CursorEntity,
  Selection_FilterCallback[Callback],
  Array:Selection_Entities,
  Float:Selection_Cursor[3],
  Float:Selection_Start[3],
  Float:Selection_End[3],
  Selection_Color[3],
  Selection_Brightness,
  Float:Selection_NextDraw
};

new g_pTrace;
new g_iMaxEntities = 0;

new g_rgSelections[MAX_SELECTIONS][Selection];

public plugin_precache() {
  g_pTrace = create_tr2();
  g_iMaxEntities = global_get(glb_maxEntities);

  for (new iSelection = 0; iSelection < MAX_SELECTIONS; ++iSelection) {
    g_rgSelections[iSelection][Selection_Free] = true;
  }
}

public plugin_init() {
  register_plugin("[API] Entity Selection", "1.0.0", "Hedgehog Fog");

  RegisterHamPlayer(Ham_Player_PostThink, "HamHook_Player_PostThink_Post", .Post = 1);

  register_forward(FM_OnFreeEntPrivateData, "FMHook_OnFreeEntPrivateData");
}

public plugin_end() {
  free_tr2(g_pTrace);

  for (new iSelection = 0; iSelection < MAX_SELECTIONS; ++iSelection) {
    if (g_rgSelections[iSelection][Selection_Free]) continue;

    @Selection_Free(g_rgSelections[iSelection]);
  }
}

public plugin_natives() {
  register_library("api_entity_selection");
  register_native("EntitySelection_Create", "Native_CreateSelection");
  register_native("EntitySelection_Destroy", "Native_DestroySelection");
  register_native("EntitySelection_SetFilter", "Native_SetSelectionFilter");
  register_native("EntitySelection_SetColor", "Native_SetSelectionColor");
  register_native("EntitySelection_SetBrightness", "Native_SetSelectionBrightness");
  register_native("EntitySelection_GetPlayer", "Native_GetSelectionPlayer");
  register_native("EntitySelection_SetCursorEntity", "Native_SetSelectionCursorEntity");
  register_native("EntitySelection_GetCursorEntity", "Native_GetSelectionCursorEntity");
  register_native("EntitySelection_Start", "Native_StartSelection");
  register_native("EntitySelection_End", "Native_EndSelection");
  register_native("EntitySelection_GetEntity", "Native_GetSelectionEntity");
  register_native("EntitySelection_GetSize", "Native_GetSelectionSize");
  register_native("EntitySelection_GetCursorPos", "Native_GetSelectionCursorPos");
  register_native("EntitySelection_SetCursorPos", "Native_SetSelectionCursorPos");
  register_native("EntitySelection_GetStartPos", "Native_GetSelectionStartPos");
  register_native("EntitySelection_GetEndPos", "Native_GetSelectionEndPos");
}

/*--------------------------------[ Natives ]--------------------------------*/

public Native_CreateSelection(iPluginId, iArgc) {
  static pPlayer; pPlayer = get_param(1);

  new iSelection = FindFreeSelection();
  if (iSelection == -1) {
    log_error(AMX_ERR_NATIVE, "Failed to allocate new selection!");
    return -1;
  }

  @Selection_Init(g_rgSelections[iSelection], pPlayer, iSelection);

  return iSelection;
}

public Native_DestroySelection(iPluginId, iArgc) {
  static iSelection; iSelection = get_param_byref(1);

  if (!@Selection_IsValid(g_rgSelections[iSelection])) {
    log_error(AMX_ERR_NATIVE, NOT_VALID_SELECTION_ERR, iSelection);
    return;
  }

  @Selection_Free(g_rgSelections[iSelection]);

  set_param_byref(1, -1);
}

public Native_SetSelectionFilter(iPluginId, iArgc) {
  static iSelection; iSelection = get_param_byref(1);
  static szCallback[64]; get_string(2, szCallback, charsmax(szCallback));

  if (!@Selection_IsValid(g_rgSelections[iSelection])) {
    log_error(AMX_ERR_NATIVE, NOT_VALID_SELECTION_ERR, iSelection);
    return;
  }

  static iFunctionId; iFunctionId = get_func_id(szCallback, iPluginId);
  if (iFunctionId == -1) {
    log_error(AMX_ERR_NATIVE, "Cannot find function ^"%s^" in plugin %d!", szCallback, iPluginId);
    return;
  }

  @Selection_SetFilterFunction(g_rgSelections[iSelection], iFunctionId, iPluginId);
}

public Native_SetSelectionColor(iPluginId, iArgc) {
  static iSelection; iSelection = get_param_byref(1);
  static rgiColor[3]; get_array(2, rgiColor, sizeof(rgiColor));

  @Selection_SetColor(g_rgSelections[iSelection], rgiColor);
}

public Native_SetSelectionBrightness(iPluginId, iArgc) {
  static iSelection; iSelection = get_param_byref(1);
  static iBrightness; iBrightness = get_param(2);

  @Selection_SetBrightness(g_rgSelections[iSelection], iBrightness);
}

public Native_GetSelectionPlayer(iPluginId, iArgc) {
  static iSelection; iSelection = get_param_byref(1);

  if (!@Selection_IsValid(g_rgSelections[iSelection])) {
    log_error(AMX_ERR_NATIVE, NOT_VALID_SELECTION_ERR, iSelection);
    return 0;
  }

  return g_rgSelections[iSelection][Selection_Player]; 
}

public Native_GetSelectionCursorEntity(iPluginId, iArgc) {
  static iSelection; iSelection = get_param_byref(1);

  if (!@Selection_IsValid(g_rgSelections[iSelection])) {
    log_error(AMX_ERR_NATIVE, NOT_VALID_SELECTION_ERR, iSelection);
    return 0;
  }

  return g_rgSelections[iSelection][Selection_CursorEntity]; 
}

public Native_SetSelectionCursorEntity(iPluginId, iArgc) {
  static iSelection; iSelection = get_param_byref(1);
  static pCursor; pCursor = get_param(2);

  if (!@Selection_IsValid(g_rgSelections[iSelection])) {
    log_error(AMX_ERR_NATIVE, NOT_VALID_SELECTION_ERR, iSelection);
    return;
  }

  g_rgSelections[iSelection][Selection_CursorEntity] = pCursor;
}

public Native_StartSelection(iPluginId, iArgc) {
  static iSelection; iSelection = get_param_byref(1);

  if (!@Selection_IsValid(g_rgSelections[iSelection])) {
    log_error(AMX_ERR_NATIVE, NOT_VALID_SELECTION_ERR, iSelection);
    return;
  }

  if (g_rgSelections[iSelection][Selection_Active]) {
    log_error(AMX_ERR_NATIVE, "Cannot start selection! Selection is already started!");
    return;
  }

  @Selection_Start(g_rgSelections[iSelection]);
}

public Native_EndSelection(iPluginId, iArgc) {
  static iSelection; iSelection = get_param_byref(1);

  if (!@Selection_IsValid(g_rgSelections[iSelection])) {
    log_error(AMX_ERR_NATIVE, NOT_VALID_SELECTION_ERR, iSelection);
    return;
  }

  if (!g_rgSelections[iSelection][Selection_Active]) {
    log_error(AMX_ERR_NATIVE, "Cannot end selection! Selection is not started!");
    return;
  }

  @Selection_End(g_rgSelections[iSelection]);
}

public Native_GetSelectionEntity(iPluginId, iArgc) {
  static iSelection; iSelection = get_param_byref(1);
  static iIndex; iIndex = get_param(2);

  if (!@Selection_IsValid(g_rgSelections[iSelection])) {
    log_error(AMX_ERR_NATIVE, NOT_VALID_SELECTION_ERR, iSelection);
    return -1;
  }

  if (g_rgSelections[iSelection][Selection_Entities] == Invalid_Array) return -1;

  return ArrayGetCell(g_rgSelections[iSelection][Selection_Entities], iIndex);
}

public Native_GetSelectionSize(iPluginId, iArgc) {
  static iSelection; iSelection = get_param_byref(1);

  if (!@Selection_IsValid(g_rgSelections[iSelection])) {
    log_error(AMX_ERR_NATIVE, NOT_VALID_SELECTION_ERR, iSelection);
    return 0;
  }

  if (g_rgSelections[iSelection][Selection_Entities] == Invalid_Array) return 0;
  
  return ArraySize(g_rgSelections[iSelection][Selection_Entities]);
}

public Native_GetSelectionStartPos(iPluginId, iArgc) {
  static iSelection; iSelection = get_param_byref(1);

  if (!@Selection_IsValid(g_rgSelections[iSelection])) {
    log_error(AMX_ERR_NATIVE, NOT_VALID_SELECTION_ERR, iSelection);
    return;
  }

  set_array_f(2, g_rgSelections[iSelection][Selection_Start], 3);
}

public Native_GetSelectionEndPos(iPluginId, iArgc) {
  static iSelection; iSelection = get_param_byref(1);

  if (!@Selection_IsValid(g_rgSelections[iSelection])) {
    log_error(AMX_ERR_NATIVE, NOT_VALID_SELECTION_ERR, iSelection);
    return;
  }

  set_array_f(2, g_rgSelections[iSelection][Selection_End], 3);
}

public Native_GetSelectionCursorPos(iPluginId, iArgc) {
  static iSelection; iSelection = get_param_byref(1);

  if (!@Selection_IsValid(g_rgSelections[iSelection])) {
    log_error(AMX_ERR_NATIVE, NOT_VALID_SELECTION_ERR, iSelection);
    return;
  }

  @Selection_CalculateCursorPos(g_rgSelections[iSelection]);

  set_array_f(2, g_rgSelections[iSelection][Selection_Cursor], 3);
}

public Native_SetSelectionCursorPos(iPluginId, iArgc) {
  static iSelection; iSelection = get_param_byref(1);
  static Float:vecOrigin[3]; get_array_f(2, vecOrigin, 3);

  if (!@Selection_IsValid(g_rgSelections[iSelection])) {
    log_error(AMX_ERR_NATIVE, NOT_VALID_SELECTION_ERR, iSelection);
    return;
  }

  xs_vec_copy(vecOrigin, g_rgSelections[iSelection][Selection_Cursor]);
}

/*--------------------------------[ Hooks ]--------------------------------*/

public HamHook_Player_PostThink_Post(pPlayer) {
  @Player_SelectionsThink(pPlayer);
}

public FMHook_OnFreeEntPrivateData(pEntity) {
  if (!pev_valid(pEntity)) return;

  for (new iSelection = 0; iSelection < MAX_SELECTIONS; ++iSelection) {
    if (g_rgSelections[iSelection][Selection_Free]) continue;

    @Selection_RemoveEntity(g_rgSelections[iSelection], pEntity);
  }
}

/*--------------------------------[ Methods ]--------------------------------*/

@Player_SelectionsThink(this) {
  for (new iSelection = 0; iSelection < MAX_SELECTIONS; ++iSelection) {
    if (g_rgSelections[iSelection][Selection_Player] != this) continue;
    if (!g_rgSelections[iSelection][Selection_Active]) continue;

    @Selection_Think(g_rgSelections[iSelection]);
  }
}

bool:@Selection_IsValid(rgSelection[Selection]) {
  return !rgSelection[Selection_Free];
}

@Selection_Init(rgSelection[Selection], pPlayer, iIndex) {
  rgSelection[Selection_Index] = iIndex;
  rgSelection[Selection_Active] = false;
  rgSelection[Selection_Free] = false;
  rgSelection[Selection_Player] = pPlayer;
  rgSelection[Selection_CursorEntity] = pPlayer;
  rgSelection[Selection_FilterCallback][Callback_PluginId] = -1;
  rgSelection[Selection_FilterCallback][Callback_FunctionId] = -1;
  rgSelection[Selection_Color][0] = 255;
  rgSelection[Selection_Color][1] = 255;
  rgSelection[Selection_Color][2] = 255;
  rgSelection[Selection_Brightness] = 255;
  rgSelection[Selection_Entities] = ArrayCreate();
  rgSelection[Selection_NextDraw] = get_gametime();
}

@Selection_Free(rgSelection[Selection]) {  
  if (rgSelection[Selection_Entities] != Invalid_Array) {
    ArrayDestroy(rgSelection[Selection_Entities]);
  }

  rgSelection[Selection_Index] = -1;
  rgSelection[Selection_Active] = false;
  rgSelection[Selection_Free] = true;
  rgSelection[Selection_Player] = 0;
  rgSelection[Selection_CursorEntity] = 0;
  rgSelection[Selection_FilterCallback][Callback_PluginId] = -1;
  rgSelection[Selection_FilterCallback][Callback_FunctionId] = -1;
  rgSelection[Selection_Entities] = Invalid_Array;
  rgSelection[Selection_NextDraw] = 0.0;
}

@Selection_SetFilterFunction(rgSelection[Selection], iFunctionId, iPluginId) {
  rgSelection[Selection_FilterCallback][Callback_FunctionId] = iFunctionId;
  rgSelection[Selection_FilterCallback][Callback_PluginId] = iPluginId;
}

@Selection_SetColor(rgSelection[Selection], const rgiColor[3]) {
  rgSelection[Selection_Color][0] = rgiColor[0];
  rgSelection[Selection_Color][1] = rgiColor[1];
  rgSelection[Selection_Color][2] = rgiColor[2];
}

@Selection_SetBrightness(rgSelection[Selection], iBrightness) {
  rgSelection[Selection_Brightness] = iBrightness;
}

@Selection_Start(rgSelection[Selection]) {
  @Selection_CalculateCursorPos(rgSelection);

  xs_vec_copy(rgSelection[Selection_Cursor], rgSelection[Selection_Start]);

  ArrayClear(rgSelection[Selection_Entities]);

  rgSelection[Selection_Active] = true;
  rgSelection[Selection_NextDraw] = get_gametime();
}

@Selection_End(rgSelection[Selection]) {
  if (!rgSelection[Selection_Active]) return;

  xs_vec_copy(rgSelection[Selection_Cursor], rgSelection[Selection_End]);

  UTIL_NormalizeBox(rgSelection[Selection_Start], rgSelection[Selection_End]);

  static Float:flMinz; flMinz = floatmin(
    TracePointHeight(rgSelection[Selection_End], -8192.0),
    TracePointHeight(rgSelection[Selection_Start], -8192.0)
  );

  static Float:flMaxZ; flMaxZ = floatmax(
    TracePointHeight(rgSelection[Selection_End], 8192.0),
    TracePointHeight(rgSelection[Selection_Start], 8192.0)
  );

  rgSelection[Selection_Start][2] = flMinz;
  rgSelection[Selection_End][2] = flMaxZ;

  @Selection_FindEntities(rgSelection);

  rgSelection[Selection_Active] = false;
}

@Selection_Think(rgSelection[Selection]) {
  if (rgSelection[Selection_NextDraw] <= get_gametime()) {
    @Selection_CalculateCursorPos(rgSelection);
    @Selection_DrawSelection(rgSelection);
    rgSelection[Selection_NextDraw] = get_gametime() + 0.1;
  }
}

bool:@Selection_CalculateCursorPos(rgSelection[Selection]) {
  static pCursor; pCursor = rgSelection[Selection_CursorEntity];

  if (pCursor <= 0) return false;

  static Float:vecOrigin[3];
  static Float:vecAngles[3];

  if (IS_PLAYER(pCursor)) {
    ExecuteHamB(Ham_EyePosition, pCursor, vecOrigin);
    pev(pCursor, pev_v_angle, vecAngles);
  } else {
    pev(pCursor, pev_origin, vecOrigin);
    pev(pCursor, pev_angles, vecAngles); 
  }

  static Float:vecForward[3]; angle_vector(vecAngles, ANGLEVECTOR_FORWARD, vecForward);
  static Float:vecEnd[3]; xs_vec_add_scaled(vecOrigin, vecForward, 8192.0, vecEnd);

  engfunc(EngFunc_TraceLine, vecOrigin, vecEnd, DONT_IGNORE_MONSTERS, pCursor, g_pTrace);

  get_tr2(g_pTrace, TR_vecEndPos, rgSelection[Selection_Cursor]);

  return true;
}

Array:@Selection_FindEntities(rgSelection[Selection]) {
  for (new pEntity = 1; pEntity < g_iMaxEntities; ++pEntity) {
    if (!pev_valid(pEntity)) continue;
    if (!UTIL_IsEntityInBox(pEntity, rgSelection[Selection_Start], rgSelection[Selection_End])) continue;

    static bResult; bResult = true;

    if (rgSelection[Selection_FilterCallback][Callback_FunctionId] != -1) {
      callfunc_begin_i(rgSelection[Selection_FilterCallback][Callback_FunctionId], rgSelection[Selection_FilterCallback][Callback_PluginId]);
      callfunc_push_int(rgSelection[Selection_Index]);
      callfunc_push_int(pEntity);
      bResult = callfunc_end();
    }

    if (bResult) {
      ArrayPushCell(rgSelection[Selection_Entities], pEntity);
    }
  }
}

@Selection_RemoveEntity(rgSelection[Selection], pEntity) {
  if (rgSelection[Selection_Entities] == Invalid_Array) return;

  static iIndex; iIndex = ArrayFindValue(rgSelection[Selection_Entities], pEntity);
  if (iIndex == -1) return;

  ArrayDeleteItem(rgSelection[Selection_Entities], iIndex);
}

@Selection_DrawSelection(rgSelection[Selection]) {
  static pPlayer; pPlayer = rgSelection[Selection_Player];
  static iModelIndex; iModelIndex = engfunc(EngFunc_ModelIndex, g_szTrailModel);
  static Float:flHeight; flHeight = floatmax(rgSelection[Selection_Start][2], rgSelection[Selection_Cursor][2]) + SelectionGroundOffset;

  for (new i = 0; i < 4; ++i) {
    engfunc(EngFunc_MessageBegin, MSG_ONE, SVC_TEMPENTITY, Float:{0.0, 0.0, 0.0}, pPlayer);
    write_byte(TE_BEAMPOINTS);

    switch (i) {
      case 0: {
        engfunc(EngFunc_WriteCoord, rgSelection[Selection_Start][0]);
        engfunc(EngFunc_WriteCoord, rgSelection[Selection_Start][1]);
      }
      case 1: {
        engfunc(EngFunc_WriteCoord, rgSelection[Selection_Start][0]);
        engfunc(EngFunc_WriteCoord, rgSelection[Selection_Start][1]);
      }
      case 2: {
        engfunc(EngFunc_WriteCoord, rgSelection[Selection_Cursor][0]);
        engfunc(EngFunc_WriteCoord, rgSelection[Selection_Start][1]);
      }
      case 3: {
        engfunc(EngFunc_WriteCoord, rgSelection[Selection_Start][0]);
        engfunc(EngFunc_WriteCoord, rgSelection[Selection_Cursor][1]);
      }
    }

    engfunc(EngFunc_WriteCoord, flHeight);

    switch (i) {
      case 0: {
        engfunc(EngFunc_WriteCoord, rgSelection[Selection_Start][0]);
        engfunc(EngFunc_WriteCoord, rgSelection[Selection_Cursor][1]);
      }
      case 1: {
        engfunc(EngFunc_WriteCoord, rgSelection[Selection_Cursor][0]);
        engfunc(EngFunc_WriteCoord, rgSelection[Selection_Start][1]);
      }
      case 2: {
        engfunc(EngFunc_WriteCoord, rgSelection[Selection_Cursor][0]);
        engfunc(EngFunc_WriteCoord, rgSelection[Selection_Cursor][1]);
      }
      case 3: {
        engfunc(EngFunc_WriteCoord, rgSelection[Selection_Cursor][0]);
        engfunc(EngFunc_WriteCoord, rgSelection[Selection_Cursor][1]);
      }
    }

    engfunc(EngFunc_WriteCoord, flHeight);

    write_short(iModelIndex);
    write_byte(0);
    write_byte(0);
    write_byte(1);
    write_byte(16);
    write_byte(0);
    write_byte(rgSelection[Selection_Color][0]);
    write_byte(rgSelection[Selection_Color][1]);
    write_byte(rgSelection[Selection_Color][2]);
    write_byte(rgSelection[Selection_Brightness]);
    write_byte(0);
    message_end();
  }
}

/*--------------------------------[ Functions ]--------------------------------*/

FindFreeSelection() {
  for (new i = 0; i < MAX_SELECTIONS; ++i) {
    if (g_rgSelections[i][Selection_Free]) return i;
  }

  return -1;
}

Float:TracePointHeight(const Float:vecOrigin[], Float:flMaxDistance) {
  static Float:vecTarget[3];
  xs_vec_set(vecTarget, vecOrigin[0], vecOrigin[1], vecOrigin[2] + flMaxDistance);

  engfunc(EngFunc_TraceLine, vecOrigin, vecTarget, IGNORE_MONSTERS, 0, g_pTrace);

  get_tr2(g_pTrace, TR_vecEndPos, vecTarget);

  return vecTarget[2];
}

/*--------------------------------[ Stocks ]--------------------------------*/

stock UTIL_IsEntityInBox(pEntity, const Float:vecBoxMin[], const Float:vecBoxMax[]) {
  static Float:vecAbsMin[3]; pev(pEntity, pev_absmin, vecAbsMin);
  static Float:vecAbsMax[3]; pev(pEntity, pev_absmax, vecAbsMax);

  for (new i = 0; i < 3; ++i) {
    if (vecAbsMin[i] > vecBoxMax[i]) return false;
    if (vecAbsMax[i] < vecBoxMin[i]) return false;
  }

  return true;
}

stock UTIL_NormalizeBox(Float:vecMin[], Float:vecMax[]) {
  for (new i = 0; i < 3; ++i) {
    if (vecMin[i] > vecMax[i]) UTIL_FloatSwap(vecMin[i], vecMax[i]);
  }
}

stock UTIL_FloatSwap(&Float:flValue, &Float:flOther) {
  static Float:flTemp;

  flTemp = flValue;
  flValue = flOther;
  flOther = flTemp;
}
