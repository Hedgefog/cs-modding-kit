#pragma semicolon 1

#include <amxmodx>
#include <amxmisc>
#include <fakemeta>
#include <hamsandwich>
#include <xs>

#include <cellclass>
#include <function_pointer>
#include <stack>

#include <api_custom_entities_const>

#define IS_PLAYER(%1) (%1 >= 1 && %1 <= MaxClients)

#define ERROR_IS_ALREADY_REGISTERED "%s Entity with class ^"%s^" is already registered."
#define ERROR_IS_NOT_REGISTERED "%s Entity ^"%s^" is not registered."
#define ERROR_FUNCTION_NOT_FOUND "%s Function ^"%s^" not found in plugin ^"%s^"."
#define ERROR_IS_NOT_REGISTERED_BASE "%s Cannot extend entity class ^"%s^". The class is not exists!"
#define ERROR_CANNOT_CREATE_UNREGISTERED "%s Failed to create entity ^"%s^"! Entity is not registered!"
#define ERROR_CANNOT_CREATE_ABSTRACT "%s Failed to create entity ^"%s^"! Entity is abstract!"

#define LOG_PREFIX "[CE]"

#define MAX_ENTITIES 2048
#define MAX_ENTITY_CLASSES 512

#define CLASS_METADATA_NAME "__NAME"
#define CLASS_METADATA_CE_ID "__CE_ID"

#define CE_INVALID_ID -1
#define CE_INVALID_HOOK_ID -1

enum _:GLOBALESTATE { GLOBAL_OFF = 0, GLOBAL_ON = 1, GLOBAL_DEAD = 2 };

enum EntityFlags (<<=1) {
  EntityFlag_None = 0,
  EntityFlag_Abstract = 1,
}

enum Entity {
  Entity_Id,
  Class:Entity_Class,
  EntityFlags:Entity_Flags,
  Trie:Entity_KeyMemberBindings,
  Array:Entity_Hierarchy,
  Array:Entity_MethodPreHooks[CEMethod],
  Array:Entity_MethodPostHooks[CEMethod],
  Entity_TotalHooksCounter[CEMethod] // Used as cache to increase hook call performance
};

enum EntityMethodPointer {
  EntityMethodPointer_Think,
  EntityMethodPointer_Touch,
  EntityMethodPointer_Use,
  EntityMethodPointer_Blocked
};

enum EntityMethodParams {
  EntityMethodParams_Num,
  EntityMethodParams_Types[6]
};

STACK_DEFINE(METHOD_PLUGIN);
STACK_DEFINE(METHOD_RETURN);
STACK_DEFINE(PREHOOK_RETURN);

new const g_rgEntityMethodParams[CEMethod][EntityMethodParams] = {
  /* Allocate */                {2, {CMP_Cell, CMP_Cell}},
  /* Free */                    {0},
  /* KeyValue */                {2, {CMP_String, CMP_String}},
  /* SpawnInit */               {0},
  /* Spawn */                   {0},
  /* ResetVariables */          {0},
  /* UpdatePhysics */           {0},
  /* UpdateModel */             {0},
  /* UpdateSize */              {0},
  /* Touch */                   {1, {CMP_Cell}},
  /* Think */                   {0},
  /* CanPickup */               {1, {CMP_Cell}},
  /* Pickup */                  {1, {CMP_Cell}},
  /* CanTrigger */              {1, {CMP_Cell}},
  /* Trigger */                 {1, {CMP_Cell}},
  /* Restart */                 {0},
  /* Kill */                    {2, {CMP_Cell, CMP_Cell}},
  /* IsMasterTriggered */       {1, {CMP_Cell}},
  /* ObjectCaps */              {0},
  /* BloodColor */              {0},
  /* Use */                     {4, {CMP_Cell, CMP_Cell, CMP_Cell, CMP_Cell}},
  /* Blocked */                 {1, {CMP_Cell}},
  /* GetDelay */                {0},
  /* Classify */                {0},
  /* IsTriggered */             {1, {CMP_Cell}},
  /* GetToggleState */          {0},
  /* SetToggleState */          {1, {CMP_Cell}},
  /* Respawn */                 {0},
  /* TraceAttack */             {6, {CMP_Cell, CMP_Cell, CMP_Array, 3, CMP_Cell, CMP_Cell}}
};

new g_iszBaseClassName;
new bool:g_bIsCStrike = false;

new g_rgPresetEntityIds[CEPreset];
new Trie:g_itEntityIds = Invalid_Trie;

new g_rgEntities[MAX_ENTITY_CLASSES][Entity];
new g_iEntityClassesNum = 0;

new Struct:g_rgEntityMethodPointers[MAX_ENTITIES][EntityMethodPointer];
new ClassInstance:g_rgEntityClassInstances[MAX_ENTITIES];

new HamHook:g_rgMethodHamHooks[CEMethod];

public plugin_precache() {
  g_bIsCStrike = !!cstrike_running();
  g_iszBaseClassName = engfunc(EngFunc_AllocString, CE_BASE_CLASSNAME);

  InitStorages();
  InitBaseClasses();
  InitHooks();
}

public plugin_init() {
  register_plugin("[API] Custom Entities", "2.0.0", "Hedgehog Fog");

  register_concmd("ce_spawn", "Command_Spawn", ADMIN_CVAR);
  register_concmd("ce_get_member", "Command_GetMember", ADMIN_CVAR);
  register_concmd("ce_get_member_float", "Command_GetMemberFloat", ADMIN_CVAR);
  register_concmd("ce_get_member_string", "Command_GetMemberString", ADMIN_CVAR);
  register_concmd("ce_set_member", "Command_SetMember", ADMIN_CVAR);
  register_concmd("ce_call_method", "Command_CallMethod", ADMIN_CVAR);
  register_concmd("ce_list", "Command_List", ADMIN_CVAR);
}

public plugin_natives() {
  register_library("api_custom_entities");

  register_native("CE_RegisterClass", "Native_Register");  
  register_native("CE_RegisterClassDerived", "Native_RegisterDerived");
  register_native("CE_RegisterClassAlias", "Native_RegisterAlias");

  register_native("CE_RegisterClassKeyMemberBinding", "Native_RegisterKeyMemberBinding");
  register_native("CE_RemoveClassKeyMemberBinding", "Native_RemoveMemberBinding");
  register_native("CE_RegisterClassMethod", "Native_RegisterMethod");
  register_native("CE_ImplementClassMethod", "Native_ImplementMethod");
  register_native("CE_RegisterClassVirtualMethod", "Native_RegisterVirtualMethod");

  register_native("CE_RegisterClassHook", "Native_RegisterHook");
  register_native("CE_GetMethodReturn", "Native_GetMethodReturn");
  register_native("CE_SetMethodReturn", "Native_SetMethodReturn");

  register_native("CE_GetClassHandler", "Native_GetHandler");
  register_native("CE_GetHandler", "Native_GetHandlerByEntity");
  register_native("CE_Create", "Native_Create");
  register_native("CE_Kill", "Native_Kill");
  register_native("CE_Remove", "Native_Remove");
  register_native("CE_Restart", "Native_Restart");
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

  register_native("CE_SetThink", "Native_SetThink");
  register_native("CE_SetTouch", "Native_SetTouch");
  register_native("CE_SetUse", "Native_SetUse");
  register_native("CE_SetBlocked", "Native_SetBlocked");
}

public plugin_end() {
  DestroyRegisteredClasses();
  DestroyStorages();
}

/*--------------------------------[ Natives ]--------------------------------*/

public Native_Register(iPluginId, iArgc) {
  new szClassname[CE_MAX_NAME_LENGTH]; get_string(1, szClassname, charsmax(szClassname));
  new CEPreset:iPreset = CEPreset:get_param(2);
  new bool:bAbstract = bool:get_param(3);

  if (iPreset == CEPreset_Invalid) {
    log_amx("Cannot register entity without preset!");
    return -1;
  }

  new EntityFlags:iFlags = bAbstract ? EntityFlag_Abstract : EntityFlag_None;
  
  return RegisterEntityClass(szClassname, iPreset, iFlags);
}

public Native_RegisterDerived(iPluginId, iArgc) {
  new szClassname[CE_MAX_NAME_LENGTH]; get_string(1, szClassname, charsmax(szClassname));
  new szBaseClassName[CE_MAX_NAME_LENGTH]; get_string(2, szBaseClassName, charsmax(szBaseClassName));
  new bool:bAbstract = bool:get_param(3);

  new EntityFlags:iFlags = bAbstract ? EntityFlag_Abstract : EntityFlag_None;
  
  return RegisterEntityClass(szClassname, _, iFlags, szBaseClassName);
}

public Native_RegisterAlias(iPluginId, iArgc) {
  new szAlias[CE_MAX_NAME_LENGTH]; get_string(1, szAlias, charsmax(szAlias));
  new szClassname[CE_MAX_NAME_LENGTH]; get_string(2, szClassname, charsmax(szClassname));

  if (GetIdByClassName(szAlias) != CE_INVALID_ID) {
    log_error(AMX_ERR_NATIVE, ERROR_IS_ALREADY_REGISTERED, LOG_PREFIX, szAlias);
    return;
  }

  new iId = GetIdByClassName(szClassname);
  if (iId == CE_INVALID_ID) {
    log_error(AMX_ERR_NATIVE, ERROR_IS_NOT_REGISTERED, LOG_PREFIX, szClassname);
    return;
  }

  TrieSetCell(g_itEntityIds, szAlias, iId);
}

public Native_Create(iPluginId, iArgc) {
  static szClassname[CE_MAX_NAME_LENGTH]; get_string(1, szClassname, charsmax(szClassname));
  static Float:vecOrigin[3]; get_array_f(2, vecOrigin, 3);
  static bool:bTemp; bTemp = !!get_param(3);

  new pEntity = CreateEntity(szClassname, vecOrigin, bTemp);
  if (pEntity == FM_NULLENT) return FM_NULLENT;

  new ClassInstance:pInstance = @Entity_GetInstance(pEntity);
  ClassInstanceSetMember(pInstance, CE_MEMBER_PLUGINID, iPluginId);

  return pEntity;
}

public Native_Kill(iPluginId, iArgc) {
  new pEntity = get_param_byref(1);
  new pKiller = get_param_byref(2);

  if (!@Entity_IsCustom(pEntity)) return;

  ExecuteMethod(CEMethod_Killed, pEntity, pKiller, false);
}

public bool:Native_Remove(iPluginId, iArgc) {
  new pEntity = get_param_byref(1);

  if (!@Entity_IsCustom(pEntity)) return;

  set_pev(pEntity, pev_flags, pev(pEntity, pev_flags) | FL_KILLME);
  dllfunc(DLLFunc_Think, pEntity);
}

public Native_Restart(iPluginId, iArgc) {
  new pEntity = get_param_byref(1);

  if (!@Entity_IsCustom(pEntity)) return;

  ExecuteMethod(CEMethod_Restart, pEntity);
}

public Native_RegisterHook(iPluginId, iArgc) {
  new szClassname[CE_MAX_NAME_LENGTH]; get_string(1, szClassname, charsmax(szClassname));
  new CEMethod:iMethod = CEMethod:get_param(2);
  new szCallback[CE_MAX_CALLBACK_NAME_LENGTH]; get_string(3, szCallback, charsmax(szCallback));
  new bool:bPost = bool:get_param(4);

  new Function:fnCallback = get_func_pointer(szCallback, iPluginId);
  if (fnCallback == Invalid_FunctionPointer) {
    new szFilename[64];
    get_plugin(iPluginId, szFilename, charsmax(szFilename));
    log_error(AMX_ERR_NATIVE, ERROR_FUNCTION_NOT_FOUND, LOG_PREFIX, szCallback, szFilename);
    return;
  }

  RegisterEntityClassHook(szClassname, iMethod, fnCallback, bool:bPost);
}

