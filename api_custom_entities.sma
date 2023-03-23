#pragma semicolon 1

#include <amxmodx>
#include <amxmisc>

#include <engine>
#include <fakemeta>
#include <hamsandwich>

#include <cellarray>
#include <celltrie>

#include <xs>

#define PLUGIN	"[API] Custom Entities"
#define VERSION	"1.2.3"
#define AUTHOR	"Hedgehog Fog"

#define CE_BASE_CLASSNAME "info_target"
#define LOG_PREFIX "[CE]"

#define TASKID_SUM_DISAPPEAR 1000
#define TASKID_SUM_RESPAWN   2000
#define TASKID_SUM_REMOVE    3000

/*--------------------------------[ Constants ]--------------------------------*/

enum CEPreset
{
	CEPreset_None = 0,
	CEPreset_Item,
	CEPreset_NPC,
	CEPreset_Prop
};

enum CEFunction
{
	CEFunction_Spawn,
	CEFunction_Kill,
	CEFunction_Killed,
	CEFunction_Remove,
	CEFunction_Picked,
	CEFunction_Pickup,
	CEFunction_KVD
};

enum CEHookData
{
	CEHookData_PluginID,
	CEHookData_FuncID
};

enum _:RegisterArgs
{
	RegisterArg_Name = 1,
	RegisterArg_ModelIndex,
	RegisterArg_Mins,
	RegisterArg_Maxs,
	RegisterArg_LifeTime,
	RegisterArg_RespawnTime,
	RegisterArg_IgnoreRounds,
	RegisterArg_Preset
};

enum _:CEData
{
	CEData_Handler,
	CEData_TempIndex,
	CEData_WorldIndex,
	CEData_StartOrigin
};

enum _:KVD {
	KVD_Key[64],
	KVD_Value[64]
}

/*--------------------------------[ Variables ]--------------------------------*/

new g_ptrBaseClassname;

new Trie:g_entityHandlers = Invalid_Trie;
new Array:g_entityName = Invalid_Array;
new Array:g_entityPluginID = Invalid_Array;
new Array:g_entityModelIndex = Invalid_Array;
new Array:g_entityMins = Invalid_Array;
new Array:g_entityMaxs = Invalid_Array;
new Array:g_entityLifeTime = Invalid_Array;
new Array:g_entityRespawnTime = Invalid_Array;
new Array:g_entityPreset = Invalid_Array;
new Array:g_entityIgnoreRounds = Invalid_Array;
new Array:g_entityHooks = Invalid_Array;

new g_entityCount = 0;

new Array:g_worldEntities = Invalid_Array;
new Array:g_tmpEntities = Invalid_Array;

new g_lastCEIdx = 0;
new g_lastCEEnt = 0;

new Array:g_ceKvd = Invalid_Array;

public plugin_init()
{
	register_plugin(PLUGIN, VERSION, AUTHOR);

	SpawnLatestCe();
	
	RegisterHam(Ham_Touch, CE_BASE_CLASSNAME, "OnTouch", .Post = 1);
	RegisterHam(Ham_Killed, CE_BASE_CLASSNAME, "OnKilled", .Post = 0);
	
	register_event("HLTV", "OnNewRound", "a", "1=0", "2=0");
	
	register_concmd("ce_spawn", "OnClCmd_CESpawn", ADMIN_CVAR);
}

public plugin_end()
{
	for (new i = 0; i < g_entityCount; ++i) {
		DestroyFunctions(i);
	}

	if (g_entityCount) {
		TrieDestroy(g_entityHandlers);
		ArrayDestroy(g_entityName);
		ArrayDestroy(g_entityPluginID);
		ArrayDestroy(g_entityModelIndex);
		ArrayDestroy(g_entityMins);
		ArrayDestroy(g_entityMaxs);
		ArrayDestroy(g_entityLifeTime);
		ArrayDestroy(g_entityRespawnTime);
		ArrayDestroy(g_entityIgnoreRounds);
		ArrayDestroy(g_entityPreset);
		ArrayDestroy(g_entityHooks);
	}

	if (g_tmpEntities) {
		ArrayDestroy(g_tmpEntities);
	}
	
	if (g_worldEntities) {
		ArrayDestroy(g_worldEntities);
	}

	if (g_ceKvd != Invalid_Array) {
		ArrayDestroy(g_ceKvd);
	}
}

