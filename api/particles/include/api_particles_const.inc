#if defined _api_particles_const_included
  #endinput
#endif
#define _api_particles_const_included

#define PARTICLE_MAX_MEMBER_LENGTH 64

enum ParticleEffectHook {
  ParticleEffectHook_System_Init,
  ParticleEffectHook_System_Destroy,
  ParticleEffectHook_System_Think,
  ParticleEffectHook_System_Activated,
  ParticleEffectHook_System_Deactivated,
  ParticleEffectHook_Particle_Init,
  ParticleEffectHook_Particle_Destroy,
  ParticleEffectHook_Particle_Think,
  ParticleEffectHook_Particle_EntityInit
};

enum ParticleEffectFlag (<<=1) {
    ParticleEffectFlag_None = 0,
    ParticleEffectFlag_AttachParticles = 1
};
