#if defined _api_states_const_included
  #endinput
#endif
#define _api_states_const_included

#define STATE_CONTEXT_MAX_NAME_LEN 64
#define STATE_MAX_CONTEXTS 32
#define STATE_MAX_CONTEXT_HOOKS 64
#define STATE_MAX_CONTEXT_GUARDS 64
#define STATE_MAX_HOOKS (STATE_MAX_CONTEXTS * STATE_MAX_CONTEXT_HOOKS)
#define STATE_MAX_MANAGERS 256

#define STATE_GUARD_CONTINUE 0
#define STATE_GUARD_BLOCK 1

enum StateManager { StateManager_Invalid = -1 };
