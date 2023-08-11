#if defined _api_rounds_included
  #endinput
#endif
#define _api_rounds_included

#pragma reqlib api_rounds

native Round_DispatchWin(iTeam, Float:fDelay);
native Round_SetTime(iTime);
native Round_GetTime();
native Round_GetTimeLeft();
native bool:Round_IsRoundStarted();
native bool:Round_IsRoundEnd();

forward Round_Fw_NewRound();
forward Round_Fw_RoundStart();
forward Round_Fw_RoundEnd(iWinnerTeam);
forward Round_Fw_RoundExpired();
forward Round_Fw_RoundRestart();
forward Round_Fw_RoundTimerTick();
forward Round_Fw_CheckWinCondition();

/**
 * @deprecated This function is deprecated, use Round_Fw_CheckWinCondition forward instead.
 */
native Round_HookCheckWinConditions(const szFunction[]);
