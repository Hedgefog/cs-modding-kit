#pragma semicolon 1

#include <amxmodx>
#include <amxmisc>
#include <engine>
#include <fakemeta>
#include <hamsandwich>
#include <xs>

#include <cellstruct>

#define PLUGIN "[API] Particles"
#define VERSION "1.0.0"
#define AUTHOR "Hedgehog Fog"

#define BIT(%0) (1<<(%0))

#define PARTICLE_CLASSNAME "_particle"

#define UPDATE_RATE 0.01
#define VISIBILITY_UPDATE_RATE 0.25

enum ParticleEffect {
    ParticleEffect_Id[32],
    Float:ParticleEffect_EmitRate,
    Float:ParticleEffect_ParticleLifeTime,
    ParticleEffect_VisibilityDistance,
    ParticleEffect_MaxParticles,
    ParticleEffect_PluginId,
    ParticleEffect_InitFunctionId,
    ParticleEffect_TransformFunctionId
};

enum ParticleSystem {
    Struct:ParticleSystem_Effect,
    bool:ParticleSystem_Active,
    Float:ParticleSystem_Origin[3],
    Float:ParticleSystem_Angles[3],
    ParticleSystem_ParentEntity,
    Float:ParticleSystem_CreatedTime,
    ParticleSystem_VisibilityBits,
    Float:ParticleSystem_KillTime,
    Array:ParticleSystem_Particles,
    Float:ParticleSystem_NextEmit,
    Float:ParticleSystem_NextVisibilityUpdate,
    Float:ParticleSystem_LasOrigin[3],
    Float:ParticleSystem_LastUpdate
};

enum Particle {
    Struct:Particle_System,
    Particle_Entity,
    Float:Particle_CreatedTime,
    Float:Particle_KillTime,
    Float:Particle_LastTransform
};

new g_iszParticleClassName;
new g_pTrace;

new Float:g_flNextSystemsUpdate;

new Array:g_irgSystems;
new Trie:g_tParticleEffects;

public plugin_precache() {
    g_flNextSystemsUpdate = 0.0;
    g_irgSystems = ArrayCreate();
    g_tParticleEffects = TrieCreate();
    g_iszParticleClassName = engfunc(EngFunc_AllocString, "info_target");
    g_pTrace = create_tr2();
}

public plugin_init() {
    register_plugin(PLUGIN, VERSION, AUTHOR);

    register_forward(FM_AddToFullPack, "FMHook_AddToFullPack", 0);
    
    register_concmd("particle_create", "Command_Create", ADMIN_CVAR);
}

public plugin_natives() {
    register_library("api_particles");

    register_native("RegisterParticleEffect", "Native_RegisterParticleEffect");

    register_native("ParticleSystem_Create", "Native_CreateParticleSystem");
    register_native("ParticleSystem_Destroy", "Native_DestroyParticleSystem");
    register_native("ParticleSystem_Activate", "Native_ActivateParticleSystem");
    register_native("ParticleSystem_Deactivate", "Native_DeactivateParticleSystem");
    register_native("ParticleSystem_GetCreatedTime", "Native_GetParticleSystemCreatedTime");
    register_native("ParticleSystem_GetKillTime", "Native_GetParticleSystemKillTime");
    register_native("ParticleSystem_GetLastUpdateTime", "Native_GetParticleSystemLastUpdate");
    register_native("ParticleSystem_GetVisibilityBits", "Native_GetParticleSystemVisibilityBits");
    register_native("ParticleSystem_GetOrigin", "Native_GetParticleSystemOrigin");
    register_native("ParticleSystem_SetOrigin", "Native_SetParticleSystemOrigin");
    register_native("ParticleSystem_GetParentEntity", "Native_GetParticleSystemParentEntity");
    register_native("ParticleSystem_SetParentEntity", "Native_SetParticleSystemParentEntity");
    register_native("ParticleSystem_GetEffect", "Native_GetParticleSystemEffect");
    register_native("ParticleSystem_SetEffect", "Native_SetParticleSystemEffect");

    register_native("Particle_GetEntity", "Native_GetParticleEntity");
    register_native("Particle_GetSystem", "Native_GetParticleSystem");
    register_native("Particle_GetCreatedTime", "Native_GetParticleCreatedTime");
    register_native("Particle_GetKillTime", "Native_GetParticleKillTime");
    register_native("Particle_GetLastTransformTime", "Native_GetParticleLastTransformTime");
}

