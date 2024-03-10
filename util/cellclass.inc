#if defined _classes_included
  #endinput
#endif
#define _classes_included

#include <amxmodx>
#include <cellstruct>
#tryinclude <datapack>
#include <datapack_stocks>

#define MAX_CLASS_NAME_LENGTH 64
#define MAX_METHOD_NAME_LENGTH 64
#define MAX_METHOD_CALL_STACK_SIZE 1024

// Default argument values

#define __cls_DefaultValue_Cell 0
#define __cls_DefaultValue_Float 0.0
#define __cls_DefaultValue_String NULL_STRING

// Error messages

#define __cls_err_MethodAlreadyRegistered "Method ^"%s^" is already registered for the class!"
#define __cls_err_VMethodArgumentsMismatch "Arguments mismatch in the overridden virtual method ^"%s^"."
#define __cls_err_ClassIdNotFound "Class with id %d is not registered!"
#define __cls_err_MethodNotFound "Method ^"%s^" is not registered for the instance (%d)!"
#define __cls_err_CallMethodOutsideContext "Calling a base method is not allowed outside of the execution context!"
#define __cls_err_ClassHasNoBaseClass "Cannot call base method of class without base class!"
#define __cls_err_MethodNotFoundInBaseClass "Cannot find method ^"%s^" in base classes!"
#define __cls_err_MaxCallStackSizeExceeded "Maximum call stack size exceeded!"
#define __cls_err_ClassMethodCallEndWithoutStart "Call ClassInstanceCallMethodEnd but method call is not started"

enum Class {
  Invalid_Class = -1
};

enum ClassInstance {
  Invalid_ClassInstance = -1
};

enum {
  CMP_Invalid = -1,
  CMP_Cell,
  CMP_Float,
  CMP_String,
  CMP_Array,
  CMP_FloatArray,
  CMP_ReadFromCellArray
};

// Internal structures enum

enum __cls_Data {
    Class:__cls_Data_Base,
    Trie:__cls_Data_Members,
    Trie:__cls_Data_Methods
};

enum __cls_MethodData {
  __cls_MethodData_Name[MAX_METHOD_NAME_LENGTH],
  Class:__cls_MethodData_Class,
  __cls_MethodData_PluginId,
  __cls_MethodData_FunctionId,
  bool:__cls_MethodData_IsVirtual,
  Array:__cls_MethodData_ParamTypes
};

enum __cls_InstanceData {
  Class:__cls_InstanceData_Class,
  Trie:__cls_InstanceData_Members
};

enum __cls_MethodParamData {
  __cls_MethodParamData_Type = 0,
  __cls_MethodParamData_Size
};

enum __cls_MethodCallStackItem {
  __cls_MethodCallStackItem_Name[MAX_METHOD_NAME_LENGTH],
  ClassInstance:__cls_MethodCallStackItem_Instance,
  Class:__cls_MethodCallStackItem_Class,
  Struct:__cls_MethodCallStackItem_Method
};

// Fast pseudo-stack implementation
stock Array:__cls_callstack[MAX_METHOD_CALL_STACK_SIZE][__cls_MethodCallStackItem];
stock __cls_callstack_size = 0;

// Variables to store info between Begin and End method calls
stock ClassInstance:__cls_call_pInstance = Invalid_ClassInstance;
stock Struct:__cls_call_sMethod = Invalid_Struct;
stock DataPack:__cls_call_dpParams = Invalid_DataPack;
stock Array:__cls_call_irgParamTypes = Invalid_Array;
stock __cls_call_iParamTypesNum = 0;
stock __cls_call_sParamsNum = 0;

// Buffers
#if defined _datapack_included
  stock __cls_szBuffer[MAX_STRING_LENGTH];
  stock __cls_rgiBuffer[MAX_STRING_LENGTH];
  stock Float:__cls_rgflBuffer[MAX_STRING_LENGTH];
#endif

/*--------------------------------[ Class Functions] --------------------------------*/

