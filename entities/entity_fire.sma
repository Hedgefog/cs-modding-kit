#pragma semicolon 1

#include <amxmodx>
#include <amxmisc>
#include <hamsandwich>
#include <fakemeta>

#include <api_custom_entities>

#define PLUGIN "[Entity] Fire"
#define VERSION "1.0.0"
#define AUTHOR "Hedgehog Fog"

#define IS_PLAYER(%1) (%1 >= 1 && %1 <= MaxClients)

#define ENTITY_NAME "fire"

#define FIRE_BORDERS 2.0
#define FIRE_PADDING (FIRE_BORDERS + 16.0)
#define FIRE_THINK_RATE 0.025
#define FIRE_DAMAGE_RATE 0.5
#define FIRE_WATER_CHECK_RATE 1.0
#define FIRE_PARTICLES_EFFECT_RATE 0.025
#define FIRE_LIGHT_EFFECT_RATE 0.05
#define FIRE_SOUND_RATE 1.0
#define FIRE_SIZE_UPDATE_RATE 1.0

#define m_flNextParticlesEffect "flNextParticlesEffect"
#define m_flNextLightEffect "flNextLightEffect"
#define m_flNextSound "flNextSound"
#define m_flNextDamage "flNextDamage"
#define m_flNextSizeUpdate "flNextSizeUpdate"
#define m_flNextWaterCheck "flNextWaterCheck"
#define m_flDamage "flDamage"
#define m_vecEffectOrigin "vecEffectOrigin"
#define m_bAllowSpread "bAllowSpread"
#define m_bDamaged "bDamaged"

new g_rgszFlameSprites[][] = {
    "sprites/bexplo.spr",
    "sprites/cexplo.spr"
};

new const g_rgszSmokeSprites[][] = {
    "sprites/black_smoke1.spr",
    "sprites/black_smoke2.spr",
    "sprites/black_smoke3.spr",
    "sprites/black_smoke4.spr"
};

new const g_rgszBurningSounds[][] = {
    "ambience/burning1.wav",
    "ambience/burning2.wav",
    "ambience/burning3.wav"
};

new g_rgiFlameModelIndex[sizeof(g_rgszFlameSprites)];
new g_rgiFlameModelFramesNum[sizeof(g_rgszFlameSprites)];
new g_rgiSmokeModelIndex[sizeof(g_rgszSmokeSprites)];
new g_rgiSmokeModelFramesNum[sizeof(g_rgszSmokeSprites)];

public plugin_precache() {
    for (new i = 0; i < sizeof(g_rgszFlameSprites); ++i) {
        g_rgiFlameModelIndex[i] = precache_model(g_rgszFlameSprites[i]);
        g_rgiFlameModelFramesNum[i] = engfunc(EngFunc_ModelFrames, g_rgiFlameModelIndex[i]);
    }

    for (new i = 0; i < sizeof(g_rgszSmokeSprites); ++i) {
        g_rgiSmokeModelIndex[i] = precache_model(g_rgszSmokeSprites[i]);
        g_rgiSmokeModelFramesNum[i] = engfunc(EngFunc_ModelFrames, g_rgiSmokeModelIndex[i]);
    }

    for (new i = 0; i < sizeof(g_rgszBurningSounds); ++i) {
        precache_sound(g_rgszBurningSounds[i]);
    }

    CE_Register(ENTITY_NAME, NULL_STRING, Float:{-FIRE_BORDERS, -FIRE_BORDERS, -FIRE_BORDERS}, Float:{FIRE_BORDERS, FIRE_BORDERS, FIRE_BORDERS});
    CE_RegisterHook(CEFunction_Init, ENTITY_NAME, "@Entity_Init");
    CE_RegisterHook(CEFunction_Spawn, ENTITY_NAME, "@Entity_Spawn");
    CE_RegisterHook(CEFunction_Touch, ENTITY_NAME, "@Entity_Touch");
    CE_RegisterHook(CEFunction_Think, ENTITY_NAME, "@Entity_Think");
    CE_RegisterHook(CEFunction_Killed, ENTITY_NAME, "@Entity_Killed");
    CE_RegisterHook(CEFunction_Remove, ENTITY_NAME, "@Entity_Remove");
}

