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
native CE:CE_Register(const szClassname[], CEPreset:iPreset = CEPreset_None, bool:bAbstract = false);

/**
 * Extend entity
 *
 * @param szClassname Name of an entity
 * @param iPreset Preset for an entity
 *
 * @return Handler of the registered entity
 */
native CE:CE_RegisterDerived(const szClassname[], const szBase[], bool:bAbstract = false);

/**
 * Spawn entity
 *
 * @param szClassname Name of entity
 * @param vecOrigin Spawn origin
 * @param bTemp Mark entity as an temporary entity
 *
 * @return Entity index
 */
native CE_Create(const szClassname[], const Float:vecOrigin[3] = {0.0, 0.0, 0.0}, bool:bTemp = true);

/**
 * Restart entity
 *
 * @param pEntity Entity index
 */
native bool:CE_Restart(pEntity);

/**
 * Kill entity
 *
 * @param pEntity Entity index
 * @param pKiller Index of killer
 */
native bool:CE_Kill(pEntity, pKiller = 0);

/**
 * Remove entity correctly
 *
 * @param pEntity Entity index
 *
 * @return Result true/false
 */
native bool:CE_Remove(pEntity);

/**
 * Register new hook for entity
 *
 * @param function Function handler
 * @param szClassname Name of entity
 * @param szCallback Callback
 */
native CE_RegisterHook(const szClassname[], CEFunction:function, const szCallback[]);

native CE_RegisterKeyMemberBinding(const szClassname[], const szKey[], const szMember[], CEMemberType:iType);

native CE_RemoveKeyMemberBinding(const szClassname[], const szKey[], const szMember[]);

/**
 * Registers a new method for entity.
 *
 * @param szClassname Name of entity
 * @param szMethod Name of method
 * @param szCallback Callback
 *
 * @noreturn
*/
native CE_RegisterMethod(const szClassname[], const szMethod[], const szCallback[], any:...);

/**
 * Registers a new virtual method for entity.
 *
 * @param szClassname Name of entity
 * @param szMethod Name of method
 * @param szCallback Callback
 *
 * @noreturn
*/
native CE_RegisterVirtualMethod(const szClassname[], const szMethod[], const szCallback[], any:...);

/**
 * Gets handler of entity by name
 *
 * @param szClassname Name of entity
 *
 * @return Handler of the registered entity or -1 otherwise
 */
native CE:CE_GetHandler(const szClassname[]);

/**
 * Gets handler of entity by index
 *
 * @param pEntity Entity index
 *
 * @return Handler of the entity or -1 otherwise
 */
native CE:CE_GetHandlerByEntity(pEntity);

/**
 * Checks if entity is an instance of specific custom entity 
 *
 * @param pEntity Entity index
 * @param szTargetName Name of target entity to check
 *
 * @return Result true/false
 */
native bool:CE_IsInstanceOf(pEntity, const szTargetName[]);

/**
 * Checks if entity has member
 *
 * @param pEntity Entity index
 * @param szMember Member name
 */
native bool:CE_HasMember(pEntity, const szMember[]);

/**
 * Deletes member of an entity
 *
 * @param pEntity Entity index
 * @param szMember Member name
 */
native CE_DeleteMember(pEntity, const szMember[]);

/**
 * Gets member of an entity
 *
 * @param pEntity Entity index
 * @param szMember Member name
 *
 * @return Member value
 */
native any:CE_GetMember(pEntity, const szMember[]);

/**
 * Sets member of an entity
 *
 * @param pEntity Entity index
 * @param szMember Member name
 * @param value Value to set
 */
native CE_SetMember(pEntity, const szMember[], any:value, bool:bReplace = true);

/**
 * Gets vector member of an entity
 *
 * @param pEntity Entity index
 * @param szMember Member name
 * @param vecOut Output vector
 */
native bool:CE_GetMemberVec(pEntity, const szMember[], Float:vecOut[3]);

/**
 * Sets vector member of an entity
 *
 * @param pEntity Entity index
 * @param szMember Member name
 * @param vecValue Vector to set
 */
native CE_SetMemberVec(pEntity, const szMember[], const Float:vecValue[3], bool:bReplace = true);

/**
 * Gets string member of an entity
 *
 * @param pEntity Entity index
 * @param szMember Member name
 * @param szOut Buffer to copy the value
 * @param iLen Maximum size of buffer
 */
native bool:CE_GetMemberString(pEntity, const szMember[], szOut[], iLen);

/**
 * Sets string member of an entity
 *
 * @param pEntity Entity index
 * @param szMember Member name
 * @param szValue String value to set
 */
native CE_SetMemberString(pEntity, const szMember[], const szValue[], bool:bReplace = true);

/**
 * Call a method for entity.
 *
 * @param pEntity Entity index
 * @param szMethod Name of method
 *
 * @return Method return value
*/
native any:CE_CallMethod(pEntity, const szMethod[], any:...);

/**
 * Call a base method for entity.
 *
 * @param pEntity Entity index
 * @param szMethod Name of method
 *
 * @return Method return value
*/
native any:CE_CallBaseMethod(any:...);
