#pragma semicolon 1

#include <amxmodx>
#include <hamsandwich>
#include <fakemeta>
#include <xs>

#include <api_advanced_pushing_system>

#define PLAYER_PREVENT_CLIMB (1<<5)

#define IS_PLAYER(%1) (%1 >= 1 && %1 <= MaxClients)

new Float:g_flPlayerReleaseClimbBlock[MAX_PLAYERS + 1];

public plugin_init() {
  register_plugin("[API] Advanced Pushing System", "1.0.0", "Hedgehog Fog");

  RegisterHamPlayer(Ham_Spawn, "HamHook_Player_Spawn_Post", .Post = 1);
  RegisterHamPlayer(Ham_Player_PostThink, "HamHook_Player_PostThink_Post", .Post = 1);
}

public plugin_natives() {
  register_library("api_advanced_pushing_system");
  register_native("APS_Push", "Native_Push");
  register_native("APS_PushFromOrigin", "Native_PushFromOrigin");
  register_native("APS_PushFromBBox", "Native_PushFromBBox");
}

public Native_Push(iPluginId, iArgc) {
  new pEntity = get_param(1);
  new Float:vecForce[3]; get_array_f(2, vecForce, sizeof(vecForce));
  new APS_Flags:iFlags = APS_Flags:get_param(3);
  @Base_Push(pEntity, vecForce, iFlags);
}

public Native_PushFromOrigin(iPluginId, iArgc) {
  new pEntity = get_param(1);
  new Float:vecPushOrigin[3]; get_array_f(2, vecPushOrigin, sizeof(vecPushOrigin));
  new Float:flForce = get_param_f(3);
  new APS_Flags:iFlags = APS_Flags:get_param(4);

  @Base_PushFromOrigin(pEntity, flForce, vecPushOrigin, iFlags);
}

public Native_PushFromBBox(iPluginId, iArgc) {
  new pEntity = get_param(1);
  new Float:flForce = get_param_f(2);
  new Float:vecAbsMin[3]; get_array_f(3, vecAbsMin, sizeof(vecAbsMin));
  new Float:vecAbsMax[3]; get_array_f(4, vecAbsMax, sizeof(vecAbsMax));
  new Float:flMinDepthRatio = get_param_f(5);
  new Float:flMaxDepthRatio = get_param_f(6);
  new Float:flDepthInfluenceMin = get_param_f(7);
  new Float:flDepthInfluenceMax = get_param_f(8);
  new APS_Flags:iFlags = APS_Flags:get_param(9);

  @Base_PushFromBBox(pEntity, flForce, vecAbsMin, vecAbsMax, flMinDepthRatio, flMaxDepthRatio, flDepthInfluenceMin, flDepthInfluenceMax, iFlags);
}

public HamHook_Player_Spawn_Post(pPlayer) {
  @Player_ReleaseClimbPrevention(pPlayer);
}

public HamHook_Player_PostThink_Post(pPlayer) {
  if (g_flPlayerReleaseClimbBlock[pPlayer] && g_flPlayerReleaseClimbBlock[pPlayer] <= get_gametime()) {
    @Player_ReleaseClimbPrevention(pPlayer);
  }
}

@Player_SetClimbPrevention(pPlayer, bool:bValue) {
  new iPlayerFlags = pev(pPlayer, pev_iuser3);

  if (bValue) {
    iPlayerFlags |= PLAYER_PREVENT_CLIMB;
  } else {
    iPlayerFlags &= ~PLAYER_PREVENT_CLIMB;
  }

  set_pev(pPlayer, pev_iuser3, iPlayerFlags);
}

@Player_ReleaseClimbPrevention(this) {
  if (g_flPlayerReleaseClimbBlock[this]) {
    @Player_SetClimbPrevention(this, false);
    g_flPlayerReleaseClimbBlock[this] = 0.0;
  }
}

@Base_Push(this, const Float:vecForce[3], APS_Flags:iFlags) {
  static Float:vecVelocity[3];
  pev(this, pev_velocity, vecVelocity);

  if (iFlags & APS_Flag_AddForce) {
    xs_vec_add(vecVelocity, vecForce, vecVelocity);
  } else {
    for (new i = 0; i < 3; ++i) {
      if (iFlags & APS_Flag_OverlapMode) {
        vecVelocity[i] = vecForce[i] ? vecForce[i] : vecVelocity[i];
      } else {
        vecVelocity[i] = vecForce[i];
      }
    }
  }

  set_pev(this, pev_velocity, vecVelocity);

  if (IS_PLAYER(this) && ~pev(this, pev_iuser3) & PLAYER_PREVENT_CLIMB) {
    @Player_SetClimbPrevention(this, true);
    g_flPlayerReleaseClimbBlock[this] = get_gametime() + 0.1;
  }
}

