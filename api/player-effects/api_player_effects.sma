#pragma semicolon 1

#include <amxmodx>
#include <amxmisc>
#include <fakemeta>
#include <hamsandwich>

#tryinclude <api_rounds>
#include <command_util>

#include <api_player_effects_const>

#define PLUGIN "[API] Player Effects"
#define VERSION "1.0.0"
#define AUTHOR "Hedgehog Fog"

#define BIT(%0) (1<<(%0))

enum PEffectData {
  Array:PEffectData_Id,
  Array:PEffectData_InvokeFunctionId,
  Array:PEffectData_RevokeFunctionId,
  Array:PEffectData_PluginId,
  Array:PEffectData_Icon,
  Array:PEffectData_IconColor,
  Array:PEffectData_Players,
  Array:PEffectData_PlayerEffectDuration,
  Array:PEffectData_PlayerEffectEnd
};

new gmsgStatusIcon;

new Trie:g_itEffectsIds = Invalid_Trie;
new g_rgPEffectData[PEffectData] = { Invalid_Array, ... };
new g_iEffectssNum = 0;

public plugin_init() {
  register_plugin(PLUGIN, VERSION, AUTHOR);

  RegisterHamPlayer(Ham_Player_PostThink, "HamHook_Player_PostThink_Post", .Post = 1);
  RegisterHamPlayer(Ham_Killed, "HamHook_Player_Killed", .Post = 0);

  g_itEffectsIds = TrieCreate();

  g_rgPEffectData[PEffectData_Id] = ArrayCreate(32);
  g_rgPEffectData[PEffectData_InvokeFunctionId] = ArrayCreate();
  g_rgPEffectData[PEffectData_RevokeFunctionId] = ArrayCreate();
  g_rgPEffectData[PEffectData_PluginId] = ArrayCreate();
  g_rgPEffectData[PEffectData_Icon] = ArrayCreate(32);
  g_rgPEffectData[PEffectData_IconColor] = ArrayCreate(3);
  g_rgPEffectData[PEffectData_Players] = ArrayCreate();
  g_rgPEffectData[PEffectData_PlayerEffectEnd] = ArrayCreate(MAX_PLAYERS + 1);
  g_rgPEffectData[PEffectData_PlayerEffectDuration] = ArrayCreate(MAX_PLAYERS + 1);

  register_concmd("player_effect_set", "Command_Set", ADMIN_CVAR);

  gmsgStatusIcon = get_user_msgid("StatusIcon");
}

public plugin_end() {
  TrieDestroy(g_itEffectsIds);

  for (new PEffectData:iEffectData = PEffectData:0; iEffectData < PEffectData; ++iEffectData) {
    ArrayDestroy(Array:g_rgPEffectData[iEffectData]);
  }
}

public plugin_natives() {
  register_library("api_player_effects");
  register_native("PlayerEffect_Register", "Native_Register");
  register_native("PlayerEffect_Set", "Native_SetPlayerEffect");
  register_native("PlayerEffect_Get", "Native_GetPlayerEffect");
  register_native("PlayerEffect_GetEndtime", "Native_GetPlayerEffectEndTime");
  register_native("PlayerEffect_GetDuration", "Native_GetPlayerEffectDuration");
}

public Native_Register(iPluginId, iArgc) {
  new szId[32]; get_string(1, szId, charsmax(szId));
  new szInvokeFunction[32]; get_string(2, szInvokeFunction, charsmax(szInvokeFunction));
  new szRevokeFunction[32]; get_string(3, szRevokeFunction, charsmax(szRevokeFunction));
  new szIcon[32]; get_string(4, szIcon, charsmax(szIcon));
  new rgiIconColor[3]; get_array(5, rgiIconColor, sizeof(rgiIconColor));

  new iInvokeFunctionId = get_func_id(szInvokeFunction, iPluginId);
  new iRevokeFunctionId = get_func_id(szRevokeFunction, iPluginId);

  return Register(szId, iInvokeFunctionId, iRevokeFunctionId, iPluginId, szIcon, rgiIconColor);
}

public bool:Native_SetPlayerEffect(iPluginId, iArgc) {
  new pPlayer = get_param(1);
  new szEffectId[32]; get_string(2, szEffectId, charsmax(szEffectId));

  new iEffectId = -1;
  if (!TrieGetCell(g_itEffectsIds, szEffectId, iEffectId)) return false;

  new bool:bValue = bool:get_param(3);
  new Float:flDuration = get_param_f(4);
  new bool:bExtend = bool:get_param(5);

  return @Player_SetEffect(pPlayer, iEffectId, bValue, flDuration, bExtend);
}

public bool:Native_GetPlayerEffect(iPluginId, iArgc) {
  new pPlayer = get_param(1);
  new szEffectId[32]; get_string(2, szEffectId, charsmax(szEffectId));

  new iEffectId = -1;
  if (!TrieGetCell(g_itEffectsIds, szEffectId, iEffectId)) return false;

  return @Player_GetEffect(pPlayer, iEffectId);
}

