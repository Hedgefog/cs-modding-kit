#pragma semicolon 1

#include <amxmodx>
#include <amxmisc>
#include <hamsandwich>
#include <fakemeta>
#include <xs>

#include <cellstruct>

#define IS_PLAYER(%1) (%1 >= 1 && %1 <= MaxClients)

#define MARKER_CLASSNAME "_wpmarker"
#define MARKER_UPDATE_RATE 0.01
#define TRACE_IGNORE_FLAGS (IGNORE_GLASS | IGNORE_MONSTERS)
#define SCREEN_SIZE_FACTOR 1024.0
#define SPRITE_MIN_SCALE 0.004

enum _:Frame {
  Frame_TopLeft,
  Frame_TopRight,
  Frame_Center,
  Frame_BottomLeft,
  Frame_BottomRight
};

enum MarkerPlayerData {
  Float:MarkerPlayerData_Origin[3],
  Float:MarkerPlayerData_Angles[3],
  Float:MarkerPlayerData_Scale,
  Float:MarkerPlayerData_LastUpdate,
  Float:MarkerPlayerData_IsVisible,
  Float:MarkerPlayerData_ShouldHide,
  Float:MarkerPlayerData_NextUpdate
};

new g_pCvarCompensation;

new g_fwCreated;
new g_fwDestroy;

new g_pTrace;
new g_iszInfoTargetClassname;
new Array:g_irgpMarkers;
new bool:g_bCompensation;

new Float:g_rgflPlayerDelay[MAX_PLAYERS + 1];
new Float:g_rgflPlayerNextDelayUpdate[MAX_PLAYERS + 1];

public plugin_precache() {
  g_pTrace = create_tr2();
  g_irgpMarkers = ArrayCreate();
  g_iszInfoTargetClassname = engfunc(EngFunc_AllocString, "info_target");

  g_fwCreated = CreateMultiForward("WaypointMarker_Fw_Created", ET_IGNORE, FP_CELL);
  g_fwDestroy = CreateMultiForward("WaypointMarker_Fw_Destroy", ET_IGNORE, FP_CELL);
}

public plugin_init() {
  register_plugin("[API] Waypoint Markers", "1.0.0", "Hedgehog Fog");

  RegisterHamPlayer(Ham_Player_PostThink, "HamHook_Player_PostThink_Post", 1);

  register_forward(FM_AddToFullPack, "FMHook_AddToFullPack", 0);
  register_forward(FM_AddToFullPack, "FMHook_AddToFullPack_Post", 1);
  register_forward(FM_CheckVisibility, "FMHook_CheckVisibility", 0);
  register_forward(FM_OnFreeEntPrivateData, "FMHook_OnFreeEntPrivateData", 0);

  g_pCvarCompensation = create_cvar("waypoint_marker_compensation", "1");

  bind_pcvar_num(g_pCvarCompensation, g_bCompensation);
}

public plugin_end() {
  free_tr2(g_pTrace);
  ArrayDestroy(g_irgpMarkers);
}

public plugin_natives() {
  register_library("api_waypoint_markers");
  register_native("WaypointMarker_Create", "Native_CreateMarker");
  register_native("WaypointMarker_SetVisible", "Native_SetVisible");
}

public Native_CreateMarker(iPluginId, iArgc) {
  new szModel[MAX_RESOURCE_PATH_LENGTH]; get_string(1, szModel, charsmax(szModel));
  new Float:vecOrigin[3]; get_array_f(2, vecOrigin, sizeof(vecOrigin));
  new Float:flScale = get_param_f(3);
  new Float:vecSize[3]; get_array_f(4, vecSize, 2);

  vecSize[2] = floatmax(vecSize[0], vecSize[1]);

  new pMarker = @Marker_Create();
  dllfunc(DLLFunc_Spawn, pMarker);
  engfunc(EngFunc_SetModel, pMarker, szModel);
  engfunc(EngFunc_SetOrigin, pMarker, vecOrigin);
  set_pev(pMarker, pev_scale, flScale);
  set_pev(pMarker, pev_size, vecSize);

  return pMarker;
}

public Native_SetVisible(iPluginId, iArgc) {
  new pMarker = get_param(1);
  new pPlayer = get_param(2);
  new bool:bValue = bool:get_param(3);

  @Marker_SetVisible(pMarker, pPlayer, bValue);
}

