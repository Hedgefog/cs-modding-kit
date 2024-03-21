#if defined _api_custom_events_const_included
  #endinput
#endif
#define _api_custom_events_const_included

#define MAX_CUSTOM_EVENT_KEY_LENGTH 64

enum {
  EP_Invalid = -1,
  EP_Cell,
  EP_Float,
  EP_String,
  EP_Array,
  EP_FloatArray
};