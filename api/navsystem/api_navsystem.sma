/*
  Nav system implementation based on ReGameDLL implementation.

    Nav File Parser
      https://github.com/s1lentq/ReGameDLL_CS/blob/master/regamedll/game_shared/bot/nav_file.h
      https://github.com/s1lentq/ReGameDLL_CS/blob/master/regamedll/game_shared/bot/nav_file.cpp

    Nav Area Members and Methods
      https://github.com/s1lentq/ReGameDLL_CS/blob/master/regamedll/game_shared/bot/nav_area.h
      https://github.com/s1lentq/ReGameDLL_CS/blob/master/regamedll/game_shared/bot/nav_area.cpp

    Nav Path Members and Methods
      https://github.com/s1lentq/ReGameDLL_CS/blob/master/regamedll/game_shared/bot/nav_path.h
      https://github.com/s1lentq/ReGameDLL_CS/blob/master/regamedll/game_shared/bot/nav_path.cpp
*/

#pragma semicolon 1

#include <amxmodx>
#include <fakemeta>
#include <xs>

#include <cellstruct>

#include <api_navsystem_const>

#define INVALID_NAV_AREA -1
#define INVALID_BUILD_PATH_TASK -1

enum _:LADDER_TOP_DIR {
  LADDER_TOP_DIR_AHEAD = 0,
  LADDER_TOP_DIR_LEFT,
  LADDER_TOP_DIR_RIGHT,
  LADDER_TOP_DIR_BEHIND,
  NUM_TOP_DIRECTIONS
};

enum Extent { Float:Extent_Lo[3], Float:Extent_Hi[3] };
enum Ray { Float:Ray_From[3], Float:Ray_To[3]};
enum NavConnect { NavConnect_Id, NavConnect_Area };
enum SpotOrder { SpotOrder_Id, Float:SpotOrder_T, Struct:SpotOrder_Spot };
enum PathSegment { PathSegment_Area, NavTraverseType:PathSegment_How, Float:PathSegment_Pos[3] };
enum NavPath { Array:NavPath_Segments, NavPath_SegmentCount };

enum ApproachInfo {
  ApproachInfo_Here[NavConnect], // the approach area
  ApproachInfo_Prev[NavConnect], // the area just before the approach area on the path
  NavTraverseType:ApproachInfo_PrevToHereHow,
  ApproachInfo_Next[NavConnect], // the area just after the approach area on the path
  NavTraverseType:ApproachInfo_HereToNextHow
};

enum SpotEncounter {
  SpotEncounter_From[NavConnect],
  NavDirType:SpotEncounter_FromDir,
  SpotEncounter_To[NavConnect],
  NavDirType:SpotEncounter_ToDir,
  SpotEncounter_Path[Ray], // the path segment
  Array:SpotEncounter_SpotList // Array[SpotOrder] // list of spots to look at, in order of occurrence
};

enum NavAreaGrid {
  Float:NavAreaGrid_CellSize,
  Array:NavAreaGrid_Grid,
  NavAreaGrid_GridSizeX,
  NavAreaGrid_GridSizeY,
  Float:NavAreaGrid_MinX,
  Float:NavAreaGrid_MinY,
  NavAreaGrid_AreaCount,
  NavAreaGrid_HashTable[HASH_TABLE_SIZE]
};

enum NavArea {
  NavArea_Index,
  NavArea_Id, // unique area ID
  NavArea_Extent[Extent], // extents of area in world coords (NOTE: lo[2] is not necessarily the minimum Z, but corresponds to Z at point (lo[0], lo[1]), etc
  Float:NavArea_Center[3], // centroid of area
  NavAttributeType:NavArea_AttributeFlags, // set of attribute bit flags (see NavAttributeType)

  // height of the implicit corners
  Float:NavArea_NeZ,
  Float:NavArea_SwZ,

  // encounter spots
  Array:NavArea_SpotEncounterList, // Array[SpotEncounter] // list of possible ways to move thru this area, and the spots to look at as we do

  // approach areas
  Array:NavArea_Approach, // Array[ApproachInfo]

  // connections to adjacent areas
  Array:NavArea_Connect[NUM_DIRECTIONS], // a list of adjacent areas for each direction
  Array:NavArea_Ladder[NUM_LADDER_DIRECTIONS], // a list of adjacent areas for each direction

  Array:NavArea_OverlapList, // list of areas that overlap this area

  // connections for grid hash table
  NavArea_PrevHash,
  NavArea_NextHash,

  NavArea_NextOpen, // only valid if m_openMarker == m_masterMarker
  NavArea_PrevOpen,
  NavArea_OpenMarker, // if this equals the current marker value, we are on the open list

  // A* pathfinding algorithm
  NavArea_Marker, // used to flag the area as visited
  NavArea_Parent, // the area just prior to this on in the search path
  NavTraverseType:NavArea_ParentHow, // how we get from parent to us
  Float:NavArea_TotalCost, // the distance so far plus an estimate of the distance left
  Float:NavArea_CostSoFar, // distance travelled so far
};

enum Callback { Callback_PluginId, Callback_FunctionId };

enum BuildPathTask {
  BuildPathTask_Index,
  bool:BuildPathTask_IsFree,
  Float:BuildPathTask_StartPos[3],
  Float:BuildPathTask_GoalPos[3],
  Float:BuildPathTask_ActualGoalPos[3],
  BuildPathTask_StartArea,
  BuildPathTask_GoalArea,
  BuildPathTask_CostCallback[Callback],
  BuildPathTask_FinishCallback[Callback],
  BuildPathTask_IgnoreEntity,
  BuildPathTask_UserToken,
  Struct:BuildPathTask_Path,
  bool:BuildPathTask_IsFinished,
  bool:BuildPathTask_IsSuccessed,
  bool:BuildPathTask_IsTerminated,
  BuildPathTask_IterationsNum
};

enum BuildPathJob {
  BuildPathJob_Task,
  Float:BuildPathJob_ClosestAreaDist,
  BuildPathJob_ClosestArea,
  bool:BuildPathJob_Finished,
  bool:BuildPathJob_Released,
  BuildPathJob_MaxIterations
};

enum NavLadder {
  Float:NavLadder_Top[3],
  Float:NavLadder_Bottom[3],
  Float:NavLadder_Length,
  NavDirType:NavLadder_Dir,
  Float:NavLadder_DirVector[2],
  NavLadder_Entity,
  NavLadder_TopForwardArea,
  NavLadder_TopLeftArea,
  NavLadder_TopRightArea,
  NavLadder_TopBehindArea,
  NavLadder_BottomArea,
  bool:NavLadder_IsDangling
};

const Float:GenerationStepSize = 25.0; 
// const Float:StepHeight = 18.0;
const Float:HalfHumanWidth = 16.0;
const Float:HalfHumanHeight = 36.0;
const Float:HumanHeight = 72.0;

new g_rgGrid[NavAreaGrid];

new g_iNavAreaNextId = 0;
new g_iNavAreaMasterMarker = 1;
new g_iNavAreaOpenList = INVALID_NAV_AREA;

new g_rgBuildPathJob[BuildPathJob];
new Array:g_irgBuildPathTasksQueue = Invalid_Array;

new g_pTrace;

new bool:b_bInitStage = false;
new bool:g_bPrecached = false;
new g_iArrowModelIndex;

new g_rgNavAreas[MAX_NAV_AREAS][NavArea];
new g_iNavAreasNum = 0;

new g_rgBuildPathTasks[MAX_NAV_PATH_TASKS][BuildPathTask];

new g_iMaxIterationsPerFrame = 0;
new bool:g_bDebug = false;

#define NAVAREA_PTR(%1) g_rgNavAreas[%1]
#define NAVAREA_INDEX(%1) %1[NavArea_Index]
#define TASK_PTR(%1) g_rgBuildPathTasks[%1]

public plugin_precache() {
  g_pTrace = create_tr2();
  g_iArrowModelIndex = precache_model("sprites/arrow1.spr");

  for (new i = 0; i < sizeof(g_rgNavAreas); ++i) {
    NAVAREA_PTR(i)[NavArea_Index] = i;
  }
  
  for (new i = 0; i < sizeof(g_rgBuildPathTasks); ++i) {
    g_rgBuildPathTasks[i][BuildPathTask_Index] = i;
    g_rgBuildPathTasks[i][BuildPathTask_IsFree] = true;
  }

  g_rgBuildPathJob[BuildPathJob_Task] = INVALID_BUILD_PATH_TASK;
}

public plugin_init() {
  register_plugin("Nav System", "0.1.0", "Hedgehog Fog");

  b_bInitStage = true;

  if (g_bPrecached) BuildLadders();

  bind_pcvar_num(register_cvar("nav_max_iterations_per_frame", "100"), g_iMaxIterationsPerFrame);
  bind_pcvar_num(register_cvar("nav_debug", "0"), g_bDebug);
}

public plugin_end() {
  for (new i = 0; i < sizeof(g_rgBuildPathTasks); ++i) {
    if (g_rgBuildPathTasks[i][BuildPathTask_Path] != Invalid_Struct) {
      @NavPath_Destroy(g_rgBuildPathTasks[i][BuildPathTask_Path]);
    }
  }

  for (new iArea = 0; iArea < g_iNavAreasNum; ++iArea) {
    if (iArea == INVALID_NAV_AREA) continue;
    @NavArea_Free(NAVAREA_PTR(iArea));
  }

  NavAreaGrid_Free();

  if (g_irgBuildPathTasksQueue != Invalid_Array) {
    ArrayDestroy(g_irgBuildPathTasksQueue);
  }

  free_tr2(g_pTrace);
}

public plugin_natives() {
  register_library("api_navsystem");

  register_native("Nav_Precache", "Native_Precache");

  register_native("Nav_GetAreaCount", "Native_GetAreaCount");
  register_native("Nav_GetArea", "Native_GetArea");
  register_native("Nav_GetAreaById", "Native_GetAreaById");
  register_native("Nav_GetAreaFromGrid", "Native_GetAreaFromGrid");
  register_native("Nav_WorldToGridX", "Native_WorldToGridX");
  register_native("Nav_WorldToGridY", "Native_WorldToGridY");
  register_native("Nav_FindFirstAreaInDirection", "Native_FindFirstAreaInDirection");
  register_native("Nav_IsAreaVisible", "Native_IsAreaVisible");
  register_native("Nav_GetNearestArea", "Native_GetNearestNavArea");

  register_native("Nav_Area_GetAttributes", "Native_Area_GetAttributes");
  register_native("Nav_Area_GetParentHow", "Native_Area_GetParentHow");
  register_native("Nav_Area_GetCenter", "Native_Area_GetCenter");
  register_native("Nav_Area_GetId", "Native_Area_GetId");
  register_native("Nav_Area_Contains", "Native_Area_Contains");
  register_native("Nav_Area_IsCoplanar", "Native_Area_IsCoplanar");
  register_native("Nav_Area_GetZ", "Native_Area_GetZ");
  register_native("Nav_Area_GetClosestPointOnArea", "Native_Area_GetClosestPointOnArea");
  register_native("Nav_Area_GetDistanceSquaredToPoint", "Native_Area_GetDistanceSquaredToPoint");
  register_native("Nav_Area_GetRandomAdjacentArea", "Native_Area_GetRandomAdjacentArea");
  register_native("Nav_Area_IsEdge", "Native_Area_IsEdge");
  register_native("Nav_Area_IsConnected", "Native_Area_IsConnected");
  register_native("Nav_Area_GetCorner", "Native_Area_GetCorner");
  register_native("Nav_Area_ComputeDirection", "Native_Area_ComputeDirection");
  register_native("Nav_Area_ComputePortal", "Native_Area_ComputePortal");
  register_native("Nav_Area_IsOverlapping", "Native_Area_IsOverlapping");
  register_native("Nav_Area_IsOverlappingPoint", "Native_Area_IsOverlappingPoint");
  register_native("Nav_Area_GetCostSoFar", "Native_Area_GetCostSoFar");

  register_native("Nav_Path_IsValid", "Native_Path_IsValid");
  register_native("Nav_Path_GetSegmentCount", "Native_Path_GetSegmentCount");
  register_native("Nav_Path_GetSegmentPos", "Native_Path_GetSegmentPos");
  register_native("Nav_Path_GetSegmentHow", "Native_Path_GetSegmentHow");
  register_native("Nav_Path_GetSegmentArea", "Native_Path_GetSegmentArea");
  register_native("Nav_Path_FindClosestPoint", "Native_Path_FindClosestPoint");

  register_native("Nav_Path_Find", "Native_Path_Find");
  register_native("Nav_Path_FindTask_Await", "Native_Path_FindTask_Await");
  register_native("Nav_Path_FindTask_GetUserToken", "Native_Path_FindTask_GetUserToken");
  register_native("Nav_Path_FindTask_Abort", "Native_Path_FindTask_Abort");
  register_native("Nav_Path_FindTask_GetPath", "Native_Path_FindTask_GetPath");
  register_native("Nav_Path_FindTask_IsFinished", "Native_Path_FindTask_IsFinished");
  register_native("Nav_Path_FindTask_IsSuccessed", "Native_Path_FindTask_IsSuccessed");
  register_native("Nav_Path_FindTask_IsTerminated", "Native_Path_FindTask_IsTerminated");
  register_native("Nav_Path_FindTask_GetIterationsNum", "Native_Path_FindTask_GetIterationsNum");
}

public server_frame() {
  NavAreaBuildPathFrame();
}

public Native_Precache(iPluginId, iArgc) {
  if (g_bPrecached) {
    return;
  }

  LoadNavigationMap();

  g_bPrecached = true;
}

public Native_GetAreaCount(iPluginId, iArgc) {
  return g_iNavAreasNum;
}

public Native_GetArea(iPluginId, iArgc) {
  new iArea = get_param(1);

  return iArea;
}

public Native_GetAreaById(iPluginId, iArgc) {
  new iId = get_param(1);

  return NavAreaGrid_GetNavAreaById(iId);
}

public Native_GetAreaFromGrid(iPluginId, iArgc) {
  static Float:vecPos[3]; get_array_f(1, vecPos, sizeof(vecPos));
  new Float:flBeneathLimit = get_param_f(2);

  return NavAreaGrid_GetNavArea(vecPos, flBeneathLimit);
}

public Native_WorldToGridX(iPluginId, iArgc) {
  new Float:flValue = get_param_f(1);

  return NavAreaGrid_WorldToGridX(flValue);
}

public Native_WorldToGridY(iPluginId, iArgc) {
  new Float:flValue = get_param_f(1);

  return NavAreaGrid_WorldToGridY(flValue);
}
public Native_FindFirstAreaInDirection(iPluginId, iArgc) {
  static Float:vecStart[3]; get_array_f(1, vecStart, sizeof(vecStart));

  new NavDirType:iDir = NavDirType:get_param(2);
  new Float:flRange = get_param_f(3);
  new Float:flBeneathLimit = get_param_f(4);
  new pIgnoreEnt = get_param(5);

  static Float:vecClosePos[3];
  new iArea = FindFirstAreaInDirection(vecStart, iDir, flRange, flBeneathLimit, pIgnoreEnt, vecClosePos);
  set_array_f(6, vecClosePos, sizeof(vecClosePos));

  return iArea;
}

public bool:Native_IsAreaVisible(iPluginId, iArgc) {
  static Float:vecPos[3]; get_array_f(1, vecPos, sizeof(vecPos));

  new iArea = get_param(2);

  return IsAreaVisible(vecPos, NAVAREA_PTR(iArea));
}

public Native_GetNearestNavArea(iPluginId, iArgc) {
  static Float:vecPos[3]; get_array_f(1, vecPos, sizeof(vecPos));
  static bool:bAnyZ; bAnyZ = bool:get_param(2);
  static pIgnoreEnt; pIgnoreEnt = get_param(3);
  static iIgnoreArea; iIgnoreArea = get_param(4);

  return NavAreaGrid_GetNearestNavArea(vecPos, bAnyZ, pIgnoreEnt, iIgnoreArea);
}

public Native_Path_Find(iPluginId, iArgc) {
  static Float:vecStart[3]; get_array_f(1, vecStart, sizeof(vecStart));
  static Float:vecGoal[3]; get_array_f(2, vecGoal, sizeof(vecGoal));
  static szCbFunction[32]; get_string(3, szCbFunction, charsmax(szCbFunction));
  static pIgnoreEnt; pIgnoreEnt = get_param(4);
  static iUserToken; iUserToken = get_param(5);
  static szCostFunction[32]; get_string(6, szCostFunction, charsmax(szCostFunction));

  static iCostFuncId; iCostFuncId = equal(szCostFunction, NULL_STRING) ? -1 : get_func_id(szCostFunction, iPluginId);
  static iCbFuncId; iCbFuncId = equal(szCbFunction, NULL_STRING) ? -1 : get_func_id(szCbFunction, iPluginId);

  return NavAreaBuildPath(vecStart, vecGoal, iCbFuncId, iPluginId, pIgnoreEnt, iUserToken, iCostFuncId, iPluginId);
}

public NavAttributeType:Native_Area_GetAttributes(iPluginId, iArgc) {
  new iArea = get_param(1);

  return @NavArea_GetAttributes(NAVAREA_PTR(iArea));
}

public NavTraverseType:Native_Area_GetParentHow(iPluginId, iArgc) {
  new iArea = get_param(1);

  return @NavArea_GetParentHow(NAVAREA_PTR(iArea));
}

public Native_Area_GetCenter(iPluginId, iArgc) {
  new iArea = get_param(1);
  static Float:vecCenter[3]; @NavArea_GetCenter(NAVAREA_PTR(iArea), vecCenter);

  set_array_f(2, vecCenter, sizeof(vecCenter));
}

