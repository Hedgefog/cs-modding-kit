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

#define DEFAULT_CELL_VALUE 0
#define DEFAULT_FLOAT_VALUE 0.0
#define DEFAULT_STRING_VALUE NULL_STRING

#define __class_err_MethodAlreadyRegistered "Method ^"%s^" is already registered for the class!"
#define __class_err_VMethodArgumentsMismatch "Arguments mismatch in the overridden virtual method ^"%s^"."
#define __class_err_ClassIdNotFound "Class with id %d is not registered!"
#define __class_err_MethodNotFound "Method ^"%s^" is not registered for the instance (%d)!"
#define __class_err_CallMethodOutsideContext "Calling a base method is not allowed outside of the execution context!"
#define __class_err_ClassHasNoBaseClass "Cannot call base method of class without base class!"
#define __class_err_MethodNotFoundInBaseClass "Cannot find method ^"%s^" in base classes!"

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
  CMP_FloatArray
};

enum __class_Data {
    Class:__class_Data_Base,
    Array:__class_Data_Hierarchy,
    Trie:__class_Data_Methods
};

enum __class_MethodData {
  __class_MethodData_Name[MAX_METHOD_NAME_LENGTH],
  Class:__class_MethodData_Class,
  __class_MethodData_PluginId,
  __class_MethodData_FunctionId,
  bool:__class_MethodData_IsVirtual,
  Array:__class_MethodData_ParamTypes
};

enum __class_InstanceData {
  Class:__class_InstanceData_Class,
  Trie:__class_InstanceData_Members
};

enum __class_MethodParamData {
  __class_MethodParamData_Type = 0,
  __class_MethodParamData_Size
};

enum __class_MethodCallStackItem {
  ClassInstance:__class_MethodCallStackItem_Instance,
  Class:__class_MethodCallStackItem_Class,
  Struct:__class_MethodCallStackItem_Method
};

stock bool:__class_bInitialized = false;
new Array:__class_irgMethodCallStack;
new DataPack:__class_dpParams = Invalid_DataPack;

#if defined _datapack_included
  new __class_szBuffer[MAX_STRING_LENGTH];
  new __class_rgiBuffer[MAX_STRING_LENGTH];
  new Float:__class_rgflBuffer[MAX_STRING_LENGTH];
#endif

stock Class:ClassCreate(const &Class:sBaseClass = Invalid_Class) {
  if (!__class_bInitialized) {
    __class_Initialize();
  }

  new Trie:itMethods = TrieCreate(); 

  new Class:class = Class:StructCreate(__class_Data);
  StructSetCell(Struct:class, __class_Data_Base, sBaseClass);
  StructSetCell(Struct:class, __class_Data_Methods, itMethods);

  return Class:class;
}

stock ClassDestroy(const &Class:cClass) {
  new Trie:itMethods = StructGetCell(Struct:cClass, __class_Data_Methods);
  TrieDestroy(itMethods);

  StructDestroy(Struct:cClass);
}

