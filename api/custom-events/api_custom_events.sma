#include <amxmodx>
#include <fakemeta>

#include <datapack_stocks>

#include <api_custom_events>

#define PLUGIN "[API] Custom Events"
#define VERSION "1.0.0"
#define AUTHOR "Hedgehog Fog"

#define LOG_PREFIX "[Custom Events] "

#define MAX_EVENT_KEY_LENGTH 64

#define DEFAULT_CELL_VALUE 0
#define DEFAULT_FLOAT_VALUE 0.0
#define DEFAULT_STRING_VALUE NULL_STRING

enum EventParam {
  EventParam_Type = 0,
  EventParam_Size
};

enum EventSubscriber {
  EventSubscriber_PluginId = 0,
  EventSubscriber_FunctionId
};

new g_fwEmit;

new g_szBuffer[MAX_STRING_LENGTH]
new g_rgiBuffer[MAX_STRING_LENGTH];
new Float:g_rgflBuffer[MAX_STRING_LENGTH];

new Trie:g_itEventParamTypes;
new Trie:g_itEventSubscribers;

new g_pCurrentActivator = 0;
new DataPack:g_dpCurrentParamData = Invalid_DataPack;
new Array:g_irgCurrentParamOffsets = Invalid_Array;

public plugin_precache() {
  g_itEventParamTypes = TrieCreate();
  g_itEventSubscribers = TrieCreate();
}

public plugin_init() {
  register_plugin(PLUGIN, VERSION, AUTHOR);

  g_fwEmit = CreateMultiForward("CustomEvent_Fw_Emit", ET_STOP, FP_STRING, FP_CELL);
}

public plugin_end() {
  TrieDestroy(g_itEventParamTypes);
  TrieDestroy(g_itEventSubscribers);
}

public plugin_natives() {
  register_library("api_custom_events");
  register_native("CustomEvent_Register", "Native_RegisterEvent");
  register_native("CustomEvent_Subscribe", "Native_SubscribeEvent");
  register_native("CustomEvent_Emit", "Native_EmitEvent");
  register_native("CustomEvent_GetParamsNum", "Native_GetParamsNum");
  register_native("CustomEvent_GetParamType", "Native_GetParamType");
  register_native("CustomEvent_GetParam", "Native_GetParam");
  register_native("CustomEvent_GetParamFloat", "Native_GetParamFloat");
  register_native("CustomEvent_GetParamString", "Native_GetParamString");
  register_native("CustomEvent_GetParamArray", "Native_GetParamArray");
  register_native("CustomEvent_GetParamFloatArray", "Native_GetParamFloatArray");
  register_native("CustomEvent_GetActivator", "Native_GetActivator");
  register_native("CustomEvent_SetActivator", "Native_SetActivator");
}

public Native_RegisterEvent(iPluginId, iArgc) {
  static szEvent[MAX_EVENT_KEY_LENGTH]; get_string(1, szEvent, charsmax(szEvent));

  if (TrieKeyExists(g_itEventParamTypes, szEvent)) {
    log_error(AMX_ERR_NATIVE, "%sEvent ^"%s^" is already registered.", LOG_PREFIX);
    return;
  }

  static Array:irgParamTypes; irgParamTypes = ArrayCreate(_:EventParam, iArgc - 1);

  for (new iParam = 2; iParam <= iArgc; ++iParam) {
    static rgParam[EventParam];
    rgParam[EventParam_Type] = get_param_byref(iParam);
    rgParam[EventParam_Size] = 1;

    switch (rgParam[EventParam_Type]) {
      case EP_Array, EP_FloatArray: {
        rgParam[EventParam_Size] = get_param_byref(iParam + 1);
        iParam++;
      }
    }

    ArrayPushArray(irgParamTypes, rgParam[any:0], _:EventParam);
  }

  TrieSetCell(g_itEventParamTypes, szEvent, irgParamTypes);
}