public plugin_precache()
{
	g_ptrBaseClassname = engfunc(EngFunc_AllocString, CE_BASE_CLASSNAME);
	
	register_forward(FM_KeyValue, "OnKeyValue", 1);	
	RegisterHam(Ham_Spawn, CE_BASE_CLASSNAME, "OnSpawn", .Post = 1);
}

public plugin_natives()
{
	register_library("api_custom_entities");
	
	register_native("CE_Register", "Native_Register");	
	register_native("CE_Create", "Native_Create");
	register_native("CE_Kill", "Native_Kill");
	register_native("CE_Remove", "Native_Remove");
	
	register_native("CE_GetSize", "Native_GetSize");
	register_native("CE_GetModelIndex", "Native_GetModelIndex");
	
	register_native("CE_RegisterHook", "Native_RegisterHook");

	register_native("CE_CheckAssociation_", "Native_CheckAssociation");

	register_native("CE_GetHandler", "Native_GetHandler");
	register_native("CE_GetHandlerByEntity", "Native_GetHandlerByEntity");
}

/*--------------------------------[ Natives ]--------------------------------*/

public Native_Register(pluginID, argc)
{
	static szClassName[32];
	get_string(RegisterArg_Name, szClassName, charsmax(szClassName));
	
	new modelIndex = get_param(RegisterArg_ModelIndex);
	new Float:fLifeTime = get_param_f(RegisterArg_LifeTime);
	new Float:fRespawnTime = get_param_f(RegisterArg_RespawnTime);
	new bool:ignoreRounds = bool:get_param(RegisterArg_IgnoreRounds);
	new CEPreset:preset = CEPreset:get_param(RegisterArg_Preset);
	
	new Float:vMins[3];
	get_array_f(RegisterArg_Mins, vMins, 3);
	
	new Float:vMaxs[3];
	get_array_f(RegisterArg_Maxs, vMaxs, 3);
	
	return Register(szClassName, pluginID, modelIndex, vMins, vMaxs, fLifeTime, fRespawnTime, ignoreRounds, preset);
}

public Native_Create(pluginID, argc)
{
	new szClassName[32];
	get_string(1, szClassName, charsmax(szClassName));
	
	new Float:vOrigin[3];
	get_array_f(2, vOrigin, 3);
	
	new bool:temp = !!get_param(3);
	
	return Create(szClassName, vOrigin, temp);
}

public Native_Kill(pluginID, argc)
{
	new ent = get_param(1);
	new killer = get_param(2);

	Kill(ent, killer);
}

public bool:Native_Remove(pluginID, argc)
{
	new ent = get_param(1);
	return Remove(ent);
}

public Native_GetSize(pluginID, argc)
{
	if (!g_entityCount) {
		return false;
	}
	
	new szClassName[32];
	get_string(1, szClassName, charsmax(szClassName));
	
	new ceIdx;
	if (!TrieGetCell(g_entityHandlers, szClassName, ceIdx)) {
		return false;
	}
	
	new Float:vMins[3];
	ArrayGetArray(g_entityMins, ceIdx, vMins);

	new Float:vMaxs[3];
	ArrayGetArray(g_entityMaxs, ceIdx, vMaxs);
	
	set_array_f(2, vMins, 3);
	set_array_f(3, vMaxs, 3);

	return true;
}

public Native_GetModelIndex(pluginID, argc)
{
	if (!g_entityCount) {
		return false;
	}
	
	new szClassName[32];
	get_string(1, szClassName, charsmax(szClassName));
	
	new ceIdx;
	if (!TrieGetCell(g_entityHandlers, szClassName, ceIdx)) {
		return false;
	}
	
	return ArrayGetCell(g_entityModelIndex, ceIdx);
}

