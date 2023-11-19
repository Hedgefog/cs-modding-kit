#pragma semicolon 1

#include <amxmodx>
#include <hamsandwich>
#include <fakemeta>
#tryinclude <reapi>

#if !defined USE_CUSTOM_ROUNDS
  #define USE_CUSTOM_ROUNDS
#endif

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

new g_iFwNewRound;
new g_iFwRoundStart;
new g_iFwRoundEnd;
new g_iFwRoundExpired;
new g_iFwRoundRestart;
new g_iFwRoundTimerTick;
new g_iFwCheckWinConditions;

new g_pCvarRoundEndDelay;

#if defined USE_CUSTOM_ROUNDS
  new g_pCvarRoundTime;
  new g_pCvarFreezeTime;
  new g_pCvarMaxRounds;
  new g_pCvarWinLimits;
  new g_pCvarRestartRound;
  new g_pCvarRestart;
#endif

#if defined USE_CUSTOM_ROUNDS
  new g_iIntroRoundTime;
  new g_iPlayersNum = 0;
  new g_iRoundWinStatus = 0;
  new bool:g_bFreezePeriod = false;
  new g_iRoundTime = 0;
  new g_iRoundTimeSecs = 0;
  new Float:g_fRoundStartTime = 0.0;
  new Float:g_fRoundStartTimeReal = 0.0;
  new Float:g_flRestartRoundTime = 0.0;
  new Float:g_tmNextPeriodicThink = 0.0;
  new bool:g_bGameStarted = false;
  // new g_bRoundTerminating = false;
  new g_iTotalRoundsPlayed = 0;
  new g_iMaxRounds = 0;
  new g_iMaxRoundsWon = 0;
  new bool:g_bCompleteReset = false;
  new g_rgiWinsNum[16];
  // new bool:g_bNeededPlayers = false;
#endif

public plugin_init() {
  register_plugin("[API] Rounds", "2.1.0", "Hedgehog Fog");

  #if !defined USE_CUSTOM_ROUNDS
    register_event("HLTV", "Event_NewRound", "a", "1=0", "2=0");
    RegisterHookChain(RG_CSGameRules_RestartRound, "HC_RestartRound", .post = 0);
    RegisterHookChain(RG_CSGameRules_OnRoundFreezeEnd, "HC_OnRoundFreezeEnd_Post", .post = 1);
    RegisterHookChain(RG_RoundEnd, "HC_RoundEnd", .post = 1);
    RegisterHookChain(RG_CSGameRules_CheckWinConditions, "HC_CheckWinConditions", .post = 0);
  #endif

  #if defined USE_CUSTOM_ROUNDS
    RegisterHamPlayer(Ham_Spawn, "HamHook_Player_Spawn_Post", .Post = 1);
    RegisterHamPlayer(Ham_Killed, "HamHook_Player_Killed_Post", .Post = 1);
  #endif

  g_iFwNewRound = CreateMultiForward("Round_Fw_NewRound", ET_IGNORE);
  g_iFwRoundStart = CreateMultiForward("Round_Fw_RoundStart", ET_IGNORE);
  g_iFwRoundEnd = CreateMultiForward("Round_Fw_RoundEnd", ET_IGNORE, FP_CELL);
  g_iFwRoundExpired = CreateMultiForward("Round_Fw_RoundExpired", ET_IGNORE);
  g_iFwRoundRestart = CreateMultiForward("Round_Fw_RoundRestart", ET_IGNORE);
  g_iFwRoundTimerTick = CreateMultiForward("Round_Fw_RoundTimerTick", ET_IGNORE);
  g_iFwCheckWinConditions = CreateMultiForward("Round_Fw_CheckWinConditions", ET_STOP);

  #if defined USE_CUSTOM_ROUNDS
    if (!cvar_exists("mp_freezetime")) register_cvar("mp_freezetime", "6.0");
    if (!cvar_exists("mp_roundtime")) register_cvar("mp_roundtime", "5.0");
    if (!cvar_exists("mp_round_restart_delay")) register_cvar("mp_round_restart_delay", "5.0");
    if (!cvar_exists("mp_maxrounds")) register_cvar("mp_maxrounds", "0");
    if (!cvar_exists("mp_winlimit")) register_cvar("mp_winlimit", "0");
    if (!cvar_exists("sv_restart")) register_cvar("sv_restart", "0");
    if (!cvar_exists("sv_restartround")) register_cvar("sv_restartround", "0");

    g_pCvarRoundTime = get_cvar_pointer("mp_roundtime");
    g_pCvarFreezeTime = get_cvar_pointer("mp_freezetime");
    g_pCvarMaxRounds = get_cvar_pointer("mp_maxrounds");
    g_pCvarWinLimits = get_cvar_pointer("mp_winlimit");
    g_pCvarRestartRound = get_cvar_pointer("sv_restartround");
    g_pCvarRestart = get_cvar_pointer("sv_restart");

    ReadMultiplayCvars();
  #endif

  g_pCvarRoundEndDelay = get_cvar_pointer("mp_round_restart_delay");
}

