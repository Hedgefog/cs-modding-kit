#pragma semicolon 1

#include <amxmodx>
#include <amxmisc>
#include <hamsandwich>
#include <fakemeta>
#tryinclude <reapi>

#define MAX_TEAMS 8

enum GameState {
  GameState_NewRound,
  GameState_RoundStarted,
  GameState_RoundEnd
};

enum _:Hook {
  Hook_PluginId,
  Hook_FunctionId
};

new GameState:g_iGameState;
new bool:g_bIsCStrike;

new g_iFwNewRound;
new g_iFwRoundStart;
new g_iFwRoundEnd;
new g_iFwRoundExpired;
new g_iFwRoundRestart;
new g_iFwRoundTimerTick;
new g_iFwUpdateTimer;
new g_iFwCheckWinConditions;

new g_pCvarRoundEndDelay;

new g_pCvarRoundTime;
new g_pCvarFreezeTime;
new g_pCvarMaxRounds;
new g_pCvarWinLimits;
new g_pCvarRestartRound;
new g_pCvarRestart;

new bool:g_bUseCustomRounds = false;
new g_iIntroRoundTime = 2;
new g_iRoundWinTeam = 0;
new g_iRoundTime = 0;
new g_iRoundTimeSecs = 2;
new g_iTotalRoundsPlayed = 0;
new g_iMaxRounds = 0;
new g_iMaxRoundsWon = 0;
new Float:g_flRoundStartTime = 0.0;
new Float:g_flRoundStartTimeReal = 0.0;
new Float:g_flRestartRoundTime = 0.0;
new Float:g_flNextPeriodicThink = 0.0;
new Float:g_flNextThink = 0.0;
new bool:g_bRoundTerminating = false;
new bool:g_bFreezePeriod = true;
new bool:g_bGameStarted = false;
new bool:g_bCompleteReset = false;
new bool:g_bNeededPlayers = false;
new g_iSpawnablePlayersNum = 0;
new g_rgiWinsNum[MAX_TEAMS];

public plugin_precache() {
  g_bIsCStrike = !!cstrike_running();
}

public plugin_init() {
  register_plugin("[API] Rounds", "2.1.0", "Hedgehog Fog");

  if (g_bIsCStrike) {
    register_event("HLTV", "Event_NewRound", "a", "1=0", "2=0");
  }

  #if defined _reapi_included
    RegisterHookChain(RG_CSGameRules_RestartRound, "HC_RestartRound", .post = 0);
    RegisterHookChain(RG_CSGameRules_OnRoundFreezeEnd, "HC_OnRoundFreezeEnd_Post", .post = 1);
    RegisterHookChain(RG_RoundEnd, "HC_RoundEnd", .post = 1);
    RegisterHookChain(RG_CSGameRules_CheckWinConditions, "HC_CheckWinConditions", .post = 0);

    g_pCvarRoundEndDelay = get_cvar_pointer("mp_round_restart_delay");
  #endif

  g_iFwNewRound = CreateMultiForward("Round_Fw_NewRound", ET_IGNORE);
  g_iFwRoundStart = CreateMultiForward("Round_Fw_RoundStart", ET_IGNORE);
  g_iFwRoundEnd = CreateMultiForward("Round_Fw_RoundEnd", ET_IGNORE, FP_CELL);
  g_iFwRoundExpired = CreateMultiForward("Round_Fw_RoundExpired", ET_IGNORE);
  g_iFwRoundRestart = CreateMultiForward("Round_Fw_RoundRestart", ET_IGNORE);
  g_iFwRoundTimerTick = CreateMultiForward("Round_Fw_RoundTimerTick", ET_IGNORE);
  g_iFwUpdateTimer = CreateMultiForward("Round_Fw_UpdateTimer", ET_IGNORE);
  g_iFwCheckWinConditions = CreateMultiForward("Round_Fw_CheckWinConditions", ET_STOP);
}