public Native_RegisterHook(pluginID, argc)
{
	new CEFunction:function = CEFunction:get_param(1);
	
	new szClassname[32];
	get_string(2, szClassname, charsmax(szClassname));
	
	new szCallback[32];
	get_string(3, szCallback, charsmax(szCallback));

	RegisterHook(function, szClassname, szCallback, pluginID);
}

public Native_CheckAssociation(pluginID, argc)
{
	new ent = get_param(1);
	new ceIdx = GetHandlerByEntity(ent);

	return (ceIdx > 0 && pluginID == ArrayGetCell(g_entityPluginID, ceIdx));
}

public Native_GetHandler(pluginID, argc)
{
	new szClassname[32];
	get_string(1, szClassname, charsmax(szClassname));
	
	return GetHandler(szClassname);
}

public Native_GetHandlerByEntity(pluginID, argc)
{
	new ent = get_param(1);

	return GetHandlerByEntity(ent);
}

/*--------------------------------[ Hooks ]--------------------------------*/

public OnClCmd_CESpawn(id, level, cid)
{
	if(!cmd_access(id, level, cid, 2)) {
		return PLUGIN_HANDLED;
	}
	
	static szClassname[128];
	read_args(szClassname, charsmax(szClassname));
	remove_quotes(szClassname);
	
	if(szClassname[0] == '^0') {
		return PLUGIN_HANDLED;
	}
	
	static Float:vOrigin[3];
	pev(id, pev_origin, vOrigin);
	
	new ent = Create(szClassname, vOrigin);
	if (ent) {
		dllfunc(DLLFunc_Spawn, ent);
	}
	
	return PLUGIN_HANDLED;
}

public OnKeyValue(ent, kvd)
{
	if (!g_entityCount) {
		return;
	}

	static szKey[32];
	get_kvd(kvd, KV_KeyName, szKey, charsmax(szKey));
	
	static szValue[32];
	get_kvd(kvd, KV_Value, szValue, charsmax(szValue));
	
	if (equal(szKey, "classname")) {
		SpawnLatestCe();

		if (TrieGetCell(g_entityHandlers, szValue, g_lastCEIdx)) {
			g_lastCEEnt = Create (szValue, .temp = false); // clone entity
		}
	}

	if (g_lastCEEnt) {
		AddKvd(szKey, szValue);
	}
}

public OnSpawn(ent)
{
	if (!Check(ent)) {
		return;
	}

	new Array:ceData = GetPData(ent);
	new ceIdx = ArrayGetCell(ceData, CEData_Handler);
	
	//Save start origin
	if (ArrayGetCell(ceData, CEData_StartOrigin) == Invalid_Array) {
		new Float:vOrigin[3];
		pev(ent, pev_origin, vOrigin);	
	
		new Array:startOrigin = ArrayCreate(3, 1);
		ArrayPushArray(startOrigin, vOrigin);

		ArraySetCell(ceData, CEData_StartOrigin, startOrigin);
	}
	
	new tmpIdx = ArrayGetCell(ceData, CEData_TempIndex);
	InitEntity(ent, ceIdx, (tmpIdx >= 0));

	ExecuteFunction(CEFunction_Spawn, ceIdx, ent);
}

public OnTouch(ent, id)
{
	// if (pev(ent, pev_flags) & ~FL_ONGROUND) {
	// 	return;
	// }

	if (!is_user_connected(id)) {
		return;
	}
	
	if (!is_user_alive(id)) {
		return;
	}

	if (!g_entityCount) {
		return;
	}

	static szClassname[32];
	pev(ent, pev_classname, szClassname, charsmax(szClassname));	
	
	new ceIdx;
	if (!TrieGetCell(g_entityHandlers, szClassname, ceIdx)) {
		return;
	}
	
	new CEPreset:preset = ArrayGetCell(g_entityPreset, ceIdx);
	if (preset != CEPreset_Item) {
		return;
	}
	
	if (ExecuteFunction(CEFunction_Pickup, ceIdx, ent, id) > 0) {
		ExecuteFunction(CEFunction_Picked, ceIdx, ent, id);
		Kill(ent, id, .picked = true);
	}
}

