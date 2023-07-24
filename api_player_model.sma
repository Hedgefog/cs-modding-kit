#include <amxmodx>
#include <hamsandwich>
#include <fakemeta>
#include <reapi>

#define PLUGIN "[API] Player Model"
#define VERSION "1.0.0"
#define AUTHOR "Hedgehog Fog"

#define MAX_SEQUENCES 101

new g_iszModelClassname;

new g_rgszDefaultPlayerModel[MAX_PLAYERS + 1][32];
new g_rgszCurrentPlayerModel[MAX_PLAYERS + 1][256];
new g_rgszCustomPlayerModel[MAX_PLAYERS + 1][256];
new g_rgiPlayerAnimationIndex[MAX_PLAYERS + 1];
new bool:g_rgbPlayerUseDefaultModel[MAX_PLAYERS + 1];

new Trie:g_itPlayerSequenceModelIndexes = Invalid_Trie;
new Trie:g_itPlayerSequences = Invalid_Trie;
new g_pPlayerModel[MAX_PLAYERS + 1];

new gmsgClCorpse;

public plugin_precache() {
    g_iszModelClassname = engfunc(EngFunc_AllocString, "info_target");
    g_itPlayerSequenceModelIndexes = TrieCreate();
    g_itPlayerSequences = TrieCreate();
}

public plugin_init() {
    register_plugin(PLUGIN, VERSION, AUTHOR);

    gmsgClCorpse = get_user_msgid("ClCorpse");

    register_forward(FM_SetClientKeyValue, "FMHook_SetClientKeyValue");

    RegisterHamPlayer(Ham_Spawn, "HamHook_Player_Spawn_Post", .Post = 1);
    RegisterHamPlayer(Ham_Player_PostThink, "HamHook_Player_PostThink_Post", .Post = 1);

    RegisterHookChain(RG_CBasePlayer_SetAnimation, "HC_Player_SetAnimation");

    register_message(gmsgClCorpse, "Message_ClCorpse");
}

public plugin_natives() {
    register_library("api_player_model");
    register_native("PlayerModel_Get", "Native_GetPlayerModel");
    register_native("PlayerModel_GetCurrent", "Native_GetCurrentPlayerModel");
    register_native("PlayerModel_Set", "Native_SetPlayerModel");
    register_native("PlayerModel_Reset", "Native_ResetPlayerModel");
    register_native("PlayerModel_Update", "Native_UpdatePlayerModel");
    register_native("PlayerModel_PrecacheAnimation", "Native_PrecacheAnimation");
    register_native("PlayerModel_SetSequence", "Native_SetPlayerSequence");
}

public Native_GetPlayerModel(iPluginId, iArgc) {
    new pPlayer = get_param(1);
    set_string(2, g_rgszCustomPlayerModel[pPlayer], get_param(3));
}

public Native_GetCurrentPlayerModel(iPluginId, iArgc) {
    new pPlayer = get_param(1);
    set_string(2, g_rgszCurrentPlayerModel[pPlayer], get_param(3));
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
    @Player_UpdateCurrentModel(pPlayer);
}

public Native_PrecacheAnimation(iPluginId, iArgc) {
    static szAnimation[MAX_RESOURCE_PATH_LENGTH];
    get_string(1, szAnimation, charsmax(szAnimation));
    PrecachePlayerAnimation(szAnimation);
}

public Native_SetPlayerSequence(iPluginId, iArgc) {
    new pPlayer = get_param(1);

    static szSequence[MAX_RESOURCE_PATH_LENGTH];
    get_string(2, szSequence, charsmax(szSequence));

    return @Player_SetSequence(pPlayer, szSequence);
}

public client_connect(pPlayer) {
    copy(g_rgszCustomPlayerModel[pPlayer], charsmax(g_rgszCustomPlayerModel[]), NULL_STRING);
    copy(g_rgszDefaultPlayerModel[pPlayer], charsmax(g_rgszDefaultPlayerModel[]), NULL_STRING);
    copy(g_rgszCurrentPlayerModel[pPlayer], charsmax(g_rgszCurrentPlayerModel[]), NULL_STRING);
    g_rgiPlayerAnimationIndex[pPlayer] = 0;
    g_rgbPlayerUseDefaultModel[pPlayer] = true;
}

