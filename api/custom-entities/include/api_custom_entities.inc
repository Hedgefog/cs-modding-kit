#if defined _api_custom_entities_included
  #endinput
#endif
#define _api_custom_entities_included

#pragma reqlib api_custom_entities

#define CE_BASE_CLASSNAME "info_target"
#define CE_ENTITY_SECRET ('c'+'e'+'2')

#define CE_MAX_NAME_LENGTH 64
#define CE_MAX_MEMBER_LENGTH 64
#define CE_MAX_CALLBACK_LENGTH 64

#define CE_MEMBER_ID "_id"
#define CE_MEMBER_POINTER "_ptr"
#define CE_MEMBER_WORLD "_world"
#define CE_MEMBER_ORIGIN "_origin"
#define CE_MEMBER_ANGLES "_angles"
#define CE_MEMBER_MASTER "_master"
#define CE_MEMBER_MODEL "_model"
#define CE_MEMBER_DELAY "_delay"
#define CE_MEMBER_NEXTKILL "_nextkill"
#define CE_MEMBER_NEXTRESPAWN "_nextrespawn"
#define CE_MEMBER_INITIALIZED "_initialized"

enum CEPreset {
  CEPreset_None = 0,
  CEPreset_Item,
  CEPreset_NPC,
  CEPreset_Prop,
  CEPreset_Trigger,
  CEPreset_BSP
};

enum CEFunction {
  CEFunction_KVD, // Calls when new key value obtained
  CEFunction_Spawn, // Calls during entity spawn
  CEFunction_Init, // Calls when entity is initialized (on first spawn)
  CEFunction_InitPhysics, // Calls during on entity physics initialization
  CEFunction_InitModel, // Calls during on entity model initialization
  CEFunction_InitSize, // Calls during on entity size initialization
  CEFunction_Spawned, // Calls when entity spawned
  CEFunction_Touch, // Calls during entity touch
  CEFunction_Touched, // Calls when entity touched
  CEFunction_Think, // Calls when entity thinking
  CEFunction_Pickup, // Calls when player touch item. Should return PLUGIN_HANDLED if picked
  CEFunction_Picked, // Calls when player pick item
  CEFunction_Activate, // Calls every trigger activation check
  CEFunction_Activated, // Calls when player activates trigger
  CEFunction_Restart, // Calls when entity is restarting
  CEFunction_Kill, // Calls when something killing entity. return PLUGIN_HANDLED to block the kill.
  CEFunction_Killed, // Calls when entity killed
  CEFunction_Remove, // Calls before entity remove
};

/**
 * Register entity
 *
 * @param szName Name of an entity
 * @param szModel Precached model
 * @param vecMins Bounding box mins vector
 * @param vecMaxs Bounding box maxs vector
 * @param flLifeTime Life time of an entity
 * @param flRespawnTime Respawn time of an entity
 * @param bIgnoreRounds Entity will ignore rounds if true
 * @param iPreset Preset for an entity
 * @param iBloodColor Blood color of an entity
 * @return Handler of the registered entity
 */
native CE_Register(
  const szName[],
  const szModel[] = "",
  const Float:vecMins[3] = {0.0, 0.0, 0.0},
  const Float:vecMaxs[3] = {0.0, 0.0, 0.0},
  Float:flLifeTime = 0.0,
  Float:flRespawnTime = 10.0,
  bool:bIgnoreRounds = false,
  CEPreset:iPreset = CEPreset_None,
  iBloodColor = -1
);

/**
 * Spawn entity
 *
 * @param szName Name of entity
 * @param vecOrigin Spawn origin
 * @param bTemp Mark entity as an temporary entity
 * @return Entity index
 */
native CE_Create(const szName[], const Float:vecOrigin[3] = {0.0, 0.0, 0.0}, bool:bTemp = true);

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
 * @return Result true/false
 */
native bool:CE_Remove(pEntity);

/**
 * Gets size of entity
 *
 * @param szName Name of entity
 * @param vecMins Output for bounding box mins vector
 * @param vecMaxs Output for bounding box maxs vector
 */
native CE_GetSize(const szName[], Float:vecMins[3], Float:vecMaxs[3]);

/**
 * Gets model of entity
 *
 * @param szName Name of entity
 * @param szModel Output string
 * @param iLen Output string max length
 * @return Result true/false
 */
native bool:CE_GetModel(const szName[], szModel[], iLen);

/**
 * Register new hook for entity
 *
 * @param function Function handler
 * @param szName Name of entity
 * @param szCallback Callback
 */
native CE_RegisterHook(CEFunction:function, const szName[], const szCallback[]);

/**
 * Gets handler of entity by name
 *
 * @param szName Name of entity
 */
native CE_GetHandler(const szName[]);

/**
 * Gets handler of entity by index
 *
 * @param pEntity Entity index
 */
native CE_GetHandlerByEntity(pEntity);

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
 */
native any:CE_GetMember(pEntity, const szMember[]);

/**
 * Sets member of an entity
 *
 * @param pEntity Entity index
 * @param szMember Member name
 * @param value Value to set
 */
native CE_SetMember(pEntity, const szMember[], any:value);

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
native CE_SetMemberVec(pEntity, const szMember[], const Float:vecValue[3]);

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
native CE_SetMemberString(pEntity, const szMember[], const szValue[]);