public plugin_end() {
    static irgSystemsNum; irgSystemsNum = ArraySize(g_irgSystems);
    for (new iSystem = 0; iSystem < irgSystemsNum; ++iSystem) {
        static Struct:sSystem; sSystem = ArrayGetCell(g_irgSystems, iSystem);
        if (sSystem == Invalid_Struct) continue;

        @ParticleSystem_Destroy(sSystem);
    }

    ArrayDestroy(g_irgSystems);
    TrieDestroy(g_tParticleEffects);
    free_tr2(g_pTrace);
}

/*--------------------------------[ Natives ]--------------------------------*/

public Native_RegisterParticleEffect(iPluginId, iArgc) {
    new szName[32]; get_string(1, szName, charsmax(szName));
    new szInitFunction[64]; get_string(2, szInitFunction, charsmax(szInitFunction));
    new szTransformFunction[64]; get_string(3, szTransformFunction, charsmax(szTransformFunction));
    new Float:flEmitRate = get_param_f(4);
    new Float:flParticleLifeTime = get_param_f(5);
    new Float:flVisibilityDistance = get_param_f(6);
    new iMaxParticles = get_param(7);

    if (TrieKeyExists(g_tParticleEffects, szName)) {
        log_error(AMX_ERR_NATIVE, "Particle effect ^"%s^" is already registered.", szName);
        return;
    }

    new iInitFunctionId = get_func_id(szInitFunction, iPluginId);
    new iTransformFunctionId = get_func_id(szTransformFunction, iPluginId);

    new Struct:sEffect = @ParticleEffect_Create(szName, flEmitRate, flParticleLifeTime, flVisibilityDistance, iMaxParticles, iPluginId, iInitFunctionId, iTransformFunctionId);

    TrieSetCell(g_tParticleEffects, szName, sEffect);
}

public Struct:Native_CreateParticleSystem(iPluginId, iArgc) {
    new szName[32]; get_string(1, szName, charsmax(szName));
    new Float:vecOrigin[3]; get_array_f(2, vecOrigin, sizeof(vecOrigin));
    new Float:vecAngles[3]; get_array_f(3, vecAngles, sizeof(vecAngles));
    new pParent; pParent = get_param(4);

    new Struct:sEffect;
    if (!TrieGetCell(g_tParticleEffects, szName, sEffect)) {
        log_error(AMX_ERR_NATIVE, "[Particles] Effect ^"%s^" is not registered!", szName);
        return Invalid_Struct;
    }

    new Struct:sSystem; sSystem = @ParticleSystem_Create(sEffect, vecOrigin, vecAngles, pParent);

    return sSystem;
}

public Native_DestroyParticleSystem(iPluginId, iArgc) {
    static Struct:sSystem; sSystem = Struct:get_param_byref(1);

    StructSetCell(sSystem, ParticleSystem_KillTime, get_gametime());

    set_param_byref(1, _:Invalid_Struct);
}

public Float:Native_ActivateParticleSystem(iPluginId, iArgc) {
    static Struct:sSystem; sSystem = Struct:get_param_byref(1);

    StructSetCell(sSystem, ParticleSystem_Active, true);
}

public Float:Native_DeactivateParticleSystem(iPluginId, iArgc) {
    static Struct:sSystem; sSystem = Struct:get_param_byref(1);

    StructSetCell(sSystem, ParticleSystem_Active, false);
}

public Float:Native_GetParticleSystemCreatedTime(iPluginId, iArgc) {
    static Struct:sSystem; sSystem = Struct:get_param_byref(1);

    return Float:StructGetCell(sSystem, ParticleSystem_CreatedTime);
}

public Float:Native_GetParticleSystemKillTime(iPluginId, iArgc) {
    static Struct:sSystem; sSystem = Struct:get_param_byref(1);

    return Float:StructGetCell(sSystem, ParticleSystem_KillTime);
}

public Native_GetParticleSystemLastUpdate(iPluginId, iArgc) {
    static Struct:sSystem; sSystem = Struct:get_param_byref(1);

    return StructGetCell(sSystem, ParticleSystem_LastUpdate);
}