public plugin_natives() {
  register_library("api_rounds");
  register_native("Round_DispatchWin", "Native_DispatchWin");
  register_native("Round_GetTime", "Native_GetTime");
  register_native("Round_SetTime", "Native_SetTime");
  register_native("Round_GetTimeLeft", "Native_GetTimeLeft");
  register_native("Round_IsRoundStarted", "Native_IsRoundStarted");
  register_native("Round_IsRoundEnd", "Native_IsRoundEnd");
  register_native("Round_CheckWinConditions", "Native_CheckWinConditions");
}

#if defined USE_CUSTOM_ROUNDS
  public client_putinserver() {
    g_iPlayersNum++;

    if (g_iPlayersNum == 1) {
      RestartRound();
    }
  }

  public client_disconnected() {
    g_iPlayersNum--;

    CheckWinConditions();
  }

  public HamHook_Player_Spawn_Post(pPlayer) {
    if (g_bFreezePeriod) {
      set_pev(pPlayer, pev_flags, pev(pPlayer, pev_flags) | FL_FROZEN);
    }
  }

  public HamHook_Player_Killed_Post(pPlayer) {
    set_pev(pPlayer, pev_flags, ~pev(pPlayer, pev_flags) & FL_FROZEN);

    CheckWinConditions();
  }
#endif

public server_frame() {
  static Float:flTime; flTime = get_gametime();
  static Float:flNextPeriodicThink; 
  
  #if defined USE_CUSTOM_ROUNDS
    flNextPeriodicThink = g_tmNextPeriodicThink;
  #else
    flNextPeriodicThink = get_gamerules_float("CHalfLifeMultiplay", "m_tmNextPeriodicThink");
  #endif

  #if defined USE_CUSTOM_ROUNDS
    Think();
  #endif

  if (flNextPeriodicThink < flTime) {
    static bool:bFreezePeriod;
    static iRoundTimeSecs;
    static Float:flStartTime;
    static Float:flEndTime;

    #if defined USE_CUSTOM_ROUNDS
      bFreezePeriod = g_bFreezePeriod;
      iRoundTimeSecs = g_iRoundTimeSecs;
      flStartTime = g_fRoundStartTimeReal;
      flEndTime = flStartTime + float(iRoundTimeSecs);
    #else
      bFreezePeriod = get_member_game(m_bFreezePeriod);
      iRoundTimeSecs = get_member_game(m_iRoundTimeSecs);
      flStartTime = get_member_game(m_fRoundStartTimeReal);
      flEndTime = flStartTime + float(iRoundTimeSecs);
    #endif

    ExecuteForward(g_iFwRoundTimerTick);

    if (!bFreezePeriod) {
      if (flTime >= flEndTime) {
        OnRoundExpired();
      }
    }

    #if defined USE_CUSTOM_ROUNDS
      g_tmNextPeriodicThink = flTime + 1.0;
    #endif
  }
}

#if !defined USE_CUSTOM_ROUNDS
  public HC_RestartRound() {
    OnRestartRound();
  }

  public HC_OnRoundFreezeEnd_Post() {
    OnEndFreezePeriod();
  }

  public Event_NewRound() {
    OnNewRound();
  }

  public HC_RoundEnd(WinStatus:iStatus, ScenarioEventEndRound:iEvent, Float:flDelay) {
    new iTeam;

    switch (iStatus) {
      case WINSTATUS_CTS: iTeam = 1;
      case WINSTATUS_TERRORISTS: iTeam = 2;
      case WINSTATUS_DRAW: iTeam = 3;
    }

    OnRoundEnd(iTeam);
  }

  public HC_CheckWinConditions() {
    static iReturn;

    ExecuteForward(g_iFwCheckWinConditions, iReturn);
    if (iReturn != PLUGIN_CONTINUE) {
      return HC_SUPERCEDE;
    }

    return HC_CONTINUE;
  }
#endif

public Native_DispatchWin(iPluginId, iArgc) {
  new iTeam = get_param(1);
  new Float:flDelay = get_param_f(2);
  DispatchWin(iTeam, flDelay);
}

public Native_GetTime(iPluginId, iArgc) {
  #if defined USE_CUSTOM_ROUNDS
    return g_iRoundTimeSecs;
  #else
    return get_member_game(m_iRoundTimeSecs);
  #endif
}

public Native_SetTime(iPluginId, iArgc) {
  new iTime = get_param(1);

  SetTime(iTime);
}

public Native_GetTimeLeft(iPluginId, iArgc) {
  return GetTimeLeft();
}