public Message_ClCorpse(iMsgId, iMsgDest, pPlayer) {
    new pTargetPlayer = get_msg_arg_int(12);
    if (!g_rgbPlayerUseDefaultModel[pTargetPlayer] || g_rgiPlayerAnimationIndex[pTargetPlayer]) {
        set_msg_arg_string(1, g_rgszCurrentPlayerModel[pTargetPlayer]);
    }
}

public HamHook_Player_Spawn_Post(pPlayer) {
    if (!g_pPlayerModel[pPlayer]) {
        new pPlayerModel = engfunc(EngFunc_CreateNamedEntity, g_iszModelClassname);
        set_pev(pPlayerModel, pev_movetype, MOVETYPE_FOLLOW);
        set_pev(pPlayerModel, pev_aiment, pPlayer);
        g_pPlayerModel[pPlayer] = pPlayerModel;
    }

    @Player_UpdateCurrentModel(pPlayer);
}

public HamHook_Player_PostThink_Post(pPlayer) {
    if (g_pPlayerModel[pPlayer]) {
        set_entvar(g_pPlayerModel[pPlayer], var_skin, get_entvar(pPlayer, var_skin));
        set_entvar(g_pPlayerModel[pPlayer], var_body, get_entvar(pPlayer, var_body));
        set_entvar(g_pPlayerModel[pPlayer], var_colormap, get_entvar(pPlayer, var_colormap));
        set_entvar(g_pPlayerModel[pPlayer], var_rendermode, get_entvar(pPlayer, var_rendermode));
        set_entvar(g_pPlayerModel[pPlayer], var_renderfx, get_entvar(pPlayer, var_renderfx));
        set_entvar(g_pPlayerModel[pPlayer], var_renderamt, get_entvar(pPlayer, var_renderamt));

        static rgflColor[3];
        get_entvar(pPlayer, var_rendercolor, rgflColor);
        set_entvar(g_pPlayerModel[pPlayer], var_rendercolor, rgflColor);
    }

    return HAM_HANDLED;
}

public FMHook_SetClientKeyValue(pPlayer, const szInfoBuffer[], const szKey[], const szValue[]) {
    if (equal(szKey, "model")) {
        copy(g_rgszDefaultPlayerModel[pPlayer], charsmax(g_rgszDefaultPlayerModel[]), szValue);

        if (!equal(g_rgszCurrentPlayerModel[pPlayer], NULL_STRING)) {
            return FMRES_SUPERCEDE;
        }

        return FMRES_IGNORED;
    }

    return FMRES_IGNORED;
}

public HC_Player_SetAnimation(pPlayer) {
    @Player_UpdateAnimationModel(pPlayer);
}

public @Player_UpdateAnimationModel(this) {
    static szAnimExt[32];
    get_member(this, m_szAnimExtention, szAnimExt, charsmax(szAnimExt));

    new iAnimationIndex = is_user_alive(this) ? GetAnimationIndexByAnimExt(szAnimExt) : 0;
    if (iAnimationIndex != g_rgiPlayerAnimationIndex[this]) {
        g_rgiPlayerAnimationIndex[this] = iAnimationIndex;
        @Player_UpdateModel(this, false);
    }
}

public @Player_UpdateCurrentModel(this) {
    new bool:bUsedDefault = g_rgbPlayerUseDefaultModel[this];

    g_rgbPlayerUseDefaultModel[this] = false;

    if (equal(g_rgszCustomPlayerModel[this], NULL_STRING)) {
        if (!equal(g_rgszDefaultPlayerModel[this], NULL_STRING)) {
            format(g_rgszCurrentPlayerModel[this], charsmax(g_rgszCurrentPlayerModel[]), "models/player/%s/%s.mdl", g_rgszDefaultPlayerModel[this], g_rgszDefaultPlayerModel[this]);
        }

        g_rgbPlayerUseDefaultModel[this] = true;
    } else {
        copy(g_rgszCurrentPlayerModel[this], charsmax(g_rgszCurrentPlayerModel[]), g_rgszCustomPlayerModel[this]);
    }

    @Player_UpdateModel(this, !bUsedDefault && g_rgbPlayerUseDefaultModel[this]);
}

