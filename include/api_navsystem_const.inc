#if defined _api_navsystem_const_included
  #endinput
#endif
#define _api_navsystem_const_included

#define NAV_MAGIC_NUMBER 0xFEEDFACE
#define NAV_VERSION 5
#define MAX_AREA_TEAMS 2
#define MAX_APPROACH_AREAS 16
#define nullptr -1
#define HASH_TABLE_SIZE 256
#define MAX_PATH_SEGMENTS 256

#define UNDEFINED_PLACE 0
#define ANY_PLACE 0xFFFF

#define WALK_THRU_DOORS 0x01
#define WALK_THRU_BREAKABLES 0x02
#define WALK_THRU_EVERYTHING (WALK_THRU_DOORS | WALK_THRU_BREAKABLES)

enum NavErrorType {
    NAV_OK,
    NAV_CANT_ACCESS_FILE,
    NAV_INVALID_FILE,
    NAV_BAD_FILE_VERSION,
    NAV_CORRUPT_DATA,
};

enum NavAttributeType {
    NAV_CROUCH  = 0x01, // must crouch to use this node/area
    NAV_JUMP    = 0x02, // must jump to traverse this area
    NAV_PRECISE = 0x04, // do not adjust for obstacles, just move along area
    NAV_NO_JUMP = 0x08, // inhibit discontinuity jumping
};

enum NavDirType {
    NORTH = 0,
    EAST,
    SOUTH,
    WEST,

    NUM_DIRECTIONS
};

// Defines possible ways to move from one area to another
enum NavTraverseType {
    // NOTE: First 4 directions MUST match NavDirType
    GO_NORTH = 0,
    GO_EAST,
    GO_SOUTH,
    GO_WEST,
    GO_LADDER_UP,
    GO_LADDER_DOWN,
    GO_JUMP,

    NUM_TRAVERSE_TYPES
};

enum NavCornerType {
    NORTH_WEST = 0,
    NORTH_EAST,
    SOUTH_EAST,
    SOUTH_WEST,

    NUM_CORNERS
};

enum NavRelativeDirType {
    FORWARD = 0,
    RIGHT,
    BACKWARD,
    LEFT,
    UP,
    DOWN,

    NUM_RELATIVE_DIRECTIONS
};

enum LadderDirectionType {
    LADDER_UP = 0,
    LADDER_DOWN,
    NUM_LADDER_DIRECTIONS
};
