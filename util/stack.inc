#if defined _stack_included
  #endinput
#endif
#define _stack_included

#if !defined STACK_MAX_SIZE
  #define STACK_MAX_SIZE 256
#endif

#define STACK_DEFINE(%1) static __stack_%1_size = 0; static __stack_%1_data[STACK_MAX_SIZE]
#define STACK_PUSH(%1,%2) __stack_%1_data[__stack_%1_size++] = %2
#define STACK_POP(%1) __stack_%1_data[--__stack_%1_size]
#define STACK_READ(%1) __stack_%1_data[__stack_%1_size - 1]
#define STACK_PATCH(%1,%2) __stack_%1_data[__stack_%1_size - 1] = %2