public Float:Native_GetPlayerEffectEndTime(iPluginId, iArgc) {
  new pPlayer = get_param(1);
  new szEffectId[32]; get_string(2, szEffectId, charsmax(szEffectId));

  new iEffectId = -1;
  if (!TrieGetCell(g_itEffectsIds, szEffectId, iEffectId)) return 0.0;

  return Float:ArrayGetCell(g_rgPEffectData[PEffectData_PlayerEffectEnd], iEffectId, pPlayer);
}

public Float:Native_GetPlayerEffectDuration(iPluginId, iArgc) {
  new pPlayer = get_param(1);
  new szEffectId[32]; get_string(2, szEffectId, charsmax(szEffectId));

  new iEffectId = -1;
  if (!TrieGetCell(g_itEffectsIds, szEffectId, iEffectId)) return 0.0;

  return Float:ArrayGetCell(g_rgPEffectData[PEffectData_PlayerEffectDuration], iEffectId, pPlayer);
}

/*--------------------------------[ Forwards ]--------------------------------*/

public client_disconnected(pPlayer) {
  @Player_RevokeEffects(pPlayer);
}

public Round_Fw_NewRound() {
  for (new pPlayer = 1; pPlayer <= MaxClients; ++pPlayer) @Player_RevokeEffects(pPlayer);
}

/*--------------------------------[ Hooks ]--------------------------------*/

public Command_Set(pPlayer, iLevel, iCId) {
  if (!cmd_access(pPlayer, iLevel, iCId, 1)) return PLUGIN_HANDLED;

  static szTarget[32]; read_argv(1, szTarget, charsmax(szTarget));
  static szEffectId[32]; read_argv(2, szEffectId, charsmax(szEffectId));
  static szValue[32]; read_argv(3, szValue, charsmax(szValue));
  static szDuration[32]; read_argv(4, szDuration, charsmax(szDuration));

  new iEffectId = -1;
  if (!TrieGetCell(g_itEffectsIds, szEffectId, iEffectId)) return PLUGIN_HANDLED;

  new iTarget = CMD_RESOLVE_TARGET(szTarget);
  new bool:bValue = equal(szValue, NULL_STRING) ? true : bool:str_to_num(szValue);
  new Float:flDuration = equal(szDuration, NULL_STRING) ? -1.0 : str_to_float(szDuration);

  for (new pTarget = 1; pTarget <= MaxClients; ++pTarget) {
    if (!CMD_SHOULD_TARGET_PLAYER(pTarget, iTarget, pPlayer)) continue;
    @Player_SetEffect(pTarget, iEffectId, bValue, flDuration, false);
  }

  return PLUGIN_HANDLED;
}

public HamHook_Player_Killed(pPlayer) {
  @Player_RevokeEffects(pPlayer);
}

public HamHook_Player_PostThink_Post(pPlayer) {
  static Float:flGameTime; flGameTime = get_gametime();

  for (new iEffectId = 0; iEffectId < g_iEffectssNum; ++iEffectId) {
    static iPlayers; iPlayers = ArrayGetCell(g_rgPEffectData[PEffectData_Players], iEffectId);
    if (~iPlayers & BIT(pPlayer & 31)) continue;

    static Float:flEndTime; flEndTime = ArrayGetCell(g_rgPEffectData[PEffectData_PlayerEffectEnd], iEffectId, pPlayer);
    if (!flEndTime || flEndTime > flGameTime) continue;

    @Player_SetEffect(pPlayer, iEffectId, false, -1.0, true);
  }
}

/*--------------------------------[ Methods ]--------------------------------*/

bool:@Player_GetEffect(pPlayer, iEffectId) {
  new iPlayers = ArrayGetCell(g_rgPEffectData[PEffectData_Players], iEffectId);

  return !!(iPlayers & BIT(pPlayer & 31));
}

