#if defined _classes_included
  #endinput
#endif
#define _classes_included

#include <amxmodx>
#include <cellstruct>
#include <function_pointer>

#if !defined CLASS_METHOD_CALL_STACK_SIZE
  #define CLASS_METHOD_CALL_STACK_SIZE 1024
#endif

#if !defined CLASS_METHOD_MAX_NAME_LENGTH
  #define CLASS_METHOD_MAX_NAME_LENGTH 64
#endif

#if !defined CLASS_METHOD_MAX_ARGUMENTS
  #define CLASS_METHOD_MAX_ARGUMENTS 32
#endif

#if !defined CLASS_PARAM_BUFFER_LENGTH
  #define CLASS_PARAM_BUFFER_LENGTH 16384
#endif

// Default argument values

#define __cls_DefaultValue_Cell 0
#define __cls_DefaultValue_Float 0.0
#define __cls_DefaultValue_String NULL_STRING

// Error messages

#define __cls_err_NotImplementedMethod "Method ^"%s^" is not implemented!"
#define __cls_err_AddMethodWithoutFunctionPointer "Cannot add unimplemented method ^"%s^"!"
#define __cls_err_MethodAlreadyRegistered "Method ^"%s^" is already registered for the class!"
#define __cls_err_VMethodArgumentsMismatch "Arguments mismatch in the overridden virtual method ^"%s^"!"
#define __cls_err_ClassIdNotFound "Class with id %d is not registered!"
#define __cls_err_MethodNotFound "Method ^"%s^" is not registered for the instance (%d)!"
#define __cls_err_CallMethodOutsideContext "Calling a method is not allowed outside of the execution context!"
#define __cls_err_ClassHasNoBaseClass "Cannot call base method of class without base class!"
#define __cls_err_MethodNotFoundInBaseClass "Cannot find method ^"%s^" in base classes!"
#define __cls_err_MaxCallStackSizeExceeded "Maximum call stack size exceeded!"
#define __cls_err_ClassMethodCallEndWithoutStart "Call ClassInstanceCallMethodEnd but method call is not started!"
#define __cls_err_NumberOfParametersExceeded "Number of argument(s) to call ^"%s^" exceeded! Expected %d, got %d."
#define __cls_err_MissingRequiredArguments "Missing required argument(s) to call ^"%s^"! Expected %d, got %d."
#define __cls_err_InvalidParamType "Invalid parameter type at position %d for call method %s. Expected: ^"%s^" got ^"%s^"!"
#define __cls_err_FailedToCallMethodFunction "Failed to call method ^"%s^" function!"

#define __cls_MethodParamOffset(%1) (%1 * _:__cls_MethodParamData)

enum Class {
  Invalid_Class = -1
};

enum ClassInstance {
  Invalid_ClassInstance = -1
};

enum _:__cls_ParamTypes {
  CMP_Invalid = -1,
  CMP_Cell,
  CMP_String,
  CMP_Array,
  CMP_CellRef,
  CMP_StringRef,
  CMP_ArrayRef,
  CMP_ParamsCellArray,
  CMP_Variadic
};

stock const __cls_ParamTypeNames[__cls_ParamTypes][64] = {
  "Cell",
  "String",
  "Array",
  "CellRef",
  "StringRef",
  "ArrayRef",
  "ParamsCellArray",
  "..."
};

// Internal structures

enum __cls_MethodType {
  __cls_MethodType_Invalid = -1,
  __cls_MethodType_Method,
  __cls_MethodType_Virtual,
  __cls_MethodType_Getter,
  __cls_MethodType_Setter
};

enum __cls_Data {
    Class:__cls_Data_Base,
    Trie:__cls_Data_Members,
    Trie:__cls_Data_Methods,
    Trie:__cls_Data_Setters,
    Trie:__cls_Data_Getters
};

enum __cls_MethodParamData {
  __cls_MethodParamData_Type = 0,
  __cls_MethodParamData_Size
};

enum __cls_MethodData {
  __cls_MethodData_Name[CLASS_METHOD_MAX_NAME_LENGTH],
  Class:__cls_MethodData_Class,
  __cls_MethodData_Function,
  __cls_MethodData_VariadicParams,
  __cls_MethodType:__cls_MethodData_Type,
  __cls_MethodData_ParamTypesNum,
  __cls_MethodData_ParamTypes[__cls_MethodParamOffset(CLASS_METHOD_MAX_ARGUMENTS + 1)]
};

enum __cls_InstanceData {
  Class:__cls_InstanceData_Class,
  Trie:__cls_InstanceData_Members
};

enum __cls_InstanceCache {
  ClassInstance:__cls_InstanceCache_Instance,
  any:__cls_InstanceCache_Value
};

// Fast pseudo-stack implementation
stock ClassInstance:__cls_callstack_pInstance[CLASS_METHOD_CALL_STACK_SIZE];
stock Class:__cls_callstack_class[CLASS_METHOD_CALL_STACK_SIZE];
stock Struct:__cls_callstack_sMethod[CLASS_METHOD_CALL_STACK_SIZE];
stock __cls_callstack_size = 0;

#define __cls_callstack_iLastItem (__cls_callstack_size - 1)

// Variables to store info between Begin and End method calls
stock Class:__cls_call_class = Invalid_Class;
stock ClassInstance:__cls_call_pInstance = Invalid_ClassInstance;
stock Struct:__cls_call_sMethod = Invalid_Struct;
stock __cls_call_iParamTypesNum = 0;
stock __cls_call_iRequiredParamsNum = 0;
stock __cls_call_iParamsNum = 0;
stock __cls_call_iBufferPos = 0;

// Cache
stock __cls_cache_InstanceClass[__cls_InstanceCache] = { Invalid_ClassInstance, Invalid_Class };
stock __cls_cache_InstanceMethods[__cls_InstanceCache] = { Invalid_ClassInstance, Invalid_Trie };
stock __cls_cache_InstanceMembers[__cls_InstanceCache] = { Invalid_ClassInstance, Invalid_Trie };
stock __cls_cache_InstanceGetters[__cls_InstanceCache] = { Invalid_ClassInstance, Invalid_Trie };
stock __cls_cache_InstanceSetters[__cls_InstanceCache] = { Invalid_ClassInstance, Invalid_Trie };

// Buffers
stock any:__cls_rgBuffer[CLASS_PARAM_BUFFER_LENGTH];

/*--------------------------------[ Class Functions] --------------------------------*/

stock Class:ClassCreate(const &Class:sBaseClass = Invalid_Class) {
  new Struct:class = StructCreate(__cls_Data);
  StructSetCell(class, __cls_Data_Base, sBaseClass);
  StructSetCell(class, __cls_Data_Members, Invalid_Trie);
  StructSetCell(class, __cls_Data_Methods, Invalid_Trie);
  StructSetCell(class, __cls_Data_Setters, Invalid_Trie);
  StructSetCell(class, __cls_Data_Getters, Invalid_Trie);

  return Class:class;
}

