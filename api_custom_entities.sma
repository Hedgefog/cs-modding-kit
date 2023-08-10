#pragma semicolon 1

#include <amxmodx>
#include <amxmisc>
#include <engine>
#include <fakemeta>
#include <hamsandwich>
#include <xs>

#include <api_custom_entities>

#define LOG_PREFIX "[CE]"

enum CEData {
  Array:CEData_Name,
  Array:CEData_ModelIndex,
  Array:CEData_Mins,
  Array:CEData_Maxs,
  Array:CEData_LifeTime,
  Array:CEData_RespawnTime,
  Array:CEData_Preset,
  Array:CEData_IgnoreRounds,
  Array:CEData_BloodColor,
  Array:CEData_Hooks[CEFunction]
};

enum CEHookData {
  CEHookData_PluginID,
  CEHookData_FuncID
};

enum _:RegisterArgs {
  RegisterArg_Name = 1,
  RegisterArg_ModelIndex,
  RegisterArg_Mins,
  RegisterArg_Maxs,
  RegisterArg_LifeTime,
  RegisterArg_RespawnTime,
  RegisterArg_IgnoreRounds,
  RegisterArg_Preset,
  RegisterArg_BloodColor
};

new g_iszBaseClassName;

new Trie:g_itPData = Invalid_Trie;
new Trie:g_itEntityIds = Invalid_Trie;
new g_rgCEData[CEData] = { Invalid_Array, ... };
new g_iEntitiesNum = 0;

public plugin_precache() {
  InitStorages();
  g_iszBaseClassName = engfunc(EngFunc_AllocString, CE_BASE_CLASSNAME);

  register_forward(FM_Spawn, "FMHook_Spawn");
  register_forward(FM_KeyValue, "FMHook_KeyValue");
  register_forward(FM_OnFreeEntPrivateData, "FMHook_OnFreeEntPrivateData");

  RegisterHam(Ham_Spawn, CE_BASE_CLASSNAME, "HamHook_Base_Spawn_Post", .Post = 1);
  RegisterHam(Ham_ObjectCaps, CE_BASE_CLASSNAME, "HamHook_Base_ObjectCaps", .Post = 0);
  RegisterHam(Ham_CS_Restart, CE_BASE_CLASSNAME, "HamHook_Base_Restart", .Post = 1);
  RegisterHam(Ham_Touch, CE_BASE_CLASSNAME, "HamHook_Base_Touch", .Post = 0);
  RegisterHam(Ham_Killed, CE_BASE_CLASSNAME, "HamHook_Base_Killed", .Post = 0);
  RegisterHam(Ham_Think, CE_BASE_CLASSNAME, "HamHook_Base_Think", .Post = 0);
  RegisterHam(Ham_BloodColor, CE_BASE_CLASSNAME, "HamHook_Base_BloodColor", .Post = 0);
}

public plugin_init() {
  register_plugin("[API] Custom Entities", "2.0.0", "Hedgehog Fog");

  register_concmd("ce_spawn", "Command_Spawn", ADMIN_CVAR);
}

public plugin_natives() {
  register_library("api_custom_entities");

  register_native("CE_Register", "Native_Register");  
  register_native("CE_Create", "Native_Create");
  register_native("CE_Kill", "Native_Kill");
  register_native("CE_Remove", "Native_Remove");

  register_native("CE_GetSize", "Native_GetSize");
  register_native("CE_GetModelIndex", "Native_GetModelIndex");

  register_native("CE_RegisterHook", "Native_RegisterHook");

  register_native("CE_GetHandler", "Native_GetHandler");
  register_native("CE_GetHandlerByEntity", "Native_GetHandlerByEntity");

  register_native("CE_HasMember", "Native_HasMember");
  register_native("CE_GetMember", "Native_GetMember");
  register_native("CE_DeleteMember", "Native_DeleteMember");
  register_native("CE_SetMember", "Native_SetMember");
  register_native("CE_GetMemberVec", "Native_GetMemberVec");
  register_native("CE_SetMemberVec", "Native_SetMemberVec");
  register_native("CE_GetMemberString", "Native_GetMemberString");
  register_native("CE_SetMemberString", "Native_SetMemberString");
}

public plugin_end() {
  DestroyStorages();
}

/*--------------------------------[ Natives ]--------------------------------*/

public Native_Register(iPluginId, iArgc) {
  static szClassName[CE_MAX_NAME_LENGTH];
  get_string(RegisterArg_Name, szClassName, charsmax(szClassName));
  
  new iModelIndex = get_param(RegisterArg_ModelIndex);
  new Float:flLifeTime = get_param_f(RegisterArg_LifeTime);
  new Float:flRespawnTime = get_param_f(RegisterArg_RespawnTime);
  new bool:bIgnoreRounds = bool:get_param(RegisterArg_IgnoreRounds);
  new CEPreset:iPreset = CEPreset:get_param(RegisterArg_Preset);
  new iBloodColor = get_param(RegisterArg_BloodColor);
  
  new Float:vecMins[3];
  get_array_f(RegisterArg_Mins, vecMins, 3);
  
  new Float:vecMaxs[3];
  get_array_f(RegisterArg_Maxs, vecMaxs, 3);
  
  return RegisterEntity(szClassName, iModelIndex, vecMins, vecMaxs, flLifeTime, flRespawnTime, bIgnoreRounds, iPreset, iBloodColor);
}

