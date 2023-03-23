#pragma semicolon 1

#include <amxmodx>
#include <fakemeta>
#include <hamsandwich>

#tryinclude <reapi>

#if defined _reapi_included
    #define ROUND_CONTINUE HC_CONTINUE
    #define ROUND_SUPERCEDE HC_SUPERCEDE
    #define WINSTATUS_TERRORIST WINSTATUS_TERRORISTS
    #define WINSTATUS_CT WINSTATUS_CTS
#else
    #include <roundcontrol>
#endif

#define PLUGIN "[API] Rounds"
#define AUTHOR "Hedgehog Fog"
#define VERSION "1.0.0"

#define TASKID_ROUNDTIME_EXPIRE 1

enum GameState {
    GameState_NewRound,
    GameState_RoundStarted,
    GameState_RoundEnd
};

enum _:Hook {
    Hook_PluginId,
    Hook_FunctionId
}

new g_iFwResult;
new g_iFwNewRound;
new g_iFwRoundStart;
new g_iFwRoundEnd;
new g_iFwRoundExpired;

new GameState:g_iGamestate;
new Float:g_fRoundStartTime;

new Array:g_iCheckWinConditionHooks;

public plugin_init() {
    register_plugin(PLUGIN, VERSION, AUTHOR);

    register_event("HLTV", "OnNewRound", "a", "1=0", "2=0");
    register_logevent("OnRoundStart", 2, "1=Round_Start");
    register_logevent("OnRoundEnd", 2, "1=Round_End");
    register_event("TextMsg", "OnRoundEnd", "a", "2=#Game_will_restart_in");

    #if defined _reapi_included
        RegisterHookChain(RG_CSGameRules_CheckWinConditions, "OnCheckWinConditions");
    #else
        RegisterControl(RC_CheckWinConditions, "OnCheckWinConditions");
    #endif

    register_message(get_user_msgid("RoundTime"), "OnMessage_RoundTime");

    g_iFwNewRound = CreateMultiForward("Round_Fw_NewRound", ET_IGNORE);
    g_iFwRoundStart = CreateMultiForward("Round_Fw_RoundStart", ET_IGNORE);
    g_iFwRoundEnd = CreateMultiForward("Round_Fw_RoundEnd", ET_IGNORE);
    g_iFwRoundExpired = CreateMultiForward("Round_Fw_RoundExpired", ET_IGNORE);

    g_iCheckWinConditionHooks = ArrayCreate(Hook);
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
    ArrayDestroy(g_iCheckWinConditionHooks);
}

/*--------------------------------[ Natives ]--------------------------------*/

public Native_DispatchWin(iPluginId, iArgc) {
    new iTeam = get_param(1);
    new Float:fDelay = get_param_f(2);
    DispatchWin(iTeam, fDelay);
}

public Native_GetTime(iPluginId, iArgc) {
    return GetTime();
}

public Native_SetTime(iPluginId, iArgc) {
    new iTime = get_param(1);
    SetTime(iTime);
}

public Native_GetTimeLeft(iPluginId, iArgc) {
    return GetTimeLeft();
}

public bool:Native_IsRoundStarted(iPluginId, iArgc) {
    return g_iGamestate > GameState_NewRound;
}

public bool:Native_IsRoundEnd(iPluginId, iArgc) {
    return g_iGamestate == GameState_RoundEnd;
}

public Native_HookCheckWinConditions(iPluginId, iArgc) {
    static szFunctionName[32];
    get_string(1, szFunctionName, charsmax(szFunctionName));

    new hook[Hook];
    hook[Hook_PluginId] = iPluginId;
    hook[Hook_FunctionId] = get_func_id(szFunctionName, iPluginId);

    ArrayPushArray(g_iCheckWinConditionHooks, hook);
}

/*--------------------------------[ Hooks ]--------------------------------*/