bool:@Player_SetEffect(pPlayer, iEffectId, bool:bValue, Float:flDuration, bool:bExtend) {
  if (bValue && !is_user_alive(pPlayer)) return false;

  new iPlayers = ArrayGetCell(g_rgPEffectData[PEffectData_Players], iEffectId);
  new bool:bCurrentValue = !!(iPlayers & BIT(pPlayer & 31));

  if (bValue == bCurrentValue && (!bValue || !bExtend)) return false;

  if (bValue) {
    ArraySetCell(g_rgPEffectData[PEffectData_Players], iEffectId, iPlayers | BIT(pPlayer & 31));
  } else {
    ArraySetCell(g_rgPEffectData[PEffectData_Players], iEffectId, iPlayers & ~BIT(pPlayer & 31));
  }

  new bool:bResult = (
    bValue
      ? CallInvokeFunction(pPlayer, iEffectId, flDuration)
      : CallRevokeFunction(pPlayer, iEffectId)
  );

  if (!bResult) {
    ArraySetCell(g_rgPEffectData[PEffectData_Players], iEffectId, iPlayers);
    return false;
  }

  if (bValue) {
    if (bCurrentValue && bExtend && flDuration >= 0.0) {
      new Float:flEndTime = ArrayGetCell(g_rgPEffectData[PEffectData_PlayerEffectEnd], iEffectId, pPlayer);
      if (flEndTime) {
        new Float:flPrevDuration = ArrayGetCell(g_rgPEffectData[PEffectData_PlayerEffectDuration], iEffectId, pPlayer);
        ArraySetCell(g_rgPEffectData[PEffectData_PlayerEffectEnd], iEffectId, flEndTime + flDuration, pPlayer);
        ArraySetCell(g_rgPEffectData[PEffectData_PlayerEffectDuration], iEffectId, flPrevDuration + flDuration, pPlayer);
      }
    } else {
      new Float:flEndTime = flDuration < 0.0 ? 0.0 : get_gametime() + flDuration;
      ArraySetCell(g_rgPEffectData[PEffectData_PlayerEffectEnd], iEffectId, flEndTime, pPlayer);
      ArraySetCell(g_rgPEffectData[PEffectData_PlayerEffectDuration], iEffectId, flDuration, pPlayer);
    }
  }

  static szIcon[32]; ArrayGetString(g_rgPEffectData[PEffectData_Icon], iEffectId, szIcon, charsmax(szIcon));

  if (!equal(szIcon, NULL_STRING)) {
    new irgIconColor[3];
    ArrayGetArray(g_rgPEffectData[PEffectData_IconColor], iEffectId, irgIconColor, sizeof(irgIconColor));

    message_begin(MSG_ONE, gmsgStatusIcon, _, pPlayer);
    write_byte(bValue);
    write_string(szIcon);

    if (bValue) {
        write_byte(irgIconColor[0]);
        write_byte(irgIconColor[1]);
        write_byte(irgIconColor[2]);
    }

    message_end();
  }

  return true;
}

@Player_RevokeEffects(pPlayer)  {
  for (new iEffectId = 0; iEffectId < g_iEffectssNum; ++iEffectId) {
    @Player_SetEffect(pPlayer, iEffectId, false, -1.0, true);
  }
}

/*--------------------------------[ Functions ]--------------------------------*/

Register(const szId[], iInvokeFunctionId, iRevokeFunctionId, iPluginId, const szIcon[], const rgiIconColor[3]) {
  new iEffectId = g_iEffectssNum;

  ArrayPushString(g_rgPEffectData[PEffectData_Id], szId);
  ArrayPushCell(g_rgPEffectData[PEffectData_InvokeFunctionId], iInvokeFunctionId);
  ArrayPushCell(g_rgPEffectData[PEffectData_RevokeFunctionId], iRevokeFunctionId);
  ArrayPushCell(g_rgPEffectData[PEffectData_PluginId], iPluginId);
  ArrayPushString(g_rgPEffectData[PEffectData_Icon], szIcon);
  ArrayPushArray(g_rgPEffectData[PEffectData_IconColor], rgiIconColor);
  ArrayPushCell(g_rgPEffectData[PEffectData_Players], 0);
  ArrayPushCell(g_rgPEffectData[PEffectData_PlayerEffectEnd], 0);
  ArrayPushCell(g_rgPEffectData[PEffectData_PlayerEffectDuration], 0);

  TrieSetCell(g_itEffectsIds, szId, iEffectId);

  g_iEffectssNum++;

  return iEffectId;
}

bool:CallInvokeFunction(pPlayer, iEffectId, Float:flDuration) {
  new iPluginId = ArrayGetCell(g_rgPEffectData[PEffectData_PluginId], iEffectId);
  new iFunctionId = ArrayGetCell(g_rgPEffectData[PEffectData_InvokeFunctionId], iEffectId);

  callfunc_begin_i(iFunctionId, iPluginId);
  callfunc_push_int(pPlayer);
  callfunc_push_float(flDuration);
  new iResult = callfunc_end();

  if (iResult >= PLUGIN_HANDLED) return false;

  return true;
}

bool:CallRevokeFunction(pPlayer, iEffectId) {
  new iPluginId = ArrayGetCell(g_rgPEffectData[PEffectData_PluginId], iEffectId);
  new iFunctionId = ArrayGetCell(g_rgPEffectData[PEffectData_RevokeFunctionId], iEffectId);

  callfunc_begin_i(iFunctionId, iPluginId);
  callfunc_push_int(pPlayer);
  new iResult = callfunc_end();

  if (iResult >= PLUGIN_HANDLED) return false;

  return true;
}
