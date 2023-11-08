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

enum Extent { Float:Extent_Lo[3], Float:Extent_Hi[3] };
enum Ray { Float:Ray_From[3], Float:Ray_To[3]};
enum NavConnect { NavConnect_Id, Struct:NavConnect_Area };
enum SpotOrder { SpotOrder_Id, Float:SpotOrder_T, Struct:SpotOrder_Spot };
enum PathSegment { Struct:PathSegment_Area, NavTraverseType:PathSegment_How, Float:PathSegment_Pos[3] };
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
    Struct:NavAreaGrid_HashTable[HASH_TABLE_SIZE]
};

enum NavArea {
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

    Array:NavArea_OverlapList, // list of areas that overlap this area

    // connections for grid hash table
    Struct:NavArea_PrevHash,
    Struct:NavArea_NextHash,

    Struct:NavArea_NextOpen, // only valid if m_openMarker == m_masterMarker
    Struct:NavArea_PrevOpen,
    NavArea_OpenMarker, // if this equals the current marker value, we are on the open list

    // A* pathfinding algorithm
    NavArea_Marker, // used to flag the area as visited
    Struct:NavArea_Parent, // the area just prior to this on in the search path
    NavTraverseType:NavArea_ParentHow, // how we get from parent to us
    Float:NavArea_TotalCost, // the distance so far plus an estimate of the distance left
    Float:NavArea_CostSoFar, // distance travelled so far
};

enum BuildPathTask {
    Float:BuildPathTask_StartPos[3],
    Float:BuildPathTask_GoalPos[3],
    Struct:BuildPathTask_StartArea,
    Struct:BuildPathTask_GoalArea, 
    Struct:BuildPathTask_ClosestArea,
    BuildPathTask_CostFuncId,
    BuildPathTask_CostFuncPluginId,
    BuildPathTask_CbFuncId,
    BuildPathTask_CbFuncPluginId,
    BuildPathTask_IgnoreEntity,
    BuildPathTask_UserToken,
    Struct:BuildPathTask_Path,
    bool:BuildPathTask_IsSuccessed,
    bool:BuildPathTask_IsTerminated
};

enum BuildPathJob {
    Struct:BuildPathJob_Task,
    Struct:BuildPathJob_StartArea,
    Struct:BuildPathJob_GoalArea, 
    Float:BuildPathJob_ActualGoalPos[3],
    Float:BuildPathJob_GoalPos[3],
    Float:BuildPathJob_ClosestAreaDist,
    Struct:BuildPathJob_ClosestArea,
    BuildPathJob_CostFuncId,
    BuildPathJob_CostFuncPluginId,
    bool:BuildPathJob_Successed,
    bool:BuildPathJob_Finished,
    bool:BuildPathJob_Terminated,
    BuildPathJob_MaxIterations,
    BuildPathJob_IgnoreEntity
};

const Float:GenerationStepSize = 25.0; 
const Float:StepHeight = 18.0;
const Float:HalfHumanWidth = 16.0;
const Float:HalfHumanHeight = 36.0;
const Float:HumanHeight = 72.0;

new g_rgGrid[NavAreaGrid];

new g_iNavAreaNextId = 0;
new g_iNavAreaMasterMarker;
new Array:g_irgNavAreaList = Invalid_Array;
new Struct:g_sNavAreaOpenList = Invalid_Struct;

new g_rgBuildPathJob[BuildPathJob];
new Array:g_irgBuildPathTasks = Invalid_Array;

new g_pTrace;

new g_pCvarMaxIterationsPerFrame;
new g_pCvarDebug;

new bool:g_bPrecached = false;
new g_iArrowModelIndex;

public plugin_precache() {
    g_pTrace = create_tr2();
    g_iArrowModelIndex = precache_model("sprites/arrow1.spr");
}

public plugin_init() {
    register_plugin("Nav System", "0.1.0", "Hedgehog Fog");

    g_pCvarMaxIterationsPerFrame = register_cvar("nav_max_iterations_per_frame", "100");
    g_pCvarDebug = register_cvar("nav_debug", "0");
}