public Native_Create(iPluginId, iArgc) {
  new szClassName[CE_MAX_NAME_LENGTH];
  get_string(1, szClassName, charsmax(szClassName));
  
  new Float:vecOrigin[3];
  get_array_f(2, vecOrigin, 3);
  
  new bool:bTemp = !!get_param(3);
  
  return @Entity_Create(szClassName, vecOrigin, bTemp);
}

public Native_Kill(iPluginId, iArgc) {
  new pEntity = get_param(1);
  new pKiller = get_param(2);

  // ExecuteHamB(Ham_Killed, pEntity, pKiller, 0);
  @Entity_Kill(pEntity, pKiller, false);
}

public bool:Native_Remove(iPluginId, iArgc) {
  new pEntity = get_param(1);
  set_pev(pEntity, pev_flags, pev(pEntity, pev_flags) | FL_KILLME);
  dllfunc(DLLFunc_Think, pEntity);
}

public Native_GetSize(iPluginId, iArgc) {
  new szClassName[CE_MAX_NAME_LENGTH];
  get_string(1, szClassName, charsmax(szClassName));
  
  new iId = GetIdByClassName(szClassName);
  if (iId == -1) {
    return false;
  }
  
  new Float:vecMins[3];
  ArrayGetArray(g_rgCEData[CEData_Mins], iId, vecMins);

  new Float:vecMaxs[3];
  ArrayGetArray(g_rgCEData[CEData_Maxs], iId, vecMaxs);
  
  set_array_f(2, vecMins, 3);
  set_array_f(3, vecMaxs, 3);

  return true;
}

public Native_GetModelIndex(iPluginId, iArgc) {  
  new szClassName[CE_MAX_NAME_LENGTH];
  get_string(1, szClassName, charsmax(szClassName));
  
  new iId = GetIdByClassName(szClassName);
  if (iId == -1) {
    return 0;
  }
  
  return ArrayGetCell(g_rgCEData[CEData_ModelIndex], iId);
}

public Native_RegisterHook(iPluginId, iArgc) {
  new CEFunction:iFunction = CEFunction:get_param(1);
  
  new szClassname[CE_MAX_NAME_LENGTH];
  get_string(2, szClassname, charsmax(szClassname));
  
  new szCallback[CE_MAX_CALLBACK_LENGTH];
  get_string(3, szCallback, charsmax(szCallback));

  RegisterEntityHook(iFunction, szClassname, szCallback, iPluginId);
}

public Native_GetHandler(iPluginId, iArgc) {
  new szClassName[CE_MAX_NAME_LENGTH];
  get_string(1, szClassName, charsmax(szClassName));
  
  return GetIdByClassName(szClassName);
}

public Native_GetHandlerByEntity(iPluginId, iArgc) {
  new pEntity = get_param(1);

  if (!@Entity_IsCustom(pEntity)) {
    return -1;
  }

  new Trie:itPData = @Entity_GetPData(pEntity);
  return GetPDataMember(itPData, CE_MEMBER_ID);
}

public bool:Native_HasMember(iPluginId, iArgc) {
  new pEntity = get_param(1);

  static szMember[CE_MAX_MEMBER_LENGTH];
  get_string(2, szMember, charsmax(szMember));

  new Trie:itPData = @Entity_GetPData(pEntity);

  return HasPDataMember(itPData, szMember);
}

public any:Native_GetMember(iPluginId, iArgc) {
  new pEntity = get_param(1);

  static szMember[CE_MAX_MEMBER_LENGTH];
  get_string(2, szMember, charsmax(szMember));

  new Trie:itPData = @Entity_GetPData(pEntity);

  return GetPDataMember(itPData, szMember);
}

public Native_DeleteMember(iPluginId, iArgc) {
  new pEntity = get_param(1);

  static szMember[CE_MAX_MEMBER_LENGTH];
  get_string(2, szMember, charsmax(szMember));

  new Trie:itPData = @Entity_GetPData(pEntity);

  DeletePDataMember(itPData, szMember);
}

public Native_SetMember(iPluginId, iArgc) {
  new pEntity = get_param(1);

  static szMember[CE_MAX_MEMBER_LENGTH];
  get_string(2, szMember, charsmax(szMember));

  new iValue = get_param(3);

  new Trie:itPData = @Entity_GetPData(pEntity);

  SetPDataMember(itPData, szMember, iValue);
}

public bool:Native_GetMemberVec(iPluginId, iArgc) {
  new pEntity = get_param(1);

  static szMember[CE_MAX_MEMBER_LENGTH];
  get_string(2, szMember, charsmax(szMember));

  new Trie:itPData = @Entity_GetPData(pEntity);

  static Float:vecValue[3];
  if (!GetPDataMemberVec(itPData, szMember, vecValue)) {
    return false;
  }

  set_array_f(3, vecValue, sizeof(vecValue));
  return true;
}

