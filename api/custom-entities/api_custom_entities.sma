#pragma semicolon 1

#include <amxmodx>
#include <amxmisc>
#include <engine>
#include <fakemeta>
#include <hamsandwich>
#tryinclude <datapack>
#include <xs>

#include <datapack_stocks>

#include <api_custom_entities_const>

#define DEFAULT_CELL_VALUE 0
#define DEFAULT_FLOAT_VALUE 0.0
#define DEFAULT_STRING_VALUE NULL_STRING

#define LOG_PREFIX "[CE]"

#if !defined _datapack_included
  enum DataPack { Invalid_DataPack = 0 }
#endif

enum _:GLOBALESTATE { GLOBAL_OFF = 0, GLOBAL_ON = 1, GLOBAL_DEAD = 2 };

enum MethodParam {
  MethodParam_Type = 0,
  MethodParam_Size
};

enum MethodCallStackItem {
  MethodCallStackItem_Entity,
  MethodCallStackItem_EntityID,
  MethodCallStackItem_Method
};

enum Entity {
  Array:Entity_Name,
  Array:Entity_Preset,
  Array:Entity_Parent,
  Array:Entity_Hooks[CEFunction],
  Array:Entity_Methods,
  Array:Entity_Hierarchy
};

enum EntityHook {
  EntityHook_PluginID,
  EntityHook_FuncID
};

enum Method {
  Method_PluginID,
  Method_FunctionID,
  bool:Method_IsVirtual,
  Array:Method_ParamTypes
};

#if defined _datapack_included
  new g_szBuffer[MAX_STRING_LENGTH];
  new g_rgiBuffer[MAX_STRING_LENGTH];
  new Float:g_rgflBuffer[MAX_STRING_LENGTH];
#endif

new g_iszBaseClassName;

new Trie:g_itPData = Invalid_Trie;
new Trie:g_itEntityIds = Invalid_Trie;
new g_rgEntity[Entity] = { Invalid_Array, ... };
new g_iEntitiesNum = 0;
new bool:g_bPrecaching = true;
new bool:g_bIsCStrike = false;

new DataPack:g_dpParams = Invalid_DataPack;

new Array:g_irgMethodCallStack = Invalid_Array;
new Array:g_irgMethods = Invalid_Array;
new Trie:g_itMethods = Invalid_Trie;

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
  g_bPrecaching = false;

  register_plugin("[API] Custom Entities", "2.0.0", "Hedgehog Fog");

  register_concmd("ce_spawn", "Command_Spawn", ADMIN_CVAR);

  #if !defined _datapack_included
    log_amx("%s Warning! This version is compiled without ^"datapack^" support. Method arguments are not supported!", LOG_PREFIX);
  #endif
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
}

public plugin_end() {
  DestroyStorages();
}

/*--------------------------------[ Natives ]--------------------------------*/

public Native_Register(iPluginId, iArgc) {
  new szClassName[CE_MAX_NAME_LENGTH]; get_string(1, szClassName, charsmax(szClassName));
  new CEPreset:iPreset = CEPreset:get_param(2);
  
  return RegisterEntity(szClassName, iPreset);
}

public Native_RegisterDerived(iPluginId, iArgc) {
  new szClassName[CE_MAX_NAME_LENGTH]; get_string(1, szClassName, charsmax(szClassName));
  new szBaseClassName[CE_MAX_NAME_LENGTH]; get_string(2, szBaseClassName, charsmax(szBaseClassName));
  
  return RegisterEntity(szClassName, _, szBaseClassName);
}

public Native_Create(iPluginId, iArgc) {
  static szClassName[CE_MAX_NAME_LENGTH]; get_string(1, szClassName, charsmax(szClassName));
  static Float:vecOrigin[3]; get_array_f(2, vecOrigin, 3);
  static bool:bTemp; bTemp = !!get_param(3);

  static pEntity; pEntity = @Entity_Create(szClassName, vecOrigin, bTemp);
  if (pEntity) {
    static Trie:itPData; itPData = @Entity_GetPData(pEntity);
    SetPDataMember(itPData, CE_MEMBER_PLUGINID, iPluginId);
  }

  return pEntity;
}

public Native_Kill(iPluginId, iArgc) {
  static pEntity; pEntity = get_param(1);
  static pKiller; pKiller = get_param(2);

  if (!@Entity_IsCustom(pEntity)) return;

  @Entity_Kill(pEntity, pKiller, false);
}

public bool:Native_Remove(iPluginId, iArgc) {
  static pEntity; pEntity = get_param(1);

  if (!@Entity_IsCustom(pEntity)) return;

  set_pev(pEntity, pev_flags, pev(pEntity, pev_flags) | FL_KILLME);
  dllfunc(DLLFunc_Think, pEntity);
}

public Native_Restart(iPluginId, iArgc) {
  static pEntity; pEntity = get_param(1);

  if (!@Entity_IsCustom(pEntity)) return;

  @Entity_Restart(pEntity);
}

public Native_RegisterHook(iPluginId, iArgc) {
  new szClassname[CE_MAX_NAME_LENGTH]; get_string(1, szClassname, charsmax(szClassname));
  new CEFunction:iFunction = CEFunction:get_param(2);
  new szCallback[CE_MAX_CALLBACK_LENGTH]; get_string(3, szCallback, charsmax(szCallback));

  RegisterEntityHook(iFunction, szClassname, szCallback, iPluginId);
}