@Base_PushFromOrigin(this, Float:flForce, Float:vecPushOrigin[3], APS_Flags:iFlags) {
  static Float:vecOrigin[3];
  pev(this, pev_origin, vecOrigin);

  static Float:vecForce[3];
  xs_vec_sub(vecOrigin, vecPushOrigin, vecForce);
  xs_vec_normalize(vecForce, vecForce);
  xs_vec_mul_scalar(vecForce, flForce, vecForce);

  @Base_Push(this, vecForce, iFlags);
}

@Base_PushFromBBox(
  this,
  Float:flForce,
  const Float:vecAbsMin[3],
  const Float:vecAbsMax[3],
  Float:flMinDepthRatio,
  Float:flMaxDepthRatio,
  Float:flDepthInfluenceMin,
  Float:flDepthInfluenceMax,
  APS_Flags:iFlags
) {
  static Float:vecOrigin[3];
  pev(this, pev_origin, vecOrigin);

  static Float:vecToucherAbsMin[3];
  pev(this, pev_absmin, vecToucherAbsMin);

  static Float:vecToucherAbsMax[3];
  pev(this, pev_absmax, vecToucherAbsMax);

  // Find and check intersection point
  for (new iAxis = 0; iAxis < 3; ++iAxis) {
    if (vecOrigin[iAxis] < vecAbsMin[iAxis]) {
      vecOrigin[iAxis] = vecToucherAbsMax[iAxis];
    } else if (vecOrigin[iAxis] > vecAbsMax[iAxis]) {
      vecOrigin[iAxis] = vecToucherAbsMin[iAxis];
    }

    if (vecAbsMin[iAxis] >= vecOrigin[iAxis]) return;
    if (vecAbsMax[iAxis] <= vecOrigin[iAxis]) return;
  }

  new iClosestAxis = -1;
  new pTrace = create_tr2();
  static Float:vecOffset[3]; xs_vec_copy(Float:{0.0, 0.0, 0.0}, vecOffset);

  for (new iAxis = 0; iAxis < 3; ++iAxis) {
    // Calculates the toucher's offset relative to the current axis
    static Float:flSideOffsets[2];
    flSideOffsets[0] = vecAbsMin[iAxis] - vecOrigin[iAxis];
    flSideOffsets[1] = vecAbsMax[iAxis] - vecOrigin[iAxis];

    if (iAxis == 2 && iClosestAxis != -1) {
      break;
    }

    for (new side = 0; side < 2; ++side) {
      // Check exit from current side
      static Float:vecTarget[3];
      xs_vec_copy(vecOrigin, vecTarget);
      vecTarget[iAxis] += flSideOffsets[side];
      engfunc(EngFunc_TraceMonsterHull, this, vecOrigin, vecTarget, IGNORE_MONSTERS | IGNORE_GLASS, this, pTrace);

      static Float:flFraction;
      get_tr2(pTrace, TR_flFraction, flFraction);

      // No exit, cannot push this way
      if (flFraction != 1.0) {
        flSideOffsets[side] = 0.0;
      }

      if (iAxis != 2) {
        // Save minimum offset, but ignore zero offsets
        if (!vecOffset[iAxis] || (flSideOffsets[side] && floatabs(flSideOffsets[side]) < floatabs(vecOffset[iAxis]))) {
          vecOffset[iAxis] = flSideOffsets[side];
        }
      } else {
        // Priority on bottom side
        if (flSideOffsets[0]) {
          vecOffset[iAxis] = flSideOffsets[0];
        }
      }

      // Find closest axis to push
      if (vecOffset[iAxis]) {
        if (iClosestAxis == -1 || floatabs(vecOffset[iAxis]) < floatabs(vecOffset[iClosestAxis])) {
          iClosestAxis = iAxis;
        }
      }
    }
  }

  free_tr2(pTrace);

  // Push by closest axis
  if (iClosestAxis == -1) return;
  
  static iPushDir; iPushDir = vecOffset[iClosestAxis] > 0.0 ? 1 : -1;
  static Float:vecSize[3]; xs_vec_sub(vecAbsMax, vecAbsMin, vecSize);
  static Float:flDepthRatio; flDepthRatio = floatabs(vecOffset[iClosestAxis]) / (vecSize[iClosestAxis] / 2);

  flDepthRatio = floatclamp(flDepthRatio, flMinDepthRatio, flMaxDepthRatio);

  static Float:vecForce[3]; xs_vec_copy(Float:{0.0, 0.0, 0.0}, vecForce);
  
  static bool:bInInfluence; bInInfluence = (
    flDepthRatio >= flDepthInfluenceMin &&
    flDepthRatio <= flDepthInfluenceMax
  );

  if (bInInfluence) {
    vecForce[iClosestAxis] = flForce * flDepthRatio * iPushDir;
  } else {
    vecForce[iClosestAxis] = flForce * iPushDir;

    if (iFlags & APS_Flag_AddForceInfluenceMode) {
      iFlags &= ~APS_Flag_AddForce;
    }
  }

  @Base_Push(this, vecForce, iFlags);
}
