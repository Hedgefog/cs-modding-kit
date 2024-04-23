#pragma semicolon 1

#include <amxmodx>
#include <fakemeta>
#include <hamsandwich>
#include <reapi>
#include <xs>

#include <api_custom_entities>
#include <api_navsystem>

#include <entity_base_npc_const>

#define PLUGIN "[Entity] Base NPC"
#define VERSION "1.0.0"
#define AUTHOR "Hedgehog Fog"

#define IS_PLAYER(%1) (%1 >= 1 && %1 <= MaxClients)
#define IS_MONSTER(%1) (!!(pev(%1, pev_flags) & FL_MONSTER))

#define ENTITY_NAME BASE_NPC_ENTITY_NAME

new g_pCvarUseAstar;

new bool:g_bUseAstar;

new g_pTrace;

public plugin_precache() {
    Nav_Precache();

    g_pTrace = create_tr2();

    CE_Register(ENTITY_NAME, CEPreset_NPC, true);

    CE_RegisterHook(ENTITY_NAME, CEFunction_Init, "@Entity_Init");
    CE_RegisterHook(ENTITY_NAME, CEFunction_Restart, "@Entity_Restart");
    CE_RegisterHook(ENTITY_NAME, CEFunction_Spawned, "@Entity_Spawned");
    CE_RegisterHook(ENTITY_NAME, CEFunction_Remove, "@Entity_Remove");
    CE_RegisterHook(ENTITY_NAME, CEFunction_Kill, "@Entity_Kill");
    CE_RegisterHook(ENTITY_NAME, CEFunction_Killed, "@Entity_Killed");
    CE_RegisterHook(ENTITY_NAME, CEFunction_Think, "@Entity_Think");

    CE_RegisterMethod(ENTITY_NAME, PlayAction, "@Entity_PlayAction", CE_MP_Cell, CE_MP_Cell, CE_MP_Float, CE_MP_Cell);
    CE_RegisterMethod(ENTITY_NAME, EmitVoice, "@Entity_EmitVoice", CE_MP_String, CE_MP_Cell);

    CE_RegisterVirtualMethod(ENTITY_NAME, ResetPath, "@Entity_ResetPath");
    CE_RegisterVirtualMethod(ENTITY_NAME, AttackThink, "@Entity_AttackThink");
    CE_RegisterVirtualMethod(ENTITY_NAME, ProcessPath, "@Entity_ProcessPath");
    CE_RegisterVirtualMethod(ENTITY_NAME, ProcessTarget, "@Entity_ProcessTarget");
    CE_RegisterVirtualMethod(ENTITY_NAME, ProcessGoal, "@Entity_ProcessGoal");
    CE_RegisterVirtualMethod(ENTITY_NAME, SetTarget, "@Entity_SetTarget", CE_MP_FloatArray, 3);
    CE_RegisterVirtualMethod(ENTITY_NAME, AIThink, "@Entity_AIThink");
    CE_RegisterVirtualMethod(ENTITY_NAME, GetEnemy, "@Entity_GetEnemy");
    CE_RegisterVirtualMethod(ENTITY_NAME, IsEnemy, "@Entity_IsEnemy", CE_MP_Cell);
    CE_RegisterVirtualMethod(ENTITY_NAME, IsValidEnemy, "@Entity_IsValidEnemy", CE_MP_Cell);
    CE_RegisterVirtualMethod(ENTITY_NAME, UpdateEnemy, "@Entity_UpdateEnemy");
    CE_RegisterVirtualMethod(ENTITY_NAME, UpdateGoal, "@Entity_UpdateGoal");
    CE_RegisterVirtualMethod(ENTITY_NAME, CanAttack, "@Entity_CanAttack", CE_MP_Cell);
    CE_RegisterVirtualMethod(ENTITY_NAME, StartAttack, "@Entity_StartAttack");
    CE_RegisterVirtualMethod(ENTITY_NAME, ReleaseAttack, "@Entity_ReleaseAttack");
    CE_RegisterVirtualMethod(ENTITY_NAME, Hit, "@Entity_Hit");
    CE_RegisterVirtualMethod(ENTITY_NAME, HandlePath, "@Entity_HandlePath", CE_MP_Cell);
    CE_RegisterVirtualMethod(ENTITY_NAME, UpdateTarget, "@Entity_UpdateTarget");
    CE_RegisterVirtualMethod(ENTITY_NAME, Dying, "@Entity_Dying");
    CE_RegisterVirtualMethod(ENTITY_NAME, GetPathCost, "@Entity_GetPathCost", CE_MP_Cell, CE_MP_Cell);
    CE_RegisterVirtualMethod(ENTITY_NAME, FindPath, "@Entity_FindPath", CE_MP_FloatArray, 3);
    CE_RegisterVirtualMethod(ENTITY_NAME, MoveTo, "@Entity_MoveTo", CE_MP_FloatArray, 3);
    CE_RegisterVirtualMethod(ENTITY_NAME, TakeDamage, "@Entity_TakeDamage", CE_MP_Cell, CE_MP_Cell, CE_MP_Float, CE_MP_Cell);
    CE_RegisterVirtualMethod(ENTITY_NAME, IsVisible, "@Entity_IsVisible", CE_MP_FloatArray, 3, CE_MP_Cell);
    CE_RegisterVirtualMethod(ENTITY_NAME, FindEnemy, "@Entity_FindEnemy", CE_MP_Float, CE_MP_Float, CE_MP_Cell, CE_MP_Cell, CE_MP_Cell);
    CE_RegisterVirtualMethod(ENTITY_NAME, GetEnemyPriority, "@Entity_GetEnemyPriority", CE_MP_Cell);
    CE_RegisterVirtualMethod(ENTITY_NAME, IsReachable, "@Entity_IsReachable", CE_MP_FloatArray, 3, CE_MP_Cell, CE_MP_Float);
    CE_RegisterVirtualMethod(ENTITY_NAME, TestStep, "@Entity_TestStep", CE_MP_FloatArray, 3, CE_MP_FloatArray, 3, CE_MP_FloatArray, 3);
    CE_RegisterVirtualMethod(ENTITY_NAME, MoveForward, "@Entity_MoveForward");
    CE_RegisterVirtualMethod(ENTITY_NAME, StopMovement, "@Entity_StopMovement");
    CE_RegisterVirtualMethod(ENTITY_NAME, MovementThink, "@Entity_MovementThink");
    CE_RegisterVirtualMethod(ENTITY_NAME, IsInViewCone, "@Entity_IsInViewCone", CE_MP_FloatArray, 3);
    CE_RegisterVirtualMethod(ENTITY_NAME, Pain, "@Entity_Pain");
}