public OnKilled(ent, killer)
{
	if (!Check(ent)) {
		return HAM_IGNORED;
	}
	
	Kill(ent, killer);
	return HAM_SUPERCEDE;
}

public OnNewRound()
{
	Cleanup();
	set_task(0.1, "TaskRespawnEntities");
}

/*--------------------------------[ Methods ]--------------------------------*/

Register(
	const szClassname[],
	pluginID,
	modelIndex,
	const Float:vMins[3],
	const Float:vMaxs[3],
	Float:fLifeTime,
	Float:fRespawnTime,
	bool:ignoreRounds,
	CEPreset:preset
)
{
	if (!g_entityCount) {
		g_entityHandlers = TrieCreate();
		g_entityName = ArrayCreate(32);
		g_entityPluginID = ArrayCreate();
		g_entityModelIndex = ArrayCreate();
		g_entityMaxs = ArrayCreate(3);
		g_entityMins = ArrayCreate(3);
		g_entityLifeTime = ArrayCreate();
		g_entityRespawnTime = ArrayCreate();
		g_entityIgnoreRounds = ArrayCreate();
		g_entityPreset = ArrayCreate();
		g_entityHooks = ArrayCreate();
	}

	new index = g_entityCount;

	TrieSetCell(g_entityHandlers, szClassname, index);
	
	ArrayPushString(g_entityName, szClassname);
	ArrayPushCell(g_entityPluginID, pluginID);
	ArrayPushCell(g_entityModelIndex, modelIndex);
	ArrayPushArray(g_entityMins, vMins);
	ArrayPushArray(g_entityMaxs, vMaxs);
	ArrayPushCell(g_entityLifeTime, fLifeTime);
	ArrayPushCell(g_entityRespawnTime, fRespawnTime);
	ArrayPushCell(g_entityIgnoreRounds, ignoreRounds);
	ArrayPushCell(g_entityPreset, preset);
	ArrayPushCell(g_entityHooks, 0);
	
	g_entityCount++;
	
	log_amx("%s Entity %s successfully registred.", LOG_PREFIX, szClassname);
	
	return index;
}

Create(const szClassname[], const Float:vOrigin[3] = {0.0, 0.0, 0.0}, bool:temp = true)
{
	new ceIdx;
	if (!g_entityCount || !TrieGetCell(g_entityHandlers, szClassname, ceIdx)) {
		log_error(0, "%s Entity %s is not registered as custom entity.", LOG_PREFIX, szClassname);
		return -1;
	}
	
	new ent = engfunc(EngFunc_CreateNamedEntity, g_ptrBaseClassname);
	set_pev(ent, pev_classname, szClassname, strlen(szClassname));
	
	engfunc(EngFunc_SetOrigin, ent, vOrigin);
	
	new tmpIdx = -1;
	new worldIdx = -1;
	if (temp) {
		if (!g_tmpEntities) {
			g_tmpEntities = ArrayCreate();
		}	
	
		tmpIdx = ArraySize(g_tmpEntities);
		ArrayPushCell(g_tmpEntities, ent);
	} else {
		if (!g_worldEntities) {
			g_worldEntities = ArrayCreate();
		}
		
		worldIdx = ArraySize(g_worldEntities);
		ArrayPushCell(g_worldEntities, ent);
	}
	
	new Array:ceData = CreatePData(ent);
	
	ArraySetCell(ceData, CEData_Handler, ceIdx);
	ArraySetCell(ceData, CEData_TempIndex, tmpIdx);
	ArraySetCell(ceData, CEData_WorldIndex, worldIdx);
	ArraySetCell(ceData, CEData_StartOrigin, Invalid_Array);
	
	set_pev(ent, pev_deadflag, DEAD_NO);
	
	return ent;
}

