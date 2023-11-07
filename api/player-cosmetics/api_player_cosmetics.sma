#pragma semicolon 1

#include <amxmodx>
#include <amxmisc>
#include <fakemeta>
#include <hamsandwich>

#include <command_util>

#define PLUGIN "[API] Player Cosmetics"
#define VERSION "1.0.0"
#define AUTHOR "Hedgehog Fog"

#define COSMETIC_CLASSNAME "_cosmetic"

new Trie:g_itPlayerCosmetics[MAX_PLAYERS + 1];
new g_iszCosmeticClassName;

new Float:g_rgflPlayerNextRenderingUpdate[MAX_PLAYERS + 1];

public plugin_precache() {
    g_iszCosmeticClassName = engfunc(EngFunc_AllocString, "info_target");
}

public plugin_init() {
    register_plugin(PLUGIN, VERSION, AUTHOR);

    RegisterHam(Ham_Think, "info_target", "HamHook_Target_Think", .Post = 0);

    register_concmd("player_cosmetic_equip", "Command_Equip", ADMIN_CVAR);
    register_concmd("player_cosmetic_unequip", "Command_Unequip", ADMIN_CVAR);
}

public plugin_natives() {
    register_library("api_player_cosmetic");
    register_native("PlayerCosmetic_Equip", "Native_Equip");
    register_native("PlayerCosmetic_Unequip", "Native_Unquip");
    register_native("PlayerCosmetic_IsEquiped", "Native_IsEquiped");
    register_native("PlayerCosmetic_GetEntity", "Native_GetEntity");
}

public client_connect(pPlayer) {
    g_itPlayerCosmetics[pPlayer] = TrieCreate();
    g_rgflPlayerNextRenderingUpdate[pPlayer] = get_gametime();
}

public client_disconnected(pPlayer) {
    for (new TrieIter:iIterator = TrieIterCreate(g_itPlayerCosmetics[pPlayer]); !TrieIterEnded(iIterator); TrieIterNext(iIterator)) {
        static pCosmetic;
        TrieIterGetCell(iIterator, pCosmetic);
        @PlayerCosmetic_Destroy(pCosmetic);
    }

    TrieDestroy(g_itPlayerCosmetics[pPlayer]);
}

public Native_Equip(iPluginId, iArgc) {
    new pPlayer = get_param(1);
    new iModelIndex = get_param(2);

    return @Player_EquipCosmetic(pPlayer, iModelIndex);
}

public Native_Unquip(iPluginId, iArgc) {
    new pPlayer = get_param(1);
    new iModelIndex = get_param(2);

    return @Player_UnequipCosmetic(pPlayer, iModelIndex);
}

public Native_IsEquiped(iPluginId, iArgc) {
    new pPlayer = get_param(1);
    new iModelIndex = get_param(2);

    return @Player_IsCosmeticEquiped(pPlayer, iModelIndex);
}

public Native_GetEntity(iPluginId, iArgc) {
    new pPlayer = get_param(1);
    new iModelIndex = get_param(2);

    return @Player_GetCosmeticEntity(pPlayer, iModelIndex);
}

public Command_Equip(pPlayer, iLevel, iCId) {
  if (!cmd_access(pPlayer, iLevel, iCId, 2)) {
    return PLUGIN_HANDLED;
  }

  static szTarget[32];
  read_argv(1, szTarget, charsmax(szTarget));

  static szModel[256];
  read_argv(2, szModel, charsmax(szModel));

  new iTarget = CMD_RESOLVE_TARGET(szTarget);
  new iModelIndex = engfunc(EngFunc_ModelIndex, szModel);

  for (new pTarget = 1; pTarget <= MaxClients; ++pTarget) {
    if (CMD_SHOULD_TARGET_PLAYER(pTarget, iTarget, pPlayer)) {
      @Player_EquipCosmetic(pTarget, iModelIndex);
    }
  }

  return PLUGIN_HANDLED;
}

public Command_Unequip(pPlayer, iLevel, iCId) {
  if (!cmd_access(pPlayer, iLevel, iCId, 2)) {
    return PLUGIN_HANDLED;
  }

  static szTarget[32]; read_argv(1, szTarget, charsmax(szTarget));
  static szModel[256]; read_argv(2, szModel, charsmax(szModel));

  new iTarget = CMD_RESOLVE_TARGET(szTarget);
  new iModelIndex = engfunc(EngFunc_ModelIndex, szModel);

  for (new pTarget = 1; pTarget <= MaxClients; ++pTarget) {
    if (CMD_SHOULD_TARGET_PLAYER(pTarget, iTarget, pPlayer)) {
      @Player_UnequipCosmetic(pTarget, iModelIndex);
    }
  }

  return PLUGIN_HANDLED;
}