public plugin_init() {
    register_plugin(PLUGIN, VERSION, AUTHOR);

    RegisterHam(Ham_TakeDamage, CE_BASE_CLASSNAME, "HamHook_Base_TakeDamage_Post", .Post = 1);

    g_pCvarUseAstar = register_cvar("npc_use_astar", "1");

    bind_pcvar_num(g_pCvarUseAstar, g_bUseAstar);
}

public plugin_end() {
    free_tr2(g_pTrace);
}

/*--------------------------------[ Methods ]--------------------------------*/

@Entity_Init(this) {
    CE_SetMemberVec(this, CE_MEMBER_MINS, Float:{-12.0, -12.0, -32.0});
    CE_SetMemberVec(this, CE_MEMBER_MAXS, Float:{12.0, 12.0, 32.0});
    CE_SetMember(this, m_flAIThinkRate, 0.1);
    CE_SetMember(this, m_irgPath, ArrayCreate(3));
    CE_SetMember(this, m_flAttackRange, 18.0);
    CE_SetMember(this, m_flHitRange, 24.0);
    CE_SetMember(this, m_flAttackRate, 1.0);
    CE_SetMember(this, m_flAttackDuration, 1.0);
    CE_SetMember(this, m_flHitDelay, 0.0);
    CE_SetMember(this, m_iRevengeChance, 10);
    CE_SetMember(this, m_flStepHeight, 18.0);
    CE_SetMember(this, m_flDamage, 0.0);
    CE_SetMember(this, m_flPathSearchDelay, 5.0);
    CE_SetMember(this, m_flDieDuration, 0.1);
    CE_SetMember(this, m_flPainRate, 0.25);
    CE_SetMember(this, m_pBuildPathTask, Invalid_NavBuildPathTask);
    CE_SetMemberVec(this, m_vecHitAngle, Float:{0.0, 0.0, 0.0});
    CE_SetMemberVec(this, m_vecWeaponOffset, Float:{0.0, 0.0, 0.0});
}

@Entity_Restart(this) {
    CE_CallMethod(this, ResetPath);
}

@Entity_Spawned(this) {
    static Float:flGameTime; flGameTime = get_gametime();

    CE_SetMember(this, m_flNextAttack, flGameTime);
    CE_SetMember(this, m_flNextAIThink, flGameTime);
    CE_SetMember(this, m_flLastAIThink, flGameTime);
    CE_SetMember(this, m_flNextAction, flGameTime);
    CE_SetMember(this, m_flNextPathSearch, flGameTime);
    CE_SetMember(this, m_flNextPain, flGameTime);
    CE_SetMember(this, m_flNextGoalUpdate, flGameTime);
    CE_SetMember(this, m_flTargetArrivalTime, 0.0);
    CE_SetMember(this, m_flReleaseAttack, 0.0);
    CE_SetMember(this, m_flReleaseHit, 0.0);
    CE_DeleteMember(this, m_vecGoal);
    CE_DeleteMember(this, m_vecInput);
    CE_DeleteMember(this, m_vecTarget);
    CE_SetMember(this, m_pKiller, 0);

    set_pev(this, pev_rendermode, kRenderNormal);
    set_pev(this, pev_renderfx, kRenderFxGlowShell);
    set_pev(this, pev_renderamt, 4.0);
    set_pev(this, pev_rendercolor, Float:{0.0, 0.0, 0.0});
    set_pev(this, pev_health, 1.0);
    set_pev(this, pev_takedamage, DAMAGE_AIM);
    set_pev(this, pev_view_ofs, Float:{0.0, 0.0, 32.0});
    set_pev(this, pev_maxspeed, 0.0);
    set_pev(this, pev_enemy, 0);
    set_pev(this, pev_fov, 90.0);
    set_pev(this, pev_gravity, 1.0);

    engfunc(EngFunc_DropToFloor, this);

    set_pev(this, pev_nextthink, flGameTime + 0.1);
}

@Entity_Kill(this, pKiller) {
    CE_SetMember(this, m_pKiller, pKiller);

    new iDeadFlag = pev(this, pev_deadflag);

    if (pKiller && iDeadFlag == DEAD_NO) {
        CE_CallMethod(this, StopMovement);

        new Float:flGameTime = get_gametime();
        new Float:flDieDuration = CE_GetMember(this, m_flDieDuration);

        set_pev(this, pev_takedamage, DAMAGE_NO);
        set_pev(this, pev_deadflag, DEAD_DYING);
        set_pev(this, pev_nextthink, flGameTime + flDieDuration);

        CE_SetMember(this, m_flNextAIThink, flGameTime + flDieDuration);

        // cancel first kill function to play duing animation
        CE_CallMethod(this, Dying);

        return PLUGIN_HANDLED;
    }

    return PLUGIN_CONTINUE;
}

@Entity_Killed(this) {
    CE_CallMethod(this, ResetPath);
}

@Entity_Dying(this) {} 

@Entity_Remove(this) {
    CE_CallMethod(this, ResetPath);

    new Array:irgPath = CE_GetMember(this, m_irgPath);
    ArrayDestroy(irgPath);
}

@Entity_Think(this) {
    static Float:flGameTime; flGameTime = get_gametime();
    static iDeadFlag; iDeadFlag = pev(this, pev_deadflag);

    switch (iDeadFlag) {
        case DEAD_NO: {
            static Float:flNextAIThink; flNextAIThink = CE_GetMember(this, m_flNextAIThink);

            if (flNextAIThink <= flGameTime) {
                CE_CallMethod(this, AIThink);

                static Float:flAIThinkRate; flAIThinkRate = CE_GetMember(this, m_flAIThinkRate);
                CE_SetMember(this, m_flNextAIThink, flGameTime + flAIThinkRate);
            }

            // update velocity at high rate to avoid inconsistent velocity
            CE_CallMethod(this, MovementThink);
        }
        case DEAD_DYING: {
            // TODO: Implement dying think
            CE_Kill(this, CE_GetMember(this, m_pKiller));
            return;
        }
        case DEAD_DEAD, DEAD_RESPAWNABLE: {
            return;
        }
    }

    set_pev(this, pev_nextthink, flGameTime + 0.01);
}