Respawn(ent)
{
	remove_task(ent+TASKID_SUM_RESPAWN);

	new Array:ceData = GetPData(ent);
		
	new Array:startOrigin = ArrayGetCell(ceData, CEData_StartOrigin);
	if (startOrigin != Invalid_Array) {
		static Float:vOrigin[3];
		ArrayGetArray(startOrigin, 0, vOrigin);
		engfunc(EngFunc_SetOrigin, ent, vOrigin);
	}

	set_pev(ent, pev_deadflag, DEAD_NO);
	set_pev(ent, pev_effects, pev(ent, pev_effects) & ~EF_NODRAW);
	
	set_pev(ent, pev_flags, pev(ent, pev_flags) & ~FL_ONGROUND);
	dllfunc(DLLFunc_Spawn, ent);
}

Kill(ent, killer = 0, bool:picked = false)
{
	new Array:ceData = GetPData(ent);

	new ceIdx = ArrayGetCell(ceData, CEData_Handler);

	if (ExecuteFunction(CEFunction_Kill, ceIdx, ent, killer, picked) != PLUGIN_CONTINUE) {
		return;
	}

	set_pev(ent, pev_takedamage, DAMAGE_NO);
	set_pev(ent, pev_effects, pev(ent, pev_effects) | EF_NODRAW);
	set_pev(ent, pev_solid, SOLID_NOT);
	set_pev(ent, pev_movetype, MOVETYPE_NONE);
	set_pev(ent, pev_flags, pev(ent, pev_flags) & ~FL_ONGROUND);
	
	//Get temp index
	new tmpIdx = ArrayGetCell(ceData, CEData_TempIndex);
	
	//Check if entity is temp
	if (tmpIdx < 0) {
		new Float:fRespawnTime = ArrayGetCell(g_entityRespawnTime, ceIdx);
		if (fRespawnTime > 0.0) {
			set_pev(ent, pev_deadflag, DEAD_RESPAWNABLE);
			set_task(fRespawnTime, "TaskRespawn", ent+TASKID_SUM_RESPAWN);
		} else {
			set_pev(ent, pev_deadflag, DEAD_DEAD);
		}
	} else {
		set_pev(ent, pev_deadflag, DEAD_DISCARDBODY);
	}

	remove_task(ent+TASKID_SUM_DISAPPEAR);

	ExecuteFunction(CEFunction_Killed, ceIdx, ent, killer, picked);

	if (tmpIdx >= 0) {
		set_task(0.0, "TaskRemove", ent+TASKID_SUM_REMOVE);
	}
}

bool:Remove(ent)
{
	if (!Check(ent)) {
		log_error(0, "%s Entity %i is not a custom entity.", LOG_PREFIX, ent);
		return false;
	}
	
	new Array:ceData = GetPData(ent);
	
	//Get temp index
	new tmpIdx = ArrayGetCell(ceData, CEData_TempIndex);
	
	//Check if entity is temp
	if (tmpIdx >= 0) {
		//Remove entity from storage of temp entities
		ArraySetCell(g_tmpEntities, tmpIdx, 0);
	} else {
		//Get world index
		new worldIdx = ArrayGetCell(ceData, CEData_WorldIndex);
		if (worldIdx >= 0) {
			ArraySetCell(g_worldEntities, worldIdx, 0);	
		}
	}

	ClearTasks(ent);
	
	//Get handler
	new ceIdx = ArrayGetCell(ceData, CEData_Handler);
	
	//Execute remove function
	ExecuteFunction(CEFunction_Remove, ceIdx, ent);
	
	DestroyPData(ent);

	//Remove entity
	set_pev(ent, pev_flags, pev(ent, pev_flags) | FL_KILLME);
	dllfunc(DLLFunc_Think, ent);
	
	return true;
}

Check(ent)
{
	return (pev(ent, pev_gaitsequence) == 'c'+'e');
}

ClearTasks(ent)
{
	remove_task(ent+TASKID_SUM_DISAPPEAR);
	remove_task(ent+TASKID_SUM_RESPAWN);
	remove_task(ent+TASKID_SUM_REMOVE);
}

