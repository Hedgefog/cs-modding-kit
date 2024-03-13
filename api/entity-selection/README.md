# Entity Selection API
This API provides in-game select entities functionality using a virtual cursor.

## Making simple strategy system
Here is a simple example of how to make something like an RTS system using the API.

![Simple Strategy Mode](../../images/example-entity-selection.gif)

```cpp
#include <amxmodx>
#include <fakemeta>
#include <hamsandwich>
#include <reapi>
#include <xs>

#include <api_custom_entities>
#include <api_entity_selection>

#define ENTITY_BASE_MONSTER_CLASS "monster_base"

new const g_rgiSelectionColor[3] = {255, 0, 0};

new bool:g_rgbPlayerInStrategyMode[MAX_PLAYERS + 1];
new Selection:g_rgiPlayerSelection[MAX_PLAYERS + 1];

public plugin_init() {
  register_plugin("Simple Strategy System", "1.0.0", "Hedgehog Fog");

  RegisterHamPlayer(Ham_Player_PreThink, "HamHook_Player_PreThink");

  register_concmd("strategy_mode", "Command_StrategyMode");
}

public client_connect(pPlayer) {
  g_rgbPlayerInStrategyMode[pPlayer] = false;
}

public client_disconnected(pPlayer) {
  @Player_SetStrategyMode(pPlayer, false);
}

public Command_StrategyMode(pPlayer) {
  new bool:bValue = !!read_argv_int(1);

  @Player_SetStrategyMode(pPlayer, bValue);

  return PLUGIN_HANDLED;
}

public HamHook_Player_PreThink(pPlayer) {
  if (g_rgbPlayerInStrategyMode[pPlayer]) {
    @Player_StrategyModeThink(pPlayer);
  }
}

@Player_SetStrategyMode(this, bool:bValue) {
  if (bValue == g_rgbPlayerInStrategyMode[this]) return;
  
  if (bValue) {
    new Selection:iSelection = EntitySelection_Create(this);
    EntitySelection_SetFilter(iSelection, "Callback_SelectionMonstersFilter");
    EntitySelection_SetColor(iSelection, g_rgiSelectionColor);

    console_print(this, "Entered strategy mode!");
  } else {
    EntitySelection_Destroy(g_rgiPlayerSelection[this]);

    console_print(this, "Left strategy mode!");
  }

  g_rgbPlayerInStrategyMode[this] = bValue;
}

@Player_StrategyModeThink(this) {
  static iButtons; iButtons = pev(this, pev_button);
  static iOldButtons; iOldButtons = pev(this, pev_oldbuttons);

  if (iButtons & IN_ATTACK && ~iOldButtons & IN_ATTACK) {
    EntitySelection_Start(g_rgiPlayerSelection[this]);
  } else if (~iButtons & IN_ATTACK && iOldButtons & IN_ATTACK) {
    EntitySelection_End(g_rgiPlayerSelection[this]);
    @Player_HighlightSelectedMonsters(this);
  }

  if (~iButtons & IN_ATTACK2 && iOldButtons & IN_ATTACK2) {
    static Float:vecTarget[3]; EntitySelection_GetCursorPos(g_rgiPlayerSelection[this], vecTarget);

    if (@Player_MoveSelectedMonsters(this, vecTarget)) {
      @Player_DrawTarget(this, vecTarget, 16.0);
    }
  }

  // Block observer input for spectators
  if (!is_user_alive(this)) {
    set_member(this, m_flNextObserverInput, get_gametime() + 1.0);
  }
}

@Player_HighlightSelectedMonsters(this) {
  static const Float:flRadiusBorder = 8.0;
  static pPlayer; pPlayer = EntitySelection_GetPlayer(g_rgiPlayerSelection[pPlayer]);
  static Float:vecSelectionStart[3]; EntitySelection_GetStartPos(g_rgiPlayerSelection[pPlayer], vecSelectionStart);

  new iMonstersNum = EntitySelection_GetSize(g_rgiPlayerSelection[this]);
  if (!iMonstersNum) return;

  for (new i = 0; i < iMonstersNum; ++i) {
    new pMonster = EntitySelection_GetEntity(g_rgiPlayerSelection[this], i);

    static Float:vecTarget[3]; pev(pMonster, pev_origin, vecTarget);
    vecTarget[2] = UTIL_TraceGroundPosition(vecTarget, pMonster) + 1.0;

    static Float:vecMins[3]; pev(pMonster, pev_mins, vecMins);
    static Float:vecMaxs[3]; pev(pMonster, pev_maxs, vecMaxs);
    static Float:flTargetRadius; flTargetRadius = floatmax(vecMaxs[0] - vecMins[0], vecMaxs[1] - vecMins[1]) / 2;
    static Float:flRadius; flRadius = flTargetRadius + flRadiusBorder;

    @Player_DrawTarget(pPlayer, vecTarget, flRadius);
  }
}

@Player_MoveSelectedMonsters(this, const Float:vecGoal[3]) {
  new iMonstersNum = EntitySelection_GetSize(g_rgiPlayerSelection[this]);
  if (!iMonstersNum) return false;

  for (new i = 0; i < iMonstersNum; ++i) {
    new pMonster = EntitySelection_GetEntity(g_rgiPlayerSelection[this], i);

    set_pev(pMonster, pev_enemy, 0);
    CE_SetMemberVec(pMonster, "vecGoal", vecGoal);
    CE_SetMember(pMonster, "flNextEnemyUpdate", get_gametime() + 5.0);
  }

  return true;
}

@Player_DrawTarget(this, const Float:vecTarget[3], Float:flRadius) {
  static iModelIndex; iModelIndex = engfunc(EngFunc_ModelIndex, "sprites/zbeam2.spr");
  static const iLifeTime = 5;
  static Float:flRadiusRatio; flRadiusRatio = 1.0 / (float(iLifeTime) / 10);

  engfunc(EngFunc_MessageBegin, MSG_ONE, SVC_TEMPENTITY, vecTarget, this);
  write_byte(TE_BEAMCYLINDER);
  engfunc(EngFunc_WriteCoord, vecTarget[0]);
  engfunc(EngFunc_WriteCoord, vecTarget[1]);
  engfunc(EngFunc_WriteCoord, vecTarget[2]);
  engfunc(EngFunc_WriteCoord, 0.0);
  engfunc(EngFunc_WriteCoord, 0.0);
  engfunc(EngFunc_WriteCoord, vecTarget[2] + (flRadius * flRadiusRatio));
  write_short(iModelIndex);
  write_byte(0);
  write_byte(0);
  write_byte(iLifeTime);
  write_byte(8);
  write_byte(0);
  write_byte(g_rgiSelectionColor[0]);
  write_byte(g_rgiSelectionColor[1]);
  write_byte(g_rgiSelectionColor[2]);
  write_byte(255);
  write_byte(0);
  message_end();
}

public bool:Callback_SelectionMonstersFilter(pPlayer, pEntity) {
  return CE_IsInstanceOf(pEntity, ENTITY_BASE_MONSTER_CLASS);
}

stock Float:UTIL_TraceGroundPosition(const Float:vecOrigin[], pIgnoreEnt) {
  static pTrace; pTrace = create_tr2();

  static Float:vecTarget[3]; xs_vec_set(vecTarget, vecOrigin[0], vecOrigin[1], vecOrigin[2] - 8192.0);

  engfunc(EngFunc_TraceLine, vecOrigin, vecTarget, IGNORE_MONSTERS, pIgnoreEnt, pTrace);

  get_tr2(pTrace, TR_vecEndPos, vecTarget);

  free_tr2(pTrace);

  return vecTarget[2];
}
```