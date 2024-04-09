#pragma semicolon 1

#include <amxmodx>
#include <amxmisc>
#include <fakemeta>
#include <hamsandwich>

#include <cellclass>
#include <function_pointer>

#include <api_custom_entities_const>

#define MAX_HOOK_CALL_HIERARCHY_DEPTH 128
#define CLASS_METADATA_ID "iId"
#define LOG_PREFIX "[CE]"

enum _:GLOBALESTATE { GLOBAL_OFF = 0, GLOBAL_ON = 1, GLOBAL_DEAD = 2 };

enum EntityFlags (<<=1) {
  EntityFlag_None = 0,
  EntityFlag_Abstract = 1,
}

enum Entity {
  Array:Entity_Name,
  Array:Entity_Preset,
  Array:Entity_Flags,
  Array:Entity_Hooks[CEFunction],
  Array:Entity_Class,
  Array:Entity_KeyMemberBindings
};

new g_iszBaseClassName;
new bool:g_bIsCStrike = false;

new Trie:g_itEntityIds = Invalid_Trie;
new Array:g_rgEntities[Entity] = { Invalid_Array, ... };
new g_iEntitiesNum = 0;

new ClassInstance:g_pInstance = Invalid_ClassInstance;

new g_iCallPluginId = -1;

public plugin_precache() {
  g_bIsCStrike = !!cstrike_running();
  g_iszBaseClassName = engfunc(EngFunc_AllocString, CE_BASE_CLASSNAME);

  InitStorages();

  register_forward(FM_Spawn, "FMHook_Spawn");
  register_forward(FM_KeyValue, "FMHook_KeyValue");
  register_forward(FM_OnFreeEntPrivateData, "FMHook_OnFreeEntPrivateData");

  RegisterHam(Ham_Spawn, CE_BASE_CLASSNAME, "HamHook_Base_Spawn_Post", .Post = 1);
  RegisterHam(Ham_ObjectCaps, CE_BASE_CLASSNAME, "HamHook_Base_ObjectCaps", .Post = 0);

  if (g_bIsCStrike) {
    RegisterHam(Ham_CS_Restart, CE_BASE_CLASSNAME, "HamHook_Base_Restart", .Post = 1);
  }

  RegisterHam(Ham_Touch, CE_BASE_CLASSNAME, "HamHook_Base_Touch", .Post = 0);
  RegisterHam(Ham_Touch, CE_BASE_CLASSNAME, "HamHook_Base_Touch_Post", .Post = 1);
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
  register_native("CE_RegisterDerived", "Native_RegisterDerived");
  register_native("CE_Create", "Native_Create");
  register_native("CE_Kill", "Native_Kill");
  register_native("CE_Remove", "Native_Remove");
  register_native("CE_Restart", "Native_Restart");

  register_native("CE_RegisterHook", "Native_RegisterHook");
  register_native("CE_RegisterKeyMemberBinding", "Native_RegisterKeyMemberBinding");
  register_native("CE_RemoveKeyMemberBinding", "Native_RemoveKeyMemberBinding");
  register_native("CE_RegisterMethod", "Native_RegisterMethod");
  register_native("CE_RegisterVirtualMethod", "Native_RegisterVirtualMethod");

  register_native("CE_GetHandler", "Native_GetHandler");
  register_native("CE_GetHandlerByEntity", "Native_GetHandlerByEntity");
  register_native("CE_IsInstanceOf", "Native_IsInstanceOf");

  register_native("CE_HasMember", "Native_HasMember");
  register_native("CE_GetMember", "Native_GetMember");
  register_native("CE_DeleteMember", "Native_DeleteMember");
  register_native("CE_SetMember", "Native_SetMember");
  register_native("CE_GetMemberVec", "Native_GetMemberVec");
  register_native("CE_SetMemberVec", "Native_SetMemberVec");
  register_native("CE_GetMemberString", "Native_GetMemberString");
  register_native("CE_SetMemberString", "Native_SetMemberString");
  register_native("CE_CallMethod", "Native_CallMethod");
  register_native("CE_CallBaseMethod", "Native_CallBaseMethod");
  register_native("CE_GetCallPluginId", "Native_GetCallPluginId");
}

public plugin_end() {
  DestroyStorages();
}

/*--------------------------------[ Natives ]--------------------------------*/

public Native_Register(iPluginId, iArgc) {
  new szClassname[CE_MAX_NAME_LENGTH]; get_string(1, szClassname, charsmax(szClassname));
  new CEPreset:iPreset = CEPreset:get_param(2);
  new bool:bAbstract = bool:get_param(3);

  new EntityFlags:iFlags = bAbstract ? EntityFlag_Abstract : EntityFlag_None;
  
  return RegisterEntity(szClassname, iPreset, iFlags);
}

public Native_RegisterDerived(iPluginId, iArgc) {
  new szClassname[CE_MAX_NAME_LENGTH]; get_string(1, szClassname, charsmax(szClassname));
  new szBaseClassName[CE_MAX_NAME_LENGTH]; get_string(2, szBaseClassName, charsmax(szBaseClassName));
  new bool:bAbstract = bool:get_param(3);

  new EntityFlags:iFlags = bAbstract ? EntityFlag_Abstract : EntityFlag_None;
  
  return RegisterEntity(szClassname, _, iFlags, szBaseClassName);
}

public Native_Create(iPluginId, iArgc) {
  static szClassname[CE_MAX_NAME_LENGTH]; get_string(1, szClassname, charsmax(szClassname));
  static Float:vecOrigin[3]; get_array_f(2, vecOrigin, 3);
  static bool:bTemp; bTemp = !!get_param(3);

  new pEntity = @Entity_Create(szClassname, vecOrigin, bTemp);
  if (!pEntity) {
    log_error(AMX_ERR_NATIVE, "%s Failed to create entity ^"%s^"! Entity is abstract or not registered!", LOG_PREFIX, szClassname);
    return 0;
  }

  new ClassInstance:pInstance = @Entity_GetClassInstance(pEntity);
  ClassInstanceSetMember(pInstance, CE_MEMBER_PLUGINID, iPluginId);

  return pEntity;
}

public Native_Kill(iPluginId, iArgc) {
  new pEntity = get_param(1);
  new pKiller = get_param(2);

  if (!@Entity_IsCustom(pEntity)) return;

  @Entity_Kill(pEntity, pKiller, false);
}

