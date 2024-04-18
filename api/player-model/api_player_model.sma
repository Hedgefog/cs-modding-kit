#pragma semicolon 1

#include <amxmodx>
#include <amxmisc>
#include <fakemeta>
#include <hamsandwich>
#tryinclude <reapi>

#define PLUGIN "[API] Player Model"
#define VERSION "1.0.0"
#define AUTHOR "Hedgehog Fog"

#define NATIVE_ERROR_NOT_CONNECTED(%1) log_error(AMX_ERR_NATIVE, "User %d is not connected", %1)

#define MAX_SEQUENCES 101

new g_iszSubModelClassname;

new bool:g_bIsCStrike;

new g_rgszDefaultPlayerModel[MAX_PLAYERS + 1][32];
new g_rgszCurrentPlayerModel[MAX_PLAYERS + 1][256];
new g_rgszCustomPlayerModel[MAX_PLAYERS + 1][256];
new g_rgiPlayerAnimationIndex[MAX_PLAYERS + 1];
new g_rgpPlayerSubModel[MAX_PLAYERS + 1];
new bool:g_rgbPlayerUseCustomModel[MAX_PLAYERS + 1];

new Trie:g_itPlayerSequenceModelIndexes = Invalid_Trie;
new Trie:g_itPlayerSequences = Invalid_Trie;

public plugin_precache() {
  g_bIsCStrike = !!cstrike_running();
  g_iszSubModelClassname = engfunc(EngFunc_AllocString, "info_target");
  g_itPlayerSequenceModelIndexes = TrieCreate();
  g_itPlayerSequences = TrieCreate();
}

public plugin_init() {
  register_plugin(PLUGIN, VERSION, AUTHOR);

  register_forward(FM_SetClientKeyValue, "FMHook_SetClientKeyValue");

  RegisterHamPlayer(Ham_Spawn, "HamHook_Player_Spawn_Post", .Post = 1);
  RegisterHamPlayer(Ham_Player_PostThink, "HamHook_Player_PostThink_Post", .Post = 1);

  #if defined _reapi_included
    RegisterHookChain(RG_CBasePlayer_SetAnimation, "HC_Player_SetAnimation");
  #endif

  register_message(get_user_msgid("ClCorpse"), "Message_ClCorpse");
}

public plugin_natives() {
  register_library("api_player_model");
  register_native("PlayerModel_Get", "Native_GetPlayerModel");
  register_native("PlayerModel_GetCurrent", "Native_GetCurrentPlayerModel");
  register_native("PlayerModel_GetEntity", "Native_GetPlayerEntity");
  register_native("PlayerModel_HasCustom", "Native_HasCustomPlayerModel");
  register_native("PlayerModel_Set", "Native_SetPlayerModel");
  register_native("PlayerModel_Reset", "Native_ResetPlayerModel");
  register_native("PlayerModel_Update", "Native_UpdatePlayerModel");
  register_native("PlayerModel_UpdateAnimation", "Native_UpdatePlayerAnimation");
  register_native("PlayerModel_SetSequence", "Native_SetPlayerSequence");
  register_native("PlayerModel_PrecacheAnimation", "Native_PrecacheAnimation");
}

public plugin_end() {
  TrieDestroy(g_itPlayerSequenceModelIndexes);
  TrieDestroy(g_itPlayerSequences);
}

// ANCHOR: Natives

public Native_GetPlayerModel(iPluginId, iArgc) {
  new pPlayer = get_param(1);

  if (!is_user_connected(pPlayer)) {
    NATIVE_ERROR_NOT_CONNECTED(pPlayer);
  }

  set_string(2, g_rgszCustomPlayerModel[pPlayer], get_param(3));
}

public Native_GetCurrentPlayerModel(iPluginId, iArgc) {
  new pPlayer = get_param(1);

  if (!is_user_connected(pPlayer)) {
    NATIVE_ERROR_NOT_CONNECTED(pPlayer);
  }
  
  set_string(2, g_rgszCurrentPlayerModel[pPlayer], get_param(3));
}

