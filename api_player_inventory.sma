#pragma semicolon 1

#include <amxmodx>
#include <amxmisc>
#include <nvault>

#include <cellstruct>

#define VAULT_NAME "api_player_inventory"
#define VAULT_VERSION 1

#define PLUGIN "[API] Player Inventory"
#define VERSION "1.0.0"
#define AUTHOR "Hedgehog Fog"

enum InventorySlot { InventorySlot_Item, InventorySlot_Type[32] };

new g_fwInitialized;
new g_fwLoad;
new g_fwLoaded;
new g_fwSave;
new g_fwSaved;
new g_fwSlotCreated;
new g_fwSlotRemoved;
new g_fwSlotLoad;
new g_fwSlotLoaded;
new g_fwSlotSave;
new g_fwSlotSaved;

new g_hVault;

new g_rgszPlayerAuthId[MAX_PLAYERS + 1][32];
new Array:g_irgPlayerInventories[MAX_PLAYERS + 1] = { Invalid_Array, ... };

public plugin_precache() {
  g_hVault = OpenVault();
}

public plugin_init() {
  register_plugin(PLUGIN, VERSION, AUTHOR);

  g_fwInitialized = CreateMultiForward("PlayerInventory_Fw_Initialized", ET_STOP, FP_CELL);
  g_fwLoad = CreateMultiForward("PlayerInventory_Fw_Load", ET_STOP, FP_CELL);
  g_fwLoaded = CreateMultiForward("PlayerInventory_Fw_Loaded", ET_IGNORE, FP_CELL);
  g_fwSave = CreateMultiForward("PlayerInventory_Fw_Save", ET_STOP, FP_CELL);
  g_fwSaved = CreateMultiForward("PlayerInventory_Fw_Saved", ET_IGNORE, FP_CELL);
  g_fwSlotCreated = CreateMultiForward("PlayerInventory_Fw_SlotCreated", ET_IGNORE, FP_CELL, FP_CELL);
  g_fwSlotRemoved = CreateMultiForward("PlayerInventory_Fw_SlotRemoved", ET_IGNORE, FP_CELL, FP_CELL);
  g_fwSlotLoad = CreateMultiForward("PlayerInventory_Fw_SlotLoad", ET_STOP, FP_CELL, FP_CELL);
  g_fwSlotLoaded = CreateMultiForward("PlayerInventory_Fw_SlotLoaded", ET_IGNORE, FP_CELL, FP_CELL);
  g_fwSlotSave = CreateMultiForward("PlayerInventory_Fw_SlotSave", ET_STOP, FP_CELL, FP_CELL);
  g_fwSlotSaved = CreateMultiForward("PlayerInventory_Fw_SlotSaved", ET_IGNORE, FP_CELL, FP_CELL);
}

public plugin_end() {
  nvault_close(g_hVault);
}

public plugin_natives() {
  register_library("api_player_inventory");

  register_native("PlayerInventory_GetItem", "Native_GetItem");
  register_native("PlayerInventory_CheckItemType", "Native_CheckItemType");
  register_native("PlayerInventory_GetItemType", "Native_GetItemType");
  register_native("PlayerInventory_GiveItem", "Native_GiveItem");
  register_native("PlayerInventory_SetItem", "Native_SetItem");
  register_native("PlayerInventory_TakeItem", "Native_TakeItem");
  register_native("PlayerInventory_Size", "Native_Size");
}

/*--------------------------------[ Natives ]--------------------------------*/

public Struct:Native_GetItem(iPluginId, iArgc) {
  new pPlayer = get_param(1);
  new iSlot = get_param(2);

  new Struct:sSlot = ArrayGetCell(g_irgPlayerInventories[pPlayer], iSlot);
  if (sSlot == Invalid_Struct) {
    return Invalid_Struct;
  }

  return StructGetCell(sSlot, InventorySlot_Item);
}

public bool:Native_CheckItemType(iPluginId, iArgc) {
  new pPlayer = get_param(1);
  new iSlot = get_param(2);

  static szType[32];
  get_string(3, szType, charsmax(szType));

  new Struct:sSlot = ArrayGetCell(g_irgPlayerInventories[pPlayer], iSlot);
  if (sSlot == Invalid_Struct) {
    return false;
  }

  static szSlotType[32];
  StructGetString(sSlot, InventorySlot_Type, szSlotType, charsmax(szSlotType));

  return !!equal(szType, szSlotType);
}

public bool:Native_GetItemType(iPluginId, iArgc) {
  new pPlayer = get_param(1);
  new iSlot = get_param(2);

  new Struct:sSlot = ArrayGetCell(g_irgPlayerInventories[pPlayer], iSlot);
  if (sSlot == Invalid_Struct) {
    return false;
  }

  static szType[32];
  StructGetString(sSlot, InventorySlot_Type, szType, charsmax(szType));

  set_string(3, szType, get_param(4));

  return true;
}

