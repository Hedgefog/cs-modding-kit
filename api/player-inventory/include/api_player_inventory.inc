#if defined _api_player_inventory_included
  #endinput
#endif
#define _api_player_inventory_included

#pragma reqlib api_player_inventory

native Struct:PlayerInventory_GetItem(pPlayer, iSlot);
native PlayerInventory_GetItemType(pPlayer, iSlot, szType[], iLen);
native PlayerInventory_CheckItemType(pPlayer, iSlot, const szType[]);
native PlayerInventory_GiveItem(pPlayer, const szType[], Struct:sItem);
native PlayerInventory_SetItem(pPlayer, iSlot, const szType[], Struct:sItem);
native PlayerInventory_TakeItem(pPlayer, iSlot);

native PlayerInventory_Size(pPlayer);

forward PlayerInventory_Fw_Initialized(pPlayer);
forward PlayerInventory_Fw_Load(pPlayer);
forward PlayerInventory_Fw_Loaded(pPlayer);
forward PlayerInventory_Fw_Save(pPlayer);
forward PlayerInventory_Fw_Saved(pPlayer);
forward PlayerInventory_Fw_SlotCreated(pPlayer, iSlot);
forward PlayerInventory_Fw_SlotRemoved(pPlayer, iSlot);
forward PlayerInventory_Fw_SlotLoad(pPlayer, iSlot);
forward PlayerInventory_Fw_SlotLoaded(pPlayer, iSlot);
forward PlayerInventory_Fw_SlotSave(pPlayer, iSlot);
forward PlayerInventory_Fw_SlotSaved(pPlayer, iSlot);