public Native_RegisterMethod(iPluginId, iArgc) {
  new szClassName[CE_MAX_NAME_LENGTH]; get_string(1, szClassName, charsmax(szClassName));
  new szMethod[CE_MAX_METHOD_NAME_LENGTH]; get_string(2, szMethod, charsmax(szMethod));
  new szCallback[CE_MAX_CALLBACK_LENGTH]; get_string(3, szCallback, charsmax(szCallback));

  new Array:irgParamTypes; irgParamTypes = ArrayCreate(_:MethodParam, iArgc - 1);

  for (new iParam = 4; iParam <= iArgc; ++iParam) {
    new rgParam[MethodParam];
    rgParam[MethodParam_Type] = get_param_byref(iParam);
    rgParam[MethodParam_Size] = 1;

    switch (rgParam[MethodParam_Type]) {
      case CE_MP_Array, CE_MP_FloatArray: {
        rgParam[MethodParam_Size] = get_param_byref(iParam + 1);
        iParam++;
      }
    }

    ArrayPushArray(irgParamTypes, rgParam[any:0], _:MethodParam);
  }

  RegisterEntityMethod(szClassName, szMethod, szCallback, iPluginId, irgParamTypes, false);
}

public Native_RegisterVirtualMethod(iPluginId, iArgc) {
  new szClassName[CE_MAX_NAME_LENGTH]; get_string(1, szClassName, charsmax(szClassName));
  new szMethod[CE_MAX_METHOD_NAME_LENGTH]; get_string(2, szMethod, charsmax(szMethod));
  new szCallback[CE_MAX_CALLBACK_LENGTH]; get_string(3, szCallback, charsmax(szCallback));

  new Array:irgParamTypes; irgParamTypes = ArrayCreate(_:MethodParam, iArgc - 1);

  for (new iParam = 4; iParam <= iArgc; ++iParam) {
    new rgParam[MethodParam];
    rgParam[MethodParam_Type] = get_param_byref(iParam);
    rgParam[MethodParam_Size] = 1;

    switch (rgParam[MethodParam_Type]) {
      case CE_MP_Array, CE_MP_FloatArray: {
        rgParam[MethodParam_Size] = get_param_byref(iParam + 1);
        iParam++;
      }
    }

    ArrayPushArray(irgParamTypes, rgParam[any:0], _:MethodParam);
  }

  RegisterEntityMethod(szClassName, szMethod, szCallback, iPluginId, irgParamTypes, true);
}

public Native_GetHandler(iPluginId, iArgc) {
  static szClassName[CE_MAX_NAME_LENGTH]; get_string(1, szClassName, charsmax(szClassName));

  return GetIdByClassName(szClassName);
}

public Native_GetHandlerByEntity(iPluginId, iArgc) {
  static pEntity; pEntity = get_param(1);

  if (!@Entity_IsCustom(pEntity)) return -1;

  static Trie:itPData; itPData = @Entity_GetPData(pEntity);

  return GetPDataMember(itPData, CE_MEMBER_ID);
}

public bool:Native_IsInstanceOf(iPluginId, iArgc) {
  static pEntity; pEntity = get_param(1);
  static szClassName[CE_MAX_NAME_LENGTH]; get_string(2, szClassName, charsmax(szClassName));

  if (!@Entity_IsCustom(pEntity)) return false;

  static iTargetId; iTargetId = GetIdByClassName(szClassName);

  if (iTargetId == -1) return false;

  static Trie:itPData; itPData = @Entity_GetPData(pEntity);
  static iId; iId = GetPDataMember(itPData, CE_MEMBER_ID);

  do {
    if (iId == iTargetId) return true;

    iId = ArrayGetCell(g_rgEntity[Entity_Parent], iId);
  } while(iId != -1);

  return false;
}

public bool:Native_HasMember(iPluginId, iArgc) {
  static pEntity; pEntity = get_param(1);
  static szMember[CE_MAX_MEMBER_LENGTH]; get_string(2, szMember, charsmax(szMember));

  if (!@Entity_IsCustom(pEntity)) return false;

  static Trie:itPData; itPData = @Entity_GetPData(pEntity);

  return HasPDataMember(itPData, szMember);
}

public any:Native_GetMember(iPluginId, iArgc) {
  static pEntity; pEntity = get_param(1);
  static szMember[CE_MAX_MEMBER_LENGTH]; get_string(2, szMember, charsmax(szMember));

  if (!@Entity_IsCustom(pEntity)) return 0;

  static Trie:itPData; itPData = @Entity_GetPData(pEntity);

  return GetPDataMember(itPData, szMember);
}

public Native_DeleteMember(iPluginId, iArgc) {
  static pEntity; pEntity = get_param(1);
  static szMember[CE_MAX_MEMBER_LENGTH]; get_string(2, szMember, charsmax(szMember));

  if (!@Entity_IsCustom(pEntity)) return;

  static Trie:itPData; itPData = @Entity_GetPData(pEntity);

  DeletePDataMember(itPData, szMember);
}

public Native_SetMember(iPluginId, iArgc) {
  static pEntity; pEntity = get_param(1);
  static szMember[CE_MAX_MEMBER_LENGTH]; get_string(2, szMember, charsmax(szMember));
  static iValue; iValue = get_param(3);

  if (!@Entity_IsCustom(pEntity)) return;

  static Trie:itPData; itPData = @Entity_GetPData(pEntity);

  SetPDataMember(itPData, szMember, iValue);
}

public bool:Native_GetMemberVec(iPluginId, iArgc) {
  static pEntity; pEntity = get_param(1);
  static szMember[CE_MAX_MEMBER_LENGTH]; get_string(2, szMember, charsmax(szMember));

  if (!@Entity_IsCustom(pEntity)) return false;

  static Trie:itPData; itPData = @Entity_GetPData(pEntity);

  static Float:vecValue[3];
  if (!GetPDataMemberVec(itPData, szMember, vecValue)) return false;

  set_array_f(3, vecValue, sizeof(vecValue));

  return true;
}

public Native_SetMemberVec(iPluginId, iArgc) {
  static pEntity; pEntity = get_param(1);
  static szMember[CE_MAX_MEMBER_LENGTH]; get_string(2, szMember, charsmax(szMember));
  static Float:vecValue[3]; get_array_f(3, vecValue, sizeof(vecValue));

  if (!@Entity_IsCustom(pEntity)) return;

  static Trie:itPData; itPData = @Entity_GetPData(pEntity);
  SetPDataMemberVec(itPData, szMember, vecValue);
}