public Native_RegisterMethod(iPluginId, iArgc) {
  new szClassname[CE_MAX_NAME_LENGTH]; get_string(1, szClassname, charsmax(szClassname));
  new szMethod[CE_MAX_METHOD_NAME_LENGTH]; get_string(2, szMethod, charsmax(szMethod));
  new szCallback[CE_MAX_CALLBACK_NAME_LENGTH]; get_string(3, szCallback, charsmax(szCallback));

  new Function:fnCallback = get_func_pointer(szCallback, iPluginId);

  if (fnCallback == Invalid_FunctionPointer) {
    new szFilename[64];
    get_plugin(iPluginId, szFilename, charsmax(szFilename));
    log_error(AMX_ERR_NATIVE, ERROR_FUNCTION_NOT_FOUND, LOG_PREFIX, szCallback, szFilename);
    return;
  }

  new Array:irgParamsTypes = ReadMethodParamsFromNativeCall(4, iArgc);
  AddEntityClassMethod(szClassname, szMethod, fnCallback, irgParamsTypes, false);
  ArrayDestroy(irgParamsTypes);
}

public Native_RegisterVirtualMethod(iPluginId, iArgc) {
  new szClassname[CE_MAX_NAME_LENGTH]; get_string(1, szClassname, charsmax(szClassname));
  new szMethod[CE_MAX_METHOD_NAME_LENGTH]; get_string(2, szMethod, charsmax(szMethod));
  new szCallback[CE_MAX_CALLBACK_NAME_LENGTH]; get_string(3, szCallback, charsmax(szCallback));

  new Function:fnCallback = get_func_pointer(szCallback, iPluginId);

  if (fnCallback == Invalid_FunctionPointer) {
    new szFilename[64];
    get_plugin(iPluginId, szFilename, charsmax(szFilename));
    log_error(AMX_ERR_NATIVE, ERROR_FUNCTION_NOT_FOUND, LOG_PREFIX, szCallback, szFilename);
    return;
  }

  new Array:irgParamsTypes = ReadMethodParamsFromNativeCall(4, iArgc);
  AddEntityClassMethod(szClassname, szMethod, fnCallback, irgParamsTypes, true);
  ArrayDestroy(irgParamsTypes);
}

public Native_ImplementMethod(iPluginId, iArgc) {
  new szClassname[CE_MAX_NAME_LENGTH]; get_string(1, szClassname, charsmax(szClassname));
  new CEMethod:iMethod = CEMethod:get_param(2);
  new szCallback[CE_MAX_CALLBACK_NAME_LENGTH]; get_string(3, szCallback, charsmax(szCallback));

  new Function:fnCallback = get_func_pointer(szCallback, iPluginId);

  if (fnCallback == Invalid_FunctionPointer) {
    new szFilename[64];
    get_plugin(iPluginId, szFilename, charsmax(szFilename));
    log_error(AMX_ERR_NATIVE, ERROR_FUNCTION_NOT_FOUND, LOG_PREFIX, szCallback, szFilename);
    return;
  }

  ImplementEntityClassMethod(szClassname, iMethod, fnCallback);
}

public Native_RegisterKeyMemberBinding(iPluginId, iArgc) {
  new szClassname[CE_MAX_NAME_LENGTH]; get_string(1, szClassname, charsmax(szClassname));
  new szKey[CE_MAX_NAME_LENGTH]; get_string(2, szKey, charsmax(szKey));
  new szMember[CE_MAX_NAME_LENGTH]; get_string(3, szMember, charsmax(szMember));
  new CEMemberType:iType = CEMemberType:get_param(4);

  RegisterEntityClassKeyMemberBinding(szClassname, szKey, szMember, iType);
}

public Native_RemoveMemberBinding(iPluginId, iArgc) {
  new szClassname[CE_MAX_NAME_LENGTH]; get_string(1, szClassname, charsmax(szClassname));
  new szKey[CE_MAX_NAME_LENGTH]; get_string(2, szKey, charsmax(szKey));
  new szMember[CE_MAX_NAME_LENGTH]; get_string(3, szMember, charsmax(szMember));

  RemoveEntityClassKeyMemberBinding(szClassname, szKey, szMember);
}

public Native_GetHandler(iPluginId, iArgc) {
  static szClassname[CE_MAX_NAME_LENGTH]; get_string(1, szClassname, charsmax(szClassname));

  return GetIdByClassName(szClassname);
}

public Native_GetHandlerByEntity(iPluginId, iArgc) {
  static pEntity; pEntity = get_param_byref(1);

  static ClassInstance:pInstance; pInstance = @Entity_GetInstance(pEntity);
  if (pInstance == Invalid_ClassInstance) return CE_INVALID_ID;

  return ClassInstanceGetMember(pInstance, CE_MEMBER_ID);
}

public bool:Native_IsInstanceOf(iPluginId, iArgc) {
  static pEntity; pEntity = get_param_byref(1);
  static szClassname[CE_MAX_NAME_LENGTH]; get_string(2, szClassname, charsmax(szClassname));

  if (!@Entity_IsCustom(pEntity)) return false;

  static iTargetId; iTargetId = GetIdByClassName(szClassname);
  if (iTargetId == CE_INVALID_ID) return false;

  new ClassInstance:pInstance = @Entity_GetInstance(pEntity);

  return ClassInstanceIsInstanceOf(pInstance, g_rgEntities[iTargetId][Entity_Class]);
}

public bool:Native_HasMember(iPluginId, iArgc) {
  static pEntity; pEntity = get_param_byref(1);
  static szMember[CE_MAX_MEMBER_NAME_LENGTH]; get_string(2, szMember, charsmax(szMember));

  if (!@Entity_IsCustom(pEntity)) return false;

  new ClassInstance:pInstance = @Entity_GetInstance(pEntity);

  return ClassInstanceHasMember(pInstance, szMember);
}

public any:Native_GetMember(iPluginId, iArgc) {
  static pEntity; pEntity = get_param_byref(1);
  static szMember[CE_MAX_MEMBER_NAME_LENGTH]; get_string(2, szMember, charsmax(szMember));

  if (!@Entity_IsCustom(pEntity)) return 0;

  new ClassInstance:pInstance = @Entity_GetInstance(pEntity);

  return ClassInstanceGetMember(pInstance, szMember);
}

public Native_DeleteMember(iPluginId, iArgc) {
  static pEntity; pEntity = get_param_byref(1);
  static szMember[CE_MAX_MEMBER_NAME_LENGTH]; get_string(2, szMember, charsmax(szMember));

  if (!@Entity_IsCustom(pEntity)) return;

  new ClassInstance:pInstance = @Entity_GetInstance(pEntity);

  ClassInstanceDeleteMember(pInstance, szMember);
}

public Native_SetMember(iPluginId, iArgc) {
  static pEntity; pEntity = get_param_byref(1);
  static szMember[CE_MAX_MEMBER_NAME_LENGTH]; get_string(2, szMember, charsmax(szMember));
  static iValue; iValue = get_param(3);
  static bool:bReplace; bReplace = bool:get_param(4);

  if (!@Entity_IsCustom(pEntity)) return;

  new ClassInstance:pInstance = @Entity_GetInstance(pEntity);

  ClassInstanceSetMember(pInstance, szMember, iValue, bReplace);
}

public bool:Native_GetMemberVec(iPluginId, iArgc) {
  static pEntity; pEntity = get_param_byref(1);
  static szMember[CE_MAX_MEMBER_NAME_LENGTH]; get_string(2, szMember, charsmax(szMember));

  if (!@Entity_IsCustom(pEntity)) return false;

  new ClassInstance:pInstance = @Entity_GetInstance(pEntity);

  static Float:vecValue[3];
  if (!ClassInstanceGetMemberArray(pInstance, szMember, vecValue, 3)) return false;

  set_array_f(3, vecValue, sizeof(vecValue));

  return true;
}

public Native_SetMemberVec(iPluginId, iArgc) {
  static pEntity; pEntity = get_param_byref(1);
  static szMember[CE_MAX_MEMBER_NAME_LENGTH]; get_string(2, szMember, charsmax(szMember));
  static Float:vecValue[3]; get_array_f(3, vecValue, sizeof(vecValue));
  static bool:bReplace; bReplace = bool:get_param(4);

  if (!@Entity_IsCustom(pEntity)) return;

  new ClassInstance:pInstance = @Entity_GetInstance(pEntity);
  ClassInstanceSetMemberArray(pInstance, szMember, vecValue, 3, bReplace);
}

public bool:Native_GetMemberString(iPluginId, iArgc) {
  static pEntity; pEntity = get_param_byref(1);
  static szMember[CE_MAX_MEMBER_NAME_LENGTH]; get_string(2, szMember, charsmax(szMember));

  if (!@Entity_IsCustom(pEntity)) return false;

  new ClassInstance:pInstance = @Entity_GetInstance(pEntity);

  static szValue[128];
  if (!ClassInstanceGetMemberString(pInstance, szMember, szValue, charsmax(szValue))) return false;

  set_string(3, szValue, get_param(4));

  return true;
}

public Native_SetMemberString(iPluginId, iArgc) {
  static pEntity; pEntity = get_param_byref(1);
  static szMember[CE_MAX_MEMBER_NAME_LENGTH]; get_string(2, szMember, charsmax(szMember));
  static szValue[128]; get_string(3, szValue, charsmax(szValue));
  static bool:bReplace; bReplace = bool:get_param(4);
  
  if (!@Entity_IsCustom(pEntity)) return;

  new ClassInstance:pInstance = @Entity_GetInstance(pEntity);
  ClassInstanceSetMemberString(pInstance, szMember, szValue, bReplace);
}

public any:Native_CallMethod(iPluginId, iArgc) {
  static pEntity; pEntity = get_param_byref(1);
  static szMethod[CE_MAX_METHOD_NAME_LENGTH]; get_string(2, szMethod, charsmax(szMethod));

  static ClassInstance:pInstance; pInstance = @Entity_GetInstance(pEntity);

  STACK_PUSH(METHOD_PLUGIN, iPluginId);

  ClassInstanceCallMethodBegin(pInstance, szMethod);

  ClassInstanceCallMethodPushParamCell(pEntity);

  static iParam;
  for (iParam = 3; iParam <= iArgc; ++iParam) {
    ClassInstanceCallMethodPushNativeParam(iParam);
  }

  static any:result; result = ClassInstanceCallMethodEnd();

  STACK_POP(METHOD_PLUGIN);

  return result;
}

public any:Native_CallBaseMethod(iPluginId, iArgc) {
  static ClassInstance:pInstance; pInstance = ClassInstanceGetCurrent();
  static pEntity; pEntity = ClassInstanceGetMember(pInstance, CE_MEMBER_POINTER);

  STACK_PUSH(METHOD_PLUGIN, iPluginId);

  ClassInstanceCallMethodBeginBase();

  ClassInstanceCallMethodPushParamCell(pEntity);

  static iParam;
  for (iParam = 1; iParam <= iArgc; ++iParam) {
    ClassInstanceCallMethodPushNativeParam(iParam);
  }

  static any:result; result = ClassInstanceCallMethodEnd();

  STACK_POP(METHOD_PLUGIN);

  return result;
}

public Native_GetCallPluginId(iPluginId, iArgc) {
  return STACK_READ(METHOD_PLUGIN);
}

Class:ResolveEntityCallClass(const &pEntity, const szClassname[]) {
  if (!equal(szClassname, NULL_STRING)) {
    static iId; iId = GetIdByClassName(szClassname);
    return g_rgEntities[iId][Entity_Class];
  }

  static Class:cEntity; cEntity = ClassInstanceGetCurrentClass();
  if (cEntity != Invalid_Class) return cEntity;

  static ClassInstance:pInstance; pInstance = @Entity_GetInstance(pEntity);
  return ClassInstanceGetClass(pInstance);
}