public Native_Path_FindTask_Await(iPluginId, iArgc) {
  static iTask; iTask = get_param(1);

  if (g_rgBuildPathTasks[iTask][BuildPathTask_IsFree]) {
    return;
  }

  while (
    g_rgBuildPathJob[BuildPathJob_Task] != iTask ||
    !g_rgBuildPathJob[BuildPathJob_Finished]
  ) {
    NavAreaBuildPathFrame();
  }

  // g_rgBuildPathTasks[iTask][BuildPathTask_IsFree] = true;
}

public bool:Native_Path_FindTask_IsFinished(iPluginId, iArgc) {
  new iTask = get_param(1);

  return g_rgBuildPathTasks[iTask][BuildPathTask_IsFinished];
}

public Native_Path_FindTask_GetUserToken(iPluginId, iArgc) {
  new iTask = get_param(1);

  return g_rgBuildPathTasks[iTask][BuildPathTask_UserToken];
}

public bool:Native_Path_FindTask_Abort(iPluginId, iArgc) {
  new iTask = get_param(1);

  return NavAreaBuildPathAbortTask(TASK_PTR(iTask));
}

public Struct:Native_Path_FindTask_GetPath(iPluginId, iArgc) {
  new iTask = get_param(1);

  return g_rgBuildPathTasks[iTask][BuildPathTask_Path];
}

public bool:Native_Path_FindTask_IsSuccessed(iPluginId, iArgc) {
  new iTask = get_param(1);

  return g_rgBuildPathTasks[iTask][BuildPathTask_IsSuccessed];
}

public bool:Native_Path_FindTask_IsTerminated(iPluginId, iArgc) {
  new iTask = get_param(1);

  return g_rgBuildPathTasks[iTask][BuildPathTask_IsTerminated];
}

public Native_Path_FindTask_GetIterationsNum(iPluginId, iArgc) {
  new iTask = get_param(1);

  return g_rgBuildPathTasks[iTask][BuildPathTask_IterationsNum];
}

public bool:Native_Path_IsValid(iPluginId, iArgc) {
  static Struct:sNavPath; sNavPath = Struct:get_param(1);

  return @NavPath_IsValid(sNavPath);
}

public Array:Native_Path_GetSegmentCount(iPluginId, iArgc) {
  static Struct:sNavPath; sNavPath = Struct:get_param(1);

  return StructGetCell(sNavPath, NavPath_SegmentCount);
}

public Native_Path_GetSegmentPos(iPluginId, iArgc) {
  static Struct:sNavPath; sNavPath = Struct:get_param(1);
  static iSegment; iSegment = get_param(2);

  static Array:irgSegments; irgSegments = StructGetCell(sNavPath, NavPath_Segments);

  static Float:vecPos[3]; ArrayGetArray2(irgSegments, iSegment, vecPos, 3, PathSegment_Pos);

  set_array_f(3, vecPos, sizeof(vecPos));
}

public NavTraverseType:Native_Path_GetSegmentHow(iPluginId, iArgc) {
  static Struct:sNavPath; sNavPath = Struct:get_param(1);
  static iSegment; iSegment = get_param(2);

  static Array:irgSegments; irgSegments = StructGetCell(sNavPath, NavPath_Segments);

  return ArrayGetCell(irgSegments, iSegment, _:PathSegment_How);
}

public NavTraverseType:Native_Path_GetSegmentArea(iPluginId, iArgc) {
  static Struct:sNavPath; sNavPath = Struct:get_param(1);
  static iSegment; iSegment = get_param(2);

  static Array:irgSegments; irgSegments = StructGetCell(sNavPath, NavPath_Segments);

  return ArrayGetCell(irgSegments, iSegment, _:PathSegment_Area);
}

public Native_Path_FindClosestPoint(iPluginId, iArgc) {
  static Struct:sNavPath; sNavPath = Struct:get_param(1);
  static Float:vecWorldPos[3]; get_array_f(2, vecWorldPos, sizeof(vecWorldPos));
  static iStartIndex; iStartIndex = get_param(3);
  static iEndIndex; iEndIndex = get_param(4);

  static Float:vecClose[3];
  if (!@NavPath_FindClosestPointOnPath(sNavPath, vecWorldPos, iStartIndex, iEndIndex, vecClose)) {
    return false;
  }

  set_array_f(5, vecClose, sizeof(vecClose));

  return true;
}

public Native_Area_GetId(iPluginId, iArgc) {
  new iArea = get_param(1);

  return @NavArea_GetId(NAVAREA_PTR(iArea));
}

public bool:Native_Area_Contains(iPluginId, iArgc) {
  new iArea = get_param(1);
  static Float:vecPoint[3]; get_array_f(2, vecPoint, sizeof(vecPoint));

  return @NavArea_Contains(NAVAREA_PTR(iArea), vecPoint);
}

public bool:Native_Area_IsCoplanar(iPluginId, iArgc) {
  new iArea = get_param(1);
  new iOtherArea = get_param(2);

  return @NavArea_IsCoplanar(NAVAREA_PTR(iArea), iOtherArea);
}

public Float:Native_Area_GetZ(iPluginId, iArgc) {
  new iArea = get_param(1);
  static Float:vecPos[3]; get_array_f(2, vecPos, sizeof(vecPos));

  return @NavArea_GetZ(NAVAREA_PTR(iArea), vecPos);
}

public Native_Area_GetClosestPointOnArea(iPluginId, iArgc) {
  new iArea = get_param(1);
  static Float:vecPos[3]; get_array_f(2, vecPos, sizeof(vecPos));

  static Float:vecClose[3];
  @NavArea_GetClosestPointOnArea(NAVAREA_PTR(iArea), vecPos, vecClose);

  set_array_f(3, vecClose, sizeof(vecClose));
}

public Float:Native_Area_GetDistanceSquaredToPoint(iPluginId, iArgc) {
  new iArea = get_param(1);
  static Float:vecPoint[3]; get_array_f(2, vecPoint, sizeof(vecPoint));

  return @NavArea_GetDistanceSquaredToPoint(NAVAREA_PTR(iArea), vecPoint);
}

public Native_Area_GetRandomAdjacentArea(iPluginId, iArgc) {
  new iArea = get_param(1);
  new NavDirType:iDir = NavDirType:get_param(2);

  return @NavArea_GetRandomAdjacentArea(NAVAREA_PTR(iArea), iDir);
}

public bool:Native_Area_IsEdge(iPluginId, iArgc) {
  new iArea = get_param(1);
  new NavDirType:iDir = NavDirType:get_param(2);

  return @NavArea_IsEdge(NAVAREA_PTR(iArea), iDir);
}

public bool:Native_Area_IsConnected(iPluginId, iArgc) {
  new iArea = get_param(1);
  new iOtherArea = get_param(2);
  new NavDirType:iDir = NavDirType:get_param(3);

  return @NavArea_IsConnected(NAVAREA_PTR(iArea), NAVAREA_PTR(iOtherArea), iDir);
}

public Native_Area_GetCorner(iPluginId, iArgc) {
  new iArea = get_param(1);
  new NavCornerType:iCorner = NavCornerType:get_param(2);
  static Float:vecPos[3]; get_array_f(3, vecPos, sizeof(vecPos));

  @NavArea_GetCorner(NAVAREA_PTR(iArea), iCorner, vecPos);

  set_array_f(3, vecPos, sizeof(vecPos));
}

public NavDirType:Native_Area_ComputeDirection(iPluginId, iArgc) {
  new iArea = get_param(1);
  static Float:vecPoint[3]; get_array_f(2, vecPoint, sizeof(vecPoint));

  return @NavArea_ComputeDirection(NAVAREA_PTR(iArea), vecPoint);
}

public Native_Area_ComputePortal(iPluginId, iArgc) {
  new iArea = get_param(1);
  new iOtherArea = get_param(2);
  new NavDirType:iDir = NavDirType:get_param(3);

  static Float:vecCenter[3];
  static Float:flHalfWidth;

  @NavArea_ComputePortal(NAVAREA_PTR(iArea), NAVAREA_PTR(iOtherArea), iDir, vecCenter, flHalfWidth);

  set_array_f(4, vecCenter, sizeof(vecCenter));
  set_float_byref(5, flHalfWidth);
}

public bool:Native_Area_IsOverlapping(iPluginId, iArgc) {
  new iArea = get_param(1);
  new iOtherArea = get_param(2);

  return @NavArea_IsOverlapping(NAVAREA_PTR(iArea), iOtherArea);
}

public bool:Native_Area_IsOverlappingPoint(iPluginId, iArgc) {
  new iArea = get_param(1);
  static Float:vecPoint[3]; get_array_f(3, vecPoint, sizeof(vecPoint));

  return @NavArea_IsOverlappingPoint(NAVAREA_PTR(iArea), vecPoint);
}

public Float:Native_Area_GetCostSoFar(iPluginId, iArgc) {
  new iArea = get_param(1);

  return @NavArea_GetCostSoFar(NAVAREA_PTR(iArea));
}

@NavArea_Allocate(this[NavArea]) {
  this[NavArea_PrevHash] = INVALID_NAV_AREA;
  this[NavArea_NextHash] = INVALID_NAV_AREA;
  this[NavArea_PrevOpen] = INVALID_NAV_AREA;
  this[NavArea_NextOpen] = INVALID_NAV_AREA;
  this[NavArea_Parent] = INVALID_NAV_AREA;
  this[NavArea_SpotEncounterList] = ArrayCreate(_:SpotEncounter);
  this[NavArea_Approach] = ArrayCreate(_:ApproachInfo);
  this[NavArea_OverlapList] = ArrayCreate();

  for (new NavDirType:d = NORTH; d < NUM_DIRECTIONS; d++) {
    this[NavArea_Connect][d] = ArrayCreate(_:NavConnect);
  }

  for (new LadderDirectionType:d = LADDER_UP; d < NUM_LADDER_DIRECTIONS; d++) {
    this[NavArea_Ladder][d] = ArrayCreate(_:NavLadder);
  }
}

@NavArea_Free(this[NavArea]) {
  new Array:irgSpotEncounterList = this[NavArea_SpotEncounterList];

  new iSpotEncounterListSize = ArraySize(irgSpotEncounterList);
  for (new i = 0; i < iSpotEncounterListSize; ++i) {
    new Array:irgSpotList = ArrayGetCell(irgSpotEncounterList, i, _:SpotEncounter_SpotList);
    ArrayDestroy(irgSpotList);
  }

  ArrayDestroy(irgSpotEncounterList);

  ArrayDestroy(this[NavArea_Approach]);
  ArrayDestroy(this[NavArea_OverlapList]);

  for (new NavDirType:d = NORTH; d < NUM_DIRECTIONS; d++) {
    ArrayDestroy(this[NavArea_Connect][d]);
  }

  for (new LadderDirectionType:d = LADDER_UP; d < NUM_LADDER_DIRECTIONS; d++) {
    ArrayDestroy(this[NavArea_Ladder][d]);
  }
}

@NavArea_Load(this[NavArea], iFile, iVersion, bool:bDebug) {
  new Array:irgSpotEncounterList = this[NavArea_SpotEncounterList];
  new Array:irgApproachList = this[NavArea_Approach];

  // load ID
  new iId;
  FileReadInt32(iFile, iId);
  this[NavArea_Id] = iId;

  // update nextID to avoid collisions
  if (iId >= g_iNavAreaNextId) {
    g_iNavAreaNextId = iId + 1;
  }

  // load attribute flags
  FileReadUint8(iFile, this[NavArea_AttributeFlags]);

  // load extent of area
  fread_blocks(iFile, this[NavArea_Extent][Extent_Lo], 3, BLOCK_INT);
  fread_blocks(iFile, this[NavArea_Extent][Extent_Hi], 3, BLOCK_INT);

  for (new i = 0; i < 3; ++i) {
    this[NavArea_Center][i] = (this[NavArea_Extent][Extent_Lo][i] + this[NavArea_Extent][Extent_Hi][i]) / 2.0;
  }


  // load heights of implicit corners

  FileReadInt32(iFile, this[NavArea_NeZ]);

  FileReadInt32(iFile, this[NavArea_SwZ]);

  // load connections (IDs) to adjacent areas
  // in the enum order NORTH, EAST, SOUTH, WEST
  for (new NavDirType:d = NORTH; d < NUM_DIRECTIONS; d++) {
    // load number of connections for this direction
    new iConnectionCount; FileReadInt32(iFile, iConnectionCount);

    for (new i = 0; i < iConnectionCount; i++) {
      new rgConnect[NavConnect];
      FileReadInt32(iFile, rgConnect[NavConnect_Id]);
      ArrayPushArray(Array:this[NavArea_Connect][d], rgConnect[any:0]);
    }
  }

  // load number of hiding spots
  new iHidingSpotCount;
  FileReadUint8(iFile, iHidingSpotCount);

  // skip hiding spots
  if (iVersion == 1) {
    fseek(iFile, iHidingSpotCount * (3 * BLOCK_INT), SEEK_CUR);
  } else {
    fseek(iFile, iHidingSpotCount * (BLOCK_INT + (3 * BLOCK_INT) + BLOCK_CHAR), SEEK_CUR);
  }

  // Load number of approach areas
  new iApproachCount;
  FileReadUint8(iFile, iApproachCount);

  // load approach area info (IDs)
  for (new a = 0; a < iApproachCount; a++) {
    new rgApproach[ApproachInfo];
    FileReadInt32(iFile, rgApproach[ApproachInfo_Here][NavConnect_Id]);
    FileReadInt32(iFile, rgApproach[ApproachInfo_Prev][NavConnect_Id]);
    FileReadUint8(iFile, rgApproach[ApproachInfo_PrevToHereHow]);
    FileReadInt32(iFile, rgApproach[ApproachInfo_Next][NavConnect_Id]);
    FileReadUint8(iFile, rgApproach[ApproachInfo_HereToNextHow]);
    ArrayPushArray(irgApproachList, rgApproach[any:0]);
  }

  // Load encounter paths for this area
  new iEncounterCount;
  FileReadInt32(iFile, iEncounterCount);

  for (new e = 0; e < iEncounterCount; e++) {
    new rgEncounter[SpotEncounter];
    rgEncounter[SpotEncounter_SpotList] = ArrayCreate(_:SpotOrder);

    FileReadInt32(iFile, rgEncounter[SpotEncounter_From][NavConnect_Id]);

    if (iVersion < 3) {
      FileReadInt32(iFile, rgEncounter[SpotEncounter_To][NavConnect_Id]);
      fread_blocks(iFile, rgEncounter[SpotEncounter_Path][Ray_From], 3, BLOCK_INT);
      fread_blocks(iFile, rgEncounter[SpotEncounter_Path][Ray_To], 3, BLOCK_INT);
    } else {
      FileReadUint8(iFile, rgEncounter[SpotEncounter_FromDir]);
      FileReadInt32(iFile, rgEncounter[SpotEncounter_To][NavConnect_Id]);
      FileReadUint8(iFile, rgEncounter[SpotEncounter_ToDir]);
    }

    // read list of spots along this path
    new iSpotCount;
    FileReadUint8(iFile, iSpotCount);

    if (iVersion < 3) {
      for (new s = 0; s < iSpotCount; s++) {
        static Float:vecPos[3];
        fread_blocks(iFile, vecPos, 3, BLOCK_INT);
        FileReadInt32(iFile, vecPos[0]);
      }
    } else {
      for (new s = 0; s < iSpotCount; s++) {
        new rgOrder[SpotOrder];
        FileReadInt32(iFile, rgOrder[SpotOrder_Id]);

        FileReadUint8(iFile, rgOrder[SpotOrder_T]);
        rgOrder[SpotOrder_T] /= 255.0;
        ArrayPushCell(rgEncounter[SpotEncounter_SpotList], rgOrder[any:0]);
      }
    }

    // old data, discard
    if (iVersion >= 3) {
      ArrayPushArray(irgSpotEncounterList, rgEncounter[any:0]);
    }
  }

  if (iVersion < NAV_VERSION) {
    return;
  }

  fseek(iFile, BLOCK_SHORT, SEEK_CUR);
}

