#pragma semicolon 1

#include <amxmodx>
#include <function_pointer>

#include <api_states_const>

enum StateContext {
  StateContext_Id,
  StateContext_HooksNum,
  StateContext_InitialState,
  StateContext_Context[STATE_CONTEXT_MAX_NAME_LEN],
  StateContext_Hooks[STATE_MAX_CONTEXT_HOOKS],
};

enum StateManager {
  StateManager_ContextId,
  bool:StateManager_Free,
  any:StateManager_State,
  any:StateManager_NextState,
  any:StateManager_PrevState,
  Float:StateManager_ChangeTime,
  any:StateManager_UserToken
};

enum StateHookType {
  StateHookType_Change = 0,
  StateHookType_Enter,
  StateHookType_Exit,
  StateHookType_Transition
};

enum StateHook {
  StateHookType:StateHook_Type,
  any:StateHook_From,
  any:StateHook_To,
  Function:StateHook_Function
};

new g_rgStateHooks[STATE_MAX_HOOKS][StateHook];
new g_iStateHooksNum = 0;

new Trie:g_itStateContexts = Invalid_Trie;
new g_rgStateContexts[STATE_MAX_CONTEXTS][StateContext];
new g_iStateContextsNum = 0;

new g_rgStateManagers[STATE_MAX_MANAGERS][StateManager];
new g_iStateManagersNum = 0;

new g_iFreeStateManagersNum = 0;

/*--------------------------------[ Initialization ]--------------------------------*/

public plugin_precache() {
  g_itStateContexts = TrieCreate();
}

public plugin_init() {
  register_plugin("[API] States", "1.0.0", "Hedgehog Fog");
}

public plugin_natives() {
  register_library("api_states");

  register_native("State_Context_Register", "Native_RegisterContext");
  register_native("State_Context_RegisterChangeHook", "Native_RegisterContextChangeHook");
  register_native("State_Context_RegisterEnterHook", "Native_RegisterContextEnterHook");
  register_native("State_Context_RegisterExitHook", "Native_RegisterContextExitHook");
  register_native("State_Context_RegisterTransitionHook", "Native_RegisterContextTransitionHook");

  register_native("State_Manager_Create", "Native_CreateManager");
  register_native("State_Manager_Destroy", "Native_DestroyManager");
  register_native("State_Manager_ResetState", "Native_ResetManagerState");
  register_native("State_Manager_SetState", "Native_SetManagerState");
  register_native("State_Manager_GetState", "Native_GetManagerState");
  register_native("State_Manager_GetPrevState", "Native_GetManagerPrevState");
  register_native("State_Manager_GetNextState", "Native_GetManagerNextState");
  register_native("State_Manager_GetUserToken", "Native_GetManagerUserToken");

  register_native("State_Manager_IsInTransition", "Native_IsManagerInTransition");
  register_native("State_Manager_EndTransition", "Native_EndManagerTransition");
  register_native("State_Manager_CancelTransition", "Native_CancelManagerTransition");
}

/*--------------------------------[ Natives ]--------------------------------*/

public Native_RegisterContext(iPluginId, iArgc) {
  new szContext[STATE_CONTEXT_MAX_NAME_LEN]; get_string(1, szContext, charsmax(szContext));
  new any:initialState = any:get_param(2);

  return State_RegisterContext(szContext, initialState);
}

public Native_RegisterContextChangeHook(iPluginId, iArgc) {
  new szContext[STATE_CONTEXT_MAX_NAME_LEN]; get_string(1, szContext, charsmax(szContext));
  new szFunction[STATE_CONTEXT_MAX_NAME_LEN]; get_string(2, szFunction, charsmax(szFunction));

  return State_RegisterHook(szContext, StateHookType_Change, _, _, get_func_pointer(szFunction, iPluginId));
}

public Native_RegisterContextEnterHook(iPluginId, iArgc) {
  new szContext[STATE_CONTEXT_MAX_NAME_LEN]; get_string(1, szContext, charsmax(szContext));
  new any:toState = any:get_param(2);
  new szFunction[STATE_CONTEXT_MAX_NAME_LEN]; get_string(3, szFunction, charsmax(szFunction));

  return State_RegisterHook(szContext, StateHookType_Enter, _, toState, get_func_pointer(szFunction, iPluginId));
}

public Native_RegisterContextExitHook(iPluginId, iArgc) {
  new szContext[STATE_CONTEXT_MAX_NAME_LEN]; get_string(1, szContext, charsmax(szContext));
  new any:fromState = any:get_param(2);
  new szFunction[STATE_CONTEXT_MAX_NAME_LEN]; get_string(3, szFunction, charsmax(szFunction));

  return State_RegisterHook(szContext, StateHookType_Exit, fromState, _, get_func_pointer(szFunction, iPluginId));
}