public Native_GetParticleSystemVisibilityBits(iPluginId, iArgc) {
    static Struct:sSystem; sSystem = Struct:get_param_byref(1);

    return StructGetCell(sSystem, ParticleSystem_VisibilityBits);
}

public Native_GetParticleSystemOrigin(iPluginId, iArgc) {
    static Struct:sSystem; sSystem = Struct:get_param_byref(1);

    static Float:vecOrigin[3]; StructGetArray(sSystem, ParticleSystem_Origin, vecOrigin, 3);

    set_array_f(2, vecOrigin, sizeof(vecOrigin));
}

public Native_SetParticleSystemOrigin(iPluginId, iArgc) {
    static Struct:sSystem; sSystem = Struct:get_param_byref(1);
    static Float:vecOrigin[3]; get_array_f(2, vecOrigin, sizeof(vecOrigin));

    StructSetArray(sSystem, ParticleSystem_Origin, vecOrigin, 3);
}

public Native_GetParticleSystemParentEntity(iPluginId, iArgc) {
    static Struct:sSystem; sSystem = Struct:get_param_byref(1);
    
    return StructGetCell(sSystem, ParticleSystem_ParentEntity);
}

public Native_SetParticleSystemParentEntity(iPluginId, iArgc) {
    static Struct:sSystem; sSystem = Struct:get_param_byref(1);
    static pParent; pParent = get_param(2);

    StructSetCell(sSystem, ParticleSystem_ParentEntity, pParent);
}

public Native_GetParticleSystemEffect(iPluginId, iArgc) {
    static Struct:sSystem; sSystem = Struct:get_param_byref(1);

    static Struct:sEffect; sEffect = StructGetCell(sSystem, ParticleSystem_Effect);

    static szName[32]; StructGetString(sEffect, ParticleEffect_Id, szName, charsmax(szName));

    set_string(2, szName, get_param(3));
}

public Native_SetParticleSystemEffect(iPluginId, iArgc) {
    static Struct:sSystem; sSystem = Struct:get_param_byref(1);
    static szName[32]; get_string(2, szName, charsmax(szName));

    static Struct:sEffect;
    if (!TrieGetCell(g_tParticleEffects, szName, sEffect)) {
        log_error(AMX_ERR_NATIVE, "[Particles] Effect ^"%s^" is not registered!", szName);
        return;
    }

    StructSetCell(sSystem, ParticleSystem_Effect, sEffect);
}

public Struct:Native_GetParticleEntity(iPluginId, iArgc) {
    static Struct:sParticle; sParticle = Struct:get_param_byref(1);

    return StructGetCell(sParticle, Particle_Entity);
}

public Struct:Native_GetParticleSystem(iPluginId, iArgc) {
    static Struct:sParticle; sParticle = Struct:get_param_byref(1);

    return StructGetCell(sParticle, Particle_System);
}

public Float:Native_GetParticleCreatedTime(iPluginId, iArgc) {
    static Struct:sParticle; sParticle = Struct:get_param_byref(1);

    return Float:StructGetCell(sParticle, Particle_CreatedTime);
}

public Float:Native_GetParticleKillTime(iPluginId, iArgc) {
    static Struct:sParticle; sParticle = Struct:get_param_byref(1);

    return Float:StructGetCell(sParticle, Particle_KillTime);
}

public Float:Native_GetParticleLastTransformTime(iPluginId, iArgc) {
    static Struct:sParticle; sParticle = Struct:get_param_byref(1);

    return Float:StructGetCell(sParticle, Particle_LastTransform);
}

/*--------------------------------[ Forwards ]--------------------------------*/

public server_frame() {
    static Float:flGameTime; flGameTime =  get_gametime();

    if (g_flNextSystemsUpdate <= flGameTime) {
        UpdateSystems();
        g_flNextSystemsUpdate = flGameTime + UPDATE_RATE;
    }
}

/*--------------------------------[ Hooks ]--------------------------------*/

