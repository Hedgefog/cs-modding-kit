#include <amxmodx>
#include <fakemeta>

#include <datapack_stocks>

#include <api_custom_events>

#define LOG_PREFIX "[Custom Events] "

#define PLUGIN "[API] Custom Events"
#define VERSION "1.0.0"
#define AUTHOR "Hedgehog Fog"

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

new Trie:g_itEvents;
new Array:g_rgszEventId;
new Array:g_rgirgEventParamTypes;
new Array:g_rgirgEventSubscribers;
new g_iEventsNum = 0;

new g_pCurrentEmitter = 0;
new g_iCurrentEvent = -1;
new DataPack:g_dpCurrentParamData = Invalid_DataPack;
new Array:g_irgCurrentParamOffsets = Invalid_Array;

public plugin_precache() {
  g_itEvents = TrieCreate();
  g_rgszEventId = ArrayCreate(32);
  g_rgirgEventParamTypes = ArrayCreate(_:EventParam);
  g_rgirgEventSubscribers = ArrayCreate(_:EventSubscriber);
}

public plugin_init() {
  register_plugin(PLUGIN, VERSION, AUTHOR);

  g_fwEmit = CreateMultiForward("CustomEvent_Fw_Emit", ET_STOP, FP_STRING, FP_CELL);
}

public plugin_end() {
  for (new iEvent = 0; iEvent < g_iEventsNum; ++iEvent) {
    new Array:irgParamTypes = ArrayGetCell(g_rgirgEventParamTypes, iEvent);
    ArrayDestroy(irgParamTypes);

    new Array:irgSubscribers = ArrayGetCell(g_rgirgEventSubscribers, iEvent);
    ArrayDestroy(irgSubscribers);
  }

  TrieDestroy(g_itEvents);
  ArrayDestroy(g_rgszEventId);
  ArrayDestroy(g_rgirgEventParamTypes);
  ArrayDestroy(g_rgirgEventSubscribers);
}

public plugin_natives() {
  register_library("api_custom_events");
  register_native("CustomEvent_Register", "Native_RegisterEvent");
  register_native("CustomEvent_Subscribe", "Native_SubscribeEvent");
  register_native("CustomEvent_Emit", "Native_EmitEvent");
  register_native("CustomEvent_EmitFromEntity", "Native_EmitEventFromEntity");
  register_native("CustomEvent_GetGetEmitter", "Native_GetEmitter");
  register_native("CustomEvent_GetParamsNum", "Native_GetParamsNum");
  register_native("CustomEvent_GetParamType", "Native_GetParamType");
  register_native("CustomEvent_GetParam", "Native_GetParam");
  register_native("CustomEvent_GetParamFloat", "Native_GetParamFloat");
  register_native("CustomEvent_GetParamString", "Native_GetParamString");
  register_native("CustomEvent_GetParamArray", "Native_GetParamArray");
  register_native("CustomEvent_GetParamFloatArray", "Native_GetParamFloatArray");
}

public Native_RegisterEvent(iPluginId, iArgc) {
  static szEvent[32]; get_string(1, szEvent, charsmax(szEvent));

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

  RegisterEvent(szEvent, irgParamTypes);
}

public Native_SubscribeEvent(iPluginId, iArgc) {
  static szEvent[32]; get_string(1, szEvent, charsmax(szEvent));
  static szCallback[32]; get_string(2, szCallback, charsmax(szCallback));

  static iEvent; iEvent = GetEventId(szEvent);
  if (iEvent == -1) {
    log_amx("%sCannot subscribe event ^"%s^". Event ^"%s^" is not registered.", LOG_PREFIX, szEvent, szEvent);
  }

  static Array:irgSubscribers; irgSubscribers = ArrayGetCell(g_rgirgEventSubscribers, iEvent);

  static rgSubscriber[EventSubscriber];
  rgSubscriber[EventSubscriber_PluginId] = iPluginId;
  rgSubscriber[EventSubscriber_FunctionId] = get_func_id(szCallback, iPluginId);

  ArrayPushArray(irgSubscribers, rgSubscriber[any:0], _:EventSubscriber);
}