public Native_SubscribeEvent(iPluginId, iArgc) {
  static szEvent[MAX_EVENT_KEY_LENGTH]; get_string(1, szEvent, charsmax(szEvent));
  static szCallback[64]; get_string(2, szCallback, charsmax(szCallback));

  if (!TrieKeyExists(g_itEventSubscribers, szEvent)) {
    TrieSetCell(g_itEventSubscribers, szEvent, ArrayCreate(_:EventSubscriber));
  }

  static Array:irgSubscribers; TrieGetCell(g_itEventSubscribers, szEvent, irgSubscribers);

  static rgSubscriber[EventSubscriber];
  rgSubscriber[EventSubscriber_PluginId] = iPluginId;
  rgSubscriber[EventSubscriber_FunctionId] = get_func_id(szCallback, iPluginId);
  ArrayPushArray(irgSubscribers, rgSubscriber[any:0], _:EventSubscriber);
}

public Native_EmitEvent(iPluginId, iArgc) {
  static szEvent[MAX_EVENT_KEY_LENGTH]; get_string(1, szEvent, charsmax(szEvent));

  static DataPack:dpParams; dpParams = CreateDataPack();

  if (TrieKeyExists(g_itEventParamTypes, szEvent)) {
    static Array:irgParamTypes; TrieGetCell(g_itEventParamTypes, szEvent, irgParamTypes);

    static iParamsNum; iParamsNum = ArraySize(irgParamTypes);
    for (new iEventParam = 0; iEventParam < iParamsNum; ++iEventParam) {
      static iParam; iParam = 3 + iEventParam;
      static iType; iType = ArrayGetCell(irgParamTypes, iEventParam, _:EventParam_Type);
      static iSize; iSize = ArrayGetCell(irgParamTypes, iEventParam, _:EventParam_Size);
      static bool:bUseDefault; bUseDefault = iParam >= iArgc;

      switch (iType) {
        case EP_Cell: {
          WritePackCell(dpParams, bUseDefault ? DEFAULT_CELL_VALUE : get_param_byref(iParam));
        }
        case EP_Float: {
          WritePackFloat(dpParams, bUseDefault ? DEFAULT_FLOAT_VALUE : Float:get_param_byref(iParam));
        }
        case EP_String: {
          if (bUseDefault) {
            copy(g_szBuffer, sizeof(g_szBuffer), DEFAULT_STRING_VALUE);
          } else {
            get_string(iParam, g_szBuffer, charsmax(g_szBuffer));
          }

          WritePackString(dpParams, g_szBuffer);
        }
        case EP_Array: {
          if (bUseDefault) {
            arrayset(g_rgiBuffer, DEFAULT_FLOAT_VALUE, iSize);
          } else {
            get_array(iParam, g_rgiBuffer, iSize);
          }

          WritePackArray(dpParams, g_rgiBuffer, iSize);
        }
        case EP_FloatArray: {
          if (bUseDefault) {
            arrayset(g_rgflBuffer, DEFAULT_FLOAT_VALUE, iSize);
          } else {
            get_array_f(iParam, g_rgflBuffer, iSize);
          }

          WritePackFloatArray(dpParams, g_rgflBuffer, iSize);
        }
      }
    }
  }

  ResetPack(dpParams);
  EmitEvent(szEvent, dpParams);

  DestroyDataPack(dpParams);
}

public Native_SetActivator(iPluginId, iArgc) {
  static pActivator; pActivator = get_param(1);

  if (pActivator && !pev_valid(pActivator)) {
    log_error(AMX_ERR_NATIVE, "%sCannot set emitter. %d is not valid entity.", LOG_PREFIX, pActivator);
    return;
  }

  g_pCurrentActivator = pActivator;
}

public Native_GetActivator(iPluginId, iArgc) {
  return g_pCurrentActivator;
}

public Native_GetParamsNum(iPluginId, iArgc) {
  static szEvent[MAX_EVENT_KEY_LENGTH]; get_string(1, szEvent, charsmax(szEvent));

  return GetEventParamsNum(szEvent);
}

public Native_GetParamType(iPluginId, iArgc) {
  static szEvent[MAX_EVENT_KEY_LENGTH]; get_string(1, szEvent, charsmax(szEvent));
  static iParam; iParam = get_param(2);

  return GetEventParamType(szEvent, iParam);
}

public any:Native_GetParam(iPluginId, iArgc) {
  static iParam; iParam = get_param(1);
  return GetCurrentEventParam(iParam - 1);
}