public Native_RegisterContextTransitionHook(iPluginId, iArgc) {
  new szContext[STATE_CONTEXT_MAX_NAME_LEN]; get_string(1, szContext, charsmax(szContext));
  new any:fromState = any:get_param(2);
  new any:toState = any:get_param(3);
  new szFunction[STATE_CONTEXT_MAX_NAME_LEN]; get_string(4, szFunction, charsmax(szFunction));

  return State_RegisterHook(szContext, StateHookType_Transition, fromState, toState, get_func_pointer(szFunction, iPluginId));
}

public Native_CreateManager(iPluginId, iArgc) {
  new szContext[STATE_CONTEXT_MAX_NAME_LEN]; get_string(1, szContext, charsmax(szContext));
  new any:userToken = any:get_param(2);

  return State_Manager_Create(szContext, userToken);
}

public Native_DestroyManager(iPluginId, iArgc) {
  static iManagerId; iManagerId = get_param_byref(1);
  
  State_Manager_Destroy(iManagerId);
}

public Native_ResetManagerState(iPluginId, iArgc) {
  static iManagerId; iManagerId = get_param_byref(1);
  
  State_Manager_ResetState(iManagerId);
}

public Native_SetManagerState(iPluginId, iArgc) {
  static iManagerId; iManagerId = get_param_byref(1);
  static any:newState; newState = any:get_param(2);
  static Float:flTransitionTime; flTransitionTime = get_param_f(3);
  static bool:bForce; bForce = bool:get_param(4);

  State_Manager_SetState(iManagerId, newState, flTransitionTime, bForce);
}

public any:Native_GetManagerState(iPluginId, iArgc) {
  static iManagerId; iManagerId = get_param_byref(1);

  return g_rgStateManagers[iManagerId][StateManager_State];
}

public any:Native_GetManagerPrevState(iPluginId, iArgc) {
  static iManagerId; iManagerId = get_param_byref(1);

  return g_rgStateManagers[iManagerId][StateManager_PrevState];
}

public any:Native_GetManagerNextState(iPluginId, iArgc) {
  static iManagerId; iManagerId = get_param_byref(1);

  return g_rgStateManagers[iManagerId][StateManager_NextState];
}

public any:Native_GetManagerUserToken(iPluginId, iArgc) {
  static iManagerId; iManagerId = get_param_byref(1);

  return g_rgStateManagers[iManagerId][StateManager_UserToken];
}

public bool:Native_IsManagerInTransition(iPluginId, iArgc) {
  static iManagerId; iManagerId = get_param_byref(1);

  return State_Manager_IsInTransition(iManagerId);
}

public Native_CancelManagerTransition(iPluginId, iArgc) {
  static iManagerId; iManagerId = get_param_byref(1);

  State_Manager_CancelTransition(iManagerId);
}

public Native_EndManagerTransition(iPluginId, iArgc) {
  static iManagerId; iManagerId = get_param_byref(1);

  State_Manager_EndTransition(iManagerId);
}

/*--------------------------------[ Functions ]--------------------------------*/

State_RegisterContext(const szContext[], any:initialState) {
  new iId = g_iStateContextsNum;

  g_rgStateContexts[iId][StateContext_Id] = iId;
  g_rgStateContexts[iId][StateContext_InitialState] = initialState;
  copy(g_rgStateContexts[iId][StateContext_Context], charsmax(g_rgStateContexts[][StateContext_Context]), szContext);

  g_iStateContextsNum++;

  return iId;
}

State_RegisterHook(const szContext[], StateHookType:iType, any:fromState = 0, any:toState = 0, Function:fnCallback) {
  new iId = g_iStateHooksNum;

  g_rgStateHooks[iId][StateHook_From] = fromState;
  g_rgStateHooks[iId][StateHook_To] = toState;
  g_rgStateHooks[iId][StateHook_Function] = fnCallback;
  g_rgStateHooks[iId][StateHook_Type] = iType;

  new iContextId; TrieGetCell(g_itStateContexts, szContext, iContextId);
  new iContextHookId = g_rgStateContexts[iContextId][StateContext_HooksNum];

  g_rgStateContexts[iContextId][StateContext_Hooks][iContextHookId] = iId;
  g_rgStateContexts[iContextId][StateContext_HooksNum]++;

  g_iStateHooksNum++;

  return iId;
}

State_Manager_Create(const szContext[], any:userToken) {
  new iId = State_Manager_AllocateId();

  new iContextId; TrieGetCell(g_itStateContexts, szContext, iContextId);

  g_rgStateManagers[iId][StateManager_ContextId] = iContextId;
  g_rgStateManagers[iId][StateManager_Free] = false;
  g_rgStateManagers[iId][StateManager_UserToken] = userToken;

  State_Manager_ResetState(iId);

  g_iStateManagersNum++;

  return iId;
}