public plugin_init() {
    register_plugin(PLUGIN, VERSION, AUTHOR);
}

@Entity_Init(this) {
    CE_SetMemberVec(this, m_vecEffectOrigin, NULL_VECTOR);

    /* 
        Currently only partially works, because the touch doesn't handle for non-moving entities, 
        as well as for entities with "MOVETYPE_FOLLOW" movetype,
        so the fire will not spread if it's attached to something.
    */
    CE_SetMember(this, m_bAllowSpread, false);
}

@Entity_Spawn(this) {
    new Float:flGameTime = get_gametime();

    CE_SetMember(this, m_flNextParticlesEffect, flGameTime);
    CE_SetMember(this, m_flNextLightEffect, flGameTime);
    CE_SetMember(this, m_flNextSound, flGameTime);
    CE_SetMember(this, m_flNextDamage, flGameTime);
    CE_SetMember(this, m_flNextSizeUpdate, flGameTime);
    CE_SetMember(this, m_flNextWaterCheck, flGameTime);
    CE_SetMember(this, m_flDamage, 5.0);
    CE_SetMember(this, m_bDamaged, false);

    set_pev(this, pev_takedamage, DAMAGE_NO);
    set_pev(this, pev_solid, SOLID_TRIGGER);
    set_pev(this, pev_movetype, MOVETYPE_TOSS);

    set_pev(this, pev_nextthink, get_gametime());
}

@Entity_Killed(this) {
    @Entity_StopSound(this);
}

@Entity_Remove(this) {
    @Entity_StopSound(this);
}

@Entity_Touch(this, pToucher) {
    @Entity_Damage(this, pToucher);
}

@Entity_Think(this) {
    static Float:flGameTime; flGameTime = get_gametime();
    static iMoveType; iMoveType = pev(this, pev_movetype);
    static pAimEnt; pAimEnt = pev(this, pev_aiment);

    if (iMoveType == MOVETYPE_FOLLOW) {
        if (pev(pAimEnt, pev_deadflag) != DEAD_NO) {
            CE_Kill(this);
            return;
        }
    }

    if (CE_GetMember(this, m_flNextWaterCheck) <= flGameTime) {
        if (@Entity_InWater(this)) {
            CE_Kill(this);
            return;
        }

        CE_SetMember(this, m_flNextWaterCheck, flGameTime + FIRE_WATER_CHECK_RATE);
    }

    /*
        Since all non-moving entities, except players, don't handle touch,
        we force a touch event the for burning entity.
    */
    if (iMoveType == MOVETYPE_FOLLOW && !IS_PLAYER(pAimEnt)) {
        static Float:vecVelocity[3]; pev(pAimEnt, pev_velocity, vecVelocity);
        if (!vector_length(vecVelocity)) {
            dllfunc(DLLFunc_Touch, this, pAimEnt);
        }
    }

    /*
        After fire has damaged to all entities we add delay before fire can deal damage to touched entities again.
        By using m_bDamaged, we avoid the problems with issue when m_flNextDamage updates before the touch. 
    */
    if (CE_GetMember(this, m_bDamaged)) {
        static Float:flNextDamage; flNextDamage = CE_GetMember(this, m_flNextDamage);
        if (flNextDamage && flNextDamage <= flGameTime) {
            CE_SetMember(this, m_flNextDamage, flGameTime + FIRE_DAMAGE_RATE);
        }

        CE_SetMember(this, m_bDamaged, false);
    }

    if (CE_GetMember(this, m_flNextSound) <= flGameTime) {
        @Entity_Sound(this);
        CE_SetMember(this, m_flNextSound, flGameTime + FIRE_SOUND_RATE);
    }

    if (CE_GetMember(this, m_flNextSizeUpdate) <= flGameTime) {
        @Entity_UpdateSize(this);
        CE_SetMember(this, m_flNextSizeUpdate, flGameTime + FIRE_SIZE_UPDATE_RATE);
    }

    if (CE_GetMember(this, m_flNextParticlesEffect) <= flGameTime) {
        // Particle effect has higher update rate, so we update effect vars before each particle effect
        @Entity_UpdateEffectVars(this);
        @Entity_ParticlesEffect(this);
        CE_SetMember(this, m_flNextParticlesEffect, flGameTime + FIRE_PARTICLES_EFFECT_RATE);
    }

    if (CE_GetMember(this, m_flNextLightEffect) <= flGameTime) {
        @Entity_LightEffect(this);
        CE_SetMember(this, m_flNextLightEffect, flGameTime + FIRE_LIGHT_EFFECT_RATE);
    }

    if (iMoveType == MOVETYPE_FOLLOW) {
        static Float:vecVelocity[3];
        pev(pAimEnt, pev_velocity, vecVelocity);
        set_pev(this, pev_velocity, vecVelocity);
    }

    set_pev(this, pev_nextthink, flGameTime + FIRE_THINK_RATE);
}