public Command_Create(pPlayer, iLevel, iCId) {
    if (!cmd_access(pPlayer, iLevel, iCId, 2)) {
        return PLUGIN_HANDLED;
    }

    static szName[32]; read_argv(1, szName, charsmax(szName));

    if (equal(szName, NULL_STRING)) return PLUGIN_HANDLED;

    static Float:vecOrigin[3]; pev(pPlayer, pev_origin, vecOrigin);
    static Float:vecAngles[3]; pev(pPlayer, pev_angles, vecAngles);

    static Struct:sEffect;
    if (!TrieGetCell(g_tParticleEffects, szName, sEffect)) return PLUGIN_HANDLED;

    static Struct:sSystem; sSystem = @ParticleSystem_Create(sEffect, vecOrigin, vecAngles, 0);
    StructSetCell(sSystem, ParticleSystem_Active, true);

    return PLUGIN_HANDLED;
}

public FMHook_AddToFullPack(es, e, pEntity, pHost, hostflags, player, pSet) {
    if (!pev_valid(pEntity)) return FMRES_IGNORED;

    static szClassName[32]; pev(pEntity, pev_classname, szClassName, charsmax(szClassName));

    if (equal(szClassName, PARTICLE_CLASSNAME)) {
        static Struct:sParticle; sParticle = Struct:pev(pEntity, pev_iuser1);
        static Struct:sSystem; sSystem = StructGetCell(sParticle, Particle_System);
        static iVisibilityBits; iVisibilityBits = StructGetCell(sSystem, ParticleSystem_VisibilityBits);

        if (~iVisibilityBits & BIT(pHost & 31)) return FMRES_SUPERCEDE;

        return FMRES_IGNORED;
    }

    return FMRES_IGNORED;
}

/*--------------------------------[ ParticleEffect Methods ]--------------------------------*/

Struct:@ParticleEffect_Create(const szName[], Float:flEmitRate, Float:flParticleLifeTime, Float:flVisibilityDistance, iMaxParticles, iPluginId, iInitFunctionId, iTransformFunctionId) {
    static Struct:this; this = StructCreate(ParticleEffect);

    StructSetString(this, ParticleEffect_Id, szName);
    StructSetCell(this, ParticleEffect_EmitRate, flEmitRate);
    StructSetCell(this, ParticleEffect_VisibilityDistance, flVisibilityDistance);
    StructSetCell(this, ParticleEffect_ParticleLifeTime, flParticleLifeTime);
    StructSetCell(this, ParticleEffect_MaxParticles, iMaxParticles);
    StructSetCell(this, ParticleEffect_PluginId, iPluginId);
    StructSetCell(this, ParticleEffect_InitFunctionId, iInitFunctionId);
    StructSetCell(this, ParticleEffect_TransformFunctionId, iTransformFunctionId);

    return this;
}

@ParticleEffect_Destroy(&Struct:this) {
    StructDestroy(this);
}

/*--------------------------------[ ParticleSystem Methods ]--------------------------------*/

Struct:@ParticleSystem_Create(const &Struct:sEffect, const Float:vecOrigin[3], const Float:vecAngles[3], pParent) {
    static Struct:this; this = StructCreate(ParticleSystem);

    static iMaxParticles; iMaxParticles = StructGetCell(sEffect, ParticleEffect_MaxParticles);

    static Array:irgParticles; irgParticles = ArrayCreate(iMaxParticles);
    for (new i = 0; i < iMaxParticles; ++i) ArrayPushCell(irgParticles, Invalid_Struct);

    StructSetCell(this, ParticleSystem_Effect, sEffect);
    StructSetArray(this, ParticleSystem_Origin, vecOrigin, 3);
    StructSetArray(this, ParticleSystem_Angles, vecAngles, 3);
    StructSetCell(this, ParticleSystem_ParentEntity, pParent);
    StructSetCell(this, ParticleSystem_Particles, irgParticles);
    StructSetCell(this, ParticleSystem_CreatedTime, get_gametime());
    StructSetCell(this, ParticleSystem_KillTime, 0.0);
    StructSetCell(this, ParticleSystem_Active, false);
    StructSetCell(this, ParticleSystem_NextEmit, 0.0);
    StructSetCell(this, ParticleSystem_NextVisibilityUpdate, 0.0);

    ArrayPushCell(g_irgSystems, this);

    return this;
}

