#pragma semicolon 1

#include <amxmodx>
#include <amxmisc>
#include <fakemeta>
#include <hamsandwich>
#include <xs>

#include <cellstruct>

#include <api_particles_const>

#define PLUGIN "[API] Particles"
#define VERSION "1.0.0"
#define AUTHOR "Hedgehog Fog"

#define BIT(%0) (1<<(%0))

#define PARTICLE_CLASSNAME "_particle"

#define UPDATE_RATE 0.01
#define VISIBILITY_UPDATE_RATE 0.25

enum Callback {
  Callback_PluginId,
  Callback_FunctionId
};

enum PositionVars {
  Float:PositionVars_Origin[3],
  Float:PositionVars_Angles[3],
  Float:PositionVars_Velocity[3]
};

enum ParticleEffect {
  ParticleEffect_Id[32],
  ParticleEffect_EmitAmount,
  Float:ParticleEffect_EmitRate,
  Float:ParticleEffect_ParticleLifeTime,
  ParticleEffect_VisibilityDistance,
  ParticleEffect_MaxParticles,
  ParticleEffectFlag:ParticleEffect_Flags,
  Array:ParticleEffect_Hooks[ParticleEffectHook]
};

enum ParticleSystem {
  Struct:ParticleSystem_Effect,
  bool:ParticleSystem_Active,
  Float:ParticleSystem_EffectSpeed,
  ParticleSystem_ParentEntity,
  Float:ParticleSystem_CreatedTime,
  ParticleSystem_VisibilityBits,
  Float:ParticleSystem_KillTime,
  Array:ParticleSystem_Particles,
  Float:ParticleSystem_NextEmit,
  Float:ParticleSystem_NextVisibilityUpdate,
  Float:ParticleSystem_LastThink,
  Trie:ParticleSystem_Members,
  ParticleSystem_PositionVars[PositionVars]
};

enum Particle {
  Particle_Index,
  Particle_BatchIndex,
  Particle_Entity,
  Float:Particle_CreatedTime,
  Float:Particle_KillTime,
  Float:Particle_LastThink,
  Struct:Particle_System,
  bool:Particle_Attached,
  Particle_PositionVars[PositionVars],
  Particle_AbsPositionVars[PositionVars]
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

  register_native("ParticleEffect_Register", "Native_RegisterParticleEffect");
  register_native("ParticleEffect_RegisterHook", "Native_RegisterParticleEffectHook");

  register_native("ParticleSystem_Create", "Native_CreateParticleSystem");
  register_native("ParticleSystem_Destroy", "Native_DestroyParticleSystem");
  register_native("ParticleSystem_Activate", "Native_ActivateParticleSystem");
  register_native("ParticleSystem_Deactivate", "Native_DeactivateParticleSystem");
  register_native("ParticleSystem_GetEffectSpeed", "Native_GetParticleSystemEffectSpeed");
  register_native("ParticleSystem_SetEffectSpeed", "Native_SetParticleSystemEffectSpeed");
  register_native("ParticleSystem_GetCreatedTime", "Native_GetParticleSystemCreatedTime");
  register_native("ParticleSystem_GetKillTime", "Native_GetParticleSystemKillTime");
  register_native("ParticleSystem_GetLastThinkTime", "Native_GetParticleSystemLastThink");
  register_native("ParticleSystem_GetVisibilityBits", "Native_GetParticleSystemVisibilityBits");
  register_native("ParticleSystem_GetOrigin", "Native_GetParticleSystemOrigin");
  register_native("ParticleSystem_SetOrigin", "Native_SetParticleSystemOrigin");
  register_native("ParticleSystem_GetParentEntity", "Native_GetParticleSystemParentEntity");
  register_native("ParticleSystem_SetParentEntity", "Native_SetParticleSystemParentEntity");
  register_native("ParticleSystem_GetEffect", "Native_GetParticleSystemEffect");
  register_native("ParticleSystem_SetEffect", "Native_SetParticleSystemEffect");
  register_native("ParticleSystem_HasMember", "Native_HasMember");
  register_native("ParticleSystem_DeleteMember", "Native_DeleteMember");
  register_native("ParticleSystem_GetMember", "Native_GetMember");
  register_native("ParticleSystem_SetMember", "Native_SetMember");
  register_native("ParticleSystem_GetMemberVec", "Native_GetMemberVec");
  register_native("ParticleSystem_SetMemberVec", "Native_SetMemberVec");
  register_native("ParticleSystem_GetMemberString", "Native_GetMemberString");
  register_native("ParticleSystem_SetMemberString", "Native_SetMemberString");