public plugin_natives() {
  register_library("api_rounds");
  register_native("Round_UseCustomRounds", "Native_UseCustomRounds");
  register_native("Round_DispatchWin", "Native_DispatchWin");
  register_native("Round_TerminateRound", "Native_TerminateRound");
  register_native("Round_GetTime", "Native_GetTime");
  register_native("Round_SetTime", "Native_SetTime");
  register_native("Round_GetIntroTime", "Native_GetIntroTime");
  register_native("Round_GetStartTime", "Native_GetStartTime");
  register_native("Round_GetRestartRoundTime", "Native_GetRestartRoundTime");
  register_native("Round_GetRemainingTime", "Native_GetRemainingTime");
  register_native("Round_IsFreezePeriod", "Native_IsFreezePeriod");
  register_native("Round_IsRoundStarted", "Native_IsRoundStarted");
  register_native("Round_IsRoundEnd", "Native_IsRoundEnd");
  register_native("Round_IsRoundTerminating", "Native_IsRoundTerminating");
  register_native("Round_IsPlayersNeeded", "Native_IsPlayersNeeded");
  register_native("Round_IsCompleteReset", "Native_IsCompleteReset");
  register_native("Round_CheckWinConditions", "Native_CheckWinConditions");
}

public client_putinserver(pPlayer) {
  if (!g_bUseCustomRounds) return;

  CheckWinConditions();
}

public client_disconnected(pPlayer) {
  if (!g_bUseCustomRounds) return;

  CheckWinConditions();
}

public HamHook_Player_Spawn_Post(pPlayer) {
  if (!g_bUseCustomRounds) return;
  if (!is_user_alive(pPlayer)) return;

  if (g_bFreezePeriod) {
    set_pev(pPlayer, pev_flags, pev(pPlayer, pev_flags) | FL_FROZEN);
  } else {
    set_pev(pPlayer, pev_flags, pev(pPlayer, pev_flags) & ~FL_FROZEN);
  }
}

public HamHook_Player_Killed(pPlayer) {
  if (!g_bUseCustomRounds) return;

  set_pev(pPlayer, pev_flags, pev(pPlayer, pev_flags) & ~FL_FROZEN);
}

public HamHook_Player_Killed_Post(pPlayer) {
  if (!g_bUseCustomRounds) return;

  CheckWinConditions();
}

public server_frame() {
  static Float:flGameTime; flGameTime = get_gametime();
  static Float:flNextPeriodicThink; 
  
  if (g_bUseCustomRounds) {
    flNextPeriodicThink = g_flNextPeriodicThink;
  } else if (g_bIsCStrike) {
    flNextPeriodicThink = get_gamerules_float("CHalfLifeMultiplay", "m_tmNextPeriodicThink");
  } else {
    return;
  }

  if (g_bUseCustomRounds) {
    if (g_flNextThink <= flGameTime) {
      RoundThink();
      g_flNextThink = flGameTime + 0.1;
    }
  }

  if (flNextPeriodicThink <= flGameTime) {
    ExecuteForward(g_iFwRoundTimerTick);

    static iRoundTimeSecs;
    static Float:flStartTime;
    static bool:bFreezePeriod;

    if (g_bUseCustomRounds) {
      iRoundTimeSecs = g_iRoundTimeSecs;
      flStartTime = g_flRoundStartTimeReal;
      bFreezePeriod = g_bFreezePeriod;
    } else if (g_bIsCStrike) {
      iRoundTimeSecs = get_gamerules_int("CHalfLifeMultiplay", "m_iRoundTimeSecs");
      flStartTime = get_gamerules_float("CHalfLifeMultiplay", "m_fIntroRoundCount");
      bFreezePeriod = get_gamerules_int("CGameRules", "m_bFreezePeriod");
    }

    if (!bFreezePeriod && flGameTime >= flStartTime + float(iRoundTimeSecs)) {
      ExecuteForward(g_iFwRoundExpired);
    }
  }
}

#if defined _reapi_included
  public HC_RestartRound() {
    if (g_bUseCustomRounds) return;

    ExecuteForward(g_iFwRoundRestart);
  }

  public HC_OnRoundFreezeEnd_Post() {
    if (g_bUseCustomRounds) return;

    g_iGameState = GameState_RoundStarted;
    ExecuteForward(g_iFwRoundStart);
  }

  public Event_NewRound() {
    if (g_bUseCustomRounds) return;

    g_iGameState = GameState_NewRound;
    ExecuteForward(g_iFwNewRound);
  }

  public HC_RoundEnd(WinStatus:iStatus, ScenarioEventEndRound:iEvent, Float:flDelay) {
    if (g_bUseCustomRounds) return;

    new iTeam;

    switch (iStatus) {
      case WINSTATUS_CTS: iTeam = 1;
      case WINSTATUS_TERRORISTS: iTeam = 2;
      case WINSTATUS_DRAW: iTeam = 3;
    }

    g_iGameState = GameState_RoundEnd;
    ExecuteForward(g_iFwRoundEnd, _, iTeam);
  }

  public HC_CheckWinConditions() {
    if (g_bUseCustomRounds) return HC_CONTINUE;

    static iReturn;

    ExecuteForward(g_iFwCheckWinConditions, iReturn);
    if (iReturn != PLUGIN_CONTINUE) return HC_SUPERCEDE;

    return HC_CONTINUE;
  }
