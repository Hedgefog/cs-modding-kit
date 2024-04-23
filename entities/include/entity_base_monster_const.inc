#if defined _entity_monster_base_const_included
  #endinput
#endif
#define _entity_monster_base_const_included

#include <cssdk_const>

#define BASE_MONSTER_ENTITY_NAME "monster_base"

#define MAX_MONSTER_SCHED_TASKS 32

enum MONSTER_TASK_DATA {
    MONSTER_TASK_DATA_ID,
    any:MONSTER_TASK_DATA_DATA
};

enum MONSTER_SCHEDULE_DATA {
    MONSTER_SCHEDULE_DATA_SHARED_ID,
    MONSTER_SCHEDULE_DATA_TASK[_:MONSTER_TASK_DATA * MAX_MONSTER_SCHED_TASKS],
    MONSTER_SCHEDULE_DATA_TASK_SIZE,
    MONSTER_SCHEDULE_DATA_INTERRUPT_MASK,// a bit mask of conditions that can interrupt this schedule 
    MONSTER_SCHEDULE_DATA_SOUND_MASK // a more specific mask that indicates which TYPES of sounds will interrupt the schedule in the event that the schedule is broken by COND_HEAR_SOUND
    // MONSTER_SCHEDULE_NAME[32]
};

enum MONSTER_STATE {
    MONSTER_STATE_NONE,
    MONSTER_STATE_IDLE,
    MONSTER_STATE_COMBAT,
    MONSTER_STATE_ALERT,
    MONSTER_STATE_HUNT,
    MONSTER_STATE_PRONE,
    MONSTER_STATE_SCRIPT,
    MONSTER_STATE_PLAYDEAD,
    MONSTER_STATE_DEAD
};

enum MONSTER_WAYPOINT {
    Float:MONSTER_WAYPOINT_LOCATION[3],
    MONSTER_WAYPOINT_TYPE
}

enum MONSTER_ENEMY {
    MONSTER_ENEMY_ENTITY,
    Float:MONSTER_ENEMY_LOCATION[3]
};

enum MONSTER_TARGET_MOVE {
    MONSTER_TARGET_MOVE_NORMAL,
    MONSTER_TARGET_MOVE_SCRIPTED
};

enum MONSTER_TASK_STATUS {
    MONSTER_TASK_STATUS_NEW, // Just started
    MONSTER_TASK_STATUS_RUNNING, // Running task & movement
    MONSTER_TASK_STATUS_RUNNING_MOVEMENT, // Just running movement
    MONSTER_TASK_STATUS_RUNNING_TASK, // Just running task
    MONSTER_TASK_STATUS_COMPLETE // Completed, get next task
};

enum MONSTER_LOCALMOVE {
    MONSTER_LOCALMOVE_INVALID,
    MONSTER_LOCALMOVE_INVALID_DONT_TRIANGULATE, // move is not possible, don't try to triangulate
    MONSTER_LOCALMOVE_VALID // move is possible
};

enum MONSTER_SCHEDULE_TYPE {
    MONSTER_SCHED_NONE = 0,
    MONSTER_SCHED_IDLE_STAND,
    MONSTER_SCHED_IDLE_WALK,
    MONSTER_SCHED_WAKE_ANGRY,
    MONSTER_SCHED_WAKE_CALLED,
    MONSTER_SCHED_ALERT_FACE,
    MONSTER_SCHED_ALERT_SMALL_FLINCH,
    MONSTER_SCHED_ALERT_BIG_FLINCH,
    MONSTER_SCHED_ALERT_STAND,
    MONSTER_SCHED_INVESTIGATE_SOUND,
    MONSTER_SCHED_COMBAT_FACE,
    MONSTER_SCHED_COMBAT_STAND,
    MONSTER_SCHED_CHASE_ENEMY,
    MONSTER_SCHED_CHASE_ENEMY_FAILED,
    MONSTER_SCHED_VICTORY_DANCE,
    MONSTER_SCHED_TARGET_FACE,
    MONSTER_SCHED_TARGET_CHASE,
    MONSTER_SCHED_SMALL_FLINCH,
    MONSTER_SCHED_TAKE_COVER_FROM_ENEMY,
    MONSTER_SCHED_TAKE_COVER_FROM_BEST_SOUND,
    MONSTER_SCHED_TAKE_COVER_FROM_ORIGIN,
    MONSTER_SCHED_COWER, // usually a last resort!
    MONSTER_SCHED_MELEE_ATTACK1,
    MONSTER_SCHED_MELEE_ATTACK2,
    MONSTER_SCHED_RANGE_ATTACK1,
    MONSTER_SCHED_RANGE_ATTACK2,
    MONSTER_SCHED_SPECIAL_ATTACK1,
    MONSTER_SCHED_SPECIAL_ATTACK2,
    MONSTER_SCHED_STANDOFF,
    MONSTER_SCHED_ARM_WEAPON,
    MONSTER_SCHED_RELOAD,
    MONSTER_SCHED_GUARD,
    MONSTER_SCHED_AMBUSH,
    MONSTER_SCHED_DIE,
    MONSTER_SCHED_WAIT_TRIGGER,
    MONSTER_SCHED_FOLLOW,
    MONSTER_SCHED_SLEEP,
    MONSTER_SCHED_WAKE,
    MONSTER_SCHED_BARNACLE_VICTIM_GRAB,
    MONSTER_SCHED_BARNACLE_VICTIM_CHOMP,
    MONSTER_SCHED_AISCRIPT,
    MONSTER_SCHED_FAIL,