stock Class:ClassCreate(const &Class:sBaseClass = Invalid_Class) {
  new Class:class = Class:StructCreate(__cls_Data);
  StructSetCell(Struct:class, __cls_Data_Base, sBaseClass);
  StructSetCell(Struct:class, __cls_Data_Methods, TrieCreate());
  StructSetCell(Struct:class, __cls_Data_Members, TrieCreate());

  return Class:class;
}

stock ClassDestroy(&Class:class) {
  new Trie:itMethods = StructGetCell(Struct:class, __cls_Data_Methods);

  new TrieIter:iMethodsIter = TrieIterCreate(itMethods);

  while (!TrieIterEnded(iMethodsIter)) {
    new Struct:sMethod; TrieIterGetCell(iMethodsIter, sMethod);
    __cls_DestroyMethod(sMethod);
    TrieIterNext(iMethodsIter);
  }

  TrieIterDestroy(iMethodsIter);

  TrieDestroy(itMethods);

  new Trie:itMembers = StructGetCell(Struct:class, __cls_Data_Members);
  TrieDestroy(itMembers);

  StructDestroy(Struct:class);

  class = Invalid_Class;
}

stock ClassFreeStorages() {
  if (__cls_call_dpParams != Invalid_DataPack) {
    DestroyDataPack(__cls_call_dpParams);
  }
}

stock Class:ClassAddMethod(const &Class:class, const szMethod[], const szCallback[], iPluginId = -1, bool:bVirtual = false, any:...) {
  static const iArgOffset = 5;

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
    new Struct:sBaseMethod = _cellclass_FindClassMethodInHierarchy(sBaseClass, szMethod);
    if (sBaseMethod != Invalid_Struct) {
      if (StructGetCell(sBaseMethod, __cls_MethodData_IsVirtual)) {
        new Array:irgBaseParamTypes = StructGetCell(sBaseMethod, __cls_MethodData_ParamTypes);
        if (!_cellclass_CompareParamTypes(irgBaseParamTypes, irgParamTypes)) {
          set_fail_state(__cls_err_VMethodArgumentsMismatch, szMethod);
          return;
        }
      }
    }
  }

  new Struct:sMethod = StructCreate(__cls_MethodData);
  StructSetCell(sMethod, __cls_MethodData_Class, class);
  StructSetString(sMethod, __cls_MethodData_Name, szMethod);
  StructSetCell(sMethod, __cls_MethodData_PluginId, iPluginId);
  StructSetCell(sMethod, __cls_MethodData_FunctionId, get_func_id(szCallback, iPluginId));
  StructSetCell(sMethod, __cls_MethodData_ParamTypes, irgParamTypes);
  StructSetCell(sMethod, __cls_MethodData_IsVirtual, bVirtual);

  TrieSetCell(itMethods, szMethod, sMethod);
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
  static Trie:itMembers; itMembers = StructGetCell(Struct:pInstance, __cls_InstanceData_Members);
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
  ClassInstanceCallMethodBegin(pInstance, szMethod);

  #if defined _datapack_included    
    for (new iMethodParam = 0; iMethodParam < __cls_call_iParamTypesNum; ++iMethodParam) {
      static iParam; iParam = 2 + iMethodParam;
      static iType; iType = ArrayGetCell(__cls_call_irgParamTypes, iMethodParam, _:__cls_MethodParamData_Type);
      static iArgc; iArgc = ArrayGetCell(__cls_call_irgParamTypes, iMethodParam, _:__cls_MethodParamData_Size);
      static bool:bUseDefault; bUseDefault = iParam > numargs();

      switch (iType) {
        case CMP_Cell: {
          ClassInstanceCallMethodPushParamCell(bUseDefault ? __cls_DefaultValue_Cell : getarg(iParam));
        }
        case CMP_Float: {
          ClassInstanceCallMethodPushParamFloat(bUseDefault ? __cls_DefaultValue_Float : Float:getarg(iParam));
        }
        case CMP_String: {
          if (bUseDefault) {
            copy(__cls_szBuffer, sizeof(__cls_szBuffer), __cls_DefaultValue_String);
          } else {
            for (new i = 0; i < charsmax(__cls_szBuffer); ++i) {
                __cls_szBuffer[i] = getarg(iParam, i);
                if (__cls_szBuffer[i]  == '^0') break;
            }
          }

          ClassInstanceCallMethodPushParamString(__cls_szBuffer);
        }
        case CMP_Array: {
          if (bUseDefault) {
            arrayset(__cls_rgiBuffer, __cls_DefaultValue_Float, iArgc);
          } else {
            for (new i = 0; i < iArgc; ++i) {
                __cls_rgiBuffer[i] = getarg(iParam, i);
            }
          }

          ClassInstanceCallMethodPushParamArray(__cls_rgiBuffer, iArgc);
        }
        case CMP_FloatArray: {
          if (bUseDefault) {
            arrayset(__cls_rgflBuffer, __cls_DefaultValue_Float, iArgc);
          } else {
            for (new i = 0; i < iArgc; ++i) {
                __cls_rgflBuffer[i] = Float:getarg(iParam, i);
            }
          }

          ClassInstanceCallMethodPushParamFloatArray(__cls_rgflBuffer, iArgc);
        }
      }
    }
  #endif

  return ClassInstanceCallMethodEnd();
}

