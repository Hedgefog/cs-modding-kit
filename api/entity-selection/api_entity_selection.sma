#pragma semicolon 1

#include <amxmodx>
#include <fakemeta>
#include <hamsandwich>
#include <xs>

const Float:SelectionGroundOffset = 1.0;
new const SelectionColor[3] = {0, 255, 0};

new const g_szTrailModel[] = "sprites/zbeam2.spr";

new g_rgiSelectionFilterPluginId[MAX_PLAYERS + 1];
new g_rgiSelectionFilterFunctionId[MAX_PLAYERS + 1];
new bool:g_rgbSelectionActive[MAX_PLAYERS + 1];
new Array:g_rgirgSelectionEntities[MAX_PLAYERS + 1];
new Float:g_rgflSelectionNextDraw[MAX_PLAYERS + 1];
new Float:g_rgvecSelectionStart[MAX_PLAYERS + 1][3];
new Float:g_rgvecSelectionEnd[MAX_PLAYERS + 1][3];

new g_pTrace;

new g_iMaxEntities = 0;

public plugin_precache() {
  g_pTrace = create_tr2();
  g_iMaxEntities = global_get(glb_maxEntities);
}

public plugin_init() {
  register_plugin("[API] Entity Selection", "1.0.0", "Hedgehog Fog");

  RegisterHamPlayer(Ham_Player_PostThink, "HamHook_Player_PostThink_Post", .Post = 1);

  register_forward(FM_OnFreeEntPrivateData, "FMHook_OnFreeEntPrivateData");
}

public plugin_end() {
  free_tr2(g_pTrace);
}

public plugin_natives() {
  register_library("api_entity_selection");
  register_native("EntitySelection_Start", "Native_StartSelection");
  register_native("EntitySelection_End", "Native_EndSelection");
  register_native("EntitySelection_GetEntity", "Native_GetSelectionEntity");
  register_native("EntitySelection_GetSize", "Native_GetSelectionSize");
  register_native("EntitySelection_GetStartPos", "Native_GetStartPos");
  register_native("EntitySelection_GetEndPos", "Native_GetEndPos");
  register_native("EntitySelection_GetCursorPos", "Native_GetSelectionCursorPos");
}

/*--------------------------------[ Natives ]--------------------------------*/

public Native_StartSelection(iPluginId, iArgc) {
  static pPlayer; pPlayer = get_param(1);
  static szFilterCallback[64]; get_string(2, szFilterCallback, charsmax(szFilterCallback));

  static iFunctionId; iFunctionId = get_func_id(szFilterCallback, iPluginId);
  if (iFunctionId == -1) {
    log_error(AMX_ERR_NATIVE, "Cannot find function ^"%s^" in plugin %d!", szFilterCallback, iPluginId);
    return;
  }

  if (g_rgiSelectionFilterPluginId[pPlayer] != -1) {
    @Player_SelectionRelease(pPlayer);
  }

  @Player_SelectionInit(pPlayer, iFunctionId, iPluginId);
  @Player_SelectionStart(pPlayer);
}

public Native_EndSelection(iPluginId, iArgc) {
  static pPlayer; pPlayer = get_param(1);

  if (!g_rgbSelectionActive[pPlayer]) {
    log_error(AMX_ERR_NATIVE, "Cannot end selection! Selection is not started!");
    return;
  }

  @Player_SelectionEnd(pPlayer);
}

public Native_GetSelectionEntity(iPluginId, iArgc) {
  new pPlayer = get_param(1);
  new iIndex = get_param(2);

  if (g_rgirgSelectionEntities[pPlayer] == Invalid_Array) return -1;

  return ArrayGetCell(g_rgirgSelectionEntities[pPlayer], iIndex);
}

public Native_GetSelectionSize(iPluginId, iArgc) {
  new pPlayer = get_param(1);

  if (g_rgirgSelectionEntities[pPlayer] == Invalid_Array) return 0;
  
  return ArraySize(g_rgirgSelectionEntities[pPlayer]);
}

public Native_GetStartPos(iPluginId, iArgc) {
  new pPlayer = get_param(1);

  set_array_f(2, g_rgvecSelectionStart[pPlayer], 3);
}

public Native_GetEndPos(iPluginId, iArgc) {
  new pPlayer = get_param(1);

  set_array_f(2, g_rgvecSelectionEnd[pPlayer], 3);
}

public Native_GetSelectionCursorPos(iPluginId, iArgc) {
  new pPlayer = get_param(1);

  static Float:vecTarget[3]; @Player_GetCursorPosition(pPlayer, vecTarget);

  set_array_f(2, vecTarget, 3);
}

/*--------------------------------[ Forwards ]--------------------------------*/

