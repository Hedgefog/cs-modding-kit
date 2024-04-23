#pragma semicolon 1

#include <amxmodx>
#include <fakemeta>
#include <hamsandwich>
#include <xs>

#include <api_custom_entities>
#tryinclude <api_navsystem>
#include <cellstruct>

#include <entity_base_monster_const>

#define PLUGIN "[Entity] Base Monster"
#define VERSION "1.0.0"
#define AUTHOR "Hedgehog Fog"

#define IS_PLAYER(%1) (%1 >= 1 && %1 <= MaxClients)
#define IS_MONSTER(%1) (!!(pev(%1, pev_flags) & FL_MONSTER))

#define ENTITY_NAME BASE_MONSTER_ENTITY_NAME

#define EVENT_CLIENT 5000
#define STUDIO_LOOPING 0x0001
#define DIST_TO_CHECK 200.0
#define MONSTER_CUT_CORNER_DIST 8.0
#define MAX_WORLD_SOUNDS 64

#define CHAR_TEX_CONCRETE 'C'
#define CHAR_TEX_METAL 'M'
#define CHAR_TEX_DIRT 'D'
#define CHAR_TEX_VENT 'V'
#define CHAR_TEX_GRATE 'G'
#define CHAR_TEX_TILE 'T'
#define CHAR_TEX_SLOSH 'S'
#define CHAR_TEX_WOOD 'W'
#define CHAR_TEX_COMPUTER 'P'
#define CHAR_TEX_GRASS 'X'
#define CHAR_TEX_GLASS 'Y'
#define CHAR_TEX_FLESH 'F'
#define CHAR_TEX_SNOW 'N'

enum Sound {
    Sound_Emitter,
    Sound_Type,
    Sound_Volume,
    Float:Sound_ExpiredTime,
    Float:Sound_Origin[3]
};

enum ModelEvent {
    ModelEvent_Frame,
    ModelEvent_Event,
    ModelEvent_Options[64]
};

enum Model {
    Float:Model_EyePosition[3],
    Array:Model_Sequences
};

enum Sequence {
    Sequence_FramesNum,
    Float:Sequence_FPS,
    Sequence_Flags,
    Sequence_Activity,
    Sequence_ActivityWeight,
    Array:Sequence_Events,
    Float:Sequence_LinearMovement[3]
};

enum {
    STEP_CONCRETE = 0,
    STEP_METAL,
    STEP_DIRT,
    STEP_VENT,
    STEP_GRATE,
    STEP_TILE,
    STEP_SLOSH,
    STEP_WADE,
    STEP_LADDER,
    STEP_SNOW
};

new const g_tlFail[][MONSTER_TASK_DATA] = {
    { TASK_STOP_MOVING, 0.0 },
    { TASK_SET_ACTIVITY, ACT_IDLE },
    { TASK_WAIT, 2.0 },
    { TASK_WAIT_PVS, 0.0 }
};

new const g_tlIdleStand1[][MONSTER_TASK_DATA] = {
    { TASK_STOP_MOVING, 0.0 },
    { TASK_SET_ACTIVITY, ACT_IDLE },
    { TASK_WAIT, 5.0 }
};

new const g_tlIdleWalk1[][MONSTER_TASK_DATA] = {
    { TASK_WALK_PATH, 9999.0 },
    { TASK_WAIT_FOR_MOVEMENT, 0.0 }
};

new const g_tlAmbush[][MONSTER_TASK_DATA] = {
    { TASK_STOP_MOVING, 0.0 },
    { TASK_SET_ACTIVITY, ACT_IDLE },
    { TASK_WAIT_INDEFINITE, 0.0 }
};

new const g_tlActiveIdle[][MONSTER_TASK_DATA] = {
    { TASK_FIND_HINTNODE, 0.0 },
    { TASK_GET_PATH_TO_HINTNODE, 0.0 },
    { TASK_STORE_LASTPOSITION, 0.0 },
    { TASK_WALK_PATH, 0.0 },
    { TASK_WAIT_FOR_MOVEMENT, 0.0 },
    { TASK_FACE_HINTNODE, 0.0 },
    { TASK_PLAY_ACTIVE_IDLE, 0.0 },
    { TASK_GET_PATH_TO_LASTPOSITION, },
    { TASK_WALK_PATH, 0.0 },
    { TASK_WAIT_FOR_MOVEMENT, 0.0 },
    { TASK_CLEAR_LASTPOSITION, 0.0 },
    { TASK_CLEAR_HINTNODE, 0.0 }
};

new const g_tlWakeAngry1[][MONSTER_TASK_DATA] = {
    { TASK_STOP_MOVING, 0.0 },
    { TASK_SET_ACTIVITY, ACT_IDLE },
    { TASK_SOUND_WAKE, 0.0 },
    { TASK_FACE_IDEAL, 0.0 }
};

new const g_tlAlertFace1[][MONSTER_TASK_DATA] = {
    { TASK_STOP_MOVING, 0.0 },
    { TASK_SET_ACTIVITY, ACT_IDLE },
    { TASK_FACE_IDEAL, 0.0 }
};

new const g_tlAlertSmallFlinch[][MONSTER_TASK_DATA] = {
    { TASK_STOP_MOVING, 0.0 },
    { TASK_REMEMBER, MEMORY_FLINCHED },
    { TASK_SMALL_FLINCH, 0.0 },
    { TASK_SET_SCHEDULE, MONSTER_SCHED_ALERT_FACE }
};

new const g_tlAlertStand1[][MONSTER_TASK_DATA] = {
    { TASK_STOP_MOVING, 0.0 },
    { TASK_SET_ACTIVITY, ACT_IDLE },
    { TASK_WAIT, 20.0 },
    { TASK_SUGGEST_STATE, MONSTER_STATE_IDLE }
};

new const g_tlInvestigateSound[][MONSTER_TASK_DATA] = {
    { TASK_STOP_MOVING, 0.0 },
    { TASK_STORE_LASTPOSITION, 0.0 },
    { TASK_GET_PATH_TO_BESTSOUND, 0.0 },
    { TASK_FACE_IDEAL, 0.0 },
    { TASK_WALK_PATH, 0.0 },
    { TASK_WAIT_FOR_MOVEMENT, 0.0 },
    { TASK_PLAY_SEQUENCE, ACT_IDLE },
    { TASK_WAIT, 10.0 },
    { TASK_GET_PATH_TO_LASTPOSITION, },
    { TASK_WALK_PATH, 0.0 },
    { TASK_WAIT_FOR_MOVEMENT, 0.0 },
    { TASK_CLEAR_LASTPOSITION, 0.0 }
};

new const g_tlCombatStand1[][MONSTER_TASK_DATA] = {
    { TASK_STOP_MOVING, 0.0 },
    { TASK_SET_ACTIVITY, ACT_IDLE },
    { TASK_WAIT_INDEFINITE, 0.0 }
};

new const g_tlCombatFace1[][MONSTER_TASK_DATA] = {
    { TASK_STOP_MOVING, 0.0 },
    { TASK_SET_ACTIVITY, ACT_IDLE },
    { TASK_FACE_ENEMY, 0.0 }
};

new const g_tlStandoff[][MONSTER_TASK_DATA] = {
    { TASK_STOP_MOVING, 0.0 },
    { TASK_SET_ACTIVITY, ACT_IDLE },
    { TASK_WAIT_FACE_ENEMY, 2.0 }
};

new const g_tlArmWeapon[][MONSTER_TASK_DATA] = {
    { TASK_STOP_MOVING, 0.0 },
    { TASK_PLAY_SEQUENCE, ACT_ARM }
};

new const g_tlReload[][MONSTER_TASK_DATA] = {
    { TASK_STOP_MOVING, 0.0 },
    { TASK_PLAY_SEQUENCE, ACT_RELOAD }
};

new const g_tlRangeAttack1[][MONSTER_TASK_DATA] = {
    { TASK_STOP_MOVING, 0.0 },
    { TASK_FACE_ENEMY, 0.0 },
    { TASK_RANGE_ATTACK1, 0.0 }
};

new const g_tlRangeAttack2[][MONSTER_TASK_DATA] = {
    { TASK_STOP_MOVING, 0.0 },
    { TASK_FACE_ENEMY, 0.0 },
    { TASK_RANGE_ATTACK2, 0.0 }
};

new const g_tlPrimaryMeleeAttack1[][MONSTER_TASK_DATA] = {
    { TASK_STOP_MOVING, 0.0 },
    { TASK_FACE_ENEMY, 0.0 },
    { TASK_MELEE_ATTACK1, 0.0 }
};

new const g_tlSecondaryMeleeAttack1[][MONSTER_TASK_DATA] = {
    { TASK_STOP_MOVING, 0.0 },
    { TASK_FACE_ENEMY, 0.0 },
    { TASK_MELEE_ATTACK2, 0.0 }
};

new const g_tlSpecialAttack1[][MONSTER_TASK_DATA] = {
    { TASK_STOP_MOVING, 0.0 },
    { TASK_FACE_ENEMY, 0.0 },
    { TASK_SPECIAL_ATTACK1, 0.0 }
};

new const g_tlSpecialAttack2[][MONSTER_TASK_DATA] = {
    { TASK_STOP_MOVING, 0.0 },
    { TASK_FACE_ENEMY, 0.0 },
    { TASK_SPECIAL_ATTACK2, 0.0 }
};

new const g_tlChaseEnemy1[][MONSTER_TASK_DATA] = {
    { TASK_SET_FAIL_SCHEDULE, MONSTER_SCHED_CHASE_ENEMY_FAILED },
    { TASK_GET_PATH_TO_ENEMY, 0.0 },
    { TASK_RUN_PATH, 0.0 },
    { TASK_WAIT_FOR_MOVEMENT, 0.0 }
};

new const g_tlChaseEnemyFailed[][MONSTER_TASK_DATA] = {
    { TASK_STOP_MOVING, 0.0 },
    { TASK_WAIT, 0.2 },
    { TASK_FIND_COVER_FROM_ENEMY, 0.0 },
    { TASK_RUN_PATH, 0.0 },
    { TASK_WAIT_FOR_MOVEMENT, 0.0 },
    { TASK_REMEMBER, MEMORY_INCOVER },
    { TASK_FACE_ENEMY, 0.0 },
    { TASK_WAIT, 1.0 }
};

new const g_tlSmallFlinch[][MONSTER_TASK_DATA] = {
    { TASK_REMEMBER, MEMORY_FLINCHED },
    { TASK_STOP_MOVING, 0.0 },
    { TASK_SMALL_FLINCH, 0.0 }
};

new const g_tlDie1[][MONSTER_TASK_DATA] = {
    { TASK_STOP_MOVING, 0.0 },
    { TASK_SOUND_DIE, 0.0 },
    { TASK_DIE, 0.0 }
};

new const g_tlVictoryDance[][MONSTER_TASK_DATA] = {
    { TASK_STOP_MOVING, 0.0 },
    { TASK_PLAY_SEQUENCE, ACT_VICTORY_DANCE },
    { TASK_WAIT, 0.0 }
};

new const g_tlBarnacleVictimGrab[][MONSTER_TASK_DATA] = {
    { TASK_STOP_MOVING, 0.0 },
    { TASK_PLAY_SEQUENCE, ACT_BARNACLE_HIT },
    { TASK_SET_ACTIVITY, ACT_BARNACLE_PULL },
    { TASK_WAIT_INDEFINITE, 0.0 },// just cycle barnacle pull anim while barnacle hoists. 
};

new const g_tlBarnacleVictimChomp[][MONSTER_TASK_DATA] = {
    { TASK_STOP_MOVING, 0.0 },
    { TASK_PLAY_SEQUENCE, ACT_BARNACLE_CHOMP },
    { TASK_SET_ACTIVITY, ACT_BARNACLE_CHEW },
    { TASK_WAIT_INDEFINITE, 0.0 },// just cycle barnacle pull anim while barnacle hoists. 
};

new const g_tlError[][MONSTER_TASK_DATA] = {
    { TASK_STOP_MOVING, 0.0 },
    { TASK_WAIT_INDEFINITE, 0.0}
};

new const g_tlScriptedWalk[][MONSTER_TASK_DATA] = {
    { TASK_WALK_TO_TARGET, MONSTER_TARGET_MOVE_SCRIPTED },
    { TASK_WAIT_FOR_MOVEMENT, 0.0 },
    { TASK_PLANT_ON_SCRIPT, 0.0 },
    { TASK_FACE_SCRIPT, 0.0 },
    { TASK_FACE_IDEAL, 0.0 },
    { TASK_ENABLE_SCRIPT, 0.0 },
    { TASK_WAIT_FOR_SCRIPT, 0.0 },
    { TASK_PLAY_SCRIPT, 0.0 }
};

new const g_tlScriptedRun[][MONSTER_TASK_DATA] = {
    { TASK_RUN_TO_TARGET, MONSTER_TARGET_MOVE_SCRIPTED },
    { TASK_WAIT_FOR_MOVEMENT, 0.0 },
    { TASK_PLANT_ON_SCRIPT, 0.0 },
    { TASK_FACE_SCRIPT, 0.0 },
    { TASK_FACE_IDEAL, 0.0 },
    { TASK_ENABLE_SCRIPT, 0.0 },
    { TASK_WAIT_FOR_SCRIPT, 0.0 },
    { TASK_PLAY_SCRIPT, 0.0 }
};

new const g_tlScriptedWait[][MONSTER_TASK_DATA] = {
    { TASK_STOP_MOVING, 0.0 },
    { TASK_WAIT_FOR_SCRIPT, 0.0 },
    { TASK_PLAY_SCRIPT, 0.0 }
};

new const g_tlScriptedFace[][MONSTER_TASK_DATA] = {
    { TASK_STOP_MOVING, 0.0 },
    { TASK_FACE_SCRIPT, 0.0 },
    { TASK_FACE_IDEAL, 0.0 },
    { TASK_WAIT_FOR_SCRIPT, 0.0 },
    { TASK_PLAY_SCRIPT, 0.0 }
};

new const g_tlTakeCoverFromOrigin[][MONSTER_TASK_DATA] = {
    { TASK_STOP_MOVING, 0.0 },
    { TASK_FIND_COVER_FROM_ORIGIN, 0.0 },
    { TASK_RUN_PATH, 0.0 },
    { TASK_WAIT_FOR_MOVEMENT, 0.0 },
    { TASK_REMEMBER, MEMORY_INCOVER },
    { TASK_TURN_LEFT, 179.0 }
};

new const g_tlTakeCoverFromBestSound[][MONSTER_TASK_DATA] = {
    { TASK_STOP_MOVING, 0.0 },
    { TASK_FIND_COVER_FROM_BEST_SOUND, 0.0 },
    { TASK_RUN_PATH, 0.0 },
    { TASK_WAIT_FOR_MOVEMENT, 0.0 },
    { TASK_REMEMBER, MEMORY_INCOVER },
    { TASK_TURN_LEFT, 179.0 }
};

new const g_tlTakeCoverFromEnemy[][MONSTER_TASK_DATA] = {
    { TASK_STOP_MOVING, 0.0 },
    { TASK_WAIT, 0.2 },
    { TASK_FIND_COVER_FROM_ENEMY, 0.0 },
    { TASK_RUN_PATH, 0.0 },
    { TASK_WAIT_FOR_MOVEMENT, 0.0 },
    { TASK_REMEMBER, MEMORY_INCOVER },
    { TASK_FACE_ENEMY, 0.0 },
    { TASK_WAIT, 1.0 }
};

new const g_tlCower[][MONSTER_TASK_DATA] = {
    { TASK_STOP_MOVING, 0.0 },
    { TASK_PLAY_SEQUENCE, ACT_COWER }
};

new Trie:g_itModelEyePosition = Invalid_Trie;
new Trie:g_itModelSequences = Invalid_Trie;

new g_pCvarUseAstar;
new g_pCvarStepSize;

new bool:g_bUseAstar;

new g_pTrace;
new g_pHit = FM_NULLENT;

new Float:g_vecAttackDir[3];

new Float:g_flGameTime = 0.0;

new Struct:g_rgSharedSchedules[MONSTER_SHARED_SCHED] = { _:Invalid_Struct, ... };

new g_rgSounds[MAX_WORLD_SOUNDS][Sound];

public plugin_precache() {
    #if defined _api_navsystem_included
        Nav_Precache();
    #endif

    g_pCvarUseAstar = register_cvar("monster_use_astar", "1");
    g_pCvarStepSize = get_cvar_pointer("sv_stepsize");

    InitSharedSchedules();

    g_pTrace = create_tr2();

    CE_Register(ENTITY_NAME, CEPreset_NPC, true);

    CE_RegisterHook(ENTITY_NAME, CEFunction_Init, "@Monster_Init");
    CE_RegisterHook(ENTITY_NAME, CEFunction_Spawned, "@Monster_Spawned");
    CE_RegisterHook(ENTITY_NAME, CEFunction_Remove, "@Monster_Remove");
    CE_RegisterHook(ENTITY_NAME, CEFunction_Kill, "@Monster_Kill");
    CE_RegisterHook(ENTITY_NAME, CEFunction_Think, "@Monster_Think");

    CE_RegisterVirtualMethod(ENTITY_NAME, TakeDamage, "@Monster_TakeDamage", CE_MP_Cell, CE_MP_Cell, CE_MP_Float, CE_MP_Cell);
    CE_RegisterVirtualMethod(ENTITY_NAME, IgnoreConditions, "@Monster_IgnoreConditions");
    CE_RegisterVirtualMethod(ENTITY_NAME, HandleAnimEvent, "@Monster_HandleAnimEvent", CE_MP_Cell, CE_MP_Array, 64);
    CE_RegisterVirtualMethod(ENTITY_NAME, Classify, "@Monster_Classify");
    CE_RegisterVirtualMethod(ENTITY_NAME, SetState, "@Monster_SetState", CE_MP_Cell);
    CE_RegisterVirtualMethod(ENTITY_NAME, MonsterInit, "@Monster_MonsterInit");
    CE_RegisterVirtualMethod(ENTITY_NAME, SetYawSpeed, "@Monster_SetYawSpeed");
    CE_RegisterMethod(ENTITY_NAME, SetThink, "@Monster_SetThink", CE_MP_String);
    CE_RegisterMethod(ENTITY_NAME, CheckTraceHullAttack, "@Monster_CheckTraceHullAttack", CE_MP_Float, CE_MP_Float, CE_MP_Cell);

    CE_RegisterVirtualMethod(ENTITY_NAME, AlertSound, "@Monster_AlertSound");
    CE_RegisterVirtualMethod(ENTITY_NAME, DeathSound, "@Monster_DeathSound");
    CE_RegisterVirtualMethod(ENTITY_NAME, IdleSound, "@Monster_IdleSound");
    CE_RegisterVirtualMethod(ENTITY_NAME, PainSound, "@Monster_PainSound");
    CE_RegisterVirtualMethod(ENTITY_NAME, ShouldGibMonster, "@Monster_ShouldGibMonster", CE_MP_Cell);
    CE_RegisterVirtualMethod(ENTITY_NAME, CallGibMonster, "@Monster_CallGibMonster");
    CE_RegisterVirtualMethod(ENTITY_NAME, GibMonster, "@Monster_GibMonster");
    CE_RegisterVirtualMethod(ENTITY_NAME, CalculateHitGroupDamage, "@Monster_CalculateHitGroupDamage", CE_MP_Float, CE_MP_Cell);
    CE_RegisterVirtualMethod(ENTITY_NAME, EmitSound, "@Monster_EmitSound", CE_MP_Cell, CE_MP_FloatArray, 3, CE_MP_Cell, CE_MP_Float);

    CE_RegisterVirtualMethod(ENTITY_NAME, MeleeAttack1, "@Monster_MeleeAttack1");
    CE_RegisterVirtualMethod(ENTITY_NAME, MeleeAttack2, "@Monster_MeleeAttack2");

    CE_RegisterVirtualMethod(ENTITY_NAME, IsCurTaskContinuousMove, "@Monster_IsCurTaskContinuousMove");
    CE_RegisterVirtualMethod(ENTITY_NAME, GetScheduleOfType, "@Monster_GetScheduleOfType", CE_MP_Cell);
    CE_RegisterVirtualMethod(ENTITY_NAME, GetSchedule, "@Monster_GetSchedule");
    CE_RegisterVirtualMethod(ENTITY_NAME, SetActivity, "@Monster_SetActivity", CE_MP_Cell);
    CE_RegisterVirtualMethod(ENTITY_NAME, ChangeSchedule, "@Monster_ChangeSchedule", CE_MP_Cell);
    CE_RegisterVirtualMethod(ENTITY_NAME, RunTask, "@Monster_RunTask", CE_MP_Cell, CE_MP_Cell);
    CE_RegisterVirtualMethod(ENTITY_NAME, StartTask, "@Monster_StartTask", CE_MP_Cell, CE_MP_Cell);

    CE_RegisterVirtualMethod(ENTITY_NAME, HandlePathTask, "@Monster_HandlePathTask");
    CE_RegisterVirtualMethod(ENTITY_NAME, MoveExecute, "@Monster_MoveExecute", CE_MP_Cell, CE_MP_FloatArray, 3, CE_MP_Float);

    CE_RegisterMethod(ENTITY_NAME, SetConditions, "@Monster_SetConditions", CE_MP_Cell);
    CE_RegisterMethod(ENTITY_NAME, ClearConditions, "@Monster_ClearConditions", CE_MP_Cell);
    CE_RegisterMethod(ENTITY_NAME, HasConditions, "@Monster_HasConditions", CE_MP_Cell);
    CE_RegisterMethod(ENTITY_NAME, HasAllConditions, "@Monster_HasAllConditions", CE_MP_Cell);
    CE_RegisterMethod(ENTITY_NAME, Remember, "@Monster_Remember", CE_MP_Cell);
    CE_RegisterMethod(ENTITY_NAME, Forget, "@Monster_Forget", CE_MP_Cell);
    CE_RegisterMethod(ENTITY_NAME, HasMemory, "@Monster_HasMemory", CE_MP_Cell);
    CE_RegisterMethod(ENTITY_NAME, HasAllMemory, "@Monster_HasAllMemory", CE_MP_Cell);

    CE_RegisterMethod(ENTITY_NAME, GetSharedSchedule, "@Monster_GetSharedSchedule", CE_MP_Cell);
    CE_RegisterMethod(ENTITY_NAME, MoveToEnemy, "@Monster_MoveToEnemy", CE_MP_Cell, CE_MP_Float);
    CE_RegisterMethod(ENTITY_NAME, MoveToTarget, "@Monster_MoveToTarget", CE_MP_Cell, CE_MP_Float);
    CE_RegisterMethod(ENTITY_NAME, MoveToLocation, "@Monster_MoveToLocation", CE_MP_Cell, CE_MP_Float, CE_MP_FloatArray, 3);
    CE_RegisterMethod(ENTITY_NAME, StepSound, "@Monster_StepSound");
}

@Monster_SetThink(this, const szCallback[]) {
    new iPluginId = -1;
    new iFunctionId = -1;

    if (!equal(szCallback, NULL_STRING)) {
        iPluginId = CE_GetCallPluginId();
        iFunctionId = get_func_id(szCallback, iPluginId);
    }

    CE_SetMember(this, m_iThinkFunctionId, iFunctionId);
    CE_SetMember(this, m_iThinkPluginId, iPluginId);
}

public plugin_init() {
    register_plugin(PLUGIN, VERSION, AUTHOR);

    RegisterHam(Ham_TakeDamage, CE_BASE_CLASSNAME, "HamHook_Base_TakeDamage_Post", .Post = 1);

    bind_pcvar_num(g_pCvarUseAstar, g_bUseAstar);

    RegisterHam(Ham_Classify, CE_BASE_CLASSNAME, "HamHook_Base_Classify", .Post = 0);
    RegisterHam(Ham_TraceAttack, CE_BASE_CLASSNAME, "HamHook_Base_TraceAttack", .Post = 0);
}

public HamHook_Base_Classify(pEntity) {
    if (CE_IsInstanceOf(pEntity, ENTITY_NAME)) {
        new iClass = CE_CallMethod(pEntity, Classify);
        SetHamReturnInteger(iClass);
        return HAM_SUPERCEDE;
    }

    return HAM_IGNORED;
}

@Monster_TraceAttack(this, pAttacker, Float:flDamage, Float:vecDirection[3], pTrace, iDamageBits) {
    static Float:flTakeDamage; pev(this, pev_takedamage, flTakeDamage);
    if (flTakeDamage == DAMAGE_NO) return;

    static iHitGroup; iHitGroup = get_tr2(pTrace, TR_iHitgroup);
    CE_SetMember(this, m_iLastHitGroup, iHitGroup);
}

Float:@Monster_CalculateHitGroupDamage(this, Float:flDamage, iHitGroup) {
    switch (iHitGroup) {
        case HITGROUP_HEAD: return flDamage * 3;
    }

    return flDamage;
}

public HamHook_Base_TraceAttack(pEntity, pAttacker, Float:flDamage, Float:vecDirection[3], pTrace, iDamageBits) {
    if (CE_IsInstanceOf(pEntity, ENTITY_NAME)) {
        @Monster_TraceAttack(pEntity, pAttacker, flDamage, vecDirection, pTrace, iDamageBits);

        static iHitGroup; iHitGroup = get_tr2(pTrace, TR_iHitgroup);

        flDamage = CE_CallMethod(pEntity, CalculateHitGroupDamage, flDamage, iHitGroup);

        SetHamParamFloat(3, flDamage);

        return HAM_HANDLED;
    }

    return HAM_IGNORED;
}

public plugin_end() {
    DestroySharedSchedule();
    free_tr2(g_pTrace);

    if (g_itModelSequences != Invalid_Trie) {
        TrieDestroy(g_itModelSequences);
    }

    if (g_itModelEyePosition != Invalid_Trie) {
        TrieDestroy(g_itModelEyePosition);
    }
}

/*--------------------------------[ Methods ]--------------------------------*/

@Monster_Init(this) {
    g_flGameTime = get_gametime();

    CE_SetMemberVec(this, CE_MEMBER_MINS, Float:{-12.0, -12.0, -32.0});
    CE_SetMemberVec(this, CE_MEMBER_MAXS, Float:{12.0, 12.0, 32.0});

    CE_SetMember(this, m_irgRoute, ArrayCreate(_:MONSTER_WAYPOINT, 8));
    CE_SetMember(this, m_irgOldEnemies, ArrayCreate(_:MONSTER_ENEMY, 8));
    CE_SetMember(this, m_irgSequences, Invalid_Array);

    CE_SetMember(this, m_iHintNode, NO_NODE);
    CE_SetMember(this, m_iMemory, MEMORY_CLEAR);
    CE_SetMember(this, m_pEnemy, FM_NULLENT);
    CE_SetMember(this, m_flDistTooFar, 1024.0);
    CE_SetMember(this, m_flDistLook, 2048.0);
    CE_SetMember(this, m_iTaskStatus, 0);
    CE_SetMember(this, m_iScheduleIndex, 0);
    CE_SetMember(this, m_iDamageType, 0);
    CE_SetMember(this, m_iMovementActivity, 0);
    CE_SetMember(this, m_iRouteIndex, 0);
    CE_SetMember(this, m_iScriptState, 0);
    CE_SetMemberVec(this, m_vecLastPosition, Float:{0.0, 0.0, 0.0});
    CE_SetMember(this, m_flMoveWaitFinished, 0.0);
    CE_SetMember(this, m_flWaitFinished, 0.0);
    CE_SetMember(this, m_pTargetEnt, FM_NULLENT);
    CE_SetMemberVec(this, m_vecMoveGoal, Float:{0.0, 0.0, 0.0});
    CE_SetMemberVec(this, m_vecEnemyLKP, Float:{0.0, 0.0, 0.0});
    CE_SetMember(this, m_pCine, FM_NULLENT);
    CE_SetMember(this, m_iFailSchedule, MONSTER_SCHED_NONE);
    CE_SetMember(this, m_bSequenceFinished, false);
    CE_SetMember(this, m_iActivity, 0);
    CE_SetMember(this, m_iMovementGoal, 0);
    CE_SetMember(this, m_pPathTask, Invalid_NavBuildPathTask);
    CE_SetMember(this, m_flMoveWaitTime, 0.0);
    CE_SetMember(this, m_flHungryTime, 0.0);
    CE_SetMember(this, m_pGoalEnt, FM_NULLENT);

    CE_SetMember(this, m_flFieldOfView, 0.5);
    CE_SetMember(this, m_bSequenceLoops, false);
    CE_SetMember(this, m_flFrameRate, 0.0);
    CE_SetMember(this, m_flGroundSpeed, 0.0);
    CE_SetMember(this, m_sSchedule, Invalid_Struct);
    CE_SetMember(this, m_iCapability, 0);
    CE_SetMember(this, m_irgSequences, Invalid_Array);

    CE_SetMember(this, m_flRangeAttack1Range, 784.0);
    CE_SetMember(this, m_flRangeAttack2Range, 512.0);
    CE_SetMember(this, m_flMeleeAttack1Range, 64.0);
    CE_SetMember(this, m_flMeleeAttack2Range, 64.0);
    CE_SetMember(this, m_flMeleeAttack1Damage, 0.0);
    CE_SetMember(this, m_flMeleeAttack2Damage, 0.0);

    CE_SetMember(this, m_flStepSize, 16.0);

    new iStepSize = max(get_pcvar_num(g_pCvarStepSize), 16);
    CE_SetMember(this, m_flStepHeight, float(iStepSize));
}

@Monster_Spawned(this) {
    g_flGameTime = get_gametime();

    static Array:irgSequences; irgSequences = Invalid_Array;
    static Float:vecEyePosition[3];


    static szModel[MAX_RESOURCE_PATH_LENGTH]; CE_GetMemberString(this, CE_MEMBER_MODEL, szModel, charsmax(szModel));
    if (!equal(szModel, NULL_STRING)) {
        LoadModel(szModel, irgSequences, vecEyePosition);
    }

    CE_SetMember(this, m_irgSequences, irgSequences);
    CE_SetMemberVec(this, m_vecEyePosition, vecEyePosition);

    CE_CallMethod(this, MonsterInit);
}