@Entity_AIThink(this) {
    CE_CallMethod(this, AttackThink);

    if (Float:CE_GetMember(this, m_flNextGoalUpdate) <= get_gametime()) {
        CE_CallMethod(this, UpdateGoal);
        CE_SetMember(this, m_flNextGoalUpdate, get_gametime() + 0.1);
    }

    CE_CallMethod(this, UpdateTarget);

    if (CE_HasMember(this, m_vecTarget)) {
        static Float:vecTarget[3]; CE_GetMemberVec(this, m_vecTarget, vecTarget);
        CE_CallMethod(this, MoveTo, vecTarget);
    } else if (CE_HasMember(this, m_vecInput)) {
        CE_CallMethod(this, StopMovement);
    }

    CE_SetMember(this, m_flLastAIThink, get_gametime());
}

@Entity_MovementThink(this) {
    if (!CE_HasMember(this, m_vecInput)) return;

    static Float:vecInput[3]; CE_GetMemberVec(this, m_vecInput, vecInput);

    static Float:flSpeed; pev(this, pev_maxspeed, flSpeed);
    static bool:bIsFlying; bIsFlying = @Entity_IsFlying(this);
    static Float:vecVelocity[3]; pev(this, pev_velocity, vecVelocity);

    vecVelocity[0] = vecInput[0] * flSpeed;
    vecVelocity[1] = vecInput[1] * flSpeed;
    if (bIsFlying) vecVelocity[2] = vecInput[2] * flSpeed;

    static Float:vecAngles[3]; vector_to_angle(vecInput, vecAngles);

    if (!bIsFlying) {
        engfunc(EngFunc_WalkMove, this, vecAngles[1], 0.01, WALKMOVE_NORMAL);
    }

    set_pev(this, pev_speed, flSpeed);
    set_pev(this, pev_velocity, vecVelocity);

    if (!xs_vec_len(vecInput)) {
        CE_DeleteMember(this, m_vecInput);
    }
}

@Entity_AttackThink(this) {
    static Float:flGameTime; flGameTime = get_gametime();

    static pEnemy; pEnemy = CE_CallMethod(this, GetEnemy);
    static Float:vecTarget[3]; pev(pEnemy, pev_origin, vecTarget);

    if (CE_CallMethod(this, IsInViewCone, vecTarget)) {
    static Float:flReleaseAttack; flReleaseAttack = CE_GetMember(this, m_flReleaseAttack);
    if (!flReleaseAttack) {
        if (pEnemy && CE_CallMethod(this, CanAttack, pEnemy)) {
            CE_CallMethod(this, StartAttack);
        }
    } else if (flReleaseAttack <= flGameTime) {
        CE_CallMethod(this, ReleaseAttack);
    }

    static Float:flReleaseHit; flReleaseHit = CE_GetMember(this, m_flReleaseHit);
    if (flReleaseHit && flReleaseHit <= flGameTime) {
        CE_CallMethod(this, Hit);
        CE_SetMember(this, m_flReleaseHit, 0.0);
    }
    }

    @Entity_TurnTo(this, vecTarget);
}

@Entity_TakeDamage(this, pInflictor, pAttacker, Float:flDamage, iDamageBits) {
    static Float:flGameTime; flGameTime = get_gametime();

    if (IS_PLAYER(pAttacker) && CE_CallMethod(this, IsEnemy, pAttacker)) {
        static Float:vecOrigin[3]; pev(this, pev_origin, vecOrigin);
        static Float:vecTarget[3]; pev(pAttacker, pev_origin, vecTarget);
        static Float:flAttackRange; flAttackRange = CE_GetMember(this, m_flAttackRange);

        if (get_distance_f(vecOrigin, vecTarget) <= flAttackRange && CE_CallMethod(this, IsVisible, vecTarget, 0)) {
            if (random(100) < CE_GetMember(this, m_iRevengeChance)) {
                set_pev(this, pev_enemy, pAttacker);
            }
        }
    }

    static Float:flNextPain; flNextPain = CE_GetMember(this, m_flNextPain);

    if (flNextPain <= flGameTime) {
        CE_CallMethod(this, Pain);
        
        static Float:flPainRate; flPainRate = CE_GetMember(this, m_flPainRate);
        CE_SetMember(this, m_flNextPain, flGameTime + flPainRate);
    }
}

@Entity_Pain(this) {}

@Entity_CanAttack(this, pEnemy) {
    static Float:flGameTime; flGameTime = get_gametime();
    static Float:flNextAttack; flNextAttack = CE_GetMember(this, m_flNextAttack);
    if (flNextAttack > flGameTime) return false;

    if (!UTIL_CheckEntitiesLevel(this, pEnemy)) return false;

    static Float:flAttackRange; flAttackRange = CE_GetMember(this, m_flAttackRange);
    static Float:vecTarget[3]; pev(pEnemy, pev_origin, vecTarget);

    static Float:vecOrigin[3]; @Entity_GetWeaponOrigin(this, vecOrigin);
    if (xs_vec_distance_2d(vecOrigin, vecTarget) > flAttackRange) return false;

    // if (!@Entity_IsInViewCone(this, vecTarget, 60.0)) return false;

    engfunc(EngFunc_TraceLine, vecOrigin, vecTarget, DONT_IGNORE_MONSTERS, this, g_pTrace);

    static Float:flFraction; get_tr2(g_pTrace, TR_flFraction, flFraction);

    if (flFraction != 1.0) {
        static pHit; pHit = get_tr2(g_pTrace, TR_pHit);

        if (pHit != pEnemy) return false;
    }

    return true;
}

@Entity_StartAttack(this) {
    static Float:flGameTime; flGameTime = get_gametime();
    static Float:flAttackRange; flAttackRange = CE_GetMember(this, m_flAttackRange);
    static Float:flAttackDuration; flAttackDuration = CE_GetMember(this, m_flAttackDuration);
    static Float:flAttackRate; flAttackRate = CE_GetMember(this, m_flAttackRate);
    static Float:flHitDelay; flHitDelay = CE_GetMember(this, m_flHitDelay);
    static pEnemy; pEnemy = CE_CallMethod(this, GetEnemy);

    if (pEnemy) {
        static Float:vecTargetVelocity[3]; pev(pEnemy, pev_velocity, vecTargetVelocity);

        if (xs_vec_len(vecTargetVelocity) < flAttackRange) {
            CE_CallMethod(this, StopMovement);
        }
    }

    CE_SetMember(this, m_flReleaseHit, flGameTime + flHitDelay);
    CE_SetMember(this, m_flReleaseAttack, flGameTime + flAttackDuration);
    CE_SetMember(this, m_flNextAttack, flGameTime + flAttackDuration + flAttackRate);
}

