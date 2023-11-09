#pragma semicolon 1

#include <amxmodx>
#include <hamsandwich>
#include <fakemeta>
#include <engine>
#include <xs>
#include <reapi>

#include <api_custom_weapons>

#define PLUGIN "[API] Custom Weapons"
#define VERSION "0.8.0"
#define AUTHOR "Hedgehog Fog"

#define WALL_PUFF_SPRITE "sprites/wall_puff1.spr"

#define VEC_DUCK_HULL_MIN Float:{-16.0, -16.0, -18.0}
#define VEC_DUCK_HULL_MAX Float:{16.0, 16.0, 18.0}

#define IS_PLAYER(%1) (%1 > 0 && %1 <= MaxClients)

#define TOKEN 743647146

enum _:WeaponListMessage {
  WL_WeaponName[32],
  WL_PrimaryAmmoType,
  WL_PrimaryAmmoMaxAmount,
  WL_SecondaryAmmoType,
  WL_SecondaryAmmoMaxAmount,
  WL_SlotId,
  WL_NumberInSlot,
  WL_WeaponId,
  WL_Flags
};

enum _:Function {
  Function_PluginId,
  Function_FunctionId
};

new const g_rgszWeaponNames[CSW_LAST_WEAPON + 1][] = {
  "",
  "weapon_p228",
  "weapon_shield",
  "weapon_scout",
  "weapon_hegrenade",
  "weapon_xm1014",
  "weapon_c4",
  "weapon_mac10",
  "weapon_aug",
  "weapon_smokegrenade",
  "weapon_elite",
  "weapon_fiveseven",
  "weapon_ump45",
  "weapon_sg550",
  "weapon_galil",
  "weapon_famas",
  "weapon_usp",
  "weapon_glock18",
  "weapon_awp",
  "weapon_mp5navy",
  "weapon_m249",
  "weapon_m3",
  "weapon_m4a1",
  "weapon_tmp",
  "weapon_g3sg1",
  "weapon_flashbang",
  "weapon_deagle",
  "weapon_sg552",
  "weapon_ak47",
  "weapon_knife",
  "weapon_p90"
};

new gmsgWeaponList;
new gmsgDeathMsg;

new bool:g_bWeaponHooks[CSW_LAST_WEAPON + 1];
new g_weaponListDefaults[CSW_LAST_WEAPON + 1][WeaponListMessage];

new Array:g_rgWeapons[CW_Data];
new Trie:g_rgWeaponsMap;
new g_iWeaponCount;

new Float:g_flNextPredictionUpdate[MAX_PLAYERS + 1];
new bool:g_bKnifeHolstered[MAX_PLAYERS + 1];

new g_pNewWeaponboxEnt = -1;
new g_pKillerItem = -1;
new bool:g_bSupercede;
new bool:g_bPrecache;

new Array:g_irgDecals;

public plugin_precache() {
  g_bPrecache = true;

  InitStorages();

  register_forward(FM_UpdateClientData, "OnUpdateClientData_Post", 1);
  register_forward(FM_PrecacheEvent, "OnPrecacheEvent_Post", 1);
  register_forward(FM_SetModel, "OnSetModel_Post", 1);
  register_forward(FM_DecalIndex, "OnDecalIndex_Post", 1);

  RegisterHam(Ham_Spawn, "weaponbox", "OnWeaponboxSpawn", .Post = 0);
  RegisterHamPlayer(Ham_Player_PreThink, "OnPlayerPreThink_Post", .Post = 1);
  RegisterHamPlayer(Ham_TakeDamage, "OnPlayerTakeDamage", .Post = 0);
  RegisterHamPlayer(Ham_TakeDamage, "OnPlayerTakeDamage_Post", .Post = 1);

  precache_model(WALL_PUFF_SPRITE);
}

public plugin_init() {
  g_bPrecache = false;

  register_plugin(PLUGIN, VERSION, AUTHOR);

  gmsgWeaponList = get_user_msgid("WeaponList");
  gmsgDeathMsg = get_user_msgid("DeathMsg");

  register_message(gmsgWeaponList, "OnMessage_WeaponList");
  register_message(gmsgDeathMsg, "OnMessage_DeathMsg");
}

public plugin_cfg() {
  InitWeaponHooks();
}

public plugin_natives() {
  register_library("api_custom_weapons");

  register_native("CW_Register", "Native_Register");
  register_native("CW_GetHandlerByEntity", "Native_GetHandlerByEntity");
  register_native("CW_GetHandler", "Native_GetHandler");
  register_native("CW_GetWeaponData", "Native_GetWeaponData");
  register_native("CW_GetWeaponStringData", "Native_GetWeaponStringData");
  register_native("CW_GiveWeapon", "Native_GiveWeapon");
  register_native("CW_HasWeapon", "Native_HasWeapon");
  register_native("CW_SpawnWeapon", "Native_SpawnWeapon");
  register_native("CW_SpawnWeaponBox", "Native_SpawnWeaponBox");

  register_native("CW_Deploy", "Native_Deploy");
  register_native("CW_Holster", "Native_Holster");
  register_native("CW_ItemPostFrame", "Native_ItemPostFrame");
  register_native("CW_Idle", "Native_Idle");
  register_native("CW_Reload", "Native_Reload");
  register_native("CW_PrimaryAttack", "Native_PrimaryAttack");
  register_native("CW_SecondaryAttack", "Native_SecondaryAttack");

  register_native("CW_FireBulletsPlayer", "Native_FireBulletsPlayer");
  register_native("CW_EjectWeaponBrass", "Native_EjectWeaponBrass");
  register_native("CW_PlayAnimation", "Native_PlayAnimation");
  register_native("CW_GetPlayer", "Native_GetPlayer");

  register_native("CW_DefaultDeploy", "Native_DefaultDeploy");
  register_native("CW_DefaultShot", "Native_DefaultShot");
  register_native("CW_DefaultShotgunShot", "Native_DefaultShotgunShot");
  register_native("CW_DefaultSwing", "Native_DefaultSwing");
  register_native("CW_DefaultReload", "Native_DefaultReload");
  register_native("CW_DefaultShotgunReload", "Native_DefaultShotgunReload");
  register_native("CW_DefaultShotgunIdle", "Native_DefaultShotgunIdle");
  
  register_native("CW_GrenadeDetonate", "Native_GrenadeDetonate");
  register_native("CW_GrenadeSmoke", "Native_GrenadeSmoke");
  register_native("CW_RemovePlayerItem", "Native_RemovePlayerItem");

  register_native("CW_Bind", "Native_Bind");
}

public plugin_end() {
  DestroyStorages();
}

// ANCHOR: Natives

public Native_Bind(iPluginId, iArgc) {
  new CW:iHandler = CW:get_param(1);
  new iBinding = get_param(2);

  new szFunctionName[32];
  get_string(3, szFunctionName, charsmax(szFunctionName));

  Bind(iHandler, iBinding, iPluginId, get_func_id(szFunctionName, iPluginId));
}

public CW:Native_GetHandlerByEntity(iPluginId, iArgc) {
  new pEntity = get_param(1);
  return GetHandlerByEntity(pEntity);
}

public CW:Native_GetHandler(iPluginId, iArgc) {
  static szName[64];
  get_string(1, szName, charsmax(szName));

  return GetHandler(szName);
}

public any:Native_GetWeaponData(iPluginId, iArgc) {
  new CW:iHandler = CW:get_param(1);
  new CW_Data:iParam = CW_Data:get_param(2);

  return GetData(iHandler, iParam);
}

public Native_GetWeaponStringData(iPluginId, iArgc) {
  new CW:iHandler = CW:get_param(1);
  new CW_Data:iParam = CW_Data:get_param(2);

  static szValue[128];
  GetStringData(iHandler, iParam, szValue, charsmax(szValue));

  new iLen = get_param(4);
  set_string(3, szValue, iLen);
}

public CW:Native_Register(iPluginId, iArgc) {
  new szName[64];
  get_string(1, szName, charsmax(szName));

  new iWeaponId = get_param(2);
  new iClipSize = get_param(3);
  new iPrimaryAmmoType = get_param(4);
  new iPrimaryAmmoMaxAmount = get_param(5);
  new iSecondaryAmmoType = get_param(6);
  new iSecondaryAmmoMaxAmount = get_param(7);
  new iSlotId = get_param(8);
  new iPosition = get_param(9);
  new iWeaponFlags = get_param(10);

  new szIcon[16];
  get_string(11, szIcon, charsmax(szIcon));

  new CW_Flags:iFlags = CW_Flags:get_param(12);

  return RegisterWeapon(iPluginId, szName, iWeaponId, iClipSize, iPrimaryAmmoType, iPrimaryAmmoMaxAmount, iSecondaryAmmoType, iSecondaryAmmoMaxAmount, iSlotId, iPosition, iWeaponFlags, szIcon, iFlags);
}

public Native_GiveWeapon(iPluginId, iArgc) {
  new pPlayer = get_param(1);
  
  static szWeapon[64];
  get_string(2, szWeapon, charsmax(szWeapon));

  new CW:iHandler;
  if (TrieGetCell(g_rgWeaponsMap, szWeapon, iHandler)) {
    GiveWeapon(pPlayer, iHandler);
  }
}

public bool:Native_HasWeapon(iPluginId, iArgc) {
  new pPlayer = get_param(1);

  static szWeapon[64];
  get_string(2, szWeapon, charsmax(szWeapon));

  new CW:iHandler;
  if (TrieGetCell(g_rgWeaponsMap, szWeapon, iHandler)) {
    return HasWeapon(pPlayer, iHandler);
  }

  return false;
}

public Native_SpawnWeapon(iPluginId, iArgc) {
  new CW:iHandler = CW:get_param(1);
  return SpawnWeapon(iHandler);
}

public Native_SpawnWeaponBox(iPluginId, iArgc) {
  new CW:iHandler = CW:get_param(1);
  return SpawnWeaponBox(iHandler);
}

public bool:Native_DefaultDeploy(iPluginId, iArgc) {
  new pWeapon = get_param(1);

  static szViewModel[64];
  get_string(2, szViewModel, charsmax(szViewModel));

  static szWeaponModel[64];
  get_string(3, szWeaponModel, charsmax(szWeaponModel));

  new iAnim = get_param(4);

  static szAnimExt[16];
  get_string(5, szAnimExt, charsmax(szAnimExt));

  return DefaultDeploy(pWeapon, szViewModel, szWeaponModel, iAnim, szAnimExt);
}

public Native_FireBulletsPlayer(iPluginId, iArgc) {
  new pWeapon = get_param(1);
  new iShots = get_param(2);

  static Float:vecSrc[3];
  get_array_f(3, vecSrc, sizeof(vecSrc));
  
  static Float:vecDirShooting[3];
  get_array_f(4, vecDirShooting, sizeof(vecDirShooting));

  static Float:vecSpread[3];
  get_array_f(5, vecSpread, sizeof(vecSpread));

  new Float:flDistance = get_param_f(6);
  new Float:flDamage = get_param_f(7);
  new Float:flRangeModifier = get_param_f(8);
  new pevAttacker = get_param(9);

  static Float:vecOut[3];

  FireBulletsPlayer(pWeapon, iShots, vecSrc, vecDirShooting, vecSpread, flDistance, flDamage, flRangeModifier, pevAttacker, vecOut);

  set_array_f(10, vecOut, sizeof(vecOut));
}

public bool:Native_EjectWeaponBrass(iPluginId, iArgc) {
  new pItem = get_param(1);
  new iModelIndex = get_param(2);
  new iSoundType = get_param(3);

  return EjectWeaponBrass(pItem, iModelIndex, iSoundType);
}

public bool:Native_DefaultShot(iPluginId, iArgc) {
  new pItem = get_param(1);
  new Float:flDamage = get_param_f(2);
  new Float:flRangeModifier = get_param_f(3);
  new Float:flRate = get_param_f(4);

  static Float:vecSpread[3];
  get_array_f(5, vecSpread, sizeof(vecSpread));

  new iShots = get_param(6);
  new Float:flDistance = get_param_f(7);

  return DefaultShot(pItem, flDamage, flRangeModifier, flRate, vecSpread, iShots, flDistance);
}

public bool:Native_DefaultShotgunShot(iPluginId, iArgc) {
  new pItem = get_param(1);
  new Float:flDamage = get_param_f(2);
  new Float:flRangeModifier = get_param_f(3);
  new Float:flRate = get_param_f(4);
  new Float:flPumpDelay = get_param_f(5);

  static Float:vecSpread[3];
  get_array_f(6, vecSpread, sizeof(vecSpread));

  new iShots = get_param(7);
  new Float:flDistance = get_param_f(8);

  return DefaultShotgunShot(pItem, flDamage, flRangeModifier, flRate, flPumpDelay, vecSpread, iShots, flDistance);
}

