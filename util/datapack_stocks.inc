#if defined _datapack_stocks_included
  #endinput
#endif
#define _datapack_stocks_included

#if !defined _datapack_included
  #tryinclude <datapack>
#endif

#if !defined _datapack_included
  #endinput
#endif

stock ReadPackArray(DataPack:pack, buffer[], maxlen = -1) {
  new len = ReadPackCell(pack);

  if (maxlen == -1) maxlen = len;

  for (new i = 0; i < len; ++i) {
    static value; value = ReadPackCell(pack);
    if (i >= maxlen) continue;
    buffer[i] = value;
  }

  return len;
}

stock ReadPackFloatArray(DataPack:pack, Float:buffer[], maxlen = -1) {
  new len = ReadPackCell(pack);
  
  if (maxlen == -1) maxlen = len;

  for (new i = 0; i < len; ++i) {
    static Float:value; value = ReadPackFloat(pack);
    if (i >= maxlen) continue;
    buffer[i] = value;
  }

  return len;
}

stock WritePackArray(DataPack:pack, const array[], maxlen) {
  WritePackCell(pack, maxlen);

  for (new i = 0; i < maxlen; ++i) {
    WritePackCell(pack, array[i]);
  }
}

stock WritePackFloatArray(DataPack:pack, const Float:array[], maxlen) {
  WritePackCell(pack, maxlen);

  for (new i = 0; i < maxlen; ++i) {
    WritePackFloat(pack, array[i]);
  }
}

stock GetDataPackOffsets(&cellOffset = 0, &floatOffset = 0, &stringOffset = 0, &charOffset = 0, &arrayOffset = 0) {
  new DataPack:pack = CreateDataPack();

  SetPackPosition(pack, DataPackPos:0);
  WritePackCell(pack, DataPackPos:0);
  cellOffset = _:GetPackPosition(pack);

  SetPackPosition(pack, DataPackPos:0);
  WritePackCell(pack, DataPackPos:0);
  floatOffset = _:GetPackPosition(pack);

  SetPackPosition(pack, DataPackPos:0);
  WritePackString(pack, "");
  stringOffset = _:GetPackPosition(pack);

  SetPackPosition(pack, DataPackPos:0);
  WritePackString(pack, "_");
  charOffset = _:GetPackPosition(pack) - stringOffset;

  arrayOffset = cellOffset;

  DestroyDataPack(pack);
}