public Native_GetPlayerEntity(iPluginId, iArgc) {
  new pPlayer = get_param(1);

  if (!is_user_connected(pPlayer)) {
    NATIVE_ERROR_NOT_CONNECTED(pPlayer);
  }

  if (g_rgpPlayerSubModel[pPlayer] && @PlayerSubModel_IsActive(g_rgpPlayerSubModel[pPlayer])) {
    return g_rgpPlayerSubModel[pPlayer];
  }

  return pPlayer;
}

public bool:Native_HasCustomPlayerModel(iPluginId, iArgc) {
  new pPlayer = get_param(1);

  if (!is_user_connected(pPlayer)) {
    NATIVE_ERROR_NOT_CONNECTED(pPlayer);
  }

  return g_rgbPlayerUseCustomModel[pPlayer];
}

public Native_SetPlayerModel(iPluginId, iArgc) {
  new pPlayer = get_param(1);

  if (!is_user_connected(pPlayer)) {
    NATIVE_ERROR_NOT_CONNECTED(pPlayer);
  }

  get_string(2, g_rgszCustomPlayerModel[pPlayer], charsmax(g_rgszCustomPlayerModel[]));
}

public Native_ResetPlayerModel(iPluginId, iArgc) {
  new pPlayer = get_param(1);

  if (!is_user_connected(pPlayer)) {
    NATIVE_ERROR_NOT_CONNECTED(pPlayer);
  }

  @Player_ResetModel(pPlayer);
}

public Native_UpdatePlayerModel(iPluginId, iArgc) {
  new pPlayer = get_param(1);
  
  if (!is_user_connected(pPlayer)) {
    NATIVE_ERROR_NOT_CONNECTED(pPlayer);
  }

  @Player_UpdateCurrentModel(pPlayer);
}

public Native_UpdatePlayerAnimation(iPluginId, iArgc) {
  new pPlayer = get_param(1);

  if (!is_user_connected(pPlayer)) {
    NATIVE_ERROR_NOT_CONNECTED(pPlayer);
  }

  @Player_UpdateAnimationModel(pPlayer);
}

public Native_SetPlayerSequence(iPluginId, iArgc) {
  new pPlayer = get_param(1);

  if (!is_user_connected(pPlayer)) {
    NATIVE_ERROR_NOT_CONNECTED(pPlayer);
  }

  static szSequence[MAX_RESOURCE_PATH_LENGTH];
  get_string(2, szSequence, charsmax(szSequence));

  return @Player_SetSequence(pPlayer, szSequence);
}

public Native_PrecacheAnimation(iPluginId, iArgc) {
  static szAnimation[MAX_RESOURCE_PATH_LENGTH];
  get_string(1, szAnimation, charsmax(szAnimation));
  return PrecachePlayerAnimation(szAnimation);
}

// ANCHOR: Hooks and Forwards

public client_connect(pPlayer) {
  copy(g_rgszCustomPlayerModel[pPlayer], charsmax(g_rgszCustomPlayerModel[]), NULL_STRING);
  copy(g_rgszDefaultPlayerModel[pPlayer], charsmax(g_rgszDefaultPlayerModel[]), NULL_STRING);
  copy(g_rgszCurrentPlayerModel[pPlayer], charsmax(g_rgszCurrentPlayerModel[]), NULL_STRING);
  g_rgiPlayerAnimationIndex[pPlayer] = 0;
  g_rgbPlayerUseCustomModel[pPlayer] = false;
}

public client_disconnected(pPlayer) {
  if (g_rgpPlayerSubModel[pPlayer]) {
    @PlayerSubModel_Destroy(g_rgpPlayerSubModel[pPlayer]);
    g_rgpPlayerSubModel[pPlayer] = 0;
  }
}