State_Manager_AllocateId() {
  if (g_iFreeStateManagersNum) {
    for (new iId = 0; iId < g_iStateManagersNum; ++iId) {
      if (g_rgStateManagers[iId][StateManager_Free]) {
        g_rgStateManagers[iId][StateManager_Free] = false;
        g_iFreeStateManagersNum--;
        return iId;
      }
    }
  }

  return g_iStateManagersNum < STATE_MAX_MANAGERS ? g_iStateManagersNum : -1;
}

State_Manager_Destroy(const iManagerId) {
  if (iManagerId == g_iStateManagersNum - 1) {
    g_iStateManagersNum--;
    return;
  }

  g_rgStateManagers[iManagerId][StateManager_Free] = true;
  g_iFreeStateManagersNum++;
}

State_Manager_ResetState(const iManagerId) {
  static iContextId; iContextId = g_rgStateManagers[iManagerId][StateManager_ContextId];

  g_rgStateManagers[iManagerId][StateManager_State] = g_rgStateContexts[iContextId][StateContext_InitialState];
  g_rgStateManagers[iManagerId][StateManager_PrevState] = g_rgStateContexts[iContextId][StateContext_InitialState];
  g_rgStateManagers[iManagerId][StateManager_NextState] = g_rgStateContexts[iContextId][StateContext_InitialState];
  g_rgStateManagers[iManagerId][StateManager_ChangeTime] = 0.0;
  
  remove_task(iManagerId);
}

State_Manager_SetState(const iManagerId, any:newState, Float:flTransitionTime, bool:bForce = false) {
  static Float:flGameTime; flGameTime = get_gametime();

  if (g_rgStateManagers[iManagerId][StateManager_ChangeTime] > flGameTime) {
    if (!bForce) return;
    State_Manager_CancelTransition(iManagerId);
  }

  g_rgStateManagers[iManagerId][StateManager_NextState] = newState;
  g_rgStateManagers[iManagerId][StateManager_ChangeTime] = flGameTime + flTransitionTime;

  if (flTransitionTime > 0.0) {
    set_task(flTransitionTime, "Task_UpdateManagerState", iManagerId);
  } else {
    State_Manager_Update(iManagerId);
  }
}

bool:State_Manager_IsInTransition(const iManagerId) {
  return g_rgStateManagers[iManagerId][StateManager_ChangeTime] > get_gametime();
}

State_Manager_EndTransition(const iManagerId) {
  remove_task(iManagerId);
  g_rgStateManagers[iManagerId][StateManager_ChangeTime] = get_gametime();
  State_Manager_Update(iManagerId);
}

State_Manager_CancelTransition(const iManagerId) {
  remove_task(iManagerId);
  g_rgStateManagers[iManagerId][StateManager_NextState] = g_rgStateManagers[iManagerId][StateManager_State];
  g_rgStateManagers[iManagerId][StateManager_ChangeTime] = get_gametime();
}

State_Manager_Update(const iManagerId) {
  static any:currentState; currentState = g_rgStateManagers[iManagerId][StateManager_State];
  static any:nextState; nextState = g_rgStateManagers[iManagerId][StateManager_NextState];

  if (currentState == nextState) return;
  if (State_Manager_IsInTransition(iManagerId)) return;

  g_rgStateManagers[iManagerId][StateManager_State] = nextState;
  g_rgStateManagers[iManagerId][StateManager_PrevState] = currentState;

  // Handle hooks
  static iContextId; iContextId = g_rgStateManagers[iManagerId][StateManager_ContextId];
  static iHooksNum; iHooksNum = g_rgStateContexts[iContextId][StateContext_HooksNum];

  for (new iHook = 0; iHook < iHooksNum; ++iHook) {
    static iHookId; iHookId = g_rgStateContexts[iContextId][StateContext_Hooks][iHook];

    switch (g_rgStateHooks[iHookId][StateHook_Type]) {
      case StateHookType_Transition: {
        if (g_rgStateHooks[iHookId][StateHook_From] != currentState) continue;
        if (g_rgStateHooks[iHookId][StateHook_To] != nextState) continue;
      }
      case StateHookType_Enter: {
        if (g_rgStateHooks[iHookId][StateHook_To] != nextState) continue;
      }
      case StateHookType_Exit: {
        if (g_rgStateHooks[iHookId][StateHook_From] != currentState) continue;
      }
    }

    callfunc_begin_p(g_rgStateHooks[iHookId][StateHook_Function]);
    callfunc_push_int(iManagerId);
    callfunc_push_int(currentState);
    callfunc_push_int(nextState);
    callfunc_end();
  }
}

public Task_UpdateManagerState(iTaskId) {
  static iManagerId; iManagerId = iTaskId;

  State_Manager_Update(iManagerId);
}