stock Class:ClassAddMethod(const &Class:class, const szMethod[], const szCallback[], iPluginId = -1, bool:bVirtual = false, any:...) {
  static const iArgOffset = 5;

  new iArgc = numargs();

  new Class:sBaseClass = StructGetCell(Struct:class, __class_Data_Base);
  new Trie:itMethods = StructGetCell(Struct:class, __class_Data_Methods);

  if (TrieKeyExists(itMethods, szMethod)) {
    log_error(AMX_ERR_NATIVE, __class_err_MethodAlreadyRegistered, szMethod);
    return;
  }

  new Array:irgParamTypes; irgParamTypes = ArrayCreate(_:__class_MethodParamData, iArgc - iArgOffset);

  for (new iArg = iArgOffset; iArg <= iArgc; ++iArg) {
    new rgParam[__class_MethodParamData];
    rgParam[__class_MethodParamData_Type] = getarg(iArg);
    rgParam[__class_MethodParamData_Size] = 1;

    switch (rgParam[__class_MethodParamData_Type]) {
      case CMP_Array, CMP_FloatArray: {
        rgParam[__class_MethodParamData_Size] = getarg(iArg + 1);
        iArg++;
      }
    }

    ArrayPushArray(irgParamTypes, rgParam[any:0], _:__class_MethodParamData);
  }

  if (sBaseClass != Invalid_Class) {
    new Struct:sBaseMethod = _cellclass_FindClassMethodInHierarchy(sBaseClass, szMethod);
    if (sBaseMethod != Invalid_Struct) {
      if (StructGetCell(sBaseMethod, __class_MethodData_IsVirtual)) {
        new Array:irgBaseParamTypes = StructGetCell(sBaseMethod, __class_MethodData_ParamTypes);
        if (!_cellclass_CompareParamTypes(irgBaseParamTypes, irgParamTypes)) {
          log_error(AMX_ERR_NATIVE, __class_err_VMethodArgumentsMismatch, szMethod);
          return;
        }
      }
    }
  }

  new Struct:sMethod = StructCreate(__class_MethodData);
  StructSetCell(sMethod, __class_MethodData_Class, class);
  StructSetString(sMethod, __class_MethodData_Name, szMethod);
  StructSetCell(sMethod, __class_MethodData_PluginId, iPluginId);
  StructSetCell(sMethod, __class_MethodData_FunctionId, get_func_id(szCallback, iPluginId));
  StructSetCell(sMethod, __class_MethodData_ParamTypes, irgParamTypes);
  StructSetCell(sMethod, __class_MethodData_IsVirtual, bVirtual);

  TrieSetCell(itMethods, szMethod, sMethod);
}

stock ClassInstance:ClassGetCurrentInstance() {
  if (__class_IsMethodCallStackEmtpy()) {
    log_error(AMX_ERR_NATIVE, __class_err_CallMethodOutsideContext);
    return Invalid_ClassInstance;
  }

  static rgCallStackItem[__class_MethodCallStackItem]; __class_GetCurrentMethodFromCallStack(rgCallStackItem);

  return rgCallStackItem[__class_MethodCallStackItem_Instance];
}

stock ClassCallMethod(const &ClassInstance:pInstance, const szMethod[], any:...) {
  static Class:class; class = __class_GetCallMethodClass(pInstance);

  static Struct:sMethod; sMethod = _cellclass_FindClassMethodInHierarchy(class, szMethod);

  // Check for virtual method call
  if (!__class_IsMethodCallStackEmtpy()) {
    // If we are already in the execution context and the method is virual jump to top level context
    if (StructGetCell(sMethod, __class_MethodData_IsVirtual)) {
      static Class:sInstanceClass; sInstanceClass = StructGetCell(Struct:pInstance, __class_InstanceData_Class);
      sMethod = _cellclass_FindClassMethodInHierarchy(sInstanceClass, szMethod);
    }
  }

  #if defined _datapack_included
    ResetPack(__class_dpParams, true);
    
    new Array:irgParamTypes; irgParamTypes = StructGetCell(sMethod, __class_MethodData_ParamTypes);

    new iParamsNum; iParamsNum = ArraySize(irgParamTypes);
    for (new iMethodParam = 0; iMethodParam < iParamsNum; ++iMethodParam) {
      new iParam; iParam = 2 + iMethodParam;
      new iType; iType = ArrayGetCell(irgParamTypes, iMethodParam, _:__class_MethodParamData_Type);
      new iSize; iSize = ArrayGetCell(irgParamTypes, iMethodParam, _:__class_MethodParamData_Size);
      new bool:bUseDefault; bUseDefault = iParam > numargs();

      switch (iType) {
        case CMP_Cell: {
          WritePackCell(__class_dpParams, bUseDefault ? DEFAULT_CELL_VALUE : getarg(iParam));
        }
        case CMP_Float: {
          WritePackFloat(__class_dpParams, bUseDefault ? DEFAULT_FLOAT_VALUE : Float:getarg(iParam));
        }
        case CMP_String: {
          if (bUseDefault) {
            copy(__class_szBuffer, sizeof(__class_szBuffer), DEFAULT_STRING_VALUE);
          } else {
            for (new i = 0; i < charsmax(__class_szBuffer); ++i) {
                __class_szBuffer[i] = getarg(iParam, i);
                if (__class_szBuffer[i]  == '^0') break;
            }
          }

          WritePackString(__class_dpParams, __class_szBuffer);
        }
        case CMP_Array: {
          if (bUseDefault) {
            arrayset(__class_rgiBuffer, DEFAULT_FLOAT_VALUE, iSize);
          } else {
            for (new i = 0; i < iSize; ++i) {
                __class_rgiBuffer[i] = getarg(iParam, i);
            }
          }

          WritePackArray(__class_dpParams, __class_rgiBuffer, iSize);
        }
        case CMP_FloatArray: {
          if (bUseDefault) {
            arrayset(__class_rgflBuffer, DEFAULT_FLOAT_VALUE, iSize);
          } else {
            for (new i = 0; i < iSize; ++i) {
                __class_rgflBuffer[i] = Float:getarg(iParam, i);
            }
          }

          WritePackFloatArray(__class_dpParams, __class_rgflBuffer, iSize);
        }
      }
    }
  #endif

  #if defined _datapack_included
    ResetPack(__class_dpParams);
  #endif

  new any:result; result = __class_ExecuteMethod(sMethod, pInstance, __class_dpParams);

  return result;
}