public Native_SetMemberVec(iPluginId, iArgc) {
  new pEntity = get_param(1);

  static szMember[CE_MAX_MEMBER_LENGTH];
  get_string(2, szMember, charsmax(szMember));

  static Float:vecValue[3];
  get_array_f(3, vecValue, sizeof(vecValue));

  new Trie:itPData = @Entity_GetPData(pEntity);
  SetPDataMemberVec(itPData, szMember, vecValue);
}

public bool:Native_GetMemberString(iPluginId, iArgc) {
  new pEntity = get_param(1);

  static szMember[CE_MAX_MEMBER_LENGTH];
  get_string(2, szMember, charsmax(szMember));

  static szValue[128];
  get_string(3, szValue, charsmax(szValue));

  new Trie:itPData = @Entity_GetPData(pEntity);
  if (!GetPDataMemberString(itPData, szMember, szValue, charsmax(szValue))) {
    return false;
  }

  set_string(4, szValue, get_param(5));

  return true;
}

public Native_SetMemberString(iPluginId, iArgc) {
  new pEntity = get_param(1);

  static szMember[CE_MAX_MEMBER_LENGTH];
  get_string(2, szMember, charsmax(szMember));

  static szValue[128];
  get_string(3, szValue, charsmax(szValue));

  new Trie:itPData = @Entity_GetPData(pEntity);
  SetPDataMemberString(itPData, szMember, szValue);
}

/*--------------------------------[ Commands ]--------------------------------*/

public Command_Spawn(pPlayer, iLevel, iCId) {
  if (!cmd_access(pPlayer, iLevel, iCId, 2)) {
    return PLUGIN_HANDLED;
  }

  static szClassName[128];
  read_args(szClassName, charsmax(szClassName));
  remove_quotes(szClassName);

  if (equal(szClassName, NULL_STRING)) {
    return PLUGIN_HANDLED;
  }

  static Float:vecOrigin[3];
  pev(pPlayer, pev_origin, vecOrigin);
  
  new pEntity = @Entity_Create(szClassName, vecOrigin, true);
  if (pEntity) {
    dllfunc(DLLFunc_Spawn, pEntity);
    engfunc(EngFunc_SetOrigin, pEntity, vecOrigin);
  }

  return PLUGIN_HANDLED;
}

/*--------------------------------[ Hooks ]--------------------------------*/

public FMHook_OnFreeEntPrivateData(pEntity) {
  if (!pev_valid(pEntity)) {
    return;
  }

  if (@Entity_IsCustom(pEntity)) {
    @Entity_FreePData(pEntity);
  }
}

public FMHook_KeyValue(pEntity, hKVD) {
  new szKey[32];
  get_kvd(hKVD, KV_KeyName, szKey, charsmax(szKey));

  new szValue[32];
  get_kvd(hKVD, KV_Value, szValue, charsmax(szValue));

  if (equal(szKey, "classname")) {
    new iId = GetIdByClassName(szValue);

    if (iId != -1) {
      // using set_kvd leads to duplicate kvd emit, this check will fix the issue
      if (g_itPData == Invalid_Trie) {
        set_kvd(hKVD, KV_Value, CE_BASE_CLASSNAME);
        g_itPData = AllocPData(iId, pEntity);
      }
    } else {
        // if for some reason data was not assigned
        if (g_itPData != Invalid_Trie) {
          FreePData(g_itPData);
          g_itPData = Invalid_Trie;
        }
    }
  }

  if (g_itPData != Invalid_Trie) {
    if (equal(szKey, "classname")) {
      SetPDataMember(g_itPData, CE_MEMBER_WORLD, true);
    } else if (equal(szKey, "origin")) {
      new Float:vecOrigin[3];
      UTIL_ParseVector(szValue, vecOrigin);
      SetPDataMemberVec(g_itPData, CE_MEMBER_ORIGIN, vecOrigin);
    } else if (equal(szKey, "angles")) {
      new Float:vecAngles[3];
      UTIL_ParseVector(szValue, vecAngles);
      SetPDataMemberVec(g_itPData, CE_MEMBER_ANGLES, vecAngles);
    } else if (equal(szKey, "master")) {
      SetPDataMemberString(g_itPData, CE_MEMBER_MASTER, szValue);
    }

    new iId = GetPDataMember(g_itPData, CE_MEMBER_ID);
    ExecuteHookFunction(CEFunction_KVD, iId, pEntity, szKey, szValue);
  }

  return FMRES_HANDLED;
}

public FMHook_Spawn(pEntity) {
  if (g_itPData != Invalid_Trie) {
    new iId = GetPDataMember(g_itPData, CE_MEMBER_ID);

    static szClassName[CE_MAX_NAME_LENGTH];
    ArrayGetString(g_rgCEData[CEData_Name], iId, szClassName, charsmax(szClassName));
    set_pev(pEntity, pev_classname, szClassName);

    @Entity_SetPData(pEntity, g_itPData);
    g_itPData = Invalid_Trie;
  }
}

