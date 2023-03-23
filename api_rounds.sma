#pragma semicolon 1

#include <amxmodx>
#include <reapi>

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

new Array:g_irgCheckWinConditionHooks;

new g_pCvarRoundEndDelay;

public plugin_init() {
    register_plugin("[API] Rounds", "2.0.0", "Hedgehog Fog");

    register_event("HLTV", "Event_NewRound", "a", "1=0", "2=0");
    RegisterHookChain(RG_CSGameRules_RestartRound, "HC_RestartRound", .post = 0);
    RegisterHookChain(RG_CSGameRules_OnRoundFreezeEnd, "HC_OnRoundFreezeEnd_Post", .post = 1);
    RegisterHookChain(RG_RoundEnd, "HC_RoundEnd", .post = 1);
    RegisterHookChain(RG_CSGameRules_CheckWinConditions, "HC_CheckWinConditions", .post = 0);

    g_iFwNewRound = CreateMultiForward("Round_Fw_NewRound", ET_IGNORE);
    g_iFwRoundStart = CreateMultiForward("Round_Fw_RoundStart", ET_IGNORE);
    g_iFwRoundEnd = CreateMultiForward("Round_Fw_RoundEnd", ET_IGNORE, FP_CELL);
    g_iFwRoundExpired = CreateMultiForward("Round_Fw_RoundExpired", ET_IGNORE);
    g_iFwRoundRestart = CreateMultiForward("Round_Fw_RoundRestart", ET_IGNORE);
    g_iFwRoundTimerTick = CreateMultiForward("Round_Fw_RoundTimerTick", ET_IGNORE);

    g_irgCheckWinConditionHooks = ArrayCreate(Hook);

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
    register_native("Round_HookCheckWinConditions", "Native_HookCheckWinConditions");
}

public plugin_destroy() {
    ArrayDestroy(g_irgCheckWinConditionHooks);
}

public server_frame() {
    static Float:flTime;
    flTime = get_gametime();

    static Float:flNextPeriodicThink;
    flNextPeriodicThink = get_member_game(m_tmNextPeriodicThink);

    if (flNextPeriodicThink < flTime) {
        static bool:bFreezePeriod;
        bFreezePeriod = get_member_game(m_bFreezePeriod);

        ExecuteForward(g_iFwRoundTimerTick);

        static iRoundTimeSecs;
        iRoundTimeSecs = get_member_game(m_iRoundTimeSecs);

        static Float:flStartTime;
        flStartTime = get_member_game(m_fRoundStartTimeReal);

        static Float:flEndTime;
        flEndTime = flStartTime + float(iRoundTimeSecs);

        if (!bFreezePeriod) {
            if (flTime >= flEndTime) {
                ExecuteForward(g_iFwRoundExpired);
            }
        }
    }
}

public HC_RestartRound() {
    if (!get_member_game(m_bCompleteReset)) {
        // g_iGameState = GameState_NewRound;
        // ExecuteForward(g_iFwNewRound);
    } else {
        ExecuteForward(g_iFwRoundRestart);
    }
}

public HC_OnRoundFreezeEnd_Post() {
    g_iGameState = GameState_RoundStarted;
    ExecuteForward(g_iFwRoundStart);
}

public Event_NewRound() {
    g_iGameState = GameState_NewRound;
    ExecuteForward(g_iFwNewRound);
}

public HC_RoundEnd(WinStatus:iStatus, ScenarioEventEndRound:iEvent, Float:flDelay) {
    new TeamName:iWinTeam = TEAM_UNASSIGNED;

    switch (iStatus) {
        case WINSTATUS_TERRORISTS: iWinTeam = TEAM_TERRORIST;
        case WINSTATUS_CTS: iWinTeam = TEAM_CT;
        case WINSTATUS_DRAW: iWinTeam = TEAM_SPECTATOR;
    }

    g_iGameState = GameState_RoundEnd;

    ExecuteForward(g_iFwRoundEnd, _, _:iWinTeam);
}

public HC_CheckWinConditions() {
    new iSize = ArraySize(g_irgCheckWinConditionHooks);

    for (new i = 0; i < iSize; ++i) {
        static hook[_:Hook];
        ArrayGetArray(g_irgCheckWinConditionHooks, i, hook);

        if (callfunc_begin_i(hook[Hook_FunctionId], hook[Hook_PluginId]) == 1) {
            if (callfunc_end() > PLUGIN_CONTINUE) {
                return HC_SUPERCEDE;
            }
        }
    }

    return HC_CONTINUE;
}

public Native_DispatchWin(iPluginId, iArgc) {
    new iTeam = get_param(1);
    new Float:flDelay = get_param_f(2);
    DispatchWin(iTeam, flDelay);
}

public Native_GetTime(iPluginId, iArgc) {
    return get_member_game(m_iRoundTimeSecs);
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

public Native_HookCheckWinConditions(iPluginId, iArgc) {
    new szFunctionName[32];
    get_string(1, szFunctionName, charsmax(szFunctionName));

    new hook[Hook];
    hook[Hook_PluginId] = iPluginId;
    hook[Hook_FunctionId] = get_func_id(szFunctionName, iPluginId);

    ArrayPushArray(g_irgCheckWinConditionHooks, hook);
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
}

SetTime(iTime) {
    new Float:flStartTime = get_member_game(m_fRoundStartTimeReal);

    set_member_game(m_iRoundTime, iTime);
    set_member_game(m_iRoundTimeSecs, iTime);
    set_member_game(m_fRoundStartTime, flStartTime);

    UpdateTimer(0, GetTimeLeft());
}

GetTimeLeft() {
    new Float:flStartTime = get_member_game(m_fRoundStartTimeReal);
    new iTime = get_member_game(m_iRoundTimeSecs);
    return floatround(flStartTime + float(iTime) - get_gametime());
}

UpdateTimer(iClient, iTime) {
    static iMsgId = 0;
    if(!iMsgId) {
        iMsgId = get_user_msgid("RoundTime");
    }

    message_begin(iClient ? MSG_ONE : MSG_ALL, iMsgId);
    write_short(iTime);
    message_end();
}
