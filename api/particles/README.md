# Particles API
This is a Particle System API for a game modification plugin, likely written in Pawn language for the AMX Mod X platform. The API provides functions to register particle effects, create and manipulate particle systems, and work with individual particles.

## Registering new particle effect

To register new particle effect use `ParticleEffect_Register` function.
```cpp
ParticleEffect_Register("my-effect", EMIT_RATE, PARTICLE_LIFETIME, MAX_PARTICLES);
```

## Controling particle effect
To control your effect use hooks. Use `ParticleEffect_RegisterHook` function together with `ParticleEffectHook_` constants to hook events.
```cpp
ParticleEffect_RegisterHook("my-effect", ParticleEffectHook_Particle_Think, "@Effect_Particle_Think");
```

## Spawning the particle effect system
Use `ParticleSystem_Create` function to spawn the system on specific origin.
```cpp
new ParticleSystem:sParticleSystem = ParticleSystem_Create("my-effect", vecOrigin);
```

## Removing the particle effect system
To remove destroy system and free memory use `ParticleSystem_Destroy` function.
```cpp
ParticleSystem_Destroy(sParticleSystem);
```

## Enabling/Disabling the particle effect system
You can use `ParticleSystem_Activate` and `ParticleSystem_Deactivate` methods to enable or disable particle system.
```cpp
ParticleSystem_Activate(sParticleSystem);
ParticleSystem_Deactivate(sParticleSystem);
```


## Simple particle effect
Here is an example of a simple particle effect to demonstrate API functionality.

![Simple Particle Effect](../../images/example-particle-effect.gif)



```cpp
#include <amxmodx>
#include <fakemeta>
#include <xs>

#include <api_particles>

#define EFFECT_PARTICLE_LIFETIME 1.5
#define EFFECT_EMIT_RATE 0.01
#define EFFECT_MAX_PARTICLES floatround(EFFECT_PARTICLE_LIFETIME / EFFECT_EMIT_RATE, floatround_ceil)

// Particle model for the effect
new g_szParticleModel[] = "sprites/animglow01.spr";

public plugin_precache() {
    // Precache the particle model
    precache_model(g_szParticleModel);
    
    // Register the particle effect
    ParticleEffect_Register("colored-circle", EFFECT_EMIT_RATE, EFFECT_PARTICLE_LIFETIME, EFFECT_MAX_PARTICLES);
    
    // Register hooks for the particle effect
    ParticleEffect_RegisterHook("colored-circle", ParticleEffectHook_System_Init, "@Effect_System_Init");
    ParticleEffect_RegisterHook("colored-circle", ParticleEffectHook_Particle_Think, "@Effect_Particle_Think");
    ParticleEffect_RegisterHook("colored-circle", ParticleEffectHook_Particle_EntityInit, "@Effect_Particle_EntityInit");
}

public plugin_init() {
    // Plugin initialization
    register_plugin("[Particle] Colored Circle", "1.0.0", "Hedgehog Fog");
}

// Hook callback for system initialization
@Effect_System_Init(ParticleSystem:this) {
    // Set additional system parameters
    ParticleSystem_SetMember(this, "flRadius", 48.0);
}

// Hook callback for particle thinking
@Effect_Particle_Think(Particle:this) {
    // Get relevant time and system information
    static Float:flGameTime; flGameTime = get_gametime();
    static ParticleSystem:sSystem; sSystem = Particle_GetSystem(this);
    static Float:flCreatedTime; flCreatedTime = Particle_GetCreatedTime(this);
    static Float:flKillTime; flKillTime = Particle_GetKillTime(this);
    static Float:flTimeRatio; flTimeRatio = (flGameTime - flCreatedTime) / (flKillTime - flCreatedTime);

    // Calculate particle velocity in a circular pattern
    static Float:flAngle; flAngle = 2 * M_PI * flTimeRatio
    static Float:flRadius; flRadius = ParticleSystem_GetMember(sSystem, "flRadius");

    static Float:vecVelocity[3];
    vecVelocity[0] = flRadius * floatcos(flAngle);
    vecVelocity[1] = flRadius * floatsin(flAngle);
    vecVelocity[2] = 0.0;

    // Set the calculated velocity to create circular motion
    Particle_SetVelocity(this, vecVelocity);
}

// Hook callback for particle entity initialization
@Effect_Particle_EntityInit(Particle:this, pEntity) {
    // Set up rendering properties for each particle entity
    static iModelIndex; iModelIndex = engfunc(EngFunc_ModelIndex, g_szParticleModel);

    set_pev(pEntity, pev_rendermode, kRenderTransAdd);
    set_pev(pEntity, pev_renderfx, kRenderFxLightMultiplier);
    set_pev(pEntity, pev_scale, 0.065);
    set_pev(pEntity, pev_modelindex, iModelIndex);
    set_pev(pEntity, pev_renderamt, 220.0);
    set_pev(pEntity, pev_framerate, 1.0);

    engfunc(EngFunc_SetModel, pEntity, g_szParticleModel);

    // Randomize color for each particle entity
    static Float:rgflColor[3];
    for (new i = 0; i < 3; ++i) rgflColor[i] = random_float(0.0, 255.0);

    set_pev(pEntity, pev_rendercolor, rgflColor);
}
```