public HamHook_Base_Spawn_Post(pEntity) {
  if (@Entity_IsCustom(pEntity)) {
    @Entity_Spawn(pEntity);
  }
}

public HamHook_Base_ObjectCaps(pEntity) {
  if (@Entity_IsCustom(pEntity)) {
    new iObjectCaps = @Entity_GetObjectCaps(pEntity);
    SetHamReturnInteger(iObjectCaps);
    return HAM_OVERRIDE;
  }

  return HAM_IGNORED;
}

public HamHook_Base_Restart(pEntity) {
  if (@Entity_IsCustom(pEntity)) {
    @Entity_Restart(pEntity);
    return HAM_HANDLED;
  }

  return HAM_IGNORED;
}

public HamHook_Base_Touch(pEntity, pToucher) {
  if (@Entity_IsCustom(pEntity)) {
    @Entity_Touch(pEntity, pToucher);
    return HAM_HANDLED;
  }

  return HAM_IGNORED;
}

public HamHook_Base_Killed(pEntity, pKiller) {
  if (@Entity_IsCustom(pEntity)) {
    @Entity_Kill(pEntity, pKiller, false);
    return HAM_SUPERCEDE;
  }

  return HAM_IGNORED;
}

public HamHook_Base_Think(pEntity, pKiller) {
  if (@Entity_IsCustom(pEntity)) {
    @Entity_Think(pEntity);
    return HAM_HANDLED;
  }

  return HAM_IGNORED;
}

public HamHook_Base_BloodColor(pEntity) {
  if (@Entity_IsCustom(pEntity)) {
    new iBloodColor = @Entity_BloodColor(pEntity);
    if (iBloodColor < 0) {
      return HAM_HANDLED;
    }

    SetHamReturnInteger(iBloodColor);
    return HAM_OVERRIDE;
  }

  return HAM_IGNORED;
}

/*--------------------------------[ Methods ]--------------------------------*/

bool:@Entity_IsCustom(this) {
  return pev(this, pev_gaitsequence) == CE_ENTITY_SECRET;
}

@Entity_Create(const szClassName[], const Float:vecOrigin[3], bool:bTemp) {
  new iId = GetIdByClassName(szClassName);
  if (iId == -1) {
    return 0;
  }

  new this = engfunc(EngFunc_CreateNamedEntity, g_iszBaseClassName);
  set_pev(this, pev_classname, szClassName);
  engfunc(EngFunc_SetOrigin, this, vecOrigin);
  // set_pev(this, pev_flags, pev(this, pev_flags) & ~FL_ONGROUND);

  new Trie:itPData = @Entity_AllocPData(this, iId);
  SetPDataMemberVec(itPData, CE_MEMBER_ORIGIN, vecOrigin);

  SetPDataMember(itPData, CE_MEMBER_WORLD, !bTemp);

  return this;
}

@Entity_Init(this) {
  new Trie:itPData = @Entity_GetPData(this);
  new iId = GetPDataMember(itPData, CE_MEMBER_ID);
  ExecuteHookFunction(CEFunction_Init, iId, this);
  SetPDataMember(itPData, CE_MEMBER_INITIALIZED, true);
}

@Entity_Spawn(this) {
  new Float:flGameTime = get_gametime();

  new Trie:itPData = @Entity_GetPData(this);

  if (!GetPDataMember(itPData, CE_MEMBER_INITIALIZED)) {
    @Entity_Init(this);
  }

  if (!pev_valid(this) || pev(this, pev_flags) & FL_KILLME) {
    return;
  }

  new iId = GetPDataMember(itPData, CE_MEMBER_ID);
  new bool:bIsWorld = GetPDataMember(itPData, CE_MEMBER_WORLD);

  new Float:flLifeTime = bIsWorld ? 0.0 : ArrayGetCell(g_rgCEData[CEData_LifeTime], iId);
  if (flLifeTime > 0.0) {
    SetPDataMember(itPData, CE_MEMBER_NEXTKILL, flGameTime + flLifeTime);
    set_pev(this, pev_nextthink, flGameTime + flLifeTime);
  } else {
    SetPDataMember(itPData, CE_MEMBER_NEXTKILL, 0.0);
  }

  set_pev(this, pev_deadflag, DEAD_NO);

  set_pev(this, pev_effects, pev(this, pev_effects) & ~EF_NODRAW);
  set_pev(this, pev_flags, pev(this, pev_flags) & ~FL_ONGROUND);

  static Float:vecMins[3];
  ArrayGetArray(g_rgCEData[CEData_Mins], iId, vecMins);

  static Float:vecMaxs[3];
  ArrayGetArray(g_rgCEData[CEData_Maxs], iId, vecMaxs);

  engfunc(EngFunc_SetSize, this, vecMins, vecMaxs);

  if (HasPDataMember(itPData, CE_MEMBER_ORIGIN)) {
    static Float:vecOrigin[3];
    GetPDataMemberVec(itPData, CE_MEMBER_ORIGIN, vecOrigin);
    engfunc(EngFunc_SetOrigin, this, vecOrigin);
  }

  if (HasPDataMember(itPData, CE_MEMBER_ANGLES)) {
    static Float:vecAngles[3];
    GetPDataMemberVec(itPData, CE_MEMBER_ANGLES, vecAngles);
    set_pev(this, pev_angles, vecAngles);
  }

  new CEPreset:iPreset = ArrayGetCell(g_rgCEData[CEData_Preset], iId);
  @Entity_ApplyPreset(this, iPreset);

  new iModelIndex = ArrayGetCell(g_rgCEData[CEData_ModelIndex], iId);
  if (iModelIndex > 0) {
    set_pev(this, pev_modelindex, iModelIndex);
  }

  @Entity_UpdateModel(this);

  ExecuteHookFunction(CEFunction_Spawn, iId, this);
}

