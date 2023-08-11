#pragma semicolon 1

#include <amxmodx>
#include <hamsandwich>
#include <fakemeta>
#include <xs>

#define DIZZINESS_THINK_RATE 0.01
#define DIZZINESS_RANDOM_PUSH_RATE 1.0
#define DIZZINESS_JUMP_SPEED 200.0
#define DIZZINESS_ANGLE_HANDLE_SPEED 100.0
#define DIZZINESS_ANGLE_HANDLE_SPEED_MIN 50.0
#define DIZZINESS_ANGLE_HANDLE_SPEED_MAX 150.0
#define DIZZINESS_PUSH_SPEED 30.0
#define DIZZINESS_PUSH_SPEED_MIN 0.0
#define DIZZINESS_PUSH_SPEED_MAX 40.0
#define DIZZINESS_PUNCH_ANGLE 45.0
#define DIZZINESS_PUNCH_ANGLE_MIN 20.0
#define DIZZINESS_PUNCH_ANGLE_MAX 75.0
#define DIZZINESS_BLINK_DURATION 0.1
#define DIZZINESS_BLINK_DURATION_MIN 0.1
#define DIZZINESS_BLINK_DURATION_MAX 1.0
#define DIZZINESS_BLINK_TRANSITION_DURATION 0.75
#define DIZZINESS_BLINK_TRANSITION_DURATION_MIN 0.25
#define DIZZINESS_BLINK_TRANSITION_DURATION_MAX 1.0
#define DIZZINESS_RANDOM_BLINK_RATE 3.0
#define DIZZINESS_RANDOM_BLINK_RATE_MIN 1.0
#define DIZZINESS_RANDOM_BLINK_RATE_MAX 10.0
#define DIZZINESS_MIN_STRENGTH_TO_BLINK 0.5

new gmsgScreenFade;

new Float:g_rgflPlayerDizzinessNextThink[MAX_PLAYERS + 1];
new Float:g_rgflPlayerDizzinessStrength[MAX_PLAYERS + 1];
new Float:g_rgflPlayerNextPush[MAX_PLAYERS + 1];
new Float:g_rgvecPlayerPushVelocityTarget[MAX_PLAYERS + 1][3];
new Float:g_rgvecPlayerPushVelocityAcc[MAX_PLAYERS + 1][3];
new Float:g_rgflPlayerLastPushThink[MAX_PLAYERS + 1];
new Float:g_rgflPlayerNextPushThink[MAX_PLAYERS + 1];
new Float:g_rgflPlayerNextBlink[MAX_PLAYERS + 1];

public plugin_init() {
  register_plugin("[API] Player Dizziness", "1.0.0", "Hedgehog Fog");

  RegisterHamPlayer(Ham_Player_Jump, "HamHook_Player_Jump_Post", .Post = 1);
  RegisterHamPlayer(Ham_Player_PreThink, "HamHook_Player_PreThink_Post", .Post = 1);

  gmsgScreenFade = get_user_msgid("ScreenFade");
}

public plugin_natives() {
    register_library("api_player_dizziness");
    register_native("PlayerDizziness_Set", "Native_SetPlayerDizziness");
    register_native("PlayerDizziness_Get", "Native_GetPlayerDizziness");
}

public Native_SetPlayerDizziness(iPluginId, iArgc) {
    new pPlayer = get_param(1);
    new Float:flValue = get_param_f(2);
    
    g_rgflPlayerDizzinessStrength[pPlayer] = floatclamp(flValue, 0.0, 10.0);
}

public Float:Native_GetPlayerDizziness(iPluginId, iArgc) {
    new pPlayer = get_param(1);

    return g_rgflPlayerDizzinessStrength[pPlayer];
}

public client_connect(pPlayer) {
  g_rgflPlayerDizzinessNextThink[pPlayer] = 0.0;
  g_rgflPlayerDizzinessStrength[pPlayer] = 0.0;
  g_rgflPlayerNextPush[pPlayer] = 0.0;
  g_rgflPlayerLastPushThink[pPlayer] = 0.0;
  g_rgflPlayerNextPushThink[pPlayer] = 0.0;
  g_rgflPlayerNextBlink[pPlayer] = 0.0;

  xs_vec_copy(Float:{0.0, 0.0, 0.0}, g_rgvecPlayerPushVelocityTarget[pPlayer]);
  xs_vec_copy(Float:{0.0, 0.0, 0.0}, g_rgvecPlayerPushVelocityAcc[pPlayer]);
}

