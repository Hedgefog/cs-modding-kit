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
  CEFunction_Spawn, // Calls when entity spawned
  CEFunction_Kill, // Calls when some plugin try to kill entity. return PLUGIN_HANDLED to discard kill.
  CEFunction_Killed, // Calls when entity killed
  CEFunction_Remove, // Calls when entity removed
  CEFunction_Picked, // Calls when player pick item
  CEFunction_Pickup, // Calls when player touch item. Should return PLUGIN_HANDLED if picked.
  CEFunction_KVD, // Calls when new key value obtained
  CEFunction_Activate, // Calls every trigger activation check
  CEFunction_Activated, // Calls when player activates trigger
  CEFunction_Init, // Calls when entity is initialized (on first spawn)
  CEFunction_Restart, // Calls when entity is restarting (on first spawn)
  CEFunction_Think, // Calls when entity thinking
  CEFunction_Touch, // Calls when entity touched
  CEFunction_InitModel, // Calls when on entity model initialization
  CEFunction_InitSize, // Calls when on entity model initialization
  CEFunction_InitPhysics, // Calls when on entity model initialization
};

/*
 * Register entity.
 *
 * @param szName Name of entity.
 * @param modelIndex Precached model index.
 * @param size Size of entity.
 * @param offset Offset of entity origin.
 * @param lifeTime Life time of entity.
 * @param preset Preset for entity.
 * @return Handler of registered entity.
 */
native CE_Register(
  const szName[],
  const szModel[] = "",
  const Float:vMins[3] = {0.0, 0.0, 0.0},
  const Float:vMaxs[3] = {0.0, 0.0, 0.0},
  Float:fLifeTime = 0.0,
  Float:fRespawnTime = 10.0,
  bool:ignoreRounds = false,
  CEPreset:preset = CEPreset_None,
  bloodColor = -1
);

/*
 * Spawn entity.
 *
 * @param szName Name of entity.
 * @param vOrigin Spawn origin.
 * @return Entity index.
 */
native CE_Create(const szName[], const Float:vOrigin[3] = {0.0, 0.0, 0.0}, bool:temp = true);

/*
 * Kill entity.
 *
 * @param ent Index of entity.
 * @param killer Index of killer.
 */
native bool:CE_Kill(ent, killer = 0);

/*
 * Remove entity correctly.
 *
 * @param ent Index of entity.
 * @return Result true/false
 */
native bool:CE_Remove(ent);

/*
 * Gets size of entity.
 *
 * @param szName Name of entity.
 * @param vSize Output vector.
 */
native CE_GetSize(const szName[], Float:vMins[3], Float:vMaxs[3]);

/*
 * Gets model of entity.
 *
 * @param szName Name of entity.
 * @param szModel Output string
 * @param iLen Output string max length
 * @return Result true/false
 */
native bool:CE_GetModel(const szName[], szModel[], iLen);

/*
 * Register new hook for entity.
 *
 * @param function Function handler
 * @param szName Name of entity
 * @param szCallback Callback
 */
native CE_RegisterHook(CEFunction:function, const szName[], const szCallback[]);

/*
 * Gets handler of entity by name.
 *
 * @param szName Name of entity.
 */
native CE_GetHandler(const szName[]);

/*
 * Gets handler of entity by index.
 *
 * @param ent Index of entity.
 */
native CE_GetHandlerByEntity(ent);

native bool:CE_HasMember(ent, const szMember[]);
native any:CE_GetMember(ent, const szMember[]);
native CE_DeleteMember(ent, const szMember[]);
native CE_SetMember(ent, const szMember[], any:value);
native bool:CE_GetMemberVec(ent, const szMember[], Float:vOut[3]);
native CE_SetMemberVec(ent, const szMember[], const Float:vValue[3]);
native bool:CE_GetMemberString(ent, const szMember[], szOut[], len);
native CE_SetMemberString(ent, const szMember[], const szValue[]);