@Entity_ReleaseAttack(this) {
    CE_SetMember(this, m_flReleaseAttack, 0.0);
}

@Entity_Hit(this) {
    static Float:flDamage; flDamage = CE_GetMember(this, m_flDamage);
    static Float:flHitRange; flHitRange = CE_GetMember(this, m_flHitRange);
    static Float:vecHitAngle[3]; CE_GetMemberVec(this, m_vecHitAngle, vecHitAngle);

    static Float:vecAngles[3];
    pev(this, pev_angles, vecAngles);
    xs_vec_add(vecAngles, vecHitAngle, vecAngles);
    vecAngles[0] = -vecAngles[0];
    
    static Float:vecDirection[3]; angle_vector(vecAngles, ANGLEVECTOR_FORWARD, vecDirection);
    static Float:vecOrigin[3]; @Entity_GetWeaponOrigin(this, vecOrigin);
    static Float:vecTarget[3]; xs_vec_add_scaled(vecOrigin, vecDirection, flHitRange, vecTarget);

    xs_vec_sub(vecTarget, vecOrigin, vecDirection);
    xs_vec_normalize(vecDirection, vecDirection);

    engfunc(EngFunc_TraceLine, vecOrigin, vecTarget, DONT_IGNORE_MONSTERS, this, g_pTrace);

    static pTarget; pTarget = get_tr2(g_pTrace, TR_pHit);

    if (pTarget == -1) {
        engfunc(EngFunc_TraceHull, vecOrigin, vecTarget, DONT_IGNORE_MONSTERS, HULL_HEAD, this, g_pTrace);
        pTarget = get_tr2(g_pTrace, TR_pHit);
    }

    if (pTarget != -1) {
        get_tr2(g_pTrace, TR_vecEndPos, vecTarget);
        xs_vec_sub(vecTarget, vecOrigin, vecDirection);
        xs_vec_normalize(vecDirection, vecDirection);

        rg_multidmg_clear();
        ExecuteHamB(Ham_TraceAttack, pTarget, this, flDamage, vecDirection, g_pTrace, DMG_GENERIC);
        rg_multidmg_apply(this, this);
    }

    return pTarget;
}

@Entity_GetDirectionVector(this, Float:vecOut[3]) {
    static Float:vecAngles[3];
    pev(this, pev_angles, vecAngles);
    vecAngles[0] = -vecAngles[0];

    angle_vector(vecAngles, ANGLEVECTOR_FORWARD, vecOut);
    xs_vec_normalize(vecOut, vecOut);
}

@Entity_MoveTo(this, const Float:vecTarget[3]) {
    @Entity_TurnTo(this, vecTarget);

    if (CE_CallMethod(this, IsInViewCone, vecTarget)) {
        static Float:flMaxSpeed; pev(this, pev_maxspeed, flMaxSpeed);

        if (flMaxSpeed > 0.0) {
            CE_CallMethod(this, MoveForward);
        }
    }
}

@Entity_EmitVoice(this, const szSound[], Float:flDuration) {
    emit_sound(this, CHAN_VOICE, szSound, VOL_NORM, ATTN_NORM, 0, PITCH_NORM);
}

@Entity_UpdateEnemy(this) {
    static Float:flViewRange; flViewRange = CE_GetMember(this, m_flViewRange);
    if (CE_CallMethod(this, FindEnemy, flViewRange, 0.0, false, true, true)) return true;

    static Float:flFindRange; flFindRange = CE_GetMember(this, m_flFindRange);
    if (CE_CallMethod(this, FindEnemy, flFindRange, 0.0, false, false, false)) return true;

    return false;
}

@Entity_UpdateGoal(this) {
    static Float:flGameTime; flGameTime = get_gametime();

    new pEnemy = CE_CallMethod(this, GetEnemy);
    if (pEnemy) {
        CE_DeleteMember(this, m_vecGoal);
    }

    if (Float:CE_GetMember(this, m_flNextEnemyUpdate) <= flGameTime) {
        if (CE_CallMethod(this, UpdateEnemy)) {
            pEnemy = pev(this, pev_enemy);
        }

        CE_SetMember(this, m_flNextEnemyUpdate, flGameTime + 0.1);
    }

    if (pEnemy) {
        static Float:vecGoal[3]; pev(pEnemy, pev_origin, vecGoal);
        CE_SetMemberVec(this, m_vecGoal, vecGoal);
    }
}

@Entity_UpdateTarget(this) {
    CE_CallMethod(this, ProcessPath);
    CE_CallMethod(this, ProcessGoal);
    CE_CallMethod(this, ProcessTarget);
}

@Entity_ProcessTarget(this) {
    if (!CE_HasMember(this, m_vecTarget)) return;

    // static Float:flGameTime; flGameTime = get_gametime();
    // static Float:flArrivalTime; flArrivalTime = CE_GetMember(this, m_flTargetArrivalTime);

    if (@Entity_IsTargetReached(this)) {
        CE_DeleteMember(this, m_vecTarget);
    }
}

@Entity_IsTargetReached(this) {
    if (!CE_HasMember(this, m_vecTarget)) return true;

    static Float:vecTarget[3]; CE_GetMemberVec(this, m_vecTarget, vecTarget);

    static Float:vecAbsMin[3]; pev(this, pev_absmin, vecAbsMin);
    static Float:vecAbsMax[3]; pev(this, pev_absmax, vecAbsMax);

    if (vecTarget[2] < vecAbsMin[2]) return false;
    if (vecTarget[2] > vecAbsMax[2]) return false;

    static Float:flMaxDistance; flMaxDistance = 0.0;

    static pEnemy; pEnemy = CE_CallMethod(this, GetEnemy);
    static Array:irgPath; irgPath = CE_GetMember(this, m_irgPath);
    if (pEnemy && !ArraySize(irgPath)) {
        flMaxDistance = CE_GetMember(this, m_flAttackRange);
    } else {
        flMaxDistance = floatmin(vecAbsMax[0] - vecAbsMin[0], vecAbsMax[0] - vecAbsMin[0]) / 2;
    }

    static Float:vecOrigin[3]; pev(this, pev_origin, vecOrigin);

    if (xs_vec_distance_2d(vecOrigin, vecTarget) > flMaxDistance) return false;

    return true;
}