@ParticleSystem_Destroy(&Struct:this) {
    static Array:irgParticles; irgParticles = StructGetCell(this, ParticleSystem_Particles);
    static iParticlesNum; iParticlesNum = ArraySize(irgParticles);

    for (new iParticle = 0; iParticle < iParticlesNum; ++iParticle) {
        static Struct:sParticle; sParticle = ArrayGetCell(irgParticles, iParticle);
        if (sParticle == Invalid_Struct) continue;

        @Particle_Destroy(sParticle);
    }

    ArrayDestroy(irgParticles);
    
    StructDestroy(this);
}

@ParticleSystem_Update(const &Struct:this) {
    static Float:flGameTime; flGameTime = get_gametime();

    static Float:vecOrigin[3]; @ParticleSystem_GetAbsOrigin(this, vecOrigin);
    static Float:vecLastOrigin[3]; StructGetArray(this, ParticleSystem_LasOrigin, vecLastOrigin, sizeof(vecLastOrigin));
    static Float:vecOffset[3]; xs_vec_sub(vecOrigin, vecLastOrigin, vecOffset);
    static Struct:sEffect; sEffect = StructGetCell(this, ParticleSystem_Effect);
    static Array:irgParticles; irgParticles = StructGetCell(this, ParticleSystem_Particles);
    static iVisibilityBits; iVisibilityBits = StructGetCell(this, ParticleSystem_VisibilityBits);
    static bool:bActive; bActive = StructGetCell(this, ParticleSystem_Active);
    static iParticlesNum; iParticlesNum = ArraySize(irgParticles);

    // Emit particles
    if (bActive) {
        static Float:flNextEmit; flNextEmit = StructGetCell(this, ParticleSystem_NextEmit);
        if (flNextEmit <= flGameTime) {
            static Float:flEmitRate; flEmitRate = StructGetCell(sEffect, ParticleEffect_EmitRate);

            if (flEmitRate || !iParticlesNum) @ParticleSystem_Emit(this);

            StructSetCell(this, ParticleSystem_NextEmit, flGameTime + flEmitRate);
        }
    }

    for (new iParticle = 0; iParticle < iParticlesNum; ++iParticle) {
        static Struct:sParticle; sParticle = ArrayGetCell(irgParticles, iParticle);
        if (sParticle == Invalid_Struct) continue;

        // Destroy expired particle and skip (also destroy all particles in case no one see the system or the system is deactivated)
        static Float:flKillTime; flKillTime = StructGetCell(sParticle, Particle_KillTime);
        if (!iVisibilityBits || !bActive || (flKillTime > 0.0 && flKillTime <= flGameTime)) {
            ArraySetCell(irgParticles, iParticle, Invalid_Struct);
            @Particle_Destroy(sParticle);
            continue;
        }

        // Make particle follow the parent entity
        static pParent; pParent = StructGetCell(this, ParticleSystem_ParentEntity);
        if (pParent > 0) {
            static pEntity; pEntity = StructGetCell(sParticle, Particle_Entity);
            static Float:vecParticleOrigin[3]; pev(pEntity, pev_origin, vecParticleOrigin);
            xs_vec_add(vecParticleOrigin, vecOffset, vecParticleOrigin);
            set_pev(pEntity, pev_origin, vecParticleOrigin);
        }

        static iPluginId; iPluginId = StructGetCell(sEffect, ParticleEffect_PluginId);
        static iFunctionId; iFunctionId = StructGetCell(sEffect, ParticleEffect_TransformFunctionId);
        if (iPluginId != -1 && iFunctionId != -1) {
            @Particle_CallTransformFunction(sParticle, iPluginId, iFunctionId);
        }

        StructSetCell(sParticle, Particle_LastTransform, flGameTime);
    }

    StructSetCell(this, ParticleSystem_LastUpdate, flGameTime);
    StructSetArray(this, ParticleSystem_LasOrigin, vecOrigin, 3);
}