stock ClassDestroy(&Class:class) {
  new Trie:itMethods = StructGetCell(Struct:class, __cls_Data_Methods);
  if (itMethods != Invalid_Trie) {
    __cls_DestroyMethodsTrie(itMethods);
  }

  new Trie:itGetters = StructGetCell(Struct:class, __cls_Data_Getters);
  if (itGetters != Invalid_Trie) {
    __cls_DestroyMethodsTrie(itGetters);
  }

  new Trie:itSetters = StructGetCell(Struct:class, __cls_Data_Setters);
  if (itSetters != Invalid_Trie) {
    __cls_DestroyMethodsTrie(itSetters);
  }

  new Trie:itMembers = StructGetCell(Struct:class, __cls_Data_Members);
  if (itMembers != Invalid_Trie) {
    TrieDestroy(itMembers);
  }

  StructDestroy(Struct:class);

  class = Invalid_Class;
}

stock Class:ClassAddMethod(const &Class:class, const szMethod[], const Function:func, bool:bVirtual = false, any:...) {
  static const iArgOffset = 4;

  new iArgc = numargs();

  new Class:sBaseClass = StructGetCell(Struct:class, __cls_Data_Base);
  new Trie:itMethods = __cls_GetClassMethodsTrie(class, __cls_MethodType_Method, true);

  if (TrieKeyExists(itMethods, szMethod)) {
    set_fail_state(__cls_err_MethodAlreadyRegistered, szMethod);
    return;
  }

  if (func == Invalid_FunctionPointer && !bVirtual) {
    set_fail_state(__cls_err_AddMethodWithoutFunctionPointer, szMethod);
    return;
  }

  new Array:irgArgs = ArrayCreate();
  new bool:bVariadicParams = false;

  // Some arguments are used to decribe type properties, so we need to skip type check for these arguments
  new bool:bSkipTypeCheck = false;

  for (new iArg = iArgOffset; iArg < iArgc; ++iArg) {
    new any:arg = getarg(iArg);


    if (!bSkipTypeCheck) {
      switch (arg) {
        case CMP_Array, CMP_ArrayRef, CMP_ParamsCellArray: {
          bSkipTypeCheck = true;
        }
        case CMP_Variadic: {
          iArgc = iArg;
          bVariadicParams = true;
          break;
        }
      }
    } else {
      bSkipTypeCheck = false;
    }

    ArrayPushCell(irgArgs, arg);
  }

  new Array:irgParamTypes; irgParamTypes = ArrayCreate(_:__cls_MethodParamData, iArgc - iArgOffset);
  __cls_ParseParamTypes(irgArgs, irgParamTypes);

  ArrayDestroy(irgArgs);

  if (sBaseClass != Invalid_Class) {
    new Struct:sBaseMethod = __cls_FindClassMethodInHierarchy(sBaseClass, szMethod, __cls_MethodType_Method);
    if (sBaseMethod != Invalid_Struct) {
      if (StructGetCell(sBaseMethod, __cls_MethodData_Type) == __cls_MethodType_Virtual) {
        if (!__cls_CompareParamTypes(sBaseMethod, irgParamTypes)) {
          set_fail_state(__cls_err_VMethodArgumentsMismatch, szMethod);
          return;
        }
      }
    }
  }

  new Struct:sMethod = __cls_CreateMethod(class, szMethod, func, irgParamTypes, bVirtual ? __cls_MethodType_Virtual : __cls_MethodType_Method, bVariadicParams);

  ArrayDestroy(irgParamTypes);

  TrieSetCell(itMethods, szMethod, sMethod);
}

stock Function:ClassGetMethodFunction(const &Class:class, const szMethod[]) {
    static Trie:itMethods; itMethods = __cls_GetClassMethodsTrie(class, __cls_MethodType_Method, false);

    if (itMethods == Invalid_Trie) return Invalid_FunctionPointer;

    static Struct:sMethod;
    if (!TrieGetCell(itMethods, szMethod, sMethod)) return Invalid_FunctionPointer;

    return StructGetCell(sMethod, __cls_MethodData_Function);
}

stock Struct:ClassGetMethodPointer(const &Class:class, const szMethod[]) {
    static Trie:itMethods; itMethods = __cls_GetClassMethodsTrie(class, __cls_MethodType_Method, false);

    if (itMethods == Invalid_Trie) return Invalid_Struct;

    static Struct:sMethod;
    if (!TrieGetCell(itMethods, szMethod, sMethod)) return Invalid_Struct;

    return sMethod;
}

stock ClassAddSetter(const &Class:class, const szMember[], const Function:func, iType, iSize = 1) {
  __cls_AddMemberAccessorMethod(class, szMember, func, __cls_MethodType_Setter, iType, iSize);
}

stock ClassAddGetter(const &Class:class, const szMember[], const Function:func, iType, iSize = 1) {
  __cls_AddMemberAccessorMethod(class, szMember, func, __cls_MethodType_Getter, iType, iSize);
}

stock Class:ClassGetBaseClass(const &Class:class) {
  return StructGetCell(Struct:class, __cls_Data_Base);
}

stock bool:ClassHasMetadata(const &Class:class, const szMember[]) {
  static Trie:itMembers; itMembers = __cls_GetClassMembersTrie(class, false);

  if (itMembers == Invalid_Trie) return false;

  return TrieKeyExists(itMembers, szMember);
}

stock ClassDeleteMetadata(const &Class:class, const szMember[]) {
  static Trie:itMembers; itMembers = __cls_GetClassMembersTrie(class, false);

  if (itMembers == Invalid_Trie) return;

  TrieDeleteKey(itMembers, szMember);
}

stock any:ClassGetMetadata(const &Class:class, const szMember[]) {
  static Trie:itMembers; itMembers = __cls_GetClassMembersTrie(class, false);

  if (itMembers == Invalid_Trie) return 0;

  static any:value;
  return TrieGetCell(itMembers, szMember, value) ? value : 0;
}

stock ClassSetMetadata(const &Class:class, const szMember[], any:value, bool:bReplace = true) {
  static Trie:itMembers; itMembers = __cls_GetClassMembersTrie(class, true);

  TrieSetCell(itMembers, szMember, value, bReplace);
}

stock bool:ClassGetMetadataString(const &Class:class, const szMember[], szOut[], iMaxLen) {
  static Trie:itMembers; itMembers = __cls_GetClassMembersTrie(class, false);

  if (itMembers == Invalid_Trie) return false;

  copy(szOut, iMaxLen, NULL_STRING);
  return !!TrieGetString(itMembers, szMember, szOut, iMaxLen);
}