    MONSTER_LAST_COMMON_SCHEDULE // Leave this at the bottom
};

enum MONSTER_SHARED_SCHED {
    MONSTER_SHARED_SCHED_INVALID = -1,
    MONSTER_SHARED_SCHED_ACTIVE_IDLE,
    MONSTER_SHARED_SCHED_IDLE_STAND,
    MONSTER_SHARED_SCHED_IDLE_WALK,
    MONSTER_SHARED_SCHED_WAKE_ANGRY,
    MONSTER_SHARED_SCHED_ALERT_FACE,
    MONSTER_SHARED_SCHED_ALERT_SMALL_FLINCH,
    MONSTER_SHARED_SCHED_ALERT_STAND,
    MONSTER_SHARED_SCHED_INVESTIGATE_SOUND,
    MONSTER_SHARED_SCHED_COMBAT_FACE,
    MONSTER_SHARED_SCHED_COMBAT_STAND,
    MONSTER_SHARED_SCHED_CHASE_ENEMY,
    MONSTER_SHARED_SCHED_CHASE_ENEMY_FAILED,
    MONSTER_SHARED_SCHED_VICTORY_DANCE,
    MONSTER_SHARED_SCHED_SMALL_FLINCH,
    MONSTER_SHARED_SCHED_TAKE_COVER_FROM_ENEMY,
    MONSTER_SHARED_SCHED_TAKE_COVER_FROM_BEST_SOUND,
    MONSTER_SHARED_SCHED_TAKE_COVER_FROM_ORIGIN,
    MONSTER_SHARED_SCHED_COWER,
    MONSTER_SHARED_SCHED_MELEE_ATTACK1,
    MONSTER_SHARED_SCHED_MELEE_ATTACK2,
    MONSTER_SHARED_SCHED_RANGE_ATTACK1,
    MONSTER_SHARED_SCHED_RANGE_ATTACK2,
    MONSTER_SHARED_SCHED_SPECIAL_ATTACK1,
    MONSTER_SHARED_SCHED_SPECIAL_ATTACK2,
    MONSTER_SHARED_SCHED_STANDOFF,
    MONSTER_SHARED_SCHED_ARM_WEAPON,
    MONSTER_SHARED_SCHED_RELOAD,
    MONSTER_SHARED_SCHED_AMBUSH,
    MONSTER_SHARED_SCHED_DIE,
    MONSTER_SHARED_SCHED_WAIT_TRIGGER,
    MONSTER_SHARED_SCHED_BARNACLE_VICTIM_GRAB,
    MONSTER_SHARED_SCHED_BARNACLE_VICTIM_CHOMP,
    MONSTER_SHARED_SCHED_WAIT_SCRIPT,
    MONSTER_SHARED_SCHED_WALK_TO_SCRIPT,
    MONSTER_SHARED_SCHED_RUN_TO_SCRIPT,
    MONSTER_SHARED_SCHED_FACE_SCRIPT,
    MONSTER_SHARED_SCHED_FAIL,
    MONSTER_SHARED_SCHED_ERROR
};