public Native_EmitEvent(iPluginId, iArgc) {
  static szEvent[32]; get_string(1, szEvent, charsmax(szEvent));

  static iEvent; iEvent = GetEventId(szEvent);
  if (iEvent == -1) {
    log_amx("%sCannot emit event ^"%s^". Event ^"%s^" is not registered.", LOG_PREFIX, szEvent, szEvent);
    return;
  }

  static Array:irgParamTypes; irgParamTypes = ArrayGetCell(g_rgirgEventParamTypes, iEvent);
  static DataPack:dpParams; dpParams = CreateDataPack();

  static iParamsNum; iParamsNum = ArraySize(irgParamTypes);
  for (new iEventParam = 0; iEventParam < iParamsNum; ++iEventParam) {
    static iParam; iParam = 2 + iEventParam;
    static iType; iType = ArrayGetCell(irgParamTypes, iEventParam, _:EventParam_Type);
    static iSize; iSize = ArrayGetCell(irgParamTypes, iEventParam, _:EventParam_Size);

    switch (iType) {
      case EP_Cell: {
        WritePackCell(dpParams, get_param_byref(iParam));
      }
      case EP_Float: {
        WritePackFloat(dpParams, Float:get_param_byref(iParam));
      }
      case EP_String: {
        get_string(iParam, g_szBuffer, charsmax(g_szBuffer));
        WritePackString(dpParams, g_szBuffer);
      }
      case EP_Array: {
        get_array(iParam, g_rgiBuffer, iSize);
        WritePackArray(dpParams, g_rgiBuffer, iSize);
      }
      case EP_FloatArray: {
        get_array_f(iParam, g_rgflBuffer, iSize);
        WritePackFloatArray(dpParams, g_rgflBuffer, iSize);
      }
    }
  }

  ResetPack(dpParams);
  EmitEvent(szEvent, dpParams, 0);

  DestroyDataPack(dpParams);
}

public Native_EmitEventFromEntity(iPluginId, iArgc) {
  static pEmitter; pEmitter = get_param(1);
  static szEvent[32]; get_string(2, szEvent, charsmax(szEvent));

  static iEvent; iEvent = GetEventId(szEvent);
  if (iEvent == -1) {
    log_amx("%sCannot emit event ^"%s^". Event ^"%s^" is not registered.", LOG_PREFIX, szEvent, szEvent);
    return;
  }

  static Array:irgParamTypes; irgParamTypes = ArrayGetCell(g_rgirgEventParamTypes, iEvent);
  static DataPack:dpParams; dpParams = CreateDataPack();

  static iParamsNum; iParamsNum = ArraySize(irgParamTypes);
  for (new iEventParam = 0; iEventParam < iParamsNum; ++iEventParam) {
    static iParam; iParam = 3 + iEventParam;
    static iType; iType = ArrayGetCell(irgParamTypes, iEventParam, _:EventParam_Type);
    static iSize; iSize = ArrayGetCell(irgParamTypes, iEventParam, _:EventParam_Size);

    switch (iType) {
      case EP_Cell: {
        WritePackCell(dpParams, get_param_byref(iParam));
      }
      case EP_Float: {
        WritePackFloat(dpParams, Float:get_param_byref(iParam));
      }
      case EP_String: {
        get_string(iParam, g_szBuffer, charsmax(g_szBuffer));
        WritePackString(dpParams, g_szBuffer);
      }
      case EP_Array: {
        get_array(iParam, g_rgiBuffer, iSize);
        WritePackArray(dpParams, g_rgiBuffer, iSize);
      }
      case EP_FloatArray: {
        get_array_f(iParam, g_rgflBuffer, iSize);
        WritePackFloatArray(dpParams, g_rgflBuffer, iSize);
      }
    }
  }

  ResetPack(dpParams);
  EmitEvent(szEvent, dpParams, pEmitter);

  DestroyDataPack(dpParams);
}

public Native_GetEmitter(iPluginId, iArgc) {
  return g_pCurrentEmitter;
}