stock ClassSetMetadataString(const &Class:class, const szMember[], const szValue[], bool:bReplace = true) {
  static Trie:itMembers; itMembers = __cls_GetClassMembersTrie(class, true);

  TrieSetString(itMembers, szMember, szValue, bReplace);
}

stock bool:ClassGetMetadataArray(const &Class:class, const szMember[], any:rgOut[], iLen) {
  static Trie:itMembers; itMembers = __cls_GetClassMembersTrie(class, false);

  if (itMembers == Invalid_Trie) return false;

  return !!TrieGetArray(itMembers, szMember, rgOut, iLen);
}

stock ClassSetMetadataArray(const &Class:class, const szMember[], const any:rgValue[], iLen, bool:bReplace = true) {
  static Trie:itMembers; itMembers = __cls_GetClassMembersTrie(class, true);

  TrieSetArray(itMembers, szMember, rgValue, iLen, bReplace);
}

/*--------------------------------[ Class Instance Functions] --------------------------------*/

stock ClassInstance:ClassInstanceCreate(const &Class:class) {
  static Struct:sInstance; sInstance = StructCreate(__cls_InstanceData);
  StructSetCell(sInstance, __cls_InstanceData_Class, class);
  StructSetCell(sInstance, __cls_InstanceData_Members, Invalid_Trie);

  return ClassInstance:sInstance;
}

stock ClassInstanceDestroy(&ClassInstance:pInstance) {
  if (pInstance == __cls_cache_InstanceClass[__cls_InstanceCache_Instance]) {
    __cls_cache_InstanceClass[__cls_InstanceCache_Instance] = Invalid_ClassInstance;
  }

  if (pInstance == __cls_cache_InstanceMembers[__cls_InstanceCache_Instance]) {
    __cls_cache_InstanceMembers[__cls_InstanceCache_Instance] = Invalid_ClassInstance;
  }

  if (pInstance == __cls_cache_InstanceGetters[__cls_InstanceCache_Instance]) {
    __cls_cache_InstanceGetters[__cls_InstanceCache_Instance] = Invalid_ClassInstance;
  }

  if (pInstance == __cls_cache_InstanceSetters[__cls_InstanceCache_Instance]) {
    __cls_cache_InstanceSetters[__cls_InstanceCache_Instance] = Invalid_ClassInstance;
  }

  static Trie:itMembers; itMembers = StructGetCell(Struct:pInstance, __cls_InstanceData_Members);
  if (itMembers != Invalid_Trie) {
    TrieDestroy(itMembers);
  }

  StructDestroy(Struct:pInstance);

  pInstance = Invalid_ClassInstance;
}

stock ClassInstance:ClassInstanceGetCurrent() {
  if (!__cls_callstack_size) {
    set_fail_state(__cls_err_CallMethodOutsideContext);
    return Invalid_ClassInstance;
  }

  return __cls_callstack_pInstance[__cls_callstack_iLastItem];
}

stock Class:ClassInstanceGetCurrentClass() {
  if (!__cls_callstack_size) {
    set_fail_state(__cls_err_CallMethodOutsideContext);
    return Invalid_Class;
  }

  return __cls_callstack_class[__cls_callstack_iLastItem];
}

#define __cls_READ_METHOD_CALL_PARAMS(%1) {\
  static iParamsNum; iParamsNum = min(__cls_call_iParamTypesNum, numargs() - %1);\
\
  for (new iMethodParam = 0; iMethodParam < iParamsNum; ++iMethodParam) {\
    static iArgument; iArgument = %1 + iMethodParam;\
    static iType; iType = StructGetCell(__cls_call_sMethod, __cls_MethodData_ParamTypes, __cls_MethodParamOffset(iMethodParam) + _:__cls_MethodParamData_Type);\
\
    switch (iType) {\
      case CMP_Cell, CMP_CellRef: {\
        __cls_rgBuffer[__cls_call_iBufferPos] = any:getarg(iArgument);\
\
        switch (iType) {\
          case CMP_CellRef: ClassInstanceCallMethodPushParamCellRef(__cls_rgBuffer[__cls_call_iBufferPos]);\
          case CMP_Cell: ClassInstanceCallMethodPushParamCell(__cls_rgBuffer[__cls_call_iBufferPos]);\
        }\
\
        __cls_call_iBufferPos++;\
      }\
      case CMP_String, CMP_StringRef: {\
        static iMaxLen; iMaxLen = charsmax(__cls_rgBuffer) - __cls_call_iBufferPos;\
\
        static iLen;\
        for (iLen = 0; iLen < iMaxLen && __cls_rgBuffer[__cls_call_iBufferPos - 1] != '^0'; ++iLen)\
          __cls_rgBuffer[__cls_call_iBufferPos++] = getarg(iArgument, iLen);\
\
        switch (iType) {\
          case CMP_StringRef: ClassInstanceCallMethodPushParamStringRef(__cls_rgBuffer[__cls_call_iBufferPos], iLen);\
          case CMP_String: ClassInstanceCallMethodPushParamString(__cls_rgBuffer[__cls_call_iBufferPos]);\
        }\
      }\
      case CMP_Array, CMP_ArrayRef: {\
        static iSize; iSize = StructGetCell(__cls_call_sMethod, __cls_MethodData_ParamTypes, __cls_MethodParamOffset(iMethodParam) + _:__cls_MethodParamData_Size);\
\
        static i;\
        for (i = 0; i < iSize; ++i)\
          __cls_rgBuffer[__cls_call_iBufferPos + i] = any:getarg(iArgument, i);\
\
        switch (iType) {\
          case CMP_ArrayRef: ClassInstanceCallMethodPushParamArrayRef(__cls_rgBuffer[__cls_call_iBufferPos], iSize);\
          case CMP_Array: ClassInstanceCallMethodPushParamArray(__cls_rgBuffer[__cls_call_iBufferPos], iSize);\
        }\
\
        __cls_call_iBufferPos += iSize;\
      }\
    }\
  }\
}

stock any:ClassInstanceCallMethod(const &ClassInstance:pInstance, const szMethod[], any:...) {
  __cls_CallMethodBegin(pInstance, szMethod, _, __cls_MethodType_Method);

  __cls_READ_METHOD_CALL_PARAMS(2)

  return ClassInstanceCallMethodEnd();
}

stock ClassInstanceCallMethodOf(const &ClassInstance:pInstance, const szMethod[], const &Class:class = Invalid_Class, any:...) {
  __cls_CallMethodBegin(pInstance, szMethod, class, __cls_MethodType_Method);

  __cls_READ_METHOD_CALL_PARAMS(3)

  return ClassInstanceCallMethodEnd();
}