enum {
    SCRIPT_PLAYING, // Playing the sequence
    SCRIPT_WAIT, // Waiting on everyone in the script to be ready
    SCRIPT_CLEANUP, // Cancelling the script / cleaning up
    SCRIPT_WALK_TO_MARK,
    SCRIPT_RUN_TO_MARK
};

enum {
    TASK_WAIT,
    TASK_WAIT_FACE_ENEMY,
    TASK_WAIT_PVS,
    TASK_SUGGEST_STATE,
    TASK_WALK_TO_TARGET,
    TASK_RUN_TO_TARGET,
    TASK_MOVE_TO_TARGET_RANGE,
    TASK_GET_PATH_TO_ENEMY,
    TASK_GET_PATH_TO_ENEMY_LKP,
    TASK_GET_PATH_TO_ENEMY_CORPSE,
    TASK_GET_PATH_TO_LEADER,
    TASK_GET_PATH_TO_SPOT,
    TASK_GET_PATH_TO_TARGET,
    TASK_GET_PATH_TO_HINTNODE,
    TASK_GET_PATH_TO_LASTPOSITION,
    TASK_GET_PATH_TO_BESTSOUND,
    TASK_GET_PATH_TO_BESTSCENT,
    TASK_RUN_PATH,    
    TASK_WALK_PATH,    
    TASK_STRAFE_PATH,
    TASK_CLEAR_MOVE_WAIT,
    TASK_STORE_LASTPOSITION,
    TASK_CLEAR_LASTPOSITION,
    TASK_PLAY_ACTIVE_IDLE,
    TASK_FIND_HINTNODE,
    TASK_CLEAR_HINTNODE,
    TASK_SMALL_FLINCH,
    TASK_FACE_IDEAL,
    TASK_FACE_ROUTE,
    TASK_FACE_ENEMY,
    TASK_FACE_HINTNODE,
    TASK_FACE_TARGET,
    TASK_FACE_LASTPOSITION,
    TASK_RANGE_ATTACK1,
    TASK_RANGE_ATTACK2,        
    TASK_MELEE_ATTACK1,        
    TASK_MELEE_ATTACK2,        
    TASK_RELOAD,
    TASK_RANGE_ATTACK1_NOTURN,
    TASK_RANGE_ATTACK2_NOTURN,        
    TASK_MELEE_ATTACK1_NOTURN,        
    TASK_MELEE_ATTACK2_NOTURN,        
    TASK_RELOAD_NOTURN,
    TASK_SPECIAL_ATTACK1,
    TASK_SPECIAL_ATTACK2,
    TASK_CROUCH,
    TASK_STAND,
    TASK_GUARD,
    TASK_STEP_LEFT,
    TASK_STEP_RIGHT,
    TASK_STEP_FORWARD,
    TASK_STEP_BACK,
    TASK_DODGE_LEFT,
    TASK_DODGE_RIGHT,
    TASK_SOUND_ANGRY,
    TASK_SOUND_DEATH,
    TASK_SET_ACTIVITY,
    TASK_SET_SCHEDULE,
    TASK_SET_FAIL_SCHEDULE,
    TASK_CLEAR_FAIL_SCHEDULE,
    TASK_PLAY_SEQUENCE,
    TASK_PLAY_SEQUENCE_FACE_ENEMY,
    TASK_PLAY_SEQUENCE_FACE_TARGET,
    TASK_SOUND_IDLE,
    TASK_SOUND_WAKE,
    TASK_SOUND_PAIN,
    TASK_SOUND_DIE,
    TASK_FIND_COVER_FROM_BEST_SOUND,// tries lateral cover first, then node cover
    TASK_FIND_COVER_FROM_ENEMY,// tries lateral cover first, then node cover
    TASK_FIND_LATERAL_COVER_FROM_ENEMY,
    TASK_FIND_NODE_COVER_FROM_ENEMY,
    TASK_FIND_NEAR_NODE_COVER_FROM_ENEMY,// data for this one is the MAXIMUM acceptable distance to the cover.
    TASK_FIND_FAR_NODE_COVER_FROM_ENEMY,// data for this one is there MINIMUM aceptable distance to the cover.
    TASK_FIND_COVER_FROM_ORIGIN,
    TASK_EAT,
    TASK_DIE,
    TASK_WAIT_FOR_SCRIPT,
    TASK_PLAY_SCRIPT,
    TASK_ENABLE_SCRIPT,
    TASK_PLANT_ON_SCRIPT,
    TASK_FACE_SCRIPT,
    TASK_WAIT_RANDOM,
    TASK_WAIT_INDEFINITE,
    TASK_STOP_MOVING,
    TASK_TURN_LEFT,
    TASK_TURN_RIGHT,
    TASK_REMEMBER,
    TASK_FORGET,
    TASK_WAIT_FOR_MOVEMENT,            // wait until MovementIsComplete()
    TASK_WAIT_FOR_ROUTE_BUILD,
    LAST_COMMON_TASK // LEAVE THIS AT THE BOTTOM!! (sjb)
};

