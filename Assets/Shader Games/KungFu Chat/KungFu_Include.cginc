#ifndef KUNGFU_INC
#define KUNGFU_INC

#include "../ShaderGames.cginc"

/* ---- General ---- */

#define MAX_ARR_SIZE 12         // Render queue stuff
#define RANGE        10.0
#define SPEED        0.8
#define EPSILON      0.1
#define MIDDLE_X     74         // Horizontal movement
#define UPPER_X      96
#define LOWER_Y      2.         // Vertical movement
#define UPPER_Y      20.

#define BOSS_DEFAULT_POS float2(100., 8.)

//// Texels

// Player Region
#define txState                  int2(0,0)
#define txP1PosDirHP             int2(1,0)
#define txP2PosDirHP             int2(2,0)
#define txP1CharAnimHistFrame    int2(3,0)
#define txP2CharAnimHistFrame    int2(4,0)
#define txP1ButtonBuffer         int2(5,0)
#define txP2ButtonBuffer         int2(6,0)
#define txP1ButtonBuffer2        int2(7,0)
#define txP2ButtonBuffer2        int2(0,1)
#define txP1HitBox               int2(1,1)
#define txP2HitBox               int2(2,1)
#define txP1Punch                int2(3,1)
#define txP2Punch                int2(4,1)
#define txP1P2Stagger            int2(5,1)

// Shared Region
#define txStagePosZContIndex     int2(0,2)
#define txScore                  int2(1,2)
#define txRenderQueue            int2(2,2)
#define txButtonFilter           int2(3,2)

// Boss
#define txBossPosDirHP           int2(4,2)
#define txBossAnimHistFrame      int2(5,2)
#define txBossHitBox             int2(6,2)
#define txBossPunch              int2(7,2)

// Character Select
#define txCharSelect             int2(0,7)
#define txPointers               int2(1,7)
#define txReadyState             int2(2,7)

#define _BOSS_IDLE        0
#define _BOSS_SPIN        1
#define _BOSS_JUSTICE     2
#define _BOSS_RASENGAN    3
#define _BOSS_HIT         4
#define _BOSS_FALL        5
#define _BOSS_DOWN        6
#define _BOSS_UP          7
#define _BOSS_INTRO       8

// Boss State Positions
/* 
    Starting location of the boss sprites
*/
static const int2 bStateLoc[9] = 
{
    int2(0, 896), int2(0, 768), int2(0, 512), int2(0, 384), int2(256, 640),
    int2(0, 640), int2(768, 640), int2(0, 640), int2(0, 896)
};

// Texture Size, Max Frame #
/* 
    Width, height and max frames of each 
    sprite per state
*/
static const int3 bSizeFrame[9] = 
{
    int3(128, 128, 6), int3(128, 128, 12), int3(128, 128, 13), int3(128, 128, 26),
    int3(128, 128, 1), int3(128, 128, 7), int3(128, 128, 1), int3(128, 128, 7), int3(128, 128, 6)
};


// Level progression states

#define TOTAL_STAGES     4

#define _FIGHT           0
#define _CONTINUE        1
#define _CUTSCENE1       2
#define _BOSS            3
#define _END             4
#define _CREDITS         5

static int checkPoint[TOTAL_STAGES] = {
    200, 400, 600, 800
};

// Spawn more enemies in later stages
static float spawnMax[TOTAL_STAGES] = {
    10, 20, 30, 1
};

//// Button Filters

// Dragon Punch
static float3 DPFilter[30] = {
    0.225188895,0.135335283,0.882496903,
    0.249352209,0.172421624,1,
    0.41111229 ,0.216265167,0.882496903,
    0.60653066 ,0.267051835,0.60653066,
    0.800737403,0.324652467,0.324652467,
    0.945959469,0.388558128,0.135335283,
    1          ,0.457833362,0.043936934,
    0.945959471,0.531095991,0.011108997,
    0.800737418,0.60653066 ,0.002187491,
    0.606530766,0.681940751,0.000335463,
    0.411112956,0.754839602,4.00653E-05,
    0.249355935,0.822577562,0.,
    0.135353948,0.882496903,0.,
    0.065812177,0.932102492,0.,
    0.028900963,0.969233234,0.,
    0.012312857,0.992217938,0.,
    0.00773184 ,1          ,0.,
    0.012312857,0.992217938,0.,
    0.028900963,0.969233234,0.,
    0.065812177,0.932102492,0.,
    0.135353948,0.882496903,0.,
    0.249355935,0.822577562,0.,
    0.411112956,0.754839602,0.,
    0.606530766,0.681940751,0.,
    0.800737418,0.60653066 ,0.,
    0.945959471,0.531095991,0.,
    1          ,0.457833362,0.,
    0.945959469,0.388558128,0.,
    0.800737403,0.324652467,0.,
    0.60653066 ,0.267051835,0.
};

