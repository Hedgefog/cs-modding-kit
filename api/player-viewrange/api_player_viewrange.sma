#pragma semicolon 1

#include <amxmodx>

#define PLUGIN "[API] Player View Range"
#define VERSION "0.9.0"
#define AUTHOR "Hedgehog Fog"

new Float:g_rgflPlayerViewRange[MAX_PLAYERS + 1];
new g_rgiPlayerNativeFogColor[MAX_PLAYERS + 1][3];
new Float:g_flPlayerNativeFogDensity[MAX_PLAYERS + 1];

new gmsgFog;

public plugin_init() {
  register_plugin(PLUGIN, VERSION, AUTHOR);

  gmsgFog = get_user_msgid("Fog");

  register_message(gmsgFog, "Message_Fog");
}

public plugin_natives() {
  register_library("api_player_viewrange");
  register_native("PlayerViewRange_Get", "Native_GetPlayerViewRange");
  register_native("PlayerViewRange_Set", "Native_SetPlayerViewRange");
  register_native("PlayerViewRange_Reset", "Native_ResetPlayerViewRange");
  register_native("PlayerViewRange_Update", "Native_UpdatePlayerViewRange");
}

public Float:Native_GetPlayerViewRange(iPluginId, iArgc) {
  new pPlayer = get_param(1);

  return g_rgflPlayerViewRange[pPlayer];
}

public Native_SetPlayerViewRange(iPluginId, iArgc) {
  new pPlayer = get_param(1);
  new Float:flValue = get_param_f(2);

  @Player_SetViewRange(pPlayer, flValue);
}

public Native_ResetPlayerViewRange(iPluginId, iArgc) {
  new pPlayer = get_param(1);

  @Player_SetViewRange(pPlayer, -1.0);
}

public Native_UpdatePlayerViewRange(iPluginId, iArgc) {
  new pPlayer = get_param(1);

  @Player_UpdateViewRange(pPlayer);
}

public client_connect(pPlayer) {
  g_rgflPlayerViewRange[pPlayer] = 0.0;
  g_rgiPlayerNativeFogColor[pPlayer][0] = 0;
  g_rgiPlayerNativeFogColor[pPlayer][1] = 0;
  g_rgiPlayerNativeFogColor[pPlayer][2] = 0;
  g_flPlayerNativeFogDensity[pPlayer] = 0.0;
}

public Message_Fog(iMsgId, iMsgDest, pPlayer) {
  g_rgiPlayerNativeFogColor[pPlayer][0] = get_msg_arg_int(1);
  g_rgiPlayerNativeFogColor[pPlayer][1] = get_msg_arg_int(2);
  g_rgiPlayerNativeFogColor[pPlayer][2] = get_msg_arg_int(3);
  g_flPlayerNativeFogDensity[pPlayer] = Float:(
    get_msg_arg_int(4) |
    (get_msg_arg_int(5) << 8) |
    (get_msg_arg_int(6) << 16) |
    (get_msg_arg_int(7) << 24)
  );
}

public @Player_SetViewRange(this, Float:flViewRange) {
  if (g_rgflPlayerViewRange[this] == flViewRange) {
    return;
  }

  g_rgflPlayerViewRange[this] = flViewRange;

  @Player_UpdateViewRange(this);
}

public @Player_UpdateViewRange(this) {
  if (g_rgflPlayerViewRange[this] >= 0.0) {
    new Float:flDensity = g_rgflPlayerViewRange[this] < 0 ? 0.0 : (1.0 / g_rgflPlayerViewRange[this]);

    message_begin(MSG_ONE, gmsgFog, {0, 0, 0}, this);
    write_byte(0);
    write_byte(0);
    write_byte(0);
    write_long(_:flDensity);
    message_end();
  } else { // reset to engine fog
    message_begin(MSG_ONE, gmsgFog, {0, 0, 0}, this);
    write_byte(g_rgiPlayerNativeFogColor[this][0]);
    write_byte(g_rgiPlayerNativeFogColor[this][1]);
    write_byte(g_rgiPlayerNativeFogColor[this][2]);
    write_long(_:g_flPlayerNativeFogDensity[this]);
    message_end();
  }
}
