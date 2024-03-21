#if defined _api_particles_included
  #endinput
#endif
#define _api_particles_included

#include <api_particles_const>

/**
 * Registers a particle effect.
 *
 * @param szName The name of the effect.
 * @param flEmitRate The rate at which particles are emitted.
 * @param flParticleLifeTime The lifetime of each particle.
 * @param iMaxParticles The maximum number of particles.
 * @param iEmitAmount  The amount of emitted particles.
 * @param flVisibilityDistance Max visible distance.
 * @param iFlags Effect flags.
 *
 * @noreturn
 */
native ParticleEffect_Register(const szName[], Float:flEmitRate = 0.1, Float:flParticleLifeTime = 1.0, iMaxParticles = 10, iEmitAmount = 1, Float:flVisibilityDistance = 1024.0, ParticleEffectFlag:iFlags = ParticleEffectFlag_None);

/**
 * Registers a particle effect hook.
 *
 * @param iHook Hook to handle.
 * @param szName Name of the particle effect.
 * @param szCallback Callback function to be called during particle effects.
 *
 * @noreturn
 */
native ParticleEffect_RegisterHook(const szName[], ParticleEffectHook:iHook, const szCallback[]);

/**
 * Creates a particle system.
 *
 * @param szEffect The name of the effect.
 * @param vecOrigin The origin of the system.
 * @param vecAngles The angles of the system.
 * @param pParent The parent System.
 *
 * @return The particle system structure pointer.
 */
native ParticleSystem:ParticleSystem_Create(const szEffect[], const Float:vecOrigin[3] = {0.0, 0.0, 0.0}, const Float:vecAngles[3] = {0.0, 0.0, 0.0}, pParent = 0);

/**
 * Destroys the particle system.
 *
 * @param sSystem The particle system structure pointer.
 *
 * @noreturn
 */
native ParticleSystem_Destroy(&ParticleSystem:sSystem);

/**
 * Activates the particle system.
 *
 * @param sSystem The particle system structure pointer.
 *
 * @noreturn
 */
native ParticleSystem_Activate(const &ParticleSystem:sSystem);

/**
 * Deactivates the particle system.
 *
 * @param sSystem The particle system structure pointer.
 *
 * @noreturn
 */
native ParticleSystem_Deactivate(const &ParticleSystem:sSystem);

/**
 * Gets particle effect speed.
 *
 * @param sSystem The particle system structure pointer.
 *
 * @return The particle system effect speed.
 */
native Float:ParticleSystem_GetEffectSpeed(const &ParticleSystem:sSystem);

/**
 * Sets particle effect speed.
 *
 * @param sSystem The particle system structure pointer.
 * @param flSpeed The particle system effect speed.
 *
 * @noreturn
 */
native ParticleSystem_SetEffectSpeed(const &ParticleSystem:sSystem, Float:flSpeed);

/**
 * Retrieves the time at which a particle system was created.
 *
 * @param sSystem The particle system structure pointer.
 *
 * @return The creation time of the particle system.
 */
native Float:ParticleSystem_GetCreatedTime(const &ParticleSystem:sSystem);

/**
 * Retrieves the time at which a particle system will killed.
 *
 * @param sSystem The particle system structure pointer.
 *
 * @return The kill time of the particle system.
 */
native Float:ParticleSystem_GetKillTime(const &ParticleSystem:sSystem);

/**
 * Retrieves the last time a particle system was thinked.
 *
 * @param sSystem The particle system structure pointer.
 *
 * @return The last think time of the particle system.
 */
native Float:ParticleSystem_GetLastThink(const &ParticleSystem:sSystem);

/**
 * Retrieves the visibility bits of a particle.
 *
 * @param sSystem The particle system structure pointer.
 *
 * @return The visibility bits of the particle system.
 */
native Float:ParticleSystem_GetVisibilityBits(const &ParticleSystem:sSystem);

/**
 * Retrieves the origin of the particle system.
 *
 * @param sSystem The particle system structure pointer.
 * @param vecOut The vector to set.
 *
 * @noreturn
 */
native ParticleSystem_GetOrigin(const &ParticleSystem:sSystem, const vecOut[]);

/**
 * Sets the origin of the particle system.
 *
 * @param sSystem The particle system structure pointer.
 * @param vecOrigin The origin vector.
 *
 * @noreturn
 */
native ParticleSystem_SetOrigin(const &ParticleSystem:sSystem, const Float:vecOrigin[3]);

/**
 * Retrieves the parent System of the particle system.
 * @param sSystem The particle system structure pointer.
 * @param pParent The parent System.
 *
 * @noreturn
 */
native ParticleSystem_GetParentSystem(const &ParticleSystem:sSystem, pParent);

/**
 * Sets the parent System of the particle system.
 *
 * @param sSystem The particle system structure pointer.
 *
 * @return The parent System.
 */
native ParticleSystem_SetParentSystem(const &ParticleSystem:sSystem);

/**
 * Retrieves the effect name of the particle system.
 *
 * @param sSystem The particle system structure pointer.
 * @param szOut The buffer to copy the value.
 * @param iMaxLen Maximum size of buffer.
 *
 * @noreturn
 */
native ParticleSystem_GetEffect(const &ParticleSystem:sSystem, szOut[], iMaxLen);