// Zombie Region
#define txZombiesPosDirHP        int4(0,3,7,3)
#define txZombiesAnimHistFrame   int4(0,4,7,4)
#define txZombiesHitBox          int4(0,5,7,5)
#define txZombiesPunch           int4(0,6,7,6)

/* ---- Player ---- */

#define SCALE        1.5        // Player scale
#define PUNCHDIST    15

#define NUM_STATES 10
#define NUM_CHARS  5

#define _SCRN      0
#define _1001      1
#define _MERLIN    2
#define _SCRUFFY   3
#define _XIEXE     4

// Button Locations
static const float2 charBtnArr[NUM_CHARS] = {
    72.5, 120.5,
    108.5, 120.5,
    72.5, 84.5,
    108.5, 84.5,
    72.5, 48.5
};

// Character States
#define _STAND_IDLE     0
#define _WALK           1
#define _HIT            2
#define _POSE           3
#define _PUNCH_LEFT     4
#define _PUNCH_RIGHT    5
// Uninterpretable states
#define _KNOCKED_IDLE   6
#define _KNOCKED_DOWN   7
#define _KNOCKED_STAND  8
#define _SPECIAL        9

// Character Position
/*
    Starting location of individual
    characters on the sprite-sheet
*/
static const int2 charA[NUM_CHARS] = {
    0,    0,
    1024, 0,
    0,    1024,
    1024, 1024,
    2048, 0
};

/*
    Lining up transition between states
*/
static const float4 charTrans[NUM_CHARS][8] = {
    // SCRN
    0..xxxx, 0..xxxx, 0..xxxx, 0..xxxx, float4(46., -2., -3.43, -2.), float4(46., -2., -3.43, -2.), float4(6, 0, 58, 0), float4(0, 0, 50, 0),
    // 1001
    0..xxxx, 0..xxxx, 0..xxxx, 0..xxxx, float4(33.13, -5.12, 8.35, -5.12), float4(26, -.95, 13.34, -.95), float4(44.79, 5.7, -2.2, 5.7), float4(44.79, 5.7, -2.2, 5.7),
    // MERLIN
    0..xxxx, 0..xxxx, 0..xxxx, 0..xxxx, float4(25.54, 0., 17.05, 0), float4(44.6, 0., -.7, 0.), float4(0., 8.3, 41.44, 8.3), float4(0., 8.3, 41.44, 8.3),
    // SCRUFFY
    0..xxxx, 0..xxxx, 0..xxxx, 0..xxxx, float4(35.28, 0.5, 7.02, 0.5), float4(22.8, -1.1, 18.4, -1.1), float4(15., 0., 15, 0.), float4(15., 0., 15, 0.),
    // XIEXE
    0..xxxx, float4(-3.76, 0, 1, 0), float4(3, 0, -3, 0), 0..xxxx, float4(21.2, 1.35, 21.2, 1.35), float4(37.24, 4.5, 6.28, 4.5), float4(-18.56, 10.79, 63.4, 10.79), float4(-18.56, 10.79, 63.4, 10.79)
};

/*
    Getting up animation translation offsets
*/
static const float4 charStandTrans[NUM_CHARS][2] = {
    // SCRN
    float4(0, 0, 36.7, 0), float4(66.4, 0, 2.86, 0),
    // 1001
    float4(41.81, 4.7, 18.2, 4.7), float4(6.1, 4.7, 23.88, 4.7),
    // MERLIN
    float4(0., 4.86, 0., 4.86), float4(40.81, 4.86, 40.81, 4.86),
    // SCRUFFY
    float4(11.38, 0., -2.78, 4.71), float4(11.38, 0., 44.3, 4.71),
    // XIEXE
    float4(-17.7, 6.17, -5.5, 6.17), float4(65.28, 6.17, 50., 6.17)
};

