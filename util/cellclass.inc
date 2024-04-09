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

#define __cls_err_MethodAlreadyRegistered "Method ^"%s^" is already registered for the class!"
#define __cls_err_VMethodArgumentsMismatch "Arguments mismatch in the overridden virtual method ^"%s^"!"
#define __cls_err_ClassIdNotFound "Class with id %d is not registered!"
#define __cls_err_MethodNotFound "Method ^"%s^" is not registered for the instance (%d)!"
#define __cls_err_CallMethodOutsideContext "Calling a base method is not allowed outside of the execution context!"
#define __cls_err_ClassHasNoBaseClass "Cannot call base method of class without base class!"
#define __cls_err_MethodNotFoundInBaseClass "Cannot find method ^"%s^" in base classes!"
#define __cls_err_MaxCallStackSizeExceeded "Maximum call stack size exceeded!"
#define __cls_err_ClassMethodCallEndWithoutStart "Call ClassInstanceCallMethodEnd but method call is not started!"
#define __cls_err_NumberOfParametersExceeded "Number of parameters exceeded!"
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
  CMP_StringRef,
  CMP_ArrayRef,
  CMP_ParamsCellArray
};

// #define CMP_Float CMP_Cell
// #define CMP_FloatArray CMP_Array

stock const __cls_ParamTypeNames[__cls_ParamTypes][64] = {
  "Cell",
  "String",
  "Array",
  "StringRef",
  "ArrayRef",
  "ParamsCellArray"
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

enum __cls_MethodCallStackItem {
  __cls_MethodCallStackItem_Name[CLASS_METHOD_MAX_NAME_LENGTH],
  ClassInstance:__cls_MethodCallStackItem_Instance,
  Class:__cls_MethodCallStackItem_Class,
  Struct:__cls_MethodCallStackItem_Method
};

// Fast pseudo-stack implementation
stock Array:__cls_callstack[CLASS_METHOD_CALL_STACK_SIZE][__cls_MethodCallStackItem];
stock __cls_callstack_size = 0;

// Variables to store info between Begin and End method calls
stock ClassInstance:__cls_call_pInstance = Invalid_ClassInstance;
stock Struct:__cls_call_sMethod = Invalid_Struct;
stock __cls_call_iParamTypesNum = 0;
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
  StructSetCell(class, __cls_Data_Methods, TrieCreate());
  StructSetCell(class, __cls_Data_Members, TrieCreate());
  StructSetCell(class, __cls_Data_Setters, TrieCreate());
  StructSetCell(class, __cls_Data_Getters, TrieCreate());

  return Class:class;
}

stock ClassDestroy(&Class:class) {
  new Trie:itMethods = StructGetCell(Struct:class, __cls_Data_Methods);
  __cls_DestroyMethodsTrie(itMethods);

  new Trie:itGetters = StructGetCell(Struct:class, __cls_Data_Getters);
  __cls_DestroyMethodsTrie(itGetters);

  new Trie:itSetters = StructGetCell(Struct:class, __cls_Data_Setters);
  __cls_DestroyMethodsTrie(itSetters);

  new Trie:itMembers = StructGetCell(Struct:class, __cls_Data_Members);
  TrieDestroy(itMembers);

  StructDestroy(Struct:class);

  class = Invalid_Class;
}