stock any:ClassCallBaseMethod(any:...) {
  if (__class_IsMethodCallStackEmtpy()) {
    log_error(AMX_ERR_NATIVE, __class_err_CallMethodOutsideContext);
    return 0;
  }

  static rgCallStackItem[__class_MethodCallStackItem]; __class_GetCurrentMethodFromCallStack(rgCallStackItem);

  static Class:class; class = StructGetCell(Struct:rgCallStackItem[__class_MethodCallStackItem_Class], __class_Data_Base);
  
  if (class == Invalid_Class) {
    log_error(AMX_ERR_NATIVE, __class_err_ClassHasNoBaseClass);
    return 0;
  }

  new szMethod[MAX_METHOD_NAME_LENGTH]; StructGetString(rgCallStackItem[__class_MethodCallStackItem_Method], __class_MethodData_Name, szMethod, charsmax(szMethod));

  static Struct:sMethod; sMethod = _cellclass_FindClassMethodInHierarchy(class, szMethod);

  if (sMethod == Invalid_Struct) {
    log_error(AMX_ERR_NATIVE, __class_err_MethodNotFoundInBaseClass, szMethod);
    return 0;
  }

  #if defined _datapack_included
    ResetPack(__class_dpParams, true);

    new Array:irgParamTypes; irgParamTypes = StructGetCell(sMethod, __class_MethodData_ParamTypes);

    new iParamsNum; iParamsNum = ArraySize(irgParamTypes);
    for (new iMethodParam = 0; iMethodParam < iParamsNum; ++iMethodParam) {
      new iParam; iParam = 0 + iMethodParam;
      new iType; iType = ArrayGetCell(irgParamTypes, iMethodParam, _:__class_MethodParamData_Type);
      new iSize; iSize = ArrayGetCell(irgParamTypes, iMethodParam, _:__class_MethodParamData_Size);
      new bool:bUseDefault; bUseDefault = iParam > numargs();

      switch (iType) {
        case CMP_Cell: {
          WritePackCell(__class_dpParams, bUseDefault ? DEFAULT_CELL_VALUE : getarg(iParam));
        }
        case CMP_Float: {
          WritePackFloat(__class_dpParams, bUseDefault ? DEFAULT_FLOAT_VALUE : Float:getarg(iParam));
        }
        case CMP_String: {
          if (bUseDefault) {
            copy(__class_szBuffer, sizeof(__class_szBuffer), DEFAULT_STRING_VALUE);
          } else {
            for (new i = 0; i < charsmax(__class_szBuffer); ++i) {
                __class_szBuffer[i] = getarg(iParam, i);
                if (__class_szBuffer[i]  == '^0') break;
            }
          }

          WritePackString(__class_dpParams, __class_szBuffer);
        }
        case CMP_Array: {
          if (bUseDefault) {
            arrayset(__class_rgiBuffer, DEFAULT_FLOAT_VALUE, iSize);
          } else {
            for (new i = 0; i < iSize; ++i) {
                __class_rgiBuffer[i] = getarg(iParam, i);
            }
          }

          WritePackArray(__class_dpParams, __class_rgiBuffer, iSize);
        }
        case CMP_FloatArray: {
          if (bUseDefault) {
            arrayset(__class_rgflBuffer, DEFAULT_FLOAT_VALUE, iSize);
          } else {
            for (new i = 0; i < iSize; ++i) {
                __class_rgflBuffer[i] = Float:getarg(iParam, i);
            }
          }

          WritePackFloatArray(__class_dpParams, __class_rgflBuffer, iSize);
        }
      }
    }
  #endif

  #if defined _datapack_included
    ResetPack(__class_dpParams);
  #endif

  new any:result; result = __class_ExecuteMethod(sMethod, rgCallStackItem[__class_MethodCallStackItem_Instance], __class_dpParams);

  return result;
}

