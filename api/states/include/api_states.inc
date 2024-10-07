#if defined _api_states_included
  #endinput
#endif
#define _api_states_included

#pragma reqlib api_states

#include <api_states_const>

/**
 * Registers a new state context with an initial state.
 *
 * @param szContext      The name of the state context.
 * @param initialState   The initial state to set for the context.
 * @noreturn
 */
native State_Context_Register(const szContext[], any:initialState = 0);

/**
 * Registers a guard callback to be invoked when any state changes within the context.
 *
 * @param szContext      The name of the state context.
 * @param szCallback     The name of the callback function to invoke on state change.
 * @noreturn
 */
native State_Context_RegisterChangeGuard(const szContext[], const szCallback[]);

/**
 * Registers a callback to be invoked when any state changes within the context.
 *
 * @param szContext      The name of the state context.
 * @param szCallback     The name of the callback function to invoke on state change.
 * @noreturn
 */
native State_Context_RegisterChangeHook(const szContext[], const szCallback[]);

/**
 * Registers a callback to be invoked when entering a specific state within the context.
 *
 * @param szContext      The name of the state context.
 * @param toState        The state that triggers the callback when entered.
 * @param szCallback     The name of the callback function to invoke on entering the specified state.
 * @noreturn
 */
native State_Context_RegisterEnterHook(const szContext[], any:toState, const szCallback[]);

/**
 * Registers a callback to be invoked when exiting a specific state within the context.
 *
 * @param szContext      The name of the state context.
 * @param fromState      The state that triggers the callback when exited.
 * @param szCallback     The name of the callback function to invoke on exiting the specified state.
 * @noreturn
 */
native State_Context_RegisterExitHook(const szContext[], any:fromState, const szCallback[]);

/**
 * Registers a callback to be invoked when transitioning from one state to another within the context.
 *
 * @param szContext      The name of the state context.
 * @param fromState      The state from which the transition begins.
 * @param toState        The state to which the transition occurs.
 * @param szCallback     The name of the callback function to invoke during the transition.
 * @noreturn
 */
native State_Context_RegisterTransitionHook(const szContext[], any:fromState, any:toState, const szCallback[]);

/**
 * Creates a new state manager for a given context and user token.
 *
 * @param szContext      The name of the state context.
 * @param userToken      A unique identifier associated with the user or object being managed.
 * @return               A handle to the created state manager.
 */
native StateManager:State_Manager_Create(const szContext[], any:userToken = 0);

/**
 * Destroys a state manager and releases associated resources.
 *
 * @param pManager       The state manager handle.
 * @noreturn
 */
native State_Manager_Destroy(const &StateManager:pManager);

/**
 * Resets the state of the state manager to its initial state.
 *
 * @param pManager       The state manager handle.
 * @noreturn
 */
native State_Manager_ResetState(const &StateManager:pManager);

/**
 * Sets a new state for the state manager with optional transition time.
 *
 * @param pManager           The state manager handle.
 * @param newState           The new state to set.
 * @param flTransitionTime   The time in seconds for the transition to occur. Default is 0.0.
 * @param bForce             If true, forces the state transition even if a transition is already in progress. Default is false.
 * @noreturn
 */
native bool:State_Manager_SetState(const &StateManager:pManager, any:newState, Float:flTransitionTime = 0.0, bool:bForce = false);

/**
 * Retrieves the current state from the state manager.
 *
 * @param pManager       The state manager handle.
 * @return               The current state.
 */
native any:State_Manager_GetState(const &StateManager:pManager);

/**
 * Retrieves the previous state from the state manager.
 *
 * @param pManager       The state manager handle.
 * @return               The previous state.
 */
native any:State_Manager_GetPrevState(const &StateManager:pManager);

/**
 * Retrieves the next state from the state manager.
 *
 * @param pManager       The state manager handle.
 * @return               The next state.
 */
native any:State_Manager_GetNextState(const &StateManager:pManager);

/**
 * Retrieves the user token associated with the state manager.
 *
 * @param pManager       The state manager handle.
 * @return               The user token.
 */
native any:State_Manager_GetUserToken(const &StateManager:pManager);

/**
 * Checks if the state manager is currently in a state transition.
 *
 * @param pManager       The state manager handle.
 * @return               True if a transition is in progress, false otherwise.
 */
native bool:State_Manager_IsInTransition(const &StateManager:pManager);

/**
 * Ends the pending state transition immediately.
 *
 * @param pManager       The state manager handle.
 * @noreturn
 */
native bool:State_Manager_EndTransition(const &StateManager:pManager);

/**
 * Cancels the scheduled state transition, if any.
 *
 * @param pManager       The state manager handle.
 * @noreturn
 */
native bool:State_Manager_CancelTransition(const &StateManager:pManager);

/**
 * Retrieves the current progress of the state transition.
 *
 * @param pManager       The state manager handle.
 * @return               The progress of the transition, expressed as a float value between 0.0 and 1.0.
 */
native Float:State_Manager_GetTransitionProgress(const &StateManager:pManager);