enum (<<= 1) {
    COND_NO_AMMO_LOADED = (1 << 0), // weapon needs to be reloaded!
    COND_SEE_HATE, // see something that you hate
    COND_SEE_FEAR, // see something that you are afraid of
    COND_SEE_DISLIKE, // see something that you dislike
    COND_SEE_ENEMY, // target entity is in full view.
    COND_ENEMY_OCCLUDED, // target entity occluded by the world
    COND_SMELL_FOOD, 
    COND_ENEMY_TOOFAR, 
    COND_LIGHT_DAMAGE, // hurt a little 
    COND_HEAVY_DAMAGE, // hurt a lot
    COND_CAN_RANGE_ATTACK1,
    COND_CAN_MELEE_ATTACK1,
    COND_CAN_RANGE_ATTACK2,
    COND_CAN_MELEE_ATTACK2,
    COND_PROVOKED, 
    COND_NEW_ENEMY, 
    COND_HEAR_SOUND,  // there is an interesting sound
    COND_SMELL, // there is an interesting scent
    COND_ENEMY_FACING_ME,  // enemy is facing me
    COND_ENEMY_DEAD,  // enemy was killed. If you get this in combat, try to find another enemy. If you get it in alert, victory dance.
    COND_SEE_CLIENT,  // see a client
    COND_SEE_NEMESIS,  // see my nemesis
    COND_WAIT_FOR_PATH = (1 << 27),
    COND_SPECIAL1 = (1 << 28), // Defined by individual monster
    COND_SPECIAL2, // Defined by individual monster
    COND_TASK_FAILED,
    COND_SCHEDULE_DONE
};

enum (<<= 1) {
    MF_TO_TARGETENT = (1 << 0), // local move to targetent.
    MF_TO_ENEMY, // local move to enemy
    MF_TO_COVER, // local move to a hiding place
    MF_TO_DETOUR, // local move to detour point.
    MF_TO_PATHCORNER, // local move to a path corner
    MF_TO_NODE, // local move to a node
    MF_TO_LOCATION, // local move to an arbitrary point
    MF_IS_GOAL, // this MONSTER_WAYPOINT is the goal of the whole move.
    MF_DONT_SIMPLIFY, // Don't let the route code simplify this MONSTER_WAYPOINT
    MF_TO_NAV
};

enum (<<= 1) {
    SOUND_NONE = 0,
    SOUND_COMBAT = (1 << 0), // gunshots, explosions
    SOUND_WORLD, // door opening/closing, glass breaking
    SOUND_PLAYER, // all noises generated by player. walking, shooting, falling, splashing
    SOUND_CARCASS, // dead body
    SOUND_MEAT, // gib or pork chop
    SOUND_DANGER, // pending danger. Grenade that is about to explode, explosive barrel that is damaged, falling crate
    SOUND_GARBAGE // trash cans, banana peels, old fast food bags.
};

enum (<<= 1) {
    CAP_NONE = 0,
    CAP_DUCK = (1 << 0),
    CAP_JUMP,
    CAP_STRAFE,
    CAP_SQUAD,
    CAP_SWIM,
    CAP_CLIMB,
    CAP_USE,
    CAP_HEAR,
    CAP_AUTO_DOORS,
    CAP_OPEN_DOORS,
    CAP_TURN_HEAD,
    CAP_RANGE_ATTACK1,
    CAP_RANGE_ATTACK2,
    CAP_MELEE_ATTACK1,
    CAP_MELEE_ATTACK2,
    CAP_FLY
};