public bool:Native_GetMemberString(iPluginId, iArgc) {
  static pEntity; pEntity = get_param(1);
  static szMember[CE_MAX_MEMBER_LENGTH]; get_string(2, szMember, charsmax(szMember));

  if (!@Entity_IsCustom(pEntity)) return false;

  static Trie:itPData; itPData = @Entity_GetPData(pEntity);

  static szValue[128];
  if (!GetPDataMemberString(itPData, szMember, szValue, charsmax(szValue))) return false;

  set_string(3, szValue, get_param(4));

  return true;
}

public Native_SetMemberString(iPluginId, iArgc) {
  static pEntity; pEntity = get_param(1);
  static szMember[CE_MAX_MEMBER_LENGTH]; get_string(2, szMember, charsmax(szMember));
  static szValue[128]; get_string(3, szValue, charsmax(szValue));
  
  if (!@Entity_IsCustom(pEntity)) return;

  static Trie:itPData; itPData = @Entity_GetPData(pEntity);
  SetPDataMemberString(itPData, szMember, szValue);
}

public any:Native_CallMethod(iPluginId, iArgc) {
  new pEntity; pEntity = get_param(1);
  new szMethod[CE_MAX_METHOD_NAME_LENGTH]; get_string(2, szMethod, charsmax(szMethod));

  if (!@Entity_IsCustom(pEntity)) return 0;

  new Trie:itPData; itPData = @Entity_GetPData(pEntity);

  new iId; iId = -1;

  // If we are already in the execution context use entity logic from current context
  if (IsMethodCallStackEmtpy()) {
    iId = GetPDataMember(itPData, CE_MEMBER_ID);
  } else {
    static rgCallStackItem[MethodCallStackItem];
    GetCurrentMethodFromCallStack(rgCallStackItem);

    if (rgCallStackItem[MethodCallStackItem_Entity] == pEntity) {
      iId = rgCallStackItem[MethodCallStackItem_EntityID];
    } else {
      iId = GetPDataMember(itPData, CE_MEMBER_ID);
    }
  }

  new rgMethod[Method];
  iId = FindEntityMethodInHierarchy(iId, szMethod, rgMethod);

  if (iId == -1) {
    new szName[CE_MAX_NAME_LENGTH]; ArrayGetString(g_rgEntity[Entity_Name], iId, szName, charsmax(szName));
    log_error(AMX_ERR_NATIVE, "%s Method ^"%s^" is not registered for the ^"%s^" entity (%d)!", LOG_PREFIX, szMethod, szName, pEntity);
    return 0;
  }

  // If we are already in the execution context and the method is virual jump to top level context
  if (IsMethodCallStackEmtpy()) {
    if (rgMethod[Method_IsVirtual]) {
      iId = FindEntityMethodInHierarchy(GetPDataMember(itPData, CE_MEMBER_ID), szMethod, rgMethod);
    }
  }

  #if defined _datapack_included
    ResetPack(g_dpParams, true);

    new Array:irgParamTypes; irgParamTypes = rgMethod[Method_ParamTypes];

    new iParamsNum; iParamsNum = ArraySize(irgParamTypes);
    for (new iMethodParam = 0; iMethodParam < iParamsNum; ++iMethodParam) {
      new iParam; iParam = 3 + iMethodParam;
      new iType; iType = ArrayGetCell(irgParamTypes, iMethodParam, _:MethodParam_Type);
      new iSize; iSize = ArrayGetCell(irgParamTypes, iMethodParam, _:MethodParam_Size);
      new bool:bUseDefault; bUseDefault = iParam > iArgc;

      switch (iType) {
        case CE_MP_Cell: {
          WritePackCell(g_dpParams, bUseDefault ? DEFAULT_CELL_VALUE : get_param_byref(iParam));
        }
        case CE_MP_Float: {
          WritePackFloat(g_dpParams, bUseDefault ? DEFAULT_FLOAT_VALUE : Float:get_param_byref(iParam));
        }
        case CE_MP_String: {
          if (bUseDefault) {
            copy(g_szBuffer, sizeof(g_szBuffer), DEFAULT_STRING_VALUE);
          } else {
            get_string(iParam, g_szBuffer, charsmax(g_szBuffer));
          }

          WritePackString(g_dpParams, g_szBuffer);
        }
        case CE_MP_Array: {
          if (bUseDefault) {
            arrayset(g_rgiBuffer, DEFAULT_FLOAT_VALUE, iSize);
          } else {
            get_array(iParam, g_rgiBuffer, iSize);
          }

          WritePackArray(g_dpParams, g_rgiBuffer, iSize);
        }
        case CE_MP_FloatArray: {
          if (bUseDefault) {
            arrayset(g_rgflBuffer, DEFAULT_FLOAT_VALUE, iSize);
          } else {
            get_array_f(iParam, g_rgflBuffer, iSize);
          }

          WritePackFloatArray(g_dpParams, g_rgflBuffer, iSize);
        }
      }
    }
  #endif

  #if defined _datapack_included
    ResetPack(g_dpParams);
  #endif

  new any:result; result = ExecuteMethod(szMethod, iId, pEntity, g_dpParams);


  return result;
}