@Entity_UpdateSize(this) {
    if (pev(this, pev_movetype) != MOVETYPE_FOLLOW) {
        return;
    }

    new pAimEnt = pev(this, pev_aiment);

    static Float:vecMins[3];
    static Float:vecMaxs[3];

    static szModel[256];
    pev(pAimEnt, pev_model, szModel, charsmax(szModel));

    new iModelStrLen = strlen(szModel);

    static bool:bIsBspModel; bIsBspModel = szModel[0] == '*';
    static bool:bHasModel; bHasModel = !!pev(pAimEnt, pev_modelindex);
    static bool:bIsSprite; bIsSprite = iModelStrLen > 5 && equal(szModel[iModelStrLen - 5], ".spr");

    if (!bHasModel || bIsBspModel || bIsSprite) {
        pev(pAimEnt, pev_mins, vecMins);
        pev(pAimEnt, pev_maxs, vecMaxs);
    } else {
        GetModelBoundingBox(pAimEnt, vecMins, vecMaxs, Model_CurrentSequence);
    }

    // Add fire borders (useful for fire spread)
    for (new i = 0; i < 3; ++i) {
        vecMins[i] -= FIRE_BORDERS;
        vecMaxs[i] += FIRE_BORDERS;
    }

    engfunc(EngFunc_SetSize, this, vecMins, vecMaxs);
}

@Entity_InWater(this) {
    static Float:vecOrigin[3];
    pev(this, pev_origin, vecOrigin);

    new pTarget = 0;
    while ((pTarget = engfunc(EngFunc_FindEntityInSphere, pTarget, vecOrigin, 1.0)) > 0) {
        static szTargetClassName[32];
        pev(pTarget, pev_classname, szTargetClassName, charsmax(szTargetClassName));

        if (equal(szTargetClassName, "func_water")) {
            return true;
        }
    }

    return false;
}