enum (<<= 1) {
    MEMORY_CLEAR = 0,
    MEMORY_PROVOKED = ( 1 << 0 ), // right now only used for houndeyes.
    MEMORY_INCOVER, // monster knows it is in a covered position.
    MEMORY_SUSPICIOUS, // Ally is suspicious of the player, and will move to provoked more easily
    MEMORY_PATH_FINISHED, // Finished monster path (just used by big momma for now)
    MEMORY_ON_PATH, // Moving on a path
    MEMORY_MOVE_FAILED, // Movement has already failed
    MEMORY_FLINCHED, // Has already flinched
    MEMORY_KILLED, // HACKHACK -- remember that I've already called my Killed()
    MEMORY_CUSTOM4 = ( 1 << 28 ), // Monster-specific memory
    MEMORY_CUSTOM3, // Monster-specific memory
    MEMORY_CUSTOM2, // Monster-specific memory
    MEMORY_CUSTOM1 // Monster-specific memory
};

enum {
    EVENT_SPECIFIC = 0,
    SCRIPT_EVENT_DEAD = 1000,
    SCRIPT_EVENT_NOINTERRUPT,
    SCRIPT_EVENT_CANINTERRUPT,
    SCRIPT_EVENT_FIREEVENT,
    SCRIPT_EVENT_SOUND,
    SCRIPT_EVENT_SENTENCE,
    SCRIPT_EVENT_INAIR,
    SCRIPT_EVENT_ENDANIMATION,
    SCRIPT_EVENT_SOUND_VOICE,
    SCRIPT_EVENT_SENTENCE_RND1,
    SCRIPT_EVENT_NOT_DEAD,
    MONSTER_EVENT_BODYDROP_LIGHT = 2001,
    MONSTER_EVENT_BODYDROP_HEAVY,
    MONSTER_EVENT_SWISHSOUND = 2010,
};

#define EVENT_SPECIFIC 0
#define EVENT_SCRIPTED 1000
#define EVENT_SHARED 2000
#define EVENT_CLIENT 5000

#define CAP_DOORS_GROUP (CAP_USE | CAP_AUTO_DOORS | CAP_OPEN_DOORS)

#define MF_NOT_TO_MASK (MF_IS_GOAL | MF_DONT_SIMPLIFY)

#define MOVEGOAL_NONE 0
#define MOVEGOAL_TARGETENT MF_TO_TARGETENT
#define MOVEGOAL_ENEMY MF_TO_ENEMY
#define MOVEGOAL_PATHCORNER MF_TO_PATHCORNER
#define MOVEGOAL_LOCATION MF_TO_LOCATION
#define MOVEGOAL_NODE MF_TO_NODE
#define MOVEGOAL_NAV MF_TO_NAV

#define SCRIPT_BREAK_CONDITIONS    (COND_LIGHT_DAMAGE | COND_HEAVY_DAMAGE)
#define COND_CAN_ATTACK (COND_CAN_RANGE_ATTACK1 | COND_CAN_MELEE_ATTACK1 | COND_CAN_RANGE_ATTACK2 | COND_CAN_MELEE_ATTACK2)

#define R_AL -2  // (ALLY) pals. Good alternative to R_NO when applicable.
#define R_FR -1 // (FEAR)will run
#define R_NO 0 // (NO RELATIONSHIP) disregard
#define R_DL 1 // (DISLIKE) will attack
#define R_HT 2 // (HATE)will attack this character instead of any visible DISLIKEd characters
#define R_NM 3 // (NEMESIS)  A monster Will ALWAYS attack its nemsis, no matter what

#define NO_NODE -1
#define SOUNDLIST_EMPTY    -1
#define ACTIVITY_NOT_AVAILABLE Activity:-1
#define ROUTE_SIZE 8