public HamHook_Player_PreThink_Post(pPlayer) {
  new Float:flGameTime = get_gametime();

  if (flGameTime >= g_rgflPlayerDizzinessNextThink[pPlayer]) {
    @Player_Think(pPlayer);
    g_rgflPlayerDizzinessNextThink[pPlayer] = flGameTime + DIZZINESS_THINK_RATE;
  }
}

public HamHook_Player_Jump_Post(pPlayer) {
  if (pev(pPlayer, pev_flags) & FL_ONGROUND && ~pev(pPlayer, pev_oldbuttons) & IN_JUMP) {
    @Player_Jump(pPlayer);
  }
}

@Player_Think(this) {
  new Float:flDizzinessStrength = g_rgflPlayerDizzinessStrength[this];
  if (flDizzinessStrength <= 0.0) {
    return;
  }

  if (pev(this, pev_flags) & FL_FROZEN) {
    return;
  }

  new Float:flGameTime = get_gametime();

  if (is_user_alive(this)) {
    static Float:vecVelocity[3];
    pev(this, pev_velocity, vecVelocity);


    new Float:flMaxPushForce = floatclamp(DIZZINESS_PUSH_SPEED * flDizzinessStrength, DIZZINESS_PUSH_SPEED_MIN, DIZZINESS_PUSH_SPEED_MAX);
    if (g_rgflPlayerNextPush[this] <= flGameTime) {
      @Player_Push(this, flMaxPushForce);
      g_rgflPlayerNextPush[this] = flGameTime + DIZZINESS_RANDOM_PUSH_RATE;
    }

    if (flDizzinessStrength >= DIZZINESS_MIN_STRENGTH_TO_BLINK) {
      if (g_rgflPlayerNextBlink[this] <= flGameTime) {
          new Float:flBlinkTransitionDuration = floatclamp(DIZZINESS_BLINK_TRANSITION_DURATION * flDizzinessStrength, DIZZINESS_BLINK_TRANSITION_DURATION_MIN, DIZZINESS_BLINK_TRANSITION_DURATION_MAX);
          new Float:flBlinkDuration = floatclamp(DIZZINESS_BLINK_DURATION * flDizzinessStrength, DIZZINESS_BLINK_DURATION_MIN, DIZZINESS_BLINK_DURATION_MAX);
          new Float:flBlinkRate = floatclamp(DIZZINESS_RANDOM_BLINK_RATE / flDizzinessStrength, DIZZINESS_RANDOM_BLINK_RATE_MIN, DIZZINESS_RANDOM_BLINK_RATE_MAX);

          @Player_Blink(this, flBlinkDuration, flBlinkTransitionDuration);
          g_rgflPlayerNextBlink[this] = flGameTime + flBlinkRate + flBlinkDuration;
      }
    }

    @Player_PushThink(this);

    new Float:flMaxPunchAngle = floatclamp(DIZZINESS_PUNCH_ANGLE * flDizzinessStrength, DIZZINESS_PUNCH_ANGLE_MIN, DIZZINESS_PUNCH_ANGLE_MAX);
    new Float:flAngleHandleSpeed = floatclamp(DIZZINESS_ANGLE_HANDLE_SPEED / flDizzinessStrength, DIZZINESS_ANGLE_HANDLE_SPEED_MIN, DIZZINESS_ANGLE_HANDLE_SPEED_MAX);
    @Player_CameraThink(this, flMaxPunchAngle, flAngleHandleSpeed);
  }
}

