// This is a beta version, some functions may be unstable. Use at your own risk.

#if defined _api_custom_weapons_included
  #endinput
#endif
#define _api_custom_weapons_included

#pragma reqlib api_custom_weapons

#define WEAPON_NOCLIP -1
#define CW_INVALID_HANDLER CW:-1

#define DEFAULT_FOV 90

#define VECTOR_CONE_1DEGREES {0.00873, 0.00873, 0.00873}
#define VECTOR_CONE_2DEGREES {0.01745, 0.01745, 0.01745}
#define VECTOR_CONE_3DEGREES {0.02618, 0.02618, 0.02618}
#define VECTOR_CONE_4DEGREES {0.03490, 0.03490, 0.03490}
#define VECTOR_CONE_5DEGREES {0.04362, 0.04362, 0.04362}
#define VECTOR_CONE_6DEGREES {0.05234, 0.05234, 0.05234}
#define VECTOR_CONE_7DEGREES {0.06105, 0.06105, 0.06105}
#define VECTOR_CONE_8DEGREES {0.06976, 0.06976, 0.06976}
#define VECTOR_CONE_9DEGREES {0.07846, 0.07846, 0.07846}
#define VECTOR_CONE_10DEGREES {0.08716, 0.08716, 0.08716}
#define VECTOR_CONE_15DEGREES {0.13053, 0.13053, 0.13053}
#define VECTOR_CONE_20DEGREES {0.17365, 0.17365, 0.17365}
#define VECTOR_CONE_DM_SHOTGUN {0.08716, 0.04362, 0.00}
#define VECTOR_CONE_DM_DOUBLESHOTGUN {0.17365, 0.04362, 0.00}

enum CW_Data {
  CW_Data_PluginId,
  CW_Data_Name,
  CW_Data_Icon,
  CW_Data_Id,
  CW_Data_ClipSize,
  CW_Data_PrimaryAmmoType,
  CW_Data_PrimaryAmmoMaxAmount,
  CW_Data_SecondaryAmmoType,
  CW_Data_SecondaryAmmoMaxAmount,
  CW_Data_SlotId,
  CW_Data_Position,
  CW_Data_WeaponFlags,
  CW_Data_Bindings,
  CW_Data_Flags
}

enum CW_Binding {
  CWB_Idle,
  CWB_Holster,
  CWB_Deploy,
  CWB_PrimaryAttack,
  CWB_SecondaryAttack,
  CWB_Reload,
  CWB_DefaultReloadEnd,
  CWB_CanDrop,
  CWB_GetMaxSpeed,
  CWB_Spawn,
  CWB_WeaponBoxModelUpdate,
  CWB_Pump,
  CWB_GrenadeThrow
}

enum CW_Flags (<<=1) {
  CWF_None,
  CWF_NoBulletSmoke = 1,
  CWF_NoBulletDecal,
  CWF_CustomReload,
  CWF_NotRefillable
}

native CW:CW_Register(const szName[], iWeaponId, iClipSize = WEAPON_NOCLIP, iPrimaryAmmoType = -1, iPrimaryAmmoMaxAmount = -1, iSecondaryAmmoType = -1, iSecondaryAmmoMaxAmount = -1, iSlotId = 0, iPosition = 0, iWeaponFlags = 0, const szIcon[] = "", CW_Flags:iFlags = CWF_None);
native CW_Bind(CW:iHandler, CW_Binding:iBinding, const szFunctionName[]);
native CW:CW_GetHandlerByEntity(pEntity);
native CW:CW_GetHandler(const szName[]);
native any:CW_GetWeaponData(CW:iHandler, CW_Data:iParam);
native CW_GetWeaponStringData(CW:iHandler, CW_Data:iParam, szOut[], iLen);

native CW_Deploy(pItem);
native CW_Holster(pItem);
native CW_ItemPostFrame(pItem);
native CW_Idle(pItem);
native CW_Reload(pItem);
native CW_PrimaryAttack(pItem);
native CW_SecondaryAttack(pItem);

native CW_PlayAnimation(pItem, iSequence, Float:flDuration = 0.0);
native CW_FireBulletsPlayer(pPlayer, iShots, const Float:vecSrc[3], const Float:vecDirShooting[3], const Float:vecSpread[3], Float:flDistance, Float:flDamage, Float:flRangeModifier = 1.0, pevAttacker = 0, Float:vOut[3]);
native CW_GrenadeDetonate(pGrenade, Float:flRadius = 0.0, Float:flMagnitude = 0.0);
native CW_GrenadeSmoke(pGrenade);
native CW_EjectWeaponBrass(pItem, iModelIndex, iSoundType);

native bool:CW_DefaultDeploy(pWeapon, const szViewModel[], const szWeaponModel[], iAnim, const szAnimExt[] = "");
native bool:CW_DefaultShot(pItem, Float:flDamage, Float:flRangeModifier, Float:flRate, Float:flSpread[3] = VECTOR_CONE_6DEGREES, iShots = 1, Float:flDistance = 8192.0);
native CW_DefaultReload(pItem, iAnim, Float:fDuration);
native bool:CW_DefaultShotgunIdle(pItem, iAnim, iReloadEndAnim, Float:fDuration = 0.25, Float:fReloadEndDuration = 1.0, const szPumpSound[] = "");
native bool:CW_DefaultShotgunShot(pItem, Float:flDamage, Float:flRangeModifier, Float:flRate, Float:flPumpDelay, Float:flSpread[3] = VECTOR_CONE_DM_SHOTGUN, iShots = 16, Float:flDistance = 2048.0);
native CW_DefaultShotgunReload(pItem, iStartAnim, iEndAnim, Float:fDelay, Float:fDuration);
native CW_DefaultSwing(pItem, Float:flDamage, Float:flRate, Float:flDistance);

native CW_GetPlayer(pItem);
native CW_RemovePlayerItem(pItem);

native CW_GiveWeapon(pPlayer, const szWeapon[]);
native CW_SpawnWeapon(CW:iHandler);
native CW_SpawnWeaponBox(CW:iHandler);