stock ClassInstance:ClassCreateInstance(const &Class:class) {
  static Struct:pInstance; pInstance = StructCreate(__class_InstanceData);
  StructSetCell(pInstance, __class_InstanceData_Class, class);
  StructSetCell(pInstance, __class_InstanceData_Members, TrieCreate());

  return ClassInstance:pInstance;
}

stock ClassDestroyInstance(&ClassInstance:pInstance) {
  static Trie:itMembers; itMembers = StructGetCell(Struct:pInstance, __class_InstanceData_Members);
  TrieDestroy(itMembers);

  StructDestroy(pInstance);

  pInstance = Invalid_Struct;
}

stock bool:ClassInstanceHasMember(const &ClassInstance:pInstance, const szMember[]) {
  static Trie:itMembers; itMembers = StructGetCell(Struct:pInstance, __class_InstanceData_Members);

  return TrieKeyExists(itMembers, szMember);
}

stock ClassDelInstanceeteMember(const &ClassInstance:pInstance, const szMember[]) {
  static Trie:itMembers; itMembers = StructGetCell(Struct:pInstance, __class_InstanceData_Members);

  TrieDeleteKey(itMembers, szMember);
}

stock any:ClassInstanceGetMember(const &ClassInstance:pInstance, const szMember[]) {
  static Trie:itMembers; itMembers = StructGetCell(Struct:pInstance, __class_InstanceData_Members);

  static any:value;
  return TrieGetCell(itMembers, szMember, value) ? value : 0;
}

stock ClassInstanceSetMember(const &ClassInstance:pInstance, const szMember[], any:value) {
  static Trie:itMembers; itMembers = StructGetCell(Struct:pInstance, __class_InstanceData_Members);

  TrieSetCell(itMembers, szMember, value);
}

stock bool:ClassInstanceGetMemberVec(const &ClassInstance:pInstance, const szMember[], Float:vecOut[]) {
  static Trie:itMembers; itMembers = StructGetCell(Struct:pInstance, __class_InstanceData_Members);

  return !!TrieGetArray(itMembers, szMember, vecOut, 3);
}

stock ClassInstanceSetMemberVec(const &ClassInstance:pInstance, const szMember[], const Float:vecValue[3]) {
  static Trie:itMembers; itMembers = StructGetCell(Struct:pInstance, __class_InstanceData_Members);

  TrieSetArray(itMembers, szMember, vecValue, 3);
}

stock bool:ClassInstanceGetMemberString(const &ClassInstance:pInstance, const szMember[], szOut[], iMaxLen) {
  static Trie:itMembers; itMembers = StructGetCell(Struct:pInstance, __class_InstanceData_Members);

  copy(szOut, iMaxLen, NULL_STRING);
  return !!TrieGetString(itMembers, szMember, szOut, iMaxLen);
}

stock ClassInstanceSetMemberString(const &ClassInstance:pInstance, const szMember[], const szValue[]) {
  static Trie:itMembers; itMembers = StructGetCell(Struct:pInstance, __class_InstanceData_Members);

  TrieSetString(itMembers, szMember, szValue);
}