@ParticleSystem_Emit(const &Struct:this) {
    static iVisibilityBits; iVisibilityBits = StructGetCell(this, ParticleSystem_VisibilityBits);
    if (!iVisibilityBits) return;

    static Float:flGameTime; flGameTime = get_gametime();
    static Struct:sEffect; sEffect = StructGetCell(this, ParticleSystem_Effect);

    static Struct:sParticle; sParticle = @Particle_Create(this);

    static Float:flLifeTime; flLifeTime = StructGetCell(sEffect, ParticleEffect_ParticleLifeTime);
    if (flLifeTime > 0.0) {
        StructSetCell(sParticle, Particle_KillTime, flGameTime + flLifeTime);
    }

    @ParticleSystem_AddParticle(this, sParticle);

    static iPluginId; iPluginId = StructGetCell(sEffect, ParticleEffect_PluginId);
    static iFunctionId; iFunctionId = StructGetCell(sEffect, ParticleEffect_InitFunctionId);
    if (iPluginId != -1 && iFunctionId != -1) {
        @Particle_CallInitFunction(sParticle, iPluginId, iFunctionId);
    }

    static Float:flEmitRate; flEmitRate = StructGetCell(sEffect, ParticleEffect_EmitRate);
    StructSetCell(this, ParticleSystem_NextEmit, flGameTime + flEmitRate);
}

@ParticleSystem_AddParticle(const &Struct:this, const &Struct:sNewParticle) {
    static Array:irgParticles; irgParticles = StructGetCell(this, ParticleSystem_Particles);
    static iParticlesNum; iParticlesNum = ArraySize(irgParticles);

    static iIndex; iIndex = -1;
    static Struct:sOldParticle; sOldParticle = Invalid_Struct;

    for (new iParticle = 0; iParticle < iParticlesNum; ++iParticle) {
        static Struct:sParticle; sParticle = ArrayGetCell(irgParticles, iParticle);
        if (sParticle == Invalid_Struct) {
            ArraySetCell(irgParticles, iParticle, sNewParticle);
            return;
        }

        static Float:flKillTime; flKillTime = StructGetCell(sParticle, Particle_KillTime);
        if (iIndex == -1 || flKillTime < StructGetCell(sOldParticle, Particle_KillTime)) {
            iIndex = iParticle;
            sOldParticle = sParticle;
        }
    }

    @Particle_Destroy(sOldParticle);
    ArraySetCell(irgParticles, iIndex, sNewParticle);
}

@ParticleSystem_GetAbsOrigin(const &Struct:this, Float:vecOrigin[3]) {
    static pParent; pParent = StructGetCell(this, ParticleSystem_ParentEntity);
    if (pParent > 0) {
        pev(pParent, pev_origin, vecOrigin);

        for (new i = 0; i < 3; ++i) {
            vecOrigin[i] += Float:StructGetCell(this, ParticleSystem_Origin, i);
        }
    } else {
        StructGetArray(this, ParticleSystem_Origin, vecOrigin, 3);
    }
}

@ParticleSystem_SetAbsOrigin(const &Struct:this, const Float:vecOrigin[3]) {
    static Float:vecAbsOrigin[3];

    static pParent; pParent = StructGetCell(this, ParticleSystem_ParentEntity);
    if (pParent > 0) {
        pev(pParent, pev_origin, vecAbsOrigin);
        xs_vec_sub(vecOrigin, vecAbsOrigin, vecAbsOrigin);
    } else {
        xs_vec_copy(vecOrigin, vecAbsOrigin);
    }

    StructSetArray(this, ParticleSystem_Origin, vecAbsOrigin, 3);
}

@ParticleSystem_UpdateVisibilityBits(const &Struct:this) {
    static Struct:sEffect; sEffect = StructGetCell(this, ParticleSystem_Effect);

    static Float:flVisibleDistance; flVisibleDistance = StructGetCell(sEffect, ParticleEffect_VisibilityDistance);
    static Float:vecOrigin[3]; @ParticleSystem_GetAbsOrigin(this, vecOrigin);

    new iVisibilityBits = 0;
    for (new pPlayer = 1; pPlayer <= MaxClients; ++pPlayer) {
        if (!is_user_connected(pPlayer)) continue;

        static Float:vecPlayerOrigin[3]; ExecuteHamB(Ham_EyePosition, pPlayer, vecPlayerOrigin);
        static Float:flDistance; flDistance = get_distance_f(vecOrigin, vecPlayerOrigin);

        if (flDistance > 32.0 && !is_in_viewcone(pPlayer, vecOrigin, 1)) continue;
        if (flDistance > flVisibleDistance) continue;

        engfunc(EngFunc_TraceLine, vecPlayerOrigin, vecOrigin, IGNORE_MONSTERS, pPlayer, g_pTrace);

        static Float:flFraction; get_tr2(g_pTrace, TR_flFraction, flFraction);
        if (flFraction == 1.0) {
            iVisibilityBits |= BIT(pPlayer & 31);
        }
    }

    StructSetCell(this, ParticleSystem_VisibilityBits, iVisibilityBits);
}