// Character States Position
/* 
    Starting location of individual
    character state animations in sprite-sheet
    with width and height
*/
static const int4 locSizeA[NUM_STATES] = {
    int4(  0, 896,  64, 128),
    int4(576, 896,  64, 128),
    int4(896, 640,  64, 128),
    int4(896, 768,  64, 128),
    int4(  0, 768, 128, 128),
    int4(  0, 640, 128, 128),
    int4(  0, 320, 128,  64),
    int4(  0, 384, 128, 128),
    int4(  0, 512, 128, 128),
    int4(896, 768,  64, 128)
};

// Sprite Frames
static int frameA[NUM_STATES] = 
{
    8, 6, 1, 1, 7, 6, 6, 8, 8, 10
};

/* ---- Zombie ---- */

#define ZSCALE       0.9        // Zombie scale
#define ZSPEED       0.01
#define ZSPEED_MAX   0.75
#define ZATTKDIST    20
#define ZPUNCHDIST   20
#define ZBOOM_HP     60.

// Zombie Types
#define _ZNORM1   0
#define _ZNORM2   1
#define _ZBOOM    2

// Zombie States
#define _ZWALK           0
#define _ZATTK           1
#define _ZDIE            2
#define _ZHIT            3

// Zombie State Positions
/* 
    Starting location of individual 
    zombie state animations in sprite-sheet
*/
static const int2 zStateLoc[3][4] = 
{
    { int2(  0, 960), int2( 96, 960), int2(  0, 896), int2(672, 960) }, //Normal zombie 1
    { int2(  0, 832), int2( 96, 832), int2(  0, 768), int2(672, 832) }, //Normal zombie 2
    { int2(  0, 704), int2(  0, 576), int2(320, 704), int2(384, 704) }  //Boomer
};

// Texture Size, Max Frame #
/* 
    Width, height and max frames of each 
    sprite per state
*/
static const int3 zSizeFrame[3][4] = 
{
    { int3(32, 64, 2), int3( 64,  64,  8), int3(64, 64, 8), int3(64, 64, 0) }, 
    { int3(32, 64, 2), int3( 64,  64,  8), int3(64, 64, 8), int3(64, 64, 0) },
    { int3(64, 64, 4), int3(128, 128, 27), int3(64, 64, 6), int3(64, 64, 0) }
};

// Texture Offset to Center
static const int4 zTranslate[3][4] =
{
    { 0..xxxx, int4(18, 0, 18, 0), int4(18, 0, 18, 0), int4(18, 0, 18, 0) },
    { 0..xxxx, int4(18, 0, 18, 0), int4(18, 0, 18, 0), int4(18, 0, 18, 0) },
    { int4(16, 14, 16, 14), int4(68, 30, 35, 30), int4(10, 14, 22, 14), int4(10, 14, 22, 14) }
};

/* ---- Functions ---- */

float4 spriteTemplate (float4 posOffset, float4 fragCoordFrame, float4 translate,
        float3 sizeFlip, Texture2D<float4> sprite, float scale) {
    posOffset.xy = sizeFlip.z ?
        posOffset.xy - translate.xy : 
        posOffset.xy - translate.zw;
    int2 coord = int2(fragCoordFrame.xy - posOffset.xy) * scale;
    if (abs(coord.y - sizeFlip.y / 2) < sizeFlip.y / 2 &&
        abs(coord.x - sizeFlip.x / 2) < sizeFlip.x / 2) {
        coord.x = sizeFlip.z ? sizeFlip.x - coord.x : coord.x;
        coord.y += posOffset.w + sizeFlip.y * fragCoordFrame.w;
        coord.x += posOffset.z + sizeFlip.x * fragCoordFrame.z;
        return sprite.Load(int3(coord, 0));
    }
    else return 0..xxxx;
}

float4 hpUI(in Texture2D<float4> uiTex, in uint2 pos, in uint2 fragCoord) {
    uint2 coord = uint2(fragCoord.x - pos.x, fragCoord.y - pos.y);
    if (coord.y < 36 && coord.x < 180) {
        coord.y += 220;
        return uiTex.Load(uint3(coord, 0));
    }
    else return 0..xxxx;
}

float4 hpBar(in Texture2D<float4> uiTex, in uint4 pos, in uint2 fragCoord) {
    uint2 coord = uint2(fragCoord.xy - pos.xy);
    if (coord.y < 15 && coord.x < pos.z) {
        coord.x = pos.w > 0.5 ? 54 - coord.x : coord.x;
        coord.y += 241;
        coord.x += 180;
        return uiTex.Load(uint3(coord, 0));
    }
    else return 0..xxxx;
}