public OnCheckWinConditions() {
    new size = ArraySize(g_iCheckWinConditionHooks);

    for (new i = 0; i < size; ++i) {
        static hook[_:Hook];
        ArrayGetArray(g_iCheckWinConditionHooks, i, hook);

        if (callfunc_begin_i(hook[Hook_FunctionId], hook[Hook_PluginId]) == 1) {
            if (callfunc_end() > PLUGIN_CONTINUE) {
                return ROUND_SUPERCEDE;
            }
        }
    }

    return ROUND_CONTINUE;
}

public OnNewRound() {
    g_iGamestate = GameState_NewRound;
    ExecuteForward(g_iFwNewRound, g_iFwResult);
}

public OnRoundStart() {
    g_iGamestate = GameState_RoundStarted;
    g_fRoundStartTime = get_gametime();
    UpdateRoundTime();
    ExecuteForward(g_iFwRoundStart, g_iFwResult);
}

public OnRoundEnd() {
    g_iGamestate = GameState_RoundEnd;
    remove_task(TASKID_ROUNDTIME_EXPIRE);
    ExecuteForward(g_iFwRoundEnd, g_iFwResult);
}

public OnRoundTimeExpired() {
    ExecuteForward(g_iFwRoundExpired, g_iFwResult);
}

public OnMessage_RoundTime() {
    if (g_iGamestate == GameState_NewRound) {
        return PLUGIN_CONTINUE;
    }

    set_msg_arg_int(1, ARG_SHORT, GetTimeLeft());

    return PLUGIN_CONTINUE;
}

/*--------------------------------[ Methods ]--------------------------------*/

DispatchWin(iTeam, Float:fDelay) {
    if (g_iGamestate == GameState_RoundEnd) {
        return;
    }

    if (iTeam < 1 || iTeam > 3) {
        return;
    }

    new any:iWinstatus = WINSTATUS_DRAW;
    if (iTeam == 1) {
        iWinstatus = WINSTATUS_TERRORIST;
    } else if (iTeam == 2) {
        iWinstatus = WINSTATUS_CT;
    }

    #if defined _reapi_included
        new ScenarioEventEndRound:iEvent = ROUND_END_DRAW;
        if (iTeam == 1) {
            iEvent = ROUND_TERRORISTS_WIN;
        } else if (iTeam == 2) {
            iEvent = ROUND_CTS_WIN;
        }

        rg_round_end(fDelay, iWinstatus, iEvent);
        rg_update_teamscores(iTeam == 2 ? 1 : 0, iTeam == 1 ? 1 : 0);
    #else
        RoundEndForceControl(iWinstatus, fDelay);
    #endif
}

GetTime() {
    #if defined _reapi_included
        return get_member_game(m_iRoundTime);
    #else
        return get_pgame_int(m_iRoundTime);
    #endif
}

SetTime(iTime) {
    #if defined _reapi_included
        set_member_game(m_iRoundTime, iTime);
        set_member_game(m_fRoundStartTime, g_fRoundStartTime);
    #else
        set_pgame_int(m_iRoundTime, iTime);
        set_pgame_float(m_fRoundCount, g_fRoundStartTime);
    #endif

    UpdateRoundTime();
}

GetTimeLeft() {
    return floatround(g_fRoundStartTime + float(GetTime()) - get_gametime());
}

UpdateRoundTime() {
    new iTimeLeft = GetTimeLeft();

    RountTimeMessage(0, iTimeLeft);
    remove_task(TASKID_ROUNDTIME_EXPIRE);
    set_task(float(iTimeLeft), "OnRoundTimeExpired", TASKID_ROUNDTIME_EXPIRE);
}

stock RountTimeMessage(iClient, iTime) {
    static iMsgId = 0;
    if(!iMsgId) {
        iMsgId = get_user_msgid("RoundTime");
    }

    message_begin(iClient ? MSG_ONE : MSG_ALL, iMsgId);
    write_short(iTime);
    message_end();
}