/*--------------------------------[ Particle Methods ]--------------------------------*/

Struct:@Particle_Create(const &Struct:sSystem) {
    static Struct:this; this = StructCreate(Particle);

    static Float:vecOrigin[3]; @ParticleSystem_GetAbsOrigin(sSystem, vecOrigin);
    static Float:vecAngles[3]; StructGetArray(sSystem, ParticleSystem_Angles, vecAngles, sizeof(vecAngles));

    static pParticle; pParticle = CreateParticleEnity(vecOrigin, vecAngles);
    set_pev(pParticle, pev_iuser1, this);

    StructSetCell(this, Particle_System, sSystem);
    StructSetCell(this, Particle_Entity, pParticle);
    StructSetCell(this, Particle_CreatedTime, get_gametime());
    StructSetCell(this, Particle_KillTime, 0.0);

    return this;
}

CreateParticleEnity(const Float:vecOrigin[3], const Float:vecAngles[3]) {
    static pEntity; pEntity = engfunc(EngFunc_CreateNamedEntity, g_iszParticleClassName);
    dllfunc(DLLFunc_Spawn, pEntity);

    set_pev(pEntity, pev_classname, PARTICLE_CLASSNAME);
    set_pev(pEntity, pev_solid, SOLID_NOT);
    set_pev(pEntity, pev_movetype, MOVETYPE_NOCLIP);
    set_pev(pEntity, pev_angles, vecAngles);

    engfunc(EngFunc_SetOrigin, pEntity, vecOrigin);

    return pEntity;
}

@Particle_Destroy(&Struct:this) {
    static pParticle; pParticle = StructGetCell(this, Particle_Entity);
    engfunc(EngFunc_RemoveEntity, pParticle);

    StructDestroy(this);
}

@Particle_CallInitFunction(const &Struct:this, iPluginId, iFunctionId) {
    callfunc_begin_i(iFunctionId, iPluginId);
    callfunc_push_int(_:this);
    callfunc_end();
}

@Particle_CallTransformFunction(const &Struct:this, iPluginId, iFunctionId) {
    callfunc_begin_i(iFunctionId, iPluginId);
    callfunc_push_int(_:this);
    callfunc_end();
}

/*--------------------------------[ Functions ]--------------------------------*/

UpdateSystems() {
    static Float:flGameTime; flGameTime = get_gametime();
    static irgSystemsNum; irgSystemsNum = ArraySize(g_irgSystems);

    for (new iSystem = 0; iSystem < irgSystemsNum; ++iSystem) {
        static Struct:sSystem; sSystem = ArrayGetCell(g_irgSystems, iSystem);
        if (sSystem == Invalid_Struct) continue;

        // Destroy expired system and skip
        static Float:flKillTime; flKillTime = StructGetCell(sSystem, ParticleSystem_KillTime);
        if (flKillTime && flKillTime <= flGameTime) {
            ArraySetCell(g_irgSystems, iSystem, Invalid_Struct);
            @ParticleSystem_Destroy(sSystem);
            continue;
        }

        @ParticleSystem_Update(sSystem);

        static Float:flNextVisibilityUpdate;  flNextVisibilityUpdate = StructGetCell(sSystem, ParticleSystem_NextVisibilityUpdate);
        if (flNextVisibilityUpdate <= flGameTime) {
            @ParticleSystem_UpdateVisibilityBits(sSystem);
            StructSetCell(sSystem, ParticleSystem_NextVisibilityUpdate, flGameTime + VISIBILITY_UPDATE_RATE);
        }
    }

    UTIL_ArrayFindAndDelete(g_irgSystems, Invalid_Struct);
}

/*--------------------------------[ Stocks ]--------------------------------*/

stock UTIL_ArrayFindAndDelete(const &Array:irgArray, any:iValue) {
    static iSize; iSize = ArraySize(irgArray);

    for (new i = 0; i < iSize; ++i) {
        if (ArrayGetCell(irgArray, i) == iValue) {
            ArrayDeleteItem(irgArray, i);
            i--;
            iSize--;
        }
    }
}
