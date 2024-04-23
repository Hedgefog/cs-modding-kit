# Custom Weapons API

## Simple 9mm handgun
Example of simple handgun from Half-Life.

```cpp
#pragma semicolon 1

#include <amxmodx>
#include <fakemeta>
#include <reapi>
#include <xs>

#include <api_custom_weapons>

#define PLUGIN "[Weapon] 9mm Handgun"
#define VERSION "1.0.0"
#define AUTHOR "Hedgehog Fog"

#define WEAPON_NAME "weapon_9mmhandgun"
#define WEAPON_ID CSW_FIVESEVEN
#define WEAPON_AMMO_ID 10
#define WEAPON_SLOT_ID 1
#define WEAPON_SLOT_POS 6
#define WEAPON_CLIP_SIZE 7
#define WEAPON_ICON "fiveseven"
#define WEAPON_DAMAGE 30.0
#define WEAPON_SPREAD_MODIFIER 0.75
#define WEAPON_RATE 0.125
#define WEAPON_RELOAD_DURATION 1.68

new const g_szHudTxt[] = "sprites/weapon_9mmhandgun.txt";

new const g_szWeaponModelV[] = "models/v_9mmhandgun.mdl";
new const g_szWeaponModelP[] = "models/p_9mmhandgun.mdl";
new const g_szWeaponModelW[] = "models/w_9mmhandgun.mdl";
new const g_szShellModel[] = "models/shell.mdl";

new const g_szShotSound[] = "weapons/pl_gun3.wav";
new const g_szReloadStartSound[] = "items/9mmclip1.wav";
new const g_szReloadEndSound[] = "items/9mmclip2.wav";

new CW:g_iCwHandler;

public plugin_precache() {
    precache_generic(g_szHudTxt);

    precache_model(g_szWeaponModelV);
    precache_model(g_szWeaponModelP);
    precache_model(g_szWeaponModelW);
    precache_model(g_szShellModel);

    precache_sound(g_szShotSound);
    precache_sound(g_szReloadStartSound);
    precache_sound(g_szReloadEndSound);

    g_iCwHandler = CW_Register(WEAPON_NAME, WEAPON_ID, WEAPON_CLIP_SIZE, WEAPON_AMMO_ID, 120, _, _, WEAPON_SLOT_ID, WEAPON_SLOT_POS, _, WEAPON_ICON, CWF_NoBulletSmoke);
    CW_Bind(g_iCwHandler, CWB_Idle, "@Weapon_Idle");
    CW_Bind(g_iCwHandler, CWB_PrimaryAttack, "@Weapon_PrimaryAttack");
    CW_Bind(g_iCwHandler, CWB_Reload, "@Weapon_Reload");
    CW_Bind(g_iCwHandler, CWB_Deploy, "@Weapon_Deploy");
    CW_Bind(g_iCwHandler, CWB_GetMaxSpeed, "@Weapon_GetMaxSpeed");
    CW_Bind(g_iCwHandler, CWB_Spawn, "@Weapon_Spawn");
    CW_Bind(g_iCwHandler, CWB_WeaponBoxModelUpdate, "@Weapon_WeaponBoxSpawn");
    CW_Bind(g_iCwHandler, CWB_Holster, "@Weapon_Holster");
}

public plugin_init() {
    register_plugin(PLUGIN, VERSION, AUTHOR);
}

@Weapon_Idle(this) {
    switch (random(3)) {
        case 0: CW_PlayAnimation(this, 0, 61.0 / 16.0);
        case 1: CW_PlayAnimation(this, 1, 61.0 / 16.0);
        case 2: CW_PlayAnimation(this, 2, 61.0 / 14.0);
    }
}

@Weapon_PrimaryAttack(this) {
    if (get_member(this, m_Weapon_iShotsFired) > 0) {
        return;
    }

    static Float:vecSpread[3];
    UTIL_CalculateWeaponSpread(this, Float:VECTOR_CONE_3DEGREES, 3.0, 0.1, 0.95, 3.5, vecSpread);

    if (CW_DefaultShot(this, WEAPON_DAMAGE, WEAPON_SPREAD_MODIFIER, WEAPON_RATE, vecSpread)) {
        CW_PlayAnimation(this, 3, 0.71);

        new pPlayer = CW_GetPlayer(this);

        emit_sound(pPlayer, CHAN_WEAPON, g_szShotSound, VOL_NORM, ATTN_NORM, 0, PITCH_NORM);

        static Float:vecPunchAngle[3];
        pev(pPlayer, pev_punchangle, vecPunchAngle);
        xs_vec_add(vecPunchAngle, Float:{-2.5, 0.0, 0.0}, vecPunchAngle);

        if (xs_vec_len(vecPunchAngle) > 0.0) {
            set_pev(pPlayer, pev_punchangle, vecPunchAngle);
        }

        CW_EjectWeaponBrass(this, engfunc(EngFunc_ModelIndex, g_szShellModel), 1);
    }
}

@Weapon_Reload(this) {
    if (CW_DefaultReload(this, 5, WEAPON_RELOAD_DURATION)) {
        new pPlayer = CW_GetPlayer(this);
        emit_sound(pPlayer, CHAN_WEAPON, g_szReloadStartSound, VOL_NORM, ATTN_NORM, 0, PITCH_NORM);
    }
}

@Weapon_DefaultReloadEnd(this) {
    new pPlayer = CW_GetPlayer(this);
    emit_sound(pPlayer, CHAN_WEAPON, g_szReloadEndSound, VOL_NORM, ATTN_NORM, 0, PITCH_NORM);
}

@Weapon_Deploy(this) {
    CW_DefaultDeploy(this, g_szWeaponModelV, g_szWeaponModelP, 7, "onehanded");
}

Float:@Weapon_GetMaxSpeed(this) {
    return 250.0;
}

@Weapon_Spawn(this) {
    engfunc(EngFunc_SetModel, this, g_szWeaponModelW);
}

@Weapon_WeaponBoxSpawn(this, pWeaponBox) {
    engfunc(EngFunc_SetModel, pWeaponBox, g_szWeaponModelW);
}

@Weapon_Holster(this) {
    CW_PlayAnimation(this, 8, 16.0 / 20.0);
}

stock Float:UTIL_CalculateWeaponSpread(pWeapon, const Float:vecSpread[3], Float:flMovementFactor, Float:flFirstShotModifier, Float:flDuckFactor, Float:flAirFactor, Float:vecOut[3]) {
    new Float:flSpreadRatio = 1.0;

    new pPlayer = get_member(pWeapon, m_pPlayer);

    static Float:vecVelocity[3]; pev(pPlayer, pev_velocity, vecVelocity);
    if (xs_vec_len(vecVelocity) > 0) flSpreadRatio *= flMovementFactor;
  
    new iPlayerFlags = pev(pPlayer, pev_flags);
    if (iPlayerFlags & FL_DUCKING) flSpreadRatio *= flDuckFactor;
    if (~iPlayerFlags & FL_ONGROUND) flSpreadRatio *= flAirFactor;

    new iShotsFired = get_member(pWeapon, m_Weapon_iShotsFired);
    if (!iShotsFired) flSpreadRatio *= flFirstShotModifier;

    xs_vec_mul_scalar(vecSpread, flSpreadRatio, vecOut);

    return flSpreadRatio;
}
```