public Native_DefaultSwing(iPluginId, iArgc) {
  new pItem = get_param(1);
  new Float:flDamage = get_param_f(2);
  new Float:flRate = get_param_f(3);
  new Float:flDistance = get_param_f(4);

  return DefaultSwing(pItem, flDamage, flRate, flDistance);
}

public Native_PlayAnimation(iPluginID, argc) {
  new pItem = get_param(1);
  new iSequence = get_param(2);
  new Float:flDuration = get_param_f(3);

  PlayWeaponAnim(pItem, iSequence, flDuration);
}

public Native_GetPlayer(iPluginID, argc) {
  new pItem = get_param(1);
  return GetPlayer(pItem);
}

public bool:Native_DefaultReload(iPluginId, iArgc) {
  new pItem = get_param(1);
  new iAnim = get_param(2);
  new Float:flDelay = get_param_f(3);

  return DefaultReload(pItem, iAnim, flDelay);
}

public bool:Native_DefaultShotgunReload(iPluginId, iArgc) {
  new pItem = get_param(1);
  new iStartAnim = get_param(2);
  new iEndAnim = get_param(3);
  new Float:flDelay = get_param_f(4);
  new Float:flDuration = get_param_f(5);

  return DefaultShotgunReload(pItem, iStartAnim, iEndAnim, flDelay, flDuration);
}

public bool:Native_DefaultShotgunIdle(iPluginId, iArgc) {
  new pItem = get_param(1);
  new iAnim = get_param(2);
  new iReloadEndAnim = get_param(3);
  new Float:flDuration = get_param_f(4);
  new Float:flReloadEndDuration = get_param_f(5);
  
  static szPumpSound[64];
  get_string(6, szPumpSound, charsmax(szPumpSound));

  return DefaultShotgunIdle(pItem, iAnim, iReloadEndAnim, flDuration, flReloadEndDuration, szPumpSound);
}

public Native_Deploy(iPluginId, iArgc) {
  new pItem = get_param(1);
  WeaponDeploy(pItem);
}

public Native_Holster(iPluginId, iArgc) {
  new pItem = get_param(1);
  WeaponHolster(pItem);
}

public Native_ItemPostFrame(iPluginId, iArgc) {
  new pItem = get_param(1);
  ItemPostFrame(pItem);
}

public Native_Idle(iPluginId, iArgc) {
  new pItem = get_param(1);
  WeaponIdle(pItem);
}

public Native_Reload(iPluginId, iArgc) {
  new pItem = get_param(1);
  Reload(pItem);
}

public Native_PrimaryAttack(iPluginId, iArgc) {
  new pItem = get_param(1);
  PrimaryAttack(pItem);
}
public Native_SecondaryAttack(iPluginId, iArgc) {
  new pItem = get_param(1);
  SecondaryAttack(pItem);
}

public Native_GrenadeDetonate(iPluginId, iArgc) {
  new pGrenade = get_param(1);
  new Float:flRadius = get_param_f(2);
  new Float:flMagnitude = get_param_f(3);
  GrenadeDetonate(pGrenade, flRadius, flMagnitude);
}

public Native_GrenadeSmoke(iPluginId, iArgc) {
  new pGrenade = get_param(1);
  GrenadeSmoke(pGrenade);
}

public Native_RemovePlayerItem(iPluginId, iArgc) {
  new pItem = get_param(1);
  RemovePlayerItem(pItem);
}

// ANCHOR: Forwards

public client_connect(pPlayer) {
  g_bKnifeHolstered[pPlayer] = true;
}

public client_disconnected(pPlayer) {
  SetWeaponPrediction(pPlayer, true);
}

// ANCHOR: Hook Callbacks

public OnItemDeploy(this) {
  new CW:iHandler = GetHandlerByEntity(this);
  if (iHandler == CW_INVALID_HANDLER) {
    return HAM_IGNORED;
  }

  WeaponDeploy(this);

  return HAM_SUPERCEDE;
}

public OnItemHolster(this) {
  new pPlayer = GetPlayer(this);
  g_bKnifeHolstered[pPlayer] = IsWeaponKnife(this);

  new CW:iHandler = GetHandlerByEntity(this);
  if (iHandler == CW_INVALID_HANDLER) {
    return HAM_IGNORED;
  }

  WeaponHolster(this);

  return HAM_SUPERCEDE;
}

public OnItemPostFrame(this) {
  new CW:iHandler = GetHandlerByEntity(this);
  if (iHandler == CW_INVALID_HANDLER) {
    return HAM_IGNORED;
  }

  ItemPostFrame(this);

  return HAM_SUPERCEDE;
}

public OnWeaponPrimaryAttack(this) {
  new CW:iHandler = GetHandlerByEntity(this);
  if (iHandler == CW_INVALID_HANDLER) {
    return HAM_IGNORED;
  }

  g_bSupercede = GetHamReturnStatus() >= HAM_SUPERCEDE;

  return HAM_SUPERCEDE;
}

public OnWeaponSecondaryAttack(this) {
  new CW:iHandler = GetHandlerByEntity(this);
  if (iHandler == CW_INVALID_HANDLER) {
    return HAM_IGNORED;
  }

  g_bSupercede = GetHamReturnStatus() >= HAM_SUPERCEDE;

  return HAM_SUPERCEDE;
}

public OnWeaponReload(this) {
  new CW:iHandler = GetHandlerByEntity(this);
  if (iHandler == CW_INVALID_HANDLER) {
    return HAM_IGNORED;
  }

  g_bSupercede = GetHamReturnStatus() >= HAM_SUPERCEDE;

  return HAM_SUPERCEDE;
}

public OnWeaponIdle(this) {
  new CW:iHandler = GetHandlerByEntity(this);
  if (iHandler == CW_INVALID_HANDLER) {
    return HAM_IGNORED;
  }

  g_bSupercede = GetHamReturnStatus() >= HAM_SUPERCEDE;

  return HAM_SUPERCEDE;
}

public OnUpdateClientData_Post(pPlayer, iSendWeapons, pCdHandle) {
  if (!is_user_alive(pPlayer)) {
    return FMRES_IGNORED;
  }

  new pItem = get_member(pPlayer, m_pActiveItem);
  if (pItem == -1) {
    return FMRES_IGNORED;
  }

  new CW:iHandler = GetHandlerByEntity(pItem);
  if (iHandler == CW_INVALID_HANDLER) {
    return FMRES_IGNORED;
  }

  set_cd(pCdHandle, CD_flNextAttack, get_gametime() + 0.001); // block default animation

  return FMRES_HANDLED;
}

public OnItemSlot(this) {
  new CW:iHandler = GetHandlerByEntity(this);
  if (iHandler == CW_INVALID_HANDLER) {
    return HAM_IGNORED;
  }

  new iSlot = GetData(iHandler, CW_Data_SlotId);
  SetHamReturnInteger(iSlot + 1);

  return HAM_SUPERCEDE;
}

public OnCSItemGetMaxSpeed(this) {  
  new CW:iHandler = GetHandlerByEntity(this);
  if (iHandler == CW_INVALID_HANDLER) {
    return HAM_IGNORED;
  }

  new Float:flMaxSpeed = ExecuteBindedFunction(CWB_GetMaxSpeed, this);
  if (_:flMaxSpeed != PLUGIN_CONTINUE) {
    SetHamReturnFloat(flMaxSpeed);
    return HAM_OVERRIDE;
  }

  return HAM_IGNORED;
}

public OnItemAddToPlayer_Post(this, pPlayer) {
  new pPlayer = GetPlayer(this);
  if (!ExecuteHam(Ham_IsPlayer, pPlayer)) {
    return HAM_IGNORED;
  }

  new CW:iHandler = GetHandlerByEntity(this);
  if (iHandler == CW_INVALID_HANDLER) {
    new iWeaponId = get_member(this, m_iId);
    ResetWeaponList(pPlayer, iWeaponId);
  } else {
    set_member(this, m_Weapon_iPrimaryAmmoType, GetData(iHandler, CW_Data_PrimaryAmmoType));
    UpdateWeaponList(pPlayer, iHandler);
  }

  return HAM_HANDLED;
}

public OnSpawn_Post(this) {
  new CW:iHandler = GetHandlerByEntity(this);
  if (iHandler == CW_INVALID_HANDLER) {
    return HAM_IGNORED;
  }

  ExecuteBindedFunction(CWB_Spawn, this);

  return HAM_IGNORED;
}

public OnWeaponboxSpawn(this) {
  g_pNewWeaponboxEnt = this;
}

public OnPlayerPreThink_Post(pPlayer) {
  if (get_gametime() < g_flNextPredictionUpdate[pPlayer]) {
    return HAM_IGNORED;
  }

  new iObsMode = pev(pPlayer, pev_iuser1);
  new pObsTarget = pev(pPlayer, pev_iuser2);

  new pActiveItem = iObsMode == OBS_IN_EYE
    ? IS_PLAYER(pObsTarget) ? get_member(pObsTarget, m_pActiveItem) : -1
    : get_member(pPlayer, m_pActiveItem);

  if (pActiveItem == -1) {
    SetWeaponPrediction(pPlayer, false);
    return HAM_IGNORED;
  }

  new CW:iHandler = GetHandlerByEntity(pActiveItem);
  SetWeaponPrediction(pPlayer, iHandler == CW_INVALID_HANDLER);

  return HAM_HANDLED;
}

public OnPlayerTakeDamage(pPlayer, pInflictor, pAttacker) {
  if (pAttacker && ExecuteHam(Ham_IsPlayer, pAttacker) && pInflictor == pAttacker) {
    g_pKillerItem = get_member(pAttacker, m_pActiveItem);
  } else {
    g_pKillerItem = pInflictor;
  }
}

public OnPlayerTakeDamage_Post() {
  g_pKillerItem = -1;
}

public OnMessage_DeathMsg(iMsgId, iDest, pPlayer) {
  if (g_pKillerItem == -1) {
    return PLUGIN_CONTINUE;
  }

  new pKiller = get_msg_arg_int(1);
  if (!pKiller) {
    return PLUGIN_CONTINUE;
  }

  if (!ExecuteHam(Ham_IsPlayer, pKiller)) {
    return PLUGIN_CONTINUE;
  }

  if (!is_user_alive(pKiller)) {
    return PLUGIN_CONTINUE;
  }

  new CW:iHandler = GetHandlerByEntity(g_pKillerItem);
  if (iHandler == CW_INVALID_HANDLER) {
    return PLUGIN_CONTINUE;
  }

  static szIcon[64];
  GetStringData(iHandler, CW_Data_Icon, szIcon, charsmax(szIcon));

  if (szIcon[0] == '^0') {
    GetStringData(iHandler, CW_Data_Name, szIcon, charsmax(szIcon));
  }

  set_msg_arg_string(4, szIcon);

  return PLUGIN_CONTINUE;
}

public OnSetModel_Post(this, const szModel[]) {
  if (!pev_valid(this)) {
    return FMRES_IGNORED;
  }

  if (g_pNewWeaponboxEnt == -1) {
    return FMRES_IGNORED;
  }

  if (this != g_pNewWeaponboxEnt) {
    return FMRES_IGNORED;
  }

  static szClassname[32];
  pev(this, pev_classname, szClassname, charsmax(szClassname));

  if (!equal(szClassname, "weaponbox")) {
    g_pNewWeaponboxEnt = -1;
    return FMRES_IGNORED;
  }

  new pItem = FindWeaponBoxSingleItem(this);
  if (pItem == -1) {
    return FMRES_IGNORED;
  }

  new CW:iHandler = GetHandlerByEntity(pItem);
  if (iHandler == CW_INVALID_HANDLER) {
    return FMRES_IGNORED;
  }

  ExecuteBindedFunction(CWB_WeaponBoxModelUpdate, pItem, this);
  g_pNewWeaponboxEnt = -1;

  if (!g_bPrecache) {
    if (!ExecuteHamB(Ham_CS_Item_CanDrop, pItem)) {
      set_pev(this, pev_flags, pev(this, pev_flags) | FL_KILLME);
      dllfunc(DLLFunc_Think, this);
    }
  }

  return FMRES_HANDLED;
}

public OnDecalIndex_Post() {
  if (!g_bPrecache) {
    return;
  }

  ArrayPushCell(g_irgDecals, get_orig_retval());
}

