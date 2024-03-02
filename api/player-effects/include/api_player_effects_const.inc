#if defined _api_particles_const_included
  #endinput
#endif
#define _api_particles_const_included

#define PARTICLE_MAX_MEMBER_LENGTH 64

enum ParticleHook {
  ParticleHook_System_Init,
  ParticleHook_System_Destroy,
  ParticleHook_System_Think,
  ParticleHook_System_Activated,
  ParticleHook_System_Deactivated,
  ParticleHook_Particle_Init,
  ParticleHook_Particle_Destroy,
  ParticleHook_Particle_Think,
  ParticleHook_Particle_EntityInit
};

enum ParticleEffectFlag (<<=1) {
  ParticleEffectFlag_None = 0,
  ParticleEffectFlag_AttachParticles = 1
};