stock ClassInstanceCallBaseMethod(any:...) {
  ClassInstanceCallMethodBeginBase();

  #if defined _datapack_included
    for (new iMethodParam = 0; iMethodParam < __cls_call_iParamTypesNum; ++iMethodParam) {
      static iParam; iParam = 0 + iMethodParam;
      static iType; iType = ArrayGetCell(__cls_call_irgParamTypes, iMethodParam, _:__cls_MethodParamData_Type);
      static iArgc; iArgc = ArrayGetCell(__cls_call_irgParamTypes, iMethodParam, _:__cls_MethodParamData_Size);
      static bool:bUseDefault; bUseDefault = iParam > numargs();

      switch (iType) {
        case CMP_Cell: {
          ClassInstanceCallMethodPushParamCell(bUseDefault ? __cls_DefaultValue_Cell : getarg(iParam));
        }
        case CMP_Float: {
          ClassInstanceCallMethodPushParamFloat(bUseDefault ? __cls_DefaultValue_Float : Float:getarg(iParam));
        }
        case CMP_String: {
          if (bUseDefault) {
            copy(__cls_szBuffer, sizeof(__cls_szBuffer), __cls_DefaultValue_String);
          } else {
            for (new i = 0; i < charsmax(__cls_szBuffer); ++i) {
                __cls_szBuffer[i] = getarg(iParam, i);
                if (__cls_szBuffer[i]  == '^0') break;
            }
          }

          ClassInstanceCallMethodPushParamString(__cls_szBuffer);
        }
        case CMP_Array: {
          if (bUseDefault) {
            arrayset(__cls_rgiBuffer, __cls_DefaultValue_Float, iArgc);
          } else {
            for (new i = 0; i < iArgc; ++i) {
                __cls_rgiBuffer[i] = getarg(iParam, i);
            }
          }

          ClassInstanceCallMethodPushParamArray(__cls_rgiBuffer, iArgc);
        }
        case CMP_FloatArray: {
          if (bUseDefault) {
            arrayset(__cls_rgflBuffer, __cls_DefaultValue_Float, iArgc);
          } else {
            for (new i = 0; i < iArgc; ++i) {
                __cls_rgflBuffer[i] = Float:getarg(iParam, i);
            }
          }

          ClassInstanceCallMethodPushParamFloatArray(__cls_rgflBuffer, iArgc);
        }
      }
    }
  #endif

  return ClassInstanceCallMethodEnd();
}

