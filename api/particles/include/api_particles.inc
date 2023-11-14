#if defined _api_particles_included
  #endinput
#endif
#define _api_particles_included

/**
 * Registers a particle effect.
 *
 * @param szName The name of the effect.
 * @param flEmitRate The rate at which particles are emitted.
 * @param flParticleLifeTime The lifetime of each particle.
 * @param iMaxParticles The maximum number of particles.
 * @param szInitFunction The name of the initialization function.
 * @param szTransformFunction The name of the transformation function.
 *
 * @noreturn
 */
native RegisterParticleEffect(const szName[], const szInitFunction[], const szTransformFunction[], Float:flEmitRate = 0.1, Float:flParticleLifeTime = 1.0, Float:flVisibilityDistance = 1024.0, iMaxParticles = 10);

/**
 * Creates a particle system.
 *
 * @param szEffect The name of the effect.
 * @param vecOrigin The origin of the system.
 * @param vecAngles The angles of the system.
 * @param pParent The parent entity.
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
 * Retrieves the last time a particle system was updated.
 *
 * @param sSystem The particle system structure pointer.
 *
 * @return The last update time of the particle system.
 */
native Float:ParticleSystem_GetLastUpdateTime(const &ParticleSystem:sSystem);

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
 * Retrieves the parent entity of the particle system.
 * @param sSystem The particle system structure pointer.
 * @param pParent The parent entity.
 *
 * @noreturn
 */
native ParticleSystem_GetParentEntity(const &ParticleSystem:sSystem, pParent);

/**
 * Sets the parent entity of the particle system.
 *
 * @param sSystem The particle system structure pointer.
 *
 * @return The parent entity.
 */
native ParticleSystem_SetParentEntity(const &ParticleSystem:sSystem);

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
 * Retrieves the time at which a particle was transformed last.
 *
 * @param sParticle The particle pointer.
 *
 * @return The last transform time of the particle.
 */
native Float:Particle_GetLastTransformTime(const &Particle:sParticle);
