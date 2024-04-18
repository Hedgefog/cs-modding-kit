
# Player Model API

## Working With Models

To change player model use `PlayerModel_Set` and `PlayerModel_Update` natives.
`PlayerModel_Set` is using to set player model, calling `PlayerModel_Update` will force update model.
```cpp
PlayerModel_Set(pPlayer, "player/model/vip/vip.mdl"); // set current player model
PlayerModel_Update(pPlayer); // force update player model
```


## Working With Animations

The API supports loading custom animations, including additional weapon animations from separate files.

### Precaching Animation

To precache the animation use `PlayerModel_PrecacheAnimation` native, it will precache animation from `animations` directory. This example will precache animation from `cstrike/animations/my-mod/player.mdl`:
```cpp
PlayerModel_PrecacheAnimation("my-mod/player.mdl");
```

### Set Custom Weapon Animation

Customize weapon animations by set `m_szAnimExtension` member. The following example sets the animation to `ref_aim_myweapon`:
```cpp
static const szCustonWeaponExt[] = "myweapon";

set_ent_data_string(pPlayer, "CBasePlayer", "m_szAnimExtention", szCustonWeaponExt);
set_ent_data(pPlayer, "CBaseMonster", "m_Activity", ACT_IDLE);
rg_set_animation(pPlayer, PLAYER_IDLE);
```


## Making Animations File

### Creating Animation Files

#### Basic Animations
Fist of all you have to provide basic player sequences like `walk`, `run`, `flitch`, etc.

<details>
    <summary>Example</summary>

    $sequence "dummy" {
        "anims/dummy"
        fps 24
        loop
    }
    $sequence "idle1" {
        "anims/idle1"
        ACT_IDLE 1
        fps 15
        loop
    }
    $sequence "crouch_idle" {
        "anims/crouch_idle"
        ACT_CROUCHIDLE 1
        fps 10
        loop
    }
    $sequence "walk" {
        "anims/walk"
        ACT_WALK 1
        fps 30
        loop
        LX
    }
    $sequence "run" {
        "anims/run"
        ACT_RUN 1
        fps 60
        loop
        LX
    }
    $sequence "crouchrun" {
        "anims/crouchrun"
        ACT_CROUCH 1
        fps 30
        loop
        LX
    }
    $sequence "jump" {
        "anims/jump"
        ACT_HOP 1
        fps 36
    }
    $sequence "longjump" {
        "anims/longjump"
        ACT_LEAP 1
        fps 36
    }
    $sequence "swim" {
        "anims/swim"
        ACT_SWIM 1
        fps 30
        loop
    }
    $sequence "treadwater" { "anims/treadwater"
        ACT_HOVER 1
        fps 24
        loop
    }
    $sequence "gut_flinch" {
        "anims/gut_flinch_blend01"
        "anims/gut_flinch_blend02"
        "anims/gut_flinch_blend03"
        "anims/gut_flinch_blend04"
        "anims/gut_flinch_blend05"
        "anims/gut_flinch_blend06"
        "anims/gut_flinch_blend07"
        "anims/gut_flinch_blend08"
        "anims/gut_flinch_blend09"
        blend XR -90 90
        fps 30
    }
    $sequence "head_flinch" {
        "anims/head_flinch_blend01"
        "anims/head_flinch_blend02"
        "anims/head_flinch_blend03"
        "anims/head_flinch_blend04"
        "anims/head_flinch_blend05"
        "anims/head_flinch_blend06"
        "anims/head_flinch_blend07"
        "anims/head_flinch_blend08"
        "anims/head_flinch_blend09"
        blend XR -90 90
        fps 30
    }
</details>


#### Fake Reference
Ensure your animation model includes at least one polygon. Here's an example SMD file for a fake reference:

<details>
    <summary>animreference.smd</summary>

    version 1
    nodes
    0 "Bip01" -1
    1 "Bip01 Pelvis" 0
    2 "Bip01 Spine" 1
    3 "Bip01 Spine1" 2
    4 "Bip01 Spine2" 3
    5 "Bip01 Spine3" 4
    6 "Bip01 Neck" 5
    7 "Bip01 Head" 6
    8 "Bone01" 7
    9 "Bip01 L Clavicle" 6
    10 "Bip01 L UpperArm" 9
    11 "Bip01 L Forearm" 10
    12 "Bip01 L Hand" 11
    13 "Bip01 L Finger0" 12
    14 "Bip01 L Finger01" 13
    15 "Bip01 L Finger1" 12
    16 "Bip01 L Finger11" 15
    17 "-- L knuckle" 15
    18 "-- L Forearm twist" 11
    19 "-- L wrist" 11
    20 "-- L Elbow" 10
    21 "-- L bicep twist" 10
    22 "-- L shoulder outside" 9
    23 "-- L Shoulder inside" 9
    24 "Bip01 R Clavicle" 6
    25 "Bip01 R UpperArm" 24
    26 "Bip01 R Forearm" 25
    27 "Bip01 R Hand" 26
    28 "Bip01 R Finger0" 27
    29 "Bip01 R Finger01" 28
    30 "Bip01 R Finger1" 27
    31 "Bip01 R Finger11" 30
    32 "-- R knuckle" 30
    33 "-- R wrist" 26
    34 "-- R forearm twist" 26
    35 "-- R Elbow" 25
    36 "-- R bicep twist" 25
    37 "-- R Shoulder inside" 24
    38 "-- R shoulder outside" 24
    39 "-- Neck smooth" 5
    40 "-- R Butt" 1
    41 "-- L butt" 1
    42 "Bip01 L Thigh" 1
    43 "Bip01 L Calf" 42
    44 "Bip01 L Foot" 43
    45 "Bip01 L Toe0" 44
    46 "-- L ankle" 43
    47 "-- L Knee" 42
    48 "Bip01 R Thigh" 1
    49 "Bip01 R Calf" 48
    50 "Bip01 R Foot" 49
    51 "Bip01 R Toe0" 50
    52 "-- R Ankle" 49
    end
    skeleton
    time 0
    0  0.233849 -2.251689 38.192150 0.000000 0.000000 -1.570795
    1  -2.276935 0.000003 -1.238186 -1.570795 -1.570451 0.000000
    2  1.797145 0.711796 -0.000002 -0.000004 -0.000001 0.000739
    3  4.118605 -0.003279 0.000000 0.000000 0.000000 0.000035
    4  4.118601 -0.003280 0.000000 0.000000 0.000000 0.000049
    5  4.118600 -0.003280 0.000000 0.000000 0.000000 -0.000009
    6  4.118531 -0.003538 0.000000 0.000000 0.000000 -0.019437
    7  4.443601 0.000000 0.000000 0.000000 -0.000001 0.201740
    8  1.426626 0.072724 0.002913 2.958476 -1.570796 0.000000
    9  0.000004 0.003534 1.732721 -0.000040 -1.501696 -3.122911
    10  6.384776 0.000000 0.000001 0.025648 -0.046980 0.004099
    11  10.242682 0.000000 -0.000002 0.000000 0.000000 -0.008014
    12  11.375562 0.000000 0.000005 -1.580468 -0.132234 0.009455
    13  0.728679 0.023429 -1.008292 1.705251 0.347372 0.567022
    14  2.136497 0.000000 0.000001 0.000000 0.000000 0.287979
    15  3.115505 -0.886041 -0.021431 -0.000782 0.000152 0.191986
    16  2.011151 0.000000 0.000000 0.000000 0.000000 0.659566
    17  1.734173 0.000003 0.000000 0.000000 0.000000 0.330185
    18  6.000001 0.000000 0.000000 -1.578050 0.000000 0.000000
    19  11.375562 0.000000 0.000005 -1.575523 -0.074433 0.005312
    20  10.510129 0.000000 0.000000 0.000000 0.000000 -1.574800
    21  5.500000 0.000000 -0.000001 -0.011814 0.000000 0.000000
    22  6.551491 0.000000 -0.000001 0.019708 -0.055281 0.008457
    23  6.551491 0.000000 -0.000001 0.010051 -0.028020 0.004425
    24  0.000004 0.003543 -1.732721 -0.000040 1.501696 -3.122992
    25  6.384777 0.000000 -0.000001 -0.025648 0.046980 0.004099
    26  10.242681 0.000000 0.000002 0.000000 0.000000 -0.008014
    27  11.375562 0.000000 -0.000002 1.580468 0.132234 0.009455
    28  0.728679 0.023429 1.008292 -1.705251 -0.347372 0.567022
    29  2.136496 -0.000001 0.000000 0.000000 0.000000 0.287979
    30  3.115505 -0.886040 0.021431 0.000782 -0.000152 0.191986
    31  2.011151 0.000000 0.000000 0.000000 0.000000 0.659566
    32  1.734173 -0.000001 0.000000 0.000000 0.000000 0.330185
    33  11.389366 -0.000819 0.158785 1.575523 0.074433 0.005312
    34  6.000001 0.000000 0.000003 1.575523 0.000000 0.000000
    35  10.510130 0.000000 -0.000001 0.000000 0.000000 -1.574800
    36  5.499999 0.000000 0.000001 0.010051 0.000000 0.000000
    37  6.551491 0.000000 0.000001 -0.010051 0.028020 0.004424
    38  6.551491 0.000000 0.000001 -0.010051 0.028020 0.004424
    39  4.226144 -0.003201 0.000000 0.000000 0.000000 0.000000
    40  0.000005 -0.000005 -3.713579 -0.006814 3.056983 -0.063787
    41  -0.000005 0.000005 3.713579 0.005299 -3.071082 -0.053070
    42  -0.000005 0.000007 3.619081 0.011132 -3.002289 -0.086533
    43  16.573919 0.000000 0.000000 0.000000 0.000000 -0.162458
    44  15.128179 0.000000 0.000001 0.000920 -0.139743 0.076637
    45  5.758665 4.244730 0.000000 0.000000 0.000000 1.570796
    46  15.708952 0.000001 0.000000 0.001562 -0.077726 0.040998
    47  17.210194 0.000000 0.000001 0.000000 0.000000 -1.486823
    48  0.000005 -0.000003 -3.619081 -0.011130 3.002286 -0.086533
    49  16.573919 0.000000 0.000000 0.000000 0.000000 -0.162458
    50  15.128179 0.000000 0.000000 -0.000920 0.139743 0.076637
    51  5.758665 4.244731 0.000000 0.000000 0.000000 1.570796
    52  15.708952 0.000000 0.000000 -0.001364 0.104219 0.055002
    end
    triangles
    black.bmp
    0 0.000000 0.000000 0.000000 0.000000 0.000000 0.000000 0.000000 0.000000
    0 0.000000 0.000000 0.000000 0.000000 0.000000 0.000000 0.000000 0.000000
    0 0.000000 0.000000 0.000000 0.000000 0.000000 0.000000 0.000000 0.000000
    end