public bool:Native_Remove(iPluginId, iArgc) {
  new pEntity = get_param(1);

  if (!@Entity_IsCustom(pEntity)) return;

  set_pev(pEntity, pev_flags, pev(pEntity, pev_flags) | FL_KILLME);
  dllfunc(DLLFunc_Think, pEntity);
}

public Native_Restart(iPluginId, iArgc) {
  new pEntity = get_param(1);

  if (!@Entity_IsCustom(pEntity)) return;

  @Entity_Restart(pEntity);
}

public Native_RegisterHook(iPluginId, iArgc) {
  new szClassname[CE_MAX_NAME_LENGTH]; get_string(1, szClassname, charsmax(szClassname));
  new CEFunction:iFunction = CEFunction:get_param(2);
  new szCallback[CE_MAX_CALLBACK_NAME_LENGTH]; get_string(3, szCallback, charsmax(szCallback));

  new Function:fnCallback = get_func_pointer(szCallback, iPluginId);
  if (fnCallback == Invalid_FunctionPointer) {
    new szFilename[64];
    get_plugin(iPluginId, szFilename, charsmax(szFilename));
    log_error(AMX_ERR_NATIVE, "%s Function ^"%s^" not found in plugin ^"%s^".", LOG_PREFIX, szCallback, szFilename);
    return;
  }

  RegisterEntityHook(iFunction, szClassname, fnCallback);
}

public Native_RegisterMethod(iPluginId, iArgc) {
  new szClassname[CE_MAX_NAME_LENGTH]; get_string(1, szClassname, charsmax(szClassname));
  new szMethod[CE_MAX_METHOD_NAME_LENGTH]; get_string(2, szMethod, charsmax(szMethod));
  new szCallback[CE_MAX_CALLBACK_NAME_LENGTH]; get_string(3, szCallback, charsmax(szCallback));

  new iId = GetIdByClassName(szClassname);
  new Class:cEntity = ArrayGetCell(g_rgEntities[Entity_Class], iId);
  new Array:irgParams = ReadMethodParamsFromNativeCall(4, iArgc);

  ClassAddMethod(cEntity, szMethod, get_func_pointer(szCallback, iPluginId), false, CMP_Cell, CMP_ParamsCellArray, irgParams);

  ArrayDestroy(irgParams);
}

public Native_RegisterVirtualMethod(iPluginId, iArgc) {
  new szClassname[CE_MAX_NAME_LENGTH]; get_string(1, szClassname, charsmax(szClassname));
  new szMethod[CE_MAX_METHOD_NAME_LENGTH]; get_string(2, szMethod, charsmax(szMethod));
  new szCallback[CE_MAX_CALLBACK_NAME_LENGTH]; get_string(3, szCallback, charsmax(szCallback));

  new iId = GetIdByClassName(szClassname);
  new Class:cEntity = ArrayGetCell(g_rgEntities[Entity_Class], iId);
  new Array:irgParams = ReadMethodParamsFromNativeCall(4, iArgc);

  ClassAddMethod(cEntity, szMethod, get_func_pointer(szCallback, iPluginId), true, CMP_Cell, CMP_ParamsCellArray, irgParams);

  ArrayDestroy(irgParams);
}

public Native_RegisterKeyMemberBinding(iPluginId, iArgc) {
  new szClassname[CE_MAX_NAME_LENGTH]; get_string(1, szClassname, charsmax(szClassname));
  new szKey[CE_MAX_NAME_LENGTH]; get_string(2, szKey, charsmax(szKey));
  new szMember[CE_MAX_NAME_LENGTH]; get_string(3, szMember, charsmax(szMember));
  new CEMemberType:iType = CEMemberType:get_param(4);

  new iId = GetIdByClassName(szClassname);
  if (iId == -1) {
    log_error(AMX_ERR_NATIVE, "%s Entity ^"%s^" is not registered.", LOG_PREFIX, szClassname);
    return;
  }

  RegisterKeyMemberBinding(iId, szKey, szMember, iType);
}

public Native_RemoveKeyMemberBinding(iPluginId, iArgc) {
  new szClassname[CE_MAX_NAME_LENGTH]; get_string(1, szClassname, charsmax(szClassname));
  new szKey[CE_MAX_NAME_LENGTH]; get_string(2, szKey, charsmax(szKey));
  new szMember[CE_MAX_NAME_LENGTH]; get_string(3, szMember, charsmax(szMember));

  new iId = GetIdByClassName(szClassname);
  if (iId == -1) {
    log_error(AMX_ERR_NATIVE, "%s Entity ^"%s^" is not registered.", LOG_PREFIX, szClassname);
    return;
  }

  RemoveKeyMemberBinding(iId, szKey, szMember);
}

public Native_GetHandler(iPluginId, iArgc) {
  static szClassname[CE_MAX_NAME_LENGTH]; get_string(1, szClassname, charsmax(szClassname));

  return GetIdByClassName(szClassname);
}

public Native_GetHandlerByEntity(iPluginId, iArgc) {
  static pEntity; pEntity = get_param(1);

  if (!@Entity_IsCustom(pEntity)) return -1;

  new ClassInstance:pInstance = @Entity_GetClassInstance(pEntity);

  return ClassInstanceGetMember(pInstance, CE_MEMBER_ID);
}

public bool:Native_IsInstanceOf(iPluginId, iArgc) {
  static pEntity; pEntity = get_param(1);
  static szClassname[CE_MAX_NAME_LENGTH]; get_string(2, szClassname, charsmax(szClassname));

  if (!@Entity_IsCustom(pEntity)) return false;

  static iTargetId; iTargetId = GetIdByClassName(szClassname);
  if (iTargetId == -1) return false;

  static Class:cTarget; cTarget = ArrayGetCell(g_rgEntities[Entity_Class], iTargetId);

  new ClassInstance:pInstance = @Entity_GetClassInstance(pEntity);

  return ClassInstanceIsInstanceOf(pInstance, cTarget);
}

public bool:Native_HasMember(iPluginId, iArgc) {
  static pEntity; pEntity = get_param(1);
  static szMember[CE_MAX_MEMBER_NAME_LENGTH]; get_string(2, szMember, charsmax(szMember));

  if (!@Entity_IsCustom(pEntity)) return false;

  new ClassInstance:pInstance = @Entity_GetClassInstance(pEntity);

  return ClassInstanceHasMember(pInstance, szMember);
}