#endif

StartCustomRounds() {
  if (g_bUseCustomRounds) return;

  RegisterHamPlayer(Ham_Spawn, "HamHook_Player_Spawn_Post", .Post = 1);
  RegisterHamPlayer(Ham_Killed, "HamHook_Player_Killed", .Post = 0);
  RegisterHamPlayer(Ham_Killed, "HamHook_Player_Killed_Post", .Post = 1);

  if (!cvar_exists("mp_roundtime")) register_cvar("mp_roundtime", "5.0");
  if (!cvar_exists("mp_freezetime")) register_cvar("mp_freezetime", "6.0");
  if (!cvar_exists("mp_maxrounds")) register_cvar("mp_maxrounds", "0");
  if (!cvar_exists("mp_winlimit")) register_cvar("mp_winlimit", "0");
  if (!cvar_exists("sv_restart")) register_cvar("sv_restart", "0");
  if (!cvar_exists("sv_restartround")) register_cvar("sv_restartround", "0");
  if (!cvar_exists("mp_round_restart_delay")) register_cvar("mp_round_restart_delay", "5.0");

  g_pCvarRoundTime = get_cvar_pointer("mp_roundtime");
  g_pCvarFreezeTime = get_cvar_pointer("mp_freezetime");
  g_pCvarMaxRounds = get_cvar_pointer("mp_maxrounds");
  g_pCvarWinLimits = get_cvar_pointer("mp_winlimit");
  g_pCvarRestart = get_cvar_pointer("sv_restart");
  g_pCvarRestartRound = get_cvar_pointer("sv_restartround");
  g_pCvarRoundEndDelay = get_cvar_pointer("mp_round_restart_delay");

  g_iMaxRounds = max(get_pcvar_num(g_pCvarMaxRounds), 0);
  g_iMaxRoundsWon = max(get_pcvar_num(g_pCvarWinLimits), 0);

  ReadMultiplayCvars();

  g_bUseCustomRounds = true;
}

public Native_UseCustomRounds(iPluginId, iArgc) {
  StartCustomRounds();
}

public Native_DispatchWin(iPluginId, iArgc) {
  new iTeam = get_param(1);
  new Float:flDelay = get_param_f(2);

  DispatchWin(iTeam, flDelay);
}

public Native_TerminateRound(iPluginId, iArgc) {
  new Float:flDelay = get_param_f(1);
  new iTeam = get_param(2);

  if (g_bUseCustomRounds) {
    TerminateRound(flDelay, iTeam);
  } else {
    DispatchWin(iTeam, flDelay);
  }
}

public Native_GetTime(iPluginId, iArgc) {
  if (g_bUseCustomRounds) {
    return g_iRoundTimeSecs;
  } else if (g_bIsCStrike) {
    return get_gamerules_int("CHalfLifeMultiplay", "m_iRoundTimeSecs");
  }

  return 0;
}

public Native_SetTime(iPluginId, iArgc) {
  new iTime = get_param(1);

  SetTime(iTime);
}

public Native_GetIntroTime(iPluginId, iArgc) {
  if (g_bUseCustomRounds) {
    return g_iIntroRoundTime;
  } else if (g_bIsCStrike) {
    return get_gamerules_int("CHalfLifeMultiplay", "m_iIntroRoundTime");
  }

  return 0;
}

public Float:Native_GetStartTime(iPluginId, iArgc) {
  if (g_bUseCustomRounds) {
    return g_flRoundStartTime;
  } else if (g_bIsCStrike) {
    return get_gamerules_float("CHalfLifeMultiplay", "m_fRoundStartTime");
  }

  return 0.0;
}

public Float:Native_GetRestartRoundTime(iPluginId, iArgc) {
  if (g_bUseCustomRounds) {
    return g_flRestartRoundTime;
  } else if (g_bIsCStrike) {
    return get_gamerules_float("CHalfLifeMultiplay", "m_flRestartRoundTime");
  }

  return 0.0;
}

public Float:Native_GetRemainingTime(iPluginId, iArgc) {
  return GetRoundRemainingTime();
}