</details>

Use the `$body` command in your QC file to add this reference:

```cpp
$body "studio" "animreference"
```

#### Protecting Bones

Use a compiler like `DoomMusic's StudioMDL` to protect bones. Add `$protection` for each animation bone before references and sequences in the `.qc`:

<details>
    <summary>Example</summary>

    $protected "Bip01" 
    $protected "Bip01 Pelvis"
    $protected "Bip01 Spine"
    $protected "Bip01 Spine1"
    $protected "Bip01 Spine2"
    $protected "Bip01 Spine3"
    $protected "Bip01 Neck"
    $protected "Bip01 Head"
    $protected "Bone01"
    $protected "Bip01 L Clavicle"
    $protected "Bip01 L UpperArm"
    $protected "Bip01 L Forearm"
    $protected "Bip01 L Hand"
    $protected "Bip01 L Finger0"
    $protected "Bip01 L Finger01"
    $protected "Bip01 L Finger1"
    $protected "Bip01 L Finger11"
    $protected "-- L knuckle"
    $protected "-- L Forearm twist"
    $protected "-- L wrist"
    $protected "-- L Elbow"
    $protected "-- L bicep twist"
    $protected "-- L shoulder outside"
    $protected "-- L Shoulder inside"
    $protected "Bip01 R Clavicle"
    $protected "Bip01 R UpperArm"
    $protected "Bip01 R Forearm"
    $protected "Bip01 R Hand"
    $protected "Bip01 R Finger0"
    $protected "Bip01 R Finger01"
    $protected "Bip01 R Finger1"
    $protected "Bip01 R Finger11"
    $protected "-- R knuckle"
    $protected "-- R wrist"
    $protected "-- R forearm twist"
    $protected "-- R Elbow"
    $protected "-- R bicep twist"
    $protected "-- R Shoulder inside"
    $protected "-- R shoulder outside"
    $protected "-- Neck smooth"
    $protected "-- R Butt"
    $protected "-- L butt"
    $protected "Bip01 L Thigh"
    $protected "Bip01 L Calf"
    $protected "Bip01 L Foot"
    $protected "Bip01 L Toe0"
    $protected "-- L ankle"
    $protected "-- L Knee"
    $protected "Bip01 R Thigh"
    $protected "Bip01 R Calf"
    $protected "Bip01 R Foot"
    $protected "Bip01 R Toe0"
    $protected "-- R Ankle"
