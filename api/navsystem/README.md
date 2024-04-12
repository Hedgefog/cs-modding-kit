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
    
    new Array:irgPath = CE_GetMember(pEntity, m_irgPath);
    ArrayClear(irgPath);

    static iSegmentsNum; iSegmentsNum = Nav_Path_GetSegmentCount(pPath);

    for (new iSegment = 0; iSegment < iSegmentsNum; ++iSegment) {
        static Float:vecPos[3]; Nav_Path_GetSegmentPos(pPath, iSegment, vecPos);

        ArrayPushArray(irgPath, vecPos, sizeof(vecPos));
    }

    CE_SetMember(pEntity, m_pFindPathTask, Invalid_NavBuildPathTask);
}


public Float:NavPathCost(NavBuildPathTask:pTask, NavArea:newArea, NavArea:prevArea) {
    // No jump
    if (Nav_Area_GetAttributes(newArea) & NAV_JUMP) return -1.0;

    // No crouch
    if (Nav_Area_GetAttributes(newArea) & NAV_CROUCH) return -1.0;

    // Don't go ladders
    if (prevArea != Invalid_NavArea) {
        new NavTraverseType:iTraverseType = Nav_Area_GetParentHow(prevArea);
        if (iTraverseType == GO_LADDER_UP) return -1.0;
        if (iTraverseType == GO_LADDER_DOWN) return -1.0;
    }

    return 1.0;
}
```