public OnWeaponClCmd(pPlayer) {
  static szName[64];
  read_argv(0, szName, charsmax(szName));

  new CW:iHandler;
  TrieGetCell(g_rgWeaponsMap, szName, iHandler);

  new iWeaponId = GetData(iHandler, CW_Data_Id);

  static szBaseName[32];
  get_weaponname(iWeaponId, szBaseName, charsmax(szBaseName));
  client_cmd(pPlayer, szBaseName);

  return PLUGIN_HANDLED;
}

public OnCanDrop(this) {
  new CW:iHandler = GetHandlerByEntity(this);
  if (iHandler == CW_INVALID_HANDLER) {
    return HAM_IGNORED;
  }

  if (GetHamReturnStatus() >= HAM_OVERRIDE) {
    return GetHamReturnStatus();
  }

  SetHamReturnInteger(
    ExecuteBindedFunction(CWB_CanDrop, this) == PLUGIN_CONTINUE ? 1 : 0
  );

  return HAM_OVERRIDE;
}

public OnMessage_WeaponList(iMsgId, iMsgDest, pPlayer) {
  new iWeaponId = get_msg_arg_int(8);

  if (g_weaponListDefaults[iWeaponId][WL_WeaponId] == iWeaponId) {
    return PLUGIN_CONTINUE; // already initialized
  }

  get_msg_arg_string(1, g_weaponListDefaults[iWeaponId][WL_WeaponName], 31);
  g_weaponListDefaults[iWeaponId][WL_PrimaryAmmoType] = get_msg_arg_int(2);
  g_weaponListDefaults[iWeaponId][WL_PrimaryAmmoMaxAmount] = get_msg_arg_int(3);
  g_weaponListDefaults[iWeaponId][WL_SecondaryAmmoType] = get_msg_arg_int(4);
  g_weaponListDefaults[iWeaponId][WL_SecondaryAmmoMaxAmount] = get_msg_arg_int(5);
  g_weaponListDefaults[iWeaponId][WL_SlotId] = get_msg_arg_int(6);
  g_weaponListDefaults[iWeaponId][WL_NumberInSlot] = get_msg_arg_int(7);
  g_weaponListDefaults[iWeaponId][WL_WeaponId] = iWeaponId;
  g_weaponListDefaults[iWeaponId][WL_Flags] = get_msg_arg_int(9);

  return PLUGIN_CONTINUE;
}

// ANCHOR: Weapon Entity Methods

CompleteReload(this) {
  new CW:iHandler = GetHandlerByEntity(this);
  new CW_Flags:iFlags = GetData(iHandler, CW_Data_Flags);

  if (~iFlags & CWF_CustomReload) {
    new pPlayer = GetPlayer(this);
    new iMaxClip = GetData(iHandler, CW_Data_ClipSize);
    new iClip = get_member(this, m_Weapon_iClip);
    new iPrimaryAmmoIndex = get_member(this, m_Weapon_iPrimaryAmmoType);
    new iBpAmmo = get_member(pPlayer, m_rgAmmo, iPrimaryAmmoIndex);
    new iSize = min(iMaxClip - iClip, iBpAmmo);

    set_member(this, m_Weapon_iClip, iClip + iSize);
    set_member(pPlayer, m_rgAmmo, iBpAmmo - iSize, iPrimaryAmmoIndex);
  }

  set_member(this, m_Weapon_fInReload, 0);

  ExecuteBindedFunction(CWB_DefaultReloadEnd, this);
}

ItemPostFrame(this) {
  new CW:iHandler = GetHandlerByEntity(this);
  new pPlayer = GetPlayer(this);
  new flInReload = get_member(this, m_Weapon_fInReload);
  new iMaxClip = GetData(iHandler, CW_Data_ClipSize);
  new iWeaponFlags = GetData(iHandler, CW_Data_WeaponFlags);
  new Float:flNextAttack = get_member(pPlayer, m_flNextAttack);
  new button = pev(pPlayer, pev_button);
  new iPrimaryAmmoIndex = get_member(this, m_Weapon_iPrimaryAmmoType);
  new iSecondaryAmmoIndex = 0;
  new Float:flNextPrimaryAttack = get_member(this, m_Weapon_flNextPrimaryAttack);
  new Float:flNextSecondaryAttack = get_member(this, m_Weapon_flNextSecondaryAttack);
  new iPrimaryAmmoAmount = get_member(pPlayer, m_rgAmmo, iPrimaryAmmoIndex);
  new iSecondaryAmmoAmount = get_member(pPlayer, m_rgAmmo, iSecondaryAmmoIndex);

  new Float:flReloadEndTime = get_member(this, m_Weapon_flNextReload);
  if (flReloadEndTime && flReloadEndTime < get_gametime()) {
    set_member(this, m_Weapon_flNextReload, 0.0);
    ExecuteBindedFunction(CWB_Pump, this);
  }

  if (flInReload && flNextAttack <= 0.0) {
    CompleteReload(this);
  }

  if ((button & IN_ATTACK2) && flNextSecondaryAttack <= 0) {
    if (iSecondaryAmmoIndex > 0 && !iSecondaryAmmoAmount) {
      set_member(this, m_Weapon_fFireOnEmpty, 1);
    }

    SecondaryAttack(this);
  } else if ((button & IN_ATTACK) && flNextPrimaryAttack <= 0) {
    if ((!get_member(this, m_Weapon_iClip) && iPrimaryAmmoIndex > 0) || (iMaxClip == -1 && !iPrimaryAmmoAmount)) {
      set_member(this, m_Weapon_fFireOnEmpty, 1);
    }

    PrimaryAttack(this);
  } else if ((button & IN_RELOAD) && iMaxClip != WEAPON_NOCLIP && !flInReload) {
    Reload(this);
  } else if (!(button & (IN_ATTACK|IN_ATTACK2))) {
    set_member(this, m_Weapon_fFireOnEmpty, 0);

    if (!IsUseable(this) && flNextPrimaryAttack < 0.0) {
      // if (!(iWeaponFlags & ITEM_FLAG_NOAUTOSWITCHEMPTY) && g_pGameRules->GetNextBestWeapon(m_pPlayer, this)) {
      //   set_member(this, m_Weapon_flNextPrimaryAttack, 0.3);
      //   return;
      // }
    } else {
      if (!get_member(this, m_Weapon_iClip) && !(iWeaponFlags & ITEM_FLAG_NOAUTORELOAD) && flNextPrimaryAttack < 0.0) {
        Reload(this);
        return;
      }
    }

    set_member(this, m_Weapon_iShotsFired, 0);
    WeaponIdle(this);
    return;
  }

  if (ShouldWeaponIdle(this)) {
    WeaponIdle(this);
  }
}

SecondaryAttack(this) {
  if (get_member_game(m_bFreezePeriod)) {
    return;
  }

  ExecuteHamB(Ham_Weapon_SecondaryAttack, this);

  if (g_bSupercede) {
    return;
  }

  if (ExecuteBindedFunction(CWB_SecondaryAttack, this) > PLUGIN_CONTINUE) {
    return;
  }
}

PrimaryAttack(this) {
  if (get_member_game(m_bFreezePeriod)) {
    return;
  }

  ExecuteHamB(Ham_Weapon_PrimaryAttack, this);

  if (g_bSupercede) {
    return;
  }

  if (ExecuteBindedFunction(CWB_PrimaryAttack, this) > PLUGIN_CONTINUE) {
    return;
  }
}

Reload(this) {
  ExecuteHamB(Ham_Weapon_Reload, this);

  if (g_bSupercede) {
    return;
  }
  
  if (ExecuteBindedFunction(CWB_Reload, this) > PLUGIN_CONTINUE) {
    return;
  }
}

WeaponIdle(this) {
  if (get_member(this, m_Weapon_flTimeWeaponIdle) > 0.0) {
    return;
  }

  ExecuteHamB(Ham_Weapon_WeaponIdle, this);

  if (g_bSupercede) {
    return;
  }

  if (ExecuteBindedFunction(CWB_Idle, this) > PLUGIN_CONTINUE) {
    return;
  }
}

WeaponHolster(this) {
  new pPlayer = GetPlayer(this);

  SetWeaponPrediction(pPlayer, true);
  set_member(this, m_Weapon_fInReload, 0);
  set_member(this, m_Weapon_fInSpecialReload, 0);
  set_member(this, m_Weapon_flNextReload, 0.0);

  if (ExecuteBindedFunction(CWB_Holster, this) > PLUGIN_CONTINUE) {
    return;
  }
}

WeaponDeploy(this) {
  if (ExecuteBindedFunction(CWB_Deploy, this) > PLUGIN_CONTINUE) {
    return;
  }

  new pPlayer = GetPlayer(this);

  if (g_bKnifeHolstered[pPlayer]) {
    g_flNextPredictionUpdate[pPlayer] = get_gametime() + 1.0;
  } else if (get_member(this, m_iId) == CSW_KNIFE) {
    SetWeaponPrediction(pPlayer, false);
  }

  // SetThink(this, "DisablePrediction");
  // set_pev(this, pev_nextthink, get_gametime() + 0.1);
}

bool:ShouldWeaponIdle(this) {
  #pragma unused this
  return false;
}

bool:IsUseable(this) {
  new CW:iHandler = GetHandlerByEntity(this);
  new pPlayer = GetPlayer(this);
  new iPrimaryAmmoIndex = get_member(this, m_Weapon_iPrimaryAmmoType);
  new iMaxAmmo1 = GetData(iHandler, CW_Data_PrimaryAmmoMaxAmount);
  new iClip = get_member(this, m_Weapon_iClip);
  new iBpAmmo = get_member(pPlayer, m_rgAmmo, iPrimaryAmmoIndex);

  if (iClip <= 0) {
    if (iBpAmmo <= 0 && iMaxAmmo1 != -1) {
      return false;
    }
  }

  return true;
}

PlayWeaponAnim(this, iSequence, Float:flDuration) {
  SendWeaponAnim(this, iSequence);
  set_member(this, m_Weapon_flTimeWeaponIdle, flDuration);
}

SendWeaponAnim(this, iAnim) {
  new pPlayer = GetPlayer(this);

  SendPlayerWeaponAnim(pPlayer, this, iAnim);

  for (new pSpectator = 1; pSpectator <= MaxClients; pSpectator++) {
    if (pSpectator == pPlayer) {
      continue;
    }
    
    if (!is_user_connected(pSpectator)) {
      continue;
    }

    if (pev(pSpectator, pev_iuser1) != OBS_IN_EYE) {
      continue;
    }

    if (pev(pSpectator, pev_iuser2) != pPlayer) {
      continue;
    }

    SendPlayerWeaponAnim(pSpectator, this, iAnim);
  }
}

SendPlayerWeaponAnim(pPlayer, pWeapon, iAnim) {
  new iBody = pev(pWeapon, pev_body);

  set_pev(pPlayer, pev_weaponanim, iAnim);

  if (!is_user_bot(pPlayer)) {
    emessage_begin(MSG_ONE, SVC_WEAPONANIM, _, pPlayer);
    ewrite_byte(iAnim);
    ewrite_byte(iBody);
    emessage_end();
  }
}

GetPlayer(this) {
  return get_member(this, m_pPlayer);
}