public Float:Native_GetParamFloat(iPluginId, iArgc) {
  static iParam; iParam = get_param(1);
  return GetCurrentEventParamFloat(iParam - 1);
}

public Float:Native_GetParamString(iPluginId, iArgc) {
  static iParam; iParam = get_param(1);
  static iLen; iLen = get_param(3);
  GetCurrentEventParamString(iParam - 1, g_szBuffer, iLen);
  set_string(2, g_szBuffer, iLen);
}

public Native_GetParamArray(iPluginId, iArgc) {
  static iParam; iParam = get_param(1);
  static iLen; iLen = get_param(3);
  GetCurrentEventParamArray(iParam - 1, g_rgiBuffer, iLen);
  set_array(2, g_rgiBuffer, iLen);
}

public Native_GetParamFloatArray(iPluginId, iArgc) {
  static iParam; iParam = get_param(1);
  static iLen; iLen = get_param(3);
  GetCurrentEventParamFloatArray(iParam - 1, g_rgflBuffer, iLen);
  set_array_f(2, g_rgflBuffer, iLen);
}

GetEventParamsNum(const szEvent[]) {
  static Array:irgParamTypes;
  if (!TrieGetCell(g_itEventParamTypes, szEvent, irgParamTypes)) return 0;

  return ArraySize(irgParamTypes);
}

GetEventParamType(const szEvent[], iParam) {
  static Array:irgParamTypes;
  if (!TrieGetCell(g_itEventParamTypes, szEvent, irgParamTypes)) return EP_Invalid;
  if (iParam <= ArraySize(irgParamTypes)) return EP_Invalid;

  return ArrayGetCell(irgParamTypes, iParam, _:EventParam_Type);
}

any:GetCurrentEventParam(iParam) {
  if (g_irgCurrentParamOffsets == Invalid_Array) return DEFAULT_CELL_VALUE;

  SetPackPosition(g_dpCurrentParamData, GetCurrentOffset(iParam));

  return ReadPackCell(g_dpCurrentParamData);
}

Float:GetCurrentEventParamFloat(iParam) {
  if (g_irgCurrentParamOffsets == Invalid_Array) return DEFAULT_FLOAT_VALUE;

  SetPackPosition(g_dpCurrentParamData, GetCurrentOffset(iParam));

  return ReadPackFloat(g_dpCurrentParamData);
}

GetCurrentEventParamString(iParam, szOut[], iLen) {
  if (g_irgCurrentParamOffsets == Invalid_Array) {
    copy(szOut, iLen, DEFAULT_STRING_VALUE);
    return;
  }

  SetPackPosition(g_dpCurrentParamData, GetCurrentOffset(iParam));

  ReadPackString(g_dpCurrentParamData, szOut, iLen);
}

GetCurrentEventParamArray(iParam, rgiOut[], iLen) {
  if (g_irgCurrentParamOffsets == Invalid_Array) {
    arrayset(rgiOut, DEFAULT_CELL_VALUE, iLen);
    return;
  }

  SetPackPosition(g_dpCurrentParamData, GetCurrentOffset(iParam));

  ReadPackArray(g_dpCurrentParamData, rgiOut, iLen)
}

GetCurrentEventParamFloatArray(iParam, Float:rgflOut[], iLen) {
  if (g_irgCurrentParamOffsets == Invalid_Array) {
    arrayset(rgflOut, DEFAULT_FLOAT_VALUE, iLen);
    return;
  }

  SetPackPosition(g_dpCurrentParamData, GetCurrentOffset(iParam));

  ReadPackFloatArray(g_dpCurrentParamData, rgflOut, iLen)
}

DataPackPos:GetCurrentOffset(iParam) {
  return ArrayGetCell(g_irgCurrentParamOffsets, iParam);
}

