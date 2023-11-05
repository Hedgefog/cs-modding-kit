#if defined _command_util_included
  #endinput
#endif
#define _command_util_included

#include <amxmodx>

enum (+= -1) {
  CMD_TARGET_TEAM_ALL = 0,
  CMD_TARGET_ALIVE,
  CMD_TARGET_DEAD,
  CMD_TARGET_TEAM_T,
  CMD_TARGET_TEAM_CT,
  CMD_TARGET_TEAM_T_ALIVE,
  CMD_TARGET_TEAM_CT_ALIVE,
  CMD_TARGET_TEAM_T_DEAD,
  CMD_TARGET_TEAM_CT_DEAD
};

stock CMD_RESOLVE_TARGET(pPlayer, const szTarget[]) {
  if (szTarget[0] == '@') {
    if (equal(szTarget[1], "me")) {
      return pPlayer;
    } else if (equal(szTarget[1], "all")) {
      return CMD_TARGET_TEAM_ALL;
    } else if (equal(szTarget[1], "alive")) {
      return CMD_TARGET_ALIVE;
    } else if (equal(szTarget[1], "dead")) {
      return CMD_TARGET_DEAD;
    } else if (equal(szTarget[1], "ct")) {
      return CMD_TARGET_TEAM_CT;
    } else if (equal(szTarget[1], "t")) {
      return CMD_TARGET_TEAM_T;
    } else if (equal(szTarget[1], "t_alive")) {
      return CMD_TARGET_TEAM_T_ALIVE;
    } else if (equal(szTarget[1], "ct_alive")) {
      return CMD_TARGET_TEAM_CT_ALIVE;
    } else if (equal(szTarget[1], "t_dead")) {
      return CMD_TARGET_TEAM_T_DEAD;
    } else if (equal(szTarget[1], "ct_dead")) {
      return CMD_TARGET_TEAM_CT_DEAD;
    }
  } else if (szTarget[0] == '#') {
    return find_player("k", str_to_num(szTarget[1]));
  } else {
    return find_player("b", szTarget);
  }

  return 0;
}

stock bool:CMD_SHOULD_TARGET_PLAYER(pPlayer, iTarget) {
  if (iTarget == pPlayer) {
    return true;
  }

  if (!is_user_connected(pPlayer)) {
    return false;
  }

  new bool:bShouldBeAlive = (
    iTarget == CMD_TARGET_ALIVE ||
    iTarget == CMD_TARGET_TEAM_T_ALIVE ||
    iTarget == CMD_TARGET_TEAM_CT_ALIVE
  );

  new bool:bShouldBeDead = (
    iTarget == CMD_TARGET_DEAD ||
    iTarget == CMD_TARGET_TEAM_T_DEAD ||
    iTarget == CMD_TARGET_TEAM_CT_DEAD
  );

  new bool:bShouldBeT = (
    iTarget == CMD_TARGET_TEAM_T ||
    iTarget == CMD_TARGET_TEAM_T_ALIVE ||
    iTarget == CMD_TARGET_TEAM_T_DEAD
  );

  new bool:bShouldBeCT = (
    iTarget == CMD_TARGET_TEAM_CT ||
    iTarget == CMD_TARGET_TEAM_CT_ALIVE ||
    iTarget == CMD_TARGET_TEAM_CT_DEAD
  );

  if (cstrike_running()) {
    #if AMXX_VERSION_NUM > 182
      new iTeam = get_ent_data(pPlayer, "CBasePlayer", "m_iTeam");

      if (bShouldBeT && iTeam != 1) {
        return false;
      }

      if (bShouldBeCT && iTeam != 2) {
        return false;
      }
    #endif
  }

  if (bShouldBeAlive && !is_user_alive(pPlayer)) {
    return false;
  }

  if (bShouldBeDead && is_user_alive(pPlayer)) {
    return false;
  }

  return true;
}
