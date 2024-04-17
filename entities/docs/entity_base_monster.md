Here is an example how to implement HL Zombie using monster_base entity. You can test zombies on map `c1a1a`.

```cpp
#include <amxmodx>
#include <fakemeta>
#include <hamsandwich>
#include <xs>

#include <api_custom_entities>

#include <entity_base_monster_const>

#define ENTITY_NAME "monster_zombie"

#define	ZOMBIE_AE_ATTACK_RIGHT 0x01
#define	ZOMBIE_AE_ATTACK_LEFT 0x02
#define	ZOMBIE_AE_ATTACK_BOTH 0x03

#define ZOMBIE_FLINCH_DELAY 2.0

#define m_flNextFlinch "flNextFlinch"

new const g_szModel[] = "models/zombie.mdl";

new const g_rgpAttackHitSounds[][] = {
	"zombie/claw_strike1.wav",
	"zombie/claw_strike2.wav",
	"zombie/claw_strike3.wav",
};

new const g_rgpAttackMissSounds[][] =  {
	"zombie/claw_miss1.wav",
	"zombie/claw_miss2.wav",
};

new const g_rgpAttackSounds[][] = {
	"zombie/zo_attack1.wav",
	"zombie/zo_attack2.wav",
};

new const g_rgpIdleSounds[][] = {
	"zombie/zo_idle1.wav",
	"zombie/zo_idle2.wav",
	"zombie/zo_idle3.wav",
	"zombie/zo_idle4.wav",
};

new const g_rgpAlertSounds[][] = {
	"zombie/zo_alert10.wav",
	"zombie/zo_alert20.wav",
	"zombie/zo_alert30.wav",
};

new const g_rgpPainSounds[][] = {
	"zombie/zo_pain1.wav",
	"zombie/zo_pain2.wav",
};

public plugin_precache() {
    precache_model(g_szModel);

    for (new i = 0; i < sizeof(g_rgpAttackHitSounds); ++i) precache_sound(g_rgpAttackHitSounds[i]);
    for (new i = 0; i < sizeof(g_rgpAttackMissSounds); ++i) precache_sound(g_rgpAttackMissSounds[i]);
    for (new i = 0; i < sizeof(g_rgpAttackSounds); ++i) precache_sound(g_rgpAttackSounds[i]);
    for (new i = 0; i < sizeof(g_rgpIdleSounds); ++i) precache_sound(g_rgpIdleSounds[i]);
    for (new i = 0; i < sizeof(g_rgpAlertSounds); ++i) precache_sound(g_rgpAlertSounds[i]);
    for (new i = 0; i < sizeof(g_rgpPainSounds); ++i) precache_sound(g_rgpPainSounds[i]);

    CE_RegisterDerived(ENTITY_NAME, BASE_MONSTER_ENTITY_NAME);

    CE_RegisterHook(ENTITY_NAME, CEFunction_Init, "@Entity_Init");
    CE_RegisterHook(ENTITY_NAME, CEFunction_InitPhysics, "@Entity_InitPhysics");
    CE_RegisterHook(ENTITY_NAME, CEFunction_Spawned, "@Entity_Spawned");

    CE_RegisterVirtualMethod(ENTITY_NAME, IgnoreConditions, "@Entity_IgnoreConditions");
    CE_RegisterVirtualMethod(ENTITY_NAME, SetYawSpeed, "@Entity_SetYawSpeed");
    CE_RegisterVirtualMethod(ENTITY_NAME, HandleAnimEvent, "@Entity_HandleAnimEvent", CE_MP_Cell, CE_MP_Array, 64);

    CE_RegisterMethod(ENTITY_NAME, AlertSound, "@Entity_AlertSound");
    CE_RegisterMethod(ENTITY_NAME, IdleSound, "@Entity_IdleSound");
    CE_RegisterMethod(ENTITY_NAME, PainSound, "@Entity_PainSound");

    CE_RegisterVirtualMethod(ENTITY_NAME, Classify, "@Entity_Classify");
}

public plugin_init() {
    register_plugin("[Entity] Zombie Monster", "1.0.0", "Hedgehog Fog");
}

@Entity_Init(this) {
    CE_SetMemberVec(this, CE_MEMBER_MINS, Float:{-16.0, -16.0, 0.0});
    CE_SetMemberVec(this, CE_MEMBER_MAXS, Float:{16.0, 16.0, 72.0});
    CE_SetMemberString(this, CE_MEMBER_MODEL, g_szModel, false);
    CE_SetMember(this, CE_MEMBER_BLOODCOLOR, 195);
}

@Entity_InitPhysics(this) {
    set_pev(this, pev_solid, SOLID_SLIDEBOX);
    set_pev(this, pev_movetype, MOVETYPE_STEP);
}

@Entity_Spawned(this) {
    set_pev(this, pev_spawnflags, pev(this, pev_spawnflags) | SF_MONSTER_FADECORPSE);
    set_pev(this, pev_health, 100.0);
    set_pev(this, pev_view_ofs, Float:{0.0, 0.0, 28.0});
    CE_SetMember(this, m_flFieldOfView, 0.5);
    CE_SetMember(this, m_iMonsterState, MONSTER_STATE_NONE);

    CE_SetMember(this, m_flMeleeAttack1Range, 70.0);
    CE_SetMember(this, m_flMeleeAttack1Damage, 10.0);

    CE_SetMember(this, m_flMeleeAttack2Range, 70.0);
    CE_SetMember(this, m_flMeleeAttack2Damage, 24.0);
}

@Entity_AlertSound(this) {
    emit_sound(this, CHAN_WEAPON, g_rgpAlertSounds[random(sizeof(g_rgpAlertSounds))], VOL_NORM, ATTN_NORM, 0, 100 + random_num(-5, 5));
}

@Entity_IdleSound(this) {
    emit_sound(this, CHAN_WEAPON, g_rgpIdleSounds[random(sizeof(g_rgpIdleSounds))], VOL_NORM, ATTN_NORM, 0, 100 + random_num(-5, 5));
}

@Entity_PainSound(this) {
    emit_sound(this, CHAN_WEAPON, g_rgpPainSounds[random(sizeof(g_rgpPainSounds))], VOL_NORM, ATTN_NORM, 0, 100 + random_num(-5, 5));
}

@Entity_SetYawSpeed(this) {
    set_pev(this, pev_yaw_speed, 120.0);
}

@Entity_HandleAnimEvent(this, iEventId, const rgOptions[]) {
    CE_CallBaseMethod(iEventId, rgOptions);

    static Float:vecAimAngles[3];
    pev(this, pev_angles, vecAimAngles);
    vecAimAngles[0] = -vecAimAngles[0];

    static Float:vecForward[3]; angle_vector(vecAimAngles, ANGLEVECTOR_FORWARD, vecForward);
    static Float:vecRight[3]; angle_vector(vecAimAngles, ANGLEVECTOR_RIGHT, vecRight);
    
    switch (iEventId) {
        case ZOMBIE_AE_ATTACK_RIGHT, ZOMBIE_AE_ATTACK_LEFT, ZOMBIE_AE_ATTACK_BOTH: {
            static pHurt; pHurt = CE_CallMethod(this, ZOMBIE_AE_ATTACK_BOTH ? MeleeAttack2 : MeleeAttack1);

            if (pHurt != FM_NULLENT && pev(pHurt, pev_flags) & (FL_MONSTER | FL_CLIENT)) {
                static Float:vecVictimPunchAngle[3]; pev(pHurt, pev_punchangle, vecVictimPunchAngle);
                static Float:vecVictimVelocity[3]; pev(pHurt, pev_velocity, vecVictimVelocity);

                vecVictimPunchAngle[0] = 5.0;

                switch (iEventId) {
                    case ZOMBIE_AE_ATTACK_RIGHT, ZOMBIE_AE_ATTACK_LEFT: {
                        static iDirection; iDirection = (iEventId == ZOMBIE_AE_ATTACK_RIGHT ? -1 : 1);

                        vecVictimPunchAngle[2] = (18.0 * iDirection);
                        xs_vec_add_scaled(vecVictimVelocity, vecRight, 100.0 * iDirection, vecVictimVelocity);
                    }
                    case ZOMBIE_AE_ATTACK_BOTH: {
                        xs_vec_add_scaled(vecVictimVelocity, vecForward, 100.0, vecVictimVelocity);
                    }
                }

                set_pev(pHurt, pev_punchangle, vecVictimPunchAngle);
                set_pev(pHurt, pev_velocity, vecVictimVelocity);
            }

            if (pHurt != FM_NULLENT) {
                emit_sound(this, CHAN_WEAPON, g_rgpAttackHitSounds[random(sizeof(g_rgpAttackHitSounds))], VOL_NORM, ATTN_NORM, 0, 100 + random_num(-5, 5));
            } else {
                emit_sound(this, CHAN_WEAPON, g_rgpAttackMissSounds[random(sizeof(g_rgpAttackMissSounds))], VOL_NORM, ATTN_NORM, 0, 100 + random_num(-5, 5));
            }

            if (random(2)) @Entity_AttackSound(this);
        }
        case SCRIPT_EVENT_SOUND: {
            if (equal(rgOptions, "common/npc_step", 15)) {
                CE_CallMethod(this, StepSound);
            }
        }
        default: {
            // CE_CallBaseMethod(iEventId, rgOptions);
        }
    }
}

@Entity_AttackSound(this) {
	emit_sound(this, CHAN_VOICE, g_rgpAttackSounds[random(sizeof(g_rgpAttackSounds))], VOL_NORM, ATTN_NORM, 0, 100 + random_num(-5, 5));
}

@Entity_Classify(this) {
    return CLASS_ALIEN_MONSTER;
}

@Entity_IgnoreConditions(this) {
    new iIgnore = CE_CallBaseMethod();

    static Float:flGameTime; flGameTime = get_gametime();
    static Float:flNextFlinch; flNextFlinch = CE_GetMember(this, m_flNextFlinch);
    static Activity:iActivity; iActivity = CE_GetMember(this, m_iActivity);

    if ((iActivity == ACT_MELEE_ATTACK1) || (iActivity == ACT_MELEE_ATTACK1)) {
        if (flNextFlinch >= flGameTime) {
            iIgnore |= (COND_LIGHT_DAMAGE | COND_HEAVY_DAMAGE);
        }
    }

    if ((iActivity == ACT_SMALL_FLINCH) || (iActivity == ACT_BIG_FLINCH)) {
        if (flNextFlinch < flGameTime) {
            flNextFlinch = flGameTime + ZOMBIE_FLINCH_DELAY;
        }
    }

    return iIgnore;
}
```