stock ClassInstanceCallMethodBegin(const &ClassInstance:pInstance, const szMethod[]) {
  __cls_InitMethodCall(pInstance, szMethod);

  // Check for virtual method call
  // If we are already in the execution context and the method is virual jump to top level context
  if (!__cls_IsMethodCallStackEmpty() && StructGetCell(__cls_call_sMethod, __cls_MethodData_IsVirtual)) {
    static Class:sInstanceClass; sInstanceClass = StructGetCell(Struct:pInstance, __cls_InstanceData_Class);
    if (sInstanceClass != StructGetCell(__cls_call_sMethod, __cls_MethodData_Class)) {
      __cls_call_sMethod = _cellclass_FindClassMethodInHierarchy(sInstanceClass, szMethod);
    }
  }

  if (__cls_call_sMethod == Invalid_Struct) {
    set_fail_state(__cls_err_MethodNotFound, szMethod, pInstance);
    return;
  }
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

  static szMethod[MAX_METHOD_NAME_LENGTH]; StructGetString(rgCallStackItem[__cls_MethodCallStackItem_Method], __cls_MethodData_Name, szMethod, charsmax(szMethod));

  __cls_InitMethodCall(rgCallStackItem[__cls_MethodCallStackItem_Instance], szMethod, class);

}

stock any:ClassInstanceCallMethodEnd() {
  if (__cls_call_sMethod == Invalid_Struct) {
    set_fail_state(__cls_err_ClassMethodCallEndWithoutStart);
    return 0;
  }

  __cls_ValidateParams();

  ResetPack(__cls_call_dpParams);

  static any:result; result = __cls_ExecuteMethod(__cls_call_pInstance, __cls_call_sMethod, __cls_call_dpParams, __cls_call_irgParamTypes);

  if (__cls_IsMethodCallStackEmpty()) {
    __cls_FreeMethodCall();
  }

  return result;
}

stock ClassInstanceCallMethodPushParamCell(iValue) {
    if (__cls_call_sParamsNum >= __cls_call_iParamTypesNum) return;
    WritePackCell(__cls_call_dpParams, iValue);
    __cls_call_sParamsNum++;
}

stock ClassInstanceCallMethodPushParamFloat(Float:flValue) {
    if (__cls_call_sParamsNum >= __cls_call_iParamTypesNum) return;
    WritePackFloat(__cls_call_dpParams, flValue);
    __cls_call_sParamsNum++;
}

stock ClassInstanceCallMethodPushParamString(const szValue[]) {
    if (__cls_call_sParamsNum >= __cls_call_iParamTypesNum) return;
    WritePackString(__cls_call_dpParams, szValue);
    __cls_call_sParamsNum++;
}

stock ClassInstanceCallMethodPushParamArray(const rgValue[], iArgc) {
    if (__cls_call_sParamsNum >= __cls_call_iParamTypesNum) return;
    WritePackArray(__cls_call_dpParams, rgValue, iArgc);
    __cls_call_sParamsNum++;
}

stock ClassInstanceCallMethodPushParamFloatArray(const Float:rgValue[], iArgc) {
    if (__cls_call_sParamsNum >= __cls_call_iParamTypesNum) return;
    WritePackFloatArray(__cls_call_dpParams, rgValue, iArgc);
    __cls_call_sParamsNum++;
}

stock ClassInstanceCallMethodPushNativeParam(iParam) {
  if (__cls_call_sParamsNum >= __cls_call_iParamTypesNum) return;

  static iType; iType = ArrayGetCell(__cls_call_irgParamTypes, __cls_call_sParamsNum, _:__cls_MethodParamData_Type);
  static iArgc; iArgc = ArrayGetCell(__cls_call_irgParamTypes, __cls_call_sParamsNum, _:__cls_MethodParamData_Size);

  switch (iType) {
    case CMP_Cell: {
      WritePackCell(__cls_call_dpParams, get_param_byref(iParam));
    }
    case CMP_Float: {
      WritePackFloat(__cls_call_dpParams, Float:get_param_byref(iParam));
    }
    case CMP_String: {
      get_string(iParam, __cls_szBuffer, charsmax(__cls_szBuffer));
      WritePackString(__cls_call_dpParams, __cls_szBuffer);
    }
    case CMP_Array: {
      get_array(iParam, __cls_rgiBuffer, iArgc);
      WritePackArray(__cls_call_dpParams, __cls_rgiBuffer, iArgc);
    }
    case CMP_FloatArray: {
      get_array_f(iParam, __cls_rgflBuffer, iArgc);
      WritePackFloatArray(__cls_call_dpParams, __cls_rgflBuffer, iArgc);
    }
  }

  __cls_call_sParamsNum++;
}