public client_connect(pPlayer) {
  g_rgiSelectionFilterPluginId[pPlayer] = -1;
  g_rgiSelectionFilterFunctionId[pPlayer] = -1;
  g_rgbSelectionActive[pPlayer] = false;
  g_rgirgSelectionEntities[pPlayer] = Invalid_Array;
  g_rgflSelectionNextDraw[pPlayer] = 0.0;
}

public client_disconnected(pPlayer) {
  @Player_SelectionRelease(pPlayer);
}

/*--------------------------------[ Hooks ]--------------------------------*/

public HamHook_Player_PostThink_Post(pPlayer) {
  if (g_rgbSelectionActive[pPlayer]) {
    @Player_SelectionThink(pPlayer);
  }
}

public FMHook_OnFreeEntPrivateData(pEntity) {
  if (!pev_valid(pEntity)) return;

  for (new pPlayer = 1; pPlayer <= MaxClients; ++pPlayer) {
    @Player_RemoveEntityFronSelection(pPlayer, pEntity);
  }
}

/*--------------------------------[ Methods ]--------------------------------*/

@Player_SelectionInit(this, iFunctionId, iPluginId) {
  if (g_rgiSelectionFilterPluginId[this] != -1) return;

  g_rgiSelectionFilterPluginId[this] = iPluginId;
  g_rgiSelectionFilterFunctionId[this] = iFunctionId;
  g_rgirgSelectionEntities[this] = ArrayCreate();
}

@Player_SelectionRelease(this) {
  if (g_rgirgSelectionEntities[this] != Invalid_Array) {
    ArrayDestroy(g_rgirgSelectionEntities[this]);
  }

  g_rgbSelectionActive[this] = false;
  g_rgiSelectionFilterPluginId[this] = -1;
  g_rgiSelectionFilterFunctionId[this] = -1;
  g_rgirgSelectionEntities[this] = Invalid_Array;
}

@Player_SelectionStart(this) {
    @Player_GetCursorPosition(this, g_rgvecSelectionStart[this]);

    ArrayClear(g_rgirgSelectionEntities[this]);

    g_rgbSelectionActive[this] = true;
    g_rgflSelectionNextDraw[this] = get_gametime();
}

@Player_SelectionEnd(this) {
  if (!g_rgbSelectionActive[this]) return;

  @Player_UpdateEndPosition(this);

  UTIL_NormalizeBox(g_rgvecSelectionStart[this], g_rgvecSelectionEnd[this]);

  g_rgvecSelectionEnd[this][2] = g_rgvecSelectionStart[this][2] + @Player_GetSelectionHeight(this);

  @Player_FindEntitiesInSelection(this);

  new iEntitiesNum = ArraySize(g_rgirgSelectionEntities[this]);

  for (new i = 0; i < iEntitiesNum; ++i) {
    static pEntity; pEntity = ArrayGetCell(g_rgirgSelectionEntities[this], i);
    @Player_HighlightEntityInSelection(this, pEntity);
  }

  g_rgbSelectionActive[this] = false;
}

@Player_SelectionThink(this) {
  if (g_rgflSelectionNextDraw[this] <= get_gametime()) {
    @Player_UpdateEndPosition(this);
    @Player_DrawSelectionBox(this);
    g_rgflSelectionNextDraw[this] = get_gametime() + 0.1;
  }
}

@Player_GetCursorPosition(this, Float:vecOut[3]) {
  static Float:vecOrigin[3]; ExecuteHamB(Ham_EyePosition, this, vecOrigin);

  pev(this, pev_v_angle, vecOut);
  angle_vector(vecOut, ANGLEVECTOR_FORWARD, vecOut);
  xs_vec_add_scaled(vecOrigin, vecOut, 8192.0, vecOut);

  engfunc(EngFunc_TraceLine, vecOrigin, vecOut, DONT_IGNORE_MONSTERS, this, g_pTrace);

  get_tr2(g_pTrace, TR_vecEndPos, vecOut);
}

Float:@Player_GetSelectionHeight(this) {
  return floatmin(
    GetHeight(g_rgvecSelectionStart[this]),
    GetHeight(g_rgvecSelectionEnd[this])
  );
}

@Player_UpdateEndPosition(this) {
    @Player_GetCursorPosition(this, g_rgvecSelectionEnd[this]);
    g_rgvecSelectionEnd[this][2] = g_rgvecSelectionStart[this][2];
}

Array:@Player_FindEntitiesInSelection(this) {
  for (new pEntity = 1; pEntity < g_iMaxEntities; ++pEntity) {
    if (!pev_valid(pEntity)) continue;
    if (!UTIL_IsEntityInBox(pEntity, g_rgvecSelectionStart[this], g_rgvecSelectionEnd[this])) continue;

    callfunc_begin_i(g_rgiSelectionFilterFunctionId[this], g_rgiSelectionFilterPluginId[this]);
    callfunc_push_int(this);
    callfunc_push_int(pEntity);
    static bResult; bResult = callfunc_end();

    if (bResult) {
      ArrayPushCell(g_rgirgSelectionEntities[this], pEntity);
    }
  }
}