@Entity_Restart(this) {
  new Trie:itPData = @Entity_GetPData(this);
  new iId = GetPDataMember(itPData, CE_MEMBER_ID);
  
  ExecuteHookFunction(CEFunction_Restart, iId, this);

  new iObjectCaps = ExecuteHamB(Ham_ObjectCaps, this);

  if (~iObjectCaps & FCAP_ACROSS_TRANSITION) {
    dllfunc(DLLFunc_Spawn, this);
  }
}

@Entity_UpdateModel(this) {
  static szModel[MAX_RESOURCE_PATH_LENGTH];
  pev(this, pev_model, szModel, charsmax(szModel));
  if (!equal(szModel, NULL_STRING)) {
    engfunc(EngFunc_SetModel, this, szModel);
  }
}

@Entity_Kill(this, pKiller, bool:bPicked) {
  new Trie:itPData = @Entity_GetPData(this);
  new iId = GetPDataMember(itPData, CE_MEMBER_ID);

  if (ExecuteHookFunction(CEFunction_Kill, iId, this, pKiller, bPicked) != PLUGIN_CONTINUE) {
    return;
  }

  SetPDataMember(itPData, CE_MEMBER_NEXTKILL, 0.0);

  set_pev(this, pev_takedamage, DAMAGE_NO);
  set_pev(this, pev_effects, pev(this, pev_effects) | EF_NODRAW);
  set_pev(this, pev_solid, SOLID_NOT);
  set_pev(this, pev_movetype, MOVETYPE_NONE);
  set_pev(this, pev_flags, pev(this, pev_flags) & ~FL_ONGROUND);

  new bool:bIsWorld = GetPDataMember(itPData, CE_MEMBER_WORLD);

  if (bIsWorld) {
    new Float:flRespawnTime = ArrayGetCell(g_rgCEData[CEData_RespawnTime], iId);
    new Float:flGameTime = get_gametime();

    if (flRespawnTime > 0.0) {
      SetPDataMember(itPData, CE_MEMBER_NEXTRESPAWN, flGameTime + flRespawnTime);
      set_pev(this, pev_deadflag, DEAD_RESPAWNABLE);
      set_pev(this, pev_nextthink, flGameTime + flRespawnTime);
    } else {
      set_pev(this, pev_deadflag, DEAD_DEAD);
    }
  } else {
    set_pev(this, pev_deadflag, DEAD_DISCARDBODY);
    set_pev(this, pev_flags, pev(this, pev_flags) | FL_KILLME);
  }

  ExecuteHookFunction(CEFunction_Killed, iId, this, pKiller, bPicked);
}

@Entity_Think(this) {
  if (pev(this, pev_flags) & FL_KILLME) {
    return;
  }

  new Float:flGameTime = get_gametime();

  new Trie:itPData = @Entity_GetPData(this);
  new iId = GetPDataMember(itPData, CE_MEMBER_ID);

  ExecuteHookFunction(CEFunction_Think, iId, this);

  new iDeadFlag = pev(this, pev_deadflag);
  switch (iDeadFlag) {
    case DEAD_NO: {
      new Float:flNextKill = GetPDataMember(itPData, CE_MEMBER_NEXTKILL);
      if (flNextKill > 0.0 && flNextKill <= flGameTime) {
        ExecuteHamB(Ham_Killed, this, 0, 0);
      }
    }
    case DEAD_RESPAWNABLE: {
      new Float:flNextRespawn = GetPDataMember(itPData, CE_MEMBER_NEXTRESPAWN);
      if (flNextRespawn <= flGameTime) {
        dllfunc(DLLFunc_Spawn, this);
      }
    }
  }
}

@Entity_Touch(this, pToucher) {
  new Trie:itPData = @Entity_GetPData(this);
  new iId = GetPDataMember(itPData, CE_MEMBER_ID);

  if (ExecuteHookFunction(CEFunction_Touch, iId, this, pToucher)) {
    return;
  }

  new CEPreset:iPreset = ArrayGetCell(g_rgCEData[CEData_Preset], iId);

  switch (iPreset) {
    case CEPreset_Item: {
      if (is_user_alive(pToucher)) {
        @Entity_Pickup(this, pToucher);
      }
    }
    case CEPreset_Trigger: {
      @Entity_Trigger(this, pToucher);
    }
  }
}

