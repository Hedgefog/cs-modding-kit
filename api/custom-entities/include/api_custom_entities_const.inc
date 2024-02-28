#if defined _api_custom_entities_const_included
  #endinput
#endif
#define _api_custom_entities_const_included

#define CE_BASE_CLASSNAME "info_target"
#define CE_ENTITY_SECRET ('c'+'e'+'2')

#define CE_MAX_NAME_LENGTH 64
#define CE_MAX_MEMBER_LENGTH 64
#define CE_MAX_CALLBACK_LENGTH 64
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
#define CE_MEMBER_INITIALIZED "_bInitialized"
#define CE_MEMBER_BLOODCOLOR "_iBloodColor"
#define CE_MEMBER_LIFETIME "_flLifeTime"
#define CE_MEMBER_IGNOREROUNDS "_bIgnoreRounds"
#define CE_MEMBER_RESPAWNTIME "_flRespawnTime"
#define CE_MEMBER_MINS "_vecMins"
#define CE_MEMBER_MAXS "_vecMaxs"
#define CE_MEMBER_LASTINIT "_flLastInit"
#define CE_MEMBER_LASTSPAWN "_flLastSpawn"
#define CE_MEMBER_PLUGINID "_iPluginId"

enum CE {
  CE_InvalidHandler = -1
};

enum CEPreset {
  CEPreset_None = 0,
  CEPreset_Item,
  CEPreset_NPC,
  CEPreset_Prop,
  CEPreset_Trigger,
  CEPreset_BSP
};

enum CEFunction {
  CEFunction_Invalid = -1,
  CEFunction_KeyValue, // Calls when new key value obtained
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

enum {
  CE_MP_Invalid = -1,
  CE_MP_Cell,
  CE_MP_Float,
  CE_MP_String,
  CE_MP_Array,
  CE_MP_FloatArray
};