public @Player_UpdateModel(this, bool:bForce) {
    new iAnimationIndex = g_rgiPlayerAnimationIndex[this];

    if (bForce || !g_rgbPlayerUseDefaultModel[this] || iAnimationIndex) {
        new iModelIndex = engfunc(EngFunc_ModelIndex, g_rgszCurrentPlayerModel[this]);
        @Player_SetModelIndex(this, iAnimationIndex ? iAnimationIndex : iModelIndex);
        set_pev(g_pPlayerModel[this], pev_modelindex, iAnimationIndex ? iModelIndex : 0);
    } else {
        set_pev(g_pPlayerModel[this], pev_modelindex, 0);
    }
}

public @Player_ResetModel(this) {
    if (equal(g_rgszDefaultPlayerModel[this], NULL_STRING)) {
        return;
    }

    copy(g_rgszCustomPlayerModel[this], charsmax(g_rgszCustomPlayerModel[]), NULL_STRING);
    copy(g_rgszCurrentPlayerModel[this], charsmax(g_rgszCurrentPlayerModel[]), NULL_STRING);
    g_rgiPlayerAnimationIndex[this] = 0;

    @Player_UpdateCurrentModel(this);
}

public @Player_SetModelIndex(this, iModelIndex) {
    set_user_info(this, "model", "");
    set_pev(this, pev_modelindex, iModelIndex);
    set_member(this, m_modelIndexPlayer, iModelIndex);
}

public @Player_SetSequence(this, const szSequence[]) {
    new iAnimationIndex = GetAnimationIndexBySequence(szSequence);
    if (!iAnimationIndex) {
        return -1;
    }

    g_rgiPlayerAnimationIndex[this] = iAnimationIndex;
    @Player_UpdateModel(this, false);

    new iSequence = GetSequenceIndex(szSequence);
    set_pev(this, pev_sequence, iSequence);
    return iSequence;
}

GetAnimationIndexByAnimExt(const szAnimExt[]) {
    static szSequence[32];
    format(szSequence, charsmax(szSequence), "ref_aim_%s", szAnimExt);
    return GetAnimationIndexBySequence(szSequence);
}

GetAnimationIndexBySequence(const szSequence[]) {
    static iAnimationIndex;
    if (!TrieGetCell(g_itPlayerSequenceModelIndexes, szSequence, iAnimationIndex)) {
        return 0;
    }

    return iAnimationIndex;
}

GetSequenceIndex(const szSequence[]) {
    static iSequence;
    if (!TrieGetCell(g_itPlayerSequences, szSequence, iSequence)) {
        return -1;
    }

    return iSequence;
}

// Credis: HamletEagle
PrecachePlayerAnimation(const szAnim[]) {
    new szFilePath[MAX_RESOURCE_PATH_LENGTH];
    format(szFilePath, charsmax(szFilePath), "animations/%s", szAnim);

    new iModelIndex = precache_model(szFilePath);

    new iFile = fopen(szFilePath, "rb")
    if (!iFile) {
        return 0
    }
    
    // Got to "numseq" position of the studiohdr_t structure
    // https://github.com/dreamstalker/rehlds/blob/65c6ce593b5eabf13e92b03352e4b429d0d797b0/rehlds/public/rehlds/studio.h#L68
    fseek(iFile, 164, SEEK_SET);

    new iSeqNum;
    fread(iFile, iSeqNum, BLOCK_INT);

    if (!iSeqNum) {
        return 0;
    }

    new iSeqIndex;
    fread(iFile, iSeqIndex, BLOCK_INT);
    fseek(iFile, iSeqIndex, SEEK_SET);

    new szLabel[32];
    for (new i = 0; i < iSeqNum; i++) {
        if (i >= MAX_SEQUENCES) {
            log_amx("Warning! Sequence limit reached for ^"%s^". Max sequences %d.", szFilePath, MAX_SEQUENCES);
            break;
        }

        fread_blocks(iFile, szLabel, sizeof(szLabel), BLOCK_CHAR);
        TrieSetCell(g_itPlayerSequenceModelIndexes, szLabel, iModelIndex);
        TrieSetCell(g_itPlayerSequences, szLabel, i);

        // jump to the end of the studiohdr_t structure
        // https://github.com/dreamstalker/rehlds/blob/65c6ce593b5eabf13e92b03352e4b429d0d797b0/rehlds/public/rehlds/studio.h#L95
        fseek(iFile, 176 - sizeof(szLabel), SEEK_CUR);
    }
    
    fclose(iFile);

    return iModelIndex;
}