stock Class:ClassInstanceGetClass(const &ClassInstance:pInstance) {
  return StructGetCell(Struct:pInstance, __cls_InstanceData_Class);
}

stock bool:ClassInstanceHasMember(const &ClassInstance:pInstance, const szMember[]) {
  static Trie:itMembers; itMembers = StructGetCell(Struct:pInstance, __cls_InstanceData_Members);

  return TrieKeyExists(itMembers, szMember);
}

stock ClassInstanceDeleteMember(const &ClassInstance:pInstance, const szMember[]) {
  static Trie:itMembers; itMembers = StructGetCell(Struct:pInstance, __cls_InstanceData_Members);

  TrieDeleteKey(itMembers, szMember);
}

stock any:ClassInstanceGetMember(const &ClassInstance:pInstance, const szMember[]) {
  static Trie:itMembers; itMembers = StructGetCell(Struct:pInstance, __cls_InstanceData_Members);

  static any:value;
  return TrieGetCell(itMembers, szMember, value) ? value : 0;
}

stock ClassInstanceSetMember(const &ClassInstance:pInstance, const szMember[], any:value, bool:bReplace = true) {
  static Trie:itMembers; itMembers = StructGetCell(Struct:pInstance, __cls_InstanceData_Members);

  TrieSetCell(itMembers, szMember, value, bReplace);
}

stock bool:ClassInstanceGetMemberString(const &ClassInstance:pInstance, const szMember[], szOut[], iMaxLen) {
  static Trie:itMembers; itMembers = StructGetCell(Struct:pInstance, __cls_InstanceData_Members);

  copy(szOut, iMaxLen, NULL_STRING);
  return !!TrieGetString(itMembers, szMember, szOut, iMaxLen);
}

stock ClassInstanceSetMemberString(const &ClassInstance:pInstance, const szMember[], const szValue[], bool:bReplace = true) {
  static Trie:itMembers; itMembers = StructGetCell(Struct:pInstance, __cls_InstanceData_Members);

  TrieSetString(itMembers, szMember, szValue, bReplace);
}

stock bool:ClassInstanceGetMemberArray(const &ClassInstance:pInstance, const szMember[], any:rgOut[], iLen) {
  static Trie:itMembers; itMembers = StructGetCell(Struct:pInstance, __cls_InstanceData_Members);

  return !!TrieGetArray(itMembers, szMember, rgOut, iLen);
}

stock ClassInstanceSetMemberArray(const &ClassInstance:pInstance, const szMember[], const any:rgValue[], iLen, bool:bReplace = true) {
  static Trie:itMembers; itMembers = StructGetCell(Struct:pInstance, __cls_InstanceData_Members);

  TrieSetArray(itMembers, szMember, rgValue, iLen, bReplace);
}

stock bool:ClassInstanceIsInstanceOf(const &ClassInstance:pInstance, const &Class:class) {
  new Class:sCurrentClass = StructGetCell(Struct:pInstance, __cls_InstanceData_Class);

  do {
    if (sCurrentClass == class) return true;
    sCurrentClass = StructGetCell(Struct:sCurrentClass, __cls_Data_Base);
  } while (sCurrentClass != Invalid_Class);

  return false;
}

/*--------------------------------[ Internal Functions] --------------------------------*/