stock ClassInstanceCallMethodByPointer(const &ClassInstance:pInstance, const &Struct:sMethod, any:...) {
  __cls_CallMethodByPointerBegin(pInstance, sMethod);

  __cls_READ_METHOD_CALL_PARAMS(2)

  return ClassInstanceCallMethodEnd();
}

stock ClassInstanceCallBaseMethod(any:...) {
  ClassInstanceCallMethodBeginBase();

  __cls_READ_METHOD_CALL_PARAMS(0)

  return ClassInstanceCallMethodEnd();
}

stock ClassInstanceCallMethodBegin(const &ClassInstance:pInstance, const szMethod[], const &Class:class = Invalid_Class) {
  __cls_CallMethodBegin(pInstance, szMethod, class, __cls_MethodType_Method);
}

stock ClassInstanceCallMethodBeginBase(any:...) {
  if (!__cls_callstack_size) {
    set_fail_state(__cls_err_CallMethodOutsideContext);
    return;
  }

  static Class:class; class = StructGetCell(Struct:__cls_callstack_class[__cls_callstack_iLastItem], __cls_Data_Base);
  if (class == Invalid_Class) {
    set_fail_state(__cls_err_ClassHasNoBaseClass);
    return;
  }

  static szMethod[CLASS_METHOD_MAX_NAME_LENGTH]; StructGetString(__cls_callstack_sMethod[__cls_callstack_iLastItem], __cls_MethodData_Name, szMethod, charsmax(szMethod));
  static __cls_MethodType:iMethodType; iMethodType = StructGetCell(__cls_callstack_sMethod[__cls_callstack_iLastItem], __cls_MethodData_Type);

  __cls_InitMethodCall(__cls_callstack_pInstance[__cls_callstack_iLastItem], szMethod, class, iMethodType);

  static Function:func; func = __cls_GetCallMethodFunctionPointer();

  if (callfunc_begin_p(func) != 1) {
    static szMethod[CLASS_METHOD_MAX_NAME_LENGTH]; StructGetString(__cls_call_sMethod, __cls_MethodData_Name, szMethod, charsmax(szMethod));
    set_fail_state(__cls_err_FailedToCallMethodFunction, szMethod);
    return;
  }
}

stock any:ClassInstanceCallMethodEnd() {
  if (__cls_call_sMethod == Invalid_Struct) {
    set_fail_state(__cls_err_ClassMethodCallEndWithoutStart);
    return 0;
  }

  if (__cls_call_iParamsNum < __cls_call_iRequiredParamsNum) {
    static szMethod[CLASS_METHOD_MAX_NAME_LENGTH]; StructGetString(__cls_call_sMethod, __cls_MethodData_Name, szMethod, charsmax(szMethod));
    set_fail_state(__cls_err_MissingRequiredArguments, szMethod, __cls_call_iRequiredParamsNum, __cls_call_iParamsNum);
    return 0;
  }

  while (__cls_call_iParamsNum < __cls_call_iParamTypesNum) {
    callfunc_push_int(0);
    __cls_call_iParamsNum++;
  }

  static any:result; result = __cls_ExecuteMethod();

  if (!__cls_callstack_size) {
    __cls_FreeMethodCall();
  }

  return result;
}

stock __cls_ValidateParamPush(iType) {
  if (__cls_call_iParamsNum >= __cls_call_iParamTypesNum) {
    if (StructGetCell(__cls_call_sMethod, __cls_MethodData_VariadicParams)) {
      return 1;
    }

    static szMethod[CLASS_METHOD_MAX_NAME_LENGTH]; StructGetString(__cls_call_sMethod, __cls_MethodData_Name, szMethod, charsmax(szMethod));
    set_fail_state(__cls_err_NumberOfParametersExceeded, szMethod, __cls_call_iParamTypesNum, __cls_call_iParamsNum);
    return 0;
  }

  static iExpectedType; iExpectedType = StructGetCell(__cls_call_sMethod, __cls_MethodData_ParamTypes, __cls_MethodParamOffset(__cls_call_iParamsNum) + _:__cls_MethodParamData_Type);

  if (iType != iExpectedType) {
    static szMethodName[CLASS_METHOD_MAX_NAME_LENGTH]; StructGetString(__cls_call_sMethod, __cls_MethodData_Name, szMethodName, charsmax(szMethodName));
    set_fail_state(__cls_err_InvalidParamType, __cls_call_iParamsNum, szMethodName, __cls_ParamTypeNames[iExpectedType], __cls_ParamTypeNames[iType]);
    return 0;
  }

  return 1;
}

stock ClassInstanceCallMethodPushParamCell(any:value) {
  if (!__cls_ValidateParamPush(CMP_Cell)) return;

  callfunc_push_int(value);

  __cls_call_iParamsNum++;
}

stock ClassInstanceCallMethodPushParamCellRef(&any:value) {
  if (!__cls_ValidateParamPush(CMP_CellRef)) return;

  callfunc_push_intrf(value);

  __cls_call_iParamsNum++;
}

stock ClassInstanceCallMethodPushParamString(const szValue[]) {
  if (!__cls_ValidateParamPush(CMP_String)) return;

  callfunc_push_str(szValue, false);

  __cls_call_iParamsNum++;
}

stock ClassInstanceCallMethodPushParamStringRef(szValue[], iLen) {
  if (!__cls_ValidateParamPush(CMP_StringRef)) return;

  arrayset(szValue, 1, iLen);
  callfunc_push_str(szValue, true);

  __cls_call_iParamsNum++;
}

stock ClassInstanceCallMethodPushParamArray(const any:rgValue[], iSize) {
  if (!__cls_ValidateParamPush(CMP_Array)) return;

  callfunc_push_array(rgValue, iSize, false);

  __cls_call_iParamsNum++;
}

stock ClassInstanceCallMethodPushParamArrayRef(rgValue[], iSize) {
  if (!__cls_ValidateParamPush(CMP_ArrayRef)) return;

  callfunc_push_array(rgValue, iSize, true);

  __cls_call_iParamsNum++;
}