public Native_GiveItem(iPluginId, iArgc) {
  new pPlayer = get_param(1);

  static szType[32];
  get_string(2, szType, charsmax(szType));

  new Struct:sItem = Struct:get_param(3);

  return @Player_GiveItem(pPlayer, szType, sItem);
}

public Native_SetItem(iPluginId, iArgc) {
  new pPlayer = get_param(1);
  new iSlot = get_param(2);

  static szType[32];
  get_string(3, szType, charsmax(szType));

  new Struct:sItem = Struct:get_param(4);

  @Player_SetItem(pPlayer, iSlot, szType, sItem);
}

public Native_TakeItem(iPluginId, iArgc) {
  new pPlayer = get_param(1);
  new iSlot = get_param(2);

  return @Player_TakeItem(pPlayer, iSlot);
}

public Native_Size(iPluginId, iArgc) {
  new pPlayer = get_param(1);

  return ArraySize(g_irgPlayerInventories[pPlayer]);
}

/*--------------------------------[ Forwards ]--------------------------------*/

public client_connect(pPlayer) {
  if (g_irgPlayerInventories[pPlayer] != Invalid_Array) {
    ArrayDestroy(g_irgPlayerInventories[pPlayer]);
  }

  g_irgPlayerInventories[pPlayer] = ArrayCreate();

  ExecuteForward(g_fwInitialized, _, pPlayer);
}

public client_authorized(pPlayer) {
  get_user_authid(pPlayer, g_rgszPlayerAuthId[pPlayer], charsmax(g_rgszPlayerAuthId[]));
  LoadPlayerInventory(pPlayer);
}

public client_disconnected(pPlayer) {
  SavePlayerInventory(pPlayer);
}

/*--------------------------------[ Player Methods ]--------------------------------*/

@Player_GiveItem(this, const szType[], Struct:sItem) {
  new Struct:sSlot = @InventorySlot_Create(this, szType, sItem);

  static szSavedType[32];
  StructGetString(sSlot, InventorySlot_Type, szSavedType, charsmax(szSavedType));

  new iSlot = ArrayPushCell(g_irgPlayerInventories[this], sSlot);
  ExecuteForward(g_fwSlotCreated, _, this, iSlot);

  return iSlot;
}

@Player_SetItem(this, iSlot, const szType[], Struct:sItem) {
  new Struct:sSlot = ArrayGetCell(g_irgPlayerInventories[this], iSlot);
  if (sSlot == Invalid_Struct) {
    sSlot = @InventorySlot_Create(this, szType, sItem);
  } else {
    StructSetString(sSlot, InventorySlot_Type, szType);
    StructSetCell(sSlot, InventorySlot_Item, sItem);
  }
}

@Player_TakeItem(this, iSlot) {
  new Struct:sSlot = ArrayGetCell(g_irgPlayerInventories[this], iSlot);
  if (sSlot == Invalid_Struct) {
    return false;
  }

  static iResult;
  ExecuteForward(g_fwSlotRemoved, iResult, this, iSlot);

  if (iResult != PLUGIN_CONTINUE) {
    return false;
  }

  @InventorySlot_Destroy(sSlot);
  ArraySetCell(g_irgPlayerInventories[this], iSlot, Invalid_Struct);

  return true;
}

/*--------------------------------[ Inventory Methods ]--------------------------------*/

Struct:@InventorySlot_Create(pPlayer, const szType[], Struct:sItem) {
  new Struct:this = StructCreate(InventorySlot);
  StructSetString(this, InventorySlot_Type, szType);
  StructSetCell(this, InventorySlot_Item, sItem);

  return this;
}

@InventorySlot_Destroy(&Struct:this) {
  StructDestroy(this);
}

/*--------------------------------[ Vault ]--------------------------------*/

OpenVault() {
  new szVaultDir[256];
  get_datadir(szVaultDir, charsmax(szVaultDir));
  format(szVaultDir, charsmax(szVaultDir), "%s/vault", szVaultDir);

  static szVaultFilePath[256];
  format(szVaultFilePath, charsmax(szVaultFilePath), "%s/%s.vault", szVaultDir, VAULT_NAME);

  new bool:bNew = true;

  if (file_exists(szVaultFilePath)) {
    new hVault = nvault_open(VAULT_NAME);
    new iVersion = nvault_get(hVault, "_version");
    nvault_close(hVault);

    if (iVersion < VAULT_VERSION) {
      log_amx("Invalid vault file. The vault file will be replaced!");

      static szBacukupVaultFilePath[256];
      format(szBacukupVaultFilePath, charsmax(szBacukupVaultFilePath), "%s/%s.vault.backup%d", szVaultDir, VAULT_NAME, get_systime());

      rename_file(szVaultFilePath, szBacukupVaultFilePath, 1);
    } else {
      bNew = false;
    }
  }

  new hVault = nvault_open(VAULT_NAME);

  if (bNew) {
    static szVersion[4];
    num_to_str(VAULT_VERSION, szVersion, charsmax(szVersion));
    nvault_pset(hVault, "_version", szVersion);
  }

  return hVault;
}