public any:Native_GetMember(iPluginId, iArgc) {
  static pEntity; pEntity = get_param(1);
  static szMember[CE_MAX_MEMBER_NAME_LENGTH]; get_string(2, szMember, charsmax(szMember));

  if (!@Entity_IsCustom(pEntity)) return 0;

  new ClassInstance:pInstance = @Entity_GetClassInstance(pEntity);

  return ClassInstanceGetMember(pInstance, szMember);
}

public Native_DeleteMember(iPluginId, iArgc) {
  static pEntity; pEntity = get_param(1);
  static szMember[CE_MAX_MEMBER_NAME_LENGTH]; get_string(2, szMember, charsmax(szMember));

  if (!@Entity_IsCustom(pEntity)) return;

  new ClassInstance:pInstance = @Entity_GetClassInstance(pEntity);

  ClassInstanceDeleteMember(pInstance, szMember);
}

public Native_SetMember(iPluginId, iArgc) {
  static pEntity; pEntity = get_param(1);
  static szMember[CE_MAX_MEMBER_NAME_LENGTH]; get_string(2, szMember, charsmax(szMember));
  static iValue; iValue = get_param(3);
  static bool:bReplace; bReplace = bool:get_param(4);

  if (!@Entity_IsCustom(pEntity)) return;

  new ClassInstance:pInstance = @Entity_GetClassInstance(pEntity);

  ClassInstanceSetMember(pInstance, szMember, iValue, bReplace);
}

public bool:Native_GetMemberVec(iPluginId, iArgc) {
  static pEntity; pEntity = get_param(1);
  static szMember[CE_MAX_MEMBER_NAME_LENGTH]; get_string(2, szMember, charsmax(szMember));

  if (!@Entity_IsCustom(pEntity)) return false;

  new ClassInstance:pInstance = @Entity_GetClassInstance(pEntity);

  static Float:vecValue[3];
  if (!ClassInstanceGetMemberArray(pInstance, szMember, vecValue, 3)) return false;

  set_array_f(3, vecValue, sizeof(vecValue));

  return true;
}

public Native_SetMemberVec(iPluginId, iArgc) {
  static pEntity; pEntity = get_param(1);
  static szMember[CE_MAX_MEMBER_NAME_LENGTH]; get_string(2, szMember, charsmax(szMember));
  static Float:vecValue[3]; get_array_f(3, vecValue, sizeof(vecValue));
  static bool:bReplace; bReplace = bool:get_param(4);

  if (!@Entity_IsCustom(pEntity)) return;

  new ClassInstance:pInstance = @Entity_GetClassInstance(pEntity);
  ClassInstanceSetMemberArray(pInstance, szMember, vecValue, 3, bReplace);
}

public bool:Native_GetMemberString(iPluginId, iArgc) {
  static pEntity; pEntity = get_param(1);
  static szMember[CE_MAX_MEMBER_NAME_LENGTH]; get_string(2, szMember, charsmax(szMember));

  if (!@Entity_IsCustom(pEntity)) return false;

  new ClassInstance:pInstance = @Entity_GetClassInstance(pEntity);

  static szValue[128];
  if (!ClassInstanceGetMemberString(pInstance, szMember, szValue, charsmax(szValue))) return false;

  set_string(3, szValue, get_param(4));

  return true;
}

public Native_SetMemberString(iPluginId, iArgc) {
  static pEntity; pEntity = get_param(1);
  static szMember[CE_MAX_MEMBER_NAME_LENGTH]; get_string(2, szMember, charsmax(szMember));
  static szValue[128]; get_string(3, szValue, charsmax(szValue));
  static bool:bReplace; bReplace = bool:get_param(4);
  
  if (!@Entity_IsCustom(pEntity)) return;

  new ClassInstance:pInstance = @Entity_GetClassInstance(pEntity);
  ClassInstanceSetMemberString(pInstance, szMember, szValue, bReplace);
}

public any:Native_CallMethod(iPluginId, iArgc) {
  new pEntity = get_param(1);
  static szMethod[CE_MAX_METHOD_NAME_LENGTH]; get_string(2, szMethod, charsmax(szMethod));

  new ClassInstance:pInstance = @Entity_GetClassInstance(pEntity);

  new iOldCallPluginId = g_iCallPluginId;

  g_iCallPluginId = iPluginId;

  ClassInstanceCallMethodBegin(pInstance, szMethod);

  ClassInstanceCallMethodPushParamCell(pEntity);

  for (new iParam = 3; iParam <= iArgc; ++iParam) {
    ClassInstanceCallMethodPushNativeParam(iParam);
  }

  new any:result = ClassInstanceCallMethodEnd();

  g_iCallPluginId = iOldCallPluginId;

  return result;
}

public any:Native_CallBaseMethod(iPluginId, iArgc) {
  new ClassInstance:pInstance = ClassInstanceGetCurrent();
  new pEntity = ClassInstanceGetMember(pInstance, CE_MEMBER_POINTER);

  new iOldCallPluginId = g_iCallPluginId;

  g_iCallPluginId = iPluginId;

  ClassInstanceCallMethodBeginBase();

  ClassInstanceCallMethodPushParamCell(pEntity);

  for (new iParam = 1; iParam <= iArgc; ++iParam) {
    ClassInstanceCallMethodPushNativeParam(iParam);
  }

  new any:result = ClassInstanceCallMethodEnd();

  g_iCallPluginId = iOldCallPluginId;

  return result;
}

public Native_GetCallPluginId(iPluginId, iArgc) {
  return g_iCallPluginId;
}

/*--------------------------------[ Commands ]--------------------------------*/

public Command_Spawn(pPlayer, iLevel, iCId) {
  if (!cmd_access(pPlayer, iLevel, iCId, 2)) return PLUGIN_HANDLED;

  new szClassname[128];
  read_args(szClassname, charsmax(szClassname));
  remove_quotes(szClassname);

  if (equal(szClassname, NULL_STRING)) return PLUGIN_HANDLED;

  new Float:vecOrigin[3]; pev(pPlayer, pev_origin, vecOrigin);
  
  new pEntity = @Entity_Create(szClassname, vecOrigin, true);
  if (!pEntity) return PLUGIN_HANDLED;

  dllfunc(DLLFunc_Spawn, pEntity);

  return PLUGIN_HANDLED;
}

/*--------------------------------[ Hooks ]--------------------------------*/

public FMHook_OnFreeEntPrivateData(pEntity) {
  if (!pev_valid(pEntity)) return;

  if (@Entity_IsCustom(pEntity)) {
    @Entity_DestroyClassInstance(pEntity);
  }
}

