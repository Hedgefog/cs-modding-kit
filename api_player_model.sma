#include <amxmodx>
#include <amxmisc>
#include <hamsandwich>
#include <reapi>
#include <fakemeta>
#include <xs>

#define PLUGIN "[API] Player Model"
#define VERSION "0.9.0"
#define AUTHOR "Hedgehog Fog"

new g_rgszPlayerModel[MAX_PLAYERS + 1][32];
new g_rgszCustomPlayerModel[MAX_PLAYERS + 1][256];

public plugin_init() {
    register_plugin(PLUGIN, VERSION, AUTHOR);

    RegisterHamPlayer(Ham_Spawn, "HamHook_Player_Spawn_Post", .Post = 1);

    register_forward(FM_SetClientKeyValue, "FMHook_SetClientKeyValue");
}

public plugin_natives() {
    register_library("api_player_model");
    register_native("PlayerModel_Get", "Native_GetPlayerModel");
    register_native("PlayerModel_Set", "Native_SetPlayerModel");
    register_native("PlayerModel_Reset", "Native_ResetPlayerModel");
    register_native("PlayerModel_Update", "Native_UpdatePlayerModel");
}

public Native_GetPlayerModel(iPluginId, iArgc) {
    new pPlayer = get_param(1);

    set_string(2, g_rgszCustomPlayerModel[pPlayer], get_param(3));
}

public Native_SetPlayerModel(iPluginId, iArgc) {
    new pPlayer = get_param(1);
    get_string(2, g_rgszCustomPlayerModel[pPlayer], charsmax(g_rgszCustomPlayerModel[]));
}

public Native_ResetPlayerModel(iPluginId, iArgc) {
    new pPlayer = get_param(1);
    @Player_ResetModel(pPlayer);
}

public Native_UpdatePlayerModel(iPluginId, iArgc) {
    new pPlayer = get_param(1);
    @Player_UpdateModel(pPlayer);
}

public client_connect(pPlayer) {
    copy(g_rgszCustomPlayerModel[pPlayer], charsmax(g_rgszCustomPlayerModel[]), NULL_STRING);
    copy(g_rgszPlayerModel[pPlayer], charsmax(g_rgszPlayerModel[]), NULL_STRING);
}

public HamHook_Player_Spawn_Post(pPlayer) {
    @Player_UpdateModel(pPlayer);
}

public FMHook_SetClientKeyValue(pPlayer, const szInfoBuffer[], const szKey[], const szValue[]) {
    if (equal(szKey, "model")) {
        copy(g_rgszPlayerModel[pPlayer], charsmax(g_rgszPlayerModel[]), szValue);

        if (!equal(g_rgszCustomPlayerModel[pPlayer], NULL_STRING)) {
            return FMRES_SUPERCEDE;
        }

        return FMRES_IGNORED;
    }

    return FMRES_IGNORED;
}

public @Player_UpdateModel(this) {
    if (!equal(g_rgszCustomPlayerModel[this], NULL_STRING)) {
        new iModelIndex = engfunc(EngFunc_ModelIndex, g_rgszCustomPlayerModel[this]);
        set_user_info(this, "model", "");
        set_pev(this, pev_modelindex, iModelIndex);
        set_member(this, m_modelIndexPlayer, iModelIndex);
    } else {
        @Player_ResetModel(this);
    }
}

public @Player_ResetModel(this) {
    if (equal(g_rgszPlayerModel[this], NULL_STRING)) {
        return;
    }
    
    static szPath[MAX_RESOURCE_PATH_LENGTH];
    format(szPath, charsmax(szPath), "models/player/%s/%s.mdl", g_rgszPlayerModel[this], g_rgszPlayerModel[this]);

    new iModelIndex = engfunc(EngFunc_ModelIndex, szPath);
    set_user_info(this, "model", g_rgszPlayerModel[this]);
    set_pev(this, pev_modelindex, iModelIndex);
    set_member(this, m_modelIndexPlayer, iModelIndex);
    copy(g_rgszCustomPlayerModel[this], charsmax(g_rgszCustomPlayerModel[]), NULL_STRING);
}