/**
 * Sets the effect of the particle system.
 *
 * @param sSystem The particle system structure pointer.
 * @param szName The name of the particle effect.
 *
 * @noreturn
 */
native ParticleSystem_SetEffect(const &ParticleSystem:sSystem, const szName[]);

/**
 * Checks if System has member
 *
 * @param sSystem System index
 * @param szMember Member name
 */
native ParticleSystem_HasMember(const &ParticleSystem:sSystem, const szMember[]);

/**
 * Deletes member of an System
 *
 * @param sSystem System index
 * @param szMember Member name
 */
native ParticleSystem_DeleteMember(const &ParticleSystem:sSystem, const szMember[]);

/**
 * Gets member of an System
 *
 * @param sSystem System index
 * @param szMember Member name
 *
 * @return Member value
 */
native any:ParticleSystem_GetMember(const &ParticleSystem:sSystem, const szMember[]);

/**
 * Sets member of an System
 *
 * @param sSystem System index
 * @param szMember Member name
 * @param value Value to set
 */
native ParticleSystem_SetMember(const &ParticleSystem:sSystem, const szMember[], any:value);

/**
 * Gets vector member of an System
 *
 * @param sSystem System index
 * @param szMember Member name
 * @param vecOut Output vector
 */
native bool:ParticleSystem_GetMemberVec(const &ParticleSystem:sSystem, const szMember[], Float:vecOut[3]);

/**
 * Sets vector member of an System
 *
 * @param sSystem System index
 * @param szMember Member name
 * @param vecValue Vector to set
 */
native ParticleSystem_SetMemberVec(const &ParticleSystem:sSystem, const szMember[], const Float:vecValue[3]);

/**
 * Gets string member of an System
 *
 * @param sSystem System index
 * @param szMember Member name
 * @param szOut Buffer to copy the value
 * @param iLen Maximum size of buffer
 */
native bool:ParticleSystem_GetMemberString(const &ParticleSystem:sSystem, const szMember[], szOut[], iLen);

/**
 * Sets string member of an System
 *
 * @param sSystem System index
 * @param szMember Member name
 * @param szValue String value to set
 */
native ParticleSystem_SetMemberString(const &ParticleSystem:sSystem, const szMember[], const szValue[]);

/**
 * Gets particle index by particle pointer.
 *
 * @param sParticle The particle pointer.
 *
 * @return The index of the particle.
 */
native Particle_GetIndex(const &Particle:sParticle);

/**
 * Gets particle batch index by particle pointer.
 *
 * @param sParticle The particle pointer.
 *
 * @return The batch index of the particle.
 */
native Particle_GetBatchIndex(const &Particle:sParticle);

/**
 * Gets particle entity by particle pointer.
 *
 * @param sParticle The particle pointer.
 *
 * @return The entity of the particle.
 */
native Particle_GetEntity(const &Particle:sParticle);

/**
 * Gets particle system pointer by particle pointer.
 *
 * @param sParticle The particle pointer.
 *
 * @return The particle system pointer.
 */
native ParticleSystem:Particle_GetSystem(const &Particle:sParticle);

/**
 * Retrieves the time at which a particle was created.
 *
 * @param sParticle The particle pointer.
 *
 * @return The creation time of the particle.
 */
native Float:Particle_GetCreatedTime(const &Particle:sParticle);

/**
 * Retrieves the time at which a particle will killed.
 *
 * @param sParticle The particle pointer.
 *
 * @return The kill time of the particle.
 */
native Float:Particle_GetKillTime(const &Particle:sParticle);

/**
 * Retrieves the time at which a particle was thinked last.
 *
 * @param sParticle The particle pointer.
 *
 * @return The last think time of the particle.
 */
native Float:Particle_GetLastThink(const &Particle:sParticle);

/**
 * Retrieves the origin of the particle.
 *
 * @param sSystem The particle structure pointer.
 * @param vecOut The vector to set.
 *
 * @noreturn
 */
native Particle_GetOrigin(const &Particle:sParticle, Float:vecOut[3]);

/**
 * Sets the origin of the particle.
 *
 * @param sSystem The particle structure pointer.
 * @param vecOrigin The origin vector.
 *
 * @noreturn
 */
native Particle_SetOrigin(const &Particle:sParticle, const Float:vecOrigin[3]);

/**
 * Retrieves the angles of the particle.
 *
 * @param sSystem The particle structure pointer.
 * @param vecOut The vector to set.
 *
 * @noreturn
 */
native Particle_GetAngles(const &Particle:sParticle, Float:vecOut[3]);

/**
 * Sets the angles of the particle.
 *
 * @param sSystem The particle structure pointer.
 * @param vecAngles The angles vector.
 *
 * @noreturn
 */
native Particle_SetAngles(const &Particle:sParticle, const Float:vecAngles[3]);

/**
 * Retrieves the velocity of the particle.
 *
 * @param sSystem The particle structure pointer.
 * @param vecOut The vector to set.
 *
 * @noreturn
 */
native Particle_GetVelocity(const &Particle:sParticle, Float:vecOut[3]);

/**
 * Sets the velocity of the particle.
 *
 * @param sSystem The particle structure pointer.
 * @param vecVelocity The origin velocity.
 *
 * @noreturn
 */
native Particle_SetVelocity(const &Particle:sParticle, const Float:vecVelocity[3]);
