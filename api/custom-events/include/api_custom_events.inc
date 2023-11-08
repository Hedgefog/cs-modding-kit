#if defined _api_custom_events_included
  #endinput
#endif
#define _api_custom_events_included

#pragma reqlib api_custom_events

enum {
  EP_Invalid = -1,
  EP_Cell,
  EP_Float,
  EP_String,
  EP_Array,
  EP_FloatArray
};

native CustomEvent_Register(const szId[], any:...);
native CustomEvent_Subscribe(const szId[], const szCallback[]);
native CustomEvent_Emit(const szId[], any:...);
native CustomEvent_GetParamsNum(const szId[]);
native CustomEvent_GetParamType(const szId[], iParam);
native any:CustomEvent_GetParam(iParam);
native Float:CustomEvent_GetParamFloat(iParam);
native CustomEvent_GetParamString(iParam, szOut[], iLen);
native CustomEvent_GetParamArray(iParam, rgiOut[], iLen);
native CustomEvent_GetParamFloatArray(iParam, Float:rgflOut[], iLen);
native CustomEvent_SetActivator(pEntity);
native CustomEvent_GetActivator();

forward CustomEvent_Fw_Emit(const szId[], pActivator);