public Native_SetThink(iPluginId, iArgc) {
  static pEntity; pEntity = get_param_byref(1);
  static szMethod[CE_MAX_METHOD_NAME_LENGTH]; get_string(2, szMethod, charsmax(szMethod));
  static szClassname[CE_MAX_NAME_LENGTH]; get_string(3, szClassname, charsmax(szClassname));

  static Class:cCurrent; cCurrent = ResolveEntityCallClass(pEntity, szClassname);

  if (!equal(szMethod, NULL_STRING)) {
    g_rgEntityMethodPointers[pEntity][EntityMethodPointer_Think] = ClassGetMethodPointer(cCurrent, szMethod);
  } else {
    g_rgEntityMethodPointers[pEntity][EntityMethodPointer_Think] = Invalid_Struct;
  }

  ClassGetMetadataString(cCurrent, CLASS_METADATA_NAME, szClassname, charsmax(szClassname));
}

public Native_SetTouch(iPluginId, iArgc) {
  static pEntity; pEntity = get_param_byref(1);
  static szMethod[CE_MAX_METHOD_NAME_LENGTH]; get_string(2, szMethod, charsmax(szMethod));
  static szClassname[CE_MAX_NAME_LENGTH]; get_string(3, szClassname, charsmax(szClassname));

  static Class:cCurrent; cCurrent = ResolveEntityCallClass(pEntity, szClassname);

  if (!equal(szMethod, NULL_STRING)) {
    g_rgEntityMethodPointers[pEntity][EntityMethodPointer_Touch] = ClassGetMethodPointer(cCurrent, szMethod);
  } else {
    g_rgEntityMethodPointers[pEntity][EntityMethodPointer_Touch] = Invalid_Struct;
  }
}

public Native_SetUse(iPluginId, iArgc) {
  static pEntity; pEntity = get_param_byref(1);
  static szMethod[CE_MAX_METHOD_NAME_LENGTH]; get_string(2, szMethod, charsmax(szMethod));
  static szClassname[CE_MAX_NAME_LENGTH]; get_string(3, szClassname, charsmax(szClassname));

  static Class:cCurrent; cCurrent = ResolveEntityCallClass(pEntity, szClassname);

  if (!equal(szMethod, NULL_STRING)) {
    g_rgEntityMethodPointers[pEntity][EntityMethodPointer_Use] = ClassGetMethodPointer(cCurrent, szMethod);
  } else {
    g_rgEntityMethodPointers[pEntity][EntityMethodPointer_Use] = Invalid_Struct;
  }
}

public Native_SetBlocked(iPluginId, iArgc) {
  static pEntity; pEntity = get_param_byref(1);
  static szMethod[CE_MAX_METHOD_NAME_LENGTH]; get_string(2, szMethod, charsmax(szMethod));
  static szClassname[CE_MAX_NAME_LENGTH]; get_string(3, szClassname, charsmax(szClassname));

  static Class:cCurrent; cCurrent = ResolveEntityCallClass(pEntity, szClassname);

  if (!equal(szMethod, NULL_STRING)) {
    g_rgEntityMethodPointers[pEntity][EntityMethodPointer_Blocked] = ClassGetMethodPointer(cCurrent, szMethod);
  } else {
    g_rgEntityMethodPointers[pEntity][EntityMethodPointer_Blocked] = Invalid_Struct;
  }
}

public any:Native_GetMethodReturn(iPluginId, iArgc) {
  return STACK_READ(METHOD_RETURN);
}

public any:Native_SetMethodReturn(iPluginId, iArgc) {
  STACK_PATCH(METHOD_RETURN, any:get_param(1));
}

/*--------------------------------[ Commands ]--------------------------------*/

public Command_Spawn(pPlayer, iLevel, iCId) {
  if (!cmd_access(pPlayer, iLevel, iCId, 2)) return PLUGIN_HANDLED;

  static szClassname[32]; read_argv(1, szClassname, charsmax(szClassname));

  if (equal(szClassname, NULL_STRING)) return PLUGIN_HANDLED;

  new Float:vecOrigin[3]; pev(pPlayer, pev_origin, vecOrigin);
  
  new pEntity = CreateEntity(szClassname, vecOrigin, true);
  if (pEntity == FM_NULLENT) return PLUGIN_HANDLED;

  new iArgsNum = read_argc();
  if (iArgsNum > 2) {
    new ClassInstance:pInstance = @Entity_GetInstance(pEntity);

    for (new iArg = 2; iArg < iArgsNum; iArg += 2) {
      static szMember[32]; read_argv(iArg, szMember, charsmax(szMember));
      static szValue[32]; read_argv(iArg + 1, szValue, charsmax(szValue));
      static iType; iType = UTIL_GetStringType(szValue);

      switch (iType) {
        case 'i': ClassInstanceSetMember(pInstance, szMember, str_to_num(szValue));
        case 'f': ClassInstanceSetMember(pInstance, szMember, str_to_float(szValue));
        case 's': ClassInstanceSetMemberString(pInstance, szMember, szValue);
      }
    }
  }

  dllfunc(DLLFunc_Spawn, pEntity);

  console_print(pPlayer, "Entity ^"%s^" successfully spawned! Entity index: %d", szClassname, pEntity);

  return PLUGIN_HANDLED;
}

public Command_GetMember(pPlayer, iLevel, iCId) {
  if (!cmd_access(pPlayer, iLevel, iCId, 3)) return PLUGIN_HANDLED;
  
  new pEntity = read_argv_int(1);

  new ClassInstance:pInstance = @Entity_GetInstance(pEntity);
  if (pInstance == Invalid_ClassInstance) {
    console_print(pPlayer, "Entity %d is not a custom entity", pEntity);
    return PLUGIN_HANDLED;
  }

  static szMember[CLASS_METHOD_MAX_NAME_LENGTH]; read_argv(2, szMember, charsmax(szMember));

  console_print(pPlayer, "Member ^"%s^" value: %d", szMember, ClassInstanceGetMember(pInstance, szMember));

  return PLUGIN_HANDLED;
}

public Command_GetMemberFloat(pPlayer, iLevel, iCId) {
  if (!cmd_access(pPlayer, iLevel, iCId, 3)) return PLUGIN_HANDLED;
  
  new pEntity = read_argv_int(1);

  new ClassInstance:pInstance = @Entity_GetInstance(pEntity);
  if (pInstance == Invalid_ClassInstance) {
    console_print(pPlayer, "Entity %d is not a custom entity", pEntity);
    return PLUGIN_HANDLED;
  }

  static szMember[CLASS_METHOD_MAX_NAME_LENGTH]; read_argv(2, szMember, charsmax(szMember));

  console_print(pPlayer, "Member ^"%s^" value: %f", szMember, Float:ClassInstanceGetMember(pInstance, szMember));

  return PLUGIN_HANDLED;
}

public Command_GetMemberString(pPlayer, iLevel, iCId) {
  if (!cmd_access(pPlayer, iLevel, iCId, 3)) return PLUGIN_HANDLED;
  
  new pEntity = read_argv_int(1);

  new ClassInstance:pInstance = @Entity_GetInstance(pEntity);
  if (pInstance == Invalid_ClassInstance) {
    console_print(pPlayer, "Entity %d is not a custom entity", pEntity);
    return PLUGIN_HANDLED;
  }

  static szMember[CLASS_METHOD_MAX_NAME_LENGTH]; read_argv(2, szMember, charsmax(szMember));

  static szValue[64]; ClassInstanceGetMemberString(pInstance, szMember, szValue, charsmax(szValue));
  console_print(pPlayer, "Member ^"%s^" value: ^"%s^"", szMember, szValue);

  return PLUGIN_HANDLED;
}

public Command_SetMember(pPlayer, iLevel, iCId) {
  if (!cmd_access(pPlayer, iLevel, iCId, 3)) return PLUGIN_HANDLED;

  new pEntity = read_argv_int(1);

  new ClassInstance:pInstance = @Entity_GetInstance(pEntity);
  if (pInstance == Invalid_ClassInstance) {
    console_print(pPlayer, "Entity %d is not a custom entity", pEntity);
    return PLUGIN_HANDLED;
  }

  static szMember[CLASS_METHOD_MAX_NAME_LENGTH]; read_argv(3, szMember, charsmax(szMember));

  static szValue[32]; read_argv(3, szValue, charsmax(szValue));
  static iType; iType = UTIL_GetStringType(szValue);

  switch (iType) {
    case 'i': ClassInstanceSetMember(pInstance, szMember, str_to_num(szValue));
    case 'f': ClassInstanceSetMember(pInstance, szMember, str_to_float(szValue));
    case 's': ClassInstanceSetMemberString(pInstance, szMember, szValue);
  }

  switch (iType) {
    case 'i', 'f': console_print(pPlayer, "^"%s^" member set to %s", szMember, szValue);
    case 's': console_print(pPlayer, "^"%s^" member set to ^"%s^"", szMember, szValue);
  }

  return PLUGIN_HANDLED;
}

public Command_CallMethod(pPlayer, iLevel, iCId) {
  if (!cmd_access(pPlayer, iLevel, iCId, 3)) return PLUGIN_HANDLED;

  new pEntity = read_argv_int(1);

  new ClassInstance:pInstance = @Entity_GetInstance(pEntity);
  if (pInstance == Invalid_ClassInstance) {
    console_print(pPlayer, "Entity %d is not a custom entity", pEntity);
    return PLUGIN_HANDLED;
  }

  static szClassname[32]; read_argv(2, szClassname, charsmax(szClassname));

  if (equal(szClassname, NULL_STRING)) return PLUGIN_HANDLED;

  new iId = GetIdByClassName(szClassname);
  if (iId == CE_INVALID_ID) return PLUGIN_HANDLED;

  if (!ClassInstanceIsInstanceOf(pInstance, g_rgEntities[iId][Entity_Class])) {
    console_print(pPlayer, "Entity %d is not instance of ^"%s^"", pEntity, szClassname);
    return PLUGIN_HANDLED;
  }

  static szMethod[CLASS_METHOD_MAX_NAME_LENGTH]; read_argv(3, szMethod, charsmax(szMethod));

  ClassInstanceCallMethodBegin(pInstance, szMethod, g_rgEntities[iId][Entity_Class]);

  ClassInstanceCallMethodPushParamCell(pEntity);

  new iArgsNum = read_argc();
  if (iArgsNum > 4) {
    for (new iArg = 4; iArg < iArgsNum; ++iArg) {
      static szArg[32]; read_argv(iArg, szArg, charsmax(szArg));
      static iType; iType = UTIL_GetStringType(szArg);

      switch (iType) {
        case 'i': ClassInstanceCallMethodPushParamCell(str_to_num(szArg));
        case 'f': ClassInstanceCallMethodPushParamCell(str_to_float(szArg));
        case 's': ClassInstanceCallMethodPushParamString(szArg);
      }
    }
  }

  new any:result = ClassInstanceCallMethodEnd();

  console_print(pPlayer, "Call ^"%s^" result: (int)%d (float)%f", szMethod, result, result);

  return PLUGIN_HANDLED;
}

