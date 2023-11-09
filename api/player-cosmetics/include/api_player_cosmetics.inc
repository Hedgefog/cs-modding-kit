#if defined _api_player_cosmetic_included
  #endinput
#endif
#define _api_player_cosmetic_included

#pragma reqlib api_player_cosmetic

/**
 * Equip a player with a cosmetic item.
 *
 * @param pPlayer The player to equip the item to.
 * @param iModelIndex The index of the cosmetic item model.
 * 
 * @noreturn
 */
native PlayerCosmetic_Equip(pPlayer, iModelIndex);

/**
 * Unequip a cosmetic item from a player.
 *
 * @param pPlayer The player to unequip the item from.
 * @param iModelIndex The index of the cosmetic item model.
 * 
 * @return True if the item was successfully unequipped, false otherwise.
 */
native bool:PlayerCosmetic_Unequip(pPlayer, iModelIndex);

/**
 * Check if a player has equipped a specific cosmetic item.
 *
 * @param pPlayer The player to check.
 * @param iModelIndex The index of the cosmetic item model.
 * 
 * @return True if the player has the item equipped, false otherwise.
 */
native bool:PlayerCosmetic_IsEquiped(pPlayer, iModelIndex);

/**
 * Get the entity of the equipped cosmetic item for a player.
 *
 * @param pPlayer The player whose equipped item entity to get.
 * @param iModelIndex The index of the cosmetic item model.
 * 
 * @return The entity of the equipped cosmetic item, or 0 if not equipped.
 */
native PlayerCosmetic_GetEntity(pPlayer, iModelIndex);