NavErrorType:@NavArea_PostLoadArea(const this[NavArea]) {
  new NavErrorType:error = NAV_OK;

  // connect areas together
  for (new NavDirType:d = NORTH; d < NUM_DIRECTIONS; d++) {
    new Array:irgConnections = Array:this[NavArea_Connect][d];
    new iConnectionCount = ArraySize(irgConnections);

    for (new i = 0; i < iConnectionCount; ++i) {
      new iConnectId = ArrayGetCell(irgConnections, i, _:NavConnect_Id);
      new iArea = NavAreaGrid_GetNavAreaById(iConnectId);
      ArraySetCell(irgConnections, i, iArea, _:NavConnect_Area);

      if (iConnectId && iArea == INVALID_NAV_AREA) {
        log_amx("ERROR: Corrupt navigation data. Cannot connect Navigation Areas.^n");
        error = NAV_CORRUPT_DATA;
      }
    }
  }

  // resolve approach area IDs
  new Array:irgApproachList = this[NavArea_Approach];
  new iApproachCount = ArraySize(irgApproachList);
  for (new a = 0; a < iApproachCount; a++) {
    new iApproachHereId = ArrayGetCell(irgApproachList, a, _:ApproachInfo_Here + _:NavConnect_Id);
    new iApproachHereArea = NavAreaGrid_GetNavAreaById(iApproachHereId);
    ArraySetCell(irgApproachList, a, iApproachHereArea, _:ApproachInfo_Here + _:NavConnect_Area);
    if (iApproachHereId && iApproachHereArea == INVALID_NAV_AREA) {
      log_amx("ERROR: Corrupt navigation data. Missing Approach Area (here).^n");
      error = NAV_CORRUPT_DATA;
    }

    new iApproachPrevId = ArrayGetCell(irgApproachList, a, _:ApproachInfo_Prev + _:NavConnect_Id);
    new iApproachPrevArea = NavAreaGrid_GetNavAreaById(iApproachPrevId);
    ArraySetCell(irgApproachList, a, iApproachPrevArea, _:ApproachInfo_Prev + _:NavConnect_Area);
    if (iApproachPrevId && iApproachPrevArea == INVALID_NAV_AREA) {
      log_amx("ERROR: Corrupt navigation data. Missing Approach Area (prev).^n");
      error = NAV_CORRUPT_DATA;
    }

    new iApproachNextId = ArrayGetCell(irgApproachList, a, _:ApproachInfo_Next + _:NavConnect_Id);
    new iApproachNextArea = NavAreaGrid_GetNavAreaById(iApproachNextId);
    ArraySetCell(irgApproachList, a, iApproachNextArea, _:ApproachInfo_Next + _:NavConnect_Area);
    if (iApproachNextId && iApproachNextArea == INVALID_NAV_AREA) {
      log_amx("ERROR: Corrupt navigation data. Missing Approach Area (next).^n");
      error = NAV_CORRUPT_DATA;
    }
  }

  // resolve spot encounter IDs
  new Array:irgSpotEncounterList = this[NavArea_SpotEncounterList];
  new iSpotEncounterCount = ArraySize(irgSpotEncounterList);
  for (new e = 0; e < iSpotEncounterCount; e++) {
    new rgSpot[SpotEncounter]; ArrayGetArray(irgSpotEncounterList, e, rgSpot[any:0]);

    rgSpot[SpotEncounter_From][NavConnect_Area] = NavAreaGrid_GetNavAreaById(rgSpot[SpotEncounter_From][NavConnect_Id]);
    if (rgSpot[SpotEncounter_From][NavConnect_Area] == INVALID_NAV_AREA) {
      log_amx("ERROR: Corrupt navigation data. Missing ^"from^" Navigation Area for Encounter Spot.^n");
      error = NAV_CORRUPT_DATA;
    }

    rgSpot[SpotEncounter_To][NavConnect_Area] = NavAreaGrid_GetNavAreaById(rgSpot[SpotEncounter_To][NavConnect_Id]);
    if (rgSpot[SpotEncounter_To][NavConnect_Area] == INVALID_NAV_AREA) {
      log_amx("ERROR: Corrupt navigation data. Missing ^"to^" Navigation Area for Encounter Spot.^n");
      error = NAV_CORRUPT_DATA;
    }

    if (rgSpot[SpotEncounter_From][NavConnect_Area] != INVALID_NAV_AREA && rgSpot[SpotEncounter_To][NavConnect_Area] != INVALID_NAV_AREA) {
      // compute path
      new Float:flHalfWidth;
      @NavArea_ComputePortal(this, NAVAREA_PTR(rgSpot[SpotEncounter_To][NavConnect_Area]), rgSpot[SpotEncounter_ToDir], rgSpot[SpotEncounter_Path][Ray_To], flHalfWidth);
      @NavArea_ComputePortal(this, NAVAREA_PTR(rgSpot[SpotEncounter_From][NavConnect_Area]), rgSpot[SpotEncounter_FromDir], rgSpot[SpotEncounter_Path][Ray_From], flHalfWidth);

      new Float:eyeHeight = HalfHumanHeight;
      rgSpot[SpotEncounter_Path][Ray_From][2] = @NavArea_GetZ(
        g_rgNavAreas[rgSpot[SpotEncounter_From][NavConnect_Area]],
        rgSpot[SpotEncounter_Path][Ray_From]
      ) + eyeHeight;

      rgSpot[SpotEncounter_Path][Ray_To][2] = @NavArea_GetZ(
        g_rgNavAreas[rgSpot[SpotEncounter_To][NavConnect_Area]],
        rgSpot[SpotEncounter_Path][Ray_To]
      ) + eyeHeight;
    }

    ArraySetArray(irgSpotEncounterList, e, rgSpot[any:0]);
  }

  // build overlap list
  new Array:irgOverlapList = this[NavArea_OverlapList];

  for (new iArea = 0; iArea < g_iNavAreasNum; ++iArea) {
    if (iArea == NAVAREA_INDEX(this)) continue;

    if (@NavArea_IsOverlapping(this, iArea)) {
      ArrayPushCell(irgOverlapList, iArea);
    }
  }

  return error;
}

@NavArea_GetId(const this[NavArea]) {
  return this[NavArea_Id];
}

NavAttributeType:@NavArea_GetAttributes(const this[NavArea]) {
  return this[NavArea_AttributeFlags];
}

@NavArea_GetParent(const this[NavArea]) {
  return this[NavArea_Parent];
}

NavTraverseType:@NavArea_GetParentHow(const this[NavArea]) {
  return this[NavArea_ParentHow];
}

bool:@NavArea_IsClosed(const this[NavArea]) {
  return @NavArea_IsMarked(this) && !@NavArea_IsOpen(this);
}

bool:@NavArea_IsOpen(const this[NavArea]) {
  return this[NavArea_OpenMarker] == g_iNavAreaMasterMarker;
}

@NavArea_Mark(this[NavArea]) {
  this[NavArea_Marker] = g_iNavAreaMasterMarker;
}

bool:@NavArea_IsMarked(const this[NavArea]) {
  return this[NavArea_Marker] == g_iNavAreaMasterMarker;
}

@NavArea_GetCenter(const this[NavArea], Float:vecCenter[]) {
  xs_vec_copy(this[NavArea_Center], vecCenter);
}

@NavArea_SetTotalCost(this[NavArea], Float:flTotalCost) {
  this[NavArea_TotalCost] = flTotalCost;
}

Float:@NavArea_GetTotalCost(const this[NavArea]) {
  return this[NavArea_TotalCost];
}

@NavArea_SetCostSoFar(this[NavArea], Float:flTotalCost) {
  this[NavArea_CostSoFar] = flTotalCost;
}

Float:@NavArea_GetCostSoFar(const this[NavArea]) {
  return this[NavArea_CostSoFar];
}

@NavArea_AddToClosedList(this[NavArea]) {
  @NavArea_Mark(this);
}

@NavArea_RemoveFromClosedList(const this[NavArea]) {
  // since "closed" is defined as visited (marked) and not on open list, do nothing
}

@NavArea_AddLadderUp(const this[NavArea], const rgNavLadder[NavLadder]) {
  ArrayPushArray(Array:this[NavArea_Ladder][LADDER_UP], rgNavLadder[any:0]);
}

@NavArea_AddLadderDown(const this[NavArea], const rgNavLadder[NavLadder]) {
  ArrayPushArray(Array:this[NavArea_Ladder][LADDER_DOWN], rgNavLadder[any:0]);
}

@NavArea_SetParent(this[NavArea], iParentArea, NavTraverseType:how) {
  this[NavArea_Parent] = iParentArea;
  this[NavArea_ParentHow] = how;
}

Array:@NavArea_GetAdjacentList(const this[NavArea], NavDirType:iDir) {
  return this[NavArea_Connect][iDir];
}

@NavArea_AddToOpenList(this[NavArea]) {
  // mark as being on open list for quick check
  this[NavArea_OpenMarker] = g_iNavAreaMasterMarker;

  // if list is empty, add and return
  if (g_iNavAreaOpenList == INVALID_NAV_AREA) {
    g_iNavAreaOpenList = NAVAREA_INDEX(this);
    this[NavArea_PrevOpen] = INVALID_NAV_AREA;
    this[NavArea_NextOpen] = INVALID_NAV_AREA;
    return;
  }

  // insert self in ascending cost order
  static iArea; iArea = INVALID_NAV_AREA;
  static iLastArea; iLastArea = INVALID_NAV_AREA;

  for (iArea = g_iNavAreaOpenList; iArea != INVALID_NAV_AREA; iArea = NAVAREA_PTR(iArea)[NavArea_NextOpen]) {
    if (@NavArea_GetTotalCost(this) < @NavArea_GetTotalCost(NAVAREA_PTR(iArea))) {
      break;
    }

    iLastArea = iArea;
  }

  if (iArea != INVALID_NAV_AREA) {
    // insert before this area
    static iPrevOpenArea; iPrevOpenArea = NAVAREA_PTR(iArea)[NavArea_PrevOpen];
    this[NavArea_PrevOpen] = iPrevOpenArea;

    if (iPrevOpenArea != INVALID_NAV_AREA) {
      NAVAREA_PTR(iPrevOpenArea)[NavArea_NextOpen] = NAVAREA_INDEX(this);
    } else {
      g_iNavAreaOpenList = NAVAREA_INDEX(this);
    }

    this[NavArea_NextOpen] = iArea;
    NAVAREA_PTR(iArea)[NavArea_PrevOpen] = NAVAREA_INDEX(this);
  } else {
    // append to end of list
    NAVAREA_PTR(iLastArea)[NavArea_NextOpen] = NAVAREA_INDEX(this);
    this[NavArea_PrevOpen] = iLastArea;
    this[NavArea_NextOpen] = INVALID_NAV_AREA;
  }
}

@NavArea_UpdateOnOpenList(this[NavArea]) {
  // since value can only decrease, bubble this area up from current spot
  static iPrevOpenArea; iPrevOpenArea = this[NavArea_PrevOpen];

  while (this[NavArea_PrevOpen] != INVALID_NAV_AREA) {
    if (@NavArea_GetTotalCost(this) >= @NavArea_GetTotalCost(NAVAREA_PTR(iPrevOpenArea))) break;

    // swap position with predecessor
    static iOtherArea; iOtherArea = this[NavArea_PrevOpen];
    static iBeforeArea; iBeforeArea = NAVAREA_PTR(iOtherArea)[NavArea_PrevOpen];
    static iAfterArea; iAfterArea = this[NavArea_NextOpen];

    this[NavArea_NextOpen] = iOtherArea;
    this[NavArea_PrevOpen] = iBeforeArea;

    NAVAREA_PTR(iOtherArea)[NavArea_PrevOpen] = NAVAREA_INDEX(this);
    NAVAREA_PTR(iOtherArea)[NavArea_NextOpen] = iAfterArea;

    if (iBeforeArea != INVALID_NAV_AREA) {
      NAVAREA_PTR(iBeforeArea)[NavArea_NextOpen] = NAVAREA_INDEX(this);
    } else {
      g_iNavAreaOpenList = NAVAREA_INDEX(this);
    }

    if (iAfterArea != INVALID_NAV_AREA) {
      NAVAREA_PTR(iAfterArea)[NavArea_PrevOpen] = iOtherArea;
    }
  }
}

@NavArea_RemoveFromOpenList(this[NavArea]) {
  static iPrevOpenArea; iPrevOpenArea = this[NavArea_PrevOpen];
  static iNextOpenArea; iNextOpenArea = this[NavArea_NextOpen];

  if (iPrevOpenArea != INVALID_NAV_AREA) {
    NAVAREA_PTR(iPrevOpenArea)[NavArea_NextOpen] = iNextOpenArea;
  } else {
    g_iNavAreaOpenList = iNextOpenArea;
  }

  if (iNextOpenArea != INVALID_NAV_AREA) {
    NAVAREA_PTR(iNextOpenArea)[NavArea_PrevOpen] = iPrevOpenArea;
  }

  // zero is an invalid marker
  this[NavArea_OpenMarker] = 0;
}

bool:@NavArea_IsOverlappingPoint(const this[NavArea], const Float:vecPoint[]) {
  if (
    vecPoint[0] >= this[NavArea_Extent][Extent_Lo][0] &&
    vecPoint[0] <= this[NavArea_Extent][Extent_Hi][0] &&
    vecPoint[1] >= this[NavArea_Extent][Extent_Lo][1] &&
    vecPoint[1] <= this[NavArea_Extent][Extent_Hi][1]
  ) {
    return true;
  }

  return false;
}

// Return true if 'area' overlaps our 2D extents
bool:@NavArea_IsOverlapping(const this[NavArea], iArea) {
  if (
    NAVAREA_PTR(iArea)[NavArea_Extent][Extent_Lo][0] < this[NavArea_Extent][Extent_Hi][0] &&
    NAVAREA_PTR(iArea)[NavArea_Extent][Extent_Hi][0] > this[NavArea_Extent][Extent_Lo][0] &&
    NAVAREA_PTR(iArea)[NavArea_Extent][Extent_Lo][1] < this[NavArea_Extent][Extent_Hi][1] &&
    NAVAREA_PTR(iArea)[NavArea_Extent][Extent_Hi][1] > this[NavArea_Extent][Extent_Lo][1]
  ) {
    return true;
  }

  return false;
}

// Return true if given point is on or above this area, but no others
bool:@NavArea_Contains(const this[NavArea], const Float:vecPos[]) {
  // check 2D overlap
  if (!@NavArea_IsOverlappingPoint(this, vecPos)) return false;

  // the point overlaps us, check that it is above us, but not above any areas that overlap us
  new Float:flOurZ = @NavArea_GetZ(this, vecPos);

  // if we are above this point, fail
  if (flOurZ > vecPos[2]) return false;

  new Array:irgOverlapList = this[NavArea_OverlapList];
  new iOverlapListSize = ArraySize(irgOverlapList);

  for (new i = 0; i < iOverlapListSize; ++i) {
    new iOtherArea = ArrayGetCell(irgOverlapList, i);

    // skip self
    if (iOtherArea == NAVAREA_INDEX(this)) continue;

    // check 2D overlap
    if (!@NavArea_IsOverlappingPoint(NAVAREA_PTR(iOtherArea), vecPos)) continue;

    new Float:flTheirZ = @NavArea_GetZ(NAVAREA_PTR(iOtherArea), vecPos);
    if (flTheirZ > vecPos[2]) continue;

    if (flTheirZ > flOurZ) return false;
  }

  return true;
}

// Return true if this area and given area are approximately co-planar
bool:@NavArea_IsCoplanar(const this[NavArea], iArea) {
  static Float:u[3];
  static Float:v[3];

  // compute our unit surface normal
  u[0] = this[NavArea_Extent][Extent_Hi][0] - this[NavArea_Extent][Extent_Lo][0];
  u[1] = 0.0;
  u[2] = this[NavArea_NeZ] - this[NavArea_Extent][Extent_Lo][2];

  v[0] = 0.0;
  v[1] = this[NavArea_Extent][Extent_Hi][1] - this[NavArea_Extent][Extent_Lo][1];
  v[2] = this[NavArea_SwZ] - this[NavArea_Extent][Extent_Lo][2];

  static Float:vecNormal[3];
  xs_vec_cross(u, v, vecNormal);
  NormalizeInPlace(vecNormal, vecNormal);

  // compute their unit surface normal
  u[0] = NAVAREA_PTR(iArea)[NavArea_Extent][Extent_Hi][0] - NAVAREA_PTR(iArea)[NavArea_Extent][Extent_Lo][0];
  u[1] = 0.0;
  u[2] = NAVAREA_PTR(iArea)[NavArea_NeZ] - NAVAREA_PTR(iArea)[NavArea_Extent][Extent_Lo][2];

  v[0] = 0.0;
  v[1] = NAVAREA_PTR(iArea)[NavArea_Extent][Extent_Hi][1] - NAVAREA_PTR(iArea)[NavArea_Extent][Extent_Lo][1];
  v[2] = NAVAREA_PTR(iArea)[NavArea_SwZ] - NAVAREA_PTR(iArea)[NavArea_Extent][Extent_Lo][2];

  static Float:vecOtherNormal[3];
  xs_vec_cross(u, v, vecOtherNormal);
  NormalizeInPlace(vecOtherNormal, vecOtherNormal);

  // can only merge areas that are nearly planar, to ensure areas do not differ from underlying geometry much
  static const Float:flTolerance = 0.99;
  if (xs_vec_dot(vecNormal, vecOtherNormal) > flTolerance) return true;

  return false;
}

// Return Z of area at (x,y) of 'vecPos'
// Trilinear interpolation of Z values at quad edges.
// NOTE: vecPos[2] is not used.
Float:@NavArea_GetZ(const this[NavArea], const Float:vecPos[]) {
  static Float:dx; dx = this[NavArea_Extent][Extent_Hi][0] - this[NavArea_Extent][Extent_Lo][0];
  static Float:dy; dy = this[NavArea_Extent][Extent_Hi][1] - this[NavArea_Extent][Extent_Lo][1];

  static Float:flNeZ; flNeZ = this[NavArea_NeZ];
  static Float:flSwZ; flSwZ = this[NavArea_SwZ];

  // guard against division by zero due to degenerate areas
  if (dx == 0.0 || dy == 0.0) return flNeZ;

  static Float:u; u = floatclamp((vecPos[0] - this[NavArea_Extent][Extent_Lo][0]) / dx, 0.0, 1.0);
  static Float:v; v = floatclamp((vecPos[1] - this[NavArea_Extent][Extent_Lo][1]) / dy, 0.0, 1.0);

  static Float:northZ; northZ = this[NavArea_Extent][Extent_Lo][2] + u * (flNeZ - this[NavArea_Extent][Extent_Lo][2]);
  static Float:southZ; southZ = flSwZ + u * (this[NavArea_Extent][Extent_Hi][2] - flSwZ);

  return northZ + v * (southZ - northZ);
}

// new Float:@NavArea_GetZ(const this[NavArea], new Float:x, new Float:y) {
//   static Float:vecPos[3](x, y, 0.0);
//   return GetZ(&vecPos);
// }