public HamHook_Player_PostThink_Post(pPlayer) {
  static Float:flGameTime; flGameTime = get_gametime();

  if (g_rgflPlayerNextDelayUpdate[pPlayer] <= flGameTime) {
    if (g_bCompensation) {
        static iPing, iLoss; get_user_ping(pPlayer, iPing, iLoss);
        g_rgflPlayerDelay[pPlayer] = float(iPing) / 1000.0;
    } else {
        g_rgflPlayerDelay[pPlayer] = 0.0;
    }

    g_rgflPlayerNextDelayUpdate[pPlayer] = flGameTime + 0.1;
  }

  static iMarkersNum; iMarkersNum = ArraySize(g_irgpMarkers);
  for (new iMarker = 0; iMarker < iMarkersNum; ++iMarker) {
    static pMarker; pMarker = ArrayGetCell(g_irgpMarkers, iMarker);
    @Marker_Calculate(pMarker, pPlayer, g_rgflPlayerDelay[pPlayer]);
  }
}

public FMHook_AddToFullPack(es, e, pEntity, pHost, pHostFlags, iPlayer, pSet) {
  if (!IS_PLAYER(pHost)) return FMRES_IGNORED;
  if (!is_user_alive(pHost)) return FMRES_IGNORED;
  if (is_user_bot(pHost)) return FMRES_IGNORED;
  if (!pev_valid(pEntity)) return FMRES_IGNORED;

  if (@Base_IsMarker(pEntity)) {
    static Struct:sPlayerData; sPlayerData = @Marker_GetPlayerData(pEntity, pHost);

    if (!StructGetCell(sPlayerData, MarkerPlayerData_IsVisible)) return FMRES_SUPERCEDE;
    if (StructGetCell(sPlayerData, MarkerPlayerData_ShouldHide)) return FMRES_SUPERCEDE;
  }

  return FMRES_IGNORED;
}

public FMHook_AddToFullPack_Post(es, e, pEntity, pHost, pHostFlags, iPlayer, pSet) {
  if (!IS_PLAYER(pHost)) return FMRES_IGNORED;
  if (!is_user_alive(pHost)) return FMRES_IGNORED;
  if (is_user_bot(pHost)) return FMRES_IGNORED;
  if (!pev_valid(pEntity)) return FMRES_IGNORED;

  if (@Base_IsMarker(pEntity)) {
    static Struct:sPlayerData; sPlayerData = @Marker_GetPlayerData(pEntity, pHost);

    if (!StructGetCell(sPlayerData, MarkerPlayerData_IsVisible)) return FMRES_SUPERCEDE;
    if (StructGetCell(sPlayerData, MarkerPlayerData_ShouldHide)) return FMRES_SUPERCEDE;

    static Float:vecOrigin[3]; StructGetArray(sPlayerData, MarkerPlayerData_Origin, vecOrigin, sizeof(vecOrigin));
    static Float:vecAngles[3]; StructGetArray(sPlayerData, MarkerPlayerData_Angles, vecAngles, sizeof(vecAngles));
    static Float:flScale; flScale = StructGetCell(sPlayerData, MarkerPlayerData_Scale);

    set_es(es, ES_Origin, vecOrigin);
    set_es(es, ES_Angles, vecAngles);
    set_es(es, ES_Scale, flScale);
  }

  return FMRES_HANDLED;
}

public FMHook_CheckVisibility(pEntity) {
  if (!pev_valid(pEntity)) return FMRES_IGNORED;

  if (@Base_IsMarker(pEntity)) {
    forward_return(FMV_CELL, 1);
    return FMRES_SUPERCEDE;
  }

  return FMRES_IGNORED;
}

public FMHook_OnFreeEntPrivateData(pEntity) {
  if (@Base_IsMarker(pEntity)) {
    @Marker_Free(pEntity);
  }
}

@Base_IsMarker(this) {
  static szClassName[32];
  pev(this, pev_classname, szClassName, charsmax(szClassName));

  return equal(szClassName, MARKER_CLASSNAME);
}

@Marker_Create() {
  new this = engfunc(EngFunc_CreateNamedEntity, g_iszInfoTargetClassname);

  set_pev(this, pev_classname, MARKER_CLASSNAME);
  set_pev(this, pev_scale, 1.0);
  set_pev(this, pev_rendermode, kRenderTransAdd);
  set_pev(this, pev_renderamt, 255.0);
  set_pev(this, pev_movetype, MOVETYPE_NONE);
  set_pev(this, pev_solid, SOLID_NOT);
  set_pev(this, pev_spawnflags, SF_SPRITE_STARTON);

  new Array:irgsPlayersData = ArrayCreate(1, MaxClients + 1);
  for (new pPlayer = 0; pPlayer <= MaxClients; ++pPlayer) {
    ArrayPushCell(irgsPlayersData, Invalid_Struct);
  }

  set_pev(this, pev_iuser1, irgsPlayersData);

  ArrayPushCell(g_irgpMarkers, this);

  ExecuteForward(g_fwCreated, _, this);

  return this;
}