bool:@Entity_Damage(this, pTarget) {
    if (!pTarget) {
        return false;
    }

    if (pev(pTarget, pev_takedamage) == DAMAGE_NO) {
        return false;
    }

    if (pev(pTarget, pev_solid) <= SOLID_TRIGGER) {
        return false;
    }

    static Float:flGameTime; flGameTime = get_gametime();
    static Float:flNextDamage; flNextDamage = CE_GetMember(this, m_flNextDamage);

    if (flNextDamage > flGameTime) {
        return false;
    }

    static Float:flDamage; flDamage = Float:CE_GetMember(this, m_flDamage) * FIRE_DAMAGE_RATE;
    if (flDamage) {
        static pOwner; pOwner = pev(this, pev_owner);
        static pAttacker; pAttacker = pOwner && pOwner != pTarget ? pOwner : this;
        static iDamageBits; iDamageBits = DMG_NEVERGIB | DMG_BURN;

        if (cstrike_running() && IS_PLAYER(pTarget)) {
            new Float:flVelocityModifier = get_ent_data_float(pTarget, "CBasePlayer", "m_flVelocityModifier");
            ExecuteHamB(Ham_TakeDamage, pTarget, this, pAttacker, flDamage, iDamageBits);
            set_ent_data_float(pTarget, "CBasePlayer", "m_flVelocityModifier", flVelocityModifier);
        } else {
            ExecuteHamB(Ham_TakeDamage, pTarget, this, pAttacker, flDamage, iDamageBits);
        }
    }

    if (pev(this, pev_movetype) != MOVETYPE_FOLLOW) {
        if (@Entity_CanIgnite(this, pTarget)) {
            // Attach fire to the entity we damaged
            set_pev(this, pev_movetype, MOVETYPE_FOLLOW);
            set_pev(this, pev_aiment, pTarget);
        }
    } else if (CE_GetMember(this, m_bAllowSpread)) {
        if (@Entity_CanIgnite(this, pTarget)) {
            static Float:vecOrigin[3];
            pev(this, pev_origin, vecOrigin);

            new pChild = CE_Create(ENTITY_NAME, vecOrigin);
            dllfunc(DLLFunc_Spawn, pChild);
            set_pev(pChild, pev_movetype, MOVETYPE_FOLLOW);
            set_pev(pChild, pev_aiment, pTarget);
            set_pev(pChild, pev_owner, this);

            CE_SetMember(pChild, CE_MEMBER_NEXTKILL, Float:CE_GetMember(this, CE_MEMBER_NEXTKILL));
        }
    }

    CE_SetMember(this, m_bDamaged, true);

    return true;
}

@Entity_CanIgnite(this, pTarget) {
    new iCeFireHandler = CE_GetHandler(ENTITY_NAME);

    static Float:vecOrigin[3];
    pev(pTarget, pev_origin, vecOrigin);

    new pNearbyTarget = 0;
    while ((pNearbyTarget = engfunc(EngFunc_FindEntityInSphere, pNearbyTarget, vecOrigin, 4.0)) > 0) {
        if (CE_GetHandlerByEntity(pNearbyTarget) != iCeFireHandler) {
            continue;
        }

        // If target is already on fire
        if (pev(pNearbyTarget, pev_aiment) == pTarget) {
            return false;
        }
    }

    return true;
}

@Entity_Sound(this) {
    emit_sound(this, CHAN_BODY, g_rgszBurningSounds[random(sizeof(g_rgszBurningSounds))], VOL_NORM, ATTN_NORM, 0, PITCH_NORM);
}

@Entity_StopSound(this) {
    emit_sound(this, CHAN_BODY, "common/null.wav", VOL_NORM, ATTN_NORM, 0, PITCH_NORM);
}

@Entity_UpdateEffectVars(this) {
    static Float:vecAbsMin[3];
    pev(this, pev_absmin, vecAbsMin);

    static Float:vecAbsMax[3];
    pev(this, pev_absmax, vecAbsMax);

    static Float:vecVelocity[3];
    pev(this, pev_velocity, vecVelocity);

    static Float:vecOrigin[3];
    for (new i = 0; i < sizeof(vecOrigin); ++i) {
        vecOrigin[i] = (
            random_float(
                floatmin(vecAbsMin[i] + FIRE_PADDING, vecAbsMax[i]),
                floatmax(vecAbsMax[i] - FIRE_PADDING, vecAbsMin[i])
            ) + (vecVelocity[i] * FIRE_THINK_RATE)
        );
    }

    CE_SetMemberVec(this, m_vecEffectOrigin, vecOrigin);
}