stock bool:ClassInstanceGetMemberArray(const &ClassInstance:pInstance, const szMember[], any:rgOut[], iLen) {
  static Trie:itMembers; itMembers = StructGetCell(Struct:pInstance, __class_InstanceData_Members);

  return !!TrieGetArray(itMembers, szMember, rgOut, iLen);
}

stock ClassInstanceSetMemberArray(const &ClassInstance:pInstance, const szMember[], const rgValue[], iLen) {
  static Trie:itMembers; itMembers = StructGetCell(Struct:pInstance, __class_InstanceData_Members);

  TrieSetArray(itMembers, szMember, rgValue, iLen);
}


__class_Initialize() {
  __class_irgMethodCallStack = ArrayCreate(_:__class_MethodCallStackItem);
  __class_bInitialized = true;

  #if defined _datapack_included
    __class_dpParams = CreateDataPack();
  #endif
}

stock _cellclass_CompareParamTypes(const &Array:irgParams, const &Array:irgOtherParams) {
  new iSize = ArraySize(irgParams);
  new iOtherSize = ArraySize(irgOtherParams);

  if (iSize != iOtherSize) return false;

  for (new i = 0; i < iSize; ++i) {
    if (ArrayGetCell(irgParams, i) != ArrayGetCell(irgOtherParams, i)) return false;
  }

  return true;
}

