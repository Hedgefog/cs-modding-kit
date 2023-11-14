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
native Particles_RegisterEffect(const szName[], Float:flEmitRate, Float:flParticleLifeTime, iMaxParticles, const szInitFunction[], const szTransformFunction[]);

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
native ParticleSystem:Particles_ParticleSystem_Create(const szEffect[], const Float:vecOrigin[3] = {0.0, 0.0, 0.0}, const Float:vecAngles[3] = {0.0, 0.0, 0.0}, pParent = 0);

/**
 * Destroys the particle system.
 *
 * @param sSystem The particle system structure pointer.
 *
 * @noreturn
 */
native ParticleSystem:Particles_ParticleSystem_Destroy(&ParticleSystem:sSystem);

/**
 * Activates the particle system.
 *
 * @param sSystem The particle system structure pointer.
 *
 * @noreturn
 */
native Particles_ParticleSystem_Activate(const &ParticleSystem:sSystem);

/**
 * Deactivates the particle system.
 *
 * @param sSystem The particle system structure pointer.
 *
 * @noreturn
 */
native Particles_ParticleSystem_Deactivate(const &ParticleSystem:sSystem);

/**
 * Retrieves the time at which a particle system was created.
 *
 * @param sSystem The particle system structure pointer.
 *
 * @return The creation time of the particle system.
 */
native Float:Particles_ParticleSystem_GetCreatedTime(const &ParticleSystem:sSystem);

/**
 * Retrieves the time at which a particle system will killed.
 *
 * @param sSystem The particle system structure pointer.
 *
 * @return The kill time of the particle system.
 */
native Float:Particles_ParticleSystem_GetKillTime(const &ParticleSystem:sSystem);

/**
 * Retrieves the last time a particle system was updated.
 *
 * @param sSystem The particle system structure pointer.
 *
 * @return The last update time of the particle system.
 */
native Float:Particles_ParticleSystem_GetLastUpdate(const &ParticleSystem:sSystem);

/**
 * Retrieves the visibility bits of a particle.
 *
 * @param sSystem The particle system structure pointer.
 *
 * @return The visibility bits of the particle system.
 */
native Float:Particles_ParticleSystem_GetVisibilityBits(const &ParticleSystem:sSystem);

/**
 * Gets particle pointer by entity.
 *
 * @param pEntity The particle entity.
 *
 * @return The particle pointer.
 */
native Particle:Particles_GetParticle(pEntity);

/**
 * Gets particle entity by particle pointer.
 *
 * @param sParticle The particle pointer.
 *
 * @return The entity of the particle.
 */
native Particles_Particle_GetEntity(const &Particle:sParticle);

/**
 * Retrieves the time at which a particle was created.
 *
 * @param sParticle The particle pointer.
 *
 * @return The creation time of the particle.
 */
native Float:Particles_Particle_GetCreatedTime(const &Particle:sParticle);

/**
 * Retrieves the time at which a particle will killed.
 *
 * @param sParticle The particle pointer.
 *
 * @return The kill time of the particle.
 */
native Float:Particles_Particle_GetKillTime(const &Particle:sParticle);

/**
 * Gets particle system pointer by particle pointer.
 *
 * @param sParticle The particle pointer.
 *
 * @return The particle system pointer.
 */
native ParticleSystem:Particles_Particle_GetSystem(const &Particle:sParticle);
