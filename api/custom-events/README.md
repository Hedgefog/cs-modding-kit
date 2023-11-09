# Custom Events API
The Custom Events API provides a flexible event pattern implementation that allows you to emit and subscribe to events using string keys. With this API, there is no need to explicitly register events. You can simply emit and subscribe to events on the fly.

## Emitting an Event
To emit an event, call the CustomEvent_Emit function and pass the event key as a parameter.

```cpp
CustomEvent_Emit("my-event");
```

## Subscribing to an Event
To subscribe to a specific event, use the CustomEvent_Subscribe function. Provide the event key and the callback function as parameters.

Subscribe to an event:

```cpp
CustomEvent_Subscribe("my-event", "EventSubscriber_MyEvent");
```

Event subscriber function:

```cpp
public EventSubscriber_MyEvent() {
    log_amx("Subscriber");
}
```

## Registering an Event with Parameters
You can register an event with parameters using the `CustomEvent_Register` function. Provide the event key, parameter types, and the number of parameters.

```cpp
CustomEvent_Register("my-event", EP_Cell, EP_Float, EP_Array, 3, EP_FloatArray, 3, EP_String, EP_Cell);
```

There are two ways to obtain event parameters.

Using arguments in the subscriber function:
```cpp
public EventSubscriber_MyEvent(iCell, Float:flFloat, const rgiArray[3], const Float:rgflArray[3], const szString[]) {
    log_amx("Subscriber");

    log_amx("iCell: %d", iCell);
    log_amx("flFloat: %f", flFloat);
    log_amx("rgiArray: {%d, %d, %d}", rgiArray[0], rgiArray[1], rgiArray[2]);
    log_amx("rgflArray: {%f, %f, %f}", rgflArray[0], rgflArray[1], rgflArray[2]);
    log_amx("szString: %s", szString);
}
```

Using getter functions in the subscriber function:

```cpp
public EventSubscriber_MyEvent() {
    log_amx("Subscriber");

    new iCell = CustomEvent_GetParam(1);
    new Float:flFloat = CustomEvent_GetParamFloat(2);
    new rgiArray[3]; CustomEvent_GetParamArray(3, rgiArray, sizeof(rgiArray));
    new Float:rgflArray[3]; CustomEvent_GetParamFloatArray(4, rgflArray, sizeof(rgflArray));
    new szString[128]; CustomEvent_GetParamString(5, szString, charsmax(szString));
    
    log_amx("iCell: %d", iCell);
    log_amx("flFloat: %f", flFloat);
    log_amx("rgiArray: {%d, %d, %d}", rgiArray[0], rgiArray[1], rgiArray[2]);
    log_amx("rgflArray: {%f, %f, %f}", rgflArray[0], rgflArray[1], rgflArray[2]);
    log_amx("szString: %s", szString);
}
```

## Using a Global Forward to Handle Events
You can use a forward declaration to handle all emitted events. Define a public CustomEvent_Fw_Emit function in your plugin.

```cpp
public CustomEvent_Fw_Emit(const szEvent[]) {
    log_amx("Event Forward %s", szEvent);

    if (equal(szEvent, "my-event")) {
      new iCell = CustomEvent_GetParam(1);
      new Float:flFloat = CustomEvent_GetParamFloat(2);
      new rgiArray[3]; CustomEvent_GetParamArray(3, rgiArray, sizeof(rgiArray));
      new Float:rgflArray[3]; CustomEvent_GetParamFloatArray(4, rgflArray, sizeof(rgflArray));
      new szString[128]; CustomEvent_GetParamString(5, szString, charsmax(szString));
      
      log_amx("iCell: %d", iCell);
      log_amx("flFloat: %f", flFloat);
      log_amx("rgiArray: {%d, %d, %d}", rgiArray[0], rgiArray[1], rgiArray[2]);
      log_amx("rgflArray: {%f, %f, %f}", rgflArray[0], rgflArray[1], rgflArray[2]);
      log_amx("szString: %s", szString);
    }
}

To block the event emit, return `PLUGIN_HANDLED` from the forward function. It will stop subscribers from being called.

```cpp
public CustomEvent_Fw_Emit(const szEvent[]) {
    if (equal(szEvent, "authorize")) {
        new szUsername[128]; CustomEvent_GetParamString(1, szUsername, charsmax(szUsername));
        new szPassword[128]; CustomEvent_GetParamString(2, szPassword, charsmax(szPassword));

        if (!equal(szUsername, "admin") || !equal(szPassword, "admin")) {
          return PLUGIN_HANDLED;
        }

        return PLUGIN_CONTINUE;
    }

    return PLUGIN_CONTINUE;
}
```

# Using activator entity
Custom events support the activator entity. It is useful if you need to emit the event from a specific entity and want to handle the activator in the forward or subscriber function.

```cpp
public plugin_init() {
    register_plugin(PLUGIN, VERSION, AUTHOR);

    register_clcmd("boo", "Command_Boo");
}

public Command_Boo(pPlayer) {
    CustomEvent_SetActivator(pPlayer);
    CustomEvent_Emit("boo-event");
}

public CustomEvent_Fw_Emit(const szEvent[]) {
    if (equal(szEvent, "boo-event")) {
        new pActivator = CustomEvent_GetActivator();
        client_print(pActivator, print_center, "Boo!");
    }
}
```
