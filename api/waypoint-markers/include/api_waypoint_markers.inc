/*
  Credits:
    joaquimandrade
*/

#if defined _api_waypoint_markers_included
  #endinput
#endif
#define _api_waypoint_markers_included

#pragma reqlib api_waypoint_markers

native WaypointMarker_Create(const szModel[], const Float:vecOrigin[3] = {0.0, 0.0, 0.0}, Float:flScale = 1.0, const Float:rgflSize[2] = {64.0, 64.0});
native WaypointMarker_SetVisible(pMarker, pPlayer, bool:bValue);

forward WaypointMarker_Fw_Created(pMarker);
forward WaypointMarker_Fw_Destroy(pMarker);