public FMHook_SetClientKeyValue(pPlayer, const szInfoBuffer[], const szKey[], const szValue[]) {
  if (equal(szKey, "model")) {
    copy(g_rgszDefaultPlayerModel[pPlayer], charsmax(g_rgszDefaultPlayerModel[]), szValue);

    if (@Player_ShouldUseCurrentModel(pPlayer)) {
      return FMRES_SUPERCEDE;
    }

    return FMRES_HANDLED;
  }

  return FMRES_IGNORED;
}

public HamHook_Player_Spawn_Post(pPlayer) {
  @Player_UpdateCurrentModel(pPlayer);

  return HAM_HANDLED;
}

public HamHook_Player_PostThink_Post(pPlayer) {
  if (g_rgpPlayerSubModel[pPlayer]) {
    @PlayerSubModel_Think(g_rgpPlayerSubModel[pPlayer]);
  }

  if (!g_bIsCStrike) {
    static szModel[MAX_RESOURCE_PATH_LENGTH];
    get_user_info(pPlayer, "model", szModel, charsmax(szModel));
    if (!equal(szModel, NULL_STRING)) {
      copy(g_rgszDefaultPlayerModel[pPlayer], charsmax(g_rgszDefaultPlayerModel[]), szModel);
    }

    @Player_UpdateModel(pPlayer, false);
  }

  return HAM_HANDLED;
}

#if defined _reapi_included
  public HC_Player_SetAnimation(pPlayer) {
    @Player_UpdateAnimationModel(pPlayer);
  }
#endif

public Message_ClCorpse(iMsgId, iMsgDest, pPlayer) {
  new pTargetPlayer = get_msg_arg_int(12);
  if (@Player_ShouldUseCurrentModel(pTargetPlayer)) {
    set_msg_arg_string(1, g_rgszCurrentPlayerModel[pTargetPlayer]);
  }
}

// ANCHOR: Methods

@Player_UpdateAnimationModel(this) {
  new iAnimationIndex = 0;

  if (is_user_alive(this)) {
    static szAnimExt[32]; get_ent_data_string(this, "CBasePlayer", "m_szAnimExtention", szAnimExt, charsmax(szAnimExt));
    iAnimationIndex = GetAnimationIndexByAnimExt(szAnimExt);
  }
  
  if (iAnimationIndex != g_rgiPlayerAnimationIndex[this]) {
    g_rgiPlayerAnimationIndex[this] = iAnimationIndex;
    @Player_UpdateModel(this, !iAnimationIndex);
  }
}

@Player_UpdateCurrentModel(this) {
  new bool:bUsedCustom = g_rgbPlayerUseCustomModel[this];
  new bool:bSetDefaultModel = false;
  new bool:bReset = !!equal(g_rgszCurrentPlayerModel[this], NULL_STRING);

  g_rgbPlayerUseCustomModel[this] = !equal(g_rgszCustomPlayerModel[this], NULL_STRING);

  if (g_rgbPlayerUseCustomModel[this]) {
    copy(g_rgszCurrentPlayerModel[this], charsmax(g_rgszCurrentPlayerModel[]), g_rgszCustomPlayerModel[this]);
  } else if (!equal(g_rgszDefaultPlayerModel[this], NULL_STRING)) {
    format(g_rgszCurrentPlayerModel[this], charsmax(g_rgszCurrentPlayerModel[]), "models/player/%s/%s.mdl", g_rgszDefaultPlayerModel[this], g_rgszDefaultPlayerModel[this]);
    bSetDefaultModel = true;
  }

  if (!g_bIsCStrike && bSetDefaultModel) {
    set_user_info(this, "model", g_rgszDefaultPlayerModel[this]);
  } else {
    @Player_UpdateModel(this, bReset || bUsedCustom && !g_rgbPlayerUseCustomModel[this]);
  }
}

