#if defined _function_pointer_included
  #endinput
#endif
#define _function_pointer_included

enum Function {
    Invalid_FunctionPointer = -1
};

stock Function:get_func_pointer(const szFunction[], iPluginId = -1) {
    static iFunctionId; iFunctionId = get_func_id(szFunction, iPluginId);

    if (iPluginId == -1) {
        iPluginId = get_plugin(-1);
    }

    if (iPluginId >= 0xFFFF) return Invalid_FunctionPointer;
    if (iFunctionId > 0xFFFF) return Invalid_FunctionPointer;

    return Function:(((iPluginId + 1) << 16) | iFunctionId);
}

stock get_pfunc_function(const &Function:function) {
    return _:function & 0xFFFF;
}

stock get_pfunc_plugin(const &Function:function) {
    return ((_:function >> 16) & 0xFFFF) - 1;
}

stock bool:is_pfunc_local(const &Function:function) {
    return get_pfunc_plugin(function) == -1;
}

stock callfunc_begin_p(const &Function:function) {
    return callfunc_begin_i(get_pfunc_function(function), get_pfunc_plugin(function));
}