@Player_PushThink(this) {
  new Float:flGameTime = get_gametime();

  if (pev(this, pev_flags) & FL_ONGROUND) {
    new Float:flDelta = flGameTime - g_rgflPlayerLastPushThink[this];

    for (new i = 0; i < 3; ++i) {
      g_rgvecPlayerPushVelocityAcc[this][i] += (g_rgvecPlayerPushVelocityTarget[this][i] - g_rgvecPlayerPushVelocityAcc[this][i]) * flDelta;
    }

    static Float:vecVelocity[3];
    pev(this, pev_velocity, vecVelocity);
    xs_vec_add(vecVelocity, g_rgvecPlayerPushVelocityAcc[this], vecVelocity);
    set_pev(this, pev_velocity, vecVelocity);
  }

  g_rgflPlayerLastPushThink[this] = get_gametime();
}

@Player_CameraThink(this, Float:flMaxPunchAngle, Float:flAngleHandleSpeed) {
  static Float:vecAngles[3];
  pev(this, pev_v_angle, vecAngles);
  vecAngles[0] = 0.0;
  vecAngles[2] = 0.0;

  static Float:vecForward[3];
  angle_vector(vecAngles, ANGLEVECTOR_FORWARD, vecForward);

  static Float:vecRight[3];
  angle_vector(vecAngles, ANGLEVECTOR_RIGHT, vecRight);

  static Float:vecVelocity[3];
  pev(this, pev_velocity, vecVelocity);

  static Float:flMaxSpeed;
  pev(this, pev_maxspeed, flMaxSpeed);
  flMaxSpeed = floatmin(flMaxSpeed, flAngleHandleSpeed);

  static Float:vecPunchAngle[3];
  pev(this, pev_punchangle, vecPunchAngle);
  vecPunchAngle[0] += floatclamp(xs_vec_dot(vecVelocity, vecForward), -flMaxSpeed, flMaxSpeed) / flMaxSpeed * flMaxPunchAngle * DIZZINESS_THINK_RATE;
  vecPunchAngle[2] += floatclamp(xs_vec_dot(vecVelocity, vecRight), -flMaxSpeed, flMaxSpeed) / flMaxSpeed * flMaxPunchAngle * DIZZINESS_THINK_RATE;

  if (xs_vec_len(vecPunchAngle) > 0.0) {
    set_pev(this, pev_punchangle, vecPunchAngle);
  }
}

@Player_Push(this, Float:flMaxForce) {
  new Float:flGameTime = get_gametime();

  xs_vec_copy(Float:{0.0, 0.0, 0.0}, g_rgvecPlayerPushVelocityAcc[this]);

  g_rgvecPlayerPushVelocityTarget[this][0] = random_float(-flMaxForce, flMaxForce);
  g_rgvecPlayerPushVelocityTarget[this][1] = random_float(-flMaxForce, flMaxForce);
  g_rgvecPlayerPushVelocityTarget[this][2] = 0.0;

  g_rgflPlayerLastPushThink[this] = flGameTime;
}

@Player_Blink(this, Float:flDuration, Float:flTransitionDuration) {
    static const iFlags = 0;
    static const rgiColor[3] = {0, 0, 0};
    static const iAlpha = 255;

    new iFadeTime = FixedUnsigned16(flTransitionDuration , 1<<12);
    new iHoldTime = FixedUnsigned16(flDuration , 1<<12);

    emessage_begin(MSG_ONE, gmsgScreenFade, _, this);
    ewrite_short(iFadeTime);
    ewrite_short(iHoldTime);
    ewrite_short(iFlags);
    ewrite_byte(rgiColor[0]);
    ewrite_byte(rgiColor[1]);
    ewrite_byte(rgiColor[2]);
    ewrite_byte(iAlpha);
    emessage_end();
}

@Player_Jump(this) {
    if (g_rgflPlayerDizzinessStrength[this] < 1.0) {
      return;
    }

    static Float:vecVelocity[3];
    vecVelocity[0] = random_float(-1.0, 1.0);
    vecVelocity[1] = random_float(-1.0, 1.0);
    vecVelocity[2] = 0.0;

    xs_vec_normalize(vecVelocity, vecVelocity);
    xs_vec_mul_scalar(vecVelocity, random_float(80.0, 100.0), vecVelocity);
    vecVelocity[2] = DIZZINESS_JUMP_SPEED;

    set_pev(this, pev_velocity, vecVelocity);
}

stock FixedUnsigned16(Float:flValue, iScale) {
    return clamp(floatround(flValue * iScale), 0, 0xFFFF);
}