@Monster_Kill(this, pKiller, iGib) {
    g_flGameTime = get_gametime();

    if (@Monster_HasMemory(this, MEMORY_KILLED)) {
        if (CE_CallMethod(this, ShouldGibMonster, iGib)) {
            CE_CallMethod(this, CallGibMonster);
        }

        return PLUGIN_HANDLED;
    }

    @Monster_Remember(this, MEMORY_KILLED);

    emit_sound(this, CHAN_WEAPON, "common/null.wav", VOL_NORM, ATTN_NORM, 0, PITCH_NORM);
    CE_SetMember(this, m_iIdealMonsterState, MONSTER_STATE_DEAD);
    @Monster_SetConditions(this, COND_LIGHT_DAMAGE);

    // tell owner ( if any ) that we're dead.This is mostly for MonsterMaker functionality.
    // CBaseEntity *pOwner = CBaseEntity::Instance(pev->owner);
    // if ( pOwner ) {
    //     pOwner->DeathNotice( pev );
    // }

    if (CE_CallMethod(this, ShouldGibMonster, iGib)) {
        CE_CallMethod(this, CallGibMonster);
        return PLUGIN_HANDLED;
    } else if (pev(this, pev_flags) & FL_MONSTER) {
        // SetTouch( NULL );
        @Monster_BecomeDead(this);
    }

    CE_SetMember(this, m_iIdealMonsterState, MONSTER_STATE_DEAD);

    return PLUGIN_HANDLED;
}

bool:@Monster_ShouldGibMonster(this, iGib) {
    return false;
}

@Monster_Remove(this) {
    @Monster_RouteNew(this);

    new Array:irgRoute = CE_GetMember(this, m_irgRoute);
    ArrayDestroy(irgRoute);

    new Array:irgOldEnemies = CE_GetMember(this, m_irgOldEnemies);
    ArrayDestroy(irgOldEnemies);
}

@Monster_Think(this) {
    g_flGameTime = get_gametime();

    new iFunctionId = CE_GetMember(this, m_iThinkFunctionId);
    new iPluginId = CE_GetMember(this, m_iThinkPluginId);

    if (iFunctionId == -1 || iPluginId == -1) return;

    callfunc_begin_i(iFunctionId, iPluginId);
    callfunc_push_int(this);
    callfunc_end();
}

@Monster_ResetSequenceInfo(this) {
    static Float:flFrameRate; flFrameRate = 0.0;
    static Float:flGroundSpeed; flGroundSpeed = 0.0;

    @Monster_GetSequenceInfo(this, flFrameRate, flGroundSpeed);
    CE_SetMember(this, m_flFrameRate, flFrameRate);
    CE_SetMember(this, m_flGroundSpeed, flGroundSpeed);

    set_pev(this, pev_animtime, g_flGameTime);
    set_pev(this, pev_framerate, 1.0);
    CE_SetMember(this, m_bSequenceLoops, !!(@Monster_GetSequenceFlags(this) & STUDIO_LOOPING));
    CE_SetMember(this, m_bSequenceFinished, false);
    CE_SetMember(this, m_flLastEventCheck, g_flGameTime);
}

@Monster_GetSequenceInfo(this, &Float:flFrameRate, &Float:flGroundSpeed) {
    static iSequence; iSequence = pev(this, pev_sequence);

    static Array:irgSequences; irgSequences = CE_GetMember(this, m_irgSequences);
    if (irgSequences == Invalid_Array) return;

    if (iSequence >= ArraySize(irgSequences)) {
        flFrameRate = 0.0;
        flGroundSpeed = 0.0;
        return;
    }

    static Float:flFPS; flFPS = ArrayGetCell(irgSequences, iSequence, _:Sequence_FPS);
    static iFramesNum; iFramesNum = ArrayGetCell(irgSequences, iSequence, _:Sequence_FramesNum);

    if (iFramesNum > 1) {
        static Float:vecLinearMovement[3];

        for (new i = 0; i < 3; ++i) {
            vecLinearMovement[i] = ArrayGetCell(irgSequences, iSequence, _:Sequence_LinearMovement + i);
        }

        flFrameRate = UTIL_FrameRateToFrameRatioRate(flFPS, iFramesNum);
        flGroundSpeed = xs_vec_len(vecLinearMovement);
        flGroundSpeed = flGroundSpeed * (flFPS / iFramesNum);
    } else {
        flFrameRate = 255.0;
        flGroundSpeed = 0.0;
    }
}

Float:@Monster_FrameAdvance(this, Float:flInterval) {

    static Float:flAnimTime; pev(this, pev_animtime, flAnimTime);
    static Float:flFrameRate; pev(this, pev_framerate, flFrameRate);
    static Float:flFrame; pev(this, pev_frame, flFrame);

    static Float:flSequenceFrameRate; flSequenceFrameRate = CE_GetMember(this, m_flFrameRate);
    static bool:bSequenceLoops; bSequenceLoops = CE_GetMember(this, m_bSequenceLoops);
    
    if (!flInterval && flAnimTime) {
        flInterval = (g_flGameTime - flAnimTime);
    }

    flFrame += (flSequenceFrameRate * flFrameRate) * flInterval;

    if (flFrame < 0.0 || flFrame > 255.0) {
        if (bSequenceLoops) {
            flFrame = UTIL_FloatMod(flFrame, 255.0);
        } else {
            flFrame = floatclamp(flFrame, 0.0, 255.0);
        }

        CE_SetMember(this, m_bSequenceFinished, true);
    }

    set_pev(this, pev_frame, flFrame);
    set_pev(this, pev_animtime, g_flGameTime);

    return flInterval;
}

@Monster_DispatchAnimEvents(this, Float:flInterval) {
    static Array:irgSequences; irgSequences = CE_GetMember(this, m_irgSequences);
    if (irgSequences == Invalid_Array) return;


    static iSequence; iSequence = pev(this, pev_sequence);

    static Array:irgEvents; irgEvents = Array:ArrayGetCell(irgSequences, iSequence, _:Sequence_Events);
    if (irgEvents == Invalid_Array) return;

    static Float:flFrame; pev(this, pev_frame, flFrame);
    static Float:flFrameRate; pev(this, pev_framerate, flFrameRate);
    static Float:flSequenceFrameRate; flSequenceFrameRate = CE_GetMember(this, m_flFrameRate);

    static Float:flStart; flStart = flFrame - (flSequenceFrameRate * flFrameRate * flInterval);
    static Float:flEnd; flEnd = flFrame;

    CE_SetMember(this, m_flLastEventCheck, g_flGameTime);

    static rgEvent[ModelEvent];

    new iEvent = 0;
    while ((iEvent = @Monster_GetAnimationEvent(this, rgEvent, flStart, flEnd, iEvent)) != 0) {
        CE_CallMethod(this, HandleAnimEvent, rgEvent[ModelEvent_Event], rgEvent[ModelEvent_Options]);
    }
}

@Monster_GetAnimationEvent(this, rgEvent[ModelEvent], Float:flStart, Float:flEnd, iStartOffset) {
    static iSequence; iSequence = pev(this, pev_sequence);
    static Array:irgSequences; irgSequences = CE_GetMember(this, m_irgSequences);

    static Array:irgEvents; irgEvents = Array:ArrayGetCell(irgSequences, iSequence, _:Sequence_Events);
    if (irgEvents == Invalid_Array) return 0;

    static iEventsNum; iEventsNum = ArraySize(irgEvents);
    if (iEventsNum == 0 || iStartOffset > iEventsNum) return 0;

    static iFlags; iFlags = ArrayGetCell(irgSequences, iSequence, _:Sequence_Flags);
    static iFramesNum; iFramesNum = ArrayGetCell(irgSequences, iSequence, _:Sequence_FramesNum);
    static Float:flFramesNum; flFramesNum = float(iFramesNum);

    flStart = UTIL_FrameRatioToFrame(flStart, iFramesNum);
    flEnd = UTIL_FrameRatioToFrame(flEnd, iFramesNum);

    if (iFlags & STUDIO_LOOPING) {
        static Float:flOffset; flOffset = UTIL_FloatMod(floatabs(flStart), (flFramesNum - 1.0));
        static Float:flFixedStart; flFixedStart = flStart;

        if (flStart < 0) {
            flFixedStart = (flFramesNum - 1.0) - flOffset;
        } else if (flStart > (flFramesNum - 1.0)) {
            flFixedStart = 0.0 + flOffset;
        }    

        flEnd += (flFixedStart - flStart);
        flStart = flFixedStart;
    } else {
        // flStart = floatclamp(flStart, 0.0, flFramesNum - 1.0);
        // flEnd = floatclamp(flStart, 0.0, flFramesNum - 1.0);
    }

    static Float:flCurrentFrame; flCurrentFrame = flStart;
    
    do {
        static Float:flNormalizedStart; flNormalizedStart = UTIL_FloatMod(flCurrentFrame, (flFramesNum - 1.0));
        static Float:flNormalizedEnd; flNormalizedEnd = floatmin(flNormalizedStart + (flEnd - flCurrentFrame), flFramesNum - 1.0);

        for (new iEvent = iStartOffset; iEvent < iEventsNum; ++iEvent) {
            static iEventId; iEventId = ArrayGetCell(irgEvents, iEvent, _:ModelEvent_Event);
            if (iEventId >= EVENT_CLIENT) continue;

            static Float:flFrame; flFrame = float(ArrayGetCell(irgEvents, iEvent, _:ModelEvent_Frame));

            if (flFrame < flNormalizedStart) continue;
            if (flFrame > flNormalizedEnd) continue;

            ArrayGetArray(irgEvents, iEvent, rgEvent[any:0], _:ModelEvent);
            return iEvent + 1;
        }

        flCurrentFrame += flNormalizedEnd - flNormalizedStart;
    } while (flCurrentFrame < flEnd);

    return 0;
}

stock Float:UTIL_FrameRateToFrameRatioRate(Float:flFrameRate, iFramesNum) {
    return (flFrameRate / iFramesNum) * 255.0;
}

stock Float:UTIL_FrameToFrameRatio(iFrame, iFramesNum) {
    return 255.0 * ((float(iFrame) + 1.0) / (iFramesNum));
}

stock Float:UTIL_FrameRatioToFrame(Float:flRatio, iFramesNum) {
    return floatmax((flRatio * (float(iFramesNum) / 255.0)) - 1.0, 0.0);
}

@Monster_HandleAnimEvent(this, iEventId, const rgOptions[]) {
    switch (iEventId) {
        case SCRIPT_EVENT_DEAD: {
            if (CE_GetMember(this, m_iMonsterState) == MONSTER_STATE_SCRIPT) {
                set_pev(this, pev_deadflag, DEAD_DYING);
                set_pev(this, pev_health, 0.0);
            }
        }
        case SCRIPT_EVENT_NOT_DEAD: {
            static Float:flMaxHealth; pev(this, pev_max_health, flMaxHealth);

            if (CE_GetMember(this, m_iMonsterState) == MONSTER_STATE_SCRIPT) {
                set_pev(this, pev_deadflag, DEAD_NO);
                set_pev(this, pev_health, flMaxHealth);
            }
        }
        case SCRIPT_EVENT_SOUND: {
            if (!equal(rgOptions, NULL_STRING)) {
                emit_sound(this, CHAN_BODY, rgOptions, VOL_NORM, ATTN_IDLE, 0, PITCH_NORM);
            }
        }

        case SCRIPT_EVENT_SOUND_VOICE: {
            if (!equal(rgOptions, NULL_STRING)) {
                emit_sound(this, CHAN_VOICE, rgOptions, VOL_NORM, ATTN_IDLE, 0, PITCH_NORM);
            }
        }
        case SCRIPT_EVENT_SENTENCE: {
            // TODO: Implement
            if (!equal(rgOptions, NULL_STRING)) {
                // SENTENCEG_PlayRndSz( edict(), rgOptions, VOL_NORM, ATTN_IDLE, 0, PITCH_NORM);
            }
        }
        case SCRIPT_EVENT_FIREEVENT: {
            if (!equal(rgOptions, NULL_STRING)) {
                FireTargets(rgOptions, this, this, USE_TOGGLE, 0.0);
            }
        }
        case SCRIPT_EVENT_NOINTERRUPT: {
            static pCine; pCine = CE_GetMember(this, m_pCine);

            if (pCine != FM_NULLENT) {
                CE_CallMethod(pCine, "AllowInterrupt", false);
            }
        }
        case SCRIPT_EVENT_CANINTERRUPT: {
            static pCine; pCine = CE_GetMember(this, m_pCine);

            if (pCine != FM_NULLENT) {
                CE_CallMethod(pCine, "AllowInterrupt", true);
            }
        }
        case MONSTER_EVENT_BODYDROP_HEAVY:
            if (pev(this, pev_flags) & FL_ONGROUND) {
                if (!random(2)) {
                    emit_sound(this, CHAN_BODY, "common/bodydrop3.wav", VOL_NORM, ATTN_NORM, 0, 90);
                } else {
                    emit_sound(this, CHAN_BODY, "common/bodydrop4.wav", VOL_NORM, ATTN_NORM, 0, 90);
                }
            }

        case MONSTER_EVENT_BODYDROP_LIGHT:
            if (pev(this, pev_flags) & FL_ONGROUND) {
                if (!random(2)) {
                    emit_sound(this, CHAN_BODY, "common/bodydrop3.wav", VOL_NORM, ATTN_NORM, 0, PITCH_NORM);
                } else {
                    emit_sound(this, CHAN_BODY, "common/bodydrop4.wav", VOL_NORM, ATTN_NORM, 0, PITCH_NORM);
                }
            }

        case MONSTER_EVENT_SWISHSOUND: {
            emit_sound(this, CHAN_BODY, "zombie/claw_miss2.wav", VOL_NORM, ATTN_NORM, 0, PITCH_NORM);
        }
    }
}

Float:@Monster_GetPathCost(this, NavArea:newArea, NavArea:prevArea, iMoveFlags) {
    if (prevArea == Invalid_NavArea) return 1.0;

    static Float:vecMins[3]; pev(this, pev_mins, vecMins);

    static pTargetEnt; pTargetEnt = FM_NULLENT;
    if (iMoveFlags & MF_TO_ENEMY) {
        pTargetEnt = CE_GetMember(this, m_pEnemy);
    } else if (iMoveFlags & MF_TO_TARGETENT) {
        pTargetEnt = CE_GetMember(this, m_pTargetEnt);
    }

    static Float:vecSrc[3];
    Nav_Area_GetCenter(prevArea, vecSrc);
    vecSrc[2] += -vecMins[2];

    static Float:vecMiddle[3];
    Nav_Area_GetClosestPointOnArea(newArea, vecSrc, vecMiddle);
    vecMiddle[2] += -vecMins[2];
    
    static Float:vecTarget[3];
    Nav_Area_GetCenter(newArea, vecTarget);
    vecTarget[2] += -vecMins[2];

    static Float:flDist;
    if (@Monster_CheckLocalMove(this, vecSrc, vecMiddle, pTargetEnt, false, flDist) != MONSTER_LOCALMOVE_VALID) {
        return -1.0;
    }

    if (@Monster_CheckLocalMove(this, vecMiddle, vecTarget, pTargetEnt, false, flDist) != MONSTER_LOCALMOVE_VALID) {
        return -1.0;
    }

    static Float:flCost; flCost = get_distance_f(vecSrc, vecTarget);

    return flCost;
}

/*--------------------------------[ Function ]--------------------------------*/

LoadModel(const szModel[], &Array:irgSequences, Float:vecEyePosition[3]) {
    g_itModelSequences = g_itModelSequences == Invalid_Trie ? TrieCreate() : g_itModelSequences;
    g_itModelEyePosition = g_itModelEyePosition == Invalid_Trie ? TrieCreate() : g_itModelEyePosition;

    if (!TrieKeyExists(g_itModelSequences, szModel)) {
        new rgModel[Model]; UTIL_LoadModel(szModel, rgModel);
        TrieSetCell(g_itModelSequences, szModel, rgModel[Model_Sequences]);
        TrieSetArray(g_itModelEyePosition, szModel, rgModel[Model_EyePosition], 3);
    }

    TrieGetCell(g_itModelSequences, szModel, irgSequences);
    TrieGetArray(g_itModelEyePosition, szModel, vecEyePosition, 3);
}

/*--------------------------------[ Hooks ]--------------------------------*/

public HamHook_Base_TakeDamage_Post(pEntity, pInflictor, pAttacker, Float:flDamage, iDamageBits) {
    if (CE_IsInstanceOf(pEntity, ENTITY_NAME)) {
        CE_CallMethod(pEntity, TakeDamage, pInflictor, pAttacker, flDamage, iDamageBits);
        return HAM_SUPERCEDE;
    }

    return HAM_IGNORED;
}

/*--------------------------------[ Callbacks ]--------------------------------*/

#if defined _api_navsystem_included
    public Float:NavPathCost(NavBuildPathTask:pTask, NavArea:newArea, NavArea:prevArea) {
        static pEntity; pEntity = Nav_Path_FindTask_GetUserToken(pTask);
        if (!pEntity) return 1.0;

        return @Monster_GetPathCost(pEntity, newArea, prevArea, MF_TO_ENEMY);
        // return CE_CallMethod(pEntity, GetPathCost, newArea, prevArea);
    }

    public NavPathCallback(NavBuildPathTask:pTask) {
        new pEntity = Nav_Path_FindTask_GetUserToken(pTask);

        return CE_CallMethod(pEntity, HandlePathTask);
    }
#endif

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

    static Float:flDelta; flDelta = UTIL_AngleDiff(flTarget, flValue);

    flValue += floatclamp(flDelta, -flSpeed, flSpeed);

    return UTIL_AngleMod(flValue);
}

