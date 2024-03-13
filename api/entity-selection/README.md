# Entity Selection API
This API provides in-game select entities functionality using a virtual cursor.

## Making simple strategy system
Here is a simple example of how to make something like an RTS system using the API.

```cpp
#include <amxmodx>
#include <fakemeta>
#include <hamsandwich>
#include <reapi>

#include <api_custom_entities>
#include <api_entity_selection>

#define ENTITY_BASE_MONSTER_CLASS "monster_base"

new bool:g_rgbPlayerInStrategyMode[MAX_PLAYERS + 1];

public plugin_init() {
  register_plugin("Simple Strategy System", "1.0.0", "Hedgehog Fog");

  RegisterHamPlayer(Ham_Player_PreThink, "HamHook_Player_PreThink");

  register_concmd("hwn_set_control_mode", "Command_SetControlMode");
}

public client_connect(pPlayer) {
  g_rgbPlayerInStrategyMode[pPlayer] = false;
}

public Command_SetControlMode(pPlayer, iLevel, iCId) {
  g_rgbPlayerInStrategyMode[pPlayer] = !!read_argv_int(1);
  
  if (g_rgbPlayerInStrategyMode[pPlayer]) {
    console_print(pPlayer, "Entered strategy mode!");
  } else {
    console_print(pPlayer, "Left strategy mode!");
  }

  return PLUGIN_HANDLED;
}

public HamHook_Player_PreThink(pPlayer) {
  if (g_rgbPlayerInStrategyMode[pPlayer]) {
    @Player_StrategyModeThink(pPlayer);

    if (!is_user_alive(pPlayer)) {
      // Block observer input
      set_member(pPlayer, m_flNextObserverInput, get_gametime() + 1.0);
    }
  }
}

@Player_StrategyModeThink(this) {
  static iButtons; iButtons = pev(this, pev_button);
  static iOldButtons; iOldButtons = pev(this, pev_oldbuttons);

  if (iButtons & IN_ATTACK && ~iOldButtons & IN_ATTACK) {
      EntitySelection_Start(this, "Callback_SelectionMonstersFilter");
  } else if (~iButtons & IN_ATTACK && iOldButtons & IN_ATTACK) {
      EntitySelection_End(this);
  }

  if (~iButtons & IN_ATTACK2 && iOldButtons & IN_ATTACK2) {
      static Float:vecTarget[3]; EntitySelection_GetCursorPos(this, vecTarget);
      if (@Player_MoveSelectedMonsters(this, vecTarget)) {
        DrawMoveTarget(this, vecTarget);
      }
  }
}

@Player_MoveSelectedMonsters(this, const Float:vecGoal[3]) {
  new iMonstersNum = EntitySelection_GetSize(this);
  if (!iMonstersNum) return false;

  for (new i = 0; i < iMonstersNum; ++i) {
    new pMonster = EntitySelection_GetEntity(this, i);

    set_pev(pMonster, pev_enemy, 0);
    CE_SetMemberVec(pMonster, "vecGoal", vecGoal);
    CE_SetMember(pMonster, "flNextEnemyUpdate", get_gametime() + 5.0);
  }

  return true;
}

public bool:Callback_SelectionMonstersFilter(pPlayer, pEntity) {
  return CE_IsInstanceOf(pEntity, ENTITY_BASE_MONSTER_CLASS);
}

DrawMoveTarget(pPlayer, const Float:vecTarget[3]) {
  new iModelIndex = engfunc(EngFunc_ModelIndex, "sprites/zbeam2.spr");

  engfunc(EngFunc_MessageBegin, MSG_ONE, SVC_TEMPENTITY, vecTarget, pPlayer);
  write_byte(TE_BEAMCYLINDER);
  engfunc(EngFunc_WriteCoord, vecTarget[0]);
  engfunc(EngFunc_WriteCoord, vecTarget[1]);
  engfunc(EngFunc_WriteCoord, vecTarget[2]);
  engfunc(EngFunc_WriteCoord, 0.0);
  engfunc(EngFunc_WriteCoord, 0.0);
  engfunc(EngFunc_WriteCoord, vecTarget[2] + 32.0);
  write_short(iModelIndex);
  write_byte(0);
  write_byte(0);
  write_byte(5);
  write_byte(8);
  write_byte(0);
  write_byte(0);
  write_byte(255);
  write_byte(0);
  write_byte(255);
  write_byte(0);
  message_end();
}
```