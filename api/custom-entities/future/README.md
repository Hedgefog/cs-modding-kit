# Custom Entities API

The Custom Entities API provides a flexible framework for managing and creating custom entities. This API allows developers to register, spawn, manipulate, and interact with custom entities, defining their behavior through hooks and methods.

## Implementing a Custom Entity

### 📚 Registering a New Entity Class

To implement a custom entity, the first thing you need to do is register a new entity class using the `CE_RegisterClass` native function. This can be done in the `plugin_precache` function, allowing you to place your entities directly on the map using the registered class as the `classname`.

Let's create a `key` item entity:

```cpp
#include <amxmodx>
#include <fakemeta>
#include <api_custom_entities>

public plugin_precache() {
    CE_RegisterClass("item_key", CEPreset_Item);
}
```

In this example, the `CEPreset_Item` preset class is used to implement the item. It inherits logic for items such as pickup methods.

### ⚙️ Setting Entity Members

The entity currently lacks a model and size, so let's provide them by implementing the `Allocate` method for the entity to supply all the necessary members:

```cpp
public plugin_precache() {
    // Precaching key model
    precache_model("models/w_security.mdl");

    CE_RegisterClass("item_key", CEPreset_Item);
    
    CE_ImplementClassMethod("item_key", CEMethod_Allocate, "@KeyItem_Allocate");
}

@KeyItem_Allocate(const this) {
    CE_CallBaseMethod(); // Calling the base Allocate method

    CE_SetMemberString(this, CE_MEMBER_MODEL, "models/w_security.mdl");
    CE_SetMemberVec(this, CE_MEMBER_MINS, Float:{-8.0, -8.0, 0.0}); 
    CE_SetMemberVec(this, CE_MEMBER_MAXS, Float:{8.0, 8.0, 8.0});
}
```

In the implementation of the `Allocate` method, the `CE_CallBaseMethod()` call allows us to invoke the base `Allocate` method of the `CEPreset_Item` preset class, allowing it to handle its own allocation logic before executing custom logic. Make sure to include this call in every implemented or overridden method unless you need to fully rewrite the implementation.

> **Caution:** The `Allocate` method is called during entity initialization. Modifying entity variables or invoking engine functions on the entity within this method may lead to unexpected results. Use this method only for initializing custom entity members!

> **Caution:** When calling `CE_CallBaseMethod`, you need to pass all method arguments to ensure the base method receives the necessary context for its operations.

Natives like `CE_SetMemberString` and `CE_SetMemberVec` are used to set members/properties for the entity instance. Constants such as `CE_MEMBER_*` are used to specify the property names that will set the model each time the entity is spawned or its variables are reset. For example, `CE_MEMBER_MODEL` sets `pev->model` of the entity every respawn. Similarly, `CE_MEMBER_MINS` and `CE_MEMBER_MAXS` specify the entity's bounding box.

### 💡 Writing Logic for the Entity

Our `item_key` entity is functional, allowing you to place the entity with the classname `item_key` on your map. It will spawn in the game and can be picked up.

However, we still need to add some logic to the entity, as it currently does not perform any specific actions. Let's implement the `Pickup` and `CanPickup` methods in the same way we implemented `Allocate`:

```cpp
new g_rgbPlayerHasKey[MAX_PLAYERS + 1];

public plugin_precache() {
    CE_RegisterClass("item_key", CEPreset_Item);
    
    CE_ImplementClassMethod("item_key", CEMethod_Allocate, "@KeyItem_Allocate");
    CE_ImplementClassMethod("item_key", CEMethod_CanPickup, "@KeyItem_CanPickup");
    CE_ImplementClassMethod("item_key", CEMethod_Pickup, "@KeyItem_Pickup");
}

@KeyItem_Allocate(const this) { ... }

@KeyItem_CanPickup(const this, const pPlayer) {
    // Base implementation returns false if the item is not on the ground
    if (!CE_CallBaseMethod(pPlayer)) return false;

    // Can't pick up if already holding a key
    if (g_rgbPlayerHasKey[pPlayer]) return false;

    return true;
}

@KeyItem_Pickup(const this, const pPlayer) {
    CE_CallBaseMethod(pPlayer);

    client_print(pPlayer, print_center, "You have found a key!");

    g_rgbPlayerHasKey[pPlayer] = true;
}
```

This simple implementation will display the text `"You have found a key!"` to the player who picks up the key and mark that the player has picked up a key.

### 🧩 Custom Members