@Entity_ProcessGoal(this) {
    static Float:flGameTime; flGameTime = get_gametime();

    if (CE_HasMember(this, m_vecGoal)) {
        static Float:vecGoal[3]; CE_GetMemberVec(this, m_vecGoal, vecGoal);

        if (!CE_CallMethod(this, IsReachable, vecGoal, pev(this, pev_enemy), 32.0)) {
            if (g_bUseAstar) {
                if (Float:CE_GetMember(this, m_flNextPathSearch) <= flGameTime) {
                    CE_CallMethod(this, FindPath, vecGoal);
                    CE_SetMember(this, m_flNextPathSearch, flGameTime + Float:CE_GetMember(this, m_flPathSearchDelay));
                    CE_DeleteMember(this, m_vecTarget);
                    CE_DeleteMember(this, m_vecGoal);
                }
            } else {
                CE_DeleteMember(this, m_vecGoal);
                CE_DeleteMember(this, m_vecTarget);
            }
        } else {
            CE_DeleteMember(this, m_vecGoal);
            CE_CallMethod(this, SetTarget, vecGoal);
        }
    }
}

@Entity_SetTarget(this, const Float:vecTarget[3]) {
    static Float:vecOrigin[3]; pev(this, pev_origin, vecOrigin);
    static Float:flMaxSpeed; pev(this, pev_maxspeed, flMaxSpeed);
    static Float:flDuration; flDuration = xs_vec_distance(vecOrigin, vecTarget) / flMaxSpeed;

    CE_SetMemberVec(this, m_vecTarget, vecTarget);
    CE_SetMember(this, m_flTargetArrivalTime, get_gametime() + flDuration);
}

@Entity_PlayAction(this, iStartSequence, iEndSequence, Float:flDuration, bSupercede) {
    static Float:flGametime; flGametime = get_gametime();
    if (!bSupercede && flGametime < Float:CE_GetMember(this, m_flNextAction)) return false;

    static iSequence; iSequence = random_num(iStartSequence, iEndSequence);
    if (!UTIL_SetSequence(this, iSequence)) return false;

    CE_SetMember(this, m_flNextAction, flGametime + flDuration);

    return true;
}

@Entity_FindPath(this, Float:vecTarget[3]) {
    CE_CallMethod(this, ResetPath);

    static Float:vecOrigin[3]; pev(this, pev_origin, vecOrigin);

    new NavBuildPathTask:pTask = Nav_Path_Find(vecOrigin, vecTarget, "NavPathCallback", this, this, "NavPathCost");
    CE_SetMember(this, m_pBuildPathTask, pTask);
}

@Entity_ResetPath(this) {
    new Array:irgPath = CE_GetMember(this, m_irgPath);
    ArrayClear(irgPath);

    new NavBuildPathTask:pTask = CE_GetMember(this, m_pBuildPathTask);
    if (pTask != Invalid_NavBuildPathTask) {
        Nav_Path_FindTask_Abort(pTask);
        CE_SetMember(this, m_pBuildPathTask, Invalid_NavBuildPathTask);
    }

    // CE_DeleteMember(this, m_vecGoal);
    CE_DeleteMember(this, m_vecTarget);
}

bool:@Entity_ProcessPath(this) {
    if (CE_HasMember(this, m_vecTarget)) return true;

    new Array:irgPath = CE_GetMember(this, m_irgPath);
    if (!ArraySize(irgPath)) return false;
    
    static Float:flStepHeight; flStepHeight = CE_GetMember(this, m_flStepHeight);
    static Float:vecMins[3]; pev(this, pev_mins, vecMins);

    static Float:vecTarget[3];
    ArrayGetArray(irgPath, 0, vecTarget);
    ArrayDeleteItem(irgPath, 0);

    vecTarget[2] += -vecMins[2] + flStepHeight;

    CE_CallMethod(this, SetTarget, vecTarget);

    return true;
}

@Entity_HandlePath(this, NavPath:pPath) {
    if (Nav_Path_IsValid(pPath)) {
        static Array:irgPath; irgPath = CE_GetMember(this, m_irgPath);
        ArrayClear(irgPath);

        static iSegmentsNum; iSegmentsNum = Nav_Path_GetSegmentCount(pPath);

        for (new iSegment = 0; iSegment < iSegmentsNum; ++iSegment) {
            static Float:vecPos[3]; Nav_Path_GetSegmentPos(pPath, iSegment, vecPos);

            ArrayPushArray(irgPath, vecPos, sizeof(vecPos));
        }
    } else {
        set_pev(this, pev_enemy, 0);
    }

    CE_SetMember(this, m_pBuildPathTask, Invalid_NavBuildPathTask);
}

@Entity_GetEnemy(this) {
    new pEnemy = pev(this, pev_enemy);

    if (!CE_CallMethod(this, IsValidEnemy, pEnemy)) return 0;

    return pEnemy;
}

bool:@Entity_IsEnemy(this, pEnemy) {
    if (pEnemy <= 0) return false;
    if (!pev_valid(pEnemy)) return false;

    static iTeam; iTeam = pev(this, pev_team);

    new iEnemyTeam = 0;
    if (IS_PLAYER(pEnemy)) {
        iEnemyTeam = get_ent_data(pEnemy, "CBasePlayer", "m_iTeam");
    } else if (IS_MONSTER(pEnemy)) {
        iEnemyTeam = pev(pEnemy, pev_team);
    } else {
        return false;
    }

    if (iTeam == iEnemyTeam) return false;
    if (pev(pEnemy, pev_takedamage) == DAMAGE_NO) return false;
    if (pev(pEnemy, pev_solid) < SOLID_BBOX) return false;
    if (IsInvisible(pEnemy)) return false;

    return true;
}