public Command_List(pPlayer, iLevel, iCId) {
  if (!cmd_access(pPlayer, iLevel, iCId, 1)) return PLUGIN_HANDLED;

  new iArgsNum = read_argc();

  static szFilter[32]; 
  
  if (iArgsNum >= 2) {
    read_argv(1, szFilter, charsmax(szFilter));
  } else {
    copy(szFilter, charsmax(szFilter), "*");
  }

  new iStart = iArgsNum >= 3 ? read_argv_int(2) : 0;
  new iLimit = iArgsNum >= 4 ? read_argv_int(3) : 10;

  new iShowedEntitiesNum = 0;
  new iEntitiesNum = 0;

  // console_print(pPlayer, "Finding entities { Start: %d; Limit: %d; Filter: ^"%s^" }", iStart, iLimit, szFilter);
  // console_print(pPlayer, "---- Found entities ----");

  for (new pEntity = iStart; pEntity < sizeof(g_rgEntityClassInstances); ++pEntity) {
    if (g_rgEntityClassInstances[pEntity] == Invalid_ClassInstance) continue;

    static ClassInstance:pInstance; pInstance = g_rgEntityClassInstances[pEntity];
    static Class:class; class = ClassInstanceGetClass(pInstance);
    // static iId; iId = ClassGetMetadata(class, CLASS_METADATA_CE_ID);
    static szClassname[CE_MAX_NAME_LENGTH]; ClassGetMetadataString(class, CLASS_METADATA_NAME, szClassname, charsmax(szClassname));

    if (!equal(szFilter, "*") && strfind(szClassname, szFilter, true) == -1) continue;

    static Float:vecOrigin[3]; pev(pEntity, pev_origin, vecOrigin);

    if (iShowedEntitiesNum < iLimit) {
      console_print(pPlayer, "[%d]^t%s^t{%.3f, %.3f, %.3f}", pEntity, szClassname, vecOrigin[0], vecOrigin[1], vecOrigin[2]);
      iShowedEntitiesNum++;
    }

    iEntitiesNum++;
  }

  // console_print(pPlayer, "Found %d entities. %d of %d are entities showed.", iEntitiesNum, iShowedEntitiesNum, iEntitiesNum);

  return PLUGIN_HANDLED;
}

/*--------------------------------[ Hooks ]--------------------------------*/

public FMHook_OnFreeEntPrivateData(pEntity) {
  if (!pev_valid(pEntity)) return;

  if (@Entity_IsCustom(pEntity)) {
    ExecuteMethod(CEMethod_Free, pEntity);
  }
}

public FMHook_KeyValue(pEntity, hKVD) {
  @Entity_KeyValue(pEntity, hKVD);

  return FMRES_HANDLED;
}

public FMHook_Spawn(pEntity) {
  new ClassInstance:pInstance = @Entity_GetInstance(pEntity);

  // Update entity classname (in case entity spawned by the engine)
  if (pInstance != Invalid_ClassInstance) {
    static Class:class; class = ClassInstanceGetClass(pInstance);

    static szClassname[CE_MAX_NAME_LENGTH];
    ClassGetMetadataString(class, CLASS_METADATA_NAME, szClassname, charsmax(szClassname));
    set_pev(pEntity, pev_classname, szClassname);
  }
}

public HamHook_Base_Spawn(pEntity) {
  if (@Entity_IsCustom(pEntity)) {
    ExecuteMethod(CEMethod_Spawn, pEntity);

    return HAM_SUPERCEDE;
  }

  return HAM_IGNORED;
}

public HamHook_Base_ObjectCaps(pEntity) {
  if (@Entity_IsCustom(pEntity)) {
    new iObjectCaps = ExecuteMethod(CEMethod_ObjectCaps, pEntity);
    SetHamReturnInteger(iObjectCaps);

    return HAM_OVERRIDE;
  }

  return HAM_IGNORED;
}

public HamHook_Base_Restart_Post(pEntity) {
  if (@Entity_IsCustom(pEntity)) {
    ExecuteMethod(CEMethod_Restart, pEntity);

    return HAM_HANDLED;
  }

  return HAM_IGNORED;
}

public HamHook_Base_Touch_Post(pEntity, pToucher) {
  if (@Entity_IsCustom(pEntity)) {
    ExecuteMethod(CEMethod_Touch, pEntity, pToucher);

    return HAM_HANDLED;
  }

  return HAM_IGNORED;
}

public HamHook_Base_Use_Post(pEntity, pCaller, pActivator, iUseType, Float:flValue) {
  if (@Entity_IsCustom(pEntity)) {
    ExecuteMethod(CEMethod_Use, pEntity, pCaller, pActivator, iUseType, flValue);

    return HAM_HANDLED;
  }

  return HAM_IGNORED;
}

public HamHook_Base_Blocked_Post(pEntity, pOther) {
  if (@Entity_IsCustom(pEntity)) {
    ExecuteMethod(CEMethod_Blocked, pEntity, pOther);

    return HAM_HANDLED;
  }

  return HAM_IGNORED;
}

public HamHook_Base_Killed(pEntity, pKiller, iShouldGib) {
  if (@Entity_IsCustom(pEntity)) {
    ExecuteMethod(CEMethod_Killed, pEntity, pKiller, iShouldGib);

    return HAM_SUPERCEDE;
  }

  return HAM_IGNORED;
}

public HamHook_Base_Think(pEntity) {
  if (@Entity_IsCustom(pEntity)) {
    ExecuteMethod(CEMethod_Think, pEntity);

    return HAM_HANDLED;
  }

  return HAM_IGNORED;
}

public HamHook_Base_BloodColor(pEntity) {
  if (@Entity_IsCustom(pEntity)) {
    static iBloodColor; iBloodColor = ExecuteMethod(CEMethod_BloodColor, pEntity);
    SetHamReturnInteger(iBloodColor);

    return HAM_OVERRIDE;
  }

  return HAM_IGNORED;
}

public HamHook_Base_GetDelay(pEntity) {
  if (@Entity_IsCustom(pEntity)) {
    static Float:flDelay; flDelay = ExecuteMethod(CEMethod_GetDelay, pEntity);
    SetHamReturnFloat(flDelay);

    return HAM_OVERRIDE;
  }

  return HAM_IGNORED;
}

public HamHook_Base_Classify(pEntity) {
  if (@Entity_IsCustom(pEntity)) {
    static iClass; iClass = ExecuteMethod(CEMethod_Classify, pEntity);
    SetHamReturnInteger(iClass);

    return HAM_OVERRIDE;
  }

  return HAM_IGNORED;
}

public HamHook_Base_IsTriggered(pEntity, pActivator) {
  if (@Entity_IsCustom(pEntity)) {
    static iTriggered; iTriggered = ExecuteMethod(CEMethod_IsTriggered, pEntity, pActivator);
    SetHamReturnInteger(iTriggered);

    return HAM_OVERRIDE;
  }

  return HAM_IGNORED;
}

public HamHook_Base_GetToggleState(pEntity) {
  if (@Entity_IsCustom(pEntity)) {
    static iState; iState = ExecuteMethod(CEMethod_GetToggleState, pEntity);
    SetHamReturnInteger(iState);

    return HAM_OVERRIDE;
  }

  return HAM_IGNORED;
}

public HamHook_Base_SetToggleState(pEntity, iState) {
  if (@Entity_IsCustom(pEntity)) {
    ExecuteMethod(CEMethod_SetToggleState, pEntity, iState);

    return HAM_HANDLED;
  }

  return HAM_IGNORED;
}

public HamHook_Base_Respawn_Post(pEntity) {
  if (@Entity_IsCustom(pEntity)) {
    ExecuteMethod(CEMethod_Respawn, pEntity);

    return HAM_HANDLED;
  }

  return HAM_IGNORED;
}

public HamHook_Base_TraceAttack_Post(pEntity, pAttacker, Float:flDamage, const Float:vecDirection[3], pTrace, iDamageBits) {
  if (@Entity_IsCustom(pEntity)) {
    ExecuteMethod(CEMethod_TraceAttack, pEntity, pAttacker, flDamage, vecDirection, pTrace, iDamageBits);

    return HAM_HANDLED;
  }

  return HAM_IGNORED;
}

/*--------------------------------[ Entity Hookable Methods ]--------------------------------*/

@Entity_KeyValue(const &this, const &hKVD) {
  new szKey[32]; get_kvd(hKVD, KV_KeyName, szKey, charsmax(szKey));
  new szValue[32]; get_kvd(hKVD, KV_Value, szValue, charsmax(szValue));
  
  if (equal(szKey, "classname")) {
    new iId = GetIdByClassName(szValue);
    if (iId != CE_INVALID_ID) {
      // using set_kvd leads to duplicate kvd emit, this check will fix the issue
      if (@Entity_GetInstance(this) == Invalid_ClassInstance) {
        if (~g_rgEntities[iId][Entity_Flags] & EntityFlag_Abstract) {
          set_kvd(hKVD, KV_Value, CE_BASE_CLASSNAME);

          ExecuteMethod(CEMethod_Allocate, this, iId, false);
        }
      }
    } else {
        // if for some reason data was not assigned
        if (@Entity_GetInstance(this) != Invalid_ClassInstance) {
          ExecuteMethod(CEMethod_Free, this);
        }
    }
  }

  if (@Entity_GetInstance(this) != Invalid_ClassInstance) {
    @Entity_HandleKeyMemberBinding(this, szKey, szValue);
  }
}

@Entity_HandleKeyMemberBinding(const &this, const szKey[], const szValue[]) {
  new iResult = CE_IGNORED;

  new ClassInstance:pInstance = @Entity_GetInstance(this);
  
  new Array:irgHierarchy = Invalid_Array;
  new iHierarchySize = 0;

  {
    static Class:cClass; cClass = ClassInstanceGetClass(pInstance);

    static iId; iId = ClassGetMetadata(cClass, CLASS_METADATA_CE_ID);
    irgHierarchy = g_rgEntities[iId][Entity_Hierarchy];
    iHierarchySize = ArraySize(irgHierarchy);
  }

  for (new iHierarchyPos = 0; iHierarchyPos < iHierarchySize; ++iHierarchyPos) {
    static iId; iId = ArrayGetCell(irgHierarchy, iHierarchyPos);

    if (g_rgEntities[iId][Entity_KeyMemberBindings] == Invalid_Trie) continue;

    static Trie:itMemberTypes; itMemberTypes = Invalid_Trie;
    if (!TrieGetCell(g_rgEntities[iId][Entity_KeyMemberBindings], szKey, itMemberTypes)) continue;

    static TrieIter:itMemberTypesIter;

    for (itMemberTypesIter = TrieIterCreate(itMemberTypes); !TrieIterEnded(itMemberTypesIter); TrieIterNext(itMemberTypesIter)) {
      new szMember[32]; TrieIterGetKey(itMemberTypesIter, szMember, charsmax(szMember));
      new CEMemberType:iType; TrieIterGetCell(itMemberTypesIter, iType);

      // log_amx("%s => %s (%s, %d)", szKey, szMember, szValue, iType);

      switch (iType) {
        case CEMemberType_Cell: {
          ClassInstanceSetMember(pInstance, szMember, str_to_num(szValue));
        }
        case CEMemberType_Float: {
          ClassInstanceSetMember(pInstance, szMember, str_to_float(szValue));
        }
        case CEMemberType_String: {
          ClassInstanceSetMemberString(pInstance, szMember, szValue);
        }
        case CEMemberType_Vector: {
          new Float:vecValue[3];
          UTIL_ParseVector(szValue, vecValue);
          ClassInstanceSetMemberArray(pInstance, szMember, vecValue, 3);
        }
      }
    }

    TrieIterDestroy(itMemberTypesIter);
  }

  return iResult;
}

ClassInstance:@Entity_GetInstance(const &this) {
  return g_rgEntityClassInstances[this];
}

@Entity_IsCustom(const &this) {
  return g_rgEntityClassInstances[this] != Invalid_ClassInstance;
}

/*--------------------------------[ Base Class Methods ]--------------------------------*/

@Base_Allocate(const this) {}

@Base_Free(const this) {}

@Base_Spawn(const this) {
  set_pev(this, pev_deadflag, DEAD_NO);
  set_pev(this, pev_effects, pev(this, pev_effects) & ~EF_NODRAW);
  set_pev(this, pev_flags, pev(this, pev_flags) & ~FL_ONGROUND);
}

@Base_Respawn(const this) {
  dllfunc(DLLFunc_Spawn, this);

  return this;
}

@Base_TraceAttack(const this, const pAttacker, Float:flDamage, const Float:vecDirection[3], pTrace, iDamageBits) {}

@Base_Restart(this) {  
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
    ExecuteHamB(Ham_Respawn, this);
  }
}

