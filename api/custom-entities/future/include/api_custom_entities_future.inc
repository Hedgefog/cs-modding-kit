#if defined _api_custom_entities_included
  #endinput
#endif
#define _api_custom_entities_included

#pragma reqlib api_custom_entities

#include <api_custom_entities_const>

/**
 * Register entity
 *
 * @param szClassname Name of an entity
 * @param iPreset Preset for an entity
 *
 * @return Handler of the registered entity
 */
native CE:CE_RegisterClass(const szClassname[], CEPreset:iPreset = CEPreset_Base, bool:bAbstract = false);

/**
 * Extend entity
 *
 * @param szClassname Name of an entity
 * @param szBase Name of a parent entity
 * @param bAbstract Abstract flag
 *
 * @return Handler of the registered entity
 */
native CE:CE_RegisterClassDerived(const szClassname[], const szBase[], bool:bAbstract = false);

/**
 * Extend entity
 *
 * @param szAlias Name of an alias
 * @param szClassname Name of an entity
 *
 * @return Handler of the registered entity
 */
native CE:CE_RegisterClassAlias(const szAlias[], const szClassname[]);

/**
 * Spawn entity
 *
 * @param szClassname Name of entity
 * @param vecOrigin Spawn origin
 * @param bTemp Mark entity as an temporary entity
 *
 * @return Entity index
 */
native CE_Create(const szClassname[], const Float:vecOrigin[] = {0.0, 0.0, 0.0}, bool:bTemp = true);
/**
 * Restart entity
 *
 * @param pEntity Entity index
 */
native bool:CE_Restart(const &pEntity);

/**
 * Kill entity
 *
 * @param pEntity Entity index
 * @param pKiller Index of killer
 */
native bool:CE_Kill(const &pEntity, const &pKiller = 0);

/**
 * Remove entity correctly
 *
 * @param pEntity Entity index
 *
 * @return Result true/false
 */
native bool:CE_Remove(const &pEntity);

/**
 * Register new hook for entity
 *
 * @param method Function handler
 * @param szClassname Name of entity
 * @param szCallback Callback
 */
native CE_RegisterClassHook(const szClassname[], CEMethod:method, const szCallback[], bool:bPost);

native any:CE_GetMethodReturn();
native CE_SetMethodReturn(any:value);

native CE_RegisterClassKeyMemberBinding(const szClassname[], const szKey[], const any:szMember[], CEMemberType:iType);

native CE_RemoveClassKeyMemberBinding(const szClassname[], const szKey[], const any:szMember[]);

/**
 * Registers a new method for entity.
 *
 * @param szClassname Name of entity
 * @param szMethod Name of method
 * @param szCallback Callback
 *
 * @noreturn
*/
native CE_RegisterClassMethod(const szClassname[], const szMethod[], const szCallback[], any:...);

/**
 * Implements a native method for entity.
 *
 * @param szClassname Name of entity
 * @param iMethod Method to implement
 * @param szCallback Callback
 *
 * @noreturn
*/
native CE_ImplementClassMethod(const szClassname[], CEMethod:iMethod, const szCallback[]);

/**
 * Registers a new virtual method for entity.
 *
 * @param szClassname Name of entity
 * @param szMethod Name of method
 * @param szCallback Callback
 *
 * @noreturn
*/
native CE_RegisterClassVirtualMethod(const szClassname[], const szMethod[], const szCallback[], any:...);

/**
 * Gets handler of entity by name
 *
 * @param szClassname Name of entity
 *
 * @return Handler of the registered entity or -1 otherwise
 */
native CE:CE_GetClassHandler(const szClassname[]);

/**
 * Gets handler of entity by index
 *
 * @param pEntity Entity index
 *
 * @return Handler of the entity or -1 otherwise
 */
native CE:CE_GetHandler(const &pEntity);

/**
 * Checks if entity is an instance of specific custom entity 
 *
 * @param pEntity Entity index
 * @param szTargetName Name of target entity to check
 *
 * @return Result true/false
 */
native bool:CE_IsInstanceOf(const &pEntity, const szTargetName[]);

/**
 * Checks if entity has member
 *
 * @param pEntity Entity index
 * @param szMember Member name
 */
native bool:CE_HasMember(const &pEntity, const any:szMember[]);

/**
 * Deletes member of an entity
 *
 * @param pEntity Entity index
 * @param szMember Member name
 */
native CE_DeleteMember(const &pEntity, const any:szMember[]);

/**
 * Gets member of an entity
 *
 * @param pEntity Entity index
 * @param szMember Member name
 *
 * @return Member value
 */
native any:CE_GetMember(const &pEntity, const any:szMember[]);

/**
 * Sets member of an entity
 *
 * @param pEntity Entity index
 * @param szMember Member name
 * @param value Value to set
 */
native CE_SetMember(const &pEntity, const any:szMember[], any:value, bool:bReplace = true);

/**
 * Gets vector member of an entity
 *
 * @param pEntity Entity index
 * @param szMember Member name
 * @param vecOut Output vector
 */
native bool:CE_GetMemberVec(const &pEntity, const any:szMember[], Float:vecOut[3]);

/**
 * Sets vector member of an entity
 *
 * @param pEntity Entity index
 * @param szMember Member name
 * @param vecValue Vector to set
 */
native CE_SetMemberVec(const &pEntity, const any:szMember[], const Float:vecValue[], bool:bReplace = true);

/**
 * Gets string member of an entity
 *
 * @param pEntity Entity index
 * @param szMember Member name
 * @param szOut Buffer to copy the value
 * @param iLen Maximum size of buffer
 */
native bool:CE_GetMemberString(const &pEntity, const any:szMember[], szOut[], iLen);

/**
 * Sets string member of an entity
 *
 * @param pEntity Entity index
 * @param szMember Member name
 * @param szValue String value to set
 */
native CE_SetMemberString(const &pEntity, const any:szMember[], const szValue[], bool:bReplace = true);

/**
 * Call a method for entity.
 *
 * @param pEntity Entity index
 * @param szMethod Name of method
 *
 * @return Method return value
*/
native any:CE_CallMethod(const &pEntity, const szMethod[], any:...);

/**
 * Call a base method for entity.
 *
 * @param pEntity Entity index
 * @param szMethod Name of method
 *
 * @return Method return value
*/
native any:CE_CallBaseMethod(any:...);

native CE_GetCallPluginId();

native CE_SetThink(const &pEntity, const szMethod[], const szClassname[] = NULL_STRING);
native CE_SetTouch(const &pEntity, const szMethod[], const szClassname[] = NULL_STRING);
native CE_SetUse(const &pEntity, const szMethod[], const szClassname[] = NULL_STRING);
native CE_SetBlocked(const &pEntity, const szMethod[], const szClassname[] = NULL_STRING);