public bool:Native_IsFreezePeriod(iPluginId, iArgc) {
  if (g_bUseCustomRounds) {
    return g_bFreezePeriod;
  } else if (g_bIsCStrike) {
    return get_gamerules_int("CHalfLifeMultiplay", "m_bFreezePeriod");
  }

  return false;
}

public bool:Native_IsRoundStarted(iPluginId, iArgc) {
  return g_iGameState > GameState_NewRound;
}

public bool:Native_IsRoundEnd(iPluginId, iArgc) {
  return g_iGameState == GameState_RoundEnd;
}

public bool:Native_IsRoundTerminating(iPluginId, iArgc) {
  if (g_bUseCustomRounds) {
    return g_bRoundTerminating;
  } else if (g_bIsCStrike) {
    return get_gamerules_int("CHalfLifeMultiplay", "m_bRoundTerminating");
  }

  return false;
}

public bool:Native_IsPlayersNeeded(iPluginId, iArgc) {
  if (g_bUseCustomRounds) {
    return g_bNeededPlayers;
  } else if (g_bIsCStrike) {
    return get_gamerules_int("CHalfLifeMultiplay", "m_bNeededPlayers");
  }

  return false;
}

public bool:Native_IsCompleteReset(iPluginId, iArgc) {
  if (g_bUseCustomRounds) {
    return g_bCompleteReset;
  } else if (g_bIsCStrike) {
    return get_gamerules_int("CHalfLifeMultiplay", "m_bCompleteReset");
  }

  return false;
}

public bool:Native_CheckWinConditions(iPluginId, iArgc) {
  if (g_bUseCustomRounds) {
    CheckWinConditions();
  } else {
    #if defined _reapi_included
      rg_check_win_conditions();
    #endif
  }
}

DispatchWin(iTeam, Float:flDelay = -1.0) {
  if (g_iGameState == GameState_RoundEnd) return;

  if (flDelay < 0.0) {
    flDelay = g_pCvarRoundEndDelay ? get_pcvar_float(g_pCvarRoundEndDelay) : 5.0;
  }

  if (!iTeam) return;

  if (!g_bUseCustomRounds) {
    #if defined _reapi_included
      if (iTeam > 3) return;

      new WinStatus:iWinstatus = WINSTATUS_DRAW;
      if (iTeam == 1) {
        iWinstatus = WINSTATUS_TERRORISTS;
      } else if (iTeam == 2) {
        iWinstatus = WINSTATUS_CTS;
      }

      new ScenarioEventEndRound:iEvent = ROUND_END_DRAW;
      if (iTeam == 1) {
        iEvent = ROUND_TERRORISTS_WIN;
      } else if (iTeam == 2) {
        iEvent = ROUND_CTS_WIN;
      }

      rg_round_end(flDelay, iWinstatus, iEvent, _, _, true);
      rg_update_teamscores(iTeam == 2 ? 1 : 0, iTeam == 1 ? 1 : 0);
    #endif
  } else {
    EndRound(flDelay, iTeam);
  }
}

SetTime(iTime) {
  if (g_bUseCustomRounds) {
    g_iRoundTime = iTime;
    g_iRoundTimeSecs = iTime;
    g_flRoundStartTime = g_flRoundStartTimeReal;
  } else if (g_bIsCStrike) {
    new Float:flStartTime = get_gamerules_float("CHalfLifeMultiplay", "m_fIntroRoundCount");
    set_gamerules_int("CHalfLifeMultiplay", "m_iRoundTime", iTime);
    set_gamerules_int("CHalfLifeMultiplay", "m_iRoundTimeSecs", iTime);
    set_gamerules_float("CHalfLifeMultiplay", "m_fRoundStartTime", flStartTime);
  }

  UpdateTimer();
}

UpdateTimer() {
  static iRemainingTime; iRemainingTime = floatround(GetRoundRemainingTime(), floatround_floor);

  if (g_bIsCStrike) {
      static iMsgId = 0;
      if(!iMsgId) iMsgId = get_user_msgid("RoundTime");

      message_begin(MSG_ALL, iMsgId);
      write_short(iRemainingTime);
      message_end();
  }

  ExecuteForward(g_iFwUpdateTimer, _, iRemainingTime);
}

EndRound(const Float:flDelay, iTeam, const szMessage[] = "") {
    EndRoundMessage(szMessage);
    TerminateRound(flDelay, iTeam);
}