@Base_ResetVariables(const this) {
  new ClassInstance:pInstance = ClassInstanceGetCurrent();

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

  ClassInstanceCallMethod(pInstance, CE_METHOD_NAMES[CEMethod_UpdatePhysics], this);
  ClassInstanceCallMethod(pInstance, CE_METHOD_NAMES[CEMethod_UpdateModel], this);
  ClassInstanceCallMethod(pInstance, CE_METHOD_NAMES[CEMethod_UpdateSize], this);
  
  static bool:bIsWorld; bIsWorld = ClassInstanceGetMember(pInstance, CE_MEMBER_WORLD);

  static Float:flLifeTime; flLifeTime = 0.0;
  if (!bIsWorld && ClassInstanceHasMember(pInstance, CE_MEMBER_LIFETIME)) {
    flLifeTime = ClassInstanceGetMember(pInstance, CE_MEMBER_LIFETIME);
  }

  if (flLifeTime > 0.0) {
    static Float:flGameTime; flGameTime = get_gametime();
    ClassInstanceSetMember(pInstance, CE_MEMBER_NEXTKILL, flGameTime + flLifeTime);
    set_pev(this, pev_nextthink, flGameTime + flLifeTime);
  } else {
    ClassInstanceSetMember(pInstance, CE_MEMBER_NEXTKILL, 0.0);
  }
}

@Base_UpdatePhysics(const this) {}

@Base_UpdateModel(this) {
  static ClassInstance:pInstance; pInstance = ClassInstanceGetCurrent();

  if (ClassInstanceHasMember(pInstance, CE_MEMBER_MODEL)) {
    static szModel[MAX_RESOURCE_PATH_LENGTH];
    ClassInstanceGetMemberString(pInstance, CE_MEMBER_MODEL, szModel, charsmax(szModel));
    engfunc(EngFunc_SetModel, this, szModel);
  }
}

@Base_UpdateSize(this) {
  static ClassInstance:pInstance; pInstance = ClassInstanceGetCurrent();

  if (ClassInstanceHasMember(pInstance, CE_MEMBER_MINS) && ClassInstanceHasMember(pInstance, CE_MEMBER_MAXS)) {
    static Float:vecMins[3]; ClassInstanceGetMemberArray(pInstance, CE_MEMBER_MINS, vecMins, 3);
    static Float:vecMaxs[3]; ClassInstanceGetMemberArray(pInstance, CE_MEMBER_MAXS, vecMaxs, 3);
    engfunc(EngFunc_SetSize, this, vecMins, vecMaxs);
  }
}

@Base_Killed(this, const &pKiller, iShouldGib) {
  static ClassInstance:pInstance; pInstance = ClassInstanceGetCurrent();

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
}

@Base_Think(this) {
  if (Struct:g_rgEntityMethodPointers[this][EntityMethodPointer_Think] != Invalid_Struct) {
    static ClassInstance:pInstance; pInstance = @Entity_GetInstance(this);
    ClassInstanceCallMethodByPointer(pInstance, Struct:g_rgEntityMethodPointers[this][EntityMethodPointer_Think], this);
  }
}

@Base_Touch(const this, pToucher) {
  if (Struct:g_rgEntityMethodPointers[this][EntityMethodPointer_Touch] != Invalid_Struct) {
    static ClassInstance:pInstance; pInstance = @Entity_GetInstance(this);
    ClassInstanceCallMethodByPointer(pInstance, Struct:g_rgEntityMethodPointers[this][EntityMethodPointer_Touch], this, pToucher);
  }
}

@Base_Use(const this, const pCaller, const pActivator, iUseType, Float:flValue) {
  if (Struct:g_rgEntityMethodPointers[this][EntityMethodPointer_Use] != Invalid_Struct) {
    static ClassInstance:pInstance; pInstance = @Entity_GetInstance(this);
    ClassInstanceCallMethodByPointer(pInstance, Struct:g_rgEntityMethodPointers[this][EntityMethodPointer_Use], this, pCaller, pActivator, iUseType, flValue);
  }
}

@Base_Blocked(const this, const pBlocker) {
  if (Struct:g_rgEntityMethodPointers[this][EntityMethodPointer_Blocked] != Invalid_Struct) {
    static ClassInstance:pInstance; pInstance = @Entity_GetInstance(this);
    ClassInstanceCallMethodByPointer(pInstance, Struct:g_rgEntityMethodPointers[this][EntityMethodPointer_Blocked], this, pBlocker);
  }
}

bool:@Base_IsMasterTriggered(const this, pActivator) {
  new ClassInstance:pInstance = ClassInstanceGetCurrent();

  static szMaster[32]; ClassInstanceGetMemberString(pInstance, CE_MEMBER_MASTER, szMaster, charsmax(szMaster));

  return UTIL_IsMasterTriggered(szMaster, pActivator);
}