FireBulletsPlayer(this, cShots, Float:vecSrc[3], Float:vecDirShooting[3], Float:vecSpread[3], Float:flDistance, Float:flDamage, Float:flRangeModifier, pAttacker, Float:vecOut[3]) {
  new CW:iHandler = GetHandlerByEntity(this);
  if (iHandler == CW_INVALID_HANDLER) {
    return;
  }

  new pPlayer = GetPlayer(this);
  new shared_rand = pPlayer > 0 ? get_member(pPlayer, random_seed) : 0;
  new CW_Flags:iFlags = GetData(iHandler, CW_Data_Flags);

  new pTr = create_tr2();

  static Float:vecRight[3];
  get_global_vector(GL_v_right, vecRight);

  static Float:vecUp[3];
  get_global_vector(GL_v_up, vecUp);

  static Float:vecMultiplier[3];

  if (!pAttacker) {
    pAttacker = this;  // the default attacker is ourselves
  }

  // ClearMultiDamage();
  // gMultiDamage.type = DMG_BULLET | DMG_NEVERGIB;

  for (new iShot = 1; iShot <= cShots; iShot++) {
    //Use player's random seed.
    // get circular gaussian spread
    vecMultiplier[0] = SharedRandomFloat( shared_rand + iShot, -0.5, 0.5 ) + SharedRandomFloat( shared_rand + ( 1 + iShot ) , -0.5, 0.5 );
    vecMultiplier[1] = SharedRandomFloat( shared_rand + ( 2 + iShot ), -0.5, 0.5 ) + SharedRandomFloat( shared_rand + ( 3 + iShot ), -0.5, 0.5 );
    vecMultiplier[2] = vecMultiplier[0] * vecMultiplier[0] + vecMultiplier[1] * vecMultiplier[1];

    static Float:vecDir[3];
    for (new i = 0; i < 3; ++i) {
      vecDir[i] = vecDirShooting[i] + (vecMultiplier[0] * vecSpread[0] * vecRight[i]) + (vecMultiplier[1] * vecSpread[1] * vecUp[i]);
    }

    static Float:vecEnd[3];
    for (new i = 0; i < 3; ++i) {
      vecEnd[i] = vecSrc[i] + (vecDir[i] * flDistance);
    }

    engfunc(EngFunc_TraceLine, vecSrc, vecEnd, DONT_IGNORE_MONSTERS, this, pTr);

    new Float:flFraction;
    get_tr2(pTr, TR_flFraction, flFraction);
    
    // do damage, paint decals
    if (flFraction != 1.0) {
      new pHit = get_tr2(pTr, TR_pHit);

      if (pHit < 0) {
        pHit = 0;
      }

      new Float:flCurrentDistance = flDistance * flFraction;
      new Float:flCurrentDamage = flDamage * floatpower(flRangeModifier, flCurrentDistance / 500.0);

      rg_multidmg_clear();
      ExecuteHamB(Ham_TraceAttack, pHit, pAttacker, flCurrentDamage, vecDir, pTr, DMG_BULLET | DMG_NEVERGIB);
      rg_multidmg_apply(this, pAttacker);
    
      // TEXTURETYPE_PlaySound(&tr, vecSrc, vecEnd, iBulletType);
      // DecalGunshot( &tr, iBulletType );

      // new iDecalIndex = ExecuteHam(Ham_DamageDecal, pHit, DMG_BULLET);
      // DecalTrace2(pTr, iDecalIndex);

      if (!ExecuteHam(Ham_IsPlayer, pHit)) {
        if (~iFlags & CWF_NoBulletSmoke) {
          BulletSmoke(pTr);
        }
        
        if (~iFlags & CWF_NoBulletDecal) {
          new iDecalIndex = GetDecalIndex(pHit);
          if (iDecalIndex >= 0) {
            MakeDecal(pTr, pHit, iDecalIndex);
          }
        }
      }
    }

    // make bullet trails
    static Float:vecEndPos[3];
    get_tr2(pTr, TR_vecEndPos, vecEndPos);

    BubbleTrail(vecSrc, vecEndPos, floatround((flDistance * flFraction) / 64.0));
  }

  vecOut[0] = vecMultiplier[0] * vecSpread[0];
  vecOut[1] = vecMultiplier[1] * vecSpread[1];
  vecOut[2] = 0.0;

  free_tr2(pTr);
}

GrenadeDetonate(this, Float:flRadius, Float:flMagnitude) {
  static Float:vecStart[3];
  pev(this, pev_origin, vecStart);
  vecStart[2] += 8.0;

  static Float:vecEnd[3];
  xs_vec_copy(vecStart, vecEnd);
  vecEnd[2] -= 40.0;

  new pTr = create_tr2();
  engfunc(EngFunc_TraceLine, vecStart, vecEnd, IGNORE_MONSTERS, this, pTr);
  GrenadeExplode(this, pTr, DMG_GRENADE | DMG_ALWAYSGIB, flRadius, flMagnitude);
  free_tr2(pTr);
}

GrenadeExplode(this, pTr, iDamageBits, Float:flRadius, Float:flMagnitude) {
  new Float:flDamage;
  pev(this, pev_dmg, flDamage);

  set_pev(this, pev_model, NULL_STRING);
  set_pev(this, pev_solid, SOLID_NOT);
  set_pev(this, pev_takedamage, DAMAGE_NO);

  new Float:flFraction;
  get_tr2(pTr, TR_Fraction, flFraction);

  static Float:vecPlaneNormal[3];
  get_tr2(pTr, TR_vecPlaneNormal, vecPlaneNormal);

  static Float:vecOrigin[3];
  pev(this, pev_origin, vecOrigin);

  if (flFraction != 1.0) {
    get_tr2(pTr, TR_vecEndPos, vecOrigin);

    for (new i = 0; i < 3; ++i) {
        vecOrigin[i] += (vecPlaneNormal[i] * (flMagnitude ? flMagnitude : flDamage - 24.0) * 0.6);
    }

    set_pev(this, pev_origin, vecOrigin);
  }
  
  GrenadeExplosion(vecOrigin, flDamage);

  // CSoundEnt::InsertSound ( bits_SOUND_COMBAT, pev->origin, NORMAL_EXPLOSION_VOLUME, 3.0 );
  new iOwner = pev(this, pev_owner);
  set_pev(this, pev_owner, 0);

  _RadiusDamage(vecOrigin, this, iOwner, flDamage, flRadius ? flRadius : flDamage * 3.5, CLASS_NONE, iDamageBits);

  ExplosionDecalTrace(pTr);
  DebrisSound(this);

  set_pev(this, pev_effects, pev(this, pev_effects) | EF_NODRAW);

  // SetThink( &CGrenade::Smoke );
  // GrenadeSmoke(vecOrigin, flDamage);

  set_pev(this, pev_velocity, NULL_VECTOR);
  set_pev(this, pev_nextthink, get_gametime() + 0.1);

  if (PointContents(vecOrigin) != CONTENTS_WATER) {
      new iSparkCount = random(4);
      for (new i = 0; i < iSparkCount; ++i) {
          SparkShower(vecOrigin, vecPlaneNormal, 0);
      }
  }
}

bool:IsWeaponKnife(pWeapon) {
  if (GetHandlerByEntity(pWeapon) != CW_INVALID_HANDLER) {
    return false;
  }

  if (get_member(pWeapon, m_iId) != CSW_KNIFE) {
    return false;
  }

  return true;
}

// ANCHOR: Weapon Callbacks

public Smack(this) {
  new CW:iHandler = GetHandlerByEntity(this);
  new CW_Flags:iFlags = GetData(iHandler, CW_Data_Flags);

  new pTr = pev(this, pev_iuser1);
  new pHit = get_tr2(pTr, TR_pHit);
  if (pHit < 0) {
    pHit = 0;
  }

  if (~iFlags & CWF_NoBulletDecal) {
    new iDecalIndex = GetDecalIndex(pHit);
    if (iDecalIndex >= 0) {
      MakeDecal(pTr, pHit, iDecalIndex, false);
    }
  }

  free_tr2(pTr);

  SetThink(this, NULL_STRING);
}

// public DisablePrediction(this) {
//   new pPlayer = GetPlayer(this);
//   SetWeaponPrediction(pPlayer, false);
//   SetThink(this, NULL_STRING);
// }

// ANCHOR: Weapon Entity Default Methods

bool:DefaultReload(this, iAnim, Float:flDelay) {
  new CW:iHandler = GetHandlerByEntity(this);
  new pPlayer = GetPlayer(this);
  new iPrimaryAmmoIndex = get_member(this, m_Weapon_iPrimaryAmmoType);
  new iPrimaryAmmoAmount = get_member(pPlayer, m_rgAmmo, iPrimaryAmmoIndex);

  if (iPrimaryAmmoAmount <= 0) {
    return false;
  }

  new iClip = get_member(this, m_Weapon_iClip);
  new iClipSize = GetData(iHandler, CW_Data_ClipSize);

  new size = min(iClipSize - iClip, iPrimaryAmmoAmount);
  if (size == 0) {
    return false;
  }

  if (get_member(this, m_Weapon_fInReload)) {
    return false;
  }

  set_member(pPlayer, m_flNextAttack, flDelay);
  set_member(this, m_Weapon_fInReload, 1);

  PlayWeaponAnim(this, iAnim, 3.0);
  rg_set_animation(pPlayer, PLAYER_RELOAD);

  return true;
}

bool:DefaultShotgunReload(this, iStartAnim, iEndAnim, Float:flDelay, Float:flDuration) {
  new pPlayer = GetPlayer(this);
  new iClip = get_member(this, m_Weapon_iClip);
  new iPrimaryAmmoType = get_member(this, m_Weapon_iPrimaryAmmoType);
  new CW:iHandler = GetHandlerByEntity(this);
  new iClipSize = GetData(iHandler, CW_Data_ClipSize);

  if (get_member(pPlayer, m_rgAmmo, iPrimaryAmmoType) <= 0 || iClip == iClipSize) {
    return false;
  }

  // don't reload until recoil is done
  new Float:flNextPrimaryAttack = get_member(this, m_Weapon_flNextPrimaryAttack);
  new flInSpecialReload = get_member(this, m_Weapon_fInSpecialReload);
  if (flNextPrimaryAttack > 0.0) {
    return false;
  }

  new Float:flTimeWeaponIdle = get_member(this, m_Weapon_flTimeWeaponIdle);
  // check to see if we're ready to reload
  if (flInSpecialReload == 0) {
    rg_set_animation(pPlayer, PLAYER_RELOAD);
    PlayWeaponAnim(this, iStartAnim, flDelay);

    set_member(this, m_Weapon_fInSpecialReload, 1);
    set_member(pPlayer, m_flNextAttack, flDelay);
    set_member(this, m_Weapon_flNextPrimaryAttack, 1.0);
    set_member(this, m_Weapon_flNextSecondaryAttack, 1.0);
  } else if (flInSpecialReload == 1) {
    if (flTimeWeaponIdle > 0.0) {
      return false;
    }

    set_member(this, m_Weapon_fInSpecialReload, 2);

    // if (RANDOM_LONG(0,1))
    // EMIT_SOUND_DYN(ENT(m_pPlayer->pev), CHAN_ITEM, "weapons/reload1.wav", 1, ATTN_NORM, 0, 85 + RANDOM_LONG(0,0x1f));
    // else
    // EMIT_SOUND_DYN(ENT(m_pPlayer->pev), CHAN_ITEM, "weapons/reload3.wav", 1, ATTN_NORM, 0, 85 + RANDOM_LONG(0,0x1f));

    PlayWeaponAnim(this, iEndAnim, flDuration);
  } else {
    // Add them to the clip
    set_member(this, m_Weapon_iClip, ++iClip);
    set_member(this, m_Weapon_fInSpecialReload, 1);
    set_member(pPlayer, m_rgAmmo, get_member(pPlayer, m_rgAmmo, iPrimaryAmmoType) - 1, iPrimaryAmmoType);
  }

  return true;
}

bool:DefaultShotgunIdle(this, iAnim, iReloadEndAnim, Float:flDuration, Float:flReloadEndDuration, const szPumpSound[]) {
  new CW:iHandler = GetHandlerByEntity(this);
  if (iHandler == CW_INVALID_HANDLER) {
    return false;
  }

  new Float:flTimeWeaponIdle = get_member(this, m_Weapon_flTimeWeaponIdle);
  if (flTimeWeaponIdle < 0.0) {
    new pPlayer = get_member(this, m_pPlayer);
    new iPrimaryAmmoType = get_member(this, m_Weapon_iPrimaryAmmoType);
    new iPrimaryAmmoAmount = get_member(pPlayer, m_rgAmmo, iPrimaryAmmoType);
    new flInSpecialReload = get_member(this, m_Weapon_fInSpecialReload);
    new iClip = get_member(this, m_Weapon_iClip);
  
    if (!iClip && flInSpecialReload == 0 && iPrimaryAmmoAmount) {
      Reload(this);
    } else if (flInSpecialReload != 0) {
      new iClipSize = GetData(iHandler, CW_Data_ClipSize);
      if (iClip < iClipSize && iPrimaryAmmoAmount) {
        Reload(this);
      } else {
        set_member(this, m_Weapon_fInSpecialReload, 0);
        emit_sound(pPlayer, CHAN_ITEM, szPumpSound, VOL_NORM, ATTN_NORM, 0, PITCH_NORM);
        PlayWeaponAnim(this, iReloadEndAnim, flReloadEndDuration);
      }
    } else {
      PlayWeaponAnim(this, iAnim, flDuration);
    }
  }

  return true;
}