public bool:Native_IsRoundStarted(iPluginId, iArgc) {
  return g_iGameState > GameState_NewRound;
}

public bool:Native_IsRoundEnd(iPluginId, iArgc) {
  return g_iGameState == GameState_RoundEnd;
}

public bool:Native_CheckWinConditions(iPluginId, iArgc) {
  #if defined USE_CUSTOM_ROUNDS
    CheckWinConditions();
  #else
    rg_check_win_conditions();
  #endif
}

DispatchWin(iTeam, Float:flDelay = -1.0) {
  if (g_iGameState == GameState_RoundEnd) {
    return;
  }

  if (iTeam < 1 || iTeam > 3) {
    return;
  }

  if (flDelay < 0.0) {
    flDelay = g_pCvarRoundEndDelay ? get_pcvar_float(g_pCvarRoundEndDelay) : 5.0;
  }

  #if !defined USE_CUSTOM_ROUNDS
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
  #else
    EndRound(flDelay, iTeam);
  #endif

  UpdateTeamScores(iTeam == 1 ? 1 : 0, iTeam == 2 ? 1 : 0);
}

SetTime(iTime) {
  #if defined USE_CUSTOM_ROUNDS
    g_iRoundTime = iTime;
    g_iRoundTimeSecs = iTime;
    g_fRoundStartTime = g_fRoundStartTimeReal;
  #else
    new flStartTime = get_member_game(m_fRoundStartTimeReal);
    set_member_game(m_iRoundTime, iTime);
    set_member_game(m_iRoundTimeSecs, iTime);
    set_member_game(m_fRoundStartTime, flStartTime);

    UpdateTimer(0, GetTimeLeft());
  #endif
}

GetTimeLeft() {
  #if defined USE_CUSTOM_ROUNDS
    new Float:flStartTime = g_fRoundStartTimeReal;
    new iTime = g_iRoundTimeSecs;
  #else
    new Float:flStartTime = get_member_game(m_fRoundStartTimeReal);
    new iTime = get_member_game(m_iRoundTimeSecs);
  #endif

  return floatround(flStartTime + float(iTime) - get_gametime());
}

#if !defined USE_CUSTOM_ROUNDS
  UpdateTimer(iClient, iTime) {
    static iMsgId = 0;
    if(!iMsgId) {
      iMsgId = get_user_msgid("RoundTime");
    }

    message_begin(iClient ? MSG_ONE : MSG_ALL, iMsgId);
    write_short(iTime);
    message_end();
  }
#endif

UpdateTeamScores(iTeam1Wins, iTeam2Wins) {
  #if defined USE_CUSTOM_ROUNDS
    #pragma unused iTeam1Wins,iTeam2Wins
    // TODO: Implement
  #else
    rg_update_teamscores(iTeam2Wins, iTeam1Wins);
  #endif
}

