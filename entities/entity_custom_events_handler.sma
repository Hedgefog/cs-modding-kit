#pragma semicolon 1

#include <amxmodx>
#include <amxmisc>
#include <hamsandwich>
#include <fakemeta>

#include <api_custom_entities>
#include <api_custom_events>

#define PLUGIN "[Entity] Custom Events Handler"
#define VERSION "1.0.0"
#define AUTHOR "Hedgehog Fog"

#define m_pActivator "pActivator"
#define m_szEvent "szEvent"
#define m_szTarget "szTarget"

#define ENTITY_NAME "custom_events_handler"

new Array:g_irgpEntities;

public plugin_precache() {
    g_irgpEntities = ArrayCreate();

    CE_Register(ENTITY_NAME);
    CE_RegisterHook(CEFunction_Init, ENTITY_NAME, "@Entity_Init");
    CE_RegisterHook(CEFunction_KVD, ENTITY_NAME, "@Entity_KeyValue");
    CE_RegisterHook(CEFunction_Think, ENTITY_NAME, "@Entity_Think");
    CE_RegisterHook(CEFunction_Remove, ENTITY_NAME, "@Entity_Remove");
}

public plugin_init() {
    register_plugin(PLUGIN, VERSION, AUTHOR);
}

public plugin_end() {
    ArrayDestroy(g_irgpEntities);
}

public CustomEvent_Fw_Emit(const szEvent[], pActivator) {
    new iSize = ArraySize(g_irgpEntities);
    for (new iGlobalId = 0; iGlobalId < iSize; ++iGlobalId) {
        static pEntity; pEntity = ArrayGetCell(g_irgpEntities, iGlobalId);

        static szEntityEvent[64]; CE_GetMemberString(pEntity, m_szEvent, szEntityEvent, charsmax(szEntityEvent));
        if (!equal(szEntityEvent, szEvent)) continue;

        CE_SetMember(pEntity, m_pActivator, pActivator);
        dllfunc(DLLFunc_Think, pEntity);
    }
}

@Entity_KeyValue(this, const szKey[], const szValue[]) {
    if (equal(szKey, "event")) {
        CE_SetMemberString(this, m_szEvent, szValue);
    } else if (equal(szKey, "target")) {
        CE_SetMemberString(this, m_szTarget, szValue);
    }
}

@Entity_Init(this) {
    ArrayPushCell(g_irgpEntities, this);
}

@Entity_Remove(this) {
    new iGlobalIndex = ArrayFindValue(g_irgpEntities, this);
    if (iGlobalIndex != -1) {
        ArrayDeleteItem(g_irgpEntities, iGlobalIndex);
    }
}

@Entity_Think(this) {
    static pActivator; pActivator = CE_GetMember(this, m_pActivator);
    static szTarget[64]; CE_GetMemberString(this, m_szTarget, szTarget, charsmax(szTarget));

    new pTarget = 0;
    while ((pTarget = engfunc(EngFunc_FindEntityByString, pTarget, "targetname", szTarget)) != 0) {
        ExecuteHamB(Ham_Use, pTarget, pActivator, this, 2, 1.0);
    }
}
