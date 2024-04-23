#if defined _api_custom_entities_const_included
  #endinput
#endif
#define _api_custom_entities_const_included

#define CE_BASE_CLASSNAME "info_target"
#define CE_ENTITY_SECRET ('c'+'e'+'2')

#define CE_MAX_NAME_LENGTH 64
#define CE_MAX_MEMBER_NAME_LENGTH 64
#define CE_MAX_CALLBACK_NAME_LENGTH 64
#define CE_MAX_METHOD_NAME_LENGTH 64

#define CE_MEMBER_ID "_id"
#define CE_MEMBER_POINTER "_ptr"
#define CE_MEMBER_WORLD "_bWorld"
#define CE_MEMBER_ORIGIN "_vecOrigin"
#define CE_MEMBER_ANGLES "_vecAngles"
#define CE_MEMBER_MASTER "_szMaster"
#define CE_MEMBER_MODEL "_szModel"
#define CE_MEMBER_DELAY "_flDelay"
#define CE_MEMBER_NEXTKILL "_flNextKill"
#define CE_MEMBER_NEXTRESPAWN "_flNextRespawn"
#define CE_MEMBER_BLOODCOLOR "_iBloodColor"
#define CE_MEMBER_LIFETIME "_flLifeTime"
#define CE_MEMBER_IGNOREROUNDS "_bIgnoreRounds"
#define CE_MEMBER_RESPAWNTIME "_flRespawnTime"
#define CE_MEMBER_MINS "_vecMins"
#define CE_MEMBER_MAXS "_vecMaxs"
#define CE_MEMBER_LASTSPAWN "_flLastSpawn"
#define CE_MEMBER_PLUGINID "_iPluginId"
#define CE_MEMBER_TARGETNAME "_szTargetname"
#define CE_MEMBER_TARGET "_szTarget"
#define CE_MEMBER_PICKED "_bPicked"
#define CE_MEMBER_TOGGLESTATE "_iToggleState"
#define CE_MEMBER_TRIGGERED "_bTriggered"

#define CE_IGNORED 0
#define CE_HANDLED 1
#define CE_OVERRIDE 2
#define CE_SUPERCEDE 3

enum CE {
  CE_InvalidHandler = -1
};

enum CEPreset {
  CEPreset_Invalid = -1,
  CEPreset_Base,
  CEPreset_Item,
  CEPreset_Monster,
  CEPreset_Prop,
  CEPreset_Trigger,
  CEPreset_BSP
};

enum CEMethod {
  CEMethod_Invalid = -1,
  CEMethod_Allocate, // Calls when entity instance allocated
  CEMethod_Free, // Called when an instance of an object is about to be destroyed
  CEMethod_KeyValue, // Calls when new key value obtained
  CEMethod_SpawnInit, // Calls when entity is initialized (on first spawn)
  CEMethod_Spawn, // Calls during entity spawn
  CEMethod_ResetVariables, // Calls when entity is initialized (on first spawn)
  CEMethod_UpdatePhysics, // Calls during on entity physics initialization
  CEMethod_UpdateModel, // Calls during on entity model initialization
  CEMethod_UpdateSize, // Calls during on entity size initialization
  CEMethod_Touch, // Calls during entity touch
  CEMethod_Think, // Calls when entity thinking
  CEMethod_CanPickup,
  CEMethod_Pickup, // Calls when player touch item. Should return PLUGIN_HANDLED if picked
  CEMethod_CanTrigger, // Calls every trigger activation check
  CEMethod_Trigger, // Calls every trigger activation check
  CEMethod_Restart, // Calls when entity is restarting
  CEMethod_Killed, // Calls when something killing entity. return PLUGIN_HANDLED to block the kill.
  CEMethod_IsMasterTriggered, // Calls when entity is initialized (on first spawn)
  CEMethod_ObjectCaps,
  CEMethod_BloodColor,
  CEMethod_Use,
  CEMethod_Blocked,
  CEMethod_GetDelay,
  CEMethod_Classify,
  CEMethod_IsTriggered,
  CEMethod_GetToggleState,
  CEMethod_SetToggleState,
  CEMethod_Respawn,
  CEMethod_TraceAttack
};

stock const CE_METHOD_NAMES[CEMethod][] = {
  "Allocate",
  "Free",
  "KeyValue",
  "SpawnInit",
  "Spawn",
  "UpdateVariables",
  "UpdatePhysics",
  "UpdateModel",
  "UpdateSize",
  "Touch",
  "Think",
  "CanPickup",
  "Pickup",
  "CanTrigger",
  "Trigger",
  "Restart",
  "Killed",
  "IsMasterTriggered",
  "ObjectCaps",
  "BloodColor",
  "Use",
  "Blocked",
  "GetDelay",
  "Classify",
  "IsTriggered",
  "GetToggleState",
  "SetToggleState",
  "Respawn",
  "TraceAttack"
};

enum CEMemberType {
  CEMemberType_Invalid = -1,
  CEMemberType_Cell,
  CEMemberType_Float,
  CEMemberType_String,
  CEMemberType_Vector
};

enum {
  CE_MP_Invalid = -1,
  CE_MP_Cell,
  CE_MP_String,
  CE_MP_Array,
  CE_MP_Vector
};