bool:DefaultDeploy(this, const szViewModel[], const szWeaponModel[], iAnim, const szAnimExt[]) {
  // if (!CanDeploy(this)) {
  //   return false;
  // }

  // new CW:iHandler = GetHandlerByEntity(this);
  new pPlayer = GetPlayer(this);
  set_pev(pPlayer, pev_viewmodel2, szViewModel); 
  set_pev(pPlayer, pev_weaponmodel2, szWeaponModel); 

  // strcpy( m_pPlayer->m_szAnimExtention, szAnimExt );
  SendWeaponAnim(this, iAnim);

  if (szAnimExt[0] != '^0') {
    set_member(pPlayer, m_szAnimExtention, szAnimExt);
  }

  set_member(this, m_Weapon_iShotsFired, 0);
  set_member(this, m_Weapon_flTimeWeaponIdle, 1.0);
  set_member(this, m_Weapon_flLastFireTime, 0.0);
  set_member(this, m_Weapon_flDecreaseShotsFired, get_gametime());

  set_member(pPlayer, m_flNextAttack, 0.5);
  set_member(pPlayer, m_iFOV, DEFAULT_FOV);
  set_member(pPlayer, m_iLastZoom, DEFAULT_FOV);
  set_member(pPlayer, m_bResumeZoom, 0);
  set_pev(pPlayer, pev_fov, float(DEFAULT_FOV));

  return true;
}

bool:DefaultShot(this, Float:flDamage, Float:flRangeModifier, Float:flRate, Float:flSpread[3], iShots, Float:flDistance) {
  new iClip = get_member(this, m_Weapon_iClip);
  if (iClip <= 0) {
    return false;
  }

  new pPlayer = GetPlayer(this);

  static Float:vecDirShooting[3];
  MakeAimDir(pPlayer, 1.0, vecDirShooting);

  static Float:vecSrc[3];
  ExecuteHam(Ham_Player_GetGunPosition, pPlayer, vecSrc);

  static Float:vecOut[3];
  FireBulletsPlayer(this, iShots, vecSrc, vecDirShooting, flSpread, flDistance, flDamage, flRangeModifier, pPlayer, vecOut);

  set_member(this, m_Weapon_iClip, --iClip);

  set_member(this, m_Weapon_flNextPrimaryAttack, flRate);
  set_member(this, m_Weapon_flNextSecondaryAttack, flRate);

  new iShotsFired = get_member(this, m_Weapon_iShotsFired);
  set_member(this, m_Weapon_iShotsFired, ++iShotsFired);

  rg_set_animation(pPlayer, PLAYER_ATTACK1);

  return true;
}

bool:DefaultShotgunShot(this, Float:flDamage, Float:flRangeModifier, Float:flRate, Float:flPumpDelay, Float:flSpread[3], iShots, Float:flDistance) {
  new iClip = get_member(this, m_Weapon_iClip);
  if (iClip <= 0) {
    Reload(this);
    if (iClip == 0) {
      // PlayEmptySound();
    }

    return false;
  }

  // m_pPlayer->m_iWeaponVolume = LOUD_GUN_VOLUME;
  // m_pPlayer->m_iWeaponFlash = NORMAL_GUN_FLASH;

  // m_pPlayer->pev->effects = (int)(m_pPlayer->pev->effects) | EF_MUZZLEFLASH;

  if (!DefaultShot(this, flDamage, flRangeModifier, flRate, flSpread, iShots, flDistance)) {
    return false;
  }

  set_member(this, m_Weapon_fInSpecialReload, 0);

  if (iClip != 0) {
    set_member(this, m_Weapon_flNextReload, get_gametime() + flPumpDelay);
  }

  return true;
}

DefaultSwing(this, Float:flDamage, Float:flRate, Float:flDistance) {
  new CW:iHandler = GetHandlerByEntity(this);
  if (iHandler == CW_INVALID_HANDLER) {
    return -1;
  }

  new pPlayer = GetPlayer(this);

  static Float:vecSrc[3];
  ExecuteHam(Ham_Player_GetGunPosition, pPlayer, vecSrc);

  static Float:vecEnd[3];
  MakeAimDir(pPlayer, flDistance, vecEnd);
  xs_vec_add(vecSrc, vecEnd, vecEnd);

  new pTr = create_tr2();
  engfunc(EngFunc_TraceLine, vecSrc, vecEnd, DONT_IGNORE_MONSTERS, this, pTr);

  new Float:flFraction;
  get_tr2(pTr, TR_flFraction, flFraction);

  if (flFraction >= 1.0) {
    engfunc(EngFunc_TraceHull, vecSrc, vecEnd, DONT_IGNORE_MONSTERS, HULL_HEAD, this, pTr);
    get_tr2(pTr, TR_flFraction, flFraction);

    if (flFraction < 1.0) {
      // Calculate the point of interANCHOR of the line (or hull) and the object we hit
      // This is and approximation of the "best" interANCHOR
      new pHit = get_tr2(pTr, TR_pHit);
      if (pHit == -1 || ExecuteHamB(Ham_IsBSPModel, pHit)) {
        FindHullIntersection(vecSrc, pTr, VEC_DUCK_HULL_MIN, VEC_DUCK_HULL_MAX, this);
      }

      get_tr2(pTr, TR_vecEndPos, vecEnd); // This is the point on the actual surface (the hull could have hit space)
      get_tr2(pTr, TR_flFraction, flFraction);
    }
  }

  new iShotsFired = get_member(this, m_Weapon_iShotsFired);
  set_member(this, m_Weapon_iShotsFired, iShotsFired + 1);

  set_member(this, m_Weapon_flNextPrimaryAttack, flRate);

  rg_set_animation(pPlayer, PLAYER_ATTACK1);

  if (flFraction >= 1.0) {
    free_tr2(pTr);
    return -1;
  }

  new pHit = get_tr2(pTr, TR_pHit);
  if (pHit < 0) {
    set_tr2(pTr, TR_pHit, 0);
    pHit = 0;
  }


  // if (get_member(this, m_Weapon_flNextPrimaryAttack) + 1.0 < 0.0) {
  // first swing does full damage
  static Float:vecDir[3];
  xs_vec_sub(vecSrc, vecEnd, vecDir);
  xs_vec_normalize(vecDir, vecDir);

  rg_multidmg_clear();
  ExecuteHamB(Ham_TraceAttack, pHit, pPlayer, flDamage, vecDir, pTr, DMG_CLUB); 
  rg_multidmg_apply(pPlayer, pPlayer);
  // }


  set_pev(this, pev_iuser1, pTr);
  SetThink(this, "Smack");
  set_pev(this, pev_nextthink, get_gametime() + (flRate * 0.5));

  return pHit;
}

// ANCHOR: Weapon Methods

CW:RegisterWeapon(iPluginId, const szName[], iWeaponId, iClipSize, iPrimaryAmmoType, iPrimaryAmmoMaxAmount, iSecondaryAmmoType, iSecondaryAmmoMaxAmount, iSlotId, iPosition, iWeaponFlags, const szIcon[], CW_Flags:iFlags) {
  new CW:iHandler = CreateWeaponData(szName);
  SetData(iHandler, CW_Data_PluginId, iPluginId);
  SetStringData(iHandler, CW_Data_Name, szName);
  SetData(iHandler, CW_Data_Id, iWeaponId);
  SetData(iHandler, CW_Data_ClipSize, iClipSize);
  SetData(iHandler, CW_Data_PrimaryAmmoType, iPrimaryAmmoType);
  SetData(iHandler, CW_Data_PrimaryAmmoMaxAmount, iPrimaryAmmoMaxAmount);
  SetData(iHandler, CW_Data_SecondaryAmmoType, iSecondaryAmmoType);
  SetData(iHandler, CW_Data_SecondaryAmmoMaxAmount, iSecondaryAmmoMaxAmount);
  SetData(iHandler, CW_Data_SlotId, iSlotId);
  SetData(iHandler, CW_Data_Position, iPosition);
  SetData(iHandler, CW_Data_WeaponFlags, iWeaponFlags);
  SetStringData(iHandler, CW_Data_Icon, szIcon);
  SetData(iHandler, CW_Data_Flags, iFlags);

  if (!g_bPrecache && !g_bWeaponHooks[iWeaponId]) { // we are not able to get weapon name in precache state
    RegisterWeaponHooks(iWeaponId);
  }

  register_clcmd(szName, "OnWeaponClCmd");

  return iHandler;
}

CW:GetHandler(const szName[]) {
  new CW:iHandler;
  if (!TrieGetCell(g_rgWeaponsMap, szName, iHandler)) {
    return CW_INVALID_HANDLER;
  }

  return iHandler;
}

CW:GetHandlerByEntity(pEntity) {
  new iToken = pev(pEntity, pev_impulse);

  if (iToken >= TOKEN && iToken < TOKEN + g_iWeaponCount) {
    return CW:(iToken - TOKEN);
  }

  return CW_INVALID_HANDLER;
}

SpawnWeapon(CW:iHandler) {
  new iWeaponId = GetData(iHandler, CW_Data_Id);

  new pEntity = rg_create_entity(g_rgszWeaponNames[iWeaponId], true);
  if (!pEntity) {
    return 0;
  }

  set_pev(pEntity, pev_impulse, TOKEN + _:iHandler);
  dllfunc(DLLFunc_Spawn, pEntity);

  new iPrimaryAmmoType = GetData(iHandler, CW_Data_PrimaryAmmoType);

  set_member(pEntity, m_Weapon_iClip, GetData(iHandler, CW_Data_ClipSize));
  set_member(pEntity, m_Weapon_iPrimaryAmmoType, iPrimaryAmmoType);
  set_member(pEntity, m_Weapon_iDefaultAmmo, 0);
  // set_member(pEntity, m_Weapon_iShell, 0);
  // set_member(pEntity, m_Weapon_bDelayFire, true);
  // set_member(pEntity, m_Weapon_fFireOnEmpty, true);

  ExecuteBindedFunction(CWB_Spawn, pEntity);

  return pEntity;
}

SpawnWeaponBox(CW:iHandler) {
  new pItem = SpawnWeapon(iHandler);
  if (!pItem) {
    return 0;
  }

  set_pev(pItem, pev_spawnflags, pev(pItem, pev_spawnflags) | SF_NORESPAWN);
  set_pev(pItem, pev_effects, EF_NODRAW);
  set_pev(pItem, pev_movetype, MOVETYPE_NONE);
  set_pev(pItem, pev_solid, SOLID_NOT);
  set_pev(pItem, pev_model, 0);
  set_pev(pItem, pev_modelindex, 0);

  new pWeaponBox = rg_create_entity("weaponbox", true);
  if (!pWeaponBox) {
    set_pev(pItem, pev_flags, pev(pItem, pev_flags) | FL_KILLME);
    dllfunc(DLLFunc_Think, pItem);
    return 0;
  }

  dllfunc(DLLFunc_Spawn, pWeaponBox);
  set_pev(pItem, pev_owner, pWeaponBox);

  new iSlot = GetData(iHandler, CW_Data_SlotId);
  set_member(pWeaponBox, m_WeaponBox_rgpPlayerItems, pItem, iSlot + 1);

  dllfunc(DLLFunc_Spawn, pWeaponBox);

  // engfunc(EngFunc_SetSize, pWeaponBox, {-8.0, -8.0, 0.0}, {8.0, 8.0, 4.0});

  return pWeaponBox;
}

// ANCHOR: Player Methods

GiveWeapon(pPlayer, CW:iHandler) {
  new pWeapon = SpawnWeapon(iHandler);
  if (!pWeapon) {
    return;
  }

  if (ExecuteHamB(Ham_AddPlayerItem, pPlayer, pWeapon)) {
    ExecuteHamB(Ham_Item_AttachToPlayer, pWeapon, pPlayer);
    emit_sound(pPlayer, CHAN_ITEM, "items/gunpickup2.wav", VOL_NORM, ATTN_NORM, 0, PITCH_NORM);
  }

  new CW_Flags:iFlags = GetData(iHandler, CW_Data_Flags);

  if (~iFlags & CWF_NotRefillable) {
    new iClipSize = GetData(iHandler, CW_Data_ClipSize);
    new iPrimaryAmmoIndex = GetData(iHandler, CW_Data_PrimaryAmmoType);
    if (iClipSize == WEAPON_NOCLIP && iPrimaryAmmoIndex != -1) {
      set_member(pPlayer, m_rgAmmo, get_member(pPlayer, m_rgAmmo, iPrimaryAmmoIndex) + 1, iPrimaryAmmoIndex);
    }
  }
}

bool:HasWeapon(pPlayer, CW:iHandler) {
  new iSlot = GetData(iHandler, CW_Data_SlotId);
  
  new pItem = get_member(pPlayer, m_rgpPlayerItems, iSlot);
  while (pItem != -1) {
    new pNextItem = get_member(pItem, m_pNext);

    if (CW_GetHandlerByEntity(pItem) == iHandler) {
      return true;
    }

    pItem = pNextItem;
  }

  return false;
}