public any:Native_CallBaseMethod(iPluginId, iArgc) {
  if (IsMethodCallStackEmtpy()) {
    log_error(AMX_ERR_NATIVE, "%s Calling a base method is not allowed outside of the execution context!", LOG_PREFIX);
    return 0;
  }

  static rgCallStackItem[MethodCallStackItem]; GetCurrentMethodFromCallStack(rgCallStackItem);
  static iId; iId = ArrayGetCell(g_rgEntity[Entity_Parent], rgCallStackItem[MethodCallStackItem_EntityID]);

  if (iId == -1) {
    new szName[CE_MAX_NAME_LENGTH]; ArrayGetString(g_rgEntity[Entity_Name], rgCallStackItem[MethodCallStackItem_EntityID], szName, charsmax(szName));
    log_error(AMX_ERR_NATIVE, "%s Entity ^"%s^" (%d) has no base entity!", LOG_PREFIX, szName, rgCallStackItem[MethodCallStackItem_Entity]);
    return 0;
  }

  new szMethod[CE_MAX_METHOD_NAME_LENGTH]; GetNameFromMethodGlobalTable(rgCallStackItem[MethodCallStackItem_Method], szMethod, charsmax(szMethod));

  static rgMethod[Method];
  iId = FindEntityMethodInHierarchy(iId, szMethod, rgMethod);

  if (iId == -1) {
    new szName[CE_MAX_NAME_LENGTH]; ArrayGetString(g_rgEntity[Entity_Name], iId, szName, charsmax(szName));
    log_error(AMX_ERR_NATIVE, "%s Method ^"%s^" is not registered for the ^"%s^" entity (%d)!", LOG_PREFIX, szMethod, szName, rgCallStackItem[MethodCallStackItem_Entity]);
    return 0;
  }

  #if defined _datapack_included
    ResetPack(g_dpParams, true);
  
    static Array:irgParamTypes; irgParamTypes = rgMethod[Method_ParamTypes];

    static iParamsNum; iParamsNum = ArraySize(irgParamTypes);
    for (new iMethodParam = 0; iMethodParam < iParamsNum; ++iMethodParam) {
      static iParam; iParam = 1 + iMethodParam;
      static iType; iType = ArrayGetCell(irgParamTypes, iMethodParam, _:MethodParam_Type);
      static iSize; iSize = ArrayGetCell(irgParamTypes, iMethodParam, _:MethodParam_Size);
      static bool:bUseDefault; bUseDefault = iParam > iArgc;

      switch (iType) {
        case CE_MP_Cell: {
          WritePackCell(g_dpParams, bUseDefault ? DEFAULT_CELL_VALUE : get_param_byref(iParam));
        }
        case CE_MP_Float: {
          WritePackFloat(g_dpParams, bUseDefault ? DEFAULT_FLOAT_VALUE : Float:get_param_byref(iParam));
        }
        case CE_MP_String: {
          if (bUseDefault) {
            copy(g_szBuffer, sizeof(g_szBuffer), DEFAULT_STRING_VALUE);
          } else {
            get_string(iParam, g_szBuffer, charsmax(g_szBuffer));
          }

          WritePackString(g_dpParams, g_szBuffer);
        }
        case CE_MP_Array: {
          if (bUseDefault) {
            arrayset(g_rgiBuffer, DEFAULT_FLOAT_VALUE, iSize);
          } else {
            get_array(iParam, g_rgiBuffer, iSize);
          }

          WritePackArray(g_dpParams, g_rgiBuffer, iSize);
        }
        case CE_MP_FloatArray: {
          if (bUseDefault) {
            arrayset(g_rgflBuffer, DEFAULT_FLOAT_VALUE, iSize);
          } else {
            get_array_f(iParam, g_rgflBuffer, iSize);
          }

          WritePackFloatArray(g_dpParams, g_rgflBuffer, iSize);
        }
      }
    }
  #endif

  #if defined _datapack_included
    ResetPack(g_dpParams);
  #endif

  static any:result; result = ExecuteMethod(szMethod, iId, rgCallStackItem[MethodCallStackItem_Entity], g_dpParams);

  return result;
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

  static Float:vecOrigin[3]; pev(pPlayer, pev_origin, vecOrigin);
  
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
  new szKey[32]; get_kvd(hKVD, KV_KeyName, szKey, charsmax(szKey));
  new szValue[32]; get_kvd(hKVD, KV_Value, szValue, charsmax(szValue));

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
    ExecuteHookFunction(CEFunction_KeyValue, iId, pEntity, szKey, szValue);
  }

  return FMRES_HANDLED;
}