LoadPlayerInventory(pPlayer) {
  if (g_rgszPlayerAuthId[pPlayer][0] == '^0') {
    return;
  }

  static iLoadResult;
  ExecuteForward(g_fwLoad, iLoadResult, pPlayer);
  if (iLoadResult != PLUGIN_CONTINUE) {
    return;
  }

  ArrayClear(g_irgPlayerInventories[pPlayer]);

  new szKey[32];
  new szValue[1024];

  format(szKey, charsmax(szKey), "%s_size", g_rgszPlayerAuthId[pPlayer]);
  new iInventorySize = nvault_get(g_hVault, szKey);

  //Save items
  for (new iSlot = 0; iSlot < iInventorySize; ++iSlot) {
    static iSlotLoadResult;
    ExecuteForward(g_fwSlotLoad, iSlotLoadResult, pPlayer, iSlot);
    if (iSlotLoadResult != PLUGIN_CONTINUE) {
      continue;
    }

    // item type
    format(szKey, charsmax(szKey), "%s_item_%i_type", g_rgszPlayerAuthId[pPlayer], iSlot);

    new szType[32];
    nvault_get(g_hVault, szKey, szType, charsmax(szType));

    // item struct
    format(szKey, charsmax(szKey), "%s_item_%i", g_rgszPlayerAuthId[pPlayer], iSlot);
    nvault_get(g_hVault, szKey, szValue, charsmax(szValue));
    new Struct:sItem = StructFromString(sItem, szValue);

    @Player_GiveItem(pPlayer, szType, sItem);

    ExecuteForward(g_fwSlotLoaded, _, pPlayer, iSlot);
  }

  ExecuteForward(g_fwLoaded, _, pPlayer);
}

SavePlayerInventory(pPlayer) {
  if (g_rgszPlayerAuthId[pPlayer][0] == '^0') {
    return;
  }

  new Array:irgInventory = g_irgPlayerInventories[pPlayer];

  new iInventorySize = ArraySize(irgInventory);
  if (!iInventorySize) {
    return;
  }

  new iSaveResult = 0;
  ExecuteForward(g_fwSave, iSaveResult, pPlayer);
  if (iSaveResult != PLUGIN_CONTINUE) {
    return;
  }

  new szKey[32];
  new szValue[1024];

  //Save items
  new iNewInventorySize = 0;
  for (new iSlot = 0; iSlot < iInventorySize; ++iSlot) {
    new Struct:sSlot = ArrayGetCell(irgInventory, iSlot);

    if (sSlot == Invalid_Struct) {
      continue;
    }

    static iSlotSaveResult;
    ExecuteForward(g_fwSlotSave, iSlotSaveResult, pPlayer, iSlot);
    if (iSlotSaveResult != PLUGIN_CONTINUE) {
      continue;
    }

    new Struct:sItem = StructGetCell(sSlot, InventorySlot_Item);

    // item type
    format(szKey, charsmax(szKey), "%s_item_%i_type", g_rgszPlayerAuthId[pPlayer], iNewInventorySize);
    StructGetString(sSlot, InventorySlot_Type, szValue, charsmax(szValue));
    nvault_set(g_hVault, szKey, szValue);

    // item struct
    format(szKey, charsmax(szKey), "%s_item_%i", g_rgszPlayerAuthId[pPlayer], iNewInventorySize);
    StructStringify(sItem, szValue, charsmax(szValue));
    nvault_set(g_hVault, szKey, szValue);

    iNewInventorySize++;

    ExecuteForward(g_fwSlotSaved, _, pPlayer, iSlot);
  }

  for (new iSlot = iNewInventorySize; iSlot < iInventorySize; ++iSlot) {
    format(szKey, charsmax(szKey), "%s_item_%i", g_rgszPlayerAuthId[pPlayer], iSlot);
    nvault_remove(g_hVault, szKey);

    format(szKey, charsmax(szKey), "%s_item_%i_type", g_rgszPlayerAuthId[pPlayer], iSlot);
    nvault_remove(g_hVault, szKey);
  }

  // save inventory size
  format(szKey, charsmax(szKey), "%s_size", g_rgszPlayerAuthId[pPlayer]);
  format(szValue, charsmax(szValue), "%i", iNewInventorySize);

  nvault_set(g_hVault, szKey, szValue);

  ExecuteForward(g_fwSaved, _, pPlayer);
}