@Player_HighlightEntityInSelection(this, pEntity) {
  static Float:vecOrigin[3]; pev(pEntity, pev_origin, vecOrigin);
  static Float:vecMins[3]; pev(pEntity, pev_mins, vecMins);
  static Float:vecMaxs[3]; pev(pEntity, pev_maxs, vecMaxs);
  static Float:flRadius; flRadius = floatmax(vecMaxs[0] - vecMins[0], vecMaxs[1] - vecMins[1]) / 2;

  // vecOrigin[2] += vecMins[2];
  vecOrigin[2] = g_rgvecSelectionStart[this][2];

  @Player_HighlightTarget(this, vecOrigin, flRadius);
}

@Player_RemoveEntityFronSelection(this, pEntity) {
  if (g_rgirgSelectionEntities[this] == Invalid_Array) return;

  static iIndex; iIndex = ArrayFindValue(g_rgirgSelectionEntities[this], pEntity);
  if (iIndex == -1) return;

  ArrayDeleteItem(g_rgirgSelectionEntities[this], iIndex);
}

@Player_DrawSelectionBox(this) {
  engfunc(EngFunc_MessageBegin, MSG_ONE, SVC_TEMPENTITY, Float:{0.0, 0.0, 0.0}, this);
  write_byte(TE_BOX);
  engfunc(EngFunc_WriteCoord, g_rgvecSelectionStart[this][0]);
  engfunc(EngFunc_WriteCoord, g_rgvecSelectionStart[this][1]);
  engfunc(EngFunc_WriteCoord, g_rgvecSelectionStart[this][2] + SelectionGroundOffset);
  engfunc(EngFunc_WriteCoord, g_rgvecSelectionEnd[this][0]);
  engfunc(EngFunc_WriteCoord, g_rgvecSelectionEnd[this][1]);
  engfunc(EngFunc_WriteCoord, g_rgvecSelectionEnd[this][2] + SelectionGroundOffset);
  write_short(1);
  write_byte(0);
  write_byte(255);
  write_byte(0);
  message_end();
}

@Player_HighlightTarget(this, const Float:vecTarget[3], Float:flRadius) {
  static iModelIndex; iModelIndex = engfunc(EngFunc_ModelIndex, g_szTrailModel);

  engfunc(EngFunc_MessageBegin, MSG_ONE, SVC_TEMPENTITY, vecTarget, this);
  write_byte(TE_BEAMCYLINDER);
  engfunc(EngFunc_WriteCoord, vecTarget[0]);
  engfunc(EngFunc_WriteCoord, vecTarget[1]);
  engfunc(EngFunc_WriteCoord, vecTarget[2] + SelectionGroundOffset);
  engfunc(EngFunc_WriteCoord, 0.0);
  engfunc(EngFunc_WriteCoord, 0.0);
  engfunc(EngFunc_WriteCoord, vecTarget[2] + SelectionGroundOffset + flRadius);
  write_short(iModelIndex);
  write_byte(0);
  write_byte(0);
  write_byte(5);
  write_byte(8);
  write_byte(0);
  write_byte(SelectionColor[0]);
  write_byte(SelectionColor[1]);
  write_byte(SelectionColor[2]);
  write_byte(255);
  write_byte(0);
  message_end();
}

/*--------------------------------[ Functions ]--------------------------------*/

Float:GetHeight(const Float:vecOrigin[3]) {
  static Float:vecTarget[3]; xs_vec_set(vecTarget, vecOrigin[0], vecOrigin[1], vecOrigin[2] + 8192.0);

  engfunc(EngFunc_TraceLine, vecOrigin, vecTarget, IGNORE_MONSTERS, 0, g_pTrace);

  get_tr2(g_pTrace, TR_vecEndPos, vecTarget);

  return vecTarget[2] - vecOrigin[2];
}

/*--------------------------------[ Stocks ]--------------------------------*/

stock UTIL_IsEntityInBox(pEntity, const Float:vecBoxMin[3], const Float:vecBoxMax[3]) {
  static Float:vecAbsMin[3]; pev(pEntity, pev_absmin, vecAbsMin);
  static Float:vecAbsMax[3]; pev(pEntity, pev_absmax, vecAbsMax);

  for (new i = 0; i < 3; ++i) {
    if (vecAbsMin[i] > vecBoxMax[i]) return false;
    if (vecAbsMax[i] < vecBoxMin[i]) return false;
  }

  return true;
}

stock UTIL_NormalizeBox(Float:vecMin[3], Float:vecMax[3]) {
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