public FMHook_Spawn(pEntity) {
  if (g_itPData != Invalid_Trie) {
    new iId = GetPDataMember(g_itPData, CE_MEMBER_ID);

    static szClassName[CE_MAX_NAME_LENGTH];
    ArrayGetString(g_rgEntity[Entity_Name], iId, szClassName, charsmax(szClassName));
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

public HamHook_Base_Touch_Post(pEntity, pToucher) {
  if (@Entity_IsCustom(pEntity)) {
    @Entity_Touched(pEntity, pToucher);
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

bool:@Entity_IsCustom(const &this) {
  if (g_itPData != Invalid_Trie && GetPDataMember(g_itPData, CE_MEMBER_POINTER) == this) {
    return true;
  }

  return pev(this, pev_gaitsequence) == CE_ENTITY_SECRET;
}

@Entity_Init(const &this) {
  new Trie:itPData = @Entity_GetPData(this);
  new iId = GetPDataMember(itPData, CE_MEMBER_ID);

  static szModel[MAX_RESOURCE_PATH_LENGTH]; pev(this, pev_model, szModel, charsmax(szModel));

  SetPDataMember(itPData, CE_MEMBER_IGNOREROUNDS, false);

  ExecuteHookFunction(CEFunction_Init, iId, this);

  if (!HasPDataMember(itPData, CE_MEMBER_MODEL) && !equal(szModel, NULL_STRING)) {
    SetPDataMemberString(itPData, CE_MEMBER_MODEL, szModel);

    if (g_bPrecaching && szModel[0] != '*') {
      precache_model(szModel);
    }
  }

  SetPDataMember(itPData, CE_MEMBER_INITIALIZED, true);
  SetPDataMember(itPData, CE_MEMBER_LASTINIT, get_gametime());
}

@Entity_Spawn(const &this) {
  new Trie:itPData = @Entity_GetPData(this);

  new iId = GetPDataMember(itPData, CE_MEMBER_ID);

  if (ExecuteHookFunction(CEFunction_Spawn, iId, this) != PLUGIN_CONTINUE) {
    return;
  }

  if (!GetPDataMember(itPData, CE_MEMBER_INITIALIZED)) {
    @Entity_Init(this);
  }

  if (!pev_valid(this) || pev(this, pev_flags) & FL_KILLME) {
    return;
  }

  static Float:flGameTime; flGameTime = get_gametime();

  set_pev(this, pev_deadflag, DEAD_NO);
  set_pev(this, pev_effects, pev(this, pev_effects) & ~EF_NODRAW);
  set_pev(this, pev_flags, pev(this, pev_flags) & ~FL_ONGROUND);

  @Entity_InitPhysics(this);
  @Entity_InitModel(this);
  @Entity_InitSize(this);

  new CEPreset:iPreset = ArrayGetCell(g_rgEntity[Entity_Preset], iId);

  switch (iPreset) {
    case CEPreset_Trigger: {
      SetPDataMember(itPData, CE_MEMBER_DELAY, 0.1);
    }
    case CEPreset_NPC: {
      set_pev(this, pev_flags, pev(this, pev_flags) | FL_MONSTER);
    }
  }

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

  new bool:bIsWorld = GetPDataMember(itPData, CE_MEMBER_WORLD);

  new Float:flLifeTime = 0.0;
  if (!bIsWorld && HasPDataMember(itPData, CE_MEMBER_LIFETIME)) {
    flLifeTime = GetPDataMember(itPData, CE_MEMBER_LIFETIME);
  }

  if (flLifeTime > 0.0) {
    SetPDataMember(itPData, CE_MEMBER_NEXTKILL, flGameTime + flLifeTime);
    set_pev(this, pev_nextthink, flGameTime + flLifeTime);
  } else {
    SetPDataMember(itPData, CE_MEMBER_NEXTKILL, 0.0);
  }

  SetPDataMember(itPData, CE_MEMBER_LASTSPAWN, flGameTime);

  ExecuteHookFunction(CEFunction_Spawned, iId, this);
}

@Entity_Restart(const &this) {
  new Trie:itPData = @Entity_GetPData(this);
  new iId = GetPDataMember(itPData, CE_MEMBER_ID);
  
  ExecuteHookFunction(CEFunction_Restart, iId, this);

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

@Entity_InitPhysics(const &this) {
  new Trie:itPData = @Entity_GetPData(this);
  new iId = GetPDataMember(itPData, CE_MEMBER_ID);
  new CEPreset:iPreset = ArrayGetCell(g_rgEntity[Entity_Preset], iId);

  if (ExecuteHookFunction(CEFunction_InitPhysics, iId, this) != PLUGIN_CONTINUE) {
    return;
  }

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

@Entity_InitModel(const &this) {
  new Trie:itPData = @Entity_GetPData(this);
  new iId = GetPDataMember(itPData, CE_MEMBER_ID);

  if (ExecuteHookFunction(CEFunction_InitModel, iId, this) != PLUGIN_CONTINUE) {
    return;
  }

  if (HasPDataMember(itPData, CE_MEMBER_MODEL)) {
    static szModel[MAX_RESOURCE_PATH_LENGTH];
    GetPDataMemberString(itPData, CE_MEMBER_MODEL, szModel, charsmax(szModel));
    engfunc(EngFunc_SetModel, this, szModel);
  }

}

@Entity_InitSize(const &this) {
  new Trie:itPData = @Entity_GetPData(this);
  new iId = GetPDataMember(itPData, CE_MEMBER_ID);

  if (ExecuteHookFunction(CEFunction_InitSize, iId, this) != PLUGIN_CONTINUE) {
    return;
  }

  if (HasPDataMember(itPData, CE_MEMBER_MINS) && HasPDataMember(itPData, CE_MEMBER_MAXS)) {
    static Float:vecMins[3]; GetPDataMemberVec(itPData, CE_MEMBER_MINS, vecMins);
    static Float:vecMaxs[3]; GetPDataMemberVec(itPData, CE_MEMBER_MAXS, vecMaxs);
    engfunc(EngFunc_SetSize, this, vecMins, vecMaxs);
  }
}

@Entity_Kill(const &this, const &pKiller, bool:bPicked) {
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
    if (HasPDataMember(itPData, CE_MEMBER_RESPAWNTIME)) {
      new Float:flRespawnTime = GetPDataMember(itPData, CE_MEMBER_RESPAWNTIME);
      new Float:flGameTime = get_gametime();

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

@Entity_Think(const &this) {
  if (pev(this, pev_flags) & FL_KILLME) return;

  static Float:flGameTime; flGameTime = get_gametime();

  static Trie:itPData; itPData = @Entity_GetPData(this);
  static iId; iId = GetPDataMember(itPData, CE_MEMBER_ID);

  ExecuteHookFunction(CEFunction_Think, iId, this);

  static iDeadFlag; iDeadFlag = pev(this, pev_deadflag);
  switch (iDeadFlag) {
    case DEAD_NO: {
      static Float:flNextKill; flNextKill = GetPDataMember(itPData, CE_MEMBER_NEXTKILL);
      if (flNextKill > 0.0 && flNextKill <= flGameTime) {
        ExecuteHamB(Ham_Killed, this, 0, 0);
      }
    }
    case DEAD_RESPAWNABLE: {
      static Float:flNextRespawn; flNextRespawn = GetPDataMember(itPData, CE_MEMBER_NEXTRESPAWN);
      if (flNextRespawn <= flGameTime) {
        dllfunc(DLLFunc_Spawn, this);
      }
    }
  }
}

@Entity_Touch(const &this, const &pToucher) {
  static Trie:itPData; itPData = @Entity_GetPData(this);
  static iId; iId = GetPDataMember(itPData, CE_MEMBER_ID);

  if (ExecuteHookFunction(CEFunction_Touch, iId, this, pToucher)) return;

  static CEPreset:iPreset; iPreset = ArrayGetCell(g_rgEntity[Entity_Preset], iId);

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

@Entity_Touched(const &this, const &pToucher) {
  static Trie:itPData; itPData = @Entity_GetPData(this);
  static iId; iId = GetPDataMember(itPData, CE_MEMBER_ID);

  ExecuteHookFunction(CEFunction_Touched, iId, this, pToucher);
}

@Entity_GetObjectCaps(const &this) {
    new Trie:itPData = @Entity_GetPData(this);
    new bool:bIgnoreRound = GetPDataMember(itPData, CE_MEMBER_IGNOREROUNDS);
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

@Entity_Pickup(const &this, const &pToucher) {
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

bool:@Entity_CanActivate(const &this, const &pTarget) {
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

@Entity_Trigger(const &this, const &pActivator) {
  if (!@Entity_CanActivate(this, pActivator)) {
    return;
  }

  new Trie:itPData = @Entity_GetPData(this);
  new iId = GetPDataMember(itPData, CE_MEMBER_ID);
  new Float:flDelay = GetPDataMember(itPData, CE_MEMBER_DELAY);

  set_pev(this, pev_nextthink, get_gametime() + flDelay);
  ExecuteHookFunction(CEFunction_Activated, iId, this, pActivator);
}

@Entity_BloodColor(const &this) {
  new Trie:itPData = @Entity_GetPData(this);

  if (!HasPDataMember(itPData, CE_MEMBER_BLOODCOLOR)) return -1;

  return GetPDataMember(itPData, CE_MEMBER_BLOODCOLOR);
}

Trie:@Entity_GetPData(const &this) {
  // Return the current allocated data if the entity is at the initialization stage
  if (g_itPData != Invalid_Trie && GetPDataMember(g_itPData, CE_MEMBER_POINTER) == this) {
    return g_itPData;
  }

  return Trie:pev(this, pev_iStepLeft);
}

@Entity_SetPData(const &this, Trie:itPData) {
  set_pev(this, pev_gaitsequence, CE_ENTITY_SECRET);
  set_pev(this, pev_iStepLeft, itPData);
}

Trie:@Entity_AllocPData(const &this, iId) {
  new Trie:itPData = AllocPData(iId, this);
  @Entity_SetPData(this, itPData);
  return itPData;
}

@Entity_FreePData(const &this) {
  new Trie:itPData = @Entity_GetPData(this);
  
  new iId = GetPDataMember(itPData, CE_MEMBER_ID);
  ExecuteHookFunction(CEFunction_Remove, iId, this);

  FreePData(itPData);

  set_pev(this, pev_gaitsequence, 0);
  set_pev(this, pev_iStepLeft, 0);
}

/*--------------------------------[ Functions ]--------------------------------*/

InitStorages() {
  g_dpParams = CreateDataPack();
  g_itEntityIds = TrieCreate();
  g_rgEntity[Entity_Name] = ArrayCreate(CE_MAX_NAME_LENGTH);
  g_rgEntity[Entity_Preset] = ArrayCreate();
  g_rgEntity[Entity_Parent] = ArrayCreate();

  for (new CEFunction:iFunction = CEFunction:0; iFunction < CEFunction; ++iFunction) {
    g_rgEntity[Entity_Hooks][iFunction] = ArrayCreate();
  }

  g_rgEntity[Entity_Methods] = ArrayCreate();
  g_rgEntity[Entity_Hierarchy] = ArrayCreate();

  g_irgMethods = ArrayCreate(CE_MAX_METHOD_NAME_LENGTH, 128);
  g_itMethods = TrieCreate();
  g_irgMethodCallStack = ArrayCreate(_:MethodCallStackItem);
}

DestroyStorages() {
  for (new iId = 0; iId < g_iEntitiesNum; ++iId) {
    FreeRegisteredEntity(iId);
  }

  for (new CEFunction:iFunction = CEFunction:0; iFunction < CEFunction; ++iFunction) {
    ArrayDestroy(g_rgEntity[Entity_Hooks][iFunction]);
  }

  for (new Entity:iData = Entity:0; iData < Entity; ++iData) {
    ArrayDestroy(Array:g_rgEntity[iData]);
  }

  ArrayDestroy(g_rgEntity[Entity_Hierarchy]);
  ArrayDestroy(g_rgEntity[Entity_Methods]);
  ArrayDestroy(g_rgEntity[Entity_Parent]);
  ArrayDestroy(g_rgEntity[Entity_Preset]);
  ArrayDestroy(g_rgEntity[Entity_Name]);

  ArrayDestroy(g_irgMethodCallStack);
  ArrayDestroy(g_irgMethods);
  TrieDestroy(g_itMethods);

  DestroyDataPack(g_dpParams);

  TrieDestroy(g_itEntityIds);
}

RegisterEntity(const szClassName[], CEPreset:iPreset = CEPreset_None, const szParent[] = "") {
  new iId = g_iEntitiesNum;

  new iParentId = -1; 
  if (!equal(szParent, "")) {
    if (!TrieGetCell(g_itEntityIds, szParent, iParentId)) {
      log_error(AMX_ERR_NATIVE, "%s Cannot extend entity class ^"%s^". The class is not exists!", LOG_PREFIX, szParent);
      return -1;
    }

    iPreset = ArrayGetCell(g_rgEntity[Entity_Preset], iParentId);
  }

  TrieSetCell(g_itEntityIds, szClassName, iId);
  ArrayPushString(g_rgEntity[Entity_Name], szClassName);
  ArrayPushCell(g_rgEntity[Entity_Preset], iPreset);
  ArrayPushCell(g_rgEntity[Entity_Parent], iParentId);
  ArrayPushCell(g_rgEntity[Entity_Methods], TrieCreate());
  ArrayPushCell(g_rgEntity[Entity_Hierarchy], Invalid_Array);

  for (new CEFunction:iFunction = CEFunction:0; iFunction < CEFunction; ++iFunction) {
    ArrayPushCell(g_rgEntity[Entity_Hooks][iFunction], ArrayCreate(_:EntityHook));
  }

  g_iEntitiesNum++;

  log_amx("%s Entity ^"%s^" successfully registred.", LOG_PREFIX, szClassName);

  return iId;
}

FreeRegisteredEntity(iId) {
  for (new CEFunction:iFunction = CEFunction:0; iFunction < CEFunction; ++iFunction) {
    new Array:irgHooks = ArrayGetCell(g_rgEntity[Entity_Hooks][iFunction], iId);
    ArrayDestroy(irgHooks);
    ArraySetCell(g_rgEntity[Entity_Hooks][iFunction], iId, Invalid_Array);
  }

  new Trie:itMethods = ArrayGetCell(g_rgEntity[Entity_Methods], iId);
  TrieDestroy(itMethods);
  ArraySetCell(g_rgEntity[Entity_Methods], iId, Invalid_Trie);

  new Array:irgHierarchy = ArrayGetCell(g_rgEntity[Entity_Hierarchy], iId);
  ArrayDestroy(irgHierarchy);
}

GetIdByClassName(const szClassName[]) {
  new iId = -1; TrieGetCell(g_itEntityIds, szClassName, iId);

  return iId;
}

RegisterEntityHook(CEFunction:iFunction, const szClassName[], const szCallback[], iPluginId = -1) {
  new iId = GetIdByClassName(szClassName);
  if (iId == -1) {
    log_error(AMX_ERR_NATIVE, "%s Entity ^"%s^" is not registered.", LOG_PREFIX, szClassName);
    return -1;
  }

  new iFunctionId = get_func_id(szCallback, iPluginId);
  if (iFunctionId < 0) {
    new szFilename[32];
    get_plugin(iPluginId, szFilename, charsmax(szFilename));
    log_error(AMX_ERR_NATIVE, "%s Function ^"%s^" not found in plugin ^"%s^".", LOG_PREFIX, szCallback, szFilename);
    return -1;
  }

  new rgHook[EntityHook];
  rgHook[EntityHook_PluginID] = iPluginId;
  rgHook[EntityHook_FuncID] = iFunctionId;

  new Array:irgHooks = ArrayGetCell(g_rgEntity[Entity_Hooks][iFunction], iId);
  new iHookId = ArrayPushArray(irgHooks, rgHook[EntityHook:0], _:EntityHook);

  return iHookId;
}

RegisterEntityMethod(const szClassName[], const szMethod[], const szCallback[], iPluginId = -1, Array:irgParamTypes, bool:bVirtual) {
  new iId = GetIdByClassName(szClassName);
  if (iId == -1) {
    log_error(AMX_ERR_NATIVE, "%s Entity ^"%s^" is not registered.", LOG_PREFIX, szClassName);
    return;
  }

  new iFunctionId = get_func_id(szCallback, iPluginId);
  if (iFunctionId < 0) {
    new szFilename[32];
    get_plugin(iPluginId, szFilename, charsmax(szFilename));
    log_error(AMX_ERR_NATIVE, "%s Function ^"%s^" not found in plugin ^"%s^".", LOG_PREFIX, szCallback, szFilename);
    return;
  }

  new Trie:itMethods; itMethods = ArrayGetCell(g_rgEntity[Entity_Methods], iId);

  if (TrieKeyExists(itMethods, szMethod)) {
    log_error(AMX_ERR_NATIVE, "%s Method ^"%s^" is already registered for ^"%s^" entity.", LOG_PREFIX, szMethod, szClassName);
    return;
  }

  new iParentId = ArrayGetCell(g_rgEntity[Entity_Parent], iId);
  if (iParentId != -1) {
    new rgMethod[Method];
    if (FindEntityMethodInHierarchy(iId, szMethod, rgMethod) != -1) {
      if (rgMethod[Method_IsVirtual]) {
        if (!CompareParamTypes(rgMethod[Method_ParamTypes], irgParamTypes)) {
          log_error(AMX_ERR_NATIVE, "%s Arguments mismatch in the overridden virtual method ^"%s^".", LOG_PREFIX, szMethod, szClassName);
          return;
        }
      }
    }
  }

  new rgMethod[Method];
  rgMethod[Method_PluginID] = iPluginId;
  rgMethod[Method_FunctionID] = iFunctionId;
  rgMethod[Method_ParamTypes] = irgParamTypes;
  rgMethod[Method_IsVirtual] = bVirtual;

  TrieSetArray(itMethods, szMethod, rgMethod[Method:0], _:Method);

  AddMethodToGlobalTable(szMethod);
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

  // Do not use static here! (recursion)
  new Array:irgHierarchy = GetEntityHierarchy(iId);
  new iHierarchySize = ArraySize(irgHierarchy);

  for (new i = 0; i < iHierarchySize; ++i) {
    new iCurrentId; iCurrentId = ArrayGetCell(irgHierarchy, i);
    new Array:irgHooks; irgHooks = ArrayGetCell(g_rgEntity[Entity_Hooks][iFunction], iCurrentId);
    new iHooksNum; iHooksNum = ArraySize(irgHooks);

    for (new iHookId = 0; iHookId < iHooksNum; ++iHookId) {
      static iPluginId; iPluginId = ArrayGetCell(irgHooks, iHookId, _:EntityHook_PluginID);
      static iFunctionId; iFunctionId = ArrayGetCell(irgHooks, iHookId, _:EntityHook_FuncID);
      
      if (callfunc_begin_i(iFunctionId, iPluginId) == 1)  {
        callfunc_push_int(pEntity);

        switch (iFunction) {
          case CEFunction_Touch, CEFunction_Touched: {
            static pToucher; pToucher = getarg(3);
            callfunc_push_int(pToucher);
          }
          case CEFunction_Kill, CEFunction_Killed: {
            static pKiller; pKiller = getarg(3);
            static bool:bPicked; bPicked = bool:getarg(4);
            callfunc_push_int(pKiller);
            callfunc_push_int(bPicked);
          }
          case CEFunction_Pickup, CEFunction_Picked: {
            static pPlayer; pPlayer = getarg(3);
            callfunc_push_int(pPlayer);
          }
          case CEFunction_Activate, CEFunction_Activated: {
            static pPlayer; pPlayer = getarg(3);
            callfunc_push_int(pPlayer);
          }
          case CEFunction_KeyValue: {
            static szKey[32];
            for (new i = 0; i < charsmax(szKey); ++i) {
              szKey[i] = getarg(3, i);
              
              if (szKey[i]  == '^0') break;
            }
            
            static szValue[32];
            for (new i = 0; i < charsmax(szValue); ++i) {
              szValue[i] = getarg(4, i);
              
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

ExecuteMethod(const szMethod[], const iId, const pEntity, const DataPack:dpParams) {
  static Trie:itMethods; itMethods = ArrayGetCell(g_rgEntity[Entity_Methods], iId);
  
  static rgMethod[Method];
  if (!TrieGetArray(itMethods, szMethod, rgMethod[Method:0], _:Method)) {
    return 0;
  }

  new iResult = 0;

  PushMethodToCallStack(pEntity, iId, szMethod);

  if (callfunc_begin_i(rgMethod[Method_FunctionID], rgMethod[Method_PluginID]) == 1) {
    callfunc_push_int(pEntity);

    #if defined _datapack_included
      static Array:irgParamTypes; irgParamTypes = rgMethod[Method_ParamTypes];

      if (irgParamTypes != Invalid_Array) {
        static iParamsNum; iParamsNum = ArraySize(irgParamTypes);

        for (new iParam = 0; iParam < iParamsNum; ++iParam) {
          static iType; iType = ArrayGetCell(irgParamTypes, iParam, _:MethodParam_Type);

          switch (iType) {
            case CE_MP_Cell: {
              static iValue; iValue = ReadPackCell(dpParams);
              callfunc_push_int(iValue);
            }
            case CE_MP_Float: {
              static Float:flValue; flValue = ReadPackFloat(dpParams);
              callfunc_push_float(flValue);
            }
            case CE_MP_String: {
              ReadPackString(dpParams, g_szBuffer, charsmax(g_szBuffer));
              callfunc_push_str(g_szBuffer);
            }
            case CE_MP_Array: {
              static iLen; iLen = ReadPackArray(dpParams, g_rgiBuffer);
              callfunc_push_array(g_rgiBuffer, iLen, false);
            }
            case CE_MP_FloatArray: {
              static iLen; iLen = ReadPackFloatArray(dpParams, g_rgflBuffer);
              callfunc_push_array(_:g_rgflBuffer, iLen, false);
            }
          }
        }
      }
    #endif

    iResult = callfunc_end();
  }

  PopMethodFromCallStack();

  return iResult;
}

FindEntityMethodInHierarchy(iId, const szMethod[], rgMethod[Method]) {
    new iCurrentId = iId;

    do {
      static Trie:itMethods; itMethods = ArrayGetCell(g_rgEntity[Entity_Methods], iCurrentId);

      if (TrieGetArray(itMethods, szMethod, rgMethod[Method:0], _:Method)) {
        break;
      }

    } while ((iCurrentId = ArrayGetCell(g_rgEntity[Entity_Parent], iCurrentId)) != -1);

    return iCurrentId;
}

Array:GetEntityHierarchy(iId) {
  static Array:irgHierarchy; irgHierarchy = ArrayGetCell(g_rgEntity[Entity_Hierarchy], iId);

  if (irgHierarchy == Invalid_Array) {
    irgHierarchy = CreateHierarchyList(iId);
    ArraySetCell(g_rgEntity[Entity_Hierarchy], iId, irgHierarchy);
  }

  return irgHierarchy;
}

Array:CreateHierarchyList(iId) {
  new Array:irgHierarchy = ArrayCreate();

  new iCurrentId = iId;

  do {
    if (iCurrentId == iId) {
      ArrayPushCell(irgHierarchy, iCurrentId);
    } else {
      ArrayInsertCellBefore(irgHierarchy, 0, iCurrentId);
    }
    iCurrentId = ArrayGetCell(g_rgEntity[Entity_Parent], iCurrentId);
  } while (iCurrentId != -1);

  return irgHierarchy;
}

AddMethodToGlobalTable(const szMethod[]) {
  if (TrieKeyExists(g_itMethods, szMethod)) return -1;

  new iIndex = ArraySize(g_irgMethods);

  ArrayPushString(g_irgMethods, szMethod);
  TrieSetCell(g_itMethods, szMethod, iIndex);

  return iIndex;
}

GetNameFromMethodGlobalTable(iIndex, szMethod[], iLen) {
  return ArrayGetString(g_irgMethods, iIndex, szMethod, iLen);
}

GetIndexFromMethodGlobalTable(const szMethod[]) {
  static iValue;
  if (!TrieGetCell(g_itMethods, szMethod, iValue)) return -1;

  return iValue;
}

bool:IsMethodCallStackEmtpy() {
  return !ArraySize(g_irgMethodCallStack);
}

PushMethodToCallStack(const pEntity, const iId, const szMethod[]) {
  static rgCallStackItem[MethodCallStackItem];
  rgCallStackItem[MethodCallStackItem_Entity] = pEntity;
  rgCallStackItem[MethodCallStackItem_EntityID] = iId;
  rgCallStackItem[MethodCallStackItem_Method] = GetIndexFromMethodGlobalTable(szMethod);
  
  ArrayPushArray(g_irgMethodCallStack, rgCallStackItem[MethodCallStackItem:0], sizeof(rgCallStackItem));
}

PopMethodFromCallStack() {
  ArrayDeleteItem(g_irgMethodCallStack, ArraySize(g_irgMethodCallStack) - 1);
}

GetCurrentMethodFromCallStack(rgCallStackItem[MethodCallStackItem]) {
  ArrayGetArray(g_irgMethodCallStack, ArraySize(g_irgMethodCallStack) - 1, rgCallStackItem[MethodCallStackItem:0], sizeof(rgCallStackItem));
}

CompareParamTypes(const &Array:irgParams, const &Array:irgOtherParams) {
  new iSize = ArraySize(irgParams);
  new iOtherSize = ArraySize(irgOtherParams);

  if (iSize != iOtherSize) {
    return false;
  }

  for (new i = 0; i < iSize; ++i) {
    if (ArrayGetCell(irgParams, i) != ArrayGetCell(irgOtherParams, i)) return false;
  }

  return true;
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