GetHandlerByEntity(ent)
{
	if (!Check(ent)) {
		return -1;
	}
	
	new Array:ceData = GetPData(ent);
	
	return ArrayGetCell(ceData, CEData_Handler);
}

GetHandler(const szClassname[])
{
	new ceIdx;
	if (!g_entityCount || !TrieGetCell(g_entityHandlers, szClassname, ceIdx)) {
		return -1;
	}

	return ceIdx;
}

Cleanup()
{
	if (!g_tmpEntities) {
		return;
	}

	new size = ArraySize(g_tmpEntities);

	for (new i = size - 1; i >= 0; --i)
	{
		new ent = ArrayGetCell(g_tmpEntities, i);
		
		if (!ent || !pev_valid(ent)) {
			continue;
		}

		new ceIdx = GetHandlerByEntity(ent);
		if (ceIdx == -1) {
			log_error(0, "%s Entity %i is not a custom entity.", LOG_PREFIX, ent);
			continue;
		}

		new ignoreRounds = ArrayGetCell(g_entityIgnoreRounds, ceIdx);
		if (!ignoreRounds) {
			Remove(ent);
			ArrayDeleteItem(g_tmpEntities, i);
		}
	}

	// update temp entities refs
	new newSize = ArraySize(g_tmpEntities);
	for (new i = 0; i < newSize; ++i) {
		new ent = ArrayGetCell(g_tmpEntities, i);
		
		if (!ent || !pev_valid(ent)) {
			continue;
		}

		new Array:ceData = GetPData(ent);
		ArraySetCell(ceData, CEData_TempIndex, i);
	}
}

RespawnEntities()
{
	if (!g_worldEntities) {
		return;
	}
	
	new size = ArraySize(g_worldEntities);
	for (new i = 0; i < size; ++i) {
		new ent = ArrayGetCell(g_worldEntities, i);
		if (ent) {
			Respawn(ent);

			new szModel[64];
			pev(ent, pev_model, szModel, charsmax(szModel));
			if (szModel[0] == '*') {
				engfunc(EngFunc_SetModel, ent, szModel);
			}
		}
	}
}

bool:InitEntity(ent, ceIdx, bool:temp)
{	
	static Float:vMins[3];
	ArrayGetArray(g_entityMins, ceIdx, vMins);
	
	static Float:vMaxs[3];
	ArrayGetArray(g_entityMaxs, ceIdx, vMaxs);
	
	static Float:vOrigin[3];
	pev(ent, pev_origin, vOrigin);
	
	engfunc(EngFunc_SetSize, ent, vMins, vMaxs);
	engfunc(EngFunc_SetOrigin, ent, vOrigin);
	
	{
		new preset = ArrayGetCell(g_entityPreset, ceIdx);
		ApplyPreset(ent, preset);
	}
	
	new modelIndex = ArrayGetCell(g_entityModelIndex, ceIdx);
	if (modelIndex > 0) {
		set_pev(ent, pev_modelindex, modelIndex);
	}

	if (temp) {
		new Float:fLifeTime = ArrayGetCell(g_entityLifeTime, ceIdx);
		if (fLifeTime > 0.0) {
			set_task(fLifeTime, "TaskDisappear", ent+TASKID_SUM_DISAPPEAR);
		}
	}
	
	return true;
}

ApplyPreset(ent, preset)
{
	switch (preset)
	{
		case CEPreset_Item:
		{
			set_pev(ent, pev_solid, SOLID_TRIGGER);
			set_pev(ent, pev_movetype, MOVETYPE_TOSS);
			set_pev(ent, pev_takedamage, DAMAGE_NO);
		}
		case CEPreset_NPC:
		{
			set_pev(ent, pev_solid, SOLID_BBOX);
			set_pev(ent, pev_movetype, MOVETYPE_PUSHSTEP);
			set_pev(ent, pev_takedamage, DAMAGE_AIM);
			
			set_pev(ent, pev_controller_0, 125);
			set_pev(ent, pev_controller_1, 125);
			set_pev(ent, pev_controller_2, 125);
			set_pev(ent, pev_controller_3, 125);
			
			set_pev(ent, pev_gamestate, 1);
			set_pev(ent, pev_gravity, 1.0);
			set_pev(ent, pev_flags, pev(ent, pev_flags) | FL_MONSTER);
			set_pev(ent, pev_fixangle, 1);
			set_pev(ent, pev_friction, 0.25);
		}
		case CEPreset_Prop:
		{
			set_pev(ent, pev_solid, SOLID_BBOX);
			set_pev(ent, pev_movetype, MOVETYPE_FLY);
			set_pev(ent, pev_takedamage, DAMAGE_NO);
		}
	}
}

