#if defined _api_custom_entities_included
  #endinput
#endif
#define _api_custom_entities_included

#pragma reqlib api_custom_entities

#define CE_LOG_PREFIX "[CE]"
#define CE_BASE_CLASSNAME "info_target"

enum CEPreset
{
	CEPreset_None = 0,
	CEPreset_Item, // For items
	CEPreset_NPC, // For NPC
	CEPreset_Prop // For static props
};

enum CEFunction
{
	CEFunction_Spawn, // Call when entity spawned
	CEFunction_Kill, // Call when some plugin try to kill entity. return PLUGIN_HANDLED to discard kill.
	CEFunction_Killed, // Call when entity killed
	CEFunction_Remove,	// Call when entity removed
	CEFunction_Picked, // Call when player pick item
	CEFunction_Pickup, // Call when player touch item. Should return PLUGIN_HANDLED if picked.
	CEFunction_KVD // Call when new key value obtained
};
/*
 * Register entity.
 *
 * @param szName			Name of entity.
 * @param modelIndex		Precached model index.
 * @param size				Size of entity.
 * @param offset			Offset of entity origin.
 * @param lifeTime			Life time of entity.
 * @param preset			Preset for entity.
 * @return					Handler of registered entity.
 */
native CE_Register
(
	const szName[],
	modelIndex = 0,
	const Float:vMins[3] = {-8.0, -8.0, -8.0},
	const Float:vMaxs[3] = {8.0, 8.0, 8.0},
	Float:fLifeTime = 0.0,
	Float:fRespawnTime = 10.0,
	bool:ignoreRounds = false,
	CEPreset:preset = CEPreset_None
);

/*
 * Spawn entity.
 *
 * @param szName			Name of entity.
 * @param vOrigin			Spawn origin.
 * @return					Entity index.
 */
native CE_Create(const szName[], const Float:vOrigin[3], bool:temp = true);

/*
 * Kill entity.
 *
 * @param ent				Index of entity.
 * @param killer			Index of killer.
 */
native bool:CE_Kill(ent, killer = 0);


/*
 * Gets size of entity.
 *
 * @param szClassname		Classname of entity.
 * @param vSize				Output vector.
 */
native CE_GetSize(const szName[], Float:vMins[3], Float:vMaxs[3]);

/*
 * Gets modelindex of entity.
 *
 * @param szClassname		Classname of entity.
 * @return					Modelindex of entity
 */
native CE_GetModelIndex(const szName[]);

/*
 * Remove entity correctly.
 *
 * @param ent				Index of entity.
 * @return					Result true/false
 */
native bool:CE_Remove(ent);

/*
 * Register new hook for entity.
 *
 * @param function			Function handler
 * @param szClassname		Classname of entity
 * @param szCallback		Callback
 */
native CE_RegisterHook(CEFunction:function, const szClassname[], const szCallback[]);

/*
 * Check if entity is associated with current plugin.
 *
 * @param ent				Index of entity.
 * @return					Result true/false
 */
native CE_CheckAssociation_(ent);

stock bool:CE_CheckAssociation(ent) {
	static bool:notified = false;
	if (!notified) {
		log_amx("%s function ^"CE_CheckAssociation^" is deprecated. Check ^"CE_GetHandlerByEntity^" function.", CE_LOG_PREFIX);
		notified = true;
	}
	
	return CE_CheckAssociation_(ent);
}

native CE_GetHandler(const szClassname[]);
native CE_GetHandlerByEntity(ent);