</details>

#### Custom Animation Sequences

Add your custom weapon animations:

<details>
    <summary>Example</summary>

    $sequence "crouch_aim_myweapon" {
            "crouch_aim_myweapon_blend1" 
            "crouch_aim_myweapon_blend2" 
            "crouch_aim_myweapon_blend3" 
            "crouch_aim_myweapon_blend4" 
            "crouch_aim_myweapon_blend5" 
            "crouch_aim_myweapon_blend6" 
            "crouch_aim_myweapon_blend7" 
            "crouch_aim_myweapon_blend8" 
            "crouch_aim_myweapon_blend9" 
            blend XR -90 90 fps 30 loop 
    }
    $sequence "crouch_shoot_myweapon" {
            "crouch_shoot_grenade_blend1" 
            "crouch_shoot_grenade_blend2" 
            "crouch_shoot_grenade_blend3" 
            "crouch_shoot_grenade_blend4" 
            "crouch_shoot_grenade_blend5" 
            "crouch_shoot_grenade_blend6" 
            "crouch_shoot_grenade_blend7" 
            "crouch_shoot_grenade_blend8" 
            "crouch_shoot_grenade_blend9" 
            blend XR -90 90 fps 30
    }
    $sequence "ref_aim_myweapon" {
            "ref_aim_myweapon_blend1" 
            "ref_aim_myweapon_blend2" 
            "ref_aim_myweapon_blend3" 
            "ref_aim_myweapon_blend4" 
            "ref_aim_myweapon_blend5" 
            "ref_aim_myweapon_blend6" 
            "ref_aim_myweapon_blend7" 
            "ref_aim_myweapon_blend8" 
            "ref_aim_myweapon_blend9" 
            blend XR -90 90 fps 30 loop 
    }
    $sequence "ref_shoot_myweapon" {
            "ref_shoot_grenade_blend1" 
            "ref_shoot_grenade_blend2" 
            "ref_shoot_grenade_blend3" 
            "ref_shoot_grenade_blend4" 
            "ref_shoot_grenade_blend5" 
            "ref_shoot_grenade_blend6" 
            "ref_shoot_grenade_blend7" 
            "ref_shoot_grenade_blend8" 
            "ref_shoot_grenade_blend9" 
            blend XR -90 90 fps 30
    }
</details>