EmitEvent(const szEvent[], DataPack:dpParams) {
  if (g_pCurrentActivator && !pev_valid(g_pCurrentActivator)) {
    log_error(AMX_ERR_NATIVE, "%sCannot emit event ^"%s^" from entity! Invalid entity %d.", LOG_PREFIX, szEvent, g_pCurrentActivator);
    return;
  }

  g_dpCurrentParamData = dpParams;
  g_irgCurrentParamOffsets = Invalid_Array;

  static Array:irgParamTypes; irgParamTypes = Invalid_Array; 

  if (TrieKeyExists(g_itEventParamTypes, szEvent)) {
    TrieGetCell(g_itEventParamTypes, szEvent, irgParamTypes);
    g_irgCurrentParamOffsets = GetEventParamOffsets(dpParams, irgParamTypes)
  }

  static iForwardReturn; ExecuteForward(g_fwEmit, iForwardReturn, szEvent, g_pCurrentActivator);

  if (iForwardReturn == PLUGIN_CONTINUE && TrieKeyExists(g_itEventSubscribers, szEvent)) {
    static Array:irgSubscribers; TrieGetCell(g_itEventSubscribers, szEvent, irgSubscribers);

    static iSubscribersNum; iSubscribersNum = ArraySize(irgSubscribers);
    for (new iSubscriber = 0; iSubscriber < iSubscribersNum; ++iSubscriber) {
      ResetPack(dpParams);

      static iPluginId; iPluginId = ArrayGetCell(irgSubscribers, iSubscriber, _:EventSubscriber_PluginId);
      static iFunctionId; iFunctionId = ArrayGetCell(irgSubscribers, iSubscriber, _:EventSubscriber_FunctionId);
      CallEventCallback(iPluginId, iFunctionId, dpParams, irgParamTypes);
    }
  }

  if (g_irgCurrentParamOffsets != Invalid_Array) {
    ArrayDestroy(g_irgCurrentParamOffsets);
  }

  g_pCurrentActivator = 0;
  g_irgCurrentParamOffsets = Invalid_Array;
  g_dpCurrentParamData = Invalid_DataPack;
}

Array:GetEventParamOffsets(DataPack:dpParams, Array:irgParamTypes) {
  static Array:irgOffsets; irgOffsets = ArrayCreate();

  static DataPackPos:iPos; iPos = GetPackPosition(dpParams);
  static iParamsNum; iParamsNum = ArraySize(irgParamTypes);

  for (new iParam = 0; iParam < iParamsNum; ++iParam) {
    ArrayPushCell(irgOffsets, GetPackPosition(dpParams));

    static iType; iType = ArrayGetCell(irgParamTypes, iParam, _:EventParam_Type);

    switch (iType) {
      case EP_Cell: ReadPackCell(dpParams);
      case EP_Float: ReadPackFloat(dpParams);
      case EP_String: ReadPackString(dpParams, g_szBuffer, charsmax(g_szBuffer));
      case EP_Array: ReadPackArray(dpParams, g_rgiBuffer, 0);
      case EP_FloatArray: ReadPackFloatArray(dpParams, g_rgflBuffer, 0);
    }
  }
  
  SetPackPosition(dpParams, iPos);

  return irgOffsets;
}

CallEventCallback(iPluginId, iFunctionId, DataPack:dpParams, Array:irgParamTypes) {
  callfunc_begin_i(iFunctionId, iPluginId);

  if (irgParamTypes != Invalid_Array) {
    static iParamsNum; iParamsNum = ArraySize(irgParamTypes);

    for (new iParam = 0; iParam < iParamsNum; ++iParam) {
      static iType; iType = ArrayGetCell(irgParamTypes, iParam, _:EventParam_Type);

      switch (iType) {
        case EP_Cell: {
          static iValue; iValue = ReadPackCell(dpParams);
          callfunc_push_int(iValue);
        }
        case EP_Float: {
          static Float:flValue; flValue = ReadPackFloat(dpParams);
          callfunc_push_float(flValue);
        }
        case EP_String: {
          ReadPackString(dpParams, g_szBuffer, charsmax(g_szBuffer));
          callfunc_push_str(g_szBuffer);
        }
        case EP_Array: {
          static iLen; iLen = ReadPackArray(dpParams, g_rgiBuffer);
          callfunc_push_array(g_rgiBuffer, iLen, false);
        }
        case EP_FloatArray: {
          static iLen; iLen = ReadPackFloatArray(dpParams, g_rgflBuffer);
          callfunc_push_array(_:g_rgflBuffer, iLen, false);
        }
      }
    }
  }

  callfunc_end();
}
