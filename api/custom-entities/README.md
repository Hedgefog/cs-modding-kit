# Custom Entities API

The Custom Entities API provides a flexible framework for managing and creating custom entities. This API allows developers to register, spawn, manipulate, and interact with custom entities, defining their behavior through hooks and methods.

## API Functions

### CE_Register

Register a new custom entity.

```pawn
native CE:CE_Register(const szName[], CEPreset:iPreset = CEPreset_None);
```

### CE_RegisterDerived

Extend an existing custom entity.

```pawn
native CE:CE_RegisterDerived(const szName[], const szBase[]);
```

### CE_Create

Spawn a custom entity.

```pawn
native CE_Create(const szName[], const Float:vecOrigin[3] = {0.0, 0.0, 0.0}, bool:bTemp = true);
```

### CE_Restart

Restart a custom entity.

```pawn
native bool:CE_Restart(pEntity);
```

### CE_Kill

Kill a custom entity.

```pawn
native bool:CE_Kill(pEntity, pKiller = 0);
```

### CE_Remove

Remove a custom entity correctly.

```pawn
native bool:CE_Remove(pEntity);
```

### CE_RegisterHook

Register a new hook for a custom entity.

```pawn
native CE_RegisterHook(const szName[], CEFunction:function, const szCallback[]);
```

### CE_RegisterMethod

Register a new method for a custom entity.

```pawn
native CE_RegisterMethod(const szName[], const szMethod[], const szCallback[], any:...);
```

### CE_RegisterVirtualMethod

Register a new virtual method for a custom entity.

```pawn
native CE_RegisterVirtualMethod(const szName[], const szMethod[], const szCallback[], any:...);
```

### CE_GetHandler

Get the handler of an entity by name.

```pawn
native CE:CE_GetHandler(const szName[]);
```

### CE_GetHandlerByEntity

Get the handler of an entity by index.

```pawn
native CE:CE_GetHandlerByEntity(pEntity);
```

### CE_IsInstanceOf

Check if an entity is an instance of a specific custom entity.

```pawn
native bool:CE_IsInstanceOf(pEntity, const szTargetName[]);
```

### CE_HasMember

Check if an entity has a member.

```pawn
native bool:CE_HasMember(pEntity, const szMember[]);
```

### CE_DeleteMember

Delete a member of an entity.

```pawn
native CE_DeleteMember(pEntity, const szMember[]);
```

### CE_GetMember

Get a member of an entity.

```pawn
native any:CE_GetMember(pEntity, const szMember[]);
```

### CE_SetMember

Set a member of an entity.

```pawn
native CE_SetMember(pEntity, const szMember[], any:value);
```

### CE_GetMemberVec

Get a vector member of an entity.

```pawn
native bool:CE_GetMemberVec(pEntity, const szMember[], Float:vecOut[3]);
```

### CE_SetMemberVec

Set a vector member of an entity.

```pawn
native CE_SetMemberVec(pEntity, const szMember[], const Float:vecValue[3]);
```

### CE_GetMemberString

Get a string member of an entity.

```pawn
native bool:CE_GetMemberString(pEntity, const szMember[], szOut[], iLen);
```

### CE_SetMemberString

Set a string member of an entity.

```pawn
native CE_SetMemberString(pEntity, const szMember[], const szValue[]);
```

### CE_CallMethod

Call a method for an entity.

```pawn
native any:CE_CallMethod(pEntity, const szMethod[], any:...);
```

### CE_CallBaseMethod

Call a base method for an entity.

```pawn
native any:CE_CallBaseMethod(any:...);
```


## Constants

### Base Class and Entity Secret

- **CE_BASE_CLASSNAME**: Base classname for custom entities, typically set to "info_target."
- **CE_ENTITY_SECRET**: A constant identifier ('c'+'e'+'2') used internally for entity verification.

### Maximum Lengths

- **CE_MAX_NAME_LENGTH**: Maximum length for the name of an entity.
- **CE_MAX_MEMBER_LENGTH**: Maximum length for a member name.
- **CE_MAX_CALLBACK_LENGTH**: Maximum length for a callback name.
- **CE_MAX_METHOD_NAME_LENGTH**: Maximum length for a method name.

### Entity Members

Defines member names commonly used in entities:

- **CE_MEMBER_ID**: Identifier member.
- **CE_MEMBER_POINTER**: Pointer member.
- **CE_MEMBER_WORLD**: World member.
- **CE_MEMBER_ORIGIN**: Origin member.
- **CE_MEMBER_ANGLES**: Angles member.
- **CE_MEMBER_MASTER**: Master member.
- **CE_MEMBER_MODEL**: Model member.
- **CE_MEMBER_DELAY**: Delay member.
- **CE_MEMBER_NEXTKILL**: Next kill member.
- **CE_MEMBER_NEXTRESPAWN**: Next respawn member.
- **CE_MEMBER_INITIALIZED**: Initialized member.
- **CE_MEMBER_BLOODCOLOR**: Blood color member.
- **CE_MEMBER_LIFETIME**: Lifetime member.
- **CE_MEMBER_IGNOREROUNDS**: Ignore rounds member.
- **CE_MEMBER_RESPAWNTIME**: Respawn time member.
- **CE_MEMBER_MINS**: Mins member.
- **CE_MEMBER_MAXS**: Maxs member.
- **CE_MEMBER_LASTINIT**: Last init member.
- **CE_MEMBER_LASTSPAWN**: Last spawn member.
- **CE_MEMBER_PLUGINID**: Plugin ID member.

### Enums
- **CEPreset**: Available presets for custom entities.
- **CEFunction**: Available functions to hook.