// Return closest point to 'vecPos' on 'area'.
// Returned point is in 'vecClose'.
@NavArea_GetClosestPointOnArea(const this[NavArea], const Float:vecPos[], Float:vecClose[]) {
  if (vecPos[0] < this[NavArea_Extent][Extent_Lo][0]) {
    if (vecPos[1] < this[NavArea_Extent][Extent_Lo][1]) {
      // position is north-west of area
      xs_vec_copy(this[NavArea_Extent][Extent_Lo], vecClose);
    } else if (vecPos[1] > this[NavArea_Extent][Extent_Hi][1]) {
      // position is south-west of area
      vecClose[0] = this[NavArea_Extent][Extent_Lo][0];
      vecClose[1] = this[NavArea_Extent][Extent_Hi][1];
    } else {
      // position is west of area
      vecClose[0] = this[NavArea_Extent][Extent_Lo][0];
      vecClose[1] = vecPos[1];
    }
  } else if (vecPos[0] > this[NavArea_Extent][Extent_Hi][0]) {
    if (vecPos[1] < this[NavArea_Extent][Extent_Lo][1]) {
      // position is north-east of area
      vecClose[0] = this[NavArea_Extent][Extent_Hi][0];
      vecClose[1] = this[NavArea_Extent][Extent_Lo][1];
    } else if (vecPos[1] > this[NavArea_Extent][Extent_Hi][1]) {
      // position is south-east of area
      xs_vec_copy(this[NavArea_Extent][Extent_Hi], vecClose);
    } else {
      // position is east of area
      vecClose[0] = this[NavArea_Extent][Extent_Hi][0];
      vecClose[1] = vecPos[1];
    }
  } else if (vecPos[1] < this[NavArea_Extent][Extent_Lo][1]) {
    // position is north of area
    vecClose[0] = vecPos[0];
    vecClose[1] = this[NavArea_Extent][Extent_Lo][1];
  } else if (vecPos[1] > this[NavArea_Extent][Extent_Hi][1]) {
    // position is south of area
    vecClose[0] = vecPos[0];
    vecClose[1] = this[NavArea_Extent][Extent_Hi][1];
  } else {
    // position is inside of area - it is the 'closest point' to itself
    xs_vec_copy(vecPos, vecClose);
  }

  vecClose[2] = @NavArea_GetZ(this, vecClose);
}

// Return shortest distance squared between point and this area
Float:@NavArea_GetDistanceSquaredToPoint(const this[NavArea], const Float:vecPos[]) {
  if (vecPos[0] < this[NavArea_Extent][Extent_Lo][0]) {
    if (vecPos[1] < this[NavArea_Extent][Extent_Lo][1]) {
      // position is north-west of area
      return floatpower(xs_vec_distance(this[NavArea_Extent][Extent_Lo], vecPos), 2.0);
    } else if (vecPos[1] > this[NavArea_Extent][Extent_Hi][1]) {
      new Float:flSwZ = this[NavArea_SwZ];

      // position is south-west of area
      static Float:d[3];
      d[0] = this[NavArea_Extent][Extent_Lo][0] - vecPos[0];
      d[1] = this[NavArea_Extent][Extent_Hi][1] - vecPos[1];
      d[2] = flSwZ - vecPos[2];

      return floatpower(xs_vec_len(d), 2.0);
    } else {
      // position is west of area
      new Float:d = this[NavArea_Extent][Extent_Lo][0] - vecPos[0];

      return d * d;
    }
  } else if (vecPos[0] > this[NavArea_Extent][Extent_Hi][0]) {
    if (vecPos[1] < this[NavArea_Extent][Extent_Lo][1]) {
      new Float:flNeZ = this[NavArea_NeZ];

      // position is north-east of area
      static Float:d[3];
      d[0] = this[NavArea_Extent][Extent_Hi][0] - vecPos[0];
      d[1] = this[NavArea_Extent][Extent_Lo][1] - vecPos[1];
      d[2] = flNeZ - vecPos[2];

      return floatpower(xs_vec_len(d), 2.0);
    } else if (vecPos[1] > this[NavArea_Extent][Extent_Hi][1]) {
      // position is south-east of area
      return floatpower(xs_vec_distance(this[NavArea_Extent][Extent_Hi], vecPos), 2.0);
    } else {
      // position is east of area
      new Float:d = vecPos[2] - this[NavArea_Extent][Extent_Hi][0];

      return d * d;
    }
  } else if (vecPos[1] < this[NavArea_Extent][Extent_Lo][1]) {
    // position is north of area
    new Float:d = this[NavArea_Extent][Extent_Lo][1] - vecPos[1];

    return d * d;
  } else if (vecPos[1] > this[NavArea_Extent][Extent_Hi][1]) {
    // position is south of area
    new Float:d = vecPos[1] - this[NavArea_Extent][Extent_Hi][1];

    return d * d;
  } else { // position is inside of 2D extent of area - find delta Z
    new Float:z = @NavArea_GetZ(this, vecPos);
    new Float:d = z - vecPos[2];

    return d * d;
  }
}

@NavArea_GetRandomAdjacentArea(const this[NavArea], NavDirType:iDir) {
  static Array:irgConnections; irgConnections = this[NavArea_Connect][iDir];

  static iConnectionCount; iConnectionCount = ArraySize(irgConnections);
  if (!iConnectionCount) return INVALID_NAV_AREA;

  static iWhich; iWhich = random(iConnectionCount);

  return ArrayGetCell(irgConnections, iWhich, _:NavConnect_Area);
}

// Compute "portal" between to adjacent areas.
// Return center of portal opening, and half-width defining sides of portal from center.
// NOTE: center[2] is unset.
@NavArea_ComputePortal(const this[NavArea], const other[NavArea], NavDirType:iDir, Float:vecCenter[], &Float:flHalfWidth) {
  if (iDir == NORTH || iDir == SOUTH) {
    if (iDir == NORTH) {
      vecCenter[1] = this[NavArea_Extent][Extent_Lo][1];
    } else {
      vecCenter[1] = this[NavArea_Extent][Extent_Hi][1];
    }

    new Float:flLeft = floatmax(
      this[NavArea_Extent][Extent_Lo][0],
      other[NavArea_Extent][Extent_Lo][0]
    );

    new Float:flRight = floatmin(
      this[NavArea_Extent][Extent_Hi][0],
      other[NavArea_Extent][Extent_Hi][0]
    );

    // clamp to our extent in case areas are disjoint
    if (flLeft < this[NavArea_Extent][Extent_Lo][0]) {
      flLeft = this[NavArea_Extent][Extent_Lo][0];
    } else if (flLeft > this[NavArea_Extent][Extent_Hi][0]) {
      flLeft = this[NavArea_Extent][Extent_Hi][0];
    }

    if (flRight < this[NavArea_Extent][Extent_Lo][0]) {
      flRight = this[NavArea_Extent][Extent_Lo][0];
    } else if (flRight > this[NavArea_Extent][Extent_Hi][0]) {
      flRight = this[NavArea_Extent][Extent_Hi][0];
    }

    vecCenter[0] = (flLeft + flRight) / 2.0;
    flHalfWidth = (flRight - flLeft) / 2.0;
  } else { // EAST or WEST
    if (iDir == WEST) {
      vecCenter[0] = this[NavArea_Extent][Extent_Lo][0];
    } else {
      vecCenter[0] = this[NavArea_Extent][Extent_Hi][0];
    }

    new Float:flTop = floatmax(
      this[NavArea_Extent][Extent_Lo][1],
      other[NavArea_Extent][Extent_Lo][1]
    );

    new Float:flBottom = floatmin(
      this[NavArea_Extent][Extent_Hi][1],
      other[NavArea_Extent][Extent_Hi][1]
    );

    // clamp to our extent in case areas are disjoint
    if (flTop < this[NavArea_Extent][Extent_Lo][1]) {
      flTop = this[NavArea_Extent][Extent_Lo][1];
    } else if (flTop > this[NavArea_Extent][Extent_Hi][1]) {
      flTop = this[NavArea_Extent][Extent_Hi][1];
    }

    if (flBottom < this[NavArea_Extent][Extent_Lo][1]) {
      flBottom = this[NavArea_Extent][Extent_Lo][1];
    } else if (flBottom > this[NavArea_Extent][Extent_Hi][1]) {
      flBottom = this[NavArea_Extent][Extent_Hi][1];
    }

    vecCenter[1] = (flTop + flBottom) / 2.0;
    flHalfWidth = (flBottom - flTop) / 2.0;
  }
}

// Compute closest point within the "portal" between to adjacent areas.
@NavArea_ComputeClosestPointInPortal(const this[NavArea], const area[NavArea], NavDirType:iDir, const Float:vecFromPos[], Float:vecClosePos[]) {
  static Float:flMargin; flMargin = GenerationStepSize / 2.0;

  if (iDir == NORTH || iDir == SOUTH) {
    if (iDir == NORTH) {
      vecClosePos[1] = this[NavArea_Extent][Extent_Lo][1];
     } else {
      vecClosePos[1] = this[NavArea_Extent][Extent_Hi][1];
    }

    static Float:flLeft; flLeft = floatmax(
      this[NavArea_Extent][Extent_Lo][0],
      area[NavArea_Extent][Extent_Lo][0]
    );

    static Float:flRight; flRight = floatmin(
      this[NavArea_Extent][Extent_Hi][0],
      area[NavArea_Extent][Extent_Hi][0]
    );

    // clamp to our extent in case areas are disjoint
    if (flLeft < this[NavArea_Extent][Extent_Lo][0]) {
      flLeft = this[NavArea_Extent][Extent_Lo][0];
    } else if (flLeft > this[NavArea_Extent][Extent_Hi][0]) {
      flLeft = this[NavArea_Extent][Extent_Hi][0];
    }

    if (flRight < this[NavArea_Extent][Extent_Lo][0]) {
      flRight = this[NavArea_Extent][Extent_Lo][0];
    } else if (flRight > this[NavArea_Extent][Extent_Hi][0]) {
      flRight = this[NavArea_Extent][Extent_Hi][0];
    }

    // keep margin if against edge
    static Float:flLeftMargin; flLeftMargin = (@NavArea_IsEdge(area, WEST)) ? (flLeft + flMargin) : flLeft;
    static Float:flRightMargin; flRightMargin = (@NavArea_IsEdge(area, EAST)) ? (flRight - flMargin) : flRight;

    // limit x to within portal
    if (vecFromPos[0] < flLeftMargin) {
      vecClosePos[0] = flLeftMargin;
    } else if (vecFromPos[0] > flRightMargin) {
      vecClosePos[0] = flRightMargin;
    } else {
      vecClosePos[0] = vecFromPos[0];
    }

  } else {  // EAST or WEST
    if (iDir == WEST) {
      vecClosePos[0] = this[NavArea_Extent][Extent_Lo][0];
    } else {
      vecClosePos[0] = this[NavArea_Extent][Extent_Hi][0];
    }

    static Float:flTop; flTop = floatmax(
      this[NavArea_Extent][Extent_Lo][1],
      area[NavArea_Extent][Extent_Lo][1]
    );

    static Float:flBottom; flBottom = floatmin(
      this[NavArea_Extent][Extent_Hi][1],
      area[NavArea_Extent][Extent_Hi][1]
    );

    // clamp to our extent in case areas are disjoint
    if (flTop < this[NavArea_Extent][Extent_Lo][1]) {
      flTop = this[NavArea_Extent][Extent_Lo][1];
    } else if (flTop > this[NavArea_Extent][Extent_Hi][1]) {
      flTop = this[NavArea_Extent][Extent_Hi][1];
    }

    if (flBottom < this[NavArea_Extent][Extent_Lo][1]) {
      flBottom = this[NavArea_Extent][Extent_Lo][1];
    } else if (flBottom > this[NavArea_Extent][Extent_Hi][1]) {
      flBottom = this[NavArea_Extent][Extent_Hi][1];
    }

    // keep margin if against edge
    static Float:flTopMargin; flTopMargin = (@NavArea_IsEdge(area, NORTH)) ? (flTop + flMargin) : flTop;
    static Float:flBottomMargin; flBottomMargin = (@NavArea_IsEdge(area, SOUTH)) ? (flBottom - flMargin) : flBottom;

    // limit y to within portal
    if (vecFromPos[1] < flTopMargin) {
      vecClosePos[1] = flTopMargin;
    } else if (vecFromPos[1] > flBottomMargin) {
      vecClosePos[1] = flBottomMargin;
    } else {
      vecClosePos[1] = vecFromPos[1];
    }
  }
}

// Return true if there are no bi-directional links on the given side
bool:@NavArea_IsEdge(const this[NavArea], NavDirType:iDir) {
  static Array:irgConnections; irgConnections = this[NavArea_Connect][iDir];
  static iConnectionCount; iConnectionCount = ArraySize(irgConnections);

  for (new i = 0; i < iConnectionCount; ++i) {
    static iConnectArea; iConnectArea = ArrayGetCell(irgConnections, i, _:NavConnect_Area);
    if (@NavArea_IsConnected(NAVAREA_PTR(iConnectArea), this, OppositeDirection(iDir))) {
      return false;
    }
  }

  return true;
}

bool:@NavArea_IsConnected(const this[NavArea], const area[NavArea], NavDirType:iDir) {
  // we are connected to ourself
  if (NAVAREA_INDEX(area) == NAVAREA_INDEX(this)) return true;

  static iArea; iArea = NAVAREA_INDEX(area);

  if (iDir == NUM_DIRECTIONS) {
    // search all directions
    for (new NavDirType:iDir = NORTH; iDir < NUM_DIRECTIONS; ++iDir) {
      if (@NavArea_IsConnected(this, area, iDir)) {
        return true;
      }
    }
    
    // check ladder connections
    {
      static Array:irgLadderList; irgLadderList = @NavArea_GetLadder(this, LADDER_UP);
      static iListSize; iListSize = ArraySize(irgLadderList);

      for (new iLadder = 0; iLadder < iListSize; ++iLadder) {
        if (
          ArrayGetCell(irgLadderList, iLadder, _:NavLadder_TopBehindArea) == iArea ||
          ArrayGetCell(irgLadderList, iLadder, _:NavLadder_TopForwardArea) == iArea ||
          ArrayGetCell(irgLadderList, iLadder, _:NavLadder_TopLeftArea) == iArea ||
          ArrayGetCell(irgLadderList, iLadder, _:NavLadder_TopRightArea) == iArea
        ) {
          return true;
        }
      }
    }

    {
      static Array:irgLadderList; irgLadderList = @NavArea_GetLadder(this, LADDER_DOWN);
      static iListSize; iListSize = ArraySize(irgLadderList);

      for (new iLadder = 0; iLadder < iListSize; ++iLadder) {
        if (ArrayGetCell(irgLadderList, iLadder, _:NavLadder_BottomArea) == iArea) {
          return true;
        }
      }
    }
  } else {
    // check specific direction
    static Array:irgConnections; irgConnections = this[NavArea_Connect][iDir];
    static iConnectionCount; iConnectionCount = ArraySize(irgConnections);

    for (new iConnection = 0; iConnection < iConnectionCount; ++iConnection) {
      if (NAVAREA_INDEX(area) == ArrayGetCell(irgConnections, iConnection, _:NavConnect_Area)) {
        return true;
      }
    }
  }

  return false;
}

// Return direction from this area to the given point
NavDirType:@NavArea_ComputeDirection(const this[NavArea], const Float:vecPoint[]) {
  if (vecPoint[0] >= this[NavArea_Extent][Extent_Lo][0] && vecPoint[0] <= this[NavArea_Extent][Extent_Hi][0]) {
    if (vecPoint[1] < this[NavArea_Extent][Extent_Lo][1]) {
      return NORTH;
    } else if (vecPoint[1] > this[NavArea_Extent][Extent_Hi][1]) {
      return SOUTH;
    }
  } else if (vecPoint[1] >= this[NavArea_Extent][Extent_Lo][1] && vecPoint[1] <= this[NavArea_Extent][Extent_Hi][1]) {
    if (vecPoint[0] < this[NavArea_Extent][Extent_Lo][0]) {
      return WEST;
    } else if (vecPoint[0] > this[NavArea_Extent][Extent_Hi][0]) {
      return EAST;
    }
  }

  // find closest direction
  static Float:vecTo[3];
  @NavArea_GetCenter(this, vecTo);
  xs_vec_sub(vecPoint, vecTo, vecTo);

  if (floatabs(vecTo[0]) > floatabs(vecTo[1])) {
    return vecTo[0] > 0.0 ? EAST : WEST;
  } else {
    return vecTo[1] > 0.0 ? SOUTH : NORTH;
  }
}

@NavArea_GetCorner(const this[NavArea], NavCornerType:corner, Float:vecOut[]) {
  switch (corner) {
    case NORTH_WEST: {
      xs_vec_copy(this[NavArea_Extent][Extent_Lo], vecOut);
    }
    case NORTH_EAST: {
      vecOut[0] = this[NavArea_Extent][Extent_Hi][0];
      vecOut[1] = this[NavArea_Extent][Extent_Lo][1];
      vecOut[2] = this[NavArea_NeZ];
    }
    case SOUTH_WEST: {
      vecOut[0] = this[NavArea_Extent][Extent_Lo][0];
      vecOut[1] = this[NavArea_Extent][Extent_Hi][1];
      vecOut[2] = this[NavArea_SwZ];
    }
    case SOUTH_EAST: {
      xs_vec_copy(this[NavArea_Extent][Extent_Hi], vecOut);
    }
  }
}

Array:@NavArea_GetLadder(const this[NavArea], LadderDirectionType:iDir) {
  return Array:this[NavArea_Ladder][iDir];
}

Struct:@NavPath_Create() {
  static Struct:this; this = StructCreate(NavPath);
  StructSetCell(this, NavPath_Segments, ArrayCreate(_:PathSegment));

  return this;
}

@NavPath_Destroy(&Struct:this) {
  StructDestroy(this);
}