UpdateWeaponList(pPlayer, CW:iHandler) {
  if (is_user_bot(pPlayer)) {
    return;
  }

  new iWeaponId = GetData(iHandler, CW_Data_Id);

  static szName[64];
  GetStringData(iHandler, CW_Data_Name, szName, charsmax(szName));
  
  new iPrimaryAmmoType = GetData(iHandler, CW_Data_PrimaryAmmoType);
  new iPrimaryAmmoMaxCount = GetData(iHandler, CW_Data_PrimaryAmmoMaxAmount);
  new iSecondaryAmmoType = GetData(iHandler, CW_Data_SecondaryAmmoType);
  new iSecondaryAmmoMaxCount = GetData(iHandler, CW_Data_SecondaryAmmoMaxAmount);
  new iSlotId = GetData(iHandler, CW_Data_SlotId);
  new iPosition = GetData(iHandler, CW_Data_Position);
  new iWeaponFlags = GetData(iHandler, CW_Data_WeaponFlags);

  emessage_begin(MSG_ONE, gmsgWeaponList, _, pPlayer);
  ewrite_string(szName);
  ewrite_byte(iPrimaryAmmoType);
  ewrite_byte(iPrimaryAmmoMaxCount);
  ewrite_byte(iSecondaryAmmoType);
  ewrite_byte(iSecondaryAmmoMaxCount);
  ewrite_byte(iSlotId);
  ewrite_byte(iPosition);
  ewrite_byte(iWeaponId);
  ewrite_byte(iWeaponFlags);
  emessage_end();
}

ResetWeaponList(pPlayer, iWeaponId) {
  if (is_user_bot(pPlayer)) {
    return;
  }

  message_begin(MSG_ONE, gmsgWeaponList, _, pPlayer);
  write_string(g_weaponListDefaults[iWeaponId][WL_WeaponName]);
  write_byte(g_weaponListDefaults[iWeaponId][WL_PrimaryAmmoType]);
  write_byte(g_weaponListDefaults[iWeaponId][WL_PrimaryAmmoMaxAmount]);
  write_byte(g_weaponListDefaults[iWeaponId][WL_SecondaryAmmoType]);
  write_byte(g_weaponListDefaults[iWeaponId][WL_SecondaryAmmoMaxAmount]);
  write_byte(g_weaponListDefaults[iWeaponId][WL_SlotId]);
  write_byte(g_weaponListDefaults[iWeaponId][WL_NumberInSlot]);
  write_byte(g_weaponListDefaults[iWeaponId][WL_WeaponId]);
  write_byte(g_weaponListDefaults[iWeaponId][WL_Flags]);
  message_end();
}

SetWeaponPrediction(pPlayer, bool:bValue) {
  if (is_user_bot(pPlayer)) {
    return;
  }

  new pszInfoBuffer = engfunc(EngFunc_GetInfoKeyBuffer, pPlayer);
  engfunc(EngFunc_SetClientKeyValue, pPlayer, pszInfoBuffer, "cl_lw", bValue ? "1" : "0");

  for (new pSpectator = 1; pSpectator <= MaxClients; pSpectator++) {
    if (pSpectator == pPlayer) {
      continue;
    }

    if (!is_user_connected(pSpectator)) {
      continue;
    }

    if (pev(pSpectator, pev_iuser1) != OBS_IN_EYE) {
      continue;
    }

    if (pev(pSpectator, pev_iuser2) != pPlayer) {
      continue;
    }

    SetWeaponPrediction(pSpectator, false);
  }
}

RemovePlayerItem(pItem) {
  new pPlayer = GetPlayer(pItem);

  new iWeaponId = get_member(pItem, m_iId);

  if (pItem == get_member(pPlayer, m_pActiveItem)) {
    ExecuteHamB(Ham_Weapon_RetireWeapon, pItem);
  }

  ExecuteHamB(Ham_RemovePlayerItem, pPlayer, pItem);
  ExecuteHamB(Ham_Item_Kill, pItem);
  set_pev(pPlayer, pev_weapons, pev(pPlayer, pev_weapons) & ~(1<<iWeaponId));
}

// ANCHOR: Utils

FindWeaponBoxSingleItem(pWeaponBox) {
  new pItem = -1;
  for (new iSlot = 0; iSlot < 6; ++iSlot) {
    new _pItem = get_member(pWeaponBox, m_WeaponBox_rgpPlayerItems, iSlot);
    if (_pItem == -1) {
      continue;
    }

    if (pItem != -1) {
      return -1; // only single item is allowed
    }

    if (get_member(_pItem, m_pNext) != -1) {
      return -1; // only single item is allowed
    }

    pItem = _pItem;
  }

  return pItem;
}

Float:WaterLevel(const Float:vecPosition[3], Float:flMinZ, Float:flMaxZ) {
  static Float:vecMidUp[3];
  xs_vec_copy(vecPosition, vecMidUp);

  vecMidUp[2] = flMinZ;
  if (PointContents(vecMidUp) != CONTENTS_WATER) {
    return flMinZ;
  }

  vecMidUp[2] = flMaxZ;
  if (PointContents(vecMidUp) == CONTENTS_WATER) {
    return flMaxZ;
  }

  new Float:flDiff = flMaxZ - flMinZ;
  while (flDiff > 1.0) {
    vecMidUp[2] = flMinZ + (flDiff / 2.0);

    if (PointContents(vecMidUp) == CONTENTS_WATER) {
      flMinZ = vecMidUp[2];
    } else {
      flMaxZ = vecMidUp[2];
    }

    flDiff = flMaxZ - flMinZ;
  }

  return vecMidUp[2];
}

FindHullIntersection(const Float:vecSrc[3], &pTr, const Float:vecMins[3], const Float:vecMaxs[3], pEntity) {
  new Float:flDistance = 8192.0;

  static Float:rgvecMinsMaxs[2][3];
  for (new i = 0; i < 3; ++i) {
    rgvecMinsMaxs[0][i] = vecMins[i];
    rgvecMinsMaxs[1][i] = vecMaxs[i];
  }

  static Float:vecHullEnd[3];
  get_tr2(pTr, TR_vecEndPos, vecHullEnd);

  for (new i = 0; i < 3; ++i) {
    vecHullEnd[i] = vecSrc[i] + ((vecHullEnd[i] - vecSrc[i]) * 2.0);
  }

  new tmpTrace = create_tr2();
  engfunc(EngFunc_TraceLine, vecSrc, vecHullEnd, DONT_IGNORE_MONSTERS, pEntity, tmpTrace);

  new Float:flFraction;
  get_tr2(tmpTrace, TR_flFraction, flFraction);

  if (flFraction < 1.0) {
    free_tr2(pTr);
    pTr = tmpTrace;
    return;
  }

  static Float:vecEnd[3];
  for (new i = 0; i < 2; i++) {
    for (new j = 0; j < 2; j++) {
      for (new k = 0; k < 2; k++) {
        vecEnd[0] = vecHullEnd[0] + rgvecMinsMaxs[i][0];
        vecEnd[1] = vecHullEnd[1] + rgvecMinsMaxs[j][1];
        vecEnd[2] = vecHullEnd[2] + rgvecMinsMaxs[k][2];

        engfunc(EngFunc_TraceLine, vecSrc, vecEnd, DONT_IGNORE_MONSTERS, pEntity, tmpTrace);
        get_tr2(tmpTrace, TR_flFraction, flFraction);

        new Float:vecEndPos[3];
        get_tr2(tmpTrace, TR_vecEndPos, vecEndPos);

        if (flFraction < 1.0) {
          new Float:flThisDistance = get_distance_f(vecEndPos, vecSrc);
          if (flThisDistance < flDistance) {
            free_tr2(pTr);
            pTr = tmpTrace;
            flDistance = flThisDistance;
          }
        }
      }
    }
  }
}

_RadiusDamage(const Float:vecOrigin[3], iInflictor, pAttacker, Float:flDamage, Float:flRadius, iClassIgnore, iDamageBits) {
  #pragma unused iClassIgnore

  static Float:vecSrc[3];
  xs_vec_copy(vecOrigin, vecSrc);

  new Float:flFalloff = flRadius ? (flDamage / flRadius) : 1.0;
  new bool:bInWater = (PointContents(vecSrc) == CONTENTS_WATER);

  vecSrc[2] += 1.0; // in case grenade is lying on the ground

  if (!pAttacker) {
    pAttacker = iInflictor;
  }

  new pTr = create_tr2();

  new pEntity;
  new pPrevEntity;
  while ((pEntity = engfunc(EngFunc_FindEntityInSphere, pEntity, vecSrc, flRadius)) != 0) {
    if (pPrevEntity >= pEntity) {
      break;
    }

    pPrevEntity = pEntity;

    if (!pev_valid(pEntity)) {
      continue;
    }

    if (ExecuteHam(Ham_IsPlayer, pEntity) && !rg_is_player_can_takedamage(pEntity, pAttacker)) {
      continue;
    }

    if (pev(pEntity, pev_takedamage) == DAMAGE_NO) {
      continue;
    }

    static szClassname[32];
    pev(pEntity, pev_classname, szClassname, charsmax(szClassname));

    // UNDONE: this should check a damage mask, not an ignore
    // if ( iClassIgnore != CLASS_NONE && pEntity->Classify() == iClassIgnore ) {// houndeyes don't hurt other houndeyes with their attack
    //   continue;
    // }

    new iWaterLevel = pev(pEntity, pev_waterlevel);

    if (bInWater && iWaterLevel == 0) {
      continue;
    }

    if (!bInWater && iWaterLevel == 3) {
      continue;
    }

    static Float:vecSpot[3];
    ExecuteHamB(Ham_BodyTarget, pEntity, vecSrc, vecSpot);
    engfunc(EngFunc_TraceLine, vecSrc, vecSpot, IGNORE_MONSTERS, iInflictor, pTr);

    static Float:flFraction;
    get_tr2(pTr, TR_flFraction, flFraction);

    if (flFraction != 1.0 && get_tr2(pTr, TR_pHit) != pEntity) {
      continue;
    }

    if (get_tr2(pTr, TR_StartSolid)) {
      set_tr2(pTr, TR_vecEndPos, vecSrc);
      set_tr2(pTr, TR_flFraction, 0.0);
      flFraction = 0.0;
    }

    static Float:vecEnd[3];
    get_tr2(pTr, TR_vecEndPos, vecEnd);

    new Float:flAdjustedDamage = flDamage - (get_distance_f(vecSrc, vecEnd) * flFalloff);

    if (flAdjustedDamage < 0.0) {
      flAdjustedDamage = 0.0;
    }

    if (flFraction != 1.0) {
      static Float:vecDir[3];
      xs_vec_sub(vecEnd, vecSrc, vecDir);
      xs_vec_normalize(vecDir, vecDir);

      rg_multidmg_clear();
      ExecuteHamB(Ham_TraceAttack, pEntity, iInflictor, flAdjustedDamage, vecDir, pTr, iDamageBits);
      rg_multidmg_apply(iInflictor, pAttacker);
    } else {
      ExecuteHamB(Ham_TakeDamage, pEntity, iInflictor, pAttacker, flAdjustedDamage, iDamageBits);
    }
  }

  free_tr2(pTr);
}

MakeAimDir(pPlayer, Float:flDistance, Float:vecOut[3]) {
  static Float:vecAngles[3];
  pev(pPlayer, pev_v_angle, vecAngles);
  engfunc(EngFunc_MakeVectors, vecAngles);

  get_global_vector(GL_v_forward, vecOut);
  xs_vec_mul_scalar(vecOut, flDistance, vecOut);
}

GetDecalIndex(pEntity) {
  new iDecalIndex = ExecuteHamB(Ham_DamageDecal, pEntity, 0);
  if (iDecalIndex < 0) {
    return -1;
  }

  iDecalIndex = ArrayGetCell(g_irgDecals, iDecalIndex);

  if (iDecalIndex == engfunc(EngFunc_DecalIndex, "{break1")
    || iDecalIndex == engfunc(EngFunc_DecalIndex, "{break2")
    || iDecalIndex == engfunc(EngFunc_DecalIndex, "{break3")) {
    return engfunc(EngFunc_DecalIndex, "{bproof1");
  }

  return iDecalIndex;
}

// ANCHOR: Storages