bool:@Entity_IsValidEnemy(this, pEnemy) {
    if (pEnemy <= 0) return false;
    if (!pev_valid(pEnemy)) return false;

    if (IS_PLAYER(pEnemy)) {
        if (!is_user_alive(pEnemy)) return false;
    } else if (IS_MONSTER(pEnemy)) {
        if (pev(pEnemy, pev_deadflag) != DEAD_NO) return false;
    } else {
        return false;
    }

    if (pev(pEnemy, pev_takedamage) == DAMAGE_NO) return false;
    if (pev(pEnemy, pev_solid) < SOLID_BBOX) return false;
    if (IsInvisible(pEnemy)) return false;

    return true;
}

Float:@Entity_GetEnemyPriority(this, pEnemy) {
    if (IS_PLAYER(pEnemy)) return 1.0;
    if (IS_MONSTER(pEnemy)) return 0.075;

    return 0.0;
}

@Entity_FindEnemy(this, Float:flMaxDistance, Float:flMinPriority, bool:bVisibleOnly, bool:bReachableOnly, bool:bAllowMonsters) {
    new pEnemy = pev(this, pev_enemy);
    if (!CE_CallMethod(this, IsValidEnemy, pEnemy)) {
        set_pev(this, pev_enemy, 0);
    }

    static Float:vecOrigin[3]; pev(this, pev_origin, vecOrigin);
    static pClosestTarget; pClosestTarget = 0;
    static Float:flClosestTargetPriority; flClosestTargetPriority = 0.0;

    new pTarget = 0;
    while ((pTarget = engfunc(EngFunc_FindEntityInSphere, pTarget, vecOrigin, flMaxDistance)) > 0) {
        if (this == pTarget) continue;

        if (!CE_CallMethod(this, IsEnemy, pTarget)) continue;
        if (!CE_CallMethod(this, IsValidEnemy, pTarget)) continue;

        static Float:vecTarget[3]; pev(pTarget, pev_origin, vecTarget);

        if (bVisibleOnly && !CE_CallMethod(this, IsVisible, vecTarget, pTarget)) continue;

        static Float:flDistance; flDistance = xs_vec_distance(vecOrigin, vecTarget);
        static Float:flTargetPriority; flTargetPriority = 1.0 - (flDistance / flMaxDistance);

        if (!bAllowMonsters && IS_MONSTER(pTarget)) {
            flTargetPriority *= 0.0;
        } else {
            flTargetPriority *= Float:CE_CallMethod(this, GetEnemyPriority, pTarget);
        }

        if (flTargetPriority >= flMinPriority && bReachableOnly && !CE_CallMethod(this, IsReachable, vecTarget, pTarget)) {
            flTargetPriority *= 0.1;
        }

        if (flTargetPriority >= flMinPriority && flTargetPriority > flClosestTargetPriority) {
            pClosestTarget = pTarget;
            flClosestTargetPriority = flTargetPriority;
        }
    }

    if (pClosestTarget) {
        set_pev(this, pev_enemy, pClosestTarget);
    }

    return pClosestTarget;
}

bool:@Entity_IsVisible(this, const Float:vecTarget[3], pIgnoreEnt) {
    static Float:vecOrigin[3]; ExecuteHamB(Ham_EyePosition, this, vecOrigin);

    static iIgnoreEntSolidType; iIgnoreEntSolidType = SOLID_NOT;
    if (pIgnoreEnt) {
        iIgnoreEntSolidType = pev(pIgnoreEnt, pev_solid);
        set_pev(pIgnoreEnt, pev_solid, SOLID_NOT);
    }

    static bool:bIsOpen; bIsOpen = IsOpen(vecOrigin, vecTarget, this);

    if (pIgnoreEnt) {
        set_pev(pIgnoreEnt, pev_solid, iIgnoreEntSolidType);
    }

    return bIsOpen;
}

bool:@Entity_IsReachable(this, const Float:vecTarget[3], pIgnoreEnt, Float:flStepLength) {    
    if ((~pev(this, pev_flags) & FL_ONGROUND) && !@Entity_IsFlying(this)) return false;

    static Float:vecOrigin[3]; pev(this, pev_origin, vecOrigin);
    static Float:vecTargetFixed[3]; xs_vec_set(vecTargetFixed, vecTarget[0], vecTarget[1], floatmax(vecTarget[2], vecOrigin[2]));

    static iIgnoreEntSolidType; iIgnoreEntSolidType = SOLID_NOT;
    if (pIgnoreEnt) {
        iIgnoreEntSolidType = pev(pIgnoreEnt, pev_solid);
        set_pev(pIgnoreEnt, pev_solid, SOLID_NOT);
    }

    static bool:bIsReachable; bIsReachable = true;

    if (bIsReachable) {
        bIsReachable = IsOpen(vecOrigin, vecTargetFixed, this);
    }

    if (bIsReachable) {
        static Float:vecMins[3]; pev(this, pev_mins, vecMins);
        static Float:vecLeftSide[3]; xs_vec_set(vecLeftSide, vecOrigin[0] + vecMins[0], vecOrigin[1] + vecMins[1], vecOrigin[2]);
        static Float:vecTargetLeftSide[3]; xs_vec_set(vecTargetLeftSide, vecTargetFixed[0] + vecMins[0], vecTargetFixed[1] + vecMins[1], vecTargetFixed[2]);

        bIsReachable = IsOpen(vecLeftSide, vecTargetLeftSide, this);
    }

    if (bIsReachable) {
        static Float:vecMaxs[3]; pev(this, pev_maxs, vecMaxs);
        static Float:vecRightSide[3]; xs_vec_set(vecRightSide, vecOrigin[0] + vecMaxs[0], vecOrigin[1] + vecMaxs[1], vecOrigin[2]);
        static Float:vecTargetRightSide[3]; xs_vec_set(vecTargetRightSide, vecTargetFixed[0] + vecMaxs[0], vecTargetFixed[1] + vecMaxs[1], vecTargetFixed[2]);

        bIsReachable = IsOpen(vecRightSide, vecTargetRightSide, this);
    }

    if (pev(this, pev_movetype) != MOVETYPE_FLY) {
        static Float:vecStepOrigin[3];

        if (bIsReachable) {
            static Float:flDistance; flDistance = get_distance_f(vecOrigin, vecTargetFixed);
            static iStepsNum; iStepsNum = floatround(flDistance / flStepLength);

            if (iStepsNum) {
                // Get direction vector
                static Float:vecStep[3];
                xs_vec_sub(vecTargetFixed, vecOrigin, vecStep);
                xs_vec_normalize(vecStep, vecStep);
                xs_vec_mul_scalar(vecStep, flStepLength, vecStep);

                xs_vec_copy(vecOrigin, vecStepOrigin);

                static iStep; iStep = 0;

                do {
                    bIsReachable = @Entity_TestStep(this, vecStepOrigin, vecStep, vecStepOrigin);
                    iStep++;
                } while (bIsReachable && iStep < iStepsNum);
            }
        }

        if (bIsReachable) {
            bIsReachable = (vecTarget[2] - vecStepOrigin[2]) < 72.0;
        }
    }

    if (pIgnoreEnt) {
        set_pev(pIgnoreEnt, pev_solid, iIgnoreEntSolidType);
    }

    return bIsReachable;
}