stock Class:ClassAddMethod(const &Class:class, const szMethod[], const Function:func, bool:bVirtual = false, any:...) {
  static const iArgOffset = 4;

  new iArgc = numargs();

  new Class:sBaseClass = StructGetCell(Struct:class, __cls_Data_Base);
  new Trie:itMethods = StructGetCell(Struct:class, __cls_Data_Methods);

  if (TrieKeyExists(itMethods, szMethod)) {
    set_fail_state(__cls_err_MethodAlreadyRegistered, szMethod);
    return;
  }

  new Array:irgArgs = ArrayCreate();

  for (new iArg = iArgOffset; iArg < iArgc; ++iArg) {
    ArrayPushCell(irgArgs, getarg(iArg));
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

  new Struct:sMethod = __cls_CreateMethod(class, szMethod, func, irgParamTypes, bVirtual ? __cls_MethodType_Virtual : __cls_MethodType_Method);

  ArrayDestroy(irgParamTypes);

  TrieSetCell(itMethods, szMethod, sMethod);
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
  static Trie:itMembers; itMembers = StructGetCell(Struct:class, __cls_Data_Members);

  return TrieKeyExists(itMembers, szMember);
}

stock ClassDeleteMetadata(const &Class:class, const szMember[]) {
  static Trie:itMembers; itMembers = StructGetCell(Struct:class, __cls_Data_Members);

  TrieDeleteKey(itMembers, szMember);
}

stock any:ClassGetMetadata(const &Class:class, const szMember[]) {
  static Trie:itMembers; itMembers = StructGetCell(Struct:class, __cls_Data_Members);

  static any:value;
  return TrieGetCell(itMembers, szMember, value) ? value : 0;
}

stock ClassSetMetadata(const &Class:class, const szMember[], any:value, bool:bReplace = true) {
  static Trie:itMembers; itMembers = StructGetCell(Struct:class, __cls_Data_Members);

  TrieSetCell(itMembers, szMember, value, bReplace);
}

stock bool:ClassGetMetadataString(const &Class:class, const szMember[], szOut[], iMaxLen) {
  static Trie:itMembers; itMembers = StructGetCell(Struct:class, __cls_Data_Members);

  copy(szOut, iMaxLen, NULL_STRING);
  return !!TrieGetString(itMembers, szMember, szOut, iMaxLen);
}

stock ClassSetMetadataString(const &Class:class, const szMember[], const szValue[], bool:bReplace = true) {
  static Trie:itMembers; itMembers = StructGetCell(Struct:class, __cls_Data_Members);

  TrieSetString(itMembers, szMember, szValue, bReplace);
}

stock bool:ClassGetMetadataArray(const &Class:class, const szMember[], any:rgOut[], iLen) {
  static Trie:itMembers; itMembers = StructGetCell(Struct:class, __cls_Data_Members);

  return !!TrieGetArray(itMembers, szMember, rgOut, iLen);
}

stock ClassSetMetadataArray(const &Class:class, const szMember[], const any:rgValue[], iLen, bool:bReplace = true) {
  static Trie:itMembers; itMembers = StructGetCell(Struct:class, __cls_Data_Members);

  TrieSetArray(itMembers, szMember, rgValue, iLen, bReplace);
}

/*--------------------------------[ Class Instance Functions] --------------------------------*/

stock ClassInstance:ClassInstanceCreate(const &Class:class) {
  static Struct:sInstance; sInstance = StructCreate(__cls_InstanceData);
  StructSetCell(sInstance, __cls_InstanceData_Class, class);
  StructSetCell(sInstance, __cls_InstanceData_Members, TrieCreate());

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

  static Trie:itMembers; itMembers = __cls_GetInstanceMembersTrie(pInstance);
  TrieDestroy(itMembers);

  StructDestroy(Struct:pInstance);

  pInstance = Invalid_ClassInstance;
}

stock ClassInstance:ClassInstanceGetCurrent() {
  if (__cls_IsMethodCallStackEmpty()) {
    set_fail_state(__cls_err_CallMethodOutsideContext);
    return Invalid_ClassInstance;
  }

  static rgCallStackItem[__cls_MethodCallStackItem]; __cls_GetCurrentMethodFromCallStack(rgCallStackItem);

  return rgCallStackItem[__cls_MethodCallStackItem_Instance];
}

stock Class:ClassInstanceGetCurrentClass() {
  if (__cls_IsMethodCallStackEmpty()) {
    set_fail_state(__cls_err_CallMethodOutsideContext);
    return Invalid_Class;
  }

  static rgCallStackItem[__cls_MethodCallStackItem]; __cls_GetCurrentMethodFromCallStack(rgCallStackItem);

  return rgCallStackItem[__cls_MethodCallStackItem_Class];
}

stock ClassInstanceCallMethod(const &ClassInstance:pInstance, const szMethod[], any:...) {
  __cls_CallMethodBegin(pInstance, szMethod, __cls_MethodType_Method);

  for (new iMethodParam = 0; iMethodParam < __cls_call_iParamTypesNum; ++iMethodParam) {
    static iParam; iParam = 2 + iMethodParam;
    static iType; iType = StructGetCell(__cls_call_sMethod, __cls_MethodData_ParamTypes, __cls_MethodParamOffset(iMethodParam) + _:__cls_MethodParamData_Type);
    static iSize; iSize = StructGetCell(__cls_call_sMethod, __cls_MethodData_ParamTypes, __cls_MethodParamOffset(iMethodParam) + _:__cls_MethodParamData_Size);
    static bool:bUseDefault; bUseDefault = iParam > numargs();

    switch (iType) {
      case CMP_Cell: {
        ClassInstanceCallMethodPushParamCell(bUseDefault ? __cls_DefaultValue_Cell : any:getarg(iParam));
      }
      case CMP_String, CMP_StringRef: {
        static iLen; iLen = 0;

        if (bUseDefault) {
          copy(__cls_rgBuffer[__cls_call_iBufferPos], charsmax(__cls_rgBuffer) - __cls_call_iBufferPos, __cls_DefaultValue_String);
        } else {
          for (new i = 0; i < charsmax(__cls_rgBuffer) - __cls_call_iBufferPos; ++i) {
              __cls_rgBuffer[__cls_call_iBufferPos + i] = getarg(iParam, i);
              if (__cls_rgBuffer[__cls_call_iBufferPos + i] == '^0') break;
              iLen++;
          }
        }

        if (iType == CMP_StringRef) {
          ClassInstanceCallMethodPushParamStringRef(__cls_rgBuffer[__cls_call_iBufferPos], iSize);
        } else {
          ClassInstanceCallMethodPushParamString(__cls_rgBuffer[__cls_call_iBufferPos]);
        }

        __cls_call_iBufferPos += iLen;
      }
      case CMP_Array, CMP_ArrayRef: {
        if (bUseDefault) {
          arrayset(__cls_rgBuffer[__cls_call_iBufferPos], __cls_DefaultValue_Float, iSize);
        } else {
          for (new i = 0; i < iSize; ++i) {
              __cls_rgBuffer[__cls_call_iBufferPos + i] = getarg(iParam, i);
          }
        }

        if (iType == CMP_ArrayRef) {
          ClassInstanceCallMethodPushParamArrayRef(__cls_rgBuffer[__cls_call_iBufferPos], iSize);
        } else {
          ClassInstanceCallMethodPushParamArray(__cls_rgBuffer[__cls_call_iBufferPos], iSize);
        }

        __cls_call_iBufferPos += iSize;
      }
    }
  }

  return ClassInstanceCallMethodEnd();
}

stock ClassInstanceCallBaseMethod(any:...) {
  ClassInstanceCallMethodBeginBase();

  for (new iMethodParam = 0; iMethodParam < __cls_call_iParamTypesNum; ++iMethodParam) {
    static iParam; iParam = 0 + iMethodParam;
    static iType; iType = StructGetCell(__cls_call_sMethod, __cls_MethodData_ParamTypes, __cls_MethodParamOffset(iMethodParam) + _:__cls_MethodParamData_Type);
    static iSize; iSize = StructGetCell(__cls_call_sMethod, __cls_MethodData_ParamTypes, __cls_MethodParamOffset(iMethodParam) + _:__cls_MethodParamData_Size);
    static bool:bUseDefault; bUseDefault = iParam > numargs();

    switch (iType) {
      case CMP_Cell: {
        ClassInstanceCallMethodPushParamCell(bUseDefault ? __cls_DefaultValue_Cell : any:getarg(iParam));
      }
      case CMP_String, CMP_StringRef: {
        static iLen; iLen = 0;

        if (bUseDefault) {
          copy(__cls_rgBuffer[__cls_call_iBufferPos], charsmax(__cls_rgBuffer) - __cls_call_iBufferPos, __cls_DefaultValue_String);
        } else {
          for (new i = 0; i < charsmax(__cls_rgBuffer) - __cls_call_iBufferPos; ++i) {
              __cls_rgBuffer[__cls_call_iBufferPos + i] = getarg(iParam, i);
              if (__cls_rgBuffer[__cls_call_iBufferPos + i] == '^0') break;
              iLen++;
          }
        }

        if (iType == CMP_StringRef) {
          ClassInstanceCallMethodPushParamStringRef(__cls_rgBuffer[__cls_call_iBufferPos], iSize);
        } else {
          ClassInstanceCallMethodPushParamString(__cls_rgBuffer[__cls_call_iBufferPos]);
        }

        __cls_call_iBufferPos += iLen;
      }
      case CMP_Array, CMP_ArrayRef: {
        if (bUseDefault) {
          arrayset(__cls_rgBuffer[__cls_call_iBufferPos], __cls_DefaultValue_Float, iSize);
        } else {
          for (new i = 0; i < iSize; ++i) {
              __cls_rgBuffer[__cls_call_iBufferPos + i] = getarg(iParam, i);
          }
        }

        if (iType == CMP_ArrayRef) {
          ClassInstanceCallMethodPushParamArrayRef(__cls_rgBuffer[__cls_call_iBufferPos], iSize);
        } else {
          ClassInstanceCallMethodPushParamArray(__cls_rgBuffer[__cls_call_iBufferPos], iSize);
        }

        __cls_call_iBufferPos += iSize;
      }
    }
  }

  return ClassInstanceCallMethodEnd();
}

stock ClassInstanceCallMethodBegin(const &ClassInstance:pInstance, const szMethod[]) {
  __cls_CallMethodBegin(pInstance, szMethod, __cls_MethodType_Method);
}

stock ClassInstanceCallMethodBeginBase(any:...) {
  if (__cls_IsMethodCallStackEmpty()) {
    set_fail_state(__cls_err_CallMethodOutsideContext);
    return;
  }

  static rgCallStackItem[__cls_MethodCallStackItem]; __cls_GetCurrentMethodFromCallStack(rgCallStackItem);

  static Class:class; class = StructGetCell(Struct:rgCallStackItem[__cls_MethodCallStackItem_Class], __cls_Data_Base);
  if (class == Invalid_Class) {
    set_fail_state(__cls_err_ClassHasNoBaseClass);
    return;
  }

  static szMethod[CLASS_METHOD_MAX_NAME_LENGTH]; StructGetString(rgCallStackItem[__cls_MethodCallStackItem_Method], __cls_MethodData_Name, szMethod, charsmax(szMethod));
  static __cls_MethodType:iMethodType; iMethodType = StructGetCell(Struct:rgCallStackItem[__cls_MethodCallStackItem_Method], __cls_MethodData_Type);

  __cls_InitMethodCall(rgCallStackItem[__cls_MethodCallStackItem_Instance], szMethod, class, iMethodType);

  static Function:func; func = StructGetCell(__cls_call_sMethod, __cls_MethodData_Function);

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

  static any:result; result = __cls_ExecuteMethod();

  if (__cls_IsMethodCallStackEmpty()) {
    __cls_FreeMethodCall();
  }

  return result;
}

stock __cls_ValidateParamPush(iParam, iType) {
    if (__cls_call_iParamsNum >= __cls_call_iParamTypesNum) {
      set_fail_state(__cls_err_NumberOfParametersExceeded);
      return 0;
    }

    static iExpectedType; iExpectedType = StructGetCell(__cls_call_sMethod, __cls_MethodData_ParamTypes, __cls_MethodParamOffset(iParam) + _:__cls_MethodParamData_Type);

    if (iType != iExpectedType) {
      static szMethodName[CLASS_METHOD_MAX_NAME_LENGTH]; StructGetString(__cls_call_sMethod, __cls_MethodData_Name, szMethodName, charsmax(szMethodName));
      set_fail_state(__cls_err_InvalidParamType, iParam, szMethodName, __cls_ParamTypeNames[iType], __cls_ParamTypeNames[iExpectedType]);
      return 0;
    }

    return 1;
}

stock ClassInstanceCallMethodPushParamCell(any:value) {
    if (!__cls_ValidateParamPush(__cls_call_iParamsNum, CMP_Cell)) return;

    callfunc_push_int(value);

    __cls_call_iParamsNum++;
}

stock ClassInstanceCallMethodPushParamCellRef(&any:value) {
    if (!__cls_ValidateParamPush(__cls_call_iParamsNum, CMP_Cell)) return;

    callfunc_push_intrf(value);

    __cls_call_iParamsNum++;
}

stock ClassInstanceCallMethodPushParamString(const szValue[]) {
    if (!__cls_ValidateParamPush(__cls_call_iParamsNum, CMP_String)) return;

    callfunc_push_str(szValue, false);

    __cls_call_iParamsNum++;
}

stock ClassInstanceCallMethodPushParamArray(const any:rgValue[], iSize) {
    if (!__cls_ValidateParamPush(__cls_call_iParamsNum, CMP_Array)) return;

    callfunc_push_array(rgValue, iSize, false);

    __cls_call_iParamsNum++;
}

stock ClassInstanceCallMethodPushParamStringRef(szValue[], iLen) {
    if (!__cls_ValidateParamPush(__cls_call_iParamsNum, CMP_StringRef)) return;

    arrayset(szValue, 1, iLen);
    callfunc_push_str(szValue, true);

    __cls_call_iParamsNum++;
}

stock ClassInstanceCallMethodPushParamArrayRef(rgValue[], iSize) {
    if (!__cls_ValidateParamPush(__cls_call_iParamsNum, CMP_ArrayRef)) return;

    callfunc_push_array(rgValue, iSize, true);

    __cls_call_iParamsNum++;
}

stock ClassInstanceCallMethodPushNativeParam(iParam) {
  if (__cls_call_iParamsNum >= __cls_call_iParamTypesNum) return;

  static iType; iType = StructGetCell(__cls_call_sMethod, __cls_MethodData_ParamTypes, __cls_MethodParamOffset(__cls_call_iParamsNum) + _:__cls_MethodParamData_Type);
  static iSize; iSize = StructGetCell(__cls_call_sMethod, __cls_MethodData_ParamTypes, __cls_MethodParamOffset(__cls_call_iParamsNum) + _:__cls_MethodParamData_Size);

  switch (iType) {
    case CMP_Cell: {
      // log_amx("Param%d: %d %f", iParam, any:get_param_byref(iParam), any:get_param_byref(iParam));
      callfunc_push_int(any:get_param_byref(iParam));
    }
    case CMP_Array, CMP_ArrayRef: {
      get_array(iParam, __cls_rgBuffer[__cls_call_iBufferPos], iSize);
      callfunc_push_array(__cls_rgBuffer[__cls_call_iBufferPos], iSize, iType == CMP_ArrayRef);
      __cls_call_iBufferPos += iSize;
    }
    case CMP_String, CMP_StringRef: {
      static iSize; iSize = get_string(iParam, __cls_rgBuffer[__cls_call_iBufferPos], charsmax(__cls_rgBuffer) - __cls_call_iBufferPos);
      // log_amx("Param%d: ^"%s^"", iParam, __cls_rgBuffer);
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
  static Trie:itMembers; itMembers = __cls_GetInstanceMembersTrie(pInstance);

  return TrieKeyExists(itMembers, szMember);
}

stock ClassInstanceDeleteMember(const &ClassInstance:pInstance, const szMember[]) {
  static Trie:itMembers; itMembers = __cls_GetInstanceMembersTrie(pInstance);

  TrieDeleteKey(itMembers, szMember);
}

stock any:ClassInstanceGetMember(const &ClassInstance:pInstance, const szMember[]) {
  static Trie:itGetters; itGetters = __cls_GetInstanceGettersTrie(pInstance);

  if (TrieKeyExists(itGetters, szMember)) {
    return __cls_CallCellGetter(pInstance, szMember);
  }

  static Trie:itMembers; itMembers = __cls_GetInstanceMembersTrie(pInstance);

  static any:value;
  return TrieGetCell(itMembers, szMember, value) ? value : 0;
}

stock ClassInstanceSetMember(const &ClassInstance:pInstance, const szMember[], any:value, bool:bReplace = true) {
  static Trie:itSetters; itSetters = __cls_GetInstanceSettersTrie(pInstance);

  if (TrieKeyExists(itSetters, szMember)) {
    __cls_CallCellSetter(pInstance, szMember, value);
    return;
  }

  static Trie:itMembers; itMembers = __cls_GetInstanceMembersTrie(pInstance);

  TrieSetCell(itMembers, szMember, value, bReplace);
}

stock bool:ClassInstanceGetMemberString(const &ClassInstance:pInstance, const szMember[], szOut[], iMaxLen) {
  static Trie:itGetters; itGetters = __cls_GetInstanceGettersTrie(pInstance);

  if (TrieKeyExists(itGetters, szMember)) {
    return __cls_CallStringGetter(pInstance, szMember, szOut, iMaxLen);
  }

  static Trie:itMembers; itMembers = __cls_GetInstanceMembersTrie(pInstance);

  copy(szOut, iMaxLen, NULL_STRING);
  return !!TrieGetString(itMembers, szMember, szOut, iMaxLen);
}

stock ClassInstanceSetMemberString(const &ClassInstance:pInstance, const szMember[], const szValue[], bool:bReplace = true) {
  static Trie:itSetters; itSetters = __cls_GetInstanceSettersTrie(pInstance);

  if (TrieKeyExists(itSetters, szMember)) {
    __cls_CallStringSetter(pInstance, szMember, szValue);
    return;
  }

  static Trie:itMembers; itMembers = __cls_GetInstanceMembersTrie(pInstance);

  TrieSetString(itMembers, szMember, szValue, bReplace);
}

stock bool:ClassInstanceGetMemberArray(const &ClassInstance:pInstance, const szMember[], any:rgOut[], iLen) {
  static Trie:itGetters; itGetters = __cls_GetInstanceGettersTrie(pInstance);

  if (TrieKeyExists(itGetters, szMember)) {
    return __cls_CallArrayGetter(pInstance, szMember, rgOut, iLen);
  }

  static Trie:itMembers; itMembers = __cls_GetInstanceMembersTrie(pInstance);

  return !!TrieGetArray(itMembers, szMember, rgOut, iLen);
}

stock ClassInstanceSetMemberArray(const &ClassInstance:pInstance, const szMember[], const any:rgValue[], iLen, bool:bReplace = true) {
  static Trie:itSetters; itSetters = __cls_GetInstanceSettersTrie(pInstance);

  if (TrieKeyExists(itSetters, szMember)) {
    __cls_CallArraySetter(pInstance, szMember, rgValue, iLen);
    return;
  }

  static Trie:itMembers; itMembers = __cls_GetInstanceMembersTrie(pInstance);

  TrieSetArray(itMembers, szMember, rgValue, iLen, bReplace);
}

stock bool:ClassInstanceIsInstanceOf(const &ClassInstance:pInstance, const &Class:class) {
  new Class:sCurrentClass = __cls_GetInstanceClass(pInstance);

  do {
    if (sCurrentClass == class) return true;
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

stock Trie:__cls_GetInstanceMembersTrie(const &ClassInstance:pInstance) {
  if (pInstance != __cls_cache_InstanceMembers[__cls_InstanceCache_Instance]) {
    __cls_cache_InstanceMembers[__cls_InstanceCache_Value] = StructGetCell(Struct:pInstance, __cls_InstanceData_Members);
    __cls_cache_InstanceMembers[__cls_InstanceCache_Instance] = pInstance;
  }

  return __cls_cache_InstanceMembers[__cls_InstanceCache_Value];
}

stock Trie:__cls_GetInstanceGettersTrie(const &ClassInstance:pInstance) {
  if (pInstance != __cls_cache_InstanceGetters[__cls_InstanceCache_Instance]) {
    static Class:class; class = __cls_GetInstanceClass(pInstance);
    __cls_cache_InstanceGetters[__cls_InstanceCache_Value] = StructGetCell(Struct:class, __cls_Data_Getters);
    __cls_cache_InstanceGetters[__cls_InstanceCache_Instance] = pInstance;
  }

  return __cls_cache_InstanceGetters[__cls_InstanceCache_Value];
}

stock Trie:__cls_GetInstanceSettersTrie(const &ClassInstance:pInstance) {
  if (pInstance != __cls_cache_InstanceSetters[__cls_InstanceCache_Instance]) {
    static Class:class; class = __cls_GetInstanceClass(pInstance);
    __cls_cache_InstanceSetters[__cls_InstanceCache_Value] = StructGetCell(Struct:class, __cls_Data_Setters);
    __cls_cache_InstanceSetters[__cls_InstanceCache_Instance] = pInstance;
  }

  return __cls_cache_InstanceSetters[__cls_InstanceCache_Value];
}

stock __cls_ParseParamTypes(Array:irgArgs, &Array:irgParamTypes) {
  new iArgc = ArraySize(irgArgs);

  new rgParam[__cls_MethodParamData];

  for (new iArg = 0; iArg < iArgc; ++iArg) {
    rgParam[__cls_MethodParamData_Type] = ArrayGetCell(irgArgs, iArg);
    rgParam[__cls_MethodParamData_Size] = 1;

    switch (rgParam[__cls_MethodParamData_Type]) {
      case CMP_Array: {
        rgParam[__cls_MethodParamData_Size] = ArrayGetCell(irgArgs, iArg + 1);
        iArg++;
      }
      case CMP_ParamsCellArray: {
        rgParam[__cls_MethodParamData_Size] = 0;

        new Array:irgExtraParamTypes = ArrayGetCell(irgArgs, iArg + 1);
        iArg++;
        __cls_ParseParamTypes(irgExtraParamTypes, irgParamTypes);
      }
    }

    if (rgParam[__cls_MethodParamData_Size]) {
      ArrayPushArray(irgParamTypes, rgParam[any:0], _:__cls_MethodParamData);
    }
  }
}

stock __cls_InitMethodCall(const &ClassInstance:pInstance, const szMethod[], const &Class:class = Invalid_Class, __cls_MethodType:iMethodType) {
  static Class:callClass; callClass = class == Invalid_Class ? __cls_GetCallMethodClass(pInstance) : class;

  __cls_call_pInstance = pInstance;
  __cls_call_sMethod = __cls_FindClassMethodInHierarchy(callClass, szMethod, iMethodType);
  __cls_call_iParamsNum = 0;
  __cls_call_iParamTypesNum = StructGetCell(__cls_call_sMethod, __cls_MethodData_ParamTypesNum);

  if (__cls_call_sMethod == Invalid_Struct) {
    set_fail_state(__cls_err_MethodNotFoundInBaseClass, szMethod);
    return;
  }
}

stock __cls_FreeMethodCall() {
  __cls_call_pInstance = Invalid_ClassInstance;
  __cls_call_sMethod = Invalid_Struct;
  __cls_call_iParamsNum = 0;
  __cls_call_iParamTypesNum = 0;
  __cls_call_iBufferPos = 0;
}

stock __cls_CallMethodBegin(const &ClassInstance:pInstance, const szMethod[], __cls_MethodType:iMethodType = __cls_MethodType_Method) {
  __cls_InitMethodCall(pInstance, szMethod, _, iMethodType);

  static Class:sInstanceClass; sInstanceClass = __cls_GetInstanceClass(pInstance);

  // Check for virtual method call
  // If we are already in the execution context and the method is virual jump to top level context
  // All Getters and Setter works like virtual methods
  if (!__cls_IsMethodCallStackEmpty()) {
    if (StructGetCell(__cls_call_sMethod, __cls_MethodData_Type) != __cls_MethodType_Method) {
      if (sInstanceClass != StructGetCell(__cls_call_sMethod, __cls_MethodData_Class)) {
        __cls_call_sMethod = __cls_FindClassMethodInHierarchy(sInstanceClass, szMethod, iMethodType);
      }
    }
  }

  if (__cls_call_sMethod == Invalid_Struct) {
    set_fail_state(__cls_err_MethodNotFound, szMethod, pInstance);
    return;
  }

  static Function:func; func = StructGetCell(__cls_call_sMethod, __cls_MethodData_Function);

  if (callfunc_begin_p(func) != 1) {
    static szMethod[CLASS_METHOD_MAX_NAME_LENGTH]; StructGetString(__cls_call_sMethod, __cls_MethodData_Name, szMethod, charsmax(szMethod));
    set_fail_state(__cls_err_FailedToCallMethodFunction, szMethod);
    return;
  }
}

stock any:__cls_CallCellGetter(const &ClassInstance:pInstance, const szMember[]) {
  __cls_CallMethodBegin(pInstance, szMember, __cls_MethodType_Getter);

  return ClassInstanceCallMethodEnd();
}

stock any:__cls_CallArrayGetter(const &ClassInstance:pInstance, const szMember[], any:rgOut[], iSize) {
  __cls_CallMethodBegin(pInstance, szMember, __cls_MethodType_Getter);

  ClassInstanceCallMethodPushParamArrayRef(rgOut, iSize);
  ClassInstanceCallMethodPushParamCell(iSize);

  return ClassInstanceCallMethodEnd();
}

stock any:__cls_CallStringGetter(const &ClassInstance:pInstance, const szMember[], any:rgOut[], iLen) {
  __cls_CallMethodBegin(pInstance, szMember, __cls_MethodType_Getter);

  ClassInstanceCallMethodPushParamStringRef(rgOut, iLen);
  ClassInstanceCallMethodPushParamCell(iLen);

  return ClassInstanceCallMethodEnd();
}

stock __cls_CallCellSetter(const &ClassInstance:pInstance, const szMember[], any:value) {
  __cls_CallMethodBegin(pInstance, szMember, __cls_MethodType_Setter);

  ClassInstanceCallMethodPushParamCell(value);

  return ClassInstanceCallMethodEnd();
}

stock __cls_CallArraySetter(const &ClassInstance:pInstance, const szMember[], const any:rgValue[], iSize) {
  __cls_CallMethodBegin(pInstance, szMember, __cls_MethodType_Setter);

  ClassInstanceCallMethodPushParamArray(rgValue, iSize);

  return ClassInstanceCallMethodEnd();
}

stock __cls_CallStringSetter(const &ClassInstance:pInstance, const szMember[], const szValue[]) {
  __cls_CallMethodBegin(pInstance, szMember, __cls_MethodType_Setter);

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
  new iStructField = -1;

  switch (iMethodType) {
    case __cls_MethodType_Getter: {
      iStructField = __cls_Data_Getters;
    }
    case __cls_MethodType_Setter: {
      iStructField = __cls_Data_Setters;
    }
  }

  if (iStructField == -1) return;

  new Trie:itMethods = StructGetCell(Struct:class, iStructField);

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

stock Struct:__cls_CreateMethod(Class:class, const szName[], const Function:func, Array:irgParamTypes, __cls_MethodType:iType = __cls_MethodType_Method) {
  new Struct:sMethod = StructCreate(__cls_MethodData);
  StructSetCell(sMethod, __cls_MethodData_Class, class);
  StructSetString(sMethod, __cls_MethodData_Name, szName);
  StructSetCell(sMethod, __cls_MethodData_Function, func);
  StructSetCell(sMethod, __cls_MethodData_Type, iType);

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

    static Struct:sMethod;
    if (TrieGetCell(itMethods, szMethod, sMethod)) return sMethod;

    sCurrentClass = StructGetCell(Struct:sCurrentClass, __cls_Data_Base);
  } while (sCurrentClass != Invalid_Class);

  return Invalid_Struct;
}

stock bool:__cls_IsMethodCallStackEmpty() {
  return !__cls_callstack_size;
}

stock __cls_PushMethodCallToCallStack() {
  if (__cls_callstack_size >= CLASS_METHOD_CALL_STACK_SIZE) {
    set_fail_state(__cls_err_MaxCallStackSizeExceeded);
  }

  __cls_callstack[__cls_callstack_size][__cls_MethodCallStackItem_Instance] = any:__cls_call_pInstance;
  __cls_callstack[__cls_callstack_size][__cls_MethodCallStackItem_Class] = any:StructGetCell(__cls_call_sMethod, __cls_MethodData_Class);
  __cls_callstack[__cls_callstack_size][__cls_MethodCallStackItem_Method] = any:__cls_call_sMethod;

  __cls_callstack_size++;
}

stock __cls_PopMethodFromCallStack() {
  __cls_callstack_size--;

  if (__cls_callstack_size) {
    __cls_call_pInstance = __cls_callstack[__cls_callstack_size - 1][__cls_MethodCallStackItem_Instance];
    __cls_call_sMethod = __cls_callstack[__cls_callstack_size - 1][__cls_MethodCallStackItem_Method];
  }
}

stock __cls_GetCurrentMethodFromCallStack(rgCallStackItem[__cls_MethodCallStackItem]) {
  rgCallStackItem[__cls_MethodCallStackItem_Instance] = __cls_callstack[__cls_callstack_size - 1][__cls_MethodCallStackItem_Instance];
  rgCallStackItem[__cls_MethodCallStackItem_Class] = __cls_callstack[__cls_callstack_size - 1][__cls_MethodCallStackItem_Class];
  rgCallStackItem[__cls_MethodCallStackItem_Method] = __cls_callstack[__cls_callstack_size - 1][__cls_MethodCallStackItem_Method];
}

stock Class:__cls_GetCallMethodClass(const &ClassInstance:pInstance) {
  if (__cls_callstack_size) {
      if (__cls_callstack[__cls_callstack_size - 1][__cls_MethodCallStackItem_Instance] == pInstance) {
        return __cls_callstack[__cls_callstack_size - 1][__cls_MethodCallStackItem_Class];
      }
  }

  return __cls_GetInstanceClass(pInstance);
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