  register_native("Particle_GetIndex", "Native_GetParticleIndex");
  register_native("Particle_GetBatchIndex", "Native_GetParticleBatchIndex");
  register_native("Particle_GetEntity", "Native_GetParticleEntity");
  register_native("Particle_GetSystem", "Native_GetParticleSystem");
  register_native("Particle_GetCreatedTime", "Native_GetParticleCreatedTime");
  register_native("Particle_GetKillTime", "Native_GetParticleKillTime");
  register_native("Particle_GetLastThink", "Native_GetParticleLastThink");
  register_native("Particle_GetOrigin", "Native_GetParticleOrigin");
  register_native("Particle_SetOrigin", "Native_SetParticleOrigin");
  register_native("Particle_GetAngles", "Native_GetParticleAngles");
  register_native("Particle_SetAngles", "Native_SetParticleAngles");
  register_native("Particle_GetVelocity", "Native_GetParticleVelocity");
  register_native("Particle_SetVelocity", "Native_SetParticleVelocity");
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
  new Float:flEmitRate = get_param_f(2);
  new Float:flParticleLifeTime = get_param_f(3);
  new iMaxParticles = get_param(4);
  new iEmitAmount = get_param(5);
  new Float:flVisibilityDistance = get_param_f(6);
  new ParticleEffectFlag:iFlags = ParticleEffectFlag:get_param(7);

  if (TrieKeyExists(g_tParticleEffects, szName)) {
    log_error(AMX_ERR_NATIVE, "Particle effect ^"%s^" is already registered.", szName);
    return;
  }

  new Struct:sEffect = @ParticleEffect_Create(szName, flEmitRate, flParticleLifeTime, flVisibilityDistance, iMaxParticles, iEmitAmount, iFlags);

