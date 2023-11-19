#pragma semicolon 1

#include <amxmodx>
#include <fakemeta>
#include <hamsandwich>
#include <xs>

new g_rgpPlayerCamera[MAX_PLAYERS + 1];
new Float:g_rgflPlayerCameraDistance[MAX_PLAYERS + 1];
new Float:g_rgflPlayerCameraAngles[MAX_PLAYERS + 1][3];
new Float:g_rgflPlayerCameraOffset[MAX_PLAYERS + 1][3];
new bool:g_rgbPlayerCameraAxisLock[MAX_PLAYERS + 1][3];
new Float:g_rgflPlayerCameraThinkDelay[MAX_PLAYERS + 1];
new Float:g_rgflPlayerCameraNextThink[MAX_PLAYERS + 1];
new g_pPlayerTargetEntity[MAX_PLAYERS + 1];

new g_fwActivate;
new g_fwDeactivate;
new g_fwActivated;
new g_fwDeactivated;

new g_iszTriggerCameraClassname;

new g_iCameraModelIndex;

public plugin_precache() {
  g_iszTriggerCameraClassname = engfunc(EngFunc_AllocString, "trigger_camera");

  g_iCameraModelIndex = precache_model("models/rpgrocket.mdl");
}

public plugin_init() {
  register_plugin("[API] Player Camera", "1.0.0", "Hedgehog Fog");

  RegisterHamPlayer(Ham_Spawn, "HamHook_Player_Spawn_Post", .Post = 1);
  RegisterHamPlayer(Ham_Player_PreThink, "HamHook_Player_PreThink_Post", .Post = 1);

  g_fwActivate = CreateMultiForward("PlayerCamera_Fw_Activate", ET_STOP, FP_CELL);
  g_fwDeactivate = CreateMultiForward("PlayerCamera_Fw_Deactivate", ET_STOP, FP_CELL);
  g_fwActivated = CreateMultiForward("PlayerCamera_Fw_Activated", ET_IGNORE, FP_CELL);
  g_fwDeactivated = CreateMultiForward("PlayerCamera_Fw_Deactivated", ET_IGNORE, FP_CELL);
}

public plugin_natives() {
  register_library("api_player_camera");
  register_native("PlayerCamera_Activate", "Native_Activate");
  register_native("PlayerCamera_Deactivate", "Native_Deactivate");
  register_native("PlayerCamera_IsActive", "Native_IsActive");
  register_native("PlayerCamera_SetOffset", "Native_SetOffset");
  register_native("PlayerCamera_SetAngles", "Native_SetAngles");
  register_native("PlayerCamera_SetDistance", "Native_SetDistance");
  register_native("PlayerCamera_SetAxisLock", "Native_SetAxisLock");
  register_native("PlayerCamera_SetThinkDelay", "Native_SetThinkDelay");
  register_native("PlayerCamera_SetTargetEntity", "Native_SetTargetEntity");
}

public bool:Native_Activate(iPluginId, iArgc) {
  new pPlayer = get_param(1);

  ActivatePlayerCamera(pPlayer);
}

public Native_Deactivate(iPluginId, iArgc) {
  new pPlayer = get_param(1);

  DeactivatePlayerCamera(pPlayer);
}

public Native_IsActive(iPluginId, iArgc) {
  new pPlayer = get_param(1);

  return g_rgpPlayerCamera[pPlayer] != -1;
}

public Native_SetOffset(iPluginId, iArgc) {
  new pPlayer = get_param(1);

  static Float:vecOffset[3];
  get_array_f(2, vecOffset, 3);

  SetCameraOffset(pPlayer, vecOffset);
}

public Native_SetAngles(iPluginId, iArgc) {
  new pPlayer = get_param(1);

  static Float:vecAngles[3];
  get_array_f(2, vecAngles, 3);

  SetCameraAngles(pPlayer, vecAngles);
}