stock ClassInstanceCallMethodPushNativeParam(iParam) {
  if (__cls_call_iParamsNum >= __cls_call_iParamTypesNum) return;

  static iType; iType = StructGetCell(__cls_call_sMethod, __cls_MethodData_ParamTypes, __cls_MethodParamOffset(__cls_call_iParamsNum) + _:__cls_MethodParamData_Type);
  static iSize; iSize = StructGetCell(__cls_call_sMethod, __cls_MethodData_ParamTypes, __cls_MethodParamOffset(__cls_call_iParamsNum) + _:__cls_MethodParamData_Size);

  switch (iType) {
    case CMP_Cell, CMP_CellRef: {
      __cls_rgBuffer[__cls_call_iBufferPos] = any:get_param_byref(iParam);

      switch (iType) {
        case CMP_CellRef: callfunc_push_intrf(__cls_rgBuffer[__cls_call_iBufferPos]);
        case CMP_Cell: callfunc_push_int(__cls_rgBuffer[__cls_call_iBufferPos]);
      }

      __cls_call_iBufferPos++;
    }
    case CMP_Array, CMP_ArrayRef: {
      get_array(iParam, __cls_rgBuffer[__cls_call_iBufferPos], iSize);
      callfunc_push_array(__cls_rgBuffer[__cls_call_iBufferPos], iSize, iType == CMP_ArrayRef);
      __cls_call_iBufferPos += iSize;
    }
    case CMP_String, CMP_StringRef: {
      static iSize; iSize = get_string(iParam, __cls_rgBuffer[__cls_call_iBufferPos], charsmax(__cls_rgBuffer) - __cls_call_iBufferPos);
      callfunc_push_str(__cls_rgBuffer[__cls_call_iBufferPos], iType == CMP_StringRef);
      __cls_call_iBufferPos += iSize;
    }
  }

  __cls_call_iParamsNum++;
}

stock Class:ClassInstanceGetClass(const &ClassInstance:pInstance) {
  return __cls_GetInstanceClass(pInstance);
}

stock bool:ClassInstanceHasMember(const &ClassInstance:pInstance, const szMember[]) {
  static Trie:itMembers; itMembers = __cls_GetInstanceMembersTrie(pInstance, false);

  if (itMembers == Invalid_Trie) return false;

  return TrieKeyExists(itMembers, szMember);
}

stock ClassInstanceDeleteMember(const &ClassInstance:pInstance, const szMember[]) {
  static Trie:itMembers; itMembers = __cls_GetInstanceMembersTrie(pInstance, false);

  if (itMembers == Invalid_Trie) return;

  TrieDeleteKey(itMembers, szMember);
}

stock any:ClassInstanceGetMember(const &ClassInstance:pInstance, const szMember[]) {
  static Trie:itGetters; itGetters = __cls_GetInstanceGettersTrie(pInstance);

  if (itGetters != Invalid_Trie && TrieKeyExists(itGetters, szMember)) {
    return __cls_CallCellGetter(pInstance, szMember);
  }

  static Trie:itMembers; itMembers = __cls_GetInstanceMembersTrie(pInstance, false);

  if (itMembers == Invalid_Trie) return 0;

  static any:value;
  return TrieGetCell(itMembers, szMember, value) ? value : 0;
}

stock ClassInstanceSetMember(const &ClassInstance:pInstance, const szMember[], any:value, bool:bReplace = true) {
  static Trie:itSetters; itSetters = __cls_GetInstanceSettersTrie(pInstance);

  if (itSetters != Invalid_Trie && TrieKeyExists(itSetters, szMember)) {
    __cls_CallCellSetter(pInstance, szMember, value);
    return;
  }

  static Trie:itMembers; itMembers = __cls_GetInstanceMembersTrie(pInstance, true);

  TrieSetCell(itMembers, szMember, value, bReplace);
}

stock bool:ClassInstanceGetMemberString(const &ClassInstance:pInstance, const szMember[], szOut[], iMaxLen) {
  static Trie:itGetters; itGetters = __cls_GetInstanceGettersTrie(pInstance);

  if (itGetters != Invalid_Trie && TrieKeyExists(itGetters, szMember)) {
    return __cls_CallStringGetter(pInstance, szMember, szOut, iMaxLen);
  }

  static Trie:itMembers; itMembers = __cls_GetInstanceMembersTrie(pInstance, false);

  if (itMembers == Invalid_Trie) return false;

  copy(szOut, iMaxLen, NULL_STRING);
  return !!TrieGetString(itMembers, szMember, szOut, iMaxLen);
}

stock ClassInstanceSetMemberString(const &ClassInstance:pInstance, const szMember[], const szValue[], bool:bReplace = true) {
  static Trie:itSetters; itSetters = __cls_GetInstanceSettersTrie(pInstance);

  if (itSetters != Invalid_Trie && TrieKeyExists(itSetters, szMember)) {
    __cls_CallStringSetter(pInstance, szMember, szValue);
    return;
  }

  static Trie:itMembers; itMembers = __cls_GetInstanceMembersTrie(pInstance, true);

  TrieSetString(itMembers, szMember, szValue, bReplace);
}

stock bool:ClassInstanceGetMemberArray(const &ClassInstance:pInstance, const szMember[], any:rgOut[], iLen) {
  static Trie:itGetters; itGetters = __cls_GetInstanceGettersTrie(pInstance);

  if (itGetters != Invalid_Trie && TrieKeyExists(itGetters, szMember)) {
    return __cls_CallArrayGetter(pInstance, szMember, rgOut, iLen);
  }

  static Trie:itMembers; itMembers = __cls_GetInstanceMembersTrie(pInstance, false);

  if (itMembers == Invalid_Trie) return false;

  return !!TrieGetArray(itMembers, szMember, rgOut, iLen);
}

stock ClassInstanceSetMemberArray(const &ClassInstance:pInstance, const szMember[], const any:rgValue[], iLen, bool:bReplace = true) {
  static Trie:itSetters; itSetters = __cls_GetInstanceSettersTrie(pInstance);

  if (itSetters != Invalid_Trie && TrieKeyExists(itSetters, szMember)) {
    __cls_CallArraySetter(pInstance, szMember, rgValue, iLen);
    return;
  }

  static Trie:itMembers; itMembers = __cls_GetInstanceMembersTrie(pInstance, true);

  TrieSetArray(itMembers, szMember, rgValue, iLen, bReplace);
}

stock bool:ClassInstanceIsInstanceOf(const &ClassInstance:pInstance, const &Class:class) {
  static Class:cInstance; cInstance = __cls_GetInstanceClass(pInstance);

  return ClassIsChildOf(cInstance, class);
}

stock bool:ClassIsChildOf(const &Class:class, const &Class:cOther) {
  static Class:sCurrentClass; sCurrentClass = class;

  do {
    if (sCurrentClass == cOther) return true;
    sCurrentClass = StructGetCell(Struct:sCurrentClass, __cls_Data_Base);
  } while (sCurrentClass != Invalid_Class);

  return false;
}

/*--------------------------------[ Internal Functions] --------------------------------*/

stock Class:__cls_GetInstanceClass(const &ClassInstance:pInstance) {
  if (pInstance != __cls_cache_InstanceClass[__cls_InstanceCache_Instance]) {
    __cls_cache_InstanceClass[__cls_InstanceCache_Value] = StructGetCell(Struct:pInstance, __cls_InstanceData_Class);
    __cls_cache_InstanceClass[__cls_InstanceCache_Instance] = pInstance;
  }

  return __cls_cache_InstanceClass[__cls_InstanceCache_Value];
}