public HamHook_Target_Think(pEntity) {
    static szClassName[32];
    pev(pEntity, pev_classname, szClassName, charsmax(szClassName));

    if (equal(szClassName, COSMETIC_CLASSNAME)) {
        @PlayerCosmetic_Think(pEntity);
    }
}

@Player_EquipCosmetic(this, iModelIndex) {
    if (g_itPlayerCosmetics[this] == Invalid_Trie) {
        return -1;
    }

    static szModelIndex[8];
    num_to_str(iModelIndex, szModelIndex, charsmax(szModelIndex));

    new pCosmetic = -1;
    if (TrieKeyExists(g_itPlayerCosmetics[this], szModelIndex)) {
        TrieGetCell(g_itPlayerCosmetics[this], szModelIndex, pCosmetic);
    } else {
        pCosmetic = @PlayerCosmetic_Create(this, iModelIndex);
        TrieSetCell(g_itPlayerCosmetics[this], szModelIndex, pCosmetic);
    }

    return pCosmetic;
}

bool:@Player_UnequipCosmetic(this, iModelIndex) {
    if (g_itPlayerCosmetics[this] == Invalid_Trie) {
        return false;
    }
    
    static szModelIndex[8];
    num_to_str(iModelIndex, szModelIndex, charsmax(szModelIndex));

    static pCosmetic;
    if (!TrieGetCell(g_itPlayerCosmetics[this], szModelIndex, pCosmetic)) {
        return false;
    }

    @PlayerCosmetic_Destroy(pCosmetic);
    TrieDeleteKey(g_itPlayerCosmetics[this], szModelIndex);

    return true;
}

bool:@Player_IsCosmeticEquiped(this, iModelIndex) {
    if (g_itPlayerCosmetics[this] == Invalid_Trie) {
        return false;
    }

    static szModelIndex[8];
    num_to_str(iModelIndex, szModelIndex, charsmax(szModelIndex));

    return TrieKeyExists(g_itPlayerCosmetics[this], szModelIndex);
}

@Player_GetCosmeticEntity(this, iModelIndex) {
    if (g_itPlayerCosmetics[this] == Invalid_Trie) {
        return -1;
    }

    static szModelIndex[8];
    num_to_str(iModelIndex, szModelIndex, charsmax(szModelIndex));

    static pCosmetic;
    if (!TrieGetCell(g_itPlayerCosmetics[this], szModelIndex, pCosmetic)) {
        return -1;
    }

    return pCosmetic;
}

@PlayerCosmetic_Create(pPlayer, iModelIndex) {
    new this = engfunc(EngFunc_CreateNamedEntity, g_iszCosmeticClassName);

    set_pev(this, pev_classname, COSMETIC_CLASSNAME);
    set_pev(this, pev_movetype, MOVETYPE_FOLLOW);
    set_pev(this, pev_aiment, pPlayer);
    set_pev(this, pev_owner, pPlayer);
    set_pev(this, pev_modelindex, iModelIndex);

    set_pev(this, pev_nextthink, get_gametime());

    return this;
}

@PlayerCosmetic_Think(this) {
    new pOwner = pev(this, pev_owner);

    static iRenderMode; iRenderMode = pev(pOwner, pev_rendermode);
    static iRenderFx; iRenderFx = pev(pOwner, pev_renderfx);
    static Float:flRenderAmt; pev(pOwner, pev_renderamt, flRenderAmt);
    static Float:rgflRenderColor[3]; pev(pOwner, pev_rendercolor, rgflRenderColor);

    set_pev(this, pev_rendermode, iRenderMode);
    set_pev(this, pev_renderamt, flRenderAmt);
    set_pev(this, pev_renderfx, iRenderFx);
    set_pev(this, pev_rendercolor, rgflRenderColor);

    set_pev(this, pev_nextthink, get_gametime() + 0.1);
}

@PlayerCosmetic_Destroy(this) {
    set_pev(this, pev_movetype, MOVETYPE_NONE);
    set_pev(this, pev_aiment, 0);
    set_pev(this, pev_flags, pev(this, pev_flags) | FL_KILLME);
    dllfunc(DLLFunc_Think, this);
}