InitStorages() {
  g_rgWeapons[CW_Data_Name] = ArrayCreate(64, 1);
  g_rgWeapons[CW_Data_Icon] = ArrayCreate(16, 1);

  for (new i = 0; i < _:CW_Data; ++i) {
    if (!g_rgWeapons[CW_Data:i]) {
      g_rgWeapons[CW_Data:i] = ArrayCreate(1, 1);
    }
  }

  g_rgWeaponsMap = TrieCreate();

  g_irgDecals = ArrayCreate();
}

DestroyStorages() {
  for (new CW:iHandler = CW:0; _:iHandler < g_iWeaponCount; ++iHandler) {
    DestroyWeaponData(iHandler);
  }

  for (new i = 0; i < _:CW_Data; ++i) {
      ArrayDestroy(Array:g_rgWeapons[CW_Data:i]);
  }

  TrieDestroy(g_rgWeaponsMap);

  ArrayDestroy(g_irgDecals);
}

// ANCHOR: Weapon Data

CW:CreateWeaponData(const szName[]) {
  new CW:iHandler = CW:g_iWeaponCount;

  for (new iParam = 0; iParam < _:CW_Data; ++iParam) {
    ArrayPushCell(Array:g_rgWeapons[CW_Data:iParam], 0);
  }

  TrieSetCell(g_rgWeaponsMap, szName, iHandler);

  InitBindings(iHandler);

  g_iWeaponCount++;

  return iHandler;
}

DestroyWeaponData(CW:iHandler) {
  DestroyBindings(iHandler);
}

any:GetData(CW:iHandler, CW_Data:iParam) {
  return ArrayGetCell(Array:g_rgWeapons[iParam], _:iHandler);
}

GetStringData(CW:iHandler, CW_Data:iParam, szOut[], iLen) {
  ArrayGetString(Array:g_rgWeapons[iParam], _:iHandler, szOut, iLen);
}

SetData(CW:iHandler, CW_Data:iParam, any:value) {
  ArraySetCell(Array:g_rgWeapons[iParam], _:iHandler, value);
}

SetStringData(CW:iHandler, CW_Data:iParam, const szValue[]) {
  ArraySetString(Array:g_rgWeapons[iParam], _:iHandler, szValue);
}

// ANCHOR: Weapon Bindings

Array:InitBindings(CW:iHandler) {
  new Array:irgBindings = ArrayCreate(Function, _:CW_Binding);
  for (new i = 0; i < _:CW_Binding; ++i) {
    new rgBinding[Function]= {-1, -1};
    ArrayPushArray(irgBindings, rgBinding);
  }

  SetData(iHandler, CW_Data_Bindings, irgBindings);
}

DestroyBindings(CW:iHandler) {
  new Array:irgBindings = GetData(iHandler, CW_Data_Bindings);
  ArrayDestroy(irgBindings);
}

Bind(CW:iHandler, iBinding, iPluginId, iFunctionid) {
  new rgBinding[Function];
  rgBinding[Function_PluginId] = iPluginId;
  rgBinding[Function_FunctionId] = iFunctionid;

  new Array:irgBindings = GetData(iHandler, CW_Data_Bindings);
  ArraySetArray(irgBindings, iBinding, rgBinding);
}

GetBinding(CW:iHandler, CW_Binding:iBinding, &iPluginId, &iFunctionId) {
  new Array:iszBindings = GetData(iHandler, CW_Data_Bindings);

  static rgBinding[Function];
  ArrayGetArray(iszBindings, _:iBinding, rgBinding, sizeof(rgBinding));

  if (rgBinding[Function_PluginId] == -1) {
    return false;
  }

  if (rgBinding[Function_FunctionId] == -1) {
    return false;
  }

  iPluginId = rgBinding[Function_PluginId];
  iFunctionId = rgBinding[Function_FunctionId];

  return true;
}

any:ExecuteBindedFunction(CW_Binding:iBinding, this, any:...) {
  new CW:iHandler = GetHandlerByEntity(this);

  new iPluginId, iFunctionId;
  if (!GetBinding(iHandler, iBinding, iPluginId, iFunctionId)) {
    return PLUGIN_CONTINUE;
  }

  if (callfunc_begin_i(iFunctionId, iPluginId) == 1)  {
    callfunc_push_int(this);
  
    if (iBinding == CWB_WeaponBoxModelUpdate) {
      new pWeaponBox = getarg(2);
      callfunc_push_int(pWeaponBox);
    }

    return callfunc_end();
  }
  
  return PLUGIN_CONTINUE;
}

// ANCHOR: Weapon Hooks

InitWeaponHooks() {
  for (new CW:iHandler = CW:0; _:iHandler < g_iWeaponCount; ++iHandler) {
    new iWeaponId = GetData(iHandler, CW_Data_Id);
    if (!g_bWeaponHooks[iWeaponId]) {
      RegisterWeaponHooks(iWeaponId);
    }
  }
}

RegisterWeaponHooks(iWeaponId) {
  new szClassname[32];
  get_weaponname(iWeaponId, szClassname, charsmax(szClassname));

  RegisterHam(Ham_Item_PostFrame, szClassname, "OnItemPostFrame", .Post = 0);
  RegisterHam(Ham_Item_ItemSlot, szClassname, "OnItemSlot", .Post = 0);
  RegisterHam(Ham_Item_Holster, szClassname, "OnItemHolster", .Post = 0);
  RegisterHam(Ham_Item_Deploy, szClassname, "OnItemDeploy", .Post = 0);
  RegisterHam(Ham_CS_Item_GetMaxSpeed, szClassname, "OnCSItemGetMaxSpeed", .Post = 0);
  // RegisterHam(Ham_Weapon_PlayEmptySound, szClassname, "OnWeaponPlayEmptySound", .Post = 0);
  RegisterHam(Ham_Item_AddToPlayer, szClassname, "OnItemAddToPlayer_Post", .Post = 1);
  RegisterHam(Ham_Spawn, szClassname, "OnSpawn_Post", .Post = 1);
  RegisterHam(Ham_CS_Item_CanDrop, szClassname, "OnCanDrop");
  // RegisterHam(Ham_Item_GetItemInfo, szClassname, "OnItemGetItemInfo", .Post = 1);
  RegisterHam(Ham_Weapon_PrimaryAttack, szClassname, "OnWeaponPrimaryAttack");
  RegisterHam(Ham_Weapon_SecondaryAttack, szClassname, "OnWeaponSecondaryAttack");
  RegisterHam(Ham_Weapon_Reload, szClassname, "OnWeaponReload");
  RegisterHam(Ham_Weapon_WeaponIdle, szClassname, "OnWeaponIdle");

  g_bWeaponHooks[iWeaponId] = true;
}

// ANCHOR: Effects

SparkShower(const Float:vecOrigin[3], const Float:vecAngles[3], iOwner) {
  new pSparkShower = engfunc(EngFunc_CreateNamedEntity, engfunc(EngFunc_AllocString, "spark_shower"));
  if (!pSparkShower) {
    return;
  }

  engfunc(EngFunc_SetOrigin, pSparkShower, vecOrigin);
  set_pev(pSparkShower, pev_angles, vecAngles);
  set_pev(pSparkShower, pev_owner, iOwner);
  dllfunc(DLLFunc_Spawn, pSparkShower);
}

GrenadeExplosion(const Float:vecOrigin[3], Float:flDamage) {
  new iModelIndex = PointContents(vecOrigin) != CONTENTS_WATER
      ? engfunc(EngFunc_ModelIndex, "sprites/zerogxplode.spr")
      : engfunc(EngFunc_ModelIndex, "sprites/WXplo1.spr");

  new iScale = floatround((flDamage - 50.0) * 0.60);

  if (iScale < 8) {
      iScale = 8;
  }

  if (iScale > 255) {
    iScale = 255;
  }

  engfunc(EngFunc_MessageBegin, MSG_PAS, SVC_TEMPENTITY, vecOrigin, 0);
  write_byte(TE_EXPLOSION);
  engfunc(EngFunc_WriteCoord, vecOrigin[0]);
  engfunc(EngFunc_WriteCoord, vecOrigin[1]);
  engfunc(EngFunc_WriteCoord, vecOrigin[2]);
  write_short(iModelIndex);
  write_byte(iScale);
  write_byte(15);
  write_byte(TE_EXPLFLAG_NONE);
  message_end();
}

GrenadeSmoke(pGrenade) {
  static Float:vecOrigin[3];
  pev(pGrenade, pev_origin, vecOrigin);

  static Float:flDamage;
  pev(pGrenade, pev_dmg, flDamage);

  if (PointContents(vecOrigin) == CONTENTS_WATER) {
    static Float:vecSize[3] = {64.0, 64.0, 64.0};

    static Float:vecMins[3];
    xs_vec_sub(vecOrigin, vecSize, vecMins);

    static Float:vecMaxs[3];
    xs_vec_add(vecOrigin, vecSize, vecMaxs);

    Bubbles(vecMins, vecMaxs, 100);
  } else {
    new iModelIndex = engfunc(EngFunc_ModelIndex, "sprites/steam1.spr");

    new Float:flRadius = (flDamage - 50.0) * 0.80;
    if (flRadius < 8.0) {
        flRadius = 9.0;
    }
      
    engfunc(EngFunc_MessageBegin, MSG_PAS, SVC_TEMPENTITY, vecOrigin, 0);
    write_byte(TE_SMOKE);
    engfunc(EngFunc_WriteCoord, vecOrigin[0]);
    engfunc(EngFunc_WriteCoord, vecOrigin[1]);
    engfunc(EngFunc_WriteCoord, vecOrigin[2]);
    write_short(iModelIndex);
    write_byte(floatround(flRadius)); // scale * 10
    write_byte(12); // framerate
    message_end();
  }
}

Bubbles(const Float:vecMins[3], const Float:vecMaxs[3], iCount) {
  static Float:vecMid[3];
  for (new i = 0; i < 3; ++i) {
    vecMid[i] = (vecMins[i] + vecMaxs[i]) * 0.5;
  }

  new Float:flHeight = WaterLevel(vecMid, vecMid[2], vecMid[2] + 1024.0) - vecMins[2];
  new iModelIndex = engfunc(EngFunc_ModelIndex, "sprites/bubble.spr");

  engfunc(EngFunc_MessageBegin, MSG_PAS, SVC_TEMPENTITY, vecMid, 0);
  write_byte(TE_BUBBLES);
  engfunc(EngFunc_WriteCoord, vecMins[0]);
  engfunc(EngFunc_WriteCoord, vecMins[1]);
  engfunc(EngFunc_WriteCoord, vecMins[2]);
  engfunc(EngFunc_WriteCoord, vecMaxs[0]);
  engfunc(EngFunc_WriteCoord, vecMaxs[1]);
  engfunc(EngFunc_WriteCoord, vecMaxs[2]);
  engfunc(EngFunc_WriteCoord, flHeight); // height
  write_short(iModelIndex);
  write_byte(iCount); // count
  write_coord(8); // speed
  message_end();
}

DecalTrace(pTr, iDecal) {
  if (iDecal < 0) {
    return;
  }

  new Float:flFraction;
  get_tr2(pTr, TR_flFraction, flFraction);

  if (flFraction == 1.0) {
    return;
  }

  // Only decal BSP models
  new pHit = get_tr2(pTr, TR_pHit);
  if (pHit != -1) {
    if (pHit && !ExecuteHam(Ham_IsBSPModel, pHit)) {
      return;
    }
  } else {
    pHit = 0;
  }

  new iMessage = TE_DECAL;
  if (pHit != 0) {
    if (iDecal > 255) {
      iMessage = TE_DECALHIGH;
      iDecal -= 256;
    }
  } else {
    iMessage = TE_WORLDDECAL;
    if (iDecal > 255) {
      iMessage = TE_WORLDDECALHIGH;
      iDecal -= 256;
    }
  }

  static Float:vecEndPos[3];
  get_tr2(pTr, TR_vecEndPos, vecEndPos);
  
  engfunc(EngFunc_MessageBegin, MSG_BROADCAST, SVC_TEMPENTITY, vecEndPos, 0);
  write_byte(iMessage);
  engfunc(EngFunc_WriteCoord, vecEndPos[0]);
  engfunc(EngFunc_WriteCoord, vecEndPos[1]);
  engfunc(EngFunc_WriteCoord, vecEndPos[2]);
  write_byte(iDecal);
  if (pHit) {
    write_short(pHit);
  }
  message_end();
}