public Native_SetDistance(iPluginId, iArgc) {
  new pPlayer = get_param(1);
  new Float:flDistance = get_param_f(2);

  SetCameraDistance(pPlayer, flDistance);
}

public Native_SetAxisLock(iPluginId, iArgc) {
  new pPlayer = get_param(1);
  new bool:bLockPitch = bool:get_param(2);
  new bool:bLockYaw = bool:get_param(3);
  new bool:bLockRoll = bool:get_param(4);

  SetAxisLock(pPlayer, bLockPitch, bLockYaw, bLockRoll);
}

public Native_SetThinkDelay(iPluginId, iArgc) {
  new pPlayer = get_param(1);
  new Float:flThinkDelay = get_param_f(2);

  SetCameraThinkDelay(pPlayer, flThinkDelay);
}

public Native_SetTargetEntity(iPluginId, iArgc) {
  new pPlayer = get_param(1);
  new pTarget = get_param(2);

  SetCameraTarget(pPlayer, pTarget);
}

public HamHook_Player_Spawn_Post(pPlayer) {
  ReattachCamera(pPlayer);
}

public HamHook_Player_PreThink_Post(pPlayer) {
  PlayerCameraThink(pPlayer);
}

public client_connect(pPlayer) {
  g_rgpPlayerCamera[pPlayer] = -1;
  SetCameraTarget(pPlayer, pPlayer);
  SetCameraDistance(pPlayer, 200.0);
  SetAxisLock(pPlayer, false, false, false);
  SetCameraAngles(pPlayer, Float:{0.0, 0.0, 0.0});
  SetCameraOffset(pPlayer, Float:{0.0, 0.0, 0.0});
  SetCameraThinkDelay(pPlayer, 0.01);
}

public client_disconnected(pPlayer) {
  DeactivatePlayerCamera(pPlayer);
}

ActivatePlayerCamera(pPlayer) {
  if (g_rgpPlayerCamera[pPlayer] != -1) {
    return;
  }

  new iResult = 0; ExecuteForward(g_fwActivate, iResult, pPlayer);
  if (iResult != PLUGIN_CONTINUE) return;

  g_rgpPlayerCamera[pPlayer] = CreatePlayerCamera(pPlayer);
  g_rgflPlayerCameraNextThink[pPlayer] = 0.0;

  engfunc(EngFunc_SetView, pPlayer, g_rgpPlayerCamera[pPlayer]);

  ExecuteForward(g_fwActivated, _, pPlayer);
}

DeactivatePlayerCamera(pPlayer) {
  if (g_rgpPlayerCamera[pPlayer] == -1) {
    return;
  }

  new iResult = 0; ExecuteForward(g_fwDeactivate, iResult, pPlayer);
  if (iResult != PLUGIN_CONTINUE) return;

  engfunc(EngFunc_RemoveEntity, g_rgpPlayerCamera[pPlayer]);
  g_rgpPlayerCamera[pPlayer] = -1;
  g_pPlayerTargetEntity[pPlayer] = pPlayer;

  if (is_user_connected(pPlayer)) {
    engfunc(EngFunc_SetView, pPlayer, pPlayer);
  }

  ExecuteForward(g_fwDeactivated, _, pPlayer);
}

SetCameraOffset(pPlayer, const Float:vecOffset[3]) {
  xs_vec_copy(vecOffset, g_rgflPlayerCameraOffset[pPlayer]);
}

SetCameraAngles(pPlayer, const Float:vecAngles[3]) {
  xs_vec_copy(vecAngles, g_rgflPlayerCameraAngles[pPlayer]);
}

SetCameraDistance(pPlayer, Float:flDistance) {
  g_rgflPlayerCameraDistance[pPlayer] = flDistance;
}

SetAxisLock(pPlayer, bool:bLockPitch, bool:bLockYaw, bool:bLockRoll) {
  g_rgbPlayerCameraAxisLock[pPlayer][0] = bLockPitch;
  g_rgbPlayerCameraAxisLock[pPlayer][1] = bLockYaw;
  g_rgbPlayerCameraAxisLock[pPlayer][2] = bLockRoll;
}

