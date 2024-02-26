# Example

```pawn
@Entity_FindPath(this, Float:vecTarget[3]) {
    static Float:vecOrigin[3];
    pev(this, pev_origin, vecOrigin);

    new NavBuildPathTask:pTask = Nav_Path_Find(vecOrigin, vecTarget, "NavPathCallback", this, this, "NavPathCost");
    CE_SetMember(this, m_pFindPathTask, pTask);
}

public NavPathCallback(NavBuildPathTask:pTask) {
    new pEntity = Nav_Path_FindTask_GetUserToken(pTask);
    new NavPath:pPath = Nav_Path_FindTask_GetPath(pTask);
    new Array:irgSegments = Nav_Path_GetSegments(pPath);
    
    new Array:irgPath = CE_GetMember(pEntity, m_irgPath);
    ArrayClear(irgPath);

    for (new i = 0; i < ArraySize(irgSegments); ++i) {
        new NavPathSegment:pSegment = ArrayGetCell(irgSegments, i);
        static Float:vecPos[3];
        Nav_Path_Segment_GetPos(pSegment, vecPos);
        ArrayPushArray(irgPath, vecPos, sizeof(vecPos));
    }

    CE_SetMember(pEntity, m_pFindPathTask, Invalid_NavBuildPathTask);
}


public Float:NavPathCost(NavBuildPathTask:pTask, NavArea:newArea, NavArea:prevArea) {
    if (Nav_Area_GetAttributes(newArea) & NAV_JUMP) {
        return -1.0;
    }

    if (Nav_Area_GetAttributes(newArea) & NAV_CROUCH) {
        return -1.0;
    }

    return 1.0;
}
```