stock __class_ExecuteMethod(const &Struct:sMethod, ClassInstance:pInstance, const DataPack:dpParams) {
  new iResult = 0;

  static Class:class; class = StructGetCell(sMethod, __class_MethodData_Class);

  __class_PushMethodToCallStack(sMethod, pInstance, class);

  if (callfunc_begin_i(StructGetCell(sMethod, __class_MethodData_FunctionId), StructGetCell(sMethod, __class_MethodData_PluginId)) == 1) {
    #if defined _datapack_included
      static Array:irgParamTypes; irgParamTypes = StructGetCell(sMethod, __class_MethodData_ParamTypes);

      if (irgParamTypes != Invalid_Array) {
        static iParamsNum; iParamsNum = ArraySize(irgParamTypes);

        for (new iParam = 0; iParam < iParamsNum; ++iParam) {
          static iType; iType = ArrayGetCell(irgParamTypes, iParam, _:__class_MethodParamData_Type);

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
              ReadPackString(dpParams, __class_szBuffer, charsmax(__class_szBuffer));
              callfunc_push_str(__class_szBuffer);
            }
            case CMP_Array: {
              static iLen; iLen = ReadPackArray(dpParams, __class_rgiBuffer);
              callfunc_push_array(__class_rgiBuffer, iLen, false);
            }
            case CMP_FloatArray: {
              static iLen; iLen = ReadPackFloatArray(dpParams, __class_rgflBuffer);
              callfunc_push_array(_:__class_rgflBuffer, iLen, false);
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
    static Trie:itMethods; itMethods = StructGetCell(Struct:class, __class_Data_Methods);

    static Struct:sMethod;
    if (TrieGetCell(itMethods, szMethod, sMethod)) return sMethod;

    sCurrentClass = StructGetCell(Struct:sCurrentClass, __class_Data_Base);
  } while (sCurrentClass != Invalid_Class);

  return Invalid_Struct;
}

stock Array:__class_GetClassHierarchy(const &Class:class) {
  static Array:irgHierarchy; irgHierarchy = StructGetCell(class, __class_Data_Hierarchy);

  if (irgHierarchy == Invalid_Array) {
    irgHierarchy = __class_CreateHierarchyList(class);
    StructSetCell(class, __class_Data_Hierarchy, irgHierarchy);
  }

  return irgHierarchy;
}

stock Array:__class_CreateHierarchyList(const &Class:class) {
  new Array:irgHierarchy = ArrayCreate();

  new Class:sCurrentClass = class;

  do {
    if (sCurrentClass == class) {
      ArrayPushCell(irgHierarchy, sCurrentClass);
    } else {
      ArrayInsertCellBefore(irgHierarchy, 0, sCurrentClass);
    }

    sCurrentClass = StructGetCell(Struct:class, __class_Data_Base);
  } while (sCurrentClass != Invalid_Class);

  return irgHierarchy;
}

stock bool:__class_IsMethodCallStackEmtpy() {
  return !ArraySize(__class_irgMethodCallStack);
}

stock __class_PushMethodToCallStack(const Struct:sMethod, const &ClassInstance:pInstance, const &Class:class) {
  static rgCallStackItem[__class_MethodCallStackItem];
  rgCallStackItem[__class_MethodCallStackItem_Instance] = pInstance;
  rgCallStackItem[__class_MethodCallStackItem_Class] = class;
  rgCallStackItem[__class_MethodCallStackItem_Method] = sMethod;
  
  ArrayPushArray(__class_irgMethodCallStack, rgCallStackItem[__class_MethodCallStackItem:0], sizeof(rgCallStackItem));
}

stock __celstruct_PopMethodFromCallStack() {
  ArrayDeleteItem(__class_irgMethodCallStack, ArraySize(__class_irgMethodCallStack) - 1);
}

stock __class_GetCurrentMethodFromCallStack(rgCallStackItem[__class_MethodCallStackItem]) {
  ArrayGetArray(__class_irgMethodCallStack, ArraySize(__class_irgMethodCallStack) - 1, rgCallStackItem[__class_MethodCallStackItem:0], sizeof(rgCallStackItem));
}

stock __class_PackNativeParams(const &Array:irgParamTypes, iOffset, iArgc) {
  ResetPack(__class_dpParams, true);

  new iParamsNum; iParamsNum = ArraySize(irgParamTypes);
  for (new iMethodParam = 0; iMethodParam < iParamsNum; ++iMethodParam) {
    new iParam; iParam = iOffset + iMethodParam;
    new iType; iType = ArrayGetCell(irgParamTypes, iMethodParam, _:__class_MethodParamData_Type);
    new iSize; iSize = ArrayGetCell(irgParamTypes, iMethodParam, _:__class_MethodParamData_Size);
    new bool:bUseDefault; bUseDefault = iParam > iArgc;

    switch (iType) {
      case CMP_Cell: {
        WritePackCell(__class_dpParams, bUseDefault ? DEFAULT_CELL_VALUE : get_param_byref(iParam));
      }
      case CMP_Float: {
        WritePackFloat(__class_dpParams, bUseDefault ? DEFAULT_FLOAT_VALUE : Float:get_param_byref(iParam));
      }
      case CMP_String: {
        if (bUseDefault) {
          copy(__class_szBuffer, sizeof(__class_szBuffer), DEFAULT_STRING_VALUE);
        } else {
          get_string(iParam, __class_szBuffer, charsmax(__class_szBuffer));
        }

        WritePackString(__class_dpParams, __class_szBuffer);
      }
      case CMP_Array: {
        if (bUseDefault) {
          arrayset(__class_rgiBuffer, DEFAULT_FLOAT_VALUE, iSize);
        } else {
          get_array(iParam, __class_rgiBuffer, iSize);
        }

        WritePackArray(__class_dpParams, __class_rgiBuffer, iSize);
      }
      case CMP_FloatArray: {
        if (bUseDefault) {
          arrayset(__class_rgflBuffer, DEFAULT_FLOAT_VALUE, iSize);
        } else {
          get_array_f(iParam, __class_rgflBuffer, iSize);
        }

        WritePackFloatArray(__class_dpParams, __class_rgflBuffer, iSize);
      }
    }
  }
}

stock Class:__class_GetCallMethodClass(const &ClassInstance:pInstance) {
  if (!__class_IsMethodCallStackEmtpy()) {
      static rgCallStackItem[__class_MethodCallStackItem]; __class_GetCurrentMethodFromCallStack(rgCallStackItem);

      if (rgCallStackItem[__class_MethodCallStackItem_Instance] == pInstance) {
        return rgCallStackItem[__class_MethodCallStackItem_Class];
      }
  }

  return StructGetCell(Struct:pInstance, __class_InstanceData_Class);
}
