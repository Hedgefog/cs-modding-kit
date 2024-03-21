#if defined _api_player_inventory_included
  #endinput
#endif
#define _api_player_inventory_included

#pragma reqlib api_player_inventory

/**
 * Retrieves an item from a player's inventory.
 *
 * @param pPlayer The player for which to get the item.
 * @param iSlot The slot index of the item to retrieve.
 * 
 * @return Returns a structure containing the structure of the item.
 */
native Struct:PlayerInventory_GetItem(pPlayer, iSlot);

/**
 * Retrieves the type of an item in a player's inventory.
 *
 * @param pPlayer The player for which to check the item type.
 * @param iSlot The slot index of the item.
 * @param szType The type of the item is copied into this string.
 * @param iLen The maximum length of the string.
 *
 * @noreturn
 */
native PlayerInventory_GetItemType(pPlayer, iSlot, szType[], iLen);

/**
 * Checks if an item in a player's inventory matches the specified type.
 *
 * @param pPlayer The player for which to check the item type.
 * @param iSlot The slot index of the item.
 * @param szType The type of the item to check.
 *
 * @return Returns 1 if the item matches the type, 0 otherwise.
 */
native PlayerInventory_CheckItemType(pPlayer, iSlot, const szType[]);

/**
 * Gives an item to a player's inventory.
 *
 * @param pPlayer The player to give the item to.
 * @param szType The type of the item to give.
 * @param sItem The structure of the item to give.
 *
 * @noreturn
 */
native PlayerInventory_GiveItem(pPlayer, const szType[], Struct:sItem);

/**
 * Sets the details of an item in a player's inventory.
 *
 * @param pPlayer The player for which to set the item.
 * @param iSlot The slot index of the item to set.
 * @param szType The type of the item to set.
 * @param sItem The structure of the item to set.
 *
 * @noreturn
 */
native PlayerInventory_SetItem(pPlayer, iSlot, const szType[], Struct:sItem);

/**
 * Takes an item from a player's inventory.
 *
 * @param pPlayer The player from which to take the item.
 * @param iSlot The slot index of the item to take.
 *
 * @noreturn
 */
native PlayerInventory_TakeItem(pPlayer, iSlot);

/**
 * Retrieves the number of slots in a player's inventory.
 *
 * @param pPlayer The player for which to get the inventory size.
 *
 * @return The number of slots in the player's inventory.
 */
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