#if defined USE_CUSTOM_ROUNDS
  EndRound(const Float:flDelay, iTeam, const szMessage[] = "") {
      EndRoundMessage(szMessage);
      TerminateRound(flDelay, iTeam);
  }

  CheckWinConditions() {
      static iReturn;

      ExecuteForward(g_iFwCheckWinConditions, iReturn);

      if (iReturn != PLUGIN_CONTINUE) {
        return;
      }

      if (g_bGameStarted && g_iRoundWinStatus != 0) {
        return;
      }

      // g_bNeededPlayers = false;
      NeededPlayersCheck();

  // #if defined USE_CUSTOM_ROUNDS
  //     if (g_bGameStarted && g_iRoundWinStatus != WINSTATUS_NONE) return; 

  //     if (g_iRoundWinStatus && g_fRoundEndTimeReal <= get_gametime()) {
  //       OnNewRound();
  //     }
  // #endif
  }

  RestartRound() {
    if (!g_bCompleteReset) {
      g_iTotalRoundsPlayed++;
      // g_iGameState = GameState_NewRound;
      // ExecuteForward(g_iFwNewRound);
    }

    if (g_bCompleteReset) {
      g_iTotalRoundsPlayed = 0;
      g_iMaxRounds = max(get_pcvar_num(g_pCvarMaxRounds), 0);
      g_iMaxRoundsWon = max(get_pcvar_num(g_pCvarWinLimits), 0);

      for (new i = 0; i < sizeof(g_rgiWinsNum); ++i) {
        g_rgiWinsNum[i] = 0;
      }
    }

    OnRestartRound();

    g_bFreezePeriod = true;
    // g_bRoundTerminating = false;

    ReadMultiplayCvars();

    g_iRoundTimeSecs = g_iIntroRoundTime;

    g_fRoundStartTime = g_fRoundStartTimeReal = get_gametime();

    CleanUpMap();

    for (new pPlayer = 1; pPlayer <= MaxClients; ++pPlayer) {
      if (!is_user_connected(pPlayer)) continue;
      if (pev(pPlayer, pev_flags) == FL_DORMANT) continue;

      PlayerRoundRespawn(pPlayer);
    }

    g_flRestartRoundTime = 0.0;
    g_iRoundWinStatus = 0;
    g_bCompleteReset = false;

    OnNewRound();
  }

  Think() {
    if (!g_fRoundStartTime) {
      g_fRoundStartTime = g_fRoundStartTimeReal = get_gametime();
    }

    // if (CheckGameOver()) return;
    // if (CheckTimeLimit()) return;
    // if (CheckFragLimit()) return;
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

    // CheckLevelInitialized();

    static Float:flNextPeriodicThink;

    #if !defined USE_CUSTOM_ROUNDS
      flNextPeriodicThink = get_gamerules_float("CHalfLifeMultiplay", "m_tmNextPeriodicThink");
    #else
      flNextPeriodicThink = g_tmNextPeriodicThink;
    #endif

    if (flNextPeriodicThink < get_gametime()) {
      CheckRestartRound();
      // m_tmNextPeriodicThink = get_gametime() + 1.0f;

      g_iMaxRounds = get_pcvar_num(g_pCvarMaxRounds);
      g_iMaxRoundsWon = get_pcvar_num(g_pCvarWinLimits);
    }
  }

  // CheckGameOver() {}

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
    g_fRoundStartTimeReal = g_fRoundStartTime = get_gametime();
    g_iRoundTimeSecs = g_iRoundTime;

    // for (new pPlayer = 1; pPlayer <= MaxClients; ++pPlayer) {
    //   if (!is_user_connected(pPlayer)) continue;
    //   if (pev(pPlayer, pev_flags) == FL_DORMANT) continue;

    //   if (get_ent_data(pPlayer, "CBasePlayer", "m_iJoiningState") == JOINED) {
        
    //   }
    // }

    for (new pPlayer = 1; pPlayer <= MaxClients; ++pPlayer) {
      set_pev(pPlayer, pev_flags, ~pev(pPlayer, pev_flags) & FL_FROZEN);
    }

    OnEndFreezePeriod();
  }

  CheckRoundTimeExpired() {
    if (!g_iRoundTime) {
      return false;
    }

    if (GetRoundRemainingTime() > 0 || g_iRoundWinStatus != 0) {
      return false;
    }

    // m_fRoundStartTime = get_gametime() + 60.0;

    return true;
  }

  // CheckLevelInitialized() {}

  RestartRoundCheck(Float:flDelay) {
    log_message("World triggered ^"Restart_Round_(%i_%s)^"^n", floatround(flDelay, floatround_floor), (flDelay == 1.0) ? "second" : "seconds");

    // let the players know
    client_print(0, print_center, "#Game_will_restart_in", floatround(flDelay, floatround_floor), (flDelay == 1.0) ? "SECOND" : "SECONDS");
    client_print(0, print_console, "#Game_will_restart_in_console", floatround(flDelay, floatround_floor), (flDelay == 1.0) ? "SECOND" : "SECONDS");

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
    if (!g_iPlayersNum) {
      // UTIL_ClientPrintAll(HUD_PRINTCONSOLE, "#Game_scoring");
      // g_bNeededPlayers = true;
      g_bGameStarted = false;
    }

    g_bFreezePeriod = false;
    g_bCompleteReset = true;

    EndRoundMessage("#Game_Commencing");
    TerminateRound(3.0, 0);

    g_bGameStarted = true;
  }

  TerminateRound(Float:flDelay, iTeam) {
    g_iRoundWinStatus = iTeam;
    g_flRestartRoundTime = get_gametime() + flDelay;
    // g_bRoundTerminating = true;
    OnRoundEnd(iTeam);
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

  Float:GetRoundRemainingTime() {
    return float(g_iRoundTimeSecs) - get_gametime() + g_fRoundStartTime;
  }

  // GetRoundRemainingTimeReal() {
  //   return float(g_iRoundTimeSecs) - get_gametime() + g_fRoundStartTimeReal;
  // }
#endif

OnRestartRound() {
  ExecuteForward(g_iFwRoundRestart);
}

OnEndFreezePeriod() {
  g_iGameState = GameState_RoundStarted;
  ExecuteForward(g_iFwRoundStart);
}

OnNewRound() {
  g_iGameState = GameState_NewRound;
  ExecuteForward(g_iFwNewRound);
}

OnRoundExpired() {
  ExecuteForward(g_iFwRoundExpired);
}

OnRoundEnd(iTeam) {
  g_iGameState = GameState_RoundEnd;
  ExecuteForward(g_iFwRoundEnd, _, _:iTeam);
}