public Native_GetParamsNum(iPluginId, iArgc) {
  static szEvent[32]; get_string(1, szEvent, charsmax(szEvent));

  static iEvent; iEvent = GetEventId(szEvent);
  if (iEvent == -1) {
    log_amx("%sEvent ^"%s^" is not registered.", LOG_PREFIX, szEvent);
    return EP_Invalid;
  }

  return GetEventParamsNum(iEvent);
}

public Native_GetParamType(iPluginId, iArgc) {
  static szEvent[32]; get_string(1, szEvent, charsmax(szEvent));
  static iParam; iParam = get_param(2);

  static iEvent; iEvent = GetEventId(szEvent);
  if (iEvent == -1) {
    log_amx("%sEvent ^"%s^" is not registered.", LOG_PREFIX, szEvent);
    return EP_Invalid;
  }

  return GetEventParamType(iEvent, iParam);
}

public any:Native_GetParam(iPluginId, iArgc) {
  if (g_iCurrentEvent == -1) {
    log_error(AMX_ERR_NATIVE, "%sNot currently in a event callback.", LOG_PREFIX);
    return 0;
  }

  static iParam; iParam = get_param(1);
  return GetCurrentEventParam(iParam - 1);
}

public Float:Native_GetParamFloat(iPluginId, iArgc) {
  if (g_iCurrentEvent == -1) {
    log_error(AMX_ERR_NATIVE, "%sNot currently in a event callback.", LOG_PREFIX);
    return 0.0;
  }

  static iParam; iParam = get_param(1);
  return GetCurrentEventParamFloat(iParam - 1);
}

public Float:Native_GetParamString(iPluginId, iArgc) {
  if (g_iCurrentEvent == -1) {
    log_error(AMX_ERR_NATIVE, "%sNot currently in a event callback.", LOG_PREFIX);
    return;
  }

  static iParam; iParam = get_param(1);
  static iLen; iLen = get_param(3);
  GetCurrentEventParamString(iParam - 1, g_szBuffer, iLen);
  set_string(2, g_szBuffer, iLen);
}

public Native_GetParamArray(iPluginId, iArgc) {
  if (g_iCurrentEvent == -1) {
    log_error(AMX_ERR_NATIVE, "%sNot currently in a event callback.", LOG_PREFIX);
    return;
  }

  static iParam; iParam = get_param(1);
  static iLen; iLen = get_param(3);
  GetCurrentEventParamArray(iParam - 1, g_rgiBuffer, iLen);
  set_array(2, g_rgiBuffer, iLen);
}

public Native_GetParamFloatArray(iPluginId, iArgc) {
  if (g_iCurrentEvent == -1) {
    log_error(AMX_ERR_NATIVE, "%sNot currently in a event callback.", LOG_PREFIX);
    return;
  }

  static iParam; iParam = get_param(1);
  static iLen; iLen = get_param(3);
  GetCurrentEventParamFloatArray(iParam - 1, g_rgflBuffer, iLen);
  set_array_f(2, g_rgflBuffer, iLen);
}

RegisterEvent(const szEvent[], Array:irgParamTypes) {
  new iEvent = g_iEventsNum;

  ArrayPushString(g_rgszEventId, szEvent);
  ArrayPushCell(g_rgirgEventParamTypes, irgParamTypes);
  ArrayPushCell(g_rgirgEventSubscribers, ArrayCreate(_:EventSubscriber));
  TrieSetCell(g_itEvents, szEvent, iEvent);

  g_iEventsNum++;

  return iEvent;
}

GetEventId(const szEvent[]) {
  static iEvent;
  if (!TrieGetCell(g_itEvents, szEvent, iEvent)) return -1;

  return iEvent;
}

GetEventParamType(iEvent, iParam) {
  static Array:irgParamTypes; irgParamTypes = ArrayGetCell(g_rgirgEventParamTypes, iEvent);

  if (iParam <= ArraySize(irgParamTypes)) return EP_Invalid;

  return ArrayGetCell(irgParamTypes, iParam, _:EventParam_Type);
}

