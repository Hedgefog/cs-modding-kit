#if defined _api_rounds_included
  #endinput
#endif
#define _api_round_included

#pragma reqlib api_rounds

native Round_DispatchWin(iTeam, Float:fDelay);
native Round_SetTime(iTime);
native Round_GetTime();
native Round_GetTimeLeft();
native bool:Round_IsRoundStarted();
native bool:Round_IsRoundEnd();
native Round_HookCheckWinConditions(szFunction[]);

forward Round_Fw_NewRound();
forward Round_Fw_RoundStart();
forward Round_Fw_RoundEnd();
forward Round_Fw_RoundExpired();