@Entity_GetObjectCaps(this) {
    new Trie:itPData = @Entity_GetPData(this);
    new iId = GetPDataMember(itPData, CE_MEMBER_ID);
    new bool:bIgnoreRound = ArrayGetCell(g_rgCEData[CEData_IgnoreRounds], iId);
    new bool:bIsWorld = GetPDataMember(itPData, CE_MEMBER_WORLD);

    new iObjectCaps = 0;

    if (bIgnoreRound) {
        iObjectCaps |= FCAP_ACROSS_TRANSITION;
    } else {
      if (bIsWorld) {
          iObjectCaps |= FCAP_MUST_RESET;
      } else {
          iObjectCaps |= FCAP_MUST_RELEASE;
      }
    }

    return iObjectCaps;
}

@Entity_Pickup(this, pToucher) {
  if (~pev(this, pev_flags) & FL_ONGROUND) {
    return;
  }

  new Trie:itPData = @Entity_GetPData(this);
  new iId = GetPDataMember(itPData, CE_MEMBER_ID);

  if (ExecuteHookFunction(CEFunction_Pickup, iId, this, pToucher)) {
    ExecuteHookFunction(CEFunction_Picked, iId, this, pToucher);
    @Entity_Kill(this, pToucher, true);
  }
}

bool:@Entity_CanActivate(this, pTarget) {
  static Float:flNextThink;
  pev(this, pev_nextthink, flNextThink);

  if (flNextThink > get_gametime()) {
    return false;
  }

  new Trie:itPData = @Entity_GetPData(this);
  new iId = GetPDataMember(itPData, CE_MEMBER_ID);

  if (!ExecuteHookFunction(CEFunction_Activate, iId, this, pTarget)) {
    return false;
  }

  static szMaster[32];
  copy(szMaster, charsmax(szMaster), NULL_STRING);
  GetPDataMemberString(@Entity_GetPData(this), CE_MEMBER_MASTER, szMaster, charsmax(szMaster));

  return UTIL_IsMasterTriggered(szMaster, pTarget);
}

@Entity_Trigger(this, pActivator) {
  if (!@Entity_CanActivate(this, pActivator)) {
    return;
  }

  new Trie:itPData = @Entity_GetPData(this);
  new iId = GetPDataMember(itPData, CE_MEMBER_ID);
  new Float:flDelay = GetPDataMember(itPData, CE_MEMBER_DELAY);

  set_pev(this, pev_nextthink, get_gametime() + flDelay);
  ExecuteHookFunction(CEFunction_Activated, iId, this, pActivator);
}

@Entity_ApplyPreset(this, CEPreset:iPreset) {
  new Trie:itPData = @Entity_GetPData(this);

  switch (iPreset) {
    case CEPreset_Item: {
      set_pev(this, pev_solid, SOLID_TRIGGER);
      set_pev(this, pev_movetype, MOVETYPE_TOSS);
      set_pev(this, pev_takedamage, DAMAGE_NO);
    }
    case CEPreset_NPC: {
      set_pev(this, pev_solid, SOLID_BBOX);
      set_pev(this, pev_movetype, MOVETYPE_PUSHSTEP);
      set_pev(this, pev_takedamage, DAMAGE_AIM);
      
      set_pev(this, pev_controller_0, 125);
      set_pev(this, pev_controller_1, 125);
      set_pev(this, pev_controller_2, 125);
      set_pev(this, pev_controller_3, 125);
      
      set_pev(this, pev_gamestate, 1);
      set_pev(this, pev_gravity, 1.0);
      set_pev(this, pev_flags, pev(this, pev_flags) | FL_MONSTER);
      set_pev(this, pev_fixangle, 1);
      set_pev(this, pev_friction, 0.25);
    }
    case CEPreset_Prop: {
      set_pev(this, pev_solid, SOLID_BBOX);
      set_pev(this, pev_movetype, MOVETYPE_FLY);
      set_pev(this, pev_takedamage, DAMAGE_NO);
    }
    case CEPreset_Trigger: {
      set_pev(this, pev_solid, SOLID_TRIGGER);
      set_pev(this, pev_movetype, MOVETYPE_NONE);
      set_pev(this, pev_effects, EF_NODRAW);
      SetPDataMember(itPData, CE_MEMBER_DELAY, 0.1);
    }
    case CEPreset_BSP: {
      set_pev(this, pev_movetype, MOVETYPE_PUSH);
      set_pev(this, pev_solid, SOLID_BSP);
      set_pev(this, pev_flags, pev(this, pev_flags) | FL_WORLDBRUSH);
    }
  }
}

@Entity_BloodColor(this) {
  new Trie:itPData = @Entity_GetPData(this);
  new iId = GetPDataMember(itPData, CE_MEMBER_ID);
  return ArrayGetCell(g_rgCEData[CEData_BloodColor], iId);
}

Trie:@Entity_GetPData(this) {
  // Return the current allocated data if the entity is at the initialization stage
  if (g_itPData != Invalid_Trie && GetPDataMember(g_itPData, CE_MEMBER_POINTER) == this) {
    return g_itPData;
  }

  return Trie:pev(this, pev_iStepLeft);
}