public plugin_end() {
    if (g_irgNavAreaList != Invalid_Array) {
        new iNavAreaListSize = ArraySize(g_irgNavAreaList);

        for (new i = 0; i < iNavAreaListSize; ++i) {
            new Struct:sNavArea = ArrayGetCell(g_irgNavAreaList, i);
            @NavArea_Destroy(sNavArea);
        }

        ArrayDestroy(g_irgNavAreaList);
    }

    NavAreaGrid_Free();

    if (g_irgBuildPathTasks != Invalid_Array) {
        ArrayDestroy(g_irgBuildPathTasks);
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

    register_native("Nav_Area_GetAttributes", "Native_Area_GetAttributes");
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

    register_native("Nav_Path_IsValid", "Native_Path_IsValid");
    register_native("Nav_Path_GetSegments", "Native_Path_GetSegments");
    register_native("Nav_Path_Segment_GetPos", "Native_Path_Segment_GetPos");

    register_native("Nav_Path_Find", "Native_Path_Find");
    register_native("Nav_Path_FindTask_GetUserToken", "Native_Path_FindTask_GetUserToken");
    register_native("Nav_Path_FindTask_Abort", "Native_Path_FindTask_Abort");
    register_native("Nav_Path_FindTask_GetPath", "Native_Path_FindTask_GetPath");
    register_native("Nav_Path_FindTask_IsSuccessed", "Native_Path_FindTask_IsSuccessed");
    register_native("Nav_Path_FindTask_IsTerminated", "Native_Path_FindTask_IsTerminated");
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
    return g_irgNavAreaList != Invalid_Array ? ArraySize(g_irgNavAreaList) : 0;
}

public Struct:Native_GetArea(iPluginId, iArgc) {
    if (g_irgNavAreaList == Invalid_Array) {
        return Invalid_Struct;
    }

    new iIndex = get_param(1);
    if (iIndex >= ArraySize(g_irgNavAreaList)) {
        return Invalid_Struct;
    }

    return ArrayGetCell(g_irgNavAreaList, iIndex);
}

public Struct:Native_GetAreaById(iPluginId, iArgc) {
    new iId = get_param(1);

    return NavAreaGrid_GetNavAreaById(iId);
}

public Struct:Native_GetAreaFromGrid(iPluginId, iArgc) {
    static Float:vecPos[3];
    get_array_f(1, vecPos, sizeof(vecPos));

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
public Struct:Native_FindFirstAreaInDirection(iPluginId, iArgc) {
    static Float:vecStart[3];
    get_array_f(1, vecStart, sizeof(vecStart));

    new NavDirType:iDir = NavDirType:get_param(2);
    new Float:flRange = get_param_f(3);
    new Float:flBeneathLimit = get_param_f(4);
    new pIgnoreEnt = get_param(5);

    static Float:vecClosePos[3];
    new Struct:sArea = FindFirstAreaInDirection(vecStart, iDir, flRange, flBeneathLimit, pIgnoreEnt, vecClosePos);
    set_array_f(6, vecClosePos, sizeof(vecClosePos));

    return sArea;
}

public bool:Native_IsAreaVisible(iPluginId, iArgc) {
    static Float:vecPos[3];
    get_array_f(1, vecPos, sizeof(vecPos));

    new Struct:sArea = Struct:get_param(2);

    return IsAreaVisible(vecPos, sArea);
}

public Struct:Native_Path_Find(iPluginId, iArgc) {
    static Float:vecStart[3];
    get_array_f(1, vecStart, sizeof(vecStart));

    static Float:vecGoal[3];
    get_array_f(2, vecGoal, sizeof(vecGoal));

    static szCbFunction[32];
    get_string(3, szCbFunction, charsmax(szCbFunction));

    new pIgnoreEnt = get_param(4);
    new iUserToken = get_param(5);

    static szCostFunction[32];
    get_string(6, szCostFunction, charsmax(szCostFunction));

    new iCostFuncId = equal(szCostFunction, NULL_STRING) ? -1 : get_func_id(szCostFunction, iPluginId);
    new iCbFuncId = equal(szCbFunction, NULL_STRING) ? -1 : get_func_id(szCbFunction, iPluginId);

    return NavAreaBuildPath(vecStart, vecGoal, iCbFuncId, iPluginId, pIgnoreEnt, iUserToken, iCostFuncId, iPluginId);
}

public NavAttributeType:Native_Area_GetAttributes(iPluginId, iArgc) {
    new Struct:sArea = Struct:get_param(1);

    return @NavArea_GetAttributes(sArea);
}

public Native_Area_GetCenter(iPluginId, iArgc) {
    new Struct:sArea = Struct:get_param(1);

    static Float:vecCenter[3];
    @NavArea_GetCenter(sArea, vecCenter);
    set_array_f(2, vecCenter, sizeof(vecCenter));
}

public Native_Path_FindTask_GetUserToken(iPluginId, iArgc) {
    new Struct:sTask = Struct:get_param(1);

    return StructGetCell(sTask, BuildPathTask_UserToken);
}

public bool:Native_Path_FindTask_Abort(iPluginId, iArgc) {
    new Struct:sTask = Struct:get_param(1);

    return NavAreaBuildPathAbortTask(sTask);
}

public Struct:Native_Path_FindTask_GetPath(iPluginId, iArgc) {
    new Struct:sTask = Struct:get_param(1);

    return StructGetCell(sTask, BuildPathTask_Path);
}

public bool:Native_Path_FindTask_IsSuccessed(iPluginId, iArgc) {
    new Struct:sTask = Struct:get_param(1);

    return StructGetCell(sTask, BuildPathTask_IsSuccessed);
}

public bool:Native_Path_FindTask_IsTerminated(iPluginId, iArgc) {
    new Struct:sTask = Struct:get_param(1);

    return StructGetCell(sTask, BuildPathTask_IsTerminated);
}

public Array:Native_Path_GetSegments(iPluginId, iArgc) {
    new Struct:sNavPath = Struct:get_param(1);

    return StructGetCell(sNavPath, NavPath_Segments);
}

public bool:Native_Path_IsValid(iPluginId, iArgc) {
    new Struct:sNavPath = Struct:get_param(1);

    return @NavPath_IsValid(sNavPath);
}

public Native_Path_Segment_GetPos(iPluginId, iArgc) {
    new Struct:sSegment = Struct:get_param(1);

    static Float:vecPos[3];
    StructGetArray(sSegment, PathSegment_Pos, vecPos, sizeof(vecPos));

    set_array_f(2, vecPos, sizeof(vecPos));
}

public Native_Area_GetId(iPluginId, iArgc) {
    new Struct:sArea = Struct:get_param(1);

    return @NavArea_GetId(sArea);
}

public bool:Native_Area_Contains(iPluginId, iArgc) {
    new Struct:sArea = Struct:get_param(1);

    static Float:vecPoint[3];
    get_array_f(2, vecPoint, sizeof(vecPoint));

    return @NavArea_Contains(sArea, vecPoint);
}

public bool:Native_Area_IsCoplanar(iPluginId, iArgc) {
    new Struct:sArea = Struct:get_param(1);
    new Struct:sOtherArea = Struct:get_param(2);

    return @NavArea_IsCoplanar(sArea, sOtherArea);
}

public Float:Native_Area_GetZ(iPluginId, iArgc) {
    new Struct:sArea = Struct:get_param(1);

    static Float:vecPos[3];
    get_array_f(2, vecPos, sizeof(vecPos));

    return @NavArea_GetZ(sArea, vecPos);
}

public Native_Area_GetClosestPointOnArea(iPluginId, iArgc) {
    new Struct:sArea = Struct:get_param(1);

    static Float:vecPos[3];
    get_array_f(2, vecPos, sizeof(vecPos));

    static Float:vecClose[3];
    get_array_f(3, vecClose, sizeof(vecClose));

    @NavArea_GetClosestPointOnArea(sArea, vecPos, vecClose);

    set_array_f(3, vecClose, sizeof(vecClose));
}

public Float:Native_Area_GetDistanceSquaredToPoint(iPluginId, iArgc) {
    new Struct:sArea = Struct:get_param(1);

    static Float:vecPoint[3];
    get_array_f(2, vecPoint, sizeof(vecPoint));

    return @NavArea_GetDistanceSquaredToPoint(sArea, vecPoint);
}

public Struct:Native_Area_GetRandomAdjacentArea(iPluginId, iArgc) {
    new Struct:sArea = Struct:get_param(1);
    new NavDirType:iDir = NavDirType:get_param(2);

    return @NavArea_GetRandomAdjacentArea(sArea, iDir);
}

public bool:Native_Area_IsEdge(iPluginId, iArgc) {
    new Struct:sArea = Struct:get_param(1);
    new NavDirType:iDir = NavDirType:get_param(2);

    return @NavArea_IsEdge(sArea, iDir);
}

public bool:Native_Area_IsConnected(iPluginId, iArgc) {
    new Struct:sArea = Struct:get_param(1);
    new Struct:sOtherArea = Struct:get_param(2);
    new NavDirType:iDir = NavDirType:get_param(3);

    return @NavArea_IsConnected(sArea, sOtherArea, iDir);
}

public Native_Area_GetCorner(iPluginId, iArgc) {
    new Struct:sArea = Struct:get_param(1);
    new NavCornerType:iCorner = NavCornerType:get_param(2);

    static Float:vecPos[3];
    get_array_f(3, vecPos, sizeof(vecPos));

    @NavArea_GetCorner(sArea, iCorner, vecPos);

    set_array_f(3, vecPos, sizeof(vecPos));
}

public NavDirType:Native_Area_ComputeDirection(iPluginId, iArgc) {
    new Struct:sArea = Struct:get_param(1);

    static Float:vecPoint[3];
    get_array_f(2, vecPoint, sizeof(vecPoint));

    return @NavArea_ComputeDirection(sArea, vecPoint);
}

public Native_Area_ComputePortal(iPluginId, iArgc) {
    new Struct:sArea = Struct:get_param(1);
    new Struct:sOtherArea = Struct:get_param(2);
    new NavDirType:iDir = NavDirType:get_param(3);

    static Float:vecCenter[3];
    static Float:flHalfWidth;

    @NavArea_ComputePortal(sArea, sOtherArea, iDir, vecCenter, flHalfWidth);

    set_array_f(4, vecCenter, sizeof(vecCenter));
    set_float_byref(5, flHalfWidth);
}

public bool:Native_Area_IsOverlapping(iPluginId, iArgc) {
    new Struct:sArea = Struct:get_param(1);
    new Struct:sOtherArea = Struct:get_param(2);

    return @NavArea_IsOverlapping(sArea, sOtherArea);
}

public bool:Native_Area_IsOverlappingPoint(iPluginId, iArgc) {
    new Struct:sArea = Struct:get_param(1);

    static Float:vecPoint[3];
    get_array_f(3, vecPoint, sizeof(vecPoint));

    return @NavArea_IsOverlappingPoint(sArea, vecPoint);
}

Struct:@NavArea_Create() {
    new Struct:this = StructCreate(NavArea);

    StructSetCell(this, NavArea_SpotEncounterList, ArrayCreate(_:SpotEncounter));
    StructSetCell(this, NavArea_Approach, ArrayCreate(_:ApproachInfo));
    StructSetCell(this, NavArea_OverlapList, ArrayCreate());

    for (new NavDirType:d = NORTH; d < NUM_DIRECTIONS; d++) {
        StructSetCell(this, NavArea_Connect, ArrayCreate(_:NavConnect), d);
    }

    return this;
}

@NavArea_Destroy(&Struct:this) {
    new Array:irgSpotEncounterList = StructGetCell(this, NavArea_SpotEncounterList);

    new iSpotEncounterListSize = ArraySize(irgSpotEncounterList);
    for (new i = 0; i < iSpotEncounterListSize; ++i) {
        new Array:irgSpotList = ArrayGetCell(irgSpotEncounterList, i, _:SpotEncounter_SpotList);
        ArrayDestroy(irgSpotList);
    }

    ArrayDestroy(irgSpotEncounterList);

    new Array:irgApproachList = StructGetCell(this, NavArea_Approach);
    ArrayDestroy(irgApproachList);

    new Array:irgOverlapList = StructGetCell(this, NavArea_OverlapList);
    ArrayDestroy(irgOverlapList);

    for (new NavDirType:d = NORTH; d < NUM_DIRECTIONS; d++) {
        new Array:irgConnectList = StructGetCell(this, NavArea_Connect, d);
        ArrayDestroy(irgConnectList);
    }

    StructDestroy(this);
}

@NavArea_Load(const &Struct:this, iFile, iVersion, bool:bDebug) {
    new Array:irgSpotEncounterList = StructGetCell(this, NavArea_SpotEncounterList);
    new Array:irgApproachList = StructGetCell(this, NavArea_Approach);

    // load ID
    new iId;
    FileReadInt32(iFile, iId);
    StructSetCell(this, NavArea_Id, iId);

    // update nextID to avoid collisions
    if (iId >= g_iNavAreaNextId) {
        g_iNavAreaNextId = iId + 1;
    }

    // load attribute flags
    new iAttributeFlags;
    FileReadUint8(iFile, iAttributeFlags);
    StructSetCell(this, NavArea_AttributeFlags, iAttributeFlags);

    // load extent of area
    new Float:rgExtent[Extent];
    fread_blocks(iFile, rgExtent[Extent_Lo], 3, BLOCK_INT);
    fread_blocks(iFile, rgExtent[Extent_Hi], 3, BLOCK_INT);

    StructSetArray(this, NavArea_Extent, rgExtent, Extent);

    new Float:vecCenter[3];
    for (new i = 0; i < 3; ++i) {
        vecCenter[i] = (rgExtent[Extent_Lo][i] + rgExtent[Extent_Hi][i]) / 2.0;
    }

    StructSetArray(this, NavArea_Center, vecCenter, sizeof(vecCenter));

    // load heights of implicit corners
    new Float:flNeZ;
    FileReadInt32(iFile, flNeZ);
    StructSetCell(this, NavArea_NeZ, flNeZ);

    new Float:flSwZ;
    FileReadInt32(iFile, flSwZ);
    StructSetCell(this, NavArea_SwZ, flSwZ);

    // load connections (IDs) to adjacent areas
    // in the enum order NORTH, EAST, SOUTH, WEST
    for (new d = 0; d < _:NUM_DIRECTIONS; d++) {
        new Array:irgConnectList = StructGetCell(this, NavArea_Connect, d);

        // load number of connections for this direction
        new iConnectionCount;
        FileReadInt32(iFile, iConnectionCount);

        for (new i = 0; i < iConnectionCount; i++) {
            new rgConnect[NavConnect];
            FileReadInt32(iFile, rgConnect[NavConnect_Id]);
            ArrayPushArray(irgConnectList, rgConnect[any:0]);
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

NavErrorType:@NavArea_PostLoadArea(const &Struct:this) {
    new NavErrorType:error = NAV_OK;

    // connect areas together
    for (new d = 0; d < _:NUM_DIRECTIONS; d++) {
        new Array:irgConnections = StructGetCell(this, NavArea_Connect, d);
        new iConnectionCount = ArraySize(irgConnections);

        for (new i = 0; i < iConnectionCount; ++i) {
            new iConnectId = ArrayGetCell(irgConnections, i, _:NavConnect_Id);
            new Struct:sArea = NavAreaGrid_GetNavAreaById(iConnectId);
            ArraySetCell(irgConnections, i, sArea, _:NavConnect_Area);

            if (iConnectId && sArea == Invalid_Struct) {
                log_amx("ERROR: Corrupt navigation data. Cannot connect Navigation Areas.^n");
                error = NAV_CORRUPT_DATA;
            }
        }
    }

    // resolve approach area IDs
    new Array:irgApproachList = StructGetCell(this, NavArea_Approach);
    new iApproachCount = ArraySize(irgApproachList);
    for (new a = 0; a < iApproachCount; a++) {
        new iApproachHereId = ArrayGetCell(irgApproachList, a, _:ApproachInfo_Here + _:NavConnect_Id);
        new Struct:sApproachHereArea = NavAreaGrid_GetNavAreaById(iApproachHereId);
        ArraySetCell(irgApproachList, a, sApproachHereArea, _:ApproachInfo_Here + _:NavConnect_Area);
        if (iApproachHereId && sApproachHereArea == Invalid_Struct) {
            log_amx("ERROR: Corrupt navigation data. Missing Approach Area (here).^n");
            error = NAV_CORRUPT_DATA;
        }

        new iApproachPrevId = ArrayGetCell(irgApproachList, a, _:ApproachInfo_Prev + _:NavConnect_Id);
        new Struct:sApproachPrevArea = NavAreaGrid_GetNavAreaById(iApproachPrevId);
        ArraySetCell(irgApproachList, a, sApproachPrevArea, _:ApproachInfo_Prev + _:NavConnect_Area);
        if (iApproachPrevId && sApproachPrevArea == Invalid_Struct) {
            log_amx("ERROR: Corrupt navigation data. Missing Approach Area (prev).^n");
            error = NAV_CORRUPT_DATA;
        }

        new iApproachNextId = ArrayGetCell(irgApproachList, a, _:ApproachInfo_Next + _:NavConnect_Id);
        new Struct:sApproachNextArea = NavAreaGrid_GetNavAreaById(iApproachNextId);
        ArraySetCell(irgApproachList, a, sApproachNextArea, _:ApproachInfo_Next + _:NavConnect_Area);
        if (iApproachNextId && sApproachNextArea == Invalid_Struct) {
            log_amx("ERROR: Corrupt navigation data. Missing Approach Area (next).^n");
            error = NAV_CORRUPT_DATA;
        }
    }

    // resolve spot encounter IDs
    new Array:irgSpotEncounterList = StructGetCell(this, NavArea_SpotEncounterList);
    new iSpotEncounterCount = ArraySize(irgSpotEncounterList);
    for (new e = 0; e < iSpotEncounterCount; e++) {
        new rgSpot[SpotEncounter];
        ArrayGetArray(irgSpotEncounterList, e, rgSpot[any:0]);

        rgSpot[SpotEncounter_From][NavConnect_Area] = NavAreaGrid_GetNavAreaById(rgSpot[SpotEncounter_From][NavConnect_Id]);
        if (rgSpot[SpotEncounter_From][NavConnect_Area] == Invalid_Struct) {
            log_amx("ERROR: Corrupt navigation data. Missing ^"from^" Navigation Area for Encounter Spot.^n");
            error = NAV_CORRUPT_DATA;
        }

        rgSpot[SpotEncounter_To][NavConnect_Area] = NavAreaGrid_GetNavAreaById(rgSpot[SpotEncounter_To][NavConnect_Id]);
        if (rgSpot[SpotEncounter_To][NavConnect_Area] == Invalid_Struct) {
            // log_amx("ERROR: Corrupt navigation data. Missing ^"to^" Navigation Area for Encounter Spot.^n");
            error = NAV_CORRUPT_DATA;
        }

        if (rgSpot[SpotEncounter_From][NavConnect_Area] != Invalid_Struct && rgSpot[SpotEncounter_To][NavConnect_Area] != Invalid_Struct) {
            // compute path
            new Float:flHalfWidth;
            @NavArea_ComputePortal(this, rgSpot[SpotEncounter_To][NavConnect_Area], rgSpot[SpotEncounter_ToDir], rgSpot[SpotEncounter_Path][Ray_To], flHalfWidth);
            @NavArea_ComputePortal(this, rgSpot[SpotEncounter_From][NavConnect_Area], rgSpot[SpotEncounter_FromDir], rgSpot[SpotEncounter_Path][Ray_From], flHalfWidth);

            new Float:eyeHeight = HalfHumanHeight;
            rgSpot[SpotEncounter_Path][Ray_From][2] = @NavArea_GetZ(rgSpot[SpotEncounter_From][NavConnect_Area], rgSpot[SpotEncounter_Path][Ray_From]) + eyeHeight;
            rgSpot[SpotEncounter_Path][Ray_To][2] = @NavArea_GetZ(rgSpot[SpotEncounter_To][NavConnect_Area], rgSpot[SpotEncounter_Path][Ray_To]) + eyeHeight;
        }

        ArraySetArray(irgSpotEncounterList, e, rgSpot[any:0]);
    }

    // build overlap list
    new Array:irgOverlapList = StructGetCell(this, NavArea_OverlapList);

    new iNavAreaListSize = ArraySize(g_irgNavAreaList);
    for (new i = 0; i < iNavAreaListSize; ++i) {
        new Struct:sArea = ArrayGetCell(g_irgNavAreaList, i);
        if (sArea == this) {
            continue;
        }

        if (@NavArea_IsOverlapping(this, sArea)) {
            ArrayPushCell(irgOverlapList, sArea);
        }
    }

    return error;
}

@NavArea_GetId(const &Struct:this) {
    return StructGetCell(this, NavArea_Id);
}

NavAttributeType:@NavArea_GetAttributes(const &Struct:this) {
    return StructGetCell(this, NavArea_AttributeFlags);
}

bool:@NavArea_IsClosed(const &Struct:this) {
    return @NavArea_IsMarked(this) && !@NavArea_IsOpen(this);
}

bool:@NavArea_IsOpen(const &Struct:this) {
    return StructGetCell(this, NavArea_OpenMarker) == g_iNavAreaMasterMarker;
}

@NavArea_Mark(const &Struct:this) {
    StructSetCell(this, NavArea_Marker, g_iNavAreaMasterMarker);
}

bool:@NavArea_IsMarked(const &Struct:this) {
    return StructGetCell(this, NavArea_Marker) == g_iNavAreaMasterMarker;
}

@NavArea_GetCenter(const &Struct:this, Float:vecCenter[]) {
    StructGetArray(this, NavArea_Center, vecCenter, 3);
}

@NavArea_SetTotalCost(const &Struct:this, Float:flTotalCost) {
    StructSetCell(this, NavArea_TotalCost, flTotalCost);
}

Float:@NavArea_GetTotalCost(const &Struct:this) {
    return StructGetCell(this, NavArea_TotalCost);
}

@NavArea_SetCostSoFar(const &Struct:this, Float:flTotalCost) {
    StructSetCell(this, NavArea_CostSoFar, flTotalCost);
}

Float:@NavArea_GetCostSoFar(const &Struct:this) {
    return StructGetCell(this, NavArea_CostSoFar);
}

@NavArea_AddToClosedList(const &Struct:this) {
    @NavArea_Mark(this);
}

@NavArea_RemoveFromClosedList(const &Struct:this) {
    // since "closed" is defined as visited (marked) and not on open list, do nothing
}

@NavArea_SetParent(const &Struct:this, Struct:parent, NavTraverseType:how) {
    StructSetCell(this, NavArea_Parent, parent);
    StructSetCell(this, NavArea_ParentHow, how);
}

Array:@NavArea_GetAdjacentList(const &Struct:this, NavDirType:iDir) {
    return StructGetCell(this, NavArea_Connect, iDir);
}

@NavArea_AddToOpenList(const &Struct:this) {
    // mark as being on open list for quick check
    StructSetCell(this, NavArea_OpenMarker, g_iNavAreaMasterMarker);

    // if list is empty, add and return
    if (g_sNavAreaOpenList == Invalid_Struct) {
        g_sNavAreaOpenList = this;
        StructSetCell(this, NavArea_PrevOpen, Invalid_Struct);
        StructSetCell(this, NavArea_NextOpen, Invalid_Struct);
        return;
    }

    // insert self in ascending cost order
    static Struct:sArea; sArea = Invalid_Struct;
    static Struct:last; last = Invalid_Struct;

    for (sArea = g_sNavAreaOpenList; sArea != Invalid_Struct; sArea = StructGetCell(sArea, NavArea_NextOpen)) {
        if (@NavArea_GetTotalCost(this) < @NavArea_GetTotalCost(sArea)) {
            break;
        }

        last = sArea;
    }

    if (sArea) {
        // insert before this area
        static Struct:sPrevOpenArea; sPrevOpenArea = StructGetCell(sArea, NavArea_PrevOpen);
        StructSetCell(this, NavArea_PrevOpen, sPrevOpenArea);
        if (sPrevOpenArea != Invalid_Struct) {
            StructSetCell(sPrevOpenArea, NavArea_NextOpen, this);
        } else {
            g_sNavAreaOpenList = this;
        }

        StructSetCell(this, NavArea_NextOpen, sArea);
        StructSetCell(sArea, NavArea_PrevOpen, this);
    } else {
        // append to end of list
        StructSetCell(last, NavArea_NextOpen, this);
        StructSetCell(this, NavArea_PrevOpen, last);
        StructSetCell(this, NavArea_NextOpen, Invalid_Struct);
    }
}

@NavArea_UpdateOnOpenList(const &Struct:this) {
    // since value can only decrease, bubble this area up from current spot
    static Struct:sPrevOpenArea; sPrevOpenArea = StructGetCell(this, NavArea_PrevOpen);
    static Float:flPrevTotalCost; flPrevTotalCost = @NavArea_GetTotalCost(sPrevOpenArea);

    while (StructGetCell(this, NavArea_PrevOpen) != Invalid_Struct && @NavArea_GetTotalCost(this) < flPrevTotalCost) {
        // swap position with predecessor
        static Struct:other; other = StructGetCell(this, NavArea_PrevOpen);
        static Struct:before; before = StructGetCell(other, NavArea_PrevOpen);
        static Struct:after; after = StructGetCell(this, NavArea_NextOpen);

        StructSetCell(this, NavArea_NextOpen, other);
        StructSetCell(this, NavArea_PrevOpen, before);

        StructSetCell(other, NavArea_PrevOpen, this);
        StructSetCell(other, NavArea_NextOpen, after);

        if (before != Invalid_Struct) {
            StructSetCell(before, NavArea_NextOpen, this);
        } else {
            g_sNavAreaOpenList = this;
        }

        if (after != Invalid_Struct) {
            StructSetCell(after, NavArea_PrevOpen, other);
        }
    }
}

@NavArea_RemoveFromOpenList(const &Struct:this) {
    static Struct:sPrevOpenArea; sPrevOpenArea = StructGetCell(this, NavArea_PrevOpen);
    static Struct:sNextOpenArea; sNextOpenArea = StructGetCell(this, NavArea_NextOpen);

    if (sPrevOpenArea != Invalid_Struct) {
        StructSetCell(sPrevOpenArea, NavArea_NextOpen, sNextOpenArea);
    } else {
        g_sNavAreaOpenList = sNextOpenArea;
    }

    if (sNextOpenArea != Invalid_Struct) {
        StructSetCell(sNextOpenArea, NavArea_PrevOpen, sPrevOpenArea);
    }

    // zero is an invalid marker
    StructSetCell(this, NavArea_OpenMarker, 0);
}

bool:@NavArea_IsOverlappingPoint(const &Struct:this, const Float:vecPoint[3]) {
    if (
        vecPoint[0] >= Float:StructGetCell(this, NavArea_Extent, _:Extent_Lo + 0) &&
        vecPoint[0] <= Float:StructGetCell(this, NavArea_Extent, _:Extent_Hi + 0) &&
        vecPoint[1] >= Float:StructGetCell(this, NavArea_Extent, _:Extent_Lo + 1) &&
        vecPoint[1] <= Float:StructGetCell(this, NavArea_Extent, _:Extent_Hi + 1)
    ) {
        return true;
    }

    return false;
}

// Return true if 'area' overlaps our 2D extents
bool:@NavArea_IsOverlapping(const &Struct:this, Struct:sArea) {
    if (
        Float:StructGetCell(sArea, NavArea_Extent, _:Extent_Lo + 0) < Float:StructGetCell(this, NavArea_Extent, _:Extent_Hi + 0) &&
        Float:StructGetCell(sArea, NavArea_Extent, _:Extent_Hi + 0) > Float:StructGetCell(this, NavArea_Extent, _:Extent_Lo + 0) &&
        Float:StructGetCell(sArea, NavArea_Extent, _:Extent_Lo + 1) < Float:StructGetCell(this, NavArea_Extent, _:Extent_Hi + 1) &&
        Float:StructGetCell(sArea, NavArea_Extent, _:Extent_Hi + 1) > Float:StructGetCell(this, NavArea_Extent, _:Extent_Lo + 1)
    ) {
        return true;
    }

    return false;
}

// Return true if given point is on or above this area, but no others
bool:@NavArea_Contains(const &Struct:this, const Float:vecPos[3]) {
    // check 2D overlap
    if (!@NavArea_IsOverlappingPoint(this, vecPos)) {
        return false;
    }

    // the point overlaps us, check that it is above us, but not above any areas that overlap us
    new Float:flOurZ = @NavArea_GetZ(this, vecPos);

    // if we are above this point, fail
    if (flOurZ > vecPos[2]) {
        return false;
    }

    new Array:irgOverlapList = StructGetCell(this, NavArea_OverlapList);
    new iOverlapListSize = ArraySize(irgOverlapList);

    for (new i = 0; i < iOverlapListSize; ++i) {
        new Struct:sOtherArea = ArrayGetCell(irgOverlapList, i);

        // skip self
        if (sOtherArea == this) {
            continue;
        }

        // check 2D overlap
        if (!@NavArea_IsOverlappingPoint(sOtherArea, vecPos)) {
            continue;
        }

        new Float:flTheirZ = @NavArea_GetZ(sOtherArea, vecPos);
        if (flTheirZ > vecPos[2]) {
            // they are above the point
            continue;
        }

        if (flTheirZ > flOurZ) {
            // we are below an area that is closer underneath the point
            return false;
        }
    }

    return true;
}

// Return true if this area and given area are approximately co-planar
bool:@NavArea_IsCoplanar(const &Struct:this, Struct:sArea) {
    static Float:u[3];
    static Float:v[3];

    // compute our unit surface normal
    u[0] = Float:StructGetCell(this, NavArea_Extent, _:Extent_Hi + 0) - Float:StructGetCell(this, NavArea_Extent, _:Extent_Lo + 0);
    u[1] = 0.0;
    u[2] = Float:StructGetCell(this, NavArea_NeZ) - Float:StructGetCell(this, NavArea_Extent, _:Extent_Lo + 2);

    v[0] = 0.0;
    v[1] = Float:StructGetCell(this, NavArea_Extent, _:Extent_Hi + 1) - Float:StructGetCell(this, NavArea_Extent, _:Extent_Lo + 1);
    v[2] = Float:StructGetCell(this, NavArea_SwZ) - Float:StructGetCell(this, NavArea_Extent, _:Extent_Lo + 2);

    static Float:vecNormal[3];
    xs_vec_cross(u, v, vecNormal);
    NormalizeInPlace(vecNormal, vecNormal);

    // compute their unit surface normal
    u[0] = Float:StructGetCell(sArea, NavArea_Extent, _:Extent_Hi + 0) - Float:StructGetCell(sArea, NavArea_Extent, _:Extent_Lo + 0);
    u[1] = 0.0;
    u[2] = Float:StructGetCell(sArea, NavArea_NeZ) - StructGetCell(sArea, NavArea_Extent, _:Extent_Lo + 2);

    v[0] = 0.0;
    v[1] = Float:StructGetCell(sArea, NavArea_Extent, _:Extent_Hi + 1) - Float:StructGetCell(sArea, NavArea_Extent, _:Extent_Lo + 1);
    v[2] = Float:StructGetCell(sArea, NavArea_SwZ) - Float:StructGetCell(sArea, NavArea_Extent, _:Extent_Lo + 2);

    static Float:vecOtherNormal[3];
    xs_vec_cross(u, v, vecOtherNormal);
    NormalizeInPlace(vecOtherNormal, vecOtherNormal);

    // can only merge areas that are nearly planar, to ensure areas do not differ from underlying geometry much
    new Float:flTolerance = 0.99;
    if (xs_vec_dot(vecNormal, vecOtherNormal) > flTolerance) {
        return true;
    }

    return false;
}

// Return Z of area at (x,y) of 'vecPos'
// Trilinear interpolation of Z values at quad edges.
// NOTE: vecPos[2] is not used.
Float:@NavArea_GetZ(const &Struct:this, const Float:vecPos[]) {
    static Float:dx; dx = Float:StructGetCell(this, NavArea_Extent, _:Extent_Hi + 0) - Float:StructGetCell(this, NavArea_Extent, _:Extent_Lo + 0);
    static Float:dy; dy = Float:StructGetCell(this, NavArea_Extent, _:Extent_Hi + 1) - Float:StructGetCell(this, NavArea_Extent, _:Extent_Lo + 1);

    static Float:flNeZ; flNeZ = StructGetCell(this, NavArea_NeZ);
    static Float:flSwZ; flSwZ = StructGetCell(this, NavArea_SwZ);

    // guard against division by zero due to degenerate areas
    if (dx == 0.0 || dy == 0.0) {
        return flNeZ;
    }

    static Float:u; u = floatclamp((vecPos[0] - Float:StructGetCell(this, NavArea_Extent, _:Extent_Lo + 0)) / dx, 0.0, 1.0);
    static Float:v; v = floatclamp((vecPos[1] - Float:StructGetCell(this, NavArea_Extent, _:Extent_Lo + 1)) / dy, 0.0, 1.0);

    static Float:northZ; northZ = Float:StructGetCell(this, NavArea_Extent, _:Extent_Lo + 2) + u * (flNeZ - Float:StructGetCell(this, NavArea_Extent, _:Extent_Lo + 2));
    static Float:southZ; southZ = flSwZ + u * (Float:StructGetCell(this, NavArea_Extent, _:Extent_Hi + 2) - flSwZ);

    return northZ + v * (southZ - northZ);
}

// new Float:@NavArea_GetZ(const &Struct:this, new Float:x, new Float:y) {
//     static Float:vecPos[3](x, y, 0.0);
//     return GetZ(&vecPos);
// }

// Return closest point to 'vecPos' on 'area'.
// Returned point is in 'vecClose'.
@NavArea_GetClosestPointOnArea(const &Struct:this, const Float:vecPos[3], Float:vecClose[3]) {
    static rgExtent[Extent];
    StructGetArray(this, NavArea_Extent, rgExtent, sizeof(rgExtent));

    if (vecPos[0] < rgExtent[Extent_Lo][0]) {
        if (vecPos[1] < rgExtent[Extent_Lo][1]) {
            // position is north-west of area
            xs_vec_copy(rgExtent[Extent_Lo], vecClose);
        } else if (vecPos[1] > rgExtent[Extent_Hi][1]) {
            // position is south-west of area
            vecClose[0] = rgExtent[Extent_Lo][0];
            vecClose[1] = rgExtent[Extent_Hi][1];
        } else {
            // position is west of area
            vecClose[0] = rgExtent[Extent_Lo][0];
            vecClose[1] = vecPos[1];
        }
    } else if (vecPos[0] > rgExtent[Extent_Hi][0]) {
        if (vecPos[1] < rgExtent[Extent_Lo][1]) {
            // position is north-east of area
            vecClose[0] = rgExtent[Extent_Hi][0];
            vecClose[1] = rgExtent[Extent_Lo][1];
        } else if (vecPos[1] > rgExtent[Extent_Hi][1]) {
            // position is south-east of area
            xs_vec_copy(rgExtent[Extent_Hi], vecClose);
        } else {
            // position is east of area
            vecClose[0] = rgExtent[Extent_Hi][0];
            vecClose[1] = vecPos[1];
        }
    } else if (vecPos[1] < rgExtent[Extent_Lo][1]) {
        // position is north of area
        vecClose[0] = vecPos[0];
        vecClose[1] = rgExtent[Extent_Lo][1];
    } else if (vecPos[1] > rgExtent[Extent_Hi][1]) {
        // position is south of area
        vecClose[0] = vecPos[0];
        vecClose[1] = rgExtent[Extent_Hi][1];
    } else {
        // position is inside of area - it is the 'closest point' to itself
        xs_vec_copy(vecPos, vecClose);
    }

    vecClose[2] = @NavArea_GetZ(this, vecClose);
}

// Return shortest distance squared between point and this area
Float:@NavArea_GetDistanceSquaredToPoint(const &Struct:this, const Float:vecPos[3]) {
    static rgExtent[Extent];
    StructGetArray(this, NavArea_Extent, rgExtent, sizeof(rgExtent));

    if (vecPos[0] < rgExtent[Extent_Lo][0]) {
        if (vecPos[1] < rgExtent[Extent_Lo][1]) {
            // position is north-west of area
            return floatpower(xs_vec_distance(rgExtent[Extent_Lo], vecPos), 2.0);
        } else if (vecPos[1] > rgExtent[Extent_Hi][1]) {
            new Float:flSwZ = StructGetCell(this, NavArea_SwZ);

            // position is south-west of area
            static Float:d[3];
            d[0] = rgExtent[Extent_Lo][0] - vecPos[0];
            d[1] = rgExtent[Extent_Hi][1] - vecPos[1];
            d[2] = flSwZ - vecPos[2];
            return floatpower(xs_vec_len(d), 2.0);
        } else {
            // position is west of area
            new Float:d = rgExtent[Extent_Lo][0] - vecPos[0];
            return d * d;
        }
    } else if (vecPos[0] > rgExtent[Extent_Hi][0]) {
        if (vecPos[1] < rgExtent[Extent_Lo][1]) {
            new Float:flNeZ = StructGetCell(this, NavArea_NeZ);

            // position is north-east of area
            static Float:d[3];
            d[0] = rgExtent[Extent_Hi][0] - vecPos[0];
            d[1] = rgExtent[Extent_Lo][1] - vecPos[1];
            d[2] = flNeZ - vecPos[2];
            return floatpower(xs_vec_len(d), 2.0);
        } else if (vecPos[1] > rgExtent[Extent_Hi][1]) {
            // position is south-east of area
            return floatpower(xs_vec_distance(rgExtent[Extent_Hi], vecPos), 2.0);
        } else {
            // position is east of area
            new Float:d = vecPos[2] - rgExtent[Extent_Hi][0];
            return d * d;
        }
    } else if (vecPos[1] < rgExtent[Extent_Lo][1]) {
        // position is north of area
        new Float:d = rgExtent[Extent_Lo][1] - vecPos[1];
        return d * d;
    } else if (vecPos[1] > rgExtent[Extent_Hi][1]) {
        // position is south of area
        new Float:d = vecPos[1] - rgExtent[Extent_Hi][1];
        return d * d;
    } else { // position is inside of 2D extent of area - find delta Z
        new Float:z = @NavArea_GetZ(this, vecPos);
        new Float:d = z - vecPos[2];
        return d * d;
    }
}

Struct:@NavArea_GetRandomAdjacentArea(const &Struct:this, NavDirType:iDir) {
    new Array:irgConnections = StructGetCell(this, NavArea_Connect, iDir);

    new iConnectionCount = ArraySize(irgConnections);
    if (!iConnectionCount) {
        return Invalid_Struct;
    }

    new iWhich = random(iConnectionCount);

    return ArrayGetCell(irgConnections, iWhich, _:NavConnect_Area);
}

// Compute "portal" between to adjacent areas.
// Return center of portal opening, and half-width defining sides of portal from center.
// NOTE: center[2] is unset.
@NavArea_ComputePortal(const &Struct:this, Struct:sArea, NavDirType:iDir, Float:vecCenter[], &Float:flHalfWidth) {
    if (iDir == NORTH || iDir == SOUTH) {
        if (iDir == NORTH) {
            vecCenter[1] = Float:StructGetCell(this, NavArea_Extent, _:Extent_Lo + 1);
        }
        else {
            vecCenter[1] = Float:StructGetCell(this, NavArea_Extent, _:Extent_Hi + 1);
        }

        new Float:flLeft = floatmax(
            Float:StructGetCell(this, NavArea_Extent, _:Extent_Lo + 0),
            Float:StructGetCell(sArea, NavArea_Extent, _:Extent_Lo + 0)
        );

        new Float:flRight = floatmin(
            Float:StructGetCell(this, NavArea_Extent, _:Extent_Hi + 0),
            Float:StructGetCell(sArea, NavArea_Extent, _:Extent_Hi + 0)
        );

        // clamp to our extent in case areas are disjoint
        if (flLeft < Float:StructGetCell(this, NavArea_Extent, _:Extent_Lo + 0)) {
            flLeft = Float:StructGetCell(this, NavArea_Extent, _:Extent_Lo + 0);
        } else if (flLeft > Float:StructGetCell(this, NavArea_Extent, _:Extent_Hi + 0)) {
            flLeft = Float:StructGetCell(this, NavArea_Extent, _:Extent_Hi + 0);
        }

        if (flRight < Float:StructGetCell(this, NavArea_Extent, _:Extent_Lo + 0)) {
            flRight = Float:StructGetCell(this, NavArea_Extent, _:Extent_Lo + 0);
        } else if (flRight > Float:StructGetCell(this, NavArea_Extent, _:Extent_Hi + 0)) {
            flRight = Float:StructGetCell(this, NavArea_Extent, _:Extent_Hi + 0);
        }

        vecCenter[0] = (flLeft + flRight) / 2.0;
        flHalfWidth = (flRight - flLeft) / 2.0;
    } else { // EAST or WEST
        if (iDir == WEST) {
            vecCenter[0] = Float:StructGetCell(this, NavArea_Extent, _:Extent_Lo + 0);
        } else {
            vecCenter[0] = Float:StructGetCell(this, NavArea_Extent, _:Extent_Hi + 0);
        }

        new Float:flTop = floatmax(
            Float:StructGetCell(this, NavArea_Extent, _:Extent_Lo + 1),
            Float:StructGetCell(sArea, NavArea_Extent, _:Extent_Lo + 1)
        );

        new Float:flBottom = floatmin(
            Float:StructGetCell(this, NavArea_Extent, _:Extent_Hi + 1),
            Float:StructGetCell(sArea, NavArea_Extent, _:Extent_Hi + 1)
        );

        // clamp to our extent in case areas are disjoint
        if (flTop < Float:StructGetCell(this, NavArea_Extent, _:Extent_Lo + 1)) {
            flTop = Float:StructGetCell(this, NavArea_Extent, _:Extent_Lo + 1);
        } else if (flTop > Float:StructGetCell(this, NavArea_Extent, _:Extent_Hi + 1)) {
            flTop = Float:StructGetCell(this, NavArea_Extent, _:Extent_Hi + 1);
        }

        if (flBottom < Float:StructGetCell(this, NavArea_Extent, _:Extent_Lo + 1)) {
            flBottom = Float:StructGetCell(this, NavArea_Extent, _:Extent_Lo + 1);
        } else if (flBottom > Float:StructGetCell(this, NavArea_Extent, _:Extent_Hi + 1)) {
            flBottom = Float:StructGetCell(this, NavArea_Extent, _:Extent_Hi + 1);
        }

        vecCenter[1] = (flTop + flBottom) / 2.0;
        flHalfWidth = (flBottom - flTop) / 2.0;
    }
}

// Compute closest point within the "portal" between to adjacent areas.
@NavArea_ComputeClosestPointInPortal(const &Struct:this, Struct:sArea, NavDirType:iDir, const Float:vecFromPos[3], Float:vecClosePos[3]) {
    new Float:flMargin = GenerationStepSize / 2.0;

    if (iDir == NORTH || iDir == SOUTH) {
        if (iDir == NORTH) {
            vecClosePos[1] = Float:StructGetCell(this, NavArea_Extent, _:Extent_Lo + 1);
         } else {
            vecClosePos[1] = Float:StructGetCell(this, NavArea_Extent, _:Extent_Hi + 1);
        }

        new Float:flLeft = floatmax(
            Float:StructGetCell(this, NavArea_Extent, _:Extent_Lo + 0),
            Float:StructGetCell(sArea, NavArea_Extent, _:Extent_Lo + 0)
        );

        new Float:flRight = floatmin(
            Float:StructGetCell(this, NavArea_Extent, _:Extent_Hi + 0),
            Float:StructGetCell(sArea, NavArea_Extent, _:Extent_Hi + 0)
        );

        // clamp to our extent in case areas are disjoint
        if (flLeft < Float:StructGetCell(this, NavArea_Extent, _:Extent_Lo + 0)) {
            flLeft = Float:StructGetCell(this, NavArea_Extent, _:Extent_Lo + 0);
        } else if (flLeft > Float:StructGetCell(this, NavArea_Extent, _:Extent_Hi + 0)) {
            flLeft = Float:StructGetCell(this, NavArea_Extent, _:Extent_Hi + 0);
        }

        if (flRight < Float:StructGetCell(this, NavArea_Extent, _:Extent_Lo + 0)) {
            flRight = Float:StructGetCell(this, NavArea_Extent, _:Extent_Lo + 0);
        } else if (flRight > Float:StructGetCell(this, NavArea_Extent, _:Extent_Hi + 0)) {
            flRight = Float:StructGetCell(this, NavArea_Extent, _:Extent_Hi + 0);
        }

        // keep margin if against edge
        new Float:flLeftMargin = (@NavArea_IsEdge(sArea, WEST)) ? (flLeft + flMargin) : flLeft;
        new Float:flRightMargin = (@NavArea_IsEdge(sArea, EAST)) ? (flRight - flMargin) : flRight;

        // limit x to within portal
        if (vecFromPos[0] < flLeftMargin) {
            vecClosePos[0] = flLeftMargin;
        } else if (vecFromPos[0] > flRightMargin) {
            vecClosePos[0] = flRightMargin;
        } else {
            vecClosePos[0] = vecFromPos[0];
        }

    } else {    // EAST or WEST
        if (iDir == WEST) {
            vecClosePos[0] = Float:StructGetCell(this, NavArea_Extent, _:Extent_Lo + 0);
        } else {
            vecClosePos[0] = Float:StructGetCell(this, NavArea_Extent, _:Extent_Hi + 0);
        }

        new Float:flTop = floatmax(
            Float:StructGetCell(this, NavArea_Extent, _:Extent_Lo + 1),
            Float:StructGetCell(sArea, NavArea_Extent, _:Extent_Lo + 1)
        );

        new Float:flBottom = floatmin(
            Float:StructGetCell(this, NavArea_Extent, _:Extent_Hi + 1),
            Float:StructGetCell(sArea, NavArea_Extent, _:Extent_Hi + 1)
        );

        // clamp to our extent in case areas are disjoint
        if (flTop < Float:StructGetCell(this, NavArea_Extent, _:Extent_Lo + 1)) {
            flTop = Float:StructGetCell(this, NavArea_Extent, _:Extent_Lo + 1);
        } else if (flTop > Float:StructGetCell(this, NavArea_Extent, _:Extent_Hi + 1)) {
            flTop = Float:StructGetCell(this, NavArea_Extent, _:Extent_Hi + 1);
        }

        if (flBottom < Float:StructGetCell(this, NavArea_Extent, _:Extent_Lo + 1)) {
            flBottom = Float:StructGetCell(this, NavArea_Extent, _:Extent_Lo + 1);
        } else if (flBottom > Float:StructGetCell(this, NavArea_Extent, _:Extent_Hi + 1)) {
            flBottom = Float:StructGetCell(this, NavArea_Extent, _:Extent_Hi + 1);
        }

        // keep margin if against edge
        new Float:flTopMargin = (@NavArea_IsEdge(sArea, NORTH)) ? (flTop + flMargin) : flTop;
        new Float:flBottomMargin = (@NavArea_IsEdge(sArea, SOUTH)) ? (flBottom - flMargin) : flBottom;

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
bool:@NavArea_IsEdge(const &Struct:this, NavDirType:iDir) {
    static Array:irgConnections; irgConnections = StructGetCell(this, NavArea_Connect, iDir);
    static iConnectionCount; iConnectionCount = ArraySize(irgConnections);

    for (new i = 0; i < iConnectionCount; ++i) {
        static Struct:sConnectArea; sConnectArea = ArrayGetCell(irgConnections, i, _:NavConnect_Area);
        if (@NavArea_IsConnected(sConnectArea, this, OppositeDirection(iDir))) {
            return false;
        }
    }

    return true;
}

bool:@NavArea_IsConnected(const &Struct:this, Struct:sArea, NavDirType:iDir) {
    // we are connected to ourself
    if (sArea == this) {
        return true;
    }

    if (iDir == NUM_DIRECTIONS) {
        // search all directions
        for (new iDir = 0; iDir < _:NUM_DIRECTIONS; iDir++) {
            if (@NavArea_IsConnected(this, sArea, NavDirType:iDir)) {
                return true;
            }
        }
    } else {
        // check specific direction
        static Array:irgConnections; irgConnections = StructGetCell(this, NavArea_Connect, iDir);
        static iConnectionCount; iConnectionCount = ArraySize(irgConnections);

        for (new i = 0; i < iConnectionCount; ++i) {
            if (sArea == ArrayGetCell(irgConnections, i, _:NavConnect_Area)) {
                return true;
            }
        }
    }

    return false;
}

// Return direction from this area to the given point
NavDirType:@NavArea_ComputeDirection(const &Struct:this, const Float:vecPoint[3]) {
    if (vecPoint[0] >= Float:StructGetCell(this, NavArea_Extent, _:Extent_Lo + 0) && vecPoint[0] <= Float:StructGetCell(this, NavArea_Extent, _:Extent_Hi + 0)) {
        if (vecPoint[1] < Float:StructGetCell(this, NavArea_Extent, _:Extent_Lo + 1)) {
            return NORTH;
        } else if (vecPoint[1] > Float:StructGetCell(this, NavArea_Extent, _:Extent_Hi + 1)) {
            return SOUTH;
        }
    } else if (vecPoint[1] >= Float:StructGetCell(this, NavArea_Extent, _:Extent_Lo + 1) && vecPoint[1] <= Float:StructGetCell(this, NavArea_Extent, _:Extent_Hi + 1)) {
        if (vecPoint[0] < Float:StructGetCell(this, NavArea_Extent, _:Extent_Lo + 0)) {
            return WEST;
        } else if (vecPoint[0] > Float:StructGetCell(this, NavArea_Extent, _:Extent_Hi + 0)) {
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

@NavArea_GetCorner(const &Struct:this, NavCornerType:corner, Float:vecOut[3]) {
    static rgExtent[Extent];
    StructGetArray(this, NavArea_Extent, rgExtent, sizeof(rgExtent));

    switch (corner) {
        case NORTH_WEST: {
            xs_vec_copy(rgExtent[Extent_Lo], vecOut);
            return;
        }
        case NORTH_EAST: {
            vecOut[0] = rgExtent[Extent_Hi][0];
            vecOut[1] = rgExtent[Extent_Lo][1];
            vecOut[2] = StructGetCell(this, NavArea_NeZ);
            return;
        }
        case SOUTH_WEST: {
            vecOut[0] = rgExtent[Extent_Lo][0];
            vecOut[1] = rgExtent[Extent_Hi][1];
            vecOut[2] = StructGetCell(this, NavArea_SwZ);
            return;
        }
        case SOUTH_EAST: {
            xs_vec_copy(rgExtent[Extent_Hi], vecOut);
            return;
        }
    }
}

Struct:@NavPath_Create() {
    new Struct:this = StructCreate(NavPath);
    StructSetCell(this, NavPath_Segments, ArrayCreate());
    return this;
}

@NavPath_Destroy(&Struct:this) {
    new Array:irgSegments = StructGetCell(this, NavPath_Segments);
    new iPathSize = ArraySize(irgSegments);

    for (new i = 0; i < iPathSize; ++i) {
        new Struct:sSegment = ArrayGetCell(irgSegments, i);
        StructDestroy(sSegment);
    }

    ArrayDestroy(irgSegments);
    StructDestroy(this);
}

// Build trivial path when start and goal are in the same nav area
bool:@NavPath_BuildTrivialPath(const &Struct:this, const Float:vecStart[3], const Float:vecGoal[3]) {
    new Array:irgSegments = StructGetCell(this, NavPath_Segments);
    ArrayClear(irgSegments);

    StructSetCell(this, NavPath_SegmentCount, 0);

    new Struct:sStartArea = NavAreaGrid_GetNearestNavArea(vecStart, false, nullptr);
    if (sStartArea == Invalid_Struct) {
        return false;
    }

    new Struct:sGoalArea = NavAreaGrid_GetNearestNavArea(vecGoal, false, nullptr);
    if (sGoalArea == Invalid_Struct) {
        return false;
    }

    new Struct:sStartSegment = @PathSegment_Create();
    StructSetCell(sStartSegment, PathSegment_Area, sStartArea);
    StructSetArray(sStartSegment, PathSegment_Pos, vecStart, sizeof(vecStart));
    StructSetCell(sStartSegment, PathSegment_Pos, @NavArea_GetZ(sStartArea, vecStart), 2);
    StructSetCell(sStartSegment, PathSegment_How, NUM_TRAVERSE_TYPES);
    @NavPath_PushSegment(this, sStartSegment);

    new Struct:sGoalSegment = @PathSegment_Create();
    StructSetCell(sGoalSegment, PathSegment_Area, sGoalArea);
    StructSetArray(sGoalSegment, PathSegment_Pos, vecGoal, sizeof(vecGoal));
    StructSetCell(sGoalSegment, PathSegment_Pos, @NavArea_GetZ(sGoalArea, vecGoal), 2);
    StructSetCell(sGoalSegment, PathSegment_How, NUM_TRAVERSE_TYPES);
    @NavPath_PushSegment(this, sGoalSegment);

    return true;
}

@NavPath_PushSegment(const &Struct:this, Struct:sSegment) {
    ArrayPushCell(StructGetCell(this, NavPath_Segments), sSegment);
    StructSetCell(this, NavPath_SegmentCount, StructGetCell(this, NavPath_SegmentCount) + 1);
}

@NavPath_ComputePathPositions(const &Struct:this) {
    if (!StructGetCell(this, NavPath_SegmentCount)) {
        return false;
    }

    static Array:irgSegments; irgSegments = StructGetCell(this, NavPath_Segments);
    static Struct:startSegment; startSegment = ArrayGetCell(irgSegments, 0);
    static Struct:sStartArea; sStartArea = StructGetCell(startSegment, PathSegment_Area);

    // start in first area's center
    static Float:vecStart[3];
    @NavArea_GetCenter(sStartArea, vecStart);

    StructSetArray(startSegment, PathSegment_Pos, vecStart, sizeof(vecStart));
    StructSetCell(startSegment, PathSegment_How, NUM_TRAVERSE_TYPES);

    for (new i = 1; i < StructGetCell(this, NavPath_SegmentCount); i++) {
        static Struct:sFromSegment; sFromSegment = ArrayGetCell(irgSegments, i - 1);
        static Struct:sFromArea; sFromArea = StructGetCell(sFromSegment, PathSegment_Area);
        static Struct:sToSegment; sToSegment = ArrayGetCell(irgSegments, i);
        static Struct:sToArea; sToArea = StructGetCell(sToSegment, PathSegment_Area);

        static Float:vecFromPos[3];
        StructGetArray(sFromSegment, PathSegment_Pos, vecFromPos, sizeof(vecFromPos));

        static Float:vecToPos[3];
        StructGetArray(sToSegment, PathSegment_Pos, vecToPos, sizeof(vecToPos));

        // walk along the floor to the next area
        static NavTraverseType:toHow; toHow = StructGetCell(sToSegment, PathSegment_How);
        if (toHow <= GO_WEST) {
            // compute next point, keeping path as straight as possible
            @NavArea_ComputeClosestPointInPortal(sFromArea, sToArea, NavDirType:toHow, vecFromPos, vecToPos);

            // move goal position into the goal area a bit
            // how far to "step into" an area - must be less than min area size
            static const Float:flStepInDist = 5.0;
            AddDirectionVector(vecToPos, NavDirType:toHow, flStepInDist);

            // we need to walk out of "from" area, so keep Z where we can reach it
            StructSetCell(sToSegment, PathSegment_Pos, @NavArea_GetZ(sFromArea, vecToPos), 2);

            // if this is a "jump down" connection, we must insert an additional point on the path
            if (!@NavArea_IsConnected(sToArea, sFromArea, NUM_DIRECTIONS)) {
                // this is a "jump down" link
                // compute direction of path just prior to "jump down"
                static Float:flDir[2];
                DirectionToVector2D(NavDirType:toHow, flDir);

                // shift top of "jump down" out a bit to "get over the ledge"
                static const Float:flPushDist = 25.0;
                StructSetCell(sToSegment, PathSegment_Pos, Float:StructGetCell(sToSegment, PathSegment_Pos, 0) + (flPushDist * flDir[0]), 0);
                StructSetCell(sToSegment, PathSegment_Pos, Float:StructGetCell(sToSegment, PathSegment_Pos, 1) + (flPushDist * flDir[1]), 1);

                // insert a duplicate node to represent the bottom of the fall
                if (StructGetCell(this, NavPath_SegmentCount) < MAX_PATH_SEGMENTS - 1) {
                    static Struct:sOldSegment; sOldSegment = ArrayGetCell(irgSegments, i);
                    static Struct:sSegment; sSegment = StructClone(sOldSegment);
                    StructSetCell(sSegment, PathSegment_Pos, vecToPos[0] + flPushDist * flDir[0], 0);
                    StructSetCell(sSegment, PathSegment_Pos, vecToPos[1] + flPushDist * flDir[1], 1);

                    // put this one at the bottom of the fall
                    static Float:vecPos[3];
                    StructGetArray(sSegment, PathSegment_Pos, vecPos, sizeof(vecPos));
                    StructSetCell(sSegment, PathSegment_Pos, @NavArea_GetZ(sToArea, vecPos), 2);

                    ArrayInsertCellAfter(irgSegments, i, sSegment);

                    // path is one node longer
                    StructSetCell(this, NavPath_SegmentCount, StructGetCell(this, NavPath_SegmentCount) + 1);

                    // move index ahead into the new node we just duplicated
                    i++;
                }
            }
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

@NavPath_GetEndpoint(const &Struct:this, Float:vecEndpoint[]) {
    static iSegmentCount; iSegmentCount = StructGetCell(this, NavPath_SegmentCount);
    static Array:irgSegments; irgSegments = StructGetCell(this, NavPath_Segments);
    static Struct:sSegment; sSegment = ArrayGetCell(irgSegments, iSegmentCount - 1);
    StructGetArray(sSegment, PathSegment_Pos, vecEndpoint, 3);
}

// Return true if position is at the end of the path
bool:@NavPath_IsAtEnd(const &Struct:this, const Float:vecPos[3]) {
    if (!@NavPath_IsValid(this)) {
        return false;
    }

    static Float:vecEndpoint[3];
    @NavPath_GetEndpoint(this, vecEndpoint);
    return xs_vec_distance(vecPos, vecEndpoint) < 20.0;
}

// Return point a given distance along the path - if distance is out of path bounds, point is clamped to start/end
// TODO: Be careful of returning "positions" along one-way drops, ladders, etc.
bool:@NavPath_GetPointAlongPath(const &Struct:this, Float:flDistAlong, Float:vecPointOnPath[3]) {
    if (!@NavPath_IsValid(this) || !xs_vec_len(vecPointOnPath)) {
        return false;
    }

    static Array:irgSegments; irgSegments = StructGetCell(this, NavPath_Segments);

    if (flDistAlong <= 0.0) {
        static Struct:sFirstSegment; sFirstSegment = ArrayGetCell(irgSegments, 0);
        StructGetArray(sFirstSegment, PathSegment_Pos, vecPointOnPath, 3);
        return true;
    }

    static Float:flLengthSoFar; flLengthSoFar = 0.0;
    static Float:flSegmentLength;
    static Float:vecDir[3];

    for (new i = 1; i < @NavPath_GetSegmentCount(this); i++) {
        static Float:vecFrom[3];
        static Struct:sFromSegment; sFromSegment = ArrayGetCell(irgSegments, i - 1);
        StructGetArray(sFromSegment, PathSegment_Pos, vecFrom, 3);

        static Float:vecTo[3];
        static Struct:sToSegment; sToSegment = ArrayGetCell(irgSegments, i);
        StructGetArray(sToSegment, PathSegment_Pos, vecTo, 3);

        xs_vec_sub(vecTo, vecFrom, vecDir);

        flSegmentLength = xs_vec_len(vecDir);

        if (flSegmentLength + flLengthSoFar >= flDistAlong) {
            // desired point is on this segment of the path
            static Float:delta; delta = flDistAlong - flLengthSoFar;
            static Float:t; t = delta / flSegmentLength;

            for (new j = 0; j < 3; ++j) {
                vecPointOnPath[j] = vecTo[j] + t * vecDir[j];
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
bool:@NavPath_FindClosestPointOnPath(const &Struct:this, const Float:vecWorldPos[3], iStartIndex, iEndIndex, Float:vecClose[3]) {
    if (!@NavPath_IsValid(this) || !vecClose) {
        return false;
    }

    static Float:vecAlong[3];
    static Float:vecToWorldPos[3];
    static Float:vecPos[3];
    static Float:flLength;
    static Float:flCloseLength;
    static Float:flCloseDistSq = 9999999999.9;
    static Float:flDistSq;

    new Array:irgSegments = StructGetCell(this, NavPath_Segments);

    for (new i = iStartIndex; i <= iEndIndex; i++) {
        static Float:vecFrom[3];
        static Struct:sFromSegment; sFromSegment = ArrayGetCell(irgSegments, i - 1);
        StructGetArray(sFromSegment, PathSegment_Pos, vecFrom, 3);

        static Float:vecTo[3];
        static Struct:sToSegment; sToSegment = ArrayGetCell(irgSegments, i);
        StructGetArray(sToSegment, PathSegment_Pos, vecTo, 3);

        // compute ray along this path segment
        xs_vec_sub(vecTo, vecFrom, vecAlong);

        // make it a unit vector along the path
        flLength = NormalizeInPlace(vecAlong, vecAlong);

        // compute vector from start of segment to our point
        xs_vec_sub(vecWorldPos, vecFrom, vecToWorldPos);

        // find distance of closest point on ray
        flCloseLength = xs_vec_dot(vecToWorldPos, vecAlong);

        // constrain point to be on path segment
        if (flCloseLength <= 0.0) {
            xs_vec_copy(vecFrom, vecPos);
        } else if (flCloseLength >= flLength) {
            xs_vec_copy(vecFrom, vecTo);
        } else {
            xs_vec_add_scaled(vecFrom, vecAlong, flCloseLength, vecPos);
        }

        flDistSq = floatpower(xs_vec_distance(vecPos, vecWorldPos), 2.0);

        // keep the closest point so far
        if (flDistSq < flCloseDistSq) {
            flCloseDistSq = flDistSq;
            xs_vec_copy(vecPos, vecClose);
        }
    }

    return true;
}

Struct:@BuildPathTask_Create() {
    new Struct:this = StructCreate(BuildPathTask);
    StructSetCell(this, BuildPathTask_Path, @NavPath_Create());
    return this;
}

@BuildPathTask_Destroy(&Struct:this) {
    new Struct:sNavPath = StructGetCell(this, BuildPathTask_Path);
    @NavPath_Destroy(sNavPath);
    StructDestroy(this);
}

Struct:@PathSegment_Create() {
    new Struct:this = StructCreate(PathSegment);
    return this;
}

@PathSegment_Destroy(&Struct:this) {
    StructDestroy(this);
}

NavAreaGrid_ComputeHashKey(iId) { // returns a hash key for the given nav area ID
    return iId & 0xFF;
}


NavAreaGrid_Init(Float:flMinX, Float:flMaxX, Float:flMinY, Float:flMaxY) {
    g_rgGrid[NavAreaGrid_CellSize] = 300.0;
    g_rgGrid[NavAreaGrid_MinX] = flMinX;
    g_rgGrid[NavAreaGrid_MinY] = flMinY;
    g_rgGrid[NavAreaGrid_GridSizeX] = floatround((flMaxX - flMinX) / g_rgGrid[NavAreaGrid_CellSize] + 1);
    g_rgGrid[NavAreaGrid_GridSizeY] = floatround((flMaxY - flMinY) / g_rgGrid[NavAreaGrid_CellSize] + 1);
    g_rgGrid[NavAreaGrid_AreaCount] = 0;

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

Struct:NavAreaGrid_GetNavAreaById(iAreaId) {
    if (iAreaId == 0) {
        return Invalid_Struct;
    }

    new iKey = NavAreaGrid_ComputeHashKey(iAreaId);

    for (new Struct:sArea = g_rgGrid[NavAreaGrid_HashTable][iKey]; sArea != Invalid_Struct; sArea = StructGetCell(sArea, NavArea_NextHash)) {
        if (@NavArea_GetId(sArea) == iAreaId) {
            return sArea;
        }
    }

    return Invalid_Struct;
}

NavAreaGrid_AddNavArea(Struct:sArea) {
    // add to grid
    new iLoX = NavAreaGrid_WorldToGridX(Float:StructGetCell(sArea, NavArea_Extent, _:Extent_Lo + 0));
    new iLoY = NavAreaGrid_WorldToGridY(Float:StructGetCell(sArea, NavArea_Extent, _:Extent_Lo + 1));
    new iHiX = NavAreaGrid_WorldToGridX(Float:StructGetCell(sArea, NavArea_Extent, _:Extent_Hi + 0));
    new iHiY = NavAreaGrid_WorldToGridY(Float:StructGetCell(sArea, NavArea_Extent, _:Extent_Hi + 1));

    for (new y = iLoY; y <= iHiY; y++) {
        for (new x = iLoX; x <= iHiX; x++) {
            new Array:irgAreas = ArrayGetCell(g_rgGrid[NavAreaGrid_Grid], x + y * g_rgGrid[NavAreaGrid_GridSizeX]);
            ArrayPushCell(irgAreas, sArea);
        }
    }

    new iAreaId = StructGetCell(sArea, NavArea_Id);

    // add to hash table
    new iKey = NavAreaGrid_ComputeHashKey(iAreaId);

    if (g_rgGrid[NavAreaGrid_HashTable][iKey] != Invalid_Struct) {
        // add to head of list in this slot
        StructSetCell(sArea, NavArea_PrevHash, Invalid_Struct);
        StructSetCell(sArea, NavArea_NextHash, g_rgGrid[NavAreaGrid_HashTable][iKey]);
        StructSetCell(g_rgGrid[NavAreaGrid_HashTable][iKey], NavArea_PrevHash, sArea);
        g_rgGrid[NavAreaGrid_HashTable][iKey] = sArea;
    } else {
        // first entry in this slot
        g_rgGrid[NavAreaGrid_HashTable][iKey] = sArea;
        StructSetCell(sArea, NavArea_NextHash, Invalid_Struct);
        StructSetCell(sArea, NavArea_PrevHash, Invalid_Struct);
    }

    g_rgGrid[NavAreaGrid_AreaCount]++;
}

// Given a position, return the nav area that IsOverlapping and is *immediately* beneath it
Struct:NavAreaGrid_GetNavArea(const Float:vecPos[3], Float:flBeneathLimit) {
    if (g_rgGrid[NavAreaGrid_Grid] == Invalid_Array) {
        return Invalid_Struct;
    }

    // get list in cell that contains position
    new x = NavAreaGrid_WorldToGridX(vecPos[0]);
    new y = NavAreaGrid_WorldToGridY(vecPos[1]);

    new Array:irgList = ArrayGetCell(g_rgGrid[NavAreaGrid_Grid], x + y * g_rgGrid[NavAreaGrid_GridSizeX]);

    // search cell list to find correct area
    new Struct:sUseArea = Invalid_Struct;
    new Float:useZ = -99999999.9;
    static Float:vecTestPos[3];
    xs_vec_add(vecPos, Float:{0, 0, 5}, vecTestPos);

    new iListSize = ArraySize(irgList);
    for (new i = 0; i < iListSize; ++i) {
        new Struct:sArea = ArrayGetCell(irgList, i);

        // check if position is within 2D boundaries of this area
        if (@NavArea_IsOverlappingPoint(sArea, vecTestPos)) {
            // project position onto area to get Z
            new Float:z = @NavArea_GetZ(sArea, vecTestPos);

            // if area is above us, skip it
            if (z > vecTestPos[2]) {
                continue;
            }

            // if area is too far below us, skip it
            if (z < vecPos[2] - flBeneathLimit) {
                continue;
            }

            // if area is higher than the one we have, use this instead
            if (z > useZ) {
                sUseArea = sArea;
                useZ = z;
            }
        }
    }

    return sUseArea;
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
Struct:NavAreaGrid_GetNearestNavArea(const Float:vecPos[3], bool:bAnyZ, pIgnoreEnt) {
    if (g_rgGrid[NavAreaGrid_Grid] == Invalid_Array) {
        return Invalid_Struct;
    }

    new Struct:sCloseArea = Invalid_Struct;
    new Float:flCloseDistSq = 100000000.0;

    // quick check
    sCloseArea = NavAreaGrid_GetNavArea(vecPos, 120.0);
    if (sCloseArea) {
        return sCloseArea;
    }

    // ensure source position is well behaved
    static Float:vecSource[3];
    vecSource[0] = vecPos[0];
    vecSource[1] = vecPos[1];

    if (GetGroundHeight(vecPos, vecSource[2], pIgnoreEnt) == false) {
        return Invalid_Struct;
    }

    vecSource[2] += HalfHumanHeight;

    // TODO: Step incrementally using grid for speed

    // find closest nav area
    new iNavAreaCount = ArraySize(g_irgNavAreaList);
    for (new i = 0; i < iNavAreaCount; ++i) {
        new Struct:sArea = ArrayGetCell(g_irgNavAreaList, i);

        static Float:flAreaPos[3];
        @NavArea_GetClosestPointOnArea(sArea, vecSource, flAreaPos);

        new Float:flDistSq = floatpower(xs_vec_distance(flAreaPos, vecSource), 2.0);

        // keep the closest area
        if (flDistSq < flCloseDistSq) {
            // check LOS to area
            if (!bAnyZ) {
                static Float:vecEnd[3];
                xs_vec_copy(flAreaPos, vecEnd);
                vecEnd[2] += HalfHumanHeight;

                engfunc(EngFunc_TraceLine, vecSource, vecEnd, IGNORE_MONSTERS | IGNORE_GLASS, pIgnoreEnt, g_pTrace);

                static Float:flFraction;
                get_tr2(g_pTrace, TR_flFraction, flFraction);
                if (flFraction != 1.0) {
                    continue;
                }
            }

            flCloseDistSq = flDistSq;
            sCloseArea = sArea;
        }
    }

    return sCloseArea;
}

// NavAreaGrid_GetNavAreaCount() {
//     return g_rgGrid[NavAreaGrid_AreaCount];
// }

NavErrorType:LoadNavigationMap() {
    new szMapName[32];
    get_mapname(szMapName, charsmax(szMapName));

    static szFilePath[256];
    format(szFilePath, charsmax(szFilePath), "maps/%s.nav", szMapName);

    if (!file_exists(szFilePath)) {
        log_amx("File ^"%s^" not found!", szFilePath);
        return NAV_CANT_ACCESS_FILE;
    }

    g_irgNavAreaList = ArrayCreate();

    new iFile = fopen(szFilePath, "rb");
    g_iNavAreaNextId = 1;

    new iMagic;
    if (!FileReadInt32(iFile, iMagic)) {
        return NAV_INVALID_FILE;
    }

    if (iMagic != NAV_MAGIC_NUMBER) {
        log_amx("Wrong magic number %d. Should be %d.", iMagic, NAV_MAGIC_NUMBER);
        return NAV_INVALID_FILE;
    }

    new iVersion;
    if (!FileReadInt32(iFile, iVersion)) {
        return NAV_BAD_FILE_VERSION;
    }

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
    static iAreaCount;
    FileReadInt32(iFile, iAreaCount);
    log_amx("Found %d areas", iAreaCount);

    new rgExtent[Extent];
    rgExtent[Extent_Lo][0] = 9999999999.9;
    rgExtent[Extent_Lo][1] = 9999999999.9;
    rgExtent[Extent_Hi][0] = -9999999999.9;
    rgExtent[Extent_Hi][1] = -9999999999.9;

    log_amx("Loading areas...");

    // load the areas and compute total extent
    for (new i = 0; i < iAreaCount; i++) {
        new Struct:sArea = @NavArea_Create();
        @NavArea_Load(sArea, iFile, iVersion, false);
        ArrayPushCell(g_irgNavAreaList, sArea);

        if (Float:StructGetCell(sArea, NavArea_Extent, _:Extent_Lo + 0) < rgExtent[Extent_Lo][0]) {
            rgExtent[Extent_Lo][0] = Float:StructGetCell(sArea, NavArea_Extent, _:Extent_Lo + 0);
        }

        if (Float:StructGetCell(sArea, NavArea_Extent, _:Extent_Lo + 1) < rgExtent[Extent_Lo][1]) {
            rgExtent[Extent_Lo][1] = Float:StructGetCell(sArea, NavArea_Extent, _:Extent_Lo + 1);
        }

        if (Float:StructGetCell(sArea, NavArea_Extent, _:Extent_Hi + 0) > rgExtent[Extent_Hi][0]) {
            rgExtent[Extent_Hi][0] = Float:StructGetCell(sArea, NavArea_Extent, _:Extent_Hi + 0);
        }

        if (Float:StructGetCell(sArea, NavArea_Extent, _:Extent_Hi + 1) > rgExtent[Extent_Hi][1]) {
            rgExtent[Extent_Hi][1] = Float:StructGetCell(sArea, NavArea_Extent, _:Extent_Hi + 1); 
        }
    }

    log_amx("All areas loaded!");

    // add the areas to the grid
    NavAreaGrid_Init(rgExtent[Extent_Lo][0], rgExtent[Extent_Hi][0], rgExtent[Extent_Lo][1], rgExtent[Extent_Hi][1]);

    log_amx("Grid initialized!");

    for (new i = 0; i < iAreaCount; i++) {
        new Struct:sArea = ArrayGetCell(g_irgNavAreaList, i);
        NavAreaGrid_AddNavArea(sArea);
    }

    log_amx("All areas added to the grid!");

    // allow areas to connect to each other, etc
    for (new i = 0; i < iAreaCount; i++) {
        new Struct:sArea = ArrayGetCell(g_irgNavAreaList, i);
        @NavArea_PostLoadArea(sArea);
    }

    log_amx("Loaded areas post processing complete!");

    fclose(iFile);

    return NAV_OK;
}

Struct:FindFirstAreaInDirection(const Float:vecStart[3], NavDirType:iDir, Float:flRange, Float:flBeneathLimit, pIgnoreEnt, Float:vecClosePos[3]) {
    new Struct:sArea = Invalid_Struct;

    static Float:vecPos[3];
    xs_vec_copy(vecStart, vecPos);

    new iEnd = floatround((flRange / GenerationStepSize) + 0.5);

    for (new i = 1; i <= iEnd; i++) {
        AddDirectionVector(vecPos, iDir, GenerationStepSize);

        // make sure we dont look thru the wall
        engfunc(EngFunc_TraceLine, vecStart, vecPos, IGNORE_MONSTERS, pIgnoreEnt, g_pTrace);

        static Float:flFraction;
        get_tr2(g_pTrace, TR_flFraction, flFraction);
        if (flFraction != 1.0) {
            break;
        }

        sArea = NavAreaGrid_GetNavArea(vecPos, flBeneathLimit);

        if (sArea != Invalid_Struct) {
            vecClosePos[0] = vecPos[0];
            vecClosePos[1] = vecPos[1];

            static Float:pos2d[3];
            xs_vec_copy(vecPos, pos2d);
            pos2d[2] = 0.0;

            vecClosePos[2] = @NavArea_GetZ(sArea, pos2d);
            break;
        }
    }

    return sArea;
}

Struct:NavAreaPopOpenList() {
    if (g_sNavAreaOpenList != Invalid_Struct) {
        static Struct:sArea; sArea = g_sNavAreaOpenList;
        // disconnect from list
        @NavArea_RemoveFromOpenList(sArea);
        return sArea;
    }

    return Invalid_Struct;
}

NavAreaMakeNewMarker() {
    if (++g_iNavAreaMasterMarker == 0) {
        g_iNavAreaMasterMarker = 1;
    }
}

NavAreaClearSearchLists() {
    NavAreaMakeNewMarker();
    g_sNavAreaOpenList = Invalid_Struct;
}

Struct:NavAreaBuildPath(const Float:vecStart[3], const Float:vecGoal[3], iCbFuncId = -1, iCbFuncPluginId = -1, pIgnoreEnt, iUserToken, iCostFuncId = -1, iCostFuncPluginId = -1) {
    if (!g_bPrecached) {
        return Invalid_Struct;
    }

    if (!xs_vec_len(vecGoal)) {
        return Invalid_Struct;
    }

    new Struct:sStartArea = NavAreaGrid_GetNearestNavArea(vecStart, false, pIgnoreEnt);
    if (sStartArea == Invalid_Struct) {
        return Invalid_Struct;
    }

    new Struct:sGoalArea = NavAreaGrid_GetNearestNavArea(vecGoal, false, pIgnoreEnt);
    if (sGoalArea == Invalid_Struct) {
        return Invalid_Struct;
    }

    new Struct:sTask = @BuildPathTask_Create();

    StructSetArray(sTask, BuildPathTask_StartPos, vecStart, 3);
    StructSetArray(sTask, BuildPathTask_GoalPos, vecGoal, 3);
    StructSetCell(sTask, BuildPathTask_StartArea, sStartArea);
    StructSetCell(sTask, BuildPathTask_GoalArea, sGoalArea);
    StructSetCell(sTask, BuildPathTask_ClosestArea, Invalid_Struct);
    StructSetCell(sTask, BuildPathTask_CbFuncId, iCbFuncId);
    StructSetCell(sTask, BuildPathTask_CbFuncPluginId, iCbFuncPluginId);
    StructSetCell(sTask, BuildPathTask_CostFuncId, iCostFuncId);
    StructSetCell(sTask, BuildPathTask_CostFuncPluginId, iCostFuncPluginId);
    StructSetCell(sTask, BuildPathTask_IgnoreEntity, pIgnoreEnt);
    StructSetCell(sTask, BuildPathTask_UserToken, iUserToken);
    StructSetCell(sTask, BuildPathTask_IsSuccessed, false);
    StructSetCell(sTask, BuildPathTask_IsTerminated, false);

    if (g_irgBuildPathTasks == Invalid_Array) {
        g_irgBuildPathTasks = ArrayCreate();
    }

    ArrayPushCell(g_irgBuildPathTasks, sTask);

    return sTask;
}

bool:NavAreaBuildPathAbortTask(Struct:sTask) {
    // if task already in progress
    if (g_rgBuildPathJob[BuildPathJob_Task] == sTask) {
        g_rgBuildPathJob[BuildPathJob_Finished] = true;
        g_rgBuildPathJob[BuildPathJob_Terminated] = true;
        g_rgBuildPathJob[BuildPathJob_Successed] = false;

        // terminate task in the same frame
        NavAreaBuildPathFrame();

        return true;
    }

    if (g_irgBuildPathTasks == Invalid_Array) {
        return false;
    }

    new iTask = ArrayFindValue(g_irgBuildPathTasks, sTask);
    if (iTask != -1) {
        @BuildPathTask_Destroy(sTask);
        ArrayDeleteItem(g_irgBuildPathTasks, iTask);
        return true;
    }

    return false;
}

bool:NavAreaBuildPathRunTask(Struct:sTask) {
    g_rgBuildPathJob[BuildPathJob_Task] = sTask;
    g_rgBuildPathJob[BuildPathJob_StartArea] = StructGetCell(sTask, BuildPathTask_StartArea);
    g_rgBuildPathJob[BuildPathJob_GoalArea] = StructGetCell(sTask, BuildPathTask_GoalArea);
    g_rgBuildPathJob[BuildPathJob_CostFuncId] = StructGetCell(sTask, BuildPathTask_CostFuncId);
    g_rgBuildPathJob[BuildPathJob_CostFuncPluginId] = StructGetCell(sTask, BuildPathTask_CostFuncPluginId);
    g_rgBuildPathJob[BuildPathJob_Finished] = false;
    g_rgBuildPathJob[BuildPathJob_Terminated] = false;
    g_rgBuildPathJob[BuildPathJob_Successed] = false;
    g_rgBuildPathJob[BuildPathJob_MaxIterations] = get_pcvar_num(g_pCvarMaxIterationsPerFrame);
    g_rgBuildPathJob[BuildPathJob_ClosestAreaDist] = 999999.0;
    g_rgBuildPathJob[BuildPathJob_ClosestArea] = Invalid_Struct;
    g_rgBuildPathJob[BuildPathJob_IgnoreEntity] = StructGetCell(sTask, BuildPathTask_IgnoreEntity);

    StructGetArray(sTask, BuildPathTask_GoalPos, g_rgBuildPathJob[BuildPathJob_GoalPos], 3);

    @NavArea_SetParent(g_rgBuildPathJob[BuildPathJob_StartArea], Invalid_Struct, NUM_TRAVERSE_TYPES);

    // if we are already in the goal area, build trivial path
    if (g_rgBuildPathJob[BuildPathJob_StartArea] == g_rgBuildPathJob[BuildPathJob_GoalArea]) {
        @NavArea_SetParent(g_rgBuildPathJob[BuildPathJob_GoalArea], Invalid_Struct, NUM_TRAVERSE_TYPES);
        g_rgBuildPathJob[BuildPathJob_ClosestArea] = g_rgBuildPathJob[BuildPathJob_GoalArea];
        g_rgBuildPathJob[BuildPathJob_Successed] = true;
        g_rgBuildPathJob[BuildPathJob_Finished] = true;
        return true;
    }

    // determine actual goal position
    if (xs_vec_len(g_rgBuildPathJob[BuildPathJob_GoalPos]) > 0.0) {
        xs_vec_copy(g_rgBuildPathJob[BuildPathJob_GoalPos], g_rgBuildPathJob[BuildPathJob_ActualGoalPos]);
    } else {
        @NavArea_GetCenter(g_rgBuildPathJob[BuildPathJob_GoalArea], g_rgBuildPathJob[BuildPathJob_ActualGoalPos]);
    }

    // start search
    NavAreaClearSearchLists();

    // compute estimate of path length
    // TODO: Cost might work as "manhattan distance"
    static Float:vecStartAreaCenter[3];
    @NavArea_GetCenter(g_rgBuildPathJob[BuildPathJob_StartArea], vecStartAreaCenter);
    @NavArea_SetTotalCost(g_rgBuildPathJob[BuildPathJob_StartArea], xs_vec_distance(vecStartAreaCenter, g_rgBuildPathJob[BuildPathJob_ActualGoalPos]));

    new Float:flInitCost = 0.0;

    if (g_rgBuildPathJob[BuildPathJob_CostFuncId] != -1 && callfunc_begin_i(g_rgBuildPathJob[BuildPathJob_CostFuncId], g_rgBuildPathJob[BuildPathJob_CostFuncPluginId])) {
        callfunc_push_int(_:g_rgBuildPathJob[BuildPathJob_Task]);
        callfunc_push_int(_:g_rgBuildPathJob[BuildPathJob_StartArea]);
        callfunc_push_int(_:Invalid_Struct);
        flInitCost = Float:callfunc_end();
    }

    if (flInitCost < 0.0) {
        g_rgBuildPathJob[BuildPathJob_Finished] = true;
        g_rgBuildPathJob[BuildPathJob_Terminated] = true;
        g_rgBuildPathJob[BuildPathJob_Successed] = false;
        return false;
    }

    @NavArea_SetCostSoFar(g_rgBuildPathJob[BuildPathJob_StartArea], flInitCost);
    @NavArea_AddToOpenList(g_rgBuildPathJob[BuildPathJob_StartArea]);

    // keep track of the area we visit that is closest to the goal
    if (g_rgBuildPathJob[BuildPathJob_ClosestArea] != Invalid_Struct) {
        g_rgBuildPathJob[BuildPathJob_ClosestArea] = g_rgBuildPathJob[BuildPathJob_StartArea];
    }

    g_rgBuildPathJob[BuildPathJob_ClosestAreaDist] = @NavArea_GetTotalCost(g_rgBuildPathJob[BuildPathJob_StartArea]);

    return true;
}

NavAreaBuildPathFinish() {
    new Struct:sTask = g_rgBuildPathJob[BuildPathJob_Task];
    StructSetCell(sTask, BuildPathTask_IsSuccessed, g_rgBuildPathJob[BuildPathJob_Successed]);
    StructSetCell(sTask, BuildPathTask_IsTerminated, g_rgBuildPathJob[BuildPathJob_Terminated]);

    new Struct:sNavPath = StructGetCell(sTask, BuildPathTask_Path);
    @NavPath_Invalidate(sNavPath);

    if (!g_rgBuildPathJob[BuildPathJob_Terminated]) {
        NavAreaBuildPathSegments();
    }

    new iCbFuncId = StructGetCell(sTask, BuildPathTask_CbFuncId);
    new iCbFuncPluginId = StructGetCell(sTask, BuildPathTask_CbFuncPluginId);

    if (iCbFuncId != -1 && callfunc_begin_i(iCbFuncId, iCbFuncPluginId)) {
        callfunc_push_int(_:sTask);
        callfunc_end();
    }
}

NavAreaBuildPathIteration() {
    if (g_sNavAreaOpenList == Invalid_Struct) {
        g_rgBuildPathJob[BuildPathJob_Finished] = true;
        g_rgBuildPathJob[BuildPathJob_Successed] = false;
        return;
    }

    // get next area to check
    static Struct:sArea; sArea = NavAreaPopOpenList();

    // check if we have found the goal area
    if (sArea == g_rgBuildPathJob[BuildPathJob_GoalArea]) {
        if (g_rgBuildPathJob[BuildPathJob_ClosestArea] != Invalid_Struct) {
            g_rgBuildPathJob[BuildPathJob_ClosestArea] = g_rgBuildPathJob[BuildPathJob_GoalArea];
        }

        g_rgBuildPathJob[BuildPathJob_Finished] = true;
        g_rgBuildPathJob[BuildPathJob_Successed] = true;

        return;
    }

    // search adjacent areas
    static Array:irgFloorList; irgFloorList = @NavArea_GetAdjacentList(sArea, NORTH);
    static iFloorIter; iFloorIter = 0;

    static NavDirType:iDir;
    for (iDir = NORTH; iDir < NUM_DIRECTIONS;) {
        // Get next adjacent area - either on floor or via ladder
        // if exhausted adjacent connections in current direction, begin checking next direction
        if (iFloorIter >= ArraySize(irgFloorList)) {
            iDir++;

            if (iDir < NUM_DIRECTIONS) {
                // start next direction
                irgFloorList = @NavArea_GetAdjacentList(sArea, iDir);
                iFloorIter = 0;
            }

            continue;
        }

        static Struct:newArea; newArea = ArrayGetCell(irgFloorList, iFloorIter, _:NavConnect_Area);

        iFloorIter++;

        // don't backtrack
        if (newArea == sArea) {
            continue;
        }

        static Float:newCostSoFar;
        newCostSoFar = 1.0;

        if (g_rgBuildPathJob[BuildPathJob_CostFuncId] != -1 && callfunc_begin_i(g_rgBuildPathJob[BuildPathJob_CostFuncId], g_rgBuildPathJob[BuildPathJob_CostFuncPluginId])) {
            callfunc_push_int(_:g_rgBuildPathJob[BuildPathJob_Task]);
            callfunc_push_int(_:newArea);
            callfunc_push_int(_:sArea);
            newCostSoFar = Float:callfunc_end();
        }

        // check if cost functor says this area is a dead-end
        if (newCostSoFar < 0.0) {
            continue;
        }

        if ((@NavArea_IsOpen(newArea) || @NavArea_IsClosed(newArea)) && @NavArea_GetCostSoFar(newArea) <= newCostSoFar) {
            // this is a worse path - skip it
            // log_amx("[%d] this is a worse path - skip it", newArea);
            continue;
        }

        // compute estimate of distance left to go
        static Float:vecNewAreaCenter[3];
        @NavArea_GetCenter(newArea, vecNewAreaCenter);

        static Float:newCostRemaining; newCostRemaining = xs_vec_distance(vecNewAreaCenter, g_rgBuildPathJob[BuildPathJob_ActualGoalPos]);

        // track closest area to goal in case path fails
        if (g_rgBuildPathJob[BuildPathJob_ClosestArea] != Invalid_Struct && newCostRemaining < g_rgBuildPathJob[BuildPathJob_ClosestAreaDist]) {
            g_rgBuildPathJob[BuildPathJob_ClosestArea] = newArea;
            g_rgBuildPathJob[BuildPathJob_ClosestAreaDist] = newCostRemaining;
        }

        @NavArea_SetParent(newArea, sArea, NavTraverseType:iDir);
        @NavArea_SetCostSoFar(newArea, newCostSoFar);
        @NavArea_SetTotalCost(newArea, newCostSoFar + newCostRemaining);

        if (@NavArea_IsClosed(newArea)) {
            @NavArea_RemoveFromClosedList(newArea);
        }

        if (@NavArea_IsOpen(newArea)) {
            // area already on open list, update the list order to keep costs sorted
            @NavArea_UpdateOnOpenList(newArea);
        } else {
            @NavArea_AddToOpenList(newArea);
        }
    }

    // we have searched this area
    @NavArea_AddToClosedList(sArea);
}

NavAreaBuildPathFrame() {
    // if no job in progress then find new task to start
    if (g_rgBuildPathJob[BuildPathJob_Task] == Invalid_Struct) {
        if (g_irgBuildPathTasks != Invalid_Array && ArraySize(g_irgBuildPathTasks)) {
            new Struct:sTask = ArrayGetCell(g_irgBuildPathTasks, 0);
            ArrayDeleteItem(g_irgBuildPathTasks, 0);
            NavAreaBuildPathRunTask(sTask);
        }

        return;
    }

    // current job finished, process
    if (g_rgBuildPathJob[BuildPathJob_Finished]) {
        NavAreaBuildPathFinish();
        @BuildPathTask_Destroy(g_rgBuildPathJob[BuildPathJob_Task]);
        g_rgBuildPathJob[BuildPathJob_Task] = Invalid_Struct;
        return;
    }

    // do path finding iterations
    new iIterationsNum = g_rgBuildPathJob[BuildPathJob_MaxIterations];
    for (new i = 0; i < iIterationsNum && !g_rgBuildPathJob[BuildPathJob_Finished]; ++i) {
        NavAreaBuildPathIteration();
    }
}

NavAreaBuildPathSegments() {
    new Struct:sTask = g_rgBuildPathJob[BuildPathJob_Task];

    new Struct:sNavPath = StructGetCell(sTask, BuildPathTask_Path);
    @NavPath_Invalidate(sNavPath);

    static Float:vecStart[3];
    StructGetArray(sTask, BuildPathTask_StartPos, vecStart, sizeof(vecStart));

    static Float:vecGoal[3];
    StructGetArray(sTask, BuildPathTask_GoalPos, vecGoal, sizeof(vecGoal));

    new iSegmentCount = 0;

    new Struct:sEffectiveGoalArea = (
        g_rgBuildPathJob[BuildPathJob_Successed]
            ? g_rgBuildPathJob[BuildPathJob_GoalArea]
            : g_rgBuildPathJob[BuildPathJob_ClosestArea]
    );

    if (g_rgBuildPathJob[BuildPathJob_StartArea] != g_rgBuildPathJob[BuildPathJob_GoalArea]) {
        // Build path by following parent links
        for (new Struct:sArea = sEffectiveGoalArea; sArea != Invalid_Struct; sArea = StructGetCell(sArea, NavArea_Parent)) {
            iSegmentCount++;
        }

        // save room for endpoint
        iSegmentCount = min(iSegmentCount, MAX_PATH_SEGMENTS - 1);

        if (iSegmentCount == 0) {
            return false;
        }

    } else {
        iSegmentCount = 1;
    }

    new Array:irgSegments = StructGetCell(sNavPath, NavPath_Segments);
    ArrayResize(irgSegments, iSegmentCount);
    StructSetCell(sNavPath, NavPath_SegmentCount, iSegmentCount);

    if (iSegmentCount > 1) {
        // Prepare segments
        static Struct:sArea; sArea = sEffectiveGoalArea;

        for (new i = iSegmentCount - 1; i >= 0; --i) {
            static Struct:sSegment; sSegment = @PathSegment_Create();
            StructSetCell(sSegment, PathSegment_Area, sArea);
            StructSetCell(sSegment, PathSegment_How, StructGetCell(sArea, NavArea_ParentHow));

            static Float:vecPos[3];
            @NavArea_GetCenter(sArea, vecPos);
            StructSetArray(sSegment, PathSegment_Pos, vecPos, sizeof(vecPos));

            ArraySetCell(irgSegments, i, sSegment);

            sArea = StructGetCell(sArea, NavArea_Parent);
        }

        if (!@NavPath_ComputePathPositions(sNavPath)) {
            @NavPath_Invalidate(sNavPath);
            return false;
        }

        // append path end position
        static Struct:sEndSegment; sEndSegment = @PathSegment_Create();
        StructSetCell(sEndSegment, PathSegment_Area, sEffectiveGoalArea);
        StructSetArray(sEndSegment, PathSegment_Pos, vecGoal, sizeof(vecGoal));
        StructSetCell(sEndSegment, PathSegment_Pos, @NavArea_GetZ(sEffectiveGoalArea, vecGoal), 2);
        StructSetCell(sEndSegment, PathSegment_How, NUM_TRAVERSE_TYPES);
        @NavPath_PushSegment(sNavPath, sEndSegment);
    } else {
        @NavPath_BuildTrivialPath(sNavPath, vecStart, vecGoal);
    }

    if (get_pcvar_bool(g_pCvarDebug)) {
        new iSegmentCount = StructGetCell(sNavPath, NavPath_SegmentCount);
        for (new i = 1; i < iSegmentCount; ++i) {
            new Struct:sPrevSegment = ArrayGetCell(irgSegments, i - 1);
            new Struct:sNextSegment = ArrayGetCell(irgSegments, i);

            static Float:vecSrc[3];
            StructGetArray(sPrevSegment, PathSegment_Pos, vecSrc, sizeof(vecSrc));

            static Float:vecNext[3];
            StructGetArray(sNextSegment, PathSegment_Pos, vecNext, sizeof(vecNext));

            static irgColor[3];
            irgColor[0] = floatround(255.0 * (1.0 - (float(i) / iSegmentCount)));
            irgColor[1] = floatround(255.0 * (float(i) / iSegmentCount));
            irgColor[2] = 0;

            UTIL_DrawArrow(0, vecSrc, vecNext, irgColor, 255, 30);
        }
    }

    return true;
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

stock bool:GetGroundHeight(const Float:vecPos[3], &Float:flHeight, pIgnoreEnt, Float:vecNormal[3] = {0.0, 0.0, 0.0}) {
    enum GroundLayerInfo {
        Float:GroundLayerInfo_ground,
        Float:GroundLayerInfo_normal[3]
    };

    static Float:vecTo[3];
    vecTo[0] = vecPos[0];
    vecTo[1] = vecPos[1];
    vecTo[2] = vecPos[2] - 9999.9;

    new Float:vecFrom[3];

    new pIgnore = pIgnoreEnt;
    // new Float:ground = 0.0;

    static const Float:flMaxOffset = 100.0;
    static const Float:flInc = 10.0;
    const MAX_GROUND_LAYERS = 16;

    static rgLayer[MAX_GROUND_LAYERS][GroundLayerInfo];
    new iLayerCount = 0;

    static Float:flOffset;
    for (flOffset = 1.0; flOffset < flMaxOffset; flOffset += flInc) {
        xs_vec_copy(vecPos, vecFrom);
        vecFrom[2] += flOffset;

        engfunc(EngFunc_TraceLine, vecFrom, vecTo, IGNORE_MONSTERS, pIgnore, g_pTrace);

        static Float:flFraction;
        get_tr2(g_pTrace, TR_flFraction, flFraction);

        static bool:bStartSolid; bStartSolid = bool:get_tr2(g_pTrace, TR_StartSolid);
        static pHit; pHit = get_tr2(g_pTrace, TR_pHit);

        static Float:vecPlaneNormal[3];
        get_tr2(g_pTrace, TR_vecPlaneNormal, vecPlaneNormal);

        static Float:vecEndPos[3];
        get_tr2(g_pTrace, TR_vecEndPos, vecEndPos);

        if (flFraction != 1.0 && pHit > 0) {
            // ignoring any entities that we can walk through
            if (IsEntityWalkable(pHit, WALK_THRU_DOORS | WALK_THRU_BREAKABLES)) {
                pIgnore = pHit;
                continue;
            }
        }

        if (!bStartSolid) {
            if (iLayerCount == 0 || vecEndPos[2] > rgLayer[iLayerCount - 1][GroundLayerInfo_ground]) {
                rgLayer[iLayerCount][GroundLayerInfo_ground] = vecEndPos[2];
                xs_vec_copy(vecPlaneNormal, rgLayer[iLayerCount][GroundLayerInfo_normal]);
                iLayerCount++;

                if (iLayerCount == MAX_GROUND_LAYERS) {
                    break;
                }
            }
        }
    }

    if (!iLayerCount) {
        return false;
    }

    static i;
    for (i = 0; i < iLayerCount - 1; i++) {
        if (rgLayer[i + 1][GroundLayerInfo_ground] - rgLayer[i][GroundLayerInfo_ground] >= HalfHumanHeight) {
            break;
        }
    }

    flHeight = rgLayer[i][GroundLayerInfo_ground];
    xs_vec_copy(rgLayer[i][GroundLayerInfo_normal], vecNormal);

    return true;
}

stock bool:IsEntityWalkable(pEntity, iFlags) {
    static szClassName[32];
    pev(pEntity, pev_classname, szClassName, charsmax(szClassName));

    // if we hit a door, assume its walkable because it will open when we touch it
    if (equal(szClassName, "func_door") || equal(szClassName, "func_door_rotating")) {
        return !!(iFlags & WALK_THRU_DOORS);
    } else if (equal(szClassName, "func_breakable")) {
        // if we hit a breakable object, assume its walkable because we will shoot it when we touch it
        static Float:flTakeDamage;
        pev(pEntity, pev_takedamage, flTakeDamage);
        if (flTakeDamage == DAMAGE_YES) {
            return !!(iFlags & WALK_THRU_BREAKABLES);
        }
    }

    return false;
}

// Can we see this area?
// For now, if we can see any corner, we can see the area
// TODO: Need to check LOS to more than the corners for large and/or long areas
stock bool:IsAreaVisible(const Float:vecPos[3], Struct:sArea) {
    static Float:vecCorner[3];
    for (new i = 0; i < _:NUM_CORNERS; i++) {
        @NavArea_GetCorner(sArea, NavCornerType:i, vecCorner);
        vecCorner[2] += 0.75 * HumanHeight;

        engfunc(EngFunc_TraceLine, vecPos, vecCorner, IGNORE_MONSTERS, nullptr, g_pTrace);

        static Float:flFraction;
        get_tr2(g_pTrace, TR_flFraction, flFraction);

        if (flFraction == 1.0) {
            // we can see this area
            return true;
        }
    }

    return false;
}

stock AddDirectionVector(Float:vecInput[3], NavDirType:iDir, Float:flAmount) {
    switch (iDir) {
        case NORTH: vecInput[1] -= flAmount;
        case SOUTH: vecInput[1] += flAmount;
        case EAST: vecInput[0] += flAmount;
        case WEST: vecInput[0] -= flAmount;
    }
}

stock DirectionToVector2D(NavDirType:iDir, Float:vecOutput[2]) {
    switch (iDir) {
        case NORTH: {
            vecOutput[0] =  0.0;
            vecOutput[1] = -1.0;
        }
        case SOUTH: {
            vecOutput[0] =  0.0;
            vecOutput[1] =  1.0;
        }
        case EAST: {
            vecOutput[0] =  1.0;
            vecOutput[1] =  0.0;
        }
        case WEST: {
            vecOutput[0] = -1.0;
            vecOutput[1] =  0.0;
        }
    }
}

stock Float:NormalizeInPlace(const Float:vecSrc[3], Float:vecOut[3]) {
    new Float:flLen = xs_vec_len(vecSrc);

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

stock UTIL_DrawArrow(pPlayer, const Float:vecSrc[3], const Float:vecTarget[3], const irgColor[3] = {255, 255, 255}, iBrightness = 255, iLifeTime = 10, iWidth = 64) {
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