public FMHook_KeyValue(pEntity, hKVD) {
  new szKey[32]; get_kvd(hKVD, KV_KeyName, szKey, charsmax(szKey));
  new szValue[32]; get_kvd(hKVD, KV_Value, szValue, charsmax(szValue));

  if (equal(szKey, "classname")) {
    new iId = GetIdByClassName(szValue);
    if (iId != -1) {
      // using set_kvd leads to duplicate kvd emit, this check will fix the issue
      if (g_pInstance == Invalid_ClassInstance) {
        new EntityFlags:iFlags = ArrayGetCell(g_rgEntities[Entity_Flags], iId);
        if (~iFlags & EntityFlag_Abstract) {
          set_kvd(hKVD, KV_Value, CE_BASE_CLASSNAME);
          g_pInstance = AllocPData(iId, pEntity);
        }
      }
    } else {
        // if for some reason data was not assigned
        if (g_pInstance != Invalid_ClassInstance) {
          ClassInstanceDestroy(g_pInstance);
          g_pInstance = Invalid_ClassInstance;
        }
    }
  }

  if (g_pInstance != Invalid_ClassInstance) {
    if (equal(szKey, "classname")) {
      ClassInstanceSetMember(g_pInstance, CE_MEMBER_WORLD, true);
    }
    
    if (ExecuteHookFunction(CEFunction_KeyValue, pEntity, szKey, szValue) == PLUGIN_CONTINUE) {
      @Entity_ApplyKeyMemberBindings(pEntity, szKey, szValue);
    }
  }

  return FMRES_HANDLED;
}