// Build trivial path when start and goal are in the same nav area
bool:@NavPath_BuildTrivialPath(const &Struct:this, const Float:vecStart[], const Float:vecGoal[]) {
  static Array:irgSegments; irgSegments = StructGetCell(this, NavPath_Segments);
  ArrayClear(irgSegments);

  StructSetCell(this, NavPath_SegmentCount, 0);

  static iStartArea; iStartArea = NavAreaGrid_GetNearestNavArea(vecStart, false, nullptr);
  if (iStartArea == INVALID_NAV_AREA) return false;

  static iGoalArea; iGoalArea = NavAreaGrid_GetNearestNavArea(vecGoal, false, nullptr);
  if (iGoalArea == INVALID_NAV_AREA) return false;

  static rgStartSegment[PathSegment];
  rgStartSegment[PathSegment_Area] = iStartArea;
  rgStartSegment[PathSegment_How] = NUM_TRAVERSE_TYPES;
  xs_vec_set(rgStartSegment[PathSegment_Pos], vecStart[0], vecStart[1], @NavArea_GetZ(NAVAREA_PTR(iStartArea), vecStart));
  @NavPath_PushSegment(this, rgStartSegment);

  static rgGoalSegment[PathSegment];
  rgGoalSegment[PathSegment_Area] = iGoalArea;
  rgGoalSegment[PathSegment_How] = NUM_TRAVERSE_TYPES;
  xs_vec_set(rgGoalSegment[PathSegment_Pos], vecGoal[0], vecGoal[1], @NavArea_GetZ(NAVAREA_PTR(iGoalArea), vecGoal));
  @NavPath_PushSegment(this, rgGoalSegment);

  return true;
}

@NavPath_PushSegment(const &Struct:this, const segment[PathSegment]) {
  ArrayPushArray(StructGetCell(this, NavPath_Segments), segment[any:0]);
  StructSetCell(this, NavPath_SegmentCount, StructGetCell(this, NavPath_SegmentCount) + 1);
}

@NavPath_ComputePathPositions(const &Struct:this) {
  static iSegmentsNum; iSegmentsNum = StructGetCell(this, NavPath_SegmentCount);
  if (!iSegmentsNum) return false;

  static Array:irgSegments; irgSegments = StructGetCell(this, NavPath_Segments);
  static iStartArea; iStartArea = ArrayGetCell(irgSegments, 0, _:PathSegment_Area);

  // start in first area's center
  ArraySetArray2(irgSegments, 0, NAVAREA_PTR(iStartArea)[NavArea_Center], 3, PathSegment_Pos);
  ArraySetCell(irgSegments, 0, NUM_TRAVERSE_TYPES, _:PathSegment_How);

  for (new iSegment = 1; iSegment < iSegmentsNum; iSegment++) {
    static iFromArea; iFromArea = ArrayGetCell(irgSegments, iSegment - 1, _:PathSegment_Area);
    static iToArea; iToArea = ArrayGetCell(irgSegments, iSegment, _:PathSegment_Area);

    // walk along the floor to the next area
    static NavTraverseType:toHow; toHow = ArrayGetCell(irgSegments, iSegment, _:PathSegment_How);
    if (toHow <= GO_WEST) {
      static Float:vecFromPos[3]; ArrayGetArray2(irgSegments, iSegment - 1, vecFromPos, 3, PathSegment_Pos);
      static Float:vecToPos[3]; ArrayGetArray2(irgSegments, iSegment, vecToPos, 3, PathSegment_Pos);
      
      // compute next point, keeping path as straight as possible
      @NavArea_ComputeClosestPointInPortal(NAVAREA_PTR(iFromArea), NAVAREA_PTR(iToArea), NavDirType:toHow, vecFromPos, vecToPos);

      // move goal position into the goal area a bit
      // how far to "step into" an area - must be less than min area size
      static const Float:flStepInDist = 5.0;
      AddDirectionVector(vecToPos, NavDirType:toHow, flStepInDist);

      // we need to walk out of "from" area, so keep Z where we can reach it
      vecToPos[2] = @NavArea_GetZ(NAVAREA_PTR(iFromArea), vecToPos);

      ArraySetArray2(irgSegments, iSegment, vecToPos, 3, PathSegment_Pos);

      // if this is a "jump down" connection, we must insert an additional point on the path
      if (!@NavArea_IsConnected(NAVAREA_PTR(iToArea), NAVAREA_PTR(iFromArea), NUM_DIRECTIONS)) {
        // this is a "jump down" link
        // compute direction of path just prior to "jump down"
        static Float:flDir[2]; DirectionToVector2D(NavDirType:toHow, flDir);

        // shift top of "jump down" out a bit to "get over the ledge"
        static const Float:flPushDist = 25.0;
        ArraySetCell(irgSegments, iSegment, Float:ArrayGetCell(irgSegments, iSegment, _:PathSegment_Pos + 0) + (flPushDist * flDir[0]), _:PathSegment_Pos + 0);
        ArraySetCell(irgSegments, iSegment, Float:ArrayGetCell(irgSegments, iSegment, _:PathSegment_Pos + 1) + (flPushDist * flDir[1]), _:PathSegment_Pos + 1);

        // insert a duplicate node to represent the bottom of the fall
        if (iSegmentsNum < MAX_PATH_SEGMENTS - 1) {
          static rgSegment[PathSegment];
          rgSegment[PathSegment_Area] = ArrayGetCell(irgSegments, iSegment, _:PathSegment_Area);
          rgSegment[PathSegment_How] = ArrayGetCell(irgSegments, iSegment, _:PathSegment_How);
          rgSegment[PathSegment_Pos][0] = vecToPos[0] + flPushDist * flDir[0];
          rgSegment[PathSegment_Pos][1] = vecToPos[1] + flPushDist * flDir[1];
          rgSegment[PathSegment_Pos][2] = ArrayGetCell(irgSegments, iSegment, _:PathSegment_Pos + 2);
          rgSegment[PathSegment_Pos][2] = @NavArea_GetZ(NAVAREA_PTR(iToArea), rgSegment[PathSegment_Pos]);

          ArrayInsertArrayAfter(irgSegments, iSegment, rgSegment[any:0]);

          // path is one node longer
          StructSetCell(this, NavPath_SegmentCount, ++iSegmentsNum);

          // move index ahead into the new node we just duplicated
          iSegment++;
        }
      }
    } else if (toHow == GO_LADDER_UP) { // to get to next area, must go up a ladder
      // find our ladder
      static bool:bFound; bFound = false;
      static Array:irgLadderList; irgLadderList = @NavArea_GetLadder(NAVAREA_PTR(iFromArea), LADDER_UP);
      
      static iListSize; iListSize = ArraySize(irgLadderList);
      for (new iLadder = 0; iLadder < iListSize; ++iLadder) {
        // can't use "behind" area when ascending...
        if (
          ArrayGetCell(irgLadderList, iLadder, _:NavLadder_TopForwardArea) == iToArea ||
          ArrayGetCell(irgLadderList, iLadder, _:NavLadder_TopLeftArea) == iToArea ||
          ArrayGetCell(irgLadderList, iLadder, _:NavLadder_TopRightArea) == iToArea
        ) {
          // to->ladder = ladder;
          static Float:vecPos[3]; ArrayGetArray2(irgLadderList, iLadder, vecPos, 3, NavLadder_Bottom);
          AddDirectionVector(vecPos, ArrayGetCell(irgLadderList, iLadder, _:NavLadder_Dir), 2.0 * HalfHumanWidth);
          ArraySetArray2(irgSegments, iSegment, vecPos, 3, PathSegment_Pos);
          bFound = true;
          break;
        }
      }

      if (!bFound) return false;
    } else if (toHow == GO_LADDER_DOWN) { // to get to next area, must go down a ladder
      // find our ladder
      static bool:bFound; bFound = false;
      static Array:irgLadderList; irgLadderList = @NavArea_GetLadder(NAVAREA_PTR(iFromArea), LADDER_DOWN);
      
      static iListSize; iListSize = ArraySize(irgLadderList);
      for (new iLadder = 0; iLadder < iListSize; ++iLadder) {
        if (ArrayGetCell(irgLadderList, iLadder, _:NavLadder_BottomArea) == iToArea) {
          // to->ladder = ladder;
          static Float:vecPos[3]; ArrayGetArray2(irgLadderList, iLadder, vecPos, 3, NavLadder_Top);
          AddDirectionVector(vecPos, OppositeDirection(ArrayGetCell(irgLadderList, iLadder, _:NavLadder_Dir)), 2.0 * HalfHumanWidth);
          ArraySetArray2(irgSegments, iSegment, vecPos, 3, PathSegment_Pos);
          bFound = true;
          break;
        }
      }

      if (!bFound) return false;
    }
  }

  return true;
}

bool:@NavPath_IsValid(const &Struct:this) {
  return StructGetCell(this, NavPath_SegmentCount) > 0;
}

@NavPath_GetSegmentCount(const &Struct:this) {
  return StructGetCell(this, NavPath_SegmentCount);
}

@NavPath_Invalidate(const &Struct:this) {
  StructSetCell(this, NavPath_SegmentCount, 0);
}

@NavPath_Clear(const &Struct:this) {
  static Array:irgSegments; irgSegments = StructGetCell(this, NavPath_Segments);
  ArrayClear(irgSegments);

  StructSetCell(this, NavPath_SegmentCount, 0);
}

@NavPath_GetEndpoint(const &Struct:this, Float:vecEndpoint[]) {
  static iSegmentCount; iSegmentCount = StructGetCell(this, NavPath_SegmentCount);
  static Array:irgSegments; irgSegments = StructGetCell(this, NavPath_Segments);

  ArrayGetArray2(irgSegments, iSegmentCount - 1, vecEndpoint, 3, PathSegment_Pos);
}

// Return true if position is at the end of the path
bool:@NavPath_IsAtEnd(const &Struct:this, const Float:vecPos[]) {
  if (!@NavPath_IsValid(this)) return false;

  static Float:vecEndpoint[3]; @NavPath_GetEndpoint(this, vecEndpoint);

  return xs_vec_distance(vecPos, vecEndpoint) < 20.0;
}

// Return point a given distance along the path - if distance is out of path bounds, point is clamped to start/end
// TODO: Be careful of returning "positions" along one-way drops, ladders, etc.
bool:@NavPath_GetPointAlongPath(const &Struct:this, Float:flDistAlong, Float:vecPointOnPath[]) {
  if (!@NavPath_IsValid(this)) {
    return false;
  }

  static Array:irgSegments; irgSegments = StructGetCell(this, NavPath_Segments);

  if (flDistAlong <= 0.0) {
    ArrayGetArray2(irgSegments, 0, vecPointOnPath, 3, PathSegment_Pos);
    return true;
  }

  static Float:flLengthSoFar; flLengthSoFar = 0.0;

  static iSegmentsNum; iSegmentsNum = @NavPath_GetSegmentCount(this);

  for (new i = 1; i < iSegmentsNum; i++) {
    static Float:vecFrom[3]; ArrayGetArray2(irgSegments, i - 1, vecFrom, 3, PathSegment_Pos);
    static Float:vecTo[3]; ArrayGetArray2(irgSegments, i, vecTo, 3, PathSegment_Pos);
    static Float:vecDir[3]; xs_vec_sub(vecTo, vecFrom, vecDir);
    static Float:flSegmentLength; flSegmentLength = xs_vec_len(vecDir);

    if (flSegmentLength + flLengthSoFar >= flDistAlong) {
      // desired point is on this segment of the path
      for (new j = 0; j < 3; ++j) {
        vecPointOnPath[j] = vecTo[j] + ((flDistAlong - flLengthSoFar) / flSegmentLength) * vecDir[j];
      }

      return true;
    }

    flLengthSoFar += flSegmentLength;
  }

  @NavPath_GetEndpoint(this, vecPointOnPath);

  return true;
}

// Compute closest point on path to given point
// NOTE: This does not do line-of-sight tests, so closest point may be thru the floor, etc
bool:@NavPath_FindClosestPointOnPath(const &Struct:this, const Float:vecWorldPos[], iStartIndex, iEndIndex, Float:vecClose[]) {
  if (!@NavPath_IsValid(this)) return false;

  static Array:irgSegments; irgSegments = StructGetCell(this, NavPath_Segments);
  
  static Float:flCloseDistSq = 8192.0;

  for (new iSegment = iStartIndex; iSegment <= iEndIndex; iSegment++) {
    static Float:vecFrom[3]; ArrayGetArray2(irgSegments, iSegment - 1, vecFrom, 3, PathSegment_Pos);
    static Float:vecTo[3]; ArrayGetArray2(irgSegments, iSegment, vecTo, 3, PathSegment_Pos);
    static Float:vecAlong[3]; xs_vec_sub(vecTo, vecFrom, vecAlong);
    static Float:flLength; flLength = NormalizeInPlace(vecAlong, vecAlong);
    static Float:vecToWorldPos[3]; xs_vec_sub(vecWorldPos, vecFrom, vecToWorldPos);
    static Float:flCloseLength; flCloseLength = xs_vec_dot(vecToWorldPos, vecAlong);

    // constrain point to be on path segment
    static Float:vecPos[3];
    if (flCloseLength <= 0.0) {
      xs_vec_copy(vecFrom, vecPos);
    } else if (flCloseLength >= flLength) {
      xs_vec_copy(vecTo, vecPos);
    } else {
      xs_vec_add_scaled(vecFrom, vecAlong, flCloseLength, vecPos);
    }

    static Float:flDistSq; flDistSq = floatpower(xs_vec_distance(vecPos, vecWorldPos), 2.0);

    // keep the closest point so far
    if (flDistSq < flCloseDistSq) {
      flCloseDistSq = flDistSq;
      xs_vec_copy(vecPos, vecClose);
    }
  }

  return true;
}

@BuildPathTask_Allocate(this[BuildPathTask], iUserToken, const &iStartArea, const &iGoalArea, const Float:vecStart[], const Float:vecGoal[], pIgnoreEnt, iCbFuncPluginId, iCbFuncId, iCostFuncPluginId, iCostFuncId) {
  if (this[BuildPathTask_Path] == Invalid_Struct) {
    this[BuildPathTask_Path] = @NavPath_Create();
  } else {
    @NavPath_Clear(this[BuildPathTask_Path]);
  }

  this[BuildPathTask_StartArea] = iStartArea;
  this[BuildPathTask_GoalArea] = iGoalArea;
  this[BuildPathTask_FinishCallback][Callback_PluginId] = iCbFuncPluginId;
  this[BuildPathTask_FinishCallback][Callback_FunctionId] = iCbFuncId;
  this[BuildPathTask_CostCallback][Callback_PluginId] = iCostFuncPluginId;
  this[BuildPathTask_CostCallback][Callback_FunctionId] = iCostFuncId;
  this[BuildPathTask_IgnoreEntity] = pIgnoreEnt;
  this[BuildPathTask_UserToken] = iUserToken;
  this[BuildPathTask_IsFinished] = false;
  this[BuildPathTask_IsSuccessed] = false;
  this[BuildPathTask_IsTerminated] = false;
  this[BuildPathTask_IsFree] = false;
  this[BuildPathTask_IterationsNum] = 0;
  xs_vec_copy(vecStart, this[BuildPathTask_StartPos]);
  xs_vec_copy(vecGoal, this[BuildPathTask_GoalPos]);
}

@BuildPathTask_Free(this[BuildPathTask]) {
  this[BuildPathTask_IsFree] = true;
}

// Struct:@PathSegment_Create() {
//   new Struct:this = StructCreate(PathSegment);

//   return this;
// }

// @PathSegment_Destroy(&Struct:this) {
//   StructDestroy(this);
// }

NavAreaGrid_Init(Float:flMinX, Float:flMaxX, Float:flMinY, Float:flMaxY) {
  g_rgGrid[NavAreaGrid_CellSize] = 300.0;
  g_rgGrid[NavAreaGrid_MinX] = flMinX;
  g_rgGrid[NavAreaGrid_MinY] = flMinY;
  g_rgGrid[NavAreaGrid_GridSizeX] = floatround((flMaxX - flMinX) / g_rgGrid[NavAreaGrid_CellSize] + 1);
  g_rgGrid[NavAreaGrid_GridSizeY] = floatround((flMaxY - flMinY) / g_rgGrid[NavAreaGrid_CellSize] + 1);
  g_rgGrid[NavAreaGrid_AreaCount] = 0;

  for (new i = 0; i < HASH_TABLE_SIZE; ++i) {
    g_rgGrid[NavAreaGrid_HashTable][i] = INVALID_NAV_AREA;
  }

  new iGridSize = g_rgGrid[NavAreaGrid_GridSizeX] * g_rgGrid[NavAreaGrid_GridSizeY];

  g_rgGrid[NavAreaGrid_Grid] = ArrayCreate(_, iGridSize);

  for (new i = 0; i < iGridSize; ++i) {
    ArrayPushCell(g_rgGrid[NavAreaGrid_Grid], ArrayCreate());
  }
}

NavAreaGrid_Free() {
  if (g_rgGrid[NavAreaGrid_Grid] != Invalid_Array) {
    new iGridSize = ArraySize(g_rgGrid[NavAreaGrid_Grid]);

    for (new i = 0; i < iGridSize; ++i) {
      new Array:irgAreas = ArrayGetCell(g_rgGrid[NavAreaGrid_Grid], i);
      ArrayDestroy(irgAreas);
    }

    ArrayDestroy(g_rgGrid[NavAreaGrid_Grid]);
  }
}

NavAreaGrid_GetNavAreaById(iAreaId) {
  if (iAreaId == 0) return INVALID_NAV_AREA;

  static iKey; iKey = NavAreaGrid_ComputeHashKey(iAreaId);

  for (new iArea = g_rgGrid[NavAreaGrid_HashTable][iKey]; iArea != INVALID_NAV_AREA; iArea = NAVAREA_PTR(iArea)[NavArea_NextHash]) {
    if (@NavArea_GetId(NAVAREA_PTR(iArea)) == iAreaId) return iArea;
  }

  return INVALID_NAV_AREA;
}