@Marker_Free(this) {
  ExecuteForward(g_fwDestroy, _, this);

  static Array:irgsPlayersData; irgsPlayersData = Array:pev(this, pev_iuser1);

  for (new pPlayer = 1; pPlayer <= MaxClients; ++pPlayer) {
    static Struct:sPlayerData; sPlayerData = ArrayGetCell(irgsPlayersData, pPlayer);
    if (sPlayerData == Invalid_Struct) continue;
    StructDestroy(sPlayerData);
  }

  ArrayDestroy(irgsPlayersData);
}

@Marker_SetVisible(this, pPlayer, bool:bValue) {
  if (!pPlayer) {
    for (new pPlayer = 0; pPlayer <= MaxClients; ++pPlayer) {
      @Marker_SetVisible(this, pPlayer, bValue);
    }

    return;
  }

  if (!IS_PLAYER(pPlayer)) return;

  static Struct:sPlayerData; sPlayerData = @Marker_GetPlayerData(this, pPlayer);
  StructSetCell(sPlayerData, MarkerPlayerData_IsVisible, bValue);
}

@Marker_Calculate(this, pPlayer, Float:flDelay) {
  static Float:flGameTime; flGameTime = get_gametime();
  static Struct:sPlayerData; sPlayerData = @Marker_GetPlayerData(this, pPlayer);

  if (!StructGetCell(sPlayerData, MarkerPlayerData_IsVisible)) return;
  if (StructGetCell(sPlayerData, MarkerPlayerData_NextUpdate) > flGameTime) return;

  static Float:flLastUpdate; flLastUpdate = StructGetCell(sPlayerData, MarkerPlayerData_LastUpdate);
  static Float:flDelta; flDelta = flGameTime - flLastUpdate;

  static Float:vecViewOrigin[3];
  ExecuteHam(Ham_Player_GetGunPosition, pPlayer, vecViewOrigin);

  if (g_bCompensation) {
    static Float:vecVelocity[3];
    pev(pPlayer, pev_velocity, vecVelocity);
    xs_vec_add_scaled(vecViewOrigin, vecVelocity, flDelay * flDelta, vecViewOrigin);
  }

  static Float:vecOrigin[3]; pev(this, pev_origin, vecOrigin);
  if (!ExecuteHamB(Ham_FVecInViewCone, pPlayer, vecOrigin)) {
    StructSetCell(sPlayerData, MarkerPlayerData_ShouldHide, true);
    return;
  }

  static Float:vecAngles[3];
  xs_vec_sub(vecOrigin, vecViewOrigin, vecAngles);
  xs_vec_normalize(vecAngles, vecAngles);
  vector_to_angle(vecAngles, vecAngles);
  vecAngles[0] = -vecAngles[0];

  static iFov; iFov = get_ent_data(pPlayer, "CBasePlayer", "m_iFOV");
  static Float:flDistance; flDistance = xs_vec_distance(vecViewOrigin, vecOrigin);
  static Float:vecSize[3]; pev(this, pev_size, vecSize);
  static Float:vecForward[3]; angle_vector(vecAngles, ANGLEVECTOR_FORWARD, vecForward);
  static Float:vecUp[3]; angle_vector(vecAngles, ANGLEVECTOR_UP, vecUp);
  static Float:vecRight[3]; angle_vector(vecAngles, ANGLEVECTOR_RIGHT, vecRight);
  static Float:flFrameScale; flFrameScale = CalculateDistanceScaleFactor(flDistance, iFov);

  static Float:rgFrame[Frame][3];
  CreateFrame(vecOrigin, vecSize[0] * flFrameScale, vecSize[1] * flFrameScale, vecUp, vecRight, rgFrame);
  TraceFrame(vecViewOrigin, rgFrame, pPlayer, rgFrame);

  static Float:flProjectionDistance; flProjectionDistance = xs_vec_distance(rgFrame[Frame_Center], vecViewOrigin);

  static Float:flScale; pev(this, pev_scale, flScale);
  flScale *= CalculateDistanceScaleFactor(flProjectionDistance, iFov);
  flScale = floatmax(flScale, SPRITE_MIN_SCALE);

  static Float:flDepth; flDepth = floatmin((vecSize[2] / 2) * flScale, flProjectionDistance);
  MoveFrame(rgFrame, vecForward, -flDepth, rgFrame);

  StructSetCell(sPlayerData, MarkerPlayerData_ShouldHide, false);
  StructSetCell(sPlayerData, MarkerPlayerData_Scale, flScale);
  StructSetArray(sPlayerData, MarkerPlayerData_Origin, rgFrame[Frame_Center], sizeof(rgFrame[]));
  StructSetArray(sPlayerData, MarkerPlayerData_Angles, vecAngles, sizeof(vecAngles));
  StructSetCell(sPlayerData, MarkerPlayerData_LastUpdate, flGameTime);
  StructSetCell(sPlayerData, MarkerPlayerData_NextUpdate, flGameTime + MARKER_UPDATE_RATE);
}