float4 profilePic(in Texture2D<float4> uiTex, in uint4 pos, in uint2 fragCoord) {
    uint2 coord = uint2(fragCoord.xy - pos.xy);
    if (coord.y < 30 && coord.x < 30) {
        coord.y += 128;
        coord.x += 994;
        coord += pos.zw;
        return uiTex.Load(uint3(coord, 0));
    }
    else return 0..xxxx;
}

float4 goForward(in Texture2D<float4> uiTex, in uint2 pos, in uint2 fragCoord) {
    uint2 coord = uint2(fragCoord.xy - pos.xy);
    if (coord.y < 24 && coord.x < 44) {
        coord.y += 217;
        coord.x += 185;
        return uiTex.Load(uint3(coord, 0));
    }
    else return 0..xxxx;
}

float4 specialUI(in Texture2D<float4> uiTex, in uint2 pos, in uint2 fragCoord) {
    uint2 coord = uint2(fragCoord.xy - pos.xy);
    if (coord.y < 10 && coord.x < 180) {
        coord.y += 209;
        return uiTex.Load(uint3(coord, 0));
    }
    else return 0..xxxx;
}

float4 specialMove(in Texture2D<float4> tex, in uint4 pos, in uint2 fragCoord) {
    uint2 coord = uint2(fragCoord.xy - pos.xy);
    if (coord.y < 192 && coord.x < 256) {
        coord.y += 128;
        coord.x += 256;
        coord += pos.zw;
        return tex.Load(uint3(coord, 0));
    }
    else return 0..xxxx;
}

float4 specialHint(in Texture2D<float4> tex, in uint2 pos, in uint2 fragCoord) {
    uint2 coord = uint2(fragCoord.xy - pos.xy);
    if (coord.y < 37 && coord.x < 81) {
        coord.y += 176;
        coord.x += 175;
        return tex.Load(uint3(coord, 0));
    }
    else return 0..xxxx;
}

float4 bossText1(in Texture2D<float4> tex, in uint2 pos, in uint2 fragCoord) {
    uint2 coord = uint2(fragCoord.xy - pos.xy);
    if (coord.y < 27 && coord.x < 150) {
        coord.y += 176;
        return tex.Load(uint3(coord, 0));
    }
    else return 0..xxxx;
}

float4 playerText1(in Texture2D<float4> tex, in uint2 pos, in uint2 fragCoord) {
    uint2 coord = uint2(fragCoord.xy - pos.xy);
    if (coord.y < 27 && coord.x < 150) {
        coord.y += 149;
        return tex.Load(uint3(coord, 0));
    }
    else return 0..xxxx;
}

float4 cursor2(in Texture2D<float4> tex, in uint2 pos, in uint2 fragCoord) {
    uint2 coord = uint2(fragCoord.xy - pos.xy);
    if (coord.y < 20 && coord.x < 30) {
        coord.x += 118; coord.y += 104;
        return tex.Load(uint3(coord, 0));
    }
    else return 0..xxxx;
}

float4 cursor1(in Texture2D<float4> tex, in uint2 pos, in uint2 fragCoord) {
    uint2 coord = uint2(fragCoord.xy - pos.xy);
    if (coord.y < 20 && coord.x < 30) {
        coord.x += 118; coord.y += 124;
        return tex.Load(uint3(coord, 0));
    }
    else return 0..xxxx;
}

float4 charPose(in Texture2D<float4> tex, in uint4 pos, in uint2 fragCoord) {
    uint2 coord = uint2(fragCoord.xy - pos.xy);
    if (coord.y < 320 && coord.x < 128) {
        coord.x += pos.z; coord.y += pos.w;
        return tex.Load(uint3(coord, 0));
    }
    else return 0..xxxx;
}

float4 charFace(in Texture2D<float4> tex, in int4 pos, in uint2 fragCoord) {
    uint2 coord = uint2(fragCoord.xy - pos.xy);
    if (coord.y < 128 && coord.x < 128) {
        coord.x = coord.x + pos.z + 896;
        coord.y = coord.y + pos.w;
        return tex.Load(uint3(coord, 0));
    }
    else return 0..xxxx;
}

float4 credits(in Texture2D<float4> tex, in uint2 pos, in uint2 fragCoord) {
    uint2 coord = uint2(fragCoord.xy - pos.xy);
    if (coord.y < 180 && coord.x < 180) {
        coord.x = coord.x + 332;
        coord.y = coord.y + 180;
        return tex.Load(uint3(coord, 0));
    }
    else return 0..xxxx;
}

#endif