NavAreaGrid_AddNavArea(area[NavArea]) {
  // add to grid
  new iLoX = NavAreaGrid_WorldToGridX(area[NavArea_Extent][Extent_Lo][0]);
  new iLoY = NavAreaGrid_WorldToGridY(area[NavArea_Extent][Extent_Lo][1]);
  new iHiX = NavAreaGrid_WorldToGridX(area[NavArea_Extent][Extent_Hi][0]);
  new iHiY = NavAreaGrid_WorldToGridY(area[NavArea_Extent][Extent_Hi][1]);

  for (new y = iLoY; y <= iHiY; y++) {
    for (new x = iLoX; x <= iHiX; x++) {
      new Array:irgAreas = ArrayGetCell(g_rgGrid[NavAreaGrid_Grid], x + y * g_rgGrid[NavAreaGrid_GridSizeX]);
      ArrayPushCell(irgAreas, NAVAREA_INDEX(area));
    }
  }

  new iAreaId = area[NavArea_Id];

  // add to hash table
  new iKey = NavAreaGrid_ComputeHashKey(iAreaId);

  if (g_rgGrid[NavAreaGrid_HashTable][iKey] != INVALID_NAV_AREA) {
    // add to head of list in this slot
    area[NavArea_PrevHash] = INVALID_NAV_AREA;
    area[NavArea_NextHash] = g_rgGrid[NavAreaGrid_HashTable][iKey];
    g_rgNavAreas[g_rgGrid[NavAreaGrid_HashTable][iKey]][NavArea_PrevHash] = NAVAREA_INDEX(area);
    g_rgGrid[NavAreaGrid_HashTable][iKey] = NAVAREA_INDEX(area);
  } else {
    // first entry in this slot
    g_rgGrid[NavAreaGrid_HashTable][iKey] = NAVAREA_INDEX(area);
    area[NavArea_NextHash] = INVALID_NAV_AREA;
    area[NavArea_PrevHash] = INVALID_NAV_AREA;
  }

  g_rgGrid[NavAreaGrid_AreaCount]++;
}

// Given a position, return the nav area that IsOverlapping and is *immediately* beneath it
NavAreaGrid_GetNavArea(const Float:vecPos[], Float:flBeneathLimit) {
  if (g_rgGrid[NavAreaGrid_Grid] == Invalid_Array) return INVALID_NAV_AREA;

  // get list in cell that contains position
  static x; x = NavAreaGrid_WorldToGridX(vecPos[0]);
  static y; y = NavAreaGrid_WorldToGridY(vecPos[1]);
  static Float:vecTestPos[3]; xs_vec_add(vecPos, Float:{0, 0, 5}, vecTestPos);

  static Array:irgList; irgList = ArrayGetCell(g_rgGrid[NavAreaGrid_Grid], x + y * g_rgGrid[NavAreaGrid_GridSizeX]);

  // search cell list to find correct area

  static iListSize; iListSize = ArraySize(irgList);
  static iUseArea; iUseArea = INVALID_NAV_AREA;
  static Float:useZ; useZ = -99999999.9;

  for (new i = 0; i < iListSize; ++i) {
    static iArea; iArea = ArrayGetCell(irgList, i);

    // check if position is within 2D boundaries of this area
    if (@NavArea_IsOverlappingPoint(NAVAREA_PTR(iArea), vecTestPos)) {
      // project position onto area to get Z
      static Float:z; z = @NavArea_GetZ(NAVAREA_PTR(iArea), vecTestPos);

      // if area is above us, skip it
      if (z > vecTestPos[2]) continue;

      // if area is too far below us, skip it
      if (z < vecPos[2] - flBeneathLimit) continue;

      // if area is higher than the one we have, use this instead
      if (z > useZ) {
        iUseArea = iArea;
        useZ = z;
      }
    }
  }

  return iUseArea;
}

NavAreaGrid_WorldToGridX(Float:wx) {
  return clamp(
    floatround((wx - g_rgGrid[NavAreaGrid_MinX]) / g_rgGrid[NavAreaGrid_CellSize], floatround_ceil),
    0,
    g_rgGrid[NavAreaGrid_GridSizeX] - 1
  );
}

NavAreaGrid_WorldToGridY(Float:wy) {
  return clamp(
    floatround((wy - g_rgGrid[NavAreaGrid_MinY]) / g_rgGrid[NavAreaGrid_CellSize], floatround_ceil),
    0,
    g_rgGrid[NavAreaGrid_GridSizeY] - 1
  );
}

// Given a position in the world, return the nav area that is closest
// and at the same height, or beneath it.
// Used to find initial area if we start off of the mesh.
NavAreaGrid_GetNearestNavArea(const Float:vecPos[], bool:bAnyZ = false, pIgnoreEnt = nullptr, iIgnoreArea = INVALID_NAV_AREA) {
  if (g_rgGrid[NavAreaGrid_Grid] == Invalid_Array) return INVALID_NAV_AREA;

  static Float:flGroundHeight; flGroundHeight = GetGroundHeight(vecPos, pIgnoreEnt);
  if (flGroundHeight == -1.0) return INVALID_NAV_AREA;

  static iCurrentArea; iCurrentArea = NavAreaGrid_GetNavArea(vecPos, 120.0);
  if (iCurrentArea != INVALID_NAV_AREA && iCurrentArea != iIgnoreArea) return iCurrentArea;

  // ensure source position is well behaved
  static Float:vecSource[3]; xs_vec_set(vecSource, vecPos[0], vecPos[1], flGroundHeight + HalfHumanHeight);

  static sCloseArea; sCloseArea = INVALID_NAV_AREA;
  static Float:flCloseDistSq; flCloseDistSq = 100000000.0;

  // TODO: Step incrementally using grid for speed
  // find closest nav area
  for (new iArea = 0; iArea < g_iNavAreasNum; ++iArea) {
    if (iArea == iIgnoreArea) continue;

    static Float:vecAreaPos[3]; @NavArea_GetClosestPointOnArea(NAVAREA_PTR(iArea), vecSource, vecAreaPos);
    static Float:flDistSq; flDistSq = floatpower(xs_vec_distance(vecAreaPos, vecSource), 2.0);

    // keep the closest area
    if (flDistSq < flCloseDistSq) {
      // check LOS to area
      if (!bAnyZ) {
        static Float:vecEnd[3]; xs_vec_set(vecEnd, vecAreaPos[0], vecAreaPos[1], vecAreaPos[2] + HalfHumanHeight);

        engfunc(EngFunc_TraceLine, vecSource, vecEnd, IGNORE_MONSTERS | IGNORE_GLASS, pIgnoreEnt, g_pTrace);

        static Float:flFraction; get_tr2(g_pTrace, TR_flFraction, flFraction);

        if (flFraction != 1.0) continue;
      }

      flCloseDistSq = flDistSq;
      sCloseArea = iArea;
    }
  }

  return sCloseArea;
}

NavAreaGrid_ComputeHashKey(iId) {
  return iId & 0xFF;
}

NavErrorType:LoadNavigationMap() {
  new szMapName[32]; get_mapname(szMapName, charsmax(szMapName));
  new szFilePath[256]; format(szFilePath, charsmax(szFilePath), "maps/%s.nav", szMapName);

  if (!file_exists(szFilePath)) {
    log_amx("File ^"%s^" not found!", szFilePath);
    return NAV_CANT_ACCESS_FILE;
  }

  // g_irgNavLadderList = ArrayCreate();

  new iFile = fopen(szFilePath, "rb");
  g_iNavAreaNextId = 1;

  new iMagic;
  if (!FileReadInt32(iFile, iMagic)) return NAV_INVALID_FILE;

  if (iMagic != NAV_MAGIC_NUMBER) {
    log_amx("Wrong magic number %d. Should be %d.", iMagic, NAV_MAGIC_NUMBER);
    return NAV_INVALID_FILE;
  }

  new iVersion;
  if (!FileReadInt32(iFile, iVersion)) return NAV_BAD_FILE_VERSION;

  if (iVersion > NAV_VERSION) {
    log_amx("Wrong version %d. Should be less then %d.", iVersion, NAV_VERSION);
    return NAV_BAD_FILE_VERSION;
  }

  log_amx("Nav version: %d", iVersion);

  if (iVersion >= 4) {
    fseek(iFile, BLOCK_INT, SEEK_CUR);
  }

  // load Place directory
  if (iVersion >= NAV_VERSION) {
    new iPlaceCount;
    FileReadUint16(iFile, iPlaceCount);

    for (new i = 0; i < iPlaceCount; ++i) {
      new iLen;
      FileReadUint16(iFile, iLen);
      fseek(iFile, iLen, SEEK_CUR);
    }
  }

  // get number of areas
  FileReadInt32(iFile, g_iNavAreasNum);
  log_amx("Found %d areas", g_iNavAreasNum);

  new rgExtent[Extent];
  rgExtent[Extent_Lo][0] = 9999999999.9;
  rgExtent[Extent_Lo][1] = 9999999999.9;
  rgExtent[Extent_Hi][0] = -9999999999.9;
  rgExtent[Extent_Hi][1] = -9999999999.9;

  log_amx("Loading areas...");

  // load the areas and compute total extent
  for (new iArea = 0; iArea < g_iNavAreasNum; iArea++) {
    @NavArea_Allocate(NAVAREA_PTR(iArea));
    @NavArea_Load(NAVAREA_PTR(iArea), iFile, iVersion, false);
    AdjustExtentWithArea(rgExtent, NAVAREA_PTR(iArea));
  }

  log_amx("All areas loaded!");

  // add the areas to the grid
  NavAreaGrid_Init(rgExtent[Extent_Lo][0], rgExtent[Extent_Hi][0], rgExtent[Extent_Lo][1], rgExtent[Extent_Hi][1]);

  log_amx("Grid initialized!");

  for (new iArea = 0; iArea < g_iNavAreasNum; iArea++) {
    NavAreaGrid_AddNavArea(NAVAREA_PTR(iArea));
  }

  log_amx("All areas added to the grid!");

  // allow areas to connect to each iOtherArea, etc
  for (new iArea = 0; iArea < g_iNavAreasNum; iArea++) {
    @NavArea_PostLoadArea(NAVAREA_PTR(iArea));
  }

  log_amx("Loaded areas post processing complete!");

  fclose(iFile);

  if (b_bInitStage) BuildLadders();

  return NAV_OK;
}

AdjustExtentWithArea(rgExtent[Extent], const area[NavArea]) {
  rgExtent[Extent_Lo][0] = floatmin(area[NavArea_Extent][Extent_Lo][0], rgExtent[Extent_Lo][0]);
  rgExtent[Extent_Lo][1] = floatmin(area[NavArea_Extent][Extent_Lo][1], rgExtent[Extent_Lo][1]);
  rgExtent[Extent_Hi][0] = floatmax(area[NavArea_Extent][Extent_Hi][0], rgExtent[Extent_Hi][0]);
  rgExtent[Extent_Hi][1] = floatmax(area[NavArea_Extent][Extent_Hi][1], rgExtent[Extent_Hi][1]);
}

// For each ladder in the map, create a navigation representation of it.
BuildLadders() {
  log_amx("Building ladders...");

  new pEntity = 0;
  while ((pEntity = engfunc(EngFunc_FindEntityByString, pEntity, "classname", "func_ladder")) != 0) {
    BuildLadder(pEntity);
  }

  log_amx("All ladders built!");
}

BuildLadder(pEntity) {
    new Float:vecAbsMin[3]; pev(pEntity, pev_absmin, vecAbsMin);
    new Float:vecAbsMax[3]; pev(pEntity, pev_absmax, vecAbsMax);

    new rgNavLadder[NavLadder];
    rgNavLadder[NavLadder_Entity] = pEntity;

    // compute top & bottom of ladder
    xs_vec_set(rgNavLadder[NavLadder_Top], (vecAbsMin[0] + vecAbsMax[0]) / 2.0, (vecAbsMin[1] + vecAbsMax[1]) / 2.0, vecAbsMax[2]);
    xs_vec_set(rgNavLadder[NavLadder_Bottom], rgNavLadder[NavLadder_Top][0], rgNavLadder[NavLadder_Top][1], vecAbsMin[2]);

    // determine facing - assumes "normal" runged ladder
    new Float:xSize = vecAbsMax[0] - vecAbsMin[0];
    new Float:ySize = vecAbsMax[1] - vecAbsMin[1];

    if (xSize > ySize) {
      // ladder is facing north or south - determine which way
      // "pull in" traceline from bottom and top in case ladder abuts floor and/or ceiling
      new Float:vecFrom[3]; xs_vec_add(rgNavLadder[NavLadder_Bottom], Float:{0.0, GenerationStepSize, GenerationStepSize}, vecFrom);
      new Float:vecTo[3]; xs_vec_add(rgNavLadder[NavLadder_Top], Float:{0.0, GenerationStepSize, -GenerationStepSize}, vecTo);

      engfunc(EngFunc_TraceLine, vecFrom, vecTo, IGNORE_MONSTERS, pEntity, g_pTrace);

      new Float:flFraction; get_tr2(g_pTrace, TR_flFraction, flFraction);

      if (flFraction != 1.0 || get_tr2(g_pTrace, TR_StartSolid)) {
        rgNavLadder[NavLadder_Dir] = NORTH;
      } else {
        rgNavLadder[NavLadder_Dir] = SOUTH;
      }
    } else {
      // ladder is facing east or west - determine which way
      new Float:vecFrom[3]; xs_vec_add(rgNavLadder[NavLadder_Bottom], Float:{GenerationStepSize, 0.0, GenerationStepSize}, vecFrom);
      new Float:vecTo[3]; xs_vec_add(rgNavLadder[NavLadder_Top], Float:{GenerationStepSize, 0.0, -GenerationStepSize}, vecTo);

      engfunc(EngFunc_TraceLine, vecFrom, vecTo, IGNORE_MONSTERS, pEntity, g_pTrace);

      new Float:flFraction; get_tr2(g_pTrace, TR_flFraction, flFraction);

      if (flFraction != 1.0 || get_tr2(g_pTrace, TR_StartSolid)) {
        rgNavLadder[NavLadder_Dir] = WEST;
      } else {
        rgNavLadder[NavLadder_Dir] = EAST;
      }
    }

    // adjust top and bottom of ladder to make sure they are reachable
    // (cs_office has a crate right in front of the base of a ladder)
    new Float:vecAlong[3]; xs_vec_sub(rgNavLadder[NavLadder_Top], rgNavLadder[NavLadder_Bottom], vecAlong);

    // adjust bottom to bypass blockages
    AdjustLadderPositionToBypassBlockages(pEntity, rgNavLadder[NavLadder_Bottom], rgNavLadder[NavLadder_Dir], vecAlong);

    // adjust top to bypass blockages
    AdjustLadderPositionToBypassBlockages(pEntity, rgNavLadder[NavLadder_Top], rgNavLadder[NavLadder_Dir], vecAlong);

    rgNavLadder[NavLadder_Length] = xs_vec_distance(rgNavLadder[NavLadder_Top], rgNavLadder[NavLadder_Bottom]);

    DirectionToVector2D(rgNavLadder[NavLadder_Dir], rgNavLadder[NavLadder_DirVector]);

    new Float:vecCenter[3];
    
    // Find naviagtion area at bottom of ladder
    // get approximate postion of player on ladder
    xs_vec_add(rgNavLadder[NavLadder_Bottom], Float:{0.0, 0.0, GenerationStepSize}, vecCenter);
    AddDirectionVector(vecCenter, rgNavLadder[NavLadder_Dir], HalfHumanWidth);

    rgNavLadder[NavLadder_BottomArea] = NavAreaGrid_GetNearestNavArea(vecCenter, true, nullptr);

    // Find adjacent navigation areas at the top of the ladder
    // get approximate postion of player on ladder
    xs_vec_add(rgNavLadder[NavLadder_Top], Float:{0.0, 0.0, GenerationStepSize}, vecCenter);
    AddDirectionVector(vecCenter, rgNavLadder[NavLadder_Dir], HalfHumanWidth);

    static const Float:flNearLadderRange = 75.0;

    // find "ahead" area
    rgNavLadder[NavLadder_TopForwardArea] = FindFirstAreaInDirection(vecCenter, OppositeDirection(rgNavLadder[NavLadder_Dir]), flNearLadderRange, 120.0, pEntity);
    if (rgNavLadder[NavLadder_TopForwardArea] == rgNavLadder[NavLadder_BottomArea]) {
      rgNavLadder[NavLadder_TopForwardArea] = INVALID_NAV_AREA;
    }

    // find "left" area
    rgNavLadder[NavLadder_TopLeftArea] = FindFirstAreaInDirection(vecCenter, DirectionLeft(rgNavLadder[NavLadder_Dir]), flNearLadderRange, 120.0, pEntity);
    if (rgNavLadder[NavLadder_TopLeftArea] == rgNavLadder[NavLadder_BottomArea]) {
      rgNavLadder[NavLadder_TopLeftArea] = INVALID_NAV_AREA;
    }

    // find "right" area
    rgNavLadder[NavLadder_TopRightArea] = FindFirstAreaInDirection(vecCenter, DirectionRight(rgNavLadder[NavLadder_Dir]), flNearLadderRange, 120.0, pEntity);
    if (rgNavLadder[NavLadder_TopRightArea] == rgNavLadder[NavLadder_BottomArea]) {
      rgNavLadder[NavLadder_TopRightArea] = INVALID_NAV_AREA;
    }

    // find "behind" area - must look farther, since ladder is against the wall away from this area
    rgNavLadder[NavLadder_TopBehindArea] = FindFirstAreaInDirection(vecCenter, rgNavLadder[NavLadder_Dir], 2.0 * flNearLadderRange, 120.0, pEntity);
    if (rgNavLadder[NavLadder_TopBehindArea] == rgNavLadder[NavLadder_BottomArea]) {
      rgNavLadder[NavLadder_TopBehindArea] = INVALID_NAV_AREA;
    }

    // can't include behind area, since it is not used when going up a ladder
    if (rgNavLadder[NavLadder_BottomArea] == INVALID_NAV_AREA) {
      log_amx("ERROR: Unconnected ladder bottom at (%f, %f, %f)", rgNavLadder[NavLadder_Bottom][0], rgNavLadder[NavLadder_Bottom][1], rgNavLadder[NavLadder_Bottom][2]);
      return;
    }

    if (rgNavLadder[NavLadder_TopForwardArea] == INVALID_NAV_AREA && rgNavLadder[NavLadder_TopLeftArea] == INVALID_NAV_AREA && rgNavLadder[NavLadder_TopRightArea] == INVALID_NAV_AREA) {
      log_amx("ERROR: Unconnected ladder top at (%f, %f, %f)", rgNavLadder[NavLadder_Top][0], rgNavLadder[NavLadder_Top][1], rgNavLadder[NavLadder_Top][2]);
      return;
    }

    // store reference to ladder in the area
    if (rgNavLadder[NavLadder_BottomArea] != INVALID_NAV_AREA) {
      @NavArea_AddLadderUp(NAVAREA_PTR(rgNavLadder[NavLadder_BottomArea]), rgNavLadder);
    }

    // store reference to ladder in the area(s)
    if (rgNavLadder[NavLadder_TopForwardArea] != INVALID_NAV_AREA) {
      @NavArea_AddLadderDown(NAVAREA_PTR(rgNavLadder[NavLadder_TopForwardArea]), rgNavLadder);
    }

    if (rgNavLadder[NavLadder_TopLeftArea] != INVALID_NAV_AREA) {
      @NavArea_AddLadderDown(NAVAREA_PTR(rgNavLadder[NavLadder_TopLeftArea]), rgNavLadder);
    }

    if (rgNavLadder[NavLadder_TopRightArea] != INVALID_NAV_AREA) {
      @NavArea_AddLadderDown(NAVAREA_PTR(rgNavLadder[NavLadder_TopRightArea]), rgNavLadder);
    }

    if (rgNavLadder[NavLadder_TopBehindArea] != INVALID_NAV_AREA) {
      @NavArea_AddLadderDown(NAVAREA_PTR(rgNavLadder[NavLadder_TopBehindArea]), rgNavLadder);
    }

    // adjust top of ladder to highest connected area
    new Float:flTopZ = -99999.9;
    new bool:bTopAdjusted = false;

    new rgsTopAreaList[NUM_CORNERS];
    rgsTopAreaList[NORTH_WEST] = rgNavLadder[NavLadder_TopForwardArea];
    rgsTopAreaList[NORTH_EAST] = rgNavLadder[NavLadder_TopLeftArea];
    rgsTopAreaList[SOUTH_EAST] = rgNavLadder[NavLadder_TopRightArea];
    rgsTopAreaList[SOUTH_WEST] = rgNavLadder[NavLadder_TopBehindArea];

    for (new NavCornerType:iCorner = NORTH_WEST; iCorner < NUM_CORNERS; iCorner++) {
      new iTopArea = rgsTopAreaList[iCorner];
      if (iTopArea == INVALID_NAV_AREA) continue;

      new Float:vecClose[3]; @NavArea_GetClosestPointOnArea(NAVAREA_PTR(iTopArea), rgNavLadder[NavLadder_Top], vecClose);

      if (flTopZ < vecClose[2]) {
        flTopZ = vecClose[2];
        bTopAdjusted = true;
      }
    }

    if (bTopAdjusted) rgNavLadder[NavLadder_Top][2] = flTopZ;

    // Determine whether this ladder is "dangling" or not
    // "Dangling" ladders are too high to go up
    rgNavLadder[NavLadder_IsDangling] = false;
    if (rgNavLadder[NavLadder_BottomArea]) {
      new Float:vecBottomSpot[3]; @NavArea_GetClosestPointOnArea(NAVAREA_PTR(rgNavLadder[NavLadder_BottomArea]), rgNavLadder[NavLadder_Bottom], vecBottomSpot);
      if (rgNavLadder[NavLadder_Bottom][2] - vecBottomSpot[2] > HumanHeight) {
        rgNavLadder[NavLadder_IsDangling] = true;
      }
    }

    // add ladder to global list
    // new Struct:sNavLadder = @NavLadder_Create();
    // StructSetArray(sNavLadder, 0, rgNavLadder, _:NavLadder);
    // ArrayPushCell(g_irgNavLadderList, sNavLadder);
}