  TrieSetCell(g_tParticleEffects, szName, sEffect);
}
public Native_RegisterParticleEffectHook(iPluginId, iArgc) {
  new szName[32]; get_string(1, szName, charsmax(szName));
  new ParticleEffectHook:iHookId = ParticleEffectHook:get_param(2);
  new szCallback[64]; get_string(3, szCallback, charsmax(szCallback));

  static Struct:sEffect;
  if (!TrieGetCell(g_tParticleEffects, szName, sEffect)) {
    log_error(AMX_ERR_NATIVE, "[Particles] Effect ^"%s^" is not registered!", szName);
    return;
  }

  new Array:irgHooks = StructGetCell(sEffect, ParticleEffect_Hooks, iHookId);

  new rgCallback[Callback];
  rgCallback[Callback_PluginId] = iPluginId;
  rgCallback[Callback_FunctionId] = get_func_id(szCallback, iPluginId);

  if (rgCallback[Callback_FunctionId] == -1) {
    log_error(AMX_ERR_NATIVE, "[Particles] Function ^"%s^" is not found!", szCallback);
    return;
  } 

  ArrayPushArray(irgHooks, rgCallback[any:0], sizeof(rgCallback));
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

public Float:Native_GetParticleSystemEffectSpeed(iPluginId, iArgc) {
  static Struct:sSystem; sSystem = Struct:get_param_byref(1);

  return StructGetCell(sSystem, ParticleSystem_EffectSpeed);
}

public Native_SetParticleSystemEffectSpeed(iPluginId, iArgc) {
  static Struct:sSystem; sSystem = Struct:get_param_byref(1);
  static Float:flSpeed; flSpeed = get_param_f(2);

  StructSetCell(sSystem, ParticleSystem_EffectSpeed, flSpeed);
}

public Float:Native_GetParticleSystemCreatedTime(iPluginId, iArgc) {
  static Struct:sSystem; sSystem = Struct:get_param_byref(1);

  return Float:StructGetCell(sSystem, ParticleSystem_CreatedTime);
}

public Float:Native_GetParticleSystemKillTime(iPluginId, iArgc) {
  static Struct:sSystem; sSystem = Struct:get_param_byref(1);

  return Float:StructGetCell(sSystem, ParticleSystem_KillTime);
}

public Native_GetParticleSystemLastThink(iPluginId, iArgc) {
  static Struct:sSystem; sSystem = Struct:get_param_byref(1);

  return StructGetCell(sSystem, ParticleSystem_LastThink);
}

public Native_GetParticleSystemVisibilityBits(iPluginId, iArgc) {
  static Struct:sSystem; sSystem = Struct:get_param_byref(1);

  return StructGetCell(sSystem, ParticleSystem_VisibilityBits);
}

public Native_GetParticleSystemOrigin(iPluginId, iArgc) {
  static Struct:sSystem; sSystem = Struct:get_param_byref(1);

  static Float:vecOrigin[3]; StructGetArray(sSystem, ParticleSystem_PositionVars, vecOrigin, 3, PositionVars_Origin);

  set_array_f(2, vecOrigin, sizeof(vecOrigin));
}

public Native_SetParticleSystemOrigin(iPluginId, iArgc) {
  static Struct:sSystem; sSystem = Struct:get_param_byref(1);
  static Float:vecOrigin[3]; get_array_f(2, vecOrigin, sizeof(vecOrigin));

  StructSetArray(sSystem, ParticleSystem_PositionVars, vecOrigin, 3, PositionVars_Origin);
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

public bool:Native_HasMember(iPluginId, iArgc) {
  static Struct:sSystem; sSystem = Struct:get_param_byref(1);
  static szMember[PARTICLE_MAX_MEMBER_LENGTH]; get_string(2, szMember, charsmax(szMember));

  static Trie:itMembers; itMembers = StructGetCell(sSystem, ParticleSystem_Members);

  return TrieKeyExists(itMembers, szMember);
}

public Native_DeleteMember(iPluginId, iArgc) {
  static Struct:sSystem; sSystem = Struct:get_param_byref(1);
  static szMember[PARTICLE_MAX_MEMBER_LENGTH]; get_string(2, szMember, charsmax(szMember));

  static Trie:itMembers; itMembers = StructGetCell(sSystem, ParticleSystem_Members);

  TrieDeleteKey(itMembers, szMember);
}

public any:Native_GetMember(iPluginId, iArgc) {
  static Struct:sSystem; sSystem = Struct:get_param_byref(1);
  static szMember[PARTICLE_MAX_MEMBER_LENGTH]; get_string(2, szMember, charsmax(szMember));

  static Trie:itMembers; itMembers = StructGetCell(sSystem, ParticleSystem_Members);

  static iValue;
  if (!TrieGetCell(itMembers, szMember, iValue)) return 0;

  return iValue;
}

public Native_SetMember(iPluginId, iArgc) {
  static Struct:sSystem; sSystem = Struct:get_param_byref(1);
  static szMember[PARTICLE_MAX_MEMBER_LENGTH]; get_string(2, szMember, charsmax(szMember));
  static iValue; iValue = get_param(3);

  static Trie:itMembers; itMembers = StructGetCell(sSystem, ParticleSystem_Members);

  TrieSetCell(itMembers, szMember, iValue);
}

public bool:Native_GetMemberVec(iPluginId, iArgc) {
  static Struct:sSystem; sSystem = Struct:get_param_byref(1);
  static szMember[PARTICLE_MAX_MEMBER_LENGTH]; get_string(2, szMember, charsmax(szMember));

  static Trie:itMembers; itMembers = StructGetCell(sSystem, ParticleSystem_Members);

  static Float:vecValue[3];
  if (!TrieGetArray(itMembers, szMember, vecValue, 3)) return false;

  set_array_f(3, vecValue, sizeof(vecValue));

  return true;
}

public Native_SetMemberVec(iPluginId, iArgc) {
  static Struct:sSystem; sSystem = Struct:get_param_byref(1);
  static szMember[PARTICLE_MAX_MEMBER_LENGTH]; get_string(2, szMember, charsmax(szMember));
  static Float:vecValue[3]; get_array_f(3, vecValue, sizeof(vecValue));

  static Trie:itMembers; itMembers = StructGetCell(sSystem, ParticleSystem_Members);
  TrieSetArray(itMembers, szMember, vecValue, 3);
}

public bool:Native_GetMemberString(iPluginId, iArgc) {
  static Struct:sSystem; sSystem = Struct:get_param_byref(1);
  static szMember[PARTICLE_MAX_MEMBER_LENGTH]; get_string(2, szMember, charsmax(szMember));

  static Trie:itMembers; itMembers = StructGetCell(sSystem, ParticleSystem_Members);

  static szValue[128];
  if (!TrieGetString(itMembers, szMember, szValue, charsmax(szValue))) return false;

  set_string(3, szValue, get_param(4));

  return true;
}

public Native_SetMemberString(iPluginId, iArgc) {
  static Struct:sSystem; sSystem = Struct:get_param_byref(1);
  static szMember[PARTICLE_MAX_MEMBER_LENGTH]; get_string(2, szMember, charsmax(szMember));
  static szValue[128]; get_string(3, szValue, charsmax(szValue));

  static Trie:itMembers; itMembers = StructGetCell(sSystem, ParticleSystem_Members);
  TrieSetString(itMembers, szMember, szValue);
}

public Native_GetParticleOrigin(iPluginId, iArgc) {
  static Struct:sParticle; sParticle = Struct:get_param_byref(1);

  static Float:vecOrigin[3]; StructGetArray(sParticle, Particle_PositionVars, vecOrigin, 3, PositionVars_Origin);

  set_array_f(2, vecOrigin, sizeof(vecOrigin));
}

public Native_SetParticleOrigin(iPluginId, iArgc) {
  static Struct:sParticle; sParticle = Struct:get_param_byref(1);
  static Float:vecOrigin[3]; get_array_f(2, vecOrigin, sizeof(vecOrigin));

  StructSetArray(sParticle, Particle_PositionVars, vecOrigin, 3, PositionVars_Origin);
}

public Native_GetParticleAngles(iPluginId, iArgc) {
  static Struct:sParticle; sParticle = Struct:get_param_byref(1);

  static Float:vecAngles[3]; StructGetArray(sParticle, Particle_PositionVars, vecAngles, 3, PositionVars_Angles);

  set_array_f(2, vecAngles, sizeof(vecAngles));
}

public Native_SetParticleAngles(iPluginId, iArgc) {
  static Struct:sParticle; sParticle = Struct:get_param_byref(1);
  static Float:vecAngles[3]; get_array_f(2, vecAngles, sizeof(vecAngles));

  StructSetArray(sParticle, Particle_PositionVars, vecAngles, 3, PositionVars_Angles);
}

public Native_GetParticleVelocity(iPluginId, iArgc) {
  static Struct:sParticle; sParticle = Struct:get_param_byref(1);

  static Float:vecVelocity[3]; StructGetArray(sParticle, Particle_PositionVars, vecVelocity, 3, PositionVars_Velocity);

  set_array_f(2, vecVelocity, sizeof(vecVelocity));
}

public Native_SetParticleVelocity(iPluginId, iArgc) {
  static Struct:sParticle; sParticle = Struct:get_param_byref(1);

  static Float:vecVelocity[3]; get_array_f(2, vecVelocity, sizeof(vecVelocity));

  StructSetArray(sParticle, Particle_PositionVars, vecVelocity, 3, PositionVars_Velocity);
}

public Struct:Native_GetParticleIndex(iPluginId, iArgc) {
  static Struct:sParticle; sParticle = Struct:get_param_byref(1);

  return StructGetCell(sParticle, Particle_Index);
}

public Struct:Native_GetParticleBatchIndex(iPluginId, iArgc) {
  static Struct:sParticle; sParticle = Struct:get_param_byref(1);

  return StructGetCell(sParticle, Particle_BatchIndex);
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

public Float:Native_GetParticleLastThink(iPluginId, iArgc) {
  static Struct:sParticle; sParticle = Struct:get_param_byref(1);

  return Float:StructGetCell(sParticle, Particle_LastThink);
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

Struct:@ParticleEffect_Create(const szName[], Float:flEmitRate, Float:flParticleLifeTime, Float:flVisibilityDistance, iMaxParticles, iEmitAmount, ParticleEffectFlag:iFlags) {
  static Struct:this; this = StructCreate(ParticleEffect);

  StructSetString(this, ParticleEffect_Id, szName);
  StructSetCell(this, ParticleEffect_EmitRate, flEmitRate);
  StructSetCell(this, ParticleEffect_EmitAmount, iEmitAmount);
  StructSetCell(this, ParticleEffect_VisibilityDistance, flVisibilityDistance);
  StructSetCell(this, ParticleEffect_ParticleLifeTime, flParticleLifeTime);
  StructSetCell(this, ParticleEffect_MaxParticles, iMaxParticles);
  StructSetCell(this, ParticleEffect_Flags, iFlags);

  for (new ParticleEffectHook:iHookId = ParticleEffectHook:0; iHookId < ParticleEffectHook; ++iHookId) {
    StructSetCell(this, ParticleEffect_Hooks, ArrayCreate(_:Callback, 1), iHookId);
  }

  return this;
}

@ParticleEffect_Destroy(&Struct:this) {
  for (new ParticleEffectHook:iHookId = ParticleEffectHook:0; iHookId < ParticleEffectHook; ++iHookId) {
    new Array:irgHooks = StructGetCell(this, ParticleEffect_Hooks, iHookId);
    ArrayDestroy(irgHooks);
  }

  StructDestroy(this);
}

static @ParticleEffect_ExecuteHook(const &Struct:this, ParticleEffectHook:iHook, const &Struct:sInstance, any:...) {
  new iResult = 0;

  new Array:irgHooks = StructGetCell(this, ParticleEffect_Hooks, iHook);

  new iHooksNum = ArraySize(irgHooks);
  for (new iHookId = 0; iHookId < iHooksNum; ++iHookId) {
    new iPluginId = ArrayGetCell(irgHooks, iHookId, _:Callback_PluginId);
    new iFunctionId = ArrayGetCell(irgHooks, iHookId, _:Callback_FunctionId);

    if (callfunc_begin_i(iFunctionId, iPluginId) == 1)  {
      callfunc_push_int(_:sInstance);

      switch (iHook) {
        case ParticleEffectHook_Particle_EntityInit: {
          callfunc_push_int(getarg(3));
        }
      }

      iResult = max(iResult, callfunc_end());
    }
  }


  return iResult;
}

/*--------------------------------[ ParticleSystem Methods ]--------------------------------*/

Struct:@ParticleSystem_Create(const &Struct:sEffect, const Float:vecOrigin[3], const Float:vecAngles[3], pParent) {
  static Struct:this; this = StructCreate(ParticleSystem);

  static iMaxParticles; iMaxParticles = StructGetCell(sEffect, ParticleEffect_MaxParticles);

  static Array:irgParticles; irgParticles = ArrayCreate(iMaxParticles);
  for (new i = 0; i < iMaxParticles; ++i) ArrayPushCell(irgParticles, Invalid_Struct);

  StructSetCell(this, ParticleSystem_Effect, sEffect);
  StructSetArray(this, ParticleSystem_PositionVars, vecOrigin, 3, PositionVars_Origin);
  StructSetArray(this, ParticleSystem_PositionVars, vecAngles, 3, PositionVars_Angles);
  StructSetArray(this, ParticleSystem_PositionVars, Float:{0.0, 0.0, 0.0}, 3, PositionVars_Velocity);
  StructSetCell(this, ParticleSystem_ParentEntity, pParent);
  StructSetCell(this, ParticleSystem_Particles, irgParticles);
  StructSetCell(this, ParticleSystem_CreatedTime, get_gametime());
  StructSetCell(this, ParticleSystem_KillTime, 0.0);
  StructSetCell(this, ParticleSystem_EffectSpeed, 1.0);
  StructSetCell(this, ParticleSystem_Active, false);
  StructSetCell(this, ParticleSystem_NextEmit, 0.0);
  StructSetCell(this, ParticleSystem_NextVisibilityUpdate, 0.0);
  StructSetCell(this, ParticleSystem_Members, TrieCreate());

  ArrayPushCell(g_irgSystems, this);

  @ParticleEffect_ExecuteHook(sEffect, ParticleEffectHook_System_Init, this);

  return this;
}

@ParticleSystem_Destroy(&Struct:this) {
  static Array:irgParticles; irgParticles = StructGetCell(this, ParticleSystem_Particles);
  static iParticlesNum; iParticlesNum = ArraySize(irgParticles);
  static Struct:sEffect; sEffect = StructGetCell(this, ParticleSystem_Effect);
  static Trie:itMembers; itMembers = StructGetCell(this, ParticleSystem_Members);

  @ParticleEffect_ExecuteHook(sEffect, ParticleEffectHook_System_Destroy, this);

  for (new iParticle = 0; iParticle < iParticlesNum; ++iParticle) {
    static Struct:sParticle; sParticle = ArrayGetCell(irgParticles, iParticle);
    if (sParticle == Invalid_Struct) continue;

    @Particle_Destroy(sParticle);
  }

  ArrayDestroy(irgParticles);
  TrieDestroy(itMembers);
  StructDestroy(this);
}

@ParticleSystem_Update(const &Struct:this) {
  static Float:flGameTime; flGameTime = get_gametime();

  static Struct:sEffect; sEffect = StructGetCell(this, ParticleSystem_Effect);
  static Array:irgParticles; irgParticles = StructGetCell(this, ParticleSystem_Particles);
  static iVisibilityBits; iVisibilityBits = StructGetCell(this, ParticleSystem_VisibilityBits);
  static bool:bActive; bActive = StructGetCell(this, ParticleSystem_Active);
  static iParticlesNum; iParticlesNum = ArraySize(irgParticles);
  static Float:flLastThink; flLastThink = StructGetCell(this, ParticleSystem_LastThink);
  static Float:flSpeed; flSpeed = StructGetCell(this, ParticleSystem_EffectSpeed);

  static Float:flDelta; flDelta = flGameTime - flLastThink;

  static Float:vecOrigin[3]; StructGetArray(this, ParticleSystem_PositionVars, vecOrigin, 3, PositionVars_Origin);
  static Float:vecVelocity[3]; StructGetArray(this, ParticleSystem_PositionVars, vecVelocity, 3, PositionVars_Velocity);
  static Float:vecAngles[3]; StructGetArray(this, ParticleSystem_PositionVars, vecAngles, 3, PositionVars_Angles);

  xs_vec_add_scaled(vecOrigin, vecVelocity, flDelta * flSpeed, vecOrigin);
  StructSetArray(this, ParticleSystem_PositionVars, vecOrigin, 3, PositionVars_Origin);

  @ParticleEffect_ExecuteHook(sEffect, ParticleEffectHook_System_Think, this);

  // Emit particles
  if (bActive) {
    static Float:flNextEmit; flNextEmit = StructGetCell(this, ParticleSystem_NextEmit);
    if (flNextEmit <= flGameTime) {
      static Float:flEmitRate; flEmitRate = StructGetCell(sEffect, ParticleEffect_EmitRate);
      static iEmitAmount; iEmitAmount = StructGetCell(sEffect, ParticleEffect_EmitAmount);

      if (flEmitRate || !iParticlesNum) {
        for (new iBatchIndex = 0; iBatchIndex < iEmitAmount; ++iBatchIndex) {
        @ParticleSystem_Emit(this, iBatchIndex);
        }
      }

      StructSetCell(this, ParticleSystem_NextEmit, flGameTime + (flEmitRate / flSpeed));
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
    
    static bool:bAttached; bAttached = StructGetCell(sParticle, Particle_Attached);
    static Float:vecParticleOrigin[3]; StructGetArray(sParticle, Particle_PositionVars, vecParticleOrigin, 3, PositionVars_Origin);
    static Float:vecParticleVelocity[3]; StructGetArray(sParticle, Particle_PositionVars, vecParticleVelocity, 3, PositionVars_Velocity);
    static Float:vecParticleAngles[3]; StructGetArray(sParticle, Particle_PositionVars, vecParticleAngles, 3, PositionVars_Angles);

    xs_vec_add_scaled(vecParticleOrigin, vecParticleVelocity, flDelta * flSpeed, vecParticleOrigin);
    StructSetArray(sParticle, Particle_PositionVars, vecParticleOrigin, 3, PositionVars_Origin);

    @ParticleEffect_ExecuteHook(sEffect, ParticleEffectHook_Particle_Think, sParticle);

    if (bAttached) {
      @ParticleSystem_UpdateParticleAbsPosition(this, sParticle);
    }

    @ParticleSystem_SyncParticleVars(this, sParticle);

    StructSetCell(sParticle, Particle_LastThink, flGameTime);
  }

  StructSetCell(this, ParticleSystem_LastThink, flGameTime);
}

@ParticleSystem_Emit(const &Struct:this, iBatchIndex) {
  static iVisibilityBits; iVisibilityBits = StructGetCell(this, ParticleSystem_VisibilityBits);
  if (!iVisibilityBits) return;

  static Float:flGameTime; flGameTime = get_gametime();
  static Struct:sEffect; sEffect = StructGetCell(this, ParticleSystem_Effect);
  static Float:flSpeed; flSpeed = StructGetCell(this, ParticleSystem_EffectSpeed);
  static ParticleEffectFlag:iEffectFlags; iEffectFlags = StructGetCell(sEffect, ParticleEffect_Flags);

  static Struct:sParticle; sParticle = @Particle_Create(this, !!(iEffectFlags & ParticleEffectFlag_AttachParticles));

  static Float:vecAbsOrigin[3]; @ParticleSystem_GetAbsPositionVar(this, PositionVars_Origin, vecAbsOrigin);
  static Float:vecAbsAngles[3]; @ParticleSystem_GetAbsPositionVar(this, PositionVars_Angles, vecAbsAngles);
  static Float:vecAbsVelocity[3]; @ParticleSystem_GetAbsPositionVar(this, PositionVars_Velocity, vecAbsVelocity);

  StructSetArray(sParticle, Particle_AbsPositionVars, vecAbsOrigin, 3, PositionVars_Origin);
  StructSetArray(sParticle, Particle_AbsPositionVars, vecAbsAngles, 3, PositionVars_Angles);
  StructSetArray(sParticle, Particle_AbsPositionVars, vecAbsVelocity, 3, PositionVars_Velocity);

  StructSetCell(sParticle, Particle_BatchIndex, iBatchIndex);

  static Float:flLifeTime; flLifeTime = StructGetCell(sEffect, ParticleEffect_ParticleLifeTime);
  if (flLifeTime > 0.0) {
    StructSetCell(sParticle, Particle_KillTime, flGameTime + (flLifeTime / flSpeed));
  }

  @ParticleSystem_AddParticle(this, sParticle);

  static Float:flEmitRate; flEmitRate = StructGetCell(sEffect, ParticleEffect_EmitRate);
  StructSetCell(this, ParticleSystem_NextEmit, flGameTime + (flEmitRate * flSpeed));

  @ParticleSystem_SyncParticleVars(this, sParticle);
}

@ParticleSystem_AddParticle(const &Struct:this, const &Struct:sNewParticle) {
  static Array:irgParticles; irgParticles = StructGetCell(this, ParticleSystem_Particles);
  static iParticlesNum; iParticlesNum = ArraySize(irgParticles);

  static iIndex; iIndex = -1;
  static Struct:sOldParticle; sOldParticle = Invalid_Struct;

  for (new iParticle = 0; iParticle < iParticlesNum; ++iParticle) {
    static Struct:sParticle; sParticle = ArrayGetCell(irgParticles, iParticle);
    if (sParticle == Invalid_Struct) {
      sOldParticle = Invalid_Struct;
      iIndex = iParticle;
      break;
    }

    static Float:flKillTime; flKillTime = StructGetCell(sParticle, Particle_KillTime);
    if (iIndex == -1 || flKillTime < StructGetCell(sOldParticle, Particle_KillTime)) {
      iIndex = iParticle;
      sOldParticle = sParticle;
    }
  }

  if (sOldParticle != Invalid_Struct) {
    @Particle_Destroy(sOldParticle);
  }

  ArraySetCell(irgParticles, iIndex, sNewParticle);
  StructSetCell(sNewParticle, Particle_Index, iIndex);
}

@ParticleSystem_GetAbsPositionVar(const &Struct:this, PositionVars:iVariable, Float:vecOut[]) {
  static pParent; pParent = StructGetCell(this, ParticleSystem_ParentEntity);

  if (pParent > 0) {
    pev(pParent, PositionVarsToPevMemberVec(iVariable), vecOut);

    for (new i = 0; i < 3; ++i) {
      vecOut[i] += Float:StructGetCell(this, ParticleSystem_PositionVars, _:iVariable + i);
    }
  } else {
    StructGetArray(this, ParticleSystem_PositionVars, vecOut, 3, iVariable);
  }
}

@ParticleSystem_SetAbsVectorVar(const &Struct:this, PositionVars:iVariable, const Float:vecValue[3]) {
  static Float:vecAbsValue[3];

  static pParent; pParent = StructGetCell(this, ParticleSystem_ParentEntity);
  if (pParent > 0) {
    pev(pParent, PositionVarsToPevMemberVec(iVariable), vecAbsValue);
    xs_vec_sub(vecValue, vecAbsValue, vecAbsValue);
  } else {
    xs_vec_copy(vecValue, vecAbsValue);
  }

  StructSetArray(this, ParticleSystem_PositionVars, vecAbsValue, 3, iVariable);
}

@ParticleSystem_UpdateVisibilityBits(const &Struct:this) {
  static Struct:sEffect; sEffect = StructGetCell(this, ParticleSystem_Effect);

  static Float:flVisibleDistance; flVisibleDistance = StructGetCell(sEffect, ParticleEffect_VisibilityDistance);
  static Float:vecAbsOrigin[3]; @ParticleSystem_GetAbsPositionVar(this, PositionVars_Origin, vecAbsOrigin);

  new iVisibilityBits = 0;
  for (new pPlayer = 1; pPlayer <= MaxClients; ++pPlayer) {
    if (!is_user_connected(pPlayer)) continue;

    static Float:vecPlayerOrigin[3]; ExecuteHamB(Ham_EyePosition, pPlayer, vecPlayerOrigin);
    static Float:flDistance; flDistance = get_distance_f(vecAbsOrigin, vecPlayerOrigin);
    static Float:flFOV; pev(pPlayer, pev_fov, flFOV);

    if (flDistance > 32.0 && !UTIL_IsInViewCone(pPlayer, vecAbsOrigin, flFOV / 2)) continue;
    if (flDistance > flVisibleDistance) continue;

    engfunc(EngFunc_TraceLine, vecPlayerOrigin, vecAbsOrigin, IGNORE_MONSTERS, pPlayer, g_pTrace);

    static Float:flFraction; get_tr2(g_pTrace, TR_flFraction, flFraction);
    if (flFraction == 1.0) {
      iVisibilityBits |= BIT(pPlayer & 31);
    }
  }

  StructSetCell(this, ParticleSystem_VisibilityBits, iVisibilityBits);
}

@ParticleSystem_UpdateParticleAbsPosition(const &Struct:this, const &Struct:sParticle) {
  static Float:vecAbsOrigin[3]; @ParticleSystem_GetAbsPositionVar(this, PositionVars_Origin, vecAbsOrigin);
  static Float:vecAbsAngles[3]; @ParticleSystem_GetAbsPositionVar(this, PositionVars_Angles, vecAbsAngles);
  static Float:vecAbsVelocity[3]; @ParticleSystem_GetAbsPositionVar(this, PositionVars_Velocity, vecAbsVelocity);    

  StructSetArray(sParticle, Particle_AbsPositionVars, vecAbsOrigin, 3, PositionVars_Origin);
  StructSetArray(sParticle, Particle_AbsPositionVars, vecAbsAngles, 3, PositionVars_Angles);
  StructSetArray(sParticle, Particle_AbsPositionVars, vecAbsVelocity, 3, PositionVars_Velocity);
}

@ParticleSystem_SyncParticleVars(const &Struct:this, const &Struct:sParticle) {
  static Float:flSpeed; flSpeed = StructGetCell(this, ParticleSystem_EffectSpeed);

  static pEntity; pEntity = StructGetCell(sParticle, Particle_Entity);
  static bool:bAttached; bAttached = StructGetCell(sParticle, Particle_Attached);

  static Float:vecAbsOrigin[3]; StructGetArray(sParticle, Particle_AbsPositionVars, vecAbsOrigin, 3, PositionVars_Origin);
  static Float:vecAbsAngles[3]; StructGetArray(sParticle, Particle_AbsPositionVars, vecAbsAngles, 3, PositionVars_Angles);
  static Float:vecAbsVelocity[3]; StructGetArray(sParticle, Particle_AbsPositionVars, vecAbsVelocity, 3, PositionVars_Velocity);

  static Float:vecOrigin[3]; StructGetArray(sParticle, Particle_PositionVars, vecOrigin, 3, PositionVars_Origin);
  static Float:vecAngles[3]; StructGetArray(sParticle, Particle_PositionVars, vecAngles, 3, PositionVars_Angles);
  static Float:vecVelocity[3]; StructGetArray(sParticle, Particle_PositionVars, vecVelocity, 3, PositionVars_Velocity);

  if (bAttached) {
    static Float:rgAngleMatrix[3][4]; UTIL_AngleMatrix(vecAbsAngles, rgAngleMatrix);

    UTIL_RotateVectorByMatrix(vecOrigin, rgAngleMatrix, vecOrigin);
    UTIL_RotateVectorByMatrix(vecVelocity, rgAngleMatrix, vecVelocity);
  }

  xs_vec_add(vecAbsOrigin, vecOrigin, vecAbsOrigin);
  xs_vec_add(vecAbsAngles, vecAngles, vecAbsAngles);
  xs_vec_add(vecAbsVelocity, vecVelocity, vecAbsVelocity);

  if (flSpeed != 1.0) {
    xs_vec_mul_scalar(vecVelocity, flSpeed, vecVelocity);
  }

  set_pev(pEntity, pev_angles, vecAbsAngles);
  set_pev(pEntity, pev_origin, vecAbsOrigin);
  set_pev(pEntity, pev_velocity, vecAbsVelocity);
}

/*--------------------------------[ Particle Methods ]--------------------------------*/

Struct:@Particle_Create(const &Struct:sSystem, bool:bAttached) {
  static Struct:this; this = StructCreate(Particle);

  StructSetCell(this, Particle_System, sSystem);
  StructSetCell(this, Particle_Index, -1);
  StructSetCell(this, Particle_BatchIndex, 0);
  StructSetCell(this, Particle_Entity, -1);
  StructSetCell(this, Particle_CreatedTime, get_gametime());
  StructSetCell(this, Particle_LastThink, get_gametime());
  StructSetCell(this, Particle_KillTime, 0.0);
  StructSetCell(this, Particle_Attached, bAttached);

  StructSetArray(this, Particle_PositionVars, Float:{0.0, 0.0, 0.0}, 3, PositionVars_Origin);
  StructSetArray(this, Particle_PositionVars, Float:{0.0, 0.0, 0.0}, 3, PositionVars_Angles);
  StructSetArray(this, Particle_PositionVars, Float:{0.0, 0.0, 0.0}, 3, PositionVars_Velocity);

  static Struct:sSystem; sSystem = StructGetCell(this, Particle_System);
  static Struct:sEffect; sEffect = StructGetCell(sSystem, ParticleSystem_Effect);
  @ParticleEffect_ExecuteHook(sEffect, ParticleEffectHook_Particle_Init, this);

  @Particle_InitEntity(this);

  return this;
}

@Particle_InitEntity(const &Struct:this) {
  static Struct:sSystem; sSystem = StructGetCell(this, Particle_System);
  static Struct:sEffect; sEffect = StructGetCell(sSystem, ParticleSystem_Effect);

  static pParticle; pParticle = CreateParticleEnity(Float:{0.0, 0.0, 0.0}, Float:{0.0, 0.0, 0.0});
  set_pev(pParticle, pev_iuser1, this);

  StructSetCell(this, Particle_Entity, pParticle);

  @ParticleEffect_ExecuteHook(sEffect, ParticleEffectHook_Particle_EntityInit, this, pParticle);
}

@Particle_Destroy(&Struct:this) {
  static Struct:sSystem; sSystem = StructGetCell(this, Particle_System);
  static Struct:sEffect; sEffect = StructGetCell(sSystem, ParticleSystem_Effect);
  @ParticleEffect_ExecuteHook(sEffect, ParticleEffectHook_Particle_Destroy, this);

  static pParticle; pParticle = StructGetCell(this, Particle_Entity);
  engfunc(EngFunc_RemoveEntity, pParticle);

  StructDestroy(this);
}

/*--------------------------------[ Functions ]--------------------------------*/

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

    static Float:flNextVisibilityUpdate; flNextVisibilityUpdate = StructGetCell(sSystem, ParticleSystem_NextVisibilityUpdate);
    if (flNextVisibilityUpdate <= flGameTime) {
      @ParticleSystem_UpdateVisibilityBits(sSystem);
      StructSetCell(sSystem, ParticleSystem_NextVisibilityUpdate, flGameTime + VISIBILITY_UPDATE_RATE);
    }
  }

  UTIL_ArrayFindAndDelete(g_irgSystems, Invalid_Struct);
}

PositionVarsToPevMemberVec(PositionVars:iVariable) {
  switch (iVariable) {
    case PositionVars_Origin: return pev_origin;
    case PositionVars_Angles: return pev_angles;
    case PositionVars_Velocity: return pev_velocity;
  }

  return -1;
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

stock UTIL_RotateVectorByMatrix(const Float:vecValue[3], Float:rgAngleMatrix[3][4], Float:vecOut[3]) {
    static Float:vecTemp[3];

    for (new i = 0; i < 3; ++i) {
    vecTemp[i] = (vecValue[0] * rgAngleMatrix[0][i]) + (vecValue[1] * rgAngleMatrix[1][i]) + (vecValue[2] * rgAngleMatrix[2][i]);
    }

    xs_vec_copy(vecTemp, vecOut);
}

stock UTIL_AngleMatrix(const Float:vecAngles[3], Float:rgMatrix[3][4]) {
  static Float:cp; cp = floatcos(vecAngles[0], degrees);
  static Float:sp; sp = floatsin(vecAngles[0], degrees);
  static Float:cy; cy = floatcos(vecAngles[1], degrees);
  static Float:sy; sy = floatsin(vecAngles[1], degrees);
  static Float:cr; cr = floatcos(-vecAngles[2], degrees);
  static Float:sr; sr = floatsin(-vecAngles[2], degrees);
  static Float:crcy; crcy = cr * cy;
  static Float:crsy; crsy = cr * sy;
  static Float:srcy; srcy = sr * cy;
  static Float:srsy; srsy = sr * sy;

  // matrix = (YAW * PITCH) * ROLL

  rgMatrix[0][0] = cp * cy;
  rgMatrix[1][0] = cp * sy;
  rgMatrix[2][0] = -sp;

  rgMatrix[0][1] = (sp * srcy) + crsy;
  rgMatrix[1][1] = (sp * srsy) - crcy;
  rgMatrix[2][1] = sr * cp;

  rgMatrix[0][2] = (sp * crcy) - srsy;
  rgMatrix[1][2] = (sp * crsy) + srcy;
  rgMatrix[2][2] = cr * cp;

  rgMatrix[0][3] = 0.0;
  rgMatrix[1][3] = 0.0;
  rgMatrix[2][3] = 0.0;
}

stock V_swap(&Float:v1, &Float:v2) {
  static Float:tmp;
  tmp = v1;
  v1 = v2;
  v2 = tmp;
}

stock bool:UTIL_IsInViewCone(pEntity, const Float:vecTarget[3], Float:fMaxAngle) {
    static Float:vecOrigin[3];
    ExecuteHamB(Ham_EyePosition, pEntity, vecOrigin);

    static Float:vecDir[3];
    xs_vec_sub(vecTarget, vecOrigin, vecDir);
    xs_vec_normalize(vecDir, vecDir);

    static Float:vecForward[3];
    pev(pEntity, pev_v_angle, vecForward);
    angle_vector(vecForward, ANGLEVECTOR_FORWARD, vecForward);

    new Float:flAngle = xs_rad2deg(xs_acos((vecDir[0] * vecForward[0]) + (vecDir[1] * vecForward[1]), radian));

    return flAngle < fMaxAngle;
}