@Entity_SetPData(this, Trie:itPData) {
  set_pev(this, pev_gaitsequence, CE_ENTITY_SECRET);
  set_pev(this, pev_iStepLeft, itPData);
}

Trie:@Entity_AllocPData(this, iId) {
  new Trie:itPData = AllocPData(iId, this);
  @Entity_SetPData(this, itPData);
  return itPData;
}

@Entity_FreePData(this) {
  new Trie:itPData = @Entity_GetPData(this);
  
  new iId = GetPDataMember(itPData, CE_MEMBER_ID);
  ExecuteHookFunction(CEFunction_Remove, iId, this);

  FreePData(itPData);

  set_pev(this, pev_gaitsequence, 0);
  set_pev(this, pev_iStepLeft, 0);
}

/*--------------------------------[ Functions ]--------------------------------*/

InitStorages() {
  g_itEntityIds = TrieCreate();
  g_rgCEData[CEData_Name] = ArrayCreate(CE_MAX_NAME_LENGTH);
  g_rgCEData[CEData_ModelIndex] = ArrayCreate();
  g_rgCEData[CEData_Mins] = ArrayCreate(3);
  g_rgCEData[CEData_Maxs] = ArrayCreate(3);
  g_rgCEData[CEData_LifeTime] = ArrayCreate();
  g_rgCEData[CEData_RespawnTime] = ArrayCreate();
  g_rgCEData[CEData_Preset] = ArrayCreate();
  g_rgCEData[CEData_IgnoreRounds] = ArrayCreate();
  g_rgCEData[CEData_BloodColor] = ArrayCreate();

  for (new CEFunction:iFunction = CEFunction:0; iFunction < CEFunction; ++iFunction) {
    g_rgCEData[CEData_Hooks][iFunction] = ArrayCreate();
  }
}

DestroyStorages() {
  for (new iId = 0; iId < g_iEntitiesNum; ++iId) {
    FreeRegisteredEntityData(iId);
  }

  for (new CEFunction:iFunction = CEFunction:0; iFunction < CEFunction; ++iFunction) {
    ArrayDestroy(g_rgCEData[CEData_Hooks][iFunction]);
  }

  for (new CEData:iData = CEData:0; iData < CEData; ++iData) {
    ArrayDestroy(Array:g_rgCEData[iData]);
  }

  TrieDestroy(g_itEntityIds);
}

RegisterEntity(
  const szClassName[],
  iModelIndex,
  const Float:vecMins[3],
  const Float:vecMaxs[3],
  Float:flLifeTime,
  Float:flRespawnTime,
  bool:bIgnoreRounds,
  CEPreset:iPreset,
  iBloodColor
) {
  new iId = g_iEntitiesNum;

  TrieSetCell(g_itEntityIds, szClassName, iId);
  ArrayPushString(g_rgCEData[CEData_Name], szClassName);
  ArrayPushCell(g_rgCEData[CEData_ModelIndex], iModelIndex);
  ArrayPushArray(g_rgCEData[CEData_Mins], vecMins);
  ArrayPushArray(g_rgCEData[CEData_Maxs], vecMaxs);
  ArrayPushCell(g_rgCEData[CEData_LifeTime], flLifeTime);
  ArrayPushCell(g_rgCEData[CEData_RespawnTime], flRespawnTime);
  ArrayPushCell(g_rgCEData[CEData_Preset], iPreset);
  ArrayPushCell(g_rgCEData[CEData_IgnoreRounds], bIgnoreRounds);
  ArrayPushCell(g_rgCEData[CEData_BloodColor], iBloodColor);

  for (new CEFunction:iFunction = CEFunction:0; iFunction < CEFunction; ++iFunction) {
    ArrayPushCell(g_rgCEData[CEData_Hooks][iFunction], ArrayCreate(_:CEHookData));
  }

  g_iEntitiesNum++;

  log_amx("%s Entity %s successfully registred.", LOG_PREFIX, szClassName);

  return iId;
}

FreeRegisteredEntityData(iId) {
  for (new CEFunction:iFunction = CEFunction:0; iFunction < CEFunction; ++iFunction) {
    new Array:irgHooks = ArrayGetCell(g_rgCEData[CEData_Hooks][iFunction], iId);
    ArrayDestroy(irgHooks);
    ArraySetCell(g_rgCEData[CEData_Hooks][iFunction], iId, Invalid_Array);
  }
}

GetIdByClassName(const szClassName[]) {
  new iId = -1;
  TrieGetCell(g_itEntityIds, szClassName, iId);
  return iId;
}