Struct:@Marker_GetPlayerData(this, pPlayer) {
  static Array:irgsPlayersData; irgsPlayersData = Array:pev(this, pev_iuser1);
  static Struct:sPlayerData; sPlayerData = ArrayGetCell(irgsPlayersData, pPlayer);

  if (sPlayerData == Invalid_Struct) {
    sPlayerData = StructCreate(MarkerPlayerData);
    StructSetCell(sPlayerData, MarkerPlayerData_IsVisible, true);
    StructSetCell(sPlayerData, MarkerPlayerData_ShouldHide, false);
    StructSetCell(sPlayerData, MarkerPlayerData_LastUpdate, get_gametime());
    StructSetCell(sPlayerData, MarkerPlayerData_NextUpdate, get_gametime());
    ArraySetCell(irgsPlayersData, pPlayer, sPlayerData);
  }

  return sPlayerData;
}

CreateFrame(const Float:vecOrigin[3], Float:flWidth, Float:flHeight, const Float:vecUp[3], const Float:vecRight[3], Float:rgFrameOut[Frame][3]) {
  static Float:flHalfWidth; flHalfWidth = flWidth / 2;
  static Float:flHalfHeight; flHalfHeight = flHeight / 2;

  for (new iAxis = 0; iAxis < 3; ++iAxis) {
    rgFrameOut[Frame_TopLeft][iAxis] = vecOrigin[iAxis] + (-vecRight[iAxis] * flHalfWidth) + (vecUp[iAxis] * flHalfHeight);
    rgFrameOut[Frame_TopRight][iAxis] = vecOrigin[iAxis] + (vecRight[iAxis] * flHalfWidth) + (vecUp[iAxis] * flHalfHeight);
    rgFrameOut[Frame_BottomLeft][iAxis] = vecOrigin[iAxis] + (-vecRight[iAxis] * flHalfWidth) + (-vecUp[iAxis] * flHalfHeight);
    rgFrameOut[Frame_BottomRight][iAxis] = vecOrigin[iAxis] + (vecRight[iAxis] * flHalfWidth) + (-vecUp[iAxis] * flHalfHeight);
    rgFrameOut[Frame_Center][iAxis] = vecOrigin[iAxis];
  }
}

Float:TraceFrame(const Float:vecViewOrigin[3], const Float:rgFrame[Frame][3], pIgnore, Float:rgFrameOut[Frame][3]) {
  static Float:flMinFraction; flMinFraction = 1.0;

  for (new iFramePoint = 0; iFramePoint < Frame; ++iFramePoint) {
    engfunc(EngFunc_TraceLine, vecViewOrigin, rgFrame[iFramePoint], TRACE_IGNORE_FLAGS, pIgnore, g_pTrace);

    static Float:flFraction; get_tr2(g_pTrace, TR_flFraction, flFraction);
    if (flFraction < flMinFraction) {
      flMinFraction = flFraction;
    }
  }

  if (flMinFraction < 1.0) {
    for (new iFramePoint = 0; iFramePoint < Frame; ++iFramePoint) {
      for (new iAxis = 0; iAxis < 3; ++iAxis) {
        rgFrameOut[iFramePoint][iAxis] = vecViewOrigin[iAxis] + ((rgFrame[iFramePoint][iAxis] - vecViewOrigin[iAxis]) * flMinFraction);
      }
    }
  }

  return flMinFraction;
}

MoveFrame(const Float:rgFrame[Frame][3], const Float:vecDirection[3], Float:flDistance, Float:rgFrameOut[Frame][3]) {
  for (new iFramePoint = 0; iFramePoint < Frame; ++iFramePoint) {
    for (new iAxis = 0; iAxis < 3; ++iAxis) {
      rgFrameOut[iFramePoint][iAxis] = rgFrame[iFramePoint][iAxis] + (vecDirection[iAxis] * flDistance);
    }
  }
}

Float:CalculateDistanceScaleFactor(Float:flDistance, iFov = 90) {
  static Float:flAngle; flAngle = floattan(xs_deg2rad(float(iFov) / 2));
  static Float:flScaleFactor; flScaleFactor = ((2 * flAngle) / SCREEN_SIZE_FACTOR) * flDistance;

  return flScaleFactor;
}