#define m_iTaskStatus "iTaskStatus"
#define m_iScheduleIndex "iScheduleIndex"
#define m_iMonsterState "iMonsterState"
#define m_iIdealMonsterState "iIdealMonsterState"
#define m_iDelay "iDelay"
#define m_iszPlay "iszPlay"
#define m_iIdealActivity "iIdealActivity"
#define m_iHintNode "iHintNode"
#define m_iMovementActivity "iMovementActivity"
#define m_iVolume "iVolume"
#define m_iRouteIndex "iRouteIndex"
#define m_iszIdle "iszIdle"
#define m_iScriptState "iScriptState"
#define m_pEnemy "pEnemy"
#define m_vecLastPosition "vecLastPosition"
#define m_flMoveWaitFinished "flMoveWaitFinished"
#define m_flWaitFinished "flWaitFinished"
#define m_pTargetEnt "pTarget"
#define m_vecMoveGoal "vecMoveGoal"
#define m_vecEnemyLKP "vecEnemyLKP"
#define m_pCine "pCine"
#define m_iFailSchedule "iFailSchedule"
#define m_bSequenceFinished "bSequenceFinished"
#define m_iActivity "iActivity"
#define m_iMemory "iMemory"
#define m_iMovementGoal "iMovementGoal"
#define m_flMoveWaitTime "flMoveWaitTime"
#define m_flHungryTime "flHungryTime"
#define m_pGoalEnt "pGoalEnt"
#define m_irgRoute "irgRoute"
#define m_flFieldOfView "flFieldOfView"
#define m_bSequenceLoops "bSequenceLoops"
#define m_flFrameRate "flFrameRate"
#define m_flGroundSpeed "flGroundSpeed"
#define m_flDistLook "flDistLook"
#define m_iCapability "iCapability"
#define m_flDistTooFar "flDistTooFar"
#define m_irgOldEnemies "irgOldEnemies"
#define m_iLastHitGroup "iLastHitGroup"
#define m_iDamageType "m_iDamageType"
#define m_vecEyePosition "m_vecEyePosition"
#define m_irgSequences "irgSequences"
#define m_flLastEventCheck "flLastEventCheck"
#define m_iConditions "iConditions"
#define m_sSchedule "sSchedule"
#define m_pPathTask "pPathTask"

#define m_iAudibleList "iAudibleList"
#define m_iSoundTypes "iSoundTypes"
#define m_iThinkPluginId "iThinkPluginId"
#define m_iThinkFunctionId "iThinkFunctionId"
#define m_flRangeAttack1Range "flRangeAttack1Range"
#define m_flRangeAttack2Range "flRangeAttack2Range"
#define m_flMeleeAttack1Range "flMeleeAttack1Range"
#define m_flMeleeAttack2Range "flMeleeAttack2Range"
#define m_flMeleeAttack1Damage "flMeleeAttack1Damage"
#define m_flMeleeAttack2Damage "flMeleeAttack2Damage"
#define m_flStepSize "flStepSize"
#define m_flStepHeight "flStepHeight"
#define m_iStepLeft "iStepLeft"

#define StartSequence "StartSequence"
#define SequenceDone "SequenceDone"
#define Classify "Classify"
#define MonsterInit "MonsterInit"
#define SetState "SetState"
#define SetYawSpeed "SetYawSpeed"
#define SetThink "SetThink"
#define TakeDamage "TakeDamage"
#define AlertSound "AlertSound"
#define DeathSound "DeathSound"
#define IdleSound "IdleSound"
#define PainSound "PainSound"
#define ShouldGibMonster "ShouldGibMonster"
#define CallGibMonster "CallGibMonster"
#define GibMonster "GibMonster"
#define EmitSound "EmitSound"
#define MoveToEnemy "MoveToEnemy"
#define MoveToTarget "MoveToTarget"
#define MoveToLocation "MoveToLocation"
#define HandleAnimEvent "HandleAnimEvent"
#define CheckTraceHullAttack "CheckTraceHullAttack"
#define MeleeAttack1 "MeleeAttack1"
#define MeleeAttack2 "MeleeAttack2"
#define StepSound "StepSound"
#define CalculateHitGroupDamage "CalculateHitGroupDamage"

#define SetSchedule "SetSchedule"

#define SetConditions "SetConditions"
#define ClearConditions "ClearConditions"
#define HasConditions "HasConditions"
#define HasAllConditions "HasAllConditions"
#define IgnoreConditions "IgnoreConditions"
#define GetScheduleOfType "GetScheduleOfType"
#define GetSchedule "GetSchedule"
#define GetSharedSchedule "GetSharedSchedule"
#define IsCurTaskContinuousMove "IsCurTaskContinuousMove"
#define RunTask "RunTask"
#define StartTask "StartTask"
#define MoveExecute "MoveExecute"

#define SetActivity "SetActivity"
#define ChangeSchedule "ChangeSchedule"
#define HandlePathTask "HandlePathTask"

#define Remember "Remember"
#define Forget "Forget"
#define HasMemory "HasMemory"
#define HasAllMemory "HasAllMemory"