stock Float:UTIL_AngleDiff(Float:flDestAngle, Float:flSrcAngle) {
    static Float:flDelta; flDelta = flDestAngle - flSrcAngle;

    if (flDestAngle > flSrcAngle) {
        if (flDelta >= 180.0) {
            flDelta -= 360.0;
        }
    } else {
        if (flDelta <= -180.0) {
            flDelta += 360.0;
        }
    }

    return flDelta;
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

stock Float:UTIL_FloatMod(Float:flValue, Float:flDelimiter) {
    return flValue - (float(floatround(flValue / flDelimiter, floatround_floor)) * flDelimiter);
}

UTIL_LoadModel(const szModel[], rgModel[Model]) {
    new iFile = fopen(szModel, "rb", true, "GAME");

    if (!iFile) {
        iFile = fopen(szModel, "rb", true, "DEFAULTGAME");
    }
    
    if (!iFile) return 0;

    // https://github.com/dreamstalker/rehlds/blob/65c6ce593b5eabf13e92b03352e4b429d0d797b0/rehlds/public/rehlds/studio.h#L68

    fseek(iFile, (BLOCK_INT * 3) + (BLOCK_CHAR * 64), SEEK_SET);

    fread_blocks(iFile, rgModel[Model_EyePosition], 3, BLOCK_INT);

    // Got to "numseq" position of the studiohdr_t structure
    fseek(iFile, 164, SEEK_SET);

    new iSeqNum; fread(iFile, iSeqNum, BLOCK_INT);
    if (!iSeqNum) return 0;

    new iSeqIndex; fread(iFile, iSeqIndex, BLOCK_INT);
    fseek(iFile, iSeqIndex, SEEK_SET);

    rgModel[Model_Sequences] = ArrayCreate(_:Sequence);

    for (new iSequence = 0; iSequence < iSeqNum; iSequence++) {
        new rgSequence[Sequence];
        rgSequence[Sequence_Events] = Invalid_Array;

        fseek(iFile, iSeqIndex + (iSequence * 176) + (BLOCK_CHAR * 32), SEEK_SET);
        fread(iFile, rgSequence[Sequence_FPS], BLOCK_INT);
        fread(iFile, rgSequence[Sequence_Flags], BLOCK_INT);
        fread(iFile, rgSequence[Sequence_Activity], BLOCK_INT);
        fread(iFile, rgSequence[Sequence_ActivityWeight], BLOCK_INT);

        new iNumEvents; fread(iFile, iNumEvents, BLOCK_INT);
        new iEventindex; fread(iFile, iEventindex, BLOCK_INT);

        fread(iFile, rgSequence[Sequence_FramesNum], BLOCK_INT);

        fseek(iFile, BLOCK_INT * 4, SEEK_CUR);

        fread_blocks(iFile, rgSequence[Sequence_LinearMovement], 3, BLOCK_INT);

        if (iNumEvents) {
            rgSequence[Sequence_Events] = ArrayCreate(_:ModelEvent);

            fseek(iFile, iEventindex, SEEK_SET);

            for (new iEvent = 0; iEvent < iNumEvents; iEvent++) {
                new rgEvent[ModelEvent];
                fread(iFile, rgEvent[ModelEvent_Frame], BLOCK_INT);
                fread(iFile, rgEvent[ModelEvent_Event], BLOCK_INT);
                fseek(iFile, BLOCK_INT, SEEK_CUR);
                fread_blocks(iFile, rgEvent[ModelEvent_Options], sizeof(rgEvent[ModelEvent_Options]), BLOCK_CHAR);

                ArrayPushArray(rgSequence[Sequence_Events], rgEvent[any:0]);
            }
        }

        ArrayPushArray(rgModel[Model_Sequences], rgSequence[any:0]);
    }
    
    fclose(iFile);

    return 1;
}

InitSharedSchedules() {
    g_rgSharedSchedules[MONSTER_SHARED_SCHED_WAIT_SCRIPT] = CreateSchedule(g_tlScriptedWait, sizeof(g_tlScriptedWait), SCRIPT_BREAK_CONDITIONS, 0, MONSTER_SHARED_SCHED_WAIT_SCRIPT);
    g_rgSharedSchedules[MONSTER_SHARED_SCHED_WALK_TO_SCRIPT] = CreateSchedule(g_tlScriptedWalk, sizeof(g_tlScriptedWalk), SCRIPT_BREAK_CONDITIONS, 0, MONSTER_SHARED_SCHED_WALK_TO_SCRIPT);
    g_rgSharedSchedules[MONSTER_SHARED_SCHED_RUN_TO_SCRIPT] = CreateSchedule(g_tlScriptedRun, sizeof(g_tlScriptedRun), SCRIPT_BREAK_CONDITIONS, 0, MONSTER_SHARED_SCHED_RUN_TO_SCRIPT);
    g_rgSharedSchedules[MONSTER_SHARED_SCHED_FACE_SCRIPT] = CreateSchedule(g_tlScriptedFace, sizeof(g_tlScriptedFace), SCRIPT_BREAK_CONDITIONS, 0, MONSTER_SHARED_SCHED_FACE_SCRIPT);
    g_rgSharedSchedules[MONSTER_SHARED_SCHED_ERROR] = CreateSchedule(g_tlError, sizeof(g_tlError), 0, 0, MONSTER_SHARED_SCHED_ERROR);

    g_rgSharedSchedules[MONSTER_SHARED_SCHED_ACTIVE_IDLE] = CreateSchedule(
        g_tlActiveIdle,
        sizeof(g_tlActiveIdle),
        (COND_NEW_ENEMY | COND_LIGHT_DAMAGE | COND_HEAVY_DAMAGE | COND_PROVOKED | COND_HEAR_SOUND),
        (SOUND_COMBAT | SOUND_WORLD | SOUND_PLAYER | SOUND_DANGER),
        MONSTER_SHARED_SCHED_ACTIVE_IDLE
    );

    g_rgSharedSchedules[MONSTER_SHARED_SCHED_IDLE_STAND] = CreateSchedule(
        g_tlIdleStand1,
        sizeof(g_tlIdleStand1),
        (COND_NEW_ENEMY | COND_SEE_FEAR | COND_LIGHT_DAMAGE | COND_HEAVY_DAMAGE | COND_HEAR_SOUND | COND_SMELL_FOOD | COND_SMELL | COND_PROVOKED),
        (SOUND_COMBAT | SOUND_WORLD | SOUND_PLAYER | SOUND_DANGER | SOUND_MEAT | SOUND_CARCASS | SOUND_GARBAGE),
        MONSTER_SHARED_SCHED_IDLE_STAND
    );

    g_rgSharedSchedules[MONSTER_SHARED_SCHED_IDLE_WALK] = CreateSchedule(
        g_tlIdleWalk1,
        sizeof(g_tlIdleWalk1),
        (COND_NEW_ENEMY | COND_LIGHT_DAMAGE | COND_HEAVY_DAMAGE | COND_HEAR_SOUND | COND_SMELL_FOOD | COND_SMELL | COND_PROVOKED),
        (SOUND_COMBAT | SOUND_MEAT | SOUND_CARCASS | SOUND_GARBAGE),
        MONSTER_SHARED_SCHED_IDLE_WALK
    );

    g_rgSharedSchedules[MONSTER_SHARED_SCHED_WAIT_TRIGGER] = CreateSchedule(
        g_tlIdleStand1,
        sizeof(g_tlIdleStand1),
        (COND_LIGHT_DAMAGE | COND_HEAVY_DAMAGE),
        0,
        MONSTER_SHARED_SCHED_WAIT_TRIGGER
    );

    g_rgSharedSchedules[MONSTER_SHARED_SCHED_WAKE_ANGRY] = CreateSchedule(g_tlWakeAngry1, sizeof(g_tlWakeAngry1), 0, 0, MONSTER_SHARED_SCHED_WAKE_ANGRY);

    g_rgSharedSchedules[MONSTER_SHARED_SCHED_ALERT_FACE] = CreateSchedule(
        g_tlAlertFace1,
        sizeof(g_tlAlertFace1),
        (COND_NEW_ENEMY | COND_SEE_FEAR | COND_LIGHT_DAMAGE | COND_HEAVY_DAMAGE | COND_PROVOKED),
        0,
        MONSTER_SHARED_SCHED_ALERT_FACE
    );

    g_rgSharedSchedules[MONSTER_SHARED_SCHED_ALERT_STAND] = CreateSchedule(
        g_tlAlertStand1,
        sizeof(g_tlAlertStand1),
        (
            COND_NEW_ENEMY |
            COND_SEE_ENEMY |
            COND_SEE_FEAR |
            COND_LIGHT_DAMAGE |
            COND_HEAVY_DAMAGE |
            COND_PROVOKED |
            COND_SMELL |
            COND_SMELL_FOOD |
            COND_HEAR_SOUND
        ),
        (
            SOUND_COMBAT |
            SOUND_WORLD |
            SOUND_PLAYER |
            SOUND_DANGER |
            SOUND_MEAT |
            SOUND_CARCASS |
            SOUND_GARBAGE
        ),
        MONSTER_SHARED_SCHED_ALERT_STAND
    );

    g_rgSharedSchedules[MONSTER_SHARED_SCHED_COMBAT_STAND] = CreateSchedule(
        g_tlCombatStand1,
        sizeof(g_tlCombatStand1),
        (COND_NEW_ENEMY | COND_ENEMY_DEAD | COND_LIGHT_DAMAGE | COND_HEAVY_DAMAGE | COND_CAN_ATTACK),
        0,
        MONSTER_SHARED_SCHED_COMBAT_STAND
    );

    g_rgSharedSchedules[MONSTER_SHARED_SCHED_COMBAT_FACE] = CreateSchedule(
        g_tlCombatFace1,
        sizeof(g_tlCombatFace1),
        (COND_CAN_ATTACK | COND_NEW_ENEMY | COND_ENEMY_DEAD),
        0,
        MONSTER_SHARED_SCHED_COMBAT_FACE
    );

    g_rgSharedSchedules[MONSTER_SHARED_SCHED_CHASE_ENEMY] = CreateSchedule(
        g_tlChaseEnemy1,
        sizeof(g_tlChaseEnemy1),
        (
            COND_NEW_ENEMY |
            COND_CAN_RANGE_ATTACK1 |
            COND_CAN_MELEE_ATTACK1 |
            COND_CAN_RANGE_ATTACK2 |
            COND_CAN_MELEE_ATTACK2 |
            COND_TASK_FAILED |
            COND_HEAR_SOUND
        ),
        SOUND_DANGER,
        MONSTER_SHARED_SCHED_CHASE_ENEMY
    );

    g_rgSharedSchedules[MONSTER_SHARED_SCHED_FAIL] = CreateSchedule(g_tlFail, sizeof(g_tlFail), COND_CAN_ATTACK, 0, MONSTER_SHARED_SCHED_FAIL);

    g_rgSharedSchedules[MONSTER_SHARED_SCHED_SMALL_FLINCH] = CreateSchedule(g_tlSmallFlinch, sizeof(g_tlSmallFlinch), 0, 0, MONSTER_SHARED_SCHED_SMALL_FLINCH);

    g_rgSharedSchedules[MONSTER_SHARED_SCHED_ALERT_SMALL_FLINCH] = CreateSchedule(g_tlAlertSmallFlinch, sizeof(g_tlAlertSmallFlinch), 0, 0, MONSTER_SHARED_SCHED_ALERT_SMALL_FLINCH);

    g_rgSharedSchedules[MONSTER_SHARED_SCHED_RELOAD] = CreateSchedule(g_tlReload, sizeof(g_tlReload), COND_HEAVY_DAMAGE, 0, MONSTER_SHARED_SCHED_RELOAD);

    g_rgSharedSchedules[MONSTER_SHARED_SCHED_ARM_WEAPON] = CreateSchedule(g_tlArmWeapon, sizeof(g_tlArmWeapon), 0, 0, MONSTER_SHARED_SCHED_ARM_WEAPON);

    g_rgSharedSchedules[MONSTER_SHARED_SCHED_STANDOFF] = CreateSchedule(
        g_tlStandoff,
        sizeof(g_tlStandoff),
        (COND_CAN_RANGE_ATTACK1 | COND_CAN_RANGE_ATTACK2 | COND_ENEMY_DEAD | COND_NEW_ENEMY | COND_HEAR_SOUND),
        SOUND_DANGER,
        MONSTER_SHARED_SCHED_STANDOFF
    );

    g_rgSharedSchedules[MONSTER_SHARED_SCHED_RANGE_ATTACK1] = CreateSchedule(
        g_tlRangeAttack1,
        sizeof(g_tlRangeAttack1),
        (COND_NEW_ENEMY | COND_ENEMY_DEAD | COND_LIGHT_DAMAGE | COND_HEAVY_DAMAGE | COND_ENEMY_OCCLUDED | COND_NO_AMMO_LOADED | COND_HEAR_SOUND),
        SOUND_DANGER,
        MONSTER_SHARED_SCHED_RANGE_ATTACK1
    );

    g_rgSharedSchedules[MONSTER_SHARED_SCHED_RANGE_ATTACK2] = CreateSchedule(
        g_tlRangeAttack2,
        sizeof(g_tlRangeAttack2),
        (COND_NEW_ENEMY | COND_ENEMY_DEAD | COND_LIGHT_DAMAGE | COND_HEAVY_DAMAGE | COND_ENEMY_OCCLUDED | COND_HEAR_SOUND),
        SOUND_DANGER,
        MONSTER_SHARED_SCHED_RANGE_ATTACK2
    );

    g_rgSharedSchedules[MONSTER_SHARED_SCHED_MELEE_ATTACK1] = CreateSchedule(
        g_tlPrimaryMeleeAttack1,
        sizeof(g_tlPrimaryMeleeAttack1),
        (COND_NEW_ENEMY | COND_ENEMY_DEAD | COND_LIGHT_DAMAGE | COND_HEAVY_DAMAGE | COND_ENEMY_OCCLUDED),
        0,
        MONSTER_SHARED_SCHED_MELEE_ATTACK1
    );

    g_rgSharedSchedules[MONSTER_SHARED_SCHED_MELEE_ATTACK2] = CreateSchedule(
        g_tlSecondaryMeleeAttack1,
        sizeof(g_tlSecondaryMeleeAttack1),
        (COND_NEW_ENEMY | COND_ENEMY_DEAD | COND_LIGHT_DAMAGE | COND_HEAVY_DAMAGE | COND_ENEMY_OCCLUDED),
        0,
        MONSTER_SHARED_SCHED_MELEE_ATTACK2
    );

    g_rgSharedSchedules[MONSTER_SHARED_SCHED_SPECIAL_ATTACK1] = CreateSchedule(
        g_tlSpecialAttack1,
        sizeof(g_tlSpecialAttack1),
        (COND_NEW_ENEMY | COND_ENEMY_DEAD | COND_LIGHT_DAMAGE | COND_HEAVY_DAMAGE | COND_ENEMY_OCCLUDED | COND_NO_AMMO_LOADED | COND_HEAR_SOUND),
        SOUND_DANGER,
        MONSTER_SHARED_SCHED_SPECIAL_ATTACK1
    );

    g_rgSharedSchedules[MONSTER_SHARED_SCHED_SPECIAL_ATTACK2] = CreateSchedule(
        g_tlSpecialAttack2,
        sizeof(g_tlSpecialAttack2),
        (COND_NEW_ENEMY | COND_ENEMY_DEAD | COND_LIGHT_DAMAGE | COND_HEAVY_DAMAGE | COND_ENEMY_OCCLUDED | COND_NO_AMMO_LOADED | COND_HEAR_SOUND),
        SOUND_DANGER,
        MONSTER_SHARED_SCHED_SPECIAL_ATTACK2
    );

    g_rgSharedSchedules[MONSTER_SHARED_SCHED_TAKE_COVER_FROM_BEST_SOUND] = CreateSchedule(g_tlTakeCoverFromBestSound, sizeof(g_tlTakeCoverFromBestSound), COND_NEW_ENEMY, 0, MONSTER_SHARED_SCHED_TAKE_COVER_FROM_BEST_SOUND);

    g_rgSharedSchedules[MONSTER_SHARED_SCHED_TAKE_COVER_FROM_ENEMY] = CreateSchedule(g_tlTakeCoverFromEnemy, sizeof(g_tlTakeCoverFromEnemy), COND_NEW_ENEMY, SOUND_DANGER, MONSTER_SHARED_SCHED_TAKE_COVER_FROM_ENEMY);

    g_rgSharedSchedules[MONSTER_SHARED_SCHED_COWER] = CreateSchedule(g_tlCower, sizeof(g_tlCower), 0, 0, MONSTER_SHARED_SCHED_COWER);

    g_rgSharedSchedules[MONSTER_SHARED_SCHED_AMBUSH] = CreateSchedule(
        g_tlAmbush,
        sizeof(g_tlAmbush),
        (COND_NEW_ENEMY | COND_LIGHT_DAMAGE | COND_HEAVY_DAMAGE | COND_PROVOKED),
        0,
        MONSTER_SHARED_SCHED_AMBUSH
    );

    g_rgSharedSchedules[MONSTER_SHARED_SCHED_BARNACLE_VICTIM_GRAB] = CreateSchedule(g_tlBarnacleVictimGrab, sizeof(g_tlBarnacleVictimGrab), 0, 0, MONSTER_SHARED_SCHED_BARNACLE_VICTIM_GRAB);

    g_rgSharedSchedules[MONSTER_SHARED_SCHED_BARNACLE_VICTIM_CHOMP] = CreateSchedule(g_tlBarnacleVictimChomp, sizeof(g_tlBarnacleVictimChomp), 0, 0, MONSTER_SHARED_SCHED_BARNACLE_VICTIM_CHOMP);

    g_rgSharedSchedules[MONSTER_SHARED_SCHED_INVESTIGATE_SOUND] = CreateSchedule(
        g_tlInvestigateSound,
        sizeof(g_tlInvestigateSound),
        (COND_NEW_ENEMY | COND_SEE_FEAR | COND_LIGHT_DAMAGE | COND_HEAVY_DAMAGE | COND_HEAR_SOUND),
        SOUND_DANGER,
        MONSTER_SHARED_SCHED_INVESTIGATE_SOUND
    );

    g_rgSharedSchedules[MONSTER_SHARED_SCHED_DIE] = CreateSchedule(g_tlDie1, sizeof(g_tlDie1), 0, 0, MONSTER_SHARED_SCHED_DIE);

    g_rgSharedSchedules[MONSTER_SHARED_SCHED_TAKE_COVER_FROM_ORIGIN] = CreateSchedule(g_tlTakeCoverFromOrigin, sizeof(g_tlTakeCoverFromOrigin), COND_NEW_ENEMY, 0, MONSTER_SHARED_SCHED_TAKE_COVER_FROM_ORIGIN);

    g_rgSharedSchedules[MONSTER_SHARED_SCHED_VICTORY_DANCE] = CreateSchedule(g_tlVictoryDance, sizeof(g_tlVictoryDance), 0, 0, MONSTER_SHARED_SCHED_VICTORY_DANCE);

    g_rgSharedSchedules[MONSTER_SHARED_SCHED_CHASE_ENEMY_FAILED] = CreateSchedule(
        g_tlChaseEnemyFailed,
        sizeof(g_tlChaseEnemyFailed),
        (COND_NEW_ENEMY | COND_CAN_RANGE_ATTACK1 | COND_CAN_MELEE_ATTACK1 | COND_CAN_RANGE_ATTACK2 | COND_CAN_MELEE_ATTACK2 | COND_HEAR_SOUND),
        0,
        MONSTER_SHARED_SCHED_CHASE_ENEMY_FAILED
    );
}

DestroySharedSchedule() {
    for (new MONSTER_SHARED_SCHED:iSchedule = MONSTER_SHARED_SCHED:0; iSchedule < MONSTER_SHARED_SCHED; ++iSchedule) {
        if (g_rgSharedSchedules[iSchedule] == Invalid_Struct) continue;
        StructDestroy(g_rgSharedSchedules[iSchedule]);
    }
}

Struct:_GetSharedSchedule(MONSTER_SHARED_SCHED:iSchedule) {
    return g_rgSharedSchedules[iSchedule];
}

Struct:@Monster_GetSharedSchedule(this, MONSTER_SHARED_SCHED:iSchedule) {
    return _GetSharedSchedule(iSchedule); 
}

Struct:CreateSchedule(const rgTask[][MONSTER_TASK_DATA], iSize, iInterruptMask, iSoundMask, MONSTER_SHARED_SCHED:iSharedId = MONSTER_SHARED_SCHED_INVALID) {
    new Struct:sSchedule = StructCreate(MONSTER_SCHEDULE_DATA);
    StructSetCell(sSchedule, MONSTER_SCHEDULE_DATA_SHARED_ID, iSharedId);
    StructSetArray(sSchedule, MONSTER_SCHEDULE_DATA_TASK, rgTask[0], _:MONSTER_TASK_DATA * iSize);
    StructSetCell(sSchedule, MONSTER_SCHEDULE_DATA_TASK_SIZE, iSize);
    StructSetCell(sSchedule, MONSTER_SCHEDULE_DATA_INTERRUPT_MASK, iInterruptMask);
    StructSetCell(sSchedule, MONSTER_SCHEDULE_DATA_SOUND_MASK, iSoundMask);

    return sSchedule;
}

@Monster_RunAI(this) {
    static MONSTER_STATE:iMonsterState; iMonsterState = CE_GetMember(this, m_iMonsterState);

    if (
        (iMonsterState == MONSTER_STATE_IDLE || iMonsterState == MONSTER_STATE_ALERT) &&
        !random(99) && !(pev(this, pev_flags) & SF_MONSTER_GAG)
    ) {
        CE_CallMethod(this, IdleSound);
    }

    if (
        iMonsterState != MONSTER_STATE_NONE && 
        iMonsterState != MONSTER_STATE_PRONE && 
        iMonsterState != MONSTER_STATE_DEAD
    ) {
        if (engfunc(EngFunc_FindClientInPVS, this) || (iMonsterState == MONSTER_STATE_COMBAT)) {
            @Monster_Look(this, Float:CE_GetMember(this, m_flDistLook));
            @Monster_Listen(this);
            @Monster_ClearConditions(this, CE_CallMethod(this, IgnoreConditions));
            @Monster_GetEnemy(this);
        }

        static pEnemy; pEnemy = CE_GetMember(this, m_pEnemy);
        if (pEnemy != FM_NULLENT) {
            @Monster_CheckEnemy(this, pEnemy);
        }

        @Monster_CheckAmmo(this);
    }

    @Monster_CheckAITrigger(this);
    @Monster_PrescheduleThink(this);
    @Monster_MaintainSchedule(this);

    CE_SetMember(this, m_iConditions, CE_GetMember(this, m_iConditions) & ~(COND_LIGHT_DAMAGE | COND_HEAVY_DAMAGE));
}

@Monster_CheckAmmo(this) {
    // Nothing
}

@Monster_MaintainSchedule(this) {
    for (new i = 0; i < 10; ++i) {
        static Struct:sSchedule; sSchedule = CE_GetMember(this, m_sSchedule);

        if (sSchedule != Invalid_Struct && @Monster_TaskIsComplete(this)) {
            @Monster_NextScheduledTask(this);
        }

        static MONSTER_STATE:iMonsterState; iMonsterState = CE_GetMember(this, m_iMonsterState);
        static MONSTER_STATE:iIdealMonsterState; iIdealMonsterState = CE_GetMember(this, m_iIdealMonsterState);

        if (!@Monster_ScheduleValid(this) || iMonsterState != iIdealMonsterState) {
            @Monster_ScheduleChange(this);

            static pEnemy; pEnemy = CE_GetMember(this, m_pEnemy);
            static iConditions; iConditions = @Monster_ScheduleFlags(this);

            if (
                iIdealMonsterState != MONSTER_STATE_DEAD && 
                (iIdealMonsterState != MONSTER_STATE_SCRIPT || iIdealMonsterState == iMonsterState)
            ) {
                if (
                    (iConditions && !@Monster_HasConditions(this, COND_SCHEDULE_DONE)) ||
                    (sSchedule && (StructGetCell(sSchedule, MONSTER_SCHEDULE_DATA_INTERRUPT_MASK) & COND_SCHEDULE_DONE)) ||
                    ((iMonsterState == MONSTER_STATE_COMBAT) && (pEnemy == FM_NULLENT))
                ) {
                    iIdealMonsterState = @Monster_GetIdealState(this);
                }
            }

            static Struct:pNewSchedule; pNewSchedule = Invalid_Struct;

            if (@Monster_HasConditions(this, COND_TASK_FAILED) && iMonsterState == iIdealMonsterState) {
                static MONSTER_SCHEDULE_TYPE:iFailSchedule; iFailSchedule = CE_GetMember(this, m_iFailSchedule);
                pNewSchedule = CE_CallMethod(this, GetScheduleOfType, iFailSchedule != MONSTER_SCHED_NONE ? iFailSchedule : MONSTER_SCHED_FAIL);
            } else {
                @Monster_SetState(this, iIdealMonsterState);

                pNewSchedule = CE_CallMethod(this, GetSchedule);
            }

            CE_CallMethod(this, ChangeSchedule, pNewSchedule);
        }

        static MONSTER_TASK_STATUS:iTaskStatus; iTaskStatus = CE_GetMember(this, m_iTaskStatus);

        if (iTaskStatus == MONSTER_TASK_STATUS_NEW) {
            static rgTask[MONSTER_TASK_DATA];
            if (@Monster_GetTask(this, rgTask) == -1) return;

            @Monster_TaskBegin(this);
            CE_CallMethod(this, StartTask, rgTask[MONSTER_TASK_DATA_ID], rgTask[MONSTER_TASK_DATA_DATA]);
        }

        static Activity:iActivity; iActivity = CE_GetMember(this, m_iActivity);
        static Activity:iIdealActivity; iIdealActivity = CE_GetMember(this, m_iIdealActivity);

        if (iActivity != iIdealActivity) {
            CE_CallMethod(this, SetActivity, iIdealActivity);
        }
        
        if (!@Monster_TaskIsComplete(this) && iTaskStatus != MONSTER_TASK_STATUS_NEW) break;
    }

    if (@Monster_TaskIsRunning(this)) {
        static rgTask[MONSTER_TASK_DATA];
        if (@Monster_GetTask(this, rgTask) == -1) return;

        CE_CallMethod(this, RunTask, rgTask[MONSTER_TASK_DATA_ID], rgTask[MONSTER_TASK_DATA_DATA]);

        // CE_CallMethod(this, RunTaskOverlay);
    }

    static Activity:iActivity; iActivity = CE_GetMember(this, m_iActivity);
    static Activity:iIdealActivity; iIdealActivity = CE_GetMember(this, m_iIdealActivity);

    if (iActivity != iIdealActivity) {
        CE_CallMethod(this, SetActivity, iIdealActivity);
    }
}

// @Monster_StartTaskOverlay(this) {}
// @Monster_RunTaskOverlay(this) {}

@Monster_MonsterInit(this) {
    static Float:vecAngles[3]; pev(this, pev_angles, vecAngles);
    static Float:flHealth; pev(this, pev_health, flHealth);

    set_pev(this, pev_rendermode, kRenderNormal);
    set_pev(this, pev_renderamt, 255.0);
    set_pev(this, pev_effects, 0);
    set_pev(this, pev_takedamage, DAMAGE_AIM);
    set_pev(this, pev_ideal_yaw, vecAngles[1]);
    set_pev(this, pev_max_health, flHealth);
    set_pev(this, pev_deadflag, DEAD_NO);
    set_pev(this, pev_flags, pev(this, pev_flags) | FL_MONSTER);

    if (pev(this, pev_spawnflags) & SF_MONSTER_HITMONSTERCLIP) {
        set_pev(this, pev_flags, pev(this, pev_flags) | FL_MONSTERCLIP);
    }
    
    CE_SetMember(this, m_iIdealMonsterState, MONSTER_STATE_IDLE);
    CE_SetMember(this, m_iIdealActivity, ACT_IDLE);
    CE_SetMember(this, m_iHintNode, NO_NODE);
    CE_SetMember(this, m_iMemory, MEMORY_CLEAR);
    CE_SetMember(this, m_pEnemy, FM_NULLENT);
    CE_SetMember(this, m_iDamageType, 0);
    CE_SetMember(this, m_iMovementActivity, 0);
    CE_SetMember(this, m_iScriptState, 0);
    CE_SetMemberVec(this, m_vecLastPosition, Float:{0.0, 0.0, 0.0});
    CE_SetMember(this, m_flMoveWaitFinished, 0.0);
    CE_SetMember(this, m_flWaitFinished, 0.0);
    CE_SetMember(this, m_pTargetEnt, FM_NULLENT);
    CE_SetMemberVec(this, m_vecMoveGoal, Float:{0.0, 0.0, 0.0});
    CE_SetMemberVec(this, m_vecEnemyLKP, Float:{0.0, 0.0, 0.0});
    CE_SetMember(this, m_pCine, FM_NULLENT);
    CE_SetMember(this, m_bSequenceFinished, false);
    CE_SetMember(this, m_iActivity, 0);
    CE_SetMember(this, m_iMovementGoal, MOVEGOAL_NONE);
    CE_SetMember(this, m_flMoveWaitTime, 0.0);
    CE_SetMember(this, m_flHungryTime, 0.0);
    CE_SetMember(this, m_pGoalEnt, FM_NULLENT);
    CE_SetMember(this, m_bSequenceLoops, false);
    CE_SetMember(this, m_flFrameRate, 0.0);
    CE_SetMember(this, m_flGroundSpeed, 0.0);
    CE_SetMember(this, m_iCapability, 0);

    @Monster_ClearSchedule(this);
    @Monster_RouteClear(this);
    @Monster_InitBoneControllers(this);

    @Monster_SetEyePosition(this);

    set_pev(this, pev_nextthink, g_flGameTime + 0.1);
    // SetUse ( &CBaseMonster::MonsterUse );

    CE_CallMethod(this, SetThink, "@Monster_MonsterInitThink");
}

@Monster_MonsterInitThink(this) {
    @Monster_StartMonster(this);
}

@Monster_InitBoneControllers(this) {
    set_controller(this, 0, 0.0);
    set_controller(this, 1, 0.0);
    set_controller(this, 2, 0.0);
    set_controller(this, 3, 0.0);
}


@Monster_SetEyePosition(this) {
    static Float:vecEyePosition[3]; CE_GetMemberVec(this, m_vecEyePosition, vecEyePosition);

    set_pev(this, pev_view_ofs, vecEyePosition);
}

@Monster_StartMonster(this) {
    new iCapability = CE_GetMember(this, m_iCapability);

    if (@Monster_LookupActivity(this, ACT_RANGE_ATTACK1) != ACTIVITY_NOT_AVAILABLE) {
        CE_SetMember(this, m_iCapability, iCapability | CAP_RANGE_ATTACK1);
    }

    if (@Monster_LookupActivity(this, ACT_RANGE_ATTACK2) != ACTIVITY_NOT_AVAILABLE) {
        CE_SetMember(this, m_iCapability, iCapability | CAP_RANGE_ATTACK2);
    }

    if (@Monster_LookupActivity(this, ACT_MELEE_ATTACK1) != ACTIVITY_NOT_AVAILABLE) {
        CE_SetMember(this, m_iCapability, iCapability | CAP_MELEE_ATTACK1);
    }

    if (@Monster_LookupActivity(this, ACT_MELEE_ATTACK2) != ACTIVITY_NOT_AVAILABLE) {
        CE_SetMember(this, m_iCapability, iCapability | CAP_MELEE_ATTACK2);
    }

    if (pev(this, pev_movetype) != MOVETYPE_FLY && !(pev(this, pev_spawnflags) & SF_MONSTER_FALL_TO_GROUND)) {
        static Float:vecOrigin[3]; pev(this, pev_origin, vecOrigin);

        vecOrigin[2] += 1.0;
        set_pev(this, pev_origin, vecOrigin);

        engfunc(EngFunc_DropToFloor, this);
        
        // if (!engfunc(EngFunc_WalkMove, this, 0.0, 0.0, WALKMOVE_NORMAL)) {
        //     set_pev(this, pev_effects, EF_BRIGHTFIELD);
        // }
    } else {
        set_pev(this, pev_flags, pev(this, pev_flags) & ~FL_ONGROUND);
    }

    static szTarget[32]; pev(this, pev_target, szTarget, charsmax(szTarget));
    
    if (!equal(szTarget, NULL_STRING)) {
        new pGoalEnt = engfunc(EngFunc_FindEntityByString, 0, "targetname", szTarget);

        CE_SetMember(this, m_pGoalEnt, pGoalEnt);

        if (pGoalEnt) {
            new Float:vecGoal[3]; pev(this, pev_origin, vecGoal);
            @Monster_MakeIdealYaw(this, vecGoal);

            CE_SetMember(this, m_iMovementGoal, MOVEGOAL_PATHCORNER);
            
            if (pev(this, pev_movetype) == MOVETYPE_FLY) {
                CE_SetMember(this, m_iMovementActivity, ACT_FLY);
            } else {
                CE_SetMember(this, m_iMovementActivity, ACT_WALK);
            }

            @Monster_RefreshRoute(this);

            @Monster_SetState(this, MONSTER_STATE_IDLE);
            CE_CallMethod(this, ChangeSchedule, CE_CallMethod(this, GetScheduleOfType, MONSTER_SCHED_IDLE_WALK));
        }
    }
    
    CE_CallMethod(this, SetThink, "@Monster_MonsterThink");

    static szTargetname[32]; pev(this, pev_targetname, szTargetname, charsmax(szTargetname));

    if (!equal(szTargetname, NULL_STRING)) {
        @Monster_SetState(this, MONSTER_STATE_IDLE);
        CE_CallMethod(this, SetActivity, ACT_IDLE);
        CE_CallMethod(this, ChangeSchedule, CE_CallMethod(this, GetScheduleOfType, MONSTER_SCHED_WAIT_TRIGGER));
    }

    set_pev(this, pev_nextthink, g_flGameTime + random_float(0.1, 0.4));
}

@Monster_MonsterInitDead(this) {
    @Monster_InitBoneControllers(this);

    set_pev(this, pev_solid, SOLID_BBOX);
    set_pev(this, pev_movetype, MOVETYPE_TOSS);

    set_pev(this, pev_frame, 0.0);
    @Monster_ResetSequenceInfo(this);
    set_pev(this, pev_framerate, 0.0);

    static Float:flHealth; pev(this, pev_health, flHealth);
    set_pev(this, pev_max_health, flHealth);

    set_pev(this, pev_deadflag, DEAD_DEAD);

    engfunc(EngFunc_SetSize, this, Float:{0.0, 0.0, 0.0}, Float:{0.0, 0.0, 0.0});

    static Float:vecOrigin[3]; pev(this, pev_origin, vecOrigin);
    engfunc(EngFunc_SetOrigin, this, vecOrigin);

    @Monster_BecomeDead(this);

    CE_CallMethod(this, SetThink, "@Monster_CorpseFallThink");

    set_pev(this, pev_nextthink, g_flGameTime + 0.5);
}

@Monster_BecomeDead(this) {
    static Float:flMaxHealth; pev(this, pev_max_health, flMaxHealth);

    set_pev(this, pev_takedamage, DAMAGE_YES);

    set_pev(this, pev_health, flMaxHealth / 2);
    set_pev(this, pev_max_health, 5.0);
    set_pev(this, pev_movetype, MOVETYPE_TOSS);
}

@Monster_CorpseFallThink(this) {
    if (pev(this, pev_flags) & FL_ONGROUND) {
        CE_CallMethod(this, SetThink, NULL_STRING);

        static Float:vecOrigin[3]; pev(this, pev_origin, vecOrigin);
        engfunc(EngFunc_SetOrigin, this, vecOrigin);
    } else {
        set_pev(this, pev_nextthink, g_flGameTime + 0.1);
    }
}

@Monster_MonsterThink(this) {
    static Float:flLTime; pev(this, pev_ltime, flLTime);

    set_pev(this, pev_nextthink, g_flGameTime + 0.01);
    set_pev(this, pev_ltime, g_flGameTime);

    @Monster_RunAI(this);

    static Float:flInterval; flInterval = @Monster_FrameAdvance(this, 0.0);
    static MONSTER_STATE:iMonsterState; iMonsterState = CE_GetMember(this, m_iMonsterState);
    static Activity:iActivity; iActivity = CE_GetMember(this, m_iActivity);
    static bool:bSequenceFinished; bSequenceFinished = CE_GetMember(this, m_bSequenceFinished);
    static bool:bSequenceLoops; bSequenceLoops = CE_GetMember(this, m_bSequenceLoops);

    if (iMonsterState != MONSTER_STATE_SCRIPT && iMonsterState != MONSTER_STATE_DEAD && iActivity == ACT_IDLE && bSequenceFinished) {
        static Activity:iSequence; iSequence = ACTIVITY_NOT_AVAILABLE;

        if (bSequenceLoops) {
            iSequence = @Monster_LookupActivity(this, iActivity);
        } else {
            iSequence = @Monster_LookupActivityHeaviest(this, iActivity);
        }

        if (iSequence != ACTIVITY_NOT_AVAILABLE) {
            set_pev(this, pev_sequence, iSequence);
            @Monster_ResetSequenceInfo(this);
        }
    }

    @Monster_DispatchAnimEvents(this, flInterval);

    if (!@Monster_MovementIsComplete(this)) {
        @Monster_Move(this, flInterval);
    }
}

stock bool:UTIL_BoxIntersects(const Float:vecMin[3], const Float:vecMax[3], const Float:vecOtherMin[3], const Float:vecOtherMax[3]) {
    for (new i = 0; i < 3; ++i) {
        if (vecMin[i] > vecOtherMax[i]) return false;
        if (vecMax[i] < vecOtherMin[i]) return false;
    }

    return true;
}

stock UTIL_FindEntityInBox(pStartEdict, const Float:vecBoxMin[3], const Float:vecBoxMax[3]) {
    static iMaxEntities = 0;
    if (!iMaxEntities) {
        iMaxEntities = global_get(glb_maxEntities);
    }

    for (new pEntity = max(pStartEdict + 1, 1); pEntity < iMaxEntities; ++pEntity) {
        if (pEntity <= 0) continue;
        if (!pev_valid(pEntity)) continue;

        static Float:vecAbsMin[3]; pev(pEntity, pev_absmin, vecAbsMin);
        static Float:vecAbsMax[3]; pev(pEntity, pev_absmax, vecAbsMax);

        if (UTIL_BoxIntersects(vecBoxMin, vecBoxMax, vecAbsMin, vecAbsMax)) {
            return pEntity;
        }
    }

    return FM_NULLENT;
}

@Monster_Look(this, Float:flDistance) {
    new iSighted = 0;

    @Monster_ClearConditions(this, COND_SEE_HATE | COND_SEE_DISLIKE | COND_SEE_ENEMY | COND_SEE_FEAR | COND_SEE_NEMESIS | COND_SEE_CLIENT);

    static pLink; pLink = FM_NULLENT;

    if (~pev(this, pev_spawnflags) & SF_MONSTER_PRISONER) {
        static Float:vecOrigin[3]; pev(this, pev_origin, vecOrigin);
        static Float:vecDelta[3]; xs_vec_set(vecDelta, flDistance, flDistance, flDistance);
        static Float:vecAbsMin[3]; xs_vec_sub(vecOrigin, vecDelta, vecAbsMin);
        static Float:vecAbsMax[3]; xs_vec_add(vecOrigin, vecDelta, vecAbsMax);

        static pSightEnt; pSightEnt = FM_NULLENT;
        while ((pSightEnt = UTIL_FindEntityInBox(pSightEnt, vecAbsMin, vecAbsMax)) != FM_NULLENT) {
            if (pSightEnt == this) continue;
            if (!(pev(pSightEnt, pev_flags) & (FL_CLIENT | FL_MONSTER))) continue;
            if (pev(pSightEnt, pev_spawnflags) & SF_MONSTER_PRISONER) continue;

            static Float:flSightHealth; pev(pSightEnt, pev_health, flSightHealth);
            if (flSightHealth <= 0) continue;

            if (@Monster_Relationship(this, pSightEnt) == R_NO) continue;
            if (!ExecuteHamB(Ham_FInViewCone, this, pSightEnt)) continue;
            if (pev(pSightEnt, pev_flags) & FL_NOTARGET) continue;
            if (!ExecuteHamB(Ham_FVisible, this, pSightEnt)) continue;

            if (ExecuteHamB(Ham_IsPlayer, pSightEnt)) {
                static iSpawnFlags; iSpawnFlags = pev(this, pev_spawnflags);

                if (iSpawnFlags & SF_MONSTER_WAIT_TILL_SEEN) {
                    if (pSightEnt && !ExecuteHamB(Ham_FInViewCone, pSightEnt, this)) continue; 

                    set_pev(this, pev_spawnflags, iSpawnFlags & ~SF_MONSTER_WAIT_TILL_SEEN);
                }

                iSighted |= COND_SEE_CLIENT;
            }

            set_ent_data_entity(pSightEnt, "CBaseEntity", "m_pLink", pLink);
            set_ent_data_entity(this, "CBaseEntity", "m_pLink", pSightEnt);

            if (pSightEnt == CE_GetMember(this, m_pEnemy)) {
                iSighted |= COND_SEE_ENEMY;
            }

            switch (@Monster_Relationship(this, pSightEnt)) {
                case R_NM: iSighted |= COND_SEE_NEMESIS;
                case R_HT: iSighted |= COND_SEE_HATE;
                case R_DL: iSighted |= COND_SEE_DISLIKE;
                case R_FR: iSighted |= COND_SEE_FEAR;
            }
        }
    }

    @Monster_SetConditions(this, iSighted);
}

@Monster_Listen(this) {
    @Monster_ClearConditions(this, COND_HEAR_SOUND | COND_SMELL | COND_SMELL_FOOD);

    static Float:vecEarPosition[3]; ExecuteHamB(Ham_EarPosition, this, vecEarPosition);
    static Float:flHearingSensitivity; flHearingSensitivity = @Monster_HearingSensitivity(this);

    static iMySounds; iMySounds = @Monster_SoundMask(this);

    static Struct:sSchedule; sSchedule = CE_GetMember(this, m_sSchedule);
    if (sSchedule != Invalid_Struct) {
        iMySounds &= StructGetCell(sSchedule, MONSTER_SCHEDULE_DATA_SOUND_MASK);
    }

    new iSoundTypes = 0;

    for (new iSound = 0; iSound < sizeof(g_rgSounds); ++iSound) {
        if (g_rgSounds[iSound][Sound_ExpiredTime] <= g_flGameTime) continue;

        if (
            (g_rgSounds[iSound][Sound_Type] & iMySounds) && 
            xs_vec_distance(vecEarPosition, g_rgSounds[iSound][Sound_Origin]) <= (g_rgSounds[iSound][Sound_Volume] * flHearingSensitivity)
        ) {
            if (@Sound_IsSound(iSound)) {
                @Monster_SetConditions(this, COND_HEAR_SOUND);
            } else {
                if (g_rgSounds[iSound][Sound_Type] & (SOUND_MEAT | SOUND_CARCASS)) {
                    @Monster_SetConditions(this, COND_SMELL_FOOD);
                    @Monster_SetConditions(this, COND_SMELL);
                } else {
                    @Monster_SetConditions(this, COND_SMELL);
                }
            }

            iSoundTypes |= g_rgSounds[iSound][Sound_Type];
        }
    }

    CE_SetMember(this, m_iSoundTypes, iSoundTypes);
}

Float:@Monster_HearingSensitivity(this) {
    return 1.0;
}

@Monster_BestSound(this) {
    static Float:vecEarPosition[3]; ExecuteHamB(Ham_EarPosition, this, vecEarPosition);

    static iBestSound; iBestSound = -1;
    static Float:flBestDist; flBestDist = 8192.0;

    for (new iSound = 0; iSound < sizeof(g_rgSounds); ++iSound) {
        if (g_rgSounds[iSound][Sound_ExpiredTime] <= g_flGameTime) continue;
    
        if (@Sound_IsSound(iSound)) {
            static Float:flDist; flDist = xs_vec_distance(vecEarPosition, g_rgSounds[iSound][Sound_Origin]);

            if (flDist < flBestDist) {
                iBestSound = iSound;
                flBestDist = flDist;
            }
        }
    }

    return iBestSound;
}

@Monster_BestScent(this) {
    static Float:vecEarPosition[3]; ExecuteHamB(Ham_EarPosition, this, vecEarPosition);

    static iBestSound; iBestSound = -1;
    static Float:flBestDist; flBestDist = 8192.0;

    for (new iSound = 0; iSound < sizeof(g_rgSounds); ++iSound) {
        if (g_rgSounds[iSound][Sound_ExpiredTime] <= g_flGameTime) continue;
    
        if (@Sound_IsScent(iSound)) {
            static Float:flDist; flDist = xs_vec_distance(vecEarPosition, g_rgSounds[iSound][Sound_Origin]);

            if (flDist < flBestDist) {
                iBestSound = iSound;
                flBestDist = flDist;
            }
        }
    }

    return iBestSound;
}

@Monster_MonsterUse(this) {
    CE_SetMember(this, m_iIdealMonsterState, MONSTER_STATE_ALERT);
}

@Monster_SoundMask(this) {
    return (SOUND_WORLD | SOUND_COMBAT | SOUND_PLAYER);
}

bool:@Monster_CheckEnemy(this, pEnemy) {
    new bool:iUpdatedLKP = false;

    @Monster_ClearConditions(this, COND_ENEMY_FACING_ME);

    if (!ExecuteHamB(Ham_FVisible, this, pEnemy)) {
        @Monster_SetConditions(this, COND_ENEMY_OCCLUDED);
    } else {
        @Monster_ClearConditions(this, COND_ENEMY_OCCLUDED);
    }

    if (!ExecuteHamB(Ham_IsAlive, pEnemy)) {
        @Monster_SetConditions(this, COND_ENEMY_DEAD);
        @Monster_ClearConditions(this, COND_SEE_ENEMY | COND_ENEMY_OCCLUDED);
        return false;
    }

    static Float:vecOrigin[3]; pev(this, pev_origin, vecOrigin);
    static Float:vecEnemyOrigin[3]; pev(pEnemy, pev_origin, vecEnemyOrigin);
    static Float:vecEnemySize[3]; pev(pEnemy, pev_size, vecEnemySize);

    static Float:vecEnemyHeadOrigin[3];
    xs_vec_copy(vecEnemyOrigin, vecEnemyHeadOrigin);
    vecEnemyHeadOrigin[2] += vecEnemySize[2] * 0.5;

    static Float:flDistToEnemy; flDistToEnemy = xs_vec_distance(vecOrigin, vecEnemyOrigin);
    static Float:flDistToEnemyHead; flDistToEnemyHead = xs_vec_distance(vecOrigin, vecEnemyHeadOrigin);

    if (flDistToEnemyHead < flDistToEnemy) {
        flDistToEnemy = flDistToEnemyHead;
    } else {
        static Float:vecEnemyFeetOrigin[3];
        xs_vec_copy(vecEnemyOrigin, vecEnemyFeetOrigin);
        vecEnemyFeetOrigin[2] -= vecEnemySize[2];

        static Float:flDistToEnemyFeet; flDistToEnemyFeet = xs_vec_distance(vecOrigin, vecEnemyFeetOrigin);
        if (flDistToEnemyFeet < flDistToEnemy) {
            flDistToEnemy = flDistToEnemyFeet;
        }
    }

    if (@Monster_HasConditions(this, COND_SEE_ENEMY)) {
        iUpdatedLKP = true;

        CE_SetMemberVec(this, m_vecEnemyLKP, vecEnemyOrigin);

        if (pEnemy) {
            if (ExecuteHamB(Ham_FInViewCone, pEnemy, this)) {
                @Monster_SetConditions(this, COND_ENEMY_FACING_ME);
            } else {
                @Monster_ClearConditions(this, COND_ENEMY_FACING_ME);
            }
        }

        static Float:vecEnemyVelocity[3]; pev(this, pev_velocity, vecEnemyVelocity);
        if (xs_vec_len(vecEnemyVelocity)) {
            static Float:vecEnemyLKP[3]; CE_GetMemberVec(this, m_vecEnemyLKP, vecEnemyLKP);

            xs_vec_sub_scaled(vecEnemyLKP, vecEnemyVelocity, random_float(-0.05, 0.0), vecEnemyLKP);

            CE_SetMemberVec(this, m_vecEnemyLKP, vecEnemyLKP);
        }
    } else if (!@Monster_HasConditions(this, COND_ENEMY_OCCLUDED | COND_SEE_ENEMY) && (flDistToEnemy <= 256.0)) {
        iUpdatedLKP = true;
        CE_SetMemberVec(this, m_vecEnemyLKP, vecEnemyOrigin);
    }

    if (flDistToEnemy >= Float:CE_GetMember(this, m_flDistTooFar)) {
        @Monster_SetConditions(this, COND_ENEMY_TOOFAR );
    } else {
        @Monster_ClearConditions(this, COND_ENEMY_TOOFAR);
    }

    if (@Monster_CanCheckAttacks(this)) {
        @Monster_CheckAttacks(this, CE_GetMember(this, m_pEnemy), flDistToEnemy);
    }

    if (CE_GetMember(this, m_iMovementGoal) == MOVEGOAL_ENEMY) {
        static Float:vecEnemyLKP[3]; CE_GetMemberVec(this, m_vecEnemyLKP, vecEnemyLKP);
        static Array:irgRoute; irgRoute = CE_GetMember(this, m_irgRoute);
        static iRouteSize; iRouteSize = ArraySize(irgRoute);
        
        for (new i = CE_GetMember(this, m_iRouteIndex); i < iRouteSize; ++i) {
            static rgWaypoint[MONSTER_WAYPOINT]; ArrayGetArray(irgRoute, i, rgWaypoint[any:0], _:MONSTER_WAYPOINT);

            if (rgWaypoint[MONSTER_WAYPOINT_TYPE] == (MF_IS_GOAL | MF_TO_ENEMY)) {
                if (xs_vec_distance(rgWaypoint[MONSTER_WAYPOINT_LOCATION], vecEnemyLKP) > 80.0) {
                    @Monster_RefreshRoute(this);
                    return iUpdatedLKP;
                }
            }
        }
    }

    return iUpdatedLKP;
}

bool:@Monster_CheckAITrigger(this) {
    return false;
}

bool:@Monster_CanCheckAttacks(this) {
    return @Monster_HasConditions(this, COND_SEE_ENEMY) && !@Monster_HasConditions(this, COND_ENEMY_TOOFAR);
}

@Monster_CallGibMonster(this) {
    new bool:bFade = false;

    if (@Monster_HasHumanGibs(this)) {
        bFade = (get_cvar_float("violence_hgibs") == 0);
    } else if (@Monster_HasAlienGibs(this)) {
        bFade = get_cvar_float("violence_agibs") == 0;
    }

    set_pev(this, pev_takedamage, DAMAGE_NO);
    set_pev(this, pev_solid, SOLID_NOT);

    if (bFade) {
        @Monster_FadeMonster(this);
    } else {
        set_pev(this, pev_effects, EF_NODRAW);
        CE_CallMethod(this, GibMonster);
    }

    set_pev(this, pev_deadflag, DEAD_DEAD);

    static Float:flHealth; pev(this, pev_health, flHealth);

    // don't let the status bar glitch for players.with <0 health.
    if (flHealth < 99.0) {
        flHealth = 0.0;
        set_pev(this, pev_health, flHealth);
    }
    
    if (@Monster_ShouldFadeOnDeath(this) && !bFade) {
        CE_Kill(this);
    }
}

@Monster_GibMonster(this) {
    emit_sound(this, CHAN_WEAPON, "common/bodysplat.wav", VOL_NORM, ATTN_NORM, 0, PITCH_NORM);

    static bool:bGibbed; bGibbed = false;

    // only humans throw skulls !!!UNDONE - eventually monsters will have their own sets of gibs
    if (@Monster_HasHumanGibs(this)) {
        if (get_cvar_float("violence_hgibs") != 0.0) {
            // TODO: Implement gibs
            // @Monster_SpawnHeadGib(this);
            // @Monster_SpawnRandomGibs(this, 4, 1);    // throw some human gibs.
        }

        bGibbed = true;
    } else if (@Monster_HasAlienGibs(this)) {
        if (get_cvar_float("violence_agibs") != 0.0) {
            // TODO: Implement gibs
            // @Monster_SpawnRandomGibs(this, 4, 0);    // Throw alien gibs
        }

        bGibbed = true;
    }


    if (bGibbed) {
        CE_CallMethod(this, SetThink, "@Monster_SUB_Remove");
        set_pev(this, pev_nextthink, g_flGameTime);
    } else {
        @Monster_FadeMonster(this);
    }
}

@Monster_FadeMonster(this) {
    @Monster_StopAnimation(this);
    set_pev(this, pev_velocity, Float:{0.0, 0.0, 0.0});
    set_pev(this, pev_movetype, MOVETYPE_NONE);
    set_pev(this, pev_avelocity, Float:{0.0, 0.0, 0.0});
    set_pev(this, pev_animtime, g_flGameTime);
    set_pev(this, pev_effects, pev(this, pev_effects) | EF_NOINTERP);
    @Monster_SUB_StartFadeOut(this);
}

@Monster_SUB_StartFadeOut(this) {
    if (pev(this, pev_rendermode) == kRenderNormal) {
        set_pev(this, pev_renderamt, 255.0);
        set_pev(this, pev_rendermode, kRenderTransTexture);
    }

    set_pev(this, pev_solid, SOLID_NOT);
    set_pev(this, pev_avelocity, Float:{0.0, 0.0, 0.0});

    set_pev(this, pev_nextthink, g_flGameTime + 0.1);

    CE_CallMethod(this, SetThink, "@Monster_SUB_FadeOut");
}

@Monster_SUB_FadeOut(this) {
    static Float:flRenderAmt; pev(this, pev_renderamt, flRenderAmt);

    if (flRenderAmt > 7.0) {
        set_pev(this, pev_renderamt, flRenderAmt - 7.0);
        set_pev(this, pev_nextthink, g_flGameTime + 0.1);
    } else {
        set_pev(this, pev_renderamt, 0.0);
        set_pev(this, pev_nextthink, g_flGameTime + 0.1);

        CE_CallMethod(this, SetThink, "@Monster_SUB_Remove");
    }
}

@Monster_SUB_Remove(this) {
    CE_Kill(this);
}

@Monster_HasHumanGibs(this) {
    new myClass = ExecuteHamB(Ham_Classify, this);

    return (
        myClass == CLASS_HUMAN_MILITARY ||
        myClass == CLASS_PLAYER_ALLY ||
        myClass == CLASS_HUMAN_PASSIVE ||
        myClass == CLASS_PLAYER
    );
}

@Monster_HasAlienGibs(this) {
    new myClass = ExecuteHamB(Ham_Classify, this);

    return (
        myClass == CLASS_ALIEN_MILITARY ||
        myClass == CLASS_ALIEN_MONSTER ||
        myClass == CLASS_ALIEN_PASSIVE ||
        myClass == CLASS_INSECT ||
        myClass == CLASS_ALIEN_PREDATOR ||
        myClass == CLASS_ALIEN_PREY
    );
}

@Monster_CheckAttacks(this, pTarget, Float:flDistance) {
    @Monster_ClearConditions(this, COND_CAN_RANGE_ATTACK1 | COND_CAN_RANGE_ATTACK2 | COND_CAN_MELEE_ATTACK1 | COND_CAN_MELEE_ATTACK2);

    static Float:vecOrigin[3]; pev(this, pev_origin, vecOrigin);
    static Float:vecTarget[3]; pev(pTarget, pev_origin, vecTarget);

    static Float:vecDirection[3];
    xs_vec_set(vecDirection, vecTarget[0] - vecOrigin[0], vecTarget[1] - vecOrigin[1], 0.0);
    xs_vec_normalize(vecDirection, vecDirection);

    static Float:vecAngles[3]; pev(this, pev_angles, vecAngles);
    static Float:vecForward[3]; angle_vector(vecAngles, ANGLEVECTOR_FORWARD, vecForward);

    // TODO: Check for forward ROLL
    static Float:flDot; flDot = xs_vec_dot(vecDirection, vecForward);

    static iCapability; iCapability = CE_GetMember(this, m_iCapability);

    if (iCapability & CAP_RANGE_ATTACK1) {
        if (@Monster_CheckRangeAttack1(this, flDot, flDistance)) {
            @Monster_SetConditions(this, COND_CAN_RANGE_ATTACK1);
        }
    }

    if (iCapability & CAP_RANGE_ATTACK2) {
        if (@Monster_CheckRangeAttack2(this, flDot, flDistance)) {
            @Monster_SetConditions(this, COND_CAN_RANGE_ATTACK2);
        }
    }

    if (iCapability & CAP_MELEE_ATTACK1) {
        if (@Monster_CheckMeleeAttack1(this, flDot, flDistance)) {
            @Monster_SetConditions(this, COND_CAN_MELEE_ATTACK1);
        }
    }

    if (iCapability & CAP_MELEE_ATTACK2) {
        if (@Monster_CheckMeleeAttack2(this, flDot, flDistance)) {
            @Monster_SetConditions(this, COND_CAN_MELEE_ATTACK2);
        }
    }
}

bool:@Monster_CheckRangeAttack1(this, Float:flDot, Float:flDistance) {
    static Float:flMeleeRange1; flMeleeRange1 = CE_GetMember(this, m_flMeleeAttack1Range);
    static Float:flMeleeRange2; flMeleeRange2 = CE_GetMember(this, m_flMeleeAttack2Range);
    static Float:flMeleeRange; flMeleeRange = floatmax(flMeleeRange1, flMeleeRange2);
    static Float:flRange; flRange = CE_GetMember(this, m_flRangeAttack1Range);

    return flRange > 0.0 && (flDistance > flMeleeRange && flDistance <= flRange && flDot >= 0.5);
}

bool:@Monster_CheckRangeAttack2(this, Float:flDot, Float:flDistance) {
    static Float:flMeleeRange1; flMeleeRange1 = CE_GetMember(this, m_flMeleeAttack1Range);
    static Float:flMeleeRange2; flMeleeRange2 = CE_GetMember(this, m_flMeleeAttack2Range);
    static Float:flMeleeRange; flMeleeRange = floatmax(flMeleeRange1, flMeleeRange2);
    static Float:flRange; flRange = CE_GetMember(this, m_flRangeAttack2Range);

    return flRange > 0.0 && (flDistance > flMeleeRange && flDistance <= flRange && flDot >= 0.5);
}

bool:@Monster_CheckMeleeAttack1(this, Float:flDot, Float:flDistance) {
    static pEnemy; pEnemy = CE_GetMember(this, m_pEnemy);
    static Float:flRange; flRange = CE_GetMember(this, m_flMeleeAttack1Range);

    return flRange > 0.0 && (flDistance <= flRange && flDot >= 0.7 && pEnemy != FM_NULLENT && (pev(pEnemy, pev_flags) & FL_ONGROUND));
}

bool:@Monster_CheckMeleeAttack2(this, Float:flDot, Float:flDistance) {
    static Float:flRange; flRange = CE_GetMember(this, m_flMeleeAttack2Range);

    return flRange > 0.0 && flDistance <= flRange && flDot >= 0.7;
}

@Monster_GetEnemy(this) {
    static Struct:sSchedule; sSchedule = CE_GetMember(this, m_sSchedule);

    static pEnemy; pEnemy = CE_GetMember(this, m_pEnemy);

    if (@Monster_HasConditions(this, COND_SEE_HATE | COND_SEE_DISLIKE | COND_SEE_NEMESIS)) {
        new pNewEnemy = @Monster_BestVisibleEnemy(this);

        if (pNewEnemy != pEnemy && pNewEnemy != FM_NULLENT) {
            if (sSchedule != Invalid_Struct) {
                static Float:vecEnemyLKP[3]; CE_GetMemberVec(this, m_vecEnemyLKP, vecEnemyLKP);

                if (StructGetCell(sSchedule, MONSTER_SCHEDULE_DATA_INTERRUPT_MASK) & COND_NEW_ENEMY) {
                    @Monster_PushEnemy(this, pEnemy, vecEnemyLKP);
                    @Monster_SetConditions(this, COND_NEW_ENEMY);
                    CE_SetMember(this, m_pEnemy, pNewEnemy);

                    pev(pNewEnemy, pev_origin, vecEnemyLKP);
                    CE_SetMemberVec(this, m_vecEnemyLKP, vecEnemyLKP);
                }

                new pOwner = pev(pNewEnemy, pev_owner);
                if (pOwner) {
                    if (pOwner && (pev(pOwner, pev_flags) & FL_MONSTER) && @Monster_Relationship(this, pOwner) != R_NO) {
                        @Monster_PushEnemy(this, pOwner, vecEnemyLKP);
                    }
                }
            }
        }
    }

    if (CE_GetMember(this, m_pEnemy) != FM_NULLENT) return true;

    if (@Monster_PopEnemy(this)) {
        if (sSchedule != Invalid_Struct) {
            if (StructGetCell(sSchedule, MONSTER_SCHEDULE_DATA_INTERRUPT_MASK) & COND_NEW_ENEMY) {
                @Monster_SetConditions(this, COND_NEW_ENEMY);
            }
        }
    }

    return false;
}

@Monster_PrescheduleThink(this) {}

@Monster_Move(this, Float:flInterval) {
    if (@Monster_HasConditions(this, COND_WAIT_FOR_PATH)) return;

    if (@Monster_IsRouteClear(this)) {
        if (CE_GetMember(this, m_iMovementGoal) == MOVEGOAL_NONE || !@Monster_RefreshRoute(this)) {
            @Monster_TaskFail(this);
            return;
        }
    }

    static Float:flMoveWaitFinished; flMoveWaitFinished = CE_GetMember(this, m_flMoveWaitFinished);

    if (flMoveWaitFinished > g_flGameTime) return;

    static Float:flMoveWaitTime; flMoveWaitTime = CE_GetMember(this, m_flMoveWaitTime);
    static Float:flGroundSpeed; flGroundSpeed = CE_GetMember(this, m_flGroundSpeed);
    static Float:vecOrigin[3]; pev(this, pev_origin, vecOrigin);

    static Array:irgRoute; irgRoute = CE_GetMember(this, m_irgRoute);
    if (!ArraySize(irgRoute)) return;

    static rgWaypoint[MONSTER_WAYPOINT]; ArrayGetArray(irgRoute, CE_GetMember(this, m_iRouteIndex), rgWaypoint[any:0], _:MONSTER_WAYPOINT);
    static Float:flWaypointDist; flWaypointDist = xs_vec_distance_2d(vecOrigin, rgWaypoint[MONSTER_WAYPOINT_LOCATION]);
    static Float:flCheckDist; flCheckDist = floatmin(flWaypointDist, DIST_TO_CHECK);

    static Float:vecDir[3];
    xs_vec_sub(rgWaypoint[MONSTER_WAYPOINT_LOCATION], vecOrigin, vecDir);
    xs_vec_normalize(vecDir, vecDir);

    static Float:vecTarget[3]; xs_vec_add_scaled(vecOrigin, vecDir, flCheckDist, vecTarget);

    @Monster_MakeIdealYaw(this, rgWaypoint[MONSTER_WAYPOINT_LOCATION]);

    static Float:flYawSpeed; pev(this, pev_yaw_speed, flYawSpeed);
    @Monster_ChangeYaw(this, flYawSpeed);

    static pTargetEnt; pTargetEnt = FM_NULLENT;
    if ((rgWaypoint[MONSTER_WAYPOINT_TYPE] & (~MF_NOT_TO_MASK)) == MF_TO_ENEMY) {
        pTargetEnt = CE_GetMember(this, m_pEnemy);
    } else if ((rgWaypoint[MONSTER_WAYPOINT_TYPE] & ~MF_NOT_TO_MASK) == MF_TO_TARGETENT) {
        pTargetEnt = CE_GetMember(this, m_pTargetEnt);
    }

    static Float:flDist; flDist = 0.0;

    if (!(rgWaypoint[MONSTER_WAYPOINT_TYPE] & MF_TO_NAV) && @Monster_CheckLocalMove(this, vecOrigin, vecTarget, pTargetEnt, false, flDist) != MONSTER_LOCALMOVE_VALID) {
        @Monster_Stop(this);

        static pBlocker; pBlocker = global_get(glb_trace_ent);
        if (pBlocker) {
            ExecuteHamB(Ham_Blocked, this, pBlocker);
        }

        if (pBlocker && flMoveWaitTime > 0.0 && ExecuteHamB(Ham_IsMoving, pBlocker) && !ExecuteHamB(Ham_IsPlayer, pBlocker) && g_flGameTime - flMoveWaitFinished > 3.0) {
            if (flDist < flGroundSpeed) {
                flMoveWaitFinished = g_flGameTime + flMoveWaitTime;
                CE_SetMember(this, m_flMoveWaitFinished, flMoveWaitFinished);
                return;
            }
        } else {
            static Float:vecApex[3];
            if (@Monster_Triangulate(this, vecOrigin, rgWaypoint[MONSTER_WAYPOINT_LOCATION], flDist, pTargetEnt, vecApex)) {
                @Monster_RouteSimplify(this, pTargetEnt);
                @Monster_InsertWaypoint(this, vecApex, MF_TO_DETOUR);
            } else {
                @Monster_Stop(this);

                if (flMoveWaitTime > 0.0 && !(CE_GetMember(this, m_iMemory) & MEMORY_MOVE_FAILED)) {
                    @Monster_RefreshRoute(this);

                    if (@Monster_IsRouteClear(this)) {
                        @Monster_TaskFail(this);
                    } else {
                        if (g_flGameTime - flMoveWaitFinished < 0.2) {
                            @Monster_Remember(this, MEMORY_MOVE_FAILED);
                        }

                        flMoveWaitFinished = g_flGameTime + 0.1;
                        CE_SetMember(this, m_flMoveWaitFinished, flMoveWaitFinished);
                    }
                } else {
                    @Monster_TaskFail(this);
                }

                return;
            }
        }
    }

    if (@Monster_ShouldAdvanceRoute(this, flWaypointDist)) {
        @Monster_AdvanceRoute(this, flWaypointDist);
    }

    if (flMoveWaitFinished > g_flGameTime) {
        @Monster_Stop(this);
        return;
    }

    if (flCheckDist < flGroundSpeed * flInterval) {
        flInterval = flCheckDist / flGroundSpeed;
    }

    CE_CallMethod(this, MoveExecute, pTargetEnt, vecDir, flInterval);

    if (@Monster_MovementIsComplete(this)) {
        @Monster_Stop(this);
        @Monster_RouteClear(this);
    }
}

@Monster_InsertWaypoint(this, const Float:vecLocation[3], iMoveFlags) {
    static rgWaypoint[MONSTER_WAYPOINT];
    xs_vec_copy(vecLocation, rgWaypoint[MONSTER_WAYPOINT_LOCATION]);
    rgWaypoint[MONSTER_WAYPOINT_TYPE] = iMoveFlags;

    static Array:irgRoute; irgRoute = CE_GetMember(this, m_irgRoute);

    if (!ArraySize(irgRoute)) {
        ArrayPushArray(irgRoute, rgWaypoint[any:0]);
        return;
    }

    static iRouteIndex; iRouteIndex = CE_GetMember(this, m_iRouteIndex);

    static rgCurrentWaypoint[MONSTER_WAYPOINT];
    ArrayGetArray(irgRoute, iRouteIndex, rgCurrentWaypoint[any:0], _:MONSTER_WAYPOINT);

    rgWaypoint[MONSTER_WAYPOINT_TYPE] |= (rgCurrentWaypoint[MONSTER_WAYPOINT_TYPE] & ~MF_NOT_TO_MASK);
    
    ArrayInsertArrayBefore(irgRoute, iRouteIndex, rgWaypoint[any:0]);
}

@Monster_PushWaypoint(this, const Float:vecLocation[3], iMoveFlag) {
    new rgWaypoint[MONSTER_WAYPOINT];
    xs_vec_copy(vecLocation, rgWaypoint[MONSTER_WAYPOINT_LOCATION]);
    rgWaypoint[MONSTER_WAYPOINT_TYPE] = iMoveFlag | MF_IS_GOAL;

    static Array:irgRoute; irgRoute = CE_GetMember(this, m_irgRoute);
    ArrayPushArray(irgRoute, rgWaypoint[any:0]);
}

bool:@Monster_ShouldAdvanceRoute(this, Float:flWaypointDist) {
    return flWaypointDist <= MONSTER_CUT_CORNER_DIST;
}

@Monster_AdvanceRoute(this, Float:flDistance) {
    static iRouteIndex; iRouteIndex = CE_GetMember(this, m_iRouteIndex);
    static Array:irgRoute; irgRoute = CE_GetMember(this, m_irgRoute);

    if (iRouteIndex == ROUTE_SIZE - 1) {
        @Monster_RefreshRoute(this);
        return;
    }

    static rgCurrentWaypoint[MONSTER_WAYPOINT]; ArrayGetArray(irgRoute, iRouteIndex, rgCurrentWaypoint[any:0], _:MONSTER_WAYPOINT);

    if (rgCurrentWaypoint[MONSTER_WAYPOINT_TYPE] & MF_IS_GOAL) {
        if (flDistance < Float:CE_GetMember(this, m_flGroundSpeed) * 0.2) {
                @Monster_MovementComplete(this);
        }

        return;
    }

    if ((rgCurrentWaypoint[MONSTER_WAYPOINT_TYPE] & ~MF_NOT_TO_MASK) == MF_TO_PATHCORNER) {
        new pNextTarget = ExecuteHamB(Ham_GetNextTarget, CE_GetMember(this, m_pGoalEnt));
        CE_SetMember(this, m_pGoalEnt, pNextTarget);
    }

    // Check if both waypoints are nodes and there is a link for a door
    static rgNextWaypoint[MONSTER_WAYPOINT]; ArrayGetArray(irgRoute, iRouteIndex + 1, rgNextWaypoint[any:0], _:MONSTER_WAYPOINT);
    if ((rgCurrentWaypoint[MONSTER_WAYPOINT_TYPE] & MF_TO_NODE) && (rgNextWaypoint[MONSTER_WAYPOINT_TYPE] & MF_TO_NODE)) {
        engfunc(EngFunc_TraceLine, rgCurrentWaypoint[MONSTER_WAYPOINT_LOCATION], rgNextWaypoint[MONSTER_WAYPOINT_LOCATION], DONT_IGNORE_MONSTERS, this, g_pTrace);

        static pHit; pHit = get_tr2(g_pTrace, TR_pHit);

        if (pHit > 0) {
            if (UTIL_IsDoor(pHit)) {
                static Float:flMoveWaitFinished; flMoveWaitFinished = @Monster_OpenDoorAndWait(this, pHit);
                CE_SetMember(this, m_flMoveWaitFinished, flMoveWaitFinished);
            }
        }
    }

    CE_SetMember(this, m_iRouteIndex, iRouteIndex + 1);
}

Float:@Monster_OpenDoorAndWait(this, pDoor) {
    if (!UTIL_IsUsableEntity(pDoor, this)) return 0.0;

    ExecuteHamB(Ham_Use, pDoor, this, this, USE_ON, 0.0);

    static Float:flDoorNextThink; pev(pDoor, pev_nextthink, flDoorNextThink);
    static Float:flDoorLastThink; pev(pDoor, pev_ltime, flDoorLastThink);
    static Float:flTravelTime; flTravelTime = flDoorNextThink - flDoorLastThink;

    static szTargetName[32]; pev(pDoor, pev_targetname, szTargetName, charsmax(szTargetName));

    if (equal(szTargetName, NULL_STRING)) {

        static pTarget; pTarget = FM_NULLENT;
        while ((pTarget = engfunc(EngFunc_FindEntityByString, pTarget, "targetname", szTargetName)) != 0) {
            if (pTarget == pDoor) continue;

            static szTargetClassname[32]; pev(pTarget, pev_classname, szTargetClassname, charsmax(szTargetClassname));

            if (UTIL_IsDoor(pTarget)) {
                ExecuteHamB(Ham_Use, pTarget, this, this, USE_ON, 0.0);
            }
        }
    }

    return g_flGameTime + flTravelTime;
}

@Monster_Stop(this) {
    CE_SetMember(this, m_iIdealActivity, @Monster_GetStoppedActivity(this));
}

@Monster_Classify() {
    return CLASS_NONE;
}

@Monster_CineCleanup(this) {}

@Monster_BestVisibleEnemy(this) {
    new Float:flNearest = 8192.0;
    new pNextEnt = get_ent_data_entity(this, "CBaseEntity", "m_pLink");
    new pReturn = FM_NULLENT;
    new iBestRelationship = R_NO;

    // TODO: Check stop condition
    while (pNextEnt != FM_NULLENT) {
        if (ExecuteHamB(Ham_IsAlive, pNextEnt)) {
            static Float:vecOrigin[3]; pev(this, pev_origin, vecOrigin);
            static Float:vecTarget[3]; pev(pNextEnt, pev_origin, vecTarget);

            if (@Monster_Relationship(this, pNextEnt) > iBestRelationship) {
                iBestRelationship = @Monster_Relationship(this, pNextEnt);
                flNearest = xs_vec_distance(vecOrigin, vecTarget);
                pReturn = pNextEnt;
            } else if (@Monster_Relationship(this, pNextEnt) == iBestRelationship) {
                static Float:flDistance; flDistance = xs_vec_distance(vecOrigin, vecTarget);
                
                if (flDistance <= flNearest) {
                    flNearest = flDistance;
                    iBestRelationship = @Monster_Relationship(this, pNextEnt);
                    pReturn = pNextEnt;
                }
            }
        }

        pNextEnt = get_ent_data_entity(pNextEnt, "CBaseEntity", "m_pLink");
    }

    return pReturn;
}

@Monster_Relationship(this, pTarget) {
    static const rgClassificationTable[14][14] = {
        /*                      NONE    MACH    PLYR    HPASS   HMIL    AMIL    APASS   AMONST  APREY   APRED   INSECT  PLRALY  PBWPN    ABWPN  */
        /*NONE*/            {   R_NO,   R_NO,   R_NO,   R_NO,   R_NO,   R_NO,   R_NO,   R_NO,   R_NO,   R_NO,   R_NO,   R_NO,   R_NO,    R_NO    },
        /*MACHINE*/         {   R_NO,   R_NO,   R_DL,   R_DL,   R_NO,   R_DL,   R_DL,   R_DL,   R_DL,   R_DL,   R_NO,   R_DL,   R_DL,    R_DL    },
        /*PLAYER*/          {   R_NO,   R_DL,   R_NO,   R_NO,   R_DL,   R_DL,   R_DL,   R_DL,   R_DL,   R_DL,   R_NO,   R_NO,   R_DL,    R_DL    },
        /*HUMANPASSIVE*/    {   R_NO,   R_NO,   R_AL,   R_AL,   R_HT,   R_FR,   R_NO,   R_HT,   R_DL,   R_FR,   R_NO,   R_AL,   R_NO,    R_NO    },
        /*HUMANMILITAR*/    {   R_NO,   R_NO,   R_HT,   R_DL,   R_NO,   R_HT,   R_DL,   R_DL,   R_DL,   R_DL,   R_NO,   R_HT,   R_NO,    R_NO    },
        /*ALIENMILITAR*/    {   R_NO,   R_DL,   R_HT,   R_DL,   R_HT,   R_NO,   R_NO,   R_NO,   R_NO,   R_NO,   R_NO,   R_DL,   R_NO,    R_NO    },
        /*ALIENPASSIVE*/    {   R_NO,   R_NO,   R_NO,   R_NO,   R_NO,   R_NO,   R_NO,   R_NO,   R_NO,   R_NO,   R_NO,   R_NO,   R_NO,    R_NO    },
        /*ALIENMONSTER*/    {   R_NO,   R_DL,   R_DL,   R_DL,   R_DL,   R_NO,   R_NO,   R_NO,   R_NO,   R_NO,   R_NO,   R_DL,   R_NO,    R_NO    },
        /*ALIENPREY*/       {   R_NO,   R_NO,   R_DL,   R_DL,   R_DL,   R_NO,   R_NO,   R_NO,   R_NO,   R_FR,   R_NO,   R_DL,   R_NO,    R_NO    },
        /*ALIENPREDATO*/    {   R_NO,   R_NO,   R_DL,   R_DL,   R_DL,   R_NO,   R_NO,   R_NO,   R_HT,   R_DL,   R_NO,   R_DL,   R_NO,    R_NO    },
        /*INSECT*/          {   R_FR,   R_FR,   R_FR,   R_FR,   R_FR,   R_NO,   R_FR,   R_FR,   R_FR,   R_FR,   R_NO,   R_FR,   R_NO,    R_NO    },
        /*PLAYERALLY*/      {   R_NO,   R_DL,   R_AL,   R_AL,   R_DL,   R_DL,   R_DL,   R_DL,   R_DL,   R_DL,   R_NO,   R_NO,   R_NO,    R_NO    },
        /*PBIOWEAPON*/      {   R_NO,   R_NO,   R_DL,   R_DL,   R_DL,   R_DL,   R_DL,   R_DL,   R_DL,   R_DL,   R_NO,   R_DL,   R_NO,    R_DL    },
        /*ABIOWEAPON*/      {   R_NO,   R_NO,   R_DL,   R_DL,   R_DL,   R_AL,   R_NO,   R_DL,   R_DL,   R_NO,   R_NO,   R_DL,   R_DL,    R_NO    }
    };

    return rgClassificationTable[ExecuteHamB(Ham_Classify, this)][ExecuteHamB(Ham_Classify, pTarget)];
}

@Monster_PushEnemy(this, pEnemy, const Float:vecLastKnownPos[3]) {
    if (pEnemy == FM_NULLENT) return;

    new Array:irgOldEnemies = CE_GetMember(this, m_irgOldEnemies);
    new iOldEnemiesNum = ArraySize(irgOldEnemies);

    for (new i = 0; i < iOldEnemiesNum; ++i) {
        if (ArrayGetCell(irgOldEnemies, i, _:MONSTER_ENEMY_ENTITY) == pEnemy) return;
    }

    new rgEnemy[MONSTER_ENEMY];
    rgEnemy[MONSTER_ENEMY_ENTITY] = pEnemy;
    rgEnemy[MONSTER_ENEMY_LOCATION] = vecLastKnownPos;

    ArrayPushArray(irgOldEnemies, rgEnemy[any:0]);
}

bool:@Monster_PopEnemy(this) {
    new Array:irgOldEnemies = CE_GetMember(this, m_irgOldEnemies);
    new iOldEnemiesNum = ArraySize(irgOldEnemies);

    for (new i = iOldEnemiesNum - 1; i >= 0; --i) {
        static rgEnemy[MONSTER_ENEMY]; ArrayGetArray(irgOldEnemies, i, rgEnemy[any:0]);

        if (ExecuteHamB(Ham_IsAlive, rgEnemy[MONSTER_ENEMY_ENTITY])) {
            CE_SetMember(this, m_pEnemy, rgEnemy[MONSTER_ENEMY_ENTITY]);
            CE_SetMemberVec(this, m_vecEnemyLKP, rgEnemy[MONSTER_ENEMY_LOCATION]);
            return true;
        } else {
            ArrayDeleteItem(irgOldEnemies, i);
        }
    }

    return false;
}

@Monster_GetTask(this, rgTask[MONSTER_TASK_DATA]) {
    static Struct:sSchedule; sSchedule = CE_GetMember(this, m_sSchedule);
    static iScheduleIndex; iScheduleIndex = CE_GetMember(this, m_iScheduleIndex);

    if (iScheduleIndex < 0) return -1;
    if (iScheduleIndex >= StructGetCell(sSchedule, MONSTER_SCHEDULE_DATA_TASK_SIZE)) return -1;

    StructGetArray(sSchedule, MONSTER_SCHEDULE_DATA_TASK, rgTask, MONSTER_TASK_DATA, _:MONSTER_TASK_DATA * iScheduleIndex);

    return rgTask[MONSTER_TASK_DATA_ID];
}

@Monster_IsCurTaskContinuousMove(this) {
    static rgTask[MONSTER_TASK_DATA];
    if (@Monster_GetTask(this, rgTask) == -1) return false;

    switch (rgTask[MONSTER_TASK_DATA_ID]) {
        case TASK_WAIT_FOR_MOVEMENT: {
            return true;
        }
	}

    return false;
}

bool:@Monster_CanActiveIdle(this) {
    return false;
}

@Monster_MovementComplete(this) {
    new iTaskStatus; CE_GetMember(this, m_iTaskStatus);

    switch (iTaskStatus) {
        case MONSTER_TASK_STATUS_NEW, MONSTER_TASK_STATUS_RUNNING: {
            CE_SetMember(this, m_iTaskStatus, MONSTER_TASK_STATUS_RUNNING_TASK);
        }
        case MONSTER_TASK_STATUS_RUNNING_MOVEMENT: {
            @Monster_TaskComplete(this);
        }
    }

    CE_SetMember(this, m_iMovementGoal, MOVEGOAL_NONE);
}

@Monster_MoveExecute(this, pTargetEnt, const Float:vecDir[3], Float:flInterval) {
    static iMovementActivity; iMovementActivity = CE_GetMember(this, m_iMovementActivity);
    static iIdealActivity; iIdealActivity = CE_GetMember(this, m_iIdealActivity);

    if (iIdealActivity != iMovementActivity) {
        CE_SetMember(this, m_iIdealActivity, iMovementActivity);
    }

    static Float:flStepSize; flStepSize = CE_GetMember(this, m_flStepSize);
    static Float:flFrameRate; pev(this, pev_framerate, flFrameRate);
    static Float:flTotal; flTotal = Float:CE_GetMember(this, m_flGroundSpeed) * flFrameRate * flInterval;

    while (flTotal > 0.001) {
        static Float:flStep; flStep = floatmin(flStepSize, flTotal);
        static Float:vecAngles[3]; pev(this, pev_angles, vecAngles);
        @Monster_WalkMove(this, vecAngles[1], flStep, WALKMOVE_NORMAL);
        flTotal -= flStep;
    }
}

Struct:@Monster_GetSchedule(this) {
    static MONSTER_STATE:iMonsterState; iMonsterState = CE_GetMember(this, m_iMonsterState);

    switch (iMonsterState) {
        case MONSTER_STATE_PRONE: {
            return CE_CallMethod(this, GetScheduleOfType, MONSTER_SCHED_BARNACLE_VICTIM_GRAB);
        }
        case MONSTER_STATE_IDLE: {
            if (@Monster_HasConditions(this, COND_HEAR_SOUND)) {
                return CE_CallMethod(this, GetScheduleOfType, MONSTER_SCHED_ALERT_FACE);
            } else if (!@Monster_IsRouteClear(this)) {
                return CE_CallMethod(this, GetScheduleOfType, MONSTER_SCHED_IDLE_WALK);
            } else {
                return CE_CallMethod(this, GetScheduleOfType, MONSTER_SCHED_IDLE_STAND);
            }
        }
        case MONSTER_STATE_ALERT: {
            if (@Monster_HasConditions(this, COND_ENEMY_DEAD) && @Monster_LookupActivity(this, ACT_VICTORY_DANCE) != ACTIVITY_NOT_AVAILABLE) {
                return CE_CallMethod(this, GetScheduleOfType,  MONSTER_SCHED_VICTORY_DANCE);
            }

            if (@Monster_HasConditions(this, COND_LIGHT_DAMAGE | COND_HEAVY_DAMAGE)) {
                static Float:flFieldOfView; flFieldOfView = CE_GetMember(this, m_flFieldOfView);

                if (floatabs(@Monster_YawDiff(this)) < (1.0 - flFieldOfView) * 60) {
                    return CE_CallMethod(this, GetScheduleOfType, MONSTER_SCHED_TAKE_COVER_FROM_ORIGIN);
                }

                return CE_CallMethod(this, GetScheduleOfType, MONSTER_SCHED_ALERT_SMALL_FLINCH);
            }
            
            if (@Monster_HasConditions(this, COND_HEAR_SOUND)) {
                return CE_CallMethod(this, GetScheduleOfType, MONSTER_SCHED_ALERT_FACE);
            }

            return CE_CallMethod(this, GetScheduleOfType, MONSTER_SCHED_ALERT_STAND);
        }
        case MONSTER_STATE_COMBAT: {
            if (@Monster_HasConditions(this, COND_ENEMY_DEAD)) {
                CE_SetMember(this, m_pEnemy, FM_NULLENT);

                if (@Monster_GetEnemy(this)) {
                    @Monster_ClearConditions(this, COND_ENEMY_DEAD);
                } else {
                    @Monster_SetState(this, MONSTER_STATE_ALERT);
                }

                return CE_CallMethod(this, GetSchedule);
            }

            if (@Monster_HasConditions(this, COND_NEW_ENEMY)) {
                return CE_CallMethod(this, GetScheduleOfType, MONSTER_SCHED_WAKE_ANGRY);
            }

            if (@Monster_HasConditions(this, COND_LIGHT_DAMAGE) && !@Monster_HasMemory(this, MEMORY_FLINCHED)) {
                return CE_CallMethod(this, GetScheduleOfType, MONSTER_SCHED_SMALL_FLINCH);
            }
            
            if (!@Monster_HasConditions(this, COND_SEE_ENEMY)) {
                if (!@Monster_HasConditions(this, COND_ENEMY_OCCLUDED)) {
                    return CE_CallMethod(this, GetScheduleOfType, MONSTER_SCHED_COMBAT_FACE);
                }

                return CE_CallMethod(this, GetScheduleOfType, MONSTER_SCHED_CHASE_ENEMY);
            }

            if (@Monster_HasConditions(this, COND_CAN_RANGE_ATTACK1)) return CE_CallMethod(this, GetScheduleOfType, MONSTER_SCHED_RANGE_ATTACK1);
            if (@Monster_HasConditions(this, COND_CAN_RANGE_ATTACK2)) return CE_CallMethod(this, GetScheduleOfType, MONSTER_SCHED_RANGE_ATTACK2);
            if (@Monster_HasConditions(this, COND_CAN_MELEE_ATTACK1)) return CE_CallMethod(this, GetScheduleOfType, MONSTER_SCHED_MELEE_ATTACK1);
            if (@Monster_HasConditions(this, COND_CAN_MELEE_ATTACK2)) return CE_CallMethod(this, GetScheduleOfType, MONSTER_SCHED_MELEE_ATTACK2);
            if (!@Monster_HasConditions(this, COND_CAN_RANGE_ATTACK1 | COND_CAN_MELEE_ATTACK1)) return CE_CallMethod(this, GetScheduleOfType, MONSTER_SCHED_CHASE_ENEMY);
            if (!@Monster_FacingIdeal(this)) return CE_CallMethod(this, GetScheduleOfType, MONSTER_SCHED_COMBAT_FACE);
        }
        case MONSTER_STATE_DEAD: {
            return CE_CallMethod(this, GetScheduleOfType, MONSTER_SCHED_DIE);
        }
        case MONSTER_STATE_SCRIPT: {
            new pCine = CE_GetMember(this, m_pCine);

            if (!pCine) {
                @Monster_CineCleanup(this);
                return CE_CallMethod(this, GetScheduleOfType, MONSTER_SCHED_IDLE_STAND);
            }

            return CE_CallMethod(this, GetScheduleOfType, MONSTER_SCHED_AISCRIPT);
        }
    }

    return _GetSharedSchedule(MONSTER_SHARED_SCHED_ERROR);
}

Struct:@Monster_GetScheduleOfType(this, MONSTER_SCHEDULE_TYPE:iType) {
    switch (iType) {
        case MONSTER_SCHED_AISCRIPT: {
            new pCine = CE_GetMember(this, m_pCine);

            if (!pCine) {
                @Monster_CineCleanup(this);
                return CE_CallMethod(this, GetScheduleOfType, MONSTER_SCHED_IDLE_STAND);
            }

            new iMoveTo = CE_GetMember(pCine, "iMoveTo");

            switch (iMoveTo) {
                case 0, 4: return _GetSharedSchedule(MONSTER_SHARED_SCHED_WAIT_SCRIPT);
                case 1: return _GetSharedSchedule(MONSTER_SHARED_SCHED_WALK_TO_SCRIPT);
                case 2: return _GetSharedSchedule(MONSTER_SHARED_SCHED_RUN_TO_SCRIPT);
                case 5: return _GetSharedSchedule(MONSTER_SHARED_SCHED_FACE_SCRIPT);
            }
        }
        case MONSTER_SCHED_IDLE_STAND: {
            if (random(14) == 0 && @Monster_CanActiveIdle(this)) {
                return _GetSharedSchedule(MONSTER_SHARED_SCHED_ACTIVE_IDLE);
            }

            return _GetSharedSchedule(MONSTER_SHARED_SCHED_IDLE_STAND);
        }
        case MONSTER_SCHED_IDLE_WALK: return _GetSharedSchedule(MONSTER_SHARED_SCHED_IDLE_WALK);
        case MONSTER_SCHED_WAIT_TRIGGER: return _GetSharedSchedule(MONSTER_SHARED_SCHED_WAIT_TRIGGER);
        case MONSTER_SCHED_WAKE_ANGRY: return _GetSharedSchedule(MONSTER_SHARED_SCHED_WAKE_ANGRY);
        case MONSTER_SCHED_ALERT_FACE: return _GetSharedSchedule(MONSTER_SHARED_SCHED_ALERT_FACE);
        case MONSTER_SCHED_ALERT_STAND: return _GetSharedSchedule(MONSTER_SHARED_SCHED_ALERT_STAND);
        case MONSTER_SCHED_COMBAT_STAND: return _GetSharedSchedule(MONSTER_SHARED_SCHED_COMBAT_STAND);
        case MONSTER_SCHED_COMBAT_FACE: return _GetSharedSchedule(MONSTER_SHARED_SCHED_COMBAT_FACE);
        case MONSTER_SCHED_CHASE_ENEMY: return _GetSharedSchedule(MONSTER_SHARED_SCHED_CHASE_ENEMY);
        case MONSTER_SCHED_CHASE_ENEMY_FAILED: return _GetSharedSchedule(MONSTER_SHARED_SCHED_FAIL);
        case MONSTER_SCHED_SMALL_FLINCH: return _GetSharedSchedule(MONSTER_SHARED_SCHED_SMALL_FLINCH);
        case MONSTER_SCHED_ALERT_SMALL_FLINCH: return _GetSharedSchedule(MONSTER_SHARED_SCHED_ALERT_SMALL_FLINCH);
        case MONSTER_SCHED_RELOAD: return _GetSharedSchedule(MONSTER_SHARED_SCHED_RELOAD);
        case MONSTER_SCHED_ARM_WEAPON: return _GetSharedSchedule(MONSTER_SHARED_SCHED_ARM_WEAPON);
        case MONSTER_SCHED_STANDOFF: return _GetSharedSchedule(MONSTER_SHARED_SCHED_STANDOFF);
        case MONSTER_SCHED_RANGE_ATTACK1: return _GetSharedSchedule(MONSTER_SHARED_SCHED_RANGE_ATTACK1);
        case MONSTER_SCHED_RANGE_ATTACK2: return _GetSharedSchedule(MONSTER_SHARED_SCHED_RANGE_ATTACK2);
        case MONSTER_SCHED_MELEE_ATTACK1: return _GetSharedSchedule(MONSTER_SHARED_SCHED_MELEE_ATTACK1);
        case MONSTER_SCHED_MELEE_ATTACK2: return _GetSharedSchedule(MONSTER_SHARED_SCHED_MELEE_ATTACK2);
        case MONSTER_SCHED_SPECIAL_ATTACK1: return _GetSharedSchedule(MONSTER_SHARED_SCHED_SPECIAL_ATTACK1);
        case MONSTER_SCHED_SPECIAL_ATTACK2: return _GetSharedSchedule(MONSTER_SHARED_SCHED_SPECIAL_ATTACK2);
        case MONSTER_SCHED_TAKE_COVER_FROM_BEST_SOUND: return _GetSharedSchedule(MONSTER_SHARED_SCHED_TAKE_COVER_FROM_BEST_SOUND);
        case MONSTER_SCHED_TAKE_COVER_FROM_ENEMY: return _GetSharedSchedule(MONSTER_SHARED_SCHED_TAKE_COVER_FROM_ENEMY);
        case MONSTER_SCHED_COWER: return _GetSharedSchedule(MONSTER_SHARED_SCHED_COWER);
        case MONSTER_SCHED_AMBUSH: return _GetSharedSchedule(MONSTER_SHARED_SCHED_AMBUSH);
        case MONSTER_SCHED_BARNACLE_VICTIM_GRAB: return _GetSharedSchedule(MONSTER_SHARED_SCHED_BARNACLE_VICTIM_GRAB);
        case MONSTER_SCHED_BARNACLE_VICTIM_CHOMP: return _GetSharedSchedule(MONSTER_SHARED_SCHED_BARNACLE_VICTIM_CHOMP);
        case MONSTER_SCHED_INVESTIGATE_SOUND: return _GetSharedSchedule(MONSTER_SHARED_SCHED_INVESTIGATE_SOUND);
        case MONSTER_SCHED_DIE: return _GetSharedSchedule(MONSTER_SHARED_SCHED_DIE);
        case MONSTER_SCHED_TAKE_COVER_FROM_ORIGIN: return _GetSharedSchedule(MONSTER_SHARED_SCHED_TAKE_COVER_FROM_ORIGIN);
        case MONSTER_SCHED_VICTORY_DANCE: return _GetSharedSchedule(MONSTER_SHARED_SCHED_VICTORY_DANCE);
        case MONSTER_SCHED_FAIL: return _GetSharedSchedule(MONSTER_SHARED_SCHED_FAIL);
        default: return _GetSharedSchedule(MONSTER_SHARED_SCHED_IDLE_STAND);
    }

    return Invalid_Struct;
}

@Monster_ClearSchedule(this) {
    new Struct:sSchedule = CE_GetMember(this, m_sSchedule);
    if (sSchedule != Invalid_Struct && StructGetCell(sSchedule, MONSTER_SCHEDULE_DATA_SHARED_ID) == MONSTER_SHARED_SCHED_INVALID) {
        StructDestroy(sSchedule);
    }

    CE_SetMember(this, m_iTaskStatus, MONSTER_TASK_STATUS_NEW);
    CE_SetMember(this, m_sSchedule, Invalid_Struct);
    CE_SetMember(this, m_iScheduleIndex, 0);
    CE_SetMember(this, m_iFailSchedule, MONSTER_SCHED_NONE);
}

@Monster_ChangeSchedule(this, Struct:sNewSchedule) {
    new Struct:sSchedule = CE_GetMember(this, m_sSchedule);
    if (sSchedule != Invalid_Struct && StructGetCell(sSchedule, MONSTER_SCHEDULE_DATA_SHARED_ID) == MONSTER_SHARED_SCHED_INVALID) {
        StructDestroy(sSchedule);
    }

    CE_SetMember(this, m_iTaskStatus, MONSTER_TASK_STATUS_NEW);
    CE_SetMember(this, m_sSchedule, sNewSchedule);
    CE_SetMember(this, m_iScheduleIndex, 0);
    CE_SetMember(this, m_iConditions, 0);
    CE_SetMember(this, m_iFailSchedule, MONSTER_SCHED_NONE);
}

@Monster_TaskBegin(this) {
    CE_SetMember(this, m_iTaskStatus, MONSTER_TASK_STATUS_RUNNING);
}

@Monster_TaskComplete(this) {
    CE_SetMember(this, m_iTaskStatus, MONSTER_TASK_STATUS_COMPLETE);
}

@Monster_TaskFail(this) {
    @Monster_SetConditions(this, COND_TASK_FAILED);
}

bool:@Monster_TaskIsComplete(this) {
    return CE_GetMember(this, m_iTaskStatus) == MONSTER_TASK_STATUS_COMPLETE;
}

@Monster_SetTurnActivity(this) {
    static Float:flYD; flYD = @Monster_YawDiff(this);

    if (flYD <= -45.0 && @Monster_LookupActivity(this, ACT_TURN_RIGHT) != ACTIVITY_NOT_AVAILABLE) {
        CE_SetMember(this, m_iIdealActivity, ACT_TURN_RIGHT);
    } else if (flYD > 45.0 && @Monster_LookupActivity(this, ACT_TURN_LEFT) != ACTIVITY_NOT_AVAILABLE) {
        CE_SetMember(this, m_iIdealActivity, ACT_TURN_LEFT);
    }
}

Float:@Monster_YawDiff(this) {
    static Float:vecAngles[3]; pev(this, pev_angles, vecAngles);
    static Float:flIdealYaw; pev(this, pev_ideal_yaw, flIdealYaw);
    static Float:flCurrentYaw; flCurrentYaw = UTIL_AngleMod(vecAngles[1]);

    if (flCurrentYaw == flIdealYaw) return 0.0;

    return UTIL_AngleDiff(flIdealYaw, flCurrentYaw);
}

@Monster_Remember(this, iMemory) {
    CE_SetMember(this, m_iMemory, CE_GetMember(this, m_iMemory) | iMemory);
}

@Monster_Forget(this, iMemory) {
    CE_SetMember(this, m_iMemory, CE_GetMember(this, m_iMemory) & ~iMemory);
}

bool:@Monster_HasMemory(this, iMemory) {
    return !!(CE_GetMember(this, m_iMemory) & iMemory);
}

bool:@Monster_HasAllMemory(this, iMemory) {
    return (CE_GetMember(this, m_iMemory) & iMemory) == iMemory;
}

@Monster_SetConditions(this, iConditions) {
    CE_SetMember(this, m_iConditions, CE_GetMember(this, m_iConditions) | iConditions);
}

@Monster_ClearConditions(this, iConditions) {
    CE_SetMember(this, m_iConditions, CE_GetMember(this, m_iConditions) & ~iConditions);
}

bool:@Monster_HasConditions(this, iConditions) {
    return !!(CE_GetMember(this, m_iConditions) & iConditions);
}

bool:@Monster_HasAllConditions(this, iConditions) {
    return (CE_GetMember(this, m_iConditions) & iConditions) == iConditions;
}

@Monster_IgnoreConditions(this) {
    new iIgnoreConditions; iIgnoreConditions = 0;

    if (!@Monster_ShouldEat(this)) {
        iIgnoreConditions |= COND_SMELL_FOOD;
    }

    if (CE_GetMember(this, m_iMonsterState) == MONSTER_STATE_SCRIPT) {
        static pCine; pCine = CE_GetMember(this, m_pCine);

        if (pCine != FM_NULLENT) {
            iIgnoreConditions |= CE_CallMethod(pCine, IgnoreConditions);
        }
    }

    return iIgnoreConditions;
}

bool:@Monster_ShouldEat(this) {
    return Float:CE_GetMember(this, m_flHungryTime) <= g_flGameTime;
}

@Monster_MakeIdealYaw(this, const Float:vecTarget[]) {
    static iMovementActivity; iMovementActivity = CE_GetMember(this, m_iMovementActivity);
    static Float:vecOrigin[3]; pev(this, pev_origin, vecOrigin);

    static Float:vecProjection[3];

    switch (iMovementActivity) {
        case ACT_STRAFE_LEFT: {
            xs_vec_set(vecProjection, -vecTarget[1], vecTarget[0], 0.0);
        }
        case ACT_STRAFE_RIGHT: {
            xs_vec_set(vecProjection, vecTarget[1], vecTarget[0], 0.0);
        }
        default: {
            xs_vec_copy(vecTarget, vecProjection);
        }
    }

    static Float:vecDirection[3]; xs_vec_sub(vecProjection, vecOrigin, vecDirection);
    static Float:vecAngles[3]; vector_to_angle(vecDirection, vecAngles);

    set_pev(this, pev_ideal_yaw, vecAngles[1]);
}

Float:@Monster_ChangeYaw(this, Float:flYawSpeed) {
    static Float:vecAngles[3]; pev(this, pev_angles, vecAngles);
    static Float:flCurrent; flCurrent = vecAngles[1];
    static Float:flIdealYaw; pev(this, pev_ideal_yaw, flIdealYaw);

    if (flCurrent == flIdealYaw) return 0.0;

    static Float:flFrameTime; global_get(glb_frametime, flFrameTime);
    flFrameTime *= 10.0;

    vecAngles[1] = UTIL_ApproachAngle(flIdealYaw, flCurrent, flYawSpeed * flFrameTime);

    set_pev(this, pev_angles, vecAngles);

    static Float:flDiff; flDiff = UTIL_AngleDiff(flIdealYaw, vecAngles[1]);

    // turn head in desired direction only if they have a turnable head
    if (CE_GetMember(this, m_iCapability) & CAP_TURN_HEAD) {
        set_controller(this, 0, flDiff);
    }

    return flDiff;
}

bool:@Monster_FacingIdeal(this) {
    return floatabs(@Monster_YawDiff(this)) <= 0.006;
}

bool:@Monster_MoveToEnemy(this, Activity:iActivity, Float:flWaitTime) {
    CE_SetMember(this, m_iMovementActivity, iActivity);
    CE_SetMember(this, m_flMoveWaitTime, flWaitTime);
    CE_SetMember(this, m_iMovementGoal, MOVEGOAL_ENEMY);

    return @Monster_RefreshRoute(this);
}

bool:@Monster_MoveToTarget(this, Activity:iActivity, Float:flWaitTime) {
    CE_SetMember(this, m_iMovementActivity, iActivity);
    CE_SetMember(this, m_flMoveWaitTime, flWaitTime);
    CE_SetMember(this, m_iMovementGoal, MOVEGOAL_TARGETENT);

    return @Monster_RefreshRoute(this);
}

bool:@Monster_MoveToLocation(this, Activity:iActivity, Float:flWaitTime, const Float:vecGoal[]) {
    CE_SetMember(this, m_iMovementActivity, iActivity);
    CE_SetMember(this, m_flMoveWaitTime, flWaitTime);
    CE_SetMember(this, m_iMovementGoal, MOVEGOAL_LOCATION);
    CE_SetMemberVec(this, m_vecMoveGoal, vecGoal);

    return @Monster_RefreshRoute(this);
}

@Monster_FindHintNode(this) { return 0; }

@Monster_NextScheduledTask(this) {
    if (CE_GetMember(this, m_sSchedule) == Invalid_Struct) return;

    CE_SetMember(this, m_iTaskStatus, MONSTER_TASK_STATUS_NEW);
    CE_SetMember(this, m_iScheduleIndex, CE_GetMember(this, m_iScheduleIndex) + 1);

    if (@Monster_ScheduleDone(this)) {
        @Monster_SetConditions(this, COND_SCHEDULE_DONE);
    }
}

@Monster_ScheduleDone(this) {
    static Struct:sSchedule; sSchedule = CE_GetMember(this, m_sSchedule);

    return CE_GetMember(this, m_iScheduleIndex) == StructGetCell(sSchedule, MONSTER_SCHEDULE_DATA_TASK_SIZE);
}

@Monster_ScheduleValid(this) {
    static Struct:sSchedule; sSchedule = CE_GetMember(this, m_sSchedule);

    if (sSchedule == Invalid_Struct) return false;

    static iInterruptMask; iInterruptMask = StructGetCell(sSchedule, MONSTER_SCHEDULE_DATA_INTERRUPT_MASK);
    if (@Monster_HasConditions(this, iInterruptMask | COND_SCHEDULE_DONE | COND_TASK_FAILED)) {
        return false;
    }

    return true;
}

@Monster_ScheduleChange(this) {}

@Monster_ScheduleFlags(this) {
    static Struct:sSchedule; sSchedule = CE_GetMember(this, m_sSchedule);

    if (sSchedule == Invalid_Struct) return 0;

    static iConditions; iConditions = CE_GetMember(this, m_iConditions);
    static iInterruptMask; iInterruptMask = StructGetCell(sSchedule, MONSTER_SCHEDULE_DATA_INTERRUPT_MASK);

    return iConditions & iInterruptMask;
}

MONSTER_STATE:@Monster_GetIdealState(this) {
    static iConditions; iConditions = @Monster_ScheduleFlags(this);
    static MONSTER_STATE:iMonsterState; iMonsterState = CE_GetMember(this, m_iMonsterState);

    switch (iMonsterState) {
        case MONSTER_STATE_IDLE: {
            new Float:vecEnemyLKP[3]; CE_GetMemberVec(this, m_vecEnemyLKP, vecEnemyLKP);

            if (iConditions & COND_NEW_ENEMY) {
                CE_SetMember(this, m_iIdealMonsterState, MONSTER_STATE_COMBAT);
            } else if (iConditions & COND_LIGHT_DAMAGE) {
                @Monster_MakeIdealYaw(this, vecEnemyLKP);
                CE_SetMember(this, m_iIdealMonsterState, MONSTER_STATE_ALERT);
            } else if (iConditions & COND_HEAVY_DAMAGE) {
                @Monster_MakeIdealYaw(this, vecEnemyLKP);
                CE_SetMember(this, m_iIdealMonsterState, MONSTER_STATE_ALERT);
            } else if (iConditions & COND_HEAR_SOUND) {
                new iSound = @Monster_BestSound(this);
                if (iSound != -1) {
                    @Monster_MakeIdealYaw(this, g_rgSounds[iSound][Sound_Origin]);

                    static iType; iType = g_rgSounds[iSound][Sound_Type];
                    if (iType & (SOUND_COMBAT | SOUND_DANGER)) {
                        CE_SetMember(this, m_iIdealMonsterState, MONSTER_STATE_ALERT);
                    }
                }
            } else if (iConditions & (COND_SMELL | COND_SMELL_FOOD)) {
                CE_SetMember(this, m_iIdealMonsterState, MONSTER_STATE_ALERT);
            }
        }
        case MONSTER_STATE_ALERT: {
            if (iConditions & (COND_NEW_ENEMY | COND_SEE_ENEMY)) {
                CE_SetMember(this, m_iIdealMonsterState, MONSTER_STATE_COMBAT);
            } else if (iConditions & COND_HEAR_SOUND) {
                CE_SetMember(this, m_iIdealMonsterState, MONSTER_STATE_ALERT);

                new iSound = @Monster_BestSound(this);
                if (iSound != -1) {
                    @Monster_MakeIdealYaw(this, g_rgSounds[iSound][Sound_Origin]);
                }
            }
        }
        case MONSTER_STATE_COMBAT: {
            if (CE_GetMember(this, m_pEnemy) == FM_NULLENT) {
                CE_SetMember(this, m_iIdealMonsterState, MONSTER_STATE_ALERT);
            }
        }
        case MONSTER_STATE_SCRIPT: {
            if (iConditions & (COND_TASK_FAILED | COND_LIGHT_DAMAGE | COND_HEAVY_DAMAGE)) {
                @Monster_ExitScriptedSequence(this);
            }
        }
        case MONSTER_STATE_DEAD: {
            CE_SetMember(this, m_iIdealMonsterState, MONSTER_STATE_DEAD);
        }
    }

    return CE_GetMember(this, m_iIdealMonsterState);
}

bool:@Monster_ExitScriptedSequence(this) {
    if (pev(this, pev_deadflag) == DEAD_DYING) {
        CE_SetMember(this, m_iIdealMonsterState, MONSTER_STATE_DEAD);
        return false;
    }

    new pCine = CE_GetMember(this, m_pCine);

    if (pCine) {
        CE_CallMethod(pCine, "CancelScript");
    }

    return true;
}

@Monster_GetSequenceFlags(this) {
    static iSequence; iSequence = pev(this, pev_sequence);

    static Array:irgSequences; irgSequences = CE_GetMember(this, m_irgSequences);
    if (irgSequences == Invalid_Array) return 0;

    return ArrayGetCell(irgSequences, iSequence, _:Sequence_Flags);
}

@Monster_SetYawSpeed(this) {
    set_pev(this, pev_yaw_speed, 180.0);
}

@Monster_SetActivity(this, Activity:iNewActivity) {
    static Activity:iSequence; iSequence = @Monster_LookupActivity(this, iNewActivity);
    static bool:bSequenceLoops; bSequenceLoops = CE_GetMember(this, m_bSequenceLoops);
    static Activity:iActivity; iActivity = CE_GetMember(this, m_iActivity);

    // Set to the desired anim, or default anim if the desired is not present
    if (iSequence > ACTIVITY_NOT_AVAILABLE) {
        if (pev(this, pev_sequence) != _:iSequence || !bSequenceLoops) {
            if (!(iActivity == ACT_WALK || iActivity == ACT_RUN) || !(iNewActivity == ACT_WALK || iNewActivity == ACT_RUN)) {
                set_pev(this, pev_frame, 0);
            }
        }

        set_pev(this, pev_sequence, iSequence);

        @Monster_ResetSequenceInfo(this);
        CE_CallMethod(this, SetYawSpeed);
    } else {
        set_pev(this, pev_sequence, 0);
    }

    CE_SetMember(this, m_iActivity, iNewActivity);
    CE_SetMember(this, m_iIdealActivity, iNewActivity);
}

bool:@Monster_TaskIsRunning(this) {
    static MONSTER_TASK_STATUS:iTaskStatus; iTaskStatus = CE_GetMember(this, m_iTaskStatus);

    return (iTaskStatus != MONSTER_TASK_STATUS_COMPLETE && iTaskStatus != MONSTER_TASK_STATUS_RUNNING_MOVEMENT);
}

@Monster_SetState(this, MONSTER_STATE:iState) {
    switch (iState) {
        case MONSTER_STATE_IDLE: {
            if (CE_GetMember(this, m_pEnemy) != FM_NULLENT) {
                CE_SetMember(this, m_pEnemy, FM_NULLENT);
            }
        }
    }

    CE_SetMember(this, m_iMonsterState, iState);
    CE_SetMember(this, m_iIdealMonsterState, iState);
}

@Monster_RouteClassify(this, iMoveFlag) {
    if (iMoveFlag & MF_TO_TARGETENT) return MOVEGOAL_TARGETENT;
    if (iMoveFlag & MF_TO_ENEMY) return MOVEGOAL_ENEMY;
    if (iMoveFlag & MF_TO_PATHCORNER) return MOVEGOAL_PATHCORNER;
    if (iMoveFlag & MF_TO_NODE) return MOVEGOAL_NODE;
    if (iMoveFlag & MF_TO_NAV) return MOVEGOAL_NAV;
    if (iMoveFlag & MF_TO_LOCATION) return MOVEGOAL_LOCATION;

    return MOVEGOAL_NONE;
}

MONSTER_LOCALMOVE:@Monster_CheckLocalMove(this, const Float:vecStart[3], const Float:vecEnd[3], pTarget, bool:bValidateZ, &Float:flOutDist) {
    new MONSTER_LOCALMOVE:iReturn = MONSTER_LOCALMOVE_VALID;

    static Float:flStepSize; flStepSize = CE_GetMember(this, m_flStepSize);
    static Float:vecOrigin[3]; pev(this, pev_origin, vecOrigin);
    static Float:vecMins[3]; pev(this, pev_mins, vecMins);

    static Float:vecDirection[3];
    xs_vec_sub(vecEnd, vecStart, vecDirection);
    xs_vec_normalize(vecDirection, vecDirection);
    
    static Float:vecAngles[3]; vector_to_angle(vecDirection, vecAngles);

    static Float:flDist; flDist = xs_vec_distance(vecStart, vecEnd);
    static iFlags; iFlags = pev(this, pev_flags);

    engfunc(EngFunc_SetOrigin, this, vecStart);

    if (~iFlags & (FL_FLY | FL_SWIM)) {
        engfunc(EngFunc_DropToFloor, this);
    }

    for (new Float:flStep = 0.0; flStep < flDist; flStep += flStepSize) {
        static Float:flCurrentStepSize; flCurrentStepSize = flStepSize;

        if ((flStep + flCurrentStepSize) >= (flDist - 1.0)) {
            flCurrentStepSize = (flDist - flStep) - 1.0;
        }

        if (!@Monster_WalkMove(this, vecAngles[1], flCurrentStepSize, WALKMOVE_CHECKONLY)) {
            flOutDist = flStep;

            if ((pTarget != FM_NULLENT && (pTarget == g_pHit))) {
                iReturn = MONSTER_LOCALMOVE_VALID;
            } else {
                iReturn = MONSTER_LOCALMOVE_INVALID;
            }

            break;
        }
    }

    if (bValidateZ && iReturn == MONSTER_LOCALMOVE_VALID) {
        if (!(iFlags & (FL_FLY | FL_SWIM)) && (pTarget == FM_NULLENT || (pev(pTarget, pev_flags) & FL_ONGROUND))) {
            static Float:vecAbsMin[3]; pev(this, pev_absmin, vecAbsMin);
            static Float:vecAbsMax[3]; pev(this, pev_absmax, vecAbsMax);

            static Float:vecTargetAbsMin[3];
            static Float:vecTargetAbsMax[3];

            if (pTarget == FM_NULLENT) {
                xs_vec_copy(vecEnd, vecTargetAbsMin);
                xs_vec_copy(vecEnd, vecTargetAbsMax);
            } else {
                pev(pTarget, pev_absmin, vecTargetAbsMin);
                pev(pTarget, pev_absmax, vecTargetAbsMax);
            }

            if (vecTargetAbsMax[2] < vecAbsMin[2] || vecTargetAbsMin[2] > vecAbsMax[2]) {
                iReturn = MONSTER_LOCALMOVE_INVALID_DONT_TRIANGULATE;
            }
        }
    }

    engfunc(EngFunc_SetOrigin, this, vecOrigin);

    return iReturn;
}

bool:@Monster_WalkMove(this, Float:flYaw, Float:flStep, iMode) {
    // static iFlags; iFlags = pev(this, pev_flags);
    // static bool:bMonsterClip; bMonsterClip = !!(iFlags & FL_MONSTERCLIP);
    static Float:vecMove[3]; xs_vec_set(vecMove, floatcos(flYaw, degrees) * flStep, floatsin(flYaw, degrees) * flStep, 0.0);

    switch (iMode) {
        // case WALKMOVE_WORLDONLY: @Monster_MoveTest(this, vecMove, true);
        case WALKMOVE_NORMAL: return @Monster_MoveStep(this, vecMove, true);
        case WALKMOVE_CHECKONLY: return @Monster_MoveStep(this, vecMove, false);
    }

    return false;
}

bool:@Monster_MoveStep(this, const Float:vecMove[3], bool:bRelink) {
    static bool:bSuccessed; bSuccessed = false;

    static iFlags; iFlags = pev(this, pev_flags);
    static Float:flStepHeight; flStepHeight = CE_GetMember(this, m_flStepHeight);
    static Float:vecOrigin[3]; pev(this, pev_origin, vecOrigin);
    
    if (iFlags & (FL_SWIM | FL_FLY)) {
        // TODO: Implement
    } else {
        static Float:vecSrc[3]; xs_vec_copy(vecOrigin, vecSrc);
        static Float:vecEnd[3]; xs_vec_add(vecOrigin, vecMove, vecEnd);

        bSuccessed = @Monster_Trace(this, vecSrc, vecEnd, DONT_IGNORE_MONSTERS, this, g_pTrace);

        // If move forward failed then try to make height step and repeat
        if (!bSuccessed) {
            xs_vec_set(vecEnd, vecSrc[0], vecSrc[1], vecSrc[2] + flStepHeight);

            @Monster_Trace(this, vecSrc, vecEnd, DONT_IGNORE_MONSTERS, this, g_pTrace);
            get_tr2(g_pTrace, TR_vecEndPos, vecSrc);
            xs_vec_add(vecSrc, vecMove, vecEnd);

            bSuccessed = @Monster_Trace(this, vecSrc, vecEnd, DONT_IGNORE_MONSTERS, this, g_pTrace);

            // TODO: Investigate ability to allow monsters go through the doors
        }

        g_pHit = get_tr2(g_pTrace, TR_pHit);

        // Do step down
        if (bSuccessed) {
            #define OFFSET_TO_HIT_GROUND 0.1

            get_tr2(g_pTrace, TR_vecEndPos, vecSrc);
            xs_vec_set(vecEnd, vecSrc[0], vecSrc[1], vecSrc[2] - flStepHeight - OFFSET_TO_HIT_GROUND);
            
            if (!@Monster_Trace(this, vecSrc, vecEnd, DONT_IGNORE_MONSTERS, this, g_pTrace)) {
                get_tr2(g_pTrace, TR_vecEndPos, vecOrigin);
            } else {
                xs_vec_copy(vecEnd, vecOrigin);
            }

            // static Float:vecPlaneNormal[3]; get_tr2(g_pTrace, TR_vecPlaneNormal, vecPlaneNormal);

            // bSuccessed = vecPlaneNormal[2] > 0.5;

            // if (vecPlaneNormal[2] <= 0.5) {
            //     log_amx("vecPlaneNormal[2] %f", vecPlaneNormal[2]);
            // }
        }

        // TODO: Investigate ability to allow monsters to fall
    }

    get_tr2(g_pTrace, TR_vecEndPos, vecOrigin);

    if (bSuccessed) {
        if (bRelink) {
            engfunc(EngFunc_SetOrigin, this, vecOrigin);
        } else {
            set_pev(this, pev_origin, vecOrigin);
        }
    }

    return bSuccessed;
}

bool:@Monster_Trace(this, const Float:vecSrc[3], const Float:vecEnd[3], iTraceFlags, pIgnoreEnt, pTrace) {
    engfunc(EngFunc_TraceMonsterHull, this, vecSrc, vecEnd, iTraceFlags, pIgnoreEnt, pTrace);

    if (get_tr2(pTrace, TR_AllSolid)) return false;

    static Float:flFraction; get_tr2(pTrace, TR_flFraction, flFraction);
    if (flFraction != 1.0) return false;

    return true;
}

@Monster_RouteNew(this) {
    new Array:irgRoute = CE_GetMember(this, m_irgRoute);
    ArrayClear(irgRoute);

    CE_SetMember(this, m_iRouteIndex, 0);

    if (@Monster_HasConditions(this, COND_WAIT_FOR_PATH)) {
        static NavBuildPathTask:pTask; pTask = CE_GetMember(this, m_pPathTask);
        Nav_Path_FindTask_Abort(pTask);

        @Monster_ClearConditions(this, COND_WAIT_FOR_PATH);
        CE_SetMember(this, m_pPathTask, Invalid_NavBuildPathTask);
    }
}

@Monster_RouteSimplify(this, pTarget) {}

@Monster_HullIndex(this) {
    return HULL_HUMAN;
}

bool:@Monster_GetNodeRoute(this, const Float:vecDest[3]) {
    if (!g_bUseAstar) return false;

    #if defined _api_navsystem_included
        static Float:vecOrigin[3]; pev(this, pev_origin, vecOrigin);

        static NavBuildPathTask:pTask; pTask = Nav_Path_Find(vecOrigin, vecDest, "NavPathCallback", this, this, "NavPathCost");
        if (pTask == Invalid_NavBuildPathTask) return false;

        CE_SetMember(this, m_pPathTask, pTask);
        @Monster_SetConditions(this, COND_WAIT_FOR_PATH);

        return true;
    #else
        return false;
    #endif
}

@Monster_HandlePathTask(this) {
    if (!@Monster_HasConditions(this, COND_WAIT_FOR_PATH)) return;

    @Monster_ClearConditions(this, COND_WAIT_FOR_PATH);

    static NavBuildPathTask:pTask; pTask = CE_GetMember(this, m_pPathTask);

    if (Nav_Path_FindTask_IsSuccessed(pTask)) {
        new NavPath:pPath = Nav_Path_FindTask_GetPath(pTask);
        if (Nav_Path_IsValid(pPath)) {
            @Monster_MoveNavPath(this, pPath);
        } else {
            @Monster_TaskFail(this);
        }
    } else {
        @Monster_TaskFail(this);
    }

    CE_SetMember(this, m_pPathTask, Invalid_NavBuildPathTask);
}

@Monster_MoveNavPath(this, NavPath:pPath) {    
    @Monster_RouteNew(this);

    static Float:vecOrigin[3]; pev(this, pev_origin, vecOrigin);

    static Array:irgRoute; irgRoute = CE_GetMember(this, m_irgRoute);

    static iSegmentsNum; iSegmentsNum = Nav_Path_GetSegmentCount(pPath);

    for (new iSegment = 0; iSegment < iSegmentsNum; ++iSegment) {
        static Float:vecPos[3]; Nav_Path_GetSegmentPos(pPath, iSegment, vecPos);

        static rgWaypoint[MONSTER_WAYPOINT];
        xs_vec_copy(vecPos, rgWaypoint[MONSTER_WAYPOINT_LOCATION]);
        rgWaypoint[MONSTER_WAYPOINT_TYPE] = MF_TO_NODE;

        if (iSegment == iSegmentsNum - 1) {
            rgWaypoint[MONSTER_WAYPOINT_TYPE] = MF_IS_GOAL;
        }

        ArrayPushArray(irgRoute, rgWaypoint[any:0]);
    }
}

bool:@Monster_MoveToNode(this, Activity:iActivity, Float:flWaitTime, const Float:vecGoal[3]) {
    CE_SetMember(this, m_iMovementActivity, iActivity);
    CE_SetMember(this, m_flMoveWaitTime, flWaitTime);
    CE_SetMember(this, m_iMovementGoal, MOVEGOAL_NODE);
    CE_SetMemberVec(this, m_vecMoveGoal, vecGoal);

    return @Monster_RefreshRoute(this);
}

bool:@Monster_MovementIsComplete(this) { 
    return CE_GetMember(this, m_iMovementGoal) == MOVEGOAL_NONE;
}

bool:@Monster_Triangulate(this, const Float:vecStart[], const Float:vecEnd[], Float:flDist, pTargetEnt, Float:vecApex[3]) {
    static iMoveType; iMoveType = pev(this, pev_movetype);
    static Float:vecOrigin[3]; pev(this, pev_origin, vecOrigin);
    static Float:vecSize[3]; pev(this, pev_size, vecSize);

    static Float:flSizeX; flSizeX = floatclamp(vecSize[0], 24.0, 48.0);
    static Float:flSizeZ; flSizeZ = vecSize[2];

    static Float:vecForward[3];
    xs_vec_sub(vecEnd, vecStart, vecForward);
    xs_vec_normalize(vecForward, vecForward);

    static Float:vecDirUp[3]; xs_vec_set(vecDirUp, 0.0, 0.0, 1.0);
    static Float:vecDir[3]; xs_vec_cross(vecForward, vecDirUp, vecDir);

    static Float:vecLeft[3];
    xs_vec_add_scaled(vecOrigin, vecForward, (flDist + flSizeX), vecLeft);
    xs_vec_sub_scaled(vecOrigin, vecDir, (flSizeX * 2), vecLeft);

    static Float:vecRight[3];
    xs_vec_add_scaled(vecOrigin, vecForward, (flDist + flSizeX), vecRight);
    xs_vec_add_scaled(vecOrigin, vecDir, (flSizeX * 2), vecRight);

    static Float:vecTop[3];
    static Float:vecBottom[3];

    if (iMoveType == MOVETYPE_FLY) {
        xs_vec_add_scaled(vecOrigin, vecForward, flDist, vecTop);
        xs_vec_add_scaled(vecOrigin, vecDirUp, (flSizeZ * 3), vecTop);

        xs_vec_add_scaled(vecOrigin, vecForward, flDist, vecBottom);
        xs_vec_sub_scaled(vecOrigin, vecDirUp, (flSizeZ * 3), vecBottom);
    }

    static Float:vecFarSide[3];

    static Array:irgRoute; irgRoute = CE_GetMember(this, m_irgRoute);
    if (ArraySize(irgRoute)) {
        static rgWaypoint[MONSTER_WAYPOINT]; ArrayGetArray(irgRoute, CE_GetMember(this, m_iRouteIndex), rgWaypoint[any:0], _:MONSTER_WAYPOINT);
        xs_vec_copy(rgWaypoint[MONSTER_WAYPOINT_LOCATION], vecFarSide);
    } else {
        xs_vec_copy(vecEnd, vecFarSide);
    }

    for (new i = 0; i < 8; i++) {
        static Float:flDistance;

        if (@Monster_CheckLocalMove(this, vecOrigin, vecRight, pTargetEnt, true, flDistance) == MONSTER_LOCALMOVE_VALID) {
            if (@Monster_CheckLocalMove(this, vecRight, vecFarSide, pTargetEnt, true, flDistance) == MONSTER_LOCALMOVE_VALID) {
                xs_vec_copy(vecRight, vecApex);
                return true;
            }
        }

        if (@Monster_CheckLocalMove(this, vecOrigin, vecLeft, pTargetEnt, true, flDistance) == MONSTER_LOCALMOVE_VALID) {
            if (@Monster_CheckLocalMove(this, vecLeft, vecFarSide, pTargetEnt, true, flDistance) == MONSTER_LOCALMOVE_VALID) {
                xs_vec_copy(vecLeft, vecApex);
                return true;
            }
        }

        if (iMoveType == MOVETYPE_FLY) {
            if (@Monster_CheckLocalMove(this, vecOrigin, vecTop, pTargetEnt, true, flDistance) == MONSTER_LOCALMOVE_VALID) {
                if (@Monster_CheckLocalMove(this, vecTop, vecFarSide, pTargetEnt, true, flDistance) == MONSTER_LOCALMOVE_VALID) {
                    xs_vec_copy(vecTop, vecApex);
                    return true;
                }
            }

            if (@Monster_CheckLocalMove(this, vecOrigin, vecBottom, pTargetEnt, true, flDistance) == MONSTER_LOCALMOVE_VALID) {
                if (@Monster_CheckLocalMove(this, vecBottom, vecFarSide, pTargetEnt, true, flDistance) == MONSTER_LOCALMOVE_VALID) {
                    xs_vec_copy(vecBottom, vecApex);
                    return true;
                }
            }
        }

        xs_vec_add_scaled(vecRight, vecDir, flSizeX * 2, vecRight);
        xs_vec_sub_scaled(vecLeft, vecDir, flSizeX * 2, vecLeft);

        if (iMoveType == MOVETYPE_FLY) {
            xs_vec_add_scaled(vecTop, vecDirUp, flSizeZ * 2, vecTop);
            xs_vec_sub_scaled(vecBottom, vecDirUp, flSizeZ * 2, vecBottom);
        }
    }

    return false;
}

bool:@Monster_BuildRoute(this, const Float:vecGoal[3], iMoveFlag, pTarget) {
    @Monster_RouteNew(this);

    static iMovementGoal; iMovementGoal = @Monster_RouteClassify(this, iMoveFlag);
    CE_SetMember(this, m_iMovementGoal, iMovementGoal);

    if (@Monster_BuildSimpleRoute(this, vecGoal, iMoveFlag, pTarget)) {
        return true;
    }

    if (@Monster_GetNodeRoute(this, vecGoal)) {
        CE_SetMemberVec(this, m_vecMoveGoal, vecGoal);
        @Monster_RouteSimplify(this, pTarget);
        return true;
    }

    return false;
}

@Monster_BuildSimpleRoute(this, const Float:vecGoal[3], iMoveFlag, pTarget) {
    static Float:vecOrigin[3]; pev(this, pev_origin, vecOrigin);

    static Float:flDistance; flDistance = 0.0;
    static MONSTER_LOCALMOVE:iLocalMove; iLocalMove = @Monster_CheckLocalMove(this, vecOrigin, vecGoal, pTarget, true, flDistance);

    if (iLocalMove == MONSTER_LOCALMOVE_VALID) {
        @Monster_PushWaypoint(this, vecGoal, iMoveFlag | MF_IS_GOAL);
        return true;
    }

    if (iLocalMove != MONSTER_LOCALMOVE_INVALID_DONT_TRIANGULATE) {
        static Float:vecApex[3];
        if (@Monster_Triangulate(this, vecOrigin, vecGoal, flDistance, pTarget, vecApex)) {
            @Monster_PushWaypoint(this, vecGoal, iMoveFlag | MF_IS_GOAL);
            @Monster_InsertWaypoint(this, vecApex, iMoveFlag | MF_TO_DETOUR);
            @Monster_RouteSimplify(this, pTarget);

            return true;
        }
    }

    return false;
}

bool:@Monster_BuildNearestRoute(this, const Float:vecThreat[3], const Float:vecViewOfs[3], Float:flMinDist, Float:flMaxDist) {
    #if defined _api_navsystem_included
        static Float:vecLookersOffset[3]; xs_vec_add(vecThreat, vecViewOfs, vecLookersOffset);

        static NavArea:pArea; pArea = Nav_GetAreaFromGrid(vecLookersOffset);
        static NavArea:pNearestArea; pNearestArea = Nav_GetNearestArea(vecLookersOffset, false, this, pArea);

        if (pNearestArea == Invalid_NavArea) return false;

        static Float:vecGoal[3];
        Nav_Area_GetCenter(pNearestArea, vecGoal);
        xs_vec_add(vecGoal, vecViewOfs, vecGoal);

        return @Monster_BuildRoute(this, vecGoal, MF_TO_LOCATION, FM_NULLENT);
    #else
        return false;
    #endif
}

@Monster_RouteClear(this) {
    @Monster_RouteNew(this);
    CE_SetMember(this, m_iMovementGoal, MOVEGOAL_NONE);
    CE_SetMember(this, m_iMovementActivity, ACT_IDLE);
    @Monster_Forget(this, MEMORY_MOVE_FAILED);
}

@Monster_IsRouteClear(this) {
    if (CE_GetMember(this, m_iMovementGoal) == MOVEGOAL_NONE) return true;
    if (@Monster_HasConditions(this, COND_WAIT_FOR_PATH)) return false;

    static Array:irgRoute; irgRoute = CE_GetMember(this, m_irgRoute);
    if (!ArraySize(irgRoute)) return true;
    
    return false;
}

bool:@Monster_RefreshRoute(this) {
    @Monster_RouteNew(this);

    new iMovementGoal = CE_GetMember(this, m_iMovementGoal);

    switch (iMovementGoal) {
        case MOVEGOAL_PATHCORNER: {
            static Array:irgRoute; irgRoute = CE_GetMember(this, m_irgRoute);

            new pPathCorner = CE_GetMember(this, m_pGoalEnt);

            while (pPathCorner) {
                static Float:vecTarget[3]; pev(pPathCorner, pev_origin, vecTarget);
                
                static rgWaypoint[MONSTER_WAYPOINT];
                rgWaypoint[MONSTER_WAYPOINT_TYPE] = MF_TO_PATHCORNER;
                xs_vec_copy(vecTarget, rgWaypoint[MONSTER_WAYPOINT_LOCATION]);

                pPathCorner = ExecuteHamB(Ham_GetNextTarget, pPathCorner);

                if (!pPathCorner) {
                    rgWaypoint[MONSTER_WAYPOINT_TYPE] |= MF_IS_GOAL;
                }

                ArrayPushArray(irgRoute, rgWaypoint[any:0]);
            }

            return true;
        }
        case MOVEGOAL_ENEMY: {
            new pEnemy = CE_GetMember(this, m_pEnemy);
            new Float:vecEnemyLKP[3]; CE_GetMemberVec(this, m_vecEnemyLKP, vecEnemyLKP);
            return @Monster_BuildRoute(this, vecEnemyLKP, MF_TO_ENEMY, pEnemy);
        }
        case MOVEGOAL_LOCATION: {
            new Float:vecMoveGoal[3]; CE_GetMemberVec(this, m_vecMoveGoal, vecMoveGoal);
            return @Monster_BuildRoute(this, vecMoveGoal, MF_TO_LOCATION, FM_NULLENT);
        }
        case MOVEGOAL_TARGETENT: {
            new pTarget = CE_GetMember(this, m_pTargetEnt);
            new Float:vecTarget[3]; pev(pTarget, pev_origin, vecTarget); 

            if (pTarget != FM_NULLENT) {
                return @Monster_BuildRoute(this, vecTarget, MF_TO_TARGETENT, pTarget);
            }
        }
        case MOVEGOAL_NODE: {
            new Float:vecMoveGoal[3]; CE_GetMemberVec(this, m_vecMoveGoal, vecMoveGoal);
            return @Monster_GetNodeRoute(this, vecMoveGoal);
        }
    }

    return false;
}

Float:@Monster_CoverRadius(this) {
    return 784.0;
}

bool:@Monster_FindCover(this, const Float:vecThreat[], const Float:vecViewOfs[], const Float:flMinDistance, Float:flData) { return false; }
bool:@Monster_FindLateralCover(this, const Float:vecThreat[3], const Float:vecViewOfs[3]) { return false; }

@Monster_StopAnimation(this) {
    set_pev(this, pev_framerate, 0.0);
}

bool:@Monster_ShouldFadeOnDeath(this) {
    if (pev(this, pev_spawnflags) & SF_MONSTER_FADECORPSE) return true;
    if (pev(this, pev_owner)) return true;

    return false;
}

bool:@Monster_BBoxFlat(this) { return false; }

@Monster_Eat(this, Float:flDuration) {
    CE_SetMember(this, m_flHungryTime, g_flGameTime + flDuration);
}

Activity:@Monster_LookupActivity(this, Activity:iActivity) {
    static Array:irgSequences; irgSequences = CE_GetMember(this, m_irgSequences);
    if (irgSequences == Invalid_Array) return ACTIVITY_NOT_AVAILABLE;

    static Activity:iActivitySeq; iActivitySeq = ACTIVITY_NOT_AVAILABLE;
    static iSequencesNum; iSequencesNum = ArraySize(irgSequences);

    static iTotalWeight; iTotalWeight = 0;

    for (new iSequence = 0; iSequence < iSequencesNum; ++iSequence) {
        static Activity:iSeqActivity; iSeqActivity = ArrayGetCell(irgSequences, iSequence, _:Sequence_Activity);

        if (iActivity != iSeqActivity) continue;

        static iActivityWeight; iActivityWeight = ArrayGetCell(irgSequences, iSequence, _:Sequence_ActivityWeight);

        if (!iTotalWeight || random(iTotalWeight - 1) < iActivityWeight) {
            iActivitySeq = Activity:iSequence;
        }

        iTotalWeight += iActivityWeight;
    }
    
    return iActivitySeq;
}

Activity:@Monster_LookupActivityHeaviest(this, Activity:iActivity) {
    static Array:irgSequences; irgSequences = CE_GetMember(this, m_irgSequences);
    if (irgSequences == Invalid_Array) return ACTIVITY_NOT_AVAILABLE;

    static iWeight; iWeight = 0;

    new Activity:iActivitySeq = ACTIVITY_NOT_AVAILABLE;

    new iSequencesNum = ArraySize(irgSequences);
    for (new iSequence = 0; iSequence <= iSequencesNum; ++iSequence) {
        static Activity:iSeqActivity; iSeqActivity = ArrayGetCell(irgSequences, iSequence, _:Sequence_Activity);
        if (iActivity != iSeqActivity) continue;

        static iActivityWeight; iActivityWeight = ArrayGetCell(irgSequences, iSequence, _:Sequence_ActivityWeight);

        if (iActivityWeight > iWeight) {
            iWeight = iActivityWeight;
            iActivitySeq = Activity:iSequence;
        }
    }
    
    return iActivitySeq;
}

Activity:@Monster_GetStoppedActivity(this) {
    return ACT_IDLE;
}

Activity:@Monster_GetSmallFlinchActivity(this) {
    return ACTIVITY_NOT_AVAILABLE;
}

Activity:@Monster_GetDeathActivity(this) {
    if (pev(this, pev_deadflag) != DEAD_NO) {
        return CE_GetMember(this, m_iIdealActivity);
    }

    new bool:fTriedDirection = false;
    new Activity:iDeathActivity = ACT_DIESIMPLE;

    static Float:vecAngles[3]; pev(this, pev_angles, vecAngles);

    static Float:vecForward[3]; angle_vector(vecAngles, ANGLEVECTOR_FORWARD, vecForward);
    static Float:vecNegAttackDir[3]; xs_vec_neg(g_vecAttackDir, vecNegAttackDir);

    static Float:flDot; flDot = xs_vec_dot(vecForward, vecNegAttackDir);

    switch (CE_GetMember(this, m_iLastHitGroup)) {
        case HITGROUP_HEAD: {
            iDeathActivity = ACT_DIE_HEADSHOT;
        }
        case HITGROUP_STOMACH: {
            iDeathActivity = ACT_DIE_GUTSHOT;
        }
        default: {
            fTriedDirection = true;

            if (flDot > 0.3) {
                iDeathActivity = ACT_DIEFORWARD;
            } else if (flDot <= -0.3) {
                iDeathActivity = ACT_DIEBACKWARD;
            }
        }
    }

    if (@Monster_LookupActivity(this, iDeathActivity) == ACTIVITY_NOT_AVAILABLE) {
        if (fTriedDirection) {
            iDeathActivity = ACT_DIESIMPLE;
        } else {
            if (flDot > 0.3) {
                iDeathActivity = ACT_DIEFORWARD;
            } else if (flDot <= -0.3) {
                iDeathActivity = ACT_DIEBACKWARD;
            }
        }
    }

    if (@Monster_LookupActivity(this, iDeathActivity) == ACTIVITY_NOT_AVAILABLE) {
        iDeathActivity = ACT_DIESIMPLE;
    }

    static Float:vecSrc[3]; ExecuteHamB(Ham_Center, this, vecSrc);

    if (iDeathActivity == ACT_DIEFORWARD || iDeathActivity == ACT_DIEBACKWARD) {
        static iDir; iDir = (iDeathActivity == ACT_DIEFORWARD ? 1 : -1);

        static Float:vecEnd[3]; xs_vec_add_scaled(vecSrc, vecForward, 64.0 * iDir, vecEnd);

        engfunc(EngFunc_TraceHull, vecSrc, vecEnd, DONT_IGNORE_MONSTERS, HULL_HEAD, this, g_pTrace);

        static Float:flFraction; get_tr2(g_pTrace, TR_flFraction, flFraction);

        if (flFraction != 1.0){
            iDeathActivity = ACT_DIESIMPLE;
        }
    }

    return iDeathActivity;
}

@Monster_TakeDamage(this, pInflictor, pAttacker, Float:flDamage, iDamageBits) {
    static Float:flTakeDamage; pev(this, pev_takedamage, flTakeDamage);

    if (flTakeDamage == DAMAGE_NO) return 0;

    if (!ExecuteHamB(Ham_IsAlive, this)) {
        return @Monster_DeadTakeDamage(this, pInflictor, pAttacker, flDamage, iDamageBits);
    }

    if (pev(this, pev_deadflag) == DEAD_NO) {
        CE_CallMethod(this, PainSound);
    }

    static Float:vecDir[3]; xs_vec_set(vecDir, 0.0, 0.0, 0.0);
    if (pInflictor > 0) {
        static Float:vecCenter[3]; ExecuteHamB(Ham_Center, this, vecCenter);
        static Float:vecInflictorCenter[3]; ExecuteHamB(Ham_Center, pInflictor, vecInflictorCenter);

        xs_vec_sub(vecInflictorCenter, vecCenter, vecDir);
        xs_vec_sub(vecDir, Float:{0.0, 0.0, 16.0}, vecDir);
        xs_vec_normalize(vecDir, vecDir);

        xs_vec_copy(vecDir, g_vecAttackDir);
    }

    static Float:flHealth; pev(this, pev_health, flHealth);

    CE_SetMember(this, m_iDamageType, CE_GetMember(this, m_iDamageType) | iDamageBits);

    if (pInflictor && pev(this, pev_movetype) == MOVETYPE_WALK && (!pAttacker || pev(pAttacker, pev_solid) != SOLID_TRIGGER)) {
        static Float:vecVelocity[3]; pev(this, pev_velocity, vecVelocity);
        xs_vec_add_scaled(vecVelocity, vecDir, -@Monster_DamageForce(this, flDamage), vecVelocity);
    }

    pev(this, pev_health, flHealth - flDamage);

    if (CE_GetMember(this, m_iMonsterState) == MONSTER_STATE_SCRIPT) {
        @Monster_SetConditions(this, COND_LIGHT_DAMAGE);
        return 0;
    }

    if (flHealth <= 0) {
        if (iDamageBits & DMG_ALWAYSGIB) {
            ExecuteHamB(Ham_Killed, this, pAttacker, GIB_ALWAYS);
        } else if (iDamageBits & DMG_NEVERGIB) {
            ExecuteHamB(Ham_Killed, this, pAttacker, GIB_NEVER);
        } else {
            ExecuteHamB(Ham_Killed, this, pAttacker, GIB_NORMAL);
        }

        return 0;
    }

    if ((pev(this, pev_flags) & FL_MONSTER) && pAttacker && (pev(pAttacker, pev_flags) & (FL_MONSTER | FL_CLIENT))) {
        static Float:vecEnemyLKP[3]; CE_GetMemberVec(this, m_vecEnemyLKP, vecEnemyLKP);
        
        static pEnemy; pEnemy = CE_GetMember(this, m_pEnemy);

        if (pInflictor) {
            if (!pEnemy || pInflictor == pEnemy || !@Monster_HasConditions(this, COND_SEE_ENEMY)) {
                pev(pInflictor, pev_origin, vecEnemyLKP);
                CE_SetMemberVec(this, m_vecEnemyLKP, vecEnemyLKP);
            }
        } else {
            static Float:vecOrigin[3]; pev(this, pev_origin, vecOrigin);
            xs_vec_add_scaled(vecOrigin, g_vecAttackDir, 64.0, vecEnemyLKP);
            CE_SetMemberVec(this, m_vecEnemyLKP, vecEnemyLKP);
        }

        @Monster_MakeIdealYaw(this, vecEnemyLKP);

        if (flDamage > 0.0) @Monster_SetConditions(this, COND_LIGHT_DAMAGE);
        if (flDamage >= 20.0) @Monster_SetConditions(this, COND_HEAVY_DAMAGE);
    }

    return 1;
}

Float:@Monster_DamageForce(this, Float:flDamage) { 
    static Float:vecSize[3]; pev(this, pev_size, vecSize);

    static Float:flForce; flForce = flDamage * ((32.0 * 32.0 * 72.0) / (vecSize[0] * vecSize[1] * vecSize[2])) * 5;

    return floatmin(flForce, 1000.0);
}


@Monster_DeadTakeDamage(this, pInflictor, pAttacker, Float:flDamage, iDamageBits) {
    static Float:vecDir[3]; xs_vec_set(vecDir, 0.0, 0.0, 0.0);

    if (pInflictor > 0) {
        static Float:vecCenter[3]; ExecuteHamB(Ham_Center, this, vecCenter);
        static Float:vecInflictorCenter[3]; ExecuteHamB(Ham_Center, pInflictor, vecInflictorCenter);

        xs_vec_sub(vecInflictorCenter, vecCenter, g_vecAttackDir);
        xs_vec_sub(g_vecAttackDir, Float:{0.0, 0.0, 10.0}, g_vecAttackDir);
        xs_vec_normalize(g_vecAttackDir, g_vecAttackDir);
    }

    if (iDamageBits & DMG_GIB_CORPSE) {
        static Float:flHealth; pev(this, pev_health, flHealth);

        if (flHealth <= flDamage) {
            flHealth = -50.0;
            ExecuteHamB(Ham_Killed, this, pAttacker, GIB_ALWAYS);
            return 0;
        }

        flHealth -= flDamage * 0.1;

        set_pev(this, pev_health, flHealth);
    }

    return 1;
}

@Monster_StartTask(this, iTask, any:data) { 
    switch (iTask) {
        case TASK_TURN_RIGHT: {
            new Float:vecAngles[3]; pev(this, pev_angles, vecAngles);
            new Float:flCurrentYaw; flCurrentYaw = UTIL_AngleMod(vecAngles[1]);
            set_pev(this, pev_ideal_yaw, UTIL_AngleMod(flCurrentYaw - Float:data));
            @Monster_SetTurnActivity(this);
        }
        case TASK_TURN_LEFT: {
            new Float:vecAngles[3]; pev(this, pev_angles, vecAngles);
            new Float:flCurrentYaw; flCurrentYaw = UTIL_AngleMod(vecAngles[1]);
            set_pev(this, pev_ideal_yaw, UTIL_AngleMod(flCurrentYaw + Float:data));
            @Monster_SetTurnActivity(this);
        }
        case TASK_REMEMBER: {
            @Monster_Remember(this, data);
            @Monster_TaskComplete(this);
        }
        case TASK_FORGET: {
            @Monster_Forget(this, data);
            @Monster_TaskComplete(this);
        }
        case TASK_FIND_HINTNODE: {
            new iHintNode = @Monster_FindHintNode(this);

            CE_SetMember(this, m_iHintNode, iHintNode);

            if (iHintNode != NO_NODE) {
                @Monster_TaskComplete(this);
            } else {
                @Monster_TaskFail(this);
            }
        }
        case TASK_STORE_LASTPOSITION: {
            new Float:vecOrigin[3]; pev(this, pev_origin, vecOrigin);
            CE_SetMemberVec(this, m_vecLastPosition, vecOrigin);
            @Monster_TaskComplete(this);
        }
        case TASK_CLEAR_LASTPOSITION: {
            CE_SetMemberVec(this, m_vecLastPosition, Float:{0.0, 0.0, 0.0});
            @Monster_TaskComplete(this);
        }
        case TASK_CLEAR_HINTNODE: {
            CE_SetMember(this, m_iHintNode, NO_NODE);
            @Monster_TaskComplete(this);
        }
        case TASK_STOP_MOVING: {
            if (CE_GetMember(this, m_iIdealActivity) == CE_GetMember(this, m_iMovementActivity)) {
                CE_SetMember(this, m_iIdealActivity, @Monster_GetStoppedActivity(this));
            }

            @Monster_RouteClear(this);
            @Monster_TaskComplete(this);
        }
        case TASK_PLAY_SEQUENCE_FACE_ENEMY, TASK_PLAY_SEQUENCE_FACE_TARGET, TASK_PLAY_SEQUENCE: {
            CE_SetMember(this, m_iIdealActivity, data);
        }
        case TASK_PLAY_ACTIVE_IDLE: {
            // TODO: Implement
            // new iHintNode = CE_GetMember(this, m_iHintNode);
            // new iActivity = g_pWorldGraphNodes[iHintNode][Nodes_HintActivity];
            // CE_SetMember(this, m_iIdealActivity, iActivity);
        }
        case TASK_SET_SCHEDULE: {
            new Struct:sNewSchedule = CE_CallMethod(this, GetScheduleOfType, MONSTER_SCHEDULE_TYPE:data);
            
            if (sNewSchedule != Invalid_Struct) {
                CE_CallMethod(this, ChangeSchedule, sNewSchedule);
            } else {
                @Monster_TaskFail(this);
            }
        }
        case TASK_FIND_NEAR_NODE_COVER_FROM_ENEMY: {
            new pEnemy = CE_GetMember(this, m_pEnemy);
            if (pEnemy == FM_NULLENT) {
                @Monster_TaskFail(this);
                return;
            }

            new Float:vecEnemyOrigin[3]; pev(pEnemy, pev_origin, vecEnemyOrigin);
            new Float:vecEnemyViewOfs[3]; pev(pEnemy, pev_view_ofs, vecEnemyViewOfs);

            if (@Monster_FindCover(this, vecEnemyOrigin, vecEnemyViewOfs, 0.0, Float:data)) {
                @Monster_TaskComplete(this);
            } else {
                @Monster_TaskFail(this);
            }
        }
        case TASK_FIND_FAR_NODE_COVER_FROM_ENEMY: {
            new pEnemy = CE_GetMember(this, m_pEnemy);
            if (pEnemy == FM_NULLENT) {
                @Monster_TaskFail(this);
                return;
            }

            new Float:vecEnemyOrigin[3]; pev(pEnemy, pev_origin, vecEnemyOrigin);
            new Float:vecEnemyViewOfs[3]; pev(pEnemy, pev_view_ofs, vecEnemyViewOfs);

            if (@Monster_FindCover(this, vecEnemyOrigin, vecEnemyViewOfs, Float:data, @Monster_CoverRadius(this))) {
                @Monster_TaskComplete(this);
            } else {
                @Monster_TaskFail(this);
            }
        }
        case TASK_FIND_NODE_COVER_FROM_ENEMY: {
            new pEnemy = CE_GetMember(this, m_pEnemy);
            if (pEnemy == FM_NULLENT) {
                @Monster_TaskFail(this);
                return;
            }

            new Float:vecEnemyOrigin[3]; pev(pEnemy, pev_origin, vecEnemyOrigin);
            new Float:vecEnemyViewOfs[3]; pev(pEnemy, pev_view_ofs, vecEnemyViewOfs);

            if (@Monster_FindCover(this, vecEnemyOrigin, vecEnemyViewOfs, 0.0, @Monster_CoverRadius(this))) {
                @Monster_TaskComplete(this);
            } else {
                @Monster_TaskFail(this);
            }
        }
        case TASK_FIND_COVER_FROM_ENEMY: {
            new pEnemy = CE_GetMember(this, m_pEnemy);
            new pCover; pCover = pEnemy == FM_NULLENT ? this : pEnemy;
            new Float:vecCoverOrigin[3]; pev(pCover, pev_origin, vecCoverOrigin);
            new Float:vecCoverViewOfs[3]; pev(pCover, pev_view_ofs, vecCoverViewOfs);

            if (@Monster_FindLateralCover(this, vecCoverOrigin, vecCoverViewOfs)) {
                CE_SetMember(this, m_flMoveWaitFinished, g_flGameTime + Float:data);
                @Monster_TaskComplete(this);
            } else if (@Monster_FindCover(this, vecCoverOrigin, vecCoverViewOfs, 0.0, @Monster_CoverRadius(this))) {
                CE_SetMember(this, m_flMoveWaitFinished, g_flGameTime + Float:data);
                @Monster_TaskComplete(this);
            } else {
                @Monster_TaskFail(this);
            }
        }
        case TASK_FIND_COVER_FROM_ORIGIN: {
            new Float:vecOrigin[3]; pev(this, pev_origin, vecOrigin);
            new Float:vecViewOfs[3]; pev(this, pev_view_ofs, vecViewOfs);
            
            if (@Monster_FindCover(this, vecOrigin, vecViewOfs, 0.0, @Monster_CoverRadius(this))) {
                CE_SetMember(this, m_flMoveWaitFinished, g_flGameTime + Float:data);
                @Monster_TaskComplete(this);
            } else {
                @Monster_TaskFail(this);
            }
        }
        case TASK_FIND_COVER_FROM_BEST_SOUND: {
            new iBestSound = @Monster_BestSound(this);

            if (iBestSound != -1 && @Monster_FindCover(this, g_rgSounds[iBestSound][Sound_Origin], Float:{0.0, 0.0, 0.0}, float(g_rgSounds[iBestSound][Sound_Volume]), @Monster_CoverRadius(this))) {
                CE_SetMember(this, m_flMoveWaitFinished, g_flGameTime + Float:data);
                @Monster_TaskComplete(this);
            } else {
                @Monster_TaskFail(this);
            }
        }
        case TASK_FACE_HINTNODE: {
            // TODO: Implement
            // new iHintNode = CE_GetMember(this, m_iHintNode);
            // new Float:flHintYaw = g_pWorldGraphNodes[iHintNode][Nodes_HintYaw];

            // set_pev(this, pev_ideal_yaw, flHintYaw);
            // @Monster_SetTurnActivity(this);
        }
        case TASK_FACE_LASTPOSITION: {
            static Float:vecLastPosition[3]; CE_GetMemberVec(this, m_vecLastPosition, vecLastPosition);
            @Monster_MakeIdealYaw(this, vecLastPosition);
            @Monster_SetTurnActivity(this); 
        }
        case TASK_FACE_TARGET: {
            new pTargetEnt = CE_GetMember(this, m_pTargetEnt);
            
            if (pTargetEnt != FM_NULLENT) {
                new Float:vecTarget[3]; pev(pTargetEnt, pev_origin, vecTarget);
                @Monster_MakeIdealYaw(this, vecTarget);
                @Monster_SetTurnActivity(this); 
            } else {
                @Monster_TaskFail(this);
            }
        }
        case TASK_FACE_ENEMY: {
            new Float:vecEnemyLKP[3]; CE_GetMemberVec(this, m_vecEnemyLKP, vecEnemyLKP);

            @Monster_MakeIdealYaw(this, vecEnemyLKP);
            @Monster_SetTurnActivity(this); 
        }
        case TASK_FACE_IDEAL: {
            @Monster_SetTurnActivity(this);
        }
        case TASK_FACE_ROUTE: {
            if (@Monster_IsRouteClear(this)) {
                @Monster_TaskFail(this);
            } else {
                static Array:irgRoute; irgRoute = CE_GetMember(this, m_irgRoute);
                static rgWaypoint[MONSTER_WAYPOINT]; ArrayGetArray(irgRoute, CE_GetMember(this, m_iRouteIndex), rgWaypoint[any:0], _:MONSTER_WAYPOINT);
                @Monster_MakeIdealYaw(this, rgWaypoint[MONSTER_WAYPOINT_LOCATION]);
                @Monster_SetTurnActivity(this);
            }
        }
        case TASK_WAIT, TASK_WAIT_FACE_ENEMY: {
            CE_SetMember(this, m_flWaitFinished, g_flGameTime + Float:data); 
        }
        case TASK_WAIT_RANDOM: {
            CE_SetMember(this, m_flWaitFinished, g_flGameTime + random_float(0.1, Float:data));
        }
        case TASK_MOVE_TO_TARGET_RANGE: {
            new pTargetEnt = CE_GetMember(this, m_pTargetEnt);
            new Float:vecOrigin[3]; pev(this, pev_origin, vecOrigin);
            new Float:vecTarget[3]; pev(pTargetEnt, pev_origin, vecTarget);

            if (xs_vec_distance(vecOrigin, vecTarget) < 1.0) {
                @Monster_TaskComplete(this);
            } else {
                CE_SetMemberVec(this, m_vecMoveGoal, vecTarget);

                if (!@Monster_MoveToTarget(this, ACT_WALK, 2.0)) {
                    @Monster_TaskFail(this);
                }
            }
        }
        case TASK_RUN_TO_TARGET, TASK_WALK_TO_TARGET: {
            new pTargetEnt = CE_GetMember(this, m_pTargetEnt);

            new Float:vecOrigin[3]; pev(this, pev_origin, vecOrigin);
            new Float:vecTarget[3]; pev(pTargetEnt, pev_origin, vecTarget);

            if (xs_vec_distance(vecOrigin, vecTarget) < 1.0) {
                @Monster_TaskComplete(this);
            } else {
                new Activity:iNewActivity = iTask == TASK_WALK_TO_TARGET ? ACT_WALK : ACT_RUN;

                if (@Monster_LookupActivity(this, iNewActivity) == ACTIVITY_NOT_AVAILABLE) {
                    @Monster_TaskComplete(this);
                } else {
                    if (pTargetEnt == FM_NULLENT || !@Monster_MoveToTarget(this, iNewActivity, 2.0)) {
                        @Monster_TaskFail(this);
                        @Monster_RouteClear(this);
                    }
                }
            }

            @Monster_TaskComplete(this);
        }
        case TASK_CLEAR_MOVE_WAIT: {
            CE_SetMember(this, m_flMoveWaitFinished, g_flGameTime);
            @Monster_TaskComplete(this);
        }
        case TASK_MELEE_ATTACK1_NOTURN, TASK_MELEE_ATTACK1: {
            CE_SetMember(this, m_iIdealActivity, ACT_MELEE_ATTACK1);
        }
        case TASK_MELEE_ATTACK2_NOTURN, TASK_MELEE_ATTACK2: {
            CE_SetMember(this, m_iIdealActivity, ACT_MELEE_ATTACK2);
        }
        case TASK_RANGE_ATTACK1_NOTURN, TASK_RANGE_ATTACK1: {
            CE_SetMember(this, m_iIdealActivity, ACT_RANGE_ATTACK1);
        }
        case TASK_RANGE_ATTACK2_NOTURN, TASK_RANGE_ATTACK2: {
            CE_SetMember(this, m_iIdealActivity, ACT_RANGE_ATTACK2);
        }
        case TASK_RELOAD_NOTURN, TASK_RELOAD: {
            CE_SetMember(this, m_iIdealActivity, ACT_RELOAD);
        }
        case TASK_SPECIAL_ATTACK1: {
            CE_SetMember(this, m_iIdealActivity, ACT_SPECIAL_ATTACK1);
        }
        case TASK_SPECIAL_ATTACK2: {
            CE_SetMember(this, m_iIdealActivity, ACT_SPECIAL_ATTACK2);
        }
        case TASK_SET_ACTIVITY: {
            CE_SetMember(this, m_iIdealActivity, data);
            @Monster_TaskComplete(this);
        }
        case TASK_GET_PATH_TO_ENEMY_LKP: {
            new Float:vecOrigin[3]; pev(this, pev_origin, vecOrigin);
            new Float:vecViewOfs[3]; pev(this, pev_view_ofs, vecViewOfs);
            new Float:vecEnemyLKP[3]; CE_GetMemberVec(this, m_vecEnemyLKP, vecEnemyLKP);

            if (@Monster_BuildRoute(this, vecEnemyLKP, MF_TO_LOCATION, FM_NULLENT)) {
                @Monster_TaskComplete(this);
            } else if (@Monster_BuildNearestRoute(this, vecEnemyLKP, vecViewOfs, 0.0, xs_vec_distance(vecOrigin, vecEnemyLKP))) {
                @Monster_TaskComplete(this);
            } else {
                @Monster_TaskFail(this);
            }
        }
        case TASK_GET_PATH_TO_ENEMY: {
            new Float:vecOrigin[3]; pev(this, pev_origin, vecOrigin);
        
            new pEnemy = CE_GetMember(this, m_pEnemy);
            new Float:vecEnemyOrigin[3]; pev(pEnemy, pev_origin, vecEnemyOrigin);
            new Float:vecEnemyViewOfs[3]; pev(pEnemy, pev_view_ofs, vecEnemyViewOfs);

            if (pEnemy == FM_NULLENT) {
                @Monster_TaskFail(this);
                return;
            }

            if (@Monster_BuildRoute(this, vecEnemyOrigin, MF_TO_ENEMY, pEnemy)) {
                @Monster_TaskComplete(this);
            } else if (@Monster_BuildNearestRoute(this, vecEnemyOrigin, vecEnemyViewOfs, 0.0, xs_vec_distance(vecOrigin, vecEnemyOrigin))) {
                @Monster_TaskComplete(this);
            } else {
                @Monster_TaskFail(this);
            }
        }
        case TASK_GET_PATH_TO_ENEMY_CORPSE: {
            new Float:vecEnemyLKP[3]; CE_GetMemberVec(this, m_vecEnemyLKP, vecEnemyLKP);
            new Float:vecAngles[3]; pev(this, pev_angles, vecAngles);
            new Float:vecForward[3]; angle_vector(vecAngles, ANGLEVECTOR_FORWARD, vecForward);
            new Float:vecTarget[3]; xs_vec_sub_scaled(vecEnemyLKP, vecForward, 64.0, vecTarget);

            if (@Monster_BuildRoute(this, vecTarget, MF_TO_LOCATION, FM_NULLENT)) {
                @Monster_TaskComplete(this);
            } else {
                @Monster_TaskFail(this);
            }
        }
        case TASK_GET_PATH_TO_SPOT: {    
            // TODO: Fix for multiplayer (find best player)
            new pPlayer = find_player_ex(FindPlayer_ExcludeDead);
            new Float:vecMoveGoal[3]; CE_GetMemberVec(this, m_vecLastPosition, vecMoveGoal);

            if (@Monster_BuildRoute(this, vecMoveGoal, MF_TO_LOCATION, pPlayer)) {
                @Monster_TaskComplete(this);
            } else {
                @Monster_TaskFail(this);
            }
        }
        case TASK_GET_PATH_TO_TARGET: {
                new Activity:iMovementActivity = CE_GetMember(this, m_iMovementActivity);
                new pTargetEnt = CE_GetMember(this, m_pTargetEnt);

                @Monster_RouteClear(this);

                if (pTargetEnt != FM_NULLENT && @Monster_MoveToTarget(this, iMovementActivity, 1.0)) {
                    @Monster_TaskComplete(this);
                } else {
                    @Monster_TaskFail(this);
                }
        }
        case TASK_GET_PATH_TO_HINTNODE: {
            // TODO: Implement
            // if (CE_GetMember(this, m_pPathTask) != Invalid_NavBuildPathTask) return;
            // new Activity:iMovementActivity = CE_GetMember(this, m_iMovementActivity);

            // if (@Monster_MoveToLocation(this, iMovementActivity, 2, WorldGraph.m_pNodes[ m_iHintNode ].m_vecOrigin)) {
            //     @Monster_TaskComplete(this);
            // } else {
            //     @Monster_TaskFail(this);
            // }
        }
        case TASK_GET_PATH_TO_LASTPOSITION: {
            // if (CE_GetMember(this, m_pPathTask) != Invalid_NavBuildPathTask) return;

            new Activity:iMovementActivity = CE_GetMember(this, m_iMovementActivity);
            new Float:vecMoveGoal[3]; CE_GetMemberVec(this, m_vecLastPosition, vecMoveGoal);

            if (@Monster_MoveToLocation(this, iMovementActivity, 2.0, vecMoveGoal)) {
                @Monster_TaskComplete(this);
            } else {
                @Monster_TaskFail(this);
            }
        }
        case TASK_GET_PATH_TO_BESTSOUND, TASK_GET_PATH_TO_BESTSCENT: {
                new iSound = -1;

                switch (iTask) {
                    case TASK_GET_PATH_TO_BESTSOUND: iSound = @Monster_BestSound(this);
                    case TASK_GET_PATH_TO_BESTSCENT: iSound = @Monster_BestScent(this);
                }

                if (iSound != -1) {
                    new Activity:iMovementActivity = CE_GetMember(this, m_iMovementActivity);

                    if (@Monster_MoveToLocation(this, iMovementActivity, 2.0, g_rgSounds[iSound][Sound_Origin])) {
                        @Monster_TaskComplete(this);
                    } else {
                        @Monster_TaskFail(this);
                    }
                } else {
                    @Monster_TaskFail(this);
                }
        }
        case TASK_RUN_PATH: {
            if (@Monster_LookupActivity(this, ACT_RUN) != ACTIVITY_NOT_AVAILABLE) {
                CE_SetMember(this, m_iMovementActivity, ACT_RUN);
            } else {
                CE_SetMember(this, m_iMovementActivity, ACT_WALK);
            }

            @Monster_TaskComplete(this);
        }
        case TASK_WALK_PATH: {
            if (pev(this, pev_movetype) == MOVETYPE_FLY) {
                CE_SetMember(this, m_iMovementActivity, ACT_FLY);
            }

            if (@Monster_LookupActivity(this, ACT_WALK) != ACTIVITY_NOT_AVAILABLE) {
                CE_SetMember(this, m_iMovementActivity, ACT_WALK);
            } else {
                CE_SetMember(this, m_iMovementActivity, ACT_RUN);
            }

            @Monster_TaskComplete(this);
        }
        case TASK_STRAFE_PATH: {
            static Array:irgRoute; irgRoute = CE_GetMember(this, m_irgRoute);
            static Float:vecOrigin[3]; pev(this, pev_origin, vecOrigin);
            static Float:vecAngles[3]; pev(this, pev_angles, vecAngles);
            static Float:vecRight[3]; angle_vector(vecAngles, ANGLEVECTOR_RIGHT, vecRight);

            static rgWaypoint[MONSTER_WAYPOINT]; ArrayGetArray(irgRoute, CE_GetMember(this, m_iRouteIndex), rgWaypoint[any:0], _:MONSTER_WAYPOINT);
            @Monster_MakeIdealYaw(this, rgWaypoint[MONSTER_WAYPOINT_LOCATION]);

            new Float:vecDirection[3];
            xs_vec_set(vecDirection, rgWaypoint[MONSTER_WAYPOINT_LOCATION][0] - vecOrigin[0], rgWaypoint[MONSTER_WAYPOINT_LOCATION][1] - vecOrigin[1], 0.0);
            xs_vec_normalize(vecDirection, vecDirection);

            if (xs_vec_dot(vecDirection, vecRight) > 0.0) {
                CE_SetMember(this, m_iMovementActivity, ACT_STRAFE_RIGHT);
            } else {
                CE_SetMember(this, m_iMovementActivity, ACT_STRAFE_LEFT);
            }
    
            @Monster_TaskComplete(this);
        }
        case TASK_WAIT_FOR_MOVEMENT: {
            if (@Monster_IsRouteClear(this)) {
                @Monster_TaskComplete(this);
            }
        }
        case TASK_EAT: {
            @Monster_Eat(this, Float:data);
            @Monster_TaskComplete(this);
        }
        case TASK_SMALL_FLINCH: {
            CE_SetMember(this, m_iIdealActivity, @Monster_GetSmallFlinchActivity(this));
        }
        case TASK_DIE: {
            @Monster_RouteClear(this);    
            CE_SetMember(this, m_iIdealActivity, @Monster_GetDeathActivity(this));
            set_pev(this, pev_deadflag, DEAD_DYING);
        }
        case TASK_SOUND_WAKE: {
            CE_CallMethod(this, AlertSound);
            @Monster_TaskComplete(this);
        }
        case TASK_SOUND_DIE: {
            CE_CallMethod(this, DeathSound);
            @Monster_TaskComplete(this);
        }
        case TASK_SOUND_IDLE: {
            CE_CallMethod(this, IdleSound);
            @Monster_TaskComplete(this);
        }
        case TASK_SOUND_PAIN: {
            CE_CallMethod(this, PainSound);
            @Monster_TaskComplete(this);
        }
        case TASK_SOUND_DEATH: {
            CE_CallMethod(this, DeathSound);
            @Monster_TaskComplete(this);
        }
        case TASK_SOUND_ANGRY: {    
            @Monster_TaskComplete(this);
        }
        case TASK_WAIT_FOR_SCRIPT: {
            static pCine; pCine = CE_GetMember(this, m_pCine);
            if (pCine != FM_NULLENT) {
                static iszIdle; iszIdle = CE_GetMember(pCine, "iszIdle");
                static iszPlay; iszPlay = CE_GetMember(pCine, "iszPlay");

                if (iszIdle) {
                    static szIdle[32]; engfunc(EngFunc_SzFromIndex, iszIdle, szIdle, charsmax(szIdle));
                    static szPlay[32]; engfunc(EngFunc_SzFromIndex, iszPlay, szPlay, charsmax(szPlay));

                    CE_CallMethod(pCine, StartSequence, iszIdle, false);

                    if (equal(szIdle, szPlay)) {
                        set_pev(this, pev_framerate, 0.0);
                    }
                } else {
                    CE_SetMember(this, m_iIdealActivity, ACT_IDLE);
                }
            }
        }
        case TASK_PLAY_SCRIPT: {
            set_pev(this, pev_movetype, MOVETYPE_FLY);
            set_pev(this, pev_flags, pev(this, pev_flags) & ~FL_ONGROUND);
            CE_SetMember(this, m_iScriptState, SCRIPT_PLAYING);
        }
        case TASK_ENABLE_SCRIPT: {
            new pCine = CE_GetMember(this, m_pCine);
            CE_CallMethod(pCine, "DelayStart", 0);
            @Monster_TaskComplete(this);
        }
        case TASK_PLANT_ON_SCRIPT: {
            new pTargetEnt = CE_GetMember(this, m_pTargetEnt);

            if (pTargetEnt != FM_NULLENT) {
                new Float:vecTarget[3]; pev(pTargetEnt, pev_origin, vecTarget);

                set_pev(this, pev_origin, vecTarget);
            }

            @Monster_TaskComplete(this);
        }
        case TASK_FACE_SCRIPT: {
            new pTargetEnt = CE_GetMember(this, m_pTargetEnt);

            if (pTargetEnt != FM_NULLENT) {
                new Float:vecAngles[3]; pev(pTargetEnt, pev_angles, vecAngles);
                set_pev(this, pev_ideal_yaw, UTIL_AngleMod(vecAngles[1]));
            }

            @Monster_TaskComplete(this);
            CE_SetMember(this, m_iIdealActivity, ACT_IDLE);
            @Monster_RouteClear(this);
        }
        case TASK_SUGGEST_STATE: {
            CE_SetMember(this, m_iIdealMonsterState, data);
            @Monster_TaskComplete(this);
        }
        case TASK_SET_FAIL_SCHEDULE: {
            CE_SetMember(this, m_iFailSchedule, data);
            @Monster_TaskComplete(this);
        }
        case TASK_CLEAR_FAIL_SCHEDULE: {
            CE_SetMember(this, m_iFailSchedule, MONSTER_SCHED_NONE);
            @Monster_TaskComplete(this);
        }
    }
}

@Monster_EmitSound(this, iType, Float:vecOrigin[3], iVolume, Float:flDuration) {
    new iSound = @Sound_FindFree();

    g_rgSounds[iSound][Sound_Emitter] = this;
    g_rgSounds[iSound][Sound_Type] = iType;
    g_rgSounds[iSound][Sound_Volume] = iVolume;
    g_rgSounds[iSound][Sound_ExpiredTime] = g_flGameTime + flDuration;
    pev(this, pev_origin, g_rgSounds[iSound][Sound_Origin]);
}

@Sound_FindFree() {
    static iBestSoundToForget; iBestSoundToForget = -1;

    for (new iSound = 0; iSound < sizeof(g_rgSounds); ++iSound) {
        if (g_rgSounds[iSound][Sound_ExpiredTime] <= g_flGameTime) {
            return iSound;
        }

        if (iBestSoundToForget == -1 || g_rgSounds[iSound][Sound_ExpiredTime] < g_rgSounds[iBestSoundToForget][Sound_ExpiredTime]) {
            iBestSoundToForget = iSound;
        }
    }

    return iBestSoundToForget;
}

bool:@Sound_IsSound(this) {
    return !!(g_rgSounds[this][Sound_Type] & (SOUND_COMBAT | SOUND_WORLD | SOUND_PLAYER | SOUND_DANGER));
}

bool:@Sound_IsScent(this) {
    return !!(g_rgSounds[this][Sound_Type] & (SOUND_CARCASS | SOUND_MEAT | SOUND_GARBAGE));
}

@Monster_RunTask(this, iTask, any:data) {
    static Float:flYawSpeed; pev(this, pev_yaw_speed, flYawSpeed);
    static bool:bSequenceFinished; bSequenceFinished = CE_GetMember(this, m_bSequenceFinished);

    switch (iTask) {
        case TASK_TURN_RIGHT, TASK_TURN_LEFT: {
            @Monster_ChangeYaw(this, flYawSpeed);

            if (@Monster_FacingIdeal(this)) {
                @Monster_TaskComplete(this);
            }
        }
        case TASK_PLAY_SEQUENCE_FACE_ENEMY, TASK_PLAY_SEQUENCE_FACE_TARGET: {
            new pEnemy = CE_GetMember(this, m_pEnemy);
            new pTargetEnt = CE_GetMember(this, m_pTargetEnt);
            new pTarget = iTask == TASK_PLAY_SEQUENCE_FACE_TARGET ? pTargetEnt : pEnemy;

            if (pTarget) {
                static Float:vecOrigin[3]; pev(this, pev_origin, vecOrigin);
                static Float:vecTarget[3]; pev(pTarget, pev_origin, vecTarget);
                
                static Float:vecDirection[3];
                xs_vec_sub(vecTarget, vecOrigin, vecDirection);
                xs_vec_normalize(vecDirection, vecDirection);

                static Float:vecAngles[3]; vector_to_angle(vecDirection, vecAngles);

                set_pev(this, pev_ideal_yaw, vecAngles[1]);

                @Monster_ChangeYaw(this, flYawSpeed);
            }
            
            if (bSequenceFinished) {
                @Monster_TaskComplete(this);
            }
        }
        case TASK_PLAY_SEQUENCE, TASK_PLAY_ACTIVE_IDLE: {
            if (bSequenceFinished) {
                @Monster_TaskComplete(this);
            }
        }
        case TASK_FACE_ENEMY: {
            new Float:vecEnemyLKP[3]; CE_GetMemberVec(this, m_vecEnemyLKP, vecEnemyLKP);
            @Monster_MakeIdealYaw(this, vecEnemyLKP);

            @Monster_ChangeYaw(this, flYawSpeed);

            if (@Monster_FacingIdeal(this)) {
                @Monster_TaskComplete(this);
            }
        }
        case TASK_FACE_HINTNODE, TASK_FACE_LASTPOSITION, TASK_FACE_TARGET, TASK_FACE_IDEAL, TASK_FACE_ROUTE: {
            @Monster_ChangeYaw(this, flYawSpeed);

            if (@Monster_FacingIdeal(this)) {
                @Monster_TaskComplete(this);
            }
        }
        case TASK_WAIT_PVS: {
            if (engfunc(EngFunc_FindClientInPVS, this) != FM_NULLENT) {
                @Monster_TaskComplete(this);
            }
        }
        case TASK_WAIT_INDEFINITE: {}
        case TASK_WAIT, TASK_WAIT_RANDOM: {
            new Float:flWaitFinished = CE_GetMember(this, m_flWaitFinished);

            if (g_flGameTime >= flWaitFinished) {
                @Monster_TaskComplete(this);
            }
        }
        case TASK_WAIT_FACE_ENEMY: {
            new Float:vecEnemyLKP[3]; CE_GetMemberVec(this, m_vecEnemyLKP, vecEnemyLKP);
            new Float:flWaitFinished = CE_GetMember(this, m_flWaitFinished);

            @Monster_MakeIdealYaw(this, vecEnemyLKP);
            @Monster_ChangeYaw(this, flYawSpeed); 

            if (g_flGameTime >= flWaitFinished) {
                @Monster_TaskComplete(this);
            }
        }
        case TASK_MOVE_TO_TARGET_RANGE: {
            new pTarget = CE_GetMember(this, m_pTargetEnt);

            if (pTarget == FM_NULLENT) {
                @Monster_TaskFail(this);
            } else { // if (CE_GetMember(this, m_pPathTask) == Invalid_NavBuildPathTask) {
                new Float:vecOrigin[3]; pev(this, pev_origin, vecOrigin);
                new Float:vecTarget[3]; pev(pTarget, pev_origin, vecTarget);
                new Float:vecMoveGoal[3]; CE_GetMemberVec(this, m_vecMoveGoal, vecMoveGoal);

                new Float:flDistance = xs_vec_distance_2d(vecOrigin, vecMoveGoal);

                if ((flDistance < Float:data) || xs_vec_distance(vecTarget, vecMoveGoal) > (Float:data * 0.5)) {
                    pev(pTarget, pev_origin, vecMoveGoal);
                    flDistance = xs_vec_distance_2d(vecOrigin, vecMoveGoal);
                    @Monster_RefreshRoute(this);
                }

                new Activity:iMovementActivity = CE_GetMember(this, m_iMovementActivity);

                if (flDistance < Float:data) {
                    @Monster_TaskComplete(this);
                    @Monster_RouteClear(this);
                } else if (flDistance < 190.0 && iMovementActivity != ACT_WALK) {
                    iMovementActivity = ACT_WALK;
                } else if (flDistance >= 270.0 && iMovementActivity != ACT_RUN) {
                    iMovementActivity = ACT_RUN;
                }
            }
        }
        case TASK_WAIT_FOR_MOVEMENT: {
            if (@Monster_MovementIsComplete(this)) {
                @Monster_TaskComplete(this);
                @Monster_RouteClear(this);
            }
        }
        case TASK_DIE: {
            static Float:flFrame; pev(this, pev_frame, flFrame);
            if (bSequenceFinished && flFrame >= 255.0) {
                set_pev(this, pev_deadflag, DEAD_DEAD);

                CE_CallMethod(this, SetThink, NULL_STRING);
                @Monster_StopAnimation(this);

                if (!@Monster_BBoxFlat(this)) {
                    engfunc(EngFunc_SetSize, this, Float:{-4.0, -4.0, 0.0}, Float:{4.0, 4.0, 1.0});
                } else {      
                    new Float:vecMins[3]; pev(this, pev_mins, vecMins);
                    new Float:vecMaxs[3]; pev(this, pev_maxs, vecMaxs);

                    vecMaxs[2] = vecMins[1] + 1.0;

                    engfunc(EngFunc_SetSize, this, vecMins, vecMaxs);
                }

                if (@Monster_ShouldFadeOnDeath(this)) {
                    @Monster_SUB_StartFadeOut(this);
                } else {
                    static Float:vecOrigin[3]; pev(this, pev_origin, vecOrigin);
                    CE_CallMethod(this, EmitSound, SOUND_CARCASS, vecOrigin, 384, 30.0);
                }
            }
        }
        case TASK_RANGE_ATTACK1_NOTURN, TASK_MELEE_ATTACK1_NOTURN, TASK_MELEE_ATTACK2_NOTURN, TASK_RANGE_ATTACK2_NOTURN, TASK_RELOAD_NOTURN: {
            if (bSequenceFinished) {
                CE_SetMember(this, m_iActivity, ACT_RESET);
                @Monster_TaskComplete(this);
            }
        }
        case TASK_RANGE_ATTACK1, TASK_MELEE_ATTACK1, TASK_MELEE_ATTACK2, TASK_RANGE_ATTACK2, TASK_SPECIAL_ATTACK1, TASK_SPECIAL_ATTACK2, TASK_RELOAD: {
            new Float:vecEnemyLKP[3]; CE_GetMemberVec(this, m_vecEnemyLKP, vecEnemyLKP);

            @Monster_MakeIdealYaw(this, vecEnemyLKP);
            @Monster_ChangeYaw(this, flYawSpeed);

            if (bSequenceFinished) {
                CE_SetMember(this, m_iActivity, ACT_RESET);
                @Monster_TaskComplete(this);
            }
        }
        case TASK_SMALL_FLINCH: {
            if (bSequenceFinished) {
                @Monster_TaskComplete(this);
            }
        }
        case TASK_WAIT_FOR_SCRIPT: {
            new pCine = CE_GetMember(this, m_pCine);
            new iDelay = CE_GetMember(pCine, "iDelay");
            new iszPlay = CE_GetMember(pCine, "iszPlay");
            new Float:flStartTime = CE_GetMember(pCine, "iStartTime");

            if (iDelay <= 0 && g_flGameTime >= flStartTime) {
                @Monster_TaskComplete(this);

                CE_CallMethod(pCine, StartSequence, iszPlay, true);

                if (bSequenceFinished) {
                    @Monster_ClearSchedule(this);
                }

                set_pev(this, pev_framerate, 1.0);
            }
        }
        case TASK_PLAY_SCRIPT: {
            new pCine = CE_GetMember(this, m_pCine);

            if (bSequenceFinished) {
                CE_CallMethod(pCine, SequenceDone);
            }
        }
    }
}

@Monster_AlertSound(this) {}
@Monster_DeathSound(this) {}
@Monster_IdleSound(this) {}
@Monster_PainSound(this) {}

stock UTIL_DrawLine(const Float:vecSrc[], const Float:vecTarget[], const rgiColor[3] = {255, 0, 0}) {
    new iLifeTime = 30;
    new iWidth = 8;
    new iBrightness = 255;
    
    new iModelIndex = engfunc(EngFunc_ModelIndex, "sprites/smoke.spr");

    engfunc(EngFunc_MessageBegin, MSG_PVS, SVC_TEMPENTITY, vecSrc, 0);
    write_byte(TE_BEAMPOINTS);
    engfunc(EngFunc_WriteCoord, vecTarget[0]);
    engfunc(EngFunc_WriteCoord, vecTarget[1]);
    engfunc(EngFunc_WriteCoord, vecTarget[2]);
    engfunc(EngFunc_WriteCoord, vecSrc[0]);
    engfunc(EngFunc_WriteCoord, vecSrc[1]);
    engfunc(EngFunc_WriteCoord, vecSrc[2]);
    write_short(iModelIndex);
    write_byte(0);
    write_byte(0);
    write_byte(iLifeTime);
    write_byte(iWidth);
    write_byte(0);
    write_byte(rgiColor[0]);
    write_byte(rgiColor[1]);
    write_byte(rgiColor[2]);
    write_byte(iBrightness);
    write_byte(0);
    message_end();
}

@Monster_CheckTraceHullAttack(this, Float:flDist, Float:flDamage, iDamageBits) {
    static Float:vecAimAngles[3];
    pev(this, pev_angles, vecAimAngles);
    vecAimAngles[0] = -vecAimAngles[0];

    static Float:vecForward[3]; angle_vector(vecAimAngles, ANGLEVECTOR_FORWARD, vecForward);

    static Float:vecSize[3]; pev(this, pev_size, vecSize);

    static Float:vecStart[3];
    pev(this, pev_origin, vecStart);
    vecStart[2] += vecSize[2] / 2;

    static Float:vecEnd[3]; xs_vec_add_scaled(vecStart, vecForward, flDist, vecEnd);

    engfunc(EngFunc_TraceHull, vecStart, vecEnd, DONT_IGNORE_MONSTERS, HULL_HEAD, this, g_pTrace);
    static pHit; pHit = get_tr2(g_pTrace, TR_pHit);

    if (pHit > 0) {
        if (flDamage > 0.0) {
            ExecuteHamB(Ham_TakeDamage, pHit, this, this, flDamage, iDamageBits);
        }

        return pHit;
    }

    return FM_NULLENT;
}

@Monster_MeleeAttack1(this) {
    static Float:flRange; flRange = CE_GetMember(this, m_flMeleeAttack1Range);
    static Float:flDamage; flDamage = CE_GetMember(this, m_flMeleeAttack1Damage);

    return CE_CallMethod(this, CheckTraceHullAttack, flRange, flDamage, DMG_SLASH);
}

@Monster_MeleeAttack2(this) {
    static Float:flRange; flRange = CE_GetMember(this, m_flMeleeAttack2Range);
    static Float:flDamage; flDamage = CE_GetMember(this, m_flMeleeAttack2Damage);

    return CE_CallMethod(this, CheckTraceHullAttack, flRange, flDamage, DMG_SLASH);
}

FireTargets(const szTargetName[], pActivator, pCaller, iUseType, Float:flValue) {
    if (equal(szTargetName, NULL_STRING)) return;

    static pTarget; pTarget = FM_NULLENT;
    while ((pTarget = engfunc(EngFunc_FindEntityByString, pTarget, "targetname", szTargetName)) != 0) {
        if (pTarget && !(pev(pTarget, pev_flags) & FL_KILLME)) {
            ExecuteHamB(Ham_Use, pTarget, pCaller, pActivator, iUseType, flValue);
        }
    }
}

MapTextureTypeStepType(chTextureType) {
    switch (chTextureType) {
        case CHAR_TEX_CONCRETE: return STEP_CONCRETE;
        case CHAR_TEX_METAL: return STEP_METAL;
        case CHAR_TEX_DIRT: return STEP_DIRT;
        case CHAR_TEX_VENT: return STEP_VENT;
        case CHAR_TEX_GRATE: return STEP_GRATE;
        case CHAR_TEX_TILE: return STEP_TILE;
        case CHAR_TEX_SLOSH: return STEP_SLOSH;
        case CHAR_TEX_SNOW: return STEP_SNOW;
    }

    return STEP_CONCRETE;
}

Float:MapTextureTypeVolume(chTextureType) {
    switch (chTextureType) {
        case CHAR_TEX_CONCRETE: return 0.5;
        case CHAR_TEX_METAL: return 0.5;
        case CHAR_TEX_DIRT: return 0.55;
        case CHAR_TEX_VENT: return 0.7;
        case CHAR_TEX_GRATE: return 0.5;
        case CHAR_TEX_TILE: return 0.5;
        case CHAR_TEX_SLOSH: return 0.5;
    }

    return 0.0;
}

@Monster_CatagorizeTextureType(this) {
    static Float:vecSrc[3]; pev(this, pev_origin, vecSrc);
    static Float:vecEnd[3]; xs_vec_set(vecEnd, vecSrc[0], vecSrc[1], -8192.0);

    static iGroundEntity; iGroundEntity = pev(this, pev_groundentity);
    if (iGroundEntity == FM_NULLENT) return CHAR_TEX_CONCRETE;

    static szTexture[32]; engfunc(EngFunc_TraceTexture, iGroundEntity, vecSrc, vecEnd, szTexture, charsmax(szTexture));

    if (szTexture[0] == '-' || szTexture[0] == '+') {
        format(szTexture, charsmax(szTexture), "%s", szTexture[2]);
    }

    if (szTexture[0] == '{' || szTexture[0] == '!' || szTexture[0] == '~' || szTexture[0] == ' ') {
        format(szTexture, charsmax(szTexture), "%s", szTexture[1]);
    }

    return dllfunc(DLLFunc_PM_FindTextureType, szTexture);
}

@Monster_StepSound(this) {
    if (~pev(this, pev_flags) & FL_ONGROUND) return;

    static Float:vecOrigin[3]; pev(this, pev_origin, vecOrigin);
    static Float:vecMins[3]; pev(this, pev_mins, vecMins);
    static Float:flStepHeight; flStepHeight = CE_GetMember(this, m_flStepHeight);
    static Float:vecKnee[3]; xs_vec_set(vecKnee, vecOrigin[0], vecOrigin[1], vecOrigin[2] - vecMins[2] + flStepHeight);
    static Float:vecFeet[3]; xs_vec_set(vecFeet, vecOrigin[0], vecOrigin[1], vecOrigin[2] - vecMins[2] + (flStepHeight / 2));

    static iStep; iStep = STEP_CONCRETE;
    static Float:fVolume; fVolume = 0.0;
    static bool:bOnLadder; bOnLadder = false;

    if (bOnLadder) {
        iStep = STEP_LADDER;
        fVolume = 0.35;
    } else if (engfunc(EngFunc_PointContents, vecKnee) == CONTENTS_WATER) {
        iStep = STEP_WADE;
        fVolume = 0.65;
    } else if (engfunc(EngFunc_PointContents, vecFeet) == CONTENTS_WATER) {
        iStep = STEP_SLOSH;
        fVolume = 0.5;
    } else {
        static chTextureType; chTextureType = @Monster_CatagorizeTextureType(this);

        iStep = MapTextureTypeStepType(chTextureType);
        fVolume = MapTextureTypeVolume(chTextureType);
    }

    if ((pev(this, pev_flags) & FL_DUCKING)) {
        fVolume *= 0.35;
    }

    @Monster_PlayStepSound(this, iStep, fVolume);
}

@Monster_PlayStepSound(this, iStep, Float:flVolume) {
    static iStepLeft; iStepLeft = CE_GetMember(this, m_iStepLeft);
    static iRand; iRand = random(2) + (iStepLeft * 2);
    static iSkipStep; iSkipStep = 0;

    switch (iStep) {
        case STEP_CONCRETE: {
            switch (iRand) {
                case 0: emit_sound(this, CHAN_BODY, "player/pl_step1.wav", flVolume, ATTN_NORM, 0, PITCH_NORM);
                case 1: emit_sound(this, CHAN_BODY, "player/pl_step3.wav", flVolume, ATTN_NORM, 0, PITCH_NORM);
                case 2: emit_sound(this, CHAN_BODY, "player/pl_step2.wav", flVolume, ATTN_NORM, 0, PITCH_NORM);
                case 3: emit_sound(this, CHAN_BODY, "player/pl_step4.wav", flVolume, ATTN_NORM, 0, PITCH_NORM);
            }   
        }
        case STEP_METAL: {
            switch (iRand) {
                case 0: emit_sound(this, CHAN_BODY, "player/pl_metal1.wav", flVolume, ATTN_NORM, 0, PITCH_NORM);
                case 1: emit_sound(this, CHAN_BODY, "player/pl_metal3.wav", flVolume, ATTN_NORM, 0, PITCH_NORM);
                case 2: emit_sound(this, CHAN_BODY, "player/pl_metal2.wav", flVolume, ATTN_NORM, 0, PITCH_NORM);
                case 3: emit_sound(this, CHAN_BODY, "player/pl_metal4.wav", flVolume, ATTN_NORM, 0, PITCH_NORM);
            }   
        }
        case STEP_DIRT: {
            switch (iRand) {
                case 0: emit_sound(this, CHAN_BODY, "player/pl_dirt1.wav", flVolume, ATTN_NORM, 0, PITCH_NORM);
                case 1: emit_sound(this, CHAN_BODY, "player/pl_dirt3.wav", flVolume, ATTN_NORM, 0, PITCH_NORM);
                case 2: emit_sound(this, CHAN_BODY, "player/pl_dirt2.wav", flVolume, ATTN_NORM, 0, PITCH_NORM);
                case 3: emit_sound(this, CHAN_BODY, "player/pl_dirt4.wav", flVolume, ATTN_NORM, 0, PITCH_NORM);
            }   
        }
        case STEP_VENT: {
            switch (iRand) {
                case 0: emit_sound(this, CHAN_BODY, "player/pl_duct1.wav", flVolume, ATTN_NORM, 0, PITCH_NORM);
                case 1: emit_sound(this, CHAN_BODY, "player/pl_duct3.wav", flVolume, ATTN_NORM, 0, PITCH_NORM);
                case 2: emit_sound(this, CHAN_BODY, "player/pl_duct2.wav", flVolume, ATTN_NORM, 0, PITCH_NORM);
                case 3: emit_sound(this, CHAN_BODY, "player/pl_duct4.wav", flVolume, ATTN_NORM, 0, PITCH_NORM);
            }   
        }
        case STEP_GRATE: {
            switch (iRand) {
                case 0: emit_sound(this, CHAN_BODY, "player/pl_grate1.wav", flVolume, ATTN_NORM, 0, PITCH_NORM);
                case 1: emit_sound(this, CHAN_BODY, "player/pl_grate3.wav", flVolume, ATTN_NORM, 0, PITCH_NORM);
                case 2: emit_sound(this, CHAN_BODY, "player/pl_grate2.wav", flVolume, ATTN_NORM, 0, PITCH_NORM);
                case 3: emit_sound(this, CHAN_BODY, "player/pl_grate4.wav", flVolume, ATTN_NORM, 0, PITCH_NORM);
            }   
        }
        case STEP_TILE: {
            if (!random(5)) {
                iRand = 4;
            }

            switch (iRand) {
                case 0: emit_sound(this, CHAN_BODY, "player/pl_tile1.wav", flVolume, ATTN_NORM, 0, PITCH_NORM);
                case 1: emit_sound(this, CHAN_BODY, "player/pl_tile3.wav", flVolume, ATTN_NORM, 0, PITCH_NORM);
                case 2: emit_sound(this, CHAN_BODY, "player/pl_tile2.wav", flVolume, ATTN_NORM, 0, PITCH_NORM);
                case 3: emit_sound(this, CHAN_BODY, "player/pl_tile4.wav", flVolume, ATTN_NORM, 0, PITCH_NORM);
                case 4: emit_sound(this, CHAN_BODY, "player/pl_tile5.wav", flVolume, ATTN_NORM, 0, PITCH_NORM);
            }   
        }
        case STEP_SLOSH: {
            switch (iRand) {
                case 0: emit_sound(this, CHAN_BODY, "player/pl_slosh1.wav", flVolume, ATTN_NORM, 0, PITCH_NORM);
                case 1: emit_sound(this, CHAN_BODY, "player/pl_slosh3.wav", flVolume, ATTN_NORM, 0, PITCH_NORM);
                case 2: emit_sound(this, CHAN_BODY, "player/pl_slosh2.wav", flVolume, ATTN_NORM, 0, PITCH_NORM);
                case 3: emit_sound(this, CHAN_BODY, "player/pl_slosh4.wav", flVolume, ATTN_NORM, 0, PITCH_NORM);
            }   
        }
        case STEP_WADE: {
            if (iSkipStep == 0) {
                iSkipStep++;
            }

            if (iSkipStep++ == 3) {
                iSkipStep = 0;
            }

            switch (iRand) {
                case 0: emit_sound(this, CHAN_BODY, "player/pl_wade1.wav", flVolume, ATTN_NORM, 0, PITCH_NORM);
                case 1: emit_sound(this, CHAN_BODY, "player/pl_wade2.wav", flVolume, ATTN_NORM, 0, PITCH_NORM);
                case 2: emit_sound(this, CHAN_BODY, "player/pl_wade3.wav", flVolume, ATTN_NORM, 0, PITCH_NORM);
                case 3: emit_sound(this, CHAN_BODY, "player/pl_wade4.wav", flVolume, ATTN_NORM, 0, PITCH_NORM);
            }
   
        }
        case STEP_LADDER: {
            switch (iRand) {
                case 0: emit_sound(this, CHAN_BODY, "player/pl_ladder1.wav", flVolume, ATTN_NORM, 0, PITCH_NORM);
                case 1: emit_sound(this, CHAN_BODY, "player/pl_ladder3.wav", flVolume, ATTN_NORM, 0, PITCH_NORM);
                case 2: emit_sound(this, CHAN_BODY, "player/pl_ladder2.wav", flVolume, ATTN_NORM, 0, PITCH_NORM);
                case 3: emit_sound(this, CHAN_BODY, "player/pl_ladder4.wav", flVolume, ATTN_NORM, 0, PITCH_NORM);
            }   
        }
        case STEP_SNOW: {
            switch (iRand) {
                case 0: emit_sound(this, CHAN_BODY, "player/pl_snow1.wav", flVolume, ATTN_NORM, 0, PITCH_NORM);
                case 1: emit_sound(this, CHAN_BODY, "player/pl_snow3.wav", flVolume, ATTN_NORM, 0, PITCH_NORM);
                case 2: emit_sound(this, CHAN_BODY, "player/pl_snow2.wav", flVolume, ATTN_NORM, 0, PITCH_NORM);
                case 3: emit_sound(this, CHAN_BODY, "player/pl_snow4.wav", flVolume, ATTN_NORM, 0, PITCH_NORM);
            }
        }  
    }

    CE_SetMember(this, m_iStepLeft, !iStepLeft);
}

stock bool:UTIL_IsMasterTriggered(const szMaster[], pActivator) {
  if (!equal(szMaster, NULL_STRING)) {
    new pMaster = engfunc(EngFunc_FindEntityByString, 0, "targetname", szMaster);

    if (pMaster && (ExecuteHam(Ham_ObjectCaps, pMaster) & FCAP_MASTER)) {
      return !!ExecuteHamB(Ham_IsTriggered, pMaster, pActivator);
    }
  }

  return true;
}

stock bool:UTIL_IsDoor(pEntity) {
    if (pEntity == FM_NULLENT) return false;
    if (!pEntity) return false;
    
    static szClassname[32]; pev(pEntity, pev_classname, szClassname, charsmax(szClassname));

    return !!equal(szClassname, "func_door", 9);
}

stock UTIL_IsUsableEntity(pEntity, pWalker) {
    static iszMaster; iszMaster = get_ent_data(pEntity, "CBaseToggle", "m_sMaster");

    if (iszMaster) {
        static szMaster[32]; engfunc(EngFunc_SzFromIndex, iszMaster, szMaster, charsmax(szMaster));

        if (!UTIL_IsMasterTriggered(szMaster, pWalker)) {
            return false;
        }
    }

    return true;
}