AddKvd(const szKey[], const szValue[])
{
	if (g_ceKvd == Invalid_Array) {
		g_ceKvd = ArrayCreate(KVD);
	}

	new kvd[KVD];
	copy(kvd[KVD_Key], charsmax(kvd[KVD_Key]), szKey);
	copy(kvd[KVD_Value], charsmax(kvd[KVD_Value]), szValue);
	ArrayPushArray(g_ceKvd, kvd);
}

SpawnLatestCe()
{
	if (!g_lastCEEnt) {
		return;
	}

	if (g_ceKvd != Invalid_Array) {
		new size = ArraySize(g_ceKvd);
		for (new i = 0; i < size; ++i) {
			new kvd[KVD];
			ArrayGetArray(g_ceKvd, i, kvd);
			DispatchKeyValue(g_lastCEEnt, kvd[KVD_Key], kvd[KVD_Value]); // dispatch kvd to cloned entity
			ExecuteFunction(CEFunction_KVD, g_lastCEIdx, g_lastCEEnt, kvd[KVD_Key], kvd[KVD_Value]);
		}
	}

	dllfunc(DLLFunc_Spawn, g_lastCEEnt); // spawn last handled entity

	if (g_ceKvd != Invalid_Array) {
		new size = ArraySize(g_ceKvd);
		for (new i = 0; i < size; ++i) {
			new kvd[KVD];
			ArrayGetArray(g_ceKvd, i, kvd);

			if (equal(kvd[KVD_Key], "model") && kvd[KVD_Value][0] == '*') {
				engfunc(EngFunc_SetModel, g_lastCEEnt, kvd[KVD_Value]);
			}
		}
	}

	g_lastCEEnt = 0;

	if (g_ceKvd != Invalid_Array) {
		ArrayDestroy(g_ceKvd);
		g_ceKvd = Invalid_Array;
	}
}

RegisterHook(CEFunction:function, const szClassname[], const szCallback[], pluginID = -1)
{
	new ceIdx;
	if (!g_entityCount || !TrieGetCell(g_entityHandlers, szClassname, ceIdx)) {
		log_error(0, "%s Entity %s is not registered.", LOG_PREFIX, szClassname);
		return -1;
	}
	
	new funcID = get_func_id(szCallback, pluginID);
	if (funcID < 0) {
		new szFilename[32];
		get_plugin(pluginID, szFilename, charsmax(szFilename));
		log_error(0, "Function %s not found in plugin %s.", szCallback, szFilename);
		return -1;
	}
	
	new Array:functions = ArrayGetCell(g_entityHooks, ceIdx);
	if (!functions) {
		functions = InitializeFunctions(ceIdx);
	}
	
	new Array:functionHooks = ArrayGetCell(functions, _:function);	

	new Array:hookData = CreateHookData(pluginID, funcID);
	return ArrayPushCell(functionHooks, hookData);
}

Array:InitializeFunctions(ceIdx)
{
	new Array:functions = ArrayCreate(1, _:CEFunction);
	
	for (new i = 0; i < _:CEFunction; ++i) {
		new Array:functionHooks = ArrayCreate();
		ArrayPushCell(functions, functionHooks);
	}
	
	ArraySetCell(g_entityHooks, ceIdx, functions);
	
	return functions;
}