@Base_ObjectCaps(const this) {
  new ClassInstance:pInstance = ClassInstanceGetCurrent();

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

@Base_BloodColor(const this) {
  new ClassInstance:pInstance = ClassInstanceGetCurrent();

  if (!ClassInstanceHasMember(pInstance, CE_MEMBER_BLOODCOLOR)) return -1;

  return ClassInstanceGetMember(pInstance, CE_MEMBER_BLOODCOLOR);
}

Float:@Base_GetDelay(const this) {
  static ClassInstance:pInstance; pInstance = ClassInstanceGetCurrent();

  return Float:ClassInstanceGetMember(pInstance, CE_MEMBER_DELAY);
}

@Base_Classify(const this) {
  return 0;
}

bool:@Base_IsTriggered(const this, const pActivator) {
  return true;
}

@Base_GetToggleState(const this) {
  static ClassInstance:pInstance; pInstance = ClassInstanceGetCurrent();

  return ClassInstanceGetMember(pInstance, CE_MEMBER_TOGGLESTATE);
}

@Base_SetToggleState(const this, iState) {
  static ClassInstance:pInstance; pInstance = ClassInstanceGetCurrent();

  ClassInstanceSetMember(pInstance, CE_MEMBER_TOGGLESTATE, iState);
}

/*--------------------------------[ BaseItem Class Methods ]--------------------------------*/

@BaseItem_Spawn(const this) {
  ClassInstanceCallBaseMethod(this);

  new ClassInstance:pInstance = ClassInstanceGetCurrent();
  ClassInstanceSetMember(pInstance, CE_MEMBER_PICKED, false);
}

@BaseItem_UpdatePhysics(const this) {
  ClassInstanceCallBaseMethod(this);

  set_pev(this, pev_solid, SOLID_TRIGGER);
  set_pev(this, pev_movetype, MOVETYPE_TOSS);
  set_pev(this, pev_takedamage, DAMAGE_NO);
}

@BaseItem_Touch(const this, const pToucher) {
  if (!IS_PLAYER(pToucher)) return;

  if (!ExecuteMethod(CEMethod_CanPickup, this, pToucher)) return;

  ExecuteMethod(CEMethod_Pickup, this, pToucher);

  static ClassInstance:pInstance; pInstance = ClassInstanceGetCurrent();
  ClassInstanceSetMember(pInstance, CE_MEMBER_PICKED, true);
  ExecuteHamB(Ham_Killed, this, pToucher, 0);
}

bool:@BaseItem_CanPickup(const this, const pToucher) {
  if (pev(this, pev_deadflag) != DEAD_NO) return false;
  if (~pev(this, pev_flags) & FL_ONGROUND) return false;

  return true;
}

@BaseItem_Pickup(const this, const pToucher) {}

/*--------------------------------[ BaseProp Class Methods ]--------------------------------*/

@BaseProp_UpdatePhysics(const this) {
  ClassInstanceCallBaseMethod(this);

  set_pev(this, pev_solid, SOLID_BBOX);
  set_pev(this, pev_movetype, MOVETYPE_FLY);
  set_pev(this, pev_takedamage, DAMAGE_NO);
}

/*--------------------------------[ BaseMonster Class Methods ]--------------------------------*/

@BaseMonster_Spawn(const this) {
  ClassInstanceCallBaseMethod(this);

  set_pev(this, pev_flags, pev(this, pev_flags) | FL_MONSTER);
}

@BaseMonster_UpdatePhysics(const this) {
  ClassInstanceCallBaseMethod(this);

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

/*--------------------------------[ BaseTrigger Class Methods ]--------------------------------*/

@BaseTrigger_Spawn(const this) {
  ClassInstanceCallBaseMethod(this);

  new ClassInstance:pInstance = ClassInstanceGetCurrent();  
  ClassInstanceSetMember(pInstance, CE_MEMBER_DELAY, 0.1);
}

@BaseTrigger_UpdatePhysics(const this) {
  ClassInstanceCallBaseMethod(this);

  set_pev(this, pev_solid, SOLID_TRIGGER);
  set_pev(this, pev_movetype, MOVETYPE_NONE);
  set_pev(this, pev_effects, EF_NODRAW);
}

bool:@BaseTrigger_IsTriggered(const this, const pActivator) {
  static ClassInstance:pInstance; pInstance = ClassInstanceGetCurrent();

  return ClassInstanceGetMember(pInstance, CE_MEMBER_TRIGGERED);
}

@BaseTrigger_Touch(const this, const pToucher) {
  if (ExecuteMethod(CEMethod_CanTrigger, this, pToucher)) {
    ExecuteMethod(CEMethod_Trigger, this, pToucher);
  }
}

bool:@BaseTrigger_CanTrigger(const this, const pActivator) {
  static Float:flNextThink; pev(this, pev_nextthink, flNextThink);

  if (flNextThink > get_gametime()) return false;

  if (!ExecuteMethod(CEMethod_IsMasterTriggered, this, pActivator)) return false;

  return true;
}

bool:@BaseTrigger_Trigger(const this, const pActivator) {
  static Float:flDelay; ExecuteHamB(Ham_GetDelay, this, flDelay);

  set_pev(this, pev_nextthink, get_gametime() + flDelay);

  return true;
}

/*--------------------------------[ BaseBSP Class Methods ]--------------------------------*/

@BaseBSP_UpdatePhysics(const this) {
  ClassInstanceCallBaseMethod(this);

  set_pev(this, pev_movetype, MOVETYPE_PUSH);
  set_pev(this, pev_solid, SOLID_BSP);
  set_pev(this, pev_flags, pev(this, pev_flags) | FL_WORLDBRUSH);
}

/*--------------------------------[ Functions ]--------------------------------*/

InitStorages() {
  g_itEntityIds = TrieCreate();

  for (new pEntity = 0; pEntity < sizeof(g_rgEntityClassInstances); ++pEntity) {
    g_rgEntityClassInstances[pEntity] = Invalid_ClassInstance;
    
    for (new EntityMethodPointer:iFunctionPointer = EntityMethodPointer:0; iFunctionPointer < EntityMethodPointer; ++iFunctionPointer) {
      g_rgEntityMethodPointers[pEntity][iFunctionPointer] = Invalid_Struct;
    }
  }
}

DestroyStorages() {
  TrieDestroy(g_itEntityIds);
}

InitBaseClasses() {
  new const BASE_ENTITY_NAMES[CEPreset][] = {
    "ce_base",
    "ce_baseitem",
    "ce_basemonster",
    "ce_baseprop",
    "ce_basetrigger",
    "ce_basebsp"
  };

  g_rgPresetEntityIds[CEPreset_Base] = RegisterEntityClass(BASE_ENTITY_NAMES[CEPreset_Base], CEPreset_Invalid, EntityFlag_Abstract);

  for (new CEPreset:iPreset = CEPreset:0; iPreset < CEPreset; ++iPreset) {
    if (iPreset == CEPreset_Base) continue;

    g_rgPresetEntityIds[iPreset] = RegisterEntityClass(BASE_ENTITY_NAMES[iPreset], CEPreset_Base, EntityFlag_Abstract);
  }

  ImplementEntityClassMethod(BASE_ENTITY_NAMES[CEPreset_Base], CEMethod_Allocate, get_func_pointer("@Base_Allocate"));
  ImplementEntityClassMethod(BASE_ENTITY_NAMES[CEPreset_Base], CEMethod_Free, get_func_pointer("@Base_Free"));
  ImplementEntityClassMethod(BASE_ENTITY_NAMES[CEPreset_Base], CEMethod_KeyValue, get_func_pointer("@Base_KeyValue"));
  ImplementEntityClassMethod(BASE_ENTITY_NAMES[CEPreset_Base], CEMethod_Spawn, get_func_pointer("@Base_Spawn"));
  ImplementEntityClassMethod(BASE_ENTITY_NAMES[CEPreset_Base], CEMethod_ResetVariables, get_func_pointer("@Base_ResetVariables"));
  ImplementEntityClassMethod(BASE_ENTITY_NAMES[CEPreset_Base], CEMethod_UpdatePhysics, get_func_pointer("@Base_UpdatePhysics"));
  ImplementEntityClassMethod(BASE_ENTITY_NAMES[CEPreset_Base], CEMethod_UpdateModel, get_func_pointer("@Base_UpdateModel"));
  ImplementEntityClassMethod(BASE_ENTITY_NAMES[CEPreset_Base], CEMethod_UpdateSize, get_func_pointer("@Base_UpdateSize"));
  ImplementEntityClassMethod(BASE_ENTITY_NAMES[CEPreset_Base], CEMethod_Touch, get_func_pointer("@Base_Touch"));
  ImplementEntityClassMethod(BASE_ENTITY_NAMES[CEPreset_Base], CEMethod_Think, get_func_pointer("@Base_Think"));
  ImplementEntityClassMethod(BASE_ENTITY_NAMES[CEPreset_Base], CEMethod_Restart, get_func_pointer("@Base_Restart"));
  ImplementEntityClassMethod(BASE_ENTITY_NAMES[CEPreset_Base], CEMethod_Killed, get_func_pointer("@Base_Killed"));
  ImplementEntityClassMethod(BASE_ENTITY_NAMES[CEPreset_Base], CEMethod_IsMasterTriggered, get_func_pointer("@Base_IsMasterTriggered"));
  ImplementEntityClassMethod(BASE_ENTITY_NAMES[CEPreset_Base], CEMethod_ObjectCaps, get_func_pointer("@Base_ObjectCaps"));
  ImplementEntityClassMethod(BASE_ENTITY_NAMES[CEPreset_Base], CEMethod_BloodColor, get_func_pointer("@Base_BloodColor"));
  ImplementEntityClassMethod(BASE_ENTITY_NAMES[CEPreset_Base], CEMethod_Use, get_func_pointer("@Base_Use"));
  ImplementEntityClassMethod(BASE_ENTITY_NAMES[CEPreset_Base], CEMethod_Blocked, get_func_pointer("@Base_Blocked"));
  ImplementEntityClassMethod(BASE_ENTITY_NAMES[CEPreset_Base], CEMethod_GetDelay, get_func_pointer("@Base_GetDelay"));
  ImplementEntityClassMethod(BASE_ENTITY_NAMES[CEPreset_Base], CEMethod_Classify, get_func_pointer("@Base_Classify"));
  ImplementEntityClassMethod(BASE_ENTITY_NAMES[CEPreset_Base], CEMethod_IsTriggered, get_func_pointer("@Base_IsTriggered"));
  ImplementEntityClassMethod(BASE_ENTITY_NAMES[CEPreset_Base], CEMethod_GetToggleState, get_func_pointer("@Base_GetToggleState"));
  ImplementEntityClassMethod(BASE_ENTITY_NAMES[CEPreset_Base], CEMethod_SetToggleState, get_func_pointer("@Base_SetToggleState"));
  ImplementEntityClassMethod(BASE_ENTITY_NAMES[CEPreset_Base], CEMethod_Respawn, get_func_pointer("@Base_Respawn"));
  ImplementEntityClassMethod(BASE_ENTITY_NAMES[CEPreset_Base], CEMethod_TraceAttack, get_func_pointer("@Base_TraceAttack"));

  RegisterEntityClassKeyMemberBinding(BASE_ENTITY_NAMES[CEPreset_Base], "origin", CE_MEMBER_ORIGIN, CEMemberType_Vector);
  RegisterEntityClassKeyMemberBinding(BASE_ENTITY_NAMES[CEPreset_Base], "angles", CE_MEMBER_ANGLES, CEMemberType_Vector);
  RegisterEntityClassKeyMemberBinding(BASE_ENTITY_NAMES[CEPreset_Base], "master", CE_MEMBER_MASTER, CEMemberType_String);
  RegisterEntityClassKeyMemberBinding(BASE_ENTITY_NAMES[CEPreset_Base], "targetname", CE_MEMBER_TARGETNAME, CEMemberType_String);
  RegisterEntityClassKeyMemberBinding(BASE_ENTITY_NAMES[CEPreset_Base], "target", CE_MEMBER_TARGET, CEMemberType_String);
  RegisterEntityClassKeyMemberBinding(BASE_ENTITY_NAMES[CEPreset_Base], "model", CE_MEMBER_MODEL, CEMemberType_String);

  ImplementEntityClassMethod(BASE_ENTITY_NAMES[CEPreset_Prop], CEMethod_UpdatePhysics, get_func_pointer("@BaseProp_UpdatePhysics"));

  ImplementEntityClassMethod(BASE_ENTITY_NAMES[CEPreset_Item], CEMethod_Spawn, get_func_pointer("@BaseItem_Spawn"));
  ImplementEntityClassMethod(BASE_ENTITY_NAMES[CEPreset_Item], CEMethod_Touch, get_func_pointer("@BaseItem_Touch"));
  ImplementEntityClassMethod(BASE_ENTITY_NAMES[CEPreset_Item], CEMethod_CanPickup, get_func_pointer("@BaseItem_CanPickup"));
  ImplementEntityClassMethod(BASE_ENTITY_NAMES[CEPreset_Item], CEMethod_Pickup, get_func_pointer("@BaseItem_Pickup"));
  ImplementEntityClassMethod(BASE_ENTITY_NAMES[CEPreset_Item], CEMethod_UpdatePhysics, get_func_pointer("@BaseItem_UpdatePhysics"));

  ImplementEntityClassMethod(BASE_ENTITY_NAMES[CEPreset_Monster], CEMethod_Spawn, get_func_pointer("@BaseMonster_Spawn"));
  ImplementEntityClassMethod(BASE_ENTITY_NAMES[CEPreset_Monster], CEMethod_UpdatePhysics, get_func_pointer("@BaseMonster_UpdatePhysics"));
  
  ImplementEntityClassMethod(BASE_ENTITY_NAMES[CEPreset_Trigger], CEMethod_Spawn, get_func_pointer("@BaseTrigger_Spawn"));
  ImplementEntityClassMethod(BASE_ENTITY_NAMES[CEPreset_Trigger], CEMethod_Touch, get_func_pointer("@BaseTrigger_Touch"));
  ImplementEntityClassMethod(BASE_ENTITY_NAMES[CEPreset_Trigger], CEMethod_CanTrigger, get_func_pointer("@BaseTrigger_CanTrigger"));
  ImplementEntityClassMethod(BASE_ENTITY_NAMES[CEPreset_Trigger], CEMethod_Trigger, get_func_pointer("@BaseTrigger_Trigger"));
  ImplementEntityClassMethod(BASE_ENTITY_NAMES[CEPreset_Trigger], CEMethod_UpdatePhysics, get_func_pointer("@BaseTrigger_UpdatePhysics"));
  ImplementEntityClassMethod(BASE_ENTITY_NAMES[CEPreset_Trigger], CEMethod_IsTriggered, get_func_pointer("@BaseTrigger_IsTriggered"));

  ImplementEntityClassMethod(BASE_ENTITY_NAMES[CEPreset_BSP], CEMethod_UpdatePhysics, get_func_pointer("@BaseBSP_UpdatePhysics"));
}

InitHooks() {
  register_forward(FM_Spawn, "FMHook_Spawn");
  register_forward(FM_KeyValue, "FMHook_KeyValue");
  register_forward(FM_OnFreeEntPrivateData, "FMHook_OnFreeEntPrivateData");
}

DestroyRegisteredClasses() {
  for (new iId = 0; iId < g_iEntityClassesNum; ++iId) {
    FreeEntityClass(g_rgEntities[iId][Entity_Class]);
  }
}

RegisterEntityClass(const szClassname[], CEPreset:iPreset = CEPreset_Invalid, const EntityFlags:iFlags = EntityFlag_None, const szParent[] = "") {
  new iId = g_iEntityClassesNum;

  new Class:cParent = Invalid_Class;

  if (!equal(szParent, NULL_STRING)) {
    new iParentId = CE_INVALID_ID;
    if (!TrieGetCell(g_itEntityIds, szParent, iParentId)) {
      log_error(AMX_ERR_NATIVE, ERROR_IS_NOT_REGISTERED_BASE, LOG_PREFIX, szParent);
      return CE_INVALID_ID;
    }

    cParent = g_rgEntities[iParentId][Entity_Class];
  } else if (iPreset != CEPreset_Invalid) {
    new iPresetEntityId = g_rgPresetEntityIds[iPreset];
    cParent = g_rgEntities[iPresetEntityId][Entity_Class];
  }

  new Class:cEntity = ClassCreate(cParent);
  ClassSetMetadataString(cEntity, CLASS_METADATA_NAME, szClassname);

  ClassSetMetadata(cEntity, CLASS_METADATA_CE_ID, iId);
  g_rgEntities[iId][Entity_Id] = iId;
  g_rgEntities[iId][Entity_Class] = cEntity;
  g_rgEntities[iId][Entity_Flags] = iFlags;
  g_rgEntities[iId][Entity_Hierarchy] = CreateClassHierarchyList(cEntity);
  g_rgEntities[iId][Entity_KeyMemberBindings] = Invalid_Trie;

  for (new CEMethod:iMethod = CEMethod:0; iMethod < CEMethod; ++iMethod) {
    g_rgEntities[iId][Entity_MethodPreHooks][iMethod] = Invalid_Array;
    g_rgEntities[iId][Entity_MethodPostHooks][iMethod] = Invalid_Array;
    g_rgEntities[iId][Entity_TotalHooksCounter][iMethod] = 0;
  }

  TrieSetCell(g_itEntityIds, szClassname, iId);

  g_iEntityClassesNum++;

  log_amx("%s Entity ^"%s^" successfully registred.", LOG_PREFIX, szClassname);

  return iId;
}

FreeEntityClass(&Class:cEntity) {
  new iId = ClassGetMetadata(cEntity, CLASS_METADATA_CE_ID);

  for (new CEMethod:iMethod = CEMethod:0; iMethod < CEMethod; ++iMethod) {
    if (g_rgEntities[iId][Entity_MethodPreHooks][iMethod] != Invalid_Array) {
      ArrayDestroy(g_rgEntities[iId][Entity_MethodPreHooks][iMethod]);
    }

    if (g_rgEntities[iId][Entity_MethodPostHooks][iMethod] != Invalid_Array) {
      ArrayDestroy(g_rgEntities[iId][Entity_MethodPostHooks][iMethod]);
    }
  }

  ArrayDestroy(g_rgEntities[iId][Entity_Hierarchy]);

  if (g_rgEntities[iId][Entity_KeyMemberBindings] != Invalid_Trie) {
    new TrieIter:itKeyMemberBindingsIter = TrieIterCreate(g_rgEntities[iId][Entity_KeyMemberBindings]);

    while (!TrieIterEnded(itKeyMemberBindingsIter)) {
      new Trie:itMemberTypes; TrieIterGetCell(itKeyMemberBindingsIter, itMemberTypes);
      TrieDestroy(itMemberTypes);
      TrieIterNext(itKeyMemberBindingsIter);
    }

    TrieIterDestroy(itKeyMemberBindingsIter);

    TrieDestroy(g_rgEntities[iId][Entity_KeyMemberBindings]);
  }

  ClassDestroy(cEntity);
}

InitMethodHamHook(CEMethod:iMethod) {
  if (!g_rgMethodHamHooks[iMethod]) {
    g_rgMethodHamHooks[iMethod] = RegisterMethodHamHook(iMethod);
  }
}

HamHook:RegisterMethodHamHook(CEMethod:iMethod) {
  switch (iMethod) {
    case CEMethod_Spawn: return RegisterHam(Ham_Spawn, CE_BASE_CLASSNAME, "HamHook_Base_Spawn", .Post = 0);
    case CEMethod_ObjectCaps: return RegisterHam(Ham_ObjectCaps, CE_BASE_CLASSNAME, "HamHook_Base_ObjectCaps", .Post = 0);
    case CEMethod_Touch: return RegisterHam(Ham_Touch, CE_BASE_CLASSNAME, "HamHook_Base_Touch_Post", .Post = 1);
    case CEMethod_Use: return RegisterHam(Ham_Use, CE_BASE_CLASSNAME, "HamHook_Base_Use_Post", .Post = 1);
    case CEMethod_Blocked: return RegisterHam(Ham_Blocked, CE_BASE_CLASSNAME, "HamHook_Base_Blocked_Post", .Post = 1);
    case CEMethod_Killed: return RegisterHam(Ham_Killed, CE_BASE_CLASSNAME, "HamHook_Base_Killed", .Post = 0);
    case CEMethod_Think: return RegisterHam(Ham_Think, CE_BASE_CLASSNAME, "HamHook_Base_Think", .Post = 0);
    case CEMethod_BloodColor: return RegisterHam(Ham_BloodColor, CE_BASE_CLASSNAME, "HamHook_Base_BloodColor", .Post = 0);
    case CEMethod_GetDelay: return RegisterHam(Ham_GetDelay, CE_BASE_CLASSNAME, "HamHook_Base_GetDelay", .Post = 0);
    case CEMethod_Classify: return RegisterHam(Ham_Classify, CE_BASE_CLASSNAME, "HamHook_Base_Classify", .Post = 0);
    case CEMethod_IsTriggered: return RegisterHam(Ham_IsTriggered, CE_BASE_CLASSNAME, "HamHook_Base_IsTriggered", .Post = 0);
    case CEMethod_GetToggleState: return RegisterHam(Ham_GetToggleState, CE_BASE_CLASSNAME, "HamHook_Base_GetToggleState", .Post = 0);
    case CEMethod_SetToggleState: return RegisterHam(Ham_SetToggleState, CE_BASE_CLASSNAME, "HamHook_Base_SetToggleState", .Post = 0);
    case CEMethod_Respawn: return RegisterHam(Ham_Respawn, CE_BASE_CLASSNAME, "HamHook_Base_Respawn_Post", .Post = 1);
    case CEMethod_TraceAttack: return RegisterHam(Ham_TraceAttack, CE_BASE_CLASSNAME, "HamHook_Base_TraceAttack_Post", .Post = 1);
    case CEMethod_Restart: {
      if (g_bIsCStrike) {
        return RegisterHam(Ham_CS_Restart, CE_BASE_CLASSNAME, "HamHook_Base_Restart_Post", .Post = 1);
      }
    }
  }

  return HamHook:0;
}

AddEntityClassMethod(const szClassname[], const szMethod[], const Function:fnCallback, Array:irgParamTypes, bool:bVirtual) {
  new iId = GetIdByClassName(szClassname);

  ClassAddMethod(g_rgEntities[iId][Entity_Class], szMethod, fnCallback, bVirtual, CMP_Cell, CMP_ParamsCellArray, irgParamTypes);
}

AddEntityClassNativeMethod(const &Class:class, CEMethod:iMethod, Function:fnCallback) {
  new Array:irgParams = ArrayCreate(_, 8);

  for (new iParam = 0; iParam < g_rgEntityMethodParams[iMethod][EntityMethodParams_Num]; ++iParam) {
    ArrayPushCell(irgParams, g_rgEntityMethodParams[iMethod][EntityMethodParams_Types][iParam]);
  }

  ClassAddMethod(class, CE_METHOD_NAMES[iMethod], fnCallback, true, CMP_Cell, CMP_ParamsCellArray, irgParams);

  ArrayDestroy(irgParams);

  InitMethodHamHook(iMethod);
}

ImplementEntityClassMethod(const szClassname[], const CEMethod:iMethod, const Function:fnCallback) {
  new iId = GetIdByClassName(szClassname);
  if (iId == CE_INVALID_ID) {
    log_error(AMX_ERR_NATIVE, ERROR_IS_NOT_REGISTERED, LOG_PREFIX, szClassname);
    return;
  }

  AddEntityClassNativeMethod(g_rgEntities[iId][Entity_Class], iMethod, fnCallback);
}

RegisterEntityClassKeyMemberBinding(const szClassname[], const szKey[], const szMember[], CEMemberType:iType) {
  new iId = GetIdByClassName(szClassname);
  if (iId == CE_INVALID_ID) {
    log_error(AMX_ERR_NATIVE, ERROR_IS_NOT_REGISTERED, LOG_PREFIX, szClassname);
    return;
  }

  if (g_rgEntities[iId][Entity_KeyMemberBindings] == Invalid_Trie) {
    g_rgEntities[iId][Entity_KeyMemberBindings] = TrieCreate();
  }

  new Trie:itMemberTypes = Invalid_Trie;
  if (!TrieGetCell(g_rgEntities[iId][Entity_KeyMemberBindings], szKey, itMemberTypes)) {
    itMemberTypes = TrieCreate();
    TrieSetCell(g_rgEntities[iId][Entity_KeyMemberBindings], szKey, itMemberTypes);
  }

  TrieSetCell(itMemberTypes, szMember, iType);
}

RemoveEntityClassKeyMemberBinding(const szClassname[], const szKey[], const szMember[]) {
  new iId = GetIdByClassName(szClassname);
  if (iId == CE_INVALID_ID) {
    log_error(AMX_ERR_NATIVE, ERROR_IS_NOT_REGISTERED, LOG_PREFIX, szClassname);
    return;
  }

  if (g_rgEntities[iId][Entity_KeyMemberBindings] == Invalid_Trie) return;

  new Trie:itMemberTypes = Invalid_Trie;
  if (!TrieGetCell(g_rgEntities[iId][Entity_KeyMemberBindings], szKey, itMemberTypes)) return;

  TrieDeleteKey(itMemberTypes, szMember);
}

RegisterEntityClassHook(const szClassname[], CEMethod:iMethod, const Function:fnCallback, bool:bPost) {
  new iId = GetIdByClassName(szClassname);
  if (iId == CE_INVALID_ID) {
    log_error(AMX_ERR_NATIVE, ERROR_IS_NOT_REGISTERED, LOG_PREFIX, szClassname);
    return CE_INVALID_HOOK_ID;
  }

  new Array:irgHooks = Invalid_Array;
  if (bPost) {
    if (g_rgEntities[iId][Entity_MethodPostHooks][iMethod] == Invalid_Array) {
      g_rgEntities[iId][Entity_MethodPostHooks][iMethod] = ArrayCreate();
    }

    irgHooks = g_rgEntities[iId][Entity_MethodPostHooks][iMethod];
  } else {
    if (g_rgEntities[iId][Entity_MethodPreHooks][iMethod] == Invalid_Array) {
      g_rgEntities[iId][Entity_MethodPreHooks][iMethod] = ArrayCreate();
    }

    irgHooks = g_rgEntities[iId][Entity_MethodPreHooks][iMethod];
  }
  
  // Incrementing hook counter for the class and all child classes
  {
    g_rgEntities[iId][Entity_TotalHooksCounter][iMethod]++;

    for (new iOtherId = iId + 1; iOtherId < g_iEntityClassesNum; ++iOtherId) {
      ClassIsChildOf(g_rgEntities[iOtherId][Entity_Class], g_rgEntities[iId][Entity_Class]);
      g_rgEntities[iOtherId][Entity_TotalHooksCounter][iMethod]++;
    }
  }

  new iHookId = ArrayPushCell(irgHooks, fnCallback);

  return iHookId;
}

CreateEntity(const szClassname[], const Float:vecOrigin[3], bool:bTemp) {
  new iId = GetIdByClassName(szClassname);
  if (iId == CE_INVALID_ID) {
    log_error(AMX_ERR_NATIVE, ERROR_CANNOT_CREATE_UNREGISTERED, LOG_PREFIX, szClassname);
    return FM_NULLENT;
  }

  static EntityFlags:iFlags; iFlags = g_rgEntities[iId][Entity_Flags];
  if (iFlags & EntityFlag_Abstract) {
    log_error(AMX_ERR_NATIVE, ERROR_CANNOT_CREATE_ABSTRACT, LOG_PREFIX, szClassname);
    return FM_NULLENT;
  }

  new this = engfunc(EngFunc_CreateNamedEntity, g_iszBaseClassName);
  set_pev(this, pev_classname, szClassname);
  engfunc(EngFunc_SetOrigin, this, vecOrigin);
  // set_pev(this, pev_flags, pev(this, pev_flags) & ~FL_ONGROUND);

  ExecuteMethod(CEMethod_Allocate, this, iId, bTemp);

  new ClassInstance:pInstance = @Entity_GetInstance(this);
  ClassInstanceSetMemberArray(pInstance, CE_MEMBER_ORIGIN, vecOrigin, 3);

  return this;
}

GetIdByClassName(const szClassname[]) {
  static iId;
  if (!TrieGetCell(g_itEntityIds, szClassname, iId)) return CE_INVALID_ID;

  return iId;
}

/*
  price - 0.0011
    engine func price - 0.0004
    hooks price - 0.0003 ms
    method call price - 0.0005 ms
      CallEntityMethodHook price - 0.00015 ms
*/
#define HOOKABLE_METHOD_IMPLEMENTATION(%1,%2,%0) {\
  static iPreHookResult; iPreHookResult = CallEntityMethodHook(%2, %1, false, %0);\
  STACK_PUSH(PREHOOK_RETURN, iPreHookResult); \
  \
  static ClassInstance:pInstance; pInstance = @Entity_GetInstance(%2);\
  \
  static any:result;\
  if (STACK_READ(PREHOOK_RETURN) != CE_SUPERCEDE) result = ClassInstanceCallMethod(pInstance, CE_METHOD_NAMES[%1], %2, %0);\
  if (STACK_POP(PREHOOK_RETURN) <= CE_HANDLED) STACK_PATCH(METHOD_RETURN, result);\
  \
  CallEntityMethodHook(%2, %1, true, %0);\
}

any:ExecuteMethod(CEMethod:iMethod, const &pEntity, any:...) {
  STACK_PUSH(METHOD_RETURN, 0);

  switch (iMethod) {
    case CEMethod_Allocate: {
      new iId = getarg(2);

      g_rgEntityClassInstances[pEntity] = ClassInstanceCreate(g_rgEntities[iId][Entity_Class]);
      ClassInstanceSetMember(g_rgEntityClassInstances[pEntity], CE_MEMBER_ID, iId);
      ClassInstanceSetMember(g_rgEntityClassInstances[pEntity], CE_MEMBER_POINTER, pEntity);
      ClassInstanceSetMember(g_rgEntityClassInstances[pEntity], CE_MEMBER_IGNOREROUNDS, false);
      ClassInstanceSetMember(g_rgEntityClassInstances[pEntity], CE_MEMBER_WORLD, !getarg(3));

      HOOKABLE_METHOD_IMPLEMENTATION(CEMethod_Allocate, pEntity, 0)
    }
    case CEMethod_Free: {
      HOOKABLE_METHOD_IMPLEMENTATION(CEMethod_Free, pEntity, 0)

      ClassInstanceDestroy(g_rgEntityClassInstances[pEntity]);
      g_rgEntityClassInstances[pEntity] = Invalid_ClassInstance;
    }
    case CEMethod_KeyValue: {
      HOOKABLE_METHOD_IMPLEMENTATION(CEMethod_KeyValue, pEntity, getarg(2))
    }
    case CEMethod_SpawnInit: {
      HOOKABLE_METHOD_IMPLEMENTATION(CEMethod_SpawnInit, pEntity, 0)
    }
    case CEMethod_Spawn: {
      if (!pev_valid(pEntity) || pev(pEntity, pev_flags) & FL_KILLME) return 0;

      ExecuteMethod(CEMethod_ResetVariables, pEntity);

      HOOKABLE_METHOD_IMPLEMENTATION(CEMethod_Spawn, pEntity, 0)
      
      new ClassInstance:pInstance = @Entity_GetInstance(pEntity);
      ClassInstanceSetMember(pInstance, CE_MEMBER_LASTSPAWN, get_gametime());
    }
    case CEMethod_ResetVariables: {
      HOOKABLE_METHOD_IMPLEMENTATION(CEMethod_ResetVariables, pEntity, 0)
    }
    case CEMethod_UpdatePhysics: {
      HOOKABLE_METHOD_IMPLEMENTATION(CEMethod_UpdatePhysics, pEntity, 0)
    }
    case CEMethod_UpdateModel: {
      HOOKABLE_METHOD_IMPLEMENTATION(CEMethod_UpdateModel, pEntity, 0)
    }
    case CEMethod_UpdateSize: {
      HOOKABLE_METHOD_IMPLEMENTATION(CEMethod_UpdateSize, pEntity, 0)
    }
    case CEMethod_Touch: {
      HOOKABLE_METHOD_IMPLEMENTATION(CEMethod_Touch, pEntity, getarg(2))
    }
    case CEMethod_Think: {
      if (pev(pEntity, pev_flags) & FL_KILLME) return 0;

      static iDeadFlag; iDeadFlag = pev(pEntity, pev_deadflag);

      switch (iDeadFlag) {
        case DEAD_NO: {
          static ClassInstance:pInstance; pInstance = @Entity_GetInstance(pEntity);
          static Float:flNextKill; flNextKill = ClassInstanceGetMember(pInstance, CE_MEMBER_NEXTKILL);
          if (flNextKill > 0.0 && flNextKill <= get_gametime()) {
            ExecuteHamB(Ham_Killed, pEntity, 0, 0);
          }
        }
        case DEAD_RESPAWNABLE: {
          static ClassInstance:pInstance; pInstance = @Entity_GetInstance(pEntity);
          static Float:flNextRespawn; flNextRespawn = ClassInstanceGetMember(pInstance, CE_MEMBER_NEXTRESPAWN);
          if (flNextRespawn <= get_gametime()) {
            ExecuteHamB(Ham_Respawn, pEntity);
          }
        }
      }

      HOOKABLE_METHOD_IMPLEMENTATION(CEMethod_Think, pEntity, 0)
    }
    case CEMethod_CanPickup: {
      HOOKABLE_METHOD_IMPLEMENTATION(CEMethod_CanPickup, pEntity, getarg(2))
    }
    case CEMethod_Pickup: {
      HOOKABLE_METHOD_IMPLEMENTATION(CEMethod_Pickup, pEntity, getarg(2))
    }
    case CEMethod_CanTrigger: {
      HOOKABLE_METHOD_IMPLEMENTATION(CEMethod_CanTrigger, pEntity, getarg(2))
    }
    case CEMethod_Trigger: {
      HOOKABLE_METHOD_IMPLEMENTATION(CEMethod_Trigger, pEntity, getarg(2))
    }
    case CEMethod_Restart: {
      HOOKABLE_METHOD_IMPLEMENTATION(CEMethod_Restart, pEntity, 0)
    }
    case CEMethod_Killed: {
      HOOKABLE_METHOD_IMPLEMENTATION(CEMethod_Killed, pEntity, getarg(2), getarg(3))
    }
    case CEMethod_IsMasterTriggered: {
      HOOKABLE_METHOD_IMPLEMENTATION(CEMethod_IsMasterTriggered, pEntity, getarg(2))
    }
    case CEMethod_ObjectCaps: {
      HOOKABLE_METHOD_IMPLEMENTATION(CEMethod_ObjectCaps, pEntity, 0)
    }
    case CEMethod_BloodColor: {
      HOOKABLE_METHOD_IMPLEMENTATION(CEMethod_BloodColor, pEntity, 0)
    }
    case CEMethod_Use: {
      HOOKABLE_METHOD_IMPLEMENTATION(CEMethod_Use, pEntity, getarg(2), getarg(3), getarg(4), Float:getarg(5))
    }
    case CEMethod_Blocked: {
      HOOKABLE_METHOD_IMPLEMENTATION(CEMethod_Blocked, pEntity, getarg(2))
    }
    case CEMethod_GetDelay: {
      HOOKABLE_METHOD_IMPLEMENTATION(CEMethod_GetDelay, pEntity, 0)
    }
    case CEMethod_Classify: {
      HOOKABLE_METHOD_IMPLEMENTATION(CEMethod_Classify, pEntity, 0)
    }
    case CEMethod_IsTriggered: {
      HOOKABLE_METHOD_IMPLEMENTATION(CEMethod_IsTriggered, pEntity, getarg(2))
    }
    case CEMethod_GetToggleState: {
      HOOKABLE_METHOD_IMPLEMENTATION(CEMethod_GetToggleState, pEntity, 0)
    }
    case CEMethod_SetToggleState: {
      HOOKABLE_METHOD_IMPLEMENTATION(CEMethod_SetToggleState, pEntity, getarg(2))
    }
    case CEMethod_Respawn: {
      HOOKABLE_METHOD_IMPLEMENTATION(CEMethod_Respawn, pEntity, 0)
    }
    case CEMethod_TraceAttack: {
      new Float:vecDirection[3]; xs_vec_set(vecDirection, Float:getarg(4, 0), Float:getarg(4, 1), Float:getarg(4, 2));
      HOOKABLE_METHOD_IMPLEMENTATION(CEMethod_TraceAttack, pEntity, getarg(2), Float:getarg(3), vecDirection, getarg(5), getarg(6))
    }
  }

  return STACK_POP(METHOD_RETURN);
}

CallEntityMethodHook(const &pEntity, CEMethod:iMethod, const bool:bPost, any:...) {
  static const iParamOffset = 3;

  static ClassInstance:pInstance; pInstance = @Entity_GetInstance(pEntity);
  static Class:cClass; cClass = ClassInstanceGetClass(pInstance);

  static iId; iId = ClassGetMetadata(cClass, CLASS_METADATA_CE_ID);
  if (!g_rgEntities[iId][Entity_TotalHooksCounter][iMethod]) return CE_IGNORED;
  
  new iResult = CE_IGNORED;

  new Array:irgHierarchy = g_rgEntities[iId][Entity_Hierarchy];
  new iHierarchySize = ArraySize(irgHierarchy);

  new Array:irgHooks = Invalid_Array;
  new irgHooksNum = 0;

  for (new iHierarchyPos = 0; iHierarchyPos < iHierarchySize; ++iHierarchyPos) {
    static iId; iId = ArrayGetCell(irgHierarchy, iHierarchyPos);

    irgHooks = (
      bPost
        ? g_rgEntities[iId][Entity_MethodPostHooks][iMethod]
        : g_rgEntities[iId][Entity_MethodPreHooks][iMethod]
    );

    if (irgHooks == Invalid_Array) continue;

    irgHooksNum = ArraySize(irgHooks);

    for (new iHookId = 0; iHookId < irgHooksNum; ++iHookId) {
      static Function:fnCallback; fnCallback = ArrayGetCell(irgHooks, iHookId);

      if (callfunc_begin_p(fnCallback) == 1)  {
        callfunc_push_int(pEntity);

        static iParam;
        for (iParam = 0; iParam < g_rgEntityMethodParams[iMethod][EntityMethodParams_Num]; ++iParam) {
          switch (g_rgEntityMethodParams[iMethod][EntityMethodParams_Types][iParam]) {
            case CMP_Cell: {
              callfunc_push_int(getarg(iParam + iParamOffset));
            }
            case CMP_String: {
              static szBuffer[MAX_STRING_LENGTH];

              static iPos;
              for (iPos = 0; iPos < charsmax(szBuffer); ++iPos) {
                szBuffer[iPos] = getarg(iParam + iParamOffset, iPos);
                if (szBuffer[iPos] == '^0') break;
              }

              callfunc_push_str(szBuffer, false);
            }
            case CMP_Array: {
              static iSize; iSize = g_rgEntityMethodParams[iMethod][EntityMethodParams_Types][++iParam];

              for (new iIndex = 0; iIndex < iSize; ++iIndex) {
                callfunc_push_int(any:getarg(iParam + iParamOffset, iIndex));
              }
            }
            // TODO: Implement other types
          }
        }

        iResult = max(callfunc_end(), iResult);
      }
    }
  }

  return iResult;
}

Array:CreateClassHierarchyList(const &Class:class) {
  new Array:irgHierarchy = ArrayCreate();

  new iSize = 0;

  for (new Class:cCurrent = class; cCurrent != Invalid_Class; cCurrent = ClassGetBaseClass(cCurrent)) {
    new iId = ClassGetMetadata(cCurrent, CLASS_METADATA_CE_ID);
    if (iId == CE_INVALID_ID) continue;

    if (iSize) {
      ArrayInsertCellBefore(irgHierarchy, 0, iId);
    } else {
      ArrayPushCell(irgHierarchy, iId);
    }

    iSize++;
  }

  return irgHierarchy;
}

Array:ReadMethodParamsFromNativeCall(iStartArg, iArgc) {
  static Array:irgParams; irgParams = ArrayCreate();

  for (new iParam = iStartArg; iParam <= iArgc; ++iParam) {
    static iType; iType = get_param_byref(iParam);

    switch (iType) {
      case CE_MP_Cell: {
        ArrayPushCell(irgParams, CMP_Cell);
      }
      case CE_MP_String: {
        ArrayPushCell(irgParams, CMP_String);
      }
      case CE_MP_Array: {
        ArrayPushCell(irgParams, CMP_Array);
        ArrayPushCell(irgParams, get_param_byref(iParam + 1));
        iParam++;
      }
      case CE_MP_Vector: {
        ArrayPushCell(irgParams, CMP_Array);
        ArrayPushCell(irgParams, 3);
      }
    }
  }

  return irgParams;
}

/*--------------------------------[ Stocks ]--------------------------------*/

stock UTIL_ParseVector(const szBuffer[], Float:vecOut[3]) {
  static rgszOrigin[3][8];
  parse(szBuffer, rgszOrigin[0], charsmax(rgszOrigin[]), rgszOrigin[1], charsmax(rgszOrigin[]), rgszOrigin[2], charsmax(rgszOrigin[]));

  for (new i = 0; i < 3; ++i) {
    vecOut[i] = str_to_float(rgszOrigin[i]);
  }
}

stock bool:UTIL_IsMasterTriggered(const szMaster[], const &pActivator) {
  if (equal(szMaster, NULL_STRING)) return false;

  new pMaster = engfunc(EngFunc_FindEntityByString, 0, "targetname", szMaster);
  if (pMaster && (ExecuteHam(Ham_ObjectCaps, pMaster) & FCAP_MASTER)) {
    return !!ExecuteHamB(Ham_IsTriggered, pMaster, pActivator);
  }

  return true;
}

stock UTIL_GetStringType(const szString[]) {
  enum {
    string_type = 's',
    integer_type = 'i',
    float_type = 'f'
  };

  static bool:bIsFloat; bIsFloat = false;

  for (new i = 0; szString[i] != '^0'; ++i) {
    if (isalpha(szString[i])) return string_type;

    if (szString[i] == '.') {
      if (bIsFloat) return string_type;

      bIsFloat = true;
    }
  }

  return bIsFloat ? float_type : integer_type;
}