stock Trie:__cls_GetInstanceMembersTrie(const &ClassInstance:pInstance, bool:bWrite = false) {
  if (
    pInstance != __cls_cache_InstanceMembers[__cls_InstanceCache_Instance] ||
    (__cls_cache_InstanceMembers[__cls_InstanceCache_Value] == Invalid_Trie && bWrite)
  ) {
    __cls_cache_InstanceMembers[__cls_InstanceCache_Value] = StructGetCell(Struct:pInstance, __cls_InstanceData_Members);

    if (__cls_cache_InstanceMembers[__cls_InstanceCache_Value] == Invalid_Trie && bWrite) {
      __cls_cache_InstanceMembers[__cls_InstanceCache_Value] = TrieCreate();
      StructSetCell(Struct:pInstance, __cls_InstanceData_Members, __cls_cache_InstanceMembers[__cls_InstanceCache_Value]);
    }

    __cls_cache_InstanceMembers[__cls_InstanceCache_Instance] = pInstance;
  }

  return __cls_cache_InstanceMembers[__cls_InstanceCache_Value];
}

stock Trie:__cls_GetInstanceGettersTrie(const &ClassInstance:pInstance) {
  if (pInstance != __cls_cache_InstanceGetters[__cls_InstanceCache_Instance]) {
    static Class:class; class = __cls_GetInstanceClass(pInstance);
    __cls_cache_InstanceGetters[__cls_InstanceCache_Value] = __cls_GetClassMethodsTrie(class, __cls_MethodType_Getter, false);
    __cls_cache_InstanceGetters[__cls_InstanceCache_Instance] = pInstance;
  }

  return __cls_cache_InstanceGetters[__cls_InstanceCache_Value];
}

stock Trie:__cls_GetInstanceSettersTrie(const &ClassInstance:pInstance) {
  if (pInstance != __cls_cache_InstanceSetters[__cls_InstanceCache_Instance]) {
    static Class:class; class = __cls_GetInstanceClass(pInstance);
    __cls_cache_InstanceSetters[__cls_InstanceCache_Value] = __cls_GetClassMethodsTrie(class, __cls_MethodType_Setter, false);
    __cls_cache_InstanceSetters[__cls_InstanceCache_Instance] = pInstance;
  }

  return __cls_cache_InstanceSetters[__cls_InstanceCache_Value];
}

stock __cls_ParseParamTypes(&Array:irgArgs, &Array:irgParamTypes) {
  new iArgc = ArraySize(irgArgs);

  new rgParam[__cls_MethodParamData];

  for (new iArg = 0; iArg < iArgc; ++iArg) {
    rgParam[__cls_MethodParamData_Type] = ArrayGetCell(irgArgs, iArg);
    rgParam[__cls_MethodParamData_Size] = 1;

    switch (rgParam[__cls_MethodParamData_Type]) {
      case CMP_Array: {
        rgParam[__cls_MethodParamData_Size] = ArrayGetCell(irgArgs, ++iArg);
      }
      case CMP_ParamsCellArray: {
        rgParam[__cls_MethodParamData_Size] = 0;

        new Array:irgExtraParamTypes = ArrayGetCell(irgArgs, ++iArg);
        __cls_ParseParamTypes(irgExtraParamTypes, irgParamTypes);
      }
    }

    if (rgParam[__cls_MethodParamData_Size]) {
      ArrayPushArray(irgParamTypes, rgParam[any:0], _:__cls_MethodParamData);
    }
  }
}

stock __cls_InitMethodCall(const &ClassInstance:pInstance, const szMethod[], const &Class:class = Invalid_Class, __cls_MethodType:iMethodType) {
  __cls_call_class = class == Invalid_Class ? __cls_GetCallMethodClass(pInstance) : class;
  __cls_call_pInstance = pInstance;
  __cls_call_sMethod = __cls_FindClassMethodInHierarchy(__cls_call_class, szMethod, iMethodType);
  __cls_call_iParamsNum = 0;
  __cls_call_iParamTypesNum = StructGetCell(__cls_call_sMethod, __cls_MethodData_ParamTypesNum);
  __cls_call_iRequiredParamsNum = __cls_call_iParamTypesNum;

  if (__cls_call_sMethod == Invalid_Struct) {
    set_fail_state(__cls_err_MethodNotFoundInBaseClass, szMethod);
    return;
  }
}

stock __cls_InitMethodCallByPointer(const &ClassInstance:pInstance, const &Struct:sMethod) {
  __cls_call_class = StructGetCell(sMethod, __cls_MethodData_Class);
  __cls_call_pInstance = pInstance;
  __cls_call_sMethod = sMethod;
  __cls_call_iParamsNum = 0;
  __cls_call_iParamTypesNum = StructGetCell(__cls_call_sMethod, __cls_MethodData_ParamTypesNum);
  __cls_call_iRequiredParamsNum = __cls_call_iParamTypesNum;
}

stock __cls_FreeMethodCall() {
  __cls_call_class = Invalid_Class;
  __cls_call_pInstance = Invalid_ClassInstance;
  __cls_call_sMethod = Invalid_Struct;
  __cls_call_iParamsNum = 0;
  __cls_call_iBufferPos = 0;
  __cls_call_iParamTypesNum = 0;
  __cls_call_iRequiredParamsNum = 0;
}

stock Function:__cls_GetCallMethodFunctionPointer() {
  static Function:func; func = StructGetCell(__cls_call_sMethod, __cls_MethodData_Function);

  if (func == Invalid_FunctionPointer) {
    static szMethod[CLASS_METHOD_MAX_NAME_LENGTH]; StructGetString(__cls_call_sMethod, __cls_MethodData_Name, szMethod, charsmax(szMethod));
    set_fail_state(__cls_err_NotImplementedMethod, szMethod);
  }

  return func;
}