GetEventParamsNum(iEvent) {
  static Array:irgParamTypes; irgParamTypes = ArrayGetCell(g_rgirgEventParamTypes, iEvent);
  static iParamsNum; iParamsNum = ArraySize(irgParamTypes);

  return iParamsNum;
}

any:GetCurrentEventParam(iParam) {
  SetPackPosition(g_dpCurrentParamData, GetCurrentOffset(iParam));

  return ReadPackCell(g_dpCurrentParamData);
}

Float:GetCurrentEventParamFloat(iParam) {
  SetPackPosition(g_dpCurrentParamData, GetCurrentOffset(iParam));

  return ReadPackFloat(g_dpCurrentParamData);
}

GetCurrentEventParamString(iParam, szOut[], iLen) {
  SetPackPosition(g_dpCurrentParamData, GetCurrentOffset(iParam));

  ReadPackString(g_dpCurrentParamData, szOut, iLen);
}

GetCurrentEventParamArray(iParam, rgiOut[], iLen) {
  SetPackPosition(g_dpCurrentParamData, GetCurrentOffset(iParam));

  ReadPackArray(g_dpCurrentParamData, rgiOut, iLen)
}

GetCurrentEventParamFloatArray(iParam, Float:rgflOut[], iLen) {
  SetPackPosition(g_dpCurrentParamData, GetCurrentOffset(iParam));

  ReadPackFloatArray(g_dpCurrentParamData, rgflOut, iLen)
}

DataPackPos:GetCurrentOffset(iParam) {
  return ArrayGetCell(g_irgCurrentParamOffsets, iParam);
}

EmitEvent(const szEvent[], DataPack:dpParams, pEmitter) {
  static iEvent; iEvent = GetEventId(szEvent);

  if (pEmitter && !pev_valid(pEmitter)) {
    log_error(AMX_ERR_NATIVE, "%sCannot emit event ^"%s^" from entity! Invalid entity %d.", LOG_PREFIX, szEvent, pEmitter);
    return;
  }

  g_iCurrentEvent = iEvent;
  g_pCurrentEmitter = pEmitter;
  g_irgCurrentParamOffsets = GetEventParamOffsets(iEvent, dpParams);
  g_dpCurrentParamData = dpParams;

  static iForwardReturn; ExecuteForward(g_fwEmit, iForwardReturn, szEvent, pEmitter);

  if (iForwardReturn == PLUGIN_CONTINUE) {
    static Array:irgSubscribers; irgSubscribers = ArrayGetCell(g_rgirgEventSubscribers, iEvent);
    static Array:irgParamTypes; irgParamTypes = ArrayGetCell(g_rgirgEventParamTypes, iEvent);

    static iSubscribersNum; iSubscribersNum = ArraySize(irgSubscribers);
    for (new iSubscriber = 0; iSubscriber < iSubscribersNum; ++iSubscriber) {
      ResetPack(dpParams);

      static iPluginId; iPluginId = ArrayGetCell(irgSubscribers, iSubscriber, _:EventSubscriber_PluginId);
      static iFunctionId; iFunctionId = ArrayGetCell(irgSubscribers, iSubscriber, _:EventSubscriber_FunctionId);
      CallEventCallback(iPluginId, iFunctionId, dpParams, irgParamTypes);
    }
  }

  ArrayDestroy(g_irgCurrentParamOffsets);

  g_iCurrentEvent = -1;
  g_pCurrentEmitter = 0;
  g_irgCurrentParamOffsets = Invalid_Array;
  g_dpCurrentParamData = Invalid_DataPack;
}

Array:GetEventParamOffsets(iEvent, DataPack:dpParams) {
  static Array:irgOffsets; irgOffsets = ArrayCreate();

  static DataPackPos:iPos; iPos = GetPackPosition(dpParams);
  static Array:irgParamTypes; irgParamTypes = ArrayGetCell(g_rgirgEventParamTypes, iEvent);
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
  static iParamsNum; iParamsNum = ArraySize(irgParamTypes);

  callfunc_begin_i(iFunctionId, iPluginId);

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

  callfunc_end();
}