@Entity_ParticlesEffect(this) {
    static Float:vecOrigin[3]; CE_GetMemberVec(this, m_vecEffectOrigin, vecOrigin);

    static Float:vecMins[3]; pev(this, pev_absmin, vecMins);
    static Float:vecMaxs[3]; pev(this, pev_absmax, vecMaxs);

    static Float:flAvgSize; flAvgSize = (
        ((vecMaxs[0] - FIRE_PADDING) - (vecMins[0] + FIRE_PADDING)) +
        ((vecMaxs[1] - FIRE_PADDING) - (vecMins[1] + FIRE_PADDING)) +
        ((vecMaxs[2] - FIRE_PADDING) - (vecMins[2] + FIRE_PADDING))
    ) / 3;

    static iScale; iScale = clamp(floatround(flAvgSize * random_float(0.0975, 0.275)), 2, 80);

    static iSmokeIndex; iSmokeIndex = random(sizeof(g_rgiFlameModelIndex));
    static iSmokeFrameRate; iSmokeFrameRate = floatround(
        g_rgiSmokeModelFramesNum[iSmokeIndex] * random_float(0.75, 1.25),
        floatround_ceil
    );

    static iFlameIndex; iFlameIndex = random(sizeof(g_rgiFlameModelIndex));
    static iFlameFrameRate; iFlameFrameRate = floatround(
        g_rgiFlameModelFramesNum[iFlameIndex] * random_float(2.975, 3.125),
        floatround_ceil
    );

    engfunc(EngFunc_MessageBegin, MSG_PAS, SVC_TEMPENTITY, vecOrigin, 0);
    write_byte(TE_EXPLOSION);
    engfunc(EngFunc_WriteCoord, vecOrigin[0]);
    engfunc(EngFunc_WriteCoord, vecOrigin[1]);
    engfunc(EngFunc_WriteCoord, vecOrigin[2]);
    write_short(g_rgiFlameModelIndex[iFlameIndex]);
    write_byte(iScale);
    write_byte(iFlameFrameRate);
    write_byte(TE_EXPLFLAG_NODLIGHTS | TE_EXPLFLAG_NOSOUND | TE_EXPLFLAG_NOPARTICLES);
    message_end();

    engfunc(EngFunc_MessageBegin, MSG_PAS, SVC_TEMPENTITY, vecOrigin, 0);
    write_byte(TE_SMOKE);
    engfunc(EngFunc_WriteCoord, vecOrigin[0]);
    engfunc(EngFunc_WriteCoord, vecOrigin[1]);
    engfunc(EngFunc_WriteCoord, vecOrigin[2]);
    write_short(g_rgiSmokeModelIndex[iSmokeIndex]);
    write_byte(iScale * 2);
    write_byte(iSmokeFrameRate);
    message_end();
}

@Entity_LightEffect(this) {
    static const irgColor[3] = {128, 64, 0};
    static Float:vecOrigin[3]; CE_GetMemberVec(this, m_vecEffectOrigin, vecOrigin);
    static Float:vecMins[3]; pev(this, pev_absmin, vecMins);
    static Float:vecMaxs[3]; pev(this, pev_absmax, vecMaxs);
    static iLifeTime; iLifeTime = 1;

    static Float:flRadius; flRadius = 0.25 * floatmax(
        vecMaxs[2] - vecMins[2],
        floatmax(vecMaxs[0] - vecMins[0], vecMaxs[1] - vecMins[1])
    ) / 2;

    static iDecayRate; iDecayRate = floatround(flRadius);

    engfunc(EngFunc_MessageBegin, MSG_PVS, SVC_TEMPENTITY, vecOrigin, 0);
    write_byte(TE_ELIGHT);
    write_short(0);
    engfunc(EngFunc_WriteCoord, vecOrigin[0]);
    engfunc(EngFunc_WriteCoord, vecOrigin[1]);
    engfunc(EngFunc_WriteCoord, vecOrigin[2]);
    engfunc(EngFunc_WriteCoord, flRadius);
    write_byte(irgColor[0]);
    write_byte(irgColor[1]);
    write_byte(irgColor[2]);
    write_byte(iLifeTime);
    write_coord(iDecayRate);
    message_end();

    engfunc(EngFunc_MessageBegin, MSG_PVS, SVC_TEMPENTITY, vecOrigin, 0);
    write_byte(TE_DLIGHT);
    engfunc(EngFunc_WriteCoord, vecOrigin[0]);
    engfunc(EngFunc_WriteCoord, vecOrigin[1]);
    engfunc(EngFunc_WriteCoord, vecOrigin[2]);
    write_byte(floatround(flRadius));
    write_byte(irgColor[0]);
    write_byte(irgColor[1]);
    write_byte(irgColor[2]);
    write_byte(iLifeTime);
    write_byte(iDecayRate);
    message_end();
}