stock __cls_CallMethodBegin(const &ClassInstance:pInstance, const szMethod[], const &Class:class = Invalid_Class, __cls_MethodType:iMethodType = __cls_MethodType_Method) {
  __cls_InitMethodCall(pInstance, szMethod, class, iMethodType);

  // Check for virtual method call
  // If we are already in the execution context and the method is virual then jump to top level context
  // All Getters and Setter works like virtual methods
  if (__cls_callstack_size) {
    if (StructGetCell(__cls_call_sMethod, __cls_MethodData_Type) != __cls_MethodType_Method) {
      static Class:sInstanceClass; sInstanceClass = __cls_GetInstanceClass(pInstance);
      if (sInstanceClass != StructGetCell(__cls_call_sMethod, __cls_MethodData_Class)) {
        __cls_call_sMethod = __cls_FindClassMethodInHierarchy(sInstanceClass, szMethod, iMethodType);
      }
    }
  }

  if (__cls_call_sMethod == Invalid_Struct) {
    set_fail_state(__cls_err_MethodNotFound, szMethod, pInstance);
    return;
  }

  static Function:func; func = __cls_GetCallMethodFunctionPointer();

  if (callfunc_begin_p(func) != 1) {
    static szMethod[CLASS_METHOD_MAX_NAME_LENGTH]; StructGetString(__cls_call_sMethod, __cls_MethodData_Name, szMethod, charsmax(szMethod));
    set_fail_state(__cls_err_FailedToCallMethodFunction, szMethod);
    return;
  }
}

stock __cls_CallMethodByPointerBegin(const &ClassInstance:pInstance, const &Struct:sMethod) {
  __cls_InitMethodCallByPointer(pInstance, sMethod);

  static Function:func; func = __cls_GetCallMethodFunctionPointer();

  if (callfunc_begin_p(func) != 1) {
    static szMethod[CLASS_METHOD_MAX_NAME_LENGTH]; StructGetString(__cls_call_sMethod, __cls_MethodData_Name, szMethod, charsmax(szMethod));
    set_fail_state(__cls_err_FailedToCallMethodFunction, szMethod);
    return;
  }
}

stock any:__cls_CallCellGetter(const &ClassInstance:pInstance, const szMember[]) {
  __cls_CallMethodBegin(pInstance, szMember, _, __cls_MethodType_Getter);

  return ClassInstanceCallMethodEnd();
}

stock any:__cls_CallArrayGetter(const &ClassInstance:pInstance, const szMember[], any:rgOut[], iSize) {
  __cls_CallMethodBegin(pInstance, szMember, _, __cls_MethodType_Getter);

  ClassInstanceCallMethodPushParamArrayRef(rgOut, iSize);
  ClassInstanceCallMethodPushParamCell(iSize);

  return ClassInstanceCallMethodEnd();
}

stock any:__cls_CallStringGetter(const &ClassInstance:pInstance, const szMember[], any:rgOut[], iLen) {
  __cls_CallMethodBegin(pInstance, szMember, _, __cls_MethodType_Getter);

  ClassInstanceCallMethodPushParamStringRef(rgOut, iLen);
  ClassInstanceCallMethodPushParamCell(iLen);

  return ClassInstanceCallMethodEnd();
}

stock __cls_CallCellSetter(const &ClassInstance:pInstance, const szMember[], any:value) {
  __cls_CallMethodBegin(pInstance, szMember, _, __cls_MethodType_Setter);

  ClassInstanceCallMethodPushParamCell(value);

  return ClassInstanceCallMethodEnd();
}

stock __cls_CallArraySetter(const &ClassInstance:pInstance, const szMember[], const any:rgValue[], iSize) {
  __cls_CallMethodBegin(pInstance, szMember, _, __cls_MethodType_Setter);

  ClassInstanceCallMethodPushParamArray(rgValue, iSize);

  return ClassInstanceCallMethodEnd();
}

stock __cls_CallStringSetter(const &ClassInstance:pInstance, const szMember[], const szValue[]) {
  __cls_CallMethodBegin(pInstance, szMember, _, __cls_MethodType_Setter);

  ClassInstanceCallMethodPushParamString(szValue);

  return ClassInstanceCallMethodEnd();
}

stock __cls_DestroyMethod(&Struct:sMethod) {
    new Array:irgParamTypes; StructGetCell(sMethod, __cls_MethodData_ParamTypes);

    if (irgParamTypes != Invalid_Array) {
      ArrayDestroy(irgParamTypes);
    }

    StructDestroy(sMethod);
}

stock __cls_DestroyMethodsTrie(&Trie:itMethods) {
  new TrieIter:iMethodsIter = TrieIterCreate(itMethods);

  while (!TrieIterEnded(iMethodsIter)) {
    new Struct:sMethod; TrieIterGetCell(iMethodsIter, sMethod);
    __cls_DestroyMethod(sMethod);
    TrieIterNext(iMethodsIter);
  }

  TrieIterDestroy(iMethodsIter);

  TrieDestroy(itMethods);
}

stock __cls_AddMemberAccessorMethod(const &Class:class, const szMember[], const Function:func, __cls_MethodType:iMethodType, iType, iSize) {
  if (iMethodType != __cls_MethodType_Getter && iMethodType != __cls_MethodType_Setter) return;

  new Trie:itMethods = __cls_GetClassMethodsTrie(class, iMethodType, true);

  new Array:irgParamTypes; irgParamTypes = ArrayCreate(_:__cls_MethodParamData, 1);

  new rgParam[__cls_MethodParamData];
  rgParam[__cls_MethodParamData_Type] = __cls_ResolveAccessorParamType(iType, iMethodType);
  rgParam[__cls_MethodParamData_Size] = iSize;

  ArrayPushArray(irgParamTypes, rgParam[any:0], _:__cls_MethodParamData);

  if (iType == CMP_String || iType == CMP_Array) {
    new rgSizeParam[__cls_MethodParamData];
    rgSizeParam[__cls_MethodParamData_Type] = CMP_Cell;
    rgSizeParam[__cls_MethodParamData_Size] = 1;

    ArrayPushArray(irgParamTypes, rgSizeParam[any:0], _:__cls_MethodParamData);
  }

  new Struct:sMethod = __cls_CreateMethod(class, szMember, func, irgParamTypes, iMethodType);

  ArrayDestroy(irgParamTypes);

  TrieSetCell(itMethods, szMember, sMethod);
}

stock __cls_ResolveAccessorParamType(iType, __cls_MethodType:iMethodType) {
  if (iMethodType == __cls_MethodType_Getter) {
    switch (iType) {
      case CMP_String: return CMP_StringRef;
      case CMP_Array: return CMP_ArrayRef;
    }
  }

  return iType;
}

