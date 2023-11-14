# Particles API

## Simple particle effect

```cpp

#include <amxmodx>
#include <fakemeta>

#include <api_particles>

new const g_szParticleModel[] = "sprites/muz4.spr";

public plugin_precache() {
    precache_model(g_szParticleModel);

    Particles_RegisterEffect("test", 0.1, 1.0, 10, "@Particle_Init", "@Particle_Transform");
}

public plugin_init() {
    register_plugin("[Particle Effect] Test", "1.0.0", "Hedgehog Fog");
}

public @Particle_Init(Particle:this) {
    // Getting entity from the particle pointer

    static pEntity; pEntity = Particles_Particle_GetEntity(this);

    static iModelIndex; iModelIndex = engfunc(EngFunc_ModelIndex, g_szParticleModel);

    set_pev(pEntity, pev_rendermode, kRenderTransAdd);
    set_pev(pEntity, pev_renderamt, 160.0);
    set_pev(pEntity, pev_scale, 0.2);
    set_pev(pEntity, pev_modelindex, iModelIndex);

    // Random Color
    static Float:rgflColor[3];
    rgflColor[0] = random_float(50.0, 255.0);
    rgflColor[1] = random_float(50.0, 255.0);
    rgflColor[2] = random_float(50.0, 255.0);

    set_pev(pEntity, pev_rendercolor, rgflColor);
}

public @Particle_Transform(Particle:this) {
    // Getting entity from the particle pointer

    static pEntity; pEntity = Particles_Particle_GetEntity(this);

    // Time Ratio Calculation

    static Float:flGameTime; flGameTime = get_gametime();
    static Float:flCreatedTime; flCreatedTime = Particles_Particle_GetCreatedTime(this);
    static Float:flKillTime; flKillTime = Particles_Particle_GetKillTime(this);
    static Float:flTimeRatio; flTimeRatio = (flGameTime - flCreatedTime) / (flKillTime - flCreatedTime);

    // Random Velocity

    static Float:flMinNoise; flMinNoise = 80.0;
    static Float:flMaxNoise; flMaxNoise = flMinNoise + (64.0 * flTimeRatio);

    static Float:vecVelocity[3];
    vecVelocity[0] = random_float(flMinNoise, flMaxNoise) * (random(2) ? -1 : 1);
    vecVelocity[1] = random_float(flMinNoise, flMaxNoise) * (random(2) ? -1 : 1);
    vecVelocity[2] = 32.0;

    set_pev(pEntity, pev_velocity, vecVelocity);

    // Fade Out effect

    static Float:flRenderAmt; flRenderAmt = 160.0;
    if (flTimeRatio <= 0.25) {
        flRenderAmt *= flTimeRatio / 0.25;
    } else if (flTimeRatio > 0.75) {
        flRenderAmt *= (1.0 - flTimeRatio) / 0.25;
    }

    set_pev(pEntity, pev_renderamt, flRenderAmt);
}

```

## Spawning the particle effect

```cpp
new ParticleSystem:g_sParticleSystem;

public SpawnTestParticleEffect() {
    g_sParticleSystem = Particles_ParticleSystem_Create("test", vecOrigin);
    Particles_ParticleSystem_Activate(g_sParticleSystem);
}

public RemoveParticleEffect() {
    Particles_ParticleSystem_Destroy(g_sParticleSystem);
}

```
