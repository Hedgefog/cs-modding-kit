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

/**
 * Registers a custom event with the specified ID and parameter types.
 *
 * @param szEvent The ID of the custom event.
 * @param any The parameter types for the custom event.
 *
 * @noreturn
*/
native CustomEvent_Register(const szEvent[], any:...);

/**
 * Subscribes to the specified custom event with the given callback function.
 *
 * @param szEvent The ID of the custom event.
 * @param szCallback The name of the callback function.
 *
 * @noreturn
 */
native CustomEvent_Subscribe(const szEvent[], const szCallback[]);

/**
 * Emits the specified custom event with the given parameters.
 *
 * @param szEvent The ID of the custom event.
 * @param any The parameters to be emitted.
 *
 * @noreturn
 */
native CustomEvent_Emit(const szEvent[], any:...);

/**
 * Gets the number of parameters for the specified custom event.
 * @param szEvent The ID of the custom event.
 *
 * @return The number of parameters for the custom event.
 */
native CustomEvent_GetParamsNum(const szEvent[]);

/**
 * Gets the type of the specified parameter for the custom event.
 *
 * @param szEvent The ID of the custom event.
 * @param iParam The index of the parameter, starting from 1.
 *
 * @return The type of the parameter.
 */
native CustomEvent_GetParamType(const szEvent[], iParam);

/**
 * Gets the value of the specified parameter for the custom event.
 * 
 * @param iParam The index of the parameter, starting from 1.
 *
 * @return The value of the parameter.
 */
native any:CustomEvent_GetParam(iParam);

/**
 * Gets the floating-point value of the specified parameter for the custom event.
 * 
 * @param iParam The index of the parameter, starting from 1.
 * 
 * @return The floating-point value of the parameter.
 */
native Float:CustomEvent_GetParamFloat(iParam);

/**
 * Gets the string value of the specified parameter for the custom event.
 *
 * @param iParam The index of the parameter, starting from 1.
 * @param szOut Buffer to store the string value.
 * @param iLen The maximum length of the output buffer.
 *
 * @noreturn
 */
native CustomEvent_GetParamString(iParam, szOut[], iLen);

/**
 * Gets the integer array value of the specified parameter for the custom event.
 *
 * @param iParam The index of the parameter, starting from 1.
 * @param rgiOut Buffer to store the integer array value.
 * @param iLen The maximum length of the output buffer.
 *
 * @noreturn
 */
native CustomEvent_GetParamArray(iParam, rgiOut[], iLen);

/**
 * Gets the floating-point array value of the specified parameter for the custom event.
 *
 * @param iParam The index of the parameter, starting from 1.
 * @param rgflOut Buffer to store the floating-point array value.
 * @param iLen The maximum length of the output buffer.
 *
 * @noreturn
 */
native CustomEvent_GetParamFloatArray(iParam, Float:rgflOut[], iLen);

/**
 * Sets the activator for the custom event.
 *
 * @param pEntity The entity to set as the activator.
 *
 * @noreturn
 */
native CustomEvent_SetActivator(pEntity);

/**
 * Retrieves the activator of the custom event.
 *
 * @return The activator entity of the custom event.
 */
native CustomEvent_GetActivator();

/**
 * Forwards the specified custom event with the given parameters and activator.
 *
 * @param szEvent The ID of the custom event.
 * @param pActivator The activator of the event. Pass 0 if no activator is needed.
 *
 * @noreturn
 */
forward CustomEvent_Fw_Emit(const szEvent[], pActivator);
