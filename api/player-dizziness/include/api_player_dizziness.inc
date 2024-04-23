#if defined _api_player_dizziness_included
  #endinput
#endif
#define _api_player_dizziness_included

#pragma reqlib api_player_dizziness

/**
 * Sets the dizziness strength for a player.
 *
 * @param pPlayer The player ID.
 * @param flStrength The strength of the dizziness.
 *
 * @noreturn
 */
native PlayerDizziness_Set(pPlayer, Float:flStrength);

/**
 * Gets the current dizziness strength for a player.
 *
 * @param pPlayer The player ID.
 *
 * @return The current dizziness strength as a float.
 */
native Float:PlayerDizziness_Get(pPlayer);