RegisterEntityHook(CEFunction:iFunction, const szClassName[], const szCallback[], iPluginId = -1) {
  new iId = GetIdByClassName(szClassName);
  if (iId == -1) {
    log_error(AMX_ERR_NATIVE, "%s Entity %s is not registered.", LOG_PREFIX, szClassName);
    return -1;
  }

  new iFunctionId = get_func_id(szCallback, iPluginId);
  if (iFunctionId < 0) {
    new szFilename[32];
    get_plugin(iPluginId, szFilename, charsmax(szFilename));
    log_error(AMX_ERR_NATIVE, "%s Function %s not found in plugin %s.", LOG_PREFIX, szCallback, szFilename);
    return -1;
  }

  new rgHook[CEHookData];
  rgHook[CEHookData_PluginID] = iPluginId;
  rgHook[CEHookData_FuncID] = iFunctionId;

  new Array:irgHooks = ArrayGetCell(g_rgCEData[CEData_Hooks][iFunction], iId);
  new iHookId = ArrayPushArray(irgHooks, rgHook[CEHookData:0], _:CEHookData);

  return iHookId;
}

Trie:AllocPData(iId, pEntity) {
  new Trie:itPData = TrieCreate();
  SetPDataMember(itPData, CE_MEMBER_ID, iId);
  SetPDataMember(itPData, CE_MEMBER_WORLD, false);
  SetPDataMember(itPData, CE_MEMBER_POINTER, pEntity);
  SetPDataMember(itPData, CE_MEMBER_INITIALIZED, false);
  return itPData;
}

FreePData(Trie:itPData) {
  TrieDestroy(itPData);
}

bool:HasPDataMember(Trie:itPData, const szMember[]) {
  return TrieKeyExists(itPData, szMember);
}

any:GetPDataMember(Trie:itPData, const szMember[]) {
  static any:value;
  return TrieGetCell(itPData, szMember, value) ? value : 0;
}

DeletePDataMember(Trie:itPData, const szMember[]) {
  TrieDeleteKey(itPData, szMember);
}

SetPDataMember(Trie:itPData, const szMember[], any:value) {
  TrieSetCell(itPData, szMember, value);
}

bool:GetPDataMemberString(Trie:itPData, const szMember[], szOutput[], iLen) {
  copy(szOutput, iLen, NULL_STRING);
  return !!TrieGetString(itPData, szMember, szOutput, iLen);
}

SetPDataMemberString(Trie:itPData, const szMember[], const szValue[]) {
  TrieSetString(itPData, szMember, szValue);
}

bool:GetPDataMemberVec(Trie:itPData, const szMember[], Float:vecOut[3]) {
  xs_vec_copy(Float:{0.0, 0.0, 0.0}, vecOut);
  return !!TrieGetArray(itPData, szMember, vecOut, 3);
}

SetPDataMemberVec(Trie:itPData, const szMember[], const Float:vecValue[3]) {
  TrieSetArray(itPData, szMember, vecValue, 3);
}

ExecuteHookFunction(CEFunction:iFunction, iId, pEntity, any:...) {
  new iResult = 0;

  new Array:irgHooks = ArrayGetCell(g_rgCEData[CEData_Hooks][iFunction], iId);

  new iHooksNum = ArraySize(irgHooks);
  for (new iHookId = 0; iHookId < iHooksNum; ++iHookId) {
    new iPluginId = ArrayGetCell(irgHooks, iHookId, _:CEHookData_PluginID);
    new iFunctionId = ArrayGetCell(irgHooks, iHookId, _:CEHookData_FuncID);
    
    if (callfunc_begin_i(iFunctionId, iPluginId) == 1)  {
      callfunc_push_int(pEntity);

      switch (iFunction) {
        case CEFunction_Touch: {
          new pToucher = getarg(3);
          callfunc_push_int(pToucher);
        }
        case CEFunction_Kill, CEFunction_Killed: {
          new pKiller = getarg(3);
          new bool:bPicked = bool:getarg(4);
          callfunc_push_int(pKiller);
          callfunc_push_int(bPicked);
        }
        case CEFunction_Pickup, CEFunction_Picked: {
          new pPlayer = getarg(3);
          callfunc_push_int(pPlayer);
        }
        case CEFunction_Activate, CEFunction_Activated: {
          new pPlayer = getarg(3);
          callfunc_push_int(pPlayer);
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

      iResult += callfunc_end();    
    }
  }

  return iResult;
}

/*--------------------------------[ Stocks ]--------------------------------*/

stock bool:UTIL_IsMasterTriggered(const szMaster[], pActivator) {
  if (!equal(szMaster, NULL_STRING)) {
    new pMaster = engfunc(EngFunc_FindEntityByString, 0, "targetname", szMaster);

    if (pMaster && (ExecuteHam(Ham_ObjectCaps, pMaster) & FCAP_MASTER)) {
      return !!ExecuteHamB(Ham_IsTriggered, pMaster, pActivator);
    }
  }

  return true;
}

stock UTIL_ParseVector(const szBuffer[], Float:vecOut[3]) {
  new rgszOrigin[3][8];
  parse(szBuffer, rgszOrigin[0], charsmax(rgszOrigin[]), rgszOrigin[1], charsmax(rgszOrigin[]), rgszOrigin[2], charsmax(rgszOrigin[]));

  for (new i = 0; i < 3; ++i) {
    vecOut[i] = str_to_float(rgszOrigin[i]);
  }
}