AdjustLadderPositionToBypassBlockages(pEntity, Float:vecPosition[], NavDirType:iDir, const Float:vecAlong[]) {
    static const Float:flMinLadderClearance = 32.0;
    static const Float:flLadderStep = 10.0;

    new Float:flPathLength = xs_vec_len(vecAlong);

    new Float:vecOn[3];
    new Float:vecOut[3];

    for (new Float:flPath = 0.0; flPath <= flPathLength; flPath += flLadderStep) {
      xs_vec_sub_scaled(vecPosition, vecAlong, flPath, vecOn);

      xs_vec_copy(vecOn, vecOut);
      AddDirectionVector(vecOut, iDir, flMinLadderClearance);

      engfunc(EngFunc_TraceLine, vecOn, vecOut, IGNORE_MONSTERS, pEntity, g_pTrace);

      new Float:flFraction; get_tr2(g_pTrace, TR_flFraction, flFraction);

      if (flFraction == 1.0 && !get_tr2(g_pTrace, TR_StartSolid)) {
        // found viable ladder pos
        xs_vec_copy(vecOn, vecPosition);
        break;
      }
    }
}

FindFirstAreaInDirection(const Float:vecStart[], NavDirType:iDir, Float:flRange, Float:flBeneathLimit, pIgnoreEnt, Float:vecClosePos[3] = 0.0) {
  static iArea; iArea = INVALID_NAV_AREA;

  static Float:vecPos[3]; xs_vec_copy(vecStart, vecPos);

  static iEnd; iEnd = floatround((flRange / GenerationStepSize) + 0.5);

  for (new i = 1; i <= iEnd; i++) {
    AddDirectionVector(vecPos, iDir, GenerationStepSize);

    // make sure we dont look thru the wall
    engfunc(EngFunc_TraceLine, vecStart, vecPos, IGNORE_MONSTERS, pIgnoreEnt, g_pTrace);

    static Float:flFraction; get_tr2(g_pTrace, TR_flFraction, flFraction);
    if (flFraction != 1.0) break;

    iArea = NavAreaGrid_GetNavArea(vecPos, flBeneathLimit);

    if (iArea != INVALID_NAV_AREA) {
      xs_vec_set(vecClosePos, vecPos[0], vecPos[1], @NavArea_GetZ(NAVAREA_PTR(iArea), vecPos));
      break;
    }
  }

  return iArea;
}

NavAreaPopOpenList() {
  if (g_iNavAreaOpenList != INVALID_NAV_AREA) {
    static iArea; iArea = g_iNavAreaOpenList;
    @NavArea_RemoveFromOpenList(NAVAREA_PTR(iArea));
    return iArea;
  }

  return INVALID_NAV_AREA;
}

NavAreaMakeNewMarker() {
  if (++g_iNavAreaMasterMarker == 0) {
    g_iNavAreaMasterMarker = 1;
  }
}

NavAreaClearSearchLists() {
  NavAreaMakeNewMarker();
  g_iNavAreaOpenList = INVALID_NAV_AREA;
}

NavAreaBuildPath(const Float:vecStart[], const Float:vecGoal[], iCbFuncId = -1, iCbFuncPluginId = -1, pIgnoreEnt, iUserToken, iCostFuncId = -1, iCostFuncPluginId = -1) {
  if (!g_bPrecached) return INVALID_BUILD_PATH_TASK;

  static iStartArea; iStartArea = NavAreaGrid_GetNearestNavArea(vecStart, false, pIgnoreEnt);
  if (iStartArea == INVALID_NAV_AREA) return INVALID_BUILD_PATH_TASK;

  static iGoalArea; iGoalArea = NavAreaGrid_GetNearestNavArea(vecGoal, false, pIgnoreEnt);
  if (iGoalArea == INVALID_NAV_AREA) return INVALID_BUILD_PATH_TASK;
  
  static iTask; iTask = FindFreeTaskSlot();

  if (iTask == INVALID_BUILD_PATH_TASK) return INVALID_BUILD_PATH_TASK;
  
  @BuildPathTask_Allocate(
    TASK_PTR(iTask),
    iUserToken,
    iStartArea,
    iGoalArea,
    vecStart,
    vecGoal,
    pIgnoreEnt,
    iCbFuncPluginId,
    iCbFuncId,
    iCostFuncPluginId,
    iCostFuncId
  );

  if (g_irgBuildPathTasksQueue == Invalid_Array) {
    g_irgBuildPathTasksQueue = ArrayCreate();
  }

  ArrayPushCell(g_irgBuildPathTasksQueue, iTask);

  return iTask;
}

bool:NavAreaBuildPathAbortTask(task[BuildPathTask]) {
  // if task already in progress
  if (g_rgBuildPathJob[BuildPathJob_Task] == task[BuildPathTask_Index]) {
    g_rgBuildPathJob[BuildPathJob_Finished] = true;
    task[BuildPathTask_IsTerminated] = true;

    // finish task in the same frame
    NavAreaBuildPathFinish();

    return true;
  }

  if (g_irgBuildPathTasksQueue == Invalid_Array) return false;

  // remove task from the queue
  static iTaskQueueIndex; iTaskQueueIndex = ArrayFindValue(g_irgBuildPathTasksQueue, task[BuildPathTask_Index]);
  if (iTaskQueueIndex != -1) {
    @BuildPathTask_Free(task);
    ArrayDeleteItem(g_irgBuildPathTasksQueue, iTaskQueueIndex);
    return true;
  }

  return false;
}

bool:NavAreaBuildPathRunTask(task[BuildPathTask]) {
  static iStartArea; iStartArea = task[BuildPathTask_StartArea];

  g_rgBuildPathJob[BuildPathJob_Task] = task[BuildPathTask_Index];
  g_rgBuildPathJob[BuildPathJob_Finished] = false;
  g_rgBuildPathJob[BuildPathJob_Released] = false;
  g_rgBuildPathJob[BuildPathJob_MaxIterations] = g_iMaxIterationsPerFrame;
  g_rgBuildPathJob[BuildPathJob_ClosestAreaDist] = 999999.0;
  g_rgBuildPathJob[BuildPathJob_ClosestArea] = INVALID_NAV_AREA;

  @NavArea_SetParent(NAVAREA_PTR(iStartArea), INVALID_NAV_AREA, NUM_TRAVERSE_TYPES);

  // if we are already in the goal area, build trivial path
  if (iStartArea == task[BuildPathTask_GoalArea]) {
    @NavArea_SetParent(NAVAREA_PTR(task[BuildPathTask_GoalArea]), INVALID_NAV_AREA, NUM_TRAVERSE_TYPES);
    g_rgBuildPathJob[BuildPathJob_ClosestArea] = task[BuildPathTask_GoalArea];
    task[BuildPathTask_IsSuccessed] = true;
    g_rgBuildPathJob[BuildPathJob_Finished] = true;

    return true;
  }

  // determine actual goal position
  if (xs_vec_len(task[BuildPathTask_GoalPos]) > 0.0) {
    xs_vec_copy(task[BuildPathTask_GoalPos], task[BuildPathTask_ActualGoalPos]);
  } else {
    @NavArea_GetCenter(NAVAREA_PTR(task[BuildPathTask_GoalArea]), task[BuildPathTask_ActualGoalPos]);
  }

  // start search
  NavAreaClearSearchLists();

  // compute estimate of path length
  // TODO: Cost might work as "manhattan distance"
  static Float:vecStartAreaCenter[3]; @NavArea_GetCenter(NAVAREA_PTR(iStartArea), vecStartAreaCenter);
  @NavArea_SetTotalCost(NAVAREA_PTR(iStartArea), xs_vec_distance(vecStartAreaCenter, task[BuildPathTask_ActualGoalPos]));

  static Float:flInitCost; flInitCost = 0.0;

  if (task[BuildPathTask_CostCallback][Callback_FunctionId] != -1) {
    if (callfunc_begin_i(task[BuildPathTask_CostCallback][Callback_FunctionId], task[BuildPathTask_CostCallback][Callback_PluginId])) {
      callfunc_push_int(g_rgBuildPathJob[BuildPathJob_Task]);
      callfunc_push_int(iStartArea);
      callfunc_push_int(INVALID_NAV_AREA);
      flInitCost = Float:callfunc_end();
    }
  }

  if (flInitCost < 0.0) {
    g_rgBuildPathJob[BuildPathJob_Finished] = true;
    // task[BuildPathTask_IsTerminated] = true;
    return false;
  }

  @NavArea_SetCostSoFar(NAVAREA_PTR(iStartArea), flInitCost);
  @NavArea_AddToOpenList(NAVAREA_PTR(iStartArea));

  // keep track of the area we visit that is closest to the goal
  g_rgBuildPathJob[BuildPathJob_ClosestArea] = iStartArea;
  g_rgBuildPathJob[BuildPathJob_ClosestAreaDist] = @NavArea_GetTotalCost(NAVAREA_PTR(iStartArea));

  return true;
}

NavAreaBuildPathFinish() {
  new iTask = g_rgBuildPathJob[BuildPathJob_Task];
  g_rgBuildPathTasks[iTask][BuildPathTask_IsFinished] = true;

  // @NavPath_Invalidate(g_rgBuildPathTasks[iTask][BuildPathTask_Path]);

  if (!g_rgBuildPathTasks[iTask][BuildPathTask_IsTerminated]) {
    NavAreaBuildPathSegments();
  }

  if (g_rgBuildPathTasks[iTask][BuildPathTask_FinishCallback][Callback_FunctionId] != -1) {
    if (callfunc_begin_i(g_rgBuildPathTasks[iTask][BuildPathTask_FinishCallback][Callback_FunctionId], g_rgBuildPathTasks[iTask][BuildPathTask_FinishCallback][Callback_PluginId])) {
      callfunc_push_int(iTask);
      callfunc_end();
    }
  }

  g_rgBuildPathJob[BuildPathJob_Released] = true;
}

NavAreaBuildPathIteration() {
  static iTask; iTask = g_rgBuildPathJob[BuildPathJob_Task];

  if (g_iNavAreaOpenList == INVALID_NAV_AREA) {
    g_rgBuildPathJob[BuildPathJob_Finished] = true;
    return;
  }

  // get next area to check
  static iArea; iArea = NavAreaPopOpenList();

  // check if we have found the goal area
  if (iArea == g_rgBuildPathTasks[iTask][BuildPathTask_GoalArea]) {
    if (g_rgBuildPathJob[BuildPathJob_ClosestArea] != INVALID_NAV_AREA) {
      g_rgBuildPathJob[BuildPathJob_ClosestArea] = g_rgBuildPathTasks[iTask][BuildPathTask_GoalArea];
    }

    g_rgBuildPathJob[BuildPathJob_Finished] = true;
    g_rgBuildPathTasks[iTask][BuildPathTask_IsSuccessed] = true;

    return;
  }

  NavAreaBuildPathFloorIteration(TASK_PTR(iTask), NAVAREA_PTR(iArea));
  NavAreaBuildPathLadderUpIteration(TASK_PTR(iTask), NAVAREA_PTR(iArea));
  NavAreaBuildPathLadderDownIteration(TASK_PTR(iTask), NAVAREA_PTR(iArea));

  // we have searched this area
  @NavArea_AddToClosedList(NAVAREA_PTR(iArea));

  g_rgBuildPathTasks[iTask][BuildPathTask_IterationsNum]++;
}

NavAreaBuildPathFloorIteration(const task[BuildPathTask], const area[NavArea]) {
  static NavDirType:iDir;

  for (iDir = NORTH; iDir < NUM_DIRECTIONS; ++iDir) {
    static Array:irgFloorList; irgFloorList = @NavArea_GetAdjacentList(area, iDir);
    static iFloorListSize; iFloorListSize = ArraySize(irgFloorList);

    static iFloor;
    for (iFloor = 0; iFloor < iFloorListSize; ++iFloor) {
      static iNewArea; iNewArea = ArrayGetCell(irgFloorList, iFloor, _:NavConnect_Area);

      if (iNewArea == INVALID_NAV_AREA) continue;

      NavAreaBuildPathProcessNewArea(task, area, NAVAREA_PTR(iNewArea), NavTraverseType:iDir);
    }
  }
}

NavAreaBuildPathLadderUpIteration(const task[BuildPathTask], const area[NavArea]) {
  static Array:irgUpLadderList; irgUpLadderList = @NavArea_GetLadder(area, LADDER_UP);
  static iUpLadderListSize; iUpLadderListSize = ArraySize(irgUpLadderList);

  static iLadder;
  for (iLadder = 0; iLadder < iUpLadderListSize; ++iLadder) {
    if (ArrayGetCell(irgUpLadderList, iLadder, _:NavLadder_IsDangling)) continue;

    static iLadderTopDir;
    for (iLadderTopDir = LADDER_TOP_DIR_AHEAD; iLadderTopDir < NUM_TOP_DIRECTIONS; ++iLadderTopDir) {
      static iNewArea; iNewArea = INVALID_NAV_AREA;

      switch (iLadderTopDir) {
        case LADDER_TOP_DIR_AHEAD: {
          iNewArea = ArrayGetCell(irgUpLadderList, iLadder, _:NavLadder_TopForwardArea);
        }
        case LADDER_TOP_DIR_LEFT: {
          iNewArea = ArrayGetCell(irgUpLadderList, iLadder, _:NavLadder_TopLeftArea);
        }
        case LADDER_TOP_DIR_RIGHT: {
          iNewArea = ArrayGetCell(irgUpLadderList, iLadder, _:NavLadder_TopRightArea);
        }
      }

      if (iNewArea == INVALID_NAV_AREA) continue;

      NavAreaBuildPathProcessNewArea(task, area, NAVAREA_PTR(iNewArea), GO_LADDER_UP);
    }
  }
}