CheckWinConditions() {
    static iReturn; ExecuteForward(g_iFwCheckWinConditions, iReturn);

    if (g_iRoundWinTeam) {
      InitializePlayerCounts();
      return;
    }

    if (iReturn != PLUGIN_CONTINUE) return;
    if (g_bGameStarted && g_iRoundWinTeam) return;

    InitializePlayerCounts();

    g_bNeededPlayers = false;

    if (NeededPlayersCheck()) return;
}

RestartRound() {
  if (!g_bCompleteReset) {
    g_iTotalRoundsPlayed++;
  }

  if (g_bCompleteReset) {
    g_iTotalRoundsPlayed = 0;
    g_iMaxRounds = max(get_pcvar_num(g_pCvarMaxRounds), 0);
    g_iMaxRoundsWon = max(get_pcvar_num(g_pCvarWinLimits), 0);

    for (new i = 0; i < sizeof(g_rgiWinsNum); ++i) {
      g_rgiWinsNum[i] = 0;
    }
  }

  ExecuteForward(g_iFwRoundRestart);

  g_bFreezePeriod = true;
  g_bRoundTerminating = false;

  ReadMultiplayCvars();

  g_iRoundTimeSecs = g_iIntroRoundTime;
  g_flRoundStartTime = g_flRoundStartTimeReal = get_gametime();

  CleanUpMap();

  for (new pPlayer = 1; pPlayer <= MaxClients; ++pPlayer) {
    if (!is_user_connected(pPlayer)) continue;
    if (pev(pPlayer, pev_flags) == FL_DORMANT) continue;

    PlayerRoundRespawn(pPlayer);
  }

  CleanUpMap();

  g_flRestartRoundTime = 0.0;
  g_iRoundWinTeam = 0;
  g_bCompleteReset = false;

  g_iGameState = GameState_NewRound;
  ExecuteForward(g_iFwNewRound);
}

RoundThink() {
  if (!g_flRoundStartTime) {
    g_flRoundStartTime = g_flRoundStartTimeReal = get_gametime();
  }

  if (CheckMaxRounds()) return;
  if (CheckWinLimit()) return;

  if (g_bFreezePeriod) {
    CheckFreezePeriodExpired();
  } else {
    CheckRoundTimeExpired();
  }

  if (g_flRestartRoundTime > 0.0 && g_flRestartRoundTime <= get_gametime()) {
    RestartRound();
  }

  if (g_flNextPeriodicThink <= get_gametime()) {
    CheckRestartRound();

    g_iMaxRounds = get_pcvar_num(g_pCvarMaxRounds);
    g_iMaxRoundsWon = get_pcvar_num(g_pCvarWinLimits);
    g_flNextPeriodicThink = get_gametime() + 1.0;
  }
}

bool:CheckMaxRounds() {
  if (g_iMaxRounds && g_iTotalRoundsPlayed >= g_iMaxRounds) {
    GoToIntermission();
    return true;
  }

  return false;
}

bool:CheckWinLimit() {
  if (g_iMaxRoundsWon) {
    new iMaxWins = 0;
    for (new i = 0; i < sizeof(g_rgiWinsNum); ++i) {
      if (g_rgiWinsNum[i] > iMaxWins) iMaxWins = g_rgiWinsNum[i];
    }

    if (iMaxWins >= g_iMaxRoundsWon) {
      GoToIntermission();
      return true;
    }
  }

  return false;
}

CheckFreezePeriodExpired() {
  if (GetRoundRemainingTime() > 0.0) return;

  log_message("World triggered ^"Round_Start^"\n");

  g_bFreezePeriod = false;
  g_flRoundStartTimeReal = g_flRoundStartTime = get_gametime();
  g_iRoundTimeSecs = g_iRoundTime;

  // for (new pPlayer = 1; pPlayer <= MaxClients; ++pPlayer) {
  //   if (!is_user_connected(pPlayer)) continue;
  //   if (pev(pPlayer, pev_flags) == FL_DORMANT) continue;

  //   if (get_ent_data(pPlayer, "CBasePlayer", "m_iJoiningState") == JOINED) {
      
  //   }
  // }

  for (new pPlayer = 1; pPlayer <= MaxClients; ++pPlayer) {
    if (!is_user_connected(pPlayer)) continue;
    if (!is_user_alive(pPlayer)) continue;
    set_pev(pPlayer, pev_flags, pev(pPlayer, pev_flags) & ~FL_FROZEN);
  }

  g_iGameState = GameState_RoundStarted;
  ExecuteForward(g_iFwRoundStart);
}

