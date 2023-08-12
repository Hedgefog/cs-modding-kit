#if defined _cellstruct_included
	#endinput
#endif

#define _cellstruct_included

#include <json>
#include <cellarray>

enum Struct {
    Invalid_Struct = 0
};

stock Struct:StructCreate(any:interface) {
    new Struct:struct = Struct:ArrayCreate(_, interface);
    ArrayResize(Array:struct, interface);
    return struct;
}

stock Struct:StructFromArray(any:interface, const any:data[any:0]) {
    new Struct:struct = StructCreate(interface);
    StructSetArray(struct, 0, data, interface);
    return struct;
}

stock Struct:StructClone(const &Struct:which) {
    return Struct:ArrayClone(Array:which);
}

stock StructSize(const &Struct:which) {
    return ArraySize(Array:which);
}

stock StructDestroy(&Struct:which) {
    ArrayDestroy(Array:which);
    which = Invalid_Struct;
}

stock any:StructGetCell(const &Struct:which, any:item, any:block = 0, bool:asChar = false) {
    return ArrayGetCell(Array:which, item + block, _, asChar);
}

stock StructSetCell(const &Struct:which, any:item, any:value, any:block = 0, bool:asChar = false) {
    ArraySetCell(Array:which, item + block, value, _, asChar);
}

stock StructGetArray(const &Struct:which, any:item, any:output[any:0], any:size, any:block = 0) {
    for (new i = 0; i < size; ++i) {
        output[i] = StructGetCell(which, item, block + i);
    }
}

stock StructSetArray(const &Struct:which, any:item, const any:input[any:0], any:size, any:block = 0) {
    for (new i = 0; i < size; ++i) {
        StructSetCell(which, item, input[i], block + i);
    }
}

stock StructGetString(const &Struct:which, any:item, output[], any:len, any:block = 0) {
    for (new i = 0; i < len; ++i) {
        output[i] = StructGetCell(which, item, block + i);

        if (output[i] == '^0') {
            break;
        }
    }
}

stock DoNotUse:StructGetStringHandle(const &Struct:which, any:item, any:block = 0) {
    return ArrayGetStringHandle(Array:which, item + block);
}

stock StructSetString(const &Struct:which, any:item, const input[], any:len = -1, any:block = 0) {
    for (new i = 0; i < len || len == -1; ++i) {
        StructSetCell(which, item, input[i], block + i);

        if (input[i] == '^0') {
            break;
        }
    }
}

stock StructStringify(const &Struct:which, output[], len) {
    new size = StructSize(which);
    new JSON:jsonData = json_init_array();

    for (new i = 0; i < size; ++i) {
        json_array_append_number(jsonData, StructGetCell(which, i));
    }

    json_serial_to_string(jsonData, output, len);

    json_free(jsonData);
}

stock Struct:StructFromString(const &Struct:which, const input[]) {
    new JSON:jsonData = json_parse(input);
    new size = json_array_get_count(jsonData);

    new Struct:sStruct = StructCreate(size);

    for (new i = 0; i < size; ++i) {
        StructSetCell(sStruct, i, json_array_get_number(jsonData, i));
    }

    json_free(jsonData);

    return sStruct;
}