public FMHook_Spawn(pEntity) {
  if (g_pInstance != Invalid_ClassInstance) {
    static iId; iId = ClassInstanceGetMember(g_pInstance, CE_MEMBER_ID);

    static szClassname[CE_MAX_NAME_LENGTH];
    ArrayGetString(g_rgEntities[Entity_Name], iId, szClassname, charsmax(szClassname));
    set_pev(pEntity, pev_classname, szClassname);

    @Entity_SetClassInstance(pEntity, g_pInstance);
    g_pInstance = Invalid_ClassInstance;
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

public HamHook_Base_Touch_Post(pEntity, pToucher) {
  if (@Entity_IsCustom(pEntity)) {
    @Entity_Touched(pEntity, pToucher);
    return HAM_HANDLED;
  }

  return HAM_IGNORED;
}

public HamHook_Base_Killed(pEntity, pKiller, iShouldGib) {
  if (@Entity_IsCustom(pEntity)) {
    @Entity_Kill(pEntity, pKiller, iShouldGib);
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

@Entity_Create(const szClassname[], const Float:vecOrigin[3], bool:bTemp) {
  new iId = GetIdByClassName(szClassname);
  if (iId == -1) return 0;

  static EntityFlags:iFlags; iFlags = ArrayGetCell(g_rgEntities[Entity_Flags], iId);
  if (iFlags & EntityFlag_Abstract) return 0;

  new this = engfunc(EngFunc_CreateNamedEntity, g_iszBaseClassName);
  set_pev(this, pev_classname, szClassname);
  engfunc(EngFunc_SetOrigin, this, vecOrigin);
  // set_pev(this, pev_flags, pev(this, pev_flags) & ~FL_ONGROUND);

  new ClassInstance:pInstance = @Entity_AllocClassInstance(this, iId);
  ClassInstanceSetMemberArray(pInstance, CE_MEMBER_ORIGIN, vecOrigin, 3);

  ClassInstanceSetMember(pInstance, CE_MEMBER_WORLD, !bTemp);

  return this;
}

bool:@Entity_IsCustom(const &this) {
  if (g_pInstance != Invalid_ClassInstance && ClassInstanceGetMember(g_pInstance, CE_MEMBER_POINTER) == this) {
    return true;
  }

  return pev(this, pev_gaitsequence) == CE_ENTITY_SECRET;
}

@Entity_Init(&this) {
  new ClassInstance:pInstance = @Entity_GetClassInstance(this);

  ClassInstanceSetMember(pInstance, CE_MEMBER_IGNOREROUNDS, false);

  if (ExecuteHookFunction(CEFunction_Init, this) != PLUGIN_CONTINUE) return;

  if (ClassInstanceHasMember(pInstance, CE_MEMBER_MODEL)) {
    static szModel[MAX_RESOURCE_PATH_LENGTH];
    ClassInstanceGetMemberString(pInstance, CE_MEMBER_MODEL, szModel, charsmax(szModel));
  }

  ClassInstanceSetMember(pInstance, CE_MEMBER_INITIALIZED, true);
  ClassInstanceSetMember(pInstance, CE_MEMBER_LASTINIT, get_gametime());
}

@Entity_Spawn(&this) {
  if (ExecuteHookFunction(CEFunction_Spawn, this) != PLUGIN_CONTINUE) return;

  new ClassInstance:pInstance; pInstance = @Entity_GetClassInstance(this);
  if (!ClassInstanceGetMember(pInstance, CE_MEMBER_INITIALIZED)) {
    @Entity_Init(this);
  }

  if (!pev_valid(this) || pev(this, pev_flags) & FL_KILLME) return;

  set_pev(this, pev_deadflag, DEAD_NO);
  set_pev(this, pev_effects, pev(this, pev_effects) & ~EF_NODRAW);
  set_pev(this, pev_flags, pev(this, pev_flags) & ~FL_ONGROUND);

  @Entity_InitPhysics(this);
  @Entity_InitModel(this);
  @Entity_InitSize(this);

  static iId; iId = ClassInstanceGetMember(pInstance, CE_MEMBER_ID);
  static CEPreset:iPreset; iPreset = ArrayGetCell(g_rgEntities[Entity_Preset], iId);

  switch (iPreset) {
    case CEPreset_Trigger: {
      ClassInstanceSetMember(pInstance, CE_MEMBER_DELAY, 0.1);
    }
    case CEPreset_NPC: {
      set_pev(this, pev_flags, pev(this, pev_flags) | FL_MONSTER);
    }
    case CEPreset_Item: {
      ClassInstanceSetMember(pInstance, CE_MEMBER_PICKED, false);
    }
  }

  if (ClassInstanceHasMember(pInstance, CE_MEMBER_ORIGIN)) {
    static Float:vecOrigin[3];
    ClassInstanceGetMemberArray(pInstance, CE_MEMBER_ORIGIN, vecOrigin, 3);
    engfunc(EngFunc_SetOrigin, this, vecOrigin);
  }

  if (ClassInstanceHasMember(pInstance, CE_MEMBER_ANGLES)) {
    static Float:vecAngles[3];
    ClassInstanceGetMemberArray(pInstance, CE_MEMBER_ANGLES, vecAngles, 3);
    set_pev(this, pev_angles, vecAngles);
  }

  if (ClassInstanceHasMember(pInstance, CE_MEMBER_TARGETNAME)) {
    static szTargetname[32];
    ClassInstanceGetMemberString(pInstance, CE_MEMBER_TARGETNAME, szTargetname, charsmax(szTargetname));
    set_pev(this, pev_targetname, szTargetname);
  }

  if (ClassInstanceHasMember(pInstance, CE_MEMBER_TARGET)) {
    static szTarget[32];
    ClassInstanceGetMemberString(pInstance, CE_MEMBER_TARGET, szTarget, charsmax(szTarget));
    set_pev(this, pev_target, szTarget);
  }

  static bool:bIsWorld; bIsWorld = ClassInstanceGetMember(pInstance, CE_MEMBER_WORLD);

  static Float:flLifeTime; flLifeTime = 0.0;
  if (!bIsWorld && ClassInstanceHasMember(pInstance, CE_MEMBER_LIFETIME)) {
    flLifeTime = ClassInstanceGetMember(pInstance, CE_MEMBER_LIFETIME);
  }

  static Float:flGameTime; flGameTime = get_gametime();

  if (flLifeTime > 0.0) {
    ClassInstanceSetMember(pInstance, CE_MEMBER_NEXTKILL, flGameTime + flLifeTime);
    set_pev(this, pev_nextthink, flGameTime + flLifeTime);
  } else {
    ClassInstanceSetMember(pInstance, CE_MEMBER_NEXTKILL, 0.0);
  }

  ClassInstanceSetMember(pInstance, CE_MEMBER_LASTSPAWN, flGameTime);

  ExecuteHookFunction(CEFunction_Spawned, this);
}

@Entity_Restart(&this) {  
  ExecuteHookFunction(CEFunction_Restart, this);

  new iObjectCaps = ExecuteHamB(Ham_ObjectCaps, this);

  if (!g_bIsCStrike) {
    if (iObjectCaps & FCAP_MUST_RELEASE) {
      set_pev(this, pev_globalname, GLOBAL_DEAD);
      set_pev(this, pev_solid, SOLID_NOT);
      set_pev(this, pev_flags, pev(this, pev_flags) | FL_KILLME);
      set_pev(this, pev_targetname, "");
      
      return;
    }
  }

  if (~iObjectCaps & FCAP_ACROSS_TRANSITION) {
    dllfunc(DLLFunc_Spawn, this);
  }
}

@Entity_InitPhysics(&this) {
  if (ExecuteHookFunction(CEFunction_InitPhysics, this) != PLUGIN_CONTINUE) return;

  static ClassInstance:pInstance; pInstance = @Entity_GetClassInstance(this);
  static iId; iId = ClassInstanceGetMember(pInstance, CE_MEMBER_ID);
  static CEPreset:iPreset; iPreset = ArrayGetCell(g_rgEntities[Entity_Preset], iId);

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
    }
    case CEPreset_BSP: {
      set_pev(this, pev_movetype, MOVETYPE_PUSH);
      set_pev(this, pev_solid, SOLID_BSP);
      set_pev(this, pev_flags, pev(this, pev_flags) | FL_WORLDBRUSH);
    }
  }
}

@Entity_InitModel(&this) {
  if (ExecuteHookFunction(CEFunction_InitModel, this) != PLUGIN_CONTINUE) return;

  static ClassInstance:pInstance; pInstance = @Entity_GetClassInstance(this);

  if (ClassInstanceHasMember(pInstance, CE_MEMBER_MODEL)) {
    static szModel[MAX_RESOURCE_PATH_LENGTH];
    ClassInstanceGetMemberString(pInstance, CE_MEMBER_MODEL, szModel, charsmax(szModel));
    engfunc(EngFunc_SetModel, this, szModel);
  }
}

@Entity_InitSize(&this) {
  if (ExecuteHookFunction(CEFunction_InitSize, this) != PLUGIN_CONTINUE) return;

  static ClassInstance:pInstance; pInstance = @Entity_GetClassInstance(this);

  if (ClassInstanceHasMember(pInstance, CE_MEMBER_MINS) && ClassInstanceHasMember(pInstance, CE_MEMBER_MAXS)) {
    static Float:vecMins[3]; ClassInstanceGetMemberArray(pInstance, CE_MEMBER_MINS, vecMins, 3);
    static Float:vecMaxs[3]; ClassInstanceGetMemberArray(pInstance, CE_MEMBER_MAXS, vecMaxs, 3);
    engfunc(EngFunc_SetSize, this, vecMins, vecMaxs);
  }
}

@Entity_Kill(&this, const &pKiller, iShouldGib) {
  if (ExecuteHookFunction(CEFunction_Kill, this, pKiller, iShouldGib) != PLUGIN_CONTINUE) return;

  static ClassInstance:pInstance; pInstance = @Entity_GetClassInstance(this);

  ClassInstanceSetMember(pInstance, CE_MEMBER_NEXTKILL, 0.0);

  set_pev(this, pev_takedamage, DAMAGE_NO);
  set_pev(this, pev_effects, pev(this, pev_effects) | EF_NODRAW);
  set_pev(this, pev_solid, SOLID_NOT);
  set_pev(this, pev_movetype, MOVETYPE_NONE);
  set_pev(this, pev_flags, pev(this, pev_flags) & ~FL_ONGROUND);

  new bool:bIsWorld = ClassInstanceGetMember(pInstance, CE_MEMBER_WORLD);

  if (bIsWorld) {
    if (ClassInstanceHasMember(pInstance, CE_MEMBER_RESPAWNTIME)) {
      new Float:flRespawnTime = ClassInstanceGetMember(pInstance, CE_MEMBER_RESPAWNTIME);
      new Float:flGameTime = get_gametime();

      ClassInstanceSetMember(pInstance, CE_MEMBER_NEXTRESPAWN, flGameTime + flRespawnTime);
      set_pev(this, pev_deadflag, DEAD_RESPAWNABLE);
      set_pev(this, pev_nextthink, flGameTime + flRespawnTime);
    } else {
      set_pev(this, pev_deadflag, DEAD_DEAD);
    }
  } else {
    set_pev(this, pev_deadflag, DEAD_DISCARDBODY);
    set_pev(this, pev_flags, pev(this, pev_flags) | FL_KILLME);
  }

  ExecuteHookFunction(CEFunction_Killed, this, pKiller, iShouldGib);
}

@Entity_Think(&this) {
  if (pev(this, pev_flags) & FL_KILLME) return;

  ExecuteHookFunction(CEFunction_Think, this);

  static ClassInstance:pInstance; pInstance = @Entity_GetClassInstance(this);

  static Float:flGameTime; flGameTime = get_gametime();
  static iDeadFlag; iDeadFlag = pev(this, pev_deadflag);

  switch (iDeadFlag) {
    case DEAD_NO: {
      static Float:flNextKill; flNextKill = ClassInstanceGetMember(pInstance, CE_MEMBER_NEXTKILL);
      if (flNextKill > 0.0 && flNextKill <= flGameTime) {
        ExecuteHamB(Ham_Killed, this, 0, 0);
      }
    }
    case DEAD_RESPAWNABLE: {
      static Float:flNextRespawn; flNextRespawn = ClassInstanceGetMember(pInstance, CE_MEMBER_NEXTRESPAWN);
      if (flNextRespawn <= flGameTime) {
        dllfunc(DLLFunc_Spawn, this);
      }
    }
  }
}

@Entity_Touch(&this, const &pToucher) {
  if (ExecuteHookFunction(CEFunction_Touch, this, pToucher)) return;

  static ClassInstance:pInstance; pInstance = @Entity_GetClassInstance(this);

  static iId; iId = ClassInstanceGetMember(pInstance, CE_MEMBER_ID);
  static CEPreset:iPreset; iPreset = ArrayGetCell(g_rgEntities[Entity_Preset], iId);

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

@Entity_Touched(&this, const &pToucher) {
  ExecuteHookFunction(CEFunction_Touched, this, pToucher);
}

@Entity_GetObjectCaps(const &this) {
    new ClassInstance:pInstance = @Entity_GetClassInstance(this);
    new bool:bIgnoreRound = ClassInstanceGetMember(pInstance, CE_MEMBER_IGNOREROUNDS);
    new bool:bIsWorld = ClassInstanceGetMember(pInstance, CE_MEMBER_WORLD);

    new iObjectCaps = 0;

    if (bIgnoreRound) {
      iObjectCaps |= FCAP_ACROSS_TRANSITION;
    } else {
      iObjectCaps |= bIsWorld ? FCAP_MUST_RESET : FCAP_MUST_RELEASE;
    }

    return iObjectCaps;
}

@Entity_Pickup(&this, const &pToucher) {
  if (~pev(this, pev_flags) & FL_ONGROUND) return;

  if (ExecuteHookFunction(CEFunction_Pickup, this, pToucher)) {
    new ClassInstance:pInstance; pInstance = @Entity_GetClassInstance(this);

    ClassInstanceSetMember(pInstance, CE_MEMBER_PICKED, true);
    ExecuteHookFunction(CEFunction_Picked, this, pToucher);
    @Entity_Kill(this, pToucher, 0);
  }
}

bool:@Entity_CanActivate(const &this, const &pTarget) {
  new ClassInstance:pInstance = @Entity_GetClassInstance(this);

  static Float:flNextThink; pev(this, pev_nextthink, flNextThink);
  if (flNextThink > get_gametime()) return false;

  if (!ExecuteHookFunction(CEFunction_Activate, this, pTarget)) return false;

  static szMaster[32]; copy(szMaster, charsmax(szMaster), NULL_STRING);

  ClassInstanceGetMemberString(pInstance, CE_MEMBER_MASTER, szMaster, charsmax(szMaster));

  return UTIL_IsMasterTriggered(szMaster, pTarget);
}

@Entity_Trigger(&this, const &pActivator) {
  if (!@Entity_CanActivate(this, pActivator)) return;

  new ClassInstance:pInstance = @Entity_GetClassInstance(this);

  static Float:flDelay; flDelay = ClassInstanceGetMember(pInstance, CE_MEMBER_DELAY);

  set_pev(this, pev_nextthink, get_gametime() + flDelay);
  ExecuteHookFunction(CEFunction_Activated, this, pActivator);
}

@Entity_BloodColor(const &this) {
  new ClassInstance:pInstance = @Entity_GetClassInstance(this);

  if (!ClassInstanceHasMember(pInstance, CE_MEMBER_BLOODCOLOR)) return -1;

  return ClassInstanceGetMember(pInstance, CE_MEMBER_BLOODCOLOR);
}

@Entity_ApplyKeyMemberBindings(&this, const szKey[], const szValue[]) {
  new ClassInstance:pInstance = @Entity_GetClassInstance(this);

  new Class:rgHierarchy[MAX_HOOK_CALL_HIERARCHY_DEPTH], iHierarchySize;
  GetInstanceHierarchy(pInstance, rgHierarchy, iHierarchySize);

  for (new i = iHierarchySize - 1; i >= 0; --i) {
    new iCurrentId; iCurrentId = ClassGetMetadata(rgHierarchy[i], CLASS_METADATA_ID);

    new Trie:itKeyMemberBindings = ArrayGetCell(g_rgEntities[Entity_KeyMemberBindings], iCurrentId);
    new Trie:itMemberTypes = Invalid_Trie;
    
    if (!TrieGetCell(itKeyMemberBindings, szKey, itMemberTypes)) return;

    new TrieIter:itMemberTypesIter = TrieIterCreate(itMemberTypes);

    while (!TrieIterEnded(itMemberTypesIter)) {
      new szMember[32]; TrieIterGetKey(itMemberTypesIter, szMember, charsmax(szMember));
      new CEMemberType:iType; TrieIterGetCell(itMemberTypesIter, iType);

      switch (iType) {
        case CEMemberType_Cell: {
          ClassInstanceSetMember(g_pInstance, szMember, str_to_num(szValue));
        }
        case CEMemberType_Float: {
          ClassInstanceSetMember(g_pInstance, szMember, str_to_float(szValue));
        }
        case CEMemberType_String: {
          ClassInstanceSetMemberString(g_pInstance, szMember, szValue);
        }
        case CEMemberType_Vector: {
          new Float:vecValue[3];
          UTIL_ParseVector(szValue, vecValue);
          ClassInstanceSetMemberArray(g_pInstance, szMember, vecValue, 3);
        }
      }

      TrieIterNext(itMemberTypesIter);
    }
  }
}

ClassInstance:@Entity_GetClassInstance(const &this) {
  // Return the current allocated data if the entity is at the initialization stage
  if (g_pInstance != Invalid_ClassInstance && ClassInstanceGetMember(g_pInstance, CE_MEMBER_POINTER) == this) {
    return g_pInstance;
  }

  return ClassInstance:pev(this, pev_iStepLeft);
}

@Entity_SetClassInstance(&this, ClassInstance:pInstance) {
  set_pev(this, pev_gaitsequence, CE_ENTITY_SECRET);
  set_pev(this, pev_iStepLeft, pInstance);
}

ClassInstance:@Entity_AllocClassInstance(&this, iId) {
  new ClassInstance:pInstance = AllocPData(iId, this);

  @Entity_SetClassInstance(this, pInstance);

  return pInstance;
}

@Entity_DestroyClassInstance(&this) {
  ExecuteHookFunction(CEFunction_Remove, this);

  new ClassInstance:pInstance = @Entity_GetClassInstance(this);
  ClassInstanceDestroy(pInstance);

  set_pev(this, pev_gaitsequence, 0);
  set_pev(this, pev_iStepLeft, 0);
}

/*--------------------------------[ Functions ]--------------------------------*/

InitStorages() {
  g_itEntityIds = TrieCreate();
  g_rgEntities[Entity_Name] = ArrayCreate(CE_MAX_NAME_LENGTH);
  g_rgEntities[Entity_Preset] = ArrayCreate();
  g_rgEntities[Entity_Class] = ArrayCreate();
  g_rgEntities[Entity_Flags] = ArrayCreate();
  g_rgEntities[Entity_KeyMemberBindings] = ArrayCreate();

  for (new CEFunction:iFunction = CEFunction:0; iFunction < CEFunction; ++iFunction) {
    g_rgEntities[Entity_Hooks][iFunction] = ArrayCreate();
  }
}

DestroyStorages() {
  for (new iId = 0; iId < g_iEntitiesNum; ++iId) {
    FreeRegisteredEntity(iId);
  }

  for (new CEFunction:iFunction = CEFunction:0; iFunction < CEFunction; ++iFunction) {
    ArrayDestroy(g_rgEntities[Entity_Hooks][iFunction]);
  }

  ArrayDestroy(g_rgEntities[Entity_KeyMemberBindings]);
  ArrayDestroy(g_rgEntities[Entity_Class]);
  ArrayDestroy(g_rgEntities[Entity_Flags]);
  ArrayDestroy(g_rgEntities[Entity_Preset]);
  ArrayDestroy(g_rgEntities[Entity_Name]);

  TrieDestroy(g_itEntityIds);
}

RegisterEntity(const szClassname[], CEPreset:iPreset = CEPreset_None, const EntityFlags:iFlags = EntityFlag_None, const szParent[] = "") {
  new iId = g_iEntitiesNum;

  new Class:cParent = Invalid_Class;
  if (!equal(szParent, NULL_STRING)) {
    new iParentId = -1;
    if (!TrieGetCell(g_itEntityIds, szParent, iParentId)) {
      log_error(AMX_ERR_NATIVE, "%s Cannot extend entity class ^"%s^". The class is not exists!", LOG_PREFIX, szParent);
      return -1;
    }

    iPreset = ArrayGetCell(g_rgEntities[Entity_Preset], iParentId);
    cParent = ArrayGetCell(g_rgEntities[Entity_Class], iParentId);
  }

  new Class:cEntity = ClassCreate(cParent);
  ClassSetMetadataString(cEntity, "__NAME", szClassname);
  ClassSetMetadata(cEntity, CLASS_METADATA_ID, iId);

  TrieSetCell(g_itEntityIds, szClassname, iId);
  ArrayPushString(g_rgEntities[Entity_Name], szClassname);
  ArrayPushCell(g_rgEntities[Entity_Preset], iPreset);
  ArrayPushCell(g_rgEntities[Entity_Class], cEntity);
  ArrayPushCell(g_rgEntities[Entity_Flags], iFlags);
  ArrayPushCell(g_rgEntities[Entity_KeyMemberBindings], TrieCreate());

  for (new CEFunction:iFunction = CEFunction:0; iFunction < CEFunction; ++iFunction) {
    ArrayPushCell(g_rgEntities[Entity_Hooks][iFunction], ArrayCreate());
  }

  g_iEntitiesNum++;

  RegisterKeyMemberBinding(iId, "origin", CE_MEMBER_ORIGIN, CEMemberType_Vector);
  RegisterKeyMemberBinding(iId, "angles", CE_MEMBER_ANGLES, CEMemberType_Vector);
  RegisterKeyMemberBinding(iId, "master", CE_MEMBER_MASTER, CEMemberType_String);
  RegisterKeyMemberBinding(iId, "targetname", CE_MEMBER_TARGETNAME, CEMemberType_String);
  RegisterKeyMemberBinding(iId, "target", CE_MEMBER_TARGET, CEMemberType_String);
  RegisterKeyMemberBinding(iId, "model", CE_MEMBER_MODEL, CEMemberType_String);

  log_amx("%s Entity ^"%s^" successfully registred.", LOG_PREFIX, szClassname);

  return iId;
}

FreeRegisteredEntity(iId) {
  for (new CEFunction:iFunction = CEFunction:0; iFunction < CEFunction; ++iFunction) {
    new Array:irgHooks = ArrayGetCell(g_rgEntities[Entity_Hooks][iFunction], iId);
    ArrayDestroy(irgHooks);
    ArraySetCell(g_rgEntities[Entity_Hooks][iFunction], iId, Invalid_Array);
  }

  FreeEntityKeyMemberBindings(iId);

  new Class:cEntity = ArrayGetCell(g_rgEntities[Entity_Class], iId);
  ClassDestroy(cEntity);
}

FreeEntityKeyMemberBindings(iId) {
  new Trie:itKeyMemberBindings = ArrayGetCell(g_rgEntities[Entity_KeyMemberBindings], iId);

  new TrieIter:itKeyMemberBindingsIter = TrieIterCreate(itKeyMemberBindings);

  while (!TrieIterEnded(itKeyMemberBindingsIter)) {
    new Trie:itMemberTypes; TrieIterGetCell(itKeyMemberBindingsIter, itMemberTypes);
    TrieDestroy(itMemberTypes);
    TrieIterNext(itKeyMemberBindingsIter);
  }

  TrieIterDestroy(itKeyMemberBindingsIter);

  TrieDestroy(itKeyMemberBindings);
}

GetIdByClassName(const szClassname[]) {
  static iId; iId = -1;
  TrieGetCell(g_itEntityIds, szClassname, iId);

  return iId;
}

RegisterEntityHook(CEFunction:iFunction, const szClassname[], const Function:fnCallback) {
  new iId = GetIdByClassName(szClassname);
  if (iId == -1) {
    log_error(AMX_ERR_NATIVE, "%s Entity ^"%s^" is not registered.", LOG_PREFIX, szClassname);
    return -1;
  }

  new Array:irgHooks = ArrayGetCell(g_rgEntities[Entity_Hooks][iFunction], iId);
  new iHookId = ArrayPushCell(irgHooks, fnCallback);

  return iHookId;
}

RegisterKeyMemberBinding(iId, const szKey[], const szMember[], CEMemberType:iType) {
  new Trie:itKeyMemberBindings = ArrayGetCell(g_rgEntities[Entity_KeyMemberBindings], iId);

  new Trie:itMemberTypes = Invalid_Trie;
  if (!TrieGetCell(itKeyMemberBindings, szKey, itMemberTypes)) {
    itMemberTypes = TrieCreate();
    TrieSetCell(itKeyMemberBindings, szKey, itMemberTypes);
  }

  TrieSetCell(itMemberTypes, szMember, iType);
}

RemoveKeyMemberBinding(iId, const szKey[], const szMember[]) {
  new Trie:itKeyMemberBindings = ArrayGetCell(g_rgEntities[Entity_KeyMemberBindings], iId);

  new Trie:itMemberTypes = Invalid_Trie;
  if (!TrieGetCell(itKeyMemberBindings, szKey, itMemberTypes)) return;

  TrieDeleteKey(itMemberTypes, szMember);
}

ClassInstance:AllocPData(iId, pEntity) {
  static Class:cEntity; cEntity = ArrayGetCell(g_rgEntities[Entity_Class], iId);
  static ClassInstance:pInstance; pInstance = ClassInstanceCreate(cEntity);

  ClassInstanceSetMember(pInstance, CE_MEMBER_ID, iId);
  ClassInstanceSetMember(pInstance, CE_MEMBER_WORLD, false);
  ClassInstanceSetMember(pInstance, CE_MEMBER_POINTER, pEntity);
  ClassInstanceSetMember(pInstance, CE_MEMBER_INITIALIZED, false);

  return pInstance;
}

ExecuteHookFunction(CEFunction:iFunction, pEntity, any:...) {
  new iResult = 0;

  new ClassInstance:pInstance = @Entity_GetClassInstance(pEntity);

  new Class:rgHierarchy[MAX_HOOK_CALL_HIERARCHY_DEPTH], iHierarchySize;
  GetInstanceHierarchy(pInstance, rgHierarchy, iHierarchySize);

  for (new i = iHierarchySize - 1; i >= 0; --i) {
    new iCurrentId; iCurrentId = ClassGetMetadata(rgHierarchy[i], CLASS_METADATA_ID);
    new Array:irgHooks; irgHooks = ArrayGetCell(g_rgEntities[Entity_Hooks][iFunction], iCurrentId);
    new iHooksNum; iHooksNum = ArraySize(irgHooks);

    for (new iHookId = 0; iHookId < iHooksNum; ++iHookId) {
      static Function:fnCallback; fnCallback = ArrayGetCell(irgHooks, iHookId);

      if (callfunc_begin_p(fnCallback) == 1)  {
        callfunc_push_int(pEntity);

        switch (iFunction) {
          case CEFunction_Touch, CEFunction_Touched: {
            static pToucher; pToucher = getarg(2);
            callfunc_push_int(pToucher);
          }
          case CEFunction_Kill, CEFunction_Killed: {
            static pKiller; pKiller = getarg(2);
            static iShouldGib; iShouldGib = getarg(3);
            callfunc_push_int(pKiller);
            callfunc_push_int(iShouldGib);
          }
          case CEFunction_Pickup, CEFunction_Picked: {
            static pPlayer; pPlayer = getarg(2);
            callfunc_push_int(pPlayer);
          }
          case CEFunction_Activate, CEFunction_Activated: {
            static pPlayer; pPlayer = getarg(2);
            callfunc_push_int(pPlayer);
          }
          case CEFunction_KeyValue: {
            static szKey[32];
            for (new i = 0; i < charsmax(szKey); ++i) {
              szKey[i] = getarg(2, i);
              
              if (szKey[i]  == '^0') break;
            }
            
            static szValue[32];
            for (new i = 0; i < charsmax(szValue); ++i) {
              szValue[i] = getarg(3, i);
              
              if (szValue[i]  == '^0') break;
            }
            
            callfunc_push_str(szKey);
            callfunc_push_str(szValue);
          }
        }

        iResult = max(iResult, callfunc_end());
      }
    }
  }

  return iResult;
}

GetInstanceHierarchy(ClassInstance:pInstance, Class:rgValue[MAX_HOOK_CALL_HIERARCHY_DEPTH], &iSize) {
  iSize = 0;

  for (new Class:cStart = ClassInstanceGetClass(pInstance); cStart != Invalid_Class; cStart = ClassGetBaseClass(cStart)) {
    rgValue[iSize] = cStart;
    iSize++;
  }
}

Array:ReadMethodParamsFromNativeCall(iStartArg, iArgc) {
  static Array:irgParams; irgParams = ArrayCreate();

  for (new iParam = iStartArg; iParam <= iArgc; ++iParam) {
    static iType; iType = get_param_byref(iParam);

    switch (iType) {
      case CE_MP_Cell, CE_MP_Float: {
        ArrayPushCell(irgParams, CMP_Cell);
      }
      case CE_MP_String: {
        ArrayPushCell(irgParams, CMP_String);
      }
      case CE_MP_Array, CE_MP_FloatArray: {
        ArrayPushCell(irgParams, CMP_Array);
        ArrayPushCell(irgParams, get_param_byref(iParam + 1));
        iParam++;
      }
    }
  }

  return irgParams;
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
  static rgszOrigin[3][8];
  parse(szBuffer, rgszOrigin[0], charsmax(rgszOrigin[]), rgszOrigin[1], charsmax(rgszOrigin[]), rgszOrigin[2], charsmax(rgszOrigin[]));

  for (new i = 0; i < 3; ++i) {
    vecOut[i] = str_to_float(rgszOrigin[i]);
  }
}