CheckRoundTimeExpired() {
  if (!g_iRoundTime) return;
  if (!HasRoundTimeExpired()) return;

  g_flRoundStartTime = get_gametime() + 60.0;
}

HasRoundTimeExpired() {
  if (!g_iRoundTime) return false;
  if (GetRoundRemainingTime() > 0 || g_iRoundWinTeam != 0) return false;

  return true;
}

// CheckLevelInitialized() {}

RestartRoundCheck(Float:flDelay) {
  log_message("World triggered ^"Restart_Round_(%d_%s)^"^n", floatround(flDelay, floatround_floor), (flDelay == 1.0) ? "second" : "seconds");

  // let the players know
  client_print(0, print_center, "The game will restart in %d %s", floatround(flDelay, floatround_floor), (flDelay == 1.0) ? "SECOND" : "SECONDS");
  client_print(0, print_console, "The game will restart in %d %s", floatround(flDelay, floatround_floor), (flDelay == 1.0) ? "SECOND" : "SECONDS");

  g_flRestartRoundTime = get_gametime() + flDelay;
  g_bCompleteReset = true;

  set_pcvar_num(g_pCvarRestartRound, 0);
  set_pcvar_num(g_pCvarRestart, 0);
}

CheckRestartRound() {
  new iRestartDelay = get_pcvar_num(g_pCvarRestartRound);

  if (!iRestartDelay) {
    iRestartDelay = get_pcvar_num(g_pCvarRestart);
  }

  if (iRestartDelay) {
    RestartRoundCheck(float(iRestartDelay));
  }
}

// FPlayerCanRespawn() {
//   return true;
// }

GoToIntermission() {
  message_begin(MSG_ALL, SVC_INTERMISSION);
  message_end();
}

PlayerRoundRespawn(pPlayer) {
  #pragma unused pPlayer
}

CleanUpMap() {}

ReadMultiplayCvars() {
  g_iRoundTime = floatround(get_pcvar_float(g_pCvarRoundTime) * 60, floatround_floor);
  g_iIntroRoundTime = floatround(get_pcvar_float(g_pCvarFreezeTime), floatround_floor);
}

NeededPlayersCheck() {
  if (!g_iSpawnablePlayersNum) {
    // log_message("#Game_scoring");
    g_bNeededPlayers = true;
    g_bGameStarted = false;
  }

  if (!g_bGameStarted && g_iSpawnablePlayersNum) {
    g_bFreezePeriod = false;
    g_bCompleteReset = true;

    EndRoundMessage("Game Commencing!");
    TerminateRound(3.0, 0);

    g_bGameStarted = true;

    return true;
  }

  return false;
}

TerminateRound(Float:flDelay, iTeam) {
  g_iRoundWinTeam = iTeam;
  g_flRestartRoundTime = get_gametime() + flDelay;
  g_bRoundTerminating = true;
  g_iGameState = GameState_RoundEnd;

  ExecuteForward(g_iFwRoundEnd, _, iTeam);
}

EndRoundMessage(const szSentence[]) {
  static szMessage[64];

  if (szSentence[0] == '#') {
    copy(szMessage, charsmax(szMessage), szSentence[1]);
  } else {
    copy(szMessage, charsmax(szMessage), szSentence);
  }

  if (!equal(szSentence, NULL_STRING)) {
    client_print(0, print_center, szSentence);
    log_message("World triggered ^"%s^"^n", szMessage);
  }

  log_message("World triggered ^"Round_End^"^n");
}

// GetRoundRemainingTimeReal() {
//   return float(g_iRoundTimeSecs) - get_gametime() + g_flRoundStartTimeReal;
// }

InitializePlayerCounts() {
  g_iSpawnablePlayersNum = 0;

  for (new pPlayer = 1; pPlayer <= MaxClients; ++pPlayer) {
    if (!is_user_connected(pPlayer)) continue;
    g_iSpawnablePlayersNum++;
  }
}

Float:GetRoundRemainingTime() {
  static Float:flStartTime;
  static iTime;

  if (g_bUseCustomRounds) {
    flStartTime = g_flRoundStartTimeReal;
    iTime = g_iRoundTimeSecs;
  } else if (g_bIsCStrike) {
    flStartTime = get_gamerules_float("CHalfLifeMultiplay", "m_fIntroRoundCount");
    iTime = get_gamerules_int("CHalfLifeMultiplay", "m_iRoundTimeSecs");
  } else {
    return 0.0;
  }

  return float(iTime) - get_gametime() + flStartTime;
}