stock __cls_ParseParamTypes(Array:irgArgs, &Array:irgParamTypes) {
  new iArgc = ArraySize(irgArgs);

  new rgParam[__cls_MethodParamData];

  for (new iArg = 0; iArg < iArgc; ++iArg) {
    rgParam[__cls_MethodParamData_Type] = ArrayGetCell(irgArgs, iArg);
    rgParam[__cls_MethodParamData_Size] = 1;

    switch (rgParam[__cls_MethodParamData_Type]) {
      case CMP_Array, CMP_FloatArray: {
        rgParam[__cls_MethodParamData_Size] = ArrayGetCell(irgArgs, iArg + 1);
        iArg++;
      }
      case CMP_ReadFromCellArray: {
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

stock __cls_ValidateParams() {
  for (new iParam = __cls_call_sParamsNum; iParam < __cls_call_iParamTypesNum; ++iParam) {
    static iType; iType = ArrayGetCell(__cls_call_irgParamTypes, iParam, _:__cls_MethodParamData_Type);
    static iSize; iSize = ArrayGetCell(__cls_call_irgParamTypes, iParam, _:__cls_MethodParamData_Size);

    switch (iType) {
      case CMP_Cell: {
        WritePackCell(__cls_call_dpParams, __cls_DefaultValue_Cell);
      }
      case CMP_Float: {
        WritePackFloat(__cls_call_dpParams, __cls_DefaultValue_Float);
      }
      case CMP_String: {
        WritePackString(__cls_call_dpParams, __cls_DefaultValue_String);
      }
      case CMP_Array: {
        arrayset(__cls_rgiBuffer, __cls_DefaultValue_Cell, iSize);
        WritePackArray(__cls_call_dpParams, __cls_rgiBuffer, iSize);
      }
      case CMP_FloatArray: {
        arrayset(__cls_rgflBuffer, __cls_DefaultValue_Float, iSize);
        WritePackFloatArray(__cls_call_dpParams, __cls_rgflBuffer, iSize);
      }
    }
  }
}

stock __cls_InitMethodCall(const &ClassInstance:pInstance, const szMethod[], const &Class:class = Invalid_Class) {
  static Class:callClass; callClass = class == Invalid_Class ? __cls_GetCallMethodClass(pInstance) : class;

  __cls_call_pInstance = pInstance;
  __cls_call_sMethod = _cellclass_FindClassMethodInHierarchy(callClass, szMethod);
  __cls_call_sParamsNum = 0;
  __cls_call_irgParamTypes = StructGetCell(__cls_call_sMethod, __cls_MethodData_ParamTypes);
  __cls_call_iParamTypesNum = ArraySize(__cls_call_irgParamTypes);

  if (__cls_call_sMethod == Invalid_Struct) {
    set_fail_state(__cls_err_MethodNotFoundInBaseClass, szMethod);
    return;
  }

  static DataPack:dpParams; dpParams = __cls_GetDataPackParams();
  ResetPack(dpParams);
}

stock __cls_FreeMethodCall() {
  __cls_call_pInstance = Invalid_ClassInstance;
  __cls_call_sMethod = Invalid_Struct;
  __cls_call_sParamsNum = 0;
  __cls_call_irgParamTypes = Invalid_Array;
  __cls_call_iParamTypesNum = 0;
}

stock __cls_DestroyMethod(&Struct:sMethod) {
    new Array:irgParamTypes; StructGetCell(sMethod, __cls_MethodData_ParamTypes);

    if (irgParamTypes != Invalid_Array) {
      ArrayDestroy(irgParamTypes);
    }

    StructDestroy(sMethod);
}

stock _cellclass_CompareParamTypes(const &Array:irgParams, const &Array:irgOtherParams) {
  new iArgc = ArraySize(irgParams);
  new iOtherSize = ArraySize(irgOtherParams);

  if (iArgc != iOtherSize) return false;

  for (new i = 0; i < iArgc; ++i) {
    if (ArrayGetCell(irgParams, i) != ArrayGetCell(irgOtherParams, i)) return false;
  }

  return true;
}

stock __cls_ExecuteMethod(const &ClassInstance:pInstance, const &Struct:sMethod, const &DataPack:dpParams, const &Array:irgParamTypes) {
  new iResult = 0;

  __cls_PushMethodToCallStack(sMethod, pInstance);

  if (callfunc_begin_i(StructGetCell(sMethod, __cls_MethodData_FunctionId), StructGetCell(sMethod, __cls_MethodData_PluginId)) == 1) {
    #if defined _datapack_included
      if (dpParams != Invalid_DataPack) {
        static iParamsNum; iParamsNum = ArraySize(irgParamTypes);

        for (new iParam = 0; iParam < iParamsNum; ++iParam) {
          static iType; iType = ArrayGetCell(irgParamTypes, iParam, _:__cls_MethodParamData_Type);
          static iSize; iSize = ArrayGetCell(irgParamTypes, iParam, _:__cls_MethodParamData_Size);

          switch (iType) {
            case CMP_Cell: {
              static iValue; iValue = ReadPackCell(dpParams);
              callfunc_push_int(iValue);
            }
            case CMP_Float: {
              static Float:flValue; flValue = ReadPackFloat(dpParams);
              callfunc_push_float(flValue);
            }
            case CMP_String: {
              ReadPackString(dpParams, __cls_szBuffer, charsmax(__cls_szBuffer));
              callfunc_push_str(__cls_szBuffer);
            }
            case CMP_Array: {
              static iLen; iLen = ReadPackArray(dpParams, __cls_rgiBuffer, iSize);
              callfunc_push_array(__cls_rgiBuffer, iLen, false);
            }
            case CMP_FloatArray: {
              static iLen; iLen = ReadPackFloatArray(dpParams, __cls_rgflBuffer, iSize);
              callfunc_push_array(_:__cls_rgflBuffer, iLen, false);
            }
          }
        }
      }
    #endif

    iResult = callfunc_end();
  }

  __celstruct_PopMethodFromCallStack();

  return iResult;
}

stock Struct:_cellclass_FindClassMethodInHierarchy(const &Class:class, const szMethod[]) {
  new Class:sCurrentClass = class;

  do {
    static Trie:itMethods; itMethods = StructGetCell(Struct:sCurrentClass, __cls_Data_Methods);

    static Struct:sMethod;
    if (TrieGetCell(itMethods, szMethod, sMethod)) return sMethod;

    sCurrentClass = StructGetCell(Struct:sCurrentClass, __cls_Data_Base);
  } while (sCurrentClass != Invalid_Class);

  return Invalid_Struct;
}

stock bool:__cls_IsMethodCallStackEmpty() {
  return !__cls_callstack_size;
}

stock __cls_PushMethodToCallStack(const Struct:sMethod, const &ClassInstance:pInstance) {
  if (__cls_callstack_size >= MAX_METHOD_CALL_STACK_SIZE) {
    set_fail_state(__cls_err_MaxCallStackSizeExceeded);
  }

  __cls_callstack[__cls_callstack_size][__cls_MethodCallStackItem_Instance] = any:pInstance;
  __cls_callstack[__cls_callstack_size][__cls_MethodCallStackItem_Class] = any:StructGetCell(sMethod, __cls_MethodData_Class);
  __cls_callstack[__cls_callstack_size][__cls_MethodCallStackItem_Method] = any:sMethod;

  __cls_callstack_size++;
}

stock __celstruct_PopMethodFromCallStack() {
  __cls_callstack_size--;
}

stock __cls_GetCurrentMethodFromCallStack(rgCallStackItem[__cls_MethodCallStackItem]) {
  rgCallStackItem[__cls_MethodCallStackItem_Instance] = __cls_callstack[__cls_callstack_size - 1][__cls_MethodCallStackItem_Instance];
  rgCallStackItem[__cls_MethodCallStackItem_Class] = __cls_callstack[__cls_callstack_size - 1][__cls_MethodCallStackItem_Class];
  rgCallStackItem[__cls_MethodCallStackItem_Method] = __cls_callstack[__cls_callstack_size - 1][__cls_MethodCallStackItem_Method];
}

stock DataPack:__cls_GetDataPackParams() {
  if (__cls_call_dpParams == Invalid_DataPack) {
    __cls_call_dpParams = CreateDataPack();
  }

  return __cls_call_dpParams;
}

stock Class:__cls_GetCallMethodClass(const &ClassInstance:pInstance) {
  if (!__cls_IsMethodCallStackEmpty()) {
      static rgCallStackItem[__cls_MethodCallStackItem]; __cls_GetCurrentMethodFromCallStack(rgCallStackItem);

      if (rgCallStackItem[__cls_MethodCallStackItem_Instance] == pInstance) {
        return rgCallStackItem[__cls_MethodCallStackItem_Class];
      }
  }

  return StructGetCell(Struct:pInstance, __cls_InstanceData_Class);
}