stock Struct:__cls_CreateMethod(Class:class, const szName[], const Function:func, Array:irgParamTypes, __cls_MethodType:iType = __cls_MethodType_Method, bool:bVariadicParams = false) {
  new Struct:sMethod = StructCreate(__cls_MethodData);
  StructSetCell(sMethod, __cls_MethodData_Class, class);
  StructSetString(sMethod, __cls_MethodData_Name, szName);
  StructSetCell(sMethod, __cls_MethodData_Function, func);
  StructSetCell(sMethod, __cls_MethodData_Type, iType);
  StructSetCell(sMethod, __cls_MethodData_VariadicParams, bVariadicParams);

  new iParamTypesNum = ArraySize(irgParamTypes);
  for (new iParam = 0; iParam < iParamTypesNum; ++iParam) {
    StructSetCell(sMethod, __cls_MethodData_ParamTypes, ArrayGetCell(irgParamTypes, iParam, __cls_MethodParamData_Type), __cls_MethodParamOffset(iParam) + _:__cls_MethodParamData_Type);
    StructSetCell(sMethod, __cls_MethodData_ParamTypes, ArrayGetCell(irgParamTypes, iParam, __cls_MethodParamData_Size), __cls_MethodParamOffset(iParam) + _:__cls_MethodParamData_Size);
  }

  StructSetCell(sMethod, __cls_MethodData_ParamTypesNum, iParamTypesNum);

  return sMethod;
}

stock __cls_CompareParamTypes(const &Struct:sMethod, const &Array:irgParams) {
  new iParamsNum = StructGetCell(sMethod, __cls_MethodData_ParamTypesNum);
  new iParamsSize = ArraySize(irgParams);

  if (iParamsNum != iParamsSize) return false;

  for (new iParam = 0; iParam < iParamsNum; ++iParam) {
    new iType = StructGetCell(sMethod, __cls_MethodData_ParamTypes, __cls_MethodParamOffset(iParam) + _:__cls_MethodParamData_Type);
    if (iType != ArrayGetCell(irgParams, iParam, _:__cls_MethodParamData_Type)) return false;

    new iSize = StructGetCell(sMethod, __cls_MethodData_ParamTypes, __cls_MethodParamOffset(iParam) + _:__cls_MethodParamData_Size);
    if (iSize != ArrayGetCell(irgParams, iParam, _:__cls_MethodParamData_Size)) return false;
  }

  return true;
}

stock any:__cls_ExecuteMethod() {
  __cls_PushMethodCallToCallStack();

  __cls_LogExecution();

  new any:result = callfunc_end();

  __cls_PopMethodFromCallStack();

  return result;
}

stock Struct:__cls_FindClassMethodInHierarchy(const &Class:class, const szMethod[], __cls_MethodType:iMethodType) {
  new Class:sCurrentClass = class;

  static iStructMethodsField = __cls_MethodType_Invalid;
  switch (iMethodType) {
    case __cls_MethodType_Method, __cls_MethodType_Virtual: {
      iStructMethodsField = __cls_Data_Methods;
    }
    case __cls_MethodType_Getter: {
      iStructMethodsField = __cls_Data_Getters;
    }
    case __cls_MethodType_Setter: {
      iStructMethodsField = __cls_Data_Setters;
    }
  }

  do {
    static Trie:itMethods; itMethods = StructGetCell(Struct:sCurrentClass, iStructMethodsField);

    if (itMethods != Invalid_Trie) {
      static Struct:sMethod;
      if (TrieGetCell(itMethods, szMethod, sMethod)) return sMethod;
    }

    sCurrentClass = StructGetCell(Struct:sCurrentClass, __cls_Data_Base);
  } while (sCurrentClass != Invalid_Class);

  return Invalid_Struct;
}

stock __cls_PushMethodCallToCallStack() {
  if (__cls_callstack_size >= CLASS_METHOD_CALL_STACK_SIZE) {
    set_fail_state(__cls_err_MaxCallStackSizeExceeded);
    return;
  }

  __cls_callstack_pInstance[__cls_callstack_size] = any:__cls_call_pInstance;
  __cls_callstack_class[__cls_callstack_size] = any:StructGetCell(__cls_call_sMethod, __cls_MethodData_Class);
  __cls_callstack_sMethod[__cls_callstack_size] = any:__cls_call_sMethod;

  __cls_callstack_size++;
}

stock __cls_PopMethodFromCallStack() {
  __cls_callstack_size--;

  if (__cls_callstack_size) {
    __cls_call_pInstance = __cls_callstack_pInstance[__cls_callstack_iLastItem];
    __cls_call_sMethod = __cls_callstack_sMethod[__cls_callstack_iLastItem];
  }
}

stock Class:__cls_GetCallMethodClass(const &ClassInstance:pInstance) {
  if (__cls_callstack_size) {
      if (__cls_callstack_pInstance[__cls_callstack_iLastItem] == pInstance) {
        return __cls_callstack_class[__cls_callstack_iLastItem];
      }
  }

  return __cls_GetInstanceClass(pInstance);
}

stock Trie:__cls_GetClassMembersTrie(const &Class:class, bool:bWrite = false) {
  static Trie:itMembers; itMembers = StructGetCell(Struct:class, __cls_Data_Members);

  if (itMembers == Invalid_Trie && bWrite) {
    itMembers = TrieCreate();
    StructSetCell(Struct:class, __cls_Data_Members, itMembers);
  }

  return itMembers;
}

stock Trie:__cls_GetClassMethodsTrie(const &Class:class, __cls_MethodType:iMethodType, bool:bWrite = false) {
  static iStructMethodsField = __cls_MethodType_Invalid;
  switch (iMethodType) {
    case __cls_MethodType_Method, __cls_MethodType_Virtual: {
      iStructMethodsField = __cls_Data_Methods;
    }
    case __cls_MethodType_Getter: {
      iStructMethodsField = __cls_Data_Getters;
    }
    case __cls_MethodType_Setter: {
      iStructMethodsField = __cls_Data_Setters;
    }
  }

  static Trie:itMethods; itMethods = StructGetCell(Struct:class, iStructMethodsField);

  if (itMethods == Invalid_Trie && bWrite) {
    itMethods = TrieCreate();
    StructSetCell(Struct:class, iStructMethodsField, itMethods);
  }

  return itMethods;
}

stock __cls_LogExecution() {
  #if defined __cls_DEBUG
    static Struct:sClass; sClass = StructGetCell(__cls_call_sMethod, __cls_MethodData_Class);
    static szName[32]; ClassGetMetadataString(Class:sClass, "__NAME", szName, charsmax(szName));
    static szMethodName[CLASS_METHOD_MAX_NAME_LENGTH]; StructGetString(__cls_call_sMethod, __cls_MethodData_Name, szMethodName, charsmax(szMethodName));

    if (equal(szName, NULL_STRING)) {
      format(szName, charsmax(szName), "CLASS_%d", sClass);
    }

    __cls_DebugMessage("[%d] %s::%s(...)", __cls_call_pInstance, szName, szMethodName);
  #endif
}

stock __cls_DebugMessage(const szFormat[], any:...) {
  #if defined __cls_DEBUG
    static szMessage[MAX_FMT_LENGTH];
    vformat(szMessage, charsmax(szMessage), szFormat, 2);
    engfunc(EngFunc_AlertMessage, at_aiconsole, "%s^n", szMessage);
  #endif
}