bool:@Entity_TestStep(this, const Float:vecOrigin[3], const Float:vecStep[3], Float:vecStepOrigin[3]) {
    static Float:vecMins[3]; pev(this, pev_mins, vecMins);
    static Float:flStepHeight; flStepHeight = CE_GetMember(this, m_flStepHeight);

    // Check wall
    static Float:vecStepStart[3]; xs_vec_set(vecStepStart, vecOrigin[0], vecOrigin[1], vecOrigin[2] + vecMins[2] + flStepHeight);
    static Float:vecStepEnd[3]; xs_vec_add(vecStepStart, vecStep, vecStepEnd);

    if (!IsOpen(vecStepStart, vecStepEnd, this)) return false;

    static Float:vecNextOrigin[3]; xs_vec_set(vecNextOrigin, vecStepEnd[0], vecStepEnd[1], vecStepEnd[2] - vecMins[2]);

    // Check if falling or solid
    new Float:flDistanceToFloor = GetDistanceToFloor(this, vecNextOrigin);
    if (flDistanceToFloor < 0.0) return false;

    vecNextOrigin[2] -= flDistanceToFloor; // apply possible height change

    xs_vec_copy(vecNextOrigin, vecStepOrigin); // copy result

    return true;
}

@Entity_MoveForward(this) {
    static Float:vecInput[3]; @Entity_GetDirectionVector(this, vecInput);

    if (!@Entity_IsFlying(this)) {
        vecInput[2] = 0.0;
        xs_vec_normalize(vecInput, vecInput);
    }

    CE_SetMemberVec(this, m_vecInput, vecInput);
}

@Entity_StopMovement(this) {
    if (CE_HasMember(this, m_vecInput)) {
        CE_SetMemberVec(this, m_vecInput, Float:{0.0, 0.0, 0.0});
    }
}

@Entity_GetWeaponOrigin(this, Float:vecOut[3]) {
    static Float:vecWeaponOffset[3]; CE_GetMemberVec(this, m_vecWeaponOffset, vecWeaponOffset);

    pev(this, pev_origin, vecOut);
    xs_vec_add(vecOut, vecWeaponOffset, vecOut);
}

bool:@Entity_IsFlying(this) {
    static iMoveType; iMoveType = pev(this, pev_movetype);

    return (iMoveType == MOVETYPE_FLY || iMoveType == MOVETYPE_NOCLIP); 
}

bool:@Entity_IsInViewCone(this, const Float:vecTarget[3]) {
    static Float:vecOrigin[3]; ExecuteHamB(Ham_EyePosition, this, vecOrigin);
    static Float:flFOV; pev(this, pev_fov, flFOV);

    static Float:vecDirection[3];
    xs_vec_sub(vecTarget, vecOrigin, vecDirection);
    xs_vec_normalize(vecDirection, vecDirection);

    static Float:vecForward[3];
    pev(this, pev_angles, vecForward);
    angle_vector(vecForward, ANGLEVECTOR_FORWARD, vecForward);

    static Float:flAngle; flAngle = xs_rad2deg(xs_acos((vecDirection[0] * vecForward[0]) + (vecDirection[1] * vecForward[1]), radian));

    return flAngle <= (flFOV / 2);
}

Float:@Entity_GetPathCost(this, NavArea:nextArea, NavArea:prevArea) {
    static NavAttributeType:iAttributes; iAttributes = Nav_Area_GetAttributes(nextArea);

    // NPCs can't jump or crouch
    if (iAttributes & NAV_JUMP || iAttributes & NAV_CROUCH) return -1.0;

    // NPCs can't go ladders
    if (prevArea != Invalid_NavArea) {
        static NavTraverseType:iTraverseType; iTraverseType = Nav_Area_GetParentHow(prevArea);
        if (iTraverseType == GO_LADDER_UP) return -1.0;
        // if (iTraverseType == GO_LADDER_DOWN) return -1.0;
    }

    static Float:flStepHeight; flStepHeight = CE_GetMember(this, m_flStepHeight);

    static Float:vecOrigin[3];

    if (prevArea != Invalid_NavArea) {
        Nav_Area_GetCenter(prevArea, vecOrigin);
    } else {
        pev(this, pev_origin, vecOrigin);
    }
    
    vecOrigin[2] += flStepHeight;
    
    static Float:vecTarget[3];
    Nav_Area_GetCenter(nextArea, vecTarget);
    vecTarget[2] = Nav_Area_GetZ(nextArea) + flStepHeight;

    engfunc(EngFunc_TraceLine, vecOrigin, vecTarget, IGNORE_MONSTERS, 0, g_pTrace);

    static pHit; pHit = get_tr2(g_pTrace, TR_pHit);

    // cancel if there is a wall
    if (!pHit) return -1.0;

    // cancel path if there is a obstacle
    if (pHit != -1 && !IS_PLAYER(pHit) && !IS_MONSTER(pHit)) return -1.0;

    static pTarget; pTarget = 0;
    while ((pTarget = engfunc(EngFunc_FindEntityInSphere, pTarget, vecTarget, 4.0)) > 0) {
        static szClassName[32]; pev(pTarget, pev_classname, szClassName, charsmax(szClassName));

        // don't go through the hurt entities
        if (equal(szClassName, "trigger_hurt")) return -1.0;
    }

    return 1.0;
}