DestroyFunctions(ceIdx)
{
	new Array:functions = ArrayGetCell(g_entityHooks, ceIdx);
	
	if (!functions) {
		return;
	}
	
	for (new i = 0; i < _:CEFunction; ++i) {
		new Array:functionHooks = ArrayGetCell(functions, i);
		ArrayDestroy(functionHooks);
	}
	
	ArrayDestroy(functions);
	ArraySetCell(g_entityHooks, ceIdx, 0);
}

Array:CreateHookData(pluginID, funcID)
{
	new Array:hookData = ArrayCreate(1, _:CEHookData);
	ArrayPushCell(hookData, pluginID);
	ArrayPushCell(hookData, funcID);
	
	return hookData;
}

ExecuteFunction(CEFunction:function, ceIdx, any:...)
{
	new result = 0;
	new ent = getarg(2);

	new Array:functions = ArrayGetCell(g_entityHooks, ceIdx);
	if (functions == Invalid_Array) {
		return 0;
	}

	new Array:functionHooks = ArrayGetCell(functions, _:function);
	
	new count = ArraySize(functionHooks);
	for (new i = 0; i < count; ++i)
	{
		new Array:hookData = ArrayGetCell(functionHooks, i);
		new pluginID = ArrayGetCell(hookData, _:CEHookData_PluginID);
		new funcID = ArrayGetCell(hookData, _:CEHookData_FuncID);

		if (funcID < 0) {
			continue;
		}
		
		if (callfunc_begin_i(funcID, pluginID) == 1) 
		{
			callfunc_push_int(ent);

			switch (function)
			{
				case CEFunction_Kill, CEFunction_Killed: {
					new killer = getarg(3);
					new bool:picked = bool:getarg(4);
					callfunc_push_int(killer);
					callfunc_push_int(picked);
				}
				case CEFunction_Pickup, CEFunction_Picked: {
					new id = getarg(3);
					callfunc_push_int(id);
				}
				case CEFunction_KVD: {
					static szKey[32];
					for (new i = 0; i < charsmax(szKey); ++i) {
						szKey[i] = getarg(3, i);						
						
						if (szKey[i]  == '^0') {
							break;
						}
					}
					
					static szValue[32];
					for (new i = 0; i < charsmax(szValue); ++i) {
						szValue[i] = getarg(4, i);						
						
						if (szValue[i]  == '^0') {
							break;
						}
					}
					
					callfunc_push_str(szKey);
					callfunc_push_str(szValue);
				}
			}

			result += callfunc_end();		
		}
	}
	
	return result;
}

Array:CreatePData(ent)
{
	new Array:ceData = ArrayCreate(1, CEData);	
	for (new i = 0; i < CEData; ++i) {
		ArrayPushCell(ceData, 0);
	}
	
	set_pev(ent, pev_gaitsequence, 'c'+'e');
	set_pev(ent, pev_iStepLeft, ceData);	
	
	return ceData;
}

DestroyPData(ent)
{
	//Destroy data array
	new Array:ceData = GetPData(ent);
	{
		new Array:startOrigin = ArrayGetCell(ceData, CEData_StartOrigin);
		if (startOrigin != Invalid_Array) {
			ArrayDestroy(startOrigin);
		}
	} ArrayDestroy(ceData);
	
	set_pev(ent, pev_gaitsequence, 0);
	set_pev(ent, pev_iStepLeft, 0);
}

Array:GetPData(ent)
{
	new Array:ceData = any:pev(ent, pev_iStepLeft);
	if (ceData == Invalid_Array) {
		log_error(0, "%s Invalid Custom Entity data provided for %i.", LOG_PREFIX, ent);
	}
	
	return ceData;
}

/*--------------------------------[ Tasks ]--------------------------------*/

public TaskDisappear(taskID)
{
	new ent = taskID - TASKID_SUM_DISAPPEAR;
	Kill(ent, 0);
}

public TaskRespawn(taskID)
{
	new ent = taskID - TASKID_SUM_RESPAWN;
	Respawn(ent);
}

public TaskRemove(taskID)
{
	new ent = taskID - TASKID_SUM_REMOVE;
	Remove(ent);
}

public TaskRespawnEntities()
{
	RespawnEntities();
}
