#if defined _api_navsystem_included
  #endinput
#endif
#define _api_navsystem_included

#pragma reqlib api_navsystem

#include <api_navsystem_const>

enum NavArea {
    Invalid_NavArea
};

enum NavBuildPathTask {
    Invalid_NavBuildPathTask = 0
};

enum NavPath {
    Invalid_NavPath = 0
};

native Nav_Precache();

native Nav_GetAreaCount();
native Nav_GetArea(iIndex);
native Nav_GetAreaById(iId);
native Nav_GetAreaFromGrid(Float:vecPos[3], Float:flBeneathLimit);
native Nav_WorldToGridX(Float:flValue);
native Nav_WorldToGridY(Float:flValue);
native NavArea:Nav_FindFirstAreaInDirection(const Float:vecStart[3], NavDirType:iDir, Float:flRange, Float:flBeneathLimit, pIgnoreEnt, Float:vecClosePos[3]);
native bool:Nav_IsAreaVisible(const Float:vecPos[3], NavArea:pArea);

native Nav_Area_GetId(NavArea:pArea);
native NavAttributeType:Nav_Area_GetAttributes(NavArea:pArea);
native Nav_Area_GetCenter(NavArea:pArea, Float:vecOut[3]);
native bool:Nav_Area_Contains(NavArea:pArea, const Float:vecPoint[3]);
native bool:Nav_Area_IsCoplanar(NavArea:pArea, NavArea:pOther);
native Float:Nav_Area_GetZ(NavArea:pArea);
native Nav_Area_GetClosestPointOnArea(NavArea:pArea, const Float:vecPoint[3], const Float:vecOut[3]);
native Float:Nav_Area_GetDistanceSquaredToPoint(NavArea:pArea, const Float:vecPoint[3]);
native NavArea:Nav_Area_GetRandomAdjacentArea(NavArea:pArea, NavDirType:iDir);
native bool:Nav_Area_IsEdge(NavArea:pArea, NavDirType:iDir);
native bool:Nav_Area_IsConnected(NavArea:pArea, NavArea:pOther, NavDirType:iDir);
native Nav_Area_GetCorner(NavArea:pArea, NavCornerType:iCorner, Float:vecPos[3]);
native NavDirType:Nav_Area_ComputeDirection(NavArea:pArea, const Float:vecPoint[3]);
native Nav_Area_ComputePortal(NavArea:pAreas, NavArea:pOther, NavDirType:iDir, Float:vecCenter[3], &Float:flHalfWidth);
native bool:Nav_Area_IsOverlapping(NavArea:pArea, NavArea:pOther);
native bool:Nav_Area_IsOverlappingPoint(NavArea:pArea, const Float:vecPoint[3]);

/**
  * Use the A* algorithm to find the shortest path asynchronous
  *
  * The callback function should be prototyped as:
  *
  * public Float:<function>(NavBuildPathTask:pTask)
  *     NavBuildPathTask:pTask - The handler of the current task
  *
  *
  * The cost function should be prototyped as:
  *
  * public Float:<function>(NavBuildPathTask:pTask, NavArea:nextArea, NavArea:prevArea)
  *     NavBuildPathTask:pTask - The handler of the current task
  *     NavArea:nextArea - Next area to check
  *     NavArea:prevArea - Previous area (Invalid_NavArea on fist call)
  *         The cost function should return a floating value as an estimatie of the step's cost
  *         If the cost function returns -1.0 for an area, that area is considered a dead end.
  *
  * @param Float:vecStart[3] Start origin
  * @param Float:vecGoal[3] Goal origin
  * @param szCbFunc[] Callback function
  * @param pIgnoreEntity Ignore entity for tracelines
  * @param iUserToken User integer value to identify the task in the future
  * @param szCostFunc[] Cost function
  *
  * @return Task handler
*/
native NavBuildPathTask:Nav_Path_Find(const Float:vecStart[3], const Float:vecGoal[3], const szCbFunc[], pIgnoreEntity, any:iUserToken, const szCostFunc[] = "");
native bool:Nav_Path_FindTask_Abort(NavBuildPathTask:pTask);
native NavPath:Nav_Path_FindTask_GetPath(NavBuildPathTask:pTask);
native bool:Nav_Path_FindTask_IsSuccessed(NavBuildPathTask:pTask);
native any:Nav_Path_FindTask_GetUserToken(NavBuildPathTask:pTask);

native Array:Nav_Path_GetSegments(NavPath:pPath);

native Nav_Path_Segment_GetPos(NavPathSegment:pSegment, Float:vecOut[3]);
