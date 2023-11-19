#if defined _api_rounds_included
  #endinput
#endif
#define _api_rounds_included

#pragma reqlib api_rounds

native Round_DispatchWin(iTeam, Float:fDelay = -1.0);
native Round_TerminateRound(Float:fDelay = 0.0, iTeam = 0);
native Round_SetTime(iTime);
native Round_GetTime();
native Round_GetIntroTime();
native Float:Round_GetRestartRoundTime();
native Float:Round_GetRemainingTime();
native bool:Round_IsFreezePeriod();
native bool:Round_IsRoundStarted();
native bool:Round_IsRoundEnd();
native bool:Round_IsPlayersNeeded();
native bool:Round_IsCompleteReset();
native Round_CheckWinConditions();

forward Round_Fw_NewRound();
forward Round_Fw_RoundStart();
forward Round_Fw_RoundEnd(iTeam);
forward Round_Fw_RoundExpired();
forward Round_Fw_RoundRestart();
forward Round_Fw_RoundTimerTick();
forward Round_Fw_UpdateTimer(iRemainingTime);
forward Round_Fw_CheckWinConditions();
