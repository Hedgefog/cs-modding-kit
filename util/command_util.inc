#if defined _command_util_included
  #endinput
#endif
#define _command_util_included

#include <amxmodx>
#include <engine>

enum (<<=1) {
  CMD_TARGET_ALL,
  CMD_TARGET_NO_ONE = 1,
  CMD_TARGET_HAS_CALLER,
  CMD_TARGET_CALLER,
  CMD_TARGET_IGNORE_CALLER,
  CMD_TARGET_ALIVE,
  CMD_TARGET_DEAD,
  CMD_TARGET_HUMAN,
  CMD_TARGET_BOT,
  CMD_TARGET_ADMIN,
  CMD_TARGET_VIEWCONE,
  CMD_TARGET_VISIBLE,
  CMD_TARGET_TEAM_T,
  CMD_TARGET_TEAM_CT,
  CMD_TARGET_TEAM_SPEC
};

stock CMD_RESOLVE_TARGET(const szTarget[]) {
  if (szTarget[0] == '@') {
    return -CMD_RESOLVE_ALIASES_BITS(szTarget[1]);
  } else if (szTarget[0] == '#') {
    static pTarget; pTarget = find_player("k", str_to_num(szTarget[1]));
    if (pTarget) return pTarget;
  } else {
    static pTarget; pTarget = find_player("b", szTarget);
    if (pTarget) return pTarget;
  }

  return CMD_TARGET_NO_ONE;
}

stock CMD_RESOLVE_ALIASES_BITS(const szAliases[]) {
  static iBits; iBits = 0;
  static iAliasStartPos; iAliasStartPos = 0;
  static iCursor; iCursor = 0;

  do {
    if (iCursor && (szAliases[iCursor] == '_' || szAliases[iCursor] == '^0')) {
      if (iCursor > iAliasStartPos && szAliases[iAliasStartPos] != '_') {
        iBits |= CMD_RESOLVE_ALIAS_BITS(szAliases[iAliasStartPos], iCursor - iAliasStartPos);
        static szSubAlias[32]; copy(szSubAlias, iCursor - iAliasStartPos, szAliases[iAliasStartPos]);
      }

      iAliasStartPos = iCursor + 1;
    }

    iCursor++;
  } while (szAliases[iCursor - 1] != '^0');

  return iBits;
}

stock CMD_RESOLVE_ALIAS_BITS(const szAlias[], iMaxLen = 0) {
  if (equal(szAlias, "all", iMaxLen)) return CMD_TARGET_ALL;
  else if (equal(szAlias, "alive", iMaxLen)) return CMD_TARGET_ALIVE;
  else if (equal(szAlias, "dead", iMaxLen)) return CMD_TARGET_DEAD;
  else if (equal(szAlias, "human", iMaxLen)) return CMD_TARGET_HUMAN;
  else if (equal(szAlias, "bot", iMaxLen)) return CMD_TARGET_BOT;
  else if (equal(szAlias, "admin", iMaxLen)) return CMD_TARGET_ADMIN;
  else if (equal(szAlias, "t", iMaxLen)) return CMD_TARGET_TEAM_T;
  else if (equal(szAlias, "ct", iMaxLen)) return CMD_TARGET_TEAM_CT;
  else if (equal(szAlias, "spec", iMaxLen)) return CMD_TARGET_TEAM_SPEC;
  else if (equal(szAlias, "me", iMaxLen)) return CMD_TARGET_HAS_CALLER | CMD_TARGET_CALLER;
  else if (equal(szAlias, "notme", iMaxLen)) return CMD_TARGET_HAS_CALLER | CMD_TARGET_IGNORE_CALLER;
  else if (equal(szAlias, "view", iMaxLen)) return CMD_TARGET_HAS_CALLER | CMD_TARGET_VIEWCONE | CMD_TARGET_VISIBLE | CMD_TARGET_ALIVE;

  return CMD_TARGET_NO_ONE;
}

stock bool:CMD_SHOULD_TARGET_PLAYER(pPlayer, iTarget, pCaller = 0) {
  if (!is_user_connected(pPlayer)) return false;
  if (iTarget == pPlayer) return true;
  if (iTarget > 0) return false;

  static iTargetBits; iTargetBits = -iTarget;

  if (!iTargetBits) return true;
  if (iTargetBits & CMD_TARGET_ALL) return true;
  if (iTargetBits & CMD_TARGET_NO_ONE) return false;
  if (iTargetBits & CMD_TARGET_HAS_CALLER && !pCaller) return false;
  if (iTargetBits & CMD_TARGET_CALLER && pPlayer != pCaller) return false;
  if (iTargetBits & CMD_TARGET_IGNORE_CALLER && pPlayer == pCaller) return false;

  static bool:bAlive; bAlive = !!is_user_alive(pPlayer);
  if (iTargetBits & CMD_TARGET_ALIVE && !bAlive) return false;
  if (iTargetBits & CMD_TARGET_DEAD && bAlive) return false;

  static bool:bBot; bBot = !!is_user_bot(pPlayer);
  if (iTargetBits & CMD_TARGET_HUMAN && bBot) return false;
  if (iTargetBits & CMD_TARGET_BOT && !bBot) return false;

  static iFlags; iFlags = get_user_flags(pPlayer);
  if (iTargetBits & CMD_TARGET_ADMIN && ~iFlags & ADMIN_ADMIN) return false;

  if (cstrike_running()) {
    #if AMXX_VERSION_NUM > 182
      static iTeam; iTeam = get_ent_data(pPlayer, "CBasePlayer", "m_iTeam");

      if (iTargetBits & CMD_TARGET_TEAM_T && iTeam != 1) return false;
      if (iTargetBits & CMD_TARGET_TEAM_CT && iTeam != 2) return false;
      if (iTargetBits & CMD_TARGET_TEAM_SPEC && iTeam != 0 && iTeam != 3) return false;
    #endif
  }

  if (iTargetBits & CMD_TARGET_VISIBLE && !is_visible(pCaller, pPlayer)) return false;

  if (iTargetBits & CMD_TARGET_VIEWCONE) {
    static Float:vecOrigin[3]; pev(pPlayer, pev_origin, vecOrigin);
    if (!is_in_viewcone(pCaller, vecOrigin)) return false;
  }

  return true;
}