@Entity_TurnTo(this, const Float:vecTarget[3]) {
    static Float:flGameTime; flGameTime = get_gametime();
    static Float:flLastAIThink; flLastAIThink = CE_GetMember(this, m_flLastAIThink);
    static Float:flDelta; flDelta = floatmin(flGameTime - flLastAIThink, 1.0);
    static Float:flSpeed; flSpeed = 180.0 * flDelta;
    static bool:rgbLockAxis[3]; rgbLockAxis = bool:{true, false, true};

    static iMoveType; iMoveType = pev(this, pev_movetype);
    if (iMoveType == MOVETYPE_FLY || iMoveType == MOVETYPE_NOCLIP) {
        rgbLockAxis[0] = false;
    }

    static Float:vecOrigin[3]; pev(this, pev_origin, vecOrigin);
    static Float:vecAngles[3]; pev(this, pev_angles, vecAngles);

    static Float:vecTargetAngles[3];
    xs_vec_sub(vecTarget, vecOrigin, vecTargetAngles);
    engfunc(EngFunc_VecToAngles, vecTargetAngles, vecTargetAngles);

    for (new i = 0; i < 3; ++i) {
        if (rgbLockAxis[i]) continue;

        if (flSpeed >= 0.0) {
            vecAngles[i] = UTIL_ApproachAngle(vecTargetAngles[i], vecAngles[i], flSpeed);
        } else {
            vecAngles[i] = vecTargetAngles[i];
        }
    }

    static Float:vecViewAngles[3];
    xs_vec_copy(vecAngles, vecViewAngles);
    vecViewAngles[0] = -vecViewAngles[0];

    set_pev(this, pev_angles, vecAngles);
    set_pev(this, pev_v_angle, vecViewAngles);
    set_pev(this, pev_ideal_yaw, vecAngles[1]);
}

/*--------------------------------[ Function ]--------------------------------*/

bool:IsOpen(const Float:vecSrc[3], const Float:vecEnd[3], pIgnoreEnt = 0, iIgnoreFlags = IGNORE_MONSTERS) {
    engfunc(EngFunc_TraceLine, vecSrc, vecEnd, iIgnoreFlags, pIgnoreEnt, g_pTrace);

    if (get_tr2(g_pTrace, TR_AllSolid)) return false;
    if (get_tr2(g_pTrace, TR_StartSolid)) return false;

    static Float:flFraction; get_tr2(g_pTrace, TR_flFraction, flFraction);
    if (flFraction < 1.0) return false;

    return true;
}

Float:GetDistanceToFloor(pEntity, const Float:vecOrigin[3]) {
    static Float:vecTarget[3]; xs_vec_set(vecTarget, vecOrigin[0], vecOrigin[1], -8192.0);

    engfunc(EngFunc_TraceMonsterHull, pEntity, vecOrigin, vecTarget, IGNORE_MONSTERS, pEntity, g_pTrace);

    static Float:flFraction; get_tr2(g_pTrace, TR_flFraction, flFraction);
    if (flFraction == 1.0) return -1.0;

    static Float:vecEnd[3]; get_tr2(g_pTrace, TR_vecEndPos, vecEnd);

    return vecOrigin[2] - vecEnd[2];
}

IsInvisible(pEntity) {
    if (!pev_valid(pEntity)) return true;
    if (pev(pEntity, pev_rendermode) == kRenderNormal) return false;

    static Float:flRenderAmt; pev(pEntity, pev_renderamt, flRenderAmt);

    return (flRenderAmt < 50.0);
}

/*--------------------------------[ Hooks ]--------------------------------*/

public HamHook_Base_TakeDamage_Post(pEntity, pInflictor, pAttacker, Float:flDamage, iDamageBits) {
    if (CE_IsInstanceOf(pEntity, ENTITY_NAME)) {
        CE_CallMethod(pEntity, TakeDamage, pInflictor, pAttacker, flDamage, iDamageBits);
        return HAM_HANDLED;
    }

    return HAM_IGNORED;
}

/*--------------------------------[ Callbacks ]--------------------------------*/

public Float:NavPathCost(NavBuildPathTask:pTask, NavArea:newArea, NavArea:prevArea) {
    static pEntity; pEntity = Nav_Path_FindTask_GetUserToken(pTask);
    if (!pEntity) return 1.0;
    
    return CE_CallMethod(pEntity, GetPathCost, newArea, prevArea);
}

public NavPathCallback(NavBuildPathTask:pTask) {
    new pEntity = Nav_Path_FindTask_GetUserToken(pTask);
    new NavPath:pPath = Nav_Path_FindTask_GetPath(pTask);

    return CE_CallMethod(pEntity, HandlePath, pPath);
}

/*--------------------------------[ Stocks ]--------------------------------*/

stock bool:UTIL_SetSequence(pEntity, iSequence) {
    if (pev(pEntity, pev_sequence) == iSequence) return false;

    set_pev(pEntity, pev_frame, 0);
    set_pev(pEntity, pev_framerate, 1.0);
    set_pev(pEntity, pev_animtime, get_gametime());
    set_pev(pEntity, pev_sequence, iSequence);

    return true;
}

stock Float:UTIL_ApproachAngle(Float:flTarget, Float:flValue, Float:flSpeed) {
    flTarget = UTIL_AngleMod(flTarget);
    flValue = UTIL_AngleMod(flValue);
    flSpeed = floatabs(flSpeed);

    static Float:flDelta; flDelta = flTarget - flValue;

    if (flDelta < -180.0) {
        flDelta += 360.0;
    } else if (flDelta > 180.0) {
        flDelta -= 360.0;
    }

    if (flDelta > flSpeed) {
        flValue += flSpeed;
    } else if (flDelta < -flSpeed) {
        flValue -= flSpeed;
    } else { 
        flValue = flTarget;
    }

    return flValue;
}

stock Float:UTIL_AngleMod(Float:flAngle) {
  return (360.0/65536) * (floatround(flAngle * (65536.0/360.0), floatround_floor) & 65535);
}

stock bool:UTIL_CheckEntitiesLevel(pEntity, pOther) {
    static Float:vecAbsMin[3]; pev(pEntity, pev_absmin, vecAbsMin);
    static Float:vecAbsMax[3]; pev(pEntity, pev_absmax, vecAbsMax);
    static Float:vecOtherAbsMin[3]; pev(pOther, pev_absmin, vecOtherAbsMin);
    static Float:vecOtherAbsMax[3]; pev(pOther, pev_absmax, vecOtherAbsMax);

    if (vecAbsMax[2] < vecOtherAbsMin[2]) return false;
    if (vecAbsMin[2] > vecOtherAbsMax[2]) return false;

    return true;
}