SetCameraThinkDelay(pPlayer, Float:flThinkDelay) {
  g_rgflPlayerCameraThinkDelay[pPlayer] = flThinkDelay;
}

SetCameraTarget(pPlayer, pTarget) {
  g_pPlayerTargetEntity[pPlayer] = pTarget;
}

CreatePlayerCamera(pPlayer) {
  new pCamera = engfunc(EngFunc_CreateNamedEntity, g_iszTriggerCameraClassname);

  set_pev(pCamera, pev_classname, "trigger_camera");
  set_pev(pCamera, pev_modelindex, g_iCameraModelIndex);
  set_pev(pCamera, pev_owner, pPlayer);
  set_pev(pCamera, pev_solid, SOLID_NOT);
  set_pev(pCamera, pev_movetype, MOVETYPE_FLY);
  set_pev(pCamera, pev_rendermode, kRenderTransTexture);

  return pCamera;
}

PlayerCameraThink(pPlayer) {
  if (g_rgflPlayerCameraNextThink[pPlayer] > get_gametime()) {
    return;
  }

  g_rgflPlayerCameraNextThink[pPlayer] = get_gametime() + g_rgflPlayerCameraThinkDelay[pPlayer];

  if (g_rgpPlayerCamera[pPlayer] == -1) {
    return;
  }

  if (!is_user_alive(pPlayer)) {
    return;
  }

  static Float:vecOrigin[3];
  pev(g_pPlayerTargetEntity[pPlayer], pev_origin, vecOrigin);
  xs_vec_add(vecOrigin, g_rgflPlayerCameraOffset[pPlayer], vecOrigin);

  static Float:vecAngles[3];
  pev(g_pPlayerTargetEntity[pPlayer], pev_v_angle, vecAngles);
  for (new iAxis = 0; iAxis < 3; ++iAxis) {
    if (g_rgbPlayerCameraAxisLock[pPlayer][iAxis]) {
      vecAngles[iAxis] = 0.0;
    }
  }

  xs_vec_add(vecAngles, g_rgflPlayerCameraAngles[pPlayer], vecAngles);

  static Float:vecBack[3];
  angle_vector(vecAngles, ANGLEVECTOR_FORWARD, vecBack);
  xs_vec_neg(vecBack, vecBack);

  static Float:vecVelocity[3];
  pev(g_pPlayerTargetEntity[pPlayer], pev_velocity, vecVelocity);

  static Float:vecCameraOrigin[3];
  for (new i = 0; i < 3; ++i) {
    vecCameraOrigin[i] = vecOrigin[i] + (vecBack[i] * g_rgflPlayerCameraDistance[pPlayer]);
  }

  new pTr = create_tr2();
  engfunc(EngFunc_TraceLine, vecOrigin, vecCameraOrigin, IGNORE_MONSTERS, pPlayer, pTr);

  static Float:flFraction;
  get_tr2(pTr, TR_flFraction, flFraction);

  free_tr2(pTr);

  if(flFraction != 1.0) { 
    for (new i = 0; i < 3; ++i) {
      vecCameraOrigin[i] = vecOrigin[i] + (vecBack[i] * (g_rgflPlayerCameraDistance[pPlayer] * flFraction));
    }
  }

  set_pev(g_rgpPlayerCamera[pPlayer], pev_origin, vecCameraOrigin);
  set_pev(g_rgpPlayerCamera[pPlayer], pev_angles, vecAngles);
  set_pev(g_rgpPlayerCamera[pPlayer], pev_velocity, vecVelocity);
}

ReattachCamera(pPlayer) {
  if (g_rgpPlayerCamera[pPlayer] == -1) {
    return;
  }

  engfunc(EngFunc_SetView, pPlayer, g_rgpPlayerCamera[pPlayer]);
}
