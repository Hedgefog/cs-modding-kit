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

forward PlayerInventory_Fw_SlotLoaded(pPlayer, iSlot);
forward PlayerInventory_Fw_SlotSaved(pPlayer, iSlot);
forward Playerinventory_Fw_NewSlot(pPlayer, iSlot);
forward Playerinventory_Fw_TakeSlot(pPlayer, iSlot);
forward PlayerInventory_Fw_Destroy();