BulletSmoke(pTr) {
  static Float:vecSrc[3];
  get_tr2(pTr, TR_vecEndPos, vecSrc);

  static Float:vecEnd[3];
  get_tr2(pTr, TR_vecPlaneNormal, vecEnd);
  xs_vec_mul_scalar(vecEnd, 2.5, vecEnd);
  xs_vec_add(vecSrc, vecEnd, vecEnd);

  static iModelIndex;
  if (!iModelIndex) {
    iModelIndex = engfunc(EngFunc_ModelIndex, WALL_PUFF_SPRITE);
  }

  engfunc(EngFunc_MessageBegin, MSG_PAS, SVC_TEMPENTITY, vecEnd, 0);
  write_byte(TE_EXPLOSION);
  engfunc(EngFunc_WriteCoord, vecEnd[0]);
  engfunc(EngFunc_WriteCoord, vecEnd[1]);
  engfunc(EngFunc_WriteCoord, vecEnd[2] - 10.0);
  write_short(iModelIndex);
  write_byte(5);
  write_byte(50);
  write_byte(TE_EXPLFLAG_NODLIGHTS | TE_EXPLFLAG_NOSOUND | TE_EXPLFLAG_NOPARTICLES);
  message_end();
}

MakeDecal(pTr, pEntity, iDecalIndex, bool:bGunshotDecal = true) {
  static vecOrigin[3];
  get_tr2(pTr, TR_vecEndPos, vecOrigin);

  new pHit;
  get_tr2(pTr, TR_pHit, pHit);
    
  if(pHit) {
    emessage_begin(MSG_BROADCAST, SVC_TEMPENTITY);
    ewrite_byte(TE_DECAL);
    engfunc(EngFunc_WriteCoord, vecOrigin[0]);
    engfunc(EngFunc_WriteCoord, vecOrigin[1]);
    engfunc(EngFunc_WriteCoord, vecOrigin[2]);
    ewrite_byte(iDecalIndex);
    ewrite_short(pHit);
    emessage_end();
  } else {
    emessage_begin(MSG_BROADCAST, SVC_TEMPENTITY);
    ewrite_byte(TE_WORLDDECAL);
    engfunc(EngFunc_WriteCoord, vecOrigin[0]);
    engfunc(EngFunc_WriteCoord, vecOrigin[1]);
    engfunc(EngFunc_WriteCoord, vecOrigin[2]);
    ewrite_byte(iDecalIndex);
    emessage_end();
  }

  if (bGunshotDecal) {
    message_begin(MSG_BROADCAST, SVC_TEMPENTITY);
    write_byte(TE_GUNSHOTDECAL);
    engfunc(EngFunc_WriteCoord, vecOrigin[0]);
    engfunc(EngFunc_WriteCoord, vecOrigin[1]);
    engfunc(EngFunc_WriteCoord, vecOrigin[2]);
    write_short(pEntity);
    write_byte(iDecalIndex);
    message_end();
  }
}

BubbleTrail(const Float:from[3], const Float:to[3], count) {
  new Float:flHeight = WaterLevel(from, from[2], from[2] + 256);
  flHeight = flHeight - from[2];

  if (flHeight < 8) {
    flHeight = WaterLevel(to, to[2], to[2] + 256.0);
    flHeight = flHeight - to[2];
    if (flHeight < 8) {
      return;
    }

    // UNDONE: do a ploink sound
    flHeight = flHeight + to[2] - from[2];
  }

  if (count > 255) {
    count = 255;
  }

  static g_sModelIndexBubbles;
  if (!g_sModelIndexBubbles) {
    g_sModelIndexBubbles = engfunc(EngFunc_ModelIndex, "sprites/bubble.spr");
  }

  engfunc(EngFunc_MessageBegin, MSG_BROADCAST, SVC_TEMPENTITY, from, 0);
  write_byte(TE_BUBBLETRAIL);
  engfunc(EngFunc_WriteCoord, from[0]);
  engfunc(EngFunc_WriteCoord, from[1]);
  engfunc(EngFunc_WriteCoord, from[2]);
  engfunc(EngFunc_WriteCoord, to[0]);
  engfunc(EngFunc_WriteCoord, to[1]);
  engfunc(EngFunc_WriteCoord, to[2]);
  engfunc(EngFunc_WriteCoord, flHeight);
  write_short(g_sModelIndexBubbles);
  write_byte(count);
  write_coord(8);
  message_end();
}

ExplosionDecalTrace(pTr) {
  switch (random(3)) {
    case 0: {
      DecalTrace(pTr, engfunc(EngFunc_DecalIndex, "{scorch1"));
    }
    case 1: {
      DecalTrace(pTr, engfunc(EngFunc_DecalIndex, "{scorch2"));
    }
    case 2: {
      DecalTrace(pTr, engfunc(EngFunc_DecalIndex, "{scorch3"));
    }
  }
}

DebrisSound(pEntity) {
  switch (random(3)) {
    case 0: {
      emit_sound(pEntity, CHAN_VOICE, "weapons/debris1.wav", 0.55, ATTN_NORM, 0, PITCH_NORM);
    }
    case 1: {
      emit_sound(pEntity, CHAN_VOICE, "weapons/debris2.wav", 0.55, ATTN_NORM, 0, PITCH_NORM);
    }
    case 2: {
      emit_sound(pEntity, CHAN_VOICE, "weapons/debris3.wav", 0.55, ATTN_NORM, 0, PITCH_NORM);
    }
  }
}

bool:EjectWeaponBrass(this, iModelIndex, iSoundType) {
  new pPlayer = GetPlayer(this);

  if (!iModelIndex) {
    return false;
  }
  
  static Float:vecViewOfs[3];
  pev(pPlayer, pev_view_ofs, vecViewOfs);

  static Float:vecAngles[3];
  pev(pPlayer, pev_angles, vecAngles);

  static Float:vecUp[3];
  angle_vector(vecAngles, ANGLEVECTOR_UP, vecUp);

  static Float:vecForward[3];
  angle_vector(vecAngles, ANGLEVECTOR_FORWARD, vecForward);
  
  static Float:vecRight[3];
  angle_vector(vecAngles, ANGLEVECTOR_RIGHT, vecRight);
  
  static Float:vecOrigin[3];
  pev(pPlayer, pev_origin, vecOrigin);

  for (new i = 0; i < 3; ++i) {
    vecOrigin[i] = vecOrigin[i] + vecViewOfs[i] + (vecUp[i] * -9.0) + (vecForward[i] * 16.0);
  }

  static Float:vecVelocity[3];
  pev(pPlayer, pev_velocity, vecVelocity);

  for (new i = 0; i < 3; ++i) {
    vecVelocity[i] = vecVelocity[i] + (vecRight[i] * random_float(50.0, 70.0)) + (vecUp[i] * random_float(100.0, 150.0)) + (vecForward[i] * 25.0);
  }

  engfunc(EngFunc_MessageBegin, MSG_PVS, SVC_TEMPENTITY, vecOrigin, 0);
  write_byte(TE_MODEL);
  engfunc(EngFunc_WriteCoord, vecOrigin[0]);
  engfunc(EngFunc_WriteCoord, vecOrigin[1]);
  engfunc(EngFunc_WriteCoord, vecOrigin[2]);
  engfunc(EngFunc_WriteCoord, vecVelocity[0]);
  engfunc(EngFunc_WriteCoord, vecVelocity[1]);
  engfunc(EngFunc_WriteCoord, vecVelocity[2]);
  write_angle(floatround(vecAngles[1]));
  write_short(iModelIndex);
  write_byte(iSoundType);
  write_byte(25);
  message_end();

  return true;
}

// ANCHOR: Random

new const seed_table[256] = {
  28985, 27138, 26457, 9451, 17764, 10909, 28790, 8716, 6361, 4853, 17798, 21977, 19643, 20662, 10834, 20103,
  27067, 28634, 18623, 25849, 8576, 26234, 23887, 18228, 32587, 4836, 3306, 1811, 3035, 24559, 18399, 315,
  26766, 907, 24102, 12370, 9674, 2972, 10472, 16492, 22683, 11529, 27968, 30406, 13213, 2319, 23620, 16823,
  10013, 23772, 21567, 1251, 19579, 20313, 18241, 30130, 8402, 20807, 27354, 7169, 21211, 17293, 5410, 19223,
  10255, 22480, 27388, 9946, 15628, 24389, 17308, 2370, 9530, 31683, 25927, 23567, 11694, 26397, 32602, 15031,
  18255, 17582, 1422, 28835, 23607, 12597, 20602, 10138, 5212, 1252, 10074, 23166, 19823, 31667, 5902, 24630,
  18948, 14330, 14950, 8939, 23540, 21311, 22428, 22391, 3583, 29004, 30498, 18714, 4278, 2437, 22430, 3439,
  28313, 23161, 25396, 13471, 19324, 15287, 2563, 18901, 13103, 16867, 9714, 14322, 15197, 26889, 19372, 26241,
  31925, 14640, 11497, 8941, 10056, 6451, 28656, 10737, 13874, 17356, 8281, 25937, 1661, 4850, 7448, 12744,
  21826, 5477, 10167, 16705, 26897, 8839, 30947, 27978, 27283, 24685, 32298, 3525, 12398, 28726, 9475, 10208,
  617, 13467, 22287, 2376, 6097, 26312, 2974, 9114, 21787, 28010, 4725, 15387, 3274, 10762, 31695, 17320,
  18324, 12441, 16801, 27376, 22464, 7500, 5666, 18144, 15314, 31914, 31627, 6495, 5226, 31203, 2331, 4668,
  12650, 18275, 351, 7268, 31319, 30119, 7600, 2905, 13826, 11343, 13053, 15583, 30055, 31093, 5067, 761,
  9685, 11070, 21369, 27155, 3663, 26542, 20169, 12161, 15411, 30401, 7580, 31784, 8985, 29367, 20989, 14203,
  29694, 21167, 10337, 1706, 28578, 887, 3373, 19477, 14382, 675, 7033, 15111, 26138, 12252, 30996, 21409,
  25678, 18555, 13256, 23316, 22407, 16727, 991, 9236, 5373, 29402, 6117, 15241, 27715, 19291, 19888, 19847
};

Float:SharedRandomFloat(seed, Float:low, Float:high) {
  new Float:range = high - low;
  if (!range) {
    return low;
  }

  new glSeed = U_Srand(seed + floatround(low) + floatround(high));
  U_Random(glSeed);
  U_Random(glSeed);

  new tensixrand = U_Random(glSeed) & 65535;
  new Float:offset = float(tensixrand) / 65536.0;

  return (low + offset * range );
}

U_Random(&glSeed)  {
  glSeed *= 69069; 
  glSeed += seed_table[glSeed & 0xff];

  return (++glSeed & 0x0fffffff);
}

U_Srand(seed) {
  return seed_table[seed & 0xff];
}

// FireEvent(pTr, const szSnd[], const szShellModel[]) {
//   static Float:flFraction;
//   get_tr2(pTr, TR_flFraction, flFraction);

//   new pHit = get_tr2(pTr, TR_pHit);

//   if (flFraction != 1.0) {
//      // Native_PlaySoundAtPosition( $origin = $trace_endpos, $sound = weapons/bullet_hit1.wav );
//      // Native_ImpactParticles( $origin = $trace_endpos );
//      // Native_PlaceDecal( $origin = $trace_endpos, $decal = "{shot2", $trace_entity );

//      new iDecalIndex = random_num(get_decal_index("{shot1"), get_decal_index("{shot5") + 1);
//      MakeDecal(pTr, pHit, iDecalIndex);
//   }
// }

// BeamPoints(const Float:vecStart[3], const Float:vecEnd[3], const color[3]) {
//     message_begin(MSG_BROADCAST ,SVC_TEMPENTITY);
//     write_byte(TE_BEAMPOINTS);
//     write_coord(floatround(vecStart[0])); // start position
//     write_coord(floatround(vecStart[1]));
//     write_coord(floatround(vecStart[2]));
//     write_coord(floatround(vecEnd[0])); // end position
//     write_coord(floatround(vecEnd[1]));
//     write_coord(floatround(vecEnd[2]));
//     write_short(engfunc(EngFunc_ModelIndex, "sprites/laserbeam.spr")); // sprite index
//     write_byte(0); // starting frame
//     write_byte(10); // frame rate in 0.1's
//     write_byte(30); // life in 0.1's
//     write_byte(2); // line width in 0.1's
//     write_byte(1); // noise amplitude in 0.01's
//     write_byte(color[0]); // Red
//     write_byte(color[1]); // Green
//     write_byte(color[2]); // Blue
//     write_byte(127); // brightness
//     write_byte(10); // scroll speed in 0.1's
//     message_end();
// }