If you want to implement different key types, you can use custom members. Let's update our logic and improve the code:

```cpp
#include <amxmodx>
#include <fakemeta>

#include <api_custom_entities>

#define ENTITY_CLASSNAME "item_key"

#define m_iType "iType"

enum KeyType {
    KeyType_Red = 0,
    KeyType_Yellow,
    KeyType_Green,
    KeyType_Blue
};

new const KEY_NAMES[KeyType][] = { "red", "yellow", "green", "blue" };

new const Float:KEY_COLORS_F[KeyType][3] = {
    {255.0, 0.0, 0.0},
    {255.0, 255.0, 0.0},
    {0.0, 255.0, 0.0},
    {0.0, 0.0, 255.0},
};

new const g_szModel[] = "models/w_security.mdl";

new bool:g_rgbPlayerHasKey[MAX_PLAYERS + 1][KeyType];

public plugin_precache() {
    precache_model(g_szModel);

    CE_RegisterClass(ENTITY_CLASSNAME, CEPreset_Item);
    
    CE_ImplementClassMethod(ENTITY_CLASSNAME, CEMethod_Allocate, "@KeyItem_Allocate");
    CE_ImplementClassMethod(ENTITY_CLASSNAME, CEMethod_Spawn, "@KeyItem_Spawn");
    CE_ImplementClassMethod(ENTITY_CLASSNAME, CEMethod_CanPickup, "@KeyItem_CanPickup");
    CE_ImplementClassMethod(ENTITY_CLASSNAME, CEMethod_Pickup, "@KeyItem_Pickup");

    // Bind the "type" entity key to the "m_iType" entity member
    CE_RegisterClassKeyMemberBinding(ENTITY_CLASSNAME, "type", m_iType, CEMemberType_Cell);
}

@KeyItem_Allocate(const this) {
    CE_CallBaseMethod();

    CE_SetMemberString(this, CE_MEMBER_MODEL, g_szModel);
    CE_SetMemberVec(this, CE_MEMBER_MINS, Float:{-8.0, -8.0, 0.0}); 
    CE_SetMemberVec(this, CE_MEMBER_MAXS, Float:{8.0, 8.0, 8.0});

    CE_SetMember(this, m_iType, KeyType_Red); // Default key type
}

@KeyItem_Spawn(const this) {
    CE_CallBaseMethod();

    new KeyType:iType = CE_GetMember(this, m_iType);

    // Adding rendering effect based on key type
    set_pev(this, pev_renderfx, kRenderFxGlowShell);
    set_pev(this, pev_renderamt, 1.0);
    set_pev(this, pev_rendercolor, KEY_COLORS_F[iType]);
}

@KeyItem_CanPickup(const this, const pPlayer) {
    if (!CE_CallBaseMethod(pPlayer)) return false;

    new KeyType:iType = CE_GetMember(this, m_iType);

    if (g_rgbPlayerHasKey[pPlayer][iType]) return false;

    return true;
}

@KeyItem_Pickup(const this, const pPlayer) {
    CE_CallBaseMethod(pPlayer);

    new KeyType:iType = CE_GetMember(this, m_iType);

    client_print(pPlayer, print_center, "You have found a %s key!", KEY_NAMES[iType]);

    g_rgbPlayerHasKey[pPlayer][iType] = true;
}
```

Here, we added `KeyType` constants to represent different key types and implemented the `Spawn` method to set rendering effects based on the key type.

You may have noticed the constant `m_iType`, which is a string constant used for the custom member we work with using `CE_GetMember` and `CE_SetMember` natives. We also use `CE_RegisterClassKeyMemberBinding` to bind this member to the entity key `type`, allowing us to change the key type by setting the `type` key-value on the map.

### 🕵️‍♂️ Testing and Debugging

> What if we don't have a map yet to test it? Is there another way to spawn our entity?

Yes, there are a few ways to do it!

#### Spawning an Entity Using the Console

You can spawn an entity using the console command `ce_spawn <classname> [...members]`. The `<classname>` parameter is the `classname` of the registered entity, and `[...members]` are optional parameters to set before spawning. Let's spawn a `"Green"` key:

```cpp
ce_spawn "item_key" "iType" 3
```

### Spawning an Entity with Code

You can also create the entity using the `CE_Create` native function and then call the engine `Spawn` function on it:

```cpp
new pKey = CE_Create("item_key", vecOrigin);

if (pKey != FM_NULLENT) {
    dllfunc(DLLFunc_Spawn, pKey);
}
```