@Player_UpdateModel(this, bool:bForceUpdate) {
  new iSubModelModelIndex = 0;

  if (bForceUpdate || @Player_ShouldUseCurrentModel(this)) {
    new iAnimationIndex = g_rgiPlayerAnimationIndex[this];
    new iModelIndex = engfunc(EngFunc_ModelIndex, g_rgszCurrentPlayerModel[this]);
    @Player_SetModelIndex(this, iAnimationIndex ? iAnimationIndex : iModelIndex);
    iSubModelModelIndex = iAnimationIndex ? iModelIndex : 0;
  }

  if (iSubModelModelIndex && !g_rgpPlayerSubModel[this]) {
    g_rgpPlayerSubModel[this] = @PlayerSubModel_Create(this);
  }

  if (g_rgpPlayerSubModel[this]) {
    set_pev(g_rgpPlayerSubModel[this], pev_modelindex, iSubModelModelIndex);
  }
}

bool:@Player_ShouldUseCurrentModel(this) {
  return g_rgbPlayerUseCustomModel[this] || g_rgiPlayerAnimationIndex[this];
}

@Player_ResetModel(this) {
  if (equal(g_rgszDefaultPlayerModel[this], NULL_STRING)) {
    return;
  }

  copy(g_rgszCustomPlayerModel[this], charsmax(g_rgszCustomPlayerModel[]), NULL_STRING);
  copy(g_rgszCurrentPlayerModel[this], charsmax(g_rgszCurrentPlayerModel[]), NULL_STRING);
  g_rgiPlayerAnimationIndex[this] = 0;

  @Player_UpdateCurrentModel(this);
}

@Player_SetModelIndex(this, iModelIndex) {
  set_user_info(this, "model", "");
  set_pev(this, pev_modelindex, iModelIndex);

  if (g_bIsCStrike) {
    set_ent_data(this, "CBasePlayer", "m_modelIndexPlayer", iModelIndex);
  }
}

@Player_SetSequence(this, const szSequence[]) {
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

@PlayerSubModel_Create(pPlayer) {
  new this = engfunc(EngFunc_CreateNamedEntity, g_iszSubModelClassname);
  set_pev(this, pev_movetype, MOVETYPE_FOLLOW);
  set_pev(this, pev_aiment, pPlayer);
  set_pev(this, pev_owner, pPlayer);

  return this;
}

@PlayerSubModel_Destroy(this) {
  set_pev(this, pev_modelindex, 0);
  set_pev(this, pev_flags, pev(this, pev_flags) | FL_KILLME);
  dllfunc(DLLFunc_Think, this);
}

@PlayerSubModel_Think(this) {
  if (!@PlayerSubModel_IsActive(this)) {
    set_pev(this, pev_effects, pev(this, pev_effects) | EF_NODRAW);
    return;
  }

  new pOwner = pev(this, pev_owner);

  set_pev(this, pev_skin, pev(pOwner, pev_skin));
  set_pev(this, pev_body, pev(pOwner, pev_body));
  set_pev(this, pev_colormap, pev(pOwner, pev_colormap));
  set_pev(this, pev_rendermode, pev(pOwner, pev_rendermode));
  set_pev(this, pev_renderfx, pev(pOwner, pev_renderfx));
  set_pev(this, pev_effects, pev(this, pev_effects) & ~EF_NODRAW);

  static Float:flRenderAmt; pev(pOwner, pev_renderamt, flRenderAmt);
  set_pev(this, pev_renderamt, flRenderAmt);

  static rgflColor[3]; pev(pOwner, pev_rendercolor, rgflColor);
  set_pev(this, pev_rendercolor, rgflColor);
}

@PlayerSubModel_IsActive(this) {
  return (pev(this, pev_modelindex) > 0);
}

// ANCHOR: Functions

GetAnimationIndexByAnimExt(const szAnimExt[]) {
  if (equal(szAnimExt, NULL_STRING)) return 0;

  static szSequence[32]; format(szSequence, charsmax(szSequence), "ref_aim_%s", szAnimExt);

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

  new iFile = fopen(szFilePath, "rb");
  if (!iFile) {
    return 0;
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