NavAreaBuildPathLadderDownIteration(const task[BuildPathTask], const area[NavArea]) {
  static Array:irgDownLadderList; irgDownLadderList = @NavArea_GetLadder(area, LADDER_DOWN);
  static iDownLadderListSize; iDownLadderListSize = ArraySize(irgDownLadderList);

  static iLadder;
  for (iLadder = 0; iLadder < iDownLadderListSize; ++iLadder) {
    static iNewArea; iNewArea = ArrayGetCell(irgDownLadderList, iLadder, _:NavLadder_BottomArea);

    if (iNewArea == INVALID_NAV_AREA) continue;

    NavAreaBuildPathProcessNewArea(task, area, NAVAREA_PTR(iNewArea), GO_LADDER_DOWN);
  }
}

bool:NavAreaBuildPathProcessNewArea(const task[BuildPathTask], const area[NavArea], newArea[NavArea], const NavTraverseType:iHow) {
  if (NAVAREA_INDEX(newArea) == NAVAREA_INDEX(area)) return false;

  static Float:flCost; flCost = 0.0;

  if (task[BuildPathTask_CostCallback][Callback_FunctionId] != -1) {
    if (callfunc_begin_i(task[BuildPathTask_CostCallback][Callback_FunctionId], task[BuildPathTask_CostCallback][Callback_PluginId])) {
      callfunc_push_int(task[BuildPathTask_Index]);
      callfunc_push_int(NAVAREA_INDEX(newArea));
      callfunc_push_int(NAVAREA_INDEX(area));
      flCost = Float:callfunc_end();
    }
  }

  // check if cost functor says this newArea is a dead-end
  if (flCost < 0.0) return false;

  static Float:flNewCostSoFar; flNewCostSoFar = @NavArea_GetCostSoFar(area) + flCost;

  if ((@NavArea_IsOpen(newArea) || @NavArea_IsClosed(newArea)) && @NavArea_GetCostSoFar(newArea) <= flNewCostSoFar) {
    // this is a worse path - skip it
    return false;
  }

  // compute estimate of distance left to go
  static Float:vecNewAreaCenter[3]; @NavArea_GetCenter(newArea, vecNewAreaCenter);
  static Float:flNewCostRemaining; flNewCostRemaining = xs_vec_distance(vecNewAreaCenter, task[BuildPathTask_ActualGoalPos]);

  // track closest area to goal in case path fails
  if (g_rgBuildPathJob[BuildPathJob_ClosestArea] != INVALID_NAV_AREA && flNewCostRemaining < g_rgBuildPathJob[BuildPathJob_ClosestAreaDist]) {
    g_rgBuildPathJob[BuildPathJob_ClosestArea] = NAVAREA_INDEX(newArea);
    g_rgBuildPathJob[BuildPathJob_ClosestAreaDist] = flNewCostRemaining;
  }

  @NavArea_SetParent(newArea, NAVAREA_INDEX(area), iHow);
  @NavArea_SetCostSoFar(newArea, flNewCostSoFar);
  @NavArea_SetTotalCost(newArea, flNewCostSoFar + flNewCostRemaining);

  if (@NavArea_IsClosed(newArea)) {
    @NavArea_RemoveFromClosedList(newArea);
  }

  if (@NavArea_IsOpen(newArea)) {
    // area already on open list, update the list order to keep costs sorted
    @NavArea_UpdateOnOpenList(newArea);
  } else {
    @NavArea_AddToOpenList(newArea);
  }

  return true;
}

NavAreaBuildPathFrame() {
  if (g_rgBuildPathJob[BuildPathJob_Task] != INVALID_BUILD_PATH_TASK) {
    if (g_rgBuildPathJob[BuildPathJob_Finished] && g_rgBuildPathJob[BuildPathJob_Released]) {
      @BuildPathTask_Free(TASK_PTR(g_rgBuildPathJob[BuildPathJob_Task]));
      g_rgBuildPathJob[BuildPathJob_Task] = INVALID_BUILD_PATH_TASK;
    }
  }

  // if no job in progress then find new task to start
  if (g_rgBuildPathJob[BuildPathJob_Task] == INVALID_BUILD_PATH_TASK) {
    if (g_irgBuildPathTasksQueue != Invalid_Array && ArraySize(g_irgBuildPathTasksQueue)) {
      static iTask; iTask = ArrayGetCell(g_irgBuildPathTasksQueue, 0);
      ArrayDeleteItem(g_irgBuildPathTasksQueue, 0);
      NavAreaBuildPathRunTask(TASK_PTR(iTask));
    }

    return;
  }

  // do path finding iterations
  static iIterationsNum; iIterationsNum = g_rgBuildPathJob[BuildPathJob_MaxIterations];
  for (new i = 0; i < iIterationsNum && !g_rgBuildPathJob[BuildPathJob_Finished]; ++i) {
    NavAreaBuildPathIteration();
  }

  // current job finished, process
  if (g_rgBuildPathJob[BuildPathJob_Finished]) {
    NavAreaBuildPathFinish();
  }
}

NavAreaBuildPathSegments() {
  static iTask; iTask = g_rgBuildPathJob[BuildPathJob_Task];
  static Struct:sNavPath; sNavPath = g_rgBuildPathTasks[iTask][BuildPathTask_Path];

  static iSegmentCount; iSegmentCount = 0;

  static iEffectiveGoalArea; iEffectiveGoalArea = (
    g_rgBuildPathTasks[iTask][BuildPathTask_IsSuccessed]
      ? g_rgBuildPathTasks[iTask][BuildPathTask_GoalArea]
      : g_rgBuildPathJob[BuildPathJob_ClosestArea]
  );

  if (g_rgBuildPathTasks[iTask][BuildPathTask_StartArea] != g_rgBuildPathTasks[iTask][BuildPathTask_GoalArea]) {
    // save room for endpoint
    if (iEffectiveGoalArea != INVALID_NAV_AREA) {
      iSegmentCount = NavAreaCalculateSegmentCount(NAVAREA_PTR(iEffectiveGoalArea));
      iSegmentCount = min(iSegmentCount, MAX_PATH_SEGMENTS - 1);
    }
  } else {
    iSegmentCount = 1;
  }

  if (iSegmentCount == 0) {
    @NavPath_Invalidate(sNavPath);
    return false;
  }

  static Array:irgSegments; irgSegments = StructGetCell(sNavPath, NavPath_Segments);
  ArrayResize(irgSegments, iSegmentCount);
  StructSetCell(sNavPath, NavPath_SegmentCount, iSegmentCount);

  if (iSegmentCount > 1) {
    // Prepare segments
    static iArea; iArea = iEffectiveGoalArea;

    for (new iSegment = iSegmentCount - 1; iSegment >= 0; --iSegment) {
      ArraySetCell(irgSegments, iSegment, iArea, _:PathSegment_Area);
      ArraySetCell(irgSegments, iSegment, NAVAREA_PTR(iArea)[NavArea_ParentHow], _:PathSegment_How);

      iArea = NAVAREA_PTR(iArea)[NavArea_Parent];
    }

    if (!@NavPath_ComputePathPositions(sNavPath)) {
      @NavPath_Invalidate(sNavPath);
      return false;
    }

    // append path end position
    static rgEndSegment[PathSegment];
    rgEndSegment[PathSegment_Area] = iEffectiveGoalArea;
    rgEndSegment[PathSegment_How] = NUM_TRAVERSE_TYPES;
    xs_vec_set(rgEndSegment[PathSegment_Pos], g_rgBuildPathTasks[iTask][BuildPathTask_GoalPos][0], g_rgBuildPathTasks[iTask][BuildPathTask_GoalPos][1], @NavArea_GetZ(NAVAREA_PTR(iEffectiveGoalArea), g_rgBuildPathTasks[iTask][BuildPathTask_GoalPos]));
    @NavPath_PushSegment(sNavPath, rgEndSegment);
    iSegmentCount++;
  } else {
    @NavPath_BuildTrivialPath(sNavPath, g_rgBuildPathTasks[iTask][BuildPathTask_StartPos], g_rgBuildPathTasks[iTask][BuildPathTask_GoalPos]);
  }

  if (g_bDebug) {
    for (new iSegment = 1; iSegment < iSegmentCount; ++iSegment) {
      static Float:vecSrc[3]; ArrayGetArray2(irgSegments, iSegment - 1, vecSrc, 3, PathSegment_Pos);
      static Float:vecNext[3]; ArrayGetArray2(irgSegments, iSegment, vecNext, 3, PathSegment_Pos);

      static irgColor[3];
      irgColor[0] = floatround(255.0 * (1.0 - (float(iSegment) / iSegmentCount)));
      irgColor[1] = floatround(255.0 * (float(iSegment) / iSegmentCount));
      irgColor[2] = 0;

      UTIL_DrawArrow(0, vecSrc, vecNext, irgColor, 255, 30);
    }
  }

  return true;
}

NavAreaCalculateSegmentCount(const goalArea[NavArea]) {
  static iCount; iCount = 0;

  static iArea; iArea = NAVAREA_INDEX(goalArea);

  while (iArea != INVALID_NAV_AREA) {
    iCount++;
    iArea = NAVAREA_PTR(iArea)[NavArea_Parent];
  }

  return iCount;
}

FindFreeTaskSlot() {
  for (new iTask; iTask < MAX_NAV_PATH_TASKS; ++iTask) {
    if (g_rgBuildPathTasks[iTask][BuildPathTask_IsFree]) {
      return iTask;
    }
  }

  return INVALID_BUILD_PATH_TASK;
}

// Can we see this area?
// For now, if we can see any corner, we can see the area
// TODO: Need to check LOS to more than the corners for large and/or long areas
stock bool:IsAreaVisible(const Float:vecPos[], const area[NavArea]) {
  for (new NavCornerType:iCorner = NORTH_WEST; iCorner < NUM_CORNERS; iCorner++) {
    static Float:vecCorner[3];
    @NavArea_GetCorner(area, iCorner, vecCorner);
    vecCorner[2] += 0.75 * HumanHeight;

    engfunc(EngFunc_TraceLine, vecPos, vecCorner, IGNORE_MONSTERS, nullptr, g_pTrace);

    static Float:flFraction; get_tr2(g_pTrace, TR_flFraction, flFraction);
    if (flFraction == 1.0) return true;
  }

  return false;
}

stock bool:IsEntityWalkable(pEntity, iFlags) {
  static szClassName[32]; pev(pEntity, pev_classname, szClassName, charsmax(szClassName));

  // if we hit a door, assume its walkable because it will open when we touch it
  if (equal(szClassName, "func_door") || equal(szClassName, "func_door_rotating")) {
    return !!(iFlags & WALK_THRU_DOORS);
  }
  
  if (equal(szClassName, "func_breakable")) {
    // if we hit a breakable object, assume its walkable because we will shoot it when we touch it
    static Float:flTakeDamage; pev(pEntity, pev_takedamage, flTakeDamage);
    if (flTakeDamage == DAMAGE_YES) {
      return !!(iFlags & WALK_THRU_BREAKABLES);
    }
  }

  return false;
}

stock Float:GetGroundHeight(const Float:vecPos[], pIgnoreEnt, Float:vecNormal[] = {0.0, 0.0, 0.0}) {
  enum GroundLayerInfo {
    Float:GroundLayerInfo_Ground,
    Float:GroundLayerInfo_Normal[3]
  };

  static Float:vecFrom[3]; xs_vec_copy(vecPos, vecFrom);
  static Float:vecTo[3]; xs_vec_set(vecTo, vecPos[0], vecPos[1], -8192.0);

  static const Float:flMaxOffset = 100.0;
  static const Float:flInc = 10.0;

  static rgLayer[MAX_NAV_GROUND_LAYERS][GroundLayerInfo];
  static iLayerCount; iLayerCount = 0;

  static pIgnore; pIgnore = pIgnoreEnt;
  static Float:flOffset;

  for (flOffset = 1.0; flOffset < flMaxOffset; flOffset += flInc) {
    vecFrom[2] = vecPos[2] + flOffset;

    engfunc(EngFunc_TraceLine, vecFrom, vecTo, IGNORE_MONSTERS, pIgnore, g_pTrace);

    static Float:flFraction; get_tr2(g_pTrace, TR_flFraction, flFraction);

    if (flFraction != 1.0) {
      static pHit; pHit = get_tr2(g_pTrace, TR_pHit);
      if (pHit > 0) {
        // ignoring any entities that we can walk through
        if (IsEntityWalkable(pHit, WALK_THRU_DOORS | WALK_THRU_BREAKABLES)) {
          pIgnore = pHit;
          continue;
        }
      }
    }

    static bool:bStartSolid; bStartSolid = bool:get_tr2(g_pTrace, TR_StartSolid);

    if (!bStartSolid) {
      static Float:vecEndPos[3]; get_tr2(g_pTrace, TR_vecEndPos, vecEndPos);

      if (iLayerCount == 0 || vecEndPos[2] > rgLayer[iLayerCount - 1][GroundLayerInfo_Ground]) {
        static Float:vecPlaneNormal[3]; get_tr2(g_pTrace, TR_vecPlaneNormal, vecPlaneNormal);

        rgLayer[iLayerCount][GroundLayerInfo_Ground] = vecEndPos[2];
        xs_vec_copy(vecPlaneNormal, rgLayer[iLayerCount][GroundLayerInfo_Normal]);
        iLayerCount++;

        if (iLayerCount == MAX_NAV_GROUND_LAYERS) break;
      }
    }
  }

  if (!iLayerCount) return -1.0;

  static i;
  for (i = 0; i < iLayerCount - 1; i++) {
    if (rgLayer[i + 1][GroundLayerInfo_Ground] - rgLayer[i][GroundLayerInfo_Ground] >= HalfHumanHeight) {
      break;
    }
  }

  xs_vec_copy(rgLayer[i][GroundLayerInfo_Normal], vecNormal);

  return rgLayer[i][GroundLayerInfo_Ground];
}

stock NavDirType:OppositeDirection(NavDirType:iDir) {
  switch (iDir) {
    case NORTH: return SOUTH;
    case EAST: return WEST;
    case SOUTH: return NORTH;
    case WEST: return EAST;
  }

  return NORTH;
}

stock NavDirType:DirectionLeft(NavDirType:iDir) {
  switch (iDir) {
    case NORTH: return WEST;
    case SOUTH: return EAST;
    case EAST: return NORTH;
    case WEST: return SOUTH;
  }

  return NORTH;
}

stock NavDirType:DirectionRight(NavDirType:iDir) {
  switch (iDir) {
    case NORTH: return EAST;
    case SOUTH: return WEST;
    case EAST: return SOUTH;
    case WEST: return NORTH;
  }

  return NORTH;
}

stock AddDirectionVector(Float:vecInput[], NavDirType:iDir, Float:flAmount) {
  switch (iDir) {
    case NORTH: vecInput[1] -= flAmount;
    case SOUTH: vecInput[1] += flAmount;
    case EAST: vecInput[0] += flAmount;
    case WEST: vecInput[0] -= flAmount;
  }
}

stock DirectionToVector2D(NavDirType:iDir, Float:vecOutput[]) {
  switch (iDir) {
    case NORTH: {
      vecOutput[0] = 0.0;
      vecOutput[1] = -1.0;
    }
    case SOUTH: {
      vecOutput[0] = 0.0;
      vecOutput[1] = 1.0;
    }
    case EAST: {
      vecOutput[0] = 1.0;
      vecOutput[1] = 0.0;
    }
    case WEST: {
      vecOutput[0] = -1.0;
      vecOutput[1] = 0.0;
    }
  }
}

stock Float:NormalizeInPlace(const Float:vecSrc[], Float:vecOut[]) {
  static Float:flLen; flLen = xs_vec_len(vecSrc);

  if (flLen > 0) {
    vecOut[0] = vecSrc[0] / flLen;
    vecOut[1] = vecSrc[1] / flLen;
    vecOut[2] = vecSrc[2] / flLen;
  } else {
    vecOut[0] = 0.0;
    vecOut[1] = 0.0;
    vecOut[2] = 1.0;
  }

  return flLen;
}

stock UTIL_DrawArrow(pPlayer, const Float:vecSrc[], const Float:vecTarget[], const irgColor[3] = {255, 255, 255}, iBrightness = 255, iLifeTime = 10, iWidth = 64) {
  engfunc(EngFunc_MessageBegin, pPlayer ? MSG_ONE : MSG_ALL, SVC_TEMPENTITY, vecSrc, pPlayer);
  write_byte(TE_BEAMPOINTS);
  engfunc(EngFunc_WriteCoord, vecTarget[0]);
  engfunc(EngFunc_WriteCoord, vecTarget[1]);
  engfunc(EngFunc_WriteCoord, vecTarget[2] + 16.0);
  engfunc(EngFunc_WriteCoord, vecSrc[0]);
  engfunc(EngFunc_WriteCoord, vecSrc[1]);
  engfunc(EngFunc_WriteCoord, vecSrc[2] + 16.0);
  write_short(g_iArrowModelIndex);
  write_byte(0);
  write_byte(0);
  write_byte(iLifeTime);
  write_byte(iWidth);
  write_byte(0);
  write_byte(irgColor[0]);
  write_byte(irgColor[1]);
  write_byte(irgColor[2]);
  write_byte(iBrightness);
  write_byte(0);
  message_end();
}

stock ArrayGetArray2(const &Array:irgArray, any:iItem, any:rgOut[], any:iSize, any:iBlock) {
  for (new i = 0; i < iSize; ++i) {
    rgOut[i] = ArrayGetCell(irgArray, iItem, iBlock + i);
  }
}

stock ArraySetArray2(const &Array:irgArray, any:iItem, const any:rgValue[], any:iSize, any:iBlock) {
  for (new i = 0; i < iSize; ++i) {
    ArraySetCell(irgArray, iItem, rgValue[i], iBlock + i